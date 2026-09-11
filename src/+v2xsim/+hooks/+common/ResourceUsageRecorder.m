classdef ResourceUsageRecorder < v2xsim.hook.Hook
    %RESOURCEUSAGERECORDER Scheduler-neutral, observational resource evidence.
    % Piecewise-constant intervals preserve elapsed-time weighting. Repeated
    % decisions with unchanged assignments do not create extra observations.
    % On-air rows count transmitters, never duplicated receiver-link rows.
    properties (Constant, Access=protected)
        DependencyTypes = ?v2xsim.hook.dependencies.OutputDirectory
    end
    properties (Constant, Access=private)
        TransmissionColumns = ["TimeSeconds","VehicleId","PacketSequence","AttemptNumber","ResourceId"]
        ChangeColumns = ["TimeSeconds","ReassignedVehicles","BlockedVehicles","SelectedVehicles"]
    end
    properties (SetAccess=immutable)
        Grid
        Pressure
        DurationSeconds (1,1) double
    end
    properties (Access=private)
        Directory (1,1) string = ""
        Kinematics table = table()
        Assignments table = table()
        LastTime (1,1) double = 0
        Rows cell = {}
        DistributionRows cell = {}
        TransmissionRows cell = {}
        ChangeRows cell = {}
        Written (1,4) logical = false(1,4)
        LastTransmissionTime (1,1) double = -1
        LastTransmissionKeys (:,1) string = strings(0,1)
    end
    methods
        function obj = ResourceUsageRecorder(grid,pressure,duration)
            arguments
                grid (1,1) v2xsim.resource.BRResourceGrid
                pressure (1,1) v2xsim.resource.ResourcePressure
                duration (1,1) double {mustBePositive,mustBeFinite}
            end
            assert(grid.NetworkSliceId==pressure.NetworkSliceId, ...
                "v2xsim:resource:UsageSlice","Grid and pressure slice mismatch.");
            obj.Grid=grid; obj.Pressure=pressure; obj.DurationSeconds=duration;
        end
        function obj = build(obj,directory)
            obj.Directory=directory.Path;
        end
        function [obj,invocation] = invoke(obj,invocation)
            t=invocation.SimulationTimeSeconds;
            if isa(invocation,"v2xsim.hook.invocations.AfterVehicleKinematicsUpdatedInvocation")
                obj=obj.closeInterval(t);
                obj.Kinematics=invocation.VehicleKinematics;
            elseif isa(invocation,"v2xsim.hook.invocations.AfterResourceAllocationDecisionInvocation")
                assignments=invocation.Result.Assignments;
                assert(size(assignments.ResourceIds,2)==1, ...
                    "v2xsim:resource:UsageTransmissionCount", ...
                    "ResourceUsage currently requires one transmission per packet.");
                % Compare small value arrays, not sorted tables, at every
                % radio slot. Most callbacks retain the previous assignment.
                changedAssignments=isempty(obj.Assignments) || ...
                    ~isequal(assignments.UeId,obj.Assignments.UeId) || ...
                    ~isequaln(assignments.ResourceIds,obj.Assignments.ResourceIds);
                changed=0;
                if changedAssignments && ~isempty(obj.Assignments)
                    [known,previous]=ismember(assignments.UeId,obj.Assignments.UeId);
                    old=obj.Assignments.ResourceIds(previous(known),:);
                    current=assignments.ResourceIds(known,:);
                    changed=nnz(~(old==current | (isnan(old) & isnan(current))));
                end
                if changedAssignments
                    obj=obj.closeInterval(t);
                    obj.Assignments=assignments;
                end
                selected=numel(invocation.Result.DecisionUeIds);
                blocked=numel(invocation.Result.BlockedUeIds);
                if changed>0 || selected>0 || blocked>0
                    obj.ChangeRows{end+1}=table(t,changed,blocked,selected, ...
                        VariableNames=obj.ChangeColumns);
                end
            elseif isa(invocation,"v2xsim.hook.invocations.AfterPacketFatesDeterminedInvocation")
                obj=obj.recordTransmission(invocation);
            else
                error("v2xsim:resource:UsageInvocation","Unsupported resource-usage invocation.");
            end
            if numel(obj.Rows)>=1000 || numel(obj.TransmissionRows)>=1000 || numel(obj.ChangeRows)>=1000
                obj=obj.flush();
            end
        end
        function obj = cleanup(obj)
            obj=obj.closeInterval(obj.DurationSeconds);
            % Finalize inactive event streams with their normal schema. Empty
            % tables add no observations and use the same first-write path as
            % real events; Written prevents duplicate headers on later cleanup.
            emptyColumn = zeros(0,1);
            if ~obj.Written(3) && isempty(obj.TransmissionRows)
                obj.TransmissionRows={table(emptyColumn,strings(0,1),emptyColumn,emptyColumn,emptyColumn, ...
                    VariableNames=obj.TransmissionColumns)};
            end
            if ~obj.Written(4) && isempty(obj.ChangeRows)
                obj.ChangeRows={table(emptyColumn,emptyColumn,emptyColumn,emptyColumn,VariableNames=obj.ChangeColumns)};
            end
            obj=obj.flush();
        end
    end
    methods (Access=private)
        function obj = closeInterval(obj,t)
            assert(t>=obj.LastTime-1e-9,"v2xsim:resource:UsageTime","Observer time moved backwards.");
            if t<=obj.LastTime, return; end
            if ~isempty(obj.Assignments)
                ids=obj.Assignments.UeId;
                positions=nan(numel(ids),2);
                if ~isempty(obj.Kinematics)
                    [known,index]=ismember(ids,string(obj.Kinematics.Properties.RowNames));
                    positions(known,:)=obj.Kinematics{index(known),["X","Y"]};
                end
                [values,occupancy]=v2xsim.resource.metrics.resourceUsage( ...
                    obj.Assignments.ResourceIds,obj.Pressure.ResourceMask,positions);
                row=[table(obj.LastTime,t,VariableNames=["StartSeconds","EndSeconds"]),struct2table(values)];
                obj.Rows{end+1}=row;
                [users,~,group]=unique(occupancy);
                counts=accumarray(group,1);
                obj.DistributionRows{end+1}=table( ...
                    repmat(obj.LastTime,numel(users),1),repmat(t,numel(users),1),users,counts, ...
                    VariableNames=["StartSeconds","EndSeconds","Users","ResourceCount"]);
            end
            obj.LastTime=t;
        end
        function obj = recordTransmission(obj,event)
            if event.Technology=="11p", return; end
            tx=event.Transmitters;
            required=["AttemptNumber","ResourceId","TransmitterUeId","PacketSequence"];
            if ~all(ismember(required,string(tx.Properties.VariableNames))), return; end
            % Block-only transitions can refer to a formerly attempted packet.
            % Require a correct/error link in this invocation as on-air evidence.
            radio=ismember(string(event.Links.Outcome),["correct","error"]);
            active=ismember(tx.TransmitterId,event.Links.TransmitterId(radio)) & ...
                tx.AttemptNumber>0 & isfinite(tx.ResourceId);
            if ismember("IsOnAirObservation",string(tx.Properties.VariableNames))
                active=tx.IsOnAirObservation & tx.AttemptNumber>0 & isfinite(tx.ResourceId);
            end
            tx=tx(active,:);
            t=event.SimulationTimeSeconds;
            if t~=obj.LastTransmissionTime
                obj.LastTransmissionTime=t; obj.LastTransmissionKeys=strings(0,1);
            end
            keys=tx.TransmitterUeId+"/"+string(tx.PacketSequence)+"/"+string(tx.AttemptNumber);
            keep=~ismember(keys,obj.LastTransmissionKeys);
            tx=tx(keep,:); keys=keys(keep);
            obj.LastTransmissionKeys=[obj.LastTransmissionKeys;keys];
            if isempty(tx), return; end
            % Save one compact row per actual transmitter. Analysis groups all
            % invocations at the same TTI to capture overlap across callbacks.
            obj.TransmissionRows{end+1}=table(repmat(t,height(tx),1), ...
                tx.TransmitterUeId,tx.PacketSequence,tx.AttemptNumber,tx.ResourceId, ...
                VariableNames=obj.TransmissionColumns);
        end
        function obj = flush(obj)
            groups={obj.Rows,obj.DistributionRows,obj.TransmissionRows,obj.ChangeRows};
            names=["resource_usage","resource_occupancy","resource_transmissions","resource_changes"];
            for k=1:4
                if isempty(groups{k}), continue; end
                rows=vertcat(groups{k}{:}); filename=fullfile(obj.Directory,names(k)+".csv");
                if obj.Written(k)
                    writetable(rows,filename,WriteMode="append",WriteVariableNames=false);
                else
                    writetable(rows,filename); obj.Written(k)=true;
                end
            end
            obj.Rows={}; obj.DistributionRows={}; obj.TransmissionRows={}; obj.ChangeRows={};
        end
    end
end

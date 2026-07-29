classdef (Abstract) ScheduledCentralizedResourceAllocator < ...
        v2xsim.resource.CentralizedResourceAllocator
    %SCHEDULEDCENTRALIZEDRESOURCEALLOCATOR Periodic centralized lifecycle.

    properties (SetAccess = immutable)
        ReassignmentCycleCount (1,1) double ...
            {mustBeInteger,mustBePositive} = 1
    end

    properties (Access = private)
        Schedule table = table( ...
            strings(0,1),nan(0,1), ...
            VariableNames=["UeId","Cycle"])
    end

    methods (Access = protected)
        function value = configurationMetadata(obj)
            value = struct( ...
                "ReassignmentCycleCount", ...
                    obj.ReassignmentCycleCount);
        end

        function obj = ScheduledCentralizedResourceAllocator( ...
                grid,randomSeed,reassignmentCycleCount)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                randomSeed (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
                reassignmentCycleCount (1,1) double ...
                    {mustBeInteger,mustBePositive}
            end

            obj = obj@v2xsim.resource.CentralizedResourceAllocator( ...
                grid,randomSeed,1);
            obj.ReassignmentCycleCount = reassignmentCycleCount;
        end

        function [obj,result] = doInitialize(obj,~,~)
            result = v2xsim.resource.internal.emptyResult(obj);
        end

        function obj = doSynchronizeUes(obj,~,~)
            previous = obj.Schedule;
            [retained,locations] = ismember(obj.UeIds,previous.UeId);
            cycle = nan(numel(obj.UeIds),1);
            cycle(retained) = previous.Cycle(locations(retained));
            obj.Schedule = table( ...
                obj.UeIds,cycle,VariableNames=["UeId","Cycle"]);
        end

        function [obj,result] = doStep(obj,context,randomStream)
            allocatorRows = v2xsim.resource.internal.contextRows( ...
                obj.UeIds,context.UeIds);
            missingCycle = isnan(obj.Schedule.Cycle);
            if any(missingCycle)
                obj.Schedule.Cycle(missingCycle) = randi( ...
                    randomStream,obj.ReassignmentCycleCount, ...
                    nnz(missingCycle),1);
            end

            completedGridPeriod = ...
                mod(context.CurrentSlot + 1,obj.Grid.NumberTimeSlots) == 0;
            if ~completedGridPeriod
                result = v2xsim.resource.internal.emptyResult(obj);
                return
            end

            periodNumber = (context.CurrentSlot + 1) / ...
                obj.Grid.NumberTimeSlots;
            activeCycle = mod( ...
                periodNumber - 1,obj.ReassignmentCycleCount) + 1;
            scheduledRows = find(obj.Schedule.Cycle == activeCycle);
            resourceIdsBefore = obj.Assignments.ResourceIds;
            allocationRandomState = randomStream.State;
            [resourceIds,decisionRows] = obj.allocate( ...
                resourceIdsBefore(:,1),scheduledRows,context, ...
                allocatorRows,randomStream);
            diagnostics = obj.buildAllocationDiagnostics( ...
                resourceIdsBefore(:,1),resourceIds, ...
                scheduledRows,decisionRows,context,allocatorRows, ...
                allocationRandomState);
            result = v2xsim.resource.internal.buildResult( ...
                obj.Grid,obj.Assignments,resourceIds,decisionRows, ...
                v2xsim.resource.ResourceAllocationResult. ...
                    emptyReservations(),diagnostics);
        end

        function diagnostics = buildAllocationDiagnostics( ...
                ~,~,~,~,~,~,~,~)
            %BUILDALLOCATIONDIAGNOSTICS Optional same-state shadow output.
            diagnostics = struct();
        end
    end

    methods (Abstract, Access = protected)
        [resourceIds,decisionRows] = allocate( ...
            obj,resourceIds,scheduledRows,context, ...
            allocatorRows,randomStream)
    end
end

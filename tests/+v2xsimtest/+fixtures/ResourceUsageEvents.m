classdef ResourceUsageEvents
    %RESOURCEUSAGEEVENTS Small typed fixtures; no simulator or global state.
    methods (Static)
        function event = kinematics(time,ids,xy)
            rows = array2table([xy,zeros(numel(ids),4)], ...
                VariableNames=["X","Y","vX","vY","aX","aY"],RowNames=ids);
            event = v2xsim.hook.invocations.AfterVehicleKinematicsUpdatedInvocation(time,rows);
        end

        function event = allocation(time,ids,resources,selected,blocked)
            arguments
                time (1,1) double
                ids (:,1) string
                resources double
                selected (:,1) string = strings(0,1)
                blocked (:,1) string = strings(0,1)
            end
            slice = v2xsim.network.NetworkSliceId("global");
            context = v2xsim.resource.ResourceAllocationContext( ...
                slice,ids,round(time*1000),false(numel(ids),1),true(numel(ids),4));
            assignments = table(ids,resources,VariableNames=["UeId","ResourceIds"]);
            result = v2xsim.resource.ResourceAllocationResult(slice,assignments, ...
                selected,strings(0,1),blocked,v2xsim.resource.ResourceAllocationResult.emptyReservations());
            event = v2xsim.hook.invocations.AfterResourceAllocationDecisionInvocation(time,uint64(1),context,result);
        end

        function event = transmission(time,vehicle,sequence,attempt,resource,onAir,outcomes)
            arguments
                time (1,1) double
                vehicle (1,1) string = "alpha"
                sequence (1,1) double = 1
                attempt (1,1) double = 1
                resource (1,1) double = 4
                onAir = true
                outcomes (:,1) string = strings(0,1)
            end
            tx = table(1,vehicle,1,1,0,sequence,attempt,resource,false,onAir, ...
                VariableNames=["TransmitterId","TransmitterUeId","Channel","PacketType", ...
                "GenerationTimeSeconds","PacketSequence","AttemptNumber","ResourceId", ...
                "IsPacketComplete","IsOnAirObservation"]);
            n = numel(outcomes);
            links = table(ones(n,1),(2:n+1).',10*ones(n,1),outcomes, ...
                VariableNames=["TransmitterId","ReceiverId","DistanceMeters","Outcome"]);
            event = v2xsim.hook.invocations.AfterPacketFatesDeterminedInvocation(time,"5G",max(1,n+1),150,tx,links);
        end
    end
end

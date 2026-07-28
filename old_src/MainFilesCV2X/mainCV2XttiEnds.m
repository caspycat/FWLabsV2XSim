function [phyParams,simValues,outputValues,sinrManagement,stationManagement,timeManagement] = ...
            mainCV2XttiEnds(appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement)
% a C-V2X TTI (time transmission interval) ends

%% From version 6.2
% Check of buffer overflow
% It needs to be performed here, otherwise the case where a packet is
% geneated in a subframe during which the station is transmitting is
% not correctly managed
for idLte = stationManagement.activeIDsCV2X'   
    if stationManagement.pckBuffer(idLte)>1
        [stationManagement,outputValues] = bufferOverflowLTE(idLte,timeManagement,positionManagement,stationManagement,phyParams,appParams,outputValues,simValues,simParams.stringCV2X);
        stationManagement.pckNextAttempt(idLte) = 1;     
    end
end
%%

[simValues,stationManagement,timeManagement,sinrManagement,Nreassign] = ...
    stepResourceAllocation( ...
        simValues,stationManagement,timeManagement, ...
        positionManagement,sinrManagement,simParams,phyParams, ...
        appParams,outParams);

% Incremental sum of successfully reassigned and unlocked vehicles
outputValues.NreassignCV2X = outputValues.NreassignCV2X + Nreassign;

% A blocked outcome belongs to the allocator decision just completed. Only
% UEs with a pending packet have a packet fate to record.
blockedUeIds = ...
    simValues.resourceAllocationResult.BlockedUeIds;
[knownBlockedUes,blockedIds] = ismember( ...
    blockedUeIds,simValues.world.UeIds);
if ~all(knownBlockedUes)
    error( ...
        "v2xsim:resource:LegacyProjectionIdentityMismatch", ...
        "Blocked allocator outcomes must identify known UEs.");
end
blockedIds = blockedIds( ...
    stationManagement.pckBuffer(blockedIds) > 0);
for blockedId = reshape(blockedIds,1,[])
    [stationManagement,outputValues] = bufferOverflowLTE( ...
        blockedId,timeManagement,positionManagement, ...
        stationManagement,phyParams,appParams,outputValues, ...
        simValues,simParams.stringCV2X);
    stationManagement.pckNextAttempt(blockedId) = 1;
end

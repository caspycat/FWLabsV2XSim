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

Nreassign = 0;
if simParams.BRAlgorithm == constants.REASSIGN_BR_STD_MODE_4
    % BRs sensing procedure
    [timeManagement,stationManagement,sinrManagement] = ...
        CV2XsensingProcedure(timeManagement,stationManagement,sinrManagement,simParams,phyParams,appParams,outParams);    
    
    % BRs reassignment (3GPP MODE 4)     
    [timeManagement,stationManagement,sinrManagement,Nreassign] = ...
        BRreassignment3GPPautonomous(timeManagement,stationManagement,positionManagement,sinrManagement,simParams,phyParams,appParams,outParams);
        
% Introduced for NOMA support from version 5.6
elseif simParams.BRAlgorithm == constants.REASSIGN_BR_RAND_ALLOCATION
    
    hasNewPacketThisTbeacon = (timeManagement.timeLastPacket(stationManagement.activeIDsCV2X) > (timeManagement.timeNow-phyParams.TTI-1e-8));

    if sum(hasNewPacketThisTbeacon)>0
        % Call Benchmark Algorithm 101 (RANDOM ALLOCATION)
        BRidModified = zeros(sum(hasNewPacketThisTbeacon),phyParams.cv2xNumberOfReplicasMax);
        for j=1:phyParams.cv2xNumberOfReplicasMax
            % From v5.4.16, when HARQ is active, n random
            % resources are selected, one per each replica 
            [BRidModified(:,j),Nreassign] = BRreassignmentRandom(simParams.T1autonomousModeTTIs,simParams.T2autonomousModeTTIs,stationManagement.activeIDsCV2X(hasNewPacketThisTbeacon),simParams,timeManagement,sinrManagement,stationManagement,phyParams,appParams);
        end      
        % Must be ordered with respect to the packet generation instant
        subframeGen = mod(ceil((timeManagement.timeNow-1e-8)/phyParams.TTI)-1,appParams.NbeaconsT)+1;
        subframe_BR = ceil(BRidModified/appParams.NbeaconsF);
        BRidModified = BRidModified + (subframe_BR<=subframeGen) * appParams.Nbeacons;
        BRidModified = sort(BRidModified,2);
        BRidModified = BRidModified - (BRidModified>appParams.Nbeacons) * appParams.Nbeacons;
   
        stationManagement.BRid(stationManagement.activeIDsCV2X(hasNewPacketThisTbeacon),:) = BRidModified;
    end
    
elseif mod(timeManagement.elapsedTime_TTIs,appParams.NbeaconsT)==0
    % All other algorithms except standard Mode 4
    % TODO not checked in version 5.X
    
    %% Radio Resources Reassignment
    if simParams.BRAlgorithm==constants.REASSIGN_BR_REUSE_DIS_SCHEDULED_VEH || simParams.BRAlgorithm==constants.REASSIGN_BR_MAX_REUSE_DIS || simParams.BRAlgorithm==constants.REASSIGN_BR_MIN_REUSE_POW
        
        if timeManagement.elapsedTime_TTIs > 0
            % Current scheduled reassign period
            reassignPeriod = mod(round(timeManagement.elapsedTime_TTIs/(appParams.NbeaconsT))-1,stationManagement.NScheduledReassignLTE)+1;

            % Find IDs of vehicles whose resource will be reassigned
            scheduledID = stationManagement.activeIDsCV2X(stationManagement.scheduledReassignLTE(stationManagement.activeIDsCV2X)==reassignPeriod);
        else
            % For the first allocation, all vehicles in the scenario
            % need to be scheduled
            scheduledID = stationManagement.activeIDsCV2X;
        end
    end

    if simParams.BRAlgorithm == constants.REASSIGN_BR_REUSE_DIS_SCHEDULED_VEH

        % BRs reassignment (CONTROLLED with REUSE DISTANCE and scheduled vehicles)
        % Call function for BRs reassignment
        % Returns updated stationManagement.BRid vector and number of successful reassignments
        [stationManagement.BRid,Nreassign] = BRreassignmentControlled(stationManagement.activeIDsCV2X,scheduledID,positionManagement.distanceEstimated,stationManagement.BRid,appParams.Nbeacons,phyParams.Rreuse);

    elseif simParams.BRAlgorithm == constants.REASSIGN_BR_MAX_REUSE_DIS

        % BRs reassignment (CONTROLLED with MAXIMUM REUSE DISTANCE)
        %[stationManagement.BRid,Nreassign] = BRreassignmentControlledMaxReuse(stationManagement.activeIDsCV2X,stationManagement.BRid,scheduledID,stationManagement.neighborsIDLTE,appParams.NbeaconsT,appParams.NbeaconsF);
        [stationManagement.BRid,Nreassign] = BRreassignmentControlledMaxReuse(stationManagement.activeIDsCV2X,stationManagement.BRid,scheduledID,stationManagement.allNeighborsID,appParams.NbeaconsT,appParams.NbeaconsF);

    elseif simParams.BRAlgorithm == constants.REASSIGN_BR_MIN_REUSE_POW

        % BRs reassignment (CONTROLLED with MINIMUM POWER REUSE)
        [stationManagement.BRid,Nreassign] = BRreassignmentControlledMinPowerReuse(stationManagement.activeIDsCV2X,stationManagement.BRid,scheduledID,sinrManagement.P_RX_MHz,sinrManagement.Shadowing_dB,simParams.knownShadowing,appParams.NbeaconsT,appParams.NbeaconsF);

    elseif (simParams.BRAlgorithm==constants.REASSIGN_BR_POW_CONTROL && timeManagement.elapsedTime_TTIs == 0) || (simParams.BRAlgorithm==constants.REASSIGN_BR_MIN_REUSE_POW && timeManagement.elapsedTime_TTIs == 0)                
        % SAME CALL AS Algorithm 101 (RANDOM ALLOCATION)
        hasNewPacketThisTbeacon = (timeManagement.timeLastPacket(stationManagement.activeIDsCV2X) > (timeManagement.timeNow-phyParams.TTI-1e-8));

        if sum(hasNewPacketThisTbeacon)>0
            % Call Benchmark Algorithm 101 (RANDOM ALLOCATION)
            BRidModified = zeros(sum(hasNewPacketThisTbeacon),phyParams.cv2xNumberOfReplicasMax);
            for j=1:phyParams.cv2xNumberOfReplicasMax
                % From v5.4.16, when HARQ is active, n random
                % resources are selected, one per each replica 
                [BRidModified(:,j),Nreassign] = BRreassignmentRandom(simParams.T1autonomousModeTTIs,simParams.T2autonomousModeTTIsstationManagement.activeIDsCV2X(hasNewPacketThisTbeacon),simParams,timeManagement,sinrManagement,stationManagement,phyParams,appParams);
            end      
            % Must be ordered with respect to the packet generation instant
            %subframeGen = ceil(timeManagement.timeNextPacket(hasNewPacketThisTbeacon)/phyParams.TTI);
            subframeGen = mod(ceil(timeManagement.timeNow/phyParams.TTI)-1,appParams.NbeaconsT)+1;
            subframe_BR = ceil(BRidModified/appParams.NbeaconsF);
            BRidModified = BRidModified + (subframe_BR<=subframeGen) * appParams.Nbeacons;
            BRidModified = sort(BRidModified,2);
            BRidModified = BRidModified - (BRidModified>appParams.Nbeacons) * appParams.Nbeacons;
       
            stationManagement.BRid(stationManagement.activeIDsCV2X(hasNewPacketThisTbeacon),:) = BRidModified;
        end
    
        
    elseif simParams.BRAlgorithm==constants.REASSIGN_BR_ORDERED_ALLOCATION

        % Call Benchmark Algorithm 102 (ORDERED ALLOCATION)
        [stationManagement.BRid,Nreassign] = BRreassignmentOrdered(positionManagement.XvehicleReal,stationManagement.activeIDsCV2X,stationManagement.BRid,appParams.NbeaconsT,appParams.NbeaconsF);

    end

end

if simParams.BRAlgorithm == constants.REASSIGN_BR_STD_MODE_4 && ~isfield(sinrManagement,'sensedPowerByLteNo11p')
    sinrManagement.sensedPowerByLteNo11p = [];
end

% Incremental sum of successfully reassigned and unlocked vehicles
outputValues.NreassignCV2X = outputValues.NreassignCV2X + Nreassign;

% Update KPIs for blocked vehicles
blockedPositions = find( ...
    stationManagement.BRid( ...
        stationManagement.transmittingIDsCV2X,1)==-1);
blockedIds = stationManagement.transmittingIDsCV2X(blockedPositions);
Nblocked = length(blockedIds);
for iBlocked = 1:Nblocked
    blockedId = blockedIds(iBlocked);
    pckType = stationManagement.pckType(blockedId);
    iChannel = stationManagement.vehicleChannel(blockedId);
    for iPhyRaw=1:length(phyParams.Raw)
        % Count as a blocked transmission (previous packet is discarded)
        outputValues.NblockedCV2X(iChannel,pckType,iPhyRaw) = outputValues.NblockedCV2X(iChannel,pckType,iPhyRaw) + nnz(positionManagement.distanceReal(blockedId,stationManagement.activeIDsCV2X) < phyParams.Raw(iPhyRaw)) - 1; % -1 to remove self
        outputValues.NblockedTOT(iChannel,pckType,iPhyRaw) = outputValues.NblockedTOT(iChannel,pckType,iPhyRaw) + nnz(positionManagement.distanceReal(blockedId,stationManagement.activeIDsCV2X) < phyParams.Raw(iPhyRaw)) - 1; % -1 to remove self
    end
    candidateReceiverIds = stationManagement.activeIDsCV2X(:).';
    candidateReceiverIds( ...
        candidateReceiverIds==blockedId) = 0;
    dispatchAfterPacketFatesDetermined( ...
        simValues,timeManagement.timeNow,simParams.stringCV2X, ...
        phyParams.Raw,stationManagement,positionManagement, ...
        blockedId, ...
        max(0,timeManagement.timeLastPacket(blockedId)), ...
        candidateReceiverIds,zeros(0,2),zeros(0,2),"blocked");
end

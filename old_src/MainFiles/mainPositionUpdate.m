function [appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement] = ...
    mainPositionUpdate(appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement)
% Step the physical World. Traffic updates vehicles; fixed RSUs remain
% unchanged, and named UE identities are projected to dense legacy slots.
[indexNewVehicles,indexOldVehicles,indexOldVehiclesToOld, ...
    stationManagement.activeIDsExit,positionManagement,simValues] = ...
    updatePosition( ...
        timeManagement.timeNow,stationManagement.activeIDs, ...
        simParams.positionTimeResolution,positionManagement,simValues, ...
        outParams,simParams);

% Vectors IDvehicleLTE and IDvehicle11p are updated
stationManagement.activeIDsCV2X = stationManagement.activeIDs.*(stationManagement.vehicleState(stationManagement.activeIDs)==100);
stationManagement.activeIDsCV2X = stationManagement.activeIDsCV2X(stationManagement.activeIDsCV2X>0);
stationManagement.activeIDs11p = stationManagement.activeIDs.*(stationManagement.vehicleState(stationManagement.activeIDs)~=100);
stationManagement.activeIDs11p = stationManagement.activeIDs11p(stationManagement.activeIDs11p>0);
stationManagement.indexInActiveIDs_ofLTEnodes = zeros(length(stationManagement.activeIDsCV2X),1);
for i=1:length(stationManagement.activeIDsCV2X)
    stationManagement.indexInActiveIDs_ofLTEnodes(i) = find(stationManagement.activeIDs==stationManagement.activeIDsCV2X(i));
end
stationManagement.indexInActiveIDs_of11pnodes = zeros(length(stationManagement.activeIDs11p),1);
for i=1:length(stationManagement.activeIDs11p)
    stationManagement.indexInActiveIDs_of11pnodes(i) = find(stationManagement.activeIDs==stationManagement.activeIDs11p(i));
end

% % For possible DEBUG
% figure(300)
% plot(timeManagement.timeNextPosUpdate*100*ones(1,length(positionManagement.XvehicleReal)),positionManagement.XvehicleReal,'*');
% hold on

% Update variables for resource allocation in LTE-V2V
%if simParams.technology ~= 2 % not only 11p
if sum(stationManagement.vehicleState(stationManagement.activeIDs)==100)>0
    
    % if simParams.BRAlgorithm==18 && timeManagement.timeNow > phyParams.Tsf (Vittorio 5.5.3)
    if simParams.BRAlgorithm==constants.REASSIGN_BR_STD_MODE_4 && timeManagement.timeNow > phyParams.TTI
        % First random allocation 
        if ~isempty(indexNewVehicles)
            %[stationManagement.BRid,~] = BRreassignmentRandom(simValues.IDvehicle,stationManagement.BRid,simParams,sinrManagement,appParams);
            [stationManagement.BRid(stationManagement.activeIDs(indexNewVehicles),1),~] = BRreassignmentRandom(simParams.T1autonomousModeTTIs,simParams.T2autonomousModeTTIs,stationManagement.activeIDs(indexNewVehicles),simParams,timeManagement,sinrManagement,stationManagement,phyParams,appParams);
            if simParams.technology==constants.TECH_COEX_STD_INTERF && ismember(simParams.coexMethod, [constants.COEX_METHOD_A, constants.COEX_METHOD_B, constants.COEX_METHOD_F])
                timeManagement.coex_timeNextSuperframe(stationManagement.activeIDs(indexNewVehicles)) = timeManagement.timeNow + ...
                    (simParams.coex_knownEndOfLTE(stationManagement.activeIDs(indexNewVehicles)) + simParams.coex_guardTimeAfter) * ones(length(stationManagement.activeIDs(indexNewVehicles)),1);
                timeManagement.coex_timeNextSuperframe(stationManagement.activeIDs(indexNewVehicles)) = timeManagement.coex_timeNextSuperframe(stationManagement.activeIDs(indexNewVehicles)) +...
                    ( rand(length(stationManagement.activeIDs(indexNewVehicles)),1) * (2*simParams.coexA_desynchError) - simParams.coexA_desynchError);
            end
        end
        % Update stationManagement.resReselectionCounterCV2X for vehicles exiting the scenario
        stationManagement.resReselectionCounterCV2X(stationManagement.activeIDsExit) = Inf;
        % Update stationManagement.resReselectionCounterCV2X for vehicles entering the scenario
        % a) LTE vehicles that enter or are blocked start with a counter set to 0
        % b) 11p vehicles are set to Inf
        stationManagement.resReselectionCounterCV2X((stationManagement.BRid(:,1)==-1) & (stationManagement.vehicleState==constants.V_STATE_LTE_TXRX)) = 0;
        stationManagement.resReselectionCounterCV2X((stationManagement.BRid(:,1)==-1) & (stationManagement.vehicleState~=constants.V_STATE_LTE_TXRX)) = Inf;
        % Reset stationManagement.errorSCImatrixLTE for new computation of correctly received SCIs
        %stationManagement.correctSCImatrixCV2X = zeros(length(stationManagement.activeIDsCV2X),length(stationManagement.activeIDsCV2X)-1);
    end
    
    % Add LTE positioning delay (if selected)
    [simValues.XvehicleEstimatedLegacy, ...
        simValues.YvehicleEstimatedLegacy,PosUpdateIndex] = ...
        addPosDelay( ...
            simValues.XvehicleEstimatedLegacy, ...
            simValues.YvehicleEstimatedLegacy, ...
            positionManagement.XvehicleReal, ...
            positionManagement.YvehicleReal, ...
            stationManagement.activeIDs,indexNewVehicles, ...
            indexOldVehicles,indexOldVehiclesToOld, ...
            positionManagement.posUpdateAllVehicles, ...
            simParams.positionTimeResolution);

    [hasVehicleId,vehicleUeIndices] = ismember( ...
        simValues.world.VehicleIds,simValues.world.UeIds);
    if ~all(hasVehicleId)
        error('v2xsim:legacy:InvalidWorldIdentity', ...
            'Every World.VehicleId must occur in World.UeIds.');
    end
    vehiclePositionUpdateIndices = intersect( ...
        PosUpdateIndex,vehicleUeIndices,'stable');

    % Add LTE positioning error only to mobile vehicles. Fixed RSUs retain
    % their configured World positions.
    [simValues.XvehicleEstimatedLegacy( ...
            vehiclePositionUpdateIndices), ...
        simValues.YvehicleEstimatedLegacy( ...
            vehiclePositionUpdateIndices)] = ...
        addPosError( ...
            positionManagement.XvehicleReal( ...
                vehiclePositionUpdateIndices), ...
            positionManagement.YvehicleReal( ...
                vehiclePositionUpdateIndices), ...
            simParams.sigmaPosError);
else
    simValues.XvehicleEstimatedLegacy = ...
        positionManagement.XvehicleReal;
    simValues.YvehicleEstimatedLegacy = ...
        positionManagement.YvehicleReal;
end

simValues.XvehicleEstimated = simValues.XvehicleEstimatedLegacy;
simValues.YvehicleEstimated = simValues.YvehicleEstimatedLegacy;
simValues = applyPositionErrorChain( ...
    simParams,simValues,timeManagement.timeNow);

% Call function to compute the distances
[positionManagement,stationManagement] = computeDistance (simParams,simValues,stationManagement,positionManagement);

% Call function to update positionManagement.distance matrix where D(i,j) is the
% change in positionManagement.distance of link i to j from time n-1 to time n and used
% for updating Shadowing matrix
[dUpdate,sinrManagement.Shadowing_dB,positionManagement.distanceRealOld] = updateDistanceChangeForShadowing(positionManagement.distanceReal,positionManagement.distanceRealOld,indexOldVehicles,indexOldVehiclesToOld,sinrManagement.Shadowing_dB,phyParams.stdDevShadowLOS_dB);

% Calculation of channel and then received power
[sinrManagement,simValues.Xmap,simValues.Ymap,phyParams.LOS] = computeChannelGain(sinrManagement,stationManagement,positionManagement,phyParams,simParams,dUpdate);

% Update of the neighbors
[positionManagement,stationManagement] = computeNeighbors (stationManagement,positionManagement,phyParams);

% Number of UEs in the world
outputValues.NUEs = length(stationManagement.activeIDs);
outputValues.NUEsTOT = outputValues.NUEsTOT + outputValues.NUEs;
outputValues.NUEsCV2X = outputValues.NUEsCV2X + ...
    length(stationManagement.activeIDsCV2X);
outputValues.NUEs11p = outputValues.NUEs11p + ...
    length(stationManagement.activeIDs11p);

% Number of neighbors
[outputValues,~,NneighborsRawLTE,NneighborsRaw11p] = updateAverageNeighbors(simParams,stationManagement,outputValues,phyParams);

% Print number of neighbors per UE to file (if enabled)
if outParams.printNeighbors
    printNeighborsToFile(timeManagement.timeNow,positionManagement, ...
        outputValues.NUEs, ...
        NneighborsRawLTE/length(stationManagement.activeIDsCV2X), ...
        NneighborsRaw11p/length(stationManagement.activeIDs11p), ...
        outParams,phyParams);
end

% Prepare matrix for update delay computation (if enabled)
if outParams.printUpdateDelay
    % Reset update time of vehicles that are outside the scenario
    allIDOut = setdiff(1:simValues.maxID,stationManagement.activeIDs);
    simValues.updateTimeMatrix11p(allIDOut,:,:) = -1;
    simValues.updateTimeMatrix11p(:,allIDOut,:) = -1;
    simValues.updateTimeMatrixCV2X(allIDOut,:,:) = -1;
    simValues.updateTimeMatrixCV2X(:,allIDOut,:) = -1;
end

% Prepare matrix for update delay computation (if enabled)
if outParams.printDataAge
    % Reset update time of vehicles that are outside the scenario
    allIDOut = setdiff(1:simValues.maxID,stationManagement.activeIDs);
    simValues.dataAgeTimestampMatrix11p(allIDOut,:,:) = -1;
    simValues.dataAgeTimestampMatrix11p(:,allIDOut,:) = -1;
    simValues.dataAgeTimestampMatrixCV2X(allIDOut,:,:) = -1;
    simValues.dataAgeTimestampMatrixCV2X(:,allIDOut,:) = -1;
end

% Compute wireless blind spot probability (if enabled - update delay is required)
% The WBSP is calculated at every position update
if outParams.printUpdateDelay && outParams.printWirelessBlindSpotProb
%     %error('Not updated in v. 5.X');
%     %% TODO with coexistence
%     if simParams.technology~=1 && simParams.technology~=2
%         error('Not implemented');
%     end
%     if simParams.technology==2 || elapsedTime_subframes>appParams.NbeaconsT
%         if simParams.technology==1
%             outputValues.wirelessBlindSpotCounter = countWirelessBlindSpotProb(simValues.updateTimeMatrixCV2X,outputValues.wirelessBlindSpotCounter,timeManagement.timeNow);
%         else
%             outputValues.wirelessBlindSpotCounter = countWirelessBlindSpotProb(simValues.updateTimeMatrix11p,outputValues.wirelessBlindSpotCounter,timeManagement.timeNow);
%         end
%     end       
    if ~isempty(stationManagement.activeIDsCV2X)
        for iRaw = 1:length(phyParams.Raw)
            valuesEnteredInRange = outputValues.enteredInRangeLTE(:,:,iRaw);
            valuesEnteredInRange(stationManagement.activeIDsCV2X,stationManagement.activeIDsCV2X) = (valuesEnteredInRange(stationManagement.activeIDsCV2X,stationManagement.activeIDsCV2X)<0 & positionManagement.distanceReal(stationManagement.activeIDsCV2X,stationManagement.activeIDsCV2X)<=phyParams.Raw(iRaw))*(1+timeManagement.timeNow)-1;
            valuesEnteredInRange( positionManagement.distanceReal > phyParams.Raw(iRaw) ) = -1;
            outputValues.enteredInRangeLTE(:,:,iRaw) = valuesEnteredInRange - (diag(diag(valuesEnteredInRange+1)));
        end
    	outputValues.wirelessBlindSpotCounterCV2X = countWirelessBlindSpotProb(simValues.updateTimeMatrixCV2X,outputValues.enteredInRangeLTE,outputValues.wirelessBlindSpotCounterCV2X,timeManagement.timeNow,phyParams);
    end
    if ~isempty(stationManagement.activeIDs11p)
        for iRaw = 1:length(phyParams.Raw)
            valuesEnteredInRange = outputValues.enteredInRange11p(:,:,iRaw);
            valuesEnteredInRange(stationManagement.activeIDs11p,stationManagement.activeIDs11p) = (valuesEnteredInRange(stationManagement.activeIDs11p,stationManagement.activeIDs11p)<0 & positionManagement.distanceReal(stationManagement.activeIDs11p,stationManagement.activeIDs11p)<=phyParams.Raw(iRaw))*(1+timeManagement.timeNow)-1;
            valuesEnteredInRange( positionManagement.distanceReal > phyParams.Raw(iRaw) ) = -1;
            outputValues.enteredInRange11p(:,:,iRaw) = valuesEnteredInRange - (diag(diag(valuesEnteredInRange+1)));
        end
    	outputValues.wirelessBlindSpotCounter11p = countWirelessBlindSpotProb(simValues.updateTimeMatrix11p,outputValues.enteredInRange11p,outputValues.wirelessBlindSpotCounter11p,timeManagement.timeNow,phyParams);
    end
end

% Update of parameters related to transmissions in IEEE 802.11p to cope
% with vehicles exiting the scenario
%if simParams.technology ~= 1 % not only LTE
if sum(stationManagement.vehicleState(stationManagement.activeIDs)~=100)>0    
    
    timeManagement.timeNextTxRx11p(stationManagement.activeIDsExit) = Inf;
    sinrManagement.idFromWhichRx11p(stationManagement.activeIDsExit) = stationManagement.activeIDsExit;
    sinrManagement.instantThisSINRavStarted11p(stationManagement.activeIDsExit) = Inf;
    stationManagement.vehicleState(stationManagement.activeIDsExit(stationManagement.vehicleState(stationManagement.activeIDsExit)~=100)) =  1;
    
    % The average SINR of all vehicles is then updated
    sinrManagement = updateSINR11p(timeManagement,sinrManagement,stationManagement,phyParams);

    % The nodes that may stop receiving must be checked
    [timeManagement,stationManagement,sinrManagement,outputValues] = checkVehiclesStopReceiving11p(timeManagement,stationManagement,sinrManagement,simParams,phyParams,outParams,outputValues);

    % The present overall/useful power received and the instant of calculation are updated
    % The power received must be calculated after
    % 'checkVehiclesStopReceiving11p', to have the correct idFromWhichtransmitting
    [sinrManagement] = updateLastPower11p(timeManagement,stationManagement,sinrManagement,phyParams,simValues);       
end

% Generate time values of new vehicles entering the scenario
timeManagement.timeNextPacket(stationManagement.activeIDs(indexNewVehicles)) = round(timeManagement.timeNow + appParams.allocationPeriod * rand(1,length(indexNewVehicles)), 10);
if appParams.variabilityGenerationInterval == constants.PACKET_GENERATION_ETSI_CAM
    timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDs(indexNewVehicles)) = generationPeriodFromSpeed(positionManagement.v(indexNewVehicles),appParams);
else
    timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDs(indexNewVehicles)) = appParams.generationInterval - appParams.variabilityGenerationInterval/2 + appParams.variabilityGenerationInterval*rand(length(indexNewVehicles),1);
    timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDsCV2X) = appParams.generationInterval;
end
% timeManagement.timeOfResourceAllocationLTE is for possible use in the future
%timeManagement.timeOfResourceAllocationLTE(stationManagement.activeIDs(indexNewVehicles)) = timeManagement.timeNextPacket(stationManagement.activeIDs(indexNewVehicles));
%timeManagement.timeOfResourceAllocationLTE(stationManagement.activeIDs11p) = -1;

% Reset time next packet and tx-rx for vehicles that exit the scenario
timeManagement.timeNextPacket(stationManagement.activeIDsExit) = Inf;

% Reset time next packet and tx-rx for vehicles that exit the scenario
stationManagement.pckBuffer(stationManagement.activeIDsExit) = 0;
stationManagement.pckReceived(:,stationManagement.activeIDsExit) = 0;
sinrManagement.cumulativeSINR(:,stationManagement.activeIDsExit) = 0;
stationManagement.preambleAlreadyDetected(:,stationManagement.activeIDsExit) = 0;
stationManagement.alreadyStartCBR(:,stationManagement.activeIDsExit) = 0;

stationManagement.pckNextAttempt(stationManagement.activeIDsExit) = 1;
stationManagement.pckTxOccurring(stationManagement.activeIDsExit) = 0;

%% CBR settings for the new vehicles
if simParams.cbrActive && (outParams.printCBR || (simParams.technology==constants.TECH_COEX_STD_INTERF && simParams.coexMethod~=constants.COEX_METHOD_NON && simParams.coex_slotManagement==constants.COEX_SLOT_DYNAMIC))
    timeManagement.cbr11p_timeStartMeasInterval(stationManagement.activeIDs(indexNewVehicles)) = timeManagement.timeNow;
    if simParams.technology==constants.TECH_COEX_STD_INTERF && simParams.coexMethod==constants.COEX_METHOD_A    
        timeManagement.cbr11p_timeStartBusy(stationManagement.activeIDs(indexNewVehicles) .* timeManagement.coex_superframeThisIsLTEPart(stationManagement.activeIDs(indexNewVehicles))) = timeManagement.timeNow;
    end
end

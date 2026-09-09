function [simValues,outputValues,sinrManagement,stationManagement] = updateKPI11p(idEvent,indexEvent,timeManagement,stationManagement,positionManagement,sinrManagement,~,phyParams,simValues,outputValues)
% KPIs: correct transmissions and errors are counted

% The message is correctly received if:
% 1) the node is currently receiving
% 2) the node is receiving from idEvent
% 3) the average SINR is above the threshold
% Values are counted within a circle of radius raw

%% printDebugKPI
% if ~isfile(filename)
%     fid = fopen(filename,'w');
%     fprintf(fid,'Time\tEvent\tdistance\tVehicle\treplication_times\tKPI_earlier\tKPI_now\n');
% 
% else
%     fid = fopen(filename,'a');
% end
%% printDebugKPI

indexEvent11p = find(stationManagement.activeIDs11p == idEvent);

IDvehicle11p = stationManagement.activeIDs11p;
indexVehicle11p = stationManagement.indexInActiveIDs_of11pnodes;

% Note: I need to work with line vectors, otherwise it works differently when
% sinrVector11p is a vector and when sinrVector11p is a scalar

sinrThr = phyParams.LOS(indexVehicle11p,indexEvent)'.*phyParams.sinrVector11p_LOS(randi(length(phyParams.sinrVector11p_LOS),1,length(indexVehicle11p)))+...
(1-phyParams.LOS(indexVehicle11p,indexEvent)').*(phyParams.sinrVector11p_NLOS(randi(length(phyParams.sinrVector11p_NLOS),1,length(indexVehicle11p))));

% Update of cumulativeSINR, to account for possible Maximal Ratio Combining

sinrManagement.cumulativeSINR(IDvehicle11p, idEvent) =...
    stationManagement.preambleAlreadyDetected(IDvehicle11p, idEvent).*(sinrManagement.cumulativeSINR(IDvehicle11p, idEvent)+sinrManagement.sinrAverage11p(IDvehicle11p));
% preamble not detected condition
totalSINR = sinrManagement.cumulativeSINR(IDvehicle11p, idEvent) +...
    (1-stationManagement.preambleAlreadyDetected(IDvehicle11p, idEvent)).*sinrManagement.sinrAverage11p(IDvehicle11p);

% Rx OK for all of the vehicles
% earlier - from this packet was first transmitted to the last time
% thisTime - during this packet is transmitted this time
% now - including all of the history of this packet
rxOK_earlier = stationManagement.pckReceived(IDvehicle11p, idEvent);
rxOK_thisTime = (stationManagement.vehicleState(IDvehicle11p)==constants.V_STATE_11P_RX) .* (sinrManagement.idFromWhichRx11p(IDvehicle11p)==idEvent)...
    .* (totalSINR >= sinrThr');
rxOK_now = rxOK_earlier | rxOK_thisTime;

% From version 5.3.1, multiple channels may be present
sameChannel = (stationManagement.vehicleChannel==stationManagement.vehicleChannel(idEvent));

fateCandidateReceiverIds = ...
    stationManagement.neighborsID11p(indexEvent11p,:);
isCandidateOnSameChannel = false(size(fateCandidateReceiverIds));
isCandidate = fateCandidateReceiverIds>0;
isCandidateOnSameChannel(isCandidate) = ...
    sameChannel(fateCandidateReceiverIds(isCandidate));
fateCandidateReceiverIds = fateCandidateReceiverIds( ...
    isCandidateOnSameChannel);
newCorrectReceiverIds = intersect( ...
    IDvehicle11p( ...
        ~logical(rxOK_earlier) & logical(rxOK_thisTime)), ...
    fateCandidateReceiverIds,"stable");
correctPairs = [ ...
    repmat(idEvent,numel(newCorrectReceiverIds),1), ...
    newCorrectReceiverIds(:)];
errorPairs = zeros(0,2);
if stationManagement.pckTxOccurring(idEvent) >= ...
        stationManagement.ITSNumberOfReplicas(idEvent)
    errorReceiverIds = intersect( ...
        IDvehicle11p(~logical(rxOK_now)), ...
        fateCandidateReceiverIds,"stable");
    errorPairs = [ ...
        repmat(idEvent,numel(errorReceiverIds),1), ...
        errorReceiverIds(:)];
end
candidateReceiverIds = stationManagement.activeIDs11p(:).';
candidateReceiverIds(candidateReceiverIds==idEvent) = 0;
dispatchAfterPacketFatesDetermined( ...
    simValues,timeManagement.timeNow,"11p",phyParams.Raw, ...
    stationManagement,positionManagement,idEvent, ...
    stationManagement.packetBuffers{idEvent}.head().GenerationTimeSeconds,candidateReceiverIds, ...
    correctPairs,errorPairs,"none");

pckType = stationManagement.pckType(idEvent);
iChannel = stationManagement.vehicleChannel(idEvent);
% Count the same first-success and final-error observations sent to hooks.
% Provisional failures during repetitions are not terminal errors: a later
% copy may succeed, the packet may be evicted, or the simulation may end.
% Committing them here previously inflated summaries for unfinished packets.
correctDistances = positionManagement.distanceReal(idEvent,correctPairs(:,2));
errorDistances = positionManagement.distanceReal(idEvent,errorPairs(:,2));
for rangeIndex = 1:numel(phyParams.Raw)
    correctCount = nnz(correctDistances < phyParams.Raw(rangeIndex));
    errorCount = nnz(errorDistances < phyParams.Raw(rangeIndex));
    for suffix = ["11p","TOT"]
        name = "NcorrectlyTxBeacons" + suffix;
        outputValues.(name)(iChannel,pckType,rangeIndex) = ...
            outputValues.(name)(iChannel,pckType,rangeIndex) + correctCount;
        name = "Nerrors" + suffix;
        outputValues.(name)(iChannel,pckType,rangeIndex) = ...
            outputValues.(name)(iChannel,pckType,rangeIndex) + errorCount;
        name = "NtxBeacons" + suffix;
        outputValues.(name)(iChannel,pckType,rangeIndex) = ...
            outputValues.(name)(iChannel,pckType,rangeIndex) + correctCount + errorCount;
    end
end
% update packet Rx OK
stationManagement.pckReceived(IDvehicle11p, idEvent) =...
    stationManagement.pckReceived(IDvehicle11p, idEvent) | rxOK_thisTime;
%% printDebugKPI
% fclose(fid);
%% printDebugKPI
end

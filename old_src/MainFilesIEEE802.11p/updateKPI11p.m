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
rxOK_earlier = stationManagement.pckReceived(indexVehicle11p, idEvent);
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
    timeManagement.timeLastPacket(idEvent),candidateReceiverIds, ...
    correctPairs,errorPairs,"none");

pckType = stationManagement.pckType(idEvent);
iChannel = stationManagement.vehicleChannel(idEvent);

for iPhyRaw = 1:length(phyParams.Raw)
    awarenessID11p = stationManagement.awarenessID11p(indexEvent11p,:,iPhyRaw)';
    
    % Vehicles' ID inside Raw
    IDIn_thisTime = awarenessID11p(awarenessID11p~=0) .* sameChannel(awarenessID11p(awarenessID11p~=0));
    
    % Index of activeIDs11p in the range of Raw:
    % earlier - from this packet was first transmitted to the last time
    % thisTime - during this packet is transmitted this time
    % now - including all of the history of this packet
    indexInRaw_earlier = stationManagement.indexInRaw_earler(:, idEvent, iPhyRaw);
    indexInRaw_thisTime = ismember(IDvehicle11p,IDIn_thisTime);
    indexInRaw_now = indexInRaw_thisTime | indexInRaw_earlier;
    
    % Rx OK of "earlier", "this time" and "till now"
    rxOKRaw_earlier = indexInRaw_earlier & stationManagement.pckReceived(indexVehicle11p, idEvent);
    rxOKRaw_thisTime = indexInRaw_thisTime & rxOK_thisTime;
    rxOKRaw_now = rxOKRaw_thisTime | rxOKRaw_earlier;
    % number of neighbors in history
    NneighborsRaw_earlier = nnz(indexInRaw_earlier);
    % number of neighbors now (includes history)
    NneighborsRaw_now = nnz(indexInRaw_now);
    NcorrectlyTxBeacons_earlier = nnz(rxOKRaw_earlier);
    NcorrectlyTxBeacons_now = nnz(rxOKRaw_now);
    % printDebugKPI(fid,timeManagement.timeNow,'NcorrTxBeacon',phyParams.Raw(iPhyRaw),idEvent,stationManagement.pckTxOccurring(idEvent), NcorrectlyTxBeacons_earlier,NcorrectlyTxBeacons_now);
    
    outputValues.NcorrectlyTxBeacons11p(iChannel,pckType,iPhyRaw) =...
        outputValues.NcorrectlyTxBeacons11p(iChannel,pckType,iPhyRaw) -...
        NcorrectlyTxBeacons_earlier +...
        NcorrectlyTxBeacons_now;
    outputValues.NcorrectlyTxBeaconsTOT(iChannel,pckType,iPhyRaw) =...
        outputValues.NcorrectlyTxBeaconsTOT(iChannel,pckType,iPhyRaw) -...
        NcorrectlyTxBeacons_earlier +...
        NcorrectlyTxBeacons_now;

    % Number of errors
    Nerrors_earlier = NneighborsRaw_earlier - NcorrectlyTxBeacons_earlier;
    Nerrors_now = NneighborsRaw_now - NcorrectlyTxBeacons_now;
    % printDebugKPI(fid,timeManagement.timeNow,'Nerrs_Raw',phyParams.Raw(iPhyRaw),idEvent,stationManagement.pckTxOccurring(idEvent), Nerrors_earlier,Nerrors_now);
    
    outputValues.Nerrors11p(iChannel,pckType,iPhyRaw) =...
        outputValues.Nerrors11p(iChannel,pckType,iPhyRaw) -...
        Nerrors_earlier + Nerrors_now;
    outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) =...
        outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) -...
        Nerrors_earlier + Nerrors_now;

    % Number of received beacons (correct + errors == neighbors)
    outputValues.NtxBeacons11p(iChannel,pckType,iPhyRaw) =...
        outputValues.NtxBeacons11p(iChannel,pckType,iPhyRaw) -...
        NneighborsRaw_earlier + NneighborsRaw_now;
    % printDebugKPI(fid,timeManagement.timeNow,'NtxBeacons11p',phyParams.Raw(iPhyRaw),idEvent,stationManagement.pckTxOccurring(idEvent), -1,outputValues.NtxBeacons11p(iChannel,pckType,iPhyRaw));

    outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) =...
        outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) -...
        NneighborsRaw_earlier + NneighborsRaw_now;
    % printDebugKPI(fid,timeManagement.timeNow,'NtxBeaconsTOT',phyParams.Raw(iPhyRaw),idEvent,stationManagement.pckTxOccurring(idEvent), -1,outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw));

    % update index of activeIDs11p in the range of Raw earlier (during one packet
    % and it's retransmission)
    stationManagement.indexInRaw_earler(:, idEvent, iPhyRaw) = indexInRaw_now;
end
% update packet Rx OK
stationManagement.pckReceived(indexVehicle11p, idEvent) =...
    stationManagement.pckReceived(indexVehicle11p, idEvent) | rxOK_thisTime;
%% printDebugKPI
% fclose(fid);
%% printDebugKPI
end

function [stationManagement,outputValues] = bufferOverflowLTE(idOverflow,timeManagement,positionManagement,stationManagement,phyParams,~,outputValues,simValues,technology)

pckType = stationManagement.pckType(idOverflow);
iChannel = stationManagement.vehicleChannel(idOverflow);

%if (stationManagement.cv2xNumberOfReplicas(idOverflow) - stationManagement.pckRemainingTx(idOverflow)) > 0
if stationManagement.pckNextAttempt(idOverflow) > 1 % means that one attempt was made
    notYetReceived = stationManagement.activeIDsCV2X(stationManagement.pckReceived(stationManagement.activeIDsCV2X,idOverflow)<=0);
end


for iPhyRaw=1:length(phyParams.Raw)
    % from v 5.4.15, retransmissions are possible - thus packets are
    % discarded if this is the first transmission, otherwise is an error
    %if (stationManagement.cv2xNumberOfReplicas(idOverflow) - stationManagement.pckRemainingTx(idOverflow)) > 0
    if stationManagement.pckNextAttempt(idOverflow) > 1 
        % Count as an error if not already received
         NtxBeacons = nnz(positionManagement.distanceReal(idOverflow,notYetReceived) < phyParams.Raw(iPhyRaw)) - 1; % -1 to remove self
         outputValues.NerrorsCV2X(iChannel,pckType,iPhyRaw) = outputValues.NerrorsCV2X(iChannel,pckType,iPhyRaw) + NtxBeacons;
         outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) = outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) + NtxBeacons;
         outputValues.NtxBeaconsCV2X(iChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsCV2X(iChannel,pckType,iPhyRaw) + NtxBeacons;
         outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) + NtxBeacons;
    else    
        % Count as a blocked transmission (previous packet is discarded without any attempt)
        outputValues.NblockedCV2X(iChannel,pckType,iPhyRaw) = outputValues.NblockedCV2X(iChannel,pckType,iPhyRaw) + nnz(positionManagement.distanceReal(idOverflow,stationManagement.activeIDsCV2X) < phyParams.Raw(iPhyRaw)) - 1; % -1 to remove self
        outputValues.NblockedTOT(iChannel,pckType,iPhyRaw) = outputValues.NblockedTOT(iChannel,pckType,iPhyRaw) + nnz(positionManagement.distanceReal(idOverflow,stationManagement.activeIDsCV2X) < phyParams.Raw(iPhyRaw)) - 1;
    end
end
candidateReceiverIds = stationManagement.activeIDsCV2X(:).';
candidateReceiverIds(candidateReceiverIds==idOverflow) = 0;
errorPairs = zeros(0,2);
if stationManagement.pckNextAttempt(idOverflow) > 1
    errorReceiverIds = notYetReceived( ...
        notYetReceived~=idOverflow);
    errorPairs = [ ...
        repmat(idOverflow,numel(errorReceiverIds),1), ...
        errorReceiverIds(:)];
    defaultOutcome = "none";
    generationTime = ...
        timeManagement.timeGeneratedPacketInTxLTE(idOverflow);
    if generationTime < 0
        generationTime = timeManagement.timeLastPacket(idOverflow);
    end
else
    defaultOutcome = "blocked";
    generationTime = timeManagement.timeLastPacket(idOverflow);
end
dispatchAfterPacketFatesDetermined( ...
    simValues,timeManagement.timeNow,technology, ...
    phyParams.Raw,stationManagement,positionManagement,idOverflow, ...
    max(0,generationTime),candidateReceiverIds, ...
    zeros(0,2),errorPairs,defaultOutcome);

stationManagement.pckBuffer(idOverflow) = stationManagement.pckBuffer(idOverflow) - 1;

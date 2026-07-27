function [stationManagement,sinrManagement,outputValues,simValues] = updateKPICV2X(activeIDsTXLTE,indexInActiveIDsOnlyLTE,neighborsID_LTE,timeManagement,stationManagement,positionManagement,sinrManagement,outputValues,simParams,appParams,phyParams,simValues)

% Update the counter for transmissions and retransmissions
outputValues.cv2xTransmissionsIncHarq = outputValues.cv2xTransmissionsIncHarq + length(activeIDsTXLTE);
outputValues.cv2xTransmissionsFirst = outputValues.cv2xTransmissionsFirst + sum(stationManagement.pckTxOccurring(activeIDsTXLTE)==1);

% Error detection (up to RawMax)
% Each line corresponds to an error [TX, RX, BR, distance] within RawMax
%errorMatrixRawMax = findErrors_TEMP(activeIDsTXLTE,indexInActiveIDsOnlyLTE,neighborsID_LTE,sinrManagement,stationManagement,positionManagement,phyParams);
% From v 5.4.14
[fateRxListRawMax,stationManagement,sinrManagement] = elaborateFateRxCV2X(timeManagement,activeIDsTXLTE,indexInActiveIDsOnlyLTE,neighborsID_LTE,sinrManagement,stationManagement,positionManagement,phyParams);

candidateReceiverIds = repmat( ...
    stationManagement.activeIDsCV2X(:).', ...
    numel(activeIDsTXLTE),1);
for transmitterIndex = 1:numel(activeIDsTXLTE)
    candidateReceiverIds( ...
        transmitterIndex, ...
        candidateReceiverIds(transmitterIndex,:)== ...
            activeIDsTXLTE(transmitterIndex)) = 0;
end
dispatchAfterPacketFatesDetermined( ...
    simValues,timeManagement.timeNow,simParams.stringCV2X, ...
    phyParams.Raw,stationManagement,positionManagement, ...
    activeIDsTXLTE, ...
    timeManagement.timeGeneratedPacketInTxLTE(activeIDsTXLTE), ...
    candidateReceiverIds, ...
    fateRxListRawMax(fateRxListRawMax(:,5)==1,1:2), ...
    fateRxListRawMax(fateRxListRawMax(:,5)==0,1:2),"none");

% Error detection (within each value of Raw)
for iPhyRaw=1:length(phyParams.Raw)
    
    % From v 5.4.14
    %errorMatrix = errorMatrixRawMax(errorMatrixRawMax(:,4)<phyParams.Raw(iPhyRaw),:);
    correctRxList = fateRxListRawMax(fateRxListRawMax(:,4)<phyParams.Raw(iPhyRaw) & fateRxListRawMax(:,5)==1,:);
    errorRxList = fateRxListRawMax(fateRxListRawMax(:,4)<phyParams.Raw(iPhyRaw) & fateRxListRawMax(:,5)==0,:);

    % Call function to create awarenessMatrix
    % [#Correctly transmitted beacons, #Errors, #Neighbors]
    % Number of errors
    for iChannel = 1:phyParams.nChannels
        for pckType = 1:appParams.nPckTypes
            %Nerrors = length(errorMatrix( (stationManagement.pckType(errorMatrix(:,1))==pckType & stationManagement.vehicleChannel(errorMatrix(:,1))==iChannel),1));
            %Nerrors = sum(awarenessMatrix((stationManagement.pckType(activeIDsTXLTE)==pckType & stationManagement.vehicleChannel(activeIDsTXLTE)==iChannel),2));
            Nerrors = length(errorRxList( (stationManagement.pckType(errorRxList(:,1))==pckType & stationManagement.vehicleChannel(errorRxList(:,1))==iChannel),1));
            outputValues.NerrorsCV2X(iChannel,pckType,iPhyRaw) = outputValues.NerrorsCV2X(iChannel,pckType,iPhyRaw) + Nerrors;
            outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) = outputValues.NerrorsTOT(iChannel,pckType,iPhyRaw) + Nerrors;
        %end
    %end
    
    % Number of correctly transmitted beacons
    %for iChannel = 1:phyParams.nChannels
        %for pckType = 1:appParams.nPckTypes
            %NcorrectlyTxBeacons = sum(awarenessMatrix((stationManagement.pckType(activeIDsTXLTE)==pckType & stationManagement.vehicleChannel(activeIDsTXLTE)==iChannel),1));
            NcorrectlyTxBeacons = length(correctRxList( (stationManagement.pckType(correctRxList(:,1))==pckType & stationManagement.vehicleChannel(correctRxList(:,1))==iChannel),1));
            outputValues.NcorrectlyTxBeaconsCV2X(iChannel,pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsCV2X(iChannel,pckType,iPhyRaw) + NcorrectlyTxBeacons;
            outputValues.NcorrectlyTxBeaconsTOT(iChannel,pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsTOT(iChannel,pckType,iPhyRaw) + NcorrectlyTxBeacons;
    %    end
    %end
    
    % Number of transmitted beacons
    %for iChannel = 1:phyParams.nChannels
        %for pckType = 1:appParams.nPckTypes
            %NtxBeacons = sum(awarenessMatrix((stationManagement.pckType(activeIDsTXLTE)==pckType & stationManagement.vehicleChannel(activeIDsTXLTE)==iChannel),3));
            NtxBeacons = Nerrors + NcorrectlyTxBeacons;
            outputValues.NtxBeaconsCV2X(iChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsCV2X(iChannel,pckType,iPhyRaw) + NtxBeacons;
            outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsTOT(iChannel,pckType,iPhyRaw) + NtxBeacons;
        end
    end
end

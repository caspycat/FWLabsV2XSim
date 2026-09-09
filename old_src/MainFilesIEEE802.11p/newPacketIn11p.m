function [timeManagement,stationManagement,sinrManagement,outputValues] = newPacketIn11p(idEvent,~,simParams,~,phyParams,timeManagement,stationManagement,sinrManagement,outputValues,~)
% A new packet is generated in IEEE 802.11p

% Queue admission and packet-state reset are owned by the V7 buffer.

% Part dealing with transmission start
% If coexistence Method A during the LTE part, the vehicle must go in State 9
if simParams.technology == constants.TECH_COEX_STD_INTERF && ...
        simParams.coexMethod == constants.COEX_METHOD_A && ...
        ~simParams.coexA_withLegacyITSG5 && ...
        timeManagement.coex_superframeThisIsLTEPart(idEvent) % LTE part
    if stationManagement.vehicleState(idEvent) == constants.V_STATE_11P_IDLE % idle
        stationManagement.vehicleState(idEvent) = constants.V_STATE_11P_RX; % rx
    end
end

% If the node was in IDLE (State==1)
% NOTE: if the channel is sensed busy, the station is in State 9, so there
% is no need to freeze here
if stationManagement.vehicleState(idEvent) == constants.V_STATE_11P_IDLE % idle
    
    % % DEBUG EVENTS
    % printDebugEvents(timeEvent,'backoff starts',idEvent);

    % Start the backoff
    stationManagement.vehicleState(idEvent) = constants.V_STATE_11P_BACKOFF; % backoff
    % A new random backoff is set and the instant of its conclusion
    % is derived
    % if there is a new packet and the channel is sensed idle during AIFS,
    % the vehicle would transmite this packet immediatly after the AIFS,
    % and without the backoff process.
    if simParams.technology~=constants.TECH_COEX_STD_INTERF || simParams.coexMethod~=constants.COEX_METHOD_C || ~simParams.coexCmodifiedCW
        [stationManagement.nSlotBackoff11p(idEvent), timeManagement.timeNextTxRx11p(idEvent)] =...
            startNewBackoff11p(timeManagement.timeNow,stationManagement.CW_11p(idEvent),...
            stationManagement.tAifs_11p(idEvent),phyParams.tSlot);
    else
        relativeTime = timeManagement.timeNow-simParams.coex_superFlength*floor(timeManagement.timeNow/simParams.coex_superFlength);
        subframeIndex = floor(relativeTime/phyParams.Tsf);
        [stationManagement.nSlotBackoff11p(idEvent), timeManagement.timeNextTxRx11p(idEvent)] =...
            coexistenceStartNewBackoff11pModified(...
                timeManagement.timeNow, stationManagement.CW_11p(idEvent),...
                stationManagement.tAifs_11p(idEvent), phyParams.tSlot,...
                subframeIndex,simParams.coex_superframeSF);
    end        
%     printDebugBackoff11p(timeManagement.timeNow,'11p backoff started',idEvent,stationManagement,outParams,timeManagement);
end

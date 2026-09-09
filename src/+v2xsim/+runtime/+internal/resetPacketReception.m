function [station,sinr] = resetPacketReception(station,sinr,id)
%RESETPACKETRECEPTION Reset only the newly selected packet's radio state.
arguments
    station (1,1) struct
    sinr (1,1) struct
    id (1,1) double {mustBeInteger,mustBePositive}
end
station.pckNextAttempt(id) = 1;
station.pckTxOccurring(id) = 0;
station.pckReceived(:,id) = 0;
sinr.cumulativeSINR(:,id) = 0;
station.preambleAlreadyDetected(:,id) = 0;
station.alreadyStartCBR(:,id) = 0;
end

function [station,sinr] = completeEnginePacket(station,sinr,id,timeSeconds)
%COMPLETEENGINEPACKET Release a head only after its final outcomes were read.
arguments
    station (1,1) struct
    sinr (1,1) struct
    id (1,1) double {mustBeInteger,mustBePositive}
    timeSeconds (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
end
station.packetBuffers{id} = station.packetBuffers{id}.removeHead();
station.pckBuffer(id) = station.packetBuffers{id}.Count;
if station.pckBuffer(id) > 0
    station.packetHeadSelectionTime(id) = timeSeconds;
end
[station,sinr] = v2xsim.runtime.internal.resetPacketReception(station,sinr,id);
end

function [station,sinr,output] = enqueueEnginePacket(id,time,station,sinr,position,phy,sim,values,output)
%ENQUEUEENGINEPACKET Admit one application packet without touching an on-air head.
arguments
    id (1,1) double
    time (1,1) struct
    station (1,1) struct
    sinr (1,1) struct
    position (1,1) struct
    phy (1,1) struct
    sim (1,1) struct
    values (1,1) struct
    output (1,1) struct
end
queue = station.packetBuffers{id};
oldCount = queue.Count;
[queue,dropped,headChanged] = queue.enqueue( ...
    max(0,time.timeNow-time.addedToGenerationTime(id)),time.timeNow,station.pckType(id));
if ~isempty(dropped)
    attempted = headChanged && oldCount > 0 && station.pckNextAttempt(id) > 1;
    output = v2xsim.runtime.internal.discardEnginePacket( ...
        id,dropped,attempted,time,station,position,phy,sim,values,output);
end
station.packetBuffers{id} = queue;
station.pckBuffer(id) = queue.Count;
if headChanged
    station.packetHeadSelectionTime(id) = time.timeNow;
    [station,sinr] = v2xsim.runtime.internal.resetPacketReception(station,sinr,id);
end
end

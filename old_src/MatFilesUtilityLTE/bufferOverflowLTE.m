function [stationManagement,outputValues] = bufferOverflowLTE(idOverflow,timeManagement,positionManagement,stationManagement,phyParams,~,outputValues,simValues,technology)
% Finalize the active packet blocked by allocation or a reduced retry budget.
% Admission overflow is handled by the native FIFO at generation time.
queue = stationManagement.packetBuffers{idOverflow};
if queue.OnAir
    % Reception processing at attempt end owns finalization while on air.
    return
end
packet = queue.head();
simParams = struct(stringCV2X=string(technology));
outputValues = v2xsim.runtime.internal.discardEnginePacket( ...
    idOverflow,packet,stationManagement.pckNextAttempt(idOverflow)>1, ...
    timeManagement,stationManagement,positionManagement,phyParams, ...
    simParams,simValues,outputValues);
stationManagement.packetBuffers{idOverflow} = queue.removeHead();
stationManagement.pckBuffer(idOverflow) = stationManagement.packetBuffers{idOverflow}.Count;
if stationManagement.pckBuffer(idOverflow) > 0
    stationManagement.packetHeadSelectionTime(idOverflow) = timeManagement.timeNow;
end
stationManagement.pckNextAttempt(idOverflow) = 1;
stationManagement.pckTxOccurring(idOverflow) = 0;
stationManagement.pckReceived(:,idOverflow) = 0;
end

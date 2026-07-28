function printDebugBackoff11p(Time,StringOfEvent,idEvent,stationManagement,outParams,timeManagement) %#ok<INUSD>
% Print of: Time, event description, then per each station:
% ID, technology, state, current SINR (if LTE, first neighbor), useful power (if LTE, first neighbor),
% interfering power (if LTE, first neighbor), interfering power from
% the other technology (if LTE, first neighbor)

return;

filename = fullfile( ...
    outParams.outputFolder,"_DebugBackoff11p.csv"); %#ok<UNRCH>
fid = fopen(filename,'r');
if fid==-1
    fid = fopen(filename,'w');
    fprintf(fid, ...
        ['TimeSeconds,Event,VehicleId,BackoffCounter,' ...
        'NextTransmissionReceptionTimeSeconds\n']);
end
fclose(fid);

fid = fopen(filename,'a');
event = strrep(char(StringOfEvent),'"','""');
fprintf(fid,'%3.6f,"%s",%d,%d,%d\n', ...
    Time,event,idEvent,stationManagement.nSlotBackoff11p(idEvent), ...
    timeManagement.timeNextTxRx11p(idEvent));
fclose(fid);

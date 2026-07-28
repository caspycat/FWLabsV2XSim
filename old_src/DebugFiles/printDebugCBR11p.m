function printDebugCBR11p(Time,StringOfEvent,idEvent,outParams)
% Print of: Time, event description, then per each station:
% ID, technology, state, current SINR (if LTE, first neighbor), useful power (if LTE, first neighbor),
% interfering power (if LTE, first neighbor), interfering power from
% the other technology (if LTE, first neighbor)


filename = fullfile(outParams.outputFolder,"_DebugCBR11p.csv");
fid = fopen(filename,'r');
if fid==-1
    fid = fopen(filename,'w');
    fprintf(fid,'TimeSeconds,Event,VehicleId\n');
end
fclose(fid);
if ismember(187,idEvent)
    index = idEvent==187;
    fid = fopen(filename,'a');
    event = strrep(char(StringOfEvent),'"','""');
    fprintf(fid,'%3.6f,"%s",%d\n',Time,event,idEvent(index));
    
    fclose(fid);
end

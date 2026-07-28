function printDebugTxRx(time,v_id,event,stationManagement,sinrManagement,outParams) %#ok<INUSD>
%PRINTDEBUGTXRX Summary of this function goes here
%   Detailed explanation goes here
filename = fullfile(outParams.outputFolder,"_DebugTxRx.csv");
writeHeader = ~isfile(filename);
fid = fopen(filename, "a");
if writeHeader
    fprintf(fid,"TimeSeconds,VehicleId,Event\n");
end
event = strrep(char(event),'"','""');
fprintf(fid,'%f,%d,"%s"\n',time,v_id,event);
fclose(fid);

end

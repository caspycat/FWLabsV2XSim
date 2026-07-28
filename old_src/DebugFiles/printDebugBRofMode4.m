function printDebugBRofMode4(timeManagement,idvehicle,BR,outParams) %#ok<INUSD>

%if timeManagement.timeNow<10
   return;
%end

filename = fullfile( ...
    outParams.outputFolder,"_DebugBRofMode4.csv"); %#ok<UNRCH>
writeHeader = ~isfile(filename);
fid = fopen(filename,'a');
if writeHeader
    fprintf(fid,'TimeSeconds,VehicleId,BeaconResourceId\n');
end

fprintf(fid,'%f,%d,%d\n',timeManagement.timeNow,idvehicle,BR);

fclose(fid);

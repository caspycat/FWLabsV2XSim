function printDebugITSNumberofReplicas(outParams, time, retransType, idTx, ITSNumberOfReplicas)
filename = fullfile(outParams.outputFolder, ...
    "_DebugITSNumberofReplicas.csv");
fid = fopen(filename,'r');
if fid==-1
    fid = fopen(filename,'w');
    fprintf(fid, ...
        ['TimeSeconds,RetransmissionType,TransmitterVehicleId,' ...
        'ReplicaCount\n']);
end
fclose(fid);

fid = fopen(filename,'a');
fprintf(fid,'%3.6f,%d,%d,%d\n', ...
    time,retransType,idTx,ITSNumberOfReplicas);

fclose(fid);

function printDebugGeneration(timeManagement,idEvent,positionManagement,outParams) %#ok<INUSD>

%if Time<4 || Time>4.2
%if Time>0.2
return;
%end

if idEvent>0 %#ok<UNRCH>
    
    filename = fullfile(outParams.outputFolder,"_DebugGen.csv");

    writeHeader = ~isfile(filename);
    fid = fopen(filename,'a');
    if writeHeader
        fprintf(fid, ...
            ['TimeSeconds,VehicleId,LongitudinalPositionMeters,' ...
            'NextPacketGenerationTimeSeconds\n']);
    end

    fprintf(fid,'%f,%d,%f,%f\n', ...
        timeManagement.timeNow,idEvent, ...
        positionManagement.XvehicleReal(idEvent), ...
        timeManagement.timeNextPacket(idEvent));

    fclose(fid);

end

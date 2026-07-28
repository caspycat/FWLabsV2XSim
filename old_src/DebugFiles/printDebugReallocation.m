function printDebugReallocation(Time,staID,posX,strEvent,BR,outParams) %#ok<INUSD>
% Print of: Time, event description, then per each station:
% ID, technology, state, current SINR (if LTE, first neighbor), useful power (if LTE, first neighbor),
% interfering power (if LTE, first neighbor), interfering power from
% the other technology (if LTE, first neighbor)

%if Time<1.8
   return;
%end

filename = fullfile( ...
    outParams.outputFolder,"_DebugReallocation.csv"); %#ok<UNRCH>
% Time - Vehicle ID - posX - Packet generation 0/1 - Reallocation 0/BR

writeHeader = ~isfile(filename);
fid = fopen(filename,'a');
if writeHeader
    fprintf(fid, ...
        ['TimeSeconds,VehicleId,LongitudinalPositionMeters,' ...
        'PacketGenerated,ReallocatedBeaconResourceId\n']);
end
if staID==-1
    error('Error in printDebugReallocation - E1');
else
	fprintf(fid,'%3.6f,%d,%d,',Time,staID,posX);
    if strcmpi(strEvent,'gen')
        fprintf(fid,'1,0\n');
    elseif strcmpi(strEvent,'reall')
        fprintf(fid,'0,%d\n',BR);
    else
        error('Error in printDebugReallocation - E2');
    end 
end
fclose(fid);

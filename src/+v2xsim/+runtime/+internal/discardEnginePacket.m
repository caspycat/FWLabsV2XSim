function output = discardEnginePacket(id,packet,attempted,time,station,position,phy,sim,values,output)
%DISCARDENGINEPACKET Finalize one evicted or allocation-blocked packet.
% This boundary projects an explicit packet snapshot, including waiting
% packets whose fate is reported before the older on-air head completes.
arguments
    id (1,1) double
    packet (1,1) struct
    attempted (1,1) logical
    time (1,1) struct
    station (1,1) struct
    position (1,1) struct
    phy (1,1) struct
    sim (1,1) struct
    values (1,1) struct
    output (1,1) struct
end
is11p = station.vehicleState(id) ~= constants.V_STATE_LTE_TXRX;
if is11p
    technology = "11p";
    suffix = "11p";
    row = find(station.activeIDs11p == id,1);
    receivers = station.neighborsID11p(row,:);
else
    technology = string(sim.stringCV2X);
    suffix = "CV2X";
    row = find(station.activeIDsCV2X == id,1);
    receivers = station.neighborsIDLTE(row,:);
end
receivers = unique(receivers(receivers > 0 & receivers ~= id));
receivers = receivers(station.vehicleChannel(receivers) == station.vehicleChannel(id));
if attempted
    receivers = receivers(station.pckReceived(receivers,id) <= 0);
    outcome = "error";
    countNames = ["Nerrors", "NtxBeacons"];
else
    outcome = "blocked";
    countNames = "Nblocked";
end
distances = position.distanceReal(id,receivers);
for rangeIndex = 1:numel(phy.Raw)
    count = nnz(distances < phy.Raw(rangeIndex));
    for countName = countNames
        for technologySuffix = [suffix,"TOT"]
            name = countName + technologySuffix;
            output.(name)(station.vehicleChannel(id),packet.PacketType,rangeIndex) = ...
                output.(name)(station.vehicleChannel(id),packet.PacketType,rangeIndex) + count;
        end
    end
end
station.packetFateMetadata = packet;
station.packetFateMetadata.IsPacketComplete = true;
station.packetFateMetadata.AttemptNumber = double(attempted) * station.pckTxOccurring(id);
dispatchAfterPacketFatesDetermined(values,time.timeNow,technology,phy.Raw, ...
    station,position,id,packet.GenerationTimeSeconds,reshape(receivers,1,[]), ...
    zeros(0,2),zeros(0,2),outcome);
end

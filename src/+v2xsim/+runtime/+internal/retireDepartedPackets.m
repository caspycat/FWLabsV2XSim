function retireDepartedPackets(id,time,station,position,phy,sim,values)
%RETIREDEPARTEDPACKETS Release observer identity state without inventing fates.
arguments
    id (1,1) double
    time (1,1) struct
    station (1,1) struct
    position (1,1) struct
    phy (1,1) struct
    sim (1,1) struct
    values (1,1) struct
end
if ~isfield(values,"hookDispatcher")
    return
end
technology = "11p";
if station.vehicleState(id) == constants.V_STATE_LTE_TXRX
    technology = string(sim.stringCV2X);
end
for packet = station.packetBuffers{id}.Packets
    station.packetFateMetadata = packet;
    station.packetFateMetadata.IsPacketComplete = true;
    station.packetFateMetadata.AttemptNumber = 0;
    dispatchAfterPacketFatesDetermined(values,time.timeNow,technology,phy.Raw, ...
        station,position,id,packet.GenerationTimeSeconds,zeros(1,0), ...
        zeros(0,2),zeros(0,2),"none");
end
end

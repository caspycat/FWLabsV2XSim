function ratio = cellularPacketReceptionRatio(summary)
%CELLULARPACKETRECEPTIONRATIO Read the outermost-range cellular PRR.

metrics = summary.Results.CellularSidelink.AwarenessRangeMetrics;
if iscell(metrics)
    metric = metrics{end};
else
    metric = metrics(end);
end
ratio = metric.PacketReceptionRatio;
if isempty(ratio)
    ratio = NaN;
end
end

function prr = readDeliveryPrrArtifact(runDirectory,options)
%READDELIVERYPRRARTIFACT Read one distance-binned delivery-PRR CSV artifact.
%   PRR contains correct, error, and blocked counts and DeliveryPrr, where
%   DeliveryPrr = correct / (correct + error + blocked).

arguments (Input)
    runDirectory (1,1) string {mustBeFolder}
    options.Technology (1,1) string = ""
end

pattern = "packet_reception_ratio_*.csv";
if options.Technology ~= ""
    pattern = "packet_reception_ratio_" + options.Technology + "*.csv";
end
files = dir(fullfile(runDirectory,pattern));
if ~isscalar(files)
    error("v2xsim:analysis:AmbiguousPrrArtifact", ...
        "Expected exactly one PRR artifact matching %s in %s.", ...
        pattern,runDirectory);
end
values = readmatrix(fullfile(files.folder,files.name));
if size(values,2) ~= 6 || any(~isfinite(values(:,1:5)),"all")
    error("v2xsim:analysis:InvalidPrrArtifact", ...
        "PRR artifact %s must contain six finite count columns.", ...
        fullfile(files.folder,files.name));
end
counts = array2table(values(:,1:4),VariableNames=[ ...
    "DistanceUpperBoundMeters","CorrectCount","ErrorCount", ...
    "BlockedCount"]);
prr = v2xsim.analysis.poolPacketReceptionCounts( ...
    counts,GroupVariables=strings(1,0));
end

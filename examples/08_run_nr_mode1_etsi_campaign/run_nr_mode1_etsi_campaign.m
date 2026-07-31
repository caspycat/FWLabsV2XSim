%% 08 - Sweep the three 3GPP freeway traffic presets with NR Mode 1
% The run is intentionally short. It demonstrates a campaign layout and
% paired seed policy, not a statistically supported density conclusion.

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample( ...
    exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Campaign)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"08_nr_mode1_etsi_campaign.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
trafficModels = [ ...
    "HighSpeedLowDensity"; ...
    "MediumSpeedMediumDensity"; ...
    "LowSpeedHighDensity"];

averageVehicleCount = zeros(size(trafficModels));
packetReceptionRatio = zeros(size(trafficModels));
simulationElapsedSeconds = zeros(size(trafficModels));
runDirectories = strings(size(trafficModels));
summaries = cell(size(trafficModels));
simulationResults = cell(size(trafficModels));

for modelIndex = 1:numel(trafficModels)
    trafficModel = trafficModels(modelIndex);
    runDirectories(modelIndex) = fullfile(outputDirectory,trafficModel);
    patchData = struct( ...
        Scenario=struct(EtsiHighway=struct( ...
            TrafficModel=trafficModel)), ...
        Simulation=struct(RandomSeed=18), ...
        ResourceAllocation=struct(RandomSeed=208));
    patch = v2xsim.config.patch(patchData);
    configuration = template.resolve(Patch=patch);
    simulationTimer = tic;
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=runDirectories(modelIndex), ...
        RunLabel="etsi-" + trafficModel);
    simulationElapsedSeconds(modelIndex) = toc(simulationTimer);
    runDirectories(modelIndex) = simulationResult.RunDirectory;
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    summaries{modelIndex} = summary;
    simulationResults{modelIndex} = simulationResult;
    averageVehicleCount(modelIndex) = ...
        summary.Results.CellularSidelink.AverageUeCount;
    packetReceptionRatio(modelIndex) = ...
        cellularPacketReceptionRatio(summary);
end

campaign = table( ...
    trafficModels,averageVehicleCount,packetReceptionRatio,runDirectories, ...
    VariableNames=[ ...
        "TrafficModel","AverageVehicleCount", ...
        "PacketReceptionRatio","RunDirectory"]);

figure(Name="V7 NR Mode 1 ETSI campaign");
plot( ...
    campaign.AverageVehicleCount,campaign.PacketReceptionRatio, ...
    "o-",LineWidth=1.2);
grid on
xlabel("Average vehicle count")
ylabel("Packet reception ratio")
ylim([0,1])
title("Short workflow check across traffic presets")

elapsedSeconds = toc(timer);
if elapsedSeconds > 30
    warning( ...
        "v2xsimexample:SlowExample", ...
        "This example took %.1f seconds on this computer.", ...
        elapsedSeconds);
end
results = struct( ...
    SimulationResults={simulationResults}, ...
    Summaries={summaries}, ...
    Campaign=campaign, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

function ratio = cellularPacketReceptionRatio(summary)
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

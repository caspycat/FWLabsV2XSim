%% 06 - Run a small multi-configuration campaign
% Every vehicle-count case receives its own child directory. The short sweep
% demonstrates aggregation mechanics, not a statistically supported trend.

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample( ...
    exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Sweep)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"06_density_sweep.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
vehicleCounts = [4;8;12];
packetReceptionRatio = zeros(size(vehicleCounts));
simulationElapsedSeconds = zeros(size(vehicleCounts));
runDirectories = strings(size(vehicleCounts));
summaries = cell(size(vehicleCounts));
simulationResults = cell(size(vehicleCounts));

for caseIndex = 1:numel(vehicleCounts)
    vehicleCount = vehicleCounts(caseIndex);
    runDirectories(caseIndex) = fullfile( ...
        outputDirectory,"vehicles-" + string(vehicleCount));
    patch = v2xsim.config.patch(struct(Scenario=struct( ...
        BidirectionalHighway=struct(VehicleCount=vehicleCount))));
    configuration = template.resolve(Patch=patch);
    simulationTimer = tic;
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=runDirectories(caseIndex), ...
        RunLabel="density-" + string(vehicleCount));
    simulationElapsedSeconds(caseIndex) = toc(simulationTimer);
    runDirectories(caseIndex) = simulationResult.RunDirectory;
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    summaries{caseIndex} = summary;
    simulationResults{caseIndex} = simulationResult;
    packetReceptionRatio(caseIndex) = ...
        cellularPacketReceptionRatio(summary);
end

sweep = table( ...
    vehicleCounts,packetReceptionRatio,runDirectories, ...
    VariableNames=[ ...
        "VehicleCount","PacketReceptionRatio","RunDirectory"]);
figure(Name="V7 density sweep");
plot( ...
    sweep.VehicleCount,sweep.PacketReceptionRatio, ...
    "o-",LineWidth=1.2);
grid on
xlabel("Vehicle count")
ylabel("Packet reception ratio")
ylim([0,1])
title("Short demonstration sweep")

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
    Sweep=sweep, ...
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

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
    exampleDirectory,"config","06_density_sweep.cfg");
outputDirectory = string(tempname);
vehicleCounts = [4;8;12];
packetReceptionRatio = zeros(size(vehicleCounts));
simulationElapsedSeconds = zeros(size(vehicleCounts));
runDirectories = strings(size(vehicleCounts));
summaries = cell(size(vehicleCounts));

for caseIndex = 1:numel(vehicleCounts)
    vehicleCount = vehicleCounts(caseIndex);
    runDirectories(caseIndex) = fullfile( ...
        outputDirectory,"vehicles-" + string(vehicleCount));
    [summary,simulationElapsedSeconds(caseIndex)] = ...
        runV7ExampleSimulation( ...
            configurationFile,runDirectories(caseIndex), { ...
                "scenarioOptions.VehicleCount",vehicleCount, ...
                "simulation.RunLabel", ...
                    "density-" + string(vehicleCount)});
    summaries{caseIndex} = summary;
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
warnIfSlowV7Example(elapsedSeconds);
results = struct( ...
    Summaries={summaries}, ...
    Sweep=sweep, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

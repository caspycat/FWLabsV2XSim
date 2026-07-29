%% 04 - Apply an ordered positioning-error chain
% The example combines Gaussian displacement, false-exit route perception,
% and observation delay on the lane-aware exit-ramp scenario.

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample( ...
    exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Modules)
fprintf("Completed output: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","04_position_errors.cfg");
outputDirectory = string(tempname);
[summary,simulationElapsedSeconds] = runV7ExampleSimulation( ...
    configurationFile,outputDirectory);

traceFiles = dir(fullfile( ...
    outputDirectory,"position_error_trace_*.csv"));
assert(~isempty(traceFiles), ...
    "The position-error example did not produce trace chunks.");
trace = table;
for fileIndex = 1:numel(traceFiles)
    rows = readtable( ...
        fullfile(traceFiles(fileIndex).folder,traceFiles(fileIndex).name), ...
        TextType="string");
    if isempty(trace)
        trace = rows;
    else
        trace = [trace;rows]; %#ok<AGROW>
    end
end

moduleIndices = unique(trace.ModuleIndex);
moduleIndices(moduleIndices == 0) = [];
moduleType = strings(numel(moduleIndices),1);
statusEffectType = strings(numel(moduleIndices),1);
rowCount = zeros(numel(moduleIndices),1);
activeRowCount = zeros(numel(moduleIndices),1);
for moduleRow = 1:numel(moduleIndices)
    mask = trace.ModuleIndex == moduleIndices(moduleRow);
    firstRow = find(mask,1,"first");
    moduleType(moduleRow) = trace.ModuleType(firstRow);
    statusEffectType(moduleRow) = trace.StatusEffectType(firstRow);
    rowCount(moduleRow) = sum(mask);
    activeRowCount(moduleRow) = sum(trace.IsActive(mask));
end
moduleTable = table( ...
    moduleIndices,moduleType,statusEffectType,rowCount,activeRowCount, ...
    VariableNames=[ ...
        "ModuleIndex","ModuleType","StatusEffectType", ...
        "TraceRowCount","ActiveRowCount"]);

configuredModules = summary.Configuration.Positioning.ErrorChain.Modules;
configuredModuleCount = numel(configuredModules);
assert(configuredModuleCount == 3, ...
    "The summary did not retain the three configured modules.");

kinematics = readtable( ...
    fullfile(outputDirectory,"vehicle_kinematics.csv"), ...
    TextType="string");
finalModuleIndex = max(trace.ModuleIndex);
apparent = trace(trace.ModuleIndex == finalModuleIndex, ...
    ["SimulationTimeSeconds","VehicleId","OutputXMeters","OutputYMeters"]);
truth = kinematics(:,["SimulationTimeSeconds","VehicleId","X","Y"]);
truth.Properties.VariableNames(end - 1:end) = ["TrueXMeters","TrueYMeters"];
trajectory = innerjoin( ...
    truth,apparent, ...
    Keys=["SimulationTimeSeconds","VehicleId"]);

activeFalseExit = trace.StatusEffectType == ...
    "FalseExitPositionErrorStatusEffect" & trace.IsActive;
if any(activeFalseExit)
    vehicleId = trace.VehicleId(find(activeFalseExit,1,"first"));
else
    vehicleId = trajectory.VehicleId(1);
end
vehicleTrajectory = trajectory(trajectory.VehicleId == vehicleId,:);
vehicleTrajectory = sortrows(vehicleTrajectory,"SimulationTimeSeconds");
figure(Name="V7 position errors");
plot( ...
    vehicleTrajectory.TrueXMeters,vehicleTrajectory.TrueYMeters, ...
    "o-",DisplayName="true");
hold on
plot( ...
    vehicleTrajectory.OutputXMeters,vehicleTrajectory.OutputYMeters, ...
    "x--",DisplayName="apparent");
hold off
axis equal
grid on
xlabel("X (m)")
ylabel("Y (m)")
title("True and apparent trajectory for vehicle " + vehicleId)
legend(Location="best")

elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct( ...
    Summary=summary, ...
    Modules=moduleTable, ...
    Trace=trace, ...
    Trajectory=trajectory, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

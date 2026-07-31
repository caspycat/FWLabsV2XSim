%% 04 - Apply and analyse an ordered positioning-error chain
% The example combines Gaussian displacement, false-exit and false-merge
% route perception, and observation delay on the exit-ramp scenario.

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample( ...
    exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Modules)
fprintf("Completed output: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"04_position_errors.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
configuration = template.resolve();
simulationTimer = tic;
simulationResult = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory=outputDirectory, ...
    RunLabel="position-errors");
simulationElapsedSeconds = toc(simulationTimer);
outputDirectory = simulationResult.RunDirectory;
summary = jsondecode(fileread(fullfile( ...
    simulationResult.RunDirectory,"simulation_summary.json")));

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
trace = sortrows( ...
    trace,["SimulationTimeSeconds","VehicleId","ModuleIndex"]);

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
assert(configuredModuleCount == 4, ...
    "The summary did not retain the four configured modules.");

routeActivity = summarizeRouteActivity(trace);
episodeEntries = trace(trace.ActiveSegmentEntered ~= 0, ...
    ["SimulationTimeSeconds","VehicleId","TrueRoute", ...
     "ModuleIndex","StatusEffectType","EpisodeId", ...
     "LeftCensoredAtStart"]);

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

figure(Name="V7 position-error modules");
layout = tiledlayout(2,1,TileSpacing="compact");
title(layout,"Incremental module errors and active episodes")
nexttile
hold on
for moduleRow = 1:numel(moduleIndices)
    mask = trace.ModuleIndex == moduleIndices(moduleRow);
    plot( ...
        trace.SimulationTimeSeconds(mask), ...
        trace.DisplacementMagnitudeMeters(mask),".", ...
        DisplayName=moduleType(moduleRow));
end
hold off
grid on
xlabel("Simulation time (s)")
ylabel("Incremental displacement (m)")
legend(Location="best")

nexttile
activeRows = trace(trace.IsActive ~= 0,:);
if isempty(activeRows)
    text(0.5,0.5,"No active status-effect rows", ...
        HorizontalAlignment="center");
    axis off
else
    scatter( ...
        activeRows.SimulationTimeSeconds, ...
        categorical(activeRows.VehicleId),18, ...
        activeRows.ModuleIndex,"filled");
    grid on
    xlabel("Simulation time (s)")
    ylabel("Vehicle ID")
    colorbar
end

elapsedSeconds = toc(timer);
if elapsedSeconds > 30
    warning( ...
        "v2xsimexample:SlowExample", ...
        "This example took %.1f seconds on this computer.", ...
        elapsedSeconds);
end
results = struct( ...
    SimulationResult=simulationResult, ...
    Summary=summary, ...
    Modules=moduleTable, ...
    RouteActivity=routeActivity, ...
    EpisodeEntries=episodeEntries, ...
    Trace=trace, ...
    Trajectory=trajectory, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

function result = summarizeRouteActivity(trace)
effectTypes = unique(trace.StatusEffectType);
routes = unique(trace.TrueRoute);
effectType = strings(0,1);
trueRoute = strings(0,1);
traceRowCount = zeros(0,1);
activeRowCount = zeros(0,1);
for effectIndex = 1:numel(effectTypes)
    for routeIndex = 1:numel(routes)
        mask = trace.StatusEffectType == effectTypes(effectIndex) & ...
            trace.TrueRoute == routes(routeIndex);
        if ~any(mask)
            continue
        end
        effectType(end + 1,1) = effectTypes(effectIndex); %#ok<AGROW>
        trueRoute(end + 1,1) = routes(routeIndex); %#ok<AGROW>
        traceRowCount(end + 1,1) = sum(mask); %#ok<AGROW>
        activeRowCount(end + 1,1) = sum(trace.IsActive(mask)); %#ok<AGROW>
    end
end
result = table( ...
    effectType,trueRoute,traceRowCount,activeRowCount, ...
    VariableNames=[ ...
        "StatusEffectType","TrueRoute","TraceRowCount","ActiveRowCount"]);
end

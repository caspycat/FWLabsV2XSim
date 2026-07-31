%% 03 - Compare named cellular-sidelink resource allocators
% V7 selects allocators by descriptive names instead of numeric algorithm IDs.

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample( ...
    exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Allocators)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"03_named_allocators.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
allocatorTypes = [ ...
    "ReuseDistance", ...
    "MaximumReuseDistance", ...
    "MinimumReusePower", ...
    "SensingBased", ...
    "Random", ...
    "Ordered"];

category = strings(numel(allocatorTypes),1);
networkSliceId = strings(numel(allocatorTypes),1);
randomSeed = zeros(numel(allocatorTypes),1);
packetReceptionRatio = zeros(numel(allocatorTypes),1);
simulationElapsedSeconds = zeros(numel(allocatorTypes),1);
summaries = cell(numel(allocatorTypes),1);
simulationResults = cell(numel(allocatorTypes),1);
for allocatorIndex = 1:numel(allocatorTypes)
    allocatorType = allocatorTypes(allocatorIndex);
    runDirectory = fullfile(outputDirectory,allocatorType);
    patch = v2xsim.config.patch( ...
        resourceAllocationPatch(allocatorType));
    configuration = template.resolve(Patch=patch);
    simulationTimer = tic;
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=runDirectory, ...
        RunLabel="allocator-" + allocatorType);
    simulationElapsedSeconds(allocatorIndex) = toc(simulationTimer);
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    metadata = summary.Configuration.ResourceAllocation.Metadata;
    assert(string(metadata.Type) == allocatorType, ...
        "The summary did not retain the requested allocator type.");
    summaries{allocatorIndex} = summary;
    simulationResults{allocatorIndex} = simulationResult;
    category(allocatorIndex) = string(metadata.Category);
    networkSliceId(allocatorIndex) = string(metadata.NetworkSliceId);
    randomSeed(allocatorIndex) = metadata.RandomSeed;
    packetReceptionRatio(allocatorIndex) = ...
        cellularPacketReceptionRatio(summary);
end

allocatorTable = table( ...
    allocatorTypes.',category,networkSliceId,randomSeed, ...
    packetReceptionRatio, ...
    VariableNames=[ ...
        "Allocator","Category","NetworkSliceId","RandomSeed", ...
        "PacketReceptionRatio"]);
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
    Allocators=allocatorTable, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

function patchData = resourceAllocationPatch(allocatorType)
allocation = struct(Type=allocatorType);
allocation.(allocatorType) = struct();
patchData = struct(ResourceAllocation=allocation);
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

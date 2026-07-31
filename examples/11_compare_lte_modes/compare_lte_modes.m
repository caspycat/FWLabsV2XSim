%% 11 - Compare LTE-V2X Mode 3 and Mode 4

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Modes)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"11_lte_modes.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
modeNames = ["Mode 3";"Mode 4"];
allocatorTypes = ["MaximumReuseDistance";"SensingBased"];
categories = strings(2,1);
prr = zeros(2,1);
summaries = cell(2,1);
simulationResults = cell(2,1);

for index = 1:2
    type = allocatorTypes(index);
    branch = struct();
    if type == "MaximumReuseDistance"
        branch.ReassignmentIntervalSeconds = 0.1;
    else
        branch.KeepResourceProbability = 0.8;
        branch.L2RankingEnabled = true;
        branch.AverageSensingEnabled = true;
    end
    allocation = struct(Type=type);
    allocation.(type) = branch;
    patch = v2xsim.config.patch( ...
        struct(ResourceAllocation=allocation));
    configuration = template.resolve(Patch=patch);
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=fullfile( ...
            outputDirectory,compose("case-%d",index)), ...
        RunLabel=modeNames(index));
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    metadata = summary.Configuration.ResourceAllocation.Metadata;
    categories(index) = string(metadata.Category);
    prr(index) = cellularPacketReceptionRatio(summary);
    summaries{index} = summary;
    simulationResults{index} = simulationResult;
end

modeTable = table(modeNames,allocatorTypes,categories,prr, ...
    VariableNames=["Mode","Allocator","Category","PacketReceptionRatio"]);
elapsedSeconds = toc(timer);
if elapsedSeconds > 30
    warning( ...
        "v2xsimexample:SlowExample", ...
        "This example took %.1f seconds on this computer.", ...
        elapsedSeconds);
end
results = struct( ...
    Modes=modeTable, ...
    SimulationResults={simulationResults}, ...
    Summaries={summaries}, ...
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

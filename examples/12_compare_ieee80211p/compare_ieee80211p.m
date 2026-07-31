%% 12 - Compare IEEE 802.11p PHY and repetition choices

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Cases)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"12_ieee80211p.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
caseNames = ["native-static";"native-probabilistic";"surrogate-static"];
physicalLayers = ["Native";"Native";"LteSurrogate"];
repetitionModes = ["Static";"Probabilistic";"Static"];
transmissionCounts = [1;4;1];
prr = zeros(3,1);
summaries = cell(3,1);
simulationResults = cell(3,1);

for index = 1:3
    ieee = struct( ...
        PhysicalLayer=physicalLayers(index), ...
        Repetition=struct( ...
            Mode=repetitionModes(index), ...
            MaximumTransmissionCount=transmissionCounts(index), ...
            BackoffMicroseconds=32, ...
            CbrThresholds=[0.03,0.05,0.09]));
    patch = v2xsim.config.patch( ...
        struct(Radio=struct(Ieee80211p=ieee)));
    configuration = template.resolve(Patch=patch);
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=fullfile(outputDirectory,caseNames(index)), ...
        RunLabel=caseNames(index));
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    prr(index) = awarenessPrr(summary.Results.Ieee80211p);
    summaries{index} = summary;
    simulationResults{index} = simulationResult;
end

caseTable = table(caseNames,physicalLayers,repetitionModes, ...
    transmissionCounts,prr, ...
    VariableNames=["Case","PhysicalLayer","RepetitionMode", ...
        "MaximumTransmissionCount","PacketReceptionRatio"]);
elapsedSeconds = toc(timer);
if elapsedSeconds > 30
    warning( ...
        "v2xsimexample:SlowExample", ...
        "This example took %.1f seconds on this computer.", ...
        elapsedSeconds);
end
results = struct( ...
    Cases=caseTable, ...
    SimulationResults={simulationResults}, ...
    Summaries={summaries}, ...
    ElapsedSeconds=elapsedSeconds);
end

function ratio = awarenessPrr(results)
metrics = results.AwarenessRangeMetrics;
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

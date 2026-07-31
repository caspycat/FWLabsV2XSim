%% 14 - Compare path-loss, fading, and packet-error models

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Cases)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"14_channel_models.toml");
    projectRoot = fileparts(fileparts(exampleDirectory));
curveDirectory = fullfile( ...
    projectRoot,"resources","per-curves","G5-HighwayLOS");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
caseNames = ["winner-threshold";"single-threshold";"winner-curves"];
pathLossModels = ["WinnerPlusB1";"SingleSlope";"WinnerPlusB1"];
packetErrorModels = ["Threshold";"Threshold";"Curves"];
rayleigh = [false;false;true];
prr = zeros(3,1);
summaries = cell(3,1);
simulationResults = cell(3,1);

for index = 1:3
    pathLoss = struct(Model=pathLossModels(index));
    if pathLossModels(index) == "SingleSlope"
        pathLoss.ReferenceLossAtOneMeterDb = 47.86;
        pathLoss.Exponent1 = 2.2;
    end
    packetError = struct(Model=packetErrorModels(index));
    if packetErrorModels(index) == "Curves"
        packetError.CurveDirectory = curveDirectory;
    end
    patchData = struct(Channel=struct( ...
        RayleighFadingEnabled=rayleigh(index), ...
        PathLoss=pathLoss,PacketError=packetError));
    patch = v2xsim.config.patch(patchData);
    configuration = template.resolve(Patch=patch);
    simulationResult = v2xsim.runSimulation( ...
        configuration, ...
        OutputDirectory=fullfile(outputDirectory,caseNames(index)), ...
        RunLabel=caseNames(index));
    summary = jsondecode(fileread(fullfile( ...
        simulationResult.RunDirectory,"simulation_summary.json")));
    prr(index) = cellularPacketReceptionRatio(summary);
    summaries{index} = summary;
    simulationResults{index} = simulationResult;
end

caseTable = table(caseNames,pathLossModels,packetErrorModels,rayleigh,prr, ...
    VariableNames=["Case","PathLoss","PacketError","Rayleigh","Prr"]);
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

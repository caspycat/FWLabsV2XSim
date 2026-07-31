%% 15 - Compare periodic and ETSI-CAM application traffic

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Cases)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"15_application_traffic.toml");
outputDirectory = string(tempname);
template = v2xsim.config.load(configurationFile);
caseNames = ["periodic";"etsi-cam-dcc"];
generationModes = ["Periodic";"EtsiCam"];
congestionControl = [false;true];
prr = zeros(2,1);
summaries = cell(2,1);
simulationResults = cell(2,1);

for index = 1:2
    generation = struct(Mode=generationModes(index));
    if generationModes(index) == "EtsiCam"
        generation.Cam = struct( ...
            IntervalDiscretization="AllocationAligned", ...
            MaximumIntervalIncreasePercent=20);
    end
    application = struct( ...
        PacketGeneration=generation, ...
        CongestionControl=struct( ...
            Enabled=congestionControl(index), ...
            ChannelOccupancyLimitScale=1));
    patch = v2xsim.config.patch(struct(Application=application));
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

caseTable = table(caseNames,generationModes,congestionControl,prr, ...
    VariableNames=["Case","GenerationMode","CongestionControl","Prr"]);
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

%% 14 - Compare path-loss, fading, and packet-error models

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Cases)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","14_channel_models.toml");
projectRoot = fileparts(fileparts(exampleDirectory));
curveDirectory = fullfile( ...
    projectRoot,"resources","per-curves","G5-HighwayLOS");
outputDirectory = string(tempname);
caseNames = ["winner-threshold";"single-threshold";"winner-curves"];
pathLossModels = ["WinnerPlusB1";"SingleSlope";"WinnerPlusB1"];
packetErrorModels = ["Threshold";"Threshold";"Curves"];
rayleigh = [false;false;true];
prr = zeros(3,1);
summaries = cell(3,1);

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
    patch = struct(Channel=struct( ...
        RayleighFadingEnabled=rayleigh(index), ...
        PathLoss=pathLoss,PacketError=packetError));
    [summary,~] = runV7ExampleSimulation( ...
        configurationFile,fullfile(outputDirectory,caseNames(index)), ...
        patch,caseNames(index));
    prr(index) = cellularPacketReceptionRatio(summary);
    summaries{index} = summary;
end

caseTable = table(caseNames,pathLossModels,packetErrorModels,rayleigh,prr, ...
    VariableNames=["Case","PathLoss","PacketError","Rayleigh","Prr"]);
elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Cases=caseTable,Summaries={summaries}, ...
    ElapsedSeconds=elapsedSeconds);
end

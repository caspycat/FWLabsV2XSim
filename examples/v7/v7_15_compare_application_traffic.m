%% 15 - Compare periodic and ETSI-CAM application traffic

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Cases)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","15_application_traffic.toml");
outputDirectory = string(tempname);
caseNames = ["periodic";"etsi-cam-dcc"];
generationModes = ["Periodic";"EtsiCam"];
congestionControl = [false;true];
prr = zeros(2,1);
summaries = cell(2,1);

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
    [summary,~] = runV7ExampleSimulation( ...
        configurationFile,fullfile(outputDirectory,caseNames(index)), ...
        struct(Application=application),caseNames(index));
    prr(index) = cellularPacketReceptionRatio(summary);
    summaries{index} = summary;
end

caseTable = table(caseNames,generationModes,congestionControl,prr, ...
    VariableNames=["Case","GenerationMode","CongestionControl","Prr"]);
elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Cases=caseTable,Summaries={summaries}, ...
    ElapsedSeconds=elapsedSeconds);
end

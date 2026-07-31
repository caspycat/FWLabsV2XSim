%% 11 - Compare LTE-V2X Mode 3 and Mode 4

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Modes)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","11_lte_modes.toml");
outputDirectory = string(tempname);
modeNames = ["Mode 3";"Mode 4"];
allocatorTypes = ["MaximumReuseDistance";"SensingBased"];
categories = strings(2,1);
prr = zeros(2,1);
summaries = cell(2,1);

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
    [summary,~] = runV7ExampleSimulation( ...
        configurationFile,fullfile(outputDirectory,compose("case-%d",index)), ...
        struct(ResourceAllocation=allocation),modeNames(index));
    metadata = summary.Configuration.ResourceAllocation.Metadata;
    categories(index) = string(metadata.Category);
    prr(index) = cellularPacketReceptionRatio(summary);
    summaries{index} = summary;
end

modeTable = table(modeNames,allocatorTypes,categories,prr, ...
    VariableNames=["Mode","Allocator","Category","PacketReceptionRatio"]);
elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Modes=modeTable,Summaries={summaries}, ...
    ElapsedSeconds=elapsedSeconds);
end

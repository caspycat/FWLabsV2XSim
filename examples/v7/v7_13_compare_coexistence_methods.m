%% 13 - Run every public coexistence method

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Methods)
fprintf("Completed outputs: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","13_coexistence_methods.toml");
outputDirectory = string(tempname);
methods = ["Standard";"MethodA";"MethodB";"MethodC";"MethodF"];
prr11p = zeros(numel(methods),1);
prrCellular = zeros(numel(methods),1);
summaries = cell(numel(methods),1);

for index = 1:numel(methods)
    method = methods(index);
    coexistence = struct(Method=method);
    if method ~= "Standard"
        coexistence.(method) = methodOptions(method);
    end
    [summary,~] = runV7ExampleSimulation( ...
        configurationFile,fullfile(outputDirectory,method), ...
        struct(Coexistence=coexistence),method);
    prr11p(index) = awarenessPrr(summary.Results.Ieee80211p);
    prrCellular(index) = ...
        awarenessPrr(summary.Results.CellularSidelink);
    summaries{index} = summary;
end

methodTable = table(methods,prr11p,prrCellular, ...
    VariableNames=["Method","Ieee80211pPrr","CellularPrr"]);
elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Methods=methodTable,Summaries={summaries}, ...
    ElapsedSeconds=elapsedSeconds);
end

function options = methodOptions(method)
switch method
    case "MethodA"
        options = struct(EnhancementVariant=1);
    case "MethodB"
        options = struct(AllNodesTransmitInEmptySubframes=true);
    case "MethodC"
        options = struct(TimeGapVariant=1);
    case "MethodF"
        options = struct(GuardIntervalEnabled=true);
end
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

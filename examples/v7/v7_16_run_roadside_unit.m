%% 16 - Run a fixed IEEE DENM roadside unit

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.RoadsideUnitFates)
fprintf("Completed output: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","16_roadside_unit.toml");
outputDirectory = string(tempname);
[summary,simulationElapsedSeconds] = runV7ExampleSimulation( ...
    configurationFile,outputDirectory,struct(),"roadside-unit");

chunks = dir(fullfile(outputDirectory,"packet_fates_*.csv"));
parts = arrayfun(@(file) readtable( ...
    fullfile(file.folder,file.name),TextType="string"), ...
    chunks,UniformOutput=false);
fates = vertcat(parts{:});
rsuMask = fates.TransmitterUeId == "rsu-west" | ...
    fates.ReceiverUeId == "rsu-west";
roadsideUnitFates = fates(rsuMask,:);
assert(~isempty(roadsideUnitFates), ...
    "The RSU example produced no directed RSU packet fates.");

elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Summary=summary,RoadsideUnitFates=roadsideUnitFates, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

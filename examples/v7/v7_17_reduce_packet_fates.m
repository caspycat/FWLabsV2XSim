%% 17 - Reduce terminal packet fates with the public analysis API

exampleScriptDirectory = fileparts(mfilename("fullpath"));
[exampleResults,exampleOutputDirectory] = runExample(exampleScriptDirectory);
clear exampleScriptDirectory

disp(exampleResults.Curve)
fprintf("Completed output: %s\n",exampleOutputDirectory);

function [results,outputDirectory] = runExample(exampleDirectory)
timer = tic;
configurationFile = fullfile( ...
    exampleDirectory,"config","05_output_artifacts.toml");
outputDirectory = string(tempname);
[summary,simulationElapsedSeconds] = runV7ExampleSimulation( ...
    configurationFile,outputDirectory,struct(),"analysis-api");

chunks = dir(fullfile(outputDirectory,"packet_fates_*.csv"));
parts = arrayfun(@(file) readtable( ...
    fullfile(file.folder,file.name),TextType="string"), ...
    chunks,UniformOutput=false);
observations = vertcat(parts{:});
terminalFates = v2xsim.analysis.aggregateTerminalPacketFates(observations);
distanceGrid = (25:25:150).';
curve = v2xsim.analysis.packetReceptionCurve( ...
    terminalFates,distanceGrid);
score = v2xsim.analysis.normalizedPrrAuc( ...
    curve,150,RequireNonemptyBins=false);

elapsedSeconds = toc(timer);
warnIfSlowV7Example(elapsedSeconds);
results = struct(Summary=summary,TerminalFates=terminalFates, ...
    Curve=curve,NormalizedPrrAuc=score, ...
    SimulationElapsedSeconds=simulationElapsedSeconds, ...
    ElapsedSeconds=elapsedSeconds);
end

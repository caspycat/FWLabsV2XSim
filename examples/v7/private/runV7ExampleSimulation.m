function [summary, elapsedSeconds] = runV7ExampleSimulation( ...
        configurationFile, outputDirectory, patchData, runLabel)
%RUNV7EXAMPLESIMULATION Run one isolated V7 example simulation.

arguments (Input)
    configurationFile (1,1) string
    outputDirectory (1,1) string
    patchData (1,1) struct = struct()
    runLabel (1,1) string = ""
end

if ~isfile(configurationFile)
    error( ...
        "v2xsimexample:ConfigurationNotFound", ...
        "Example configuration was not found: %s", ...
        configurationFile);
end
if ismissing(outputDirectory) || strlength(outputDirectory) == 0
    error( ...
        "v2xsimexample:InvalidOutputDirectory", ...
        "The example output directory must be nonempty.");
end

privateDirectory = fileparts(mfilename("fullpath"));
projectRoot = fileparts(fileparts(fileparts(privateDirectory)));
sourceDirectory = fullfile(projectRoot,"src");
tomlDirectory = fullfile(projectRoot,"lib","matlab-toml");
if ~isfile(fullfile(sourceDirectory,"+v2xsim","runSimulation.m"))
    error( ...
        "v2xsimexample:SimulatorNotFound", ...
        "v2xsim.runSimulation was not found below %s.", projectRoot);
end

originalPath = path;
originalStream = RandStream.getGlobalStream();
originalStreamState = originalStream.State;
originalWarningState = warning;
stateCleanup = onCleanup(@() restoreProcessState( ...
    originalPath, originalStream, originalStreamState, ...
    originalWarningState));

addpath(sourceDirectory);
addpath(tomlDirectory);

template = v2xsim.config.load(configurationFile);
if isempty(fieldnames(patchData))
    configuration = template.resolve();
else
    configuration = template.resolve( ...
        Patch=v2xsim.config.patch(patchData));
end
timer = tic;
v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory=outputDirectory, ...
    RunLabel=runLabel);
elapsedSeconds = toc(timer);

summaryFile = fullfile(outputDirectory,"simulation_summary.json");
if ~isfile(summaryFile)
    error( ...
        "v2xsimexample:MissingCompletionSummary", ...
        "The example did not publish its completion summary: %s", ...
        summaryFile);
end
summary = jsondecode(fileread(summaryFile));
end

function restoreProcessState( ...
        originalPath, originalStream, originalStreamState, ...
        originalWarningState)
path(originalPath);
RandStream.setGlobalStream(originalStream);
originalStream.State = originalStreamState;
warning(originalWarningState);
end

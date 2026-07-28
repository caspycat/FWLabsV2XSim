function outputFile = writeSimulationSummary(outputDirectory, summary)
%WRITESIMULATIONSUMMARY Atomically publish simulation_summary.json.
%   The JSON is first written to a temporary file in OUTPUTDIRECTORY and
%   then renamed. Existing summaries are never overwritten.

arguments (Input)
    outputDirectory (1, 1) string {mustBeFolder}
    summary (1, 1) struct
end

outputFile = fullfile(outputDirectory, "simulation_summary.json");
if isfile(outputFile) || isfolder(outputFile)
    error( ...
        "v2xsim:output:SummaryAlreadyExists", ...
        "Simulation summary already exists at ""%s"".",outputFile);
end

temporaryFile = string(tempname(outputDirectory)) + ".json";
temporaryFileCleanup = onCleanup(@() deleteIfPresent(temporaryFile));
writestruct( ...
    summary, temporaryFile, ...
    FileType="json", ...
    PrettyPrint=true, ...
    PreserveInfAndNaN=false);

[moved, message] = movefile(temporaryFile, outputFile);
if ~moved
    error( ...
        "v2xsim:output:SummaryPublicationFailed", ...
        "Could not publish simulation summary ""%s"": %s", ...
        outputFile, message);
end
clear temporaryFileCleanup
end

function deleteIfPresent(file)
if isfile(file)
    delete(file);
end
end

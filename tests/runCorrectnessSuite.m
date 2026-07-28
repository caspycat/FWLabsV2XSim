function [results, coverageDirectory] = runCorrectnessSuite(options)
%RUNCORRECTNESSSUITE Run V7 tests and produce an HTML coverage report.
%   RESULTS = RUNCORRECTNESSSUITE runs every test below the tests folder,
%   prefers decision coverage for src/+v2xsim (falling back to statement
%   coverage when MATLAB Test is unavailable), and fails when any test is
%   unsuccessful.
%
%   [RESULTS,COVERAGEDIRECTORY] = RUNCORRECTNESSSUITE(...) also returns the
%   directory containing the generated HTML report. By default, that
%   directory is outside the repository.

arguments (Input)
    options.CoverageDirectory (1,1) string = ""
    options.CoverageMetric (1,1) string {mustBeMember( ...
        options.CoverageMetric, ...
        ["auto","statement","decision","condition","mcdc"])} = "auto"
    options.IncludeRegressionTests (1,1) logical = false
end

arguments (Output)
    results (1,:) matlab.unittest.TestResult
    coverageDirectory (1,1) string
end

projectRoot = string(fileparts(fileparts(mfilename("fullpath"))));
testsRoot = fullfile(projectRoot,"tests");
sourceParent = fullfile(projectRoot,"src");
sourceRoot = fullfile(sourceParent,"+v2xsim");
legacyRoot = fullfile(projectRoot,"old_src");
regressionRoot = fullfile(projectRoot,"regression-tests");

originalPath = path;
originalWorkingDirectory = string(pwd);
originalStream = RandStream.getGlobalStream();
originalStreamState = originalStream.State;
originalWarningState = warning;
processStateCleanup = onCleanup(@() restoreProcessState( ...
    originalPath,originalWorkingDirectory, ...
    originalStream,originalStreamState,originalWarningState));
addpath(sourceParent);
addpath(testsRoot);
addpath(genpath(legacyRoot));

suite = matlab.unittest.TestSuite.fromFolder( ...
    testsRoot, IncludingSubfolders=true);
if options.IncludeRegressionTests
    addpath(regressionRoot);
    regressionSuite = matlab.unittest.TestSuite.fromFolder( ...
        regressionRoot, IncludingSubfolders=true);
    suite = [suite,regressionSuite];
end
if isempty(suite)
    error( ...
        "v2xsimtest:correctness:NoTestsDiscovered", ...
        "No tests were discovered below %s.", testsRoot);
end

if strlength(options.CoverageDirectory) == 0
    coverageDirectory = string(tempname) + "-v2xsim-coverage";
else
    coverageDirectory = ...
        absolutePath(options.CoverageDirectory, projectRoot);
end

coverageFormat = ...
    matlab.unittest.plugins.codecoverage.CoverageReport( ...
        coverageDirectory);
selectedCoverageMetric = options.CoverageMetric;
if selectedCoverageMetric == "auto"
    selectedCoverageMetric = "decision";
end
try
    coveragePlugin = createCoveragePlugin( ...
        sourceRoot,coverageFormat,selectedCoverageMetric);
catch cause
    if options.CoverageMetric ~= "auto" || ...
            string(cause.identifier) ~= ...
            "MATLAB:unittest:CodeCoveragePlugin:InvalidMetric"
        rethrow(cause);
    end
    selectedCoverageMetric = "statement";
    warning( ...
        "v2xsimtest:correctness:DecisionCoverageUnavailable", ...
        "Decision coverage requires MATLAB Test. " + ...
        "Falling back to statement coverage.");
    coveragePlugin = createCoveragePlugin( ...
        sourceRoot,coverageFormat,selectedCoverageMetric);
end

runner = matlab.unittest.TestRunner.withTextOutput;
runner.addPlugin(coveragePlugin);
fprintf( ...
    "Running %d tests with %s coverage. Report: %s\n", ...
    numel(suite), selectedCoverageMetric, coverageDirectory);
results = runner.run(suite);
assertSuccess(results);
end

function plugin = createCoveragePlugin( ...
        sourceRoot,coverageFormat,coverageMetric)
plugin = matlab.unittest.plugins.CodeCoveragePlugin.forFolder( ...
    sourceRoot, ...
    IncludingSubfolders=true, ...
    Producing=coverageFormat, ...
    MetricLevel=coverageMetric);
end

function restoreProcessState( ...
        originalPath,originalWorkingDirectory, ...
        originalStream,originalStreamState,originalWarningState)
path(originalPath);
cd(originalWorkingDirectory);
RandStream.setGlobalStream(originalStream);
originalStream.State = originalStreamState;
warning(originalWarningState);
end

function pathValue = absolutePath(pathValue, projectRoot)
if ismissing(pathValue) || strlength(pathValue) == 0
    error( ...
        "v2xsimtest:correctness:InvalidCoverageDirectory", ...
        "CoverageDirectory must be a nonmissing, nonempty path.");
end
if ~isAbsolute(pathValue)
    pathValue = fullfile(projectRoot,pathValue);
end
end

function tf = isAbsolute(pathValue)
if ispc
    tf = ~isempty(regexp(pathValue,"^[A-Za-z]:[\\/]|^\\\\","once"));
else
    tf = startsWith(pathValue,"/");
end
end

function [results, coverageDirectory] = runCorrectnessSuite(options)
%RUNCORRECTNESSSUITE Run V7 tests and produce an HTML coverage report.
%   RESULTS = RUNCORRECTNESSSUITE runs every test below the tests folder,
%   uses all workers exposed by the local Processes profile when parallel
%   capability is available, prefers decision coverage for src/+v2xsim
%   (falling back to statement coverage when MATLAB Test is unavailable),
%   and fails when any test is unsuccessful.
%
%   IncludeRegressionTests=true adds routine regressions and shortened
%   conclusion-level publication campaigns. Full-duration registered
%   campaigns tagged PublicationCampaign remain excluded unless
%   IncludePublicationCampaigns=true is also supplied.
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
    options.IncludePublicationCampaigns (1,1) logical = false
    options.ExecutionMode (1,1) string {mustBeMember( ...
        options.ExecutionMode, ["auto","serial","parallel"])} = "auto"
end

arguments (Output)
    results (1,:) matlab.unittest.TestResult
    coverageDirectory (1,1) string
end

if options.IncludePublicationCampaigns && ...
        ~options.IncludeRegressionTests
    error( ...
        "v2xsimtest:correctness:" + ...
        "PublicationCampaignsRequireRegressionTests", ...
        "IncludePublicationCampaigns=true requires " + ...
        "IncludeRegressionTests=true.");
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

ordinarySuite = matlab.unittest.TestSuite.fromFolder( ...
    testsRoot, IncludingSubfolders=true);
regressionSuite = matlab.unittest.TestSuite.empty;
if options.IncludeRegressionTests
    addpath(regressionRoot);
    regressionSuite = matlab.unittest.TestSuite.fromFolder( ...
        regressionRoot, IncludingSubfolders=true);
    [regressionSuite,excludedPublicationCampaignCount] = ...
        v2xsimtest.execution.selectRegressionCampaigns( ...
            regressionSuite,options.IncludePublicationCampaigns);
    if excludedPublicationCampaignCount > 0
        fprintf( ...
            "Excluded %d registered PublicationCampaign test(s). " + ...
            "Set IncludePublicationCampaigns=true to include them.\n", ...
            excludedPublicationCampaignCount);
    end
end
if isempty(ordinarySuite)
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

selectedCoverageMetric = selectCoverageMetric( ...
    options.CoverageMetric,sourceRoot);
[useParallel,pool,poolCleanup] = prepareExecution( ...
    options.ExecutionMode);
if useParallel
    fprintf( ...
        "Using %d workers from process pool profile %s.\n", ...
        pool.NumWorkers,string(pool.Cluster.Profile));
else
    fprintf("Using serial test execution.\n");
end

[ordinaryResults,coverageResults] = runSuiteWithCoverage( ...
    ordinarySuite,sourceRoot,selectedCoverageMetric,useParallel, ...
    "ordinary");
results = ordinaryResults;
if options.IncludeRegressionTests && ~isempty(regressionSuite)
    % Regression methods launch process-parallel campaign work themselves.
    % Keep their outer test layer on the client to avoid nested pools while
    % allowing runWorkItems to reuse the full profile-sized process pool.
    [regressionResults,regressionCoverageResults] = ...
        runSuiteWithCoverage( ...
            regressionSuite,sourceRoot,selectedCoverageMetric,false, ...
            "regression");
    results = [results,regressionResults];
    coverageResults = coverageResults + regressionCoverageResults;
end

generateHTMLReport( ...
    coverageResults,coverageDirectory, ...
    MetricLevel=selectedCoverageMetric);
fprintf("Coverage report: %s\n",coverageDirectory);
assertSuccess(results);
poolCleanup; %#ok<VUNUS>
end

function plugin = createCoveragePlugin( ...
        sourceRoot,coverageFormat,coverageMetric)
plugin = matlab.unittest.plugins.CodeCoveragePlugin.forFolder( ...
    sourceRoot, ...
    IncludingSubfolders=true, ...
    Producing=coverageFormat, ...
    MetricLevel=coverageMetric);
end

function coverageMetric = selectCoverageMetric( ...
        requestedCoverageMetric,sourceRoot)
coverageMetric = requestedCoverageMetric;
if coverageMetric == "auto"
    coverageMetric = "decision";
end

try
    coverageFormat = ...
        matlab.unittest.plugins.codecoverage.CoverageResult;
    createCoveragePlugin(sourceRoot,coverageFormat,coverageMetric);
catch cause
    if requestedCoverageMetric ~= "auto" || ...
            string(cause.identifier) ~= ...
            "MATLAB:unittest:CodeCoveragePlugin:InvalidMetric"
        rethrow(cause);
    end
    coverageMetric = "statement";
    warning( ...
        "v2xsimtest:correctness:DecisionCoverageUnavailable", ...
        "Decision coverage requires MATLAB Test. " + ...
        "Falling back to statement coverage.");
end
end

function [results,coverageResults] = runSuiteWithCoverage( ...
        suite,sourceRoot,coverageMetric,useParallel,suiteLabel)
coverageFormat = ...
    matlab.unittest.plugins.codecoverage.CoverageResult;
coveragePlugin = createCoveragePlugin( ...
    sourceRoot,coverageFormat,coverageMetric);
runner = matlab.unittest.TestRunner.withTextOutput;
runner.addPlugin(coveragePlugin);
fprintf( ...
    "Running %d %s tests with %s coverage.\n", ...
    numel(suite),suiteLabel,coverageMetric);
if useParallel
    results = runner.runInParallel(suite);
else
    results = runner.run(suite);
end
coverageResults = coverageFormat.Result;
end

function [useParallel,pool,poolCleanup] = prepareExecution(executionMode)
useParallel = false;
pool = [];
poolCleanup = onCleanup.empty;
if executionMode == "serial"
    return
end

if ~parallelComputingIsAvailable()
    if executionMode == "parallel"
        error( ...
            "v2xsimtest:correctness:ParallelUnavailable", ...
            "Parallel execution requires an available Parallel " + ...
            "Computing Toolbox license.");
    end
    warning( ...
        "v2xsimtest:correctness:ParallelUnavailable", ...
        "Parallel Computing Toolbox is unavailable; running serially.");
    return
end

pool = gcp("nocreate");
if ~isempty(pool)
    if isa(pool,"parallel.ProcessPool")
        useParallel = true;
        return
    end
    message = compose( ...
        "Parallel correctness testing requires a process pool; " + ...
        "the caller owns a %s pool.",class(pool));
    if executionMode == "parallel"
        error( ...
            "v2xsimtest:correctness:ProcessPoolRequired", ...
            "%s",message);
    end
    warning( ...
        "v2xsimtest:correctness:ProcessPoolRequired", ...
        "%s Running serially.",message);
    pool = [];
    return
end

try
    cluster = parcluster("Processes");
    % Request the profile's configured capacity explicitly. Calling
    % parpool(cluster) may instead honor PreferredPoolNumWorkers, which can
    % be lower than NumWorkers and would then constrain publication
    % campaigns that reuse this caller-owned pool.
    pool = parpool(cluster,cluster.NumWorkers);
    poolCleanup = onCleanup(@() delete(pool));
    useParallel = true;
catch cause
    pool = [];
    if executionMode == "parallel"
        exception = MException( ...
            "v2xsimtest:correctness:ParallelStartupFailed", ...
            "Could not start the Processes profile for parallel tests.");
        throwAsCaller(addCause(exception,cause));
    end
    warning( ...
        "v2xsimtest:correctness:ParallelStartupFailed", ...
        "Could not start the Processes profile (%s); running serially.", ...
        cause.message);
end
end

function tf = parallelComputingIsAvailable()
tf = ~isempty(ver("parallel")) && ...
    license("test","Distrib_Computing_Toolbox");
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

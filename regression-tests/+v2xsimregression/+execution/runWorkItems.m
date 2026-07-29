function outputs = runWorkItems(workItems, workerFunction, options)
%RUNWORKITEMS Execute independent regression work in a stable order.
%   The parallel backend intentionally uses process workers. Simulations
%   change process-wide MATLAB state and are not safe on a thread pool.

arguments (Input)
    workItems (1, :) cell
    workerFunction (1, 1) function_handle
    options.Labels (1, :) string = compose("work-item-%d", 1:numel(workItems))
    options.ExecutionMode (1, 1) string {mustBeMember( ...
        options.ExecutionMode, ["auto", "serial", "parallel"])} = "auto"
    options.MaxWorkers (1, 1) double { ...
        v2xsimregression.execution.mustBeWorkerLimit} = Inf
    options.AdditionalPaths (1, :) string = strings(1, 0)
    options.EnvironmentVariableNames (1, :) string = strings(1, 0)
    options.CollectAllFailures (1, 1) logical = false
end

arguments (Output)
    outputs (1, :) cell
end

if numel(options.Labels) ~= numel(workItems)
    error( ...
        "v2xsimregression:execution:WrongLabelCount", ...
        "Labels must contain one value for every work item.");
end
if any(ismissing(options.EnvironmentVariableNames)) || ...
        any(strlength(options.EnvironmentVariableNames) == 0)
    error( ...
        "v2xsimregression:execution:InvalidEnvironmentVariableName", ...
        "EnvironmentVariableNames must contain nonempty names.");
end
environmentVariableNames = unique( ...
    options.EnvironmentVariableNames, "stable");
additionalPaths = resolveAdditionalPaths(options.AdditionalPaths);

outputs = cell(size(workItems));
if isempty(workItems)
    return
end

if options.ExecutionMode == "serial"
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures);
    return
end

if ~parallelComputingIsAvailable()
    if options.ExecutionMode == "parallel"
        error( ...
            "v2xsimregression:execution:ParallelUnavailable", ...
            "Parallel execution requires an available Parallel " + ...
            "Computing Toolbox license.");
    end
    warnParallelFallback( ...
        "Parallel Computing Toolbox is unavailable; running serially.");
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures);
    return
end

if isscalar(workItems) || options.MaxWorkers == 1
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures);
    return
end

try
    [pool, poolCleanup] = acquireProcessPool( ...
        numel(workItems), options.MaxWorkers);
catch cause
    if options.ExecutionMode == "parallel"
        exception = MException( ...
            "v2xsimregression:execution:ParallelStartupFailed", ...
            "Could not obtain a local process pool.");
        throwAsCaller(addCause(exception, cause));
    end
    warnParallelFallback(compose( ...
        "Could not obtain a local process pool (%s); running serially.", ...
        cause.message));
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures);
    return
end

requestedWorkers = min([ ...
    options.MaxWorkers, numel(workItems), pool.NumWorkers]);
parallelOptions = parforOptions( ...
    pool, ...
    MaxNumWorkers=requestedWorkers);
workLabels = options.Labels;
if options.CollectAllFailures
    captured = cell(size(workItems));
    parfor (workIndex = 1:numel(workItems), parallelOptions)
        captured{workIndex} = executeCaptured( ...
            workItems{workIndex}, workerFunction, ...
            workLabels(workIndex), additionalPaths, ...
            environmentVariableNames);
    end
    outputs = unwrapCaptured(captured);
else
    parfor (workIndex = 1:numel(workItems), parallelOptions)
        outputs{workIndex} = executeSafely( ...
            workItems{workIndex}, workerFunction, ...
            workLabels(workIndex), additionalPaths, ...
            environmentVariableNames);
    end
end
retainCleanup(poolCleanup);
end

function outputs = runSerial( ...
        workItems, workerFunction, labels, ...
        additionalPaths, environmentVariableNames, collectAllFailures)
outputs = cell(size(workItems));
if collectAllFailures
    captured = cell(size(workItems));
    for workIndex = 1:numel(workItems)
        captured{workIndex} = executeCaptured( ...
            workItems{workIndex}, workerFunction, labels(workIndex), ...
            additionalPaths, environmentVariableNames);
    end
    outputs = unwrapCaptured(captured);
    return
end

for workIndex = 1:numel(workItems)
    outputs{workIndex} = executeSafely( ...
        workItems{workIndex}, workerFunction, labels(workIndex), ...
        additionalPaths, environmentVariableNames);
end
end

function captured = executeCaptured( ...
        workItem, workerFunction, label, additionalPaths, ...
        environmentVariableNames)
try
    output = executeSafely( ...
        workItem, workerFunction, label, additionalPaths, ...
        environmentVariableNames);
    captured = {true, output, []};
catch exception
    captured = {false, [], exception};
end
end

function outputs = unwrapCaptured(captured)
outputs = cell(size(captured));
failed = false(size(captured));
for workIndex = 1:numel(captured)
    failed(workIndex) = ~captured{workIndex}{1};
    if ~failed(workIndex)
        outputs{workIndex} = captured{workIndex}{2};
    end
end

failureIndices = find(failed);
if isempty(failureIndices)
    return
end
if isscalar(failureIndices)
    throwAsCaller(captured{failureIndices}{3});
end

exception = MException( ...
    "v2xsimregression:execution:MultipleWorkItemsFailed", ...
    "%d regression work items failed. See the ordered causes for labels.", ...
    numel(failureIndices));
for failureIndex = failureIndices
    exception = addCause(exception, captured{failureIndex}{3});
end
throwAsCaller(exception);
end

function output = executeSafely( ...
        workItem, workerFunction, label, additionalPaths, ...
        environmentVariableNames)
originalPath = path;
originalWorkingDirectory = string(pwd);
originalStream = RandStream.getGlobalStream();
originalStreamState = originalStream.State;
originalWarningState = warning;
originalEnvironmentValues = cell(size(environmentVariableNames));
for variableIndex = 1:numel(environmentVariableNames)
    originalEnvironmentValues{variableIndex} = getenv( ...
        environmentVariableNames(variableIndex));
end
environmentCleanup = onCleanup(@() restoreEnvironment( ...
    originalPath, originalWorkingDirectory, ...
    originalStream, originalStreamState, ...
    originalWarningState, environmentVariableNames, ...
    originalEnvironmentValues));
for pathIndex = numel(additionalPaths):-1:1
    addpath(additionalPaths(pathIndex));
end

try
    output = workerFunction(workItem);
catch cause
    exception = MException( ...
        "v2xsimregression:execution:WorkItemFailed", ...
        "Regression work item failed: %s.", label);
    throw(addCause(exception, cause));
end

end

function additionalPaths = resolveAdditionalPaths(additionalPaths)
if any(ismissing(additionalPaths)) || ...
        any(strlength(additionalPaths) == 0)
    error( ...
        "v2xsimregression:execution:InvalidAdditionalPath", ...
        "AdditionalPaths must contain nonempty folder paths.");
end
for pathIndex = 1:numel(additionalPaths)
    pathValue = additionalPaths(pathIndex);
    if ~isAbsolutePath(pathValue)
        pathValue = fullfile(pwd,pathValue);
    end
    if ~isfolder(pathValue)
        error( ...
            "v2xsimregression:execution:InvalidAdditionalPath", ...
            "Additional path is not an existing folder: %s", ...
            pathValue);
    end
    additionalPaths(pathIndex) = pathValue;
end
additionalPaths = unique(additionalPaths, "stable");
end

function tf = isAbsolutePath(pathValue)
if ispc
    tf = ~isempty(regexp( ...
        pathValue,"^[A-Za-z]:[\\/]|^\\\\","once"));
else
    tf = startsWith(pathValue,"/");
end
end

function [pool, cleanup] = acquireProcessPool(workItemCount, maxWorkers)
pool = gcp("nocreate");
if ~isempty(pool) && isa(pool, "parallel.ProcessPool")
    cleanup = onCleanup.empty;
    return
end

cluster = parcluster("Processes");
workerCount = min([workItemCount, maxWorkers, cluster.NumWorkers]);
pool = parpool(cluster, workerCount);
cleanup = onCleanup(@() delete(pool));
end

function tf = parallelComputingIsAvailable()
tf = ~isempty(ver("parallel")) && ...
    license("test", "Distrib_Computing_Toolbox");
end

function warnParallelFallback(message)
persistent hasWarned
if isempty(hasWarned) || ~hasWarned
    warning( ...
        "v2xsimregression:execution:ParallelUnavailable", ...
        "%s", message);
    hasWarned = true;
end
end

function restoreEnvironment( ...
        originalPath, originalWorkingDirectory, ...
        originalStream, originalStreamState, ...
        originalWarningState, environmentVariableNames, ...
        originalEnvironmentValues)
cd(originalWorkingDirectory);
path(originalPath);
RandStream.setGlobalStream(originalStream);
originalStream.State = originalStreamState;
warning(originalWarningState);
for variableIndex = 1:numel(environmentVariableNames)
    setenv( ...
        environmentVariableNames(variableIndex), ...
        originalEnvironmentValues{variableIndex});
end
end

function retainCleanup(~)
% Keep a scheduler-owned pool cleanup alive until parallel work completes.
end

function outputs = runWorkItems(workItems, workerFunction, options)
%RUNWORKITEMS Execute independent regression work in a stable order.
%   The parallel backend intentionally uses process workers. WiLabV2Xsim
%   changes process-wide MATLAB state and is not safe on a thread pool.

arguments (Input)
    workItems (1, :) cell
    workerFunction (1, 1) function_handle
    options.Labels (1, :) string = compose("work-item-%d", 1:numel(workItems))
    options.ExecutionMode (1, 1) string {mustBeMember( ...
        options.ExecutionMode, ["auto", "serial", "parallel"])} = "auto"
    options.MaxWorkers (1, 1) double { ...
        v2xsimregression.execution.mustBeWorkerLimit} = Inf
    options.AdditionalPaths (1, :) string = strings(1, 0)
end

arguments (Output)
    outputs (1, :) cell
end

if numel(options.Labels) ~= numel(workItems)
    error( ...
        "v2xsimregression:execution:WrongLabelCount", ...
        "Labels must contain one value for every work item.");
end

outputs = cell(size(workItems));
if isempty(workItems)
    return
end

if options.ExecutionMode == "serial"
    outputs = runSerial(workItems, workerFunction, options.Labels);
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
    outputs = runSerial(workItems, workerFunction, options.Labels);
    return
end

if isscalar(workItems) || options.MaxWorkers == 1
    outputs = runSerial(workItems, workerFunction, options.Labels);
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
    outputs = runSerial(workItems, workerFunction, options.Labels);
    return
end

requestedWorkers = min([ ...
    options.MaxWorkers, numel(workItems), pool.NumWorkers]);
parallelOptions = parforOptions( ...
    pool, ...
    MaxNumWorkers=requestedWorkers, ...
    AdditionalPaths=options.AdditionalPaths);
workLabels = options.Labels;
parfor (workIndex = 1:numel(workItems), parallelOptions)
    outputs{workIndex} = executeSafely( ...
        workItems{workIndex}, workerFunction, ...
        workLabels(workIndex));
end
retainCleanup(poolCleanup);
end

function outputs = runSerial(workItems, workerFunction, labels)
outputs = cell(size(workItems));
for workIndex = 1:numel(workItems)
    outputs{workIndex} = executeSafely( ...
        workItems{workIndex}, workerFunction, labels(workIndex));
end
end

function output = executeSafely(workItem, workerFunction, label)
originalPath = path;
originalStream = RandStream.getGlobalStream();
originalStreamState = originalStream.State;
environmentCleanup = onCleanup(@() restoreEnvironment( ...
    originalPath, originalStream, originalStreamState));

try
    output = workerFunction(workItem);
catch cause
    exception = MException( ...
        "v2xsimregression:execution:WorkItemFailed", ...
        "Regression work item failed: %s.", label);
    throw(addCause(exception, cause));
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

function restoreEnvironment(originalPath, originalStream, originalStreamState)
path(originalPath);
RandStream.setGlobalStream(originalStream);
originalStream.State = originalStreamState;
end

function retainCleanup(~)
% Keep a scheduler-owned pool cleanup alive until parallel work completes.
end

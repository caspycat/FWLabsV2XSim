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
    options.ProgressLogFile (1, 1) string = ""
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
progressLogFile = resolveProgressLogFile(options.ProgressLogFile);
workerAcceptsProgress = workerFunctionAcceptsProgress(workerFunction);
parallelAvailable = false;
if ~isempty(workItems) && options.ExecutionMode ~= "serial"
    parallelAvailable = parallelComputingIsAvailable();
    if options.ExecutionMode == "parallel" && ~parallelAvailable
        error( ...
            "v2xsimregression:execution:ParallelUnavailable", ...
            "Parallel execution requires an available Parallel " + ...
            "Computing Toolbox license.");
    end
end
progressJournal = createProgressJournal( ...
    progressLogFile, numel(workItems));
recordQueuedWorkItems(progressJournal, options.Labels);

outputs = cell(size(workItems));
if isempty(workItems)
    return
end

if options.ExecutionMode == "serial"
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures, workerAcceptsProgress, ...
        progressJournal);
    return
end

if ~parallelAvailable
    warnParallelFallback( ...
        "Parallel Computing Toolbox is unavailable; running serially.");
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures, workerAcceptsProgress, ...
        progressJournal);
    return
end

if options.ExecutionMode == "auto" && (isscalar(workItems) || options.MaxWorkers == 1)
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures, workerAcceptsProgress, ...
        progressJournal);
    return
end

try
    [pool, poolCleanup] = acquireProcessPool( ...
        options.MaxWorkers);
catch cause
    if options.ExecutionMode == "parallel"
        exception = MException( ...
            "v2xsimregression:execution:ParallelStartupFailed", ...
            "Could not obtain a process pool.");
        throwAsCaller(addCause(exception, cause));
    end
    warnParallelFallback(compose( ...
        "Could not obtain a process pool (%s); running serially.", ...
        cause.message));
    outputs = runSerial( ...
        workItems, workerFunction, options.Labels, ...
        additionalPaths, environmentVariableNames, ...
        options.CollectAllFailures, workerAcceptsProgress, ...
        progressJournal);
    return
end

requestedWorkers = min(options.MaxWorkers,pool.NumWorkers);
parallelOptions = parforOptions( ...
    pool, ...
    MaxNumWorkers=requestedWorkers);
workLabels = options.Labels;
[progressTarget, progressListener] = createParallelProgressTarget( ...
    progressJournal);
progressFlushCleanup = onCleanup(@() flushProgressEvents(progressTarget));
primaryFailure = [];
if options.CollectAllFailures
    captured = cell(size(workItems));
    try
        parfor (workIndex = 1:numel(workItems), parallelOptions)
            captured{workIndex} = executeCaptured( ...
                workItems{workIndex}, workerFunction, ...
                workLabels(workIndex), additionalPaths, ...
                environmentVariableNames, workerAcceptsProgress, ...
                progressTarget, workIndex);
        end
    catch cause
        primaryFailure = cause;
    end
else
    try
        parfor (workIndex = 1:numel(workItems), parallelOptions)
            outputs{workIndex} = executeSafely( ...
                workItems{workIndex}, workerFunction, ...
                workLabels(workIndex), additionalPaths, ...
                environmentVariableNames, workerAcceptsProgress, ...
                progressTarget, workIndex);
        end
    catch cause
        primaryFailure = cause;
    end
end

progressFailure = [];
try
    flushProgressEvents(progressTarget);
catch cause
    progressFailure = cause;
end
clear progressFlushCleanup
progressFailure = combineFailures( ...
    progressFailure, parallelProgressFailure(progressJournal));

if options.CollectAllFailures && isempty(primaryFailure)
    try
        outputs = unwrapCaptured(captured);
    catch cause
        primaryFailure = cause;
    end
end
if ~isempty(primaryFailure)
    primaryFailure = combineFailures(primaryFailure,progressFailure);
    throwAsCaller(primaryFailure);
end
if ~isempty(progressFailure)
    throwAsCaller(progressFailure);
end
retainCleanup(progressListener);
retainCleanup(poolCleanup);
end

function outputs = runSerial( ...
        workItems, workerFunction, labels, ...
        additionalPaths, environmentVariableNames, collectAllFailures, ...
        workerAcceptsProgress, progressJournal)
outputs = cell(size(workItems));
progressTarget = createSerialProgressTarget(progressJournal);
if collectAllFailures
    captured = cell(size(workItems));
    for workIndex = 1:numel(workItems)
        captured{workIndex} = executeCaptured( ...
            workItems{workIndex}, workerFunction, labels(workIndex), ...
            additionalPaths, environmentVariableNames, ...
            workerAcceptsProgress, progressTarget, workIndex);
    end
    outputs = unwrapCaptured(captured);
    return
end

for workIndex = 1:numel(workItems)
    outputs{workIndex} = executeSafely( ...
        workItems{workIndex}, workerFunction, labels(workIndex), ...
        additionalPaths, environmentVariableNames, ...
        workerAcceptsProgress, progressTarget, workIndex);
end
end

function captured = executeCaptured( ...
        workItem, workerFunction, label, additionalPaths, ...
        environmentVariableNames, workerAcceptsProgress, ...
        progressTarget, workIndex)
try
    output = executeSafely( ...
        workItem, workerFunction, label, additionalPaths, ...
        environmentVariableNames, workerAcceptsProgress, ...
        progressTarget, workIndex);
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
        environmentVariableNames, workerAcceptsProgress, ...
        progressTarget, workIndex)
originalPath = path;
originalWorkingDirectory = string(pwd);
originalStream = RandStream.getGlobalStream();
originalStreamState = originalStream.State;
originalStreamProperties = snapshotRandomStreamProperties(originalStream);
originalWarningState = warning;
originalEnvironmentValues = cell(size(environmentVariableNames));
for variableIndex = 1:numel(environmentVariableNames)
    originalEnvironmentValues{variableIndex} = getenv( ...
        environmentVariableNames(variableIndex));
end
environmentCleanup = onCleanup(@() restoreEnvironment( ...
    originalPath, originalWorkingDirectory, ...
    originalStream, originalStreamState, originalStreamProperties, ...
    originalWarningState, environmentVariableNames, ...
    originalEnvironmentValues, BestEffort=true));

attemptId = createAttemptId();
attemptStopwatch = tic;
emitProgressEvent(progressTarget, progressEvent( ...
    workIndex, label, attemptId, "started", "work-item", ...
    ElapsedWallSeconds=0));
reportProgress = @(payload) reportHeartbeat( ...
    progressTarget, workIndex, label, attemptId, ...
    attemptStopwatch, payload);
workerFailure = [];
try
    for pathIndex = numel(additionalPaths):-1:1
        addpath(additionalPaths(pathIndex));
    end
    if workerAcceptsProgress
        output = workerFunction(workItem, reportProgress);
    else
        output = workerFunction(workItem);
    end
catch cause
    workerFailure = cause;
end

restorationFailure = [];
try
    restoreEnvironment( ...
        originalPath, originalWorkingDirectory, ...
        originalStream, originalStreamState, originalStreamProperties, ...
        originalWarningState, environmentVariableNames, ...
        originalEnvironmentValues);
catch cause
    restorationFailure = cause;
end
% Explicit restoration above provides actionable diagnostics. The
% best-effort cleanup remains a fallback for asynchronous interruption.
clear environmentCleanup

if ~isempty(workerFailure) || ~isempty(restorationFailure)
    exception = MException( ...
        "v2xsimregression:execution:WorkItemFailed", ...
        "Regression work item failed: %s.", label);
    exception = combineFailures(exception,workerFailure);
    exception = combineFailures(exception,restorationFailure);
    emitProgressEvent(progressTarget, progressEvent( ...
        workIndex, label, attemptId, "failed", "work-item", ...
        ElapsedWallSeconds=toc(attemptStopwatch), ...
        Message=failureMessage(workerFailure,restorationFailure)));
    throw(exception);
end
emitProgressEvent(progressTarget, progressEvent( ...
    workIndex, label, attemptId, "completed", "work-item", ...
    ElapsedWallSeconds=toc(attemptStopwatch)));
end

function acceptsProgress = workerFunctionAcceptsProgress(workerFunction)
try
    inputCount = nargin(workerFunction);
catch
    % Preserve the historical one-input invocation for opaque handles.
    acceptsProgress = false;
    return
end
% A fixed two-input signature is the explicit opt-in to progress. Optional
% and variadic workers retain the scheduler's historical one-input call.
acceptsProgress = inputCount == 2;
end

function message = failureMessage(workerFailure, restorationFailure)
if ~isempty(workerFailure)
    message = compose( ...
        "[%s] %s",workerFailure.identifier,workerFailure.message);
else
    message = compose( ...
        "[%s] %s", ...
        restorationFailure.identifier,restorationFailure.message);
end
if ~isempty(workerFailure) && ~isempty(restorationFailure)
    message = message + compose( ...
        " Environment restoration also failed: [%s] %s", ...
        restorationFailure.identifier,restorationFailure.message);
end
end

function combined = combineFailures(primary, additional)
if isempty(primary)
    combined = additional;
elseif isempty(additional)
    combined = primary;
else
    combined = addCause(primary,additional);
end
end

function failure = parallelProgressFailure(journal)
if isempty(journal)
    failure = [];
    return
end
failure = journal.parallelCallbackFailure();
end

function progressLogFile = resolveProgressLogFile(progressLogFile)
if ismissing(progressLogFile)
    error( ...
        "v2xsimregression:execution:InvalidProgressLogFile", ...
        "ProgressLogFile must not be missing.");
end
if progressLogFile == ""
    return
end
progressLogFile = strip(progressLogFile);
if strlength(progressLogFile) == 0
    error( ...
        "v2xsimregression:execution:InvalidProgressLogFile", ...
        "ProgressLogFile must be empty or a nonblank file path.");
end
if ~isAbsolutePath(progressLogFile)
    progressLogFile = fullfile(pwd,progressLogFile);
end
end

function journal = createProgressJournal(progressLogFile, workItemCount)
if progressLogFile == ""
    journal = [];
    return
end
journal = ...
    v2xsimregression.execution.internal.ProgressJournal( ...
        progressLogFile, workItemCount);
end

function recordQueuedWorkItems(journal, labels)
if isempty(journal)
    return
end
for workIndex = 1:numel(labels)
    journal.record(progressEvent( ...
        workIndex, labels(workIndex), "", "queued", "work-item"));
end
end

function target = createSerialProgressTarget(journal)
if isempty(journal)
    target = [];
    return
end
target = @(event) journal.record(event);
end

function [target, listener] = createParallelProgressTarget(journal)
if isempty(journal)
    target = [];
    listener = [];
    return
end
target = parallel.pool.DataQueue;
listener = afterEach( ...
    target,@(event) journal.recordFromParallelQueue(event));
end

function flushProgressEvents(target)
if isempty(target)
    return
end
while target.QueueLength > 0
    drawnow
end
drawnow
end

function reportHeartbeat( ...
        target, workIndex, label, attemptId, attemptStopwatch, payload)
payload = validateHeartbeatPayload(payload);
elapsedWallSeconds = toc(attemptStopwatch);
if ~isempty(payload.ElapsedWallSeconds)
    elapsedWallSeconds = payload.ElapsedWallSeconds;
end
emitProgressEvent(target, progressEvent( ...
    workIndex, label, attemptId, "heartbeat", payload.Stage, ...
    SimulatedTimeSeconds=payload.SimulatedTimeSeconds, ...
    SimulationDurationSeconds=payload.SimulationDurationSeconds, ...
    FractionComplete=payload.FractionComplete, ...
    ElapsedWallSeconds=elapsedWallSeconds, ...
    Message=payload.Message));
end

function payload = validateHeartbeatPayload(payload)
if ~isstruct(payload) || ~isscalar(payload)
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "A progress callback requires a scalar structure payload.");
end
allowedFields = [ ...
    "Stage", "SimulatedTimeSeconds", ...
    "SimulationDurationSeconds", "FractionComplete", ...
    "ElapsedWallSeconds", "Message"];
payloadFields = string(fieldnames(payload)).';
unexpectedFields = setdiff(payloadFields,allowedFields);
if ~isempty(unexpectedFields)
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "Unknown progress payload field: %s.", unexpectedFields(1));
end
if ~isfield(payload,"Stage")
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "A progress payload must contain Stage.");
end
payload.Stage = progressText(payload.Stage,"Stage",false);
payload.SimulatedTimeSeconds = optionalProgressNumber( ...
    payload,"SimulatedTimeSeconds",0,Inf);
payload.SimulationDurationSeconds = optionalProgressNumber( ...
    payload,"SimulationDurationSeconds",0,Inf);
payload.FractionComplete = optionalProgressNumber( ...
    payload,"FractionComplete",0,1);
payload.ElapsedWallSeconds = optionalProgressNumber( ...
    payload,"ElapsedWallSeconds",0,Inf);
if isfield(payload,"Message")
    payload.Message = progressText(payload.Message,"Message",true);
else
    payload.Message = "";
end
if ~isempty(payload.SimulatedTimeSeconds) && ...
        ~isempty(payload.SimulationDurationSeconds) && ...
        payload.SimulatedTimeSeconds > payload.SimulationDurationSeconds
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "SimulatedTimeSeconds must not exceed " + ...
        "SimulationDurationSeconds.");
end
end

function value = optionalProgressNumber( ...
        payload, fieldName, minimumValue, maximumValue)
if ~isfield(payload,fieldName) || isempty(payload.(fieldName))
    value = [];
    return
end
value = payload.(fieldName);
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value < minimumValue || value > maximumValue
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "%s must be a finite numeric scalar in [%g, %g].", ...
        fieldName, minimumValue, maximumValue);
end
value = double(value);
end

function value = progressText(value, fieldName, allowEmpty)
if ~(isstring(value) && isscalar(value)) && ...
        ~(ischar(value) && (isrow(value) || isempty(value)))
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "%s must be a text scalar.", fieldName);
end
value = string(value);
if ismissing(value) || (~allowEmpty && strlength(strip(value)) == 0)
    error( ...
        "v2xsimregression:execution:InvalidProgressPayload", ...
        "%s must not be missing or blank.", fieldName);
end
value = strip(value);
end

function emitProgressEvent(target, event)
if isempty(target)
    return
end
if isa(target,"function_handle")
    target(event);
else
    send(target,event);
end
end

function event = progressEvent( ...
        workIndex, label, attemptId, eventType, stage, options)
arguments (Input)
    workIndex (1, 1) double {mustBeInteger,mustBeNonnegative}
    label (1, 1) string
    attemptId (1, 1) string
    eventType (1, 1) string
    stage (1, 1) string
    options.SimulatedTimeSeconds = []
    options.SimulationDurationSeconds = []
    options.FractionComplete = []
    options.ElapsedWallSeconds = []
    options.Message (1, 1) string = ""
end
event = struct( ...
    WorkItemIndex=workIndex, ...
    Label=label, ...
    AttemptId=attemptId, ...
    Event=eventType, ...
    Stage=stage, ...
    SimulatedTimeSeconds=options.SimulatedTimeSeconds, ...
    SimulationDurationSeconds=options.SimulationDurationSeconds, ...
    FractionComplete=options.FractionComplete, ...
    ElapsedWallSeconds=options.ElapsedWallSeconds, ...
    Message=options.Message);
end

function attemptId = createAttemptId()
[~,attemptName] = fileparts(tempname);
attemptId = string(attemptName);
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

function [pool, cleanup] = acquireProcessPool(maxWorkers)
pool = gcp("nocreate");
if ~isempty(pool) && v2xsimregression.execution.isProcessPoolClass(string(class(pool)))
    cleanup = onCleanup.empty;
    return
end

assert(isempty(pool), "v2xsimregression:execution:UnsupportedPool", ...
    "An existing pool must use separate MATLAB processes; thread pools are unsupported.");
cluster = parcluster("Processes");
workerCount = ...
    v2xsimregression.execution.internal.resolveWorkerCount( ...
        maxWorkers,cluster.NumWorkers);
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
        originalStream, originalStreamState, originalStreamProperties, ...
        originalWarningState, environmentVariableNames, ...
        originalEnvironmentValues, options)
arguments (Input)
    originalPath
    originalWorkingDirectory
    originalStream
    originalStreamState
    originalStreamProperties
    originalWarningState
    environmentVariableNames
    originalEnvironmentValues
    options.BestEffort (1, 1) logical = false
end

failures = cell(1,0);
failures = attemptRestoration( ...
    failures, ...
    "v2xsimregression:execution:WorkingDirectoryRestoreFailed", ...
    compose( ...
        "Could not restore working directory %s.", ...
        originalWorkingDirectory), ...
    @() cd(originalWorkingDirectory));
failures = attemptRestoration( ...
    failures, ...
    "v2xsimregression:execution:PathRestoreFailed", ...
    "Could not restore the MATLAB path.", ...
    @() path(originalPath));
failures = attemptRestoration( ...
    failures, ...
    "v2xsimregression:execution:GlobalStreamRestoreFailed", ...
    "Could not restore the original global random stream.", ...
    @() RandStream.setGlobalStream(originalStream));
for propertyIndex = 1:numel(originalStreamProperties.Names)
    propertyName = originalStreamProperties.Names(propertyIndex);
    propertyValue = originalStreamProperties.Values{propertyIndex};
    failures = attemptRestoration( ...
        failures, ...
        "v2xsimregression:execution:" + ...
        "RandomStreamPropertyRestoreFailed", ...
        compose( ...
            "Could not restore global random-stream property %s.", ...
            propertyName), ...
        @() setRandomStreamProperty( ...
            originalStream, propertyName, propertyValue));
end
failures = attemptRestoration( ...
    failures, ...
    "v2xsimregression:execution:RandomStateRestoreFailed", ...
    "Could not restore the original global random-stream state.", ...
    @() restoreRandomStreamState(originalStream,originalStreamState));
failures = attemptRestoration( ...
    failures, ...
    "v2xsimregression:execution:WarningStateRestoreFailed", ...
    "Could not restore the MATLAB warning state.", ...
    @() warning(originalWarningState));
for variableIndex = 1:numel(environmentVariableNames)
    variableName = environmentVariableNames(variableIndex);
    variableValue = originalEnvironmentValues{variableIndex};
    failures = attemptRestoration( ...
        failures, ...
        "v2xsimregression:execution:" + ...
        "EnvironmentVariableRestoreFailed", ...
        compose( ...
            "Could not restore environment variable %s.", ...
            variableName), ...
        @() setenv(variableName,variableValue));
end
if isempty(failures) || options.BestEffort
    return
end

exception = MException( ...
    "v2xsimregression:execution:EnvironmentRestoreFailed", ...
    "%d environment components could not be restored.", ...
    numel(failures));
for failureIndex = 1:numel(failures)
    exception = addCause(exception,failures{failureIndex});
end
throw(exception);
end

function failures = attemptRestoration( ...
        failures, identifier, message, action)
try
    action();
catch cause
    exception = MException(identifier,"%s",message);
    failures{end + 1} = addCause(exception,cause);
end
end

function snapshot = snapshotRandomStreamProperties(stream)
snapshot.Names = strings(0,1);
snapshot.Values = cell(0,1);
propertyNames = [ ...
    "Antithetic"; "FullPrecision"; "NormalTransform"; "Substream"];
for propertyName = propertyNames.'
    propertyNameText = char(propertyName);
    if ~isprop(stream,propertyNameText)
        continue
    end
    snapshot.Names(end + 1,1) = propertyName;
    snapshot.Values{end + 1,1} = stream.(propertyNameText);
end
end

function setRandomStreamProperty(stream, propertyName, propertyValue)
stream.(char(propertyName)) = propertyValue;
end

function restoreRandomStreamState(stream, state)
stream.State = state;
end

function retainCleanup(~)
% Keep a scheduler-owned pool cleanup alive until parallel work completes.
end

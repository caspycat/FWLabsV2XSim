function reportProgress( ...
        progressFcn, stage, simulatedTimeSeconds, ...
        simulationDurationSeconds, elapsedWallSeconds, message)
%REPORTPROGRESS Deliver one run-owned simulation progress observation.
%   Progress callbacks are execution observers. They receive only scalar
%   timing metadata and cannot alter scientific simulation state.

arguments (Input)
    progressFcn (1, 1) function_handle
    stage (1, 1) string {mustBeMember( ...
        stage, ["initializing", "simulating", "finalizing"])}
    simulatedTimeSeconds (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeNonnegative}
    simulationDurationSeconds (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBePositive}
    elapsedWallSeconds (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeNonnegative}
    message (1, 1) string = ""
end

fractionComplete = min( ...
    max(simulatedTimeSeconds ./ simulationDurationSeconds, 0), 1);
event = struct( ...
    Stage=stage, ...
    SimulatedTimeSeconds=simulatedTimeSeconds, ...
    SimulationDurationSeconds=simulationDurationSeconds, ...
    FractionComplete=fractionComplete, ...
    ElapsedWallSeconds=elapsedWallSeconds, ...
    Message=message);

processSnapshot = snapshotProcessState();
restorationStatus = containers.Map( ...
    "KeyType", "char", "ValueType", "logical");
restorationStatus("Complete") = false;
observerCleanup = onCleanup(@() restoreOnUnwind( ...
    processSnapshot, restorationStatus));
callbackException = [];
try
    progressFcn(event);
catch cause
    callbackException = MException( ...
        "v2xsim:runtime:ProgressCallbackFailed", ...
        "The simulation progress callback failed during stage %s.", ...
        stage);
    callbackException = addCause(callbackException, cause);
end

% Restore explicitly so a restoration failure is a run failure rather than
% an onCleanup destructor warning. The cleanup remains armed until every
% component has been attempted successfully.
try
    restoreProcessState(processSnapshot);
    restorationStatus("Complete") = true; %#ok<NASGU>
catch restorationException
    if isempty(callbackException)
        throwAsCaller(restorationException);
    end
    callbackException = addCause( ...
        callbackException, restorationException);
    throwAsCaller(callbackException);
end

if ~isempty(callbackException)
    throwAsCaller(callbackException);
end
observerCleanup; %#ok<VUNUS>
end

function snapshot = snapshotProcessState()
snapshot.Path = path;
snapshot.WorkingDirectory = string(pwd);
snapshot.Stream = RandStream.getGlobalStream();
snapshot.StreamState = snapshot.Stream.State;
snapshot.StreamPropertyNames = strings(0, 1);
snapshot.StreamPropertyValues = cell(0, 1);

mutablePropertyNames = [ ...
    "Antithetic"; "FullPrecision"; "NormalTransform"; "Substream"];
for propertyName = mutablePropertyNames.'
    propertyNameText = char(propertyName);
    if ~isprop(snapshot.Stream, propertyNameText)
        continue
    end
    snapshot.StreamPropertyNames(end + 1, 1) = ...
        string(propertyNameText);
    snapshot.StreamPropertyValues{end + 1, 1} = ...
        snapshot.Stream.(propertyNameText);
end
snapshot.WarningState = warning;
end

function restoreOnUnwind(snapshot, restorationStatus)
if restorationStatus("Complete")
    return
end
try
    % Best effort only: the explicit attempt already provides the stable
    % diagnostic, while an unexpected unwind must not mask its original
    % exception with an onCleanup destructor warning.
    restoreProcessState(snapshot);
catch ignoredFailure
end
end

function restoreProcessState(snapshot)
failureComponents = strings(0, 1);
failureCauses = cell(0, 1);

[failureComponents, failureCauses] = attemptRestoration( ...
    failureComponents, failureCauses, "working directory", ...
    @() cd(snapshot.WorkingDirectory));
[failureComponents, failureCauses] = attemptRestoration( ...
    failureComponents, failureCauses, "MATLAB path", ...
    @() path(snapshot.Path));
[failureComponents, failureCauses] = attemptRestoration( ...
    failureComponents, failureCauses, "global random-stream handle", ...
    @() RandStream.setGlobalStream(snapshot.Stream));

for propertyIndex = 1:numel(snapshot.StreamPropertyNames)
    propertyName = snapshot.StreamPropertyNames(propertyIndex);
    propertyValue = snapshot.StreamPropertyValues{propertyIndex};
    [failureComponents, failureCauses] = attemptRestoration( ...
        failureComponents, failureCauses, ...
        "random-stream property " + propertyName, ...
        @() setStreamProperty( ...
            snapshot.Stream, propertyName, propertyValue));
end
[failureComponents, failureCauses] = attemptRestoration( ...
    failureComponents, failureCauses, "random-stream state", ...
    @() setStreamProperty( ...
        snapshot.Stream, "State", snapshot.StreamState));
[failureComponents, failureCauses] = attemptRestoration( ...
    failureComponents, failureCauses, "warning state", ...
    @() warning(snapshot.WarningState));

if isempty(failureCauses)
    return
end

exception = MException( ...
    "v2xsim:runtime:ProgressStateRestoreFailed", ...
    "Failed to restore progress callback process state: %s.", ...
    strjoin(failureComponents, ", "));
for causeIndex = 1:numel(failureCauses)
    exception = addCause(exception, failureCauses{causeIndex});
end
throw(exception);
end

function [failureComponents, failureCauses] = attemptRestoration( ...
        failureComponents, failureCauses, component, restoreAction)
try
    restoreAction();
catch cause
    failureComponents(end + 1, 1) = component;
    failureCauses{end + 1, 1} = cause;
end
end

function setStreamProperty(stream, propertyName, propertyValue)
stream.(char(propertyName)) = propertyValue;
end

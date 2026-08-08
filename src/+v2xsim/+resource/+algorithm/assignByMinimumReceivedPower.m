function [resourceIds,decisionRows] = assignByMinimumReceivedPower( ...
        resourceIds,scheduledRows,receivedPowerWatts,shadowingDb, ...
        removeKnownShadowing,gridSize,randomStream,eligibilityMask)
%ASSIGNBYMINIMUMRECEIVEDPOWER Reuse the least strongly received resource.

arguments (Input)
    resourceIds (:,1) double
    scheduledRows (:,1) double {mustBeInteger,mustBePositive}
    receivedPowerWatts (:,:) double {mustBeReal,mustBeNonnegative}
    shadowingDb (:,:) double {mustBeReal}
    removeKnownShadowing (1,1) logical
    gridSize (1,2) double {mustBeInteger,mustBePositive}
    randomStream (1,1) RandStream
    eligibilityMask (:,:) logical = false(0,0)
end

ueCount = numel(resourceIds);
if ~isequal(size(receivedPowerWatts),[ueCount ueCount]) || ...
        any(~isfinite(receivedPowerWatts),"all") || ...
        ~isequal(size(shadowingDb),[ueCount ueCount]) || ...
        any(~isfinite(shadowingDb),"all")
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "Power and shadowing must be finite square UE matrices.");
end
resourceCount = prod(gridSize);
validateRowsAndResources(scheduledRows,resourceIds,resourceCount);
eligibilityMask = normalizedEligibilityMask( ...
    eligibilityMask,ueCount,resourceCount);

estimatedPower = receivedPowerWatts;
if removeKnownShadowing
    estimatedPower = estimatedPower ./ db2pow(shadowingDb);
end

decisionRows = unique([find(isnan(resourceIds)); scheduledRows],"stable");
resourceIds(scheduledRows) = NaN;
decisionOrder = decisionRows(randperm(randomStream,numel(decisionRows)));

for row = reshape(decisionOrder,1,[])
    [~,neighborOrder] = sort(estimatedPower(row,:),"descend");
    neighborOrder(neighborOrder == row) = [];
    resourceIds(row) = selectResource( ...
        resourceIds(neighborOrder),gridSize,randomStream, ...
        eligibilityMask(row,:));
end
end

function resourceId = selectResource( ...
        orderedResources,gridSize,stream,eligibleResourceMask)
timeCount = gridSize(1);
frequencyCount = gridSize(2);
orderedResources = orderedResources(~isnan(orderedResources));
orderedTimes = ceil(orderedResources / frequencyCount);
orderedFrequencies = mod(orderedResources - 1,frequencyCount) + 1;

eligibleResourceIds = find(eligibleResourceMask);
eligibleTimes = unique(ceil(eligibleResourceIds / frequencyCount));

seenTimes = true(timeCount,1);
seenTimes(eligibleTimes) = false;
selectedTime = NaN;
for index = 1:numel(orderedTimes)
    selectedTime = orderedTimes(index);
    if ~ismember(selectedTime,eligibleTimes)
        continue
    end
    seenTimes(selectedTime) = true;
    if all(seenTimes(eligibleTimes))
        break
    end
end

if ~all(seenTimes(eligibleTimes))
    freeTimes = eligibleTimes(~seenTimes(eligibleTimes));
    selectedTime = freeTimes(randi(stream,numel(freeTimes)));
    eligibleFrequencies = eligibleResourceIds( ...
        ceil(eligibleResourceIds / frequencyCount) == selectedTime);
    selectedFrequency = mod( ...
        eligibleFrequencies(randi(stream,numel(eligibleFrequencies))) - 1, ...
        frequencyCount) + 1;
else
    sameTimeIndexes = find(orderedTimes == selectedTime);
    eligibleFrequencies = mod( ...
        eligibleResourceIds( ...
        ceil(eligibleResourceIds / frequencyCount) == selectedTime) - 1, ...
        frequencyCount) + 1;
    seenFrequencies = true(frequencyCount,1);
    seenFrequencies(eligibleFrequencies) = false;
    selectedFrequency = NaN;
    for index = reshape(sameTimeIndexes,1,[])
        selectedFrequency = orderedFrequencies(index);
        if ~ismember(selectedFrequency,eligibleFrequencies)
            continue
        end
        seenFrequencies(selectedFrequency) = true;
        if all(seenFrequencies(eligibleFrequencies))
            break
        end
    end
    if ~all(seenFrequencies(eligibleFrequencies))
        freeFrequencies = eligibleFrequencies( ...
            ~seenFrequencies(eligibleFrequencies));
        selectedFrequency = freeFrequencies( ...
            randi(stream,numel(freeFrequencies)));
    end
end

resourceId = (selectedTime - 1) * frequencyCount + selectedFrequency;
end

function mask = normalizedEligibilityMask(mask,ueCount,resourceCount)
if isempty(mask)
    mask = true(ueCount,resourceCount);
elseif ~isequal(size(mask),[ueCount resourceCount]) || ...
        any(~any(mask,2))
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "eligibilityMask must provide at least one resource per UE.");
end
end

function validateRowsAndResources(rows,resourceIds,resourceCount)
if any(rows > numel(resourceIds)) || numel(unique(rows)) ~= numel(rows)
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "Scheduled rows must be unique valid UE row indices.");
end
assigned = resourceIds(~isnan(resourceIds));
if any(~isfinite(assigned)) || any(assigned < 1) || ...
        any(assigned > resourceCount) || any(fix(assigned) ~= assigned)
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "Resource IDs must be NaN or local 1-based integer IDs.");
end
end

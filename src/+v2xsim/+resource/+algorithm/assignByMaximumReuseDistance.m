function [resourceIds,decisionRows] = assignByMaximumReuseDistance( ...
        resourceIds,scheduledRows,distanceMeters,gridSize,randomStream)
%ASSIGNBYMAXIMUMREUSEDISTANCE Reuse the resource of the farthest UE.

arguments (Input)
    resourceIds (:,1) double
    scheduledRows (:,1) double {mustBeInteger,mustBePositive}
    distanceMeters (:,:) double {mustBeReal,mustBeNonnegative}
    gridSize (1,2) double {mustBeInteger,mustBePositive}
    randomStream (1,1) RandStream
end

ueCount = numel(resourceIds);
if ~isequal(size(distanceMeters),[ueCount ueCount]) || ...
        any(~isfinite(distanceMeters),"all")
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "distanceMeters must be a finite square UE matrix.");
end
resourceCount = prod(gridSize);
validateRowsAndResources(scheduledRows,resourceIds,resourceCount);

decisionRows = unique([find(isnan(resourceIds)); scheduledRows],"stable");
resourceIds(scheduledRows) = NaN;
decisionOrder = decisionRows(randperm(randomStream,numel(decisionRows)));

for row = reshape(decisionOrder,1,[])
    [~,neighborOrder] = sort(distanceMeters(row,:),"ascend");
    neighborOrder(neighborOrder == row) = [];
    resourceIds(row) = selectResource( ...
        resourceIds(neighborOrder),gridSize,randomStream);
end
end

function resourceId = selectResource(orderedResources,gridSize,stream)
timeCount = gridSize(1);
frequencyCount = gridSize(2);
valid = ~isnan(orderedResources);
orderedResources = orderedResources(valid);
orderedTimes = ceil(orderedResources / frequencyCount);
orderedFrequencies = mod(orderedResources - 1,frequencyCount) + 1;

seenTimes = false(timeCount,1);
selectedTime = NaN;
coverageIndex = NaN;
for index = 1:numel(orderedTimes)
    selectedTime = orderedTimes(index);
    seenTimes(selectedTime) = true;
    if all(seenTimes)
        coverageIndex = index;
        break
    end
end

if isnan(coverageIndex)
    freeTimes = find(~seenTimes);
    selectedTime = freeTimes(randi(stream,numel(freeTimes)));
    selectedFrequency = randi(stream,frequencyCount);
else
    sameTimeIndexes = find(orderedTimes == selectedTime);
    seenFrequencies = false(frequencyCount,1);
    selectedFrequency = NaN;
    for index = reshape(sameTimeIndexes,1,[])
        selectedFrequency = orderedFrequencies(index);
        seenFrequencies(selectedFrequency) = true;
        if all(seenFrequencies)
            break
        end
    end
    if ~all(seenFrequencies)
        freeFrequencies = find(~seenFrequencies);
        selectedFrequency = freeFrequencies( ...
            randi(stream,numel(freeFrequencies)));
    end
end

resourceId = (selectedTime - 1) * frequencyCount + selectedFrequency;
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

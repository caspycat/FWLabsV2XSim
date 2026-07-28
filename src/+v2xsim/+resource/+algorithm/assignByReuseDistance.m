function [resourceIds,decisionRows] = assignByReuseDistance( ...
        resourceIds,scheduledRows,distanceMeters,resourceCount, ...
        reuseDistanceMeters,randomStream)
%ASSIGNBYREUSEDISTANCE Allocate without nearby same-resource reuse.

arguments (Input)
    resourceIds (:,1) double
    scheduledRows (:,1) double {mustBeInteger,mustBePositive}
    distanceMeters (:,:) double {mustBeReal,mustBeNonnegative}
    resourceCount (1,1) double {mustBeInteger,mustBePositive}
    reuseDistanceMeters (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeNonnegative}
    randomStream (1,1) RandStream
end

ueCount = numel(resourceIds);
validateSquareMatrix(distanceMeters,ueCount,"distanceMeters");
validateRowsAndResources(scheduledRows,resourceIds,resourceCount);

decisionRows = unique([find(isnan(resourceIds)); scheduledRows],"stable");
resourceIds(scheduledRows) = NaN;
if isempty(decisionRows)
    return
end

decisionOrder = decisionRows( ...
    randperm(randomStream,numel(decisionRows)));
for row = reshape(decisionOrder,1,[])
    candidateResources = randperm(randomStream,resourceCount);
    for resourceId = candidateResources
        usersOfResource = resourceIds == resourceId;
        if all(distanceMeters(row,usersOfResource) >= reuseDistanceMeters)
            resourceIds(row) = resourceId;
            break
        end
    end
end
end

function validateSquareMatrix(values,expectedSize,name)
if ~isequal(size(values),[expectedSize expectedSize]) || ...
        any(~isfinite(values),"all")
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "%s must be a finite %d-by-%d matrix.", ...
        name,expectedSize,expectedSize);
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

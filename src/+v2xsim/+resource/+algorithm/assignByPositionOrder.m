function [resourceIds,decisionRows] = assignByPositionOrder( ...
        xPositions,gridSize,eligibilityMask)
%ASSIGNBYPOSITIONORDER Assign resources by ascending longitudinal position.

arguments (Input)
    xPositions (:,1) double {mustBeReal,mustBeFinite}
    gridSize (1,2) double {mustBeInteger,mustBePositive}
    eligibilityMask (:,:) logical = false(0,0)
end

ueCount = numel(xPositions);
resourceCount = prod(gridSize);
if isempty(eligibilityMask)
    eligibilityMask = true(ueCount,resourceCount);
elseif ~isequal(size(eligibilityMask),[ueCount resourceCount])
    error( ...
        "v2xsim:resource:InvalidAllocationInput", ...
        "eligibilityMask must contain one row per UE and grid resource.");
elseif any(~any(eligibilityMask,2))
    error( ...
        "v2xsim:resource:NoEligibleResources", ...
        "Each UE requires at least one eligible resource.");
end
[~,positionOrder] = sort(xPositions,"ascend");

resourceIds = NaN(ueCount,1);
for orderIndex = 1:ueCount
    row = positionOrder(orderIndex);
    candidates = find(eligibilityMask(row,:));
    frequencyIds = mod(candidates - 1,gridSize(2)) + 1;
    timeSlots = ceil(candidates / gridSize(2));
    ordering = sortrows([frequencyIds(:),timeSlots(:),candidates(:)]);
    resourceIds(row) = ordering( ...
        mod(orderIndex - 1,size(ordering,1)) + 1,3);
end
decisionRows = (1:ueCount).';
end

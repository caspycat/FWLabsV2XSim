function [resourceIds,decisionRows] = assignByPositionOrder( ...
        xPositions,gridSize)
%ASSIGNBYPOSITIONORDER Assign resources by ascending longitudinal position.

arguments (Input)
    xPositions (:,1) double {mustBeReal,mustBeFinite}
    gridSize (1,2) double {mustBeInteger,mustBePositive}
end

ueCount = numel(xPositions);
resourceCount = prod(gridSize);
[~,positionOrder] = sort(xPositions,"ascend");

allResources = (1:resourceCount).';
frequencyIds = mod(allResources - 1,gridSize(2)) + 1;
[~,frequencyFirstOrder] = sort(frequencyIds,"ascend");
orderedResources = allResources(frequencyFirstOrder);
orderedResources = repmat( ...
    orderedResources,ceil(ueCount / resourceCount),1);

resourceIds = NaN(ueCount,1);
resourceIds(positionOrder) = orderedResources(1:ueCount);
decisionRows = (1:ueCount).';
end

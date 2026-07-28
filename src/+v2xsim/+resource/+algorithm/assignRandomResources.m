function [resourceIds,decisionRows,blockedRows] = assignRandomResources( ...
        allowedResourceMask,maximumTransmissionCount,randomStream, ...
        numberFrequencyResources)
%ASSIGNRANDOMRESOURCES Sample eligible resources in distinct time slots.

arguments (Input)
    allowedResourceMask (:,:) logical
    maximumTransmissionCount (1,1) double ...
        {mustBeInteger,mustBePositive}
    randomStream (1,1) RandStream
    numberFrequencyResources (1,1) double ...
        {mustBeInteger,mustBePositive} = 1
end

ueCount = size(allowedResourceMask,1);
resourceIds = NaN(ueCount,maximumTransmissionCount);
decisionRows = (1:ueCount).';

for row = 1:ueCount
    eligible = find(allowedResourceMask(row,:));
    eligibleTimeSlots = unique( ...
        ceil(eligible / numberFrequencyResources),"stable");
    selectionCount = min( ...
        maximumTransmissionCount,numel(eligibleTimeSlots));
    if selectionCount == 0
        continue
    end
    selectedTimeIndexes = randperm( ...
        randomStream,numel(eligibleTimeSlots),selectionCount);
    selectedTimeSlots = eligibleTimeSlots(selectedTimeIndexes);
    selected = zeros(1,selectionCount);
    eligibleResourceTimeSlots = ...
        ceil(eligible / numberFrequencyResources);
    for transmission = 1:selectionCount
        candidates = eligible( ...
            eligibleResourceTimeSlots == ...
            selectedTimeSlots(transmission));
        selected(transmission) = candidates( ...
            randi(randomStream,numel(candidates)));
    end
    resourceIds(row,1:selectionCount) = sort(selected);
end

blockedRows = find(isnan(resourceIds(:,1)));
end

function eligibilityMask = buildSelectionWindowEligibility( ...
        grid,selectionOriginSlots,currentSlot, ...
        windowStartOffsetSlots,windowEndOffsetSlots)
%BUILDSELECTIONWINDOWELIGIBILITY Select future T1--T2 resources per UE.
%   Resource coordinates repeat once per grid period. For each UE, this
%   function considers the first occurrence of every resource strictly
%   after SelectionOriginSlots. A resource is eligible when that
%   occurrence is within the inclusive T1--T2 window and is also strictly
%   after CurrentSlot. The latter condition prevents a later
%   re-evaluation from selecting an occurrence that has already elapsed.

arguments (Input)
    grid (1,1) v2xsim.resource.BRResourceGrid
    selectionOriginSlots (:,1) double ...
        {mustBeReal,mustBeFinite,mustBeInteger,mustBeNonnegative}
    currentSlot (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeInteger,mustBeNonnegative}
    windowStartOffsetSlots (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive}
    windowEndOffsetSlots (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive}
end

arguments (Output)
    eligibilityMask (:,:) logical
end

if windowStartOffsetSlots > windowEndOffsetSlots || ...
        windowEndOffsetSlots > grid.NumberTimeSlots
    error( ...
        "v2xsim:resource:InvalidSelectionWindow", ...
        "The selection window must satisfy 1 <= T1 <= T2 <= " + ...
        "the number of time slots in the resource grid.");
end

ueCount = numel(selectionOriginSlots);
if ueCount == 0
    eligibilityMask = false(0,grid.ResourceCount);
    return
end

resourceIds = 1:grid.ResourceCount;
[resourceTimeSlots,~] = grid.resourceCoordinates(resourceIds);
originPeriodicSlots = grid.periodicSlot(selectionOriginSlots);
offsetSlots = mod( ...
    resourceTimeSlots - originPeriodicSlots - 1, ...
    grid.NumberTimeSlots) + 1;
firstOccurrenceSlots = selectionOriginSlots + offsetSlots;

eligibilityMask = ...
    offsetSlots >= windowStartOffsetSlots & ...
    offsetSlots <= windowEndOffsetSlots & ...
    firstOccurrenceSlots > currentSlot;
end

function [crossingCoordinate, status] = ...
        firstDownwardCrossing(coordinates, values, threshold)
%FIRSTDOWNWARDCROSSING Interpolate the first value at or below a threshold.
%   STATUS is "crossed", "left_censored", or "right_censored". A
%   censoring status returns the corresponding observation-window bound.

arguments (Input)
    coordinates (:, 1) double {mustBeReal, mustBeFinite}
    values (:, 1) double {mustBeReal, mustBeFinite}
    threshold (1, 1) double {mustBeReal, mustBeFinite}
end

if isempty(coordinates) || numel(coordinates) ~= numel(values) || ...
        any(diff(coordinates) <= 0)
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidCrossingCurve", ...
        "Coordinates and values must be nonempty equal-length " + ...
        "columns with strictly increasing coordinates.");
end

firstAtOrBelow = find(values <= threshold, 1);
if isempty(firstAtOrBelow)
    crossingCoordinate = coordinates(end);
    status = "right_censored";
    return
end
if firstAtOrBelow == 1
    crossingCoordinate = coordinates(1);
    status = "left_censored";
    return
end

leftIndex = firstAtOrBelow - 1;
rightIndex = firstAtOrBelow;
leftCoordinate = coordinates(leftIndex);
rightCoordinate = coordinates(rightIndex);
leftValue = values(leftIndex);
rightValue = values(rightIndex);
if rightValue == threshold
    crossingCoordinate = rightCoordinate;
else
    crossingCoordinate = leftCoordinate + ...
        (threshold - leftValue) .* ...
        (rightCoordinate - leftCoordinate) ./ ...
        (rightValue - leftValue);
end
status = "crossed";
end

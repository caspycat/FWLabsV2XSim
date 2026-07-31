function [rangeMeters,status,anchoredCurve] = prrThresholdRange( ...
        curve,options)
%PRRTHRESHOLDRANGE Find a reproducible PRR-versus-distance threshold range.
%   [RANGE,STATUS,ANCHORED] = PRRTHRESHOLDRANGE(CURVE) finds the first
%   linearly interpolated downward crossing of delivery PRR = 0.9. CURVE
%   must describe exactly one already-pooled distance curve. To combine
%   replications, first use v2xsim.analysis.poolPacketReceptionCounts so
%   that every packet opportunity, rather than every run, has equal weight.
%
%   ANCHORED is the plot-ready curve with the explicit synthetic point
%   (0 m, AnchorPrr). The anchor is an analysis convention, not a measured
%   packet-fate bin. STATUS is "Crossed" when the threshold occurs within
%   the observed range, "RightCensored" when PRR remains above it through
%   the furthest distance, or "LeftCensored" when the anchor is already at
%   or below it. STATUS is "IncompleteDistanceGrid" with RANGE = NaN when
%   any configured bin has no observations; sparse data must not imply a
%   threshold range.
%
%   Threshold defaults to 0.9, matching the archived PRR-range papers. Set
%   Threshold=0.95 to report a 95-percent range using the same convention.

arguments (Input)
    curve table
    options.Metric (1,1) string = "DeliveryPrr"
    options.Threshold (1,1) double {mustBeReal,mustBeFinite} = 0.9
    options.AnchorPrr (1,1) double {mustBeReal,mustBeFinite} = 1
end
arguments (Output)
    rangeMeters (1,1) double
    status (1,1) string
    anchoredCurve table
end

metric = string(validatestring( ...
    options.Metric,["DeliveryPrr","RadioPrr"]));
validateProbability(options.Threshold,"Threshold");
validateProbability(options.AnchorPrr,"AnchorPrr");

if metric == "DeliveryPrr"
    denominatorName = "TotalCount";
else
    denominatorName = "RadioAttemptCount";
end
requiredNames = ["DistanceUpperBoundMeters",metric,denominatorName];
actualNames = string(curve.Properties.VariableNames);
if any(~ismember(requiredNames,actualNames))
    error( ...
        "v2xsim:analysis:InvalidPrrCurveSchema", ...
        "PRR curve must contain %s.",strjoin(requiredNames,", "));
end

distances = curve.DistanceUpperBoundMeters;
ratios = curve.(metric);
denominators = curve.(denominatorName);
if isempty(curve) || ~isnumeric(distances) || ~iscolumn(distances) || ...
        any(~isfinite(distances)) || any(distances <= 0) || ...
        numel(unique(distances)) ~= numel(distances)
    error( ...
        "v2xsim:analysis:InvalidPrrRangeCurve", ...
        "PRR range requires one nonempty curve with unique positive " + ...
        "distance bounds.");
end
if ~isnumeric(denominators) || ~iscolumn(denominators) || ...
        any(~isfinite(denominators)) || any(denominators < 0)
    error( ...
        "v2xsim:analysis:InvalidPrrRangeCurve", ...
        "PRR-range bin denominators must be finite and nonnegative.");
end
hasObservations = denominators > 0;
if ~isnumeric(ratios) || ~iscolumn(ratios) || ...
        any(~isfinite(ratios(hasObservations))) || ...
        any(ratios(hasObservations) < 0) || ...
        any(ratios(hasObservations) > 1) || ...
        any(isfinite(ratios(~hasObservations)))
    error( ...
        "v2xsim:analysis:InvalidPrrRangeValues", ...
        "Observed PRR-range values must be finite probabilities, and " + ...
        "empty bins must have missing PRR.");
end

[distances,order] = sort(distances);
ratios = ratios(order);
hasObservations = hasObservations(order);
anchoredCurve = table( ...
    [0;distances], [options.AnchorPrr;ratios], ...
    [true;false(numel(distances),1)], ...
    VariableNames=["DistanceMeters",metric,"IsSyntheticAnchor"]);

if any(~hasObservations)
    rangeMeters = NaN;
    status = "IncompleteDistanceGrid";
    return
end

firstAtOrBelow = find( ...
    anchoredCurve.(metric) <= options.Threshold,1);
if isempty(firstAtOrBelow)
    rangeMeters = distances(end);
    status = "RightCensored";
elseif firstAtOrBelow == 1
    rangeMeters = 0;
    status = "LeftCensored";
elseif anchoredCurve.(metric)(firstAtOrBelow) == options.Threshold
    rangeMeters = anchoredCurve.DistanceMeters(firstAtOrBelow);
    status = "Crossed";
else
    leftIndex = firstAtOrBelow - 1;
    rangeMeters = interp1( ...
        anchoredCurve.(metric)([leftIndex,firstAtOrBelow]), ...
        anchoredCurve.DistanceMeters([leftIndex,firstAtOrBelow]), ...
        options.Threshold);
    status = "Crossed";
end
end

function validateProbability(value,name)
if value < 0 || value > 1
    error( ...
        "v2xsim:analysis:InvalidPrrThreshold", ...
        "%s must be in the inclusive interval [0, 1].",name);
end
end

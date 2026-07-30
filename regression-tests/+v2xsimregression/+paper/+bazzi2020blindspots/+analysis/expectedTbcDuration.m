function [durationSeconds, durationPeriods] = expectedTbcDuration( ...
        keepProbability, options)
%EXPECTEDTBCDURATION Exact mean TBC from Bazzi Eqs. (7)-(9).
%   The number of reservation intervals has a geometric survival
%   probability p_keep^(m-1). A finite cap truncates that survival sum,
%   while an infinite cap gives the ordinary geometric mean.
%
%   Reference: A. Bazzi et al., IEEE TVT 69(8), 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    keepProbability (1, 1) double
    options.MaximumConsecutiveReservationIntervals (1, 1) double = Inf
    options.MinimumReselectionCounter (1, 1) double = 5
    options.MaximumReselectionCounter (1, 1) double = 15
    options.BeaconRateHz (1, 1) double = 10
end

arguments (Output)
    durationSeconds (1, 1) double
    durationPeriods (1, 1) double
end

% Reuse the PMF helpers as the single source of validation for the paper
% parameters. Unlike a PMF materialization, the closed form remains safe
% for a very large finite cap.
v2xsimregression.paper.bazzi2020blindspots.analysis.tbePmf( ...
    options.MinimumReselectionCounter, ...
    options.MaximumReselectionCounter);
v2xsimregression.paper.bazzi2020blindspots.analysis. ...
    validateRetentionParameters( ...
    keepProbability, ...
    options.MaximumConsecutiveReservationIntervals);
validateBeaconRate(options.BeaconRateHz);

meanEvaluationPeriods = ...
    (options.MinimumReselectionCounter + ...
    options.MaximumReselectionCounter) ./ 2;

if isinf(options.MaximumConsecutiveReservationIntervals)
    meanIntervalCount = 1 ./ (1 - keepProbability);
elseif keepProbability == 1
    meanIntervalCount = ...
        options.MaximumConsecutiveReservationIntervals;
else
    cap = options.MaximumConsecutiveReservationIntervals;
    meanIntervalCount = ...
        (1 - keepProbability .^ cap) ./ (1 - keepProbability);
end

durationPeriods = meanEvaluationPeriods .* meanIntervalCount;
durationSeconds = durationPeriods ./ options.BeaconRateHz;
end

function validateBeaconRate(value)
if ~isreal(value) || ~isfinite(value) || value <= 0
    error( ...
        "v2xsimregression:bazzi2020blindspots:InvalidBeaconRate", ...
        "Beacon rate must be a finite positive scalar.");
end
end

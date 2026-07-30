function [periods, probability, omittedProbability] = tbcPmf( ...
        keepProbability, options)
%TBCPMF Time-between-resource-changes PMF from Bazzi Eqs. (3)-(8).
%   The conditional distribution for m consecutive reservation intervals
%   is formed by convolving the time-before-evaluation PMF m times. The
%   final PMF is the mixture over the capped or legacy interval-count PMF.
%
%   For an infinite cap, OMITTEDPROBABILITY is the geometric interval-count
%   tail excluded according to TailTolerance. The returned probabilities
%   are deliberately not renormalized, so callers can account for this
%   numerical approximation explicitly.
%
%   Reference: A. Bazzi et al., "On Wireless Blind Spots in the C-V2X
%   Sidelink," IEEE Trans. Veh. Technol., vol. 69, no. 8, 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    keepProbability (1, 1) double
    options.MaximumConsecutiveReservationIntervals (1, 1) double = Inf
    options.MinimumReselectionCounter (1, 1) double = 5
    options.MaximumReselectionCounter (1, 1) double = 15
    options.TailTolerance (1, 1) double = 1e-12
end

arguments (Output)
    periods (1, :) double
    probability (1, :) double
    omittedProbability (1, 1) double
end

[evaluationPeriods, evaluationProbability] = ...
    v2xsimregression.paper.bazzi2020blindspots.analysis.tbePmf( ...
    options.MinimumReselectionCounter, ...
    options.MaximumReselectionCounter);
[intervalCounts, intervalCountProbability, omittedProbability] = ...
    v2xsimregression.paper.bazzi2020blindspots.analysis. ...
    intervalCountPmf( ...
    keepProbability, ...
    options.MaximumConsecutiveReservationIntervals, ...
    TailTolerance=options.TailTolerance);

% Index k+1 represents a duration of k beacon periods. Keeping the zero
% entries in the single-interval vector makes ordinary CONV implement the
% discrete duration convolution without custom index arithmetic.
singleIntervalProbability = ...
    zeros(1, options.MaximumReselectionCounter + 1);
singleIntervalProbability(evaluationPeriods + 1) = ...
    evaluationProbability;

maximumDuration = ...
    intervalCounts(end) * options.MaximumReselectionCounter;
validateSupportedDuration(maximumDuration);
mixtureProbability = zeros(1, maximumDuration + 1);
conditionalProbability = 1;

for intervalIndex = 1:numel(intervalCounts)
    conditionalProbability = conv( ...
        conditionalProbability, singleIntervalProbability);
    mixtureProbability(1:numel(conditionalProbability)) = ...
        mixtureProbability(1:numel(conditionalProbability)) + ...
        intervalCountProbability(intervalIndex) .* ...
        conditionalProbability;
end

firstNonzeroIndex = find(mixtureProbability > 0, 1, "first");
lastNonzeroIndex = find(mixtureProbability > 0, 1, "last");
periods = (firstNonzeroIndex - 1):(lastNonzeroIndex - 1);
probability = mixtureProbability( ...
    firstNonzeroIndex:lastNonzeroIndex);
end

function validateSupportedDuration(maximumDuration)
maximumSupportedDuration = 1e6;
if maximumDuration > maximumSupportedDuration
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "AnalyticalSupportTooLarge", ...
        "The requested TBC convolution needs support through %g " + ...
        "periods; the analytical oracle supports at most %g.", ...
        maximumDuration, maximumSupportedDuration);
end
end

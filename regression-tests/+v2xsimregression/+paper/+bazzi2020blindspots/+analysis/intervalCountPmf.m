function [intervalCounts, probability, omittedProbability] = ...
        intervalCountPmf( ...
        keepProbability, maximumIntervals, options)
%INTERVALCOUNTPMF Number of TBE intervals in a TBC, Bazzi Eq. (2).
%   The finite-cap result is the capped geometric distribution proposed in
%   the paper. An infinite cap gives the legacy geometric distribution and
%   is truncated only after its omitted tail is no greater than
%   TailTolerance. The omitted mass is returned explicitly and is never
%   silently renormalized.
%
%   Reference: A. Bazzi et al., IEEE TVT 69(8), 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    keepProbability (1, 1) double
    maximumIntervals (1, 1) double = Inf
    options.TailTolerance (1, 1) double = 1e-12
end

arguments (Output)
    intervalCounts (1, :) double
    probability (1, :) double
    omittedProbability (1, 1) double
end

v2xsimregression.paper.bazzi2020blindspots.analysis. ...
    validateRetentionParameters(keepProbability, maximumIntervals);
validateTailTolerance(options.TailTolerance);

if isinf(maximumIntervals)
    if keepProbability == 0
        intervalCounts = 1;
        probability = 1;
        omittedProbability = 0;
        return
    end

    % For a geometric distribution, Pr(M > m) = p_keep^m. Choose the
    % smallest retained support whose omitted mass meets the requested
    % tolerance.
    maximumRetainedCount = max(1, ceil( ...
        log(options.TailTolerance) ./ log(keepProbability)));
    validateSupportedIntervalCount(maximumRetainedCount);
    intervalCounts = 1:maximumRetainedCount;
    probability = (1 - keepProbability) .* ...
        keepProbability .^ (intervalCounts - 1);
    omittedProbability = keepProbability .^ maximumRetainedCount;
    return
end

validateSupportedIntervalCount(maximumIntervals);
intervalCounts = 1:maximumIntervals;
probability = (1 - keepProbability) .* ...
    keepProbability .^ (intervalCounts - 1);

% Equation (2) assigns the full surviving geometric tail to the cap.
probability(end) = keepProbability .^ (maximumIntervals - 1);
omittedProbability = 0;
end

function validateSupportedIntervalCount(intervalCount)
maximumSupportedIntervalCount = 1024;
if intervalCount > maximumSupportedIntervalCount
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "AnalyticalSupportTooLarge", ...
        "The requested interval-count distribution needs %g terms; " + ...
        "the analytical oracle supports at most %g. Reduce the finite " + ...
        "cap or use a larger TailTolerance.", ...
        intervalCount, maximumSupportedIntervalCount);
end
end

function validateTailTolerance(value)
if ~isreal(value) || ~isfinite(value) || value <= 0 || value >= 1
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidTailTolerance", ...
        "Tail tolerance must be a finite scalar strictly between 0 and 1.");
end
end

function probability = resourceUnchangedProbability( ...
        elapsedPeriods, tbcPeriods, tbcProbability)
%RESOURCEUNCHANGEDPROBABILITY Residual TBC probability, Bazzi Eqs. (10)-(11).
%   For S(n) = sum_l max(l-n+1, 0) P_TBC(l), the stationary probability
%   that a resource remains unchanged for n periods is
%
%       P_unchanged(n) = S(n) / (1 + S(1)).
%
%   The denominator is constant; it must not be recomputed as 1+S(n).
%   Integer elapsed periods reproduce the paper's discrete model.
%   Noninteger values provide its natural piecewise-linear interpolation.
%
%   Reference: A. Bazzi et al., IEEE TVT 69(8), 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    elapsedPeriods double
    tbcPeriods (1, :) double
    tbcProbability (1, :) double
end

arguments (Output)
    probability double
end

validateElapsedPeriods(elapsedPeriods);
validateTbcDistribution(tbcPeriods, tbcProbability);

originalSize = size(elapsedPeriods);
remainingPeriods = max( ...
    tbcPeriods - elapsedPeriods(:) + 1, 0);
survivalMass = remainingPeriods * tbcProbability(:);

% S(1) is the expected TBC length in beacon periods.
denominator = 1 + tbcPeriods * tbcProbability(:);
probability = reshape(survivalMass ./ denominator, originalSize);
end

function validateElapsedPeriods(value)
if ~isreal(value) || any(~isfinite(value), "all") || ...
        any(value < 0, "all")
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidElapsedPeriods", ...
        "Elapsed periods must be finite, real, and nonnegative.");
end
end

function validateTbcDistribution(periods, probability)
isValidPeriods = ...
    isreal(periods) && all(isfinite(periods), "all") && ...
    all(periods >= 1, "all") && ...
    all(fix(periods) == periods, "all") && ...
    all(diff(periods) > 0, "all");
isValidProbability = ...
    isreal(probability) && all(isfinite(probability), "all") && ...
    all(probability >= 0, "all") && ...
    numel(probability) == numel(periods) && ...
    sum(probability) > 0 && sum(probability) <= 1 + 1e-12;

if ~isValidPeriods || ~isValidProbability
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidTbcDistribution", ...
        "TBC periods must be strictly increasing positive integers, " + ...
        "with matching finite nonnegative probabilities of total mass " + ...
        "no greater than one.");
end
end

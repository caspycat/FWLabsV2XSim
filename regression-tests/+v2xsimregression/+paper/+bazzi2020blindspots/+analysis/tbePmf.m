function [periods, probability] = tbePmf( ...
        minimumPeriods, maximumPeriods)
%TBEPMF Time-before-evaluation distribution from Bazzi et al., Eq. (1).
%   [PERIODS, PROBABILITY] = TBEPMF(MINIMUMPERIODS, MAXIMUMPERIODS)
%   returns the discrete-uniform distribution of the number of beacon
%   periods in one reselection-counter interval.
%
%   Reference: A. Bazzi et al., "On Wireless Blind Spots in the C-V2X
%   Sidelink," IEEE Trans. Veh. Technol., vol. 69, no. 8, 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    minimumPeriods (1, 1) double
    maximumPeriods (1, 1) double
end

arguments (Output)
    periods (1, :) double
    probability (1, :) double
end

validateIntervalBounds(minimumPeriods, maximumPeriods);
validateSupportedOutcomeCount( ...
    maximumPeriods - minimumPeriods + 1);

periods = minimumPeriods:maximumPeriods;
probability = ones(size(periods), "double") ./ numel(periods);
end

function validateIntervalBounds(minimumPeriods, maximumPeriods)
areValidScalars = ...
    isreal(minimumPeriods) && isreal(maximumPeriods) && ...
    isfinite(minimumPeriods) && isfinite(maximumPeriods) && ...
    minimumPeriods >= 1 && maximumPeriods >= minimumPeriods && ...
    fix(minimumPeriods) == minimumPeriods && ...
    fix(maximumPeriods) == maximumPeriods;
if ~areValidScalars
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidTbeIntervalBounds", ...
        "TBE bounds must be finite positive integers with the maximum " + ...
        "greater than or equal to the minimum.");
end
end

function validateSupportedOutcomeCount(outcomeCount)
maximumSupportedOutcomeCount = 1e6;
if outcomeCount > maximumSupportedOutcomeCount
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "AnalyticalSupportTooLarge", ...
        "The requested TBE distribution has %g outcomes; the " + ...
        "analytical oracle supports at most %g.", ...
        outcomeCount, maximumSupportedOutcomeCount);
end
end

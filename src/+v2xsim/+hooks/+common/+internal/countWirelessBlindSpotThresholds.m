function [greaterOrEqualCounts, shorterCounts] = ...
        countWirelessBlindSpotThresholds( ...
            receivedAges, neverReceivedEntryAges, thresholds)
%COUNTWIRELESSBLINDSPOTTHRESHOLDS Count one WBS snapshot by age.
%   RECEIVEDAGES contains the ages of links with a successful reception.
%   NEVERRECEIVEDENTRYAGES contains in-range ages for links that have not
%   received successfully. THRESHOLDS must be an increasing row of
%   positive finite values.
%
%   A received age equal to a threshold contributes to GREATEROREQUALCOUNTS
%   and not SHORTERCOUNTS. A never-received entry age must be strictly
%   greater than a threshold to contribute to GREATEROREQUALCOUNTS.

arguments (Input)
    receivedAges (:, 1) double
    neverReceivedEntryAges (:, 1) double
    thresholds (1, :) double
end

arguments (Output)
    greaterOrEqualCounts (1, :) double
    shorterCounts (1, :) double
end

% histcounts uses left-inclusive, right-exclusive bins. Consequently, the
% cumulative counts before each ordinary edge are exactly the number of
% received ages strictly below that threshold.
receivedBinCounts = histcounts( ...
    receivedAges, [-Inf, thresholds, Inf]);
receivedBelowCounts = cumsum(receivedBinCounts(1:end - 1));
receivedGreaterOrEqualCounts = ...
    numel(receivedAges) - receivedBelowCounts;

% The ordinary below-threshold count includes zero and any negative value.
% Remove those values to retain the recorder's strict 0 < age condition.
receivedPositiveBelowCounts = ...
    receivedBelowCounts - nnz(receivedAges <= 0);

% For a positive finite double, threshold + eps(threshold) is the next
% representable value. Values below the shifted edge are therefore exactly
% those less than or equal to the original threshold.
strictGreaterEdges = [ ...
    -Inf, thresholds + eps(thresholds), Inf];
entryBinCounts = histcounts( ...
    neverReceivedEntryAges, strictGreaterEdges);
entryLessOrEqualCounts = cumsum(entryBinCounts(1:end - 1));
entryGreaterCounts = ...
    numel(neverReceivedEntryAges) - entryLessOrEqualCounts;

greaterOrEqualCounts = ...
    receivedGreaterOrEqualCounts + entryGreaterCounts;
shorterCounts = receivedPositiveBelowCounts;
end

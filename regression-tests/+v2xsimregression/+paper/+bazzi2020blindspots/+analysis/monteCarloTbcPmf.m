function [periods, probability, sampleDurations] = ...
        monteCarloTbcPmf(keepProbability, options)
%MONTECARLOTBCPMF Independent sampled validation of the Bazzi TBC model.
%   A private MT19937 stream owns every retention and reselection-counter
%   draw. This function never reads or advances MATLAB's global stream.
%
%   Reference: A. Bazzi et al., IEEE TVT 69(8), 2020,
%   DOI 10.1109/TVT.2020.3001074.

arguments (Input)
    keepProbability (1, 1) double
    options.NumberOfSamples (1, 1) double = 100000
    options.MaximumConsecutiveReservationIntervals (1, 1) double = Inf
    options.MinimumReselectionCounter (1, 1) double = 5
    options.MaximumReselectionCounter (1, 1) double = 15
    options.Seed (1, 1) double = 2020
end

arguments (Output)
    periods (1, :) double
    probability (1, :) double
    sampleDurations (:, 1) double
end

% The analytical helpers provide one shared validation contract for the
% scientific model parameters.
v2xsimregression.paper.bazzi2020blindspots.analysis.tbePmf( ...
    options.MinimumReselectionCounter, ...
    options.MaximumReselectionCounter);
v2xsimregression.paper.bazzi2020blindspots.analysis. ...
    validateRetentionParameters( ...
    keepProbability, ...
    options.MaximumConsecutiveReservationIntervals);
validateNumberOfSamples(options.NumberOfSamples);
validateSeed(options.Seed);

stream = RandStream("mt19937ar", Seed=options.Seed);
intervalCounts = ones(options.NumberOfSamples, 1);
activeSamples = true(options.NumberOfSamples, 1);

% The initial reselection-counter interval counts as one. Further
% intervals are added only after an accepted p_keep decision. At the cap,
% no retention draw is consumed, matching the allocator semantics.
while any(activeSamples)
    eligibleSamples = activeSamples & ...
        intervalCounts < ...
        options.MaximumConsecutiveReservationIntervals;
    activeSamples(:) = false;
    if ~any(eligibleSamples)
        break
    end

    eligibleIndices = find(eligibleSamples);
    kept = rand(stream, numel(eligibleIndices), 1) < keepProbability;
    keptIndices = eligibleIndices(kept);
    intervalCounts(keptIndices) = intervalCounts(keptIndices) + 1;
    activeSamples(keptIndices) = true;
end

sampleDurations = zeros(options.NumberOfSamples, 1);
for intervalIndex = 1:max(intervalCounts)
    participatingSamples = intervalCounts >= intervalIndex;
    drawCount = nnz(participatingSamples);
    sampleDurations(participatingSamples) = ...
        sampleDurations(participatingSamples) + ...
        randi( ...
        stream, ...
        [options.MinimumReselectionCounter, ...
        options.MaximumReselectionCounter], ...
        drawCount, 1);
end

minimumDuration = min(sampleDurations);
maximumDuration = max(sampleDurations);
periods = minimumDuration:maximumDuration;
sampleCounts = accumarray( ...
    sampleDurations - minimumDuration + 1, ...
    1, ...
    [numel(periods), 1]);
probability = (sampleCounts ./ options.NumberOfSamples).';
end

function validateNumberOfSamples(value)
if ~isreal(value) || ~isfinite(value) || value < 1 || ...
        fix(value) ~= value
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidMonteCarloSampleCount", ...
        "NumberOfSamples must be a finite positive integer.");
end
end

function validateSeed(value)
if ~isreal(value) || ~isfinite(value) || value < 0 || ...
        fix(value) ~= value || value > double(intmax("uint32"))
    error( ...
        "v2xsimregression:bazzi2020blindspots:" + ...
        "InvalidMonteCarloSeed", ...
        "Seed must be an integer in the uint32 range.");
end
end

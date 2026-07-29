function result = calculateCumulativeSinrCounterfactuals( ...
        priorCombinedSinr,usefulPower,unattributedDenominatorPower, ...
        interfererPowers)
%CALCULATECUMULATIVESINRCOUNTERFACTUALS Remove terminal-attempt sources.
%   The simulator combines HARQ attempts by summing their linear SINRs.
%   PRIORCOMBINEDSINR therefore remains unchanged while interference
%   sources are removed only from the current, terminal attempt.
%
%   UNATTRIBUTEDDENOMINATORPOWER contains thermal noise and any aggregate
%   source that is not represented by INTERFERERPOWERS. The all-removal
%   result removes every explicitly enumerated source, not unattributed
%   power.

arguments (Input)
    priorCombinedSinr (1,1) double {mustBeReal,mustBeNonnegative}
    usefulPower (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
    unattributedDenominatorPower (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeNonnegative}
    interfererPowers (:,1) double {mustBeReal,mustBeNonnegative}
end
arguments (Output)
    result (1,1) struct
end

if isnan(priorCombinedSinr) || any(isnan(interfererPowers))
    error( ...
        "v2xsim:analysis:InvalidCounterfactualPower", ...
        "SINR and interference powers cannot contain NaN.");
end

currentDenominator = unattributedDenominatorPower + ...
    sum(interfererPowers);
observedCurrentSinr = safeRatio(usefulPower,currentDenominator);

interfererCount = numel(interfererPowers);
withoutEach = zeros(interfererCount,1);
for interfererIndex = 1:interfererCount
    remainingPowers = interfererPowers;
    remainingPowers(interfererIndex) = [];
    denominatorWithoutInterferer = ...
        unattributedDenominatorPower + sum(remainingPowers);
    withoutEach(interfererIndex) = priorCombinedSinr + ...
        safeRatio(usefulPower,denominatorWithoutInterferer);
end

result = struct( ...
    ObservedSinr=priorCombinedSinr + observedCurrentSinr, ...
    SinrWithoutEachInterferer=withoutEach, ...
    SinrWithoutAllInterferers=priorCombinedSinr + ...
        safeRatio(usefulPower,unattributedDenominatorPower));
end

function ratio = safeRatio(numerator,denominator)
if numerator == 0
    ratio = 0;
elseif denominator == 0
    ratio = Inf;
else
    ratio = numerator / denominator;
end
end

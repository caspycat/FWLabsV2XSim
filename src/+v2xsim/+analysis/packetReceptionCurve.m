function curve = packetReceptionCurve( ...
        terminalFates,distanceGridMeters,options)
%PACKETRECEPTIONCURVE Pool terminal fate counts on a fixed distance grid.
%   The returned DeliveryPrr includes blocked packets in its denominator:
%       correct / (correct + error + blocked)
%   RadioPrr conditions on a radio attempt:
%       correct / (correct + error)
%   BlockingRate is blocked / total. Empty bins are retained with zero
%   counts and NaN ratios so that callers cannot silently change the grid.

arguments (Input)
    terminalFates table
    distanceGridMeters (:,1) double ...
        {mustBeReal,mustBeFinite,mustBePositive}
    options.GroupVariables (1,:) string = ...
        ["Technology","Channel","PacketType"]
end
arguments (Output)
    curve table
end

if isempty(distanceGridMeters) || ...
        any(diff(distanceGridMeters) <= 0)
    error( ...
        "v2xsim:analysis:InvalidPrrDistanceGrid", ...
        "Distance grid values must be strictly increasing.");
end
terminalFates = ...
    v2xsim.analysis.aggregateTerminalPacketFates( ...
        terminalFates);
groupVariables = options.GroupVariables;
if numel(unique(groupVariables)) ~= numel(groupVariables) || ...
        any(~ismember( ...
            groupVariables, ...
            string(terminalFates.Properties.VariableNames)))
    error( ...
        "v2xsim:analysis:InvalidPrrGrouping", ...
        "GroupVariables must uniquely identify packet-fate variables.");
end

metricNames = [ ...
    "DistanceUpperBoundMeters","CorrectCount","ErrorCount", ...
    "BlockedCount","TotalCount","RadioAttemptCount", ...
    "DeliveryPrr","RadioPrr","BlockingRate"];
if any(ismember(groupVariables,metricNames))
    error( ...
        "v2xsim:analysis:InvalidPrrGrouping", ...
        "GroupVariables conflict with PRR metric names.");
end

if isempty(terminalFates)
    curve = emptyCurve(terminalFates,groupVariables);
    return
end
if isempty(groupVariables)
    groupIndices = ones(height(terminalFates),1);
    groupRows = table(1,VariableNames="Group");
else
    [groupIndices,groupRows] = findgroups( ...
        terminalFates(:,groupVariables));
end
groupCount = height(groupRows);
binCount = numel(distanceGridMeters);
correctCounts = zeros(groupCount,binCount);
errorCounts = zeros(groupCount,binCount);
blockedCounts = zeros(groupCount,binCount);

distances = terminalFates.TrueDistanceMeters;
binIndices = sum( ...
    distances >= distanceGridMeters.',2) + 1;
outcomes = string(terminalFates.Outcome);
for fateIndex = 1:height(terminalFates)
    binIndex = binIndices(fateIndex);
    if binIndex > binCount
        continue
    end
    groupIndex = groupIndices(fateIndex);
    if outcomes(fateIndex) == "correct"
        correctCounts(groupIndex,binIndex) = ...
            correctCounts(groupIndex,binIndex) + 1;
    elseif outcomes(fateIndex) == "error"
        errorCounts(groupIndex,binIndex) = ...
            errorCounts(groupIndex,binIndex) + 1;
    elseif outcomes(fateIndex) == "blocked"
        blockedCounts(groupIndex,binIndex) = ...
            blockedCounts(groupIndex,binIndex) + 1;
    end
end

if isempty(groupVariables)
    groupColumns = table();
else
    groupColumns = groupRows( ...
        repelem((1:groupCount).',binCount),:);
end
correctCounts = reshape(correctCounts.',[],1);
errorCounts = reshape(errorCounts.',[],1);
blockedCounts = reshape(blockedCounts.',[],1);
totalCounts = correctCounts + errorCounts + blockedCounts;
radioAttemptCounts = correctCounts + errorCounts;
deliveryPrr = divideOrNan(correctCounts,totalCounts);
radioPrr = divideOrNan(correctCounts,radioAttemptCounts);
blockingRate = divideOrNan(blockedCounts,totalCounts);
metricColumns = table( ...
    repmat(distanceGridMeters,groupCount,1), ...
    correctCounts,errorCounts,blockedCounts,totalCounts, ...
    radioAttemptCounts,deliveryPrr,radioPrr,blockingRate, ...
    VariableNames=metricNames);
curve = [groupColumns,metricColumns];
end

function values = divideOrNan(numerator,denominator)
values = nan(size(numerator));
hasDenominator = denominator > 0;
values(hasDenominator) = ...
    numerator(hasDenominator) ./ denominator(hasDenominator);
end

function curve = emptyCurve(terminalFates,groupVariables)
if isempty(groupVariables)
    groupColumns = table();
else
    groupColumns = terminalFates( ...
        false(height(terminalFates),1),groupVariables);
end
metricColumns = table( ...
    zeros(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),zeros(0,1), ...
    VariableNames=[ ...
        "DistanceUpperBoundMeters","CorrectCount","ErrorCount", ...
        "BlockedCount","TotalCount","RadioAttemptCount", ...
        "DeliveryPrr","RadioPrr","BlockingRate"]);
curve = [groupColumns,metricColumns];
end

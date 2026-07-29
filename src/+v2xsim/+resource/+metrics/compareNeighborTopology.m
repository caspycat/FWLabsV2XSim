function comparison = compareNeighborTopology( ...
        ueIds,apparentDistanceMeters,trueDistanceMeters,options)
%COMPARENEIGHBORTOPOLOGY Compare controller-visible and true neighborhoods.
%   Ties in both rankings are resolved by stable UE identity. Kendall
%   distance is the normalized inversion count and is missing when an ego
%   has fewer than two other UEs.

arguments (Input)
    ueIds string
    apparentDistanceMeters (:,:) double {mustBeReal,mustBeNonnegative}
    trueDistanceMeters (:,:) double {mustBeReal,mustBeNonnegative}
    options.TopK (1,1) double ...
        {mustBeInteger,mustBePositive} = 10
    options.NeighborRangesMeters (1,:) double ...
        {mustBeReal,mustBeFinite,mustBePositive} = zeros(1,0)
    options.IncludeRankDisplacement (1,1) logical = true
end

ueIds = ueIds(:);
v2xsim.resource.validation.mustBeUeIds(ueIds);
ueCount = numel(ueIds);
expectedSize = [ueCount ueCount];
if ~isequal(size(apparentDistanceMeters),expectedSize) || ...
        ~isequal(size(trueDistanceMeters),expectedSize) || ...
        any(isnan(apparentDistanceMeters),"all") || ...
        any(isnan(trueDistanceMeters),"all")
    error( ...
        "v2xsim:resource:metrics:DistanceMatrixSizeMismatch", ...
        "Distance matrices must be non-NaN square matrices aligned " + ...
        "with UeIds.");
end
ranges = unique(options.NeighborRangesMeters,"sorted");

kendallDistance = nan(ueCount,1);
meanAbsoluteRankDisplacement = nan(ueCount,1);
maximumAbsoluteRankDisplacement = nan(ueCount,1);
topKNeighborJaccard = nan(ueCount,1);
effectiveTopK = zeros(ueCount,1);

rankRowCount = 0;
if options.IncludeRankDisplacement
    rankRowCount = ueCount * max(ueCount - 1,0);
end
rankEgoIds = strings(rankRowCount,1);
rankNeighborIds = strings(rankRowCount,1);
trueRanks = zeros(rankRowCount,1);
apparentRanks = zeros(rankRowCount,1);
signedDisplacements = zeros(rankRowCount,1);
rankCursor = 0;

rangeRowCount = ueCount * numel(ranges);
rangeEgoIds = strings(rangeRowCount,1);
rangeValues = zeros(rangeRowCount,1);
trueCounts = zeros(rangeRowCount,1);
apparentCounts = zeros(rangeRowCount,1);
missedCounts = zeros(rangeRowCount,1);
phantomCounts = zeros(rangeRowCount,1);
rangeJaccards = nan(rangeRowCount,1);
rangeCursor = 0;

for egoRow = 1:ueCount
    neighborRows = [1:egoRow - 1 egoRow + 1:ueCount].';
    neighborCount = numel(neighborRows);
    trueOrder = stableOrder( ...
        neighborRows,trueDistanceMeters(egoRow,neighborRows),ueIds);
    apparentOrder = stableOrder( ...
        neighborRows, ...
        apparentDistanceMeters(egoRow,neighborRows),ueIds);

    trueRankByRow = zeros(ueCount,1);
    apparentRankByRow = zeros(ueCount,1);
    trueRankByRow(trueOrder) = (1:neighborCount).';
    apparentRankByRow(apparentOrder) = (1:neighborCount).';
    displacements = ...
        apparentRankByRow(neighborRows) - ...
        trueRankByRow(neighborRows);
    if neighborCount >= 2
        apparentRanksInTrueOrder = ...
            apparentRankByRow(trueOrder);
        inversionCount = countInversions( ...
            apparentRanksInTrueOrder);
        kendallDistance(egoRow) = inversionCount / ...
            nchoosek(neighborCount,2);
    end
    if neighborCount > 0
        absoluteDisplacements = abs(displacements);
        meanAbsoluteRankDisplacement(egoRow) = ...
            mean(absoluteDisplacements);
        maximumAbsoluteRankDisplacement(egoRow) = ...
            max(absoluteDisplacements);
        effectiveTopK(egoRow) = min(options.TopK,neighborCount);
        trueTop = trueOrder(1:effectiveTopK(egoRow));
        apparentTop = apparentOrder(1:effectiveTopK(egoRow));
        topKNeighborJaccard(egoRow) = setJaccard( ...
            trueTop,apparentTop);

        if options.IncludeRankDisplacement
            rows = rankCursor + (1:neighborCount);
            rankEgoIds(rows) = ueIds(egoRow);
            rankNeighborIds(rows) = ueIds(neighborRows);
            trueRanks(rows) = trueRankByRow(neighborRows);
            apparentRanks(rows) = apparentRankByRow(neighborRows);
            signedDisplacements(rows) = displacements;
            rankCursor = rankCursor + neighborCount;
        end
    end

    for rangeMeters = ranges
        rangeCursor = rangeCursor + 1;
        trueSet = neighborRows( ...
            trueDistanceMeters(egoRow,neighborRows) < rangeMeters);
        apparentSet = neighborRows( ...
            apparentDistanceMeters(egoRow,neighborRows) < ...
            rangeMeters);
        rangeEgoIds(rangeCursor) = ueIds(egoRow);
        rangeValues(rangeCursor) = rangeMeters;
        trueCounts(rangeCursor) = numel(trueSet);
        apparentCounts(rangeCursor) = numel(apparentSet);
        missedCounts(rangeCursor) = ...
            numel(setdiff(trueSet,apparentSet));
        phantomCounts(rangeCursor) = ...
            numel(setdiff(apparentSet,trueSet));
        rangeJaccards(rangeCursor) = ...
            setJaccard(trueSet,apparentSet);
    end
end

comparison.Topology = table( ...
    ueIds,kendallDistance, ...
    meanAbsoluteRankDisplacement, ...
    maximumAbsoluteRankDisplacement,effectiveTopK, ...
    topKNeighborJaccard, ...
    VariableNames=[ ...
        "EgoUeId","NormalizedKendallTauDistance", ...
        "MeanAbsoluteRankDisplacement", ...
        "MaximumAbsoluteRankDisplacement","TopK", ...
        "TopKNeighborJaccard"]);
comparison.RankDisplacement = table( ...
    rankEgoIds,rankNeighborIds,trueRanks,apparentRanks, ...
    signedDisplacements,abs(signedDisplacements), ...
    VariableNames=[ ...
        "EgoUeId","NeighborUeId","TrueRank","ApparentRank", ...
        "SignedRankDisplacement","AbsoluteRankDisplacement"]);
comparison.RangeTopology = table( ...
    rangeEgoIds,rangeValues,trueCounts,apparentCounts, ...
    missedCounts,phantomCounts,rangeJaccards, ...
    VariableNames=[ ...
        "EgoUeId","RangeMeters","TrueNeighborCount", ...
        "ApparentNeighborCount","MissedNeighborCount", ...
        "PhantomNeighborCount","NeighborSetJaccard"]);
end

function order = stableOrder(rows,distances,ueIds)
if isempty(rows)
    order = zeros(0,1);
    return
end
ranking = table( ...
    distances(:),ueIds(rows),rows, ...
    VariableNames=["DistanceMeters","UeId","RowIndex"]);
ranking = sortrows(ranking,["DistanceMeters","UeId","RowIndex"]);
order = ranking.RowIndex;
end

function inversionCount = countInversions(permutation)
elementCount = numel(permutation);
tree = zeros(elementCount + 1,1);
inversionCount = 0;
for index = elementCount:-1:1
    value = permutation(index);
    queryIndex = value;
    while queryIndex > 0
        inversionCount = inversionCount + tree(queryIndex);
        queryIndex = bitand(queryIndex,queryIndex - 1);
    end
    updateIndex = value + 1;
    while updateIndex <= elementCount + 1
        tree(updateIndex) = tree(updateIndex) + 1;
        updateIndex = updateIndex + ...
            (updateIndex - bitand(updateIndex,updateIndex - 1));
    end
end
end

function value = setJaccard(left,right)
unionCount = numel(union(left,right));
if unionCount == 0
    value = 1;
else
    value = numel(intersect(left,right)) / unionCount;
end
end

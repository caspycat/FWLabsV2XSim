function groupIndex = cyclicUpdateGroup(updateIndex, groupCount)
%CYCLICUPDATEGROUP Map a one-based update number to a cyclic group.

arguments (Input)
    updateIndex (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive}
    groupCount (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive}
end

groupIndex = mod(updateIndex - 1, groupCount) + 1;
end

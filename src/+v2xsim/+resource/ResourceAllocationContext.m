classdef ResourceAllocationContext
    %RESOURCEALLOCATIONCONTEXT Slice-scoped inputs shared by allocators.
    %   CurrentSlot is an absolute, zero-based simulation slot. UeIds gives
    %   the row identity for NewPacketMask and EligibilityMask.

    properties (SetAccess = immutable)
        NetworkSliceId (1, 1) v2xsim.network.NetworkSliceId
        UeIds (:, 1) string = strings(0, 1)
        CurrentSlot (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBeNonnegative} = 0
        NewPacketMask (:, 1) logical = false(0, 1)
        EligibilityMask (:, :) logical = false(0, 0)
        SelectionOriginSlot (:, 1) double = zeros(0, 1)
    end

    methods
        function obj = ResourceAllocationContext( ...
                networkSliceId, ueIds, currentSlot, ...
                newPacketMask, eligibilityMask,selectionOriginSlot)
            arguments (Input)
                networkSliceId (1, 1) v2xsim.network.NetworkSliceId
                ueIds string
                currentSlot (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBeNonnegative}
                newPacketMask logical
                eligibilityMask (:, :) logical
                selectionOriginSlot double = []
            end

            if (~isvector(ueIds) && ~isempty(ueIds)) || ...
                    (~isvector(newPacketMask) && ~isempty(newPacketMask))
                error( ...
                    "v2xsim:resource:ContextRowCountMismatch", ...
                    "UeIds and NewPacketMask must be vectors.");
            end
            ueIds = ueIds(:);
            newPacketMask = newPacketMask(:);
            v2xsim.resource.validation.mustBeUeIds(ueIds);

            if numel(newPacketMask) ~= numel(ueIds)
                error( ...
                    "v2xsim:resource:ContextRowCountMismatch", ...
                    "NewPacketMask must contain one value per UE.");
            end
            if size(eligibilityMask, 1) ~= numel(ueIds)
                error( ...
                    "v2xsim:resource:ContextRowCountMismatch", ...
                    "EligibilityMask must contain one row per UE.");
            end
            if isempty(selectionOriginSlot)
                selectionOriginSlot = repmat(currentSlot,numel(ueIds),1);
            elseif ~isvector(selectionOriginSlot) || ...
                    numel(selectionOriginSlot) ~= numel(ueIds) || ...
                    any(~isfinite(selectionOriginSlot)) || ...
                    any(selectionOriginSlot < 0) || ...
                    any(mod(selectionOriginSlot,1) ~= 0)
                error( ...
                    "v2xsim:resource:ContextRowCountMismatch", ...
                    "SelectionOriginSlot must contain one nonnegative " + ...
                    "integer slot per UE.");
            end

            obj.NetworkSliceId = networkSliceId;
            obj.UeIds = ueIds;
            obj.CurrentSlot = currentSlot;
            obj.NewPacketMask = newPacketMask;
            obj.EligibilityMask = eligibilityMask;
            obj.SelectionOriginSlot = selectionOriginSlot(:);
        end
    end
end

classdef SensingSnapshot
    %SENSINGSNAPSHOT Row-keyed autonomous sensing for one network slice.
    %   EnergyWattsPerMHz and ReservedMask have one row per UE and one
    %   column per local beacon resource.

    properties (SetAccess = immutable)
        NetworkSliceId (1, 1) v2xsim.network.NetworkSliceId
        UeIds (:, 1) string = strings(0, 1)
        EnergyWattsPerMHz (:, :) double = zeros(0, 0)
        ReservedMask (:, :) logical = false(0, 0)
    end

    methods
        function obj = SensingSnapshot( ...
                networkSliceId, ueIds, energyWattsPerMHz, reservedMask)
            arguments (Input)
                networkSliceId (1, 1) ...
                    v2xsim.network.NetworkSliceId = ...
                    v2xsim.network.NetworkSliceId()
                ueIds string = strings(0, 1)
                energyWattsPerMHz (:, :) double ...
                    {mustBeReal} = zeros(0, 0)
                reservedMask (:, :) logical = false(0, 0)
            end

            if ~isvector(ueIds) && ~isempty(ueIds)
                error( ...
                    "v2xsim:resource:SensingSnapshotSizeMismatch", ...
                    "Sensing UE identifiers must be a vector.");
            end
            ueIds = ueIds(:);
            v2xsim.resource.validation.mustBeUeIds(ueIds);
            if size(energyWattsPerMHz, 1) ~= numel(ueIds) || ...
                    ~isequal(size(energyWattsPerMHz), size(reservedMask))
                error( ...
                    "v2xsim:resource:SensingSnapshotSizeMismatch", ...
                    "Sensing arrays must have one aligned row per UE " + ...
                    "and identical dimensions.");
            end
            if any(isnan(energyWattsPerMHz), "all") || ...
                    any(energyWattsPerMHz < 0, "all")
                error( ...
                    "v2xsim:resource:InvalidSensedEnergy", ...
                    "Sensed energy must be nonnegative and cannot " + ...
                    "contain NaN.");
            end

            obj.NetworkSliceId = networkSliceId;
            obj.UeIds = ueIds;
            obj.EnergyWattsPerMHz = energyWattsPerMHz;
            obj.ReservedMask = reservedMask;
        end
    end
end

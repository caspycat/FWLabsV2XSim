classdef SensingHistory
    %SENSINGHISTORY Slice-scoped shared C-V2X sensing state.
    %   Energy and decoded reservations are deliberately separate. Energy
    %   retains one sample per grid resource for each configured grid
    %   period; reservations retain the latest decoded future-use map.

    properties (SetAccess = immutable)
        Grid (1,1) v2xsim.resource.BRResourceGrid
        WindowPeriodCount (1,1) double ...
            {mustBeInteger,mustBePositive} = 1
    end

    properties (SetAccess = private)
        UeIds (:,1) string = strings(0,1)
        EnergyHistory (:,:,:) double = zeros(1,0,0)
        ReservationHistory (:,:,:) logical = false(1,0,0)
        LastUpdatedSlot (1,1) double = -1
    end

    methods
        function obj = SensingHistory(grid,windowPeriodCount)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                windowPeriodCount (1,1) double ...
                    {mustBeInteger,mustBePositive}
            end

            obj.Grid = grid;
            obj.WindowPeriodCount = windowPeriodCount;
            obj.EnergyHistory = zeros( ...
                windowPeriodCount,grid.ResourceCount,0);
            obj.ReservationHistory = false(1,grid.ResourceCount,0);
        end

        function obj = synchronizeUes(obj,ueIds)
            arguments (Input)
                obj (1,1)
                ueIds string
            end

            ueIds = ueIds(:);
            v2xsim.resource.validation.mustBeUeIds(ueIds);
            [retained,locations] = ismember(ueIds,obj.UeIds);
            energy = zeros( ...
                obj.WindowPeriodCount,obj.Grid.ResourceCount, ...
                numel(ueIds));
            reservations = false(1,obj.Grid.ResourceCount,numel(ueIds));
            energy(:,:,retained) = ...
                obj.EnergyHistory(:,:,locations(retained));
            reservations(:,:,retained) = ...
                obj.ReservationHistory(:,:,locations(retained));
            obj.UeIds = ueIds;
            obj.EnergyHistory = energy;
            obj.ReservationHistory = reservations;
        end

        function obj = update( ...
                obj,networkSliceId,ueIds,absoluteSlot, ...
                currentSlotEnergyWattsPerMHz,reservedMask)
            arguments (Input)
                obj (1,1)
                networkSliceId (1,1) v2xsim.network.NetworkSliceId
                ueIds string
                absoluteSlot (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
                currentSlotEnergyWattsPerMHz (:,:) double ...
                    {mustBeReal,mustBeNonnegative}
                reservedMask (:,:) logical
            end

            if networkSliceId ~= obj.Grid.NetworkSliceId
                error( ...
                    "v2xsim:resource:NetworkSliceMismatch", ...
                    "Sensing update and resource grid belong to " + ...
                    "different network slices.");
            end
            ueIds = ueIds(:);
            if ~isequal(ueIds,obj.UeIds)
                error( ...
                    "v2xsim:resource:SensingUeSetMismatch", ...
                    "Synchronize sensing UE identities before updating.");
            end
            expectedEnergySize = [ ...
                numel(ueIds),obj.Grid.NumberFrequencyResources];
            if ~isequal(size(currentSlotEnergyWattsPerMHz), ...
                    expectedEnergySize) || ...
                    any(isnan(currentSlotEnergyWattsPerMHz),"all") || ...
                    ~isequal(size(reservedMask), ...
                    [numel(ueIds),obj.Grid.ResourceCount])
                error( ...
                    "v2xsim:resource:SensingUpdateSizeMismatch", ...
                    "Sensing observations do not align with the grid.");
            end
            if absoluteSlot <= obj.LastUpdatedSlot
                error( ...
                    "v2xsim:resource:DuplicateSensingUpdate", ...
                    "Shared sensing can be updated only once per TTI.");
            end
            if obj.LastUpdatedSlot >= 0 && ...
                    absoluteSlot ~= obj.LastUpdatedSlot + 1
                error( ...
                    "v2xsim:resource:NonconsecutiveSensingUpdate", ...
                    "Shared sensing updates must cover consecutive TTIs.");
            end

            periodicSlot = obj.Grid.periodicSlot(absoluteSlot);
            columns = obj.Grid.resourceId( ...
                periodicSlot,1:obj.Grid.NumberFrequencyResources);
            obj.EnergyHistory(:,columns,:) = ...
                circshift(obj.EnergyHistory(:,columns,:),1,1);
            obj.EnergyHistory(1,columns,:) = permute( ...
                currentSlotEnergyWattsPerMHz,[3 2 1]);
            obj.ReservationHistory(1,:,:) = permute( ...
                reservedMask,[3 2 1]);
            obj.LastUpdatedSlot = absoluteSlot;
        end

        function snapshot = snapshot(obj,averageEnergy)
            arguments (Input)
                obj (1,1)
                averageEnergy (1,1) logical = true
            end

            if averageEnergy
                energy = reshape( ...
                    mean(obj.EnergyHistory,1), ...
                    obj.Grid.ResourceCount,numel(obj.UeIds)).';
            else
                energy = reshape( ...
                    obj.EnergyHistory(1,:,:), ...
                    obj.Grid.ResourceCount,numel(obj.UeIds)).';
            end
            if isempty(obj.UeIds)
                energy = zeros(0,obj.Grid.ResourceCount);
            end
            reservations = reshape( ...
                obj.ReservationHistory(1,:,:), ...
                obj.Grid.ResourceCount,numel(obj.UeIds)).';
            if isempty(obj.UeIds)
                reservations = false(0,obj.Grid.ResourceCount);
            end
            snapshot = v2xsim.resource.SensingSnapshot( ...
                obj.Grid.NetworkSliceId,obj.UeIds,energy,reservations);
        end
    end
end

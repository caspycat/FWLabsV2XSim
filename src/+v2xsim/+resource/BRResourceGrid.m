classdef BRResourceGrid
    %BRRESOURCEGRID Immutable beacon-resource topology for one slice.
    %   Resource identifiers are local to NetworkSliceId and are ordered
    %   first by time slot and then by frequency resource.

    properties (SetAccess = immutable)
        NetworkSliceId (1, 1) v2xsim.network.NetworkSliceId
        NumberTimeSlots (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive} = 1
        NumberFrequencyResources (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive} = 1
        SlotDurationSeconds (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBePositive} = 1
    end

    properties (Dependent, SetAccess = private)
        ResourceCount (1, 1) double
    end

    methods
        function obj = BRResourceGrid( ...
                networkSliceId, numberTimeSlots, ...
                numberFrequencyResources, slotDurationSeconds)
            arguments (Input)
                networkSliceId (1, 1) ...
                    v2xsim.network.NetworkSliceId = ...
                    v2xsim.network.NetworkSliceId()
                numberTimeSlots (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBePositive} = 1
                numberFrequencyResources (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBePositive} = 1
                slotDurationSeconds (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBePositive} = 1
            end

            obj.NetworkSliceId = networkSliceId;
            obj.NumberTimeSlots = numberTimeSlots;
            obj.NumberFrequencyResources = numberFrequencyResources;
            obj.SlotDurationSeconds = slotDurationSeconds;
        end

        function value = get.ResourceCount(obj)
            value = obj.NumberTimeSlots * obj.NumberFrequencyResources;
        end

        function periodicSlot = periodicSlot(obj, absoluteSlot)
            %PERIODICSLOT Convert a zero-based absolute slot to grid slot.
            arguments (Input)
                obj (1, 1)
                absoluteSlot double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBeNonnegative}
            end

            periodicSlot = mod(absoluteSlot, obj.NumberTimeSlots) + 1;
        end

        function resourceId = resourceId( ...
                obj, timeSlot, frequencyResource)
            %RESOURCEID Convert one-based grid coordinates to local IDs.
            arguments (Input)
                obj (1, 1)
                timeSlot double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive}
                frequencyResource double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive}
            end

            if any(timeSlot > obj.NumberTimeSlots, "all") || ...
                    any( ...
                        frequencyResource > ...
                        obj.NumberFrequencyResources, "all")
                error( ...
                    "v2xsim:resource:GridCoordinateOutOfRange", ...
                    "Beacon-resource coordinates exceed the grid bounds.");
            end

            if ~isscalar(timeSlot) && ~isscalar(frequencyResource) && ...
                    ~isequal(size(timeSlot), size(frequencyResource))
                error( ...
                    "v2xsim:resource:GridCoordinateSizeMismatch", ...
                    "Time-slot and frequency-resource arrays must have " + ...
                    "compatible sizes.");
            end

            resourceId = ...
                (timeSlot - 1) .* obj.NumberFrequencyResources + ...
                frequencyResource;
        end

        function [timeSlot, frequencyResource] = ...
                resourceCoordinates(obj, resourceId)
            %RESOURCECOORDINATES Convert local IDs to one-based coordinates.
            arguments (Input)
                obj (1, 1)
                resourceId double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive}
            end

            if any(resourceId > obj.ResourceCount, "all")
                error( ...
                    "v2xsim:resource:ResourceIdOutOfRange", ...
                    "A resource identifier exceeds the grid bounds.");
            end

            timeSlot = ceil(resourceId ./ obj.NumberFrequencyResources);
            frequencyResource = ...
                mod(resourceId - 1, obj.NumberFrequencyResources) + 1;
        end
    end
end

classdef ResourcePressure
    %RESOURCEPRESSURE Immutable slice-local selectable-BR restriction.
    %   Resource pressure preserves the physical BR grid and limits only
    %   allocator eligibility. Axis masks are static, evenly distributed,
    %   and combine as a time-frequency Cartesian product.

    properties (SetAccess = immutable)
        NetworkSliceId (1,1) v2xsim.network.NetworkSliceId
        TimeAvailabilityPercent (1,1) double ...
            {mustBeInteger}
        FrequencyAvailabilityPercent (1,1) double ...
            {mustBeInteger}
        TimeSlotMask (1,:) logical
        FrequencyResourceMask (1,:) logical
        ResourceMask (1,:) logical
    end

    properties (Dependent, SetAccess = private)
        AvailableTimeSlotCount (1,1) double
        AvailableFrequencyResourceCount (1,1) double
        AvailableResourceCount (1,1) double
        EffectiveResourceAvailabilityPercent (1,1) double
    end

    methods
        function obj = ResourcePressure( ...
                grid,timeAvailabilityPercent,frequencyAvailabilityPercent)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                timeAvailabilityPercent (1,1) double {mustBeInteger} = 100
                frequencyAvailabilityPercent (1,1) double {mustBeInteger} = 100
            end

            validateAvailabilityPercent( ...
                timeAvailabilityPercent,"TimeAvailabilityPercent");
            validateAvailabilityPercent( ...
                frequencyAvailabilityPercent,"FrequencyAvailabilityPercent");
            obj.NetworkSliceId = grid.NetworkSliceId;
            obj.TimeAvailabilityPercent = timeAvailabilityPercent;
            obj.FrequencyAvailabilityPercent = frequencyAvailabilityPercent;
            obj.TimeSlotMask = evenlyDistributedMask( ...
                grid.NumberTimeSlots,timeAvailabilityPercent);
            obj.FrequencyResourceMask = evenlyDistributedMask( ...
                grid.NumberFrequencyResources,frequencyAvailabilityPercent);
            % BRResourceGrid numbers frequency resources consecutively
            % inside each time slot, so the Cartesian product must be
            % flattened in time-major order.
            obj.ResourceMask = kron( ...
                obj.TimeSlotMask,obj.FrequencyResourceMask);
        end

        function value = get.AvailableTimeSlotCount(obj)
            value = nnz(obj.TimeSlotMask);
        end

        function value = get.AvailableFrequencyResourceCount(obj)
            value = nnz(obj.FrequencyResourceMask);
        end

        function value = get.AvailableResourceCount(obj)
            value = nnz(obj.ResourceMask);
        end

        function value = get.EffectiveResourceAvailabilityPercent(obj)
            value = 100 * obj.AvailableResourceCount / numel(obj.ResourceMask);
        end

        function mask = eligibilityMask(obj,ueCount)
            arguments (Input)
                obj (1,1)
                ueCount (1,1) double {mustBeInteger,mustBeNonnegative}
            end
            mask = repmat(obj.ResourceMask,ueCount,1);
        end

        function value = metadata(obj)
            value = struct( ...
                "NetworkSliceId",string(obj.NetworkSliceId), ...
                "TimeAvailabilityPercent",obj.TimeAvailabilityPercent, ...
                "FrequencyAvailabilityPercent", ...
                    obj.FrequencyAvailabilityPercent, ...
                "AvailableTimeSlotCount",obj.AvailableTimeSlotCount, ...
                "AvailableFrequencyResourceCount", ...
                    obj.AvailableFrequencyResourceCount, ...
                "AvailableResourceCount",obj.AvailableResourceCount, ...
                "EffectiveResourceAvailabilityPercent", ...
                    obj.EffectiveResourceAvailabilityPercent);
        end
    end
end

function mask = evenlyDistributedMask(axisCount,availabilityPercent)
availableCount = max(1,round(axisCount * availabilityPercent / 100));
axisIndexes = 1:axisCount;
mask = floor(axisIndexes * availableCount / axisCount) > ...
    floor((axisIndexes - 1) * availableCount / axisCount);
end

function validateAvailabilityPercent(value,name)
if value < 1 || value > 100
    error( ...
        "v2xsim:resource:InvalidResourcePressure", ...
        "%s must be an integer from 1 to 100.",name);
end
end

classdef (Abstract, HandleCompatible) ResourceAllocator
    %RESOURCEALLOCATOR Validated value-class BR allocation lifecycle.
    %   Allocators are bound to one immutable grid and network slice.
    %   Assignments are committed only by the sealed lifecycle methods.
    %   Random state is stored as value data, so allocator copies do not
    %   share a mutable RandStream handle.

    properties (Abstract, Constant)
        Type
        Category
        Description
        ContextContract
        UsesSelectionWindow
    end

    properties (SetAccess = immutable)
        Grid (1, 1) v2xsim.resource.BRResourceGrid
        RandomSeed (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBeNonnegative} = 0
        MaximumTransmissionCount (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive} = 1
        RandomGeneratorType (1, 1) string = "mt19937ar"
    end

    properties (SetAccess = private)
        Assignments table = table( ...
            strings(0, 1), nan(0, 1), ...
            VariableNames=["UeId", "ResourceIds"])
        IsInitialized (1, 1) logical = false
    end

    properties (Dependent, SetAccess = private)
        UeIds (:, 1) string
    end

    properties (Access = private)
        RandomState
    end

    methods (Access = protected)
        function obj = ResourceAllocator( ...
                grid, randomSeed, maximumTransmissionCount)
            arguments (Input)
                grid (1, 1) v2xsim.resource.BRResourceGrid
                randomSeed (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBeNonnegative}
                maximumTransmissionCount (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBePositive} = 1
            end

            if randomSeed > double(intmax("uint32"))
                error( ...
                    "v2xsim:resource:RandomSeedOutOfRange", ...
                    "RandomSeed must fit in an unsigned 32-bit integer.");
            end

            obj.Grid = grid;
            obj.RandomSeed = randomSeed;
            obj.MaximumTransmissionCount = maximumTransmissionCount;
            obj.RandomGeneratorType = "mt19937ar";
            obj.Assignments = ...
                v2xsim.resource.ResourceAllocationResult ...
                .emptyAssignments(maximumTransmissionCount);
            obj.validateMetadata();

            randomStream = RandStream( ...
                obj.RandomGeneratorType, Seed=obj.RandomSeed);
            obj.RandomState = randomStream.State;
        end
    end

    methods
        function value = get.UeIds(obj)
            value = obj.Assignments.UeId;
        end

        function value = metadata(obj)
            %METADATA Serializable, branch-free allocator provenance.
            value = struct( ...
                "Type",obj.Type, ...
                "Category",obj.Category, ...
                "Description",obj.Description, ...
                "ContextContract",obj.ContextContract, ...
                "UsesSelectionWindow",obj.UsesSelectionWindow, ...
                "NetworkSliceId",string(obj.Grid.NetworkSliceId), ...
                "RandomSeed",obj.RandomSeed, ...
                "RandomGeneratorType",obj.RandomGeneratorType, ...
                "MaximumTransmissionCount", ...
                    obj.MaximumTransmissionCount, ...
                "NumberTimeSlots",obj.Grid.NumberTimeSlots, ...
                "NumberFrequencyResources", ...
                    obj.Grid.NumberFrequencyResources, ...
                "SlotDurationSeconds", ...
                    obj.Grid.SlotDurationSeconds, ...
                "Options",obj.configurationMetadata());
        end
    end

    methods (Sealed)
        function obj = synchronizeUes(obj, ueIds)
            %SYNCHRONIZEUES Reconcile allocator state with active C-V2X UEs.
            arguments (Input)
                obj (1, 1)
                ueIds string
            end

            ueIds = ueIds(:);
            v2xsim.resource.validation.mustBeUeIds(ueIds);

            previousAssignments = obj.Assignments;
            previousUeIds = previousAssignments.UeId;
            [isRetained, previousLocations] = ...
                ismember(ueIds, previousUeIds);
            resourceIds = nan( ...
                numel(ueIds), obj.MaximumTransmissionCount);
            resourceIds(isRetained, :) = ...
                previousAssignments.ResourceIds( ...
                    previousLocations(isRetained), :);

            enteredUeIds = ueIds(~isRetained);
            exitedUeIds = previousUeIds( ...
                ~ismember(previousUeIds, ueIds));
            obj.Assignments = table( ...
                ueIds, resourceIds, ...
                VariableNames=["UeId", "ResourceIds"]);

            if ~isequal(ueIds, previousUeIds)
                obj = obj.doSynchronizeUes( ...
                    enteredUeIds, exitedUeIds);
            end
        end

        function [obj, result] = initialize(obj, context)
            %INITIALIZE Establish the allocator's initial assignments.
            arguments (Input)
                obj (1, 1)
                context (1, 1) ...
                    v2xsim.resource.ResourceAllocationContext
            end

            if obj.IsInitialized
                error( ...
                    "v2xsim:resource:AllocatorAlreadyInitialized", ...
                    "A resource allocator can only be initialized once.");
            end

            obj.validateContext(context);
            randomStream = obj.materializeRandomStream();
            [obj, result] = obj.doInitialize(context, randomStream);
            obj.RandomState = randomStream.State;
            obj.validateResult(result);
            obj.Assignments = result.Assignments;
            obj.IsInitialized = true;
        end

        function [obj, result] = step(obj, context)
            %STEP Advance allocation state by one completed C-V2X TTI.
            arguments (Input)
                obj (1, 1)
                context (1, 1) ...
                    v2xsim.resource.ResourceAllocationContext
            end

            if ~obj.IsInitialized
                error( ...
                    "v2xsim:resource:AllocatorNotInitialized", ...
                    "Initialize the resource allocator before stepping it.");
            end

            obj.validateContext(context);
            randomStream = obj.materializeRandomStream();
            [obj, result] = obj.doStep(context, randomStream);
            obj.RandomState = randomStream.State;
            obj.validateResult(result);
            obj.Assignments = result.Assignments;
        end
    end

    methods (Access = private)
        function validateMetadata(obj)
            metadata = { ...
                obj.Type,obj.Category,obj.Description, ...
                obj.ContextContract};
            for index = 1:numel(metadata)
                value = metadata{index};
                if ~isstring(value) || ~isscalar(value) || ...
                        ismissing(value) || strlength(strip(value)) == 0
                    error( ...
                        "v2xsim:resource:InvalidAllocatorMetadata", ...
                        "Allocator text metadata fields must be " + ...
                        "nonblank string scalars.");
                end
            end
            if ~islogical(obj.UsesSelectionWindow) || ...
                    ~isscalar(obj.UsesSelectionWindow)
                error( ...
                    "v2xsim:resource:InvalidAllocatorMetadata", ...
                    "UsesSelectionWindow must be a logical scalar.");
            end
        end

        function validateContext(obj, context)
            obj.validateContextType(context);
            if context.NetworkSliceId ~= obj.Grid.NetworkSliceId
                error( ...
                    "v2xsim:resource:NetworkSliceMismatch", ...
                    "The allocation context and resource grid must " + ...
                    "belong to the same network slice.");
            end
            if size(context.EligibilityMask, 2) ~= ...
                    obj.Grid.ResourceCount
                error( ...
                    "v2xsim:resource:ResourceCountMismatch", ...
                    "EligibilityMask must contain one column per grid " + ...
                    "resource.");
            end
            if ~isequal(sort(context.UeIds), sort(obj.UeIds))
                error( ...
                    "v2xsim:resource:AllocatorUeSetMismatch", ...
                    "Synchronize the allocator with the context UE set " + ...
                    "before initialization or stepping.");
            end
        end

        function validateResult(obj, result)
            if ~isa(result, "v2xsim.resource.ResourceAllocationResult") || ...
                    ~isscalar(result)
                error( ...
                    "v2xsim:resource:InvalidAllocationResult", ...
                    "Allocator hooks must return one " + ...
                    "ResourceAllocationResult.");
            end
            if result.NetworkSliceId ~= obj.Grid.NetworkSliceId
                error( ...
                    "v2xsim:resource:NetworkSliceMismatch", ...
                    "The allocation result and resource grid must " + ...
                    "belong to the same network slice.");
            end
            if ~isequal( ...
                    sort(result.Assignments.UeId), sort(obj.UeIds))
                error( ...
                    "v2xsim:resource:AllocationResultUeSetMismatch", ...
                    "Allocator output must assign every synchronized UE " + ...
                    "exactly once.");
            end
            if size(result.Assignments.ResourceIds, 2) ~= ...
                    obj.MaximumTransmissionCount
                error( ...
                    "v2xsim:resource:TransmissionCountMismatch", ...
                    "Allocator output must contain the configured number " + ...
                    "of resource columns.");
            end

            assignedResourceIds = result.Assignments.ResourceIds;
            assignedResourceIds = ...
                assignedResourceIds(~isnan(assignedResourceIds));
            if any(assignedResourceIds > obj.Grid.ResourceCount)
                error( ...
                    "v2xsim:resource:ResourceIdOutOfRange", ...
                    "An assigned resource identifier exceeds the grid.");
            end
            if any(result.Reservations.ResourceId > ...
                    obj.Grid.ResourceCount)
                error( ...
                    "v2xsim:resource:ResourceIdOutOfRange", ...
                    "A reserved resource identifier exceeds the grid.");
            end
        end

        function randomStream = materializeRandomStream(obj)
            randomStream = RandStream( ...
                obj.RandomGeneratorType, Seed=obj.RandomSeed);
            randomStream.State = obj.RandomState;
        end
    end

    methods (Access = protected)
        function value = configurationMetadata(~)
            value = struct();
        end

        function obj = doSynchronizeUes( ...
                obj, enteredUeIds, exitedUeIds) %#ok<INUSD>
            %DOSYNCHRONIZEUES Optional hook for allocator-owned UE state.
        end
    end

    methods (Abstract, Access = protected)
        validateContextType(obj, context)

        [obj, result] = doInitialize(obj, context, randomStream)

        [obj, result] = doStep(obj, context, randomStream)
    end
end

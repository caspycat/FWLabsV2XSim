classdef RandomBenchmarkAllocator < v2xsim.resource.ResourceAllocator
    %RANDOMBENCHMARKALLOCATOR Packet-triggered random benchmark.

    properties (Constant)
        Type = "RandomBenchmark"
        Category = "Benchmark"
        Description = ...
            "Random eligible-resource benchmark"
        ContextContract = "Basic"
        UsesSelectionWindow = true
    end

    methods
        function obj = RandomBenchmarkAllocator( ...
                grid,randomSeed,maximumTransmissionCount)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                randomSeed (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
                maximumTransmissionCount (1,1) double ...
                    {mustBeInteger,mustBePositive} = 1
            end

            obj = obj@v2xsim.resource.ResourceAllocator( ...
                grid,randomSeed,maximumTransmissionCount);
        end
    end

    methods (Access = protected)
        function validateContextType(~,context)
            if ~isa(context,"v2xsim.resource.ResourceAllocationContext")
                error( ...
                    "v2xsim:resource:InvalidAllocationContextType", ...
                    "RandomBenchmark requires a ResourceAllocationContext.");
            end
        end

        function [obj,result] = doInitialize(obj,~,~)
            result = v2xsim.resource.internal.emptyResult(obj);
        end

        function [obj,result] = doStep(obj,context,randomStream)
            rows = v2xsim.resource.internal.contextRows( ...
                obj.UeIds,context.UeIds);
            newPacketMask = context.NewPacketMask(rows);
            decisionRows = find(newPacketMask);
            resourceIds = obj.Assignments.ResourceIds;
            if isempty(decisionRows)
                result = v2xsim.resource.internal.emptyResult(obj);
                return
            end

            selected = v2xsim.resource.algorithm.assignRandomResources( ...
                context.EligibilityMask(rows(decisionRows),:), ...
                obj.MaximumTransmissionCount,randomStream, ...
                obj.Grid.NumberFrequencyResources);
            selected = obj.orderByFutureOccurrence( ...
                selected, ...
                context.SelectionOriginSlot(rows(decisionRows)));
            resourceIds(decisionRows,:) = selected;
            result = v2xsim.resource.internal.buildResult( ...
                obj.Grid,obj.Assignments,resourceIds,decisionRows);
        end
    end

    methods (Access = private)
        function resourceIds = orderByFutureOccurrence( ...
                obj,resourceIds,selectionOriginSlot)
            for row = 1:size(resourceIds,1)
                assigned = resourceIds(row,~isnan(resourceIds(row,:)));
                timeSlots = ceil( ...
                    assigned / obj.Grid.NumberFrequencyResources);
                periodicOrigin = ...
                    obj.Grid.periodicSlot(selectionOriginSlot(row));
                futureSlots = timeSlots;
                futureSlots(timeSlots <= periodicOrigin) = ...
                    futureSlots(timeSlots <= periodicOrigin) + ...
                    obj.Grid.NumberTimeSlots;
                [~,order] = sort(futureSlots);
                resourceIds(row,:) = NaN;
                resourceIds(row,1:numel(assigned)) = assigned(order);
            end
        end
    end
end

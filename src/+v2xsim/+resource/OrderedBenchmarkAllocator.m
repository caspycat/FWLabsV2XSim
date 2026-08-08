classdef OrderedBenchmarkAllocator < v2xsim.resource.ResourceAllocator
    %ORDEREDBENCHMARKALLOCATOR Position-ordered deterministic benchmark.

    properties (Constant)
        Type = "OrderedBenchmark"
        Category = "Benchmark"
        Description = ...
            "Frequency-first resources ordered by longitudinal position"
        ContextContract = "Centralized"
        UsesSelectionWindow = false
    end

    methods
        function obj = OrderedBenchmarkAllocator(grid,randomSeed)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                randomSeed (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
            end

            obj = obj@v2xsim.resource.ResourceAllocator( ...
                grid,randomSeed,1);
        end
    end

    methods (Access = protected)
        function validateContextType(~,context)
            if ~isa( ...
                    context, ...
                    "v2xsim.resource.CentralizedAllocationContext")
                error( ...
                    "v2xsim:resource:InvalidAllocationContextType", ...
                    "OrderedBenchmark requires centralized positions.");
            end
        end

        function [obj,result] = doInitialize(obj,~,~)
            result = v2xsim.resource.internal.emptyResult(obj);
        end

        function [obj,result] = doStep(obj,context,~)
            isGridBoundary = ...
                mod(context.CurrentSlot + 1,obj.Grid.NumberTimeSlots) == 0;
            if ~isGridBoundary
                result = v2xsim.resource.internal.emptyResult(obj);
                return
            end

            rows = v2xsim.resource.internal.contextRows( ...
                obj.UeIds,context.UeIds);
            [resourceIds,decisionRows] = ...
                v2xsim.resource.algorithm.assignByPositionOrder( ...
                    context.X(rows), ...
                    [obj.Grid.NumberTimeSlots, ...
                    obj.Grid.NumberFrequencyResources], ...
                    context.EligibilityMask(rows,:));
            result = v2xsim.resource.internal.buildResult( ...
                obj.Grid,obj.Assignments,resourceIds,decisionRows);
        end
    end
end

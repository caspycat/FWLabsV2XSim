classdef (Abstract) CentralizedResourceAllocator < ...
        v2xsim.resource.ResourceAllocator
    %CENTRALIZEDRESOURCEALLOCATOR Allocator allowed global slice state.

    properties (Constant)
        Category = "Centralized"
        ContextContract = "Centralized"
        UsesSelectionWindow = false
    end

    methods (Access = protected)
        function obj = CentralizedResourceAllocator( ...
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

            obj = obj@v2xsim.resource.ResourceAllocator( ...
                grid, randomSeed, maximumTransmissionCount);
        end
    end

    methods (Sealed, Access = protected)
        function validateContextType(~, context)
            if ~isa( ...
                    context, ...
                    "v2xsim.resource.CentralizedAllocationContext")
                error( ...
                    "v2xsim:resource:InvalidAllocationContextType", ...
                    "A centralized allocator requires a " + ...
                    "CentralizedAllocationContext.");
            end
        end
    end
end

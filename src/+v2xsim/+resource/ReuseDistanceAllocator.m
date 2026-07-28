classdef ReuseDistanceAllocator < ...
        v2xsim.resource.ScheduledCentralizedResourceAllocator
    %REUSEDISTANCEALLOCATOR Controlled minimum-distance reuse.

    properties (Constant)
        Type = "ReuseDistance"
        Description = ...
            "Controlled allocation with a minimum reuse distance"
    end

    properties (SetAccess = immutable)
        ReuseDistanceMeters (1,1) double ...
            {mustBeFinite,mustBeNonnegative}
    end

    methods
        function obj = ReuseDistanceAllocator( ...
                grid,randomSeed,reassignmentCycleCount,reuseDistanceMeters)
            arguments (Input)
                grid (1,1) v2xsim.resource.BRResourceGrid
                randomSeed (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
                reassignmentCycleCount (1,1) double ...
                    {mustBeInteger,mustBePositive}
                reuseDistanceMeters (1,1) double ...
                    {mustBeFinite,mustBeNonnegative}
            end

            obj = obj@v2xsim.resource. ...
                ScheduledCentralizedResourceAllocator( ...
                    grid,randomSeed,reassignmentCycleCount);
            obj.ReuseDistanceMeters = reuseDistanceMeters;
        end
    end

    methods (Access = protected)
        function value = configurationMetadata(obj)
            value = configurationMetadata@v2xsim.resource.ScheduledCentralizedResourceAllocator(obj);
            value.ReuseDistanceMeters = obj.ReuseDistanceMeters;
        end

        function [resourceIds,decisionRows] = allocate( ...
                obj,resourceIds,scheduledRows,context, ...
                allocatorRows,randomStream)
            distance = context.EstimatedDistanceMeters( ...
                allocatorRows,allocatorRows);
            [resourceIds,decisionRows] = ...
                v2xsim.resource.algorithm.assignByReuseDistance( ...
                    resourceIds,scheduledRows,distance, ...
                    obj.Grid.ResourceCount,obj.ReuseDistanceMeters, ...
                    randomStream);
        end
    end
end

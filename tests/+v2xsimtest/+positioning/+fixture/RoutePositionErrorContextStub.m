classdef RoutePositionErrorContextStub < ...
        v2xsim.positioning.RoutePositionErrorContext
    %ROUTEPOSITIONERRORCONTEXTSTUB Supply a caller-controlled projection.

    properties (SetAccess = immutable)
        Projection
    end

    methods
        function obj = RoutePositionErrorContextStub( ...
                actualPositions, projection, options)
            arguments (Input)
                actualPositions table
                projection
                options.SimulationTimeSeconds (1, 1) double = 0
            end

            obj = obj@v2xsim.positioning.RoutePositionErrorContext( ...
                actualPositions, options.SimulationTimeSeconds, 0.1, 1);
            obj.Projection = projection;
        end
    end

    methods (Access = protected)
        function projection = buildRouteProjection(obj, ~, ~)
            projection = obj.Projection;
        end
    end
end

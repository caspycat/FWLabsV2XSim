function diagnostics = attachContext(diagnostics, context)
%ATTACHCONTEXT Add scenario-specific values to diagnostic rows.

if isempty(diagnostics) || ...
        ~isa( ...
            context, ...
            "v2xsim.positioning.RoutePositionErrorContext")
    return
end

vehicleIds = reshape(diagnostics.VehicleId, [], 1);
projection = context.getRouteProjection("FalseExit", vehicleIds);
diagnostics.TrueRoute = projection.TrueRoute;
end

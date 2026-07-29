classdef (Abstract, HandleCompatible) PositionErrorModule
    %POSITIONERRORMODULE Transforms vehicle positions seen by a controller.
    %   Modules receive a table containing the planar X and Y positions in
    %   meters. Vehicle identities are stored as table row names. Context
    %   supplies timing and the unmodified scenario position snapshot.
    %   Specialized contexts may provide additional scenario capabilities.
    %
    %   APPLY returns the updated module, transformed positions, and an
    %   optional normalized per-vehicle diagnostic table. Existing one- or
    %   two-output calls remain valid. Implementations must preserve the
    %   set of vehicle identities, although row order has no semantic
    %   meaning. Modules are value classes by default; callers must retain
    %   the returned module.

    methods (Sealed)
        function [obj, outputPositions, diagnostics] = apply( ...
                obj, inputPositions, context)
            %APPLY Transform one position snapshot.
            arguments (Input)
                obj (1, 1)
                inputPositions table ...
                    {v2xsim.positioning.validation.mustBe2DPositionTable}
                context (1, 1) ...
                    v2xsim.positioning.PositionErrorContext
            end

            collectDiagnostics = nargout >= 3;
            v2xsim.positioning.validation. ...
                mustMatchContextVehicleIdentities( ...
                    inputPositions, context.ActualPositions);
            [obj, outputPositions] = ...
                obj.doApply(inputPositions, context);

            v2xsim.positioning.validation.mustBe2DPositionTable( ...
                outputPositions);
            v2xsim.positioning.validation. ...
                mustPreserveVehicleIdentities( ...
                    inputPositions, outputPositions);
            if collectDiagnostics
                diagnostics = obj.buildDiagnostics( ...
                    inputPositions, outputPositions, context);
                diagnostics = v2xsim.positioning.diagnostics. ...
                    attachContext(diagnostics, context);
                v2xsim.positioning.diagnostics. ...
                    mustBePositionErrorDiagnosticsTable(diagnostics);
            end
        end
    end

    methods (Access = protected)
        function diagnostics = buildDiagnostics( ...
                obj, inputPositions, outputPositions, context)
            %BUILDDIAGNOSTICS Build generic displacement-only rows.
            diagnostics = v2xsim.positioning.diagnostics.createRows( ...
                inputPositions, outputPositions, ...
                context.SimulationTimeSeconds, string(class(obj)));
        end
    end

    methods (Abstract, Access = protected)
        % Transform the apparent inputPositions using the immutable
        % context. Return the updated module to support value-class
        % implementations with state.
        [obj, outputPositions] = doApply( ...
            obj, inputPositions, context)
    end
end

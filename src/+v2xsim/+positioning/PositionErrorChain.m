classdef PositionErrorChain
    %POSITIONERRORCHAIN Applies position error modules in a fixed order.
    %   Modules are applied from left to right. Each module receives the
    %   apparent output of the preceding module and the same immutable
    %   context. An empty chain leaves positions unchanged.

    properties (SetAccess = private)
        Modules (1, :) cell = cell(1, 0)
    end

    methods
        function obj = PositionErrorChain(modules)
            %POSITIONERRORCHAIN Construct a chain from a row cell array.
            arguments (Input)
                modules (1, :) cell = cell(1, 0)
            end

            for moduleIndex = 1:numel(modules)
                module = modules{moduleIndex};
                if ~isa(module, ...
                        "v2xsim.positioning.PositionErrorModule") || ...
                        ~isscalar(module)
                    error( ...
                        "v2xsim:positioning:InvalidErrorModule", ...
                        "Chain element %d must be a scalar " + ...
                        "PositionErrorModule.", ...
                        moduleIndex);
                end
            end

            obj.Modules = modules;
        end

        function [obj, outputPositions, diagnostics] = apply( ...
                obj, inputPositions, context)
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
            outputPositions = inputPositions;
            if collectDiagnostics
                moduleDiagnosticsByIndex = cell( ...
                    1, numel(obj.Modules));
            end

            for moduleIndex = 1:numel(obj.Modules)
                module = obj.Modules{moduleIndex};
                if collectDiagnostics
                    [module, outputPositions, moduleDiagnostics] = ...
                        module.apply(outputPositions, context);
                    moduleDiagnostics.ModuleIndex(:) = moduleIndex;
                    moduleDiagnosticsByIndex{moduleIndex} = ...
                        moduleDiagnostics;
                else
                    [module, outputPositions] = module.apply( ...
                        outputPositions, context);
                end
                obj.Modules{moduleIndex} = module;
            end

            v2xsim.positioning.validation.mustBe2DPositionTable( ...
                outputPositions);
            v2xsim.positioning.validation. ...
                mustPreserveVehicleIdentities( ...
                    inputPositions, outputPositions);
            if collectDiagnostics
                if isempty(obj.Modules)
                    diagnostics = ...
                        v2xsim.positioning.diagnostics.createRows( ...
                        inputPositions, outputPositions, ...
                        context.SimulationTimeSeconds, ...
                        "v2xsim.positioning.PositionErrorChain");
                    diagnostics.ModuleIndex(:) = 0;
                    diagnostics = v2xsim.positioning.diagnostics. ...
                        attachContext(diagnostics, context);
                else
                    diagnostics = vertcat( ...
                        moduleDiagnosticsByIndex{:});
                end
                v2xsim.positioning.diagnostics. ...
                    mustBePositionErrorDiagnosticsTable(diagnostics);
            end
        end
    end
end

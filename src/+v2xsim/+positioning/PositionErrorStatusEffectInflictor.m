classdef PositionErrorStatusEffectInflictor < ...
        v2xsim.positioning.PositionErrorModule
    %POSITIONERRORSTATUSEFFECTINFLICTOR Apply one position status effect.
    %   The module advances its composed effect's lifecycle, then applies
    %   the effect's positional consequence to active vehicles.

    properties (Dependent, SetAccess = private)
        Effect (1, 1) ...
            v2xsim.positioning.PositionErrorStatusEffect
    end

    properties (Access = private)
        EffectStorage (1, 1) cell = {[]}
        LastLifecycle (1, 1) struct = struct()
    end

    methods
        function obj = PositionErrorStatusEffectInflictor(effect)
            arguments (Input)
                effect (1, 1) ...
                    v2xsim.positioning.PositionErrorStatusEffect
            end

            obj.Effect = effect;
        end

        function effect = get.Effect(obj)
            effect = obj.EffectStorage{1};
        end

        function obj = set.Effect(obj, effect)
            obj.EffectStorage = {effect};
        end
    end

    methods (Access = protected)
        function [obj, outputPositions] = doApply( ...
                obj, inputPositions, context)
            [eligible, applicable] = obj.Effect.classifyTargets( ...
                inputPositions, context);
            vehicleIds = reshape( ...
                string(inputPositions.Properties.RowNames), [], 1);
            [obj.Effect, lifecycle] = obj.Effect.advance( ...
                vehicleIds, eligible, applicable, ...
                context.SimulationTimeSeconds);
            [obj.Effect, outputPositions] = ...
                obj.Effect.applyToPositions( ...
                    inputPositions, context, lifecycle.IsActive);
            obj.LastLifecycle = lifecycle;
        end

        function diagnostics = buildDiagnostics( ...
                obj, inputPositions, outputPositions, context)
            diagnostics = v2xsim.positioning.diagnostics.createRows( ...
                inputPositions, outputPositions, ...
                context.SimulationTimeSeconds, string(class(obj)), ...
                obj.LastLifecycle, string(class(obj.Effect)));
        end
    end
end

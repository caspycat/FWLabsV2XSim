classdef (Abstract) PositionErrorStatusEffect < ...
        v2xsim.status.StatusEffect
    %POSITIONERRORSTATUSEFFECT Status effect with a position consequence.
    %   Implementations classify eligible/applicable vehicles and define
    %   how an active effect transforms their apparent positions. The
    %   effect is not itself a position-error module.

    methods (Access = protected)
        function obj = PositionErrorStatusEffect( ...
                selectionProbability, selectionRandomSeed, ...
                resetAfterSeconds, selectionRandomStream)
            obj = obj@v2xsim.status.StatusEffect( ...
                selectionProbability, selectionRandomSeed, ...
                resetAfterSeconds, selectionRandomStream);
        end
    end

    methods (Abstract)
        [eligible, applicable] = classifyTargets( ...
            obj, inputPositions, context)
        [obj, outputPositions] = applyToPositions( ...
            obj, inputPositions, context, activeMask)
    end
end

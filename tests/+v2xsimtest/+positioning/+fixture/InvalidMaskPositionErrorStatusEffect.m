classdef InvalidMaskPositionErrorStatusEffect < ...
        v2xsim.positioning.PositionErrorStatusEffect
    %INVALIDMASKPOSITIONERRORSTATUSEFFECT Returns invalid row masks.

    methods
        function obj = InvalidMaskPositionErrorStatusEffect()
            obj = obj@v2xsim.positioning.PositionErrorStatusEffect( ...
                1, 0, Inf, []);
        end

        function [eligible, applicable] = classifyTargets( ...
                ~, inputPositions, ~)
            eligible = true(1, height(inputPositions));
            applicable = eligible;
        end

        function [obj, outputPositions] = applyToPositions( ...
                obj, inputPositions, ~, ~)
            outputPositions = inputPositions;
        end
    end
end

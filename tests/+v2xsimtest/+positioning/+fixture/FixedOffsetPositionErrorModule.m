classdef FixedOffsetPositionErrorModule < ...
        v2xsim.positioning.PositionErrorModule
    %FIXEDOFFSETPOSITIONERRORMODULE Stateful custom-module test fixture.

    properties (SetAccess = immutable)
        OffsetMeters (1, 1) double {mustBeReal, mustBeFinite}
    end

    properties (SetAccess = private)
        ApplicationCount (1, 1) double = 0
    end

    methods
        function obj = FixedOffsetPositionErrorModule(offsetMeters)
            arguments (Input)
                offsetMeters (1, 1) double ...
                    {mustBeReal, mustBeFinite}
            end
            obj.OffsetMeters = offsetMeters;
        end
    end

    methods (Access = protected)
        function [obj, outputPositions] = doApply( ...
                obj, inputPositions, ~)
            obj.ApplicationCount = obj.ApplicationCount + 1;
            outputPositions = inputPositions;
            outputPositions.X = ...
                outputPositions.X + obj.OffsetMeters;
        end
    end
end

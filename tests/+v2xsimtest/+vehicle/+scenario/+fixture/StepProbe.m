classdef StepProbe < handle
    %STEPPROBE Handle-backed record of Scenario step side effects.

    properties (SetAccess = private)
        Count (1,1) double {mustBeInteger,mustBeNonnegative} = 0
        LastDeltaTime (1,1) double = NaN
    end

    methods
        function record(obj,deltaTime)
            obj.Count = obj.Count + 1;
            obj.LastDeltaTime = deltaTime;
        end
    end
end

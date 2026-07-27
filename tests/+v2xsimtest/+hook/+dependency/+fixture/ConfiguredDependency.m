classdef ConfiguredDependency < handle & ...
        v2xsim.hook.dependency.Dependency
    %CONFIGUREDDEPENDENCY Dependency without a zero-argument constructor.

    properties (SetAccess = immutable)
        Value (1, 1) double
    end

    methods
        function obj = ConfiguredDependency(value)
            arguments (Input)
                value (1, 1) double
            end

            obj.Value = value;
        end
    end
end

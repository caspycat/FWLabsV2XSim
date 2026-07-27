classdef SimulationIdentifier < v2xsim.hook.dependency.Dependency
    %SIMULATIONIDENTIFIER Numeric identity assigned to one simulation run.

    properties (SetAccess = immutable)
        Value (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, mustBePositive} = 1
    end

    methods
        function obj = SimulationIdentifier(value)
            arguments (Input)
                value (1, 1) double ...
                    {mustBeReal, mustBeFinite, ...
                    mustBeInteger, mustBePositive}
            end

            obj.Value = value;
        end
    end
end

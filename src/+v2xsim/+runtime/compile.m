function plan = compile(configuration)
%COMPILE Create an immutable runtime plan from resolved configuration.

arguments (Input)
    configuration (1, 1) v2xsim.config.ResolvedConfiguration
end
arguments (Output)
    plan (1, 1) v2xsim.runtime.CompiledSimulationPlan
end

plan = v2xsim.runtime.CompiledSimulationPlan(configuration);
end

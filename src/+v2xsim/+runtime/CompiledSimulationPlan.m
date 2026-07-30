classdef CompiledSimulationPlan
    %COMPILEDSIMULATIONPLAN Immutable runtime view of resolved configuration.
    %   The plan deliberately exposes only the resolved V7 configuration
    %   domains. It has no dependency on the legacy simParams, appParams,
    %   phyParams, or outParams structures.

    properties (SetAccess = immutable)
        % ResolvedConfiguration has no zero-input constructor. The
        % constructor arguments block enforces this property's type without
        % forcing MATLAB to synthesize an invalid default object.
        Configuration
        SchemaVersion (1, 1) double
        Simulation (1, 1) struct
        Scenario (1, 1) struct
        Application (1, 1) struct
        Radio (1, 1) struct
        Channel (1, 1) struct
        Awareness (1, 1) struct
        ResourceAllocation (1, 1) struct
        Coexistence (1, 1) struct
        Positioning (1, 1) struct
        Infrastructure (1, 1) struct
        Outputs (1, 1) struct
    end

    methods
        function obj = CompiledSimulationPlan(configuration)
            arguments (Input)
                configuration (1, 1) ...
                    v2xsim.config.ResolvedConfiguration
            end

            data = configuration.Data;
            expectedNames = [ ...
                "SchemaVersion", ...
                "Simulation", ...
                "Scenario", ...
                "Application", ...
                "Radio", ...
                "Channel", ...
                "Awareness", ...
                "ResourceAllocation", ...
                "Coexistence", ...
                "Positioning", ...
                "Infrastructure", ...
                "Outputs"];
            actualNames = string(fieldnames(data)).';
            if numel(actualNames) ~= numel(expectedNames) || ...
                    ~all(ismember(expectedNames, actualNames))
                error( ...
                    "v2xsim:runtime:InvalidConfigurationSchema", ...
                    "Resolved configuration Data must contain exactly " + ...
                    "the supported V7 top-level fields.");
            end

            domainNames = expectedNames(2:end);
            for domainName = domainNames
                domainPlan = data.(domainName);
                if ~isstruct(domainPlan) || ~isscalar(domainPlan)
                    error( ...
                        "v2xsim:runtime:InvalidDomainPlan", ...
                        "Resolved configuration domain %s must be a " + ...
                        "scalar struct.", domainName);
                end
            end

            schemaVersion = data.SchemaVersion;
            if ~isnumeric(schemaVersion) || ~isreal(schemaVersion) || ...
                    ~isscalar(schemaVersion) || ...
                    ~isfinite(schemaVersion) || schemaVersion ~= 1
                error( ...
                    "v2xsim:runtime:InvalidSchemaVersion", ...
                    "Compiled plans support SchemaVersion 1.");
            end

            % Structs have value semantics, so assigning each domain gives
            % the plan its own immutable runtime view without altering the
            % resolved configuration object.
            obj.Configuration = configuration;
            obj.SchemaVersion = double(schemaVersion);
            obj.Simulation = data.Simulation;
            obj.Scenario = data.Scenario;
            obj.Application = data.Application;
            obj.Radio = data.Radio;
            obj.Channel = data.Channel;
            obj.Awareness = data.Awareness;
            obj.ResourceAllocation = data.ResourceAllocation;
            obj.Coexistence = data.Coexistence;
            obj.Positioning = data.Positioning;
            obj.Infrastructure = data.Infrastructure;
            obj.Outputs = data.Outputs;
        end
    end
end

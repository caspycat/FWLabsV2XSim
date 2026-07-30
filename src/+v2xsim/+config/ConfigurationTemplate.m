classdef ConfigurationTemplate
    %CONFIGURATIONTEMPLATE Unresolved declarative simulator configuration.
    %   A template contains only values explicitly authored in TOML or
    %   supplied by a typed ConfigurationPatch. Defaults are applied only
    %   by resolve, so changing a discriminator cannot retain defaults from
    %   the previously selected variant.

    properties (SetAccess = immutable)
        Data (1, 1) struct
        Provenance table
    end

    methods
        function obj = ConfigurationTemplate(data, provenance)
            arguments (Input)
                data (1, 1) struct = struct()
                provenance table = v2xsim.config.internal.Operations.emptyProvenance()
            end

            if nargin < 2
                provenance = ...
                    v2xsim.config.internal.Operations.provenanceForData( ...
                        data, "Template");
            end
            v2xsim.config.internal.Operations.validateProvenance(provenance);
            v2xsim.config.internal.Operations.validateKnownStructure( ...
                data, v2xsim.config.schema(), "Configuration template");
            v2xsim.config.internal.Operations.validateProvenanceForData( ...
                provenance, data);
            obj.Data = data;
            obj.Provenance = provenance;
        end

        function result = withPatch(obj, patch)
            arguments (Input)
                obj (1, 1) v2xsim.config.ConfigurationTemplate
                patch (1, 1) v2xsim.config.ConfigurationPatch
            end

            result = v2xsim.config.merge(obj, patch);
        end

        function result = resolve(obj, options)
            arguments (Input)
                obj (1, 1) v2xsim.config.ConfigurationTemplate
                options.Patch (1, 1) ...
                    v2xsim.config.ConfigurationPatch = ...
                    v2xsim.config.ConfigurationPatch()
            end

            result = v2xsim.config.resolve(obj, Patch=options.Patch);
        end
    end
end

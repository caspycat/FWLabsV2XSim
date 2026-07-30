classdef ResolvedConfiguration
    %RESOLVEDCONFIGURATION Immutable effective declarative configuration.
    %   Data is a nested scalar struct containing only the selected
    %   polymorphic branches. Provenance records the source of every leaf.

    properties (SetAccess = immutable)
        Data (1, 1) struct
        Provenance table
    end

    methods
        function obj = ResolvedConfiguration(data, provenance)
            arguments (Input)
                data (1, 1) struct
                provenance table
            end

            v2xsim.config.internal.Operations.validateProvenance(provenance);
            v2xsim.config.internal.Operations.validateResolved( ...
                data, v2xsim.config.schema());
            v2xsim.config.internal.Operations.validateProvenanceForData( ...
                provenance, data);
            obj.Data = data;
            obj.Provenance = provenance;
        end

        function source = sourceFor(obj, path)
            arguments (Input)
                obj (1, 1) v2xsim.config.ResolvedConfiguration
                path (1, 1) string {mustBeNonzeroLengthText}
            end

            match = obj.Provenance.Path == path;
            if ~any(match)
                error( ...
                    "v2xsim:config:UnknownProvenancePath", ...
                    "No resolved configuration value has path ""%s"".", ...
                    path);
            end
            source = obj.Provenance.Source(find(match, 1, "last"));
        end
    end
end

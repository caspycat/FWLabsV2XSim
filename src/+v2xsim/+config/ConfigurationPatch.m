classdef ConfigurationPatch
    %CONFIGURATIONPATCH Sparse, typed overlay for a configuration template.
    %   Patches contain nested MATLAB structs using the same exact-case
    %   names as the TOML schema. Tables merge recursively. Scalars, native
    %   arrays, and arrays of tables replace the prior value atomically.

    properties (SetAccess = immutable)
        Data (1, 1) struct
        Provenance table
    end

    methods
        function obj = ConfigurationPatch(data, provenance)
            arguments (Input)
                data (1, 1) struct = struct()
                provenance table = v2xsim.config.internal.Operations.emptyProvenance()
            end

            if nargin < 2
                provenance = ...
                    v2xsim.config.internal.Operations.provenanceForData( ...
                        data, "Patch");
            end
            v2xsim.config.internal.Operations.validateProvenance(provenance);
            v2xsim.config.internal.Operations.validateKnownStructure( ...
                data, v2xsim.config.schema(), "Configuration patch");
            v2xsim.config.internal.Operations.validateProvenanceForData( ...
                provenance, data);
            obj.Data = data;
            obj.Provenance = provenance;
        end
    end
end

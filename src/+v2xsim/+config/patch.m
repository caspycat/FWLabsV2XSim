function result = patch(data)
%PATCH Create a sparse typed configuration patch.
%   PATCH(DATA) accepts one scalar nested struct. Dotted name-value
%   arguments are deliberately unsupported: MATLAB callers use the same
%   object shape as TOML files.

arguments (Input)
    data (1, 1) struct
end

schema = v2xsim.config.schema();
v2xsim.config.internal.Operations.validateKnownStructure( ...
    data, schema, "Patch");
provenance = ...
    v2xsim.config.internal.Operations.provenanceForData(data, "Patch");
result = v2xsim.config.ConfigurationPatch(data, provenance);
end

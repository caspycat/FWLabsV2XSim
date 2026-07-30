function result = merge(template, patch)
%MERGE Apply a sparse configuration patch without resolving defaults.
%   Tables merge recursively. Scalars, native arrays, and arrays of tables
%   replace atomically. Patch values have higher precedence.

arguments (Input)
    template (1, 1) v2xsim.config.ConfigurationTemplate
    patch (1, 1) v2xsim.config.ConfigurationPatch
end

data = v2xsim.config.internal.Operations.deepMerge( ...
    template.Data, patch.Data);
provenance = v2xsim.config.internal.Operations.mergeProvenance( ...
    template.Provenance, patch.Provenance);
provenance = ...
    v2xsim.config.internal.Operations.retainProvenanceForData( ...
        provenance, data);
result = v2xsim.config.ConfigurationTemplate(data, provenance);
end

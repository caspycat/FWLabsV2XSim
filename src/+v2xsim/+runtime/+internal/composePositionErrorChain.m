function simParams = composePositionErrorChain( ...
        simParams, positioning, specification)
%COMPOSEPOSITIONERRORCHAIN Interleave configured and custom modules.
%   Configured entries reuse the exact module objects constructed by the
%   established engine. Custom entries are inserted without copying so the
%   supplied instances are owned by this simulation run.

arguments (Input)
    simParams (1, 1) struct
    positioning (1, 1) struct
    specification (1, 1) ...
        v2xsim.positioning.PositionErrorChainSpecification
end
arguments (Output)
    simParams (1, 1) struct
end

configuredTypes = configuredErrorTypes(positioning);
configuredModuleNames = string(simParams.positionErrorModuleNames);
configuredModuleNames = reshape(configuredModuleNames, 1, []);
configuredModules = simParams.positionErrorChain.Modules;
if ~isequal(configuredTypes, configuredModuleNames) || ...
        numel(configuredModules) ~= numel(configuredTypes)
    error( ...
        "v2xsim:runtime:ConfiguredPositionErrorChainMismatch", ...
        "The established engine did not construct the configured " + ...
        "position-error chain in resolved-configuration order.");
end

entries = specification.Entries;
modules = cell(1, numel(entries));
composition = cell(1, numel(entries));
referencedConfiguredTypes = strings(1, 0);
for entryIndex = 1:numel(entries)
    entry = entries(entryIndex);
    if entry.Origin == "Custom"
        modules{entryIndex} = entry.Module;
        composition{entryIndex} = struct( ...
            "Origin", "Custom", ...
            "Class", string(class(entry.Module)), ...
            "Descriptor", entry.Descriptor);
        continue
    end

    configuredType = entry.ConfiguredType;
    configuredIndex = find( ...
        configuredTypes == configuredType, 1, "first");
    if isempty(configuredIndex)
        error( ...
            "v2xsim:positioning:UnknownConfiguredPositionErrorType", ...
            "Position-error type ""%s"" is not present in the " + ...
            "resolved configuration.", configuredType);
    end
    if any(referencedConfiguredTypes == configuredType)
        error( ...
            "v2xsim:positioning:DuplicateConfiguredPositionErrorReference", ...
            "Configured position-error type ""%s"" is referenced " + ...
            "more than once.", configuredType);
    end

    referencedConfiguredTypes(end + 1) = configuredType; %#ok<AGROW>
    modules{entryIndex} = configuredModules{configuredIndex};
    composition{entryIndex} = struct( ...
        "Origin", "Configured", ...
        "ConfiguredType", configuredType);
end

missingTypes = configuredTypes( ...
    ~ismember(configuredTypes, referencedConfiguredTypes));
if ~isempty(missingTypes)
    error( ...
        "v2xsim:positioning:MissingConfiguredPositionErrorReference", ...
        "The chain specification omits configured position-error " + ...
        "type(s): %s.", strjoin(missingTypes, ", "));
end

simParams.positionErrorChain = ...
    v2xsim.positioning.PositionErrorChain(modules);
simParams.positionErrorChainComposition = composition;
end

function types = configuredErrorTypes(positioning)
errors = positioning.Errors;
types = strings(1, numel(errors));
for errorIndex = 1:numel(errors)
    types(errorIndex) = string(errors{errorIndex}.Type);
end
end

function [stream, effectiveSeed] = createOwnedRandomStream( ...
        configuredSeed, configuredStream)
%CREATEOWNEDRANDOMSTREAM Create an isolated reproducible random stream.

arguments (Input)
    configuredSeed (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeInteger, mustBeNonnegative}
    configuredStream = []
end

if configuredSeed > 2^32 - 1
    error( ...
        "v2xsim:status:InvalidSelectionRandomSeed", ...
        "Selection random seeds must not exceed 2^32 - 1.");
end

if isempty(configuredStream)
    stream = RandStream("mt19937ar", Seed=configuredSeed);
    effectiveSeed = configuredSeed;
    return
end
if ~isa(configuredStream, "RandStream") || ~isscalar(configuredStream)
    error( ...
        "v2xsim:status:InvalidSelectionRandomStream", ...
        "SelectionRandomStream must be empty or a scalar RandStream.");
end

try
    effectiveSeed = double(configuredStream.Seed);
    stream = RandStream( ...
        configuredStream.Type, Seed=configuredStream.Seed);
    stream.State = configuredStream.State;
catch cause
    error( ...
        "v2xsim:status:SelectionRandomStreamCloneFailed", ...
        "Could not clone the selection random stream: %s", ...
        cause.message);
end
end

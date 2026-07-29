function [stream, effectiveSeed] = createOwnedRandomStream( ...
        configuredSeed, configuredStream)
%CREATEOWNEDRANDOMSTREAM Create an isolated reproducible random stream.
%   A supplied stream is cloned at its current state. Drawing from the
%   returned stream therefore never advances the supplied stream or the
%   MATLAB global random stream.

arguments (Input)
    configuredSeed (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeInteger, mustBeNonnegative}
    configuredStream = []
end

if configuredSeed > 2^32 - 1
    error( ...
        "v2xsim:positioning:InvalidRandomSeed", ...
        "Random seeds must not exceed 2^32 - 1.");
end

if isempty(configuredStream)
    stream = RandStream("mt19937ar", Seed=configuredSeed);
    effectiveSeed = configuredSeed;
    return
end
if ~isa(configuredStream, "RandStream") || ~isscalar(configuredStream)
    error( ...
        "v2xsim:positioning:InvalidRandomStream", ...
        "RandomStream options must be empty or a scalar RandStream.");
end

try
    effectiveSeed = double(configuredStream.Seed);
    stream = RandStream( ...
        configuredStream.Type, Seed=configuredStream.Seed);
    stream.State = configuredStream.State;
catch cause
    error( ...
        "v2xsim:positioning:RandomStreamCloneFailed", ...
        "Could not clone the configured random stream: %s", ...
        cause.message);
end
end

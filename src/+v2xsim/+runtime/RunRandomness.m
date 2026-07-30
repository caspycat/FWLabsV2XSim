classdef RunRandomness < handle
    %RUNRANDOMNESS Owns the master random stream for one run.
    %   Handle semantics are intentional because RandStream itself carries
    %   mutable draw state. Each RunRandomness constructs a private
    %   mt19937ar stream and never changes MATLAB's global random stream.

    properties (SetAccess = immutable)
        MasterSeed (1, 1) double
        % RandStream has no zero-input constructor, so a property type
        % declaration would make MATLAB instantiate it before this
        % constructor can create the owned stream.
        MasterStream
    end

    methods
        function obj = RunRandomness(masterSeed)
            arguments (Input)
                masterSeed (1, 1) double = 1
            end

            if ~isreal(masterSeed) || ~isfinite(masterSeed) || ...
                    masterSeed < 1 || mod(masterSeed, 1) ~= 0 || ...
                    masterSeed > 2^32 - 1
                error( ...
                    "v2xsim:runtime:InvalidRandomSeed", ...
                    "The master seed must be an integer from 1 through " + ...
                    "2^32 - 1.");
            end

            obj.MasterSeed = masterSeed;
            obj.MasterStream = RandStream( ...
                "mt19937ar", Seed=masterSeed);
        end

        function reset(obj)
            %RESET Restore the owned master stream to its initial state.
            arguments (Input)
                obj (1, 1)
            end

            reset(obj.MasterStream);
        end
    end
end

classdef PositionErrorChainSpecification
    %POSITIONERRORCHAINSPECIFICATION Explicit run-scoped module order.
    %   ENTRIES is an ordered row vector of PositionErrorChainEntry values.
    %   A specification supplied to v2xsim.runSimulation must reference
    %   every configured built-in module exactly once. Custom entries may
    %   occur at any position.

    properties (SetAccess = immutable)
        % PositionErrorChainEntry has no public zero-input constructor.
        % Constructor validation supplies the public type boundary without
        % forcing MATLAB to synthesize an invalid default instance.
        Entries
    end

    methods
        function obj = PositionErrorChainSpecification(entries)
            arguments (Input)
                entries = []
            end

            isEntryArray = isa( ...
                entries, ...
                "v2xsim.positioning.PositionErrorChainEntry");
            isRow = isrow(entries) || isempty(entries);
            if (~isempty(entries) && ~isEntryArray) || ~isRow
                error( ...
                    "v2xsim:positioning:InvalidPositionErrorChainEntry", ...
                    "Entries must be a row vector of " + ...
                    "PositionErrorChainEntry values.");
            end
            obj.Entries = entries;
        end
    end
end

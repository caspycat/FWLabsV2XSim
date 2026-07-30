classdef CoexistenceState < handle
    %COEXISTENCESTATE Owns per-node coexistence timing knowledge.
    %   KnownLteEndsSeconds records the end of the LTE portion known by
    %   each node. Handle semantics are intentional for shared mutable
    %   state within one run.

    properties (SetAccess = private)
        NodeIds (:, 1) uint64 = zeros(0, 1, "uint64")
        KnownLteEndsSeconds (:, 1) double = zeros(0, 1)
    end

    methods
        function obj = CoexistenceState(nodeIds, knownLteEndsSeconds)
            arguments (Input)
                nodeIds = zeros(0, 1)
                knownLteEndsSeconds = zeros(0, 1)
            end

            obj.replace(nodeIds, knownLteEndsSeconds);
        end

        function replace(obj, nodeIds, knownLteEndsSeconds)
            %REPLACE Atomically replace all per-node coexistence state.
            arguments (Input)
                obj (1, 1)
                nodeIds
                knownLteEndsSeconds
            end

            [nodeIds, knownLteEndsSeconds] = ...
                v2xsim.runtime.CoexistenceState.validateState( ...
                    nodeIds, knownLteEndsSeconds);
            obj.NodeIds = nodeIds;
            obj.KnownLteEndsSeconds = knownLteEndsSeconds;
        end

        function updateNode(obj, nodeId, knownLteEndSeconds)
            %UPDATENODE Replace coexistence knowledge for one existing node.
            arguments (Input)
                obj (1, 1)
                nodeId
                knownLteEndSeconds
            end

            [validatedId, validatedEnd] = ...
                v2xsim.runtime.CoexistenceState.validateState( ...
                    nodeId, knownLteEndSeconds);
            nodeIndex = find(obj.NodeIds == validatedId, 1);
            if isempty(nodeIndex)
                error( ...
                    "v2xsim:runtime:UnknownNodeId", ...
                    "Coexistence state has no node with identifier %s.", ...
                    string(validatedId));
            end
            obj.KnownLteEndsSeconds(nodeIndex) = validatedEnd;
        end

        function nodes = snapshot(obj)
            %SNAPSHOT Return a value-semantic table of current state.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                nodes table
            end

            nodes = table( ...
                obj.NodeIds, obj.KnownLteEndsSeconds, ...
                VariableNames=["NodeId", "KnownLteEndSeconds"]);
        end
    end

    methods (Static, Access = private)
        function [nodeIds, knownEnds] = ...
                validateState(nodeIds, knownEnds)
            if ~isnumeric(nodeIds) || ~isreal(nodeIds) || ...
                    (~isempty(nodeIds) && ~isvector(nodeIds)) || ...
                    any(~isfinite(nodeIds)) || ...
                    any(nodeIds <= 0) || any(mod(nodeIds, 1) ~= 0) || ...
                    any(nodeIds > flintmax)
                error( ...
                    "v2xsim:runtime:InvalidNodeIds", ...
                    "Node identifiers must be exactly representable " + ...
                    "positive integers.");
            end
            nodeIds = uint64(nodeIds(:));
            if numel(unique(nodeIds)) ~= numel(nodeIds)
                error( ...
                    "v2xsim:runtime:DuplicateNodeId", ...
                    "Node identifiers must be unique.");
            end

            if ~isnumeric(knownEnds) || ~isreal(knownEnds) || ...
                    (~isempty(knownEnds) && ~isvector(knownEnds)) || ...
                    any(~isfinite(knownEnds)) || any(knownEnds < 0)
                error( ...
                    "v2xsim:runtime:InvalidKnownLteEnds", ...
                    "Known LTE end times must be a finite, " + ...
                    "nonnegative real vector.");
            end
            knownEnds = double(knownEnds(:));
            if numel(knownEnds) ~= numel(nodeIds)
                error( ...
                    "v2xsim:runtime:NodeStateSizeMismatch", ...
                    "Node identifiers and known LTE end times must " + ...
                    "have equal lengths.");
            end
        end
    end
end

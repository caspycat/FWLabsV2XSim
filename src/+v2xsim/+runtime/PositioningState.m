classdef PositioningState < handle
    %POSITIONINGSTATE Owns mutable positioning process and chain data.
    %   Handle semantics provide one run-scoped owner while the two
    %   explicit scalar structs keep process state separate from ordered
    %   chain state.

    properties (SetAccess = private)
        ErrorProcessData (1, 1) struct = struct()
        ChainData (1, 1) struct = struct()
    end

    methods
        function obj = PositioningState(errorProcessData, chainData)
            arguments (Input)
                errorProcessData = struct()
                chainData = struct()
            end

            obj.replace(errorProcessData, chainData);
        end

        function replace(obj, errorProcessData, chainData)
            %REPLACE Atomically replace process and chain data.
            arguments (Input)
                obj (1, 1)
                errorProcessData
                chainData
            end

            v2xsim.runtime.PositioningState.validateData( ...
                errorProcessData, "ErrorProcessData");
            v2xsim.runtime.PositioningState.validateData( ...
                chainData, "ChainData");
            obj.ErrorProcessData = errorProcessData;
            obj.ChainData = chainData;
        end

        function replaceErrorProcessData(obj, errorProcessData)
            %REPLACEERRORPROCESSDATA Replace only error-process state.
            arguments (Input)
                obj (1, 1)
                errorProcessData
            end

            v2xsim.runtime.PositioningState.validateData( ...
                errorProcessData, "ErrorProcessData");
            obj.ErrorProcessData = errorProcessData;
        end

        function replaceChainData(obj, chainData)
            %REPLACECHAINDATA Replace only ordered-chain state.
            arguments (Input)
                obj (1, 1)
                chainData
            end

            v2xsim.runtime.PositioningState.validateData( ...
                chainData, "ChainData");
            obj.ChainData = chainData;
        end

        function state = snapshot(obj)
            %SNAPSHOT Return a value-semantic state snapshot.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                state (1, 1) struct
            end

            state = struct( ...
                "ErrorProcessData", obj.ErrorProcessData, ...
                "ChainData", obj.ChainData);
        end
    end

    methods (Static, Access = private)
        function validateData(value, propertyName)
            if ~isstruct(value) || ~isscalar(value)
                error( ...
                    "v2xsim:runtime:InvalidPositioningState", ...
                    "%s must be a scalar struct.", propertyName);
            end
        end
    end
end

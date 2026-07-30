classdef ChannelState < handle
    %CHANNELSTATE Owns mutable channel state for one simulation run.
    %   Handle semantics let collaborating channel components share the
    %   current line-of-sight matrix without using a process-global struct.

    properties (SetAccess = private)
        LosMatrix (:, :) logical = false(0, 0)
    end

    methods
        function obj = ChannelState(losMatrix)
            arguments (Input)
                losMatrix = false(0, 0)
            end

            obj.replaceLosMatrix(losMatrix);
        end

        function replaceLosMatrix(obj, losMatrix)
            %REPLACELOSMATRIX Atomically replace the square LOS matrix.
            arguments (Input)
                obj (1, 1)
                losMatrix
            end

            if ~islogical(losMatrix) || ~ismatrix(losMatrix) || ...
                    size(losMatrix, 1) ~= size(losMatrix, 2)
                error( ...
                    "v2xsim:runtime:InvalidLosMatrix", ...
                    "LosMatrix must be a square logical matrix.");
            end
            obj.LosMatrix = losMatrix;
        end
    end
end

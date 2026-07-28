classdef NetworkSliceId
    %NETWORKSLICEID Stable identity for a logical V2X network slice.
    %   Slice identifiers are exact, case-sensitive, nonblank strings.
    %   Whitespace is allowed inside an identifier but not at its edges.

    properties (SetAccess = immutable)
        Value (1, 1) string
    end

    methods
        function obj = NetworkSliceId(value)
            arguments (Input)
                value (1, 1) string = "global"
            end

            if ismissing(value) || strlength(value) == 0 || ...
                    strlength(strip(value)) == 0 || value ~= strip(value)
                error( ...
                    "v2xsim:network:InvalidNetworkSliceId", ...
                    "A network-slice identifier must be a nonblank " + ...
                    "string without leading or trailing whitespace.");
            end

            obj.Value = value;
        end

        function result = eq(left, right)
            arguments (Input)
                left (1, 1) v2xsim.network.NetworkSliceId
                right (1, 1) v2xsim.network.NetworkSliceId
            end

            result = left.Value == right.Value;
        end

        function result = ne(left, right)
            result = ~(left == right);
        end

        function value = string(obj)
            arguments (Input)
                obj (1, 1) v2xsim.network.NetworkSliceId
            end

            value = obj.Value;
        end
    end
end

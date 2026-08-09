classdef PositionErrorChainEntry
    %POSITIONERRORCHAINENTRY One configured or researcher-supplied module.
    %   CONFIGURED(TYPE) refers to one built-in module already defined by
    %   Positioning.Errors in the resolved configuration. CUSTOM(MODULE,
    %   DESCRIPTOR) contributes one run-owned PositionErrorModule and a
    %   JSON-safe provenance descriptor for the simulation summary.

    properties (SetAccess = immutable)
        Origin (1, 1) string = "Configured"
        ConfiguredType (1, 1) string = ""
        Module = []
        Descriptor (1, 1) struct = struct()
    end

    methods (Static)
        function obj = configured(type)
            %CONFIGURED Reference one TOML-configured built-in module.
            arguments (Input)
                type (1, 1) string
            end

            type = strip(type);
            if ismissing(type) || strlength(type) == 0
                error( ...
                    "v2xsim:positioning:InvalidConfiguredErrorType", ...
                    "A configured position-error type must be nonblank.");
            end
            obj = v2xsim.positioning.PositionErrorChainEntry( ...
                "Configured", type, [], struct());
        end

        function obj = custom(module, descriptor)
            %CUSTOM Add one researcher-supplied module and provenance.
            arguments (Input)
                module
                descriptor (1, 1) struct
            end

            isModule = isa(module, ...
                "v2xsim.positioning.PositionErrorModule") && ...
                isscalar(module);
            isValidHandle = ~isModule || ~isa(module, "handle") || ...
                isvalid(module);
            if ~isModule || ~isValidHandle
                error( ...
                    "v2xsim:positioning:InvalidCustomPositionErrorModule", ...
                    "A custom chain entry requires one scalar " + ...
                    "PositionErrorModule.");
            end
            v2xsim.positioning.PositionErrorChainEntry. ...
                validateJsonValue(descriptor, "Descriptor");
            obj = v2xsim.positioning.PositionErrorChainEntry( ...
                "Custom", "", module, descriptor);
        end
    end

    methods (Access = private)
        function obj = PositionErrorChainEntry( ...
                origin, configuredType, module, descriptor)
            obj.Origin = origin;
            obj.ConfiguredType = configuredType;
            obj.Module = module;
            obj.Descriptor = descriptor;
        end
    end

    methods (Static, Access = private)
        function validateJsonValue(value, path)
            if isstruct(value)
                fieldNames = string(fieldnames(value));
                for valueIndex = 1:numel(value)
                    for fieldName = reshape(fieldNames, 1, [])
                        childPath = path + "." + fieldName;
                        v2xsim.positioning.PositionErrorChainEntry. ...
                            validateJsonValue( ...
                                value(valueIndex).(fieldName), childPath);
                    end
                end
                return
            end

            if iscell(value)
                for valueIndex = 1:numel(value)
                    childPath = path + "{" + valueIndex + "}";
                    v2xsim.positioning.PositionErrorChainEntry. ...
                        validateJsonValue(value{valueIndex}, childPath);
                end
                return
            end

            isFiniteNumeric = isnumeric(value) && ~issparse(value) && ...
                isreal(value) && ...
                all(isfinite(value), "all");
            isLogical = islogical(value);
            isValidString = isstring(value) && ~any(ismissing(value), "all");
            isCharacterVector = ischar(value) && ...
                (isrow(value) || isempty(value));
            if isFiniteNumeric || isLogical || isValidString || ...
                    isCharacterVector
                return
            end

            error( ...
                "v2xsim:positioning:InvalidPositionErrorDescriptor", ...
                "%s contains a value of class %s that cannot be " + ...
                "preserved as strict JSON.", path, class(value));
        end
    end
end

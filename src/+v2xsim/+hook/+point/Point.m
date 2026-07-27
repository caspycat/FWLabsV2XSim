classdef (Abstract, HandleCompatible) Point
    %POINT Base type for logical locations where hooks are invoked.

    methods (Sealed)
        function invocationType = invocationType(obj)
            %INVOCATIONTYPE Validated class metadata for this point.
            arguments (Input)
                obj (1, 1)
            end

            invocationType = obj.declaredInvocationType();
            isMetadata = isa( ...
                invocationType, ...
                "matlab.metadata.Class") && ...
                isscalar(invocationType);
            invocationBaseType = ...
                ?v2xsim.hook.invocation.Invocation;
            if ~isMetadata || ...
                    ~(invocationType <= invocationBaseType)
                error( ...
                    "v2xsim:hook:InvalidInvocationTypeDeclaration", ...
                    "A Hook Point must declare one Hook Invocation type.");
            end
        end

        function isCompatible = acceptsInvocation(obj, invocation)
            %ACCEPTSINVOCATION Whether invocation belongs to this point.
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsim.hook.invocation.Invocation
            end

            invocationType = obj.invocationType();
            isCompatible = isa(invocation, invocationType.Name);
        end
    end

    methods (Abstract, Access = protected)
        %DECLAREDINVOCATIONTYPE Invocation metadata supplied by subclass.
        invocationType = declaredInvocationType(obj)
    end
end

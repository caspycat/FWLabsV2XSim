classdef (Sealed) HookDispatcher
    %HOOKDISPATCHER Dispatches hook invocations inside one simulation.
    %   This value facade exposes dispatch without exposing registration,
    %   dependency configuration, hook inspection, or cleanup.

    properties (GetAccess = private, SetAccess = immutable)
        Registry
    end

    methods (Access = ?v2xsim.hook.HookRegistry)
        function obj = HookDispatcher(registry)
            arguments (Input)
                registry (1, 1) v2xsim.hook.HookRegistry
            end

            obj.Registry = registry;
        end
    end

    methods
        function invocation = dispatch( ...
                obj, hookPoint, invocation)
            %DISPATCH Invoke registered hooks at one point.
            arguments (Input)
                obj (1, 1)
                hookPoint (1, 1) v2xsim.hook.point.Point
                invocation (1, 1) ...
                    v2xsim.hook.invocation.Invocation
            end

            if ~hookPoint.acceptsInvocation(invocation)
                error( ...
                    "v2xsim:hook:InvocationTypeMismatch", ...
                    "Hook point %s requires %s, but received %s.", ...
                    string(hookPoint), ...
                    hookPoint.invocationType().Name, ...
                    class(invocation));
            end

            invocation = obj.Registry.dispatchHooks( ...
                hookPoint, invocation);
        end
    end
end

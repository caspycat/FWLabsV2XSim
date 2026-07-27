classdef HookRegistry < handle
    %HOOKREGISTRY Registers and owns hooks for one simulation.
    %   Registrations are built when the first HookDispatcher is created.
    %   Greater priorities run first; equal priorities retain registration
    %   order. Registration closes once a dispatcher has been created.

    properties (Access = private)
        ServiceContainer
        Entries (1, :) cell = cell(1, 0)
        NextRegistrationOrder (1, 1) uint64 = uint64(1)
        IsRegistrationClosed (1, 1) logical = false
        IsBuilt (1, 1) logical = false
        IsCleanedUp (1, 1) logical = false
    end

    methods
        function obj = HookRegistry(serviceContainer)
            arguments (Input)
                serviceContainer (1, 1) ...
                    v2xsim.hook.dependency.ServiceContainer
            end

            obj.ServiceContainer = serviceContainer;
        end

        function register(obj, hook, hookPoints, options)
            %REGISTER Register one logical hook at one or more points.
            %   A multi-point registration is built and cleaned up once.
            %   The registry retains the hook returned by every invocation,
            %   so value-hook state is shared across all registered points.
            arguments (Input)
                obj (1, 1)
                hook (1, 1) v2xsim.hook.Hook
                hookPoints (1, :) v2xsim.hook.point.Point
                options.Priority (1, 1) double ...
                    {mustBeReal, mustBeFinite} = 0
            end

            obj.mustAcceptRegistrations();
            if isempty(hookPoints)
                error( ...
                    "v2xsim:hook:MissingHookPoint", ...
                    "A hook must be registered at one or more points.");
            end
            hook.dependencies();
            for hookPoint = hookPoints
                hookPoint.invocationType();
            end
            entry = struct( ...
                Hook=hook, ...
                HookPoints=hookPoints, ...
                Priority=options.Priority, ...
                RegistrationOrder=obj.NextRegistrationOrder, ...
                IsBuilt=false, ...
                IsCleanedUp=false);
            obj.Entries{end + 1} = entry;
            obj.NextRegistrationOrder = ...
                obj.NextRegistrationOrder + 1;
        end

        function dispatcher = createDispatcher(obj)
            %CREATEDISPATCHER Build registered hooks and create a facade.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                dispatcher (1, 1) v2xsim.hook.HookDispatcher
            end

            obj.mustNotBeCleanedUp();
            obj.IsRegistrationClosed = true;
            if ~obj.IsBuilt
                obj.buildHooks();
            end
            dispatcher = v2xsim.hook.HookDispatcher(obj);
        end

        function hooks = getHooks(obj, hookPoint)
            %GETHOOKS Return hooks at a point in registration order.
            arguments (Input)
                obj (1, 1)
                hookPoint (1, 1) v2xsim.hook.point.Point
            end
            arguments (Output)
                hooks (1, :) cell
            end

            matchingIndices = obj.findHookIndices(hookPoint);
            hooks = cell(1, numel(matchingIndices));
            for outputIndex = 1:numel(matchingIndices)
                entry = obj.Entries{matchingIndices(outputIndex)};
                hooks{outputIndex} = entry.Hook;
            end
        end

        function cleanup(obj)
            %CLEANUP Finalize every built hook once.
            %   Hooks are cleaned up in reverse registration order.
            arguments (Input)
                obj (1, 1)
            end

            if obj.IsCleanedUp
                return
            end

            for entryIndex = numel(obj.Entries):-1:1
                entry = obj.Entries{entryIndex};
                if ~entry.IsBuilt || entry.IsCleanedUp
                    continue
                end

                cleanedHook = entry.Hook.cleanup();
                obj.validateReturnedHook( ...
                    cleanedHook, entry.Hook, "cleanup");
                entry.Hook = cleanedHook;
                entry.IsCleanedUp = true;
                obj.Entries{entryIndex} = entry;
            end
            obj.IsCleanedUp = true;
        end
    end

    methods (Access = ?v2xsim.hook.HookDispatcher)
        function invocation = dispatchHooks( ...
                obj, hookPoint, invocation)
            obj.mustBeDispatchable();
            matchingIndices = obj.findHookIndices(hookPoint);
            if isempty(matchingIndices)
                return
            end

            priorities = zeros(numel(matchingIndices), 1);
            registrationOrders = zeros( ...
                numel(matchingIndices), 1);
            for matchIndex = 1:numel(matchingIndices)
                entry = obj.Entries{matchingIndices(matchIndex)};
                priorities(matchIndex) = entry.Priority;
                registrationOrders(matchIndex) = ...
                    double(entry.RegistrationOrder);
            end
            [~, executionOrder] = sortrows( ...
                [-priorities, registrationOrders], [1, 2]);
            matchingIndices = matchingIndices(executionOrder);

            for entryIndex = matchingIndices
                entry = obj.Entries{entryIndex};
                inputInvocation = invocation;
                [invokedHook, invocation] = ...
                    entry.Hook.invoke(invocation);
                obj.validateReturnedHook( ...
                    invokedHook, entry.Hook, "invoke");
                obj.validateReturnedInvocation( ...
                    invocation, inputInvocation, hookPoint);
                entry.Hook = invokedHook;
                obj.Entries{entryIndex} = entry;
            end
        end
    end

    methods (Access = private)
        function buildHooks(obj)
            for entryIndex = 1:numel(obj.Entries)
                entry = obj.Entries{entryIndex};
                if entry.IsBuilt
                    continue
                end

                dependencyTypes = entry.Hook.dependencies();
                dependencies = obj.ServiceContainer.resolveAll( ...
                    dependencyTypes);
                builtHook = entry.Hook.build(dependencies{:});
                obj.validateReturnedHook( ...
                    builtHook, entry.Hook, "build");
                entry.Hook = builtHook;
                entry.IsBuilt = true;
                obj.Entries{entryIndex} = entry;
            end

            obj.IsBuilt = true;
        end

        function matchingIndices = findHookIndices( ...
                obj, hookPoint)
            isMatch = cellfun( ...
                @(entry) any(arrayfun( ...
                    @(registeredPoint) isequal( ...
                        registeredPoint, hookPoint), ...
                    entry.HookPoints)), ...
                obj.Entries);
            matchingIndices = find(isMatch);
        end

        function mustAcceptRegistrations(obj)
            obj.mustNotBeCleanedUp();
            if obj.IsRegistrationClosed
                error( ...
                    "v2xsim:hook:RegistrationClosed", ...
                    "Hooks cannot be registered after a dispatcher " + ...
                    "has been created.");
            end
        end

        function mustBeDispatchable(obj)
            obj.mustNotBeCleanedUp();
            if ~obj.IsBuilt
                error( ...
                    "v2xsim:hook:RegistryNotBuilt", ...
                    "Hooks cannot be dispatched before they are built.");
            end
        end

        function mustNotBeCleanedUp(obj)
            if obj.IsCleanedUp
                error( ...
                    "v2xsim:hook:RegistryCleanedUp", ...
                    "A cleaned-up HookRegistry cannot register, build, " + ...
                    "or dispatch hooks.");
            end
        end

        function validateReturnedHook( ...
                ~, returnedHook, originalHook, operation)
            isHook = isa(returnedHook, "v2xsim.hook.Hook") && ...
                isscalar(returnedHook);
            isSameClass = isHook && ...
                strcmp(class(returnedHook), class(originalHook));
            isValidHandle = ~isHook || ...
                ~isa(returnedHook, "handle") || ...
                isvalid(returnedHook);
            if ~isHook || ~isSameClass || ~isValidHandle
                error( ...
                    "v2xsim:hook:InvalidReturnedHook", ...
                    "Hook %s must return one valid %s from %s.", ...
                    class(originalHook), class(originalHook), operation);
            end
        end

        function validateReturnedInvocation( ...
                ~, invocation, inputInvocation, hookPoint)
            isInvocation = isa( ...
                invocation, ...
                "v2xsim.hook.invocation.Invocation") && ...
                isscalar(invocation);
            isValidHandle = ~isInvocation || ...
                ~isa(invocation, "handle") || ...
                isvalid(invocation);
            if ~isInvocation || ~isValidHandle
                error( ...
                    "v2xsim:hook:InvalidReturnedInvocation", ...
                    "A hook must return one valid Hook Invocation.");
            end
            if ~strcmp(class(invocation), class(inputInvocation))
                error( ...
                    "v2xsim:hook:InvocationTypeChanged", ...
                    "A hook must return the same invocation class " + ...
                    "that it received.");
            end
            if ~hookPoint.acceptsInvocation(invocation)
                error( ...
                    "v2xsim:hook:InvocationTypeChanged", ...
                    "A hook at point %s returned %s instead of %s.", ...
                    string(hookPoint), ...
                    class(invocation), ...
                    hookPoint.invocationType().Name);
            end
        end
    end
end

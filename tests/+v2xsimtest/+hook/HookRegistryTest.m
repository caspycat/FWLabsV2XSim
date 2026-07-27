classdef HookRegistryTest < matlab.unittest.TestCase
    %HOOKREGISTRYTEST Tests registration, dispatch, and cleanup.

    methods (Test)
        function testBuildsDependenciesWhenDispatcherIsCreated( ...
                testCase)
            import v2xsim.hook.dependencies.OutputDirectory
            import v2xsimtest.hook.fixture.HookStub
            import v2xsimtest.hook.fixture.PointStub

            container = ...
                v2xsim.hook.dependency.ServiceContainer();
            expected = OutputDirectory(tempdir);
            container.provideConstant( ...
                ?v2xsim.hook.dependencies.OutputDirectory, ...
                expected);
            registry = v2xsim.hook.HookRegistry(container);
            registry.register(HookStub(), PointStub.Test);

            dispatcher = registry.createDispatcher();

            hooks = registry.getHooks(PointStub.Test);
            testCase.verifyInstanceOf( ...
                dispatcher, "v2xsim.hook.HookDispatcher");
            testCase.verifyEqual(hooks{1}.BuildCount, 1);
            testCase.verifyEqual( ...
                hooks{1}.OutputDirectory, expected);
        end

        function testDispatcherCreationBuildsEachHookOnce(testCase)
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register(TraceHook("metric"), PointStub.Test);

            registry.createDispatcher();
            registry.createDispatcher();

            hooks = registry.getHooks(PointStub.Test);
            testCase.verifyEqual(hooks{1}.BuildCount, 1);
        end

        function testDispatchesByPriorityThenRegistrationOrder( ...
                testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register( ...
                TraceHook("low"), ...
                PointStub.Test, Priority=-1);
            registry.register( ...
                TraceHook("first-high"), ...
                PointStub.Test, Priority=2);
            registry.register( ...
                TraceHook("second-high"), ...
                PointStub.Test, Priority=2);
            dispatcher = registry.createDispatcher();

            invocation = dispatcher.dispatch( ...
                PointStub.Test, InvocationStub());

            testCase.verifyEqual( ...
                invocation.Trace, ...
                ["first-high", "second-high", "low"]);
        end

        function testRetainsUpdatedValueHooks(testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register(TraceHook("metric"), PointStub.Test);
            dispatcher = registry.createDispatcher();

            dispatcher.dispatch(PointStub.Test, InvocationStub());
            dispatcher.dispatch(PointStub.Test, InvocationStub());

            hooks = registry.getHooks(PointStub.Test);
            testCase.verifyEqual(hooks{1}.InvocationCount, 2);
        end

        function testSharesValueHookStateAcrossRegisteredPoints( ...
                testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register( ...
                TraceHook("metric"), ...
                [PointStub.Test, PointStub.Other]);
            dispatcher = registry.createDispatcher();

            dispatcher.dispatch(PointStub.Test, InvocationStub());
            dispatcher.dispatch(PointStub.Other, InvocationStub());

            testHooks = registry.getHooks(PointStub.Test);
            otherHooks = registry.getHooks(PointStub.Other);
            testCase.verifyEqual(testHooks{1}.InvocationCount, 2);
            testCase.verifyEqual(otherHooks{1}.InvocationCount, 2);
            testCase.verifyEqual(testHooks{1}, otherHooks{1});
        end

        function testBuildsAndCleansMultiPointHookOnce(testCase)
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register( ...
                TraceHook("metric"), ...
                [PointStub.Test, PointStub.Other]);

            registry.createDispatcher();
            registry.cleanup();

            hooks = registry.getHooks(PointStub.Test);
            testCase.verifyEqual(hooks{1}.BuildCount, 1);
            testCase.verifyEqual(hooks{1}.CleanupCount, 1);
        end

        function testCleanupUpdatesBuiltHooksOnce(testCase)
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.register(TraceHook("first"), PointStub.Test);
            registry.register(TraceHook("second"), PointStub.Test);
            registry.createDispatcher();

            registry.cleanup();
            registry.cleanup();

            hooks = registry.getHooks(PointStub.Test);
            testCase.verifyEqual(hooks{1}.CleanupCount, 1);
            testCase.verifyEqual(hooks{2}.CleanupCount, 1);
        end

        function testCleanupUsesReverseRegistrationOrder(testCase)
            import v2xsimtest.hook.dependency.fixture.LifecycleRecorder
            import v2xsimtest.hook.fixture.CleanupRecordingHook
            import v2xsimtest.hook.fixture.PointStub

            container = ...
                v2xsim.hook.dependency.ServiceContainer();
            recorder = LifecycleRecorder();
            container.provideInstance( ...
                ?v2xsimtest.hook.dependency.fixture. ...
                LifecycleRecorder, ...
                recorder);
            registry = v2xsim.hook.HookRegistry(container);
            registry.register( ...
                CleanupRecordingHook("first"), PointStub.Test);
            registry.register( ...
                CleanupRecordingHook("second"), PointStub.Test);
            registry.createDispatcher();

            registry.cleanup();
            registry.cleanup();

            testCase.verifyEqual( ...
                recorder.Trace, ["second", "first"]);
        end

        function testRejectsRegistrationAfterDispatcherCreation( ...
                testCase)
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            registry = testCase.createEmptyRegistry();
            registry.createDispatcher();

            testCase.verifyError( ...
                @() registry.register( ...
                    TraceHook("late"), PointStub.Test), ...
                "v2xsim:hook:RegistrationClosed");
        end

        function testRejectsInvocationForDifferentPoint(testCase)
            import v2xsimtest.hook.fixture.PointStub

            registry = testCase.createEmptyRegistry();
            dispatcher = registry.createDispatcher();
            positions = testCase.createEmptyPositions();
            invocation = v2xsim.hook.invocations. ...
                AfterPositionErrorChainAppliedInvocation( ...
                    positions, positions);

            testCase.verifyError( ...
                @() dispatcher.dispatch( ...
                    PointStub.Test, invocation), ...
                "v2xsim:hook:InvocationTypeMismatch");
        end

        function testRejectsDispatchAfterCleanup(testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub

            registry = testCase.createEmptyRegistry();
            dispatcher = registry.createDispatcher();
            registry.cleanup();

            testCase.verifyError( ...
                @() dispatcher.dispatch( ...
                    PointStub.Test, InvocationStub()), ...
                "v2xsim:hook:RegistryCleanedUp");
        end

        function testReportsMissingDependencyDuringBuild(testCase)
            import v2xsimtest.hook.fixture.HookStub
            import v2xsimtest.hook.fixture.PointStub

            registry = testCase.createEmptyRegistry();
            registry.register(HookStub(), PointStub.Test);

            testCase.verifyError( ...
                @() registry.createDispatcher(), ...
                "v2xsim:hook:dependency:NotProvided");
        end

        function testBuildRetryDoesNotRebuildSuccessfulHooks( ...
                testCase)
            import v2xsim.hook.dependencies.OutputDirectory
            import v2xsimtest.hook.fixture.HookStub
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            container = ...
                v2xsim.hook.dependency.ServiceContainer();
            registry = v2xsim.hook.HookRegistry(container);
            registry.register( ...
                TraceHook("already-built"), PointStub.Test);
            registry.register(HookStub(), PointStub.Test);

            testCase.verifyError( ...
                @() registry.createDispatcher(), ...
                "v2xsim:hook:dependency:NotProvided");
            hooksAfterFailure = registry.getHooks(PointStub.Test);
            testCase.verifyEqual( ...
                hooksAfterFailure{1}.BuildCount, 1);
            testCase.verifyEqual( ...
                hooksAfterFailure{2}.BuildCount, 0);

            container.provideConstant( ...
                ?v2xsim.hook.dependencies.OutputDirectory, ...
                OutputDirectory(tempdir));
            registry.createDispatcher();

            hooksAfterRetry = registry.getHooks(PointStub.Test);
            testCase.verifyEqual(hooksAfterRetry{1}.BuildCount, 1);
            testCase.verifyEqual(hooksAfterRetry{2}.BuildCount, 1);
        end

        function testDispatchWithoutHooksReturnsInvocation( ...
                testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub

            registry = testCase.createEmptyRegistry();
            dispatcher = registry.createDispatcher();
            expected = InvocationStub();

            actual = dispatcher.dispatch(PointStub.Test, expected);

            testCase.verifyEqual(actual, expected);
        end

        function testRegistriesKeepSimulationStateIsolated( ...
                testCase)
            import v2xsimtest.hook.fixture.InvocationStub
            import v2xsimtest.hook.fixture.PointStub
            import v2xsimtest.hook.fixture.TraceHook

            firstRegistry = testCase.createEmptyRegistry();
            secondRegistry = testCase.createEmptyRegistry();
            firstRegistry.register( ...
                TraceHook("first"), PointStub.Test);
            secondRegistry.register( ...
                TraceHook("second"), PointStub.Test);
            firstDispatcher = firstRegistry.createDispatcher();
            secondDispatcher = secondRegistry.createDispatcher();

            firstDispatcher.dispatch( ...
                PointStub.Test, InvocationStub());
            secondDispatcher.dispatch( ...
                PointStub.Test, InvocationStub());
            secondDispatcher.dispatch( ...
                PointStub.Test, InvocationStub());

            firstHooks = firstRegistry.getHooks(PointStub.Test);
            secondHooks = secondRegistry.getHooks(PointStub.Test);
            testCase.verifyEqual( ...
                firstHooks{1}.InvocationCount, 1);
            testCase.verifyEqual( ...
                secondHooks{1}.InvocationCount, 2);
        end
    end

    methods (Access = private)
        function registry = createEmptyRegistry(~)
            container = ...
                v2xsim.hook.dependency.ServiceContainer();
            registry = v2xsim.hook.HookRegistry(container);
        end

        function positions = createEmptyPositions(~)
            positions = table( ...
                zeros(0, 1), zeros(0, 1), ...
                VariableNames=["X", "Y"]);
        end
    end
end

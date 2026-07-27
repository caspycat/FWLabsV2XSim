classdef HookTest < matlab.unittest.TestCase
    %HOOKTEST Tests value-hook lifecycle and dependency declarations.

    methods (Test)
        function testBuildReceivesDeclaredDependencies(testCase)
            import v2xsim.hook.dependencies.OutputDirectory
            import v2xsimtest.hook.fixture.HookStub

            container = ...
                v2xsim.hook.dependency.ServiceContainer();
            expected = OutputDirectory(tempdir);
            container.provideConstant( ...
                ?v2xsim.hook.dependencies.OutputDirectory, ...
                expected);
            hook = HookStub();

            dependencies = ...
                container.resolveAll(hook.dependencies());
            hook = hook.build(dependencies{:});

            testCase.verifyEqual( ...
                hook.OutputDirectory, expected);
        end

        function testInvokeAndCleanupRetainValueState(testCase)
            import v2xsim.hook.dependencies.OutputDirectory
            import v2xsimtest.hook.fixture.HookStub
            import v2xsimtest.hook.fixture.InvocationStub

            hook = HookStub();
            hook = hook.build(OutputDirectory(tempdir));
            [hook, invocation] = hook.invoke(InvocationStub());
            hook = hook.cleanup();

            testCase.verifyEqual(hook.InvocationCount, 1);
            testCase.verifyEqual(hook.CleanupCount, 1);
            testCase.verifyEqual(invocation.InvocationCount, 1);
        end

        function testRejectsArbitraryDependencyType(testCase)
            hook = v2xsimtest.hook.fixture. ...
                InvalidDependencyHook();

            testCase.verifyError( ...
                @() hook.dependencies(), ...
                "v2xsim:hook:InvalidDependencyDeclaration");
        end

        function testRejectsDuplicateDependencyType(testCase)
            hook = v2xsimtest.hook.fixture. ...
                DuplicateDependencyHook();

            testCase.verifyError( ...
                @() hook.dependencies(), ...
                "v2xsim:hook:DuplicateDependencyDeclaration");
        end
    end
end

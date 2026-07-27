classdef HookStub < v2xsim.hook.Hook
    %HOOKSTUB Value hook with one injected dependency.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            ?v2xsim.hook.dependencies.OutputDirectory
    end

    properties (SetAccess = private)
        OutputDirectory
        BuildCount (1, 1) double = 0
        InvocationCount (1, 1) double = 0
        CleanupCount (1, 1) double = 0
    end

    methods
        function obj = build(obj, outputDirectory)
            arguments (Input)
                obj (1, 1)
                outputDirectory (1, 1) ...
                    v2xsim.hook.dependencies.OutputDirectory
            end

            obj.OutputDirectory = outputDirectory;
            obj.BuildCount = obj.BuildCount + 1;
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsimtest.hook.fixture.InvocationStub
            end

            obj.InvocationCount = obj.InvocationCount + 1;
            invocation = invocation.recordInvocation();
        end

        function obj = cleanup(obj)
            arguments (Input)
                obj (1, 1)
            end

            obj.CleanupCount = obj.CleanupCount + 1;
        end
    end
end

classdef TraceHook < v2xsim.hook.Hook
    %TRACEHOOK Stateful value hook without dependencies.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            matlab.metadata.Class.empty(1, 0)
    end

    properties (SetAccess = immutable)
        Label (1, 1) string
    end

    properties (SetAccess = private)
        BuildCount (1, 1) double = 0
        InvocationCount (1, 1) double = 0
        CleanupCount (1, 1) double = 0
    end

    methods
        function obj = TraceHook(label)
            arguments (Input)
                label (1, 1) string
            end

            obj.Label = label;
        end

        function obj = build(obj)
            obj.BuildCount = obj.BuildCount + 1;
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsimtest.hook.fixture.InvocationStub
            end

            obj.InvocationCount = obj.InvocationCount + 1;
            invocation = invocation.recordInvocation(obj.Label);
        end

        function obj = cleanup(obj)
            obj.CleanupCount = obj.CleanupCount + 1;
        end
    end
end

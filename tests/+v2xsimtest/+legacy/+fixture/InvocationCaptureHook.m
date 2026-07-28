classdef InvocationCaptureHook < v2xsim.hook.Hook
    %INVOCATIONCAPTUREHOOK Retain typed invocations for bridge tests.

    properties (Constant, Access = protected)
        DependencyTypes = matlab.metadata.Class.empty(1,0)
    end

    properties (SetAccess = private)
        Invocations (1,:) cell = cell(1,0)
    end

    methods
        function obj = build(obj)
        end

        function [obj,invocation] = invoke(obj,invocation)
            arguments (Input)
                obj (1,1)
                invocation (1,1) v2xsim.hook.invocation.Invocation
            end

            obj.Invocations{end + 1} = invocation;
        end

        function obj = cleanup(obj)
        end
    end
end

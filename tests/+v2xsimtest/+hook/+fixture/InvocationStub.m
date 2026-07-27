classdef InvocationStub < v2xsim.hook.invocation.Invocation
    %INVOCATIONSTUB Value invocation for Hook tests.

    properties (SetAccess = private)
        InvocationCount (1, 1) double = 0
        Trace (1, :) string = strings(1, 0)
    end

    methods
        function obj = recordInvocation(obj, label)
            arguments (Input)
                obj (1, 1)
                label (1, 1) string = ""
            end

            obj.InvocationCount = obj.InvocationCount + 1;
            if label ~= ""
                obj.Trace(end + 1) = label;
            end
        end
    end
end

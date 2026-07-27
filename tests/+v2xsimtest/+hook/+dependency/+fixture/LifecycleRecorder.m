classdef LifecycleRecorder < handle & ...
        v2xsim.hook.dependency.Dependency
    %LIFECYCLERECORDER Shared lifecycle log for registry tests.

    properties (SetAccess = private)
        Trace (1, :) string = strings(1, 0)
    end

    methods
        function record(obj, label)
            arguments (Input)
                obj (1, 1)
                label (1, 1) string
            end

            obj.Trace(end + 1) = label;
        end
    end
end

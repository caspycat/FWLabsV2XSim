classdef CleanupRecordingHook < v2xsim.hook.Hook
    %CLEANUPRECORDINGHOOK Value hook that records cleanup order.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            ?v2xsimtest.hook.dependency.fixture. ...
            LifecycleRecorder
    end

    properties (SetAccess = immutable)
        Label (1, 1) string
    end

    properties (Access = private)
        Recorder
    end

    methods
        function obj = CleanupRecordingHook(label)
            arguments (Input)
                label (1, 1) string
            end

            obj.Label = label;
        end

        function obj = build(obj, recorder)
            arguments (Input)
                obj (1, 1)
                recorder (1, 1) ...
                    v2xsimtest.hook.dependency.fixture. ...
                    LifecycleRecorder
            end

            obj.Recorder = recorder;
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsimtest.hook.fixture.InvocationStub
            end
        end

        function obj = cleanup(obj)
            obj.Recorder.record(obj.Label);
        end
    end
end

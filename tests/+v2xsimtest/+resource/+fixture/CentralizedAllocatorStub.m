classdef CentralizedAllocatorStub < ...
        v2xsim.resource.CentralizedResourceAllocator
    %CENTRALIZEDALLOCATORSTUB Controllable centralized allocator test double.

    properties (Constant)
        Type = "CentralizedStub"
        Description = "Centralized allocator test double"
    end

    properties (SetAccess = immutable)
        ResultFactory (1, 1) function_handle = ...
            @v2xsimtest.resource.fixture.createEchoResult
    end

    properties (SetAccess = private)
        LastRandomValue (1, 1) double = NaN
        InitializationCount (1, 1) double = 0
        StepCount (1, 1) double = 0
        SynchronizationCount (1, 1) double = 0
        EnteredUeIds (:, 1) string = strings(0, 1)
        ExitedUeIds (:, 1) string = strings(0, 1)
    end

    methods
        function obj = CentralizedAllocatorStub( ...
                grid, randomSeed, maximumTransmissionCount, resultFactory)
            arguments (Input)
                grid (1, 1) v2xsim.resource.BRResourceGrid
                randomSeed (1, 1) double
                maximumTransmissionCount (1, 1) double = 1
                resultFactory (1, 1) function_handle = ...
                    @v2xsimtest.resource.fixture.createEchoResult
            end

            obj = obj@v2xsim.resource.CentralizedResourceAllocator( ...
                grid, randomSeed, maximumTransmissionCount);
            obj.ResultFactory = resultFactory;
        end
    end

    methods (Access = protected)
        function obj = doSynchronizeUes( ...
                obj, enteredUeIds, exitedUeIds)
            obj.SynchronizationCount = obj.SynchronizationCount + 1;
            obj.EnteredUeIds = [obj.EnteredUeIds; enteredUeIds];
            obj.ExitedUeIds = [obj.ExitedUeIds; exitedUeIds];
        end

        function [obj, result] = doInitialize( ...
                obj, context, randomStream)
            obj.InitializationCount = obj.InitializationCount + 1;
            obj.LastRandomValue = rand(randomStream);
            result = obj.ResultFactory( ...
                context, obj.Assignments, obj.LastRandomValue);
        end

        function [obj, result] = doStep(obj, context, randomStream)
            obj.StepCount = obj.StepCount + 1;
            obj.LastRandomValue = rand(randomStream);
            result = obj.ResultFactory( ...
                context, obj.Assignments, obj.LastRandomValue);
        end
    end
end

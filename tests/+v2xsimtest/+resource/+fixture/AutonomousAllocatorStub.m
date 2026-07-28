classdef AutonomousAllocatorStub < ...
        v2xsim.resource.AutonomousResourceAllocator
    %AUTONOMOUSALLOCATORSTUB Controllable autonomous allocator test double.

    properties (Constant)
        Type = "AutonomousStub"
        Description = "Autonomous allocator test double"
        ContextContract = "Autonomous"
        UsesSelectionWindow = false
    end

    properties (SetAccess = immutable)
        ResultFactory (1, 1) function_handle = ...
            @v2xsimtest.resource.fixture.createEchoResult
    end

    properties (SetAccess = private)
        LastRandomValue (1, 1) double = NaN
    end

    methods
        function obj = AutonomousAllocatorStub( ...
                grid, randomSeed, maximumTransmissionCount, resultFactory)
            arguments (Input)
                grid (1, 1) v2xsim.resource.BRResourceGrid
                randomSeed (1, 1) double
                maximumTransmissionCount (1, 1) double = 1
                resultFactory (1, 1) function_handle = ...
                    @v2xsimtest.resource.fixture.createEchoResult
            end

            obj = obj@v2xsim.resource.AutonomousResourceAllocator( ...
                grid, randomSeed, maximumTransmissionCount);
            obj.ResultFactory = resultFactory;
        end
    end

    methods (Access = protected)
        function [obj, result] = doInitialize( ...
                obj, context, randomStream)
            obj.LastRandomValue = rand(randomStream);
            result = obj.ResultFactory( ...
                context, obj.Assignments, obj.LastRandomValue);
        end

        function [obj, result] = doStep(obj, context, randomStream)
            obj.LastRandomValue = rand(randomStream);
            result = obj.ResultFactory( ...
                context, obj.Assignments, obj.LastRandomValue);
        end
    end
end

classdef DynamicScenarioStub < v2xsim.vehicle.scenario.Scenario
    %DYNAMICSCENARIOSTUB Controllable dynamic Scenario used by unit tests.

    properties (Constant)
        IS_VEHICLE_COUNT_DYNAMIC = true
        CAN_STEP_BACKWARD = false
        PROVIDES_VELOCITY = false
        PROVIDES_ACCELERATION = false
    end

    properties (SetAccess = private)
        NextVehicleKinematics table
        NextVehicleLifecycleTransitions table
        LastDeltaTime (1, 1) double = NaN
        StepProbe = []
    end

    methods
        function obj = DynamicScenarioStub( ...
                initialVehicleKinematics, ...
                nextVehicleKinematics, ...
                nextVehicleLifecycleTransitions, ...
                stepProbe)
            arguments (Input)
                initialVehicleKinematics table
                nextVehicleKinematics table
                nextVehicleLifecycleTransitions table
                stepProbe = []
            end

            obj = obj@v2xsim.vehicle.scenario.Scenario( ...
                initialVehicleKinematics);
            obj.NextVehicleKinematics = nextVehicleKinematics;
            obj.NextVehicleLifecycleTransitions = ...
                nextVehicleLifecycleTransitions;
            obj.StepProbe = stepProbe;
        end
    end

    methods (Access = protected)
        function [obj, vehicleKinematics, vehicleLifecycleTransitions] = ...
                doStep(obj, deltaTime)
            obj.LastDeltaTime = deltaTime;
            if ~isempty(obj.StepProbe)
                obj.StepProbe.record(deltaTime);
            end
            vehicleKinematics = obj.NextVehicleKinematics;
            vehicleLifecycleTransitions = ...
                obj.NextVehicleLifecycleTransitions;
        end
    end
end

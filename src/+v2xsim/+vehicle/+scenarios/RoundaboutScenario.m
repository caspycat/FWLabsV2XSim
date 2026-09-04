classdef RoundaboutScenario < v2xsim.vehicle.scenario.LanedScenario
    %ROUNDABOUTSCENARIO Clockwise left-driving four-arm roundabout.
    %   A fixed vehicle population is distributed across complete routes.
    %   Every spawn selects its entry and exit arms independently and
    %   uniformly, including U-turn routes whose entry and exit arms match.
    %   Vehicles recycle at outbound endpoints. This model intentionally
    %   has no following, collision, gap-acceptance, or yielding behavior.

    properties (Constant)
        CAN_STEP_BACKWARD = false
        PROVIDES_ACCELERATION = false
    end

    properties (SetAccess = immutable)
        Geometry (1, 1) ...
            v2xsim.vehicle.scenario.roundabout.Geometry = ...
            v2xsim.vehicle.scenario.roundabout.Geometry(500, 4, 60)
    end

    properties (SetAccess = private)
        MobilityModel = []
    end

    properties (Dependent, SetAccess = private)
        ExitLengths
        RoadWidth
        InnerCircleDiameter
        MeanVehicleSpeed
        VehicleSpeedStandardDeviation
        RerollSpeedOnWrapAround
        VehicleRouteStates
    end

    methods
        function obj = RoundaboutScenario(vehicleCount, options)
            arguments (Input)
                vehicleCount (1, 1) double ...
                    {mustBeInteger, mustBePositive}
                options.RandomSeed (1, 1) double ...
                    {mustBeInteger, mustBeNonnegative} = 0
                options.ExitLengths double = 500
                options.RoadWidth (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBePositive} = 4
                options.InnerCircleDiameter (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBePositive} = 60
                options.MeanVehicleSpeed (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeNonnegative} = 20
                options.VehicleSpeedStandardDeviation (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeNonnegative} = 2
                options.RerollSpeedOnWrapAround (1, 1) logical = true
            end

            randomStream = RandStream( ...
                "mt19937ar", Seed=options.RandomSeed);
            geometry = ...
                v2xsim.vehicle.scenario.roundabout.Geometry( ...
                    options.ExitLengths, ...
                    options.RoadWidth, ...
                    options.InnerCircleDiameter);
            laneNetwork = geometry.createLaneNetwork();
            mobilityModel = ...
                v2xsim.vehicle.scenario.roundabout.MobilityModel( ...
                    options.MeanVehicleSpeed, ...
                    options.VehicleSpeedStandardDeviation, ...
                    options.RerollSpeedOnWrapAround, ...
                    randomStream);
            [mobilityModel, initialVehicleKinematics, ...
                initialVehicleLaneStates] = mobilityModel.initialize( ...
                    vehicleCount, geometry, laneNetwork);

            obj = obj@v2xsim.vehicle.scenario.LanedScenario( ...
                initialVehicleKinematics, ...
                laneNetwork, ...
                initialVehicleLaneStates);
            obj.Geometry = geometry;
            obj.MobilityModel = mobilityModel;
        end

        function value = get.ExitLengths(obj)
            value = obj.Geometry.ExitLengths;
        end

        function value = get.RoadWidth(obj)
            value = obj.Geometry.RoadWidth;
        end

        function value = get.InnerCircleDiameter(obj)
            value = obj.Geometry.InnerCircleDiameter;
        end

        function value = get.MeanVehicleSpeed(obj)
            value = obj.MobilityModel.MeanVehicleSpeed;
        end

        function value = get.VehicleSpeedStandardDeviation(obj)
            value = obj.MobilityModel.VehicleSpeedStandardDeviation;
        end

        function value = get.RerollSpeedOnWrapAround(obj)
            value = obj.MobilityModel.RerollSpeedOnWrapAround;
        end

        function value = get.VehicleRouteStates(obj)
            value = obj.MobilityModel.getVehicleRouteStates( ...
                obj.Geometry, obj.VehicleLaneStates);
        end
    end

    methods (Access = protected)
        function [obj, vehicleKinematics] = updateVelocities( ...
                obj, vehicleKinematics, ~)
            [mobilityModel, vehicleKinematics] = ...
                obj.MobilityModel.updateVelocities( ...
                    obj.Geometry, ...
                    vehicleKinematics, ...
                    obj.VehicleLaneStates);
            obj.MobilityModel = mobilityModel;
        end

        function [obj, vehicleKinematics, vehicleLaneStates] = ...
                resolveLanedPositionConstraints( ...
                    obj, previousVehicleKinematics, ~, ...
                    previousVehicleLaneStates, deltaTime)
            [mobilityModel, vehicleKinematics, vehicleLaneStates] = ...
                obj.MobilityModel.resolvePositionConstraints( ...
                    obj.Geometry, ...
                    obj.LaneNetwork, ...
                    previousVehicleKinematics, ...
                    previousVehicleLaneStates, ...
                    deltaTime);
            obj.MobilityModel = mobilityModel;
        end
    end
end

classdef MobilityModel
    %MOBILITYMODEL Fixed-population route motion for the roundabout.
    %   Every vehicle owns an entry arm, a uniformly selected exit arm,
    %   and a nonnegative scalar speed. Motion is measured as physical
    %   distance along named lanes. Reaching an outbound endpoint recycles
    %   the same vehicle to a newly sampled route, and a remaining-time
    %   loop preserves all intervening boundary events for large steps.

    properties (SetAccess = immutable)
        MeanVehicleSpeed (1, 1) double = 20
        VehicleSpeedStandardDeviation (1, 1) double = 2
        RerollSpeedOnWrapAround (1, 1) logical = true
    end

    properties (SetAccess = immutable, GetAccess = private)
        RandomStream (1, 1) RandStream = RandStream("mt19937ar", Seed=0)
    end

    properties (SetAccess = private)
        VehicleRoutes table = table()
    end

    methods
        function obj = MobilityModel( ...
                meanVehicleSpeed, vehicleSpeedStandardDeviation, ...
                rerollSpeedOnWrapAround, randomStream)
            arguments (Input)
                meanVehicleSpeed (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeNonnegative}
                vehicleSpeedStandardDeviation (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeNonnegative}
                rerollSpeedOnWrapAround (1, 1) logical
                randomStream (1, 1) RandStream
            end

            obj.MeanVehicleSpeed = meanVehicleSpeed;
            obj.VehicleSpeedStandardDeviation = ...
                vehicleSpeedStandardDeviation;
            obj.RerollSpeedOnWrapAround = rerollSpeedOnWrapAround;
            obj.RandomStream = randomStream;
        end

        function [obj, vehicleKinematics, vehicleLaneStates] = ...
                initialize(obj, vehicleCount, geometry, laneNetwork)
            arguments (Input)
                obj (1, 1)
                vehicleCount (1, 1) double ...
                    {mustBeInteger, mustBePositive}
                geometry (1, 1) ...
                    v2xsim.vehicle.scenario.roundabout.Geometry
                laneNetwork (1, 1) ...
                    v2xsim.vehicle.scenario.highway.LaneNetwork
            end

            rowNames = compose("V%d", (1:vehicleCount).');
            entryIndices = randi(obj.RandomStream, 4, vehicleCount, 1);
            exitIndices = randi(obj.RandomStream, 4, vehicleCount, 1);
            speed = obj.sampleSpeed(vehicleCount);
            entryArm = geometry.ArmNames(entryIndices).';
            exitArm = geometry.ArmNames(exitIndices).';
            obj.VehicleRoutes = table( ...
                entryArm, exitArm, speed, ...
                VariableNames=["EntryArm", "ExitArm", "Speed"], ...
                RowNames=rowNames);

            totalDistance = obj.getRouteLengths( ...
                geometry, entryIndices, exitIndices);
            routeDistance = totalDistance .* ...
                rand(obj.RandomStream, vehicleCount, 1);
            laneId = strings(vehicleCount, 1);
            progress = zeros(vehicleCount, 1);
            for vehicleIndex = 1:vehicleCount
                [laneId(vehicleIndex), progress(vehicleIndex)] = ...
                    obj.locateRouteDistance( ...
                        geometry, ...
                        entryIndices(vehicleIndex), ...
                        exitIndices(vehicleIndex), ...
                        routeDistance(vehicleIndex));
            end

            lateralOffsetMeters = zeros(vehicleCount, 1);
            vehicleLaneStates = table( ...
                laneId, progress, lateralOffsetMeters, ...
                VariableNames=[ ...
                    "LaneId", "Progress", "LateralOffsetMeters"], ...
                RowNames=rowNames);
            vehicleKinematics = obj.createKinematics( ...
                geometry, laneNetwork, vehicleLaneStates);
        end

        function [obj, vehicleKinematics] = updateVelocities( ...
                obj, geometry, vehicleKinematics, vehicleLaneStates)
            arguments (Input)
                obj (1, 1)
                geometry (1, 1) ...
                    v2xsim.vehicle.scenario.roundabout.Geometry
                vehicleKinematics table ...
                    {v2xsim.vehicle.scenario.validation.mustBe2DKinematicsTable}
                vehicleLaneStates table ...
                    {v2xsim.vehicle.scenario.validation.mustBeVehicleLaneStateTable}
            end

            rowNames = vehicleKinematics.Properties.RowNames;
            obj.validateVehicleSets(rowNames, vehicleLaneStates);
            obj.VehicleRoutes = obj.VehicleRoutes(rowNames, :);
            vehicleLaneStates = vehicleLaneStates(rowNames, :);
            tangents = geometry.getLaneTangent( ...
                vehicleLaneStates.LaneId, vehicleLaneStates.Progress);
            speed = obj.VehicleRoutes.Speed;
            vehicleKinematics.vX = speed .* tangents(:, 1);
            vehicleKinematics.vY = speed .* tangents(:, 2);
        end

        function [obj, vehicleKinematics, vehicleLaneStates] = ...
                resolvePositionConstraints( ...
                    obj, geometry, laneNetwork, ...
                    previousVehicleKinematics, previousVehicleLaneStates, ...
                    deltaTime)
            arguments (Input)
                obj (1, 1)
                geometry (1, 1) ...
                    v2xsim.vehicle.scenario.roundabout.Geometry
                laneNetwork (1, 1) ...
                    v2xsim.vehicle.scenario.highway.LaneNetwork
                previousVehicleKinematics table ...
                    {v2xsim.vehicle.scenario.validation.mustBe2DKinematicsTable}
                previousVehicleLaneStates table ...
                    {v2xsim.vehicle.scenario.validation.mustBeVehicleLaneStateTable}
                deltaTime (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBePositive}
            end

            rowNames = previousVehicleKinematics.Properties.RowNames;
            obj.validateVehicleSets(rowNames, previousVehicleLaneStates);
            obj.VehicleRoutes = obj.VehicleRoutes(rowNames, :);
            vehicleLaneStates = previousVehicleLaneStates(rowNames, :);

            for vehicleIndex = 1:height(vehicleLaneStates)
                remainingTime = deltaTime;
                while remainingTime > 0
                    speed = obj.VehicleRoutes.Speed(vehicleIndex);
                    if speed == 0
                        break
                    end

                    laneId = vehicleLaneStates.LaneId(vehicleIndex);
                    laneLength = geometry.getLaneLength(laneId);
                    progress = vehicleLaneStates.Progress(vehicleIndex);
                    distanceToEnd = max(0, (1 - progress) .* laneLength);
                    timeToEnd = distanceToEnd ./ speed;
                    if all(remainingTime < timeToEnd, "all")
                        vehicleLaneStates.Progress(vehicleIndex) = ...
                            min(1, progress + ...
                            speed .* remainingTime ./ laneLength);
                        remainingTime = 0;
                    else
                        remainingTime = max(0, ...
                            remainingTime - timeToEnd);
                        [obj, nextLaneId] = obj.transitionAtLaneEnd( ...
                            geometry, vehicleIndex, laneId);
                        vehicleLaneStates.LaneId(vehicleIndex) = nextLaneId;
                        vehicleLaneStates.Progress(vehicleIndex) = 0;
                    end
                end
            end

            vehicleKinematics = obj.createKinematics( ...
                geometry, laneNetwork, vehicleLaneStates);
        end

        function routeStates = getVehicleRouteStates( ...
                obj, geometry, vehicleLaneStates)
            arguments (Input)
                obj (1, 1)
                geometry (1, 1) ...
                    v2xsim.vehicle.scenario.roundabout.Geometry
                vehicleLaneStates table ...
                    {v2xsim.vehicle.scenario.validation.mustBeVehicleLaneStateTable}
            end

            rowNames = vehicleLaneStates.Properties.RowNames;
            obj.validateVehicleSets(rowNames, vehicleLaneStates);
            routes = obj.VehicleRoutes(rowNames, :);
            stage = geometry.getRouteStage( ...
                vehicleLaneStates.LaneId, vehicleLaneStates.Progress);
            routeStates = table( ...
                routes.EntryArm, routes.ExitArm, stage, ...
                VariableNames=["EntryArm", "ExitArm", "Stage"], ...
                RowNames=rowNames);
        end
    end

    methods (Access = private)
        function speed = sampleSpeed(obj, count)
            if obj.VehicleSpeedStandardDeviation == 0
                speed = repmat(obj.MeanVehicleSpeed, count, 1);
                return
            end

            speed = obj.MeanVehicleSpeed + ...
                obj.VehicleSpeedStandardDeviation .* ...
                randn(obj.RandomStream, count, 1);
            needsResampling = speed < 0;
            while any(needsResampling)
                speed(needsResampling) = obj.MeanVehicleSpeed + ...
                    obj.VehicleSpeedStandardDeviation .* randn( ...
                        obj.RandomStream, nnz(needsResampling), 1);
                needsResampling = speed < 0;
            end
        end

        function routeLengths = getRouteLengths( ...
                ~, geometry, entryIndices, exitIndices)
            exitStep = mod(exitIndices - entryIndices - 1, 4) + 1;
            routeLengths = ...
                geometry.ApproachLaneLengths(entryIndices).' + ...
                exitStep .* geometry.EntryToExitArcLength + ...
                (exitStep - 1) .* geometry.ExitToEntryArcLength + ...
                geometry.ExitLaneLengths(exitIndices).';
        end

        function [laneId, progress] = locateRouteDistance( ...
                ~, geometry, entryIndex, exitIndex, routeDistance)
            approachLength = geometry.ApproachLaneLengths(entryIndex);
            if routeDistance < approachLength
                laneId = geometry.getApproachLaneId( ...
                    geometry.ArmNames(entryIndex));
                progress = routeDistance ./ approachLength;
                return
            end
            routeDistance = routeDistance - approachLength;

            exitStep = mod(exitIndex - entryIndex - 1, 4) + 1;
            currentArmIndex = entryIndex;
            for stepIndex = 1:exitStep
                if routeDistance < geometry.EntryToExitArcLength
                    laneId = ...
                        geometry.getCirculatingLaneIdAfterEntry( ...
                            geometry.ArmNames(currentArmIndex));
                    progress = routeDistance ./ ...
                        geometry.EntryToExitArcLength;
                    return
                end
                routeDistance = routeDistance - ...
                    geometry.EntryToExitArcLength;
                nextArmIndex = mod(currentArmIndex, 4) + 1;

                if stepIndex == exitStep
                    laneId = geometry.getExitLaneId( ...
                        geometry.ArmNames(nextArmIndex));
                    progress = min(1, routeDistance ./ ...
                        geometry.ExitLaneLengths(nextArmIndex));
                    return
                end

                if routeDistance < geometry.ExitToEntryArcLength
                    laneId = ...
                        geometry.getCirculatingLaneIdAfterExit( ...
                            geometry.ArmNames(nextArmIndex));
                    progress = routeDistance ./ ...
                        geometry.ExitToEntryArcLength;
                    return
                end
                routeDistance = routeDistance - ...
                    geometry.ExitToEntryArcLength;
                currentArmIndex = nextArmIndex;
            end

            error( ...
                "v2xsim:scenario:roundabout:InvalidRouteDistance", ...
                "Route distance could not be mapped onto the route.");
        end

        function [obj, nextLaneId] = transitionAtLaneEnd( ...
                obj, geometry, vehicleIndex, laneId)
            routes = obj.VehicleRoutes;
            for armIndex = 1:4
                arm = geometry.ArmNames(armIndex);
                if laneId == geometry.getApproachLaneId(arm)
                    nextLaneId = ...
                        geometry.getCirculatingLaneIdAfterEntry(arm);
                    return
                end
                if laneId == ...
                        geometry.getCirculatingLaneIdAfterEntry(arm)
                    nextArm = geometry.getClockwiseArm(arm);
                    if routes.ExitArm(vehicleIndex) == nextArm
                        nextLaneId = geometry.getExitLaneId(nextArm);
                    else
                        nextLaneId = ...
                            geometry.getCirculatingLaneIdAfterExit(nextArm);
                    end
                    return
                end
                if laneId == ...
                        geometry.getCirculatingLaneIdAfterExit(arm)
                    nextLaneId = ...
                        geometry.getCirculatingLaneIdAfterEntry(arm);
                    return
                end
                if laneId == geometry.getExitLaneId(arm)
                    entryIndex = randi(obj.RandomStream, 4);
                    exitIndex = randi(obj.RandomStream, 4);
                    routes.EntryArm(vehicleIndex) = ...
                        geometry.ArmNames(entryIndex);
                    routes.ExitArm(vehicleIndex) = ...
                        geometry.ArmNames(exitIndex);
                    if obj.RerollSpeedOnWrapAround
                        routes.Speed(vehicleIndex) = obj.sampleSpeed(1);
                    end
                    obj.VehicleRoutes = routes;
                    nextLaneId = geometry.getApproachLaneId( ...
                        routes.EntryArm(vehicleIndex));
                    return
                end
            end

            error( ...
                "v2xsim:scenario:roundabout:UnknownLane", ...
                "Vehicle route state references an unknown lane.");
        end

        function vehicleKinematics = createKinematics( ...
                obj, geometry, laneNetwork, vehicleLaneStates)
            positions = laneNetwork.evaluate( ...
                vehicleLaneStates.LaneId, vehicleLaneStates.Progress);
            routes = obj.VehicleRoutes( ...
                vehicleLaneStates.Properties.RowNames, :);
            tangents = geometry.getLaneTangent( ...
                vehicleLaneStates.LaneId, vehicleLaneStates.Progress);
            speed = routes.Speed;
            vehicleCount = height(vehicleLaneStates);
            vehicleKinematics = table( ...
                positions(:, 1), positions(:, 2), ...
                speed .* tangents(:, 1), speed .* tangents(:, 2), ...
                nan(vehicleCount, 1), nan(vehicleCount, 1), ...
                VariableNames=["X", "Y", "vX", "vY", "aX", "aY"], ...
                RowNames=vehicleLaneStates.Properties.RowNames);
        end

        function validateVehicleSets(obj, rowNames, vehicleLaneStates)
            expected = sort(string(rowNames));
            laneRows = sort(string( ...
                vehicleLaneStates.Properties.RowNames));
            routeRows = sort(string( ...
                obj.VehicleRoutes.Properties.RowNames));
            if isempty(obj.VehicleRoutes) || ...
                    ~isequal(expected, laneRows) || ...
                    ~isequal(expected, routeRows)
                error( ...
                    "v2xsim:scenario:roundabout:VehicleSetMismatch", ...
                    "Kinematics, lane state, and route state must " + ...
                    "identify the same vehicles.");
            end
        end
    end
end

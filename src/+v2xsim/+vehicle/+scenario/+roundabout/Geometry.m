classdef Geometry
    %GEOMETRY Exact single-lane geometry for a four-arm roundabout.
    %   Arms are ordered North, East, South, West. Traffic keeps left and
    %   circulates clockwise. Each arm has a composite approach lane, a
    %   composite exit lane, and two circular circulatory segments. The
    %   approach/exit composites join their offset straights to the circle
    %   with exact radius-matched circular fillets, so all lane-centerline
    %   joins are C1 continuous.

    properties (Constant)
        ArmNames (1, 4) string = ["North", "East", "South", "West"]
    end

    properties (SetAccess = immutable)
        ExitLengths (1, 4) double = 500 .* ones(1, 4)
        RoadWidth (1, 1) double = 4
        InnerCircleDiameter (1, 1) double = 60
    end

    properties (Dependent, SetAccess = private)
        CirculatoryLaneCenterRadius
        OuterPavementRadius
        FilletTangentAxialDistance
        FilletSweepAngleRadians
        MinimumExitLength
        StraightLaneLengths
        ConnectorArcLength
        ApproachLaneLengths
        ExitLaneLengths
        EntryToExitArcLength
        ExitToEntryArcLength
    end

    methods
        function obj = Geometry( ...
                exitLengths, roadWidth, innerCircleDiameter)
            arguments (Input)
                exitLengths double
                roadWidth (1, 1) double
                innerCircleDiameter (1, 1) double
            end

            if ~isreal(exitLengths) || ~isvector(exitLengths) || ...
                    ~ismember(numel(exitLengths), [1, 4]) || ...
                    any(~isfinite(exitLengths), "all") || ...
                    any(exitLengths <= 0, "all")
                error( ...
                    "v2xsim:scenario:roundabout:InvalidExitLengths", ...
                    "ExitLengths must be a positive finite scalar or " + ...
                    "a four-element [North East South West] vector.");
            end
            if ~isreal(roadWidth) || ~isfinite(roadWidth) || roadWidth <= 0
                error( ...
                    "v2xsim:scenario:roundabout:InvalidRoadWidth", ...
                    "RoadWidth must be a positive finite scalar.");
            end
            if ~isreal(innerCircleDiameter) || ...
                    ~isfinite(innerCircleDiameter) || ...
                    innerCircleDiameter <= 0
                error( ...
                    "v2xsim:scenario:roundabout:InvalidInnerCircleDiameter", ...
                    "InnerCircleDiameter must be a positive finite scalar.");
            end
            if innerCircleDiameter < 2 .* roadWidth
                error( ...
                    "v2xsim:scenario:roundabout:InnerCircleTooSmall", ...
                    "InnerCircleDiameter must be at least twice RoadWidth.");
            end

            if isscalar(exitLengths)
                exitLengths = repmat(exitLengths, 1, 4);
            else
                exitLengths = reshape(exitLengths, 1, 4);
            end

            outerRadius = innerCircleDiameter ./ 2 + roadWidth;
            tangentDistance = sqrt( ...
                0.75 .* innerCircleDiameter .^ 2 + ...
                innerCircleDiameter .* roadWidth);
            minimumLength = tangentDistance - outerRadius;
            if any(exitLengths < minimumLength)
                error( ...
                    "v2xsim:scenario:roundabout:ExitLengthTooShort", ...
                    "Each ExitLengths value must be at least %.15g m " + ...
                    "for the selected RoadWidth and " + ...
                    "InnerCircleDiameter.", minimumLength);
            end

            obj.ExitLengths = exitLengths;
            obj.RoadWidth = roadWidth;
            obj.InnerCircleDiameter = innerCircleDiameter;
        end

        function value = get.CirculatoryLaneCenterRadius(obj)
            value = obj.InnerCircleDiameter ./ 2 + obj.RoadWidth ./ 2;
        end

        function value = get.OuterPavementRadius(obj)
            value = obj.InnerCircleDiameter ./ 2 + obj.RoadWidth;
        end

        function value = get.FilletTangentAxialDistance(obj)
            value = sqrt(0.75 .* obj.InnerCircleDiameter .^ 2 + ...
                obj.InnerCircleDiameter .* obj.RoadWidth);
        end

        function value = get.FilletSweepAngleRadians(obj)
            value = atan2( ...
                obj.FilletTangentAxialDistance, ...
                obj.OuterPavementRadius);
        end

        function value = get.MinimumExitLength(obj)
            value = obj.FilletTangentAxialDistance - ...
                obj.OuterPavementRadius;
        end

        function value = get.StraightLaneLengths(obj)
            value = max(0, ...
                obj.OuterPavementRadius + obj.ExitLengths - ...
                obj.FilletTangentAxialDistance);
        end

        function value = get.ConnectorArcLength(obj)
            value = obj.CirculatoryLaneCenterRadius .* ...
                obj.FilletSweepAngleRadians;
        end

        function value = get.ApproachLaneLengths(obj)
            value = obj.StraightLaneLengths + obj.ConnectorArcLength;
        end

        function value = get.ExitLaneLengths(obj)
            value = obj.ApproachLaneLengths;
        end

        function value = get.EntryToExitArcLength(obj)
            sweep = 2 .* obj.FilletSweepAngleRadians - pi ./ 2;
            value = obj.CirculatoryLaneCenterRadius .* sweep;
        end

        function value = get.ExitToEntryArcLength(obj)
            sweep = pi - 2 .* obj.FilletSweepAngleRadians;
            value = obj.CirculatoryLaneCenterRadius .* sweep;
        end

        function laneNetwork = createLaneNetwork(obj)
            %CREATELANENETWORK Build the named parametric lane graph.
            import v2xsim.vehicle.scenario.highway.LaneConnectionKind

            laneIds = strings(1, 16);
            lanes = cell(1, 16);
            nextLane = 1;
            for arm = obj.ArmNames
                laneIds(nextLane) = obj.getApproachLaneId(arm);
                lanes{nextLane} = ...
                    v2xsim.vehicle.scenario.highway.ParametricLane( ...
                        obj.RoadWidth, ...
                        @(progress) obj.evaluateApproachLane( ...
                            arm, progress));
                nextLane = nextLane + 1;

                laneIds(nextLane) = obj.getExitLaneId(arm);
                lanes{nextLane} = ...
                    v2xsim.vehicle.scenario.highway.ParametricLane( ...
                        obj.RoadWidth, ...
                        @(progress) obj.evaluateExitLane(arm, progress));
                nextLane = nextLane + 1;

                laneIds(nextLane) = ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                lanes{nextLane} = ...
                    v2xsim.vehicle.scenario.highway.ParametricLane( ...
                        obj.RoadWidth, ...
                        @(progress) obj.evaluateEntryToExitArc( ...
                            arm, progress));
                nextLane = nextLane + 1;

                laneIds(nextLane) = ...
                    obj.getCirculatingLaneIdAfterExit(arm);
                lanes{nextLane} = ...
                    v2xsim.vehicle.scenario.highway.ParametricLane( ...
                        obj.RoadWidth, ...
                        @(progress) obj.evaluateExitToEntryArc( ...
                            arm, progress));
                nextLane = nextLane + 1;
            end

            connectionCount = 16;
            fromLaneId = strings(connectionCount, 1);
            toLaneId = strings(connectionCount, 1);
            kind = repmat( ...
                LaneConnectionKind.Continuation, connectionCount, 1);
            fromProgress = ones(connectionCount, 1);
            toProgress = zeros(connectionCount, 1);
            nextConnection = 1;
            for arm = obj.ArmNames
                nextArm = obj.getClockwiseArm(arm);

                fromLaneId(nextConnection) = ...
                    obj.getApproachLaneId(arm);
                toLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                kind(nextConnection) = LaneConnectionKind.Merge;
                nextConnection = nextConnection + 1;

                fromLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                toLaneId(nextConnection) = obj.getExitLaneId(nextArm);
                kind(nextConnection) = LaneConnectionKind.Diverge;
                nextConnection = nextConnection + 1;

                fromLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                toLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterExit(nextArm);
                nextConnection = nextConnection + 1;

                fromLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterExit(arm);
                toLaneId(nextConnection) = ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                nextConnection = nextConnection + 1;
            end

            connections = table( ...
                fromLaneId, toLaneId, kind, ...
                fromProgress, toProgress, ...
                VariableNames=[ ...
                    "FromLaneId", "ToLaneId", "Kind", ...
                    "FromProgress", "ToProgress"]);
            laneNetwork = ...
                v2xsim.vehicle.scenario.highway.LaneNetwork( ...
                    laneIds, lanes, connections);
        end

        function laneIds = getApproachLaneId(obj, arms)
            arms = obj.validateArms(arms);
            laneIds = lower(arms) + "-approach";
        end

        function laneIds = getExitLaneId(obj, arms)
            arms = obj.validateArms(arms);
            laneIds = lower(arms) + "-exit";
        end

        function laneIds = getCirculatingLaneIdAfterEntry(obj, arms)
            arms = obj.validateArms(arms);
            laneIds = lower(arms) + "-circulation-after-entry";
        end

        function laneIds = getCirculatingLaneIdAfterExit(obj, arms)
            arms = obj.validateArms(arms);
            laneIds = lower(arms) + "-circulation-after-exit";
        end

        function nextArms = getClockwiseArm(obj, arms)
            arms = obj.validateArms(arms);
            armIndices = obj.getArmIndices(arms);
            nextArms = obj.ArmNames(mod(armIndices, 4) + 1);
            nextArms = reshape(nextArms, size(arms));
        end

        function lengths = getLaneLength(obj, laneIds)
            arguments (Input)
                obj (1, 1)
                laneIds string
            end

            lengths = nan(size(laneIds));
            for armIndex = 1:4
                arm = obj.ArmNames(armIndex);
                armLength = obj.ApproachLaneLengths(armIndex);
                lengths(laneIds == obj.getApproachLaneId(arm) | ...
                    laneIds == obj.getExitLaneId(arm)) = armLength;
                lengths(laneIds == ...
                    obj.getCirculatingLaneIdAfterEntry(arm)) = ...
                    obj.EntryToExitArcLength;
                lengths(laneIds == ...
                    obj.getCirculatingLaneIdAfterExit(arm)) = ...
                    obj.ExitToEntryArcLength;
            end
            if any(isnan(lengths), "all")
                error( ...
                    "v2xsim:scenario:roundabout:UnknownLane", ...
                    "Every LaneId must identify a roundabout lane.");
            end
        end

        function tangents = getLaneTangent(obj, laneIds, progress)
            arguments (Input)
                obj (1, 1)
                laneIds string
                progress double {mustBeReal, mustBeFinite}
            end

            if numel(laneIds) ~= numel(progress) || ...
                    any(progress < 0 | progress > 1, "all")
                error( ...
                    "v2xsim:scenario:roundabout:InvalidLaneCoordinates", ...
                    "LaneId and Progress must have equal sizes and " + ...
                    "Progress must lie in [0,1].");
            end
            laneIds = laneIds(:);
            progress = progress(:);
            tangents = nan(numel(progress), 2);
            for arm = obj.ArmNames
                mask = laneIds == obj.getApproachLaneId(arm);
                tangents(mask, :) = obj.evaluateApproachTangent( ...
                    arm, progress(mask));
                mask = laneIds == obj.getExitLaneId(arm);
                tangents(mask, :) = obj.evaluateExitTangent( ...
                    arm, progress(mask));
                mask = laneIds == ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                tangents(mask, :) = obj.evaluateEntryToExitTangent( ...
                    arm, progress(mask));
                mask = laneIds == ...
                    obj.getCirculatingLaneIdAfterExit(arm);
                tangents(mask, :) = obj.evaluateExitToEntryTangent( ...
                    arm, progress(mask));
            end
            if any(isnan(tangents), "all")
                error( ...
                    "v2xsim:scenario:roundabout:UnknownLane", ...
                    "Every LaneId must identify a roundabout lane.");
            end
        end

        function stages = getRouteStage(obj, laneIds, progress)
            arguments (Input)
                obj (1, 1)
                laneIds string
                progress double {mustBeReal, mustBeFinite}
            end

            if numel(laneIds) ~= numel(progress) || ...
                    any(progress < 0 | progress > 1, "all")
                error( ...
                    "v2xsim:scenario:roundabout:InvalidLaneCoordinates", ...
                    "LaneId and Progress must have equal sizes and " + ...
                    "Progress must lie in [0,1].");
            end
            originalSize = size(progress);
            laneIds = laneIds(:);
            progress = progress(:);
            stages = strings(numel(progress), 1);
            for armIndex = 1:4
                arm = obj.ArmNames(armIndex);
                approach = laneIds == obj.getApproachLaneId(arm);
                approachDistance = progress(approach) .* ...
                    obj.ApproachLaneLengths(armIndex);
                approachStages = repmat( ...
                    "EntryConnector", nnz(approach), 1);
                approachStages(approachDistance < ...
                    obj.StraightLaneLengths(armIndex)) = "Inbound";
                stages(approach) = approachStages;

                onExit = laneIds == obj.getExitLaneId(arm);
                exitDistance = progress(onExit) .* ...
                    obj.ExitLaneLengths(armIndex);
                exitStages = repmat("Outbound", nnz(onExit), 1);
                exitStages(exitDistance < obj.ConnectorArcLength) = ...
                    "ExitConnector";
                stages(onExit) = exitStages;

                circulating = laneIds == ...
                    obj.getCirculatingLaneIdAfterEntry(arm) | ...
                    laneIds == ...
                    obj.getCirculatingLaneIdAfterExit(arm);
                stages(circulating) = "Circulating";
            end
            if any(strlength(stages) == 0)
                error( ...
                    "v2xsim:scenario:roundabout:UnknownLane", ...
                    "Every LaneId must identify a roundabout lane.");
            end
            stages = reshape(stages, originalSize);
        end

        function [isApplicable, targetLaneIds, targetProgress] = ...
                getFalseExitLaneCoordinates( ...
                    obj, vehicleLaneStates, vehicleRouteStates)
            %GETFALSEEXITLANECOORDINATES Project skipped exits without RNG.
            arguments (Input)
                obj (1, 1)
                vehicleLaneStates table ...
                    {v2xsim.vehicle.scenario.validation.mustBeVehicleLaneStateTable}
                vehicleRouteStates table
            end

            obj.validateRouteStates( ...
                vehicleRouteStates, vehicleLaneStates.Properties.RowNames);
            vehicleRouteStates = vehicleRouteStates( ...
                vehicleLaneStates.Properties.RowNames, :);
            vehicleCount = height(vehicleLaneStates);
            isApplicable = false(vehicleCount, 1);
            targetLaneIds = vehicleLaneStates.LaneId;
            targetProgress = vehicleLaneStates.Progress;
            if vehicleCount == 0
                return
            end

            entryIndices = obj.getArmIndices( ...
                vehicleRouteStates.EntryArm);
            exitIndices = obj.getArmIndices( ...
                vehicleRouteStates.ExitArm);
            exitStep = mod(exitIndices - entryIndices - 1, 4) + 1;
            onCircle = vehicleRouteStates.Stage == "Circulating";

            for armIndex = 1:4
                arm = obj.ArmNames(armIndex);
                afterExit = vehicleLaneStates.LaneId == ...
                    obj.getCirculatingLaneIdAfterExit(arm);
                afterEntry = vehicleLaneStates.LaneId == ...
                    obj.getCirculatingLaneIdAfterEntry(arm);
                candidates = onCircle & (afterExit | afterEntry);
                if ~any(candidates)
                    continue
                end

                armStep = mod(armIndex - entryIndices - 1, 4) + 1;
                skipped = armStep < exitStep;
                distance = zeros(vehicleCount, 1);
                distance(afterExit) = ...
                    vehicleLaneStates.Progress(afterExit) .* ...
                    obj.ExitToEntryArcLength;
                distance(afterEntry) = obj.ExitToEntryArcLength + ...
                    vehicleLaneStates.Progress(afterEntry) .* ...
                    obj.EntryToExitArcLength;

                falseLaneLength = obj.ExitLaneLengths(armIndex);
                windowLength = obj.ExitToEntryArcLength + ...
                    obj.EntryToExitArcLength;
                limit = min(falseLaneLength, windowLength);
                tolerance = 64 .* eps(max([1, falseLaneLength, limit]));
                applicable = candidates & skipped & ...
                    distance + tolerance < limit;
                isApplicable(applicable) = true;
                targetLaneIds(applicable) = obj.getExitLaneId(arm);
                targetProgress(applicable) = ...
                    distance(applicable) ./ falseLaneLength;
            end
        end
    end

    methods (Access = private)
        function arms = validateArms(obj, arms)
            arms = string(arms);
            if any(ismissing(arms) | ~ismember(arms, obj.ArmNames), "all")
                error( ...
                    "v2xsim:scenario:roundabout:InvalidArm", ...
                    "Arm values must be North, East, South, or West.");
            end
        end

        function indices = getArmIndices(obj, arms)
            arms = obj.validateArms(arms);
            [~, indices] = ismember(arms, obj.ArmNames);
        end

        function validateRouteStates(obj, routeStates, expectedRowNames)
            expectedVariables = ["EntryArm", "ExitArm", "Stage"];
            validVariables = isequal( ...
                string(routeStates.Properties.VariableNames), ...
                expectedVariables);
            validColumns = validVariables && ...
                isstring(routeStates.EntryArm) && ...
                isstring(routeStates.ExitArm) && ...
                isstring(routeStates.Stage) && ...
                size(routeStates.EntryArm, 2) == 1 && ...
                size(routeStates.ExitArm, 2) == 1 && ...
                size(routeStates.Stage, 2) == 1;
            actualRows = string(routeStates.Properties.RowNames);
            expectedRows = string(expectedRowNames);
            validRows = isequal(sort(actualRows), sort(expectedRows));
            if ~validColumns || ~validRows || ...
                    any(~ismember(routeStates.EntryArm, obj.ArmNames)) || ...
                    any(~ismember(routeStates.ExitArm, obj.ArmNames)) || ...
                    any(~ismember(routeStates.Stage, [ ...
                        "Inbound", "EntryConnector", "Circulating", ...
                        "ExitConnector", "Outbound"]))
                error( ...
                    "v2xsim:scenario:roundabout:InvalidRouteStates", ...
                    "Route states must have matching named rows and " + ...
                    "exactly EntryArm, ExitArm, and Stage string columns.");
            end
        end

        function [outward, clockwise] = getArmBasis(obj, arm)
            armIndex = obj.getArmIndices(arm);
            outwardBases = [0, 1; 1, 0; 0, -1; -1, 0];
            clockwiseBases = [1, 0; 0, -1; -1, 0; 0, 1];
            outward = outwardBases(armIndex, :);
            clockwise = clockwiseBases(armIndex, :);
        end

        function angle = getArmAngle(obj, arm)
            armIndex = obj.getArmIndices(arm);
            angle = [pi ./ 2, 0, -pi ./ 2, pi];
            angle = angle(armIndex);
        end

        function positions = evaluateApproachLane(obj, arm, progress)
            [outward, clockwise] = obj.getArmBasis(arm);
            armIndex = obj.getArmIndices(arm);
            straightLength = obj.StraightLaneLengths(armIndex);
            totalLength = obj.ApproachLaneLengths(armIndex);
            distance = progress(:) .* totalLength;
            positions = zeros(numel(progress), 2);

            onStraight = distance <= straightLength;
            axialDistance = obj.OuterPavementRadius + ...
                obj.ExitLengths(armIndex) - distance(onStraight);
            positions(onStraight, :) = ...
                axialDistance(:) * outward + ...
                ones(nnz(onStraight), 1) * ...
                ((obj.RoadWidth ./ 2) .* clockwise);

            onConnector = ~onStraight;
            theta = (distance(onConnector) - straightLength) ./ ...
                obj.CirculatoryLaneCenterRadius;
            clockwiseCoordinate = obj.OuterPavementRadius - ...
                obj.CirculatoryLaneCenterRadius .* cos(theta);
            outwardCoordinate = obj.FilletTangentAxialDistance - ...
                obj.CirculatoryLaneCenterRadius .* sin(theta);
            positions(onConnector, :) = ...
                clockwiseCoordinate(:) * clockwise + ...
                outwardCoordinate(:) * outward;
        end

        function tangents = evaluateApproachTangent(obj, arm, progress)
            [outward, clockwise] = obj.getArmBasis(arm);
            armIndex = obj.getArmIndices(arm);
            straightLength = obj.StraightLaneLengths(armIndex);
            distance = progress(:) .* obj.ApproachLaneLengths(armIndex);
            tangents = repmat(-outward, numel(progress), 1);
            onConnector = distance > straightLength;
            theta = (distance(onConnector) - straightLength) ./ ...
                obj.CirculatoryLaneCenterRadius;
            tangents(onConnector, :) = ...
                sin(theta(:)) * clockwise - cos(theta(:)) * outward;
        end

        function positions = evaluateExitLane(obj, arm, progress)
            [outward, clockwise] = obj.getArmBasis(arm);
            armIndex = obj.getArmIndices(arm);
            distance = progress(:) .* obj.ExitLaneLengths(armIndex);
            positions = zeros(numel(progress), 2);
            onConnector = distance <= obj.ConnectorArcLength;
            theta = distance(onConnector) ./ ...
                obj.CirculatoryLaneCenterRadius;
            shiftedTheta = theta - obj.FilletSweepAngleRadians;
            clockwiseCoordinate = -obj.OuterPavementRadius + ...
                obj.CirculatoryLaneCenterRadius .* cos(shiftedTheta);
            outwardCoordinate = obj.FilletTangentAxialDistance + ...
                obj.CirculatoryLaneCenterRadius .* sin(shiftedTheta);
            positions(onConnector, :) = ...
                clockwiseCoordinate(:) * clockwise + ...
                outwardCoordinate(:) * outward;

            onStraight = ~onConnector;
            straightDistance = distance(onStraight) - ...
                obj.ConnectorArcLength;
            positions(onStraight, :) = ...
                (obj.FilletTangentAxialDistance + ...
                    straightDistance(:)) * ...
                    outward - ...
                ones(nnz(onStraight), 1) * ...
                ((obj.RoadWidth ./ 2) .* clockwise);
        end

        function tangents = evaluateExitTangent(obj, arm, progress)
            [outward, clockwise] = obj.getArmBasis(arm);
            armIndex = obj.getArmIndices(arm);
            distance = progress(:) .* obj.ExitLaneLengths(armIndex);
            tangents = repmat(outward, numel(progress), 1);
            onConnector = distance < obj.ConnectorArcLength;
            theta = distance(onConnector) ./ ...
                obj.CirculatoryLaneCenterRadius;
            shiftedTheta = theta - obj.FilletSweepAngleRadians;
            tangents(onConnector, :) = ...
                -sin(shiftedTheta(:)) * clockwise + ...
                cos(shiftedTheta(:)) * outward;
        end

        function positions = evaluateEntryToExitArc(obj, arm, progress)
            startAngle = obj.getArmAngle(arm) - pi ./ 2 + ...
                obj.FilletSweepAngleRadians;
            sweep = obj.EntryToExitArcLength ./ ...
                obj.CirculatoryLaneCenterRadius;
            angle = startAngle - sweep .* progress(:);
            positions = obj.CirculatoryLaneCenterRadius .* ...
                [cos(angle), sin(angle)];
        end

        function tangents = evaluateEntryToExitTangent( ...
                obj, arm, progress)
            startAngle = obj.getArmAngle(arm) - pi ./ 2 + ...
                obj.FilletSweepAngleRadians;
            sweep = obj.EntryToExitArcLength ./ ...
                obj.CirculatoryLaneCenterRadius;
            angle = startAngle - sweep .* progress(:);
            tangents = [sin(angle), -cos(angle)];
        end

        function positions = evaluateExitToEntryArc(obj, arm, progress)
            startAngle = obj.getArmAngle(arm) + pi ./ 2 - ...
                obj.FilletSweepAngleRadians;
            sweep = obj.ExitToEntryArcLength ./ ...
                obj.CirculatoryLaneCenterRadius;
            angle = startAngle - sweep .* progress(:);
            positions = obj.CirculatoryLaneCenterRadius .* ...
                [cos(angle), sin(angle)];
        end

        function tangents = evaluateExitToEntryTangent( ...
                obj, arm, progress)
            startAngle = obj.getArmAngle(arm) + pi ./ 2 - ...
                obj.FilletSweepAngleRadians;
            sweep = obj.ExitToEntryArcLength ./ ...
                obj.CirculatoryLaneCenterRadius;
            angle = startAngle - sweep .* progress(:);
            tangents = [sin(angle), -cos(angle)];
        end
    end
end

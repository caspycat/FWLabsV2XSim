classdef PositionDelayError < v2xsim.positioning.PositionErrorModule
    %POSITIONDELAYERROR Return an earlier apparent position snapshot.
    %   The module stores its apparent input history. At time t, it returns
    %   the newest stored snapshot whose timestamp is no later than
    %   t - DelaySeconds. Before that history exists, it holds the earliest
    %   available snapshot. Vehicles without history are reported at their
    %   current apparent position. Diagnostics report which module-input
    %   snapshot supplied each output and its module-local age.

    properties (SetAccess = immutable)
        DelaySeconds (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeNonnegative} = 0
    end

    properties (Access = private)
        HistoryTimesSeconds (:, 1) double = zeros(0, 1)
        HistorySnapshots (1, :) cell = cell(1, 0)
        LastNetworkUpdateOutcomes (:, 1) string = strings(0, 1)
        LastOutputSourceTimesSeconds (:, 1) double = zeros(0, 1)
    end

    methods
        function obj = PositionDelayError(delaySeconds)
            arguments (Input)
                delaySeconds (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeNonnegative}
            end

            obj.DelaySeconds = delaySeconds;
        end
    end

    methods (Access = protected)
        function [obj, outputPositions] = doApply( ...
                obj, inputPositions, context)
            currentTime = context.SimulationTimeSeconds;
            obj = obj.storeSnapshot(currentTime, inputPositions);

            targetTime = currentTime - obj.DelaySeconds;
            % Decimal report intervals need an ULP-scaled comparison: e.g.
            % 0.3 - 0.2 must select the report at 0.1, not the previous tick.
            tolerance = 16 * eps(max(1,currentTime));
            snapshotIndex = find( ...
                obj.HistoryTimesSeconds <= targetTime + tolerance, 1, "last");
            isWarmupHold = isempty(snapshotIndex);
            if isWarmupHold
                snapshotIndex = 1;
            end

            delayedSnapshot = obj.HistorySnapshots{snapshotIndex};
            [outputPositions, hasSelectedHistory] = ...
                obj.copyAvailableVehicleHistory( ...
                inputPositions, delayedSnapshot);
            vehicleCount = height(inputPositions);
            sourceTimeSeconds = ...
                obj.HistoryTimesSeconds(snapshotIndex);
            obj.LastOutputSourceTimesSeconds = repmat( ...
                sourceTimeSeconds, vehicleCount, 1);
            if isWarmupHold
                historyOutcome = "WarmupHeld";
            else
                historyOutcome = "Delayed";
            end
            obj.LastNetworkUpdateOutcomes = repmat( ...
                historyOutcome, vehicleCount, 1);
            obj.LastOutputSourceTimesSeconds(~hasSelectedHistory) = ...
                currentTime;
            obj.LastNetworkUpdateOutcomes(~hasSelectedHistory) = ...
                "CurrentFallback";

            obj.HistoryTimesSeconds = ...
                obj.HistoryTimesSeconds(snapshotIndex:end);
            obj.HistorySnapshots = ...
                obj.HistorySnapshots(snapshotIndex:end);
        end

        function diagnostics = buildDiagnostics( ...
                obj, inputPositions, outputPositions, context)
            diagnostics = v2xsim.positioning.diagnostics.createRows( ...
                inputPositions, outputPositions, ...
                context.SimulationTimeSeconds, string(class(obj)));
            diagnostics.NetworkUpdateOutcome = ...
                obj.LastNetworkUpdateOutcomes;
            diagnostics.OutputSourceTimeSeconds = ...
                obj.LastOutputSourceTimesSeconds;
            diagnostics.OutputAgeSeconds = ...
                context.SimulationTimeSeconds - ...
                obj.LastOutputSourceTimesSeconds;
        end
    end

    methods (Access = private)
        function obj = storeSnapshot(obj, timeSeconds, positions)
            if ~isempty(obj.HistoryTimesSeconds) && ...
                    timeSeconds < obj.HistoryTimesSeconds(end)
                error( ...
                    "v2xsim:positioning:PositionDelayTimeReversed", ...
                    "PositionDelayError requires nondecreasing " + ...
                    "simulation times.");
            end

            if ~isempty(obj.HistoryTimesSeconds) && ...
                    timeSeconds == obj.HistoryTimesSeconds(end)
                obj.HistorySnapshots{end} = positions;
                return
            end

            obj.HistoryTimesSeconds(end + 1, 1) = timeSeconds;
            obj.HistorySnapshots{end + 1} = positions;
        end

        function [outputPositions, hasHistory] = ...
                copyAvailableVehicleHistory( ...
                ~, inputPositions, delayedSnapshot)
            outputPositions = inputPositions;
            currentVehicleIds = reshape(string( ...
                inputPositions.Properties.RowNames), [], 1);
            delayedVehicleIds = reshape(string( ...
                delayedSnapshot.Properties.RowNames), [], 1);
            hasHistory = ismember(currentVehicleIds, delayedVehicleIds);
            vehicleIdsWithHistory = currentVehicleIds(hasHistory);
            outputPositions( ...
                vehicleIdsWithHistory, :) = ...
                delayedSnapshot(vehicleIdsWithHistory, :);
        end
    end
end

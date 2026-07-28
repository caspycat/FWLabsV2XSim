classdef AverageNeighborCountRecorder < v2xsim.hook.Hook
    %AVERAGENEIGHBORCOUNTRECORDER Record average neighbors by range.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            ?v2xsim.hook.dependencies.OutputDirectory
    end

    properties (SetAccess = immutable)
        Technology (1, 1) string
    end

    properties (Access = private)
        OutputDirectory (1, 1) string = ""
        AwarenessRangesMeters (1, :) double = zeros(1, 0)
        TotalNeighborObservations (1, :) double = zeros(1, 0)
        TotalUeObservations (1, 1) double = 0
        HasObservedSnapshot (1, 1) logical = false
        HasWrittenTimeSeries (1, 1) logical = false
    end

    methods
        function obj = AverageNeighborCountRecorder(technology)
            arguments (Input)
                technology (1, 1) string
            end

            obj.Technology = validatestring( ...
                technology, ["all", "cv2x", "itsg5"]);
        end

        function obj = build(obj, outputDirectory)
            arguments (Input)
                obj (1, 1)
                outputDirectory (1, 1) ...
                    v2xsim.hook.dependencies.OutputDirectory
            end

            obj.OutputDirectory = outputDirectory.Path;
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsim.hook.invocations. ...
                    AfterNeighborGraphUpdatedInvocation
            end

            obj = obj.acceptRanges( ...
                invocation.AwarenessRangesMeters);
            [averageNeighborCounts, ueCount] = ...
                obj.snapshotAverages(invocation);
            obj = obj.writeTimeSeries( ...
                invocation.SimulationTimeSeconds, ...
                averageNeighborCounts);

            obj.TotalNeighborObservations = ...
                obj.TotalNeighborObservations + ...
                averageNeighborCounts .* ueCount;
            obj.TotalUeObservations = ...
                obj.TotalUeObservations + ueCount;
        end

        function obj = cleanup(obj)
            if ~obj.HasObservedSnapshot
                return
            end

            if obj.TotalUeObservations == 0
                simulationWideAverages = ...
                    zeros(size(obj.TotalNeighborObservations));
            else
                simulationWideAverages = ...
                    obj.TotalNeighborObservations ./ ...
                    obj.TotalUeObservations;
            end
            outputRows = obj.rangeRows(simulationWideAverages);
            filename = obj.outputFilename("simulation_wide");
            try
                writetable(outputRows, filename);
            catch cause
                error( ...
                    "v2xsim:hook:OutputOpenFailed", ...
                    "Could not write simulation-wide average-neighbor " + ...
                    "output file %s: %s", ...
                    filename, cause.message);
            end
        end
    end

    methods (Access = private)
        function obj = acceptRanges(obj, awarenessRangesMeters)
            if isempty(awarenessRangesMeters)
                error( ...
                    "v2xsim:hook:outputs:InvalidAwarenessRanges", ...
                    "Awareness ranges must be nonempty.");
            end

            if ~obj.HasObservedSnapshot
                obj.AwarenessRangesMeters = awarenessRangesMeters;
                obj.TotalNeighborObservations = ...
                    zeros(size(awarenessRangesMeters));
                obj.HasObservedSnapshot = true;
            elseif ~isequal( ...
                    obj.AwarenessRangesMeters, awarenessRangesMeters)
                error( ...
                    "v2xsim:hook:outputs:AwarenessRangesChanged", ...
                    "Awareness ranges cannot change during a simulation.");
            end
        end

        function [averageNeighborCounts, ueCount] = ...
                snapshotAverages(obj, invocation)
            switch obj.Technology
                case "all"
                    ueCount = numel(invocation.UeIds);
                    averageNeighborCounts = ...
                        obj.allTechnologyAverages( ...
                            invocation.DistanceMatrixMeters, ueCount);
                case "cv2x"
                    ueCount = numel(invocation.Cv2xUeIds);
                    averageNeighborCounts = ...
                        invocation.AverageCv2xNeighbors;
                case "itsg5"
                    ueCount = numel(invocation.ItsG5UeIds);
                    averageNeighborCounts = ...
                        invocation.AverageItsG5Neighbors;
            end

            if ueCount == 0
                averageNeighborCounts = ...
                    zeros(size(obj.AwarenessRangesMeters));
            end
        end

        function averageNeighborCounts = allTechnologyAverages( ...
                obj, distanceMatrixMeters, ueCount)
            averageNeighborCounts = ...
                zeros(size(obj.AwarenessRangesMeters));
            if ueCount == 0
                return
            end

            for rangeIndex = 1:numel(obj.AwarenessRangesMeters)
                upperBound = ...
                    obj.AwarenessRangesMeters(rangeIndex);
                if rangeIndex == 1
                    isInBin = distanceMatrixMeters < upperBound;
                else
                    lowerBound = ...
                        obj.AwarenessRangesMeters(rangeIndex - 1);
                    isInBin = ...
                        distanceMatrixMeters >= lowerBound & ...
                        distanceMatrixMeters < upperBound;
                end
                isInBin(1:ueCount + 1:end) = false;
                averageNeighborCounts(rangeIndex) = ...
                    nnz(isInBin) ./ ueCount;
            end
        end

        function obj = writeTimeSeries( ...
                obj, simulationTimeSeconds, averageNeighborCounts)
            outputRows = obj.rangeRows(averageNeighborCounts);
            outputRows = addvars( ...
                outputRows, ...
                repmat( ...
                    simulationTimeSeconds, height(outputRows), 1), ...
                Before=1, ...
                NewVariableNames="SimulationTimeSeconds");
            filename = obj.outputFilename("over_time");
            try
                if obj.HasWrittenTimeSeries
                    writetable( ...
                        outputRows, filename, ...
                        WriteMode="append", ...
                        WriteVariableNames=false);
                else
                    writetable(outputRows, filename);
                    obj.HasWrittenTimeSeries = true;
                end
            catch cause
                error( ...
                    "v2xsim:hook:OutputOpenFailed", ...
                    "Could not write average-neighbor time-series " + ...
                    "output file %s: %s", ...
                    filename, cause.message);
            end
        end

        function outputRows = rangeRows( ...
                obj, averageNeighborCounts)
            lowerBounds = [0, obj.AwarenessRangesMeters(1:end - 1)];
            outputRows = table( ...
                lowerBounds.', ...
                obj.AwarenessRangesMeters.', ...
                averageNeighborCounts.', ...
                VariableNames=[ ...
                    "AwarenessRangeLowerBoundMeters", ...
                    "AwarenessRangeUpperBoundMeters", ...
                    "AverageNeighborCount"]);
        end

        function filename = outputFilename(obj, outputKind)
            filename = fullfile( ...
                obj.OutputDirectory, ...
                sprintf( ...
                    "average_neighbor_count_%s_%s.csv", ...
                    outputKind,obj.Technology));
        end
    end
end

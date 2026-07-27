classdef PacketReceptionRatioRecorder < v2xsim.hook.Hook
    %PACKETRECEPTIONRATIORECORDER Collect link outcomes by distance.

    properties (Constant, Access = protected)
        DependencyTypes = [ ...
            ?v2xsim.hook.dependencies.OutputDirectory, ...
            ?v2xsim.hook.dependencies.SimulationIdentifier]
    end

    properties (SetAccess = immutable)
        DistanceBinWidthMeters (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, ...
            mustBePositive} = 1
        MaximumDistanceMeters (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBePositive} = 1
        Technology (1, 1) string = ""
        ChannelCount (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, ...
            mustBePositive} = 1
    end

    properties (Access = private)
        OutputDirectory (1, 1) string = ""
        SimulationIdentifier (1, 1) double = NaN
        BinCount (1, 1) double = 1
        Counts (:, :, :, :) double = zeros(0, 0, 0, 3)
    end

    methods
        function obj = PacketReceptionRatioRecorder( ...
                distanceBinWidthMeters, maximumDistanceMeters, ...
                technology, options)
            arguments (Input)
                distanceBinWidthMeters (1, 1) double ...
                    {mustBeReal, mustBeFinite, ...
                    mustBeInteger, mustBePositive}
                maximumDistanceMeters (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBePositive}
                technology (1, 1) string
                options.ChannelCount (1, 1) double ...
                    {mustBeReal, mustBeFinite, ...
                    mustBeInteger, mustBePositive} = 1
            end

            obj.DistanceBinWidthMeters = distanceBinWidthMeters;
            obj.MaximumDistanceMeters = maximumDistanceMeters;
            obj.Technology = validatestring( ...
                technology, ["11p", "LTE", "5G"]);
            obj.ChannelCount = options.ChannelCount;
            obj.BinCount = floor( ...
                maximumDistanceMeters ./ distanceBinWidthMeters);
            if obj.BinCount < 1
                error( ...
                    "v2xsim:hook:outputs:EmptyDistanceHistogram", ...
                    "Maximum distance must include at least one bin.");
            end
            obj.Counts = zeros(0, 0, obj.BinCount, 3);
        end

        function obj = build( ...
                obj, outputDirectory, simulationIdentifier)
            arguments (Input)
                obj (1, 1)
                outputDirectory (1, 1) ...
                    v2xsim.hook.dependencies.OutputDirectory
                simulationIdentifier (1, 1) ...
                    v2xsim.hook.dependencies.SimulationIdentifier
            end

            obj.OutputDirectory = outputDirectory.Path;
            obj.SimulationIdentifier = simulationIdentifier.Value;
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsim.hook.invocations. ...
                    AfterPacketFatesDeterminedInvocation
            end

            if invocation.Technology ~= obj.Technology || ...
                    isempty(invocation.Links)
                return
            end
            obj.mustAcceptChannels(invocation.Transmitters.Channel);
            obj.Counts = obj.expandCounts( ...
                max(invocation.Transmitters.Channel), ...
                max(invocation.Transmitters.PacketType));
            [~, transmitterRows] = ismember( ...
                invocation.Links.TransmitterId, ...
                invocation.Transmitters.TransmitterId);
            channels = ...
                invocation.Transmitters.Channel(transmitterRows);
            packetTypes = ...
                invocation.Transmitters.PacketType(transmitterRows);
            outcomes = string(invocation.Links.Outcome);

            for linkIndex = 1:height(invocation.Links)
                outcomeIndex = obj.outcomeIndex(outcomes(linkIndex));
                if outcomeIndex == 0
                    continue
                end
                distanceBin = floor( ...
                    invocation.Links.DistanceMeters(linkIndex) ./ ...
                    obj.DistanceBinWidthMeters) + 1;
                if distanceBin > obj.BinCount
                    continue
                end
                obj.Counts( ...
                    channels(linkIndex), packetTypes(linkIndex), ...
                    distanceBin, outcomeIndex) = ...
                    obj.Counts( ...
                        channels(linkIndex), packetTypes(linkIndex), ...
                        distanceBin, outcomeIndex) + 1;
            end
        end

        function obj = cleanup(obj)
            for channel = 1:size(obj.Counts, 1)
                for packetType = 1:size(obj.Counts, 2)
                    counts = reshape( ...
                        obj.Counts(channel, packetType, :, :), ...
                        obj.BinCount, 3);
                    if sum(counts, "all") == 0
                        continue
                    end
                    filename = obj.outputFilename( ...
                        channel, packetType);
                    obj.writeCounts(filename, counts);
                end
            end
        end
    end

    methods (Access = private)
        function counts = expandCounts( ...
                obj, channelCount, packetTypeCount)
            counts = obj.Counts;
            if size(counts, 1) >= channelCount && ...
                    size(counts, 2) >= packetTypeCount
                return
            end
            expanded = zeros( ...
                max(size(counts, 1), channelCount), ...
                max(size(counts, 2), packetTypeCount), ...
                obj.BinCount, 3);
            if ~isempty(counts)
                expanded( ...
                    1:size(counts, 1), ...
                    1:size(counts, 2), :, :) = counts;
            end
            counts = expanded;
        end

        function outcomeIndex = outcomeIndex(~, outcome)
            if outcome == "correct"
                outcomeIndex = 1;
            elseif outcome == "error"
                outcomeIndex = 2;
            elseif outcome == "blocked"
                outcomeIndex = 3;
            else
                outcomeIndex = 0;
            end
        end

        function filename = outputFilename(obj, channel, packetType)
            packetSuffix = obj.packetTypeSuffix(packetType);
            if obj.ChannelCount == 1
                channelSuffix = "";
            else
                channelSuffix = sprintf("_C%d", channel);
            end
            filename = fullfile( ...
                obj.OutputDirectory, ...
                sprintf( ...
                    "packet_reception_ratio_%d_%s%s%s.csv", ...
                    obj.SimulationIdentifier, obj.Technology, ...
                    packetSuffix, channelSuffix));
        end

        function suffix = packetTypeSuffix(~, packetType)
            if packetType == 1
                suffix = "";
            elseif packetType == 2
                suffix = "_DENM";
            else
                error( ...
                    "v2xsim:hook:outputs:UnsupportedPacketType", ...
                    "Packet type %d is not supported.", packetType);
            end
        end

        function writeCounts(obj, filename, counts)
            fileIdentifier = fopen(filename, "a");
            if fileIdentifier == -1
                error( ...
                    "v2xsim:hook:OutputOpenFailed", ...
                    "Could not open packet-reception output file %s.", ...
                    filename);
            end
            closeFile = onCleanup(@() fclose(fileIdentifier));
            totalCounts = sum(counts, 2);
            distances = ...
                (1:obj.BinCount).' .* obj.DistanceBinWidthMeters;
            ratios = counts(:, 1) ./ totalCounts;
            fprintf( ...
                fileIdentifier, "%d,%d,%d,%d,%d,%f\n", ...
                [distances, counts, totalCounts, ratios].');
        end

        function mustAcceptChannels(obj, channels)
            if any(channels > obj.ChannelCount)
                error( ...
                    "v2xsim:hook:outputs:ChannelOutOfRange", ...
                    "Invocation channel exceeds configured channel count.");
            end
        end
    end
end

classdef ControllerDiagnosticsRecorder < v2xsim.hook.Hook
    %CONTROLLERDIAGNOSTICSRECORDER Record topology and allocation deltas.
    %   Rows are buffered only up to FlushRowCount and written as
    %   append-only CSV. Scientific transformations live in the pure
    %   v2xsim.resource.metrics package. Pair output is sparse, while
    %   all-pair counts remain in the allocation summary.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            ?v2xsim.hook.dependencies.OutputDirectory
    end

    properties (SetAccess = immutable)
        NeighborRangesMeters (1,:) double
        TopK (1,1) double {mustBeInteger,mustBePositive} = 10
        FlushRowCount (1,1) double ...
            {mustBeInteger,mustBePositive} = 5000
        FilenamePrefix (1,1) string = "controller"
        RankDisplacementEnabled (1,1) logical = false
        FrequencyInterferenceCoupling (:,:) double = zeros(0,0)
    end

    properties (Access = private)
        OutputDirectory (1,1) string = ""
        Buffers (1,1) struct = struct()
        WrittenKinds (1,:) string = strings(1,0)
    end

    methods
        function obj = ControllerDiagnosticsRecorder( ...
                neighborRangesMeters,options)
            arguments (Input)
                neighborRangesMeters (1,:) double ...
                    {mustBeReal,mustBeFinite,mustBePositive}
                options.TopK (1,1) double ...
                    {mustBeInteger,mustBePositive} = 10
                options.FlushRowCount (1,1) double ...
                    {mustBeInteger,mustBePositive} = 5000
                options.FilenamePrefix (1,1) string = "controller"
                options.RankDisplacementEnabled (1,1) logical = false
                options.FrequencyInterferenceCoupling (:,:) double ...
                    {mustBeReal,mustBeFinite,mustBeNonnegative} = ...
                        zeros(0,0)
            end

            if isempty(neighborRangesMeters)
                error( ...
                    "v2xsim:hook:outputs:EmptyControllerRanges", ...
                    "Controller diagnostics require at least one " + ...
                    "neighbor range.");
            end
            if ~isempty(options.FrequencyInterferenceCoupling) && ...
                    ~ismatrix(options.FrequencyInterferenceCoupling) || ...
                    size(options.FrequencyInterferenceCoupling,1) ~= ...
                    size(options.FrequencyInterferenceCoupling,2)
                error( ...
                    "v2xsim:hook:outputs:" + ...
                    "InvalidFrequencyInterferenceCoupling", ...
                    "FrequencyInterferenceCoupling must be an empty " + ...
                    "or square nonnegative matrix.");
            end
            prefix = strip(options.FilenamePrefix);
            if ismissing(prefix) || strlength(prefix) == 0 || ...
                    any(contains(prefix,["/","\\"]))
                error( ...
                    "v2xsim:hook:outputs:InvalidFilenamePrefix", ...
                    "FilenamePrefix must be a nonblank file-name stem.");
            end

            obj.NeighborRangesMeters = ...
                unique(neighborRangesMeters,"sorted");
            obj.TopK = options.TopK;
            obj.FlushRowCount = options.FlushRowCount;
            obj.FilenamePrefix = prefix;
            obj.RankDisplacementEnabled = ...
                options.RankDisplacementEnabled;
            obj.FrequencyInterferenceCoupling = ...
                options.FrequencyInterferenceCoupling;
        end

        function obj = build(obj,outputDirectory)
            arguments (Input)
                obj (1,1)
                outputDirectory (1,1) ...
                    v2xsim.hook.dependencies.OutputDirectory
            end

            obj.OutputDirectory = outputDirectory.Path;
        end

        function [obj,invocation] = invoke(obj,invocation)
            arguments (Input)
                obj (1,1)
                invocation (1,1) ...
                    v2xsim.hook.invocations. ...
                    AfterResourceAllocationDecisionInvocation
            end

            if ~isa( ...
                    invocation.Context, ...
                    "v2xsim.resource.CentralizedAllocationContext") || ...
                    ~isfield(invocation.Result.Diagnostics,"Kind") || ...
                    string(invocation.Result.Diagnostics.Kind) ~= ...
                    "MaximumReuseDistance"
                return
            end
            newRows = ...
                v2xsim.resource.metrics. ...
                    buildControllerDiagnosticRows( ...
                        invocation.SimulationTimeSeconds, ...
                        invocation.AllocationEpoch, ...
                        invocation.Context,invocation.Result, ...
                        obj.NeighborRangesMeters,obj.TopK, ...
                        RankDisplacementEnabled= ...
                            obj.RankDisplacementEnabled, ...
                        FrequencyInterferenceCoupling= ...
                            obj.FrequencyInterferenceCoupling);
            obj = obj.append(newRows);
            if obj.bufferedRowCount() >= obj.FlushRowCount
                obj = obj.flush();
            end
        end

        function obj = cleanup(obj)
            obj = obj.flush();
        end
    end

    methods (Access = private)
        function obj = append(obj,newRows)
            kinds = string(fieldnames(newRows)).';
            for kind = kinds
                field = char(kind);
                if ~isfield(obj.Buffers,field)
                    obj.Buffers.(field) = newRows.(field);
                else
                    obj.Buffers.(field) = [ ...
                        obj.Buffers.(field);newRows.(field)];
                end
            end
        end

        function count = bufferedRowCount(obj)
            count = 0;
            kinds = fieldnames(obj.Buffers);
            for index = 1:numel(kinds)
                count = count + height(obj.Buffers.(kinds{index}));
            end
        end

        function obj = flush(obj)
            kinds = string(fieldnames(obj.Buffers)).';
            for kind = kinds
                field = char(kind);
                rows = obj.Buffers.(field);
                if isempty(rows)
                    if kind == "ReuseCandidate" && ...
                            ~ismember(kind,obj.WrittenKinds)
                        obj = obj.writeRows(kind,rows);
                    end
                    continue
                end
                obj = obj.writeRows(kind,rows);
                obj.Buffers.(field) = rows([],:);
            end
        end

        function obj = writeRows(obj,kind,rows)
            filename = obj.outputFilename(kind);
            try
                if ismember(kind,obj.WrittenKinds)
                    writetable( ...
                        rows,filename,WriteMode="append", ...
                        WriteVariableNames=false);
                else
                    writetable(rows,filename);
                    obj.WrittenKinds(end + 1) = kind;
                end
            catch cause
                error( ...
                    "v2xsim:hook:OutputOpenFailed", ...
                    "Could not write controller diagnostics file " + ...
                    "%s: %s",filename,cause.message);
            end
        end

        function filename = outputFilename(obj,kind)
            suffix = obj.filenameSuffix(kind);
            filename = fullfile( ...
                obj.OutputDirectory, ...
                obj.FilenamePrefix + "_" + suffix + ".csv");
        end
    end

    methods (Static, Access = private)
        function suffix = filenameSuffix(kind)
            switch kind
                case "Topology"
                    suffix = "topology";
                case "RankDisplacement"
                    suffix = "rank_displacement";
                case "RangeTopology"
                    suffix = "range_topology";
                case "AllocationDecision"
                    suffix = "allocation_decision";
                case "AllocationSummary"
                    suffix = "allocation_summary";
                case "CoUser"
                    suffix = "co_user";
                case "ReuseCandidate"
                    suffix = "reuse_candidate";
                otherwise
                    error( ...
                        "v2xsim:hook:outputs:" + ...
                        "UnknownControllerDiagnosticKind", ...
                        "Unknown controller diagnostic table %s.",kind);
            end
        end
    end
end

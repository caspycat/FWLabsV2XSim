classdef PositionErrorTraceRecorder < v2xsim.hook.Hook
    %POSITIONERRORTRACERECORDER Write bounded position-error trace chunks.
    %   Module diagnostic rows are buffered up to FlushEveryRows and then
    %   written to numbered CSV files. Records contains only the currently
    %   buffered, not-yet-written rows.

    properties (Constant, Access = protected)
        DependencyTypes = ...
            ?v2xsim.hook.dependencies.OutputDirectory
    end

    properties (SetAccess = immutable)
        FlushEveryRows (1, 1) double ...
            {mustBeReal, mustBeFinite, mustBeInteger, ...
            mustBePositive} = 10000
    end

    properties (SetAccess = private)
        Records table = ...
            v2xsim.positioning.diagnostics.emptyTable()
    end

    properties (Access = private)
        OutputDirectory (1, 1) string = ""
        NextChunkIndex (1, 1) double = 1
    end

    methods
        function obj = PositionErrorTraceRecorder(options)
            arguments (Input)
                options.FlushEveryRows (1, 1) double ...
                    {mustBeReal, mustBeFinite, mustBeInteger, ...
                    mustBePositive} = 10000
            end

            obj.FlushEveryRows = options.FlushEveryRows;
        end

        function obj = build(obj, outputDirectory)
            arguments (Input)
                obj (1, 1)
                outputDirectory (1, 1) ...
                    v2xsim.hook.dependencies.OutputDirectory
            end

            obj.OutputDirectory = outputDirectory.Path;
            obj.NextChunkIndex = obj.findNextChunkIndex();
        end

        function [obj, invocation] = invoke(obj, invocation)
            arguments (Input)
                obj (1, 1)
                invocation (1, 1) ...
                    v2xsim.hook.invocations. ...
                    AfterPositionErrorChainAppliedInvocation
            end

            rows = obj.rowsForInvocation(invocation);
            obj.Records = [obj.Records; rows];
            while height(obj.Records) >= obj.FlushEveryRows
                chunkRows = obj.Records(1:obj.FlushEveryRows, :);
                obj.Records(1:obj.FlushEveryRows, :) = [];
                obj = obj.writeChunk(chunkRows);
            end
        end

        function obj = cleanup(obj)
            if isempty(obj.Records)
                return
            end

            rows = obj.Records;
            obj.Records = ...
                v2xsim.positioning.diagnostics.emptyTable();
            obj = obj.writeChunk(rows);
        end
    end

    methods (Static)
        function rows = rowsForInvocation(invocation)
            %ROWSFORINVOCATION Return normalized trace rows without I/O.
            arguments (Input)
                invocation (1, 1) ...
                    v2xsim.hook.invocations. ...
                    AfterPositionErrorChainAppliedInvocation
            end

            rows = invocation.ModuleDiagnostics;
            if ~isempty(rows)
                return
            end

            rows = v2xsim.positioning.diagnostics.createRows( ...
                invocation.PositionsBeforeErrorChain, ...
                invocation.PositionsAfterErrorChain, ...
                invocation.SimulationTimeSeconds, ...
                "v2xsim.positioning.PositionErrorChain");
            rows.ModuleIndex(:) = 0;
        end
    end

    methods (Access = private)
        function obj = writeChunk(obj, rows)
            if obj.OutputDirectory == ""
                error( ...
                    "v2xsim:hook:PositionErrorTraceNotBuilt", ...
                    "PositionErrorTraceRecorder must be built before " + ...
                    "it can write output.");
            end

            filename = fullfile( ...
                obj.OutputDirectory, ...
                sprintf( ...
                    "position_error_trace_%06d.csv", ...
                    obj.NextChunkIndex));
            try
                writetable(rows, filename);
            catch cause
                error( ...
                    "v2xsim:hook:OutputOpenFailed", ...
                    "Could not write position-error trace file %s: %s", ...
                    filename, cause.message);
            end
            obj.NextChunkIndex = obj.NextChunkIndex + 1;
        end

        function nextIndex = findNextChunkIndex(obj)
            files = dir(fullfile( ...
                obj.OutputDirectory, ...
                "position_error_trace_*.csv"));
            nextIndex = 1;
            for fileIndex = 1:numel(files)
                token = regexp( ...
                    files(fileIndex).name, ...
                    "position_error_trace_(\d+)\.csv", ...
                    "tokens", "once");
                if ~isempty(token)
                    nextIndex = max( ...
                        nextIndex, str2double(token{1}) + 1);
                end
            end
        end
    end
end

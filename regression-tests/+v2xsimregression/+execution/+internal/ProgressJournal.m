classdef ProgressJournal < handle
    %PROGRESSJOURNAL Client-owned append-only work-item progress journal.
    %   Workers never write the journal directly. Parallel workers send
    %   events through a DataQueue, whose client callback serializes each
    %   event as one independently appended JSON line.

    properties (SetAccess = immutable)
        File (1, 1) string
        WorkItemCount (1, 1) double
    end

    properties (Access = private)
        Sequence (1, 1) double = 0
        WorkItemStates (1, :) string
        LastConsoleUpdate
        FirstParallelCallbackFailure (1, :) cell = cell(1,0)
    end

    methods
        function obj = ProgressJournal(file, workItemCount)
            arguments (Input)
                file (1, 1) string {mustBeNonzeroLengthText}
                workItemCount (1, 1) double { ...
                    mustBeInteger, mustBeNonnegative}
            end

            parentDirectory = string(fileparts(file));
            if parentDirectory == ""
                parentDirectory = string(pwd);
            end
            if ~isfolder(parentDirectory)
                error( ...
                    "v2xsimregression:execution:" + ...
                    "InvalidProgressLogFile", ...
                    "The ProgressLogFile parent directory does not " + ...
                    "exist: %s", parentDirectory);
            end
            if isfile(file) || isfolder(file)
                error( ...
                    "v2xsimregression:execution:" + ...
                    "ProgressLogFileExists", ...
                    "Refusing to overwrite an existing progress log: %s", ...
                    file);
            end

            v2xsimregression.execution.internal.ProgressJournal. ...
                createFileExclusively(file);

            obj.File = file;
            obj.WorkItemCount = workItemCount;
            obj.WorkItemStates = repmat("queued",1,workItemCount);
            obj.LastConsoleUpdate = tic;
            fprintf("Regression progress journal: %s\n",obj.File);
        end

        function record(obj, event)
            arguments (Input)
                obj (1, 1)
                event (1, 1) struct
            end

            obj.Sequence = obj.Sequence + 1;
            receivedAt = datetime( ...
                "now", TimeZone="UTC", ...
                Format="uuuu-MM-dd'T'HH:mm:ss.SSS'Z'");
            journalEvent = struct( ...
                SchemaVersion=1, ...
                Sequence=obj.Sequence, ...
                ReceivedAtUtc=string(receivedAt), ...
                WorkItemIndex=event.WorkItemIndex, ...
                Label=event.Label, ...
                AttemptId=event.AttemptId, ...
                Event=event.Event, ...
                Stage=event.Stage, ...
                SimulatedTimeSeconds=event.SimulatedTimeSeconds, ...
                SimulationDurationSeconds= ...
                    event.SimulationDurationSeconds, ...
                FractionComplete=event.FractionComplete, ...
                ElapsedWallSeconds=event.ElapsedWallSeconds, ...
                Message=event.Message);
            obj.append(journalEvent);
            obj.updateConsole(journalEvent);
        end

        function recordFromParallelQueue(obj, event)
            % DataQueue callback exceptions are converted to warnings by
            % MATLAB. Retain the first failure so the scheduler can throw
            % it synchronously after draining the queue.
            try
                obj.record(event);
            catch cause
                if isempty(obj.FirstParallelCallbackFailure)
                    obj.FirstParallelCallbackFailure = {cause};
                end
            end
        end

        function failure = parallelCallbackFailure(obj)
            if isempty(obj.FirstParallelCallbackFailure)
                failure = [];
            else
                failure = obj.FirstParallelCallbackFailure{1};
            end
        end
    end

    methods (Access = private)
        function append(obj, event)
            [fileId,message] = fopen(obj.File,"a","n","UTF-8");
            if fileId == -1
                error( ...
                    "v2xsimregression:execution:" + ...
                    "ProgressLogFileWriteFailed", ...
                    "Could not append progress log %s: %s", ...
                    obj.File, message);
            end
            fileCleanup = onCleanup(@() closeFileQuietly(fileId));
            try
                encodedEvent = jsonencode(event);
                bytesWritten = fprintf(fileId,"%s\n",encodedEvent);
                [writeMessage,writeErrorNumber] = ferror(fileId);
                closeStatus = fclose(fileId);
            catch cause
                exception = MException( ...
                    "v2xsimregression:execution:" + ...
                    "ProgressLogFileWriteFailed", ...
                    "Could not append progress log %s.",obj.File);
                throw(addCause(exception,cause));
            end
            if bytesWritten <= 0 || writeErrorNumber ~= 0 || ...
                    closeStatus ~= 0
                error( ...
                    "v2xsimregression:execution:" + ...
                    "ProgressLogFileWriteFailed", ...
                    "Could not completely append progress log %s " + ...
                    "(fprintf bytes=%d, ferror=%d: %s, fclose=%d).", ...
                    obj.File, bytesWritten, writeErrorNumber, ...
                    string(writeMessage), closeStatus);
            end
            fileCleanup; %#ok<VUNUS>
        end

        function updateConsole(obj, event)
            workIndex = event.WorkItemIndex;
            if workIndex >= 1 && workIndex <= obj.WorkItemCount
                switch event.Event
                    case "started"
                        obj.WorkItemStates(workIndex) = "running";
                    case "completed"
                        obj.WorkItemStates(workIndex) = "completed";
                    case "failed"
                        obj.WorkItemStates(workIndex) = "failed";
                end
            end

            alwaysPrint = any(event.Event == ...
                ["started","completed","failed"]);
            heartbeatDue = event.Event == "heartbeat" && ...
                toc(obj.LastConsoleUpdate) >= 15;
            if ~alwaysPrint && ~heartbeatDue
                return
            end

            completedCount = nnz(obj.WorkItemStates == "completed");
            failedCount = nnz(obj.WorkItemStates == "failed");
            activeCount = nnz(obj.WorkItemStates == "running");
            terminalCount = completedCount + failedCount;
            detail = event.Label + " | " + event.Event;
            if event.Event == "heartbeat"
                detail = detail + " " + event.Stage;
                if ~isempty(event.FractionComplete)
                    detail = detail + compose( ...
                        " %.0f%%",100 .* event.FractionComplete);
                elseif ~isempty(event.SimulatedTimeSeconds) && ...
                        ~isempty(event.SimulationDurationSeconds)
                    detail = detail + compose( ...
                        " %.3g/%.3g simulated s", ...
                        event.SimulatedTimeSeconds, ...
                        event.SimulationDurationSeconds);
                end
            end
            fprintf( ...
                "[%s] Regression progress: %d/%d terminal " + ...
                "(%d completed, %d failed), %d active | %s\n", ...
                event.ReceivedAtUtc, terminalCount, obj.WorkItemCount, ...
                completedCount, failedCount, activeCount, detail);
            obj.LastConsoleUpdate = tic;
        end
    end

    methods (Static, Access = private)
        function createFileExclusively(file)
            % MATLAB fopen has no exclusive-create mode. Java NIO's
            % createFile maps to CREATE_NEW, which atomically refuses an
            % existing file or directory on every supported host OS.
            try
                emptyPathParts = javaArray( ...
                    'java.lang.String',0);
                pathObject = java.nio.file.Paths.get( ...
                    char(file),emptyPathParts);
                attributes = javaArray( ...
                    'java.nio.file.attribute.FileAttribute',0);
                java.nio.file.Files.createFile(pathObject,attributes);
            catch cause
                if isa( ...
                        cause.ExceptionObject, ...
                        "java.nio.file.FileAlreadyExistsException")
                    error( ...
                        "v2xsimregression:execution:" + ...
                        "ProgressLogFileExists", ...
                        "Refusing to overwrite an existing progress " + ...
                        "log: %s", file);
                end
                exception = MException( ...
                    "v2xsimregression:execution:" + ...
                    "ProgressLogFileCreationFailed", ...
                    "Could not create progress log %s.",file);
                throw(addCause(exception,cause));
            end
        end
    end
end

function closeFileQuietly(fileId)
try
    fclose(fileId);
catch
    % An explicit checked fclose is used on the normal path. This cleanup
    % only prevents a leaked handle when encoding or writing throws.
end
end

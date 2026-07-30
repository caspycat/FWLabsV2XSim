classdef OutputSession < handle
    %OUTPUTSESSION Owns the exclusive output-directory lease for one run.
    %   Handle semantics are required because there must be exactly one
    %   owner of the lease. close and delete release only that lease; they
    %   never remove the run directory or any artifact in it.

    properties (SetAccess = immutable)
        OutputDirectory (1, 1) string
        RunLabel (1, 1) string
    end

    properties (SetAccess = private)
        RunDirectory (1, 1) string = ""
        IsClosed (1, 1) logical = true
    end

    properties (Access = private)
        DirectoryLease = []
    end

    methods
        function obj = OutputSession(options)
            arguments (Input)
                options (1, 1) v2xsim.runtime.RunOptions
            end

            obj.OutputDirectory = options.OutputDirectory;
            obj.RunLabel = options.RunLabel;
            [runDirectory, lease] = ...
                v2xsim.output.acquireRunDirectory( ...
                    options.OutputDirectory);
            obj.RunDirectory = runDirectory;
            obj.DirectoryLease = lease;
            obj.IsClosed = false;
        end

        function close(obj)
            %CLOSE Idempotently release this session's directory lease.
            arguments (Input)
                obj (1, 1)
            end

            if obj.IsClosed
                return
            end
            obj.DirectoryLease = [];
            obj.IsClosed = true;
        end

        function delete(obj)
            %DELETE Release the owned lease during normal destruction.
            obj.close();
        end
    end
end

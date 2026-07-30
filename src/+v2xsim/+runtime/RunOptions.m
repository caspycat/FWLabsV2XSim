classdef RunOptions
    %RUNOPTIONS Validated run-owned execution options.
    %   RunOptions contains process-boundary choices rather than scientific
    %   configuration. Scientific choices such as the master random seed
    %   remain in the resolved simulation plan.

    properties (SetAccess = immutable)
        OutputDirectory (1, 1) string
        RunLabel (1, 1) string
    end

    methods
        function obj = RunOptions(options)
            arguments (Input)
                options.OutputDirectory (1, 1) string
                options.RunLabel (1, 1) string = ""
            end

            if ~isfield(options, "OutputDirectory")
                error( ...
                    "v2xsim:runtime:MissingOutputDirectory", ...
                    "OutputDirectory is required for every run.");
            end
            outputDirectory = strip(options.OutputDirectory);
            if ismissing(outputDirectory) || ...
                    strlength(outputDirectory) == 0
                error( ...
                    "v2xsim:runtime:InvalidOutputDirectory", ...
                    "OutputDirectory must be nonblank.");
            end
            runLabel = strip(options.RunLabel);
            if ismissing(runLabel)
                error( ...
                    "v2xsim:runtime:InvalidRunLabel", ...
                    "RunLabel must not be missing.");
            end

            obj.OutputDirectory = outputDirectory;
            obj.RunLabel = runLabel;
        end
    end
end

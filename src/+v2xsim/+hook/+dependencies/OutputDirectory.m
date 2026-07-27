classdef OutputDirectory < v2xsim.hook.dependency.Dependency
    %OUTPUTDIRECTORY Directory in which a hook may write its output.

    properties (SetAccess = immutable)
        Path (1, 1) string
    end

    methods
        function obj = OutputDirectory(path)
            arguments (Input)
                path {mustBeTextScalar}
            end

            mustBeFolder(path);
            permissions = filePermissions(path);
            obj.Path = permissions.AbsolutePath;
        end
    end
end

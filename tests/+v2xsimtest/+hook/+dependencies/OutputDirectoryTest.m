classdef OutputDirectoryTest < matlab.unittest.TestCase
    %OUTPUTDIRECTORYTEST Tests stable output-directory paths.

    methods (Test)
        function testStoresAbsolutePath(testCase)
            permissions = filePermissions(".");

            outputDirectory = ...
                v2xsim.hook.dependencies.OutputDirectory(".");

            testCase.verifyEqual( ...
                outputDirectory.Path, ...
                permissions.AbsolutePath);
        end
    end
end

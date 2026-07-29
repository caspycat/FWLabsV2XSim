classdef RunSimulationPathTest < matlab.unittest.TestCase
    %RUNSIMULATIONPATHTEST The public entrypoint preserves MATLAB's path.

    methods (Test)
        function testNamespacedEntrypointIsTheOnlyActiveEntrypoint(testCase)
            projectRoot = string(fileparts(fileparts(fileparts( ...
                fileparts(mfilename("fullpath"))))));
            expectedEntrypoint = fullfile( ...
                projectRoot, "src", "+v2xsim", "runSimulation.m");

            testCase.verifyEqual( ...
                string(which("v2xsim.runSimulation")), ...
                expectedEntrypoint);
            testCase.verifyEmpty(which("WiLabV2Xsim"));
        end

        function testHelpDoesNotChangeMatlabPath(testCase)
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));

            evalc("v2xsim.runSimulation(""help"");");

            testCase.verifyEqual(path, originalPath);
        end
    end
end

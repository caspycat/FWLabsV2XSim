classdef RunSimulationPathTest < matlab.unittest.TestCase
    %RUNSIMULATIONPATHTEST The public entrypoint preserves MATLAB's path.

    methods (Test)
        function testNamespacedEntrypointIsTheOnlyActiveEntrypoint(testCase)
            projectRoot = string(fileparts(fileparts(fileparts( ...
                fileparts(mfilename("fullpath"))))));
            project = currentProject;
            expectedEntrypoint = fullfile( ...
                projectRoot, "src", "+v2xsim", "runSimulation.m");

            testCase.verifyNotEmpty(project);
            testCase.verifyEqual(string(project.Name), "FWLabsV2XSim");
            testCase.verifyEqual( ...
                string(which("v2xsim.runSimulation")), ...
                expectedEntrypoint);
            testCase.verifyEmpty(which("WiLabV2Xsim"));
            testCase.verifyEmpty(which("FWLabsV2XSim"));
            testCase.verifyTrue(isfile(fullfile( ...
                projectRoot, "FWLabsV2XSim.prj")));
            testCase.verifyFalse(isfile(fullfile( ...
                projectRoot, "WiLabV2XSim.prj")));
        end

        function testHelpDoesNotChangeMatlabPath(testCase)
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));

            output = evalc("v2xsim.runSimulation(""help"");");

            testCase.verifyEqual(path, originalPath);
            testCase.verifySubstring(output, "FWLabsV2XSim V7");
            testCase.verifyFalse(contains(output, "WiLabV2X"));
        end
    end
end

classdef RunSimulationBoundaryTest < matlab.unittest.TestCase
    %RUNSIMULATIONBOUNDARYTEST Tests the configuration-object-only API.

    methods (Test)
        function rejectsLegacyCfgStringBeforeCreatingOutput(testCase)
            temporaryFolder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            cfgFile = fullfile(temporaryFolder.Folder, "legacy.cfg");
            writelines("simulation.duration = 1", cfgFile);
            outputDirectory = fullfile( ...
                temporaryFolder.Folder, "must-not-exist");

            testCase.verifyError( ...
                @() v2xsim.runSimulation( ...
                    string(cfgFile), ...
                    OutputDirectory=string(outputDirectory)), ...
                "v2xsim:runtime:ResolvedConfigurationRequired");
            testCase.verifyFalse(isfolder(outputDirectory));
        end
    end
end

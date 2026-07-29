classdef RunFailureCleanupTest < matlab.unittest.TestCase
    %RUNFAILURECLEANUPTEST Failed runs never look complete or retain locks.

    properties (SetAccess = private)
        TemporaryDirectory (1,1) string
        ConfigurationFile (1,1) string
    end

    methods (TestClassSetup)
        function configurePathsAndOutput(testCase)
            originalPath = path;
            originalWarnings = warning;
            originalStream = RandStream.getGlobalStream();
            originalStreamState = originalStream.State;
            testCase.addTeardown(@() path(originalPath));
            testCase.addTeardown(@() warning(originalWarnings));
            testCase.addTeardown(@() restoreGlobalRandomStream( ...
                originalStream,originalStreamState));

            projectRoot = string(fileparts(fileparts(fileparts( ...
                fileparts(mfilename("fullpath"))))));
            addpath(fullfile(projectRoot,"src"));
            addpath(fullfile(projectRoot,"old_src"));
            testCase.ConfigurationFile = fullfile( ...
                projectRoot,"old_src","ConfigFiles", ...
                "EtsiHighwayMediumMode1.cfg");
            temporaryFolder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryDirectory = ...
                string(temporaryFolder.Folder);
        end
    end

    methods (Test)
        function testRuntimeFailureReleasesLeaseWithoutSummary(testCase)
            outputDirectory = fullfile( ...
                testCase.TemporaryDirectory,"failed-run");
            simulationArguments = { ...
                testCase.ConfigurationFile, ...
                "simulation.RandomSeed",1, ...
                "simulation.DurationSeconds",0.1, ...
                "simulation.RadioAccessMode","LTE-V2X", ...
                "scenario.Type","BrownianMotionScenario", ...
                "scenarioOptions.VehicleCount",0, ...
                "output.Directory",outputDirectory}; %#ok<NASGU>

            thrownException = [];
            pathBeforeSimulation = path;
            try
                evalc("v2xsim.runSimulation(simulationArguments{:});");
            catch exception
                thrownException = exception;
            end
            testCase.verifyEqual(path, pathBeforeSimulation);

            testCase.verifyNotEmpty( ...
                thrownException, ...
                "The deliberately invalid runtime scenario must fail.");
            testCase.assertTrue(isfolder(outputDirectory));
            testCase.verifyFalse(isfile(fullfile( ...
                outputDirectory,"simulation_summary.json")));
            testCase.verifyFalse(isfolder(fullfile( ...
                outputDirectory,".v2xsim-output-lock")));
            entries = dir(outputDirectory);
            entryNames = string({entries.name});
            testCase.verifyTrue(all(ismember( ...
                entryNames,[".",".."])));

            [~,lease] = ...
                v2xsim.output.acquireRunDirectory(outputDirectory);
            testCase.verifyClass(lease,"onCleanup");
            testCase.verifyTrue(isfolder(fullfile( ...
                outputDirectory,".v2xsim-output-lock")));
            clear lease
            testCase.verifyFalse(isfolder(fullfile( ...
                outputDirectory,".v2xsim-output-lock")));
        end
    end
end

function restoreGlobalRandomStream(stream,state)
RandStream.setGlobalStream(stream);
stream.State = state;
end

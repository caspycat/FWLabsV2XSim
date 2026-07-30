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
            addpath(fullfile(projectRoot,"lib","matlab-toml"));
            testCase.ConfigurationFile = fullfile( ...
                projectRoot,"tests","+v2xsimtest","+fixtures", ...
                "config","EtsiHighwayMediumMode1.toml");
            temporaryFolder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryDirectory = ...
                string(temporaryFolder.Folder);
        end
    end

    methods (Test)
        function testNonemptyOutputFailureReleasesLeaseWithoutSummary( ...
                testCase)
            outputDirectory = fullfile( ...
                testCase.TemporaryDirectory,"failed-run");
            mkdir(outputDirectory);
            sentinelFile = fullfile(outputDirectory,"preexisting.txt");
            writelines("preserve me",sentinelFile);
            patchData = struct( ...
                Simulation=struct( ...
                    RandomSeed=1, ...
                    DurationSeconds=0.1));
            template = v2xsim.config.load( ...
                testCase.ConfigurationFile);
            configuration = template.resolve( ...
                Patch=v2xsim.config.patch(patchData)); %#ok<NASGU>

            thrownException = [];
            pathBeforeSimulation = path;
            try
                evalc("v2xsim.runSimulation(configuration," + ...
                    "OutputDirectory=outputDirectory);");
            catch exception
                thrownException = exception;
            end
            testCase.verifyEqual(path, pathBeforeSimulation);

            testCase.verifyNotEmpty( ...
                thrownException, ...
                "A nonempty output directory must fail.");
            testCase.verifyEqual( ...
                string(thrownException.identifier), ...
                "v2xsim:output:DirectoryNotEmpty");
            testCase.assertTrue(isfolder(outputDirectory));
            testCase.verifyFalse(isfile(fullfile( ...
                outputDirectory,"simulation_summary.json")));
            testCase.verifyFalse(isfolder(fullfile( ...
                outputDirectory,".v2xsim-output-lock")));
            testCase.verifyTrue(isfile(sentinelFile));

            delete(sentinelFile);
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

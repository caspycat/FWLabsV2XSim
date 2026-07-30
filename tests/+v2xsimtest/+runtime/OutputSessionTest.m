classdef OutputSessionTest < matlab.unittest.TestCase
    %OUTPUTSESSIONTEST Tests run-directory lease ownership.

    methods (Test)
        function testReservesConfiguredDirectoryWithoutUsingLabelInPath( ...
                testCase)
            requestedDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "run-output");
            options = v2xsim.runtime.RunOptions( ...
                OutputDirectory=requestedDirectory, ...
                RunLabel="metadata-only");
            session = v2xsim.runtime.OutputSession(options);
            cleanup = onCleanup(@() delete(session));
            permissions = filePermissions(requestedDirectory);

            testCase.verifyEqual( ...
                session.OutputDirectory, requestedDirectory);
            testCase.verifyEqual(session.RunLabel, "metadata-only");
            testCase.verifyEqual( ...
                session.RunDirectory, permissions.AbsolutePath);
            testCase.verifyFalse(session.IsClosed);
            testCase.verifyTrue(isfolder(fullfile( ...
                session.RunDirectory, ".v2xsim-output-lock")));
        end

        function testCloseIsIdempotentAndPreservesArtifacts(testCase)
            requestedDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "preserved-output");
            session = v2xsim.runtime.OutputSession( ...
                v2xsim.runtime.RunOptions( ...
                    OutputDirectory=requestedDirectory));
            artifact = fullfile( ...
                session.RunDirectory, "metric.csv");
            testCase.writeMarker(artifact, "metric");

            session.close();
            session.close();

            testCase.verifyTrue(session.IsClosed);
            testCase.verifyTrue(isfolder(session.RunDirectory));
            testCase.verifyTrue(isfile(artifact));
            testCase.verifyFalse(isfolder(fullfile( ...
                session.RunDirectory, ".v2xsim-output-lock")));
        end

        function testDeleteReleasesOnlyTheOwnedLease(testCase)
            requestedDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "deleted-session");
            session = v2xsim.runtime.OutputSession( ...
                v2xsim.runtime.RunOptions( ...
                    OutputDirectory=requestedDirectory));
            artifact = fullfile(session.RunDirectory, "result.txt");
            testCase.writeMarker(artifact, "complete");

            delete(session);

            testCase.verifyTrue(isfolder(requestedDirectory));
            testCase.verifyTrue(isfile(artifact));
            testCase.verifyFalse(isfolder(fullfile( ...
                requestedDirectory, ".v2xsim-output-lock")));
        end

        function testConcurrentSessionCannotAcquireSameDirectory( ...
                testCase)
            requestedDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "exclusive-output");
            options = v2xsim.runtime.RunOptions( ...
                OutputDirectory=requestedDirectory);
            firstSession = v2xsim.runtime.OutputSession(options);
            cleanup = onCleanup(@() delete(firstSession));

            testCase.verifyError( ...
                @() v2xsim.runtime.OutputSession(options), ...
                "v2xsim:output:DirectoryInUse");
        end
    end

    methods (Access = private)
        function folder = makeTemporaryDirectory(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folder = string(fixture.Folder);
        end

        function writeMarker(~, file, value)
            fileIdentifier = fopen(file, "wt");
            assert(fileIdentifier ~= -1);
            cleanup = onCleanup(@() fclose(fileIdentifier));
            fprintf(fileIdentifier, "%s", value);
            clear cleanup
        end
    end
end

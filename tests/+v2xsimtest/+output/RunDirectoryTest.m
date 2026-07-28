classdef RunDirectoryTest < matlab.unittest.TestCase
    %RUNDIRECTORYTEST Tests exclusive single-run output directories.

    methods (Test)
        function testCreatesAndReservesAbsentDirectory(testCase)
            root = testCase.makeTemporaryDirectory();
            requestedDirectory = fullfile(root, "new-run");

            [outputDirectory, lease] = ...
                v2xsim.output.acquireRunDirectory(requestedDirectory);

            permissions = filePermissions(requestedDirectory);
            testCase.verifyEqual( ...
                outputDirectory, permissions.AbsolutePath);
            testCase.verifyClass(lease, "onCleanup");
            testCase.verifyTrue(isfolder(outputDirectory));
            testCase.verifyTrue(isfolder(fullfile( ...
                outputDirectory, ".v2xsim-output-lock")));

            clear lease
            testCase.verifyFalse(isfolder(fullfile( ...
                outputDirectory, ".v2xsim-output-lock")));
        end

        function testAcceptsEmptyExistingDirectory(testCase)
            outputDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "empty-run");
            mkdir(outputDirectory);

            [~, lease] = ...
                v2xsim.output.acquireRunDirectory(outputDirectory);

            testCase.verifyClass(lease, "onCleanup");
            testCase.verifyTrue(isfolder(fullfile( ...
                outputDirectory, ".v2xsim-output-lock")));
            clear lease
        end

        function testRejectsNonemptyDirectoryWithoutChangingContents( ...
                testCase)
            outputDirectory = testCase.makeTemporaryDirectory();
            marker = fullfile(outputDirectory, "research-result.txt");
            testCase.writeMarker(marker, "preserve me");

            testCase.verifyError( ...
                @() v2xsim.output.acquireRunDirectory( ...
                    outputDirectory), ...
                "v2xsim:output:DirectoryNotEmpty");
            testCase.verifyEqual( ...
                string(fileread(marker)), "preserve me");
            testCase.verifyFalse(isfolder(fullfile( ...
                outputDirectory, ".v2xsim-output-lock")));
        end

        function testRejectsDirectoryWhileLeaseIsHeld(testCase)
            outputDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "held-run");
            [~, lease] = ...
                v2xsim.output.acquireRunDirectory(outputDirectory);
            testCase.verifyClass(lease, "onCleanup");

            testCase.verifyError( ...
                @() v2xsim.output.acquireRunDirectory( ...
                    outputDirectory), ...
                "v2xsim:output:DirectoryInUse");

            clear lease
        end

        function testDoesNotBreakStaleLock(testCase)
            outputDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "stale-run");
            lockDirectory = fullfile( ...
                outputDirectory, ".v2xsim-output-lock");
            mkdir(lockDirectory);

            testCase.verifyError( ...
                @() v2xsim.output.acquireRunDirectory( ...
                    outputDirectory), ...
                "v2xsim:output:DirectoryInUse");
            testCase.verifyTrue(isfolder(lockDirectory));
        end

        function testRefusesCompletedDirectoryAfterLeaseRelease(testCase)
            outputDirectory = fullfile( ...
                testCase.makeTemporaryDirectory(), "completed-run");
            [~, lease] = ...
                v2xsim.output.acquireRunDirectory( ...
                    outputDirectory); %#ok<ASGLU>
            summaryFile = fullfile( ...
                outputDirectory,"simulation_summary.json");
            testCase.writeMarker(summaryFile,"completed result");
            clear lease

            testCase.verifyError( ...
                @() v2xsim.output.acquireRunDirectory( ...
                    outputDirectory), ...
                "v2xsim:output:DirectoryNotEmpty");
            testCase.verifyEqual( ...
                string(fileread(summaryFile)),"completed result");
        end
    end

    methods (Access = private)
        function folder = makeTemporaryDirectory(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folder = string(fixture.Folder);
        end

        function writeMarker(~, file, value)
            fileId = fopen(file, "wt");
            assert(fileId ~= -1);
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s", value);
            clear cleanup
        end
    end
end

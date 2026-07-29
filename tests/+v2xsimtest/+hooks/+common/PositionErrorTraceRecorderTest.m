classdef PositionErrorTraceRecorderTest < matlab.unittest.TestCase
    %POSITIONERRORTRACERECORDERTEST Tests bounded trace serialization.

    methods (Test)
        function testRowsForInvocationSynthesizesIdentityModule( ...
                testCase)
            positions = testCase.createPositions();
            invocation = v2xsim.hook.invocations. ...
                AfterPositionErrorChainAppliedInvocation( ...
                    positions, positions, 0.25);

            rows = v2xsim.hooks.common. ...
                PositionErrorTraceRecorder.rowsForInvocation(invocation);

            testCase.verifyEqual(height(rows), 2);
            testCase.verifyEqual(rows.ModuleIndex, zeros(2, 1));
            testCase.verifyEqual( ...
                rows.DisplacementMagnitudeMeters, zeros(2, 1));
        end

        function testFlushesBoundedNumberedChunks(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = v2xsim.hooks.common. ...
                PositionErrorTraceRecorder(FlushEveryRows=3);
            hook = hook.build( ...
                v2xsim.hook.dependencies.OutputDirectory( ...
                    outputDirectory));
            positions = testCase.createPositions();

            for simulationTime = [0, 0.1]
                after = positions;
                after.X = after.X + simulationTime + 1;
                diagnostics = ...
                    v2xsim.positioning.diagnostics.createRows( ...
                        positions, after, simulationTime, ...
                        "v2xsim.positioning.TestModule");
                invocation = v2xsim.hook.invocations. ...
                    AfterPositionErrorChainAppliedInvocation( ...
                        positions, after, simulationTime, diagnostics);
                hook = hook.invoke(invocation);
            end

            firstFilename = fullfile( ...
                outputDirectory, ...
                "position_error_trace_000001.csv");
            testCase.verifyTrue(isfile(firstFilename));
            testCase.verifyEqual(height(hook.Records), 1);
            hook = hook.cleanup();
            secondFilename = fullfile( ...
                outputDirectory, ...
                "position_error_trace_000002.csv");
            testCase.verifyTrue(isfile(secondFilename));
            testCase.verifyEmpty(hook.Records);
            testCase.verifyEqual(height(readtable(firstFilename)), 3);
            testCase.verifyEqual(height(readtable(secondFilename)), 1);
        end
    end

    methods (Access = private)
        function positions = createPositions(~)
            positions = table( ...
                [1; 2], [3; 4], ...
                VariableNames=["X", "Y"], ...
                RowNames=["V1", "V2"]);
        end

        function outputDirectory = makeOutputDirectory(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            outputDirectory = string(fixture.Folder);
        end
    end
end

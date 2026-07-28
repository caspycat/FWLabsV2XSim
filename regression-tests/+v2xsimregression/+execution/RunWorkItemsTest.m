classdef RunWorkItemsTest < matlab.unittest.TestCase
    %RUNWORKITEMSTEST Contracts for regression campaign scheduling.

    methods (Test)
        function testSerialExecutionPreservesOrderAndEnvironment(testCase)
            originalPath = path;
            originalStream = RandStream.getGlobalStream();
            originalState = originalStream.State;
            testCleanup = onCleanup(@() restoreTestEnvironment( ...
                originalPath, originalStream, originalState));

            workItems = num2cell([4, 1, 3, 2]);
            outputs = v2xsimregression.execution.runWorkItems( ...
                workItems, @mutateEnvironmentAndSquare, ...
                ExecutionMode="serial");

            testCase.verifyEqual(cell2mat(outputs), [16, 1, 9, 4]);
            testCase.verifyEqual(path, originalPath);
            testCase.verifyTrue( ...
                isequal(RandStream.getGlobalStream(), originalStream));
            testCase.verifyEqual(originalStream.State, originalState);

            testCleanup; %#ok<VUNUS>
        end

        function testWorkItemFailureIncludesLabelAndCause(testCase)
            try
                v2xsimregression.execution.runWorkItems( ...
                    {17}, @failWorkItem, ...
                    Labels="seed-17", ExecutionMode="serial");
                testCase.assertFail("The work item should have failed.");
            catch exception
                testCase.verifyEqual( ...
                    string(exception.identifier), ...
                    "v2xsimregression:execution:WorkItemFailed");
                testCase.verifySubstring(exception.message, "seed-17");
                testCase.verifyNumElements(exception.cause, 1);
                testCase.verifyEqual( ...
                    string(exception.cause{1}.identifier), ...
                    "v2xsimregression:test:ExpectedFailure");
            end
        end

        function testWrongLabelCountIsRejected(testCase)
            testCase.verifyError( ...
                @() v2xsimregression.execution.runWorkItems( ...
                    {1, 2}, @identity, Labels="one", ...
                    ExecutionMode="serial"), ...
                "v2xsimregression:execution:WrongLabelCount");
        end

        function testInvalidWorkerLimitIsRejected(testCase)
            testCase.verifyError( ...
                @() v2xsimregression.execution.mustBeWorkerLimit(0), ...
                "v2xsimregression:execution:InvalidMaxWorkers");
            testCase.verifyError( ...
                @() v2xsimregression.execution.mustBeWorkerLimit(1.5), ...
                "v2xsimregression:execution:InvalidMaxWorkers");
            testCase.verifyError( ...
                @() v2xsimregression.execution.mustBeWorkerLimit(-Inf), ...
                "v2xsimregression:execution:InvalidMaxWorkers");
            v2xsimregression.execution.mustBeWorkerLimit(Inf);
            v2xsimregression.execution.mustBeWorkerLimit(2);
        end

        function testParallelExecutionPreservesOrder(testCase)
            testCase.assumeTrue( ...
                ~isempty(ver("parallel")) && ...
                license("test", "Distrib_Computing_Toolbox"), ...
                "Parallel Computing Toolbox is unavailable.");

            originalPool = gcp("nocreate");
            outputs = v2xsimregression.execution.runWorkItems( ...
                num2cell([4, 1, 3, 2]), @identity, ...
                ExecutionMode="parallel", MaxWorkers=2);

            testCase.verifyEqual(cell2mat(outputs), [4, 1, 3, 2]);
            if isempty(originalPool)
                testCase.verifyEmpty(gcp("nocreate"), ...
                    "A scheduler-owned process pool must be closed.");
            else
                testCase.verifyTrue(isvalid(originalPool), ...
                    "A caller-owned pool must remain open.");
            end
        end

        function testExplicitParallelModeRequiresToolbox(testCase)
            testCase.assumeFalse( ...
                ~isempty(ver("parallel")) && ...
                license("test", "Distrib_Computing_Toolbox"), ...
                "Parallel Computing Toolbox is available.");

            testCase.verifyError( ...
                @() v2xsimregression.execution.runWorkItems( ...
                    {1, 2}, @identity, ExecutionMode="parallel"), ...
                "v2xsimregression:execution:ParallelUnavailable");
        end
    end
end

function output = identity(input)
output = input;
end

function output = mutateEnvironmentAndSquare(input)
addpath(tempdir);
RandStream.setGlobalStream(RandStream("mrg32k3a", Seed=input));
output = input .^ 2;
end

function output = failWorkItem(~) %#ok<STOUT>
error( ...
    "v2xsimregression:test:ExpectedFailure", ...
    "Expected scheduler test failure.");
end

function restoreTestEnvironment(pathValue, stream, streamState)
path(pathValue);
RandStream.setGlobalStream(stream);
stream.State = streamState;
end

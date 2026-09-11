classdef ProcessPoolClassTest < matlab.unittest.TestCase
    methods (Test)
        function acceptsLocalAndRemoteProcesses(testCase)
            testCase.verifyTrue(v2xsimregression.execution.isProcessPoolClass("parallel.ProcessPool"));
            testCase.verifyTrue(v2xsimregression.execution.isProcessPoolClass("parallel.ClusterPool"));
        end
        function rejectsThreadsAndUnknownTypes(testCase)
            testCase.verifyFalse(v2xsimregression.execution.isProcessPoolClass("parallel.ThreadPool"));
            testCase.verifyFalse(v2xsimregression.execution.isProcessPoolClass(""));
            testCase.verifyFalse(v2xsimregression.execution.isProcessPoolClass("other.Pool"));
        end
    end
end
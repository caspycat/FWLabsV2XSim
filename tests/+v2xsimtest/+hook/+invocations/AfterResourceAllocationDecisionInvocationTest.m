classdef AfterResourceAllocationDecisionInvocationTest < ...
        matlab.unittest.TestCase
    %AFTERRESOURCEALLOCATIONDECISIONINVOCATIONTEST Tests typed snapshots.

    methods (Test)
        function retainsEpochContextAndResult(testCase)
            [context,result] = testCase.createPair("global","global");

            invocation = v2xsim.hook.invocations. ...
                AfterResourceAllocationDecisionInvocation( ...
                    0.2,uint64(7),context,result);

            testCase.verifyEqual(invocation.AllocationEpoch,uint64(7));
            testCase.verifyEqual(invocation.Context,context);
            testCase.verifyEqual(invocation.Result,result);
            point = v2xsim.hook.points. ...
                AfterResourceAllocationDecision;
            testCase.verifyTrue(point.acceptsInvocation(invocation));
        end

        function rejectsDifferentNetworkSlices(testCase)
            [context,result] = testCase.createPair("one","two");

            testCase.verifyError( ...
                @() v2xsim.hook.invocations. ...
                    AfterResourceAllocationDecisionInvocation( ...
                        0,uint64(0),context,result), ...
                "v2xsim:hook:invocations:" + ...
                    "ResourceAllocationSliceMismatch");
        end
    end

    methods (Static, Access = private)
        function [context,result] = createPair(contextSlice,resultSlice)
            contextId = v2xsim.network.NetworkSliceId(contextSlice);
            resultId = v2xsim.network.NetworkSliceId(resultSlice);
            context = v2xsim.resource.ResourceAllocationContext( ...
                contextId,"ue",0,false,true(1,1));
            assignments = table( ...
                "ue",1,VariableNames=["UeId","ResourceIds"]);
            result = v2xsim.resource.ResourceAllocationResult( ...
                resultId,assignments,"ue","ue",strings(0,1), ...
                v2xsim.resource.ResourceAllocationResult. ...
                    emptyReservations());
        end
    end
end

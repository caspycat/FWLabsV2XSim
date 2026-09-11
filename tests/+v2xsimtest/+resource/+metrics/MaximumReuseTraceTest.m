classdef MaximumReuseTraceTest < matlab.unittest.TestCase
    %MAXIMUMREUSETRACETEST Eligibility-aware sequential decision scoring.

    methods (Test)
        function unavailableEmptySlotsDoNotIncreaseRegret(testCase)
            [trace,before,distance] = testCase.example();
            mask = true(3,6);
            mask(1,:) = [true false false false false false];
            scored = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2],EligibilityMask=mask);
            testCase.verifyEqual(scored.TrueResourceRank,1);
            testCase.verifyEqual(scored.TrueTimeRank,1);
            testCase.verifyEqual(scored.TrueTimeRegretMeters,0);
            testCase.verifyEqual(scored.TrueSelectionScoreMeters,10);
            testCase.verifyEqual(scored.TrueWitnessUeId,"b");

            % A genuinely eligible empty time slot still has infinite quality.
            unmasked = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2]);
            testCase.verifyEqual(unmasked.TrueTimeRegretMeters,Inf);
            explicit = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2],EligibilityMask=true(3,6));
            testCase.verifyEqual(explicit,unmasked);
        end

        function timeQualityIncludesUsersOnUnavailableFrequencies(testCase)
            [trace,before,distance] = testCase.example();
            mask = true(3,6);
            mask(1,:) = [true false true false false false];
            scored = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2],EligibilityMask=mask);
            testCase.verifyEqual(scored.TrueResourceRank,2);
            testCase.verifyEqual(scored.TrueTimeRank,2);
            testCase.verifyEqual(scored.TrueTimeRegretMeters,10);
        end

        function equivalentResourceRelabelingPreservesScores(testCase)
            [trace,before,distance] = testCase.example();
            mask = true(3,6);
            mask(1,:) = [true false true false false false];
            original = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2],EligibilityMask=mask);
            % Swap whole time slots and frequency labels within slots.
            labels = [6 5 4 3 2 1];
            assigned = ~isnan(before.ResourceIds);
            before.ResourceIds(assigned) = labels(before.ResourceIds(assigned));
            trace.SelectedResourceId = labels(trace.SelectedResourceId);
            trace.SelectedTimeSlot = 3;
            trace.SelectedFrequencyResource = 2;
            mask(:,labels) = mask;
            relabeled = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2],EligibilityMask=mask);
            testCase.verifyEqual(relabeled(:,11:end),original(:,11:end));
        end

        function noSharingHasInfiniteDistanceAndZeroRegret(testCase)
            [trace,before,distance] = testCase.example();
            trace.SelectedResourceId = 5;
            trace.SelectedTimeSlot = 3;
            scored = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before,distance,[3 2]);
            testCase.verifyEqual(scored.TrueResourceRank,1);
            testCase.verifyEqual(scored.TrueTimeRank,1);
            testCase.verifyEqual(scored.TrueTimeRegretMeters,0);
            testCase.verifyEqual(scored.TrueSelectionScoreMeters,Inf);
            testCase.verifyTrue(ismissing(scored.TrueWitnessUeId));
        end

        function rejectsUnavailableAndMalformedSelections(testCase)
            [trace,before,distance] = testCase.example();
            mask = true(3,6);
            mask(1,2) = false;
            for selected = [2 0 -1 7 1.5 NaN Inf]
                trace.SelectedResourceId = selected;
                testCase.verifyError(@() ...
                    v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                        trace,before,distance,[3 2],EligibilityMask=mask), ...
                    "v2xsim:resource:metrics:IneligibleSelection");
            end
        end

        function rejectsMisalignedOrUnusableMasks(testCase)
            [trace,before,distance] = testCase.example();
            masks = {true(2,6),true(3,5),false(3,6),true(0,6),true(3,0)};
            for index = 1:numel(masks)
                testCase.verifyError(@() ...
                    v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                        trace,before,distance,[3 2],EligibilityMask=masks{index}), ...
                    "v2xsim:resource:metrics:InvalidEligibility");
            end
        end

        function emptyAndSingletonInputsKeepTraceSchema(testCase)
            [trace,before,~] = testCase.example();
            empty = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace([],:),before([],:),zeros(0),[1 1], ...
                EligibilityMask=true(0,1));
            testCase.verifySize(empty,[0 16]);
            singleton = v2xsim.resource.metrics.evaluateMaximumReuseDistanceTrace( ...
                trace,before(1,:),0,[1 1],EligibilityMask=true);
            testCase.verifyEqual(singleton.TrueResourceRank,1);
            testCase.verifyEqual(singleton.TrueTimeRegretMeters,0);
            testCase.verifyEqual(singleton.TrueTimeScoreMeters,Inf);
        end
    end

    methods (Static, Access = private)
        function [trace,before,distance] = example()
            before = table(["a";"b";"c"],[NaN;1;4], ...
                VariableNames=["UeId","ResourceIds"]);
            distance = [0 10 20;10 0 30;20 30 0];
            trace = table("a",1,NaN,1,1,1,10,0,0,"b", ...
                VariableNames=[ ...
                    "UeId","DecisionOrder","PreviousResourceId", ...
                    "SelectedResourceId","SelectedTimeSlot", ...
                    "SelectedFrequencyResource","SelectionScoreMeters", ...
                    "WinningTimeMarginMeters","WinningFrequencyMarginMeters", ...
                    "WitnessUeId"]);
        end
    end
end

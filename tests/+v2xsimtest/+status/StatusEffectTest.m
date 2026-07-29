classdef StatusEffectTest < matlab.unittest.TestCase
    %STATUSEFFECTTEST Tests the domain-neutral lifecycle state machine.

    methods (Test)
        function testHasNoPositioningInheritance(testCase)
            effect = ...
                v2xsimtest.status.fixture.StatusEffectStub(1);

            testCase.verifyTrue( ...
                isa(effect, "v2xsim.status.StatusEffect"));
            testCase.verifyFalse( ...
                isa(effect, "v2xsim.positioning.PositionErrorModule"));
        end

        function testSelectsEligibleTargetsOnceInStableIdOrder(testCase)
            seed = 713;
            first = v2xsimtest.status.fixture.StatusEffectStub( ...
                0.5, SelectionRandomSeed=seed);
            second = v2xsimtest.status.fixture.StatusEffectStub( ...
                0.5, SelectionRandomSeed=seed);

            [~, firstLifecycle] = first.advance( ...
                ["vehicle-b"; "vehicle-a"], true(2, 1), ...
                true(2, 1), 0);
            [~, secondLifecycle] = second.advance( ...
                ["vehicle-a"; "vehicle-b"], true(2, 1), ...
                true(2, 1), 0);

            testCase.verifyEqual( ...
                firstLifecycle.IsSelected([2, 1]), ...
                secondLifecycle.IsSelected);
        end

        function testCopiedEffectsOwnIndependentSelectionStreams(testCase)
            targetIds = "vehicle-" + string((1:64).');
            original = v2xsimtest.status.fixture.StatusEffectStub( ...
                0.5, SelectionRandomSeed=991);
            firstCopy = original;
            secondCopy = original;

            [~, firstLifecycle] = firstCopy.advance( ...
                targetIds, true(64, 1), true(64, 1), 0);
            [~, secondLifecycle] = secondCopy.advance( ...
                targetIds, true(64, 1), true(64, 1), 0);

            testCase.verifyEqual( ...
                firstLifecycle.IsSelected, ...
                secondLifecycle.IsSelected);
        end

        function testWaitsForEligibilityBeforeEvaluation(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);

            [effect, before] = effect.advance( ...
                "vehicle-1", false, false, 0);
            [~, after] = effect.advance( ...
                "vehicle-1", true, true, 1);

            testCase.verifyFalse(before.IsEvaluated);
            testCase.verifyFalse(before.IsSelected);
            testCase.verifyTrue(after.EvaluationOccurred);
            testCase.verifyTrue(after.SelectionOccurred);
            testCase.verifyTrue(after.IsActive);
            testCase.verifyEqual(after.EpisodeId, 1);
            testCase.verifyFalse(after.LeftCensoredAtStart);
        end

        function testTracksExitAndReentryAsDistinctEpisodes(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);

            [effect, initial] = effect.advance( ...
                "vehicle-1", true, true, 0);
            [effect, outside] = effect.advance( ...
                "vehicle-1", true, false, 1);
            [~, reentered] = effect.advance( ...
                "vehicle-1", true, true, 2);

            testCase.verifyTrue(initial.LeftCensoredAtStart);
            testCase.verifyEqual(initial.EpisodeId, 1);
            testCase.verifyTrue(outside.ActiveSegmentExited);
            testCase.verifyFalse(outside.IsActive);
            testCase.verifyTrue(reentered.ActiveSegmentEntered);
            testCase.verifyEqual(reentered.EpisodeId, 2);
        end

        function testResetsAtBoundaryAndNeverReselects(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub( ...
                1, ResetAfterSeconds=2);

            [effect, ~] = effect.advance( ...
                "vehicle-1", true, true, 3);
            [effect, before] = effect.advance( ...
                "vehicle-1", true, true, 4.999);
            [effect, atBoundary] = effect.advance( ...
                "vehicle-1", true, true, 5);
            [~, later] = effect.advance( ...
                "vehicle-1", true, true, 8);

            testCase.verifyTrue(before.IsActive);
            testCase.verifyTrue(atBoundary.ResetOccurred);
            testCase.verifyTrue(atBoundary.ActiveSegmentExited);
            testCase.verifyFalse(atBoundary.IsSelected);
            testCase.verifyFalse(later.IsSelected);
            testCase.verifyFalse(later.EvaluationOccurred);
        end

        function testZeroDurationResetNeverBecomesActive(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub( ...
                1, ResetAfterSeconds=0);

            [~, lifecycle] = effect.advance( ...
                "vehicle-1", true, true, 0);

            testCase.verifyTrue(lifecycle.SelectionOccurred);
            testCase.verifyTrue(lifecycle.ResetOccurred);
            testCase.verifyFalse(lifecycle.IsSelected);
            testCase.verifyFalse(lifecycle.IsActive);
            testCase.verifyTrue(isnan(lifecycle.EpisodeId));
        end

        function testRejectsReversedTime(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);
            effect = effect.advance( ...
                "vehicle-1", true, true, 1);

            testCase.verifyError( ...
                @() effect.advance( ...
                    "vehicle-1", true, true, 0.5), ...
                "v2xsim:status:TimeReversed");
        end

        function testRejectsDuplicateTargetIds(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);

            testCase.verifyError( ...
                @() effect.advance( ...
                    ["vehicle-1"; "vehicle-1"], ...
                    true(2, 1), true(2, 1), 0), ...
                "v2xsim:status:InvalidTargetIds");
        end

        function testRejectsMismatchedMaskSizes(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);

            testCase.verifyError( ...
                @() effect.advance( ...
                    ["vehicle-1"; "vehicle-2"], ...
                    true, true(2, 1), 0), ...
                "v2xsim:status:TargetMaskSizeMismatch");
        end

        function testRejectsNumericMasks(testCase)
            effect = v2xsimtest.status.fixture.StatusEffectStub(1);

            testCase.verifyError( ...
                @() effect.advance( ...
                    "vehicle-1", 1, true, 0), ...
                "v2xsim:status:InvalidTargetMask");
        end
    end
end

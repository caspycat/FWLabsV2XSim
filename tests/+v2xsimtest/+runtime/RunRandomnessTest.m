classdef RunRandomnessTest < matlab.unittest.TestCase
    %RUNRANDOMNESSTEST Tests run-owned deterministic randomness.

    methods (Test)
        function testDefaultOwnsMt19937arStreamSeededWithOne(testCase)
            randomness = v2xsim.runtime.RunRandomness();

            testCase.verifyEqual(randomness.MasterSeed, 1);
            testCase.verifyEqual( ...
                string(randomness.MasterStream.Type), "mt19937ar");
        end

        function testEqualSeedsProduceEqualIndependentSequences(testCase)
            first = v2xsim.runtime.RunRandomness(17);
            second = v2xsim.runtime.RunRandomness(17);

            firstValues = rand(first.MasterStream, 1, 8);
            secondValues = rand(second.MasterStream, 1, 8);

            testCase.verifyEqual(firstValues, secondValues);
            testCase.verifyNotSameHandle( ...
                first.MasterStream, second.MasterStream);
        end

        function testDrawingDoesNotAdvanceGlobalStream(testCase)
            globalStream = RandStream.getGlobalStream();
            stateBefore = globalStream.State;
            randomness = v2xsim.runtime.RunRandomness(31);

            rand(randomness.MasterStream, 1, 10);

            testCase.verifyEqual(globalStream.State, stateBefore);
        end

        function testResetRestoresInitialSequence(testCase)
            randomness = v2xsim.runtime.RunRandomness(23);
            expected = rand(randomness.MasterStream, 1, 5);
            rand(randomness.MasterStream, 1, 7);

            randomness.reset();

            testCase.verifyEqual( ...
                rand(randomness.MasterStream, 1, 5), expected);
        end

        function testRejectsSeedsOutsidePositiveUint32Range(testCase)
            invalidSeeds = [0, -1, 1.5, Inf, 2^32];

            for seed = invalidSeeds
                testCase.verifyError( ...
                    @() v2xsim.runtime.RunRandomness(seed), ...
                    "v2xsim:runtime:InvalidRandomSeed");
            end
        end
    end
end

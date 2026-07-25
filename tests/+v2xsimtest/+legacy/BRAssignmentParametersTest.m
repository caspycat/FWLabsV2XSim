classdef BRAssignmentParametersTest < matlab.unittest.TestCase
    %BRASSIGNMENTPARAMETERSTEST Tests independent resource-selection ratios.

    methods (TestClassSetup)
        function addLegacyInitializationPath(testCase)
            projectRoot = fileparts(fileparts(fileparts(fileparts( ...
                mfilename("fullpath")))));
            legacyInitializationPath = fullfile( ...
                projectRoot, "old_src", "MatFilesInit");
            addpath(legacyInitializationPath);
            testCase.addTeardown(@() rmpath(legacyInitializationPath));
        end
    end

    methods (Test)
        function testDefaultRatiosRemainCoupledAtTwentyPercent(testCase)
            simParams = testCase.initializeWithArguments({});

            testCase.verifyEqual( ...
                simParams.ratioSelectedAutonomousMode, 0.2);
            testCase.verifyEqual(simParams.ratioSelectedL2, 0.2);
        end

        function testExistingRatioStillConfiguresBothStages(testCase)
            simParams = testCase.initializeWithArguments( ...
                {"resourceAllocation.Autonomous.MinimumCandidateFraction", 0.5});

            testCase.verifyEqual( ...
                simParams.ratioSelectedAutonomousMode, 0.5);
            testCase.verifyEqual(simParams.ratioSelectedL2, 0.5);
        end

        function testThresholdAndL2RatiosCanBeSetIndependently(testCase)
            simParams = testCase.initializeWithArguments({ ...
                "resourceAllocation.Autonomous.MinimumCandidateFraction", 0.2, ...
                "resourceAllocation.Autonomous.L2CandidateFraction", 0.5});

            testCase.verifyEqual( ...
                simParams.ratioSelectedAutonomousMode, 0.2);
            testCase.verifyEqual(simParams.ratioSelectedL2, 0.5);
        end
    end

    methods (Access = private)
        function simParams = initializeWithArguments( ...
                testCase, inputArguments)
            initialSimParams = struct("mode5G", 1);
            initialPhyParams = struct( ...
                "PDelta", Inf, ...
                "duplexCV2X", "HD", ...
                "cv2xNumberOfReplicasMax", 1, ...
                "muNumerology", 0, ...
                "BRoverlapAllowed", false);

            [simParams, ~, remainingArguments] = ...
                initiateBRAssignmentAlgorithm( ...
                    initialSimParams, initialPhyParams, 0.1, "", ...
                    inputArguments);
            testCase.verifyEmpty(remainingArguments{1});
        end
    end
end

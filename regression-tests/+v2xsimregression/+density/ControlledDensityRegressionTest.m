classdef ControlledDensityRegressionTest < matlab.unittest.TestCase
    %CONTROLLEDDENSITYREGRESSIONTEST Load-response regression for each RAT.

    properties (SetAccess = private)
        SimulatorRoot (1, 1) string
        OutputDirectory (1, 1) string
    end

    methods (TestClassSetup)
        function configureCampaign(testCase)
            testCase.SimulatorRoot = repositoryRoot();
            temporaryFolder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.OutputDirectory = string(temporaryFolder.Folder);
        end
    end

    methods (Test)
        function testHigherVehicleLoadReducesPrrAuc(testCase)
            randomSeeds = configuredSeeds();
            simulationTimeSeconds = configuredDurationSeconds();
            [seedResults, comparisons] = ...
                v2xsimregression.density.runControlledCampaign( ...
                    testCase.SimulatorRoot, ...
                    testCase.OutputDirectory, ...
                    RandomSeeds=randomSeeds, ...
                    SimulationTimeSeconds=simulationTimeSeconds);

            testCase.verifyEqual( ...
                unique(seedResults.VehicleCount).', ...
                [72, 126, 252]);
            testCase.verifyEqual( ...
                unique(seedResults.RandomSeed).', randomSeeds);
            testCase.verifyEqual( ...
                comparisons.Technology.', ...
                ["LTE-V2X", "NR-V2X", "80211p"]);
            testCase.verifyGreaterThan( ...
                comparisons.Lower95ConfidenceBound, 0, ...
                "The paired 95% bootstrap interval for low-minus-high " + ...
                "normalized PRR AUC must be strictly positive.");
        end
    end
end

function root = repositoryRoot()
root = string(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))));
end

function seeds = configuredSeeds()
configuredCount = string(getenv( ...
    "V2XSIM_DENSITY_REGRESSION_SEED_COUNT"));
if strlength(configuredCount) == 0
    seedCount = 20;
else
    seedCount = str2double(configuredCount);
    if ~isscalar(seedCount) || ~isfinite(seedCount) || ...
            seedCount < 1 || fix(seedCount) ~= seedCount
        error( ...
            "v2xsimregression:density:InvalidSeedCountOverride", ...
            "V2XSIM_DENSITY_REGRESSION_SEED_COUNT must be a " + ...
            "positive integer.");
    end
end
seeds = 10:(9 + seedCount);
end

function duration = configuredDurationSeconds()
configuredDuration = string(getenv( ...
    "V2XSIM_DENSITY_REGRESSION_DURATION_SECONDS"));
if strlength(configuredDuration) == 0
    duration = 2;
else
    duration = str2double(configuredDuration);
    if ~isscalar(duration) || ~isfinite(duration) || duration <= 0
        error( ...
            "v2xsimregression:density:InvalidDurationOverride", ...
            "V2XSIM_DENSITY_REGRESSION_DURATION_SECONDS must be " + ...
            "positive and finite.");
    end
end
end

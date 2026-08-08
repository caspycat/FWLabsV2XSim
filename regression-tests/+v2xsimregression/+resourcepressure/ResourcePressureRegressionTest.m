classdef ResourcePressureRegressionTest < matlab.unittest.TestCase
    %RESOURCEPRESSUREREGRESSIONTEST Capacity-response contract per allocator.

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
        function testPressureReducesNormalizedPrrAucForEveryAllocator(testCase)
            allocators = [ ...
                "ReuseDistance", "MaximumReuseDistance", ...
                "MinimumReusePower", "SensingBased", "Random", "Ordered"];
            randomSeeds = configuredSeeds();
            simulationTimeSeconds = configuredDurationSeconds();

            [seedResults, comparisons] = ...
                v2xsimregression.resourcepressure.runPressureCampaign( ...
                    testCase.SimulatorRoot, testCase.OutputDirectory, ...
                    Allocators=allocators, RandomSeeds=randomSeeds, ...
                    SimulationTimeSeconds=simulationTimeSeconds);

            testCase.verifyEqual( ...
                sort(unique(seedResults.Allocator)).',sort(allocators));
            testCase.verifyEqual(unique(seedResults.RandomSeed).',randomSeeds);
            testCase.verifyEqual(comparisons.Allocator.',allocators);
            testCase.verifyEqual(comparisons.SeedCount, ...
                repmat(numel(randomSeeds),numel(allocators),1));
            testCase.verifyGreaterThan( ...
                comparisons.Lower95ConfidenceBound, 0, ...
                "For every allocator, the paired 95% bootstrap interval " + ...
                "for unpressured-minus-pressured normalized PRR-AUC " + ...
                "must be strictly positive.");
        end
    end
end

function root = repositoryRoot()
root = string(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))));
end

function seeds = configuredSeeds()
configuredCount = string(getenv( ...
    "V2XSIM_RESOURCE_PRESSURE_REGRESSION_SEED_COUNT"));
if strlength(configuredCount) == 0
    seedCount = 10;
else
    seedCount = str2double(configuredCount);
    if ~isscalar(seedCount) || ~isfinite(seedCount) || ...
            seedCount < 1 || fix(seedCount) ~= seedCount
        error( ...
            "v2xsimregression:resourcepressure:InvalidSeedCountOverride", ...
            "V2XSIM_RESOURCE_PRESSURE_REGRESSION_SEED_COUNT must " + ...
            "be a positive integer.");
    end
end
seeds = 10:(9 + seedCount);
end

function duration = configuredDurationSeconds()
configuredDuration = string(getenv( ...
    "V2XSIM_RESOURCE_PRESSURE_REGRESSION_DURATION_SECONDS"));
if strlength(configuredDuration) == 0
    duration = 2;
else
    duration = str2double(configuredDuration);
    if ~isscalar(duration) || ~isfinite(duration) || duration <= 0
        error( ...
            "v2xsimregression:resourcepressure:InvalidDurationOverride", ...
            "V2XSIM_RESOURCE_PRESSURE_REGRESSION_DURATION_SECONDS " + ...
            "must be positive and finite.");
    end
end
end

classdef EtsiHighwayIeee80211pSmokeTest < matlab.unittest.TestCase
    %ETSIHIGHWAYIEEE80211PSMOKETEST Smoke tests for IEEE 802.11p.

    properties (SetAccess = private)
        OutputDirectory (1, 1) string
    end

    methods (TestClassSetup)
        function createUniqueOutputDirectory(testCase)
            temporaryFolder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.OutputDirectory = string(temporaryFolder.Folder);
        end
    end

    methods (Test)
        function testPrrDecreasesAsDensityIncreases(testCase)
            packetReceptionRatios = ...
                v2xsimtest.smoke.runEtsiHighwayDensitySweep( ...
                    testCase.OutputDirectory, ...
                    "80211p");

            testCase.verifyGreaterThan( ...
                packetReceptionRatios(1:end - 1), ...
                packetReceptionRatios(2:end), ...
                "PRR must decrease from low to medium to high density.");
        end
    end
end

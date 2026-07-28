classdef EtsiHighwayLteV2xSmokeTest < matlab.unittest.TestCase
    %ETSIHIGHWAYLTEV2XSMOKETEST Smoke tests for LTE-V2X.

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
                    "LTE-V2X");

            testCase.verifyGreaterThan( ...
                packetReceptionRatios(1:end - 1), ...
                packetReceptionRatios(2:end), ...
                "PRR must decrease from low to medium to high density.");
        end
    end
end

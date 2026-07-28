classdef NetworkSliceIdTest < matlab.unittest.TestCase
    %NETWORKSLICEIDTEST Tests exact, immutable slice identities.

    methods (Test)
        function testDefaultRepresentsGlobalSlice(testCase)
            sliceId = v2xsim.network.NetworkSliceId();

            testCase.verifyEqual(string(sliceId), "global");
        end

        function testEqualityIsExactAndCaseSensitive(testCase)
            globalA = v2xsim.network.NetworkSliceId("global");
            globalB = v2xsim.network.NetworkSliceId("global");
            capitalized = v2xsim.network.NetworkSliceId("Global");

            testCase.verifyTrue(globalA == globalB);
            testCase.verifyTrue(globalA ~= capitalized);
        end

        function testRejectsInvalidIdentifiers(testCase)
            invalidValues = ["", " ", " global", "global ", missing];

            for value = invalidValues
                testCase.verifyError( ...
                    @() v2xsim.network.NetworkSliceId(value), ...
                    "v2xsim:network:InvalidNetworkSliceId");
            end
        end
    end
end

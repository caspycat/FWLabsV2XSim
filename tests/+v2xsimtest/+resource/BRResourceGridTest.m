classdef BRResourceGridTest < matlab.unittest.TestCase
    %BRRESOURCEGRIDTEST Tests slice-local beacon-resource coordinates.

    methods (Test)
        function testExposesTopologyAndResourceCount(testCase)
            sliceId = v2xsim.network.NetworkSliceId("global");
            grid = v2xsim.resource.BRResourceGrid( ...
                sliceId, 10, 3, 0.0005);

            testCase.verifyEqual(grid.NetworkSliceId, sliceId);
            testCase.verifyEqual(grid.NumberTimeSlots, 10);
            testCase.verifyEqual(grid.NumberFrequencyResources, 3);
            testCase.verifyEqual(grid.SlotDurationSeconds, 0.0005);
            testCase.verifyEqual(grid.ResourceCount, 30);
        end

        function testMapsAbsoluteAndPeriodicSlots(testCase)
            grid = testCase.createGrid();

            testCase.verifyEqual( ...
                grid.periodicSlot([0, 9, 10, 21]), [1, 10, 1, 2]);
        end

        function testRoundTripsResourceCoordinates(testCase)
            grid = testCase.createGrid();
            resourceIds = grid.resourceId([1, 2, 10], [1, 2, 2]);
            [timeSlots, frequencyResources] = ...
                grid.resourceCoordinates(resourceIds);

            testCase.verifyEqual(resourceIds, [1, 4, 20]);
            testCase.verifyEqual(timeSlots, [1, 2, 10]);
            testCase.verifyEqual(frequencyResources, [1, 2, 2]);
        end

        function testRejectsOutOfRangeCoordinates(testCase)
            grid = testCase.createGrid();

            testCase.verifyError(@() grid.resourceId(11, 1), ...
                "v2xsim:resource:GridCoordinateOutOfRange");
            testCase.verifyError(@() grid.resourceCoordinates(21), ...
                "v2xsim:resource:ResourceIdOutOfRange");
        end

        function testEqualLocalIdsRemainSliceQualified(testCase)
            gridA = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("slice-a"), 10, 2, 0.001);
            gridB = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("slice-b"), 10, 2, 0.001);

            testCase.verifyEqual(gridA.resourceId(2, 1), ...
                gridB.resourceId(2, 1));
            testCase.verifyNotEqual( ...
                gridA.NetworkSliceId, gridB.NetworkSliceId);
        end
    end

    methods (Access = private)
        function grid = createGrid(~)
            grid = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("global"), 10, 2, 0.001);
        end
    end
end

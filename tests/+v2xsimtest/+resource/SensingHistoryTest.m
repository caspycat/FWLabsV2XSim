classdef SensingHistoryTest < matlab.unittest.TestCase
    %SENSINGHISTORYTEST Tests shared slice-scoped sensing state.

    methods (Test)
        function testUpdatesOnlyCurrentSlotResources(testCase)
            grid = testCase.createGrid();
            history = v2xsim.resource.sensing.SensingHistory(grid,2);
            history = history.synchronizeUes(["ue-1";"ue-2"]);
            reservations = logical([1 0 0 0;0 0 1 0]);

            history = history.update( ...
                grid.NetworkSliceId,["ue-1";"ue-2"],0, ...
                [1 2;3 4],reservations);
            history = history.update( ...
                grid.NetworkSliceId,["ue-1";"ue-2"],1, ...
                [5 6;7 8],reservations);

            snapshot = history.snapshot(false);
            testCase.verifyEqual( ...
                snapshot.EnergyWattsPerMHz,[1 2 5 6;3 4 7 8]);
            testCase.verifyEqual(snapshot.ReservedMask,reservations);
            testCase.verifyEqual(history.LastUpdatedSlot,1);
        end

        function testAverageRetainsConfiguredNumberOfPeriods(testCase)
            grid = testCase.createGrid();
            history = v2xsim.resource.sensing.SensingHistory(grid,2);
            history = history.synchronizeUes("ue-1");
            history = history.update( ...
                grid.NetworkSliceId,"ue-1",0,[2 4],false(1,4));
            history = history.update( ...
                grid.NetworkSliceId,"ue-1",1,[6 8],false(1,4));
            history = history.update( ...
                grid.NetworkSliceId,"ue-1",2,[10 12],false(1,4));

            snapshot = history.snapshot(true);

            testCase.verifyEqual( ...
                snapshot.EnergyWattsPerMHz,[6 8 3 4]);
        end

        function testSynchronizePreservesRetainedUeState(testCase)
            grid = testCase.createGrid();
            history = v2xsim.resource.sensing.SensingHistory(grid,1);
            history = history.synchronizeUes(["ue-1";"ue-2"]);
            history = history.update( ...
                grid.NetworkSliceId,["ue-1";"ue-2"],0, ...
                [1 2;3 4],false(2,4));

            history = history.synchronizeUes(["ue-2";"ue-3"]);
            snapshot = history.snapshot(false);

            testCase.verifyEqual(snapshot.UeIds,["ue-2";"ue-3"]);
            testCase.verifyEqual( ...
                snapshot.EnergyWattsPerMHz,[3 4 0 0;0 0 0 0]);
        end

        function testRejectsDuplicateAndSkippedUpdates(testCase)
            grid = testCase.createGrid();
            history = v2xsim.resource.sensing.SensingHistory(grid,1);
            history = history.synchronizeUes("ue-1");
            history = history.update( ...
                grid.NetworkSliceId,"ue-1",0,[1 2],false(1,4));

            testCase.verifyError( ...
                @() history.update( ...
                    grid.NetworkSliceId,"ue-1",0,[1 2],false(1,4)), ...
                "v2xsim:resource:DuplicateSensingUpdate");
            testCase.verifyError( ...
                @() history.update( ...
                    grid.NetworkSliceId,"ue-1",2,[1 2],false(1,4)), ...
                "v2xsim:resource:NonconsecutiveSensingUpdate");
        end

        function testRejectsSliceAndUeSetMismatch(testCase)
            grid = testCase.createGrid();
            history = v2xsim.resource.sensing.SensingHistory(grid,1);
            history = history.synchronizeUes("ue-1");

            testCase.verifyError( ...
                @() history.update( ...
                    v2xsim.network.NetworkSliceId("other"), ...
                    "ue-1",0,[1 2],false(1,4)), ...
                "v2xsim:resource:NetworkSliceMismatch");
            testCase.verifyError( ...
                @() history.update( ...
                    grid.NetworkSliceId,"ue-2",0,[1 2],false(1,4)), ...
                "v2xsim:resource:SensingUeSetMismatch");
        end
    end

    methods (Static, Access = private)
        function grid = createGrid()
            grid = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("global"),2,2,0.001);
        end
    end
end

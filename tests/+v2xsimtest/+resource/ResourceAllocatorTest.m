classdef ResourceAllocatorTest < matlab.unittest.TestCase
    %RESOURCEALLOCATORTEST Tests the sealed allocator lifecycle and RNG.

    methods (Test)
        function testSynchronizePreservesAssignmentsAndReplicaWidth(testCase)
            allocator = testCase.createCentralizedAllocator(19, 2);
            allocator = allocator.synchronizeUes(["ue-1"; "ue-2"]);
            context = testCase.createCentralizedContext( ...
                allocator.Grid, ["ue-1"; "ue-2"]);
            [allocator, ~] = allocator.initialize(context);

            allocator = allocator.synchronizeUes(["ue-2"; "ue-3"]);

            testCase.verifyEqual(allocator.UeIds, ["ue-2"; "ue-3"]);
            testCase.verifySize(allocator.Assignments.ResourceIds, [2, 2]);
            testCase.verifyEqual(allocator.EnteredUeIds, ...
                ["ue-1"; "ue-2"; "ue-3"]);
            testCase.verifyEqual(allocator.ExitedUeIds, "ue-1");
        end

        function testPureReorderSynchronizesSubclassState(testCase)
            allocator = testCase.createCentralizedAllocator(19, 1);
            allocator = allocator.synchronizeUes(["ue-1"; "ue-2"]);

            allocator = allocator.synchronizeUes(["ue-2"; "ue-1"]);

            testCase.verifyEqual(allocator.UeIds, ["ue-2"; "ue-1"]);
            testCase.verifyEqual(allocator.SynchronizationCount, 2);
            testCase.verifyEqual( ...
                allocator.EnteredUeIds, ["ue-1"; "ue-2"]);
            testCase.verifyEmpty(allocator.ExitedUeIds);
        end

        function testLifecycleRequiresSynchronizationAndInitialization( ...
                testCase)
            allocator = testCase.createCentralizedAllocator(1, 1);
            context = testCase.createCentralizedContext( ...
                allocator.Grid, "ue-1");

            testCase.verifyError(@() allocator.initialize(context), ...
                "v2xsim:resource:AllocatorUeSetMismatch");
            testCase.verifyError(@() allocator.step(context), ...
                "v2xsim:resource:AllocatorNotInitialized");

            allocator = allocator.synchronizeUes("ue-1");
            [allocator, ~] = allocator.initialize(context);
            testCase.verifyTrue(allocator.IsInitialized);
            testCase.verifyError(@() allocator.initialize(context), ...
                "v2xsim:resource:AllocatorAlreadyInitialized");
        end

        function testCentralizedAndAutonomousBoundariesAreEnforced(testCase)
            grid = testCase.createGrid();
            centralized = testCase.createCentralizedAllocator(2, 1);
            centralized = centralized.synchronizeUes("ue-1");
            autonomous = ...
                v2xsimtest.resource.fixture.AutonomousAllocatorStub( ...
                    grid, 2);
            autonomous = autonomous.synchronizeUes("ue-1");

            centralizedContext = ...
                testCase.createCentralizedContext(grid, "ue-1");
            autonomousContext = ...
                testCase.createAutonomousContext(grid, "ue-1");

            testCase.verifyError( ...
                @() centralized.initialize(autonomousContext), ...
                "v2xsim:resource:InvalidAllocationContextType");
            testCase.verifyError( ...
                @() autonomous.initialize(centralizedContext), ...
                "v2xsim:resource:InvalidAllocationContextType");
        end

        function testRejectsSliceAndResourceCountMismatch(testCase)
            allocator = testCase.createCentralizedAllocator(3, 1);
            allocator = allocator.synchronizeUes("ue-1");
            otherGrid = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("other"), 2, 2, 0.001);
            otherContext = ...
                testCase.createCentralizedContext(otherGrid, "ue-1");

            testCase.verifyError( ...
                @() allocator.initialize(otherContext), ...
                "v2xsim:resource:NetworkSliceMismatch");

            badWidthContext = testCase.createCentralizedContext( ...
                allocator.Grid, "ue-1", 3);
            testCase.verifyError( ...
                @() allocator.initialize(badWidthContext), ...
                "v2xsim:resource:ResourceCountMismatch");
        end

        function testRejectsMalformedHookOutput(testCase)
            grid = testCase.createGrid();
            sliceId = grid.NetworkSliceId;
            wrongAssignments = table( ...
                "ue-1", 99, VariableNames=["UeId", "ResourceIds"]);
            wrongResult = v2xsim.resource.ResourceAllocationResult( ...
                sliceId, wrongAssignments, strings(0, 1), ...
                strings(0, 1), strings(0, 1), ...
                v2xsim.resource.ResourceAllocationResult ...
                .emptyReservations());
            allocator = ...
                v2xsimtest.resource.fixture.CentralizedAllocatorStub( ...
                    grid, 1, 1, @(~, ~, ~) wrongResult);
            allocator = allocator.synchronizeUes("ue-1");
            context = testCase.createCentralizedContext(grid, "ue-1");

            testCase.verifyError(@() allocator.initialize(context), ...
                "v2xsim:resource:ResourceIdOutOfRange");
        end

        function testAcceptsAssignmentRowReordering(testCase)
            grid = testCase.createGrid();
            assignments = table( ...
                ["ue-2"; "ue-1"], [2; 1], ...
                VariableNames=["UeId", "ResourceIds"]);
            result = v2xsim.resource.ResourceAllocationResult( ...
                grid.NetworkSliceId, assignments, strings(0, 1), ...
                strings(0, 1), strings(0, 1), ...
                v2xsim.resource.ResourceAllocationResult ...
                .emptyReservations());
            allocator = ...
                v2xsimtest.resource.fixture.CentralizedAllocatorStub( ...
                    grid, 1, 1, @(~, ~, ~) result);
            allocator = allocator.synchronizeUes(["ue-1"; "ue-2"]);
            context = testCase.createCentralizedContext( ...
                grid, ["ue-1"; "ue-2"]);

            [allocator, ~] = allocator.initialize(context);

            testCase.verifyEqual( ...
                allocator.Assignments.UeId, ["ue-2"; "ue-1"]);
        end

        function testRandomStateIsDeterministicAndCopyIsolated(testCase)
            allocator = testCase.createCentralizedAllocator(1234, 1);
            allocator = allocator.synchronizeUes("ue-1");
            context = testCase.createCentralizedContext( ...
                allocator.Grid, "ue-1");
            [allocator, ~] = allocator.initialize(context);
            copyA = allocator;
            copyB = allocator;

            [copyA, ~] = copyA.step(context);
            firstValue = copyA.LastRandomValue;
            rand(100, 1);
            [copyB, ~] = copyB.step(context);

            testCase.verifyEqual(copyB.LastRandomValue, firstValue);
            testCase.verifyEqual(copyA.RandomSeed, 1234);
            testCase.verifyEqual(copyA.RandomGeneratorType, "mt19937ar");
        end

        function testDifferentSeedsProduceDifferentStreams(testCase)
            allocatorA = testCase.initializeAllocatorWithSeed(10);
            allocatorB = testCase.initializeAllocatorWithSeed(11);

            testCase.verifyNotEqual( ...
                allocatorA.LastRandomValue, allocatorB.LastRandomValue);
        end

        function testExposesBranchFreeMetadata(testCase)
            allocator = testCase.createCentralizedAllocator(1, 1);
            metadata = allocator.metadata();

            testCase.verifyEqual(metadata.Type, "CentralizedStub");
            testCase.verifyEqual(metadata.Category, "Centralized");
            testCase.verifyEqual( ...
                metadata.Description, ...
                "Centralized allocator test double");
            testCase.verifyEqual(metadata.NetworkSliceId,"global");
            testCase.verifyEqual(metadata.RandomSeed,1);
            testCase.verifyEqual(metadata.MaximumTransmissionCount,1);
            testCase.verifyEqual(metadata.NumberTimeSlots,2);
            testCase.verifyEqual(metadata.NumberFrequencyResources,2);
            testCase.verifyEqual(metadata.SlotDurationSeconds,0.001);
            testCase.verifyEqual(metadata.Options,struct());
        end
    end

    methods (Access = private)
        function allocator = createCentralizedAllocator( ...
                testCase, seed, maximumTransmissionCount)
            allocator = ...
                v2xsimtest.resource.fixture.CentralizedAllocatorStub( ...
                    testCase.createGrid(), seed, maximumTransmissionCount);
        end

        function allocator = initializeAllocatorWithSeed(testCase, seed)
            allocator = testCase.createCentralizedAllocator(seed, 1);
            allocator = allocator.synchronizeUes("ue-1");
            context = testCase.createCentralizedContext( ...
                allocator.Grid, "ue-1");
            [allocator, ~] = allocator.initialize(context);
        end

        function grid = createGrid(~)
            grid = v2xsim.resource.BRResourceGrid( ...
                v2xsim.network.NetworkSliceId("global"), 2, 2, 0.001);
        end

        function context = createCentralizedContext( ...
                ~, grid, ueIds, resourceCount)
            arguments (Input)
                ~
                grid (1, 1) v2xsim.resource.BRResourceGrid
                ueIds string
                resourceCount (1, 1) double = grid.ResourceCount
            end

            ueIds = ueIds(:);
            numberUes = numel(ueIds);
            context = v2xsim.resource.CentralizedAllocationContext( ...
                grid.NetworkSliceId, ueIds, 0, ...
                false(numberUes, 1), true(numberUes, resourceCount), ...
                zeros(numberUes, 1), zeros(numberUes), ...
                zeros(numberUes), zeros(numberUes), zeros(numberUes));
        end

        function context = createAutonomousContext(~, grid, ueIds)
            ueIds = ueIds(:);
            numberUes = numel(ueIds);
            snapshot = v2xsim.resource.SensingSnapshot( ...
                grid.NetworkSliceId, ueIds, ...
                zeros(numberUes, grid.ResourceCount), ...
                false(numberUes, grid.ResourceCount));
            context = v2xsim.resource.AutonomousAllocationContext( ...
                grid.NetworkSliceId, ueIds, 0, ...
                false(numberUes, 1), ...
                true(numberUes, grid.ResourceCount), snapshot);
        end
    end
end

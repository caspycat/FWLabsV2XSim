classdef ResourceUsageRecorderTest < matlab.unittest.TestCase
    %RESOURCEUSAGERECORDERTEST Upstream sections 5-6, using public lifecycle.
    properties (TestParameter)
        emptyFile = {"resource_changes","resource_transmissions"}
    end

    methods (Test)
        function intervalsUseElapsedTimeAndTrueKinematics(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1);
            ids = ["a";"b";"c";"d"];
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0,ids,[0 0;10 0;210 0;400 0]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,ids,[2;2;3;nan],ids));
            % Both callbacks at 0.1 end one interval, with no double exposure.
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0.1,ids,[0 0;150 0;210 0;400 0]));
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0.1,ids,[0 0;200 0;210 0;400 0]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.2,ids,[2;2;3;nan],"a"));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.4,ids,[2;3;3;nan],"b"));
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0.65,ids,[0 0;200 0;400 0;600 0]));
            recorder = recorder.cleanup();
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            occupancy = readtable(fullfile(directory,"resource_occupancy.csv"));
            required = ["StartSeconds","EndSeconds","VehicleCount","AssignedVehicles", ...
                "AvailableResources","OccupiedResources","OccupiedFraction", ...
                "UsersPerOccupiedResource","MaximumOccupancy","SharingVehicles", ...
                "SharingFraction","CoResourcePairs","LocalPairs","LocalCoResourcePairs", ...
                "MeanCoResourceSeparationMeters","MinimumCoResourceSeparationMeters","GeometryCoverage"];
            testCase.verifyTrue(all(ismember(required,string(usage.Properties.VariableNames))));
            testCase.verifyTrue(all(ismember(["StartSeconds","EndSeconds","Users","ResourceCount"], ...
                string(occupancy.Properties.VariableNames))));
            testCase.verifyEqual(usage.StartSeconds,[0;0.1;0.4;0.65],AbsTol=1e-14);
            testCase.verifyEqual(usage.EndSeconds,[0.1;0.4;0.65;1],AbsTol=1e-14);
            testCase.verifyEqual(usage.VehicleCount,4*ones(4,1));
            testCase.verifyEqual(usage.AssignedVehicles,3*ones(4,1));
            testCase.verifyEqual(usage.AvailableResources,3*ones(4,1));
            testCase.verifyEqual(usage.GeometryCoverage,ones(4,1));
            testCase.verifyEqual(usage.MeanCoResourceSeparationMeters,[10;200;10;200]);
            verifyConservation(testCase,usage,occupancy,0.05,0.8);
            weights = clippedSeconds(usage,0.05,0.8);
            testCase.verifyEqual(sum(weights),0.75,AbsTol=1e-14);
            testCase.verifyEqual(sum(weights.*usage.MeanCoResourceSeparationMeters)/sum(weights),124,AbsTol=1e-12);
            % Repeated cleanup must not append the final interval again.
            recorder.cleanup();
            testCase.verifyEqual(readtable(fullfile(directory,"resource_usage.csv")),usage);
        end

        function stableIdentitySeparatesChangesFromSelections(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,0.7);
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0,["a";"b";"c"],[1999 0;200 0;19 0]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,["a";"b";"c"],[2;nan;3],["a";"b";"c"]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.1,["c";"a";"b"],[3;2;nan],"a"));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.2,["c";"a";"b"],[3;3;nan],["a";"b"],"b"));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.3,["c";"a";"d"],[3;nan;2],["a";"d"]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.4,["c";"a";"d"],[3;2;2],"a"));
            % A coordinate wrap and row reordering preserve the physical IDs.
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0.5,["d";"a";"c"],[10 0;1 0;19 0]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.6,["c";"a";"d"],[3;2;2]));
            recorder.cleanup();
            changes = readtable(fullfile(directory,"resource_changes.csv"));
            testCase.verifyTrue(all(ismember( ...
                ["TimeSeconds","ReassignedVehicles","BlockedVehicles","SelectedVehicles"], ...
                string(changes.Properties.VariableNames))));
            testCase.verifyEqual(changes.TimeSeconds,[0;0.1;0.2;0.3;0.4]);
            testCase.verifyEqual(changes.ReassignedVehicles,[0;0;1;1;1]);
            testCase.verifyEqual(changes.SelectedVehicles,[3;1;2;2;1]);
            testCase.verifyEqual(changes.BlockedVehicles,[0;0;1;0;0]);
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            testCase.verifyEqual(usage.GeometryCoverage(end),1);
            testCase.verifyEqual(usage.MeanCoResourceSeparationMeters(end),9);
            testCase.verifyEqual(usage.GeometryCoverage(usage.StartSeconds==0.4),2/3,AbsTol=1e-14);
        end

        function recordsPhysicalAttemptsOnceIndependentOfReceiverOutcomes(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1);
            % Ten receiver links are one attempt; callback splits stay one.
            event = ResourceUsageEvents.transmission(0.2,"alpha",7,1,4,true,repmat("correct",10,1));
            [recorder,returned] = recorder.invoke(event);
            testCase.verifyEqual(returned,event);
            recorder = recorder.invoke(event);
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.2,"alpha",7,1,4,true,"error"));
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.2,"beta",8,1,4,true));
            % Same packet, later physical attempt; the event's resource wins.
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.3,"alpha",2,"alpha"));
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.4,"alpha",7,2,3,true));
            % Neither a pre-air discard nor later cleanup is a transmission.
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.5,"alpha",9,0,nan,false,"blocked"));
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.6,"alpha",7,2,3,false,"blocked"));
            % Explicit false provenance overrides even a positive radio link.
            recorder = recorder.invoke(ResourceUsageEvents.transmission(0.7,"alpha",7,2,3,false,"correct"));
            recorder.cleanup();
            rows = readtable(fullfile(directory,"resource_transmissions.csv"),TextType="string");
            expected = table([0.2;0.2;0.4],["alpha";"beta";"alpha"],[7;8;7],[1;1;2],[4;4;3], ...
                VariableNames=["TimeSeconds","VehicleId","PacketSequence","AttemptNumber","ResourceId"]);
            testCase.verifyEqual(rows(:,expected.Properties.VariableNames),expected);
            testCase.verifyEqual(height(unique(rows(:,1:4))),height(rows));
        end

        function reservationWithoutEventsWritesHeaderOnlyFile(testCase,emptyFile)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1);
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,"a",2));
            recorder = recorder.cleanup();
            filename = fullfile(directory,emptyFile+".csv");
            testCase.assertTrue(isfile(filename),"No activity must be represented by a header-only CSV.");
            rows = readtable(filename);
            testCase.verifyEqual(height(rows),0);
            if emptyFile == "resource_changes"
                expected = ["TimeSeconds","ReassignedVehicles","BlockedVehicles","SelectedVehicles"];
            else
                expected = ["TimeSeconds","VehicleId","PacketSequence","AttemptNumber","ResourceId"];
            end
            testCase.verifyTrue(all(ismember(expected,string(rows.Properties.VariableNames))));
            contents = fileread(filename);
            recorder.cleanup();
            testCase.verifyEqual(fileread(filename),contents);
        end

        function noCallbacksStillFinalizesEmptyEventStream(testCase,emptyFile)
            [recorder,directory] = makeRecorder(testCase,1);
            recorder = recorder.cleanup();
            filename = fullfile(directory,emptyFile+".csv");
            testCase.assertTrue(isfile(filename));
            testCase.verifyEqual(height(readtable(filename)),0);
            contents = fileread(filename);
            recorder.cleanup();
            testCase.verifyEqual(fileread(filename),contents);
            % Event headers alone must not fabricate assignment exposure.
            usageFile = fullfile(directory,"resource_usage.csv");
            if isfile(usageFile)
                testCase.verifyEqual(height(readtable(usageFile)),0);
            end
        end

        function unassignedSingletonRetainsVehicleAndUnusedResources(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1);
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0,"a",[10 20]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,"a",nan));
            recorder.cleanup();
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            occupancy = readtable(fullfile(directory,"resource_occupancy.csv"));
            testCase.verifyEqual(usage{:,1:2},[0 1]);
            testCase.verifyEqual(usage.VehicleCount,1);
            testCase.verifyEqual(usage.AssignedVehicles,0);
            testCase.verifyEqual(usage.GeometryCoverage,1);
            testCase.verifyEqual(usage.SharingFraction,0);
            testCase.verifyEqual(occupancy.Users,0);
            testCase.verifyEqual(occupancy.ResourceCount,3);
            verifyConservation(testCase,usage,occupancy,0,1);
        end

        function flushingPreservesIntervalsHistogramsAndAttemptDeduplication(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1.01);
            ids = ["a";"b"];
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0,ids,[0 0;10 0]));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,ids,[2;2]));
            % Cross the recorder's bounded buffer with distinct TTI attempts.
            % Duplicates straddling the flush must not be emitted twice.
            for index = 1:1001
                time = index/1000;
                event = ResourceUsageEvents.transmission(time,"a",index,1,2,true);
                recorder = recorder.invoke(event);
                recorder = recorder.invoke(event);
            end
            testCase.assertTrue(isfile(fullfile(directory,"resource_transmissions.csv")), ...
                "The recorder must flush before end-of-run cleanup.");
            recorder.cleanup();
            rows = readtable(fullfile(directory,"resource_transmissions.csv"));
            testCase.verifyEqual(rows.TimeSeconds,(1:1001).'/1000);
            testCase.verifyEqual(rows.PacketSequence,(1:1001).');
            testCase.verifyEqual(rows.AttemptNumber,ones(1001,1));
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            occupancy = readtable(fullfile(directory,"resource_occupancy.csv"));
            testCase.verifyEqual(usage{:,1:2},[0 1.01]);
            verifyConservation(testCase,usage,occupancy,0,1.01);
        end

        function intervalAndChangeBuffersFlushWithoutFabricatingRunEnd(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,2);
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,"a",2));
            for index = 1:1001
                time = index/1000;
                recorder = recorder.invoke(ResourceUsageEvents.kinematics(time,"a",[index 0]));
                recorder = recorder.invoke(ResourceUsageEvents.allocation(time,"a",2,"a"));
            end
            % Before successful cleanup, only closed intervals are evidence.
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            testCase.verifyLessThanOrEqual(max(usage.EndSeconds),1.001);
            recorder = recorder.cleanup();
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            occupancy = readtable(fullfile(directory,"resource_occupancy.csv"));
            changes = readtable(fullfile(directory,"resource_changes.csv"));
            testCase.verifyEqual(height(usage),1002);
            testCase.verifyEqual(height(changes),1001);
            testCase.verifyEqual(sum(changes.SelectedVehicles),1001);
            testCase.verifyEqual(sum(changes.ReassignedVehicles),0);
            testCase.verifyEqual(usage.EndSeconds(end),2);
            verifyConservation(testCase,usage,occupancy,0,2);
            recorder.cleanup();
            testCase.verifyEqual(readtable(fullfile(directory,"resource_changes.csv")),changes);
        end

        function emptyPopulationGapDoesNotBorrowPreviousAssignments(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,directory] = makeRecorder(testCase,1);
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0,"a",2));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.2,strings(0,1),nan(0,1)));
            recorder = recorder.invoke(ResourceUsageEvents.allocation(0.5,"b",3,"b"));
            recorder.cleanup();
            usage = readtable(fullfile(directory,"resource_usage.csv"));
            testCase.verifyFalse(any(usage.StartSeconds<0.5 & usage.EndSeconds>0.2 & usage.AssignedVehicles>0));
            changes = readtable(fullfile(directory,"resource_changes.csv"));
            testCase.verifyEqual(changes.ReassignedVehicles,0);
        end

        function rejectsUnsupportedReservationsAndBackwardTime(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            [recorder,~] = makeRecorder(testCase,1);
            testCase.verifyError(@() recorder.invoke(ResourceUsageEvents.allocation(0,"a",[2 3])), ...
                "v2xsim:resource:UsageTransmissionCount");
            recorder = recorder.invoke(ResourceUsageEvents.kinematics(0.5,"a",[0 0]));
            testCase.verifyError(@() recorder.invoke(ResourceUsageEvents.kinematics(0.4,"a",[0 0])), ...
                "v2xsim:resource:UsageTime");
        end

        function invocationAndRandomStreamAreUnchanged(testCase)
            import v2xsimtest.fixtures.ResourceUsageEvents
            stream = RandStream.getGlobalStream();
            state = stream.State;
            testCase.addTeardown(@() restoreStream(stream,state));
            [recorder,~] = makeRecorder(testCase,1);
            events = {ResourceUsageEvents.kinematics(0,"a",[1 2]), ...
                ResourceUsageEvents.allocation(0,"a",2,"a"), ...
                ResourceUsageEvents.transmission(0.1)};
            for index = 1:numel(events)
                [recorder,returned] = recorder.invoke(events{index});
                testCase.verifyEqual(returned,events{index});
            end
            recorder.cleanup();
            testCase.verifyEqual(RandStream.getGlobalStream(),stream);
            testCase.verifyEqual(stream.State,state);
        end
    end
end

function [recorder,directory] = makeRecorder(testCase,duration)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
directory = string(folder.Folder);
grid = v2xsim.resource.BRResourceGrid(v2xsim.network.NetworkSliceId("global"),4,1,0.001);
pressure = v2xsim.resource.ResourcePressure(grid,75,100);
recorder = v2xsim.hooks.common.ResourceUsageRecorder(grid,pressure,duration);
recorder = recorder.build(v2xsim.hook.dependencies.OutputDirectory(directory));
end

function weights = clippedSeconds(rows,startTime,endTime)
weights = max(0,min(rows.EndSeconds,endTime)-max(rows.StartSeconds,startTime));
end

function verifyConservation(testCase,usage,occupancy,startTime,endTime)
testCase.verifyGreaterThan(usage.EndSeconds-usage.StartSeconds,0);
testCase.verifyEqual(usage.StartSeconds(2:end),usage.EndSeconds(1:end-1),AbsTol=1e-12);
testCase.verifyGreaterThan(occupancy.ResourceCount,0);
for index = 1:height(usage)
    selected = occupancy.StartSeconds==usage.StartSeconds(index) & occupancy.EndSeconds==usage.EndSeconds(index);
    rows = occupancy(selected,:);
    testCase.verifyEqual(sum(rows.ResourceCount),usage.AvailableResources(index));
    testCase.verifyEqual(sum(rows.Users.*rows.ResourceCount),usage.AssignedVehicles(index));
end
weights = clippedSeconds(usage,startTime,endTime);
histogramWeights = clippedSeconds(occupancy,startTime,endTime);
testCase.verifyEqual(sum(histogramWeights.*occupancy.ResourceCount), ...
    sum(weights.*usage.AvailableResources),AbsTol=1e-10);
testCase.verifyEqual(sum(histogramWeights.*occupancy.Users.*occupancy.ResourceCount), ...
    sum(weights.*usage.AssignedVehicles),AbsTol=1e-10);
end

function restoreStream(stream,state)
RandStream.setGlobalStream(stream);
stream.State = state;
end

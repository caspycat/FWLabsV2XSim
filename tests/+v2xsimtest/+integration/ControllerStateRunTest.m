classdef ControllerStateRunTest < matlab.unittest.TestCase
    %CONTROLLERSTATERUNTEST Join consumed delayed reports across road wraps.

    methods (TestMethodSetup)
        function isolateProcessState(testCase)
            originalPath = path;
            originalStream = RandStream.getGlobalStream();
            originalState = originalStream.State;
            originalWarnings = warning;
            testCase.addTeardown(@() path(originalPath));
            testCase.addTeardown(@() warning(originalWarnings));
            testCase.addTeardown(@() restoreStream(originalStream,originalState));
        end
    end

    methods (Test)
        function delayedStateJoinsReportsAndRecordingPreservesRun(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            patch = struct( ...
                Simulation=struct(RandomSeed=21,DurationSeconds=0.45), ...
                Scenario=struct(Type="BidirectionalHighway",UpdateIntervalSeconds=0.1, ...
                    BidirectionalHighway=struct(RandomSeed=22,VehicleCount=4, ...
                        RoadLength=100,NLanes=1,MeanVehicleSpeed=400, ...
                        VehicleSpeedStandardDeviation=0,RerollSpeedOnWrapAround=false)), ...
                ResourceAllocation=struct(Type="MaximumReuseDistance",RandomSeed=23, ...
                    MaximumReuseDistance=struct(ReassignmentIntervalSeconds=0.1)), ...
                Positioning=struct(Errors={{struct(Type="Delay",DelaySeconds=0.2)}}), ...
                Outputs=struct(ControllerDiagnostics=struct(Enabled=true), ...
                    PositionErrorTrace=struct(Enabled=true), ...
                    PacketFateTrace=struct(Enabled=true,FileFormat="csv")));
            template = v2xsim.config.ConfigurationTemplate(struct(SchemaVersion=1));
            configuration = template.resolve(Patch=v2xsim.config.patch(patch)); %#ok<NASGU>
            recordedDirectory = fullfile(string(folder.Folder),"recorded");
            plainDirectory = fullfile(string(folder.Folder),"plain");
            evalc("recorded = v2xsim.runSimulation(configuration, " + ...
                "OutputDirectory=recordedDirectory);");
            patch.Outputs.ControllerDiagnostics.Enabled = false;
            configuration = template.resolve(Patch=v2xsim.config.patch(patch)); %#ok<NASGU>
            evalc("plain = v2xsim.runSimulation(configuration, " + ...
                "OutputDirectory=plainDirectory);");
            % Wall-clock computation time is expected to change with recording.
            recordedMetrics = recorded.Metrics.Metrics;
            plainMetrics = plain.Metrics.Metrics;
            testCase.verifyEqual(recordedMetrics( ...
                recordedMetrics.Name ~= "ComputationDurationSeconds",:), ...
                plainMetrics(plainMetrics.Name ~= "ComputationDurationSeconds",:));
            testCase.verifyEqual(recorded.Metrics.Events,plain.Metrics.Events);
            packetTrace = readChunks(recordedDirectory,"packet_fates_*.csv");
            testCase.assertNotEmpty(packetTrace);
            testCase.verifyEqual(packetTrace,readChunks(plainDirectory,"packet_fates_*.csv"));
            trace = readChunks(recordedDirectory,"position_error_trace_*.csv");
            testCase.verifyEqual(trace,readChunks(plainDirectory,"position_error_trace_*.csv"));
            state = readtable(fullfile(recordedDirectory,"controller_state.csv"), ...
                TextType="string");
            testCase.assertNotEmpty(state);
            ids = unique(trace.VehicleId);
            testCase.verifyEqual(sort(unique(state.UeId)),ids);
            epochs = unique(state.AllocationEpoch);
            testCase.verifyEqual(height(state),numel(ids)*numel(epochs));
            for epoch = epochs.'
                rows = state(state.AllocationEpoch == epoch,:);
                testCase.verifyEqual(sort(rows.UeId),ids);
                testCase.verifyNumElements(unique(rows.RandomPlanFingerprint),1);
            end
            % Carry each final module output forward to the controller epoch.
            for row = 1:height(state)
                reports = trace(trace.VehicleId == state.UeId(row),:);
                reports = sortrows(reports,"SimulationTimeSeconds");
                selected = find(reports.SimulationTimeSeconds <= ...
                    state.SimulationTimeSeconds(row) + 16*eps(1),1,"last");
                testCase.assertNotEmpty(selected);
                testCase.verifyEqual(state.EstimatedXMeters(row), ...
                    reports.OutputXMeters(selected),AbsTol=1e-10);
            end
            boundary = trace(abs(trace.SimulationTimeSeconds-0.3) < 16*eps(1),:);
            testCase.assertEqual(height(boundary),numel(ids));
            testCase.verifyEqual(boundary.OutputSourceTimeSeconds, ...
                repmat(0.1,numel(ids),1),AbsTol=1e-14);
            testCase.verifyEqual(boundary.OutputAgeSeconds, ...
                repmat(0.2,numel(ids),1),AbsTol=1e-14);
            % At 400 m/s on a 100 m road at least one native coordinate wrap
            % occurs. Delayed records retain stable identities across it.
            wrapped = false;
            for id = ids.'
                reports = sortrows(trace(trace.VehicleId == id,:),"SimulationTimeSeconds");
                wrapped = wrapped || any(abs(diff(reports.InputXMeters)) > 50);
            end
            testCase.verifyTrue(wrapped);
        end
    end
end

function rows = readChunks(directory,pattern)
files = dir(fullfile(directory,pattern));
tables = cell(numel(files),1);
for index = 1:numel(files)
    tables{index} = readtable(fullfile(files(index).folder,files(index).name), ...
        TextType="string");
end
rows = vertcat(tables{:});
end

function restoreStream(stream,state)
RandStream.setGlobalStream(stream);
stream.State = state;
end

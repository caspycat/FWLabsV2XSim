classdef ResourceUsageRunTest < matlab.unittest.TestCase
    %RESOURCEUSAGERUNTEST Short NR software contracts, not pilot PRR targets.
    properties (TestParameter)
        profile = struct(Mrd=struct(Type="MaximumReuseDistance",Diagnostics=false), ...
            MrdDiagnostics=struct(Type="MaximumReuseDistance",Diagnostics=true), ...
            Sensing=struct(Type="SensingBased",Diagnostics=false))
        impairment = struct(Delay=struct(Type="Delay",DelaySeconds=0.2), ...
            Loss=struct(Type="PacketLoss",LossProbability=0.5,RandomSeed=107), ...
            Gaussian=struct(Type="Gaussian",StandardDeviationMeters=10,DisplacementRandomSeed=109))
    end

    methods (TestMethodSetup)
        function isolateProcessState(testCase)
            originalPath = path;
            originalWarnings = warning;
            stream = RandStream.getGlobalStream();
            state = stream.State;
            testCase.addTeardown(@() path(originalPath));
            testCase.addTeardown(@() warning(originalWarnings));
            testCase.addTeardown(@() restoreStream(stream,state));
        end
    end

    methods (Test)
        function switchDefaultsValidatesAndCompiles(testCase)
            defaults = v2xsim.config.defaults();
            testCase.verifyFalse(defaults.Data.Outputs.ResourceUsage.Enabled);
            template = studyTemplate();
            configuration = template.resolve();
            plan = v2xsim.runtime.compile(configuration);
            testCase.verifyTrue(plan.Outputs.ResourceUsage.Enabled);
            testCase.verifyFalse(plan.Outputs.ControllerDiagnostics.Enabled);
            testCase.verifyFalse(plan.Outputs.PositionErrorTrace.Enabled);
            for invalid = {1,"true",[true false]}
                data = template.Data;
                data.Outputs.ResourceUsage.Enabled = invalid{1};
                testCase.verifyError(@() resolveData(data),"v2xsim:config:InvalidType");
            end
        end

        function studyPressurePointsRetainPhysicalGridAndExactMasks(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            availability = [80 20 16 15];
            expected = [400 100 80 75];
            for index = 1:numel(availability)
                template = studyTemplate();
                data = template.Data;
                data.Radio.Sidelink.ResourcePool.ResourcePressure.TimeAvailabilityPercent = availability(index);
                plan = v2xsim.runtime.compile(resolveData(data)); %#ok<NASGU>
                options = v2xsim.runtime.RunOptions(OutputDirectory=string(folder.Folder)); %#ok<NASGU>
                evalc("[~,app] = v2xsim.runtime.internal.initializeEstablishedEngine(plan,options);");
                testCase.verifyEqual([app.NbeaconsT app.NbeaconsF app.Nbeacons],[100 5 500]);
                grid = v2xsim.resource.BRResourceGrid(v2xsim.network.NetworkSliceId("global"), ...
                    app.NbeaconsT,app.NbeaconsF,0.001);
                pressure = v2xsim.resource.ResourcePressure(grid,availability(index),100);
                testCase.verifyEqual(pressure.AvailableResourceCount,expected(index));
                testCase.verifyEqual(nnz(pressure.ResourceMask),expected(index));
                testCase.verifyGreaterThan(find(pressure.ResourceMask,1,"last"),expected(index));
            end
        end

        function observerPreservesSeededNrRun(testCase,profile)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            template = studyTemplate();
            data = template.Data;
            % Build SensingBased from an unresolved fresh branch; retaining
            % MRD defaults would make a discriminator change invalid.
            if profile.Type == "SensingBased"
                data.ResourceAllocation = struct(Type="SensingBased",RandomSeed=101);
            end
            data.Outputs.ControllerDiagnostics.Enabled = profile.Diagnostics;
            directories = string(folder.Folder) + ["/off","/on"];
            runs = cell(1,2);
            for index = 1:2
                data.Outputs.ResourceUsage.Enabled = index==2;
                configuration = resolveData(data); %#ok<NASGU>
                % Own generator type AND seed across the serial pair.
                rng(113,"twister");
                before = rng;
                outputDirectory = directories(index); %#ok<NASGU>
                evalc("result = v2xsim.runSimulation(configuration,OutputDirectory=outputDirectory);");
                testCase.verifyEqual(rng,before);
                runs{index} = result;
            end
            off = runs{1}.Metrics;
            on = runs{2}.Metrics;
            testCase.verifyEqual(on.Metrics(on.Metrics.Name~="ComputationDurationSeconds",:), ...
                off.Metrics(off.Metrics.Name~="ComputationDurationSeconds",:));
            testCase.verifyEqual(on.Events,off.Events);
            testCase.verifyEqual(readtable(fullfile(directories(1),"vehicle_kinematics.csv")), ...
                readtable(fullfile(directories(2),"vehicle_kinematics.csv")));
            fates = readChunks(directories(2),"packet_fates_*.parquet");
            testCase.assertNotEmpty(fates);
            testCase.verifyEqual(fates,readChunks(directories(1),"packet_fates_*.parquet"));
            testCase.verifyEmpty(dir(fullfile(directories(1),"resource_*.csv")));
            verifyRunContracts(testCase,directories(2),1.2);
            if profile.Diagnostics
                % Includes committed live assignments, shadow choices and
                % allocation random-plan fingerprints for the same epochs.
                files = dir(fullfile(directories(2),"controller_*.csv"));
                testCase.assertNotEmpty(files);
                for file = files.'
                    testCase.verifyEqual(readtable(fullfile(directories(2),file.name),TextType="string"), ...
                        readtable(fullfile(directories(1),file.name),TextType="string"));
                end
                testCase.assertTrue(isfile(fullfile(directories(2),"controller_state.csv")));
            else
                testCase.verifyEmpty(dir(fullfile(directories(2),"controller_*.csv")));
            end
            testCase.verifyEmpty(dir(fullfile(directories(2),"position_error_trace_*")));
            % An independent packet-link export must collapse to the same
            % physical attempts, with event time (not generation time).
            transmitted = fates(ismember(fates.Outcome,["correct","error"]),:);
            expected = unique(transmitted(:,["FateTimeSeconds","TransmitterUeId", ...
                "PacketSequence","AttemptNumber","ResourceId"]));
            expected.Properties.VariableNames = ["TimeSeconds","VehicleId","PacketSequence","AttemptNumber","ResourceId"];
            actual = readtable(fullfile(directories(2),"resource_transmissions.csv"),TextType="string");
            testCase.verifyEqual(sortrows(actual(:,expected.Properties.VariableNames)),sortrows(expected));
        end

        function nativeImpairmentsCoexistWithObserverAndDiagnostics(testCase,impairment)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            template = studyTemplate();
            data = template.Data;
            data.Outputs.ControllerDiagnostics.Enabled = true;
            data.Outputs.PositionErrorTrace.Enabled = true;
            data.Positioning = struct(Errors={{impairment}});
            configuration = resolveData(data); %#ok<NASGU>
            directory = string(folder.Folder);
            rng(113,"twister");
            evalc("v2xsim.runSimulation(configuration,OutputDirectory=directory);");
            verifyRunContracts(testCase,directory,1.2);
            trace = readChunks(directory,"position_error_trace_*.csv");
            state = readtable(fullfile(directory,"controller_state.csv"),TextType="string");
            testCase.assertNotEmpty(trace);
            testCase.assertNotEmpty(state);
            testCase.verifyTrue(all(ismember(unique(state.UeId),unique(trace.VehicleId))));
            testCase.verifyGreaterThan(max(trace.SimulationTimeSeconds),0.2);
            if impairment.Type == "Delay"
                afterBootstrap = trace.SimulationTimeSeconds>0.2;
                testCase.verifyEqual(trace.OutputAgeSeconds(afterBootstrap), ...
                    repmat(0.2,nnz(afterBootstrap),1),AbsTol=1e-12);
                testCase.verifyGreaterThan(max(trace.OutputSourceTimeSeconds),0);
            end
        end
    end
end

function template = studyTemplate()
root = fileparts(fileparts(mfilename("fullpath")));
template = v2xsim.config.load(fullfile(root,"+fixtures","config","ResourceUsageNrStudy.toml"));
end

function configuration = resolveData(data)
configuration = v2xsim.config.ConfigurationTemplate(data).resolve();
end

function rows = readChunks(directory,pattern)
files = dir(fullfile(directory,pattern));
tables = cell(numel(files),1);
for index = 1:numel(files)
    filename = fullfile(files(index).folder,files(index).name);
    if endsWith(filename,".parquet")
        tables{index} = parquetread(filename);
    else
        tables{index} = readtable(filename,TextType="string");
    end
end
rows = vertcat(tables{:});
end

function verifyRunContracts(testCase,directory,duration)
names = ["resource_usage","resource_occupancy","resource_changes","resource_transmissions"];
testCase.assertTrue(all(isfile(fullfile(directory,names+".csv"))));
usage = readtable(fullfile(directory,"resource_usage.csv"));
occupancy = readtable(fullfile(directory,"resource_occupancy.csv"));
testCase.assertNotEmpty(usage);
% The study's measured window starts after initialization. Do not demand
% invented exposure before the producer's first committed assignment.
testCase.verifyLessThanOrEqual(usage.StartSeconds(1),0.2);
testCase.verifyEqual(usage.EndSeconds(end),duration,AbsTol=1e-12);
testCase.verifyEqual(usage.StartSeconds(2:end),usage.EndSeconds(1:end-1),AbsTol=1e-12);
testCase.verifyGreaterThan(usage.EndSeconds-usage.StartSeconds,0);
testCase.verifyEqual(usage.VehicleCount,100*ones(height(usage),1));
testCase.verifyEqual(usage.GeometryCoverage,ones(height(usage),1));
testCase.verifyEqual(usage.AvailableResources,80*ones(height(usage),1));
% Clip away bootstrap and the last part of the run, as the consumer does.
weights = max(0,min(usage.EndSeconds,1.1)-max(usage.StartSeconds,0.2));
histWeights = max(0,min(occupancy.EndSeconds,1.1)-max(occupancy.StartSeconds,0.2));
testCase.verifyEqual(sum(weights),0.9,AbsTol=1e-12);
testCase.verifyEqual(sum(histWeights.*occupancy.ResourceCount),sum(weights.*usage.AvailableResources),AbsTol=1e-9);
testCase.verifyEqual(sum(histWeights.*occupancy.Users.*occupancy.ResourceCount),sum(weights.*usage.AssignedVehicles),AbsTol=1e-9);
testCase.verifyGreaterThan(occupancy.ResourceCount,0);
tx = readtable(fullfile(directory,"resource_transmissions.csv"),TextType="string");
testCase.assertNotEmpty(tx);
testCase.verifyEqual(height(unique(tx(:,1:4))),height(tx));
testCase.verifyEqual(tx.AttemptNumber,ones(height(tx),1));
testCase.verifyGreaterThan(tx.PacketSequence,0);
testCase.verifyEqual(tx.PacketSequence,fix(tx.PacketSequence));
grid = v2xsim.resource.BRResourceGrid(v2xsim.network.NetworkSliceId("global"),100,5,0.001);
pressure = v2xsim.resource.ResourcePressure(grid,16,100);
testCase.verifyTrue(all(pressure.ResourceMask(tx.ResourceId)));
summary = jsondecode(fileread(fullfile(directory,"simulation_summary.json")));
pool = summary.Configuration.ResourcePool;
testCase.verifyEqual(pool.BeaconResourceCount,500);
testCase.verifyEqual(pool.ResourcePressure.AvailableResourceCount,80);
end

function restoreStream(stream,state)
RandStream.setGlobalStream(stream);
stream.State = state;
end

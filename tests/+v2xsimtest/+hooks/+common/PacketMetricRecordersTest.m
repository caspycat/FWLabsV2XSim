classdef PacketMetricRecordersTest < matlab.unittest.TestCase
    methods (Test)
        function queuedPacketRetainsWaitingAndRetryDelay(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = testCase.buildHook(v2xsim.hooks.common.PacketDelayRecorder(0.05,0.1),outputDirectory);
            queue = v2xsim.packet.PacketBuffer("UE1",3);
            queue = queue.enqueue(0,0,1);
            queue = queue.enqueue(0.2,0.2,1);
            queue = queue.startAttempt();
            packet = queue.head();
            hook = hook.invoke(testCase.makeInvocation(0.35,packet.GenerationTimeSeconds,50,"correct",100));
            queue = queue.endAttempt();
            queue = queue.startAttempt();
            packet = queue.head();
            % The second receiver first decodes the same packet on its retry.
            hook = hook.invoke(testCase.makeInvocation(0.55,packet.GenerationTimeSeconds,50,"correct",100));
            hook = hook.invoke(testCase.makeInvocation(2,0.2,50,"blocked",100));
            hook.cleanup();
            values = readmatrix(fullfile(outputDirectory,"packet_delay_11p.csv"));
            testCase.verifySize(values,[11,3]);
            testCase.verifyEqual(values([7,11],2),[1;1]);
            testCase.verifyEqual(sum(values(:,2)),2);
            testCase.verifyEqual(values(end,1),0.55,AbsTol=1e-12);
        end

        function growthPreservesAllTechnologyChannelAndPacketBins(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = testCase.buildHook(v2xsim.hooks.common.PacketDelayRecorder(0.1,0.1,ChannelCount=2),outputDirectory);
            original = testCase.makeInvocation(0.1,0,50,"correct",100);
            hook = hook.invoke(original);
            tx = original.Transmitters;
            tx.Channel = 2;
            tx.PacketType = 2;
            other = v2xsim.hook.invocations.AfterPacketFatesDeterminedInvocation( ...
                0.55,"LTE",2,100,tx,original.Links);
            hook = hook.invoke(other);
            hook.cleanup();
            a = readmatrix(fullfile(outputDirectory,"packet_delay_11p_C1.csv"));
            b = readmatrix(fullfile(outputDirectory,"packet_delay_LTE_DENM_C2.csv"));
            testCase.verifySize(a,[6,3]);
            testCase.verifySize(b,[6,3]);
            testCase.verifyEqual(a(:,2),[1;zeros(5,1)]);
            testCase.verifyEqual(b(:,2),[zeros(5,1);1]);
        end

        function ageCountsWaitingAndIgnoresUnsuccessfulUpdates(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = testCase.buildHook(v2xsim.hooks.common.DataAgeRecorder(0.01),outputDirectory);
            hook = hook.invoke(testCase.makeInvocation(0.1,0.04,50,"correct",100));
            hook = hook.invoke(testCase.makeInvocation(0.2,0.15,50,"blocked",100));
            hook = hook.invoke(testCase.makeInvocation(0.3,0.25,50,"error",100));
            hook = hook.invoke(testCase.makeInvocation(0.35,0.3,50,"correct",100));
            hook.cleanup();
            values = readmatrix(fullfile(outputDirectory,"data_age_11p.csv"));
            testCase.verifyEqual(sum(values(:,2)),1);
            testCase.verifyEqual(values(31,2),1);
        end

        function writesPacketDelayByAwarenessRange(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = v2xsim.hooks.common.PacketDelayRecorder(0.1, 0.2);
            hook = testCase.buildHook(hook,outputDirectory);
            invocation = testCase.makeInvocation( ...
                0.19, 0, [50; 150], ["correct"; "correct"], ...
                [100, 200]);

            hook = hook.invoke(invocation);
            hook.cleanup();

            values = readmatrix(fullfile( ...
                outputDirectory, "packet_delay_11p.csv"), ...
                FileType="text", Delimiter=",");
            testCase.verifyEqual( ...
                values(2, [1, 2, 4, 6]), ...
                [0.2, 1, 1, 2], AbsTol=1e-12);
        end

        function writesUpdateDelayBetweenSuccessfulReceptions(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = v2xsim.hooks.common.UpdateDelayRecorder( ...
                0.1, MaximumDelaySeconds=0.3);
            hook = testCase.buildHook(hook,outputDirectory);

            hook = hook.invoke(testCase.makeInvocation( ...
                0.1, 0.05, 50, "correct", 100));
            hook = hook.invoke(testCase.makeInvocation( ...
                0.31, 0.25, 50, "correct", 100));
            hook.cleanup();

            values = readmatrix(fullfile( ...
                outputDirectory, "update_delay_11p.csv"), ...
                FileType="text", Delimiter=",");
            testCase.verifyEqual( ...
                values(3, :), [0.3, 1, 1], AbsTol=1e-12);
        end

        function writesAgeFromPreviousPacketGeneration(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = v2xsim.hooks.common.DataAgeRecorder( ...
                0.1, MaximumAgeSeconds=0.3);
            hook = testCase.buildHook(hook,outputDirectory);

            hook = hook.invoke(testCase.makeInvocation( ...
                0.1, 0.04, 50, "correct", 100));
            hook = hook.invoke(testCase.makeInvocation( ...
                0.35, 0.3, 50, "correct", 100));
            hook.cleanup();

            values = readmatrix(fullfile( ...
                outputDirectory, "data_age_11p.csv"), ...
                FileType="text", Delimiter=",");
            testCase.verifyEqual( ...
                values(4, :), [0.4, 1, 1], AbsTol=1e-12);
        end

        function writesPacketReceptionOutcomesByDistanceBin(testCase)
            outputDirectory = testCase.makeOutputDirectory();
            hook = v2xsim.hooks.common. ...
                PacketReceptionRatioRecorder(10, 30, "11p");
            hook = testCase.buildHook(hook,outputDirectory);
            invocation = testCase.makeInvocation( ...
                0.1, 0.05, [5; 10; 15; 25], ...
                ["correct"; "correct"; "error"; "blocked"], 100);

            hook = hook.invoke(invocation);
            hook.cleanup();

            values = readmatrix(fullfile( ...
                outputDirectory, ...
                "packet_reception_ratio_11p.csv"), ...
                FileType="text", Delimiter=",");
            testCase.verifyEqual( ...
                values, [ ...
                    10, 1, 0, 0, 1, 1; ...
                    20, 1, 1, 0, 2, 0.5; ...
                    30, 0, 0, 1, 1, 0], ...
                AbsTol=1e-12);
        end
    end

    methods (Access = private)
        function outputDirectory = makeOutputDirectory(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            outputDirectory = string(fixture.Folder);
        end

        function hook = buildHook(~,hook,outputDirectory)
            hook = hook.build( ...
                v2xsim.hook.dependencies.OutputDirectory( ...
                    outputDirectory));
        end

        function invocation = makeInvocation( ...
                ~, simulationTime, generationTime, distances, ...
                outcomes, awarenessRanges)
            distances = distances(:);
            outcomes = string(outcomes(:));
            receiverIds = (2:numel(distances) + 1).';
            transmitters = table( ...
                1, 1, 1, generationTime, ...
                VariableNames=[ ...
                    "TransmitterId", "Channel", "PacketType", ...
                    "GenerationTimeSeconds"]);
            links = table( ...
                ones(numel(distances), 1), receiverIds, ...
                distances, outcomes, ...
                VariableNames=[ ...
                    "TransmitterId", "ReceiverId", ...
                    "DistanceMeters", "Outcome"]);
            invocation = v2xsim.hook.invocations. ...
                AfterPacketFatesDeterminedInvocation( ...
                    simulationTime, "11p", numel(distances) + 1, ...
                    awarenessRanges, transmitters, links);
        end
    end
end

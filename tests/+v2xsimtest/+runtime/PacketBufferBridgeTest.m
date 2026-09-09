classdef PacketBufferBridgeTest < matlab.unittest.TestCase
    properties (TestParameter)
        Technology = {"11p","LTE","5G"}
    end
    methods (Test)
        function intermediateWifiFailureIsNotATerminalError(testCase)
            original = RandStream.getGlobalStream();
            testCase.addTeardown(@() RandStream.setGlobalStream(original));
            RandStream.setGlobalStream(RandStream("mt19937ar",Seed=7));
            [s,n,t,p,phy,sim,v,o,registry] = testCase.state("11p",2);
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            s.activeIDs11p = [3;1;2];
            s.indexInActiveIDs_of11pnodes = (1:3).';
            s.neighborsID11p = [1,2;2,3;1,3];
            s.awarenessID11p = zeros(3,2,2);
            s.awarenessID11p(3,:,1) = [1,0];
            s.awarenessID11p(3,:,2) = [1,3];
            s.vehicleState(:) = constants.V_STATE_11P_RX;
            s.pckTxOccurring(2) = 1;
            s.ITSNumberOfReplicas = 2*ones(3,1);
            n.idFromWhichRx11p = 2*ones(3,1);
            n.sinrAverage11p = [2;0;0];
            phy.LOS = ones(3);
            phy.sinrVector11p_LOS = 1;
            phy.sinrVector11p_NLOS = 1;
            t.timeNow = 0.1;
            [v,o,n,s] = updateKPI11p(2,3,t,s,p,n,sim,phy,v,o);
            testCase.verifyEqual(reshape(o.NcorrectlyTxBeaconsTOT,1,[]),[1,1]);
            testCase.verifyEqual(sum(o.NerrorsTOT,"all"),0);
            testCase.verifyEqual(reshape(o.NtxBeaconsTOT,1,[]),[1,1]);
            % Receiver state uses stable UE rows, not positions in activeIDs.
            testCase.verifyEqual(s.pckReceived(:,2),[1;0;0]);
            s.pckTxOccurring(2) = 2;
            n.sinrAverage11p(:) = 0;
            t.timeNow = 0.2;
            [~,o] = updateKPI11p(2,3,t,s,p,n,sim,phy,v,o);
            testCase.verifyEqual(reshape(o.NerrorsTOT,1,[]),[0,1]);
            testCase.verifyEqual(reshape(o.NtxBeaconsTOT,1,[]),[1,2]);
            hooks = registry.getHooks(v2xsim.hook.points.AfterPacketFatesDetermined);
            testCase.verifyEqual(nnz(hooks{1}.Invocations{1}.Links.Outcome == "error"),0);
            testCase.verifyEqual(nnz(hooks{1}.Invocations{2}.Links.Outcome == "error"),1);
        end

        function emptyCompletionDoesNotSignalAnotherApplicationPacket(testCase)
            [s,n,t,p,phy,sim,v,o,~] = testCase.state("LTE",1);
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o); %#ok<ASGLU>
            [s,n] = v2xsim.runtime.internal.completeEnginePacket(s,n,2,0.2); %#ok<ASGLU>
            testCase.verifyEqual(s.pckBuffer(2),0);
            testCase.verifyEqual(s.packetHeadSelectionTime(2),0);
        end

        function departureRetiresIdentitiesWithoutInventingReceiverFates(testCase)
            [s,n,t,p,phy,sim,v,o,registry] = testCase.state("LTE",3);
            for time = [0,0.1]
                t.timeNow = time;
                [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            end
            v2xsim.runtime.internal.retireDepartedPackets(2,t,s,p,phy,sim,v);
            hooks = registry.getHooks(v2xsim.hook.points.AfterPacketFatesDetermined);
            testCase.verifyNumElements(hooks{1}.Invocations,2);
            for index = 1:2
                fate = hooks{1}.Invocations{index};
                testCase.verifyEmpty(fate.Links);
                testCase.verifyTrue(fate.Transmitters.IsPacketComplete);
                testCase.verifyEqual(fate.Transmitters.PacketSequence,index);
            end
        end

        function queuedOverflowPreservesActiveRadioState(testCase,Technology)
            [s,n,t,p,phy,sim,v,o,registry] = testCase.state(Technology,2);
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            s.packetBuffers{2} = s.packetBuffers{2}.startAttempt();
            s.pckNextAttempt(2) = 2;
            s.pckTxOccurring(2) = 1;
            s.pckReceived(:,2) = [1;0;0];
            n.cumulativeSINR(:,2) = [10;20;30];
            t.timeNow = 0.1;
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            t.timeNow = 0.2;
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            testCase.verifyEqual([s.packetBuffers{2}.Packets.Sequence],[1,3]);
            testCase.verifyEqual(s.pckBuffer(2),2);
            testCase.verifyEqual(s.pckReceived(:,2),[1;0;0]);
            testCase.verifyEqual(n.cumulativeSINR(:,2),[10;20;30]);
            testCase.verifyEqual(s.pckNextAttempt(2),2);
            testCase.verifyEqual(reshape(o.NblockedTOT,1,[]),[1,2]);
            hooks = registry.getHooks(v2xsim.hook.points.AfterPacketFatesDetermined);
            fate = hooks{1}.Invocations{1};
            testCase.verifyEqual(fate.Transmitters.PacketSequence,2);
            testCase.verifyEqual(fate.Transmitters.GenerationTimeSeconds,0.1);
            testCase.verifyEqual(fate.Transmitters.AttemptNumber,0);
            testCase.verifyTrue(fate.Transmitters.IsPacketComplete);
        end

        function evictionBetweenAttemptsPreservesSuccessfulReceivers(testCase,Technology)
            [s,n,t,p,phy,sim,v,o,registry] = testCase.state(Technology,1);
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            s.pckNextAttempt(2) = 2;
            s.pckTxOccurring(2) = 1;
            s.pckReceived(:,2) = [1;0;0];
            n.cumulativeSINR(:,2) = 42;
            t.timeNow = 0.2;
            [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            hooks = registry.getHooks(v2xsim.hook.points.AfterPacketFatesDetermined);
            fate = hooks{1}.Invocations{1};
            testCase.verifyEqual(fate.Links.ReceiverId,3);
            testCase.verifyEqual(fate.Links.Outcome,"error");
            testCase.verifyEqual(fate.Transmitters.PacketSequence,1);
            testCase.verifyEqual(s.packetBuffers{2}.head().Sequence,2);
            testCase.verifyEqual(s.pckNextAttempt(2),1);
            testCase.verifyEqual(n.cumulativeSINR(:,2),zeros(3,1));
            testCase.verifyEqual(s.pckReceived(:,2),zeros(3,1));
            testCase.verifyEqual(sum(o.NblockedTOT,"all"),0);
            testCase.verifyEqual(reshape(o.NerrorsTOT,1,[]),[0,1]);
        end

        function sidelinkBlockRemovesOnlyHeadAndCannotInterruptAir(testCase)
            [s,n,t,p,phy,sim,v,o,~] = testCase.state("LTE",3);
            for time = [0,0.1,0.2]
                t.timeNow = time;
                [s,n,o] = v2xsim.runtime.internal.enqueueEnginePacket(2,t,s,n,p,phy,sim,v,o);
            end
            s.packetBuffers{2} = s.packetBuffers{2}.startAttempt();
            [protected,unchanged] = bufferOverflowLTE(2,t,p,s,phy,struct(),o,v,sim.stringCV2X);
            testCase.verifyEqual(protected.pckBuffer,s.pckBuffer);
            testCase.verifyEqual(unchanged,o);
            s.packetBuffers{2} = s.packetBuffers{2}.endAttempt();
            [s,o] = bufferOverflowLTE(2,t,p,s,phy,struct(),o,v,sim.stringCV2X);
            testCase.verifyEqual([s.packetBuffers{2}.Packets.Sequence],[2,3]);
            testCase.verifyEqual(s.pckBuffer(2),2);
            testCase.verifyEqual(reshape(o.NblockedTOT,1,[]),[1,2]);
        end
    end
    methods (Access = private)
        function [s,n,t,p,phy,sim,v,o,registry] = state(~,technology,capacity)
            s = struct(activeIDs=[3;1;2],activeIDs11p=(1:3).',activeIDsCV2X=(1:3).', ...
                vehicleState=ones(3,1),vehicleChannel=ones(3,1),pckType=ones(3,1), ...
                pckBuffer=zeros(3,1),pckNextAttempt=ones(3,1),pckTxOccurring=zeros(3,1), ...
                pckReceived=zeros(3),preambleAlreadyDetected=zeros(3),alreadyStartCBR=zeros(3), ...
                indexInRaw_earler=zeros(3,3,2),neighborsID11p=[2,3;1,3;1,2], ...
                neighborsIDLTE=[2,3;1,3;1,2]);
            s.packetBuffers = {v2xsim.packet.PacketBuffer("UE1",capacity); ...
                v2xsim.packet.PacketBuffer("UE2",capacity);v2xsim.packet.PacketBuffer("UE3",capacity)};
            if technology ~= "11p"
                s.vehicleState(:) = constants.V_STATE_LTE_TXRX;
            end
            n = struct(cumulativeSINR=zeros(3));
            t = struct(timeNow=0,addedToGenerationTime=zeros(3,1));
            p = struct(distanceReal=[0,10,190;10,0,200;190,200,0]);
            phy = struct(Raw=[100,300]);
            sim = struct(stringCV2X=technology);
            registry = v2xsim.hook.HookRegistry(v2xsim.hook.dependency.ServiceContainer());
            registry.register(v2xsimtest.legacy.fixture.InvocationCaptureHook(), ...
                v2xsim.hook.points.AfterPacketFatesDetermined);
            v = struct(maxID=3,hookDispatcher=registry.createDispatcher());
            o = struct();
            for count = ["Nblocked","Nerrors","NtxBeacons","NcorrectlyTxBeacons"]
                for suffix = ["11p","CV2X","TOT"]
                    o.(count+suffix) = zeros(1,1,2);
                end
            end
        end
    end
end

classdef PacketBufferTest < matlab.unittest.TestCase
    methods (Test)
        function validatesCapacityAndTime(testCase)
            for invalid = [0,-1,1.5,inf,nan,flintmax*2,1i]
                testCase.verifyError(@() v2xsim.packet.PacketBuffer("UE",invalid), ...
                    "v2xsim:packet:InvalidCapacity");
            end
            q = v2xsim.packet.PacketBuffer("UE",2);
            testCase.verifyError(@() q.enqueue(2,1,1),"v2xsim:packet:InvalidGenerationTime");
            testCase.verifyError(@() q.head(),"v2xsim:packet:EmptyBuffer");
            testCase.verifyError(@() q.removeHead(),"v2xsim:packet:EmptyBuffer");
            testCase.verifyError(@() q.endAttempt(),"v2xsim:packet:NotOnAir");
        end

        function protectsOnAirHeadAndReplacesOldestWaiting(testCase)
            q = v2xsim.packet.PacketBuffer("UE",3);
            q = q.enqueue(0,0,1);
            q = q.startAttempt();
            q = q.enqueue(0.1,0.1,2);
            q = q.enqueue(0.2,0.2,1);
            [q,dropped,headChanged] = q.enqueue(0.3,0.3,1);
            testCase.verifyEqual(dropped.Sequence,2);
            testCase.verifyEqual(dropped.PacketType,2);
            testCase.verifyFalse(headChanged);
            testCase.verifyEqual([q.Packets.Sequence],[1,3,4]);
            testCase.verifyEqual(q.head().GenerationTimeSeconds,0);
            testCase.verifyError(@() q.removeHead(),"v2xsim:packet:PacketOnAir");
            testCase.verifyError(@() q.startAttempt(),"v2xsim:packet:AlreadyOnAir");
            q = q.endAttempt();
            [q,dropped,headChanged] = q.enqueue(0.4,0.4,1);
            testCase.verifyEqual(dropped.Sequence,1);
            testCase.verifyTrue(headChanged);
            testCase.verifyEqual([q.Packets.Sequence],[3,4,5]);
        end

        function singleOnAirSlotDropsIncomingAndRetryKeepsTimestamp(testCase)
            q = v2xsim.packet.PacketBuffer("UE",1);
            q = q.enqueue(0,0.1,1);
            q = q.startAttempt();
            [q,dropped,changed] = q.enqueue(0.2,0.2,1);
            testCase.verifyEqual(dropped.Sequence,2);
            testCase.verifyFalse(changed);
            q = q.endAttempt();
            q = q.startAttempt();
            testCase.verifyEqual(q.head().GenerationTimeSeconds,0);
            testCase.verifyEqual(q.head().EnqueueTimeSeconds,0.1);
            q = q.endAttempt();
            [q,completed] = q.removeHead();
            testCase.verifyEqual(completed.Sequence,1);
            testCase.verifyEqual(q.Count,0);
        end

        function modelChecksRepeatedTransitionsAndConservation(testCase)
            % Independent list model; exercise wrap/reuse, eviction, retry,
            % and finalization without consuming the global random stream.
            for capacity = [1,2,3,64]
                q = v2xsim.packet.PacketBuffer("UE",capacity);
                model = [];
                finalized = [];
                next = 1;
                onAir = false;
                for step = 1:600
                    if mod(step,5) <= 2 || isempty(model)
                        removed = [];
                        if numel(model) == capacity
                            index = 1 + double(onAir);
                            if index > numel(model)
                                removed = next;
                            else
                                removed = model(index);
                                model(index) = []; %#ok<AGROW>
                            end
                        end
                        if isempty(removed) || removed ~= next
                            model(end+1) = next; %#ok<AGROW>
                        end
                        [q,dropped] = q.enqueue(step,step,1);
                        testCase.verifyEqual([dropped.Sequence],removed);
                        finalized = [finalized,removed]; %#ok<AGROW>
                        next = next + 1;
                    elseif ~onAir
                        q = q.startAttempt();
                        onAir = true;
                    else
                        q = q.endAttempt();
                        onAir = false;
                        if mod(step,7) ~= 0
                            [q,packet] = q.removeHead();
                            testCase.verifyEqual(packet.Sequence,model(1));
                            finalized(end+1) = model(1); %#ok<AGROW>
                            model(1) = [];
                        end
                    end
                    testCase.verifyEqual(reshape([q.Packets.Sequence],1,[]),reshape(model,1,[]));
                    testCase.verifyEqual(q.OnAir,onAir);
                    testCase.verifyEqual(sort([finalized,model]),1:next-1);
                    testCase.verifyLessThanOrEqual(q.Count,capacity);
                end
            end
        end

        function clearsLifecycleWithoutReusingIdentityAndHasValueSemantics(testCase)
            q = v2xsim.packet.PacketBuffer("UE",flintmax);
            q = q.enqueue(0,0,1);
            copy = q;
            q = q.startAttempt();
            q = q.clear();
            q = q.enqueue(1,1,1);
            testCase.verifyEqual(q.Count,1);
            testCase.verifyEqual(q.head().Sequence,2);
            testCase.verifyEqual(copy.head().Sequence,1);
            testCase.verifyFalse(copy.OnAir);
        end
    end
end

classdef AllocationKernelTest < matlab.unittest.TestCase
    %ALLOCATIONKERNELTEST Behavioral tests for pure allocation kernels.

    methods (Test)
        function reuseDistanceSeparatesNearbyUes(testCase)
            stream = RandStream("mt19937ar","Seed",11);
            distance = [0 5 50; 5 0 45; 50 45 0];

            [resources,decisions] = ...
                v2xsim.resource.algorithm.assignByReuseDistance( ...
                    NaN(3,1),zeros(0,1),distance,2,10,stream);

            testCase.verifyEqual(decisions,[1;2;3]);
            testCase.verifyNotEqual(resources(1),resources(2));
            testCase.verifyTrue(all(ismember(resources,[1 2])));
        end

        function reuseDistanceLeavesUeBlockedWhenPoolExhausted(testCase)
            stream = RandStream("mt19937ar","Seed",4);
            distance = [0 1; 1 0];

            resources = ...
                v2xsim.resource.algorithm.assignByReuseDistance( ...
                    NaN(2,1),zeros(0,1),distance,1,10,stream);

            testCase.verifyEqual(nnz(isnan(resources)),1);
        end

        function maximumReuseProcessesNewAndScheduledRows(testCase)
            stream = RandStream("mt19937ar","Seed",7);
            distance = [0 10 30; 10 0 20; 30 20 0];

            [resources,decisions] = ...
                v2xsim.resource.algorithm. ...
                    assignByMaximumReuseDistance( ...
                        [1;NaN;2],3,distance,[2 2],stream);

            testCase.verifyEqual(sort(decisions),[2;3]);
            testCase.verifyTrue(all(isfinite(resources)));
            testCase.verifyTrue(all(resources >= 1 & resources <= 4));
        end

        function minimumPowerCanRemoveKnownShadowing(testCase)
            streamA = RandStream("mt19937ar","Seed",3);
            streamB = RandStream("mt19937ar","Seed",3);
            power = [0 10 1; 10 0 2; 1 2 0];
            shadowing = zeros(3);

            resultA = v2xsim.resource.algorithm. ...
                assignByMinimumReceivedPower( ...
                    [1;2;NaN],3,power,shadowing,false,[2 2],streamA);
            resultB = v2xsim.resource.algorithm. ...
                assignByMinimumReceivedPower( ...
                    [1;2;NaN],3,power,shadowing,true,[2 2],streamB);

            testCase.verifyEqual(resultA,resultB);
            testCase.verifyTrue(all(isfinite(resultA)));
        end

        function randomAllocationUsesOnlyEligibleResources(testCase)
            allowed = logical([1 0 1 0; 0 1 0 0; 0 0 0 0]);
            stream = RandStream("mt19937ar","Seed",12);

            [resources,decisions,blocked] = ...
                v2xsim.resource.algorithm.assignRandomResources( ...
                    allowed,2,stream);

            testCase.verifyEqual(decisions,[1;2;3]);
            testCase.verifyEqual(sort(resources(1,:)),[1 3]);
            testCase.verifyEqual(resources(2,1),2);
            testCase.verifyTrue(isnan(resources(2,2)));
            testCase.verifyEqual(blocked,3);
        end

        function randomAllocationIsStreamDeterministic(testCase)
            streamA = RandStream("mt19937ar","Seed",99);
            streamB = RandStream("mt19937ar","Seed",99);
            allowed = true(10,20);

            resultA = v2xsim.resource.algorithm.assignRandomResources( ...
                allowed,2,streamA);
            resultB = v2xsim.resource.algorithm.assignRandomResources( ...
                allowed,2,streamB);

            testCase.verifyEqual(resultA,resultB);
        end

        function randomAllocationUsesDistinctTimeSlotsForHarq( ...
                testCase)
            stream = RandStream("mt19937ar","Seed",21);

            resources = ...
                v2xsim.resource.algorithm.assignRandomResources( ...
                    true(1,6),2,stream,3);

            selectedTimeSlots = ceil(resources / 3);
            testCase.verifyEqual( ...
                numel(unique(selectedTimeSlots)),2);
        end

        function randomAllocationLeavesMissingHarqAttemptUnassigned( ...
                testCase)
            stream = RandStream("mt19937ar","Seed",21);

            resources = ...
                v2xsim.resource.algorithm.assignRandomResources( ...
                    logical([1 1 0 0]),2,stream,2);

            testCase.verifyTrue(isfinite(resources(1)));
            testCase.verifyTrue(isnan(resources(2)));
        end

        function orderedAllocationUsesFrequencyFirstGridOrder(testCase)
            [resources,decisions] = ...
                v2xsim.resource.algorithm.assignByPositionOrder( ...
                    [30;10;20],[2 2]);

            testCase.verifyEqual(resources,[2;1;3]);
            testCase.verifyEqual(decisions,[1;2;3]);
        end

        function kernelsAcceptEmptyUeSets(testCase)
            stream = RandStream("mt19937ar","Seed",1);

            [resources,decisions,blocked] = ...
                v2xsim.resource.algorithm.assignRandomResources( ...
                    false(0,4),1,stream);

            testCase.verifySize(resources,[0 1]);
            testCase.verifyEmpty(decisions);
            testCase.verifyEmpty(blocked);
        end
    end
end

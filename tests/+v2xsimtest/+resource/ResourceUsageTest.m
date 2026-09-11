classdef ResourceUsageTest < matlab.unittest.TestCase
    %RESOURCEUSAGETEST UPSTREAM_REQUIREMENTS sections 5 and 6: pure metrics.
    properties (TestParameter)
        selectableMask = {[true true],[false false]}
    end
    methods (Test)
        function maskedOccupancyMatchesHandCalculatedContract(testCase)
            [values,occupancy] = v2xsim.resource.metrics.resourceUsage( ...
                [1;1;3;nan],[true false true true],[0 0;10 0;200 0;400 0]);
            expected = struct(VehicleCount=4,AssignedVehicles=3, ...
                AvailableResources=3,OccupiedResources=2,OccupiedFraction=2/3, ...
                UsersPerOccupiedResource=1.5,MaximumOccupancy=2, ...
                SharingVehicles=2,SharingFraction=0.5,CoResourcePairs=1, ...
                LocalPairs=1,LocalCoResourcePairs=1, ...
                MeanCoResourceSeparationMeters=10, ...
                MinimumCoResourceSeparationMeters=10,GeometryCoverage=1);
            testCase.verifyEqual(values,expected);
            testCase.verifyEqual(occupancy,[2;1;0]);
        end

        function rejectsIneligibleAndInvalidNativeIds(testCase)
            for id = [0 -1 1.5 2 5]
                testCase.verifyError(@() v2xsim.resource.metrics.resourceUsage( ...
                    id,[true false true true],[0 0]), ...
                    "v2xsim:resource:UsageEligibility");
            end
            testCase.verifyError(@() v2xsim.resource.metrics.resourceUsage( ...
                [1;3],[true false true],zeros(1,2)),"v2xsim:resource:UsageRows");
        end

        function noSharingHasDefinedEmptySeparation(testCase)
            values = v2xsim.resource.metrics.resourceUsage([1;2;nan],true(1,3),zeros(3,2));
            testCase.verifyEqual(values.CoResourcePairs,0);
            testCase.verifyEqual(values.SharingVehicles,0);
            testCase.verifyEqual(values.SharingFraction,0);
            testCase.verifyEqual(values.LocalPairs,3);
            testCase.verifyEqual(values.LocalCoResourcePairs,0);
            testCase.verifyTrue(isnan(values.MeanCoResourceSeparationMeters));
            testCase.verifyEqual(values.MinimumCoResourceSeparationMeters,Inf);
        end

        function missingGeometryPreservesOccupancyAndAllAssignmentPairs(testCase)
            [values,occupancy] = v2xsim.resource.metrics.resourceUsage( ...
                ones(4,1),true(1,2),[0 0;3 4;nan 0;0 Inf]);
            testCase.verifyEqual(occupancy,[4;0]);
            testCase.verifyEqual(values.AssignedVehicles,4);
            testCase.verifyEqual(values.SharingVehicles,4);
            testCase.verifyEqual(values.CoResourcePairs,6);
            testCase.verifyEqual(values.GeometryCoverage,0.5);
            testCase.verifyEqual(values.LocalPairs,1);
            testCase.verifyEqual(values.LocalCoResourcePairs,1);
            testCase.verifyEqual(values.MeanCoResourceSeparationMeters,5);
            testCase.verifyEqual(values.MinimumCoResourceSeparationMeters,5);
        end

        function emptyAndAssignedSingletonPopulations(testCase)
            [empty,occupancy] = v2xsim.resource.metrics.resourceUsage(zeros(0,1),true(1,2),zeros(0,2));
            testCase.verifyEqual(occupancy,[0;0]);
            testCase.verifyEqual(empty.VehicleCount,0);
            testCase.verifyEqual(empty.GeometryCoverage,0);
            testCase.verifyEqual(empty.MaximumOccupancy,0);
            single = v2xsim.resource.metrics.resourceUsage(2,true(1,2),[0 0]);
            testCase.verifyEqual(single.VehicleCount,1);
            testCase.verifyEqual(single.AssignedVehicles,1);
            testCase.verifyEqual(single.GeometryCoverage,1);
            testCase.verifyEqual(single.CoResourcePairs,0);
        end

        function unassignedSingletonHasZeroOccupancy(testCase,selectableMask)
            [masked,occupancy] = v2xsim.resource.metrics.resourceUsage(nan,selectableMask,[0 0]);
            testCase.verifyEqual(occupancy,zeros(nnz(selectableMask),1));
            testCase.verifyEqual(masked.AvailableResources,nnz(selectableMask));
            testCase.verifyEqual(masked.MaximumOccupancy,0);
            testCase.verifyEqual(masked.OccupiedFraction,0);
            testCase.verifyEqual(masked.UsersPerOccupiedResource,0);
            testCase.verifyTrue(isnan(masked.MeanCoResourceSeparationMeters));
            testCase.verifyEqual(masked.MinimumCoResourceSeparationMeters,Inf);
        end

        function geometryUsesEuclideanDistanceAndInclusiveRange(testCase)
            % 90/120 forms a 150 m diagonal; longitudinal-only geometry
            % would incorrectly include the third pair. No periodic wrap.
            values = v2xsim.resource.metrics.resourceUsage(ones(3,1),true,[0 0;90 120;1990 0]);
            distances = [150,hypot(1900,120),1990];
            testCase.verifyEqual(values.LocalPairs,1);
            testCase.verifyEqual(values.LocalCoResourcePairs,1);
            testCase.verifyEqual(values.CoResourcePairs,3);
            testCase.verifyEqual(values.MeanCoResourceSeparationMeters,mean(distances),AbsTol=1e-12);
            testCase.verifyEqual(values.MinimumCoResourceSeparationMeters,150);
            values = v2xsim.resource.metrics.resourceUsage(ones(2,1),true,[0 0;3 4],4.99);
            testCase.verifyEqual(values.LocalPairs,0);
        end

        function relabelingAndRowPermutationPreserveMetricsWithoutRandomDraws(testCase)
            stream = RandStream.getGlobalStream();
            state = stream.State;
            testCase.addTeardown(@() restoreStream(stream,state));
            xy = [0 0;10 0;200 0;400 0];
            [reference,counts] = v2xsim.resource.metrics.resourceUsage([1;1;3;nan],[true false true true],xy);
            [actual,relabeled] = v2xsim.resource.metrics.resourceUsage([2;nan;4;4],[false true true true],xy([3 4 1 2],:));
            testCase.verifyEqual(actual,reference);
            testCase.verifyEqual(sort(relabeled),sort(counts));
            testCase.verifyEqual(RandStream.getGlobalStream(),stream);
            testCase.verifyEqual(stream.State,state);
        end
    end
end

function restoreStream(stream,state)
RandStream.setGlobalStream(stream);
stream.State = state;
end

classdef EffectiveCv2xTransmissionCountTest < matlab.unittest.TestCase
    %EFFECTIVECV2XTRANSMISSIONCOUNTTEST Tests partial HARQ projection.

    methods (TestClassSetup)
        function addLegacyResourcePath(testCase)
            projectRoot = fileparts(fileparts(fileparts(fileparts( ...
                mfilename("fullpath")))));
            resourcePath = fullfile( ...
                projectRoot,"old_src", ...
                "MatFilesResourceAllocationCV2X");
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));
            addpath(resourcePath);
        end
    end

    methods (Test)
        function testCountIsLimitedByPolicyAndFiniteAssignments(testCase)
            stationManagement = struct( ...
                cv2xNumberOfReplicas=[1;2;2], ...
                BRid=[1 2;3 -1;-1 -1]);

            actual = effectiveCv2xTransmissionCount( ...
                stationManagement,[1;2;3]);

            testCase.verifyEqual(actual,[1;1;0]);
        end
    end
end

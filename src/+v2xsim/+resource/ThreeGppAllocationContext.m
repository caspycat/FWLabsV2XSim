classdef ThreeGppAllocationContext < ...
        v2xsim.resource.AutonomousAllocationContext
    %THREEGPPALLOCATIONCONTEXT Per-UE MAC facts for Mode 4/Mode 2.

    properties (SetAccess = immutable)
        FirstTransmissionMask (:,1) logical
        SkippedReservedTransmissionMask (:,1) logical
        PacketPendingMask (:,1) logical
        TransmissionCount (:,1) double
    end

    methods
        function obj = ThreeGppAllocationContext( ...
                networkSliceId,ueIds,currentSlot,newPacketMask, ...
                eligibilityMask,sensingSnapshot,firstTransmissionMask, ...
                skippedReservedTransmissionMask,packetPendingMask, ...
                transmissionCount,selectionOriginSlot)
            arguments (Input)
                networkSliceId (1,1) v2xsim.network.NetworkSliceId
                ueIds string {mustBeVector}
                currentSlot (1,1) double ...
                    {mustBeInteger,mustBeNonnegative}
                newPacketMask logical {mustBeVector}
                eligibilityMask (:,:) logical
                sensingSnapshot (1,1) v2xsim.resource.SensingSnapshot
                firstTransmissionMask logical {mustBeVector}
                skippedReservedTransmissionMask logical {mustBeVector}
                packetPendingMask logical {mustBeVector}
                transmissionCount double ...
                    {mustBeVector,mustBeInteger,mustBePositive}
                selectionOriginSlot double = []
            end

            obj = obj@v2xsim.resource.AutonomousAllocationContext( ...
                networkSliceId,ueIds,currentSlot,newPacketMask, ...
                eligibilityMask,sensingSnapshot,selectionOriginSlot);

            ueCount = numel(obj.UeIds);
            if numel(firstTransmissionMask) ~= ueCount || ...
                    numel(skippedReservedTransmissionMask) ~= ueCount || ...
                    numel(packetPendingMask) ~= ueCount || ...
                    numel(transmissionCount) ~= ueCount
                error( ...
                    "v2xsim:resource:ContextRowCountMismatch", ...
                    "ThreeGpp MAC facts must contain one value per UE.");
            end

            obj.FirstTransmissionMask = firstTransmissionMask(:);
            obj.SkippedReservedTransmissionMask = ...
                skippedReservedTransmissionMask(:);
            obj.PacketPendingMask = packetPendingMask(:);
            obj.TransmissionCount = transmissionCount(:);
        end
    end
end

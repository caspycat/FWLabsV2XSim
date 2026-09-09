classdef PacketBuffer
    %PACKETBUFFER Value-owned FIFO of outstanding packets for one stable UE.
    % Capacity includes the head during transmission. Only an on-air head
    % is protected from replacement; a head awaiting a retry is eligible.
    properties (SetAccess = private)
        UeId (1,1) string
        CapacityPackets (1,1) double
        OnAir (1,1) logical = false
        NextSequence (1,1) double = 1
        Packets (1,:) struct = struct('Sequence',{}, ...
            'GenerationTimeSeconds',{},'EnqueueTimeSeconds',{},'PacketType',{})
    end
    properties (Dependent)
        Count
    end
    methods
        function obj = PacketBuffer(ueId,capacity)
            arguments
                ueId (1,1) string {mustBeNonmissing,mustBeNonzeroLengthText}
                capacity (1,1) double
            end
            if ~isreal(capacity) || ~isfinite(capacity) || capacity < 1 || ...
                    fix(capacity) ~= capacity || capacity > flintmax
                error("v2xsim:packet:InvalidCapacity", ...
                    "Capacity must be a finite positive exactly representable integer.");
            end
            obj.UeId = ueId;
            obj.CapacityPackets = capacity;
        end

        function count = get.Count(obj)
            count = numel(obj.Packets);
        end

        function [obj,dropped,headChanged] = enqueue(obj,generationTime,enqueueTime,packetType)
            arguments
                obj (1,1) v2xsim.packet.PacketBuffer
                generationTime (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                enqueueTime (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                packetType (1,1) double {mustBeReal,mustBeFinite,mustBeInteger,mustBePositive}
            end
            if generationTime > enqueueTime
                error("v2xsim:packet:InvalidGenerationTime", ...
                    "Generation cannot follow admission.");
            end
            if obj.NextSequence >= flintmax
                error("v2xsim:packet:SequenceExhausted", ...
                    "Packet sequence exhausted for UE %s.",obj.UeId);
            end
            packet = struct(Sequence=obj.NextSequence, ...
                GenerationTimeSeconds=generationTime, ...
                EnqueueTimeSeconds=enqueueTime,PacketType=packetType);
            obj.NextSequence = obj.NextSequence + 1;
            dropped = obj.Packets([]);
            headChanged = obj.Count == 0;
            if obj.Count == obj.CapacityPackets
                index = 1 + double(obj.OnAir);
                if index > obj.Count
                    dropped = packet;
                    return
                end
                dropped = obj.Packets(index);
                obj.Packets(index) = [];
                headChanged = index == 1;
            end
            obj.Packets(end+1) = packet;
        end

        function packet = head(obj)
            if obj.Count == 0
                error("v2xsim:packet:EmptyBuffer","No outstanding packet.");
            end
            packet = obj.Packets(1);
        end

        function obj = startAttempt(obj)
            obj.head();
            if obj.OnAir
                error("v2xsim:packet:AlreadyOnAir","An attempt is already on air.");
            end
            obj.OnAir = true;
        end

        function obj = endAttempt(obj)
            if ~obj.OnAir
                error("v2xsim:packet:NotOnAir","No attempt is on air.");
            end
            obj.OnAir = false;
        end

        function [obj,packet] = removeHead(obj)
            packet = obj.head();
            if obj.OnAir
                error("v2xsim:packet:PacketOnAir","Cannot remove an on-air packet.");
            end
            obj.Packets(1) = [];
        end

        function obj = clear(obj)
            % Preserve sequences across a departure/re-entry of the same UE.
            obj.Packets = obj.Packets([]);
            obj.OnAir = false;
        end
    end
end

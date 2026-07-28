function transmissionCount = effectiveCv2xTransmissionCount( ...
        stationManagement,ueIds)
%EFFECTIVECV2XTRANSMISSIONCOUNT Attempts supported by policy and assignment.

arguments (Input)
    stationManagement (1,1) struct
    ueIds double {mustBeInteger,mustBePositive}
end

ueIds = ueIds(:);
configuredCount = ...
    stationManagement.cv2xNumberOfReplicas(ueIds);
assignedCount = sum(stationManagement.BRid(ueIds,:) > 0,2);
transmissionCount = min(configuredCount(:),assignedCount);
end

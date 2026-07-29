function [positionManagement,stationManagement] = computeDistance( ...
        ~,simValues,stationManagement,positionManagement)
% Function derived dividing previous version in computeDistance and
% computeNeighbors (version 5.6.0)


% Compute distance matrix
positionManagement.distanceReal = sqrt((positionManagement.XvehicleReal - positionManagement.XvehicleReal').^2+(positionManagement.YvehicleReal - positionManagement.YvehicleReal').^2);
% Controller geometry must always use the final apparent position chain.
% Whether legacy delay/error parameters are enabled is not evidence that
% the modular position-error chain is an identity transform.
positionManagement.distanceEstimated = sqrt( ...
    (simValues.XvehicleEstimated - ...
        simValues.XvehicleEstimated').^2 + ...
    (simValues.YvehicleEstimated - ...
        simValues.YvehicleEstimated').^2);

end

function [simValues,stationManagement] = ...
        synchronizeResourceAllocation(simValues,stationManagement)
%SYNCHRONIZERESOURCEALLOCATION Reconcile named C-V2X UE lifecycle state.

allocator = simValues.resourceAllocator;
activeIds = stationManagement.activeIDsCV2X(:);
ueIds = simValues.world.UeIds(activeIds);
allocator = allocator.synchronizeUes(ueIds);
sensingHistory = simValues.sensingHistory.synchronizeUes(ueIds);
stationManagement.sensingMatrixCV2X(:,:,activeIds) = ...
    sensingHistory.EnergyHistory;
sensingSnapshot = sensingHistory.snapshot(false);
stationManagement.knownUsedMatrixCV2X(:,activeIds) = ...
    sensingSnapshot.ReservedMask.';

previousReservations = simValues.resourceAllocationResult.Reservations;
previousReservations = previousReservations( ...
    ismember(previousReservations.UeId,ueIds),:);
result = v2xsim.resource.ResourceAllocationResult( ...
    allocator.Grid.NetworkSliceId,allocator.Assignments, ...
    strings(0,1),strings(0,1),strings(0,1), ...
    previousReservations);
stationManagement = projectResourceAllocation( ...
    stationManagement,simValues,result,allocator.Grid);

simValues.resourceAllocator = allocator;
simValues.sensingHistory = sensingHistory;
simValues.resourceAllocationResult = result;
end

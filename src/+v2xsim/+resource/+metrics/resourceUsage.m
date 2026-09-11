function [values,occupancy] = resourceUsage(resourceIds,mask,positions,localRange)
%RESOURCEUSAGE Pure occupancy and true-geometry statistics for one snapshot.
% A resource shared at large separation is not necessarily a harmful reuse.
arguments
    resourceIds (:,1) double
    mask (1,:) logical
    positions (:,2) double
    localRange (1,1) double {mustBePositive,mustBeFinite} = 150
end
assert(size(positions,1)==numel(resourceIds), ...
    "v2xsim:resource:UsageRows","Position and assignment rows must agree.");
valid = isfinite(resourceIds);
ids = resourceIds(valid);
assert(all(ids>=1 & ids<=numel(mask) & ids==fix(ids)) && all(mask(ids)), ...
    "v2xsim:resource:UsageEligibility","Assignments must use selectable resources.");
% Selecting no values from a scalar can produce a 0-by-0 array. Preserve
% the subscript column required by accumarray, including an unassigned UE.
occupancy = accumarray(ids(:),1,[numel(mask),1]);
occupancy = occupancy(mask);
n = numel(resourceIds); assigned = numel(ids); used = nnz(occupancy);
pairs = sum(occupancy.*(occupancy-1)/2);
sharing = sum(occupancy(occupancy>1));
distance = hypot(positions(:,1)-positions(:,1)',positions(:,2)-positions(:,2)');
known = all(isfinite(positions),2);
pairMask = triu(known & known',1);
local = pairMask & distance<=localRange;
shared = pairMask & valid & valid' & resourceIds==resourceIds';
separation = distance(shared);
values = struct(VehicleCount=n,AssignedVehicles=assigned, ...
    AvailableResources=nnz(mask),OccupiedResources=used, ...
    OccupiedFraction=used/max(1,nnz(mask)), ...
    UsersPerOccupiedResource=assigned/max(1,used), ...
    MaximumOccupancy=max([0;occupancy]),SharingVehicles=sharing, ...
    SharingFraction=sharing/max(1,n),CoResourcePairs=pairs, ...
    LocalPairs=nnz(local),LocalCoResourcePairs=nnz(local & shared), ...
    MeanCoResourceSeparationMeters=mean(separation), ...
    MinimumCoResourceSeparationMeters=min([Inf;separation]), ...
    GeometryCoverage=nnz(known)/max(1,n));
end

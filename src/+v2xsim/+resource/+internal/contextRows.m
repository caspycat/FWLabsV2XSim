function rows = contextRows(allocatorUeIds,contextUeIds)
%CONTEXTROWS Map allocator row identity to context row identity.
[found,rows] = ismember(allocatorUeIds,contextUeIds);
if ~all(found)
    error( ...
        "v2xsim:resource:AllocatorUeSetMismatch", ...
        "Allocation context does not contain every allocator UE.");
end
end

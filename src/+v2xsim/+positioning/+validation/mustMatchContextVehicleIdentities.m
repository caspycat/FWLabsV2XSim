function mustMatchContextVehicleIdentities( ...
        inputPositions, actualPositions)
%MUSTMATCHCONTEXTVEHICLEIDENTITIES Require the same vehicle set.

inputVehicleIds = string(inputPositions.Properties.RowNames);
actualVehicleIds = string(actualPositions.Properties.RowNames);
if ~isequal(sort(inputVehicleIds), sort(actualVehicleIds))
    error( ...
        "v2xsim:positioning:ContextVehicleSetMismatch", ...
        "Apparent and actual positions must identify the same vehicles.");
end
end

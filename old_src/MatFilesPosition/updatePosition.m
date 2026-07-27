function [indexNewVehicles,indexOldVehicles,indexOldVehiclesToOld, ...
        IDvehicleExit,positionManagement,simValues] = updatePosition( ...
        time,IDvehicle,updateInterval,positionManagement,simValues, ...
        ~,~)
%UPDATEPOSITION Step the World and project it into legacy matrices.
%   Dense legacy indices follow World.UeIds. Traffic advances vehicles,
%   while fixed RSU positions remain unchanged.

world = simValues.world;
if world.TrafficScenario.IS_VEHICLE_COUNT_DYNAMIC
    error('v2xsim:legacy:DynamicVehicleCountUnsupported', ...
        ['The legacy simulator requires a fixed vehicle count. ', ...
        'Use a Scenario whose IS_VEHICLE_COUNT_DYNAMIC flag is false.']);
end

[world,~] = world.step(updateInterval);
simValues.world = world;

expectedIDs = (1:numel(world.UeIds)).';
if ~isequal(IDvehicle(:),expectedIDs)
    error('v2xsim:legacy:InvalidDenseUeIds', ...
        ['The legacy active IDs must be the dense indices of ', ...
        'World.UeIds.']);
end

positionManagement = v2xsim.legacy.projectWorldToPositionManagement( ...
    world,positionManagement);

% All currently supported Scenarios have a fixed vehicle set, so every
% UE remains at the same position in the active-ID vectors.
indexNewVehicles = [];
indexOldVehicles = (1:numel(IDvehicle)).';
indexOldVehiclesToOld = indexOldVehicles;
IDvehicleExit = [];

vehicleKinematics = ...
    world.TrafficScenario.VehicleKinematics( ...
        cellstr(world.VehicleIds), ...
        ["X","Y","vX","vY","aX","aY"]);
dispatchAfterVehicleKinematicsUpdated( ...
    simValues,time,vehicleKinematics);
end

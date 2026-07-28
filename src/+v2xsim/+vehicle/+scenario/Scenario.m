classdef (Abstract, HandleCompatible) Scenario
    %SCENARIO ABS for Traffic Scenarios
    % These are value classes by default – only upgrade to a handle class
    % if dependent on external sources such as TCP Sockets

    properties (Abstract, Constant)
        IS_VEHICLE_COUNT_DYNAMIC (1, 1) logical
        CAN_STEP_BACKWARD (1, 1) logical
        PROVIDES_VELOCITY (1, 1) logical
        PROVIDES_ACCELERATION (1, 1) logical
    end

    properties (SetAccess = private)
        VehicleKinematics table ...
            {v2xsim.vehicle.scenario.validation.mustBe2DKinematicsTable} = ...
            table( ...
                zeros(0, 1), zeros(0, 1), ...
                zeros(0, 1), zeros(0, 1), ...
                zeros(0, 1), zeros(0, 1), ...
                VariableNames=["X", "Y", "vX", "vY", "aX", "aY"])
    end

    methods (Access = protected)
        function obj = Scenario(initialVehicleKinematics)
            arguments (Input)
                initialVehicleKinematics table ...
                    {v2xsim.vehicle.scenario.validation.mustBe2DKinematicsTable}
            end

            obj.validateVehicleRowNames(initialVehicleKinematics);
            obj.VehicleKinematics = initialVehicleKinematics;
        end

    end
    
    methods (Sealed)
        function [obj, vehicleLifecycleTransitions] = step(obj, dt)
            arguments (Input)
                obj (1, 1)
                dt (1, 1) ...
                    {mustBeFloat, mustBeReal, mustBeFinite, mustBeNonzero}
            end

            obj.validateBeforeStep(dt);
            previousVehicleKinematics = obj.VehicleKinematics;

            [obj, nextVehicleKinematics, vehicleLifecycleTransitions] = ...
                obj.doStep(dt);

            obj.validateAfterStep( ...
                previousVehicleKinematics, ...
                nextVehicleKinematics, ...
                vehicleLifecycleTransitions);

            obj.VehicleKinematics = nextVehicleKinematics;
        end
    end

    methods (Access = private)
        function validateBeforeStep(obj, dt)
            arguments (Input)
                obj (1, 1)
                dt (1, 1) ...
                    {mustBeFloat, mustBeReal, mustBeFinite, mustBeNonzero}
            end
            % Validate input arguments of the abstract method,
            % because MATLAB doesn't let us add validation functions for
            % abstract methods

            % Assert that the user does not attempt to step backwards in
            % time if the scenario class defines it cannot step backwards
            if ~obj.CAN_STEP_BACKWARD && dt < 0
                errorId = "v2xsim:scenario:StepBackInTimeNotAllowed";
                errorMessage = ...
                    "Attempted to step %g seconds for a scenario that " + ...
                    "does not allow stepping backwards in time.";
                error(errorId, errorMessage, dt);
            end
        end

        function validateAfterStep(obj, previousVehicleKinematics, ...
                nextVehicleKinematics, vehicleLifecycleTransitions)
            v2xsim.vehicle.scenario.validation.mustBe2DKinematicsTable( ...
                nextVehicleKinematics);
            v2xsim.vehicle.scenario.validation.mustBeVehicleLifecycleTransitionTable( ...
                vehicleLifecycleTransitions);

            obj.validateVehicleRowNames(nextVehicleKinematics);
            obj.validateTransitionRowNames(vehicleLifecycleTransitions);

            import v2xsim.vehicle.scenario.VehicleLifecycleTransition;
            previousRowNames = string( ...
                previousVehicleKinematics.Properties.RowNames);
            previousRowNames = previousRowNames(:);
            nextRowNames = string( ...
                nextVehicleKinematics.Properties.RowNames);
            nextRowNames = nextRowNames(:);

            % A static scenario must preserve the vehicle identity set.
            % Perform this check before the general transition checks to
            % retain the more specific static-scenario diagnostic.
            if ~obj.IS_VEHICLE_COUNT_DYNAMIC
                hasSameVehicles = obj.haveSameIdentities( ...
                    previousRowNames, nextRowNames);
                if ~hasSameVehicles
                    errorId = "v2xsim:scenario:VehicleSetChanged";
                    errorMessage = ...
                        "A scenario with a static vehicle count must " + ...
                        "preserve its set of vehicle row names.";
                    error(errorId, errorMessage);
                end
            end

            % Transition rows describe the union of identities immediately
            % before and after the step. This retains exited identities even
            % though they no longer have a next-kinematics row.
            transitionRowNames = string( ...
                vehicleLifecycleTransitions.Properties.RowNames);
            transitionRowNames = transitionRowNames(:);
            expectedTransitionRowNames = unique( ...
                [previousRowNames; nextRowNames], "stable");
            if ~obj.haveSameIdentities( ...
                    transitionRowNames, expectedTransitionRowNames)
                errorId = ...
                    "v2xsim:scenario:LifecycleTransitionSetMismatch";
                errorMessage = ...
                    "Lifecycle transition row names must equal the " + ...
                    "union of the previous and next vehicle identities.";
                error(errorId, errorMessage);
            end

            expectedEntered = setdiff( ...
                nextRowNames, previousRowNames, "stable");
            expectedExited = setdiff( ...
                previousRowNames, nextRowNames, "stable");
            expectedUnchanged = intersect( ...
                previousRowNames, nextRowNames, "stable");
            actualEntered = transitionRowNames( ...
                vehicleLifecycleTransitions.Transition == ...
                VehicleLifecycleTransition.Entered);
            actualExited = transitionRowNames( ...
                vehicleLifecycleTransitions.Transition == ...
                VehicleLifecycleTransition.Exited);
            actualUnchanged = transitionRowNames( ...
                vehicleLifecycleTransitions.Transition == ...
                VehicleLifecycleTransition.Unchanged);
            transitionsAreExact = ...
                obj.haveSameIdentities(actualEntered, expectedEntered) && ...
                obj.haveSameIdentities(actualExited, expectedExited) && ...
                obj.haveSameIdentities( ...
                    actualUnchanged, expectedUnchanged);
            if ~transitionsAreExact
                if ~obj.IS_VEHICLE_COUNT_DYNAMIC
                    errorId = "v2xsim:scenario:DynamicVehicleCountNotAllowed";
                    errorMessage = ...
                        "A scenario with a static vehicle count cannot " + ...
                        "report entered or exited vehicles.";
                else
                    errorId = ...
                        "v2xsim:scenario:LifecycleTransitionMismatch";
                    errorMessage = ...
                        "Lifecycle transitions must report Entered for " + ...
                        "next-only identities, Exited for previous-only " + ...
                        "identities, and Unchanged for surviving identities.";
                end
                error(errorId, errorMessage);
            end
        end

        function validateVehicleRowNames(~, vehicleKinematics)
            rowNames = vehicleKinematics.Properties.RowNames;
            if height(vehicleKinematics) > 0 && ...
                    (isempty(rowNames) || ...
                    numel(rowNames) ~= height(vehicleKinematics))
                errorId = "v2xsim:scenario:MissingVehicleRowNames";
                errorMessage = ...
                    "VehicleKinematics must have one unique row name " + ...
                    "for every vehicle.";
                error(errorId, errorMessage);
            end
        end

        function validateTransitionRowNames(~, vehicleLifecycleTransitions)
            rowNames = vehicleLifecycleTransitions.Properties.RowNames;
            if height(vehicleLifecycleTransitions) > 0 && ...
                    (isempty(rowNames) || ...
                    numel(rowNames) ~= height(vehicleLifecycleTransitions))
                errorId = "v2xsim:scenario:MissingTransitionRowNames";
                errorMessage = ...
                    "VehicleLifecycleTransitions must have one unique " + ...
                    "row name for every transition.";
                error(errorId, errorMessage);
            end
        end

        function result = haveSameIdentities(~, left, right)
            result = isequal(sort(left(:)), sort(right(:)));
        end
    end

    methods (Abstract, Access = protected)
        % The implementation of the step function
        % Return the updated object, candidate vehicle kinematics, and a
        % lifecycle transition table. Vehicle identities are represented by
        % table row names; row order has no semantic meaning. Transition
        % rows must equal the union of the previous and next identities:
        % next-only identities are Entered, previous-only identities are
        % Exited, and identities present in both are Unchanged.
        [obj, vehicleKinematics, vehicleLifecycleTransitions] = ...
            doStep(obj, deltaTime)
    end
end

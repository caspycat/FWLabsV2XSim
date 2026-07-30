classdef MetricsAccumulator < handle
    %METRICSACCUMULATOR Owns named metrics and ordered runtime events.
    %   Handle semantics provide one mutable accumulator per run. finalize
    %   freezes the accumulator and returns an immutable-by-value snapshot.

    properties (SetAccess = private)
        IsFinalized (1, 1) logical = false
    end

    properties (Access = private)
        MetricNames (:, 1) string = strings(0, 1)
        MetricValues (:, 1) double = zeros(0, 1)
        EventNames (:, 1) string = strings(0, 1)
        EventTimesSeconds (:, 1) double = zeros(0, 1)
        EventDetails (:, 1) cell = cell(0, 1)
        FinalSnapshot (1, 1) struct = struct()
    end

    methods
        function addMetric(obj, name, delta)
            %ADDMETRIC Add a finite scalar delta to a named metric.
            arguments (Input)
                obj (1, 1)
                name
                delta = 1
            end

            obj.mustBeMutable();
            name = ...
                v2xsim.runtime.MetricsAccumulator.validateName(name);
            delta = ...
                v2xsim.runtime.MetricsAccumulator.validateMetricValue( ...
                    delta);
            metricIndex = find(obj.MetricNames == name, 1);
            if isempty(metricIndex)
                obj.MetricNames(end + 1, 1) = name;
                obj.MetricValues(end + 1, 1) = delta;
                return
            end

            updatedValue = obj.MetricValues(metricIndex) + delta;
            if ~isfinite(updatedValue)
                error( ...
                    "v2xsim:runtime:InvalidMetricValue", ...
                    "Accumulating metric %s produced a nonfinite value.", ...
                    name);
            end
            obj.MetricValues(metricIndex) = updatedValue;
        end

        function increment(obj, name, amount)
            %INCREMENT Increment a named metric; the default amount is one.
            arguments (Input)
                obj (1, 1)
                name
                amount = 1
            end

            obj.addMetric(name, amount);
        end

        function setMetric(obj, name, value)
            %SETMETRIC Set one named metric to a finite scalar value.
            arguments (Input)
                obj (1, 1)
                name
                value
            end

            obj.mustBeMutable();
            name = ...
                v2xsim.runtime.MetricsAccumulator.validateName(name);
            value = ...
                v2xsim.runtime.MetricsAccumulator.validateMetricValue( ...
                    value);
            metricIndex = find(obj.MetricNames == name, 1);
            if isempty(metricIndex)
                obj.MetricNames(end + 1, 1) = name;
                obj.MetricValues(end + 1, 1) = value;
            else
                obj.MetricValues(metricIndex) = value;
            end
        end

        function value = getMetric(obj, name)
            %GETMETRIC Return one metric or reject an unknown name.
            arguments (Input)
                obj (1, 1)
                name
            end
            arguments (Output)
                value (1, 1) double
            end

            name = ...
                v2xsim.runtime.MetricsAccumulator.validateName(name);
            metricIndex = find(obj.MetricNames == name, 1);
            if isempty(metricIndex)
                error( ...
                    "v2xsim:runtime:UnknownMetric", ...
                    "No metric named %s has been recorded.", name);
            end
            value = obj.MetricValues(metricIndex);
        end

        function recordEvent(obj, name, simulationTimeSeconds, details)
            %RECORDEVENT Append one named event in observation order.
            arguments (Input)
                obj (1, 1)
                name
                simulationTimeSeconds
                details = struct()
            end

            obj.mustBeMutable();
            name = ...
                v2xsim.runtime.MetricsAccumulator.validateName(name);
            if ~isnumeric(simulationTimeSeconds) || ...
                    ~isreal(simulationTimeSeconds) || ...
                    ~isscalar(simulationTimeSeconds) || ...
                    ~isfinite(simulationTimeSeconds) || ...
                    simulationTimeSeconds < 0
                error( ...
                    "v2xsim:runtime:InvalidEventTime", ...
                    "Event time must be one finite nonnegative number.");
            end
            if ~isstruct(details) || ~isscalar(details)
                error( ...
                    "v2xsim:runtime:InvalidEventDetails", ...
                    "Event details must be a scalar struct.");
            end

            obj.EventNames(end + 1, 1) = name;
            obj.EventTimesSeconds(end + 1, 1) = ...
                double(simulationTimeSeconds);
            obj.EventDetails{end + 1, 1} = details;
        end

        function result = snapshot(obj)
            %SNAPSHOT Return current metrics and events by value.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                result (1, 1) struct
            end

            if obj.IsFinalized
                result = obj.FinalSnapshot;
                return
            end
            result = obj.createSnapshot();
        end

        function result = finalize(obj)
            %FINALIZE Freeze the accumulator and return its final snapshot.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                result (1, 1) struct
            end

            if ~obj.IsFinalized
                obj.FinalSnapshot = obj.createSnapshot();
                obj.IsFinalized = true;
            end
            result = obj.FinalSnapshot;
        end
    end

    methods (Access = private)
        function mustBeMutable(obj)
            if obj.IsFinalized
                error( ...
                    "v2xsim:runtime:MetricsFinalized", ...
                    "Finalized metrics cannot be changed.");
            end
        end

        function result = createSnapshot(obj)
            metrics = table( ...
                obj.MetricNames, obj.MetricValues, ...
                VariableNames=["Name", "Value"]);
            events = table( ...
                obj.EventNames, obj.EventTimesSeconds, obj.EventDetails, ...
                VariableNames=[ ...
                    "Name", "SimulationTimeSeconds", "Details"]);
            result = struct("Metrics", metrics, "Events", events);
        end
    end

    methods (Static, Access = private)
        function name = validateName(name)
            if ~(isstring(name) || ischar(name)) || ~isscalar(name)
                error( ...
                    "v2xsim:runtime:InvalidMetricName", ...
                    "Metric and event names must be text scalars.");
            end
            name = strip(string(name));
            if ismissing(name) || strlength(name) == 0
                error( ...
                    "v2xsim:runtime:InvalidMetricName", ...
                    "Metric and event names must be nonblank.");
            end
        end

        function value = validateMetricValue(value)
            if ~isnumeric(value) || ~isreal(value) || ...
                    ~isscalar(value) || ~isfinite(value)
                error( ...
                    "v2xsim:runtime:InvalidMetricValue", ...
                    "Metric values must be finite real scalars.");
            end
            value = double(value);
        end
    end
end

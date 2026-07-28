function mustBeWorkerLimit(value)
%MUSTBEWORKERLIMIT Validate a maximum process-worker count.

if ~(value == Inf || ...
        (isfinite(value) && value > 0 && value == fix(value)))
    error( ...
        "v2xsimregression:execution:InvalidMaxWorkers", ...
        "MaxWorkers must be a positive integer or Inf.");
end
end

function workerCount = resolveWorkerCount(maxWorkers,profileWorkerCount)
%RESOLVEWORKERCOUNT Apply an optional cap to a process profile's capacity.

arguments (Input)
    maxWorkers (1,1) double { ...
        v2xsimregression.execution.mustBeWorkerLimit}
    profileWorkerCount (1,1) double { ...
        mustBeFinite,mustBeInteger,mustBePositive}
end

arguments (Output)
    workerCount (1,1) double
end

workerCount = min(maxWorkers,profileWorkerCount);
end

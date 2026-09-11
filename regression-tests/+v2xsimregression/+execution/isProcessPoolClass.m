function supported = isProcessPoolClass(className)
%ISPROCESSPOOLCLASS Local and remote MATLAB processes are simulation safe.
% ClusterPool support also covers the existing pool inside a batch job.
arguments
    className (1,1) string
end
supported = ismember(className,["parallel.ProcessPool","parallel.ClusterPool"]);
end
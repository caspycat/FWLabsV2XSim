function [outputDirectory, lease] = acquireRunDirectory(requestedDirectory)
%ACQUIRERUNDIRECTORY Reserve one directory for one simulator run.
%   [OUTPUTDIRECTORY, LEASE] = ACQUIRERUNDIRECTORY(REQUESTEDDIRECTORY)
%   creates REQUESTEDDIRECTORY when needed, rejects directories that
%   already contain output, and atomically creates a hidden lock directory.
%   OUTPUTDIRECTORY is absolute. The caller must retain LEASE for the whole
%   run; destroying it removes the lock.

arguments (Input)
    requestedDirectory (1, 1) string {mustBeNonzeroLengthText}
end

requestedDirectory = strip(requestedDirectory);
if strlength(requestedDirectory) == 0
    error( ...
        "v2xsim:output:InvalidDirectory", ...
        "The output directory must not be blank.");
end

if ~isfolder(requestedDirectory)
    [created, message] = mkdir(requestedDirectory);
    if ~created
        error( ...
            "v2xsim:output:DirectoryCreationFailed", ...
            "Could not create output directory ""%s"": %s", ...
            requestedDirectory, message);
    end
end

try
    permissions = filePermissions(requestedDirectory);
catch exception
    error( ...
        "v2xsim:output:DirectoryCreationFailed", ...
        """%s"" is not an accessible directory: %s", ...
        requestedDirectory, exception.message);
end
outputDirectory = permissions.AbsolutePath;

lockDirectory = fullfile(outputDirectory, ".v2xsim-output-lock");
[locked, message, messageId] = mkdir(lockDirectory);
lockAlreadyExists = strcmp( ...
    messageId, "MATLAB:MKDIR:DirectoryExists");
if ~locked || lockAlreadyExists
    if isfolder(lockDirectory) || isfile(lockDirectory) || ...
            lockAlreadyExists
        error( ...
            "v2xsim:output:DirectoryInUse", ...
            "Output directory ""%s"" is already reserved.", ...
            outputDirectory);
    end
    error( ...
        "v2xsim:output:DirectoryCreationFailed", ...
        "Could not reserve output directory ""%s"": %s", ...
        outputDirectory, message);
end

lease = onCleanup(@() releaseLock(lockDirectory));
entries = dir(outputDirectory);
entryNames = string({entries.name});
allowedNames = [".", "..", ".v2xsim-output-lock"];
if any(~ismember(entryNames, allowedNames))
    error( ...
        "v2xsim:output:DirectoryNotEmpty", ...
        "Output directory ""%s"" must be empty.",outputDirectory);
end
end

function releaseLock(lockDirectory)
if isfolder(lockDirectory)
    rmdir(lockDirectory);
end
end

function result = load(filePath)
%LOAD Read one UTF-8 TOML file into a configuration template.
%   LOAD deliberately accepts only .toml files using SchemaVersion 1.
%   Parsing normalizes file-relative resource paths but does not resolve
%   defaults, construct runtime objects, or mutate MATLAB process state.

arguments (Input)
    filePath (1, 1) string {mustBeNonzeroLengthText}
end

[~, ~, extension] = fileparts(filePath);
if extension ~= ".toml"
    error( ...
        "v2xsim:config:UnsupportedFileExtension", ...
        "Configuration file ""%s"" must have the exact .toml extension.", ...
        filePath);
end
if ~isfile(filePath)
    error( ...
        "v2xsim:config:FileNotFound", ...
        "Configuration file ""%s"" does not exist.", filePath);
end
if ~isAbsolutePath(filePath)
    % Absolute source paths keep provenance and referenced resources stable
    % across process workers and changes of the current directory.
    filePath = string(fullfile(pwd, filePath));
end

fileIdentifier = fopen(filePath, "rt", "n", "UTF-8");
if fileIdentifier < 0
    error( ...
        "v2xsim:config:FileOpenFailed", ...
        "Configuration file ""%s"" could not be opened.", filePath);
end
cleanup = onCleanup(@() fclose(fileIdentifier));
text = fread(fileIdentifier, inf, "*char").';
if ~isempty(text) && text(1) == char(65279)
    text(1) = [];
end

try
    decoded = toml.decode(text);
catch cause
    exception = MException( ...
        "v2xsim:config:InvalidToml", ...
        "Configuration file ""%s"" is not valid TOML: %s", ...
        filePath, cause.message);
    exception = addCause(exception, cause);
    throwAsCaller(exception);
end
data = v2xsim.config.internal.Operations.fromToml(decoded);
data = resolveReferencedPaths(data, string(fileparts(filePath)));
if ~isfield(data, "SchemaVersion")
    error( ...
        "v2xsim:config:MissingSchemaVersion", ...
        "Configuration file ""%s"" must declare SchemaVersion = 1.", ...
        filePath);
end
if ~isnumeric(data.SchemaVersion) || ...
        ~isscalar(data.SchemaVersion) || data.SchemaVersion ~= 1
    error( ...
        "v2xsim:config:UnsupportedSchemaVersion", ...
        "Configuration file ""%s"" uses unsupported SchemaVersion %s.", ...
        filePath, string(data.SchemaVersion));
end

schema = v2xsim.config.schema();
v2xsim.config.internal.Operations.validateKnownStructure( ...
    data, schema, "TOML configuration");
source = "File:" + filePath;
provenance = ...
    v2xsim.config.internal.Operations.provenanceForData(data, source);
result = v2xsim.config.ConfigurationTemplate(data, provenance);
end

function data = resolveReferencedPaths(data, sourceDirectory)
if ~isfield(data, "Channel") || ...
        ~isfield(data.Channel, "PacketError")
    return
end

packetError = data.Channel.PacketError;
for field = ["CurveDirectory", "NlosCurveDirectory"]
    if ~isfield(packetError, field)
        continue
    end
    configuredPath = strip(string(packetError.(field)));
    if strlength(configuredPath) == 0 || ...
            strcmpi(configuredPath, "null") || ...
            isAbsolutePath(configuredPath)
        packetError.(field) = configuredPath;
        continue
    end
    packetError.(field) = ...
        string(fullfile(sourceDirectory, configuredPath));
end
data.Channel.PacketError = packetError;
end

function result = isAbsolutePath(path)
if ispc
    result = ~isempty(regexp(path, "^[A-Za-z]:[\\/]|^\\\\", "once"));
else
    result = startsWith(path, "/");
end
end

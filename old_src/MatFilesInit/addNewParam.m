function [structureChanged,varargin] = addNewParam(structureToChange,internalField,defaultValue,paramDescription,paramType,fileCfg,varargin)
% Function to create a new parameter.
% internalField preserves the implementation-facing V6 structure layout.
% canonicalParameterName supplies the dotted V7 public name.

sourceForValue = 0; % 0: default
value = defaultValue;
publicField = canonicalParameterName(internalField);

[canonicalCfgValue,canonicalInCfg] = searchParamInCfgFile( ...
    fileCfg,publicField,paramType);
legacyInCfg = false;
if ~strcmpi(publicField,internalField)
    [legacyCfgValue,legacyInCfg] = searchParamInCfgFile( ...
        fileCfg,internalField,paramType);
end
if canonicalInCfg && legacyInCfg
    error( ...
        'v2xsim:parameters:ConflictingNames', ...
        ['Configuration supplies both V7 parameter [%s] and its ', ...
        'deprecated V6 alias [%s].'],publicField,internalField);
elseif canonicalInCfg
    value = canonicalCfgValue;
    sourceForValue = 1; % 1: file config
elseif legacyInCfg
    value = legacyCfgValue;
    sourceForValue = 3; % 3: file config using V6 alias
    warning( ...
        'v2xsim:parameters:DeprecatedV6Name', ...
        ['Configuration parameter [%s] is a deprecated V6 name. ', ...
        'Use [%s] in V7.'],internalField,publicField);
end

argumentNames = string(varargin{1,1}(1:2:end));
canonicalArgumentIndex = find( ...
    strcmpi(argumentNames,publicField),1);
legacyArgumentIndex = [];
if ~strcmpi(publicField,internalField)
    legacyArgumentIndex = find( ...
        strcmpi(argumentNames,internalField),1);
end
if ~isempty(canonicalArgumentIndex) && ~isempty(legacyArgumentIndex)
    error( ...
        'v2xsim:parameters:ConflictingNames', ...
        ['Command line supplies both V7 parameter "%s" and its ', ...
        'deprecated V6 alias "%s".'],publicField,internalField);
elseif ~isempty(canonicalArgumentIndex)
    argumentIndex = canonicalArgumentIndex;
    sourceForValue = 2; % 2: command line
elseif ~isempty(legacyArgumentIndex)
    argumentIndex = legacyArgumentIndex;
    sourceForValue = 4; % 4: command line using V6 alias
    warning( ...
        'v2xsim:parameters:DeprecatedV6Name', ...
        ['Parameter name "%s" is deprecated from V6. ', ...
        'Use "%s" in V7.'],internalField,publicField);
else
    argumentIndex = [];
end
if ~isempty(argumentIndex)
    valueIndex = 2*argumentIndex;
    value = varargin{1,1}{valueIndex};
    varargin{1}(valueIndex-1:valueIndex) = [];
end

% Print to command window
fprintf('%s:\t',paramDescription);
fprintf('[%s] = ',publicField);
if strcmpi(paramType,'integer')
    if ~isnumeric(value) || mod(value,1)~=0
        error('Error: parameter %s must be an integer.',publicField);
    end
    fprintf('%.0f ',value);
elseif strcmpi(paramType,'double')
    if ~isnumeric(value)
        error('Error: parameter %s must be a number.',publicField);
    end
    fprintf('%f ',value);
elseif strcmpi(paramType,'string')
    if ~isstring(value) && ~ischar(value)
        error('Error: parameter %s must be a string.',publicField);
    end
    fprintf('%s ',value);
elseif strcmpi(paramType,'bool')
    if ~islogical(value)
        error('Error: parameter %s must be a boolean.',publicField);
    end
    if value == true
        fprintf('true ');
    else
        fprintf('false ');
    end
elseif strcmpi(paramType,'integerOrArrayString')
    if ischar(value)
        value = str2num(value); %#ok<ST2NM> Supports numeric arrays.
    end
    for iValue=1:length(value)
        if ~isnumeric(value(iValue)) || mod(value(iValue),1)~=0
            error('Error: parameter %s must be an integer or a string with integers.',publicField);
        end
        if iValue>1
            fprintf(',');
        end
        fprintf('%.0f',value(iValue));
    end
    fprintf(' ');
else
    error('Error in addNewParam: paramType can be only integer, double, string, or bool.');
end
if sourceForValue==0
    fprintf('(default)\n');
elseif sourceForValue==1
    fprintf('(file %s)\n',fileCfg);
elseif sourceForValue==2
    fprintf('(command line)\n');
elseif sourceForValue==3
    fprintf('(file %s, deprecated V6 name [%s])\n', ...
        fileCfg,internalField);
else
    fprintf('(command line, deprecated V6 name "%s")\n', ...
        internalField);
end
structureChanged = setNestedField( ...
    structureToChange,internalField,value);

end

function structureChanged = setNestedField( ...
        structureToChange,fieldPath,value)
% Support dotted configuration names while preserving flat legacy fields.
fieldParts = split(string(fieldPath),'.');
fieldName = fieldParts(1);

if isscalar(fieldParts)
    structureChanged = structureToChange;
    structureChanged.(fieldName) = value;
    return
end

if ~isfield(structureToChange,fieldName) || ...
        ~isstruct(structureToChange.(fieldName))
    nestedStructure = struct();
else
    nestedStructure = structureToChange.(fieldName);
end

nestedFieldPath = join(fieldParts(2:end),'.');
structureChanged = structureToChange;
structureChanged.(fieldName) = setNestedField( ...
    nestedStructure,nestedFieldPath,value);
end

function [simParams, appParams, phyParams, outParams, hookOptions] = ...
        initializeEstablishedEngine(plan, runOptions)
%INITIALIZEESTABLISHEDENGINE Build engine state from one compiled V7 plan.
%   The temporary file is deliberately empty and is not a configuration
%   input. It prevents the established numerical initializer from consulting
%   any implicit default configuration while the engine is being retired in
%   favour of domain-owned runtime components.

arguments (Input)
    plan (1, 1) v2xsim.runtime.CompiledSimulationPlan
    runOptions (1, 1) v2xsim.runtime.RunOptions
end

requiredFunctions = [ ...
    "initiateParameters", "deriveRanges", "composeOutputHooks", ...
    "initVehiclePositions", "mainV2X"];
missingFunctions = requiredFunctions( ...
    arrayfun(@(name) strlength(string(which(name))) == 0, ...
        requiredFunctions));
if ~isempty(missingFunctions)
    error( ...
        "v2xsim:runtime:EngineUnavailable", ...
        "The MATLAB Project must be open so the established numerical " + ...
        "engine is available. Missing functions: %s.", ...
        strjoin(missingFunctions, ", "));
end

[engineArguments, roadsideUnits] = ...
    v2xsim.runtime.internal.compileEngineArguments(plan, runOptions);

emptyInputFile = string(tempname) + ".tmp";
fileIdentifier = fopen(emptyInputFile, "wt", "n", "UTF-8");
if fileIdentifier < 0
    error( ...
        "v2xsim:runtime:TemporaryInputCreationFailed", ...
        "Could not create the isolated empty engine-input file.");
end
fclose(fileIdentifier);
inputCleanup = onCleanup(@() deleteTemporaryFile(emptyInputFile));

[simParams, appParams, phyParams, outParams, hookOptions] = ...
    initiateParameters([{char(emptyInputFile)}, engineArguments]);
% The empty isolation file is an implementation detail, never run
% metadata. Record the single TOML source when the resolved configuration
% has one; programmatically constructed or multi-source templates have no
% configuration-file provenance.
simParams.fileCfg = configurationFile(plan.Configuration);
% Runtime consumers use the immutable plan directly. This field is a
% temporary hand-off to numerical engine functions that have not yet moved
% into the v2xsim.runtime package; it is not a public parameter structure.
simParams.compiledPlan = plan;
if plan.Radio.Type == "Coexistence"
    simParams.coex_printTechPercentage = ...
        plan.Outputs.CoexistenceTechnologyShare.Enabled;
    simParams.coex_cbrLteVariant = ...
        plan.Coexistence.ChannelLoad.SidelinkVariant;
    simParams.coex_cbrTotVariant = ...
        plan.Coexistence.ChannelLoad.TotalVariant;
end
appParams = applyRoadsideUnits(appParams, roadsideUnits);

inputCleanup; %#ok<VUNUS>
end

function appParams = applyRoadsideUnits(appParams, units)
unitCount = numel(units);
appParams.nRSUs = unitCount;
if unitCount == 0
    return
end

appParams.RSU_ids = strings(unitCount, 1);
appParams.RSU_xLocation = zeros(1, unitCount);
appParams.RSU_yLocation = zeros(1, unitCount);
for index = 1:unitCount
    unit = units{index};
    appParams.RSU_ids(index) = unit.Id;
    appParams.RSU_xLocation(index) = unit.PositionMeters(1);
    appParams.RSU_yLocation(index) = unit.PositionMeters(2);
end

technology = units{1}.Technology;
if technology == "Ieee80211p"
    appParams.RSU_technology = "11p";
else
    appParams.RSU_technology = "LTE";
end

packetType = units{1}.PacketType;
switch packetType
    case "Cam"
        appParams.RSU_pckTypeString = "CAM";
    case "Denm"
        appParams.RSU_pckTypeString = "DENM";
        appParams.nPckTypes = 2;
    case "HighPriorityDenm"
        appParams.RSU_pckTypeString = "hpDENM";
        appParams.nPckTypes = 2;
end
end

function deleteTemporaryFile(file)
if isfile(file)
    delete(file);
end
end

function file = configurationFile(configuration)
sources = configuration.Provenance.Source;
fileSources = unique(sources(startsWith(sources, "File:")), "stable");
if isscalar(fileSources)
    file = extractAfter(fileSources, "File:");
else
    file = "";
end
end

function result = runSimulation(configuration, options)
%RUNSIMULATION Run one simulation from a resolved V7 configuration.
%   RESULT = v2xsim.runSimulation(CONFIGURATION,
%   OutputDirectory=DIRECTORY) compiles one immutable
%   v2xsim.config.ResolvedConfiguration and runs it in an exclusively
%   reserved directory.
%
%   RunLabel is optional execution metadata. Scientific inputs belong in
%   the TOML configuration or a typed, nested ConfigurationPatch. This
%   entrypoint intentionally accepts neither configuration filenames nor
%   dotted name-value overrides. ProgressFcn is an optional run-owned
%   observer that receives structured initialization, simulated-time, and
%   finalization events without changing scientific state.
%   PositionErrorChainSpecification optionally provides an explicit
%   ordered chain containing configured and researcher-supplied modules.
%
%   The FWLabsV2XSim MATLAB Project must be active before calling this
%   function, either because it is open directly or because a research
%   project references it. Project metadata owns all source-path
%   configuration; this entrypoint never mutates the MATLAB path.

% ==============
% Copyright (C) Alessandro Bazzi, University of Bologna, and Alberto Zanella, CNR
% 
% All rights reserved.
% 
% Permission to use, copy, modify, and distribute this software for any 
% purpose without fee is hereby granted, provided that this entire notice 
% is included in all copies of any software which is or includes a copy or 
% modification of this software and in all copies of the supporting 
% documentation for such software.
% 
% THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED 
% WARRANTY. IN PARTICULAR, NEITHER OF THE AUTHORS MAKES ANY REPRESENTATION 
% OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY OF THIS SOFTWARE 
% OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
% 
% Project: FWLabsV2XSim V7
% ==============

arguments (Input)
    configuration (1, 1) {mustBeResolvedConfiguration}
    options.OutputDirectory (1, 1) string
    options.RunLabel (1, 1) string = ""
    options.ProgressFcn {mustBeProgressFunctionOrEmpty} = []
    options.PositionErrorChainSpecification ...
        {mustBePositionErrorChainSpecificationOrEmpty} = []
end
arguments (Output)
    result (1, 1) v2xsim.runtime.SimulationResult
end

plan = v2xsim.runtime.compile(configuration);
runOptions = v2xsim.runtime.RunOptions( ...
    OutputDirectory=options.OutputDirectory, ...
    RunLabel=options.RunLabel);
outputSession = v2xsim.runtime.OutputSession(runOptions);
outputCleanup = onCleanup(@() outputSession.close());
engineRunOptions = v2xsim.runtime.RunOptions( ...
    OutputDirectory=outputSession.RunDirectory, ...
    RunLabel=runOptions.RunLabel);
simulationDurationSeconds = plan.Simulation.DurationSeconds;
if ~isempty(options.ProgressFcn)
    v2xsim.runtime.internal.reportProgress( ...
        options.ProgressFcn, "initializing", 0, ...
        simulationDurationSeconds, 0, ...
        "Initializing the established radio engine.");
end

% The established radio engine still consumes MATLAB's global stream.
% Confine that side effect to this orchestration boundary and restore the
% caller's exact generator settings on every success and failure path.
callerRandomState = rng;
randomCleanup = onCleanup(@() rng(callerRandomState));

[simParams,appParams,phyParams,outParams,outputHookOptions] = ...
    v2xsim.runtime.internal.initializeEstablishedEngine( ...
        plan, engineRunOptions);
if ~isempty(options.PositionErrorChainSpecification)
    simParams = v2xsim.runtime.internal.composePositionErrorChain( ...
        simParams, plan.Positioning, ...
        options.PositionErrorChainSpecification);
end
fprintf('FWLabsV2XSim %s\n\n',constants.SIM_VERSION);
fprintf('Full path of the output directory = %s\n', ...
    outputSession.RunDirectory);

% Update PHY structure with the ranges
[phyParams] = deriveRanges(phyParams,simParams);

% Compose optional outputs once. Runtime code receives only the dispatcher.
[hookRegistry,hookDispatcher] = composeOutputHooks( ...
    outputHookOptions,outParams,simParams,appParams,phyParams);

% Simulator output inizialization
outputValues = struct('computationTime',-1,...
    'blockingRateCV2X',-1*ones(1,length(phyParams.Raw)),'blockingRate11p',-1*ones(1,length(phyParams.Raw)),'blockingRateTOT',-1*ones(1,length(phyParams.Raw)),...
    'errorRateCV2X',-1*ones(1,length(phyParams.Raw)),'errorRate11p',-1*ones(1,length(phyParams.Raw)),'errorRateTOT',-1*ones(1,length(phyParams.Raw)),...
    'packetReceptionRatioCV2X',-1*ones(1,length(phyParams.Raw)),'packetReceptionRatio11p',-1*ones(1,length(phyParams.Raw)),'packetReceptionRatioTOT',-1*ones(1,length(phyParams.Raw)),...
    'NUEsCV2X',0,'NUEs11p',0,'NUEsTOT',0,...
    'NneighborsCV2X',zeros(1,length(phyParams.Raw)),'Nneighbors11p',zeros(1,length(phyParams.Raw)),'NneighborsTOT',zeros(1,length(phyParams.Raw)),...
    'StDevNeighboursCV2X',zeros(1,length(phyParams.Raw)),'StDevNeighbours11p',zeros(1,length(phyParams.Raw)),'StDevNeighboursTOT',zeros(1,length(phyParams.Raw)),...
    'NreassignCV2X',0,...%%%%%
    'NblockedCV2X',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'Nblocked11p',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NblockedTOT',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),...
    'NtxBeaconsCV2X',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NtxBeacons11p',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NtxBeaconsTOT',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),...
    'NerrorsCV2X',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'Nerrors11p',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NerrorsTOT',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),...    
    'NcorrectlyTxBeaconsCV2X',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NcorrectlyTxBeacons11p',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),'NcorrectlyTxBeaconsTOT',zeros(phyParams.nChannels,appParams.nPckTypes,length(phyParams.Raw)),...
    'cv2xTransmissionsIncHarq',0,'cv2xTransmissionsFirst',0);
%     'NblockedCV2X',zeros(appParams.nPckTypes,length(phyParams.Raw)),'Nblocked11p',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NblockedTOT',zeros(appParams.nPckTypes,length(phyParams.Raw)),...
%     'NtxBeaconsCV2X',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NtxBeacons11p',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NtxBeaconsTOT',zeros(appParams.nPckTypes,length(phyParams.Raw)),...
%     'NerrorsCV2X',zeros(appParams.nPckTypes,length(phyParams.Raw)),'Nerrors11p',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NerrorsTOT',zeros(appParams.nPckTypes,length(phyParams.Raw)),...    
%     'NcorrectlyTxBeaconsCV2X',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NcorrectlyTxBeacons11p',zeros(appParams.nPckTypes,length(phyParams.Raw)),'NcorrectlyTxBeaconsTOT',zeros(appParams.nPckTypes,length(phyParams.Raw)));
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Scenario Description

% Load scenario from Trace File or generate initial positions of vehicles
[simParams,simValues,positionManagement,appParams] = ...
    initVehiclePositions(simParams,appParams,hookDispatcher);
[simValues,positionManagement] = applyConfiguredRsuIds( ...
    simValues,positionManagement,appParams);

% Obstacle maps and PRR maps belonged to the removed trace scenarios.
[positionManagement.XminMap,positionManagement.YmaxMap, ...
    positionManagement.StepMap,positionManagement.GridMap] = deal(-1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Start Simulation
[simValues,outputValues,appParams,simParams,phyParams,sinrManagement,outParams,stationManagement] = mainV2X( ...
    appParams,simParams,phyParams,outParams,simValues,outputValues, ...
    positionManagement,options.ProgressFcn);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% KPIs Computation (Output)
if ~isempty(options.ProgressFcn)
    v2xsim.runtime.internal.reportProgress( ...
        options.ProgressFcn, "finalizing", ...
        simulationDurationSeconds, simulationDurationSeconds, ...
        outputValues.computationTime, ...
        "Simulation events completed; finalizing output artifacts.");
end
fprintf('\nElaborating the outputs...\n');

% First of all convert from cumulative to groups
for pckType = 1:appParams.nPckTypes
    for iPhyRaw=length(phyParams.Raw):-1:2
        for idChannel = 1:phyParams.nChannels
%            outputValues.NblockedCV2X(pckType,iPhyRaw) = outputValues.NblockedCV2X(pckType,iPhyRaw)-outputValues.NblockedCV2X(pckType,iPhyRaw-1);
%             outputValues.NcorrectlyTxBeaconsCV2X(pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsCV2X(pckType,iPhyRaw)-outputValues.NcorrectlyTxBeaconsCV2X(pckType,iPhyRaw-1);
%             outputValues.NerrorsCV2X(pckType,iPhyRaw) = outputValues.NerrorsCV2X(pckType,iPhyRaw)-outputValues.NerrorsCV2X(pckType,iPhyRaw-1);
%             outputValues.NtxBeaconsCV2X(pckType,iPhyRaw) = outputValues.NtxBeaconsCV2X(pckType,iPhyRaw)-outputValues.NtxBeaconsCV2X(pckType,iPhyRaw-1);
%             outputValues.Nblocked11p(pckType,iPhyRaw) = outputValues.Nblocked11p(pckType,iPhyRaw)-outputValues.Nblocked11p(pckType,iPhyRaw-1);
%             outputValues.NcorrectlyTxBeacons11p(pckType,iPhyRaw) = outputValues.NcorrectlyTxBeacons11p(pckType,iPhyRaw)-outputValues.NcorrectlyTxBeacons11p(pckType,iPhyRaw-1);
%             outputValues.Nerrors11p(pckType,iPhyRaw) = outputValues.Nerrors11p(pckType,iPhyRaw)-outputValues.Nerrors11p(pckType,iPhyRaw-1);
%             outputValues.NtxBeacons11p(pckType,iPhyRaw) = outputValues.NtxBeacons11p(pckType,iPhyRaw)-outputValues.NtxBeacons11p(pckType,iPhyRaw-1);
%             outputValues.NblockedTOT(pckType,iPhyRaw) = outputValues.NblockedTOT(pckType,iPhyRaw)-outputValues.NblockedTOT(pckType,iPhyRaw-1);
%             outputValues.NcorrectlyTxBeaconsTOT(pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsTOT(pckType,iPhyRaw)-outputValues.NcorrectlyTxBeaconsTOT(pckType,iPhyRaw-1);
%             outputValues.NerrorsTOT(pckType,iPhyRaw) = outputValues.NerrorsTOT(pckType,iPhyRaw)-outputValues.NerrorsTOT(pckType,iPhyRaw-1);
%             outputValues.NtxBeaconsTOT(pckType,iPhyRaw) = outputValues.NtxBeaconsTOT(pckType,iPhyRaw)-outputValues.NtxBeaconsTOT(pckType,iPhyRaw-1);
            outputValues.NblockedCV2X(idChannel,pckType,iPhyRaw) = outputValues.NblockedCV2X(idChannel,pckType,iPhyRaw)-outputValues.NblockedCV2X(idChannel,pckType,iPhyRaw-1);
            outputValues.NcorrectlyTxBeaconsCV2X(idChannel,pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsCV2X(idChannel,pckType,iPhyRaw)-outputValues.NcorrectlyTxBeaconsCV2X(idChannel,pckType,iPhyRaw-1);
            outputValues.NerrorsCV2X(idChannel,pckType,iPhyRaw) = outputValues.NerrorsCV2X(idChannel,pckType,iPhyRaw)-outputValues.NerrorsCV2X(idChannel,pckType,iPhyRaw-1);
            outputValues.NtxBeaconsCV2X(idChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsCV2X(idChannel,pckType,iPhyRaw)-outputValues.NtxBeaconsCV2X(idChannel,pckType,iPhyRaw-1);
            outputValues.Nblocked11p(idChannel,pckType,iPhyRaw) = outputValues.Nblocked11p(idChannel,pckType,iPhyRaw)-outputValues.Nblocked11p(idChannel,pckType,iPhyRaw-1);
            outputValues.NcorrectlyTxBeacons11p(idChannel,pckType,iPhyRaw) = outputValues.NcorrectlyTxBeacons11p(idChannel,pckType,iPhyRaw)-outputValues.NcorrectlyTxBeacons11p(idChannel,pckType,iPhyRaw-1);
            outputValues.Nerrors11p(idChannel,pckType,iPhyRaw) = outputValues.Nerrors11p(idChannel,pckType,iPhyRaw)-outputValues.Nerrors11p(idChannel,pckType,iPhyRaw-1);
            outputValues.NtxBeacons11p(idChannel,pckType,iPhyRaw) = outputValues.NtxBeacons11p(idChannel,pckType,iPhyRaw)-outputValues.NtxBeacons11p(idChannel,pckType,iPhyRaw-1);
            outputValues.NblockedTOT(idChannel,pckType,iPhyRaw) = outputValues.NblockedTOT(idChannel,pckType,iPhyRaw)-outputValues.NblockedTOT(idChannel,pckType,iPhyRaw-1);
            outputValues.NcorrectlyTxBeaconsTOT(idChannel,pckType,iPhyRaw) = outputValues.NcorrectlyTxBeaconsTOT(idChannel,pckType,iPhyRaw)-outputValues.NcorrectlyTxBeaconsTOT(idChannel,pckType,iPhyRaw-1);
            outputValues.NerrorsTOT(idChannel,pckType,iPhyRaw) = outputValues.NerrorsTOT(idChannel,pckType,iPhyRaw)-outputValues.NerrorsTOT(idChannel,pckType,iPhyRaw-1);
            outputValues.NtxBeaconsTOT(idChannel,pckType,iPhyRaw) = outputValues.NtxBeaconsTOT(idChannel,pckType,iPhyRaw)-outputValues.NtxBeaconsTOT(idChannel,pckType,iPhyRaw-1);
        end
    end
end

% Average Blocking Rate
% outputValues.blockingRateCV2X = sum(outputValues.NblockedCV2X,1) ./ (sum(outputValues.NcorrectlyTxBeaconsCV2X+outputValues.NerrorsCV2X+outputValues.NblockedCV2X,1));
% outputValues.blockingRate11p = sum(outputValues.Nblocked11p,1) ./ (sum(outputValues.NcorrectlyTxBeacons11p+outputValues.Nerrors11p+outputValues.Nblocked11p,1));
% outputValues.blockingRateTOT = sum(outputValues.NblockedTOT,1) ./ (sum(outputValues.NcorrectlyTxBeaconsTOT+outputValues.NerrorsTOT+outputValues.NblockedTOT,1));
outputValues.blockingRateCV2X = sum(sum(outputValues.NblockedCV2X,1),1) ./ (sum(sum(outputValues.NcorrectlyTxBeaconsCV2X+outputValues.NerrorsCV2X+outputValues.NblockedCV2X,1),1));
outputValues.blockingRate11p = sum(sum(outputValues.Nblocked11p,1),1) ./ (sum(sum(outputValues.NcorrectlyTxBeacons11p+outputValues.Nerrors11p+outputValues.Nblocked11p,1),1));
outputValues.blockingRateTOT = sum(sum(outputValues.NblockedTOT,1),1) ./ (sum(sum(outputValues.NcorrectlyTxBeaconsTOT+outputValues.NerrorsTOT+outputValues.NblockedTOT,1),1));

% Average Error Rate
% outputValues.errorRateCV2X = sum(outputValues.NerrorsCV2X,1) ./ sum(outputValues.NtxBeaconsCV2X,1);
% outputValues.errorRate11p = sum(outputValues.Nerrors11p,1) ./ sum(outputValues.NtxBeacons11p,1);
% outputValues.errorRateTOT = sum(outputValues.NerrorsTOT,1) ./ sum(outputValues.NtxBeaconsTOT,1);
outputValues.errorRateCV2X = sum(sum(outputValues.NerrorsCV2X,1),1) ./ sum(sum(outputValues.NtxBeaconsCV2X,1),1);
outputValues.errorRate11p = sum(sum(outputValues.Nerrors11p,1),1) ./ sum(sum(outputValues.NtxBeacons11p,1),1);
outputValues.errorRateTOT = sum(sum(outputValues.NerrorsTOT,1),1) ./ sum(sum(outputValues.NtxBeaconsTOT,1),1);

% Average Packet Reception Ratio
% outputValues.packetReceptionRatioCV2X = sum(outputValues.NcorrectlyTxBeaconsCV2X,1) ./ sum(outputValues.NtxBeaconsCV2X,1);
% outputValues.packetReceptionRatio11p = sum(outputValues.NcorrectlyTxBeacons11p,1) ./ sum(outputValues.NtxBeacons11p,1);
% outputValues.packetReceptionRatioTOT = sum(outputValues.NcorrectlyTxBeaconsTOT,1) ./ sum(outputValues.NtxBeaconsTOT,1);
outputValues.packetReceptionRatioCV2X = sum(sum(outputValues.NcorrectlyTxBeaconsCV2X,1),1) ./ sum(sum(outputValues.NtxBeaconsCV2X,1),1);
outputValues.packetReceptionRatio11p = sum(sum(outputValues.NcorrectlyTxBeacons11p,1),1) ./ sum(sum(outputValues.NtxBeacons11p,1),1);
outputValues.packetReceptionRatioTOT = sum(sum(outputValues.NcorrectlyTxBeaconsTOT,1),1) ./ sum(sum(outputValues.NtxBeaconsTOT,1),1);

% Average number of neighbors per UE
outputValues.NneighborsCV2X = outputValues.NneighborsCV2X ./ outputValues.NUEsCV2X;
outputValues.Nneighbors11p = outputValues.Nneighbors11p ./ outputValues.NUEs11p;
outputValues.NneighborsTOT = outputValues.NneighborsTOT ./ outputValues.NUEsTOT;
outputValues.StDevNeighboursCV2X = outputValues.StDevNeighboursCV2X / simValues.snapshots;
outputValues.StDevNeighbours11p = outputValues.StDevNeighbours11p / simValues.snapshots;
outputValues.StDevNeighboursTOT = outputValues.StDevNeighboursTOT / simValues.snapshots;

% Average number of UEs in the world
outputValues.AvgNUEsCV2X = outputValues.NUEsCV2X / simValues.snapshots;
outputValues.AvgNUEs11p = outputValues.NUEs11p / simValues.snapshots;
outputValues.AvgNUEsTOT = outputValues.NUEsTOT / simValues.snapshots;

% Average number of successful BR reassignments per UE per second
if outputValues.AvgNUEsCV2X>0
    outputValues.NreassignCV2X = (outputValues.NreassignCV2X ./ outputValues.AvgNUEsCV2X) / simParams.simulationTime;
else
    outputValues.NreassignCV2X = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Print To Video
fprintf('\nAverage number of UEs in the world = %.0f\n',outputValues.AvgNUEsTOT);
if outputValues.AvgNUEsCV2X>0 && outputValues.AvgNUEs11p>0
    fprintf('Average %.0f C-V2X, ',outputValues.AvgNUEsCV2X);
    fprintf('average %.0f IEEE 802.11p\n',outputValues.AvgNUEs11p);
end
for iPhyRaw=1:length(phyParams.Raw)
    if iPhyRaw==1
        fprintf('*** In the range 0-%d:\n',phyParams.Raw(iPhyRaw));
    else
        fprintf('*** In the range %d-%d:\n',phyParams.Raw(iPhyRaw-1),phyParams.Raw(iPhyRaw));
    end
    if outputValues.AvgNUEsCV2X>0 && outputValues.AvgNUEs11p>0
        fprintf('LTE: average neigbors %.2f +- %.2f, ',outputValues.NneighborsCV2X(iPhyRaw),outputValues.StDevNeighboursCV2X(iPhyRaw));
        fprintf('Blocking = %.5f\tError = %.5f\tCorrect = %.5f\n',outputValues.blockingRateCV2X(iPhyRaw),outputValues.errorRateCV2X(iPhyRaw),outputValues.packetReceptionRatioCV2X(iPhyRaw));
        fprintf('11p: average neighbors %.2f +- %.2f, ',outputValues.Nneighbors11p(iPhyRaw),outputValues.StDevNeighbours11p(iPhyRaw));
        fprintf('Blocking = %.5f\tError = %.5f\tCorrect = %.5f\n',outputValues.blockingRate11p(iPhyRaw),outputValues.errorRate11p(iPhyRaw),outputValues.packetReceptionRatio11p(iPhyRaw));
    else
        fprintf('Average neighbors %.2f +- %.2f\n',outputValues.NneighborsTOT(iPhyRaw),outputValues.StDevNeighboursTOT(iPhyRaw));
        fprintf('Blocking = %.5f\tError = %.5f\tCorrect = %.5f\n',outputValues.blockingRateTOT(iPhyRaw),outputValues.errorRateTOT(iPhyRaw),outputValues.packetReceptionRatioTOT(iPhyRaw));
    end    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Print To Files

% Finalize hook-owned optional outputs.
hookRegistry.cleanup();

% Publish the summary as the final fallible operation so its presence means
% the entire run completed.
summary = v2xsim.output.buildSimulationSummary( ...
    stationManagement,simParams,appParams,phyParams, ...
    sinrManagement,outParams,outputValues);
v2xsim.output.writeSimulationSummary( ...
    outParams.outputFolder,summary);

metrics = v2xsim.runtime.MetricsAccumulator();
metrics.setMetric( ...
    "ComputationDurationSeconds", outputValues.computationTime);
metrics.setMetric("AverageUeCount", outputValues.AvgNUEsTOT);
metrics.recordEvent( ...
    "SimulationCompleted", simParams.simulationTime, ...
    struct("RunLabel", runOptions.RunLabel));
metricSnapshot = metrics.finalize();
artifacts = collectArtifactPaths(outputSession.RunDirectory);

outputSession.close();
result = v2xsim.runtime.SimulationResult( ...
    configuration, plan, metricSnapshot, artifacts, ...
    outputSession.RunDirectory, ...
    summary.Configuration.Positioning.ErrorChain);
clear outputCleanup randomCleanup

end

function [simValues, positionManagement] = applyConfiguredRsuIds( ...
        simValues, positionManagement, appParams)
if ~isfield(appParams, "RSU_ids") || isempty(appParams.RSU_ids)
    return
end

world = simValues.world;
rsuPositions = world.RsuPositions;
rsuPositions.Properties.RowNames = cellstr(appParams.RSU_ids);
world = v2xsim.World( ...
    world.TrafficScenario, rsuPositions, world.ObstacleGeometry);
simValues.world = world;
positionManagement = ...
    v2xsim.legacy.projectWorldToPositionManagement( ...
        world, positionManagement);
end

function artifacts = collectArtifactPaths(runDirectory)
entries = dir(fullfile(runDirectory, "**", "*"));
entries = entries(~[entries.isdir]);
if isempty(entries)
    artifacts = strings(0, 1);
    return
end
artifacts = string(fullfile( ...
    {entries.folder}, {entries.name})).';
artifacts = sort(artifacts);
end

function mustBeResolvedConfiguration(value)
if ~isa(value, "v2xsim.config.ResolvedConfiguration")
    error( ...
        "v2xsim:runtime:ResolvedConfigurationRequired", ...
        "runSimulation requires a resolved V7 configuration object. " + ...
        "Configuration filenames, including legacy .cfg files, are not " + ...
        "accepted.");
end
end

function mustBeProgressFunctionOrEmpty(value)
if isequal(value, [])
    return
end
if ~(isa(value, "function_handle") && isscalar(value))
    error( ...
        "v2xsim:runtime:InvalidProgressFunction", ...
        "ProgressFcn must be empty or a scalar function handle.");
end
end

function mustBePositionErrorChainSpecificationOrEmpty(value)
if isequal(value, [])
    return
end
if ~isa(value, ...
        "v2xsim.positioning.PositionErrorChainSpecification") || ...
        ~isscalar(value)
    error( ...
        "v2xsim:runtime:InvalidPositionErrorChainSpecification", ...
        "PositionErrorChainSpecification must be empty or one " + ...
        "v2xsim.positioning.PositionErrorChainSpecification.");
end
end

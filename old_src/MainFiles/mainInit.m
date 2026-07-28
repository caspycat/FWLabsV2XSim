function [appParams,simParams,phyParams,outParams,simValues,outputValues,...
    sinrManagement,timeManagement,positionManagement,stationManagement] = mainInit(appParams,simParams,phyParams,outParams,simValues,outputValues,positionManagement)
% Initialization function

%% Init of active vehicles and states
% Move IDvehicle from simValues to station Management
stationManagement.activeIDs = simValues.IDvehicle;
simValues = rmfield(simValues,'IDvehicle');

% Resolve the World RSU identities to the dense numeric UE indices used by
% the legacy station-management arrays. RSUs are not required to occupy a
% particular suffix of the UE ordering.
[isRsuMapped,rsuUeIndices] = ismember( ...
    simValues.world.RsuIds,simValues.world.UeIds);
assert(all(isRsuMapped), ...
    'Every World RSU ID must be present in World UeIds.');
assert(numel(rsuUeIndices)==appParams.nRSUs, ...
    'appParams.nRSUs must match the number of RSUs in the World.');

% The simulation starts at time '0'
timeManagement.timeNow = 0;

% State of each node
% Discriminates C-V2X nodes from 11p nodes
if simParams.technology==constants.TECH_ONLY_CV2X
    
    % All vehicles in C-V2X (lte or 5g) are currently in the same state
    % 100 = LTE TX/RX
    stationManagement.vehicleState = constants.V_STATE_LTE_TXRX * ones(simValues.maxID,1);
 
elseif simParams.technology==constants.TECH_ONLY_11P
   
    % The possible states in 11p are four:
    % 1 = IDLE :    the node has no packet and senses the medium as free
    % 2 = BACKOFF : the node has a packet to transmit and senses the medium as
    %               free; it is thus performing the backoff
    % 3 = TX :      the node is transmitting
    % 9 = RX :      the node is sensing the medium as busy and possibly receiving
    %               a packet (the sender it firstly sensed is saved in
    %               idFromWhichRx)
    stationManagement.vehicleState = ones(simValues.maxID,1);

else % coexistence
    
    % Init all as LTE
    stationManagement.vehicleState = constants.V_STATE_LTE_TXRX * ones(simValues.maxID,1);
    %Then use simParams.numVehiclesLTE and simParams.numVehicles11p to
    %initialize
    stationManagement.vehicleState(simParams.numVehiclesLTE+1:simParams.numVehiclesLTE+simParams.numVehicles11p) = constants.V_STATE_11P_IDLE;
end

% RSUs technology set
if appParams.nRSUs>0
    if strcmpi(appParams.RSU_technology,'11p')
        stationManagement.vehicleState(rsuUeIndices) = constants.V_STATE_11P_IDLE;
    elseif strcmpi(appParams.RSU_technology,'LTE')
        stationManagement.vehicleState(rsuUeIndices) = constants.V_STATE_LTE_TXRX;
    end
end

%% Initialization of the vectors of active vehicles in each technology, 
% which is helpful to work with smaller vectors and matrixes
stationManagement.activeIDsCV2X = stationManagement.activeIDs.*(stationManagement.vehicleState(stationManagement.activeIDs)==constants.V_STATE_LTE_TXRX);
stationManagement.activeIDsCV2X = stationManagement.activeIDsCV2X(stationManagement.activeIDsCV2X>0);
stationManagement.activeIDs11p = stationManagement.activeIDs.*(stationManagement.vehicleState(stationManagement.activeIDs)~=constants.V_STATE_LTE_TXRX);
stationManagement.activeIDs11p = stationManagement.activeIDs11p(stationManagement.activeIDs11p>0);
stationManagement.indexInActiveIDs_ofLTEnodes = zeros(length(stationManagement.activeIDsCV2X),1);
for i=1:length(stationManagement.activeIDsCV2X)
    stationManagement.indexInActiveIDs_ofLTEnodes(i) = find(stationManagement.activeIDs==stationManagement.activeIDsCV2X(i));
end
stationManagement.indexInActiveIDs_of11pnodes = zeros(length(stationManagement.activeIDs11p),1);
for i=1:length(stationManagement.activeIDs11p)
    stationManagement.indexInActiveIDs_of11pnodes(i) = find(stationManagement.activeIDs==stationManagement.activeIDs11p(i));
end

%% Number of UEs at the current time
outputValues.NUEs = length(stationManagement.activeIDs);
outputValues.NUEsTOT = outputValues.NUEsTOT + outputValues.NUEs;
outputValues.NUEsCV2X = outputValues.NUEsCV2X + ...
    length(stationManagement.activeIDsCV2X);
outputValues.NUEs11p = outputValues.NUEs11p + ...
    length(stationManagement.activeIDs11p);

%% Initialization of packets management 
% Number of packets in the queue of each node
stationManagement.pckBuffer = zeros(simValues.maxID,1);
% Type of packets
% 1 = CAM
% 2 = DENM
stationManagement.pckType = constants.PACKET_TYPE_CAM * ones(simValues.maxID,1);
if appParams.nRSUs>0 && ~strcmpi(appParams.RSU_pckTypeString,'CAM')
    stationManagement.pckType(rsuUeIndices) = constants.PACKET_TYPE_DENM;
end
% From v 5.4.14 the following are needed for multiple transmissions 
% 'pckReceived' registers if the current packet has already been received
% pckReceived=1 means already received
% pckReceived=0 means never attempted to decode
% pckReceived=-x means attempted to decode 'x' times 
stationManagement.pckReceived = zeros(simValues.maxID,simValues.maxID); % (TO, FROM)
% cumulate SINR
sinrManagement.cumulativeSINR = zeros(simValues.maxID,simValues.maxID); % (TO, FROM)

stationManagement.preambleAlreadyDetected = zeros(simValues.maxID,simValues.maxID); % (TO, FROM)
% counting the CBR of 11p, for many repetitions, only counting the first
% received packets
stationManagement.alreadyStartCBR = zeros(simValues.maxID,simValues.maxID); % (TO, FROM)

% pckNextAttempt is the total times the packet transmitting if countting
% the next packet
stationManagement.pckNextAttempt = ones(simValues.maxID,1);
% pckTxOccurring is used in LTE and set at the beginning of the subframe,
% because pckRemainingTx might change during the subframe
stationManagement.pckTxOccurring = zeros(simValues.maxID,1);

% Parameter for 11p retransmission KPI calculation, the index of active11p
% in the range during earlier retransmission
NactiveIDs11p = length(stationManagement.activeIDs11p);
stationManagement.indexInRaw_earler = zeros(NactiveIDs11p, NactiveIDs11p, length(phyParams.Raw)); % (to, from, idRaw)

% HARQ init
stationManagement.cv2xNumberOfReplicas = phyParams.cv2xNumberOfReplicasMax * ones(simValues.maxID,1);
% IGS-G5 retransmission init
stationManagement.ITSNumberOfReplicas = phyParams.ITSNumberOfReplicasMax * ones(simValues.maxID,1);
%%%%%%%


%% Packet generation
timeManagement.timeGeneratedPacketInTxLTE = -1 * ones(simValues.maxID,1);
if appParams.variabilityGenerationInterval == constants.PACKET_GENERATION_ETSI_CAM
    timeManagement.generationIntervalDeterministicPart = ...
        generationPeriodFromSpeed(positionManagement.v,appParams);
else
    timeManagement.generationIntervalDeterministicPart = appParams.generationInterval - appParams.variabilityGenerationInterval/2 + appParams.variabilityGenerationInterval*rand(simValues.maxID,1);
    timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDsCV2X) = appParams.generationInterval;
end
% this additional delay can be used to add a delay from application to
% access layer or to add an artificial delay in the generatioon
timeManagement.addedToGenerationTime = zeros(simValues.maxID,1);

% From v5.2.5: RSU DENM and hpDENM are sent at fixed 20 Hz
if appParams.nRSUs>0 && ~strcmpi(appParams.RSU_pckTypeString,'CAM')
    timeManagement.generationIntervalDeterministicPart(rsuUeIndices) = 0.05;
end
%timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDsCV2X) = appParams.averageTbeacon;
timeManagement.timeNextPacket = Inf * ones(simValues.maxID,1);
timeManagement.timeNextPacket(stationManagement.activeIDs) = round(timeManagement.generationIntervalDeterministicPart(stationManagement.activeIDs) .* rand(length(stationManagement.activeIDs),1), 10);
timeManagement.timeLastPacket = -1 * ones(simValues.maxID,1); % needed for the calculation of the CBR

timeManagement.dcc_minInterval = zeros(simValues.maxID,1);
stationManagement.dcc11pTriggered = false(1,phyParams.nChannels);
stationManagement.dccLteTriggered = false(1,phyParams.nChannels);
stationManagement.dccLteTriggeredHarq = false(1,phyParams.nChannels);

% Initialization of variables related to transmission in LTE-V2V - must be
% initialized also if 11p is not present
%if simParams.technology~=2 % if not only 11p
    sinrManagement.coex_currentInterfFrom11pToLTE = zeros(simValues.maxID,1);
    sinrManagement.coex_currentInterfEach11pNodeToLTE = zeros(simValues.maxID,simValues.maxID);
%end
% Initialization of variables related to transmission in 11p - must be
% initialized also if LTE is not present
%if simParams.technology~=1 % if not only LTE
   sinrManagement.coex_InterfFromLTEto11p = zeros(simValues.maxID,1);
%end

%% Initialize propagation
% Tx power vectors
if isfield(phyParams,'P_ERP_MHz_CV2X')
    if phyParams.FixedPdensity
        % Power density is fixed, must be scaled based on subchannels
        phyParams.P_ERP_MHz_CV2X = phyParams.P_ERP_MHz_CV2X * (phyParams.NsubchannelsBeacon/phyParams.NsubchannelsFrequency);
    end %else % Power is fixed, independently to the used bandwidth
    phyParams.P_ERP_MHz_CV2X = phyParams.P_ERP_MHz_CV2X*ones(simValues.maxID,1);
else
    phyParams.P_ERP_MHz_CV2X = -ones(simValues.maxID,1);
end
if isfield(phyParams,'P_ERP_MHz_11p')
    phyParams.P_ERP_MHz_11p = phyParams.P_ERP_MHz_11p*ones(simValues.maxID,1);
else
    phyParams.P_ERP_MHz_11p = -ones(simValues.maxID,1);
end

% Vehicles in a technology have the power to -1000 in the other; this is helpful for
% verification purposes
phyParams.P_ERP_MHz_CV2X(stationManagement.vehicleState ~= constants.V_STATE_LTE_TXRX) = -1000;
phyParams.P_ERP_MHz_11p(stationManagement.vehicleState == constants.V_STATE_LTE_TXRX) = -1000;

%% Channels
stationManagement.vehicleChannel = ones(simValues.maxID,1);
% NOTE: sinrManagement.mcoCoefficient( RECEIVER, TRANSMITTER) 
sinrManagement.mcoCoefficient = ones(simValues.maxID,simValues.maxID);

% Shadowing matrix
sinrManagement.Shadowing_dB = randn(length(stationManagement.activeIDs),length(stationManagement.activeIDs))*phyParams.stdDevShadowLOS_dB;
sinrManagement.Shadowing_dB = triu(sinrManagement.Shadowing_dB,1)+triu(sinrManagement.Shadowing_dB)';

%% Management of coordinates and distances
% Init knowledge at eNodeB of nodes positions
%if simParams.technology~=2 % not only 11p
if sum(stationManagement.vehicleState(stationManagement.activeIDs)==constants.V_STATE_LTE_TXRX)>0    
    % Number of groups for position update
 	positionManagement.NgroupPosUpdate = round(simParams.Tupdate/appParams.allocationPeriod);
    % Assign update period to all vehicles (introduce a position update delay)
    positionManagement.posUpdateAllVehicles = randi(positionManagement.NgroupPosUpdate,simValues.maxID,1);
else
    positionManagement.NgroupPosUpdate = -1;
end

% initVehiclePositions initializes both the legacy pre-module estimate and
% the final controller-visible position-error chain output.
if ~isfield(simValues,'XvehicleEstimatedLegacy')
    simValues.XvehicleEstimatedLegacy = ...
        positionManagement.XvehicleReal;
    simValues.YvehicleEstimatedLegacy = ...
        positionManagement.YvehicleReal;
end
if ~isfield(simValues,'XvehicleEstimated')
    simValues.XvehicleEstimated = ...
        simValues.XvehicleEstimatedLegacy;
    simValues.YvehicleEstimated = ...
        simValues.YvehicleEstimatedLegacy;
end

% Call function to compute distances
% computeDistance(i,j): computeDistance from vehicle with index i to vehicle with index j
% positionManagement.distance matrix has dimensions equal to simValues.IDvehicle x simValues.IDvehicle in order to
% speed up the computation (only vehicles present at the considered instant)
% positionManagement.distance(i,j): positionManagement.distance from vehicle with index i to vehicle with index j
[positionManagement,stationManagement] = computeDistance (simParams,simValues,stationManagement,positionManagement);

% Save positionManagement.distance matrix
positionManagement.XvehicleRealOld = positionManagement.XvehicleReal;
positionManagement.YvehicleRealOld =  positionManagement.YvehicleReal;
positionManagement.distanceRealOld = positionManagement.distanceReal;
positionManagement.angleOld = zeros(length(positionManagement.XvehicleRealOld),1);

% Computation of the channel gain
% 'dUpdate': vector used for the calculation of correlated shadowing
dUpdate = zeros(outputValues.NUEs,outputValues.NUEs);
[sinrManagement,simValues.Xmap,simValues.Ymap,phyParams.LOS] = computeChannelGain(sinrManagement,stationManagement,positionManagement,phyParams,simParams,dUpdate);

% Update of the neighbors
[positionManagement,stationManagement] = computeNeighbors(stationManagement,positionManagement,phyParams);

% The variable 'timeManagement.timeNextPosUpdate' is used for updating the positions
timeManagement.timeNextPosUpdate = round(simParams.positionTimeResolution, 10);
positionManagement.NposUpdates = 1;

% Number of neighbors
[outputValues,~,NneighborsRawLTE,NneighborsRaw11p] = ...
    updateAverageNeighbors( ...
        simParams,stationManagement,outputValues,phyParams);
dispatchAfterNeighborGraphUpdated( ...
    simValues,timeManagement,stationManagement, ...
    positionManagement,phyParams, ...
    NneighborsRawLTE,NneighborsRaw11p);

%% Initialization of variables related to transmission in IEEE 802.11p
% 'timeNextTxRx11p' stores the instant of the next backoff or
% transmission end, if the station is 11p - not used in LTE and therefore
% init to inf in all cases
timeManagement.timeNextTxRx11p = Inf * ones(simValues.maxID,1);
%
if sum(stationManagement.vehicleState(stationManagement.activeIDs)~=constants.V_STATE_LTE_TXRX)>0
% if not only LTE
    % When a node senses the medium as busy and goes to State RX, the
    % transmitting node is saved in 'idFromWhichRx'
    % Note that once a node starts receiving a signal, it will not be able to
    % synchronize to a different signal, thus there is no reason to change this
    % value before exiting from State RX
    % 'idFromWhichRx' is set to the id of the node if the node is not receiving
    % (a number must be set in order to avoid exceptions running the code that follow)
    sinrManagement.idFromWhichRx11p = (1:simValues.maxID)';

    % Possible events: A) New packet, B) Backoff ends, C) Transmission end;
    % A - 'timeNextPacket' stores the instant of the next message generation; the
    % first instant is randomly chosen within 0-Tbeacon
    %timeManagement.timeNextGeneration11p = timeManagement.timeNextPacket;
    timeManagement.cbr11p_timeStartBusy = -1 * ones(simValues.maxID,1); % needed for the calculation of the CBR
    timeManagement.cbr11p_timeStartMeasInterval = -1 * ones(simValues.maxID,1); % needed for the calculation of the CBR

    % Total power being received from nodes are transmitting
    sinrManagement.rxPowerInterfLast11p = zeros(simValues.maxID,1);
    sinrManagement.rxPowerUsefulLast11p = zeros(simValues.maxID,1);
 
    % Instant when the power store in 'PrTot' was calculated; it will remain
    % constant until a new calculation will be performed
    %sinrManagement.instantThisPrStarted11p = Inf;
    sinrManagement.instantThisSINRstarted11p = ones(simValues.maxID,1)*Inf;

    % Average SINR - This parameter is irrelevant if the node is not in state V_STATE_11P_RX
    sinrManagement.sinrAverage11p = zeros(simValues.maxID,1);
    sinrManagement.interfAverage11p = zeros(simValues.maxID,1);

    % Instant when the average SINR of a node in State V_STATE_11P_RX was initiated - This
    % parameter is irrelevant if the node is not in State V_STATE_11P_RX
    sinrManagement.instantThisSINRavStarted11p = Inf * ones(simValues.maxID,1);

    % Number of slots for the backoff - Set to '-1' when not initiated
    stationManagement.nSlotBackoff11p = -1 * ones(simValues.maxID,1);
    % Init of AIFS and CW per station
    stationManagement.CW_11p = ones(simValues.maxID,1) * phyParams.CW;
    stationManagement.tAifs_11p = ones(simValues.maxID,1) * phyParams.tAifs;
    % Removal from struct to avoid mistakes
    %phyParams = rmfield( phyParams , 'CW' );
    %phyParams = rmfield( phyParams , 'AifsN' );
    phyParams = rmfield( phyParams , 'tAifs' );
    if appParams.nRSUs>0 && ~strcmpi(appParams.RSU_pckTypeString,'CAM')
        if strcmpi(appParams.RSU_pckTypeString,'hpDENM')
            % High priority DENM: CWmax=3, AIFS=58us
            stationManagement.CW_11p(rsuUeIndices) = 3;
            stationManagement.tAifs_11p(rsuUeIndices) = 58e-6;
        elseif strcmpi(appParams.RSU_pckTypeString,'DENM')
            % DENM: CWmax=7, AIFS=71us
            stationManagement.CW_11p(rsuUeIndices) = 7;
            stationManagement.tAifs_11p(rsuUeIndices) = 71e-6;
        else
            error('Something wrong with the packet type of RSUs');
        end
    end
end % end of not only LTE

%% Coexistence
% Settings of Coexistence must be before BR assignment initialization
timeManagement.coex_timeNextSuperframe = inf * ones(simValues.maxID,1);
sinrManagement.coex_virtualInterference = zeros(simValues.maxID,1);
sinrManagement.coex_averageTTIinterfFrom11pToLTE = zeros(simValues.maxID,1);
if simParams.technology==constants.TECH_COEX_STD_INTERF 
    if simParams.coexMethod~=constants.COEX_METHOD_NON
        [timeManagement,stationManagement,sinrManagement,simParams,phyParams] = mainInitCoexistence(timeManagement,stationManagement,sinrManagement,simParams,simValues,phyParams,appParams);
    end

    % Initialization of the matrix coex_correctSCIhistory
    sinrManagement.coex_correctSCIhistory = zeros(appParams.NbeaconsT*appParams.NbeaconsF,simValues.maxID);
end

% vector sensedPowerByLteNo11p created (might remain void)
sinrManagement.sensedPowerByLteNo11p = [];


%% Initialization of variables related to transmission in IEEE 802.11p
% Initialize the beacon resource used by each vehicle
stationManagement.BRid = -2*ones(simValues.maxID,phyParams.cv2xNumberOfReplicasMax);
stationManagement.BRid(stationManagement.activeIDs,:) = -1;
%
% Initialize next LTE event to inf
timeManagement.timeNextCV2X = inf;

if ismember( ...
        constants.V_STATE_LTE_TXRX, ...
        stationManagement.vehicleState(stationManagement.activeIDs))
    [simValues,stationManagement,simParams] = ...
        initializeResourceAllocation( ...
            simValues,stationManagement,timeManagement, ...
            positionManagement,sinrManagement,simParams,phyParams,appParams);

    % The next instant in C-V2X will be the beginning
    % of the first TTI in 0
    timeManagement.timeNextCV2X = 0;
    timeManagement.ttiCV2Xstarts = true;
    
    % The channel busy ratio of C-V2X is initialized
    sinrManagement.cbrCV2X = zeros(simValues.maxID,1);
    sinrManagement.cbrLTE_coexLTEonly = zeros(simValues.maxID,1);
end

% if CBR is active, set the next CBR instant - else set to inf
if simParams.cbrActive
    
    if simParams.technology == constants.TECH_COEX_STD_INTERF && simParams.coexMethod == constants.COEX_METHOD_A
        if mod(simParams.coex_superFlength/simParams.cbrSensingInterval, 1) ~= 0 && ...
           mod(simParams.cbrSensingInterval/simParams.coex_superFlength, 1) ~= 0
            error('coex, Method A, cbrSensingInterval must be a multiple or a divisor of coex_superFlength');
        end
    end   
    
    timeManagement.timeNextCBRupdate = simParams.cbrSensingInterval/simParams.cbrSensingIntervalDesynchN;
    stationManagement.cbr_subinterval = randi(simParams.cbrSensingIntervalDesynchN,simValues.maxID,1);
    
    timeManagement.cbr11p_timeStartMeasInterval(stationManagement.activeIDs11p) = 0;
    timeManagement.cbr11p_timeStartBusy = -1 * ones(simValues.maxID,1);
%     if simParams.technology==4 && simParams.coexMethod==1
%         timeManagement.cbr11p_timeStartBusy(stationManagement.activeIDs .* timeManagement.coex_superframeThisIsLTEPart(stationManagement.activeIDs)) = -1;
%     end    
    if simParams.technology~=constants.TECH_ONLY_CV2X % Not only C-V2X
        stationManagement.channelSensedBusyMatrix11p = zeros(ceil(simParams.cbrSensingInterval/appParams.allocationPeriod),simValues.maxID);        
    end
    
    nCbrIntervals = ceil(simParams.simulationTime/simParams.cbrSensingInterval);
    stationManagement.cbr11pValues = -1 * ones(simValues.maxID,nCbrIntervals); 
    stationManagement.cbrCV2Xvalues = -1 * ones(simValues.maxID,nCbrIntervals);     
    stationManagement.coex_cbrLteOnlyValues = -1 * ones(simValues.maxID,nCbrIntervals); 

%     %% =========
%     % Plot figs of related paper, could be commented in other case.
%     % Please check .../codeForPaper/Zhuofei2023Repetition/fig6
%     % Only for IEEE 802.11p, highway scenario. 
%     stationManagement.ITSReplicasLog = zeros(simValues.maxID,nCbrIntervals);
%     stationManagement.positionLog = zeros(simValues.maxID,nCbrIntervals);
%     %% =========
else
    timeManagement.timeNextCBRupdate = inf;
end

% BRid set to -1 for non-LTE
stationManagement.BRid(stationManagement.vehicleState~=constants.V_STATE_LTE_TXRX,:)=-3;

%% Initialization of time variables
% Stores the instant of the next event among all possible events;
% initially set to the first packet generation
timeManagement.timeNextEvent = Inf * ones(simValues.maxID,1);
timeManagement.timeNextEvent(stationManagement.activeIDs) = timeManagement.timeNextPacket(stationManagement.activeIDs);

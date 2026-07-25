close all % Close all open figures
clear % Reset variables
clc % Clear the command window

%% init simulator and path
% path of simulation task
version_fit = "V7";  % simulator V7 is needed
path_task = fileparts(mfilename('fullpath'));
addpath(path_task);

% path of simulator
path_simulator = fileparts(fileparts(fileparts(path_task)));
addpath(fullfile(path_simulator, "src"));
addpath(fullfile(path_simulator, "old_src"));

% path of output
path_output = fullfile(path_task, 'Output', 'data_fig_11');


%% Simulation for different SCS
% Configuration file
configFile = fullfile(path_task, 'fig11_config.cfg');

simTime = 10; % simulation time
nTransm=1; % Number of transmission for each packet
sizeSubchannel=10; % Number of Resource Blocks for each subchannel
Raw = 150; % Range of Awarness for evaluation of metrics
vehicleCount=200;
nLanes=3;
laneWidth=4;
roadLength=2000;
centralDividerWidth=0;
speed=70/3.6; % Average speed (m/s)
speedStDev=7/3.6; % Standard deviation speed (m/s)
pKeep=0.4; % keep probability
BandMHz=10;
SCS = 15;
nDMRS = 24;
thresholds = -126; % threshold to detect resources as busy
pSizes = 350; % 350B packet size
MCS = 4;
averageSensingValues = [true, false];
co_arrivals = [true, false];

generationInterval = 0.2; % calibrated campaign value
thresholdFloorFraction = 0.2;
M_values = [1, 0.2];

for M = M_values
    for averageSensing = averageSensingValues
        for coarri = co_arrivals
            if coarri
                if M == 0.2 || averageSensing  % condition not considered
                    continue;
                end
                allocationPeriod=0.2; % RRI
            else
                allocationPeriod=0.1; % RRI
            end
            outputsubfolder = sprintf("M_%d_avgRSRP_%d_coherentArrival_%d",100*M,averageSensing,coarri);
            WiLabV2Xsim(configFile,'simulation.RequiredVersion', version_fit,...
                'simulation.DurationSeconds',simTime,...
                'scenario.Type','BidirectionalHighwayScenario',...
                'scenarioOptions.VehicleCount',vehicleCount,...
                'scenarioOptions.NLanes',nLanes,...
                'scenarioOptions.LaneWidth',laneWidth,...
                'scenarioOptions.RoadLength',roadLength,...
                'scenarioOptions.CentralDividerWidth',centralDividerWidth,...
                'scenarioOptions.MeanVehicleSpeed',speed,...
                'scenarioOptions.VehicleSpeedStandardDeviation',speedStDev,...
                'scenarioOptions.RerollSpeedOnWrapAround',false,...
                'application.PacketSizeBytes',pSizes,'application.ResourceReservationIntervalSeconds',allocationPeriod,...
                'application.PacketGeneration.IntervalSeconds',generationInterval,'awareness.RangesMeters',Raw,...
                'simulation.RadioAccessMode','5G-V2X','nrV2x.Mcs',MCS,'nrV2x.SubcarrierSpacingKilohertz',SCS,'nrV2x.DmrsResourceElementCountPerSlot',nDMRS,...
                'resourceAllocation.Autonomous.KeepResourceProbability',pKeep,'radio.BandwidthMHz',BandMHz,'resourcePool.SubchannelSizeResourceBlocks',sizeSubchannel,...
                'sidelink.Harq.MaximumTransmissionCount',nTransm,...
                'resourceAllocation.Autonomous.SensingThresholdDbm',thresholds,'radio.FixedPowerDensityEnabled',true,...
                'resourceAllocation.Autonomous.MinimumCandidateFraction',thresholdFloorFraction,...
                'resourceAllocation.Autonomous.L2CandidateFraction',M,'resourceAllocation.Autonomous.L2RankingEnabled',M<1,...
                'resourceAllocation.Autonomous.AverageSensingEnabled',averageSensing,...
                'congestionControl.Enabled',false,'channelLoad.Enabled',true,...
                'output.Directory',fullfile(path_output,outputsubfolder),...
                'simulation.RunLabel', sprintf("Simulation: %s is running", outputsubfolder));

        end
    end
end

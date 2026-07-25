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
path_output = fullfile(path_task, 'Output', 'data_fig_7');


%% Simulation for different SCS
% Configuration file
configFile = fullfile(path_task, 'fig7_config.cfg');

simTime = 10; % simulation time
packetSize=350; % 350B packet size
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
periodicity=0.1; % RRI 
% generationInterval = 0.1; % periodic generation every 100 ms (default)
sensingThreshold=-126; % threshold to detect resources as busy
BandMHz=10;

SCS = [15, 30, 60];
nDMRS = [24, 18, 12];

haveIBE = [true, false];  
IBE_name = ["true", "false"];

for i_SCS = 1:length(SCS)
    for i_IBE = 1:length(haveIBE)           
        if SCS(i_SCS) == 60 && haveIBE(i_IBE) == 1  % situation not considered
            continue;
        end
        outputsubfolder = sprintf("SCS_%d_IBE_%s", SCS(i_SCS), IBE_name(i_IBE));
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
            'application.PacketSizeBytes',packetSize,'application.ResourceReservationIntervalSeconds',periodicity,'awareness.RangesMeters',Raw,...
            'simulation.RadioAccessMode','5G-V2X','nrV2x.Mcs',21,'nrV2x.SubcarrierSpacingKilohertz',SCS(i_SCS),'nrV2x.DmrsResourceElementCountPerSlot',nDMRS(i_SCS),...
            'resourceAllocation.Autonomous.KeepResourceProbability',pKeep,'radio.BandwidthMHz',BandMHz,'resourcePool.SubchannelSizeResourceBlocks',sizeSubchannel,...
            'sidelink.Harq.MaximumTransmissionCount',nTransm,'sidelink.InBandEmissionEnabled',haveIBE(i_IBE),...
            'resourceAllocation.Autonomous.SensingThresholdDbm',sensingThreshold,'radio.FixedPowerDensityEnabled',true,...
            'congestionControl.Enabled',false,'channelLoad.Enabled',true,...
            'output.Directory',fullfile(path_output,outputsubfolder),...
            'simulation.RunLabel', sprintf("Simulation: %s is running", outputsubfolder));
    end
end

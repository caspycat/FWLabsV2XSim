%% init
%% was running on Giammarco's computer
close all       % Close all open figures
clear           % Reset variables
clc             % Clear the command window
path(pathdef);  % Reset Matlab path

path_task = fileparts(mfilename('fullpath'));
path_sim = fileparts(fileparts(fileparts(path_task)));
addpath(genpath(path_sim));
rmpath(genpath(fullfile(path_sim, "codeForPaper")));
addpath(path_task);

path_PERcurves	= fullfile(path_sim,"PERcurves", "G5-HighwayLOS");
path_output = fullfile(path_task, "mataData");


%% set parameters for paralle simulation
configFile = 'fig6_config.cfg';

% NOTE: The threshold index here is inversed compared with the paper
% if replicate type is 0, thresholds would be ignored
thre1 = 0.03;       % threshold 3 in paper
thre2 = 0.05;       % threshold 2 in paper
thre3 = 0.09;       % threshold 1 in paper


%% simulation
for rType = [1,2]
    WiLabV2Xsim(configFile, 'simulation.RandomSeed', 0,...
        'itsG5.Repetition.Mode', rType, 'itsG5.Repetition.MaximumTransmissionCount', 4,...
        'itsG5.Repetition.LowCbrThreshold', thre1, 'itsG5.Repetition.MediumCbrThreshold', thre2,...
        'itsG5.Repetition.HighCbrThreshold', thre3,...
        'channel.PacketErrorRateCurveDirectory', path_PERcurves,'channel.PathLoss.Model',0,...
        'output.Directory', fullfile(path_output, sprintf("rType_%d",rType)));
end


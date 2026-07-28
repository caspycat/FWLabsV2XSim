%% init
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

configFile = 'fig4_config.cfg';


%% set parameters for paralle simulation
density = [1:10,12:2:30,40:20:100];
ch_model = [0, 3];      % [winner+ B1, ECC rural]
repNumbers = 1:4;       % statistic repetition number
times = 1;              % archived quick-check setting
runCount = numel(ch_model) * numel(density) * ...
    numel(repNumbers) * times;
p_ch = zeros(1, runCount);
p_roadL = zeros(1, runCount);
p_dens = zeros(1, runCount);
p_repNum = zeros(1, runCount);
p_outfolder = strings(runCount, 1);
runIndex = 0;

for ch = ch_model
    for dens_kms = density
        if ch == 0
            roadLength = 2000;
            dens = dens_kms;
        elseif ch == 3
            roadLength = 8000;
            dens = dens_kms./4;
        end

        for repNum = repNumbers
            for t = 1:times
                runIndex = runIndex + 1;
                p_ch(runIndex) = ch;
                p_roadL(runIndex) = roadLength;
                p_dens(runIndex) = dens;
                p_repNum(runIndex) = repNum;
                p_outfolder(runIndex) = fullfile(path_output,...
                    sprintf("ch_%d_replicate_%d_dens_%.2f",ch, repNum, dens),...
                    sprintf("sim_%d", t));
            end
        end
    end
end


%% simulation
par_num = length(p_ch);
parfor i = 1:par_num
    % if not complete at last time, remove files and restart
    if exist(p_outfolder(i), "dir")
        if ~exist(fullfile(p_outfolder(i), "simulation_summary.json"), "file")
            rmdir(p_outfolder(i),"s");
        else
            continue;
        end
    end

    % start simulation
    WiLabV2Xsim(configFile, 'simulation.RandomSeed', 0,...
        'rho', p_dens(i), 'roadLength', p_roadL(i),...
        'itsG5.Repetition.MaximumTransmissionCount', p_repNum(i),...
        'channel.PacketErrorRateCurveDirectory', path_PERcurves, 'channel.PathLoss.Model',p_ch(i),...
        'output.Directory', p_outfolder(i));
end

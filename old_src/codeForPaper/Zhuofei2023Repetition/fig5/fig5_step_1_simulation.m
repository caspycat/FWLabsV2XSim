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
configFile = 'fig5_config.cfg';
density = flip([1:10,12:2:30,40:20:100]);

% NOTE: The threshold index here is inversed compared with the paper
% if replicate type is 0, thresholds would be ignored
thre1 = 0.03;       % threshold 3 in paper
thre2 = 0.05;       % threshold 2 in paper
thre3 = 0.09;       % threshold 1 in paper

ch_model = [0, 3];          % [winner+ B1, ECC rural]
repType = [0,1,2];            % [0,1,2]: [static, deterministic, probabilistic]
times = 1;                    % archived quick-check setting
repetitionCaseCount = numel(1:4) + numel(repType) - 1;
runCount = numel(ch_model) * repetitionCaseCount * ...
    numel(density) * times;
p_ch = zeros(1, runCount);
p_roadL = zeros(1, runCount);
p_dens = zeros(1, runCount);
p_reptype = zeros(1, runCount);
p_repnum = zeros(1, runCount);
p_outfolder = strings(runCount, 1);
runIndex = 0;

for ch = ch_model
    for rType = repType
        if rType == 0
            repNumbers = 1:4;
        else
            repNumbers = 4;
        end
        for replicate = repNumbers
            for dens_km = density
                if ch == 0
                    roadLength = 2000;
                    dens = dens_km;
                elseif ch == 3
                    roadLength = 8000;
                    dens = dens_km/4;
                end

                for t = 1:times
                    runIndex = runIndex + 1;
                    p_ch(runIndex) = ch;
                    p_roadL(runIndex) = roadLength;
                    p_dens(runIndex) = dens;
                    p_reptype(runIndex) = rType;
                    p_repnum(runIndex) = replicate;
                    scenario = sprintf("ch_%d_rType_%d_replicate_%d_dens_%.2f",...
                        ch, rType, replicate, dens);
                    p_outfolder(runIndex) = fullfile( ...
                        path_output, scenario, sprintf("sim_%d", t));
                end
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

    WiLabV2Xsim(configFile, 'simulation.RandomSeed', 0,...
        'rho', p_dens(i), 'roadLength', p_roadL(i),...
        'itsG5.Repetition.Mode', p_reptype(i), 'itsG5.Repetition.MaximumTransmissionCount', p_repnum(i),...
        'itsG5.Repetition.LowCbrThreshold', thre1, 'itsG5.Repetition.MediumCbrThreshold', thre2,...
        'itsG5.Repetition.HighCbrThreshold', thre3,...
        'channel.PacketErrorRateCurveDirectory', path_PERcurves,'channel.PathLoss.Model',p_ch(i),...
        'output.Directory', p_outfolder(i));
end

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

configFile = 'fig3_config.cfg';


%% set parameters for paralle simulation
repNumbers = 1:4;
times = 30;                             % repeat simulation
sensitivity = [-100, -103, -120];       % preamble detection threshold
runCount = numel(repNumbers) * times * numel(sensitivity);
p_repNum = zeros(1, runCount);
p_sens = zeros(1, runCount);
p_outfolder = strings(runCount, 1);
runIndex = 0;
for sens = sensitivity
    for t = 1:times
        for repNum = repNumbers
            runIndex = runIndex + 1;
            p_repNum(runIndex) = repNum;
            p_sens(runIndex) = sens;
            p_outfolder(runIndex) = fullfile(path_output,...
                sprintf("replicate_%d_sensitivity__%d", repNum, abs(sens)),...
                sprintf("sim_%d",t));
        end
    end
end


%% simulation
par_num = length(p_repNum);     % total simualtion numbers
parfor i = 1:par_num            % if not work, use "for" instead of "parfor"
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
        'itsG5.Repetition.MaximumTransmissionCount', p_repNum(i),...
        'ieee80211p.PreambleSensitivityDbm', p_sens(i),...
        'channel.PacketErrorRateCurveDirectory', path_PERcurves,...
        'output.Directory', p_outfolder(i));
end

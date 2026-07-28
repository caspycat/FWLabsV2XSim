% init env
close all    % Close all open figures
clear        % Reset variables
clc          % Clear the command window

% add path of the simulator and the code of this paper
path(pathdef);  % Reset Matlab path
path_task = fileparts(mfilename("fullpath"));
path_code = fileparts(path_task);
path_simulator = fileparts(fileparts(path_code));
addpath(genpath(path_simulator));
rmpath(genpath(fileparts(path_code)));
addpath(genpath(path_task));


%% fixed params
dens = 0.5:0.5:6; % cars per lane per km
Raw = [50, 150, 300, 500];
dens_km = dens * 6; % dens per km
roadLength = 8; % km
ratio_lte = 1/3;
v_lte = ceil(dens_km * ratio_lte * roadLength); 
v_11p = roadLength*dens_km - v_lte;

%% variable params
varTs = 0;   % variabilityTbeacon, [0, -1]
sTime = 120;    % simulation time
computer_name = "felix_1_3_lte";
dataSize = 350;

Methods = ["no_method", "enhanced_A", "method_B", "dynamic_C", "method_F", "dynamic_C_preamble"];

stopTimesByDensity = 2 * ones(size(dens_km));
stopTimesByDensity(dens_km < 10) = 20;
stopTimesByDensity(dens_km >= 10 & dens_km < 20) = 10;
stopTimesByDensity(dens_km >= 20 & dens_km <= 30) = 5;
runCount = sum(stopTimesByDensity) * numel(varTs) * numel(Methods);
p_method = strings(1, runCount);
p_dens = zeros(1, runCount);
p_vgi = zeros(1, runCount);
p_n_vgi = strings(1, runCount);
p_v_lte = zeros(1, runCount);
p_v_11p = zeros(1, runCount);
p_sim_ids = zeros(1, runCount);
p_configFile = strings(runCount, 1);
p_outputF = strings(runCount, 1);
runIndex = 0;
for tot_time = 1:50
    for i_d = 1:length(dens_km)
        stop_times = stopTimesByDensity(i_d);
        if tot_time > stop_times
            continue;
        end
        for VGI = varTs
            if VGI == -1
                n_vgi = "CAM";
            else
                n_vgi = "period";
            end
            for method = Methods
                runIndex = runIndex + 1;
                p_method(runIndex) = method;
                p_dens(runIndex) = dens_km(i_d);
                p_n_vgi(runIndex) = n_vgi;
                p_vgi(runIndex) = VGI;
                p_v_11p(runIndex) = v_11p(i_d);
                p_v_lte(runIndex) = v_lte(i_d);
                p_sim_ids(runIndex) = tot_time;
                p_configFile(runIndex) = fullfile( ...
                    path_task, sprintf("wp_%s.cfg",method));
                outfolder = fullfile(fileparts(path_task), "dataNewSetting", computer_name,...
                    method, sprintf("dens_%d_vgi_%s", dens_km(i_d), n_vgi));
                p_outputF(runIndex) = outfolder;
            end
        end
    end
end

parfor i = 1:length(p_dens)
    % if not complete at last time, remove files and restart
    if exist(fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i))), "dir") 
        if ~exist(fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i)), ...
                "simulation_summary.json"), "file")
            rmdir(fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i))),"s");
        else
            continue;
        end
    end
    if strcmp(p_method(i), "only_NR")
        WiLabV2Xsim(p_configFile(i), ...
            'simulation.DurationSeconds', sTime, 'rho', p_dens(i), 'roadLength', roadLength*1000,...
            'awareness.RangesMeters', Raw, ...
            'application.PacketGeneration.IntervalVariationSeconds', p_vgi(i), 'application.PacketSizeBytes', dataSize,...
            'output.WirelessBlindSpot.Enabled', true, 'output.UpdateDelay.Enabled', true,...
            'output.PacketDelay.Enabled', true, 'output.DataAge.Enabled', true,...
            'simulation.RunLabel', sprintf("dens: %d, VGI: %d, method: %s", p_dens(i), p_vgi(i), p_method(i)),...
            'output.Directory', fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i))));
    elseif strcmp(p_method(i), "only_ITS")
        WiLabV2Xsim(p_configFile(i),...
            'simulation.DurationSeconds', sTime, 'rho', p_dens(i),  'roadLength', roadLength*1000,...
            'awareness.RangesMeters', Raw,...
            'application.PacketGeneration.IntervalVariationSeconds', p_vgi(i), 'application.PacketSizeBytes', dataSize,...
            'output.WirelessBlindSpot.Enabled', true, 'output.UpdateDelay.Enabled', true,...
            'output.PacketDelay.Enabled', true, 'output.DataAge.Enabled', true,...
            'simulation.RunLabel', sprintf("dens: %d, VGI: %d, method: %s", p_dens(i), p_vgi(i), p_method(i)),...
            'output.Directory', fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i))));
    else
        WiLabV2Xsim(p_configFile(i),...
            'simulation.DurationSeconds', sTime, 'rho', p_dens(i), 'roadLength', roadLength*1000,...
            'awareness.RangesMeters', Raw, ...
            'application.PacketGeneration.IntervalVariationSeconds', p_vgi(i), 'application.PacketSizeBytes', dataSize,...
            'coexistence.VehiclePattern.SidelinkVehicleCount', p_v_lte(i), 'coexistence.VehiclePattern.ItsG5VehicleCount', p_v_11p(i),...
            'output.WirelessBlindSpot.Enabled', true, 'output.UpdateDelay.Enabled', true,...
            'output.PacketDelay.Enabled', true, 'output.DataAge.Enabled', true,...
            'simulation.RunLabel', sprintf("dens: %d, VGI: %s, method: %s\n", p_dens(i), p_n_vgi(i), p_method(i)),...
            'output.Directory', fullfile(p_outputF(i), sprintf("sim_%d", p_sim_ids(i))));
    end
end

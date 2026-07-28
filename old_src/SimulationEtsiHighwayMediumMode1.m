% Sample ETSI highway simulation using controlled mode-1 scheduling.

close all
clear
clc

simulatorRoot = fileparts(mfilename("fullpath"));
projectRoot = fileparts(simulatorRoot);
addpath(fullfile(projectRoot,"src"));
addpath(simulatorRoot);

configFile = fullfile( ...
    simulatorRoot,"ConfigFiles","EtsiHighwayMediumMode1.cfg");
% A smoke invocation owns a fresh output directory and never overwrites a
% previous run.
outputFolder = string(tempname);

WiLabV2Xsim(configFile,"outputFolder",outputFolder);

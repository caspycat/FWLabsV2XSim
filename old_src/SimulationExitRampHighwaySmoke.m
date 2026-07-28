% Smoke test for the default exit-ramp highway Scenario.

close all
clear
clc

simulatorRoot = fileparts(mfilename("fullpath"));
projectRoot = fileparts(simulatorRoot);
addpath(fullfile(projectRoot,"src"));
addpath(simulatorRoot);

configFile = fullfile( ...
    simulatorRoot,"ConfigFiles","ExitRampHighwaySmoke.cfg");
% A smoke invocation owns a fresh output directory and never overwrites a
% previous run.
outputFolder = string(tempname);

WiLabV2Xsim(configFile,"outputFolder",outputFolder);

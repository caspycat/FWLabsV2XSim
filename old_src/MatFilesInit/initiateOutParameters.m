function [outParams,varargin] = initiateOutParameters(simParams,~,fileCfg,varargin)
% function [outParams,varargin] = initiateOutParameters(fileCfg,varargin)
%
% Settings of the outputs
% It takes in input the name of the (possible) file config and the inputs
% of the main function
% It returns the structure "outParams"

fprintf('Output settings\n');

% [outputFolder]
% Folder where the output files are recorded
% If the folder is not present, the simulator creates it
[outParams,varargin]= addNewParam([],'outputFolder','Output','Folder for the output files','string',fileCfg,varargin{1});
if exist(outParams.outputFolder,'dir')~=7
    mkdir(outParams.outputFolder);
end
% change the path as absolute path
s = what(outParams.outputFolder);
outParams.outputFolder = s.path;
fprintf('Full path of the output folder = %s\n',outParams.outputFolder);

% Name of the file that summarizes the inputs and outputs of the simulation
% Each simulation adds a line in append
% The file is a xls file
% The name of the file cannot be changed
outParams.outMainFile = 'MainOut.xls';
fprintf('Main output file = %s/%s\n',outParams.outputFolder,outParams.outMainFile);

% Simulation ID
mainFileName = sprintf('%s/%s',outParams.outputFolder,outParams.outMainFile);
fid = fopen(mainFileName);
if fid==-1
    simID = 0;
else
    % use recommended function textscan
    C = textscan(fid,'%s %*[^\n]');
    simID = str2double(C{1}{end});
    fclose(fid);
end
outParams.simID = simID+1;
fprintf('Simulation ID = %.0f\n',outParams.simID);

% [printNeighbors]
% Boolean to activate the print to file of the number of neighbors
[outParams,varargin]= addNewParam(outParams,'printNeighbors',false,'Activate the print to file of the number of neighbors','bool',fileCfg,varargin{1});

% [printSpeed]
[outParams,varargin]= addNewParam(outParams,'printSpeed',false,'Activate the print to file of the speed (trace files)','bool',fileCfg,varargin{1});

% [printUpdateDelay]
% Boolean to activate the print to file of the update delay between received beacons
[outParams,varargin]= addNewParam(outParams,'printUpdateDelay',false,'Activate the print to file of the update delay between received beacons','bool',fileCfg,varargin{1});

% [printWirelessBlindSpotProb]
% Boolean to activate the print to file of the wireless blind spot probability
if outParams.printUpdateDelay
    [outParams,varargin]= addNewParam(outParams,'printWirelessBlindSpotProb',false,'Activate the print to file of the wireless blind spot probability','bool',fileCfg,varargin{1});
    if outParams.printWirelessBlindSpotProb
        % [delayWBSmax]
        % Maximum recordable delay for wireless blind spot probability (s)
        [outParams,varargin]= addNewParam(outParams,'delayWBSmax',10,'Maximum recordable delay for wireless blind spot probability (s)','double',fileCfg,varargin{1});
        if outParams.delayWBSmax<=0
            error('Error: "outParams.delayWBSmax" cannot be <= 0');
        end
        % [delayWBSresolution]
        % Maximum recordable delay for wireless blind spot probability (s)
        [outParams,varargin]= addNewParam(outParams,'delayWBSresolution',0.1,'Resolution of wireless blind spot probability (s)','double',fileCfg,varargin{1});
        if outParams.delayWBSresolution > outParams.delayWBSmax
            error('Error: "outParams.delayWBSresolution > outParams.delayWBSmax" not acceptable');
        end
    end
end

% [printPacketDelay]
% Boolean to activate the print to file of the packet delay between received beacons
[outParams,varargin]= addNewParam(outParams,'printPacketDelay',false,'Activate the print to file of the packet delay between received beacons','bool',fileCfg,varargin{1});

% [printDataAge]
% Boolean to activate the print to file of the data age of received beacons
[outParams,varargin]= addNewParam(outParams,'printDataAge',false,'Activate the print to file of data age of beacons','bool',fileCfg,varargin{1});

% [delayResolution]
% Delay resolution (s)
if outParams.printUpdateDelay || outParams.printDataAge || outParams.printPacketDelay
    [outParams,varargin]= addNewParam(outParams,'delayResolution',0.001,'Delay resolution (s)','double',fileCfg,varargin{1});
    if outParams.delayResolution<=0
        error('Error: "outParams.delayResolution" cannot be <= 0');
    end
end

% [printPacketReceptionRatio]
% Boolean to activate the print to file of the details for distances from 0
% up to the maximum awareness range
[outParams,varargin]= addNewParam(outParams,'printPacketReceptionRatio',false,'Activate the print to file of detailed PRR up to the maximum awareness range','bool',fileCfg,varargin{1});

if outParams.printPacketReceptionRatio
    % [prrResolution]
    [outParams,varargin]= addNewParam(outParams,'prrResolution',10,'Step of the distance for the calculation of the pdr [m]','integer',fileCfg,varargin{1});
    if outParams.prrResolution<1
        error('prrResolution cannot be zero or negative');
    end
end

if simParams.cbrActive
  
    % [printCBR]
    % Boolean to activate the print to file of the channel busy ratio
    [outParams,varargin]= addNewParam(outParams,'printCBR',false,'Activate the print to file of the channel busy ratio','bool',fileCfg,varargin{1});
end

% [message]
[outParams,varargin]= addNewParam(outParams,'message', 'None', 'Message during simulation','string',fileCfg,varargin{1});
fprintf('\n');
%
%%%%%%%%%

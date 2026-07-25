function [simParams,appParams,phyParams,varargin] = initiateSpecificCasesParameters(simParams,appParams,phyParams,fileCfg,varargin)
%
% Settings of specific cases

fprintf('Additional settings\n');

% Packet types: normally only CAMs, which are Type 1
appParams.nPckTypes = 1;

% [RSUcfg]
[appParams,varargin]= addNewParam(appParams,'RSUcfg','null','Config file for RSUs - Null if no RSUs','string',fileCfg,varargin{1});
if ~strcmpi(appParams.RSUcfg,'null')
    if ~exist(appParams.RSUcfg, 'file')
       error('File cfg of RSUs ("%s") does not exist. Set "Null" if no RSUs are to be used.',appParams.RSUcfg);
    end
    appParams = readRSUconfig(appParams.RSUcfg,appParams);
else
    appParams.nRSUs = 0;
end
appParams = rmfield( appParams , 'RSUcfg' );

% The removed multi-channel initializer never had an implementation in
% this codebase. Keep the internal dimension explicit for the single
% supported channel.
phyParams.nChannels = 1;

fprintf('\n');
%
%%%%%%%%%

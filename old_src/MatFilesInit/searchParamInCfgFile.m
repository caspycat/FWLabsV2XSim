function [value,found] = searchParamInCfgFile(filename,paramname,paramType)
% Function used to search for a given parameter in the config file

value = NaN;
found = false;

fid = fopen(filename);
if fid==-1
    return    
end
[C]=textscan(fid,'%s %s','CommentStyle','%');
fclose(fid);

params = C{1};
values = C{2};
for i=1:length(params)
    parameter = char(params(i));
    if parameter(1)=='[' && parameter(end)==']' && strcmpi(parameter(2:end-1),paramname)
        found = true;

        if strcmpi(paramType,'integer') || strcmpi(paramType,'double')
            value = str2double(values(i));
        elseif strcmpi(paramType,'string')
            value = values{i};
        elseif strcmpi(paramType,'bool')

            if strcmpi(values(i),'true')
                value = true;
            elseif strcmpi(values(i),'false')
                value = false;
            else
                error('Error: parameter %s must be a boolean.',params(i));
            end
        elseif strcmpi(paramType,'integerOrArrayString')
            % Numeric arrays are represented as one config-file string.
                value = str2num(values{i}); %#ok<ST2NM>
            %else
            %    value = str2double(values(i));
            %end                
        else
            error('Error in searchParamInCfgFile: paramType can be only integer, double, string, or bool.');
        end
               
        return
    end
end

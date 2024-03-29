% SIMCHECKVERSION
%  Checks to see if a new simEngine is available on the
%  simatratechnologies.com website.
%
% Copyright 2010 Simatra Modeling Technologies
%
function [varargout] = simCheckVersion(varargin)

% Check arguments to simCheckVersion
if nargin == 0
  quiet = false;
elseif nargin == 1
  if strcmpi(varargin{1}, '-quiet')
    quiet = true;
  else
    usage();
    return;
  end
else
  usage();
  return;
end

% check if jvm is enabled
try
    java_available = usejava('jvm');
catch
    java_available = false;
end

if ~java_available
    if ~quiet
        error('Simatra:simCheckVersion:Java', 'Needs jvm enabled in MATLAB to check the current available simEngine version');
    end
    % in quiet mode, don't return anything, just exit...
    if nargout == 1
        varargout{1} = false;
    end
    return
end

% retrieve the latest version information from the website
versionInfo = retrieveLatestVersion(quiet);
if isstruct(versionInfo)
  % Display some information about the license
  if not(quiet)
    ver_str = [num2str(versionInfo.major) '.' num2str(versionInfo.minor) ...
               versionInfo.revision];
    epoch = datenum('01-01-1970');
    try
      gen_date = datestr(epoch+versionInfo.date);
    catch
      error('Simatra:simCheckVersion', ['Can''t interpret date ' num2str(epoch) '+' ...
                   num2str(versionInfo.date)]);
    end
    if isfield(versionInfo, 'build')
      disp(['Latest build of simEngine is ' num2str(versionInfo.build) ' (' ver_str '), built on ' ...
            gen_date]);
    else
      disp(['Latest version of simEngine is ' ver_str ', built on ' ...
            gen_date]);
    end      
  end
else
    if nargout == 1
        varargout{1} = false;
    end
    return;
end

% now create/replace the update.dol file with the new update information
generateUpdateDol(versionInfo, quiet);

% return the structure if asked for
if nargout == 1
    varargout{1} = versionInfo;
end


end


% retrieveLatestVersion - determine online what the latest version is
function versionInfo = retrieveLatestVersion(quiet)
  url = execSimEngine('settings.installation.versionURL.getValue() + "?" + settings.installation.updateQuery.getValue()', quiet);
  if ~url
    url = 'http://www.simatratechnologies.com/simengine-current-version.php';
  end

  %% this is the current location for the current_version.txt file.
  %% It's a simple ':' delimited file that includes the major version,
  %% minor version, revision, and time stamp
  [ver_str, status] = urlread(url);

  if 0 == status
    if not(quiet)
      error('Simatra:simCheckVersion', ['Can''t access the latest version online at ' url '.  Please check your internet connection.']);
    end
    
    %% Can't read the latest version
    versionInfo = false;
  else
    %% Can read it, so just decompose the data
    fields = regexp(ver_str, ',', 'split');

    %% We are expecting four fields
    if 6 == length(fields)
      %% Save those fields as a structure
      versionInfo = struct('major', str2double(fields{1}), ...
                           'minor', str2double(fields{2}), ...
                           'revision', fields{3}, ...
                           'date', str2double(fields{4}), ...
                           'file', fields{5}, ...
                           'size', str2double(fields{6}));
    elseif 8 == length(fields)
      %% Save those fields as a structure
      versionInfo = struct('major', str2double(fields{1}), ...
                           'minor', str2double(fields{2}), ...
                           'revision', fields{3}, ...
                           'date', str2double(fields{4}), ...
                           'file', fields{5}, ...
                           'size', str2double(fields{6}), ...
                           'development', true, ...
                           'build', str2double(fields{8}));
    else
        if not(quiet)
            error('Simatra:simCheckVersion', ['Unexpected format of the ' ...
                'version information at ' url ': ' ver_str]);
        end
        versionInfo = false;
    end
  end
end

% generateUpdateDol - create a dol file with the update information
function generateUpdateDol(versionInfo, quiet)

% Open the file as write
try
    filename = '~/.simatra/update.dol';
    fid = fopen(filename, 'w');
catch
    if not(quiet)
        error('Simatra:simCheckVersion', ['Can''t write dol file: ' filename]);
    end
    return;
end

% Start writing information to the file
fprintf(fid, '// Update DOL file - AUTOGENERATED by simCheckVersion\n');
fprintf(fid, '// Copyright 2010 Simatra Modeling Technologies\n');
fprintf(fid, '// Generated: %s\n', datestr(now));
fprintf(fid, '\n');
fprintf(fid, '<updateMajorVersion = %d>\n', versionInfo.major);
fprintf(fid, '<updateMinorVersion = %d>\n', versionInfo.minor);
fprintf(fid, '<updateRevision = "%s">\n', versionInfo.revision);
fprintf(fid, '<updateBuildDate = %ld>\n', versionInfo.date);
if isfield(versionInfo, 'build')
  fprintf(fid, '<updateBuildNumber = %ld>\n', versionInfo.build);
end
fprintf(fid, '\n');

% Close the file descriptor before returning
fclose(fid);

end

% Run simEngine command and return result
function result = execSimEngine(cmd, quiet)

[pathstr, name, ext] = fileparts(which('simex'));
simEngine = fullfile(pathstr, 'bin', 'simEngine');
print_cmd = ['println(' cmd ')'];
echo_cmd = ['echo ''' print_cmd ''''];
arguments = [' -batch - -startupmessage=false'];

full_cmd = [echo_cmd ' | ' simEngine arguments];

[status, result] = system(full_cmd);

% chomp the trailing new line
if 10 == double(result(end))
    result = result(1:(end-1));
end

% % DEBUG INFO
%if not(quiet)
%    disp(['Default download location: ' result]);
%end
%

if status ~= 0
    if not(quiet)
        disp(['Command: ' full_cmd]);
        disp(['Status: ' num2str(status)]);
        disp(['Result: ' result]);
        warning('Simatra:simCheckVersion', ['simEngine did not execute properly']);
    end
    result = false;
end

end


% usage - display usage information for simCheckVersion
function usage() 

disp(' ');
disp('simCheckVersion - See if a new version is available on the website');
disp(' ');

end
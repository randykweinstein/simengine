%SIMEX   Executes a high-performance software simulation engine using the SIMENGINE compiler.
%
%   Usage:
%       M = SIMEX(MODEL)
%       [OUT Y1 T1] = SIMEX(MODEL, TIME, INPUTS, Y0, ...)
%
%   Description:
%    SIMEX compiles the model defined in the DSL file into a
%    high-performance software simulation engine. SIMEX generates a
%    specially tuned executable version of the model for the selected computing
%    platform and executes the simulation with the given parameters.
%
%    SIMEX(MODEL, TIME, INPUTS, Y0, ...) accepts the following options, all
%    of which are optional except for the file name of the DSL model and the
%    time to execute the simulation.
%
%      MODEL is a full pathname to a DSL model file.
%
%      TIME is the simulation time limit. If scalar, it specifies a
%      simulation starting at T=0 proceeding to T=TIME. TIME must be
%      greater than zero. Otherwise, TIME may be a 2-element array
%      specifying a simulation starting at T=TIME(1) proceeding to
%      T=TIME(2). TIME(2) must be greater than TIME(1).
%
%      INPUTS is a structure containing model parameter values. The
%      field names of the structure correspond to model parameter names.
%      The associated values may be scalar or they may be arrays of
%      length N indicating that N parallel simulations are run. All
%      non-scalar values must have the same length. In parallel
%      simulations, all models receive the same value for scalar inputs.
%
%      Y0 is an array of model initial state values.
%
%      Additional optional parameters may follow:
%
%      '-double'
%        Constructs a simulation engine that computes in
%        double-precision floating point. (This is the default.)
%
%      '-single' '-float'
%        Constructs a simulation engine that computes in
%        single-precision floating point.
%
%      '-cpu'
%        Constructs a serialized cpu-based simulation engine.
%
%      '-parallelcpu'
%        Constructs a multiprocessor cpu-based simulation engine.
%        (This is the default.)
%
%
%    M = SIMEX(MODEL) compiles MODEL as above and returns a
%    model description structure M containing information
%    which describes the model states, parameters, and outputs.
%
% Copyright 2009 Simatra Modeling Technologies, L.L.C.
% For more information, please visit http://www.simatratechnologies.com
%
function [varargout] = simex(varargin)

if nargin == 0
  simex_gui
  return;
end

opts = get_simex_opts(varargin{:});

% Make sure directory exists if we need to write inputs or states
if ~mkdir(opts.outputs);
  error('Simatra:SIMEX:mkdir', ['Could not create temporary directory ' opts.outputs]);
end

if opts.debug
  disp(['Creating temporary directory ' opts.outputs ' to store results and compiled objects.']);
else
  % Cleanup the temporary files
  c = onCleanup(@()removeTempDirectory(opts.outputs));
end
           
interface = get_interface(opts);

if nargin == 1 || ischar(varargin{2}) % alternative is that you
                                     % supply a flag as a second
                                     % arg (not a time)
  varargout = {interface};
else
  userInputs = vet_user_inputs(interface, opts.inputs);
  userStates = vet_user_states(interface, opts.states);
  
  inputsM = size(userInputs,1);
  statesM = size(userStates,1);

  if 1 < inputsM && 1 < statesM && inputsM ~= statesM
    error('Simatra:SIMEX:argumentError', ...
          'When INPUTS and Y0 both contain more than 1 row, they must have the same number of rows.');
  end

  % Write inputs to file
  if 0 < inputsM
    inputsFile = fullfile(opts.outputs, 'inputs');
    opts.args = [opts.args ' -inputs ' inputsFile];
    inputFileID = fopen(inputsFile, 'w');
    if -1 == inputFileID
      error(['Could not open inputs file: ' inputsFile]);
    end
    for i = size(userInputs, 1):opts.instances
      fwrite(inputFileID, userInputs', 'double');
    end
    fclose(inputFileID);
  end

  % Write states to file
  if 0 < statesM
    statesFile = fullfile(opts.outputs, 'states');
    opts.args = [opts.args ' -states ' statesFile];
    stateFileID = fopen(statesFile, 'w');
    if -1 == stateFileID
      error(['Could not open inputs file: ' statesFile]);
    end
    for i = size(userStates,1):opts.instances
      fwrite(stateFileID, userStates', 'double');
    end
    fclose(stateFileID);
  end

  simulate_model(opts);
  
  outputs = {};
  finalStates = zeros(opts.instances, length(interface.states));
  finalTimes = zeros(1, opts.instances);
  for modelid = 1:opts.instances
    for outputid = 1:length(interface.outputs)
      modelDir = fullfile(opts.outputs, modelidToPath(modelid-1));
      outputFile = fullfile(modelDir, interface.outputs{outputid});
      try
        m = memmapfile(outputFile, 'format', 'double');
        outputs(modelid).(interface.outputs{outputid}) = reshape(m.Data, interface.outputNumQuantities(outputid), [])';
      catch it
        % this means there is no data in the output file which can happen for conditional outputs
        outputs(modelid).(interface.outputs{outputid}) = [];
      end
      try
        if(~isempty(interface.states))
          finalStatesFile = fullfile(modelDir, 'final-states');
          m = memmapfile(finalStatesFile, 'format', 'double');
          finalStates(modelid,:) = m.Data;
        end
        finalTimeFile = fullfile(modelDir, 'final-time');
        m = memmapfile(finalTimeFile, 'format', 'double');
        finalTimes(modelid) = m.Data;
      catch it
        error('Simatra:Simex', ['Simulation did not finish, final time was not reached for model instance ' num2str(modelid) '.'])
      end
    end
  end

  varargout = {outputs finalStates finalTimes};
end
end

function removeTempDirectory(directory)
  status = rmdir(directory, 's');
  if ~status
    disp(['Could not remove directory: ' directory])
  end
end

function [val] = stringByte(number, b)
  val = num2str(bitand(bitshift(number, -(b*8)),255), '%02x');
end

function [path] = modelidToPath(modelid)
  path = fullfile(stringByte(modelid,2),stringByte(modelid,1),stringByte(modelid,0));
end

%%
function [opts] = get_simex_opts(varargin)
%
% GET_SIMEX_OPTS parses the options from the command
% invocation.
%

% Make sure the temporary directory simex uses doesn't exist
% if it is there it probably means a previous invocation crashed
opts = struct('simengine','', 'model', '', 'instances',1, 'startTime',0, ...
              'stopTime',0, 'inputs',struct(), 'states',[], ...
              'outputs', '', 'debug', false, 'args', '-binary');

[seroot] = fileparts(which('simex'));
opts.simengine = fullfile(seroot, 'bin', 'simEngine');

% Specify a temporary directory for results
opts.outputs = ['.simex' num2str(now,'%16f')];

if 1 > nargin
  help('simex')
  error('Simatra:SIMEX:argumentError', ...
        'SIMEX requires an input model file name.');
end

opts.model = realpath(varargin{1});

if 1 < nargin
  if isnumeric(varargin{2})
    [opts.startTime opts.stopTime] = get_time(varargin{2});
    start_index = 3;
  else
    start_index = 2;
  end

  for count=start_index:nargin
    arg = varargin{count};
    if isstruct(arg)
      opts.inputs = arg;
    elseif isnumeric(arg)
      opts.states = arg;
    elseif strcmpi(arg, '-debug')
      opts.args = [opts.args ' ' arg];
      opts.debug = true;
    elseif ~(ischar(arg) || isempty(arg))
      error('Simatra:SIMEX:argumentError', ...
            'All additional arguments must be non-empty strings.');
    else
      opts.args = [opts.args ' ' arg];
    end
  end
  
  opts.instances = max(1, size(opts.states,1));
  fnames = fieldnames(opts.inputs);
  for fid = 1:size(fnames)
    opts.instances = max([opts.instances size(opts.inputs.(fnames{fid}))]);
  end
end

end

%%
function [startTime stopTime] = get_time(userTime)
% GET_TIME returns a 2-element array containing the time limit for
% a simulation run.
[rows cols] = size(userTime);

switch (rows * cols)
 case 1
  startTime = 0;
  stopTime = double(userTime);
  if userTime < 0
    error('Simatra:SIMEX:argumentError', ...
          'TIME must be greater than zero.');
  end
 case 2
  startTime = double(userTime(1));
  stopTime = double(userTime(2));
  if stopTime < startTime
    error('Simatra:SIMEX:argumentError', ...
          'TIME(2) must be greater than TIME(1).');
  end
 otherwise
  error('Simatra:argumentError', 'TIME must have length of 1 or 2.');
end
end

%%
function [userInputs] = vet_user_inputs(interface, inputs)
% VET_USER_INPUTS verifies that the user-supplied inputs are valid.
% Returns a MxN matrix where N is the number of model inputs.
% M is the number of parallel models.
if ~isstruct(inputs)
  error('Simatra:typeError', ...
        'Expected INPUTS to be a structure.')
end

models = 0;

fieldnames = interface.inputs;
for fieldid=1:length(fieldnames)
  fieldname = fieldnames{fieldid};
  if ~isfield(inputs, fieldname)
    if isnan(interface.defaultInputs.(fieldname))
      error('Simatra:valueError', 'INPUTS.%s has no default value and must be specified.', fieldname);
    end
    continue
  end

  field = inputs.(fieldname);
  
  if ~isnumeric(field)
    error('Simatra:typeError', 'Expected INPUTS.%s to be numeric.', fieldname);
  elseif issparse(field)
    error('Simatra:typeError', 'Did not expect INPUTS.%s to be sparse.', fieldname);
%  elseif iscomplex(field)
%    warning('Simatra:warning', 'Ignoring imaginary components of INPUTS.%s.', fieldname);
  elseif any(isnan(field))
    error('Simatra:valueError', 'INPUTS.%s may not contain NaN values.', fieldname);
  end
  
  if ~isscalar(field)
    [rows cols] = size(field);
    if 2 < ndims(field)
      error('Simatra:valueError', 'INPUTS.%s may not have more than 2 dimensions.', fieldname);
    elseif ~(1 == rows || 1 == cols)
      error('Simatra:valueError', 'Expected INPUTS.%s to be a vector or scalar.', fieldname);
    end
    
    if 1 < models
      if models ~= length(field)
        error('Simatra:valueError', 'All non-scalar fields must have the same length.');
      end
    else
      models = max(rows, cols);
    end
  elseif 0 == models
    models = 1;
  end
end

userInputs = zeros(models, length(interface.inputs));
for fieldid=1:length(fieldnames)
  fieldname = fieldnames{fieldid};
  if ~isfield(inputs, fieldname)
    userInputs(1:models, fieldid) = interface.defaultInputs.(fieldname) * ones(models, 1);
    continue
  end
  
  field = inputs.(fieldname);
  if isscalar(field)
    userInputs(1:models, fieldid) = double(field) * ones(models, 1);
  elseif length(field) == models
    userInputs(1:models, fieldid) = double(field);
  else
    error('Simatra:valueError', 'Expected INPUTS.%s to have length %d.', fieldname, models);
  end
end

end

%%
function [userStates] = vet_user_states(interface, states)
% VET_USER_STATES verifies that the user-supplied initial states
% contain valid data.
if ~isnumeric(states)
  error('Simatra:typeError', 'Expected Y0 to be numeric.');
elseif issparse(states)
  error('Simatra:typeError', 'Did not expect Y0 to be sparse.');
%elseif iscomplex(states)
%  warning('Simatra:warning', 'Ignoring imaginary components of Y0.');
elseif any(isnan(states))
  error('Simatra:valueError', 'Y0 may not contain NaN values.');
end

[statesRows statesCols] = size(states);
userStates = [];

if 0 < statesRows && 0 < statesCols
  if statesCols ~= length(interface.states)
    error('Simatra:SIMEX:argumentError', ...
          'Y0 must contain %d columns.', length(interface.states));
  end
  userStates = double(states);
end

end


%%
function [abspath] = realpath(relpath, root)
% REALPATH returns a fully-qualified absolute path for a given
% relative path. The ROOT parameter is optional. If given, RELPATH
% is taken as relative to ROOT. If omitted, RELPATH is treated as
% relative to the current working directory.
[dirname file ext ver] = fileparts(relpath);
if isempty(dirname)
    dirname = '.';
end 
command = ['cd ' dirname ';'...
           ' echo $(pwd)/' file ext ver ';'];
if nargin > 1
  command = ['cd ' root '; ' command];
end
[stat, abspath] = system(command);
abspath = strtrim(abspath);
end

% Retrieve the interface from a simulation object and translate it into a format
% amenable to Matlab use
function [interface] = get_interface(opts)
  simex_interface_json = fullfile(opts.outputs, 'simex_interface.json');
  opts.args = [opts.args ' -json-interface ' simex_interface_json];
  status = compile_model(opts);
  if(status)
    error(['Simatra:Simex:simulate_model Model compilation failed (' num2str(status) ').'])
  end
  try
    json_interface = fileread(simex_interface_json);
    interface = parse_json(json_interface);
  catch it
    error('Simatra:Simex:get_interface', 'Could not open interface file.')
  end

  % Convert default inputs to a structure
  defaultInputs = interface.defaultInputs;
  interface.defaultInputs = {};
  for i = 1:length(defaultInputs)
    % Ensure any "NaN", "-Inf", or "Inf" strings are converted to numbers.
    if isa(defaultInputs{i}, 'char')
        interface.defaultInputs.(interface.inputs{i}) = str2num(defaultInputs{i});
    else
        interface.defaultInputs.(interface.inputs{i}) = defaultInputs{i};  
    end
  end

  % Convert default states to a flat vector
  defaultStates = interface.defaultStates;
  interface.defaultStates = zeros(1, length(defaultStates));
  for i = 1:length(defaultStates)
    % Ensure any "NaN", "-Inf", or "Inf" strings are converted to numbers.
    if isa(defaultStates{i}, 'char')
        interface.defaultStates(i) = str2num(defaultStates{i});
    else
        interface.defaultStates(i) = defaultStates{i};
    end
  end

  % Convert output sizes to a flat vector
  outputNumQuantities = interface.outputNumQuantities;
  interface.outputNumQuantities = zeros(1, length(outputNumQuantities));
  for i = 1:length(outputNumQuantities)
    interface.outputNumQuantities(i) = outputNumQuantities{i};
  end

  % Remove fields that have no meaning to user
  interface = rmfield(interface, {'hashcode', 'version'});
end

function [] = simulate_model(opts)
  opts.args = [opts.args ' -start ' num2str(opts.startTime)];
  opts.args = [opts.args ' -stop ' num2str(opts.stopTime)];
  opts.args = [opts.args ' -instances ' num2str(opts.instances)];
  status = compile_model(opts);
  if(status)
    error('Simatra:Simex:simulate_model',['Model simulation failed (' num2str(status) ').'])
  end
end

function [status] = compile_model(opts)
  command = [opts.simengine ' -simex ' opts.model ' -outputs ' opts.outputs ' ' opts.args];
  status = launchBackground(command, opts.outputs);
end

function [status] = launchBackground(command, workingDir)
logFile = fullfile(workingDir, 'logfile');
progressFile = fullfile(workingDir, 'progress');
statusFile = fullfile(workingDir, 'status');
pidFile = fullfile(workingDir, 'pid');

system(['touch ' logFile]);
command = ['(' command ' &>' logFile ' & pid=$! ; echo $pid > ' pidFile ' ; wait $pid; echo $? > ' statusFile ')&'];
[stat, ignore] = system(command);
while ~exist(pidFile) | ~length(fileread(pidFile))
  pause(0.1);
end
% Ignore the newline
pid = num2str(str2num(fileread(pidFile)));
% Remove the file to prevent crosstalk across launchBackground calls
delete(pidFile);

c = onCleanup(@()cleanupBackgroundProcess(pid));

outputlen = 0;
messagelen = 0;
while(processRunning(pid))
  if(~exist('m') & exist(progressFile))
    m = memmapfile(progressFile, 'format', 'double');
  end
  if(exist('m'))
    progress = 100*sum(m.Data)/length(m.Data);
    message = sprintf('Simulating: %0.2f %%', progress);
    messagelen = statusBar(message, messagelen);
  end
  try
    log = fileread(logFile);
  catch
    error('Simatra:Simex:launchBackground', 'Process log file does not exist.')
  end
  if length(log) > outputlen
    fprintf('%s', log(outputlen+1:end));
    outputlen = length(log);
  else
    pause(0.1);
  end
end
try
  log = fileread(logFile);
catch
  error('Simatra:Simex:launchBackground', 'Process log file does not exist.')
end
if length(log) > outputlen
  fprintf('%s', log(outputlen+1:end));
end
try
  status = str2num(fileread(statusFile));
  % Prevent any crosstalk between launchBackground calls
  delete(statusFile);
  if(exist(progressFile))
    messagelen = statusBar('', messagelen);
    delete(progressFile);
  end
  delete(logFile);
catch
  error('Simatra:Simex:launchBackground', 'Process status file does not exist.')
end
end

function [running] = processRunning(pid)
[stat, ignored] = system(['ps -p ' pid ' -o pid=']);
running = not(stat);
end

function cleanupBackgroundProcess(pid)
  % kill is called unconditionally, on CTRL+C the simulation is stopped
  % For normal execution, the process will have exited and the kill won't do anything
  command = sprintf('kill -9 %s', pid);
  [stat, result] = system(command);
  if ~stat
    disp('User terminated simulation.')
  end
end

function [messageLength] = statusBar(message, previousLength)
try
  dt = javaMethod('getInstance', 'com.mathworks.mde.desk.MLDesktop');
  if dt.hasMainFrame
    dt.setStatusText(message);
  else
    textStatusBar(message, previousLength);
  end
catch
  textStatusBar(message, previousLength);
end
messageLength = length(message);
end

function textStatusBar(message, previousLength)
    % Backup over previous message
    for i = 1:previousLength
        fprintf('\b');
    end
    % Wipe the previous message with spaces
    for i = 1:previousLength
        fprintf(' ');
    end
    % Backup over spaces
    for i = 1:previousLength
        fprintf('\b');
    end
    % Print a new message if available
    if length(message)
      fprintf('%s', message);
    end
end

function [outputs y1 t1 interface] = simEngine (options)
%  SIMENGINE Executes a compiled simulation
    options = writeUserInputs(options);
    writeUserStates(options);
    
    [outputs y1 t1 interface] = simulateModel(options);
end

%%
function [options] = writeUserInputs (options)
%  WRITEUSERINPUTS Creates files for the inputs of each model instance.
    inputs = options.inputs;
    
    if ~isstruct(inputs)
        simexError('typeError', 'Expected INPUTS to be a structure array.')
    end
    
    names = fieldnames(inputs);

    % Tell simEngine which inputs were written to files
    if length(names) > 0
      nameslist = names{1};
      for n = 2:length(names)
        nameslist = [nameslist ':' names{n}];
      end
      options.args = [options.args [' --inputs ' nameslist]];
    end
    
    for modelid = 1:options.instances
        modelPath = modelidToPath(modelid-1);
        mkdir(fullfile(options.outputs, modelPath), 'inputs');
        for inputid = 1:length(names)
            field = names{inputid};
            if ~isfield(options.inputs, field)
                warning(['INPUTS.' field ' is not a model input.']);
                continue
            end
            filename = fullfile(options.outputs, modelPath, 'inputs', field);
            fid = fopen(filename, 'w');
            onCleanup(@()fid>0 && fclose(fid));
            
            if -1 == fid
                simFailure('simEngine', ['Unable to write inputs file ' filename]);
            end
            
            if 1 == max(size(inputs))
                % INPUTS given as a structure of scalars or cell arrays
                value = inputs.(field);
                if iscell(value)
                    if 1 == length(value)
                        if isnan(value{1})
                            simexError('valueError', ['INPUTS.' field ' may not contain NaN.']);
                        end
                        fwrite(fid, value{1}, 'double');
                    else
                        if isnan(value{modelid})
                            simexError('valueError', ['INPUTS.' field ' may not contain NaN.']);
                        end
                        fwrite(fid, value{modelid}, 'double');
                    end
                elseif isnan(value)
                    simexError('valueError', ['INPUTS.' field ' may not contain NaN.']);
                else
                    fwrite(fid, value, 'double');
                end
            else
                value = inputs(modelid).(field);
                fwrite(fid, value, 'double');
            end
        end
    end
end
%%
function writeUserStates (options)
% WRITEUSERSTATES Creates files for the initial states of each model instance.
    states = options.states;
    
    if ~isempty(states)
        for modelid = 1:options.instances
            modelPath = modelidToPath(modelid-1);
            filename = fullfile(options.outputs, modelPath, 'initial-states');
            fid = fopen(filename, 'w');
            onCleanup(@()fid>0 && fclose(fid));
            if -1 == fid
                simFailure('simEngine', ['Unable to write states file ' filename]);
            end
            
            if 1 == size(states, 1)
                fwrite(fid, states, 'double');
            else
                fwrite(fid, states(modelid,:), 'double');
            end
        end
    end
end
%%
function [outputs y1 t1 interface] = simulateModel(opts)
  if opts.stopTime ~= 0
    opts.args = [opts.args ' --start ' num2str(opts.startTime)];
    opts.args = [opts.args ' --stop ' num2str(opts.stopTime)];
    opts.args = [opts.args ' --instances ' num2str(opts.instances)];
  end
  
  interface = simCompile(opts);

  if opts.stopTime ~= 0  
    [outputs y1 t1] = readSimulationData(interface, opts);
  else
    outputs = struct();
    y1 = [];
    t1 = [];
  end
end
%%
function [val] = byte(number, b)
    val = bitand(bitshift(number, -(b*8)),255);
end

function [path] = modelidToPath(modelid)
    path = sprintf('%02x%s%02x%s%02x', byte(modelid,2), filesep, byte(modelid,1), filesep, byte(modelid,0));
end

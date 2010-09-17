classdef Instance
    
    properties
        InstName
        ClassName
        Inputs
        Outputs
        Mdl
        SubMdl
    end
    
    properties (Access = protected)
        definedInputs
    end
    
    methods
        function inst = Instance(InstName, Mdl, SubMdl, Inputs, Outputs)
            inst.Mdl = Mdl;
            inst.SubMdl = SubMdl;
            inst.InstName = InstName;
            inst.Inputs = Inputs;
            inst.Outputs = Outputs;
            inst.definedInputs = containers.Map;
        end
        
        function b = subsref(inst, s)
            if length(s) == 1 && isfield(s, 'type') && strcmp(s.type, '.')
                % make sure that the output exists
                out = s.subs;
                %items = strfind(inst.Outputs, s.subs);
                %if isempty(cell2mat(items))
                if isOutput(inst, out)
                    output = Exp(inst.InstName, s.subs);
                    b = output;
                elseif isInput(inst, out)
                    % now, if it's an input, we can still handle that by
                    % returning what ever is defined, if it has been
                    % defined
                    if isKey(inst.definedInputs, out)
                        b = inst.definedInputs(out);
                    else
                        error('Simatra:Instance', 'Can not read from an input of a submodel if it has not been already defined.')
                    end    
                elseif strcmp(out, 'Inputs')
                    b = inst.Inputs;
                elseif strcmp(out, 'Outputs')
                    b = inst.Outputs;
                elseif strcmp(out, 'ModelObject')
                    b = inst.SubMdl;
                else
                    inst.Outputs
                    error('Simatra:Instance', 'No output with name %s found', s.subs);
                end
            else
                for i=1:length(s)
                    i
                    s(i)
                end
                error('Simatra:Instance', 'Unexpected argument syntax');
            end
        end
        
        function i2 = subsasgn(inst, s, b)
            if length(s) == 1 && isfield(s, 'type') && strcmp(s.type, '.')
                inp = s.subs;
                if ~isInput(inst, inp)
                    inst.Inputs
                    error('Simatra:Instance', 'No input with name %s found', inp);
                end
                input = Exp(inst.InstName, s.subs);
                inst.Mdl.equ(input, b);
                inst.definedInputs(inp) = b;
            end
            i2 = inst;
        end
        
        function r = isInput(inst, inp)
            r = any(strcmp(inst.Inputs, inp));
        end
        
        function r = isOutput(inst, out)
            r = any(strcmp(inst.Outputs, out));
        end
    end
    
end
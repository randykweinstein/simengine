classdef Unit < GenericUnit
    
    properties %(Access = protected)
    end
    
    methods
        function u = Unit(name, id, data)
            switch nargin
                case 0
                    error('Simatra:Unit', 'not enough arguments');
                case 1
                    u.name = false;
                    u.id = false;
                    if isstruct(name)
                        u.data = name;
                    elseif isa(name, 'GenericUnit')
                        u.data = struct('unit', name, 'prefix', 1, 'exp', 1);
                    else
                        error('Simatra:Unit', 'first argument is not in the proper form')
                    end
                case 2
                    u_base = BaseUnit(name, id);
                    u.data = u_base.data;
                    u.id = u_base.id;
                    u.name = u_base.name;
                otherwise
                    u.name = name;
                    u.id = id;
                    if isstruct(data)
                        u.data = data;
                    elseif isa(data, 'GenericUnit')
                        u.data = struct('unit', data, 'prefix', 1, 'exp', 1);
                    else
                        error('Simatra:Unit', 'third argument must be a unit or a structure of unit data')
                    end
            end
            [u.flatfactor, u.flatdata] = flatten(u);
            u.flatdata = aggregate(u);
        end
        
        function disp(u)
            if islogical(u.name) && ~u.name
                disp(['Generated Unit: ' toStr(u)]);
            else
                disp([sprintf('Generated Unit: %s (%s) ', u.name, u.id) toStr(u)])
            end           
        end
        
        function s = toStr(u)
            c = {};
            if u.flatfactor ~= 1
                c{1} = num2str(u.flatfactor);
            end
            for i=1:length(u.flatdata)
                d = u.flatdata(i);
                str = d.unit.id;
                if d.exp ~= 1
                    str = [str '^' num2str(d.exp)];
                end
                if length(u.flatdata) == 1 || ~strcmp(d.unit.id, '_')
                    c{end+1} = str;
                end
            end
            s = '';
            for i=1:(length(c)-1)
                s = [s c{i} '*'];
            end
            if isempty(c)
                s = '_';
            else
                s = [s c{end}];
            end
        end
    end

    
end

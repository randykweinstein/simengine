classdef Exp
    
    properties (Constant, Access = private)
        NULLEXP = 0
        VARIABLE = 1
        LITERAL = 2
        OPERATION = 3
        REFERENCE = 4
        ITERATOR = 5
    end
    
    properties (Access = private)
        type
        val
        op
        args
        dims = [1 1]
        iterReference = false
    end
    
    methods
        function e = Exp(v, sub)
            if nargin == 0
                e.val = '';
                e.type = e.NULLEXP;
            elseif nargin == 1
                e.val = v;
                if ischar(v)
                    e.type = e.VARIABLE;
                elseif isnumeric(v)
                    e.type = e.LITERAL;
                    e.dims = size(v);
                elseif isa(v, 'Exp')
                    e = v;
                elseif isa(v, 'Iterator')
                    e.type = e.ITERATOR;
                    e.iterReference = v;
                    e.val = v.id;
                end
            elseif nargin == 2
                e.val = [v '.' sub];
                e.type = e.REFERENCE;
            end
        end
        
        % Algebraic operations
        function er = plus(varargin)
            fcn = @(elem, init)(oper('+', {init, elem}));
            switch nargin
                case 0
                    error('Simatra:Exp:plus','Not enough input arguments');
                case 1
                    er = Exp(varargin{1}); % NON STANDARD BEHAVIOR
                case 2
                    er = oper('+', varargin);
                otherwise
                    er = List.foldl(fcn, varargin{1}, varargin(2:end));
            end
            %er = oper('+', {e1, e2});
        end
        
        function er = minus(e1, e2)
            er = oper('-', {e1, e2});
        end
        
        function er = uminus(e1)
            er = oper('-', {e1});
        end
        
        function er = times(varargin)
            fcn = @(elem, init)(oper('*', {init, elem}));
            switch nargin
                case 0
                    error('Simatra:Exp:times','Not enough input arguments');
                case 1
                    er = Exp(varargin{1}); % NON STANDARD BEHAVIOR
                case 2
                    er = oper('*', varargin);
                otherwise
                    er = List.foldl(fcn, varargin{1}, varargin(2:end));
            end
            %er = oper('*', {e1, e2});
        end
        
        function er = mtimes(e1, e2)
            er = oper('*', {e1, e2});
        end
        
        function er = rdivide(e1, e2)
            er = oper('/', {e1, e2});
        end

        function er = mrdivide(e1, e2)
            er = oper('/', {e1, e2});
        end

        function er = ldivide(e1, e2)
            er = oper('/', {e2, e1});
        end

        function er = mldivide(e1, e2)
            er = oper('/', {e2, e1});
        end
        
        function er = power(e1, e2)
            er = oper('^', {e1, e2});
        end
        
        function er = mpower(e1, e2)
            er = oper('^', {e1, e2});
        end
        
        function er = mod(e1, e2)
            er = oper('%%', {e1, e2});
        end
        
        % Relational
        function er = gt(e1, e2)
            er = oper('>', {e1, e2});
        end

        function er = lt(e1, e2)
            er = oper('<', {e1, e2});
        end
        
        function er = ge(e1, e2)
            er = oper('>=', {e1, e2});
        end

        function er = le(e1, e2)
            er = oper('<=', {e1, e2});
        end
        
        function er = eq(e1, e2)
            er = oper('==', {e1, e2});
        end
         
        function er = ne(e1, e2)
            er = oper('<>', {e1, e2});
        end
        
        % Logical
        function er = and(varargin)
            fcn = @(elem, init)(oper(' and ', {init, elem}));
            switch nargin
                case 0
                    error('Simatra:Exp:and','Not enough input arguments');
                case 1
                    er = Exp(varargin{1}); % NON STANDARD BEHAVIOR
                case 2
                    er = oper(' and ', varargin);
                otherwise
                    er = List.foldl(fcn, varargin{1}, varargin(2:end));
            end
            %er = oper(' and ', {e1, e2});
        end
        
        function er = or(varargin)
            fcn = @(elem, init)(oper(' or ', {init, elem}));
            switch nargin
                case 0
                    error('Simatra:Exp:or','Not enough input arguments');
                case 1
                    er = Exp(varargin{1}); % NON STANDARD BEHAVIOR
                case 2
                    er = oper(' or ', varargin);
                otherwise
                    er = List.foldl(fcn, varargin{1}, varargin(2:end));
            end
            %er = oper(' or ', {e1, e2});
        end

        function er = not(e1)
            er = oper('not', {e1});
        end

        % Functions
        function er = exp(e1)
            er = oper('exp', {e1});
        end
        function er = log(e1)
            er = oper('ln', {e1});
        end
        function er = log10(e1)
            er = oper('log10', {e1});
        end
        function er = sqrt(e1)
            er = oper('sqrt', {e1});
        end
        function er = abs(e1)
            er = oper('abs', {e1});
        end
        
        % Trig functions
        function er = sin(e1)
            er = oper('sin', {e1});
        end
        function er = cos(e1)
            er = oper('cos', {e1});
        end
        function er = tan(e1)
            er = oper('tan', {e1});
        end
        function er = csc(e1)
            er = oper('csc', {e1});
        end
        function er = sec(e1)
            er = oper('sec', {e1});
        end
        function er = cot(e1)
            er = oper('cot', {e1});
        end
        function er = asin(e1)
            er = oper('asin', {e1});
        end
        function er = acos(e1)
            er = oper('acos', {e1});
        end
        function er = atan(e1)
            er = oper('atan', {e1});
        end
        function er = acsc(e1)
            er = oper('acsc', {e1});
        end
        function er = asec(e1)
            er = oper('asec', {e1});
        end
        function er = acot(e1)
            er = oper('acot', {e1});
        end
        function er = sinh(e1)
            er = oper('sinh', {e1});
        end
        function er = cosh(e1)
            er = oper('cosh', {e1});
        end
        function er = tanh(e1)
            er = oper('tanh', {e1});
        end
        function er = csch(e1)
            er = oper('csch', {e1});
        end
        function er = sech(e1)
            er = oper('sech', {e1});
        end
        function er = coth(e1)
            er = oper('coth', {e1});
        end
        function er = asinh(e1)
            er = oper('asinh', {e1});
        end
        function er = acosh(e1)
            er = oper('acosh', {e1});
        end
        function er = atanh(e1)
            er = oper('atanh', {e1});
        end
        function er = acsch(e1)
            er = oper('acsch', {e1});
        end
        function er = asech(e1)
            er = oper('asech', {e1});
        end
        function er = acoth(e1)
            er = oper('acoth', {e1});
        end
        
        % Piecewise functions
        function er = piecewise(varargin)            
            if nargin == 1 && iscell(varargin{1})
                args = varargin{1};
            else
                args = varargin;
            end
            isOdd = mod(length(args), 2) == 1;
            if ~isOdd
                error('Simatra:Exp:piecewise', 'Pieceswise expects an odd number of Expression arguments')
            end
            er = oper('piecewise', varargin);
        end
        
        % extra functions
        function er = piecewise_piece(e1, e2)
            er = oper('piece', {e1, e2});
        end
        function er = piecewise_otherwise(e1)
            er = oper('otherwise', e1);
        end
        
        % Compound functions (TODO - make these have arbitrary numbers of
        % arguments)
        function er = max(e1, e2)
            er = piecewise(e1, e1 > e2, e2);
        end
        function er = min(e1, e2)
            er = piecewise(e1, e1 < e2, e2);
        end        
        
        % for arrays
        function l = length(e1)
            if e1.dims(1) == 1 && length(e1.dims)>1
                l = e1.dims(2);
            else
                l = e1.dims(1);
            end
        end
        
        function s = size(e1, ind)
            if 1 == nargin
                s = e1.dims;
            else
                s = e1.dims(ind);
            end
        end
        
        function str = toId(e)
            str = regexprep(toStr(e),'\.','__');
        end
        
        function b = isRef(e)
            b = (e.type == e.REFERENCE);
        end
        
        function er = subsref(e, s)
            er = e;
            for i=1:length(s)
                if strcmp(s(i).type,'()')
                    subs = s(i).subs;
                    for j=1:length(subs)
                        %disp(sprintf('j=%d; e.val=%s; subs{j}=%d', j, num2str(e.val), subs{j}));
                        if isnumeric(subs{j})
                            if subs{j} >= 1 && (subs{j} <= e.dims(j) || (length(e) > e.dims(j) && subs{j} <= length(e)))
                                e = Exp(e.val(subs{j}));
                            else
                                error('Simatra:Exp:subsref', 'Invalid index into quantity');
                            end
                        elseif isa(subs{j},'IteratorReference')
                            e.iterReference = subs{j};
                        elseif isa(subs{j},'Iterator')
                            e.iterReference = subs{j}.toReference;
                        end
                        er = e;
                    end
                elseif strcmp(s(i).type,'.')
                    switch s(i).subs
                        case 'toStr'
                            er = toStr(e);
                        otherwise
                            error('Simatra:Exp:subsref', 'Unrecognized method %s', s(i).subs);
                    end
                end
            end

        end
        
        % Expression Processing
        % =======================================================
        
        function syms = exp_to_symbols(e)
            if ~isa(e, 'Exp')
                class(e)
                e
                error('Simatra:Exp:exp_to_symbols', 'Argument is not an expression');
            elseif isempty(e.type)
                e.val
                error('Simatra:Exp:exp_to_symbols', 'Expression type is empty');                
            end
            
            
            switch e.type
                case {e.VARIABLE, e.ITERATOR}
                    syms = {e.val};
                case e.LITERAL
                    syms = {};
                case e.REFERENCE
                    syms = {}; % ignore this since this is a different scope
                case e.OPERATION
                    syms = {};
                    for i=1:length(e.args)
                        syms = [syms exp_to_symbols(e.args{i})];
                    end
            end
            syms = unique(syms);
        end
        
        
        function i = toIterReference(e)
        i = e.iterReference;
        end
        
        function iters = findIterators(e, map)
            if 1 == nargin
                map = containers.Map;
            end
            
            if isempty(e.type)
                e
                error('Simatra:Exp:findIterators', 'Unexpected empty expression type')
            end
            switch e.type
                case {e.VARIABLE, e.REFERENCE}
                    if isa(e.iterReference, 'IteratorReference')
                        iter = e.iterReference.iterator;
                        map(iter.id) = iter;
                    end
                case e.ITERATOR
                    map(e.val) = e.iterReference;
                case e.OPERATION
                    for i=1:length(e.args)
                      if isa(e.args{i}, 'Exp')
                        map = findIterators(e.args{i}, map);
                      end
                    end
            end
            iters = map;            
        end
        
        
        % Display functions
        % =======================================================
        
        function s = char(e)
            s = toStr(e);
        end
        
        function s = toStr(e)
            if isempty(e.type)
                e.val
                error('Simatra:Exp:toStr', 'Unexpected empty expression type')
            end

            switch e.type
                case e.VARIABLE
                    s = e.val;
                    if isa(e.iterReference, 'IteratorReference')
                        s = [s '[' e.iterReference.toStr ']'];
                    end
                case e.REFERENCE
                    s = e.val;
                    if isa(e.iterReference, 'IteratorReference')
                        s = [s '[' e.iterReference.toStr ']'];
                    end
                case e.ITERATOR
                    s = e.val;
                case e.LITERAL
                    if length(e.val) > 1
                        s = ['[' num2str(e.val) ']'];
                    else
                        s = num2str(e.val);
                    end
                case e.OPERATION
                    if strcmp(e.op, 'piecewise')
                        if length(e.args) == 1
                            s = toStr(e.args{1});
                        else
                            s = '{';
                            for i=1:2:(length(e.args)-1);
                                s = [s toStr(e.args{i}) ' when ' toStr(e.args{i+1}) ', '];
                            end
                            s = [s  toStr(e.args{end}) ' otherwise}'];
                        end
                    else
                        if length(e.args) == 1
                            s = ['(' e.op '(' toStr(e.args{1}) '))'];
                        elseif length(e.args) == 2
                            s = ['(' toStr(e.args{1}) e.op toStr(e.args{2}) ')'];
                        end
                    end
            end
        end
        
        function disp(e)
            disp(['Exp: ' toStr(e)]);
        end
    end
    
    
    
    
end

function er = oper(operation, args)
len = length(args);
exps = cell(1,len);
for i=1:len
    exps{i} = Exp(args{i});
end
er = Exp;
% check binary operations
if len == 2
    len1 = length(args{1});
    len2 = length(args{2});
    if len1 > 1 && len2 > 1 && (len1 ~= len2)
        error('Simatra:Exp', 'Invalid array sizes');
    end
    if len1 > len2
        er.dims = exps{1}.dims;
    else
        er.dims = exps{2}.dims;
    end
end
er.type = er.OPERATION;
er.op = operation;
er.args = exps;
end


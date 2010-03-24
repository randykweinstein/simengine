function [varargout] = simex(dsl, varargin)
%  SIMEX Executes a high-performance software simulation engine using the SIMENGINE compiler.
%     Usage:
%     [OUT Y1 T1] = SIMEX(DSL, TIME, INPUTS, ...)
%     [OUT Y1 T1] = SIMEX(DSL, TIME, INPUTS, '-resume', Y0, ...)
%     M = SIMEX(DSL)
%
%     Description:
%     SIMEX compiles the model defined in the DSL file into a
%     high-performance software simulation engine.
%
%     SIMEX(DSL, TIME, ...) accepts the following options, all
%     of which are optional except for the file name of the DSL model and the
%     time to execute the simulation.
%
%       DSL is a full pathname to a DSL model file.
%
%       TIME is the simulation time limit. If scalar, it specifies a
%       simulation starting at T=0 proceeding to T=TIME. TIME must be
%       greater than zero.
%
%       TIME may be a 2-element array specifying a simulation
%       starting at T=TIME(1) proceeding to T=TIME(2). TIME(2) must
%       be greater than TIME(1) and TIME(1) must be greater than
%       zero.
%
%       INPUTS is a structure containing model parameter values. The
%       field names of the structure correspond to model parameter names.
%       The associated values may be scalar or they may be cell arrays of
%       length M indicating that M parallel simulations are to be
%       executed. All cell arrays must be the same size. In parallel
%       simulations, scalar inputs are replicated for all models.
%
%       '-resume'
%         The simulation will continue from the initial state vector
%         specified in Y0. All state initial values specified within
%         the model are ignored.
%
%         Y0 is an array of model initial state values. It should be
%         the value returned in Y1 from a previous execution. If
%         parallel inputs are given, the number of rows in Y0 must
%         be the same as the number of elements in the input cell array.
%
%       Additional optional parameters may follow:
%
%       '-float'
%         Constructs a simulation engine that computes in
%         lower-precision floating point.
%
%       '-gpu'
%         Constructs a parallel simulation engine capable of
%         executing on a GPU.
%
%       Up to three values are returned:
%
%       OUT is a structure array containing model output
%       values. The structure array itself has length M where M is
%       the number of parallel simulations. The field names of the
%       structure correspond to model output names. The field
%       values are two-dimensional matrices of varying sizes. The
%       first dimension correlates to the time axis; the size of
%       the second dimension is determined by the number of
%       quantities specified in the model output.
%
%       Y1 is an N-by-M matrix of final state values where N is the
%       number of states in a model and M is the number of parallel
%       simulations.
%
%       T1 is a scalar value representing the time at which the
%       simulation ended.
%
%     M = SIMEX(DSL) compiles DSL as above and returns a
%     model description structure M containing information
%     which describes the model states, inputs, and outputs.
%
% Copyright 2009,2010 Simatra Modeling Technologies, L.L.C.
% For more information, please visit http://www.simatratechnologies.com
% For additional help, please email support@simatratechnologies.com
%
    options = simexOptions(dsl, varargin{:});
    makeOutputDirectory (options);
    interface = simInterface (options);
    
    if 1 == nargin || ischar(varargin{1})
        % No time given, just return the interface
        varargout = {interface};
    else
        % Execute the simulation
        varargout = cell(1,3);
        [varargout{:}] = simEngine(interface, options);
    end
end

function makeOutputDirectory (options)
    if ~mkdir(options.outputs)
        simexError('mkdir', ['Could not create temporary data directory ' options.outputs]);
    end
    if ~options.debug
        onCleanup(@()(cleanUp(options)));
    else
        disp(['Created temporary data directory ' options.outputs]);
    end
end

function cleanUp (options)
    status = rmdir(options.outputs, 's');
    if ~status
        warning(['Could not remove temporary data directory: ' directory '. ' ...
                 'Please remove this directory manually as it is no ' ...
                 'longer needed by simEngine'])
    end
end

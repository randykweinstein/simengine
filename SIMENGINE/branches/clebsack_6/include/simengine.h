/*** NOTE some of this is legacy of diesel compiler, may be
 * incompletely integrated. ***/
#define YES 1
#define NO 0

#define NMALLOC(NMEM, TYP) ((TYP *)MALLOC((NMEM) * sizeof(TYP)))
#define NREALLOC(PTR, NMEM, TYP) ((TYP *)REALLOC(PTR, (NMEM) * sizeof(TYP)))

#ifndef MIN
#define MIN(X, Y) ((X) < (Y) ? (X) : (Y))
#endif
#ifndef MAX
#define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

#ifdef SIMENGINE_MATLAB_CLIENT
#include <mex.h>
// The following macros invoke MATLAB API functions.
#define MALLOC mxMalloc
#define REALLOC mxRealloc
#define FREE mxFree
#define PRINTF mexPrintf
#define ERROR(ID, MESSAGE, ARG...) mexErrMsgIdAndTxt(#ID, MESSAGE, ##ARG)
#define WARN(ID, MESSAGE, ARG...) mexWarnMsgIdAndTxt(#ID, MESSAGE, ##ARG)
#else
#define MALLOC malloc
#define REALLOC realloc
#define FREE free
#define PRINTF printf
// NOTE that this macro expands to multiple statements making it
// potentially dangerous in conditionals if one is in the habit of
// omitting braces.
// TODO replace with a single-statement function call?
#define ERROR(ID, MESSAGE, ARG...) {fprintf(stderr, "ERROR (%s): " MESSAGE "\n",  #ID, ##ARG); exit(-1); }
#define WARN(ID, MESSAGE, ARG...) fprintf(stderr, "WARNING (%s): " MESSAGE "\n", #ID, ##ARG)
#endif

// The type of simulation quantity values.
#ifdef SIMENGINE_DOUBLE_STORAGE
typedef double CDATAFORMAT;
#define FLITERAL(X) X
#else
typedef float CDATAFORMAT;
// Ensures that operations involving literal quantities are not promoted to double-precision.
#define FLITERAL(X) X##f
#endif

typedef unsigned long counter;


/*** Carl's code starts here ***/
/*
 * simengine.h
 *
 * API interface to the Simatra simEngine model execution.
 *
 * Copyright 2009 Simatra Modeling Technologies
 */
#include <stddef.h>

enum{ SUCCESS, ERRMEM, ERRCOMP, ERRNUMMDL};

char *errors[] = {"Success", "Out of memory error", "Flow computation error", "Wrong number of models"};

typedef struct {
  const unsigned long long hashcode; // Signature of the DSL model file
  const unsigned int num_models; // Parallel count of models given at compilation
  const char *solver; // Name of integration method
  const size_t precision; // Number of bytes in data storage, e.g. 4 = single-precision
  // TODO maybe include data about the compiler itself, e.g. branch id, build time, etc.
} simengine_metadata;

typedef struct{
  const unsigned long version;
  const unsigned int num_inputs;
  const unsigned int num_states;
  const unsigned int num_outputs;
  const char **input_names;
  const char **state_names;
  const char **output_names;
  const double *default_inputs;
  const double *default_states;
  const char *name;
  const simengine_metadata *metadata;
} simengine_interface;

// Josh: variables that track counts should be declared as
// unsigned long. We should also be bounds-checking, especially
// quantities that track the number of samples. Most likely we'd run
// out of memory before overrunning a 32-bit counter but we could
// eventually be working with >20GB RAM.
/* Output data are stored interleaved.
 * The data of an output with Q quantities over T samples would look like
 *     [q0t0, q1t0, ... qQt0, q0t1, q1t1, ... qQt1, ... qQtT]
 */
typedef struct{
  int num_quantities;
  int num_samples;
  double *data;
} simengine_output;

/* Model outputs are stored consecutively.
 * The results of M models with N outputs would look like
 *     [m0o0, m0o1, ... m0oN, m1o0, m1o1, ... m1oN, ... mMoN]
 */
typedef struct{
  unsigned int status;
  char *status_message;
  simengine_output *outputs;
} simengine_result;

typedef struct{
  void *(*malloc)(size_t);
  void *(*realloc)(void *, size_t);
  void (*free)(void *);
} simengine_alloc;

typedef struct {
  simengine_interface *(*getinterface)(void);
  simengine_result *(*runmodel)(double, double, unsigned int, double *, double *, simengine_alloc *);
  void *driver;
} simengine_api;

/*
 * simengine_getinterface()
 *
 * outputs:
 *          simengine_interface * - pointer to a static structure within a model that defines its interface
 */
const simengine_interface *simengine_getinterface();



/*
 * simengine_runmodel()
 *
 * inputs:
 *         start_time - time to start simulation
 *         stop_time - time to stop simulation
 *         num_models - dimensionality of inputs value greater than 1 indicates parallel execution of models
 *         inputs - array of input values to the simulation (contiguous arrays when num_input_sets > 1)
 *         states - array of state initial values to the simulation (contiguous arrays when num_state_sets > 1)
 *         alloc - allocation routines used for simengine_output return data
 *
 * outputs:
 *          simengine_output * - returns an array of output structures with the data produced by the models
 *                               outputs from a single model are contiguous
 */
simengine_result *simengine_runmodel(double start_time, double stop_time, unsigned int num_models, double *inputs, double *states, simengine_alloc *alloc);


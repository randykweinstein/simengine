// Solvers Header File
// Copyright 2009 Simatra Modeling Technologies, L.L.C.

#ifndef SOLVERS_H
#define SOLVERS_H

#include <simengine_target.h>
#include <stdlib.h>
#include <math.h>

// Defines a solver entry point
#define SOLVER(solver, entry, target, type, args...)  \
  JOIN4(solver, entry, target, type)(args)
// Helper macro to allow nested macro expansion of arguments to INTEGRATION_METHOD
#define JOIN4(w, x, y, z) w##_##x##_##y##_##z

// Solver indexing mode for states
#define STATE_IDX TARGET_IDX(mem->props->statesize, mem->props->num_models, i, modelid)

// Properties data structure
// ============================================================================================================

typedef struct {
  // Pointers to GPU device memory, used only on the Host for transfers
  CDATAFORMAT *time;
  CDATAFORMAT *model_states;
  uint blockx; // kernel geometry
  uint blocky;
  uint blockz;
  uint gridx;
  uint gridy;
  uint gridz;
  size_t shmem_per_block;
  int ob_mapped; // 1 if the output buffers are mapped for zero-copy.
  int async; // 1 if executing asyncronously
  void *ob; // output buffers; may be memory-mapped on capable devices
} gpu_data;

typedef struct {
  unsigned int outputid;
  unsigned int nquantities;
  CDATAFORMAT data[];
} ob_data;

typedef struct {
  CDATAFORMAT timestep;
  CDATAFORMAT abstol;
  CDATAFORMAT reltol;
  CDATAFORMAT starttime;
  CDATAFORMAT stoptime;
  CDATAFORMAT *time;
  CDATAFORMAT *model_states;
  CDATAFORMAT *inputs;
  CDATAFORMAT *outputs;
  unsigned int inputsize;
  unsigned int statesize;
  unsigned int outputsize;
  unsigned int num_models;
  unsigned int ob_size;
  void *ob;
  gpu_data gpu;
  int *running;
} solver_props;


// Pre-declaration of model_flows, the interface between the solver and the model
__DEVICE__ int model_flows(CDATAFORMAT t, const CDATAFORMAT *y, CDATAFORMAT *dydt, CDATAFORMAT *inputs, CDATAFORMAT *outputs, unsigned int first_iteration, unsigned int modelid, unsigned int threadid, solver_props *props);


// Forward Euler data structures and function declarations
// ============================================================================================================

typedef struct {
  solver_props *props;
  CDATAFORMAT *k1;
} forwardeuler_mem;

forwardeuler_mem *SOLVER(forwardeuler, init, TARGET, SIMENGINE_STORAGE, solver_props *props);

__DEVICE__ void SOLVER(forwardeuler, pre_eval, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(forwardeuler, post_eval, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem, uint modelid, uint threadid, uint blocksize);
#if defined TARGET_GPU
__DEVICE__ void SOLVER(forwardeuler, stage, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem, CDATAFORMAT *s_states, CDATAFORMAT *g_states, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(forwardeuler, destage, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem, CDATAFORMAT *g_states, CDATAFORMAT *s_states, uint modelid, uint threadid, uint blocksize);
#endif
__DEVICE__ int SOLVER(forwardeuler, eval, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem, uint modelid, uint threadid);

void SOLVER(forwardeuler, free, TARGET, SIMENGINE_STORAGE, forwardeuler_mem *mem);


// Runga-Kutta (4th order) data structures and function declarations
// ============================================================================================================

typedef struct {
  solver_props *props;
  CDATAFORMAT *k1;
  CDATAFORMAT *k2;
  CDATAFORMAT *k3;
  CDATAFORMAT *k4;
  CDATAFORMAT *temp;
} rk4_mem;

rk4_mem *SOLVER(rk4, init, TARGET, SIMENGINE_STORAGE, solver_props *props);

__DEVICE__ void SOLVER(rk4, pre_eval, TARGET, SIMENGINE_STORAGE, rk4_mem *mem, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(rk4, post_eval, TARGET, SIMENGINE_STORAGE, rk4_mem *mem, uint modelid, uint threadid, uint blocksize);
#if defined TARGET_GPU
__DEVICE__ void SOLVER(rk4, stage, TARGET, SIMENGINE_STORAGE, rk4_mem *mem, CDATAFORMAT *s_states, CDATAFORMAT *g_states, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(rk4, destage, TARGET, SIMENGINE_STORAGE, rk4_mem *mem, CDATAFORMAT *g_states, CDATAFORMAT *s_states, uint modelid, uint threadid, uint blocksize);
#endif
__DEVICE__ int SOLVER(rk4, eval, TARGET, SIMENGINE_STORAGE, rk4_mem *mem, unsigned int modelid, unsigned int threadid);

void SOLVER(rk4, free, TARGET, SIMENGINE_STORAGE, rk4_mem *mem);


// Bogacki-Shampine (ode23) data structures and function declarations
// ============================================================================================================

typedef struct {
  solver_props *props;
  CDATAFORMAT *k1;
  CDATAFORMAT *k2;
  CDATAFORMAT *k3;
  CDATAFORMAT *k4;
  CDATAFORMAT *temp;
  CDATAFORMAT *next_states;
  CDATAFORMAT *z_next_states;
  CDATAFORMAT *cur_timestep;
} bogacki_shampine_mem;

bogacki_shampine_mem *SOLVER(bogacki_shampine, init, TARGET, SIMENGINE_STORAGE, solver_props *props);

__DEVICE__ void SOLVER(bogacki_shampine, pre_eval, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(bogacki_shampine, post_eval, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem, uint modelid, uint threadid, uint blocksize);
#if defined TARGET_GPU
__DEVICE__ void SOLVER(bogacki_shampine, stage, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem, CDATAFORMAT *s_states, CDATAFORMAT *g_states, uint modelid, uint threadid, uint blocksize);
__DEVICE__ void SOLVER(bogacki_shampine, destage, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem, CDATAFORMAT *g_states, CDATAFORMAT *s_states, uint modelid, uint threadid, uint blocksize);
#endif

__DEVICE__ int SOLVER(bogacki_shampine, eval, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem, unsigned int modelid, unsigned int threadid);

void SOLVER(bogacki_shampine, free, TARGET, SIMENGINE_STORAGE, bogacki_shampine_mem *mem);


// Dormand-Prince (ode45) data structures and function declarations
// ============================================================================================================

typedef struct {
  solver_props *props;
  CDATAFORMAT *k1;
  CDATAFORMAT *k2;
  CDATAFORMAT *k3;
  CDATAFORMAT *k4;
  CDATAFORMAT *k5;
  CDATAFORMAT *k6;
  CDATAFORMAT *k7;
  CDATAFORMAT *temp;
  CDATAFORMAT *next_states;
  CDATAFORMAT *z_next_states;
  CDATAFORMAT *cur_timestep;
} dormand_prince_mem;

dormand_prince_mem *SOLVER(dormand_prince, init, TARGET, SIMENGINE_STORAGE, solver_props *props);

__DEVICE__ int SOLVER(dormand_prince, running, TARGET, SIMENGINE_STORAGE);

__DEVICE__ int SOLVER(dormand_prince, eval, TARGET, SIMENGINE_STORAGE, dormand_prince_mem *mem, unsigned int modelid);

void SOLVER(dormand_prince, free, TARGET, SIMENGINE_STORAGE, dormand_prince_mem *mem);


// CVODE data structures and function declarations
// ============================================================================================================

typedef struct{
  solver_props *props;
  CDATAFORMAT *k1; // Used only to produce last output values
  void *cvmem;
  void *y0;
  unsigned int modelid;
  unsigned int first_iteration;
} cvode_mem;

cvode_mem *SOLVER(cvode, init, TARGET, SIMENGINE_STORAGE, solver_props *props);

int SOLVER(cvode, eval, TARGET, SIMENGINE_STORAGE, cvode_mem *mem, unsigned int modelid);

void SOLVER(cvode, free, TARGET, SIMENGINE_STORAGE, cvode_mem *mem);


// GPU Specific functions

#if defined (TARGET_GPU)
#if defined (__DEVICE_EMULATION__)
#define GPU_ENTRY(entry, type, args...) JOIN3(emugpu, entry, type)(args)
#else
#define GPU_ENTRY(entry, type, args...) JOIN3(gpu, entry, type)(args)
#endif
#define JOIN3(a,b,c) a##_##b##_##c

void GPU_ENTRY(init, SIMENGINE_STORAGE);
void GPU_ENTRY(exit, SIMENGINE_STORAGE);

solver_props *GPU_ENTRY(init_props, SIMENGINE_STORAGE, solver_props *props);
void GPU_ENTRY(free_props, SIMENGINE_STORAGE, solver_props *props);

#endif

#endif // SOLVERS_H

// Dormand-Prince (ode45) Integration Method
// Copyright 2009 Simatra Modeling Technologies, L.L.C.
#include "solvers.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

CDATAFORMAT *cur_timestep;

dormand_prince_mem *dormand_prince_init(solver_props *props) {
  dormand_prince_mem *mem = (dormand_prince_mem*)malloc(sizeof(dormand_prince_mem));

  mem->props = props;
  mem->k1 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k2 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k3 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k4 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k5 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k6 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->k7 = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->temp = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->next_states = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));
  mem->z_next_states = malloc(props->statesize*props->num_models*sizeof(CDATAFORMAT));

  // Allocate and initialize timesteps to 0
  cur_timestep = calloc(props->num_models, sizeof(CDATAFORMAT));

  return mem;
}

int dormand_prince_eval(dormand_prince_mem *mem, int modelid) {

  if (cur_timestep[modelid] == 0) cur_timestep[modelid] = mem->props->timestep;
		      
  CDATAFORMAT max_timestep = mem->props->timestep*1024;
  CDATAFORMAT min_timestep = mem->props->timestep/1024;

  //fprintf(stderr, "ts=%g\n", cur_timestep[modelid]);

  int i;
  int ret = model_flows(*(mem->props->time), mem->props->model_states, mem->k1, mem->props->inputs, mem->props->outputs, 1, modelid);

  int appropriate_step = FALSE;

  CDATAFORMAT max_error;

  while(!appropriate_step) {

    //fprintf(stderr, "|-> ts=%g", cur_timestep[modelid]);
    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->temp[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(cur_timestep[modelid]/5.0)*mem->k1[i*mem->props->num_models + modelid];
    }
    ret |= model_flows(*(mem->props->time)+(cur_timestep[modelid]/5.0), mem->temp, mem->k2, mem->props->inputs, mem->props->outputs, 0, modelid);

    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->temp[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(3.0*cur_timestep[modelid]/40.0)*mem->k1[i*mem->props->num_models + modelid] +
	(9.0*cur_timestep[modelid]/40.0)*mem->k2[i*mem->props->num_models + modelid];
    }
    ret |= model_flows(*(mem->props->time)+(3.0*cur_timestep[modelid]/10.0), mem->temp, mem->k3, mem->props->inputs, mem->props->outputs, 0, modelid);
    
    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->temp[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(44.0*cur_timestep[modelid]/45.0)*mem->k1[i*mem->props->num_models + modelid] +
	(-56.0*cur_timestep[modelid]/15.0)*mem->k2[i*mem->props->num_models + modelid] +
	(32.0*cur_timestep[modelid]/9.0)*mem->k3[i*mem->props->num_models + modelid];
    }
    ret |= model_flows(*(mem->props->time)+(4.0*cur_timestep[modelid]/5.0), mem->temp, mem->k4, mem->props->inputs, mem->props->outputs, 0, modelid);
    
    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->temp[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(19372.0*cur_timestep[modelid]/6561.0)*mem->k1[i*mem->props->num_models + modelid] +
	(-25360.0*cur_timestep[modelid]/2187.0)*mem->k2[i*mem->props->num_models + modelid] +
	(64448.0*cur_timestep[modelid]/6561.0)*mem->k3[i*mem->props->num_models + modelid] +
	(-212.0*cur_timestep[modelid]/729.0)*mem->k4[i*mem->props->num_models + modelid];
    }
    ret |= model_flows(*(mem->props->time)+(8.0*cur_timestep[modelid]/9.0), mem->temp, mem->k5, mem->props->inputs, mem->props->outputs, 0, modelid);
    
    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->temp[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(9017.0*cur_timestep[modelid]/3168.0)*mem->k1[i*mem->props->num_models + modelid] +
	(-355.0*cur_timestep[modelid]/33.0)*mem->k2[i*mem->props->num_models + modelid] +
	(46732.0*cur_timestep[modelid]/5247.0)*mem->k3[i*mem->props->num_models + modelid] +
	(49.0*cur_timestep[modelid]/176.0)*mem->k4[i*mem->props->num_models + modelid] +
	(-5103.0*cur_timestep[modelid]/18656.0)*mem->k5[i*mem->props->num_models + modelid];
    }
    ret |= model_flows(*(mem->props->time)+cur_timestep[modelid], mem->temp, mem->k6, mem->props->inputs, mem->props->outputs, 0, modelid);
    
    for(i=mem->props->statesize-1; i>=0; i--) {
      mem->next_states[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] +
	(35.0*cur_timestep[modelid]/384.0)*mem->k1[i*mem->props->num_models + modelid] +
	(500.0*cur_timestep[modelid]/1113.0)*mem->k3[i*mem->props->num_models + modelid] +
	(125.0*cur_timestep[modelid]/192.0)*mem->k4[i*mem->props->num_models + modelid] +
	(-2187.0*cur_timestep[modelid]/6784.0)*mem->k5[i*mem->props->num_models + modelid] +
	(11.0*cur_timestep[modelid]/84.0)*mem->k6[i*mem->props->num_models + modelid];
    }
    
    // now compute k4 to adapt the step size
    ret |= model_flows(*(mem->props->time)+cur_timestep[modelid], mem->next_states, mem->k7, mem->props->inputs, mem->props->outputs, 0, modelid);
    
    CDATAFORMAT E1 = 71.0/57600.0;
    CDATAFORMAT E3 = -71.0/16695.0;
    CDATAFORMAT E4 = 71.0/1920.0;
    CDATAFORMAT E5 = -17253.0/339200.0;
    CDATAFORMAT E6 = 22.0/525.0;
    CDATAFORMAT E7 = -1.0/40.0;
    for(i=mem->props->statesize-1; i>=0; i--) {
      //mexPrintf("%d: k1=%g, k2=%g, k3=%g, k4=%g, k5=%g, k6=%g, k7=%g\n", i, mem->k1[i*mem->props->num_models + modelid], mem->k2[i*mem->props->num_models + modelid], mem->k3[i*mem->props->num_models + modelid], mem->k4[i*mem->props->num_models + modelid], mem->k5[i*mem->props->num_models + modelid], mem->k6[i*mem->props->num_models + modelid], mem->k7[i*mem->props->num_models + modelid]);
      mem->temp[i*mem->props->num_models + modelid] = /*next_states[i*mem->props->num_models + modelid] + */
	cur_timestep[modelid]*(E1*mem->k1[i*mem->props->num_models + modelid] +
			       E3*mem->k3[i*mem->props->num_models + modelid] +
			       E4*mem->k4[i*mem->props->num_models + modelid] +
			       E5*mem->k5[i*mem->props->num_models + modelid] +
			       E6*mem->k6[i*mem->props->num_models + modelid] +
			       E7*mem->k7[i*mem->props->num_models + modelid]);
      //z_next_states[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] + (71*cur_timestep[modelid]/57600)*k1[i*mem->props->num_models + modelid] + (-71*cur_timestep[modelid]/16695)*k3[i*mem->props->num_models + modelid] + (71*cur_timestep[modelid]/1920)*k4[i*mem->props->num_models + modelid] + (-17253*cur_timestep[modelid]/339200)*k5[i*mem->props->num_models + modelid] + (22*cur_timestep[modelid]/525)*k6[i*mem->props->num_models + modelid] + (-1*cur_timestep[modelid]/40)*k7[i*mem->props->num_models + modelid];
      //z_next_states[i*mem->props->num_models + modelid] = mem->props->model_states[i*mem->props->num_models + modelid] + (5179*cur_timestep[modelid]/57600)*k1[i*mem->props->num_models + modelid] + (7571*cur_timestep[modelid]/16695)*k3[i*mem->props->num_models + modelid] + (393*cur_timestep[modelid]/640)*k4[i*mem->props->num_models + modelid] + (-92097*cur_timestep[modelid]/339200)*k5[i*mem->props->num_models + modelid] + (187*cur_timestep[modelid]/2100)*k6[i*mem->props->num_models + modelid] + (1*cur_timestep[modelid]/40)*k7[i*mem->props->num_models + modelid];
    }

    // compare the difference
    CDATAFORMAT err;
    max_error = -1e20;
    CDATAFORMAT max_allowed_error;
    CDATAFORMAT err_sum = 0.0;
    CDATAFORMAT next_timestep;

    for(i=mem->props->statesize-1; i>=0; i--) {
      err = mem->temp[i*mem->props->num_models + modelid];
      max_allowed_error = mem->props->reltol*MAX(fabs(mem->next_states[i*mem->props->num_models + modelid]),fabs(mem->props->model_states[i*mem->props->num_models + modelid]))+mem->props->abstol;


      //err = fabs(next_states[i*mem->props->num_models + modelid]-z_next_states[i*mem->props->num_models + modelid]);
      //max_allowed_error = RELTOL*fabs(next_states[i*mem->props->num_models + modelid])+ABSTOL;
            //if (err-max_allowed_error > max_error) max_error = err - max_allowed_error;
			       
      CDATAFORMAT ratio = (err/max_allowed_error);
      max_error = ratio>max_error ? ratio : max_error;
      err_sum += ratio*ratio;

      //mexPrintf("%d: ratio=%g next_states=%g err=%g max_allowed_error=%g\n ", i, ratio, mem->next_states[i*mem->props->num_models + modelid], err, max_allowed_error);
    }
    
    //CDATAFORMAT norm = max_error; 
    CDATAFORMAT norm = sqrt(err_sum/((CDATAFORMAT)mem->props->statesize));
    appropriate_step = norm <= 1;
    if (cur_timestep[modelid] == min_timestep) appropriate_step = TRUE;

    if (appropriate_step)
      mem->props->time[modelid] += cur_timestep[modelid];

    next_timestep = 0.9 * cur_timestep[modelid]*pow(1.0/norm, 1.0/5.0);
    //mexPrintf("ts: %g -> %g (norm=%g)\n", cur_timestep[modelid], next_timestep, norm);
			  
    if ((isnan(next_timestep)) || (next_timestep < min_timestep))
      cur_timestep[modelid] = min_timestep;
    else if (next_timestep > max_timestep )
      cur_timestep[modelid] = max_timestep;
    else
      cur_timestep[modelid] = next_timestep;
    
  }

  // just return back the expected
  for(i=mem->props->statesize-1; i>=0; i--) {
    mem->props->model_states[i*mem->props->num_models + modelid] = mem->next_states[i*mem->props->num_models + modelid];
  }
  
  return ret;
}

void dormand_prince_free(dormand_prince_mem *mem) {
  free(mem->k1);
  free(mem->k2);
  free(mem->k3);
  free(mem->k4);
  free(mem->k5);
  free(mem->k6);
  free(mem->k7);
  free(mem->temp);
  free(mem->next_states);
  free(mem->z_next_states);
  free(mem);
  mem = NULL;
  free(cur_timestep);
}

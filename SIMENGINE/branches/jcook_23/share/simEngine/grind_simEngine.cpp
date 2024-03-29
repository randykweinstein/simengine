#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <dlfcn.h>
#include <math.h>

#include "simengine_api.h"

/* Loads the given named dynamic library file.
 * Returns an opaque handle to the library.
 */
void *load_simengine(const char *name)
    {
    void *simengine;

    if (!(simengine = dlopen(name, RTLD_NOW)))
	{
	ERROR(Simatra:SIMEX:HELPER:dynamicLoadError, 
	    "dlopen() failed to load %s: %s", name, dlerror());
	}

    return simengine;
    }

void analyze_result(const simengine_interface *iface, simengine_result *result)
    {
    unsigned int modelid, outputid, sampleid, quantityid;
    simengine_output *output = result->outputs;

    for (modelid = 0; modelid < NUM_MODELS; ++modelid)
	{
	if (0 == modelid) { continue; }

	double errorNorm = 0.0;

	for (outputid = 0; outputid < iface->num_outputs; ++outputid)
	    {
	    simengine_output *op0 = &output[AS_IDX(iface->num_outputs, NUM_MODELS, outputid, modelid-1)];
	    simengine_output *op1 = &output[AS_IDX(iface->num_outputs, NUM_MODELS, outputid, modelid)];

//	    PRINTF("%d samples in model %d output %d\n", op1->num_samples, modelid, outputid);
	    if (op1->num_samples != op0->num_samples)
		{
		PRINTF("difference of sample count from %d to %d: %d\n", modelid-1, modelid, op1->num_samples - op0->num_samples);
		continue;
		}

	    for (sampleid = 0; sampleid < op1->num_samples; ++sampleid)
		{
		for (quantityid = 0; quantityid < op1->num_quantities; ++quantityid)
		    {
		    double d0 = op0->data[AS_IDX(op1->num_quantities, op1->num_samples, quantityid, sampleid)];
		    double d1 = op1->data[AS_IDX(op1->num_quantities, op1->num_samples, quantityid, sampleid)];

		    double diff = d1 - d0;
		    errorNorm += diff * diff;
		    }
		}
	    }

	if (1.0e-6 < fabs(errorNorm - 0.0))
	    { PRINTF("Error from %d to %d: %0.8f\n", modelid-1, modelid, errorNorm); }
	}
    }

/* Retrieves function pointers to the simengine API calls. */
simengine_api *init_simengine(void *simengine)
    {
    simengine_api *api;
    char *msg;
    api = NMALLOC(1, simengine_api);

    api->getinterface = (simengine_getinterface_f)dlsym(simengine, "simengine_getinterface");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:SIMEX:HELPER:dynamicLoadError, 
	    "dlsym() failed to load getinterface: %s", msg); 
	}
    api->runmodel = (simengine_runmodel_f)dlsym(simengine, "simengine_runmodel");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:SIMEX:HELPER:dynamicLoadError, 
	    "dlsym() failed to load runmodel: %s", msg); 
	}

    api->driver = simengine;

    return api;
    }

/* Releases a library handle. The given handle and associated api may no longer be used. */
void release_simengine(simengine_api *api)
    {
    dlclose(api->driver);
    FREE(api);
    }


int main(int argc, char **argv)
    {
    if (argc < 2) {
      fprintf(stderr, "First argument must be the name of a simEngine DLL\n.");
      exit(1);
    }
    char *name = argv[1];

    unsigned int models = NUM_MODELS, modelid;

    double stop_time = 100.0;

    simengine_api *api = init_simengine(load_simengine(name));
    const simengine_interface *iface = api->getinterface();
    simengine_alloc allocator = { MALLOC, REALLOC, FREE };

    double *inputs = NMALLOC(models * iface->num_inputs, double);
    for (modelid = 0; modelid < models; ++modelid)
	{
	memcpy(&inputs[AS_IDX(iface->num_inputs, models, 0, modelid)], iface->default_inputs, iface->num_inputs * sizeof(double));
	}
    double *states = NMALLOC(models * iface->num_states, double);
    for (modelid = 0; modelid < models; ++modelid)
	{
	memcpy(&states[AS_IDX(iface->num_states, models, 0, modelid)], iface->default_states, iface->num_states * sizeof(double));
	}

    simengine_result *result = api->runmodel(0, stop_time, models, inputs, states, &allocator);

    if (SUCCESS != result->status)
	{
	ERROR(Simatra:error, "runmodel returned non-zero status %d: %s", result->status, result->status_message);
	}

    analyze_result(iface, result);


    FREE(inputs);
    FREE(states);
    release_simengine(api);
    return 0;
    }

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <dlfcn.h>
#include <omp.h>


#define GL_GLEXT_PROTOTYPES
#include <GL/glut.h>
#include <GL/glext.h>

#include <cuda_runtime.h>
#include <cutil_inline.h>
#include <cutil_gl_inline.h>
#include <cutil_gl_error.h>
#include <cuda_gl_interop.h>

#include "simengine.h"
#include "stg_spiker.h"

const unsigned int WINDOW_WIDTH = 512;
const unsigned int WINDOW_HEIGHT = 512;
const unsigned int FRAME_LIMIT = 64;

#define _QUOTE(X) #X
#define QUOTE(X) _QUOTE(X)

const size_t VBO_SIZE = NUM_MODELS * MAX_ITERATIONS * 4 * sizeof(CDATAFORMAT);

static struct 
    {
    int2 mouse;
    int mouseButtons;
    float3 rotation;
    float3 translation;
    float3 scale;
    float3 cameraPosition;
    unsigned int cameraCounter;
    unsigned int frameCounter;
    unsigned int frameTimer;
    unsigned int firstFrame;
    float frameRate;
    } glui_data = 
	{
	{0,0}, 0, {0.0f,-90.0f,0.0f}, {0.0f,0.0f,0.0f}, {0.01f, 0.5f, 1.0f}, {1.0f,sqrt(1.0f/2.0f),0.0f}, 0, 0, 0, 1, 0.0f
	};

// OpenGL vertex buffers
GLuint vbo[FRAME_LIMIT];
GLuint cbo[FRAME_LIMIT];
unsigned int vbo_count[NUM_MODELS][FRAME_LIMIT];

simengine_api *simengine;
const simengine_interface *iface;
simengine_alloc simemory = { MALLOC, REALLOC, FREE };

// Initializes the OpenGL runtime.
int initGL(int argc, char **argv);
// Initializes an OpenGL buffer and registers it with the CUDA runtime.
void makeGLBuffer(GLuint *vbo, size_t size);
// Deletes an OpenGL buffer and removes its registration from the CUDA runtime.
void destroyGLBuffer(GLuint *vbo);
void computeFrameRate(void);
void computeCameraPosition(void);
void computeTask();
void initSimulation(unsigned int);

#pragma mark OpenGL callbacks
// Invoked by every iteration of the OpenGL main loop
void display(void);
// Invoked on each mouse button event (press and release)
void mouse(int button, int state, int x, int y);
// Invoked on mouse motion while a button is pressed (click-and-drag)
void motion(int x, int y);
// Invoked on keystroke
void keyboard(unsigned char key, int x, int y);
// Invoked at exit
void cleanup(void);

#pragma mark simEngine API utilities
void *loadSimEngine(const char *name);
simengine_api *initSimEngine(void *simEngine);
void releaseSimEngine(simengine_api *api);

static simengine_alloc alloc = {malloc, realloc, free};
static CDATAFORMAT *model_inputs, *model_states;
double *states = 0, *rgbs = 0;
static float4 *clut;
static CDATAFORMAT t[NUM_MODELS];
float max_t = 0.0f;
float min_t = 0.0f;
static CDATAFORMAT t0 = 0.0;
static CDATAFORMAT t1 = 10000.0;
static solver_props *props;
static void *mem;
static simengine_result *result;

struct timeval tv;


unsigned int simulationid = 0;
unsigned int nsimulations = 1;
char **inputsfiles;


output_buffer *OB;

unsigned int num_rgbs;
int main(int argc, char** argv)
    {
    unsigned int num_states;

    if (argc < 2) 
	{
	fprintf(stderr, "usage: %s INPUTS ...\n", argv[0]);
	exit(1);
	}
	
    nsimulations = argc - 1;
    inputsfiles = NMALLOC(nsimulations, char*);
    for (simulationid = 0; simulationid < nsimulations; ++simulationid)
	{
	inputsfiles[simulationid] = argv[1 + simulationid];
	}
    simulationid = 0;

    simengine = initSimEngine(loadSimEngine(QUOTE(LIBSIMENGINE)));
    iface = simengine->getinterface();



    initGL(argc, argv);

    cutilCheckError(cutCreateTimer(&glui_data.frameTimer));


    if (!cutReadFiled("states.dat", &states, &num_states, YES))
	{ ERROR(Simatra:error, "Failed to read file %s\n", "states.dat"); exit(1); }
//    PRINTF("read %d states from %s\n", num_states, "states.dat");

    model_states = (CDATAFORMAT *)malloc(iface->num_states * NUM_MODELS * sizeof(CDATAFORMAT));


    if (!cutReadFiled("clut.dat", &rgbs, &num_rgbs, YES))
	{ ERROR(Simatra:error, "Failed to read file %s\n", "clut.dat");  exit(1);}
//    PRINTF("read %d rgbs from %s\n", num_rgbs, "clut.dat");

    clut = (float4 *)malloc(num_rgbs / 3 * sizeof(float4));

    for (unsigned int i = 0; i < num_rgbs; i += 3)
	{
	clut[i/3] = make_float4(rgbs[i], rgbs[i+1], rgbs[i+2], 1.0f);
	}



    initSimulation(simulationid);



    glutMainLoop();
 
    }

void initSimulation(unsigned int id)
    {
    unsigned int num_inputs;
    unsigned int frameid, modelid;
    double *inputs = 0;

    if (!cutReadFiled(inputsfiles[simulationid], &inputs, &num_inputs, YES)) 
	{ ERROR(Simatra:error, "Failed to read file %s\n", inputsfiles[1]);  exit(1);}
//    PRINTF("read %d inputs from %s\n", num_inputs, inputsfiles[1]);

    model_inputs = (CDATAFORMAT *)malloc(iface->num_inputs * NUM_MODELS * sizeof(CDATAFORMAT));

    result = simengine->init(NUM_MODELS, t0, t, t1, inputs, model_inputs, states, model_states, &alloc, &props, &mem);
    OB = (output_buffer *)simengine->getoutputs();

    for (frameid = 0; frameid < FRAME_LIMIT; ++frameid)
	{ 
	makeGLBuffer(&vbo[frameid], VBO_SIZE); 
	makeGLBuffer(&cbo[frameid], VBO_SIZE);
	for (modelid = 0; modelid < NUM_MODELS; ++modelid)
	    { vbo_count[modelid][frameid] = 0; }
	}

    simengine->register_clut(clut, num_rgbs/3);

    }


void computeTask()
    {
    if (!OB->active_models)
	{
	if (nsimulations == ++simulationid)
	    { simulationid = 0; }

	cleanup();
	initSimulation(simulationid);
	glui_data.firstFrame = 1;
	}

    unsigned int modelid;
    float4 *verts, *colors;

    if (!glui_data.firstFrame)
	{
	if (cudaSuccess != cudaStreamQuery(0))
	    { return; }
	else
	    {
	    simengine->sync_kernel(props, result->outputs);

	    cutilSafeCall(cudaMemcpy(t, props->time, props->num_models*sizeof(CDATAFORMAT), cudaMemcpyDeviceToHost));

	    cutilSafeCall(cudaGLUnmapBufferObject(vbo[glui_data.frameCounter]));
	    cutilSafeCall(cudaGLUnmapBufferObject(cbo[glui_data.frameCounter]));

	    float prev_max_t = max_t;
	    float prev_min_t = min_t;
	    for (modelid = 0; modelid < NUM_MODELS; ++modelid)
		{
		if (max_t < t[modelid]) {
		    max_t = t[modelid];
		    }


		vbo_count[modelid][glui_data.frameCounter] = 
		    OB->vb_count[modelid];
		}
	    
	    min_t = max_t;
	    for (modelid = 0; modelid < NUM_MODELS; ++modelid)
		{
		if (min_t > 0 && min_t > t[modelid]) 
		    {
		    min_t = t[modelid];
		    }
		}

	    // PRINTF("d_max_t %.4f, d_min_t %.4f\n",
	    // max_t - prev_max_t, min_t - prev_min_t);
	    // PRINTF("max_t %.4f, min_t %.4f\n",
	    // max_t, min_t);

	    glui_data.translation.x = -1.0 * min_t;
	    //glui_data.scale.x = 1.0f / sqrt(max_t - min_t);

	    if (FRAME_LIMIT == ++glui_data.frameCounter)
		{ glui_data.frameCounter = 0; }
	    }
	}
    else
	{ glui_data.firstFrame = 0; }


    for (modelid = 0; modelid < NUM_MODELS; ++modelid)
	{
	vbo_count[modelid][glui_data.frameCounter] = 0;
	}

    cutilSafeCall(cudaGLMapBufferObject((void **)&verts, 
	    vbo[glui_data.frameCounter]));
    cutilSafeCall(cudaGLMapBufferObject((void **)&colors, 
	    cbo[glui_data.frameCounter]));

    simengine->register_vertex_buffer(verts, colors);

    simengine->async_invoke_kernel(mem, props);
    }

void display(void)
    {
    unsigned int modelid, frameid;
    //char title[24];

    cutilCheckError(cutStartTimer(glui_data.frameTimer));

    computeTask();
    computeCameraPosition();    

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


    // Rotates and translates the current view matrix
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    //PRINTF("scale %.4f %.4f %.4f\n", glui_data.scale.x, glui_data.scale.y, glui_data.scale.z);

    gluLookAt(glui_data.cameraPosition.x, glui_data.cameraPosition.y, glui_data.cameraPosition.z,
    	0.0, 0.0, 0.0, 
    	0.0, 1.0, 0.0);
//    PRINTF("camera %.4f %.4f %.4f\n", glui_data.cameraPosition.x, glui_data.cameraPosition.y, glui_data.cameraPosition.z);

    glRotatef(glui_data.rotation.x, 1.0, 0.0, 0.0);
    glRotatef(glui_data.rotation.y, 0.0, 1.0, 0.0);
    glRotatef(glui_data.rotation.z, 0.0, 0.0, 1.0);

    glScalef(glui_data.scale.x, glui_data.scale.y, glui_data.scale.z);

    glTranslatef(glui_data.translation.x, glui_data.translation.y, glui_data.translation.z);
//   PRINTF("translation %.4f %.4f %.4f\n", glui_data.translation.x, glui_data.translation.y, glui_data.translation.z);
    
    
    // Renders the vertex buffer
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glColor4f(1.0f, 0.0f, 0.0f, 0.5f);
    for (frameid=0; frameid<FRAME_LIMIT; ++frameid)
	{
	glBindBuffer(GL_ARRAY_BUFFER, vbo[frameid]);
	glVertexPointer(4, GL_FLOAT, 0, 0);
	glBindBuffer(GL_ARRAY_BUFFER, cbo[frameid]);
	glColorPointer(4, GL_FLOAT, 0, 0);

	for (modelid=0; modelid<NUM_MODELS; ++modelid)
	    {
	    if (!vbo_count[modelid][frameid])
		{continue;}

//	    PRINTF("rendering %d vertices of frame %d for model %d\n", vbo_count[modelid][frameid], frameid, modelid);

	    glDrawArrays(GL_LINE_STRIP, modelid * MAX_ITERATIONS, vbo_count[modelid][frameid]);
	    }
	}
    glDisableClientState(GL_VERTEX_ARRAY);




    glutSwapBuffers();
    glutPostRedisplay();

    cutilCheckError(cutStopTimer(glui_data.frameTimer));  

    computeFrameRate();
//    sprintf(title, "%3.4f fps", glui_data.frameRate);
//    glutSetWindowTitle(title);
    }

void computeFrameRate(void)
    {
    if (FRAME_LIMIT == glui_data.frameCounter)
	{
	glui_data.frameRate = 1.0f / cutGetAverageTimerValue(glui_data.frameTimer);
	glui_data.frameCounter = 0;
	cutilCheckError(cutResetTimer(glui_data.frameTimer));
	}
    }



unsigned long long getnanos(){
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return (unsigned long long) ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

float get_cycle_angle(float cycle_time){
  double now = (getnanos()/1.0E9) / cycle_time;
  now = now - (int)now;
  return 2*M_PI*now;
}


void computeCameraPosition(void)
    {
    float t = get_cycle_angle(24.0);
    float theta = 23.5f; // viewing angle of incidence
    float r = sin((90.0f-theta) * M_PI / 180.0f);

    glui_data.cameraPosition.x = r * cos(t);
    glui_data.cameraPosition.y = cos((90.0f-theta) * M_PI / 180.0f);
    glui_data.cameraPosition.z = r * sin(t);
    }

void cleanup(void)
    {
//    PRINTF("cleanup!\n");
    unsigned int frameid;
    simengine->register_clut(0, 0);

    if (model_inputs)
	{ free(model_inputs); }

    for (frameid = 0; frameid < FRAME_LIMIT; ++frameid)
    	{ 
	destroyGLBuffer(&vbo[frameid]); 
	destroyGLBuffer(&cbo[frameid]);
	}

    simengine->free_solver(mem, props);
    simengine->release_result(result);
    }

void keyboard(unsigned char key, int x, int y)
    {
    switch (key)
	{
	case 27:
	    exit(0);
	    break;
	}
    }


int initGL(int argc, char **argv)
    {
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
    glutInitWindowSize(WINDOW_WIDTH, WINDOW_HEIGHT);
    glutCreateWindow("Cuda GL Interop (VBO)");
    glutDisplayFunc(display);
    glutMouseFunc(mouse);
    glutMotionFunc(motion);
    glutKeyboardFunc(keyboard);

    // Default to black background
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_ALPHA_TEST);

    glViewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

    // projection
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    gluPerspective(60.0, (GLfloat)WINDOW_WIDTH / (GLfloat)WINDOW_HEIGHT, 0.01, 100.0);
    glTranslatef(0.0f, 0.0f, -2.0f);

    CUT_CHECK_ERROR_GL();

    glutFullScreen();

    atexit(cleanup);

    return YES;
    }

void makeGLBuffer(GLuint *vbo, size_t size)
    {
    // create buffer object
    glGenBuffers(1, vbo);
    glBindBuffer(GL_ARRAY_BUFFER, *vbo);

    // initialize buffer object
    glBufferData(GL_ARRAY_BUFFER, size, 0, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // register buffer object with CUDA
    cutilSafeCall(cudaGLRegisterBufferObject(*vbo));

    CUT_CHECK_ERROR_GL();
    }

void destroyGLBuffer(GLuint *vbo)
    {
    glBindBuffer(1, *vbo);
    glDeleteBuffers(1, vbo);

    cutilSafeCall(cudaGLUnregisterBufferObject(*vbo));

    *vbo = 0;
    }

void mouse(int button, int state, int x, int y)
    {
    switch (state)
	{
	case GLUT_DOWN:
	    glui_data.mouseButtons |= 1<<button;
	    break;
	case GLUT_UP:
	    glui_data.mouseButtons = 0;
	    break;
	}

    glui_data.mouse.x = x;
    glui_data.mouse.y = y;
    glutPostRedisplay();
    }

void motion(int x, int y)
    {
    float dx = x - glui_data.mouse.x,
	dy = y - glui_data.mouse.y;

    if (1 & glui_data.mouseButtons)
	{
	glui_data.rotation.x += 0.2 * dy;
	glui_data.rotation.y += 0.2 * dx;
	}
    else if (4 & glui_data.mouseButtons)
	{
	glui_data.translation.z += -0.01 * dy;
//	glui_data.translation.x += -0.01 * dx;
	}

    glui_data.mouse.x = x;
    glui_data.mouse.y = y;
    glutPostRedisplay();
    }


void *loadSimEngine(const char *name)
    {
    void *simEngine;

    if (!(simEngine = dlopen(name, RTLD_NOW)))
	{
	ERROR(Simatra:SIMEX:HELPER:dynamicLoadError, 
	    "dlopen() failed to load %s: %s", name, dlerror());
	}

    return simEngine;
    }

simengine_api *initSimEngine(void *simEngine)
    {
    simengine_api *api;
    char *msg;
    api = NMALLOC(1, simengine_api);

    api->getinterface = (simengine_getinterface_f)dlsym(simEngine, "simengine_getinterface");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load getinterface: %s", msg); 
	}

    api->getoutputs = (simengine_getoutputs_f)dlsym(simEngine, "simengine_getoutputs");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load getoutputs: %s", msg); 
	}

    api->runmodel = (simengine_runmodel_f)dlsym(simEngine, "simengine_runmodel");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load runmodel: %s", msg); 
	}

    api->init = (simengine_init_f)dlsym(simEngine, "simengine_init");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load init: %s", msg); 
	}

    api->free_solver = (simengine_free_solver_f)dlsym(simEngine, "simengine_free_solver");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load free_solver: %s", msg); 
	}

    api->release_result = (simengine_release_result_f)dlsym(simEngine, "simengine_release_result");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load release_result: %s", msg); 
	}

    api->invoke_kernel = (simengine_invoke_kernel_f)dlsym(simEngine, "simengine_invoke_kernel");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load invoke_kernel: %s", msg); 
	}

    api->async_invoke_kernel = (simengine_async_invoke_kernel_f)dlsym(simEngine, "simengine_async_invoke_kernel");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load async_invoke_kernel: %s", msg); 
	}

    api->sync_kernel = (simengine_sync_kernel_f)dlsym(simEngine, "simengine_sync_kernel");
    if (0 != (msg = dlerror()))
	{ 
	ERROR(Simatra:dynamicLoadError, 
	    "dlsym() failed to load sync_kernel: %s", msg); 
	}

    api->register_vertex_buffer = (simengine_register_vertex_buffer_f)dlsym(simEngine, "simengine_register_vertex_buffer");
    if (0 != (msg = dlerror()))
    	{ 
    	ERROR(Simatra:dynamicLoadError, 
    	    "dlsym() failed to load register_vertex_buffer: %s", msg); 
    	}

    api->register_clut = (simengine_register_clut_f)dlsym(simEngine, "simengine_register_clut");
    if (0 != (msg = dlerror()))
    	{ 
    	ERROR(Simatra:dynamicLoadError, 
    	    "dlsym() failed to load register_clut: %s", msg); 
    	}

    api->driver = simengine;

    return api;
    }

void releaseSimEngine(simengine_api *api)
    {
    dlclose(api->driver);
    FREE(api);
    }


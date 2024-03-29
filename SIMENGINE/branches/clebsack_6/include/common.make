# Definitions of variables and macros common to many subsystems.
#
# Copyright 2009-2010 Simatra Modeling Technologies, L.L.C.
# For more information, please visit http://www.simatratechnologies.com

## User-specifiable options
# If non-empty, instructs the compiler to produce additional debugging information.
debug ?=
# If non-empty, instructs the compiler to produce additional profiling information.
profile ?=
# If non-empty, commands will print extra diagnostic information.
verbose ?= 1
# If non-empty, will not echo commands as they are executed
noecho ?=

#SVN_ROOT = https://svn1.hosted-projects.com/simatra/simEngine/
SVN_PREFIX = https://simatra.jira.com/svn
SVN_ROOT = $(SVN_PREFIX)/SIMENGINE
SVN_TRUNK = $(addsuffix $(SVN_ROOT),trunk)
SVN_INFO = svn info $(CURDIR) 2>/dev/null
SVN_URL := $(shell $(SVN_INFO) | sed -n 's/^URL: //p')
SVN_REVISION := $(shell svnversion -nc . | cut -d: -f2)
SVN_BRANCH := $(subst $(SVN_ROOT),,$(SVN_URL))

DEBUG := $(or $(debug),$(findstring branches,$(SVN_BRANCH)))
PROFILE := $(if $(profile),$(profile),)
VERBOSE := $(if $(verbose),$(verbose),)
NOECHO := $(if $(noecho),@,)

## Platform and operating system detection
OSLOWER := $(shell uname -s|tr [:upper:] [:lower:])
DARWIN := $(findstring darwin,$(OSLOWER))
LINUX := $(findstring linux,$(OSLOWER))

ARCH := $(strip $(shell arch))
ARCH64 := $(findstring 64,$(ARCH))

ifneq ($(ARCH64),)
VPATH := /lib64 /usr/lib64 /usr/local/lib64 $(VPATH)
endif

TARGET_ARCH = $(if $(ARCH64),-m64,-m32)
ifneq ($(DARWIN),)
TARGET_ARCH = -arch i386 -arch x86_64
endif

## Compilers and commands
# The SML compiler
SMLC = mlton
SMLRUNTIMEFLAGS = ram-slop 0.6
SMLFLAGS =
ifneq ($(DEBUG),)
SMLFLAGS += -cc-opt "-g"
endif
SMLPPFLAGS =
SMLTARGET_ARCH = -codegen native
SMLLEX = mllex
SMLYACC = mlyacc

COMPILE.sml = $(SMLC) @MLton $(SMLRUNTIMEFLAGS) -- $(SMLFLAGS) $(SMLPPFLAGS) $(SMLTARGET_ARCH)
LEX.sml = $(SMLLEX)
YACC.sml = $(SMLYACC)

%.lex.sml: %.lex
	$(LEX.sml) $<

%.grm.sml %.grm.sig: %.grm
	$(YACC.sml) $<

# The C compiler
CC = gcc
CCVERSION := $(shell $(CC) -v 2>&1 | tail -1 | cut -d' ' -f 3)
CCMAJOR := $(shell echo $(CCVERSION) | cut -d. -f 1)
CCMINOR := $(shell echo $(CCVERSION) | cut -d. -f 2)

CWARNINGS = -Wstrict-prototypes -Wmissing-prototypes \
	-Wmissing-declarations -Wnested-externs -Wmain $(CXXWARNINGS)
ifneq ($(DEBUG),)
CFLAGS += -g
endif

# When producing a shared library, OS X requires different linker flags.
SHARED_FLAGS = -shared
ifneq ($(DARWIN),)
SHARED_FLAGS = -dynamiclib -Wl,-single_module
endif

# OpenMP requires gcc-4.2 on OS X Leopard
ifneq ($(DARWIN),)
CC := $(shell if [ 4 -ge $(CCMAJOR) -a 2 -gt $(CCMINOR) ]; then echo $(CC)-4.2; else echo $(CC); fi)
CCVERSION := $(shell $(CC) -v 2>&1 | tail -1 | cut -d' ' -f 3)
CCMAJOR := $(shell echo $(CCVERSION) | cut -d. -f 1)
CCMINOR := $(shell echo $(CCVERSION) | cut -d. -f 2)
endif

# The C++ compiler
CXX = g++
CXXVERSION := $(shell $(CXX) -v 2>&1 | tail -1 | cut -d' ' -f 3)
CXXMAJOR := $(shell echo $(CXXVERSION) | cut -d. -f 1)
CXXMINOR := $(shell echo $(CXXVERSION) | cut -d. -f 2)

CXXWARNINGS = -W -Wall -Wimplicit -Wswitch -Wformat -Wchar-subscripts \
	-Wparentheses -Wmultichar -Wtrigraphs -Wpointer-arith -Wcast-align \
	-Wreturn-type -Wno-unused-function
ifneq ($(DEBUG),)
CXXFLAGS += -g
endif

# OpenMP requires g++-4.2 on OS X Leopard
ifneq ($(DARWIN),)
CXX := $(shell if [ 4 -ge $(CXXMAJOR) -a 2 -gt $(CXXMINOR) ]; then echo $(CXX)-4.2; else echo $(CXX); fi)
CXXVERSION := $(shell $(CXX) -v 2>&1 | tail -1 | cut -d' ' -f 3)
CXXMAJOR := $(shell echo $(CXXVERSION) | cut -d. -f 1)
CXXMINOR := $(shell echo $(CXXVERSION) | cut -d. -f 2)
endif

# Required when compiling for OpenMP
OPENMP_LDLIBS = -lgomp
OPENMP_CFLAGS = -fopenmp

# The CUDA compiler
NVCC := $(shell which nvcc 2>/dev/null)
ifneq ($(NVCC),)
CUDA_INSTALL_PATH := $(shell dirname $$(dirname $(realpath $(NVCC))))
NVCC = $(CUDA_INSTALL_PATH)/bin/nvcc
CUDA_RELEASE_VERSION := $(shell $(NVCC) --version | grep release | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/')
CUDA_INCLUDES = -I$(CUDA_INSTALL_PATH)/include
CUDA_LDFLAGS = -L$(CUDA_INSTALL_PATH)/lib 
ifneq ($(ARCH64),)
CUDA_LDFLAGS := -L$(CUDA_INSTALL_PATH)/lib64 $(CUDA_LDFLAGS)
endif
CUDA_LDLIBS = -lcudart
endif
ifneq ($(DARWIN),)
CUDART_LIBRARY_NAME = libcudart.dylib
else
CUDART_LIBRARY_NAME = libcudart.so
endif


# MATLAB and the MEX compiler
MATLAB := $(shell which matlab 2>/dev/null)
ifneq ($(MATLAB),)
MATLAB_INSTALL_PATH := $(shell dirname $$(dirname $(realpath $(MATLAB))))
MATLAB = MATLABROOT=$(MATLAB_INSTALL_PATH) $(MATLAB_INSTALL_PATH)/bin/matlab
MEX = MATLABROOT=$(MATLAB_INSTALL_PATH) $(MATLAB_INSTALL_PATH)/bin/mex
endif

# GNU Octave and the MKOCTFILE compiler
OCTAVE := $(shell which octave 2>/dev/null)
ifneq ($(OCTAVE),)
OCTAVE_INSTALL_PATH := $(shell dirname $$(dirname $(realpath $(OCTAVE))))
OCTAVE = $(OCTAVE_INSTALL_PATH)/bin/octave
MKOCTFILE = $(OCTAVE_INSTALL_PATH)/bin/mkoctfile --mex
endif

# Every possible MEX extension
ALL_MEXEXT = .mexglx .mexa64 .mexmaci .mexmaci64 .mexs64 .mexw32 .mexw64 .mex

# Determines the appropriate MEX extension for the current platform.
ifneq ($(MATLAB),)
ifneq ($(DARWIN),)
MEXEXT = .mexmaci .mexmaci64
else
MEXEXT := .$(shell MATLABROOT=$(MATLAB_INSTALL_PATH) $(MATLAB_INSTALL_PATH)/bin/mexext)
endif
endif
export MEXEXT

#MEXFLAGS += CFLAGS="$(CFLAGS) $(CWARNINGS)" LDFLAGS="$(LDFLAGS)"
ifneq ($(DEBUG),)
MEXFLAGS += -g
endif
ifneq ($(VERBOSE),)
MEXFLAGS += -v
endif

# Rules for compiling various MEX targets
COMPILE.mex = $(MEX) CC=$(CC) CXX=$(CXX) LD=$(CC) $(MEXFLAGS) $(MEXTARGET_ARCH)

%.mexglx: override MEXTARGET_ARCH = -glnx86
%.mexglx: %.c
	$(COMPILE.mex) -output $* $<

%.mexa64: override MEXTARGET_ARCH = -glnxa64
%.mexa64: %.c
	$(COMPILE.mex) -output $* $<

%.mexmaci: override MEXTARGET_ARCH = -maci
%.mexmaci: override MEX := MACI64=0 $(MEX)
%.mexmaci: override CFLAGS += -m32
%.mexmaci: override LDFLAGS += -m32
%.mexmaci: %.c
	$(COMPILE.mex) -output $* $<

%.mexmaci64: override MEXTARGET_ARCH = -maci64
%.mexmaci64: override MEX := MACI64=1 $(MEX)
%.mexmaci64: override CFLAGS += -m64
%.mexmaci64: override LDFLAGS += -m64
%.mexmaci64: %.c
	$(COMPILE.mex) -output $* $<

%.mexs64: override MEXTARGET_ARCH = -sol64
%.mexs64: %.c
	$(COMPILE.mex) -output $* $<

%.mexw32: override MEXTARGET_ARCH = -win32
%.mexw32: %.c
	$(COMPILE.mex) -output $* $<

%.mexw64: override MEXTARGET_ARCH = -win64
%.mexw64: %.c
	$(COMPILE.mex) -output $* $<

## Other misc tools
AR = ar
ARFLAGS = rsc
LN = ln -s
MKDIR = mkdir -p
RM = rm -f
GRIND = valgrind
ENV = $(if $(DARWIN),/usr/bin/env,/bin/env)
MKDIR = mkdir -p
CONFIGURE = ./configure
ifeq ($(VERBOSE),)
CONFIGURE_FLAGS += --quiet
endif
INSTALL = install
INSTALL_PROG = $(INSTALL)
INSTALL_HEADER = $(INSTALL) -m 644
INSTALL_DOC = $(INSTALL) -m 644

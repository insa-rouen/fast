PROG_FAST = fast_$(PLATFORM)
PROG_TURB = turbsim_$(PLATFORM)
PROG_CRUNCH = crunch_$(PLATFORM)
PROG_IECWIND = iecwind_$(PLATFORM)
PROG_BMODES = bmodes_$(PLATFORM)
PROG_MODES = modes_$(PLATFORM)

MAP_LIB = libmap
DISCON_LIB = DISCON_$(PLATFORM)

BMODES = bmodes
MODES = modes
FAST = fast
TURBSIM = turbsim
CRUNCH = crunch
IECWIND = iecwind
DISCON = discon
REGISTRY = $(FAST)/Source/dependencies/Registry
MAP = map

export BASEDIR = $(PWD)
export OUTDIR = $(PWD)/build
export MODDIR = $(PWD)/include
export BINDIR = $(PWD)
export LIBDIR = $(PWD)

all: $(MAP_LIB) $(PROG_FAST) $(DISCON_LIB) $(PROG_TURB) $(PROG_IECWIND) $(PROG_CRUNCH) $(PROG_BMODES) $(PROG_MODES)

ALL_OBJ = $(OUTDIR)/*.o
 	
$(MAP_LIB) map: map_lib

$(PROG_FAST) fast: registry fast_lib

$(PROG_MODES) modes: modes_lib

$(PROG_BMODES) bmodes: bmodes_lib

$(PROG_TURB) turbsim: turbsim_lib

$(PROG_IECWIND) iecwind: iecwind_lib

$(PROG_CRUNCH) crunch: crunch_lib

$(DISCON_LIB) discon: discon_lib

registry:
	$(MAKE) -C $(REGISTRY)

discon_lib:
	$(MAKE) -C $(DISCON)

map_lib:
	$(MAKE) -C $(MAP)/src

fast_lib: map_lib
	$(MAKE) -C $(FAST)/Compiling

modes_lib:
	$(MAKE) -C $(MODES)/Source

bmodes_lib:
	$(MAKE) -C $(BMODES)/Source

turbsim_lib:
	$(MAKE) -C $(TURBSIM)/compiling

iecwind_lib:
	$(MAKE) -C $(IECWIND)/Source

crunch_lib:
	$(MAKE) -C $(CRUNCH)/Source

.PHONY: clean
 	
clean:
	$(MAKE) clean -C $(MAP)/src; \
	$(MAKE) clean -C $(DISCON); \
	$(MAKE) clean -C $(FAST)/Compiling; \
	$(MAKE) clean -C $(BMODES)/Source; \
	$(MAKE) clean -C $(MODES)/Source; \
	$(MAKE) clean -C $(CRUNCH)/Source; \
	$(MAKE) clean -C $(TURBSIM)/compiling; \
	$(MAKE) clean -C $(IECWIND)/Source/;
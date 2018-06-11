include ../../make.inc

OUTPUT_NAME = Modes

Modes_DIR  = ../Source

BIN_DIR      = ../..

ifeq ($(OS),Windows_NT)
      # Windows
   DEL_CMD   = del
   EXE_EXT   = _gwin$(BITS).exe
   INTER_DIR = Obj_win$(BITS)
   MD_CMD    = @mkdir
   OBJ_EXT   = .obj
   PATH_SEP  = \\
else

   UNAME := $(shell uname -s)

   ifeq ($(UNAME), Darwin)
       EXE_EXT   = _gdar$(BITS)
       INTER_DIR = Obj_dar$(BITS)
   else
       EXE_EXT   = _glin$(BITS)
       INTER_DIR = Obj_lin$(BITS)
   endif
   
      # Linux
   DEL_CMD   = rm -f
   MD_CMD    = @mkdir -p
   OBJ_EXT   = .o
   PATH_SEP  = /
endif

vpath %.f90 $(Modes_DIR)
vpath %.for $(Modes_DIR)
vpath %.mod $(INTER_DIR)
vpath %$(OBJ_EXT) $(INTER_DIR)

SRC = Eigen.for
SRC += Modules.f90
SRC += ModCVF.f90
SRC += SysCVF.f90
SRC += GenUse.f90
SRC += Modes.f90

objtemp = $(SRC:.for=$(OBJ_EXT))
OBJ += $(objtemp:.f90=$(OBJ_EXT))

all: default

default: $(INTER_DIR) $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT)

$(INTER_DIR):
	$(MD_CMD) $(INTER_DIR)
   # General rules for compliling the files.

%$(OBJ_EXT): %.f90
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

%$(OBJ_EXT): %.for
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

$(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT): $(OBJ) | $(INTER_DIR)
	$(FC) $(LDFLAGS) -I $(INTER_DIR) -o $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT) \
	$(foreach src, $(OBJ), $(addprefix $(INTER_DIR)/,$(src)))

checkdir:
	$(MD_CMD) -p $(MODDIR);

clean:
	$(DEL_CMD) $(INTER_DIR)$(PATH_SEP)*.mod $(INTER_DIR)$(PATH_SEP)*$(OBJ_EXT)

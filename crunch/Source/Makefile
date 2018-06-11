include ../../make.inc

OUTPUT_NAME = Crunch

Crunch_DIR  = ../Source

BIN_DIR      = ../..

NWTC_Lib_DIR = ../../nwtc/source

ifeq ($(OS),Windows_NT)
      # Windows
   DEL_CMD   = del
   EXE_EXT   = _gwin$(BITS).exe
   INTER_DIR = Obj_win$(BITS)
   MD_CMD    = @mkdir
   OBJ_EXT   = .obj
   PATH_SEP  = \\
   SYS_FILE  = SysGnuWin
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
   SYS_FILE  = SysGnuLinux
endif

vpath %.f90 $(NWTC_Lib_DIR) $(Crunch_DIR)
vpath %.f   $(Crunch_DIR)
vpath %.mod $(INTER_DIR)
vpath %.obj $(INTER_DIR)

LIB_SOURCES =             \
	SingPrec.f90           \
	NWTC_Aero.f90          \
	$(SYS_FILE).f90        \
	NWTC_IO.f90            \
	NWTC_Num.f90           \
	ModMesh.f90            \
	NWTC_Library.f90

CRUNCH_SOURCES = \
    Crunch_Mods.f90 \
    Crunch_Subs.f90 \
    Crunch_IO.f90 \
    Parser.f90 \
    AzimAver.f90 \
    CalcChan.f90 \
    ExtEvent.f90 \
    ExtrValu.f90 \
    Filter.f90 \
    LoadRose.f90 \
    MoveAver.f90 \
    PeakList.f90 \
    PMF.f90 \
    Rainflow.f90 \
    Stats.f90 \
    SetProg.f90 \
    Crunch.f90

SRC = $(CRUNCH_SOURCES) $(LIB_SOURCES)
OBJ   = $(SRC:.f90=.obj)

all: default

default: $(INTER_DIR) $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT)

# Dependency rules.
# NWTC Library dependency rules:
$(SYS_FILE).obj:            SingPrec.obj
NWTC_Aero.obj:              NWTC_IO.obj NWTC_Num.obj
NWTC_Library.obj:           ModMesh.obj NWTC_Aero.obj
ModMesh.obj:                $(SYS_FILE).obj
NWTC_IO.obj:                $(SYS_FILE).obj

# Crunch dependency rules:
Crunch_Mods.obj:          NWTC_Library.obj

$(INTER_DIR):
	$(MD_CMD) $(INTER_DIR)
   # General rules for compliling the files.

%.obj: %.f90
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

%.obj: %.F90
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

%.obj: %.f
	$(F77) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

$(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT): $(OBJ) | $(INTER_DIR)
	$(FC) $(LDFLAGS) -I $(INTER_DIR) -o $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT) \
	$(foreach src, $(OBJ), $(addprefix $(INTER_DIR)/,$(src)))

clean:
	$(DEL_CMD) $(INTER_DIR)$(PATH_SEP)*.mod $(INTER_DIR)$(PATH_SEP)*$(OBJ_EXT)
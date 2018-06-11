include ../../make.inc

OUTPUT_NAME = BModes

BModes_DIR  = ../Source
NWTC_Lib_DIR = ../../nwtc/source

BIN_DIR      = ../..

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

vpath %.f90 $(BModes_DIR) $(NWTC_Lib_DIR)
vpath %.for $(BModes_DIR)
vpath %.mod $(INTER_DIR)
vpath %$(OBJ_EXT) $(INTER_DIR)

LIBSRC=SingPrec.f90 \
        ModMesh.f90 \
        NWTC_Aero.f90 \
        NWTC_IO.f90 \
        NWTC_Library.f90 \
        NWTC_Num.f90 \
        $(SYS_FILE).f90

SRC = modules.f90
SRC += math.f
SRC += Alloc.f90
SRC += utilss.f90
SRC += BldVib.f90
SRC += Struct.f90
SRC += SetProg.f90
SRC += BModes.f90

ALLSOURCES = $(SRC) $(LIBSRC)
tempobj = $(ALLSOURCES:.f90=$(OBJ_EXT))
OBJ = $(tempobj:.f=$(OBJ_EXT))

all: default

default: $(INTER_DIR) $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT)
NWTC_Base$(OBJ_EXT):            SingPrec$(OBJ_EXT)
$(SYS_FILE)$(OBJ_EXT):          NWTC_Base$(OBJ_EXT)
NWTC_Library_Types$(OBJ_EXT):   $(SYS_FILE)$(OBJ_EXT)
NWTC_Num$(OBJ_EXT):             NWTC_IO$(OBJ_EXT)
ModMesh_Types$(OBJ_EXT):        NWTC_Num$(OBJ_EXT)
ModMesh$(OBJ_EXT):              ModMesh_Types$(OBJ_EXT)

NWTC_IO$(OBJ_EXT):              $(SYS_FILE)$(OBJ_EXT)
NWTC_Aero$(OBJ_EXT):            NWTC_IO$(OBJ_EXT) NWTC_Num$(OBJ_EXT)
NWTC_Library$(OBJ_EXT):         NWTC_Aero$(OBJ_EXT) ModMesh$(OBJ_EXT)
math$(OBJ_EXT):                 NWTC_Library$(OBJ_EXT)
modules$(OBJ_EXT):              SingPrec$(OBJ_EXT)

$(INTER_DIR):
	$(MD_CMD) $(INTER_DIR)
   # General rules for compliling the files.

%$(OBJ_EXT): %.f90
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

%$(OBJ_EXT): %.f
	$(FC) -I $(INTER_DIR) $(FFLAGS) -c $< -o $(INTER_DIR)/$@ -J $(INTER_DIR) -B $(INTER_DIR)

$(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT): $(OBJ) | $(INTER_DIR)
	$(FC) $(LDFLAGS) -I $(INTER_DIR) -o $(BIN_DIR)/$(OUTPUT_NAME)$(EXE_EXT) \
	$(foreach src, $(OBJ), $(addprefix $(INTER_DIR)/,$(src)))

checkdir:
	$(MD_CMD) -p $(MODDIR);

clean:
	$(DEL_CMD) $(INTER_DIR)$(PATH_SEP)*.mod $(INTER_DIR)$(PATH_SEP)*$(OBJ_EXT)

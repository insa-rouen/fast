include ../make.inc

OUTPUT_NAME = DISCON

BIN_DIR      = ..

ifeq ($(OS),Windows_NT)
      # Windows
   DEL_CMD   = del
   EXE_EXT   = _gwin$(BITS)
   INTER_DIR = Obj_win$(BITS)
   MD_CMD    = @mkdir
   OBJ_EXT   = .obj
   PATH_SEP  = \\
   LIB_EXT   = .dll
else

   UNAME := $(shell uname -s)

   ifeq ($(UNAME), Darwin)
       EXE_EXT   = _gdar$(BITS)
       INTER_DIR = Obj_dar$(BITS)
       LIB_EXT   = .dylib
   else
       EXE_EXT   = _glin$(BITS)
       INTER_DIR = Obj_lin$(BITS)
       LIB_EXT   = .so
   endif
   
      # Linux
   DEL_CMD   = rm -f
   MD_CMD    = @mkdir -p
   OBJ_EXT   = .o
   PATH_SEP  = /
endif

OBJ       = $(OUTPUT_NAME)$(OBJ_EXT)

all : $(OBJ)
	$(FC) -shared -o $(OUTPUT_NAME)$(EXE_EXT)$(LIB_EXT) $(OBJ)
	cp $(OUTPUT_NAME)$(EXE_EXT)$(LIB_EXT) $(BIN_DIR)

%$(OBJ_EXT): %.f90
	$(FC) $(F90_FLAGS) -fPIC -C -DIMPLICIT_DLLEXPORT -c $<

clean:
	rm -rf *$(LIB_EXT) *.o *~

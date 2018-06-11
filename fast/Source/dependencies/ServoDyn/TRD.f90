!**********************************************************************************************************************************
! Twin Rotor Damper Module
!**********************************************************************************************************************************

MODULE TRD  

   USE TRD_Types   
   USE NWTC_Library
      
   IMPLICIT NONE
   
   PRIVATE

  
   TYPE(ProgDesc), PARAMETER            :: TRD_Ver = ProgDesc( 'TRD', 'v1.03.00-jmc', '11-June-2018' )

    
   
   
      ! ..... Public Subroutines ...................................................................................................

   PUBLIC :: TRD_Init                           ! Initialization routine
   PUBLIC :: TRD_End                            ! Ending routine (includes clean up)
   
   PUBLIC :: TRD_UpdateStates                   ! Loose coupling routine for solving for constraint states, integrating 
                                                    !   continuous states, and updating discrete states
   PUBLIC :: TRD_CalcOutput                     ! Routine for computing outputs
   
  ! PUBLIC :: TRD_CalcConstrStateResidual        ! Tight coupling routine for returning the constraint state residual
   PUBLIC :: TRD_CalcContStateDeriv             ! Tight coupling routine for computing derivatives of continuous states

   !PUBLIC :: TRD_UpdateDiscState                ! Tight coupling routine for updating discrete states
      
   !PUBLIC :: TRD_JacobianPInput                 ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the inputs (u)
   !PUBLIC :: TRD_JacobianPContState             ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the continuous 
   !                                                 !   states (x)
   !PUBLIC :: TRD_JacobianPDiscState             ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
   !                                                 !   (Xd), and constraint-state (Z) equations all with respect to the discrete 
   !                                                 !   states (xd)
   !PUBLIC :: TRD_JacobianPConstrState           ! Routine to compute the Jacobians of the output (Y), continuous- (X), discrete-
                                                    !   (Xd), and constraint-state (Z) equations all with respect to the constraint 
                                                    !   states (z)
   
 
   INTEGER(IntKi), PARAMETER :: ControlMode_NONE      = 0          ! The (ServoDyn-universal) control code for not using a particular type of control


   INTEGER(IntKi), PRIVATE, PARAMETER :: CMODE_Simple            = 1          !< one mode damping 
   INTEGER(IntKi), PRIVATE, PARAMETER :: CMODE_All               = 2          !< one mode damping                                      
                                                    
CONTAINS
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_Init( InitInp, u, p, x, xd, z, OtherState, y, m, Interval, InitOut, ErrStat, ErrMsg )
! This routine is called at the start of the simulation to perform initialization steps. 
! The parameters are set here and not changed during the simulation.
! The initial states and initial guess for the input are defined.
!..................................................................................................................................

      TYPE(TRD_InitInputType),       INTENT(INOUT)  :: InitInp     ! Input data for initialization routine. 
      TYPE(TRD_InputType),           INTENT(  OUT)  :: u           ! An initial guess for the input; input mesh must be defined
      TYPE(TRD_ParameterType),       INTENT(  OUT)  :: p           ! Parameters      
      TYPE(TRD_ContinuousStateType), INTENT(  OUT)  :: x           ! Initial continuous states
      TYPE(TRD_DiscreteStateType),   INTENT(  OUT)  :: xd          ! Initial discrete states
      TYPE(TRD_ConstraintStateType), INTENT(  OUT)  :: z           ! Initial guess of the constraint states
      TYPE(TRD_OtherStateType),      INTENT(  OUT)  :: OtherState  ! Initial other/optimization states            
      TYPE(TRD_OutputType),          INTENT(INOUT)  :: y           ! Initial system outputs (outputs are not calculated; 
                                                                   !   only the output mesh is initialized)
      TYPE(TRD_MiscVarType),         INTENT(  OUT)  :: m           !< Misc (optimization) variables

      REAL(DbKi),                    INTENT(INOUT)  :: Interval    ! Coupling interval in seconds: the rate that 
                                                                   !   (1) TRD_UpdateStates() is called in loose coupling &
                                                                   !   (2) TRD_UpdateDiscState() is called in tight coupling.
                                                                   !   Input is the suggested time from the glue code; 
                                                                   !   Output is the actual coupling interval that will be used 
                                                                   !   by the glue code.
      TYPE(TRD_InitOutputType),      INTENT(  OUT)  :: InitOut     ! Output for initialization routine
      INTEGER(IntKi),                INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                  INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None
 
      
         ! Local variables
      INTEGER(IntKi)                                :: NumOuts
!      INTEGER(IntKi)                                :: NumStates
      TYPE(TRD_InputFile)                           :: InputFileData ! Data stored in the module's input file    
!      CHARACTER(1024)                               :: SummaryName   ! name of the TRD summary file
!      TYPE(TRD_InitInputType)                       :: InitLocal     ! Local version of the initialization data, needed because the framework data (InitInp) is read-only
!      INTEGER                                       :: i             ! Generic index
!      INTEGER                                       :: j             ! Generic index  
                                                    
      INTEGER(IntKi)                                :: UnEcho        ! Unit number for the echo file   
      INTEGER(IntKi)                                :: ErrStat2      ! local error status
      CHARACTER(1024)                               :: ErrMsg2       ! local error message
      
      CHARACTER(*), PARAMETER                       :: RoutineName = 'TRD_Init'
      
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ''               
      NumOuts = 0
      !p%NumBl = 3
      !p%NumOuts = 4
     ! Initialize the NWTC Subroutine Library

   InitOut%dummyInitOut = 0.0_SiKi  ! initialize this so compiler doesn't warn about un-set intent(out) variables


   CALL NWTC_Init( EchoLibVer=.FALSE. )

      ! Display the module information

   CALL DispNVD( TRD_Ver )
   
    !............................................................................................      
    ! Read the input file and validate the data
    ! (note p%NumBl and p%RootName must be set first!) 
    !............................................................................................      
   p%RootName = TRIM(InitInp%RootName)//'.TRD' ! all of the output file names from this module will end with '.TRD'
          
      
   CALL TRD_ReadInput( InitInp%InputFile, InputFileData, Interval, p%RootName, ErrStat2, ErrMsg2 )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF (ErrStat >= AbortErrLev) RETURN

      
   !CALL ValidatePrimaryData( InputFileData, InitInp%NumBl, ErrStat2, ErrMsg2 )
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF (ErrStat >= AbortErrLev) RETURN

   IF ( InputFileData%TRD_CMODE /= CMODE_All .and. InputFileData%TRD_CMODE /= CMODE_Simple) &
      CALL SetErrStat( ErrID_Fatal, 'Control mode (TRD_CMode) must be 1 or 2 for this version of TRD.', ErrStat, ErrMsg, RoutineName )
   
   
      !............................................................................................
      ! Define parameters here:
      !............................................................................................
   CALL TRD_SetParameters( InputFileData, p, ErrStat2, ErrMsg2 )   
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF (ErrStat >= AbortErrLev) RETURN      
   
      p%DT  = Interval
      p%Gravity = InitInp%Gravity
         ! Destroy the local initialization data
      !CALL CleanUp()
         
      !............................................................................................
      ! Define initial system states here:
      !............................................................................................
      ! Define initial system states here:
            
    xd%DummyDiscState = 0
    z%DummyConstrState = 0
    
    ! Initialize other states here:
    OtherState%DummyOtherState = 0
    
    ! misc variables: external and stop forces
    m%F_ext  = 0.0_ReKi  ! whole array initializaton
    m%F_stop = 0.0_ReKi  ! whole array initializaton
    m%VA = 0.0_ReKi
    m%A = 0.0_ReKi
    m%PHIDD = 0.0_ReKi
    m%CE(1) = 0.0_ReKi
    m%CE(2) = 0.0_ReKi

    
    ! Define initial guess for the system inputs here:
    x%TRD_x(1) = 0.0_ReKi
    x%TRD_x(2) = 0.0_ReKi
    x%TRD_x(3) = p%PHI_DSP
    x%TRD_x(4) = 0.0_ReKi
        
    ! Filter Velocity
    x%TRD_xfiltervel(1) = 0.0_ReKi
    x%TRD_xfiltervel(2) = 0.0_ReKi
    x%TRD_xfiltervel(3) = 0.0_ReKi
    x%TRD_xfiltervel(4) = 0.0_ReKi
    
    ! Filter Acceleration
    x%TRD_xfilteracc(1) = 0.0_ReKi
    x%TRD_xfilteracc(2) = 0.0_ReKi
    x%TRD_xfilteracc(3) = 0.0_ReKi
    x%TRD_xfilteracc(4) = 0.0_ReKi
    
    ! PID Controller
    x%TRD_xpid(1) = 0.0_ReKi
    x%TRD_xpid(2) = 0.0_ReKi
    
    ! Define system output initializations (set up mesh) here:
    ! Create the input and output meshes associated with lumped loads
      
      CALL MeshCreate( BlankMesh        = u%Mesh            &
                     ,IOS               = COMPONENT_INPUT   &
                     ,Nnodes            = 1                 &
                     ,ErrStat           = ErrStat2          &
                     ,ErrMess           = ErrMsg2           &
                     ,TranslationDisp   = .TRUE.            &
                     ,Orientation       = .TRUE.            &
                     ,TranslationVel    = .TRUE.            &
                     ,RotationVel       = .TRUE.            &
                     ,TranslationAcc    = .TRUE.            &
                     ,RotationAcc       = .TRUE.)
         
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'TRD_Init')
         IF ( ErrStat >= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         END IF
      
         ! Create the node on the mesh
            
         
         ! make position node at point P (rest position of TRDs, somewhere above the yaw bearing) 
      CALL MeshPositionNode (u%Mesh                                &
                              , 1                                  &
                              , (/InitInp%r_N_O_G(1)+InputFileData%TRD_P(1), InitInp%r_N_O_G(2)+InputFileData%TRD_P(2), InitInp%r_N_O_G(3)+InputFileData%TRD_P(3)/)   &  
                              , ErrStat2                           &
                              , ErrMsg2                            )
      
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'TRD_Init')
       
      
         ! Create the mesh element
      CALL MeshConstructElement (  u%Mesh              &
                                  , ELEMENT_POINT      &                         
                                  , ErrStat2           &
                                  , ErrMsg2            &
                                  , 1                  &
                                              )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'TRD_Init')

      CALL MeshCommit ( u%Mesh              &
                      , ErrStat2            &
                      , ErrMsg2             )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'TRD_Init')
         IF ( ErrStat >= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         END IF      

         
      CALL MeshCopy ( SrcMesh      = u%Mesh                 &
                     ,DestMesh     = y%Mesh                 &
                     ,CtrlCode     = MESH_SIBLING           &
                     ,IOS          = COMPONENT_OUTPUT       &
                     ,ErrStat      = ErrStat2               &
                     ,ErrMess      = ErrMsg2                &
                     ,Force        = .TRUE.                 &
                     ,Moment       = .TRUE.                 )
     
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'TRD_Init')
         IF ( ErrStat >= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         END IF      
      
      
     u%Mesh%RemapFlag  = .TRUE.
     y%Mesh%RemapFlag  = .TRUE.
          
   !bjj: removed for now; output handled in ServoDyn
    !IF (NumOuts > 0) THEN   
    !   ALLOCATE( y%WriteOutput(NumOuts), STAT = ErrStat )
    !   IF ( ErrStat/= 0 ) THEN
    !      CALL SetErrStat(ErrID_Fatal,'Error allocating output array.',ErrStat,ErrMsg,'TRD_Init')
    !      CALL Cleanup()
    !      RETURN    
    !   END IF
    !   y%WriteOutput = 0
    !
    !   ! Define initialization-routine output here:
    !   ALLOCATE( InitOut%WriteOutputHdr(NumOuts), InitOut%WriteOutputUnt(NumOuts), STAT = ErrStat )
    !   IF ( ErrStat/= 0 ) THEN
    !      CALL SetErrStat(ErrID_Fatal,'Error allocating output header and units arrays.',ErrStat,ErrMsg,'TRD_Init')
    !      CALL Cleanup()
    !      RETURN
    !   END IF
    !  
    !   DO i=1,NumOuts
    !        InitOut%WriteOutputHdr(i) = "Heading"//trim(num2lstr(i))
    !        InitOut%WriteOutputUnt(i) = "(-)"
    !   END DO       
    !   
    !END IF
    
    !bjj: need to initialize headers/units
    
    ! If you want to choose your own rate instead of using what the glue code suggests, tell the glue code the rate at which
    ! this module must be called here:
    !Interval = p%DT
    
     
   call cleanup()   
!................................
CONTAINS
 SUBROUTINE CheckError(ErrID,Msg)
   ! This subroutine sets the error message and level and cleans up if the error is >= AbortErrLev
   !...............................................................................................................................

         ! Passed arguments
      INTEGER(IntKi), INTENT(IN) :: ErrID       ! The error identifier (ErrStat)
      CHARACTER(*),   INTENT(IN) :: Msg         ! The error message (ErrMsg)


      !............................................................................................................................
      ! Set error status/message;
      !............................................................................................................................

      IF ( ErrID /= ErrID_None ) THEN

         IF (ErrStat /= ErrID_None) ErrMsg = TRIM(ErrMsg)//NewLine
         ErrMsg = TRIM(ErrMsg)//'TRD_Init:'//TRIM(Msg)
         ErrStat = MAX(ErrStat, ErrID)

         !.........................................................................................................................
         ! Clean up if we're going to return on error: close files, deallocate local arrays
         !.........................................................................................................................
         IF ( ErrStat >= AbortErrLev ) THEN
            IF ( UnEcho > 0 ) CLOSE( UnEcho )
         END IF

      END IF


 END SUBROUTINE CheckError
       ! clean up

   SUBROUTINE CleanUp()
 
   IF ( UnEcho > 0 ) CLOSE( UnEcho )
 
   CALL TRD_DestroyInputFile( InputFileData, ErrStat2, ErrMsg2)
        ! Destroy the input data:
         
!      CALL TRD_DestroyInput( u, ErrStat, ErrMsg )
!         ! Destroy the parameter data:      
!      CALL TRD_DestroyParam( p, ErrStat, ErrMsg )
!         ! Destroy the state data:
!      CALL TRD_DestroyContState(   x,           ErrStat, ErrMsg )
!     ! CALL TRD_DestroyDiscState(   xd,          ErrStat, ErrMsg )
!     ! CALL TRD_DestroyConstrState( z,           ErrStat, ErrMsg )
!     ! CALL TRD_DestroyOtherState(  OtherState,  ErrStat, ErrMsg )
!     ! Destroy the output data:
!      CALL TRD_DestroyOutput( y, ErrStat, ErrMsg )      
      
   END SUBROUTINE CleanUp
END SUBROUTINE TRD_Init
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_End( u, p, x, xd, z, OtherState, y, m, ErrStat, ErrMsg )
! This routine is called at the end of the simulation.
!..................................................................................................................................

      TYPE(TRD_InputType),           INTENT(INOUT)  :: u           ! System inputs
      TYPE(TRD_ParameterType),       INTENT(INOUT)  :: p           ! Parameters     
      TYPE(TRD_ContinuousStateType), INTENT(INOUT)  :: x           ! Continuous states
      TYPE(TRD_DiscreteStateType),   INTENT(INOUT)  :: xd          ! Discrete states
      TYPE(TRD_ConstraintStateType), INTENT(INOUT)  :: z           ! Constraint states
      TYPE(TRD_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states            
      TYPE(TRD_OutputType),          INTENT(INOUT)  :: y           ! System outputs
      TYPE(TRD_MiscVarType),         INTENT(INOUT)  :: m           !< Misc (optimization) variables
      INTEGER(IntKi),                INTENT(  OUT)  :: ErrStat      ! Error status of the operation
      CHARACTER(*),                  INTENT(  OUT)  :: ErrMsg       ! Error message if ErrStat /= ErrID_None


         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
    
      
         ! Place any last minute operations or calculations here:


            
         ! Write the TRD-level output file data if the user requested module-level output
         ! and the current time has advanced since the last stored time step.
         
              
      
         ! Close files here:  
         

         ! Destroy the input data:
         
      CALL TRD_DestroyInput( u, ErrStat, ErrMsg )


         ! Destroy the parameter data:
      
      CALL TRD_DestroyParam( p, ErrStat, ErrMsg )


         ! Destroy the state data:
         
      CALL TRD_DestroyContState(   x,           ErrStat, ErrMsg )
      CALL TRD_DestroyDiscState(   xd,          ErrStat, ErrMsg )
      CALL TRD_DestroyConstrState( z,           ErrStat, ErrMsg )
      CALL TRD_DestroyOtherState(  OtherState,  ErrStat, ErrMsg )
         
      CALL TRD_DestroyMisc(  m,  ErrStat, ErrMsg )

         ! Destroy the output data:
         
      CALL TRD_DestroyOutput( y, ErrStat, ErrMsg )     

END SUBROUTINE TRD_End

!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_UpdateStates( t, n, Inputs, InputTimes, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )
! Loose coupling routine for solving constraint states, integrating continuous states, and updating discrete states.
! Continuous, constraint, and discrete states are updated to values at t + Interval.
!..................................................................................................................................

      REAL(DbKi),                         INTENT(IN   )  :: t               ! Current simulation time in seconds
      INTEGER(IntKi),                     INTENT(IN   )  :: n               ! Current step of the simulation: t = n*Interval
      TYPE(TRD_InputType),                INTENT(INOUT)  :: Inputs(:)       ! Inputs at InputTimes
      REAL(DbKi),                         INTENT(IN   )  :: InputTimes(:)   ! Times in seconds associated with Inputs
      TYPE(TRD_ParameterType),            INTENT(IN   )  :: p               ! Parameters
      TYPE(TRD_ContinuousStateType),      INTENT(INOUT)  :: x               ! Input: Continuous states at t;
                                                                            !   Output: Continuous states at t + Interval
      TYPE(TRD_DiscreteStateType),        INTENT(INOUT)  :: xd              ! Input: Discrete states at t;
                                                                            !   Output: Discrete states at t + Interval
      TYPE(TRD_ConstraintStateType),      INTENT(INOUT)  :: z               ! Input: Constraint states at t;
                                                                            !   Output: Constraint states at t + Interval
      TYPE(TRD_OtherStateType),           INTENT(INOUT)  :: OtherState      ! Other/optimization states
      !!   Output: Other states at t + Interval
      TYPE(TRD_MiscVarType),              INTENT(INOUT)  :: m               !< Misc (optimization) variables
      INTEGER(IntKi),                     INTENT(  OUT)  :: ErrStat         ! Error status of the operation
      CHARACTER(*),                       INTENT(  OUT)  :: ErrMsg          ! Error message if ErrStat /= ErrID_None

         ! Local variables
      !INTEGER                                            :: I               ! Generic loop counter
      !TYPE(TRD_ContinuousStateType)                      :: dxdt            ! Continuous state derivatives at t
      !TYPE(TRD_DiscreteStateType)                        :: xd_t            ! Discrete states at t (copy)
      !TYPE(TRD_ConstraintStateType)                      :: z_Residual      ! Residual of the constraint state functions (Z)
      !TYPE(TRD_InputType)                                :: u               ! Instantaneous inputs
      !INTEGER(IntKi)                                     :: ErrStat2        ! Error status of the operation (secondary error)
      !CHARACTER(ErrMsgLen)                               :: ErrMsg2         ! Error message if ErrStat2 /= ErrID_None
      !INTEGER                                            :: nTime           ! number of inputs 

     
      CALL TRD_RK4( t, n, Inputs, InputTimes, p, x, xd, z, OtherState, m,  ErrStat, ErrMsg )
      
END SUBROUTINE TRD_UpdateStates

SUBROUTINE TRD_RK4( t, n, u, utimes, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )
!
! This subroutine implements the fourth-order Runge-Kutta Method (RK4) for numerically integrating ordinary differential equations:
!
!   Let f(t, x) = xdot denote the time (t) derivative of the continuous states (x). 
!   Define constants k1, k2, k3, and k4 as 
!        k1 = dt * f(t        , x_t        )
!        k2 = dt * f(t + dt/2 , x_t + k1/2 )
!        k3 = dt * f(t + dt/2 , x_t + k2/2 ), and
!        k4 = dt * f(t + dt   , x_t + k3   ).
!   Then the continuous states at t = t + dt are
!        x_(t+dt) = x_t + k1/6 + k2/3 + k3/3 + k4/6 + O(dt^5)
!
! For details, see:
! Press, W. H.; Flannery, B. P.; Teukolsky, S. A.; and Vetterling, W. T. "Runge-Kutta Method" and "Adaptive Step Size Control for 
!   Runge-Kutta." §16.1 and 16.2 in Numerical Recipes in FORTRAN: The Art of Scientific Computing, 2nd ed. Cambridge, England: 
!   Cambridge University Press, pp. 704-716, 1992.
!
!..................................................................................................................................

      REAL(DbKi),                    INTENT(IN   )  :: t           ! Current simulation time in seconds
      INTEGER(IntKi),                INTENT(IN   )  :: n           ! time step number
      TYPE(TRD_InputType),           INTENT(INOUT)  :: u(:)        ! Inputs at t (out only for mesh record-keeping in ExtrapInterp routine)
      REAL(DbKi),                    INTENT(IN   )  :: utimes(:)   ! times of input
      TYPE(TRD_ParameterType),       INTENT(IN   )  :: p           ! Parameters
      TYPE(TRD_ContinuousStateType), INTENT(INOUT)  :: x           ! Continuous states at t on input at t + dt on output
      TYPE(TRD_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at t
      TYPE(TRD_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at t (possibly a guess)
      TYPE(TRD_OtherStateType),      INTENT(INOUT)  :: OtherState  ! Other/optimization states
      TYPE(TRD_MiscVarType),         INTENT(INOUT)  :: m           !< Misc (optimization) variables
      INTEGER(IntKi),                INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                  INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None
                                     
      ! local variables
         
      TYPE(TRD_ContinuousStateType)                 :: xdot        ! time derivatives of continuous states      
      TYPE(TRD_ContinuousStateType)                 :: k1          ! RK4 constant; see above
      TYPE(TRD_ContinuousStateType)                 :: k2          ! RK4 constant; see above 
      TYPE(TRD_ContinuousStateType)                 :: k3          ! RK4 constant; see above 
      TYPE(TRD_ContinuousStateType)                 :: k4          ! RK4 constant; see above 
      TYPE(TRD_ContinuousStateType)                 :: x_tmp       ! Holds temporary modification to x
      TYPE(TRD_InputType)                           :: u_interp    ! interpolated value of inputs 

      INTEGER(IntKi)                                :: ErrStat2    ! local error status
      CHARACTER(LEN(ErrMsg))                          :: ErrMsg2     ! local error message (ErrMsg)
      ! Initialize ErrStat

      ErrStat = ErrID_None
      ErrMsg  = "" 

      CALL TRD_CopyContState( x, k1, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
      CALL TRD_CopyContState( x, k2, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
      CALL TRD_CopyContState( x, k3, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
      CALL TRD_CopyContState( x, k4, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
      CALL TRD_CopyContState( x, x_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN


      CALL TRD_CopyInput( u(1), u_interp, MESH_NEWCOPY, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN
                     
      ! interpolate u to find u_interp = u(t)
      CALL TRD_Input_ExtrapInterp( u, utimes, u_interp, t, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      ! find xdot at t
      CALL TRD_CalcContStateDeriv( t, u_interp, p, x, xd, z, OtherState, m, xdot, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      k1%TRD_x  = p%dt * xdot%TRD_x
      x_tmp%TRD_x  = x%TRD_x  + 0.5 * k1%TRD_x

      IF (p%CMODE == 2) THEN

          k1%TRD_xfiltervel  = p%dt * xdot%TRD_xfiltervel
          x_tmp%TRD_xfiltervel  = x%TRD_xfiltervel  + 0.5 * k1%TRD_xfiltervel
    
          k1%TRD_xfilteracc  = p%dt * xdot%TRD_xfilteracc
          x_tmp%TRD_xfilteracc  = x%TRD_xfilteracc  + 0.5 * k1%TRD_xfilteracc
    
          k1%TRD_xpid  = p%dt * xdot%TRD_xpid
          x_tmp%TRD_xpid  = x%TRD_xpid  + 0.5 * k1%TRD_xpid

      ENDIF

      ! interpolate u to find u_interp = u(t + dt/2)
      CALL TRD_Input_ExtrapInterp(u, utimes, u_interp, t+0.5*p%dt, ErrStat2, ErrMsg2)
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      ! find xdot at t + dt/2
      CALL TRD_CalcContStateDeriv( t + 0.5*p%dt, u_interp, p, x_tmp, xd, z, OtherState, m, xdot, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      k2%TRD_x  = p%dt * xdot%TRD_x
      x_tmp%TRD_x  = x%TRD_x  + 0.5 * k2%TRD_x

      IF (p%CMODE == 2) THEN

          k2%TRD_xfiltervel  = p%dt * xdot%TRD_xfiltervel
          x_tmp%TRD_xfiltervel  = x%TRD_xfiltervel  + 0.5 * k2%TRD_xfiltervel
    
          k2%TRD_xfilteracc  = p%dt * xdot%TRD_xfilteracc
          x_tmp%TRD_xfilteracc  = x%TRD_xfilteracc  + 0.5 * k2%TRD_xfilteracc
    
          k2%TRD_xpid  = p%dt * xdot%TRD_xpid
          x_tmp%TRD_xpid  = x%TRD_xpid  + 0.5 * k2%TRD_xpid

      ENDIF

      ! find xdot at t + dt/2
      CALL TRD_CalcContStateDeriv( t + 0.5*p%dt, u_interp, p, x_tmp, xd, z, OtherState, m, xdot, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      k3%TRD_x  = p%dt * xdot%TRD_x
      x_tmp%TRD_x  = x%TRD_x  + k3%TRD_x

      IF (p%CMODE == 2) THEN

          k3%TRD_xfiltervel  = p%dt * xdot%TRD_xfiltervel
          x_tmp%TRD_xfiltervel  = x%TRD_xfiltervel  + k3%TRD_xfiltervel
    
          k3%TRD_xfilteracc  = p%dt * xdot%TRD_xfilteracc
          x_tmp%TRD_xfilteracc  = x%TRD_xfilteracc  + k3%TRD_xfilteracc
    
          k3%TRD_xpid  = p%dt * xdot%TRD_xpid
          x_tmp%TRD_xpid  = x%TRD_xpid  + k3%TRD_xpid

      ENDIF

      ! interpolate u to find u_interp = u(t + dt)
      CALL TRD_Input_ExtrapInterp(u, utimes, u_interp, t + p%dt, ErrStat2, ErrMsg2)
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      ! find xdot at t + dt
      CALL TRD_CalcContStateDeriv( t + p%dt, u_interp, p, x_tmp, xd, z, OtherState, m, xdot, ErrStat2, ErrMsg2 )
         CALL CheckError(ErrStat2,ErrMsg2)
         IF ( ErrStat >= AbortErrLev ) RETURN

      k4%TRD_x  = p%dt * xdot%TRD_x
      
      x%TRD_x  = x%TRD_x  +  ( k1%TRD_x  + 2. * k2%TRD_x  + 2. * k3%TRD_x  + k4%TRD_x  ) / 6. 

      IF (p%CMODE == 2) THEN

          k4%TRD_xfiltervel  = p%dt * xdot%TRD_xfiltervel
    
          k4%TRD_xfilteracc  = p%dt * xdot%TRD_xfilteracc
    
          k4%TRD_xpid  = p%dt * xdot%TRD_xpid
          
          x%TRD_xfiltervel  = x%TRD_xfiltervel  +  ( k1%TRD_xfiltervel  + 2. * k2%TRD_xfiltervel  + 2. * k3%TRD_xfiltervel  + k4%TRD_xfiltervel  ) / 6.
          x%TRD_xfilteracc  = x%TRD_xfilteracc  +  ( k1%TRD_xfilteracc  + 2. * k2%TRD_xfilteracc  + 2. * k3%TRD_xfilteracc  + k4%TRD_xfilteracc  ) / 6. 
          x%TRD_xpid  = x%TRD_xpid  +  ( k1%TRD_xpid  + 2. * k2%TRD_xpid  + 2. * k3%TRD_xpid  + k4%TRD_xpid  ) / 6. 

      ENDIF       
     ! x%TRD_dxdt = x%TRD_dxdt +  ( k1%TRD_dxdt + 2. * k2%TRD_dxdt + 2. * k3%TRD_dxdt + k4%TRD_dxdt ) / 6.      

         ! clean up local variables:
      CALL ExitThisRoutine(  )
         
CONTAINS      
   !...............................................................................................................................
   SUBROUTINE ExitThisRoutine()
   ! This subroutine destroys all the local variables
   !...............................................................................................................................

         ! local variables
      INTEGER(IntKi)             :: ErrStat3    ! The error identifier (ErrStat)
      CHARACTER(1024)            :: ErrMsg3     ! The error message (ErrMsg)
   
   
      CALL TRD_DestroyContState( xdot,     ErrStat3, ErrMsg3 )
      CALL TRD_DestroyContState( k1,       ErrStat3, ErrMsg3 )
      CALL TRD_DestroyContState( k2,       ErrStat3, ErrMsg3 )
      CALL TRD_DestroyContState( k3,       ErrStat3, ErrMsg3 )
      CALL TRD_DestroyContState( k4,       ErrStat3, ErrMsg3 )
      CALL TRD_DestroyContState( x_tmp,    ErrStat3, ErrMsg3 )

      CALL TRD_DestroyInput(     u_interp, ErrStat3, ErrMsg3 )
         
   END SUBROUTINE ExitThisRoutine      
   !...............................................................................................................................
   SUBROUTINE CheckError(ErrID,Msg)
   ! This subroutine sets the error message and level and cleans up if the error is >= AbortErrLev
   !...............................................................................................................................

         ! Passed arguments
      INTEGER(IntKi), INTENT(IN) :: ErrID       ! The error identifier (ErrStat)
      CHARACTER(*),   INTENT(IN) :: Msg         ! The error message (ErrMsg)

         ! local variables
      INTEGER(IntKi)             :: ErrStat3    ! The error identifier (ErrStat)
      CHARACTER(LEN(Msg))       :: ErrMsg3     ! The error message (ErrMsg)

      !............................................................................................................................
      ! Set error status/message;
      !............................................................................................................................

      IF ( ErrID /= ErrID_None ) THEN

         IF (ErrStat /= ErrID_None) ErrMsg = TRIM(ErrMsg)//NewLine
         ErrMsg = TRIM(ErrMsg)//'TRD_RK4:'//TRIM(Msg)         
         ErrStat = MAX(ErrStat,ErrID)
         
         !.........................................................................................................................
         ! Clean up if we're going to return on error: close files, deallocate local arrays
         !.........................................................................................................................
         
         IF ( ErrStat >= AbortErrLev ) CALL ExitThisRoutine( )                  
                  
         
      END IF

   END SUBROUTINE CheckError                    
      
END SUBROUTINE TRD_RK4

!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_CalcOutput( Time, u, p, x, xd, z, OtherState, y, m, ErrStat, ErrMsg )   
! Routine for computing outputs, used in both loose and tight coupling.
!..................................................................................................................................
   
      REAL(DbKi),                    INTENT(IN   )  :: Time        ! Current simulation time in seconds
      TYPE(TRD_InputType),           INTENT(IN   )  :: u           ! Inputs at Time
      TYPE(TRD_ParameterType),       INTENT(IN   )  :: p           ! Parameters
      TYPE(TRD_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(TRD_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at Time
      TYPE(TRD_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time
      TYPE(TRD_OtherStateType),      INTENT(IN   )  :: OtherState  ! Other/optimization states
      TYPE(TRD_OutputType),          INTENT(INOUT)  :: y           ! Outputs computed at Time (Input only so that mesh con-
                                                                        !   nectivity information does not have to be recalculated)
      TYPE(TRD_MiscVarType),         INTENT(INOUT)  :: m           !< Misc (optimization) variables
      INTEGER(IntKi),                INTENT(  OUT)  :: ErrStat     ! Error status of the operation
      CHARACTER(*),                  INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None
      ! local variables
      REAL(ReKi), dimension(3)                   :: a_G_O
      REAL(ReKi), dimension(3)                   :: a_G_N
      REAL(ReKi), dimension(3)                   :: F_P_N
      REAL(ReKi), dimension(3)                   :: M_P_N
      !nacelle movement in local coordinates
      Real(ReKi), dimension(3)                   :: r_ddot_P_N
      Real(ReKi), dimension(3)                   :: omega_N_O_N
      Real(ReKi), dimension(3)                   :: alpha_N_O_N
      !dependent accelerations
      Real(ReKi)                                 :: F_x_TRDY_P_N 
      Real(ReKi)                                 :: F_z_TRDY_P_N 
      Real(ReKi)                                 :: F_y_TRDX_P_N 
      Real(ReKi)                                 :: F_z_TRDX_P_N

      Real(ReKi)                                :: FC,FEXT,F_E

      ErrStat = ErrID_None         
      ErrMsg  = "" 
      ! gravity vector in global coordinates
      a_G_O (1) = 0.0_ReKi 
      a_G_O (2) = 0.0_ReKi
      a_G_O (3) = -p%Gravity
      
       ! Compute nacelle and gravitational acceleration in nacelle coordinates 
      a_G_N  = matmul(u%Mesh%Orientation(:,:,1),a_G_O)
      r_ddot_P_N = matmul(u%Mesh%Orientation(:,:,1),u%Mesh%TranslationAcc(:,1))
      omega_N_O_N = matmul(u%Mesh%Orientation(:,:,1),u%Mesh%RotationVel(:,1))
      alpha_N_O_N = matmul(u%Mesh%Orientation(:,:,1),u%Mesh%RotationAcc(:,1))
      
      ! TRD external forces of dependent degrees:
      !F_x_TRDY_P_N = - p%M_Y * (a_G_N(1) - r_ddot_P_N(1) + (alpha_N_O_N(3) - omega_N_O_N(1)*omega_N_O_N(2))*x%TRD_x(3) + 2*omega_N_O_N(3)*x%TRD_x(4))
      !F_z_TRDY_P_N = - p%M_Y * (a_G_N(3) - r_ddot_P_N(3) + (alpha_N_O_N(1) + omega_N_O_N(2)*omega_N_O_N(3))*x%TRD_x(3) - 2*omega_N_O_N(1)*x%TRD_x(4))
      
      !F_y_TRDX_P_N = - p%M_X *( a_G_N(2) - r_ddot_P_N(2) + (alpha_N_O_N(3) + omega_N_O_N(1)*omega_N_O_N(2))*x%TRD_x(1) - 2*omega_N_O_N(3)*x%TRD_x(2))
      !F_z_TRDX_P_N = - p%M_X * (a_G_N(3) - r_ddot_P_N(3) + (alpha_N_O_N(2) - omega_N_O_N(1)*omega_N_O_N(3))*x%TRD_x(1) + 2*omega_N_O_N(2)*x%TRD_x(2))
      
      ! forces in local coordinates

!      F_E=0.2308_ReKi
!      F_E=0.2387_ReKi

!      FEXT=10000.0_ReKi*SIN(8.0_Reki*ATAN(1.0_ReKi)*F_E*Time)

      FC=p%MC * p%RC * (m%PHIDD*SIN(x%TRD_x(3))+x%TRD_x(4)*x%TRD_x(4)*COS(x%TRD_x(3)))

      F_P_N(1) =  m%A*FC !+FEXT
      F_P_N(2) =  0.0_ReKi
      F_P_N(3) =  0.0_ReKi
      
      ! inertial contributions from mass of TRDs and acceleration of nacelle
      ! forces in global coordinates
      y%Mesh%Force(:,1) =  matmul(transpose(u%Mesh%Orientation(:,:,1)),F_P_N)
     
      ! Moments on nacelle in local coordinates
      M_P_N(1) = 0.0_ReKi !- F_z_TRDY_P_N * x%TRD_x(3)
      M_P_N(2) = 0.0_ReKi ! F_z_TRDX_P_N * x%TRD_x(1)
      M_P_N(3) = 0.0_ReKi !(- F_x_TRDY_P_N) * x%TRD_x(3) + (F_y_TRDX_P_N) * x%TRD_x(1)
      
      ! moments in global coordinates
      y%Mesh%Moment(:,1) = matmul(transpose(u%Mesh%Orientation(:,:,1)),M_P_N)
       
END SUBROUTINE TRD_CalcOutput
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_CalcContStateDeriv( Time, u, p, x, xd, z, OtherState, m, dxdt, ErrStat, ErrMsg )  
! Tight coupling routine for computing derivatives of continuous states
!..................................................................................................................................
   
      REAL(DbKi),                    INTENT(IN   )  :: Time        ! Current simulation time in seconds
      TYPE(TRD_InputType),           INTENT(IN   )  :: u           ! Inputs at Time                    
      TYPE(TRD_ParameterType),       INTENT(IN   )  :: p           ! Parameters                             
      TYPE(TRD_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(TRD_DiscreteStateType),   INTENT(IN   )  :: xd          ! Discrete states at Time
      TYPE(TRD_ConstraintStateType), INTENT(IN   )  :: z           ! Constraint states at Time
      TYPE(TRD_OtherStateType),      INTENT(IN   )  :: OtherState  ! Other/optimization states                    
      TYPE(TRD_ContinuousStateType), INTENT(  OUT)  :: dxdt        ! Continuous state derivatives at Time
      TYPE(TRD_MiscVarType),         INTENT(INOUT)  :: m           !< Misc (optimization) variables
      INTEGER(IntKi),                INTENT(  OUT)  :: ErrStat     ! Error status of the operation     
      CHARACTER(*),                  INTENT(  OUT)  :: ErrMsg      ! Error message if ErrStat /= ErrID_None
         ! local variables
      REAL(ReKi), dimension(3)                      :: a_G_O
      REAL(ReKi), dimension(3)                      :: a_G_N
      REAL(ReKi), dimension(3)                      :: rddot_N_N
      REAL(ReKi), dimension(3)                      :: omega_P_N ! angular velocity of nacelle transformed to nacelle orientation
      REAL(ReKi)                                    :: B_X 
      REAL(ReKi)                                    :: B_Y
      REAL(ReKi)                                    :: K
      REAL(ReKi)                                    :: TWOPIF,PSI1,PSI2,TP1,TP2,PI,E1,E2,CE1,CE2,vectemp,mattemp
      REAL(ReKi), dimension(3)                      :: position,velocity,acceleration
      REAL(ReKi)                                    :: filteredvel,filteredacc
      REAL(ReKi), dimension(4)                      :: xfilter,xfilterdot
      
      REAL(ReKi), dimension(4,4)                    :: Afilter
      REAL(ReKi), dimension(4)                      :: Bfilter,Cfilter
      REAL(ReKi)                                    :: Dfilter

      
      INTEGER(IntKi)                                :: N1,N2,i,j
!      INTEGER                                      :: i         
      !Real(ReKi), dimension(2)                  :: F_stop !stop forces
         ! Initialize ErrStat
         
      ErrStat = ErrID_None         
      ErrMsg  = ""               
      
      CALL TRD_CalcStopForce(x,p,m%F_stop)
     
      ! gravity vector in global coordinates
      a_G_O (1) = 0.0_ReKi
      a_G_O (2) = 0.0_ReKi
      a_G_O (3) = -p%Gravity
      
       ! Compute nacelle and gravitational acceleration in nacelle coordinates 
      a_G_N  = matmul(u%Mesh%Orientation(:,:,1),a_G_O)
      rddot_N_N =  matmul(u%Mesh%Orientation(:,:,1),u%Mesh%TranslationAcc(:,1))    
      omega_P_N = matmul(u%Mesh%Orientation(:,:,1),u%Mesh%RotationVel(:,1)) 
      
      
      ! Compute inputs
!      B_X = - rddot_N_N(1) + a_G_N(1) + 1 / p%M_X * ( OtherState%F_ext(1) + OtherState%F_stop(1))
!      B_Y = - rddot_N_N(2) + a_G_N(2) + 1 / p%M_Y * ( OtherState%F_ext(2) + OtherState%F_stop(2))

      PI=4.0_ReKi*ATAN(1.0_ReKi)

      TWOPIF=2.0_ReKi*PI*p%F0

      K=(TWOPIF**2.0_ReKi)*p%M
      
      position=matmul(transpose(u%Mesh%Orientation(:,:,1)),u%Mesh%TranslationDisp(:,1))
      
      IF (p%CMODE == 1) THEN
      
       ! Damping of the first mode
          
          dxdt%TRD_x(1) = x%TRD_x(2)+(x%TRD_x(1)-position(1))*p%L(2)
          dxdt%TRD_x(2) = -1.0*K/p%M*x%TRD_x(1)+(x%TRD_x(1)-position(1))*p%L(1)
    
          PSI1=ATAN2(TWOPIF*x%TRD_x(2),dxdt%TRD_x(2))
          PSI2=ATAN2(TWOPIF*x%TRD_x(1),x%TRD_x(2))
    
          TP1=PI/2.0_ReKi+PSI1
          TP2=PI+PSI2
    
          E1=TP1-x%TRD_x(3)
          E2=TP2-x%TRD_x(3)
    
          N1=CEILING((-1.0_ReKi*PI-E1)/(2.0_ReKi*PI))
          N2=CEILING((-1.0_ReKi*PI-E2)/(2.0_ReKi*PI))
          
          CE1 = E1+REAL(N1,ReKi)*2.0_ReKi*PI
          CE2 = E2+REAL(N2,ReKi)*2.0_ReKi*PI
    
          m%CE(1)=CE1
          m%CE(2)=CE2
          
          dxdt%TRD_x(3) = x%TRD_x(4)
          dxdt%TRD_x(4) = p%K(1)*CE1+p%K(2)*(TWOPIF-x%TRD_x(4))
    
          m%PHIDD = dxdt%TRD_x(4)
    
          m%VA=SQRT((x%TRD_x(1)*TWOPIF)**2.0_ReKi+x%TRD_x(2)**2.0_ReKi)
      
      ELSEIF (p%CMODE == 2) THEN
      
       ! Damping of all vibrations
      
          velocity=matmul(transpose(u%Mesh%Orientation(:,:,1)),u%Mesh%TranslationVel(:,1))
          acceleration=matmul(transpose(u%Mesh%Orientation(:,:,1)),u%Mesh%TranslationAcc(:,1))
                            
          filteredvel = 0.0_ReKi
          filteredacc = 0.0_ReKi
    
          DO i=1,4
                dxdt%TRD_xfiltervel(i) = 0.0_ReKi
                dxdt%TRD_xfilteracc(i) = 0.0_ReKi
                DO j=1,4
                    dxdt%TRD_xfiltervel(i) = dxdt%TRD_xfiltervel(i)+p%Afilter(i,j)*x%TRD_xfiltervel(j)
                    dxdt%TRD_xfilteracc(i) = dxdt%TRD_xfilteracc(i)+p%Afilter(i,j)*x%TRD_xfilteracc(j)
                ENDDO
                dxdt%TRD_xfiltervel(i) = dxdt%TRD_xfiltervel(i)+p%Bfilter(i)*velocity(1)
                dxdt%TRD_xfilteracc(i) = dxdt%TRD_xfilteracc(i)+p%Bfilter(i)*acceleration(1)
                filteredvel = filteredvel+p%Cfilter(i)*x%TRD_xfiltervel(i)
                filteredacc = filteredacc+p%Cfilter(i)*x%TRD_xfilteracc(i)
          ENDDO
    
          filteredvel = filteredvel+velocity(1)*p%Dfilter
          filteredacc = filteredacc+acceleration(1)*p%Dfilter
    
          PSI1=ATAN2(TWOPIF*filteredvel,filteredacc)
     
          TP1=PI/2.0_ReKi+PSI1+0.6_ReKi
          
          E1=TP1-x%TRD_x(3)
        
          N1=CEILING((-1.0_ReKi*PI-E1)/(2.0_ReKi*PI))
    
          CE1 = E1+REAL(N1,ReKi)*2.0_ReKi*PI
          
          dxdt%TRD_x(3) = x%TRD_x(4)
          dxdt%TRD_x(4) = 0.0_ReKi
    
          do i=1,2
                dxdt%TRD_xpid(i) = 0.0_ReKi
                do j=1,2
                    dxdt%TRD_xpid(i) = dxdt%TRD_xpid(i)+p%Apid(i,j)*x%TRD_xpid(j)
                enddo
                dxdt%TRD_xpid(i) = dxdt%TRD_xpid(i)+p%Bpid(i)*CE1
                dxdt%TRD_x(4) = dxdt%TRD_x(4)+p%Cpid(i)*x%TRD_xpid(i)
          enddo
          
          m%CE(1)=CE1
          m%CE(2)=0.0_ReKi
    
          dxdt%TRD_x(4) = dxdt%TRD_x(4)+p%Dpid*CE1
    
          m%PHIDD = dxdt%TRD_x(4)
    
          m%VA=SQRT((filteredvel*TWOPIF)**2.0_ReKi+filteredacc**2.0_ReKi)
      
      ENDIF

      IF (m%VA > p%AON) THEN

            m%A = 1.0_ReKi 

      ENDIF

      IF(m%VA < p%AOFF) THEN

            m%A = 0.0_ReKi 

      ENDIF

CONTAINS
   SUBROUTINE TRD_CalcStopForce(x,p,F_stop)
      TYPE(TRD_ContinuousStateType), INTENT(IN   )  :: x           ! Continuous states at Time
      TYPE(TRD_ParameterType),       INTENT(IN   )  :: p           ! Parameters   
      Real(ReKi), dimension(2), INTENT(INOUT)       :: F_stop      !stop forces
   ! local variables
      Real(ReKi), dimension(2)                      :: F_SK      !stop spring forces
      Real(ReKi), dimension(2)                      :: F_SD      !stop damping forces
      INTEGER(IntKi)                              :: i ! counter
      INTEGER(IntKi)                              :: j = 1! counter
      j=1
      DO i=1,2
!         IF (j < 5) THEN
!            IF ( x%TRD_x(j) > p%P_SP(i) ) THEN
!               F_SK(i) = p%K_S(i) *( p%P_SP(i) - x%TRD_x(j)  )
!            ELSEIF ( x%TRD_x(j) < p%N_SP(i) ) THEN
!               F_SK(i) = p%K_S(i) * ( p%N_SP(i) - x%TRD_x(j) )
!            ENDIF
!            IF ( (x%TRD_x(j) > p%P_SP(i)) .AND. (x%TRD_x(j+1) > 0) ) THEN
!               F_SD(i) = -p%C_S(i) *( x%TRD_x(j+1)  )
!            ELSEIF ( (x%TRD_x(j) < p%N_SP(i)) .AND. (x%TRD_x(j+1) < 0) ) THEN
!               F_SD(i) = -p%C_S(i) *( x%TRD_x(j+1)  )
!            ENDIF
            F_stop(i) = 0 !F_SK(i) + F_SD(i)
!            j = j+2
!         END IF
   END DO
   END SUBROUTINE TRD_CalcStopForce
END SUBROUTINE TRD_CalcContStateDeriv
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_ReadInput( InputFileName, InputFileData, Default_DT, OutFileRoot, ErrStat, ErrMsg )
! This subroutine reads the input file and stores all the data in the TRD_InputFile structure.
! It does not perform data validation.
!..................................................................................................................................

      ! Passed variables
   REAL(DbKi),           INTENT(IN)       :: Default_DT     ! The default DT (from glue code)

   CHARACTER(*), INTENT(IN)               :: InputFileName  ! Name of the input file
   CHARACTER(*), INTENT(IN)               :: OutFileRoot    ! The rootname of all the output files written by this routine.

   TYPE(TRD_InputFile),   INTENT(OUT)     :: InputFileData  ! Data stored in the module's input file

   INTEGER(IntKi),       INTENT(OUT)      :: ErrStat        ! The error status code
   CHARACTER(*),         INTENT(OUT)      :: ErrMsg         ! The error message, if an error occurred

      ! local variables

   INTEGER(IntKi)                         :: UnEcho         ! Unit number for the echo file
   INTEGER(IntKi)                         :: ErrStat2       ! The error status code
   CHARACTER(LEN(ErrMsg))                   :: ErrMsg2        ! The error message, if an error occurred
   
      ! initialize values: 
   
   ErrStat = ErrID_None
   ErrMsg  = ""

  ! InputFileData%DT = Default_DT  ! the glue code's suggested DT for the module (may be overwritten in ReadPrimaryFile())
   
      ! get the primary/platform input-file data
   
   CALL ReadPrimaryFile( InputFileName, InputFileData, OutFileRoot, UnEcho, ErrStat2, ErrMsg2 )
      CALL CheckError(ErrStat2,ErrMsg2)
      IF ( ErrStat >= AbortErrLev ) RETURN
      

      ! we may need to read additional files here 
   
      
      ! close any echo file that was opened
      
   IF ( UnEcho > 0 ) CLOSE( UnEcho )        

CONTAINS
   !...............................................................................................................................
   SUBROUTINE CheckError(ErrID,Msg)
   ! This subroutine sets the error message and level and cleans up if the error is >= AbortErrLev
   !...............................................................................................................................

         ! Passed arguments
      INTEGER(IntKi), INTENT(IN) :: ErrID       ! The error identifier (ErrStat)
      CHARACTER(*),   INTENT(IN) :: Msg         ! The error message (ErrMsg)


      !............................................................................................................................
      ! Set error status/message;
      !............................................................................................................................

      IF ( ErrID /= ErrID_None ) THEN

         IF (ErrStat /= ErrID_None) ErrMsg = TRIM(ErrMsg)//NewLine
         ErrMsg = TRIM(ErrMsg)//'TRD_ReadInput:'//TRIM(Msg)
         ErrStat = MAX(ErrStat, ErrID)

         !.........................................................................................................................
         ! Clean up if we're going to return on error: close files, deallocate local arrays
         !.........................................................................................................................
         IF ( ErrStat >= AbortErrLev ) THEN
            IF ( UnEcho > 0 ) CLOSE( UnEcho )
         END IF

      END IF


   END SUBROUTINE CheckError     

END SUBROUTINE TRD_ReadInput
!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE ReadPrimaryFile( InputFile, InputFileData, OutFileRoot, UnEc, ErrStat, ErrMsg )
! This routine reads in the primary ServoDyn input file and places the values it reads in the InputFileData structure.
!   It opens and prints to an echo file if requested.
!..................................................................................................................................


   IMPLICIT                        NONE

      ! Passed variables
   INTEGER(IntKi),     INTENT(OUT)     :: UnEc                                ! I/O unit for echo file. If > 0, file is open for writing.
   INTEGER(IntKi),     INTENT(OUT)     :: ErrStat                             ! Error status

   CHARACTER(*),       INTENT(IN)      :: InputFile                           ! Name of the file containing the primary input data
   CHARACTER(*),       INTENT(OUT)     :: ErrMsg                              ! Error message
   CHARACTER(*),       INTENT(IN)      :: OutFileRoot                         ! The rootname of the echo file, possibly opened in this routine

   TYPE(TRD_InputFile), INTENT(INOUT) :: InputFileData                       ! All the data in the TRD input file
   
      ! Local variables:
   REAL(ReKi)                    :: TmpRAry(4)                                ! A temporary array to read a table from the input file
   INTEGER(IntKi)                :: I                                         ! loop counter
!   INTEGER(IntKi)                :: NumOuts                                   ! Number of output channel names read from the file 
   INTEGER(IntKi)                :: UnIn                                      ! Unit number for reading file
     
   INTEGER(IntKi)                :: ErrStat2                                  ! Temporary Error status
   LOGICAL                       :: Echo                                      ! Determines if an echo file should be written
   CHARACTER(LEN(ErrMsg))          :: ErrMsg2                                   ! Temporary Error message
   CHARACTER(1024)               :: PriPath                                   ! Path name of the primary file
   CHARACTER(1024)               :: FTitle                                    ! "File Title": the 2nd line of the input file, which contains a description of its contents
!   CHARACTER(200)                :: Line                                      ! Temporary storage of a line from the input file (to compare with "default")

   
      ! Initialize some variables:
   ErrStat = ErrID_None
   ErrMsg  = ""
      
   UnEc = -1
   Echo = .FALSE.   
   CALL GetPath( InputFile, PriPath )     ! Input files will be relative to the path where the primary input file is located.
   

   !CALL AllocAry( InputFileData%OutList, MaxOutPts, "ServoDyn Input File's Outlist", ErrStat2, ErrMsg2 )
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF ( ErrStat >= AbortErrLev ) RETURN   
      
   
      ! Get an available unit number for the file.

   CALL GetNewUnit( UnIn, ErrStat2, ErrMsg2 )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN


      ! Open the Primary input file.

   CALL OpenFInpFile ( UnIn, InputFile, ErrStat2, ErrMsg2 )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
                  
      
   ! Read the lines up/including to the "Echo" simulation control variable
   ! If echo is FALSE, don't write these lines to the echo file. 
   ! If Echo is TRUE, rewind and write on the second try.
   

   !-------------------------- HEADER ---------------------------------------------
   
   CALL ReadCom( UnIn, InputFile, 'File header: Module Version (line 1)', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN

   CALL ReadStr( UnIn, InputFile, FTitle, 'FTitle', 'File Header: File Description (line 2)', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN      
         
   !------------------ TRD GEOMETRICAL CONFIGURATION -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: TRD GEOMETRICAL CONFIGURATION', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
   
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_MC, "TRD_MC", "TRD mass", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
   
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_RC, "TRD_RC", "TRD radius", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN

   CALL ReadAryLines ( UnIn, InputFile, InputFileData%TRD_P, SIZE(InputFileData%TRD_P), 'TRD_P', 'position of the TRD', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
      
   !------------------ TRD INITIAL CONDITIONS -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: TRD INITIAL CONDITIONS', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN  

   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_PHI_DSP, "TRD_PHI_DSP", "TRD_PHI initial position", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
      
   !------------------ TRD CONTROL PARAMETERS - COMMON -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: TRD CONTROL PARAMETERS - COMMON', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_CMODE, "TRD_CMODE", "control mode (0:none; 1:damping of one mode; 2:damping of all vibrations)", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN

   CALL ReadVar(UnIn,InputFile,InputFileData%TRD_AON,"TRD_AON","TRD activation threshold (-)",ErrStat2,ErrMsg2,UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN   

   CALL ReadVar(UnIn,InputFile,InputFileData%TRD_AOFF,"TRD_AOFF","TRD deactivation threshold (-)",ErrStat2,ErrMsg2,UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN 
   
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_F0, "TRD_F0" , "TRD frequency of the mode to be damped", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN   
      
   !------------------ TRD CONTROL PARAMETERS - MODE 1 -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: TRD CONTROL PARAMETERS - MODE 1', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 

   CALL ReadAryLines ( UnIn, InputFile, InputFileData%TRD_K, SIZE(InputFileData%TRD_K), 'TRD_K', 'TRD K vector coefficients', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN

   CALL ReadAryLines ( UnIn, InputFile, InputFileData%TRD_L, SIZE(InputFileData%TRD_L), 'TRD_L', 'TRD L vector coefficients', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN
   
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_M, "TRD_M" , "TRD modal mass of the first mode", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN   
      
   !------------------ TRD CONTROL PARAMETERS - MODE 2 -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: TRD CONTROL PARAMETERS - MODE 2', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   !------------------ TRD CONTROL PARAMETERS - A FILTER MATRIX -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: A matrix (4x4) for input signal filtering', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   DO I=1,4

      CALL ReadAry( UnIn, InputFile, TmpRAry, 4, 'Line'//TRIM(Num2LStr(I)), 'A matrix (4x4) for input signal filtering', &
                    ErrStat2, ErrMsg2, UnEc )
          CALL CheckError( ErrStat2, ErrMsg2 )
          IF ( ErrStat >= AbortErrLev ) RETURN  

      InputFileData%TRD_Afilter(I,1:4) = TmpRAry(1:4)

   END DO   
       
   !------------------ TRD CONTROL PARAMETERS - B FILTER VECTOR -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: B vector (4) for input signal filtering', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   CALL ReadAry( UnIn, InputFile, InputFileData%TRD_Bfilter, 4, 'Line 1', 'B vector (4) for input signal filtering', &
                ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN     
       
   !------------------ TRD CONTROL PARAMETERS - C FILTER VECTOR -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: C vector (4) for input signal filtering', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   CALL ReadAry( UnIn, InputFile, InputFileData%TRD_Cfilter, 4, 'Line 1', 'C vector (4) for input signal filtering', &
                ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN  
       
   !------------------ TRD CONTROL PARAMETERS - D FILTER PARAMETER -----------------------------
      
   CALL ReadCom( UnIn, InputFile, 'Section Header: D parameter for input signal filtering', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_Dfilter, "TRD_Dfilter", "D parameter for input signal filtering", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN   
      
   !------------------ TRD CONTROL PARAMETERS - A PID MATRIX -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: A matrix (4x4) for PID', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   DO I=1,2

      CALL ReadAry( UnIn, InputFile, TmpRAry, 2, 'Line'//TRIM(Num2LStr(I)), 'A matrix (4x4) for PID', &
                    ErrStat2, ErrMsg2, UnEc )
          CALL CheckError( ErrStat2, ErrMsg2 )
          IF ( ErrStat >= AbortErrLev ) RETURN  

      InputFileData%TRD_Apid(I,1:2) = TmpRAry(1:2)

   END DO   
       
   !------------------ TRD CONTROL PARAMETERS - B PID VECTOR -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: B vector (2) for PID', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   CALL ReadAry( UnIn, InputFile, InputFileData%TRD_Bpid, 2, 'Line 1', 'B vector (2) for PID', &
                ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN     
       
   !------------------ TRD CONTROL PARAMETERS - C PID VECTOR -----------------------------
   CALL ReadCom( UnIn, InputFile, 'Section Header: C vector (2) for PID', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 ) 
      
   CALL ReadAry( UnIn, InputFile, InputFileData%TRD_Cpid, 2, 'Line 1', 'C vector (2) for PID', &
                ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN  
       
   !------------------ TRD CONTROL PARAMETERS - D PID PARAMETER -----------------------------
      
   CALL ReadCom( UnIn, InputFile, 'Section Header: D parameter for PID', ErrStat2, ErrMsg2, UnEc )
      CALL CheckError( ErrStat2, ErrMsg2 )
      
   CALL ReadVar( UnIn, InputFile, InputFileData%TRD_Dpid, "TRD_Dpid", "D parameter for PID", ErrStat2, ErrMsg2, UnEc)
      CALL CheckError( ErrStat2, ErrMsg2 )
      IF ( ErrStat >= AbortErrLev ) RETURN    
      
      
      
      
   !!---------------------- OUTPUT --------------------------------------------------         
   !CALL ReadCom( UnIn, InputFile, 'Section Header: Output', ErrStat2, ErrMsg2, UnEc )
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF ( ErrStat >= AbortErrLev ) RETURN

   !   ! SumPrint - Print summary data to <RootName>.sum (flag):
   !CALL ReadVar( UnIn, InputFile, InputFileData%SumPrint, "SumPrint", "Print summary data to <RootName>.sum (flag)", ErrStat2, ErrMsg2, UnEc)
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF ( ErrStat >= AbortErrLev ) RETURN

   !!---------------------- OUTLIST  --------------------------------------------
   !   CALL ReadCom( UnIn, InputFile, 'Section Header: OutList', ErrStat2, ErrMsg2, UnEc )
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF ( ErrStat >= AbortErrLev ) RETURN

      ! OutList - List of user-requested output channels (-):
   !CALL ReadOutputList ( UnIn, InputFile, InputFileData%OutList, InputFileData%NumOuts, 'OutList', "List of user-requested output channels", ErrStat2, ErrMsg2, UnEc  )     ! Routine in NWTC Subroutine Library
   !   CALL CheckError( ErrStat2, ErrMsg2 )
   !   IF ( ErrStat >= AbortErrLev ) RETURN     
      
   !---------------------- END OF FILE -----------------------------------------
      
   CLOSE ( UnIn )
   RETURN


CONTAINS
   !...............................................................................................................................
   SUBROUTINE CheckError(ErrID,Msg)
   ! This subroutine sets the error message and level
   !...............................................................................................................................

         ! Passed arguments
      INTEGER(IntKi), INTENT(IN) :: ErrID       ! The error identifier (ErrStat)
      CHARACTER(*),   INTENT(IN) :: Msg         ! The error message (ErrMsg)


      !............................................................................................................................
      ! Set error status/message;
      !............................................................................................................................

      IF ( ErrID /= ErrID_None ) THEN

         IF (ErrStat /= ErrID_None) ErrMsg = TRIM(ErrMsg)//NewLine
         ErrMsg = TRIM(ErrMsg)//'ReadPrimaryFile:'//TRIM(Msg)
         ErrStat = MAX(ErrStat, ErrID)

         !.........................................................................................................................
         ! Clean up if we're going to return on error: close file, deallocate local arrays
         !.........................................................................................................................
         IF ( ErrStat >= AbortErrLev ) THEN
            CLOSE( UnIn )
!            IF ( UnEc > 0 ) CLOSE ( UnEc )
         END IF

      END IF


   END SUBROUTINE CheckError
   !...............................................................................................................................
END SUBROUTINE ReadPrimaryFile      
!-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE TRD_SetParameters( InputFileData, p, ErrStat, ErrMsg )
! This subroutine sets the parameters, based on the data stored in InputFileData
!..................................................................................................................................

   TYPE(TRD_InputFile),      INTENT(IN)       :: InputFileData  ! Data stored in the module's input file
   TYPE(TRD_ParameterType),  INTENT(INOUT)    :: p              ! The module's parameter data
   INTEGER(IntKi),           INTENT(OUT)      :: ErrStat        ! The error status code
   CHARACTER(*),             INTENT(OUT)      :: ErrMsg         ! The error message, if an error occurred

      ! Local variables
!   REAL(ReKi)                                 :: ComDenom       ! Common denominator of variables used in the TEC model
!   REAL(ReKi)                                 :: SIG_RtSp       ! Rated speed
!   REAL(ReKi)                                 :: TEC_K1         ! K1 term for Thevenin-equivalent circuit
!   REAL(ReKi)                                 :: TEC_K2         ! K2 term for Thevenin-equivalent circuit
   
!   INTEGER(IntKi)                             :: K              ! Loop counter (for blades)
!   INTEGER(IntKi)                             :: ErrStat2       ! Temporary error ID   
!   CHARACTER(ErrMsgLen)                       :: ErrMsg2        ! Temporary message describing error


   
      ! Initialize variables

   ErrStat = ErrID_None
   ErrMsg  = ''


   !p%DT = InputFileData%DT
   !p%RootName = 'TRD'
   ! DOFs 
   
   p%CMODE = InputFileData%TRD_CMODE
   
   p%K(:) = InputFileData%TRD_K(:)
   p%L(:) = InputFileData%TRD_L(:)
   p%M = InputFileData%TRD_M
   p%F0 = InputFileData%TRD_F0
   p%MC = InputFileData%TRD_MC
   p%RC = InputFileData%TRD_RC
   p%AON = InputFileData%TRD_AON
   p%AOFF = InputFileData%TRD_AOFF
   p%P(:) = InputFileData%TRD_P(:)
   p%PHI_DSP = InputFileData%TRD_PHI_DSP
   
   p%Afilter(:,:) = InputFileData%TRD_Afilter(:,:)
   p%Bfilter(:) = InputFileData%TRD_Bfilter(:)
   p%Cfilter(:) = InputFileData%TRD_Cfilter(:)
   p%Dfilter = InputFileData%TRD_Dfilter
   
   p%Apid(:,:) = InputFileData%TRD_Apid(:,:)
   p%Bpid(:) = InputFileData%TRD_Bpid(:)
   p%Cpid(:) = InputFileData%TRD_Cpid(:)
   p%Dpid = InputFileData%TRD_Dpid
    
CONTAINS
   !...............................................................................................................................
   SUBROUTINE CheckError(ErrID,Msg)
   ! This subroutine sets the error message and level
   !...............................................................................................................................

         ! Passed arguments
      INTEGER(IntKi), INTENT(IN) :: ErrID       ! The error identifier (ErrStat)
      CHARACTER(*),   INTENT(IN) :: Msg         ! The error message (ErrMsg)


      !............................................................................................................................
      ! Set error status/message;
      !............................................................................................................................

      IF ( ErrID /= ErrID_None ) THEN

         IF (ErrStat /= ErrID_None) ErrMsg = TRIM(ErrMsg)//NewLine
!         ErrMsg = TRIM(ErrMsg)//' '//TRIM(Msg)  !bjj: note that when you pass a literal string "", it somehow adds an extra space at the beginning.
         ErrMsg = TRIM(ErrMsg)//'TRD_SetParameters:'//TRIM(Msg)
         ErrStat = MAX(ErrStat, ErrID)
         
         !.........................................................................................................................
         ! Clean up if we're going to return on error: close files, deallocate local arrays
         !.........................................................................................................................
         IF ( ErrStat >= AbortErrLev ) THEN
         END IF

      END IF


   END SUBROUTINE CheckError

END SUBROUTINE TRD_SetParameters   
!-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END MODULE TRD
!**********************************************************************************************************************************

PROGRAM Modes


   ! THis program generates mode shapes for a flexible beam.  It is
   ! intended to be used for wind-turbine blades and towers.


USE                            GenMod
USE                            GenSubs
USE                            SysSubs

IMPLICIT                       NONE

REAL(Flt), ALLOCATABLE      :: CNORM   (:)               ! The factor to normalize the eigenvectors.
REAL(Flt), ALLOCATABLE      :: EIG     (:)               ! The eigenvalues from TMK.
REAL(Flt), PARAMETER        :: Grav    = 9.80665         ! The gravitational constant.
REAL(Flt)                   :: PHIIJ                     ! unknown.
REAL(Flt)                   :: PHPIJ                     ! unknown.
REAL(Flt)                   :: PHPPIJ                    ! unknown.
REAL(Flt)                   :: Omega2                    ! The square of the rotor speed in rad/sec.
REAL(Flt), ALLOCATABLE      :: PLOAD   (:)               ! unknown.
REAL(Flt), ALLOCATABLE      :: REIG    (:)               ! The adjusted frequency of the mode.
REAL(Flt)                   :: RL2                       ! The beam length squared.
REAL(Flt)                   :: RL4                       ! The beam length raised to the fourth power.
REAL(Flt), ALLOCATABLE      :: TCC     (:,:)             ! unknown.
REAL(Flt), ALLOCATABLE      :: TC      (:,:)             ! unknown.
REAL(Flt), ALLOCATABLE      :: TENS    (:)               ! unknown.
REAL(Flt), ALLOCATABLE      :: TK      (:,:)             ! The integrated stiffness matrix.
REAL(Flt), ALLOCATABLE      :: TKK     (:,:)             ! unknown.
REAL(Flt), ALLOCATABLE      :: TM      (:,:)             ! The integrated mass matrix.
REAL(Flt)                   :: TwoPi                     ! The constant pi time 2.
REAL(Flt), ALLOCATABLE      :: VEC     (:,:)             ! The eigenvectors from TMK.
REAL(Flt)                   :: ZFREE                     ! unknown.

INTEGER                     :: AllocStat                 ! The allocation status.
INTEGER                     :: I                         ! Index for mode number.
INTEGER                     :: II                        ! A temporary integer.
INTEGER                     :: INP1                      ! A temporary integer.
INTEGER                     :: INP2                      ! A temporary integer.
INTEGER                     :: INP3                      ! A temporary integer.
INTEGER                     :: IS                        ! The stiffness index.
INTEGER                     :: JNP1                      ! A temporary integer.
INTEGER                     :: JNP2                      ! A temporary integer.
INTEGER                     :: JNP3                      ! A temporary integer.
INTEGER                     :: J                         ! Index for mode number.
INTEGER                     :: K                         ! Index for station number.
INTEGER                     :: M                         ! Index for mode shape.

CHARACTER(200)              :: Line                      ! A string for output.


   ! Open the console for output.

CALL OpenCon


   ! Print out program name, version, and date.

CALL WrScr1 ( ' Running '//ProgName//TRIM( ProgVer )//'.' )


   ! Check for command line arguments.

CALL CheckArgs


   ! Open input file and optional hub-height files.

CALL GetFiles


   ! Get input parameters.

CALL GetInput


   ! Start Interpolation

FlexLen = TotLen - RigLen
DelLen  = FlexLen/NIPts

CALL Interp


   ! Deallocate the arrays of input station data.

IF ( ALLOCATED( LocIS    ) )  DEALLOCATE( LocIS    )
IF ( ALLOCATED( InpMass  ) )  DEALLOCATE( InpMass  )
IF ( ALLOCATED( InpStiff ) )  DEALLOCATE( InpStiff )
IF ( ALLOCATED( InpTwist ) )  DEALLOCATE( InpTwist )


   ! Allocate some arrays.

ALLOCATE ( TC(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TC array .' )
ENDIF


ALLOCATE ( TCC(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TCC array .' )
ENDIF


ALLOCATE ( TM(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TM array .' )
ENDIF


ALLOCATE ( TK(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TK array .' )
ENDIF


ALLOCATE ( TKK(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TKK array .' )
ENDIF


ALLOCATE ( TENS(0:NIpts) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the TENS array .' )
ENDIF


ALLOCATE ( PLOAD(0:NIpts) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the PLOAD array .' )
ENDIF


   ! Calculate some oft-used constants.

RL2    = FlexLen*FlexLen
RL4    = RL2*RL2
TwoPi  = 2.0*ACOS( -1.0 )
Omega2 = ( Omega*TwoPi/60.0 )**2


   ! Print out the input parameters.

WRITE (UO,'(A,F10.3)')  'Rigid beam length (m)    =', RigLen
WRITE (UO,'(A,F10.3)')  'Flexible beam length (m) =', FlexLen
WRITE (UO,'(A,F10.3)')  'Total beam length (m)    =', TotLen
WRITE (UO,'(A,F10.3)')  'End mass (kg)            =', EndMass
IF ( IsBlade )  THEN
   WRITE (UO,'(A,F10.3)')  'Rotor speed (rpm)        =', Omega
   WRITE (UO,'(A,F10.3)')  'Pitch angle (deg)        =', Pitch
ENDIF
WRITE (UO,'(A,F10.3)')  'Mass multiplier          =', MassFact
IF ( IsBlade )  THEN
   WRITE (UO,'(A,F10.3)')  'Flatwise stiffness mult. =', StiffFact(1)
   WRITE (UO,'(A,F10.3)')  'Edgewise stiffness mult. =', StiffFact(2)
ELSE
   WRITE (UO,'(A,F10.3)')  'Stiffness multiplier     =', StiffFact(1)
ENDIF


   ! Allocate memory to hold eigenvalues and eigenvectors.

ALLOCATE ( EIG(N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the EIG array .' )
ENDIF


ALLOCATE ( VEC(N,N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the VEC array .' )
ENDIF


ALLOCATE ( REIG(N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the REIG array .' )
ENDIF


ALLOCATE ( CNORM(N) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the CNORM array .' )
ENDIF


   ! Let's run this stuff once or twice.  Two times for blades.

DO IS=1,NumStiff


      ! Integrate polynomial functions based on mass and stiffness.

   DO I=1,N

      INP1 = I + NP - 1
      INP2 = I + NP - 2
      INP3 = I + NP - 3

      DO J=1,N

         JNP1 = J + NP - 1
         JNP2 = J + NP - 2
         JNP3 = J + NP - 3

         TC (I,J) = 0.0
         TCC(I,J) = 0.0
         TM (I,J) = 0.0
         TK (I,J) = 0.0

         TENS (NIPts) = EndMass*TotLen + 0.5*DelLen*BM(NIPts)*TotLen
         PLOAD(NIPts) = EndMass        + 0.5*DelLen*BM(NIPts)

         DO K=NIPts-1,0,-1

            ZFREE = 1.0

            IF ( K == 0 )  ZFREE = 0.5

            TENS (K) = TENS (K+1) + DelLen*ZFREE*BM(K)*( R(K)*FlexLen + RigLen )
            PLOAD(K) = PLOAD(K+1) + DelLen*ZFREE*BM(K)


         ENDDO ! K


            ! Add properties for each station to matrices.

         DO K=0,NIPts

            IF ( ( K == 0 ) .OR. ( K == NIPts ) )  THEN
               ZFREE = 0.5
            ELSE
               ZFREE = 1.0
            ENDIF

            PHIIJ  = R(K)**( INP1 + JNP1 )
            PHPIJ  = R(K)**( INP2 + JNP2 )*INP1*JNP1/RL2
            PHPPIJ = R(K)**( INP3 + JNP3 )*INP1*INP2*JNP1*JNP2/RL4

            TM (I,J) = TM (I,J) + DelLen*ZFREE*PHIIJ *BM(K)
            TC (I,J) = TC (I,J) + DelLen*ZFREE*PHPIJ *TENS(K)
            TCC(I,J) = TCC(I,J) + DelLen*ZFREE*PHPIJ *PLOAD(K)
            TK (I,J) = TK (I,J) + DelLen*ZFREE*PHPPIJ*BS(K,IS)

         ENDDO ! K

         TM (I,J) = TM(I,J) + EndMass
         TKK(I,J) = TK(I,J) - IBody*Grav*TCC(I,J) + ( 1 - IBody )*Omega2*TC(I,J)

      ENDDO ! J

   ENDDO ! I


      ! Find Eigenvalues and Eigenvectors

   CALL NROOT ( N, TM, TKK, EIG, VEC )


   DO I=1,N

      REIG(I)  = 1.0/( TwoPi*SQRT( ABS( EIG(I) ) ) )
      CNORM(I) = 0.0

      DO J=1,N
         CNORM(I) = CNORM(I) + VEC(J,I)
      ENDDO ! J

   ENDDO ! I


      ! Print out the results.

   IF ( IsBlade )  THEN

      IF ( IS == 1 )  THEN
         WRITE (Line,'("Out-of-plane mode shapes:")')
      ELSE
         WRITE (Line,'("In-plane mode shapes:")')
      ENDIF
      WRITE (UO,'(//,A)')  TRIM( Line )
      CALL WrScr1 ( TRIM( ' '//Line ) )

   ENDIF

   WRITE (Line,'(10X,9("     Shape",I2,:))')  ( I, I=1,N )
   WRITE (UO,'(/,A)')  TRIM( Line )
   CALL WrScr1 ( TRIM( Line ) )

   WRITE (Line,'(10X,9(5X,A,:))')  ( '-------', I=1,N )
   WRITE (UO,'(A)')  TRIM( Line )
   CALL WrScr ( TRIM( Line ) )

   WRITE (Line,'(" Freq (hz)",9(F12.4,:))')  ( REIG(J), J=1,N )
   WRITE (UO,'(A)')  TRIM( Line )
   WRITE (UO,'()')
   CALL WrScr ( TRIM( Line ) )
   CALL WrScr ( ' ' )

   DO M=NP,N+NP-1

      II = M - NP + 1
      WRITE (Line,'("    x^",I1,3X,9(F12.4,:))')  M, ( VEC(II,J)/CNORM(J), J=1,N )
      WRITE (UO,'(A)')  TRIM( Line )
      CALL WrScr ( TRIM( Line ) )

   ENDDO ! M

ENDDO ! IS


CALL WrScr1 ( ' Processing complete.' )
CALL WrScr  ( ' ' )
CALL EXIT ( 0 )
END PROGRAM Modes
!=======================================================================
SUBROUTINE CheckArgs


   ! This subroutine is used to check for command-line arguments.


USE                   GenMod
USE                   SysMod
USE                   SysSubs

IMPLICIT              NONE

INTEGER               IArg
INTEGER               Arg_Num

LOGICAL               Error

CHARACTER(99)         Arg



   ! Find out how many arguments were entered on the command line.

CALL Get_Arg_Num ( Arg_Num )


   ! Parse them.

IF ( Arg_Num > 0 )  THEN

   DO IArg=1,Arg_Num

      CALL Get_Arg ( IArg , Arg , Error )

      IF ( Error )  THEN
         CALL Abort ( )
      ENDIF

            ! If the argument is a command switch, assume it is "/h", and give help.
            ! Otherwise, assume it is a root file name.

      IF (Arg(1:1) ==  SwChar )  THEN
         CALL WrSyntax
      ELSE
         RootName = Arg
      ENDIF

   ENDDO

ENDIF


RETURN
END SUBROUTINE CheckArgs
!=======================================================================
SUBROUTINE GetFiles


  ! This subroutine is used to open the input and output files.


USE                GenMod
USE                GenSubs

IMPLICIT           NONE

INTEGER         :: I
INTEGER         :: Ind
INTEGER         :: IOS

LOGICAL         :: Error
LOGICAL         :: Exists

CHARACTER(200)  :: FormStr                 ! A format string.
CHARACTER(200)  :: InFile                  ! Input file name.
CHARACTER(200)  :: OutFile                 ! Output file name.



   ! Open input file.

InFile = TRIM( RootName )//'.inp'

INQUIRE ( FILE=InFile , EXIST=Exists )

IF ( Exists )  THEN
   OPEN( UI , FILE=InFile , STATUS='OLD' , FORM='FORMATTED' )
ELSE
   CALL Abort ( 'Error.  The input file, "'//TRIM( RootName )//'.inp", was not found.' )
ENDIF


   ! Open output file.

OutFile = TRIM( RootName )//'.mod'

OPEN( UO , FILE=TRIM( OutFile ) , STATUS='UNKNOWN' , FORM='FORMATTED', IOSTAT=IOS )

IF ( IOS /= 0 )  THEN
   CALL Abort ( 'Error.  The output file, "'//TRIM( OutFile )//'", could not be opened.' )
ENDIF


   ! Write the program name and version, date and time into the summary file.

FormStr = "( 'This mode-shape file was generated by ' , A , A , ' on ' , A , ' at ' , A , '.' )"
WRITE (UO,FormStr)  ProgName, TRIM( ProgVer ), CurDate(), CurTime()
FormStr = '( ''Results are based upon data input from "'', A, ''".'' , / )'
WRITE (UO,FormStr)  TRIM( InFile )


RETURN
END SUBROUTINE GetFiles
!=======================================================================
SUBROUTINE GetInput


   ! This program reads the input file.


USE              GenMod
USE              GenSubs

IMPLICIT          NONE

INTEGER        :: AllocStat                           ! The allocation status.
INTEGER        :: IC                                  ! The column index.
INTEGER        :: IOS                                 ! The I/O status.
INTEGER        :: Stat                                ! The station index.



   ! Read in the blade/tower indicator, 1 = blade, 2 = tower.

READ(UI,*,IOSTAT=IOS)  IsBlade

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the blade/tower indicator.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the blade/tower indicator from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( IsBlade )  THEN
   IBody    = 0
   NumCols  = 3
   NumStiff = 2
ELSE
   IBody    = 1
   NumCols  = 2
   NumStiff = 1
ENDIF


   ! Read in the rotor angular speed, rpm.

READ(UI,*,IOSTAT=IOS)  Omega

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the rotor speed.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the rotor speed from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF


   ! Read in the pitch angle for blades, degrees.

READ(UI,*,IOSTAT=IOS)  Pitch

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the pitch angle.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the pitch angle from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( .NOT. IsBlade )  Pitch = 0.0


   ! Read in the total (rigid plus flex) beam length.

READ(UI,*,IOSTAT=IOS)  TotLen

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the total beam length.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the total beam length from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( TotLen <= 0.0 )  THEN
   Call Abort ( 'The total beam length must > 0.' )
ENDIF


   ! Read in the length of the rigid part of the beam.

READ(UI,*,IOSTAT=IOS)  RigLen

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the length of the rigid part of the beam.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the length of the rigid part of the beam from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( RigLen < 0.0 )  THEN
   Call Abort ( 'The length of the rigid part of the beam must >= 0.' )
ENDIF


   ! Read in the beam end mass.

READ(UI,*,IOSTAT=IOS)  EndMass

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the beam end mass.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the beam end mass from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( EndMass < 0.0 )  THEN
   Call Abort ( 'The beam end mass must >= 0.' )
ENDIF


   ! Read in the number of mode shapes.

READ(UI,*,IOSTAT=IOS)  N

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the number of mode shapes.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the number of mode shapes from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF


   ! Read in the order of the first polynomial coefficient.

READ(UI,*,IOSTAT=IOS)  NP

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the order of the first polynomial coefficient.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the order of the first polynomial coefficient from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF


   ! Read in the number of input stations.

READ(UI,*,IOSTAT=IOS)  NumInSt

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the number of input stations.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the number of input stations from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( NumInSt < 1 )  THEN
   Call Abort ( 'The number of input stations must >= 1' )
ENDIF


   ! Read in the factor to adjust beam mass.

READ(UI,*,IOSTAT=IOS)  MassFact

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the mass factor.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the mass factor from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( MassFact <= 0.0 )  THEN
   Call Abort ( 'The mass factor must be > 0.0' )
ENDIF


   ! Read in the factor to adjust out-of-plane or tower stiffness to give correct natural frequency.

READ(UI,*,IOSTAT=IOS)  StiffFact(1)

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the out-of-plane or tower stiffness factor.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the out-of-plane or tower stiffness factor from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( StiffFact(1) <= 0.0 )  THEN
   Call Abort ( 'The out-of-plane or tower stiffness factor must be > 0.0' )
ENDIF


   ! Read in the factor to adjust in-plane stiffness to give correct natural frequency.  Ignored for twoers.

READ(UI,*,IOSTAT=IOS)  StiffFact(2)

IF ( IOS < 0 )  THEN
   CALL PremEOF ( TRIM( RootName )//'.inp' , ' The error occurred while trying to read the in-plane stiffness factor.' )
ELSEIF ( IOS > 0 )  THEN
   Call Abort ( ProgName//' could not read the in-plane stiffness factor from the input file, "'//TRIM( RootName )//'.inp".' )
ENDIF

IF ( ( StiffFact(2) <= 0.0 ) .AND. ( IsBlade ) )  THEN
   Call Abort ( 'The in-plane stiffness factor must be > 0.0' )
ENDIF


   ! Allocate arrays for station data.

ALLOCATE ( LocIS(0:NumInSt-1) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the array for locations of the input stations.' )
ENDIF


ALLOCATE ( InpMass(0:NumInSt-1) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the array for input mass.' )
ENDIF


ALLOCATE ( InpStiff(NumStiff,0:NumInSt-1) , STAT=AllocStat )
IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the array for input stiffness.' )
ENDIF


ALLOCATE ( InpTwist(0:NumInSt-1) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the array for input twist.' )
ENDIF


   ! Read station data (fractional distance from hub center or ground, mass lineal density, and stiffness).

DO Stat=0,NumInSt-1

   IF ( IsBlade )  THEN
      READ(UI,*)  LocIS(Stat), InpTwist(Stat), InpMass(Stat), InpStiff(1,Stat), InpStiff(2,Stat)
   ELSE
      READ(UI,*)  LocIS(Stat), InpMass(Stat), InpStiff(1,Stat)
   ENDIF


      ! Adjust stiffness for towers and mass for towers and blades.
      ! We will adjust blade stiffness after we remove twist effects.

   IF ( .NOT. IsBlade )  THEN
      InpStiff(1,Stat) = InpStiff(1,Stat)*StiffFact(1)
   ENDIF

   InpMass(Stat) = InpMass(Stat)*MassFact

ENDDO ! Stat

IF ( ( LocIS(0) /= 0.0 ) .OR. ( LocIS(NumInSt-1) /= 1.0 ) )  THEN
   CALL Abort ( 'Station location data must go from 0 to 1.' )
ENDIF


CLOSE ( UI )


RETURN
END SUBROUTINE GetInput
!=======================================================================
SUBROUTINE Interp


   ! This subroutine performs a linear interpolation of the input
   ! blade data.  Before it interpolates, the routine transforms the
   ! flatwise and edgewise stiffnesses to out-of-plane and in-plane
   ! stiffnesses if we are working on a blade.


USE                       GenMod
USE                       GenSubs
USE                       SysSubs

IMPLICIT                  NONE

REAL(Flt)              :: Cos2Pit         ! The cosine of twice the pitch angle.
REAL(Flt)              :: Cos2Twist       ! The cosine of twice the local twist angle.
REAL(Flt)              :: Deg2Rad         ! The constant to convert from degrees to radians.
REAL(Flt)              :: EdgeStiff       ! The edgewise stiffnesses.
REAL(Flt)              :: FlatStiff       ! The flatwise stiffnesses.
REAL(Flt), ALLOCATABLE :: Ixy       (:)   ! The cross stiffnesses after transforming to the zero-pitch orientation.
REAL(Flt), ALLOCATABLE :: LocPit    (:)   ! The flatwise stiffnesses.
REAL(Flt)              :: Ratio           ! The factional distant between input stations.
REAL(Flt)              :: Sin2Pit         ! The sine of twice the pitch angle.
REAL(Flt)              :: Sin2Twist       ! The sine of twice the local twist angle.
REAL(Flt)              :: ZPEStiff        ! The zero-pitch flatwise stiffnesses.
REAL(Flt)              :: ZPFStiff        ! The zero-pitch edgewise stiffnesses.
REAL(Flt)              :: ZPPStiff        ! The zero-pitch cross stiffnesses.

INTEGER                :: AllocStat       ! The allocation status.
INTEGER                :: Ind             ! The counter for current element of the input locations matrix.
INTEGER                :: IS              ! The stiffness index.
INTEGER                :: J               ! The counter for beam element.




   ! If this is a blade we're analyzing, we need to transform the stiffness into the OoP/IP axes.

IF ( IsBlade )  THEN


      ! For the transforms below, calculate the sine and cosine of the pitch andgle.

   Deg2Rad = ACOS( -1.0 )/180.0
   Cos2Pit = COS( 2.0*Pitch*Deg2Rad )
   Sin2Pit = SIN( 2.0*Pitch*Deg2Rad )

   DO Ind=0,NumInSt-1


         ! Transform the stiffnesses to the zero-pitch orientation for the input locations.
         ! Apply stiffness adjustment factors after the transform.

      Cos2Twist = COS( 2.0*InpTwist(Ind)*Deg2Rad )
      Sin2Twist = SIN( 2.0*InpTwist(Ind)*Deg2Rad )

      FlatStiff = InpStiff(1,Ind)  ! We haven't accounted for the stiffness factors yet.
      EdgeStiff = InpStiff(2,Ind)

      ZPFStiff = 0.5*StiffFact(1)*( FlatStiff + EdgeStiff + ( FlatStiff - EdgeStiff )*Cos2Twist )
      ZPEStiff = 0.5*StiffFact(2)*( FlatStiff + EdgeStiff - ( FlatStiff - EdgeStiff )*Cos2Twist )


         ! To calculate the zero-pitch EIxy stiffness, transform the adjusted stiffnesses back into the principal axes.

      FlatStiff = 0.5*( ZPFStiff + ZPEStiff + ( ZPFStiff - ZPEStiff )/Cos2Twist )
      EdgeStiff = 0.5*( ZPFStiff + ZPEStiff - ( ZPFStiff - ZPEStiff )/Cos2Twist )

      ZPPStiff  = 0.5*( FlatStiff - EdgeStiff )*Sin2Twist


         ! Now transform to the pitched axes and store results in the original array.

      InpStiff(1,Ind) = 0.5*( ZPFStiff + ZPEStiff + ( ZPFStiff - ZPEStiff )*Cos2Pit ) - ZPPStiff*Sin2Pit
      InpStiff(2,Ind) = 0.5*( ZPFStiff + ZPEStiff - ( ZPFStiff - ZPEStiff )*Cos2Pit ) + ZPPStiff*Sin2Pit

   ENDDO ! Ind

ENDIF


   ! Allocate the interpolated mass and stiffness arrays.

ALLOCATE ( BM(0:NIPts) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the BM array .' )
ENDIF


ALLOCATE ( BS(0:NIPts,NumStiff) , STAT=AllocStat )

IF ( AllocStat /= 0 )  THEN
   CALL Abort ( 'Error allocating memory for the BS array .' )
ENDIF


   ! Interpolate.

Ind = 0

DO J=0,NIPts-1


      ! First compute blade radius fraction for Jth point to be
      ! interpolated.

   R(J) = J*DelLen/FlexLen


      ! Keep increasing Ind until we surround R(J).

   DO

      IF ( R(J) <= LocIS(Ind+1) )  EXIT

      Ind = Ind + 1

   ENDDO


      ! Interpolate.

   Ratio = ( R(J) - LocIS(Ind) )/( LocIS(Ind+1) - LocIS(Ind) )

   BM(J) = Ratio*( InpMass (Ind+1) - InpMass (Ind) ) + InpMass (Ind)

   DO IS=1,NumStiff
      BS(J,IS) = Ratio*( InpStiff(IS,Ind+1) - InpStiff(IS,Ind) ) + InpStiff(IS,Ind)
   ENDDO ! IC

ENDDO ! J

BM(NIPts) = InpMass(NumInSt-1)

DO IS=1,NumStiff
   BS(NIPts,IS) = InpStiff(IS,NumInSt-1)
ENDDO ! IC


RETURN
END SUBROUTINE Interp
!=======================================================================
SUBROUTINE WrSyntax


   !  This routine writes out the syntax for executing the program, then
   !  exits.


USE             GenMod
USE             GenSubs
USE             SysMod
USE             SysSubs

IMPLICIT        NONE




CALL WrScr1 ( ' Syntax is:' )
CALL WrScr1 ( '    '//ProgName//' ['//SwChar//'h] [<infile>]'  )
CALL WrScr1 ( ' where:' )
CALL WrScr1 ( '    '//SwChar//'h       generates this help message.' )
CALL WrScr  ( '    <infile> is the root name of the I/O files.' )
CALL WrScr  ( ' ' )

CALL EXIT ( 1 )


END SUBROUTINE WrSyntax


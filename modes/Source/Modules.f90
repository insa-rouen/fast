MODULE GenMod


INTEGER, PARAMETER         :: NIPts    = 100                         ! The number of interpolated points minus 1.
INTEGER, PARAMETER         :: Flt      = KIND( 0.0_4 )               ! The kind of single-precision floating-point numbers.
INTEGER, PARAMETER         :: UI       = 1                           ! The I/O unit for input.
INTEGER, PARAMETER         :: UO       = 2                           ! The I/O unit for output.

REAL(Flt)                  :: AdjFact  (3)                           ! The adjustment factors for mass and stiffness.
REAL(Flt), ALLOCATABLE     :: BM       (:)                           ! The interpolated beam element lineal density in kg/m.
REAL(Flt), ALLOCATABLE     :: BS       (:,:)                         ! The interpolated beam element stiffnesses (EI) in N-m^2.
REAL(Flt)                  :: DelLen                                 ! The delta length between interpolated stations.
REAL(Flt)                  :: EndMass                                ! The lump mass at the end of the beam.
REAL(Flt)                  :: FlexLen                                ! The length of the flexible part of the beam.
REAL(Flt), ALLOCATABLE     :: InpMass  (:)                           ! The input twist for blades.
REAL(Flt), ALLOCATABLE     :: InpStiff (:,:)                         ! The input stiffness.
REAL(Flt), ALLOCATABLE     :: InpTwist (:)                           ! The input mass.
REAL(Flt), ALLOCATABLE     :: LocIS    (:)                           ! The locations of the input stations.
REAL(Flt)                  :: MassFact                               ! The adjustment factors for mass.
REAL(Flt)                  :: Omega                                  ! The rotor speed.
REAL(Flt), ALLOCATABLE     :: OutStiff (:,:)                         ! The output stiffness.
REAL(Flt)                  :: Pitch                                  ! The pitch angle of the blade.
REAL(Flt)                  :: R        (0:NIPts)                     ! The interpolated locations (fractional over flexible part).
REAL(Flt)                  :: RigLen                                 ! The length of the rigid part of the beam.
REAL(Flt)                  :: StiffFact(2)                           ! The adjustment factors stiffness.
REAL(Flt)                  :: TotLen                                 ! The total length of the beam.

INTEGER                    :: IBody                                  ! The blade/tower indicator.
INTEGER                    :: N                                      ! The number of modes to compute.
INTEGER                    :: NP                                     ! The order of the first polynomial coefficient.
INTEGER                    :: NumCols                                ! The number of mass and stiffness distributions.
INTEGER                    :: NumInSt                                ! The number of input stations.
INTEGER                    :: NumStiff                               ! The number of stiffness distributions.

LOGICAL                    :: IsBlade                                ! Flag to indicate that the beam is a blade.

CHARACTER(197)             :: RootName = 'modes'                     ! Root name of the I/O files.
CHARACTER(  5), PARAMETER  :: ProgName = 'modes'                     ! The name of this program.
CHARACTER( 25), PARAMETER  :: ProgVer  = ' v2.22 (29-Apr-2002)'      ! The version info for this program.


END MODULE GenMod
!**********************************************************************************************************************************
! LICENSING
! Copyright (C) 2015-2016  National Renewable Energy Laboratory
!
! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.
!**********************************************************************************************************************************
MODULE BeamDyn

   USE BeamDyn_IO
   USE BeamDyn_Subs
   USE NWTC_LAPACK

   IMPLICIT NONE

   PRIVATE

   ! ..... Public Subroutines....................................................................

   PUBLIC :: BD_Init                           ! Initialization routine
   PUBLIC :: BD_End                            ! Ending routine (includes clean up)
   PUBLIC :: BD_UpdateStates                   ! Loose coupling routine for solving for constraint states, integrating
   PUBLIC :: BD_CalcOutput                     ! Routine for computing outputs
   PUBLIC :: BD_CalcConstrStateResidual        ! Tight coupling routine for returning the constraint state residual
   PUBLIC :: BD_UpdateDiscState                ! Tight coupling routine for updating discrete states
   

CONTAINS

!-----------------------------------------------------------------------------------------------------------------------------------
!> This routine is called at the start of the simulation to perform initialization steps.
!! The parameters are set here and not changed during the simulation.
!! The initial states and initial guess for the input are defined.
SUBROUTINE BD_Init( InitInp, u, p, x, xd, z, OtherState, y, MiscVar, Interval, InitOut, ErrStat, ErrMsg )

   TYPE(BD_InitInputType),            INTENT(IN   )  :: InitInp     !< Input data for initialization routine
   TYPE(BD_InputType),                INTENT(  OUT)  :: u           !< An initial guess for the input; input mesh must be defined
   TYPE(BD_ParameterType),            INTENT(  OUT)  :: p           !< Parameters
   TYPE(BD_ContinuousStateType),      INTENT(  OUT)  :: x           !< Initial continuous states
   TYPE(BD_DiscreteStateType),        INTENT(  OUT)  :: xd          !< Initial discrete states
   TYPE(BD_ConstraintStateType),      INTENT(  OUT)  :: z           !< Initial guess of the constraint states
   TYPE(BD_OtherStateType),           INTENT(  OUT)  :: OtherState  !< Initial other states
   TYPE(BD_OutputType),               INTENT(  OUT)  :: y           !< Initial system outputs (outputs are not calculated;
                                                                    !!    only the output mesh is initialized)
   TYPE(BD_MiscVarType),              INTENT(  OUT)  :: MiscVar     !<  Misc variables for optimization (not copied in glue code)
   REAL(DbKi),                        INTENT(INOUT)  :: Interval    !< Coupling interval in seconds: the rate that
                                                                    !!   (1) Mod1_UpdateStates() is called in loose coupling &
                                                                    !!   (2) Mod1_UpdateDiscState() is called in tight coupling.  !   Input is the suggested time from the glue code;
                                                                    !!   Output is the actual coupling interval that will be used
                                                                    !!   by the glue code.
   TYPE(BD_InitOutputType),           INTENT(  OUT)  :: InitOut     !< Output for initialization routine
   INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   ! local variables
   TYPE(BD_InputFile)      :: InputFileData    ! Data stored in the module's input file
   INTEGER(IntKi)          :: i                ! do-loop counter
   INTEGER(IntKi)          :: j                ! do-loop counter
   INTEGER(IntKi)          :: k                ! do-loop counter
   INTEGER(IntKi)          :: m                ! do-loop counter
   INTEGER(IntKi)          :: id0
   INTEGER(IntKi)          :: id1
   INTEGER(IntKi)          :: temp_int
   INTEGER(IntKi)          :: temp_id
   INTEGER(IntKi)          :: temp_id2
   REAL(BDKi)              :: temp_Coef(4,4)
   REAL(BDKi)              :: temp66(6,6)
   REAL(BDKi)              :: temp_twist
   REAL(BDKi)              :: eta
   REAL(BDKi)              :: temp_POS(3)
   REAL(BDKi)              :: temp_e1(3)
   REAL(BDKi)              :: temp_CRV(3)
   REAL(BDKi),PARAMETER    :: EPS = 1.0D-10
   REAL(BDKi),ALLOCATABLE  :: GLL(:)
   REAL(BDKi),ALLOCATABLE  :: temp_GL(:)
   REAL(BDKi),ALLOCATABLE  :: temp_w(:)
   REAL(BDKi),ALLOCATABLE  :: temp_ratio(:,:)
   REAL(BDKi),ALLOCATABLE  :: SP_Coef(:,:,:)
   REAL(BDKi)              :: TmpDCM(3,3)
   REAL(BDKi)              :: denom

   INTEGER(IntKi)          :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)    :: ErrMsg2                      ! Temporary Error message
   character(*), parameter :: RoutineName = 'BD_Init'
   
   
  ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""

   ! Initialize the NWTC Subroutine Library

   CALL NWTC_Init( )

   ! Display the module information

   CALL DispNVD( BeamDyn_Ver )
      
   CALL BD_ReadInput(InitInp%InputFile,InputFileData,InitInp%RootName,Interval,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
   CALL BD_ValidateInputData( InputFileData, ErrStat2, ErrMsg2 )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      ! this routine sets *some* of the parameters (basically the "easy" ones)
  call setParameters(InitInp, InputFileData, p, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      
   ! Compute coefficients for cubic spline fit, clamped at two ends
   CALL AllocAry(SP_Coef,InputFileData%kp_total-1,4,4,'Spline coefficient matrix',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if   
      
   SP_Coef(:,:,:) = 0.0_BDKi
   temp_id = 1
   temp_id2 = 0
   DO i=1,InputFileData%member_total
       temp_id2= temp_id + InputFileData%kp_member(i) - 1
       CALL BD_ComputeIniCoef(InputFileData%kp_member(i),InputFileData%kp_coordinate(temp_id:temp_id2,1:4),&
                              SP_Coef(temp_id:temp_id2-1,1:4,1:4), ErrStat2, ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       temp_id = temp_id2
   ENDDO
   ! Compute blade/member/segment lengths and the ratios between member/segment and blade lengths
   
   p%member_length(:,:) = 0.0_BDKi
   p%segment_length(:,:) = 0.0_BDKi
   CALL BD_ComputeMemberLength(InputFileData%member_total,InputFileData%kp_member,&
                               InputFileData%kp_coordinate,SP_Coef,&
                               p%segment_length,p%member_length,p%blade_length,&
                               ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
   
   ! Temporary GLL point intrinsic coordinates array
   CALL AllocAry(GLL,p%node_elem,'GLL points array',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ! Temporary GLL weight function array
   CALL AllocAry(temp_w,p%node_elem,'GLL weight array',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
   p%uuN0(:,:) = 0.0_BDKi
   GLL(:) = 0.0_BDKi
   temp_w(:) = 0.0_BDKi
   CALL BD_GenerateGLL(p%node_elem-1,GLL,temp_w,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
   DEALLOCATE(temp_w)
   if (ErrStat >= AbortErrLev) then
      call cleanup()
      return
   end if
   p%GL(:) = 0.0_BDKi
   p%GLw(:) = 0.0_BDKi
   IF(p%quadrature .EQ. 1) THEN
       ! p%Gauss: the DistrLoad mesh node location
       ! p%Gauss: physical coordinates of Gauss points and two end points
       CALL AllocAry(p%Gauss,6,p%ngp*p%elem_total+2,'p%Gauss',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
             call cleanup()
             return
          end if

       p%Gauss(:,:) = 0.0_BDKi
       CALL BD_GaussPointWeight(p%ngp,p%GL,p%GLw,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
             call cleanup()
             return
          end if
   ELSEIF(p%quadrature .EQ. 2) THEN
       CALL AllocAry(p%Gauss,6,p%ngp,'p%Trapezoidal',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ! Temporary Gauss point intrinsic coordinates array
       p%Gauss(:,:) = 0.0_BDKi

       id0 = 1
       p%GL(1) = InputFileData%InpBl%station_eta(id0)
       DO j = 2,p%ngp
            p%GL(j) = InputFileData%InpBl%station_eta(id0+(j-2)/p%refine) + &
                    ((InputFileData%InpBl%station_eta(id0+(j-2)/p%refine + 1) - &
                      InputFileData%InpBl%station_eta(id0+(j-2)/p%refine))/p%refine) * &
                  (MOD(j-2,p%refine) + 1)
       ENDDO
   ENDIF

     ! initialize for first step (i=1)
   temp_id = 0
   id0 = 1
   DO i=1,p%elem_total
       id1 = id0 + InputFileData%kp_member(i) - 1
       DO j=1,p%node_elem
           eta = (GLL(j) + 1.0_BDKi)/2.0_BDKi
           DO k=1,InputFileData%kp_member(i)-1
               temp_id2 = temp_id + k
               IF(eta - p%segment_length(temp_id2,3) <= EPS) THEN !bjj: would it be better to use equalRealNos and compare with 0? 1D-10 stored in single precision scares me as a limit
                   DO m=1,4
                       temp_Coef(m,1:4) = SP_Coef(temp_id2,1:4,m)
                   ENDDO
                   eta = InputFileData%kp_coordinate(id0,1) + &
                         eta * (InputFileData%kp_coordinate(id1,1) - InputFileData%kp_coordinate(id0,1))
                   ! Compute GLL point physical coordinates in blade frame
                   CALL BD_ComputeIniNodalPosition(temp_Coef,eta,temp_POS,temp_e1,temp_twist,&
                                                   ErrStat2, ErrMsg2)
                      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                   ! Compute initial rotation parameters at GLL points in blade frame
                   CALL BD_ComputeIniNodalCrv(temp_e1,temp_twist,temp_CRV,ErrStat2,ErrMsg2)
                      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                   temp_id2 = (j-1)*p%dof_node
                   p%uuN0(temp_id2+1:temp_id2+3,i) = temp_POS(1:3)
                   p%uuN0(temp_id2+4:temp_id2+6,i) = temp_CRV(1:3)
                   EXIT
               ENDIF
           ENDDO
       ENDDO
       IF(p%quadrature .EQ. 1) THEN
           DO j=1,p%ngp
               eta = (p%GL(j) + 1.0_BDKi)/2.0_BDKi
               DO k=1,InputFileData%kp_member(i)-1
                   temp_id2 = temp_id + k
                   IF(eta - p%segment_length(temp_id2,3) <= EPS) THEN
                       DO m=1,4
                           temp_Coef(m,1:4) = SP_Coef(temp_id2,1:4,m)
                       ENDDO
                       eta = InputFileData%kp_coordinate(id0,1) + &
                             eta * (InputFileData%kp_coordinate(id1,1) - InputFileData%kp_coordinate(id0,1))
                       CALL BD_ComputeIniNodalPosition(temp_Coef,eta,temp_POS,temp_e1,temp_twist,&
                                                       ErrStat2, ErrMsg2)
                          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                       CALL BD_ComputeIniNodalCrv(temp_e1,temp_twist,temp_CRV,ErrStat2,ErrMsg2)
                          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                       temp_id2 = (i-1)*p%ngp+j+1
                       p%Gauss(1:3,temp_id2) = temp_POS(1:3)
                       p%Gauss(4:6,temp_id2) = temp_CRV(1:3)
                       EXIT
                   ENDIF
               ENDDO
           ENDDO
       ELSEIF(p%quadrature .EQ. 2) THEN
           DO j = 1,p%ngp
               IF( j .EQ. 1) THEN
                   DO m=1,4
                       temp_Coef(m,1:4) = SP_Coef(1,1:4,m)
                   ENDDO
                   eta = InputFileData%kp_coordinate(id0,1)
               ELSE
                   DO m=1,4
                       temp_Coef(m,1:4) = SP_Coef( (j-2)/p%refine + 1,1:4,m)
                   ENDDO
                   eta = InputFileData%kp_coordinate(id0+(j-2)/p%refine,1) + &
                         ((InputFileData%kp_coordinate(id0+(j-2)/p%refine + 1,1) - &
                           InputFileData%kp_coordinate(id0+(j-2)/p%refine,1))/p%refine) * &
                         (MOD(j-2,p%refine) + 1)
               ENDIF
               CALL BD_ComputeIniNodalPosition(temp_Coef,eta,temp_POS,temp_e1,temp_twist,&
                                               ErrStat2, ErrMsg2)
                  CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
               CALL BD_ComputeIniNodalCrv(temp_e1,temp_twist,temp_CRV,ErrStat2,ErrMsg2)
                  CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
               p%Gauss(1:3,j) = temp_POS(1:3)  
               p%Gauss(4:6,j) = temp_CRV(1:3)
           ENDDO
       ENDIF

         ! set for next time:
      temp_id = temp_id + InputFileData%kp_member(i) - 1
      id0 = id1           
       
   ENDDO
   IF(p%quadrature .EQ. 1) THEN
       p%Gauss(1:3,1) = p%uuN0(1:3,1)
       p%Gauss(4:6,1) = p%uuN0(4:6,1)
       
       temp_int = p%node_elem * p%dof_node
       p%Gauss(1:3,p%ngp*p%elem_total+2) = p%uuN0(temp_int-5:temp_int-3,p%elem_total)
       p%Gauss(4:6,p%ngp*p%elem_total+2) = p%uuN0(temp_int-2:temp_int,p%elem_total)
   ENDIF
   DEALLOCATE(SP_Coef)

   IF(p%quadrature .EQ. 1) THEN
       ! Compute sectional propertities ( 6 by 6 stiffness and mass matrices)
       ! at Gauss points
       CALL AllocAry(temp_ratio,p%ngp,p%elem_total,'temp_ratio',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL AllocAry(temp_GL,p%ngp,'temp_GL',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
             call cleanup()
             return
          end if
       DO i=1,p%ngp
           temp_GL(i) = (p%GL(i) + 1.0_BDKi)/2.0_BDKi
       ENDDO

      temp_ratio(:,:) = 0.0_BDKi
      DO j=1,p%ngp
         temp_ratio(j,1) = temp_GL(j)*p%member_length(1,2)
      ENDDO
      DO i=2,p%elem_total
         DO j=1,i-1
               temp_ratio(:,i) = temp_ratio(:,i) + p%member_length(j,2)
         ENDDO
         DO j=1,p%ngp
               temp_ratio(j,i) = temp_ratio(j,i) + temp_GL(j)*p%member_length(i,2)
         ENDDO
      ENDDO

       CALL AllocAry(p%Stif0_GL,6,6,p%ngp*p%elem_total,'Stif0_GL',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL AllocAry(p%Mass0_GL,6,6,p%ngp*p%elem_total,'Mass0_GL',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
             call cleanup()
             return
          end if
       p%Stif0_GL(:,:,:) = 0.0_BDKi
       p%Mass0_GL(:,:,:) = 0.0_BDKi
       DO i=1,p%elem_total
           DO j=1,p%ngp
               temp_id = (i-1)*p%ngp+j
               DO k=1,InputFileData%InpBl%station_total
                   IF(temp_ratio(j,i) - InputFileData%InpBl%station_eta(k) <= EPS) THEN
                       IF(ABS(temp_ratio(j,i) - InputFileData%InpBl%station_eta(k)) <= EPS) THEN
                           p%Stif0_GL(1:6,1:6,temp_id) = InputFileData%InpBl%stiff0(1:6,1:6,k)
                           p%Mass0_GL(1:6,1:6,temp_id) = InputFileData%InpBl%mass0(1:6,1:6,k)
                       ELSE
                           temp66(:,:) = 0.0_BDKi
                           temp66(1:6,1:6) = (InputFileData%InpBl%stiff0(1:6,1:6,k)-InputFileData%InpBl%stiff0(1:6,1:6,k-1)) / &
                                             (InputFileData%InpBl%station_eta(k) - InputFileData%InpBl%station_eta(k-1))
                           p%Stif0_GL(1:6,1:6,temp_id) = temp66(1:6,1:6) * temp_ratio(j,i) + &
                                                         InputFileData%InpBl%stiff0(1:6,1:6,k-1) - &
                                                         temp66(1:6,1:6) * InputFileData%InpBl%station_eta(k-1)
                           temp66(:,:) = 0.0_BDKi
                           temp66(1:6,1:6) = (InputFileData%InpBl%mass0(1:6,1:6,k)-InputFileData%InpBl%mass0(1:6,1:6,k-1)) / &
                                             (InputFileData%InpBl%station_eta(k) - InputFileData%InpBl%station_eta(k-1))
                           p%Mass0_GL(1:6,1:6,temp_id) = temp66(1:6,1:6) * temp_ratio(j,i) + &
                                                         InputFileData%InpBl%mass0(1:6,1:6,k-1) - &
                                                         temp66(1:6,1:6) * InputFileData%InpBl%station_eta(k-1)
                       ENDIF
                       EXIT
                   ENDIF
               ENDDO
           ENDDO
       ENDDO
       DEALLOCATE(temp_GL)
       DEALLOCATE(temp_ratio)
   ELSEIF(p%quadrature .EQ. 2) THEN
       CALL AllocAry(p%Stif0_GL,6,6,p%ngp,'Stif0_TZ',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL AllocAry(p%Mass0_GL,6,6,p%ngp,'Mass0_TZ',ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
             call cleanup()
             return
          end if
       p%Stif0_GL(:,:,:) = 0.0_BDKi
       p%Mass0_GL(:,:,:) = 0.0_BDKi

       temp_id = 0
       id0 = 1
       id1 = InputFileData%kp_member(1)
           
       DO j = 1,p%ngp
           IF( j .EQ. 1) THEN
               p%Stif0_GL(1:6,1:6,temp_id*p%refine + j) = InputFileData%InpBl%stiff0(1:6,1:6,temp_id*p%refine + j)
               p%Mass0_GL(1:6,1:6,temp_id*p%refine + j) = InputFileData%InpBl%mass0(1:6,1:6,temp_id*p%refine + j)
           ELSE
               p%Stif0_GL(1:6,1:6,temp_id*p%refine + j) = InputFileData%InpBl%stiff0(1:6,1:6,id0+(j-2)/p%refine) + &
                   ((InputFileData%InpBl%stiff0(1:6,1:6,id0+(j-2)/p%refine + 1) - &
                    InputFileData%InpBl%stiff0(1:6,1:6,id0+(j-2)/p%refine))/p%refine) * &
                   (MOD(j-2,p%refine) + 1)
                   
               p%Mass0_GL(1:6,1:6,temp_id*p%refine + j) = InputFileData%InpBl%mass0(1:6,1:6,id0+(j-2)/p%refine) + &
                   ((InputFileData%InpBl%mass0(1:6,1:6,id0+(j-2)/p%refine + 1) - &
                    InputFileData%InpBl%mass0(1:6,1:6,id0+(j-2)/p%refine))/p%refine) * &
                   (MOD(j-2,p%refine) + 1)
           ENDIF
       ENDDO
   ENDIF
   
   if (ErrStat >= AbortErrLev) then
      call cleanup()
      return
   end if
   p%Shp(:,:) = 0.0_BDKi
   p%Der(:,:) = 0.0_BDKi
   p%Jacobian(:,:) = 0.0_BDKi

   CALL BD_InitShpDerJaco(p%quadrature,p%GL,GLL,p%uuN0,&
           p%node_elem,p%elem_total,p%dof_node,p%ngp,    &
           p%refine,InputFileData%kp_member,             &
           p%Shp,p%Der,p%GLw,p%Jacobian,                 &
           ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if

      ! calculate rrN0 (Initial relative rotation array)
   DO i = 1,p%elem_total
       CALL BD_NodalRelRot(p%uuN0(:,i),p%node_elem,p%dof_node,p%rrN0(:,i),ErrStat2,ErrMsg2)  !computes p%rrN0(:,i)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ENDDO
          
   p%uu0(:,:)  = 0.0_BDKi
   p%E10(:,:)  = 0.0_BDKi
   DO i = 1,p%elem_total
       DO j = 1,p%ngp
           temp_id = (j-1)*p%dof_node
           temp_id2= (j-1)*(p%dof_node/2)
           CALL BD_GaussPointDataAt0(p%Shp(:,j),p%Der(:,j),p%Jacobian(j,i),&
                   p%uuN0(:,i),p%rrN0(:,i),p%node_elem,p%dof_node,&
                   p%uu0(temp_id +1:temp_id +6,i),&
                   p%E10(temp_id2+1:temp_id2+3,i),ErrStat2,ErrMsg2) !computes p%uu0(temp_id+1:temp_id+6,i) and p%E10(temp_id2+1:temp_id2+3,i)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDDO
   ENDDO
   !CALL WrScr( "Finished reading input" )

      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if

         ! compute blade mass, CG, and IN for summary file:
   CALL BD_ComputeBladeMassNew(p%Mass0_GL,p%Gauss,p%elem_total,p%node_elem,&
                               p%dof_node,p%quadrature,p%ngp,p%GLw,p%Jacobian,&
                               p%blade_mass,p%blade_CG,p%blade_IN,ErrStat2,ErrMsg2) !computes p%blade_mass,p%blade_CG,p%blade_IN
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      
! Actuator
   p%UsePitchAct = InputFileData%UsePitchAct
   
   if (p%UsePitchAct) then
   
      p%pitchK = InputFileData%pitchK 
      p%pitchC = InputFileData%pitchC 
      p%pitchJ = InputFileData%pitchJ 
      
         ! calculate (I-hA)^-1
      
      p%torqM(1,1) =  p%pitchJ + p%pitchC*p%dt
      p%torqM(2,1) = -p%pitchK * p%dt
      p%torqM(1,2) =  p%pitchJ * p%dt
      p%torqM(2,2) =  p%pitchJ
      denom        =  p%pitchJ + p%pitchC*p%dt + p%pitchK*p%dt**2
      if (EqualRealNos(denom,0.0_BDKi)) then
         call SetErrStat(ErrID_Fatal,"Cannot invert matrix for pitch actuator: J+c*dt+k*dt^2 is zero.",ErrStat,ErrMsg,RoutineName)
      else         
         p%torqM(:,:) =  p%torqM / denom
      end if
               
      TmpDCM(:,:) = MATMUL(u%RootMotion%Orientation(:,:,1),TRANSPOSE(u%HubMotion%Orientation(:,:,1)))
      temp_CRV(:) = EulerExtract(TmpDCM)
      xd%thetaP = -temp_CRV(3)    
      xd%thetaPD = 0.0_BDKi
   end if   
! END Actuator
                     
   
      ! Define and initialize system inputs (set up and initialize input meshes) here:
   call Init_u(InitInp, p, u, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
            
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      ! allocate and initialize continuous states (need to do this after initializing inputs):
   call Init_ContinuousStates(p, u, x, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      ! allocate and initialize other states:
   call Init_OtherStates(p, OtherState, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                           
      ! initialize outputs (need to do this after initializing inputs and continuous states)      
   call Init_y(p, x, u, y, ErrStat2, ErrMsg2)
      call SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      
      ! allocate and initialize misc vars (do this after initializing input and output meshes):
   call Init_MiscVars(p, u, y, MiscVar, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
      
      ! set initializaiton outputs
   call SetInitOut(p, InitOut, errStat, errMsg)
      call SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
                  
   !...............................................
            
       ! Print the summary file if requested:
   if (InputFileData%SumPrint) then
      call BD_PrintSum( p, u, y, x, MiscVar, InitInp%RootName, ErrStat2, ErrMsg2 )
      call SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )      
   end if
      
   !...............................................
   
   z%DummyConstrState = 0.0_BDKi
   
   call Cleanup()
      
   return
contains
      subroutine Cleanup()
   
         if (allocated(GLL       )) deallocate(GLL       )
         if (allocated(temp_GL   )) deallocate(temp_GL   )
         if (allocated(temp_w    )) deallocate(temp_w    )
         if (allocated(temp_ratio)) deallocate(temp_ratio)
         if (allocated(SP_Coef   )) deallocate(SP_Coef   )
      
         call BD_DestroyInputFile( InputFileData, ErrStat2, ErrMsg2)
         
      end subroutine Cleanup            
END SUBROUTINE BD_Init
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine initializes data in the InitOut type, which is returned to the glue code.
subroutine SetInitOut(p, InitOut, ErrStat, ErrMsg)

   type(BD_InitOutputType),       intent(  out)  :: InitOut          !< output data
   type(BD_ParameterType),        intent(in   )  :: p                !< Parameters
   integer(IntKi),                intent(  out)  :: ErrStat          !< Error status of the operation
   character(*),                  intent(  out)  :: ErrMsg           !< Error message if ErrStat /= ErrID_None


      ! Local variables
   integer(intKi)                               :: i                 ! loop counter
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'SetInitOut'
   
   
   
      ! Initialize variables for this routine

   errStat = ErrID_None
   errMsg  = ""
   
   call AllocAry( InitOut%WriteOutputHdr, p%numOuts, 'WriteOutputHdr', errStat2, errMsg2 )
      call SetErrStat( errStat2, errMsg2, errStat, errMsg, RoutineName )
   
   call AllocAry( InitOut%WriteOutputUnt, p%numOuts, 'WriteOutputUnt', errStat2, errMsg2 )
      call SetErrStat( errStat2, errMsg2, errStat, errMsg, RoutineName )
      
   if (ErrStat >= AbortErrLev) return
   
   do i=1,p%NumOuts
      InitOut%WriteOutputHdr(i) = p%OutParam(i)%Name
      InitOut%WriteOutputUnt(i) = p%OutParam(i)%Units
   end do
         
   InitOut%Ver = BeamDyn_Ver
   
end subroutine SetInitOut
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine allocates and initializes most (not all) of the parameters used in BeamDyn.
subroutine SetParameters(InitInp, InputFileData, p, ErrStat, ErrMsg)
   type(BD_InitInputType),       intent(in   )  :: InitInp           !< Input data for initialization routine
   type(BD_InputFile),           intent(in   )  :: InputFileData     !< data from the input file
   type(BD_ParameterType),       intent(inout)  :: p                 !< Parameters  ! intent(out) only because it changes p%NdIndx
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None

   
   !local variables
   REAL(BDKi)                                   :: TmpPos(3)
   REAL(BDKi)                                   :: temp_POS(3)  
         
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'SetParameters'
   
   
   
   ErrStat = ErrID_None
   ErrMsg  = ""   
   
            
   !Read inputs from Driver/Glue code
   !1 Global position vector
   !2 Global rotation tensor
   !3 Gravity vector
   p%GlbPos(1)     = InitInp%GlbPos(3)
   p%GlbPos(2)     = InitInp%GlbPos(1)
   p%GlbPos(3)     = InitInp%GlbPos(2)

   p%GlbRot = TRANSPOSE(InitInp%GlbRot)
   CALL BD_CrvExtractCrv(p%GlbRot,TmpPos,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   p%Glb_crv(1) = TmpPos(3)
   p%Glb_crv(2) = TmpPos(1)
   p%Glb_crv(3) = TmpPos(2)
   CALL BD_CrvMatrixR(p%Glb_crv,p%GlbRot,ErrStat2,ErrMsg2) !given p%Glb_crv, returns p%GlbRot
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   temp_POS(1) = InitInp%gravity(3)
   temp_POS(2) = InitInp%gravity(1)
   temp_POS(3) = InitInp%gravity(2)
   p%gravity = MATMUL(TRANSPOSE(p%GlbRot),temp_POS)

           
   !....................
   ! data copied/derived from input file
   !....................
   ! Analysis type: 1 Static 2 Dynamic
   p%analysis_type  = InputFileData%analysis_type
   ! Numerical damping coefficient: [0,1].
   ! No numerical damping if rhoinf = 1; maximum numerical damping if rhoinf = 0.
   p%rhoinf = InputFileData%rhoinf
   ! Time step size
   p%dt = InputFileData%DTBeam
   ! Compute generalized-alpha time integrator coefficients given rhoinf
   CALL BD_TiSchmComputeCoefficients(p%rhoinf,p%dt,p%coef, ErrStat2, ErrMsg2) !requires p%rhoinf,p%dt; sets p%coef
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ! Maximum number of iterations in Newton-Ralphson algorithm
   p%niter = InputFileData%NRMax
   ! Tolerance used in stopping criterion
   p%tol = InputFileData%stop_tol
   ! Total number of elements
   p%elem_total = InputFileData%member_total      
   ! Total number of key points
   !p%kp_total = InputFileData%kp_total  !bjj: not used
      
   ! Number of nodes per elelemt
   p%node_elem  = InputFileData%order_elem + 1   
   ! Factorization frequency
   p%n_fact = InputFileData%n_fact
   ! Quadrature method: 1 Gauss 2 Trapezoidal
   p%quadrature = InputFileData%quadrature
   
   IF(p%quadrature .EQ. 1) THEN
       ! Number of Gauss points
       p%ngp = p%node_elem !- 1
   ELSEIF(p%quadrature .EQ. 2) THEN 
       p%refine = InputFileData%refine
       p%ngp = (InputFileData%kp_member(1) - 1)*p%refine + 1
   ENDIF

   ! Degree-of-freedom (DoF) per node
   p%dof_node   = 6
   ! Total number of (finite element) nodes
   p%node_total  = p%elem_total*(p%node_elem-1) + 1         
   ! Total number of (finite element) dofs
   p%dof_total   = p%node_total*p%dof_node   
   
   p%dof_elem = p%dof_node   * p%node_elem
   p%rot_elem = p%dof_node/2 * p%node_elem

      
   !................................
   ! allocate some parameter arrays
   !................................
   CALL AllocAry(p%member_length, InputFileData%member_total,2,'member length array', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%segment_length,InputFileData%kp_total-1,  3,'segment length array',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   CALL AllocAry(p%Shp,     p%node_elem,p%ngp,       'p%Shp',     ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%Der,     p%node_elem,p%ngp,       'p%Der',     ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%Jacobian,p%ngp,      p%elem_total,'p%Jacobian',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   CALL AllocAry(p%uuN0, p%dof_node*p%node_elem,   p%elem_total,'uuN0 (initial position) array',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
   CALL AllocAry(p%rrN0,(p%dof_node*p%node_elem)/2,p%elem_total,'p%Nrr0',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%uu0,  p%dof_node*p%ngp,         p%elem_total,'p%uu0', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%E10,  3*p%ngp,                  p%elem_total,'p%E10', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   ! Quadrature point and weight arrays in natural frame
   !    If Gauss: Gauss points and weights
   !    If Trapezoidal: quadrature points and weights
   CALL AllocAry(p%GL, p%ngp,'p%GL',              ErrStat2,ErrMsg2) ; CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(p%GLw,p%ngp,'p%GLw weight array',ErrStat2,ErrMsg2) ; CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   !bjj: these values aren't used anywhere
   !! Key point coordinates
   !CALL AllocAry(p%kp_coordinate,p%kp_total,3,'Key point coordinates array',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   !! Number of key points in each member
   !CALL AllocAry(p%kp_member,InputFileData%member_total,'Number of key points in each memeber',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   
   if (ErrStat >= AbortErrLev) return
         
   !p%kp_coordinate = InputFileData%kp_coordinate(:,1:3)
   !p%kp_member     = InputFileData%kp_member
   
   !...............................................      
   ! Physical damping flag and 6 damping coefficients
   !...............................................
   p%damp_flag  = InputFileData%InpBl%damp_flag
   p%beta       = InputFileData%InpBl%beta
      
   !...............................................
   ! set parameters for pitch actuator:
   !...............................................
      
      
      
   !...............................................
   ! set parameters for File I/O data:
   !...............................................
      ! allocate arry for mapping PointLoad to BldMotion (for writeOutput); array is initialized in Init_y
   CALL AllocAry(p%NdIndx,p%node_total,'p%NdIndx',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
            
   p%OutFmt    = InputFileData%OutFmt
   
   p%numOuts   = InputFileData%NumOuts  
   p%NNodeOuts = InputFileData%NNodeOuts      
   p%OutNd     = InputFileData%OutNd

   p%OutInputs = .false.  ! will get set to true in SetOutParam if we request the inputs as output values

   call SetOutParam(InputFileData%OutList, p, ErrStat2, ErrMsg2 ) ! requires: p%NumOuts, p%NNodeOuts, p%UsePitchAct; sets: p%OutParam.
      call setErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
      if (ErrStat >= AbortErrLev) return        
      
end subroutine SetParameters
!-----------------------------------------------------------------------------------------------------------------------------------
!> this routine initializes the outputs, y, that are used in the BeamDyn interface for coupling in the FAST framework.
subroutine Init_y( p, x, u, y, ErrStat, ErrMsg)

   type(BD_ParameterType),       intent(inout)  :: p                 !< Parameters  -- intent(out) only because it changes p%NdIndx
   type(BD_ContinuousStateType), intent(in   )  :: x                 !< Continuous states
   type(BD_InputType),           intent(inout)  :: u                 !< Inputs
   type(BD_OutputType),          intent(inout)  :: y                 !< Outputs
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None

      ! local variables
   real(R8Ki)                                   :: DCM(3,3)          ! must be same type as mesh orientation fields
   real(ReKi)                                   :: Pos(3)            ! must be same type as mesh position fields 
   
   real(BDKi)                                   :: TmpDCM(3,3)
   real(BDKi)                                   :: temp_POS(3)
   real(BDKi)                                   :: temp_CRV(3)
   
   integer(intKi)                               :: temp_id        
   integer(intKi)                               :: i,j,indx          ! loop counters
   integer(intKi)                               :: NNodes            ! number of nodes in mesh
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'Init_y'
   
   
   
   ErrStat = ErrID_None
   ErrMsg  = ""   
   
   !.................................
   ! y%BldForce (used only for WriteOutput)
   !.................................
   CALL MeshCopy ( SrcMesh  = u%PointLoad      &
                 , DestMesh = y%BldForce       &
                 , CtrlCode = MESH_SIBLING     &
                 , IOS      = COMPONENT_OUTPUT &
                 , Force    = .TRUE.           &
                 , Moment   = .TRUE.           &
                 , ErrStat  = ErrStat2         &
                 , ErrMess  = ErrMsg2          )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) RETURN
      ! initialization (not necessary)
   !y%BldForce%Force(:,:)  = 0.0_BDKi
   !y%BldForce%Moment(:,:) = 0.0_BDKi
      
   !.................................
   ! y%ReactionForce (for coupling with ElastoDyn)
   !.................................
      
   CALL MeshCopy( SrcMesh   = u%RootMotion     &
                 , DestMesh = y%ReactionForce  &
                 , CtrlCode = MESH_SIBLING     &
                 , IOS      = COMPONENT_OUTPUT &
                 , Force    = .TRUE.           &
                 , Moment   = .TRUE.           &
                 , ErrStat  = ErrStat2         &
                 , ErrMess  = ErrMsg2          )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) RETURN
         
      ! initialization (not necessary)
      
   !y%ReactionForce%Force(:,:)  = 0.0_BDKi
   !y%ReactionForce%Moment(:,:) = 0.0_BDKi

      
   !.................................
   ! y%BldMotion (for coupling with AeroDyn)
   !.................................
      
   NNodes = p%node_elem*p%elem_total
   CALL MeshCreate( BlankMesh        = y%BldMotion        &
                   ,IOS              = COMPONENT_OUTPUT   &
                   ,NNodes           = NNodes             &
                   ,TranslationDisp  = .TRUE.             &
                   ,Orientation      = .TRUE.             &
                   ,TranslationVel   = .TRUE.             &
                   ,RotationVel      = .TRUE.             &
                   ,TranslationAcc   = .TRUE.             &
                   ,RotationAcc      = .TRUE.             &
                   ,ErrStat          = ErrStat2           &
                   ,ErrMess          = ErrMsg2             )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) RETURN
   
   
      ! position nodes
   DO i=1,p%elem_total
      DO j=1,p%node_elem
         
           temp_id = (j-1)*p%dof_node
           
           temp_POS = p%GlbPos + MATMUL(p%GlbRot,p%uuN0(temp_id+1:temp_id+3,i))
           Pos(1) = temp_POS(2)
           Pos(2) = temp_POS(3)
           Pos(3) = temp_POS(1)
           
           temp_CRV = MATMUL(p%GlbRot,p%uuN0(temp_id+4:temp_id+6,i))
           CALL BD_CrvCompose(temp_POS,p%Glb_crv,temp_CRV,0,ErrStat2,ErrMsg2) !given p%Glb_crv and temp_CRV, returns temp_POS
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
              
           temp_CRV(1) = temp_POS(2)
           temp_CRV(2) = temp_POS(3)
           temp_CRV(3) = temp_POS(1)
           
           CALL BD_CrvMatrixR(temp_CRV,TmpDCM,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )  
              
              ! possible type conversions here:
           DCM = TRANSPOSE(TmpDCM)
           
           temp_id = (i-1)*p%node_elem+j
           CALL MeshPositionNode ( Mesh    = y%BldMotion   &
                                  ,INode   = temp_id       &
                                  ,Pos     = Pos           &
                                  ,ErrStat = ErrStat2      &
                                  ,ErrMess = ErrMsg2       &
                                  ,Orient  = DCM           )
            CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
           
       ENDDO
   ENDDO
   
      ! create elements and create index array
   
   !NNodes = p%node_elem*p%elem_total
   p%NdIndx(1) = 1
   indx = 2
   DO i=1,NNodes-1
      
      if (.not. equalRealNos( REAL( TwoNorm( y%BldMotion%Position(:,i)-y%BldMotion%Position(:,i+1) ), SiKi ), 0.0_SiKi ) ) then
         p%NdIndx(indx) = i + 1
         indx = indx + 1;
         ! do not connect nodes that are collocated
          CALL MeshConstructElement( Mesh     = y%BldMotion      &
                                    ,Xelement = ELEMENT_LINE2    &
                                    ,P1       = i                &
                                    ,P2       = i+1              &
                                    ,ErrStat  = ErrStat2         &
                                    ,ErrMess  = ErrMsg2          )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      end if
      
   ENDDO
         
            
   CALL MeshCommit ( Mesh    = y%BldMotion     &
                    ,ErrStat = ErrStat2        &
                    ,ErrMess = ErrMsg2         )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
      if (ErrStat>=AbortErrLev) RETURN
   
   
      ! initialization (used for initial guess to AeroDyn)

   CALL Set_BldMotion_NoAcc(p, x, y, ErrStat2, ErrMsg2)        
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
   !y%BldMotion%TranslationDisp = 0.0_BDKi
   !y%BldMotion%Orientation     = y%BldMotion%RefOrientation
   !y%BldMotion%TranslationVel  = 0.0_BDKi
   !y%BldMotion%RotationVel     = 0.0_BDKi
   y%BldMotion%TranslationAcc  = 0.0_BDKi
   y%BldMotion%RotationAcc     = 0.0_BDKi
   
   
   !.................................
   ! y%WriteOutput (for writing columns to output file)
   !.................................
   
   call AllocAry( y%WriteOutput, p%numOuts, 'WriteOutput', errStat2, errMsg2 )
      call SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   
end subroutine Init_y
!-----------------------------------------------------------------------------------------------------------------------------------
!> this routine initializes the inputs, u, that are used in the BeamDyn interface for coupling in the FAST framework.
subroutine Init_u( InitInp, p, u, ErrStat, ErrMsg )

   type(BD_InitInputType),       intent(in   )  :: InitInp           !< Input data for initialization routine
   type(BD_ParameterType),       intent(in   )  :: p                 !< Parameters
   type(BD_InputType),           intent(inout)  :: u                 !< Inputs
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None
   
   
   real(R8Ki)                                   :: DCM(3,3)          ! must be same type as mesh orientation fields
   real(ReKi)                                   :: Pos(3)            ! must be same type as mesh position fields

   real(BDKi)                                   :: TmpDCM(3,3)
   real(BDKi)                                   :: temp_POS(3)
   real(BDKi)                                   :: temp_CRV(3)
   
   integer(intKi)                               :: temp_id           
   integer(intKi)                               :: i,j               ! loop counters
   integer(intKi)                               :: NNodes            ! number of nodes in mesh
   
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'Init_u'
   
   ErrStat = ErrID_None
   ErrMsg  = ""
   
   !.................................
   ! u%HubMotion (from ElastoDyn for pitch actuator)
   !.................................

   CALL MeshCreate( BlankMesh        = u%HubMotion        &
                   ,IOS              = COMPONENT_INPUT    &
                   ,NNodes           = 1                  &
                   , TranslationDisp = .TRUE.             &
                   , Orientation     = .TRUE.             &
                   ,ErrStat          = ErrStat2           &
                   ,ErrMess          = ErrMsg2            )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) return
      
      ! possible type conversions here:
   DCM = InitInp%HubRot 
   Pos = InitInp%HubPos
   CALL MeshPositionNode ( Mesh    = u%HubMotion          &
                         , INode   = 1                    &
                         , Pos     = Pos                  &
                         , ErrStat = ErrStat2             &
                         , ErrMess = ErrMsg2              &
                         , Orient  = DCM                  )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   CALL MeshConstructElement ( Mesh = u%HubMotion         &
                             , Xelement = ELEMENT_POINT   &
                             , P1       = 1               &
                             , ErrStat  = ErrStat2        &
                             , ErrMess  = ErrMsg2         )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   CALL MeshCommit(u%HubMotion, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
   
      ! initial guesses
   u%HubMotion%TranslationDisp(1:3,1) = 0.0_ReKi
   u%HubMotion%Orientation(1:3,1:3,1) = InitInp%HubRot
      
   !.................................
   ! u%RootMotion (for coupling with ElastoDyn)
   !.................................

   CALL MeshCreate( BlankMesh        = u%RootMotion          &
                   ,IOS              = COMPONENT_INPUT       &
                   ,NNodes           = 1                     &
                   , TranslationDisp = .TRUE.                &
                   , TranslationVel  = .TRUE.                &
                   , TranslationAcc  = .TRUE.                &
                   , Orientation     = .TRUE.                &
                   , RotationVel     = .TRUE.                &
                   , RotationAcc     = .TRUE.                &
                   ,ErrStat         = ErrStat2               &
                   ,ErrMess         = ErrMsg2                )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) return
            
  !! ! place single node at origin; position affects mapping/coupling with other modules
  !! temp_POS(:) = p%GlbPos(1:3) + MATMUL(p%GlbRot,p%uuN0(1:3,1))
  !! Pos(1) = temp_POS(2)
  !! Pos(2) = temp_POS(3)
  !! Pos(3) = temp_POS(1)
  !!
  !! temp_CRV(1) = p%Glb_crv(2)
  !! temp_CRV(2) = p%Glb_crv(3)
  !! temp_CRV(3) = p%Glb_crv(1)
  !!CALL BD_CrvMatrixR(temp_CRV,TmpDCM,ErrStat2,ErrMsg2)
  !!    CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
  !! DCM = TRANSPOSE(TmpDCM)
      
   DCM = InitInp%GlbRot 
   Pos = InitInp%GlbPos      
   CALL MeshPositionNode ( Mesh    = u%RootMotion &
                         , INode   = 1            &
                         , Pos     = Pos          &
                         , ErrStat = ErrStat2     &
                         , ErrMess = ErrMsg2      &
                         , Orient  = DCM          ) 
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
         
   CALL MeshConstructElement ( Mesh     = u%RootMotion       &
                             , Xelement = ELEMENT_POINT      &
                             , P1       = 1                  &
                             , ErrStat  = ErrStat2           &
                             , ErrMess  = ErrMsg2            )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
   
   CALL MeshCommit ( Mesh    = u%RootMotion    &
                    ,ErrStat = ErrStat2        &
                    ,ErrMess = ErrMsg2         )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      ! initial guesses
   u%RootMotion%TranslationDisp(1:3,1) = InitInp%RootDisp(1:3)
   u%RootMotion%Orientation(1:3,1:3,1) = InitInp%RootOri(1:3,1:3)
   u%RootMotion%TranslationVel(1:3,1)  = InitInp%RootVel(1:3)
   u%RootMotion%RotationVel(1:3,1)     = InitInp%RootVel(4:6)
   u%RootMotion%TranslationAcc(:,:)    = 0.0_ReKi
   u%RootMotion%RotationAcc(:,:)       = 0.0_ReKi
            
   !.................................
   ! u%PointLoad (currently not used in FAST)
   !.................................
   
   CALL MeshCreate( BlankMesh       = u%PointLoad      &
                   ,IOS             = COMPONENT_INPUT  &
                   ,NNodes          = p%node_total     &
                   ,Force           = .TRUE.           &
                   ,Moment          = .TRUE.           &
                   ,ErrStat         = ErrStat2         &
                   ,ErrMess         = ErrMsg2          )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat>=AbortErrLev) return

   DO i=1,p%elem_total
       DO j=1,p%node_elem
           temp_id = (j-1) * p%dof_node
           temp_POS = p%GlbPos(1:3) + MATMUL(p%GlbRot,p%uuN0(temp_id+1:temp_id+3,i))
           Pos(1) = temp_POS(2)
           Pos(2) = temp_POS(3)
           Pos(3) = temp_POS(1)
           
           temp_CRV = MATMUL(p%GlbRot,p%uuN0(temp_id+4:temp_id+6,i))
           CALL BD_CrvCompose(temp_POS,p%Glb_crv,temp_CRV,0,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
           temp_CRV(1) = temp_POS(2)
           temp_CRV(2) = temp_POS(3)
           temp_CRV(3) = temp_POS(1)
           CALL BD_CrvMatrixR(temp_CRV,TmpDCM,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
           DCM = TRANSPOSE(TmpDCM)
           
           temp_id = (i-1)*(p%node_elem-1)+j           
           CALL MeshPositionNode ( Mesh    = u%PointLoad  &
                                  ,INode   = temp_id      &
                                  ,Pos     = Pos          &
                                  ,ErrStat = ErrStat2     &
                                  ,ErrMess = ErrMsg2      &
                                  , Orient = DCM ) 
               CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDDO
   ENDDO      
      
   DO i=1,p%node_total
       CALL MeshConstructElement( Mesh     = u%PointLoad      &
                                 ,Xelement = ELEMENT_POINT    &
                                 ,P1       = i                &
                                 ,ErrStat  = ErrStat2         &
                                 ,ErrMess  = ErrMsg2          )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       
   ENDDO
      
   CALL MeshCommit ( Mesh    = u%PointLoad     &
                    ,ErrStat = ErrStat2        &
                    ,ErrMess = ErrMsg2         )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
      ! initial guesses
   u%PointLoad%Force  = 0.0_ReKi
   u%PointLoad%Moment = 0.0_ReKi      
      
   !.................................
   ! u%DistrLoad (for coupling with AeroDyn)
   !.................................
            
   NNodes = size(p%Gauss,2)   
   CALL MeshCreate( BlankMesh  = u%DistrLoad      &
                   ,IOS        = COMPONENT_INPUT  &
                   ,NNodes     = NNodes           &
                   ,Force      = .TRUE.           &
                   ,Moment     = .TRUE.           &
                   ,ErrStat    = ErrStat2         &
                   ,ErrMess    = ErrMsg2          )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
      if (ErrStat>=AbortErrLev) return

   DO i=1,NNodes
      temp_POS(1:3) = p%GlbPos(1:3) + MATMUL(p%GlbRot,p%Gauss(1:3,i))
      Pos(1) = temp_POS(2)
      Pos(2) = temp_POS(3)
      Pos(3) = temp_POS(1)
      
      temp_CRV(:) = MATMUL(p%GlbRot,p%Gauss(4:6,i))
      CALL BD_CrvCompose(temp_POS,p%Glb_crv,temp_CRV,0,ErrStat2,ErrMsg2)
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      temp_CRV(1) = temp_POS(2)
      temp_CRV(2) = temp_POS(3)
      temp_CRV(3) = temp_POS(1)
      CALL BD_CrvMatrixR(temp_CRV,TmpDCM,ErrStat2,ErrMsg2)
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      DCM = TRANSPOSE(TmpDCM)
      
      CALL MeshPositionNode ( Mesh    = u%DistrLoad  &
                             ,INode   = i            &
                             ,Pos     = Pos          &
                             ,ErrStat = ErrStat2     &
                             ,ErrMess = ErrMsg2      &
                             ,Orient  = DCM ) 
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ENDDO   
   
   DO i=1,NNodes-1
      CALL MeshConstructElement( Mesh      = u%DistrLoad      &
                                 ,Xelement = ELEMENT_LINE2    &
                                 ,P1       = i                &
                                 ,P2       = i+1              &
                                 ,ErrStat  = ErrStat2         &
                                 ,ErrMess  = ErrMsg2          )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ENDDO

   
   CALL MeshCommit ( Mesh    = u%DistrLoad     &
                    ,ErrStat = ErrStat2        &
                    ,ErrMess = ErrMsg2         )
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
      ! initial guesses
   u%DistrLoad%Force  = 0.0_ReKi
   u%DistrLoad%Moment = 0.0_ReKi      
   
      
end subroutine Init_u
!-----------------------------------------------------------------------------------------------------------------------------------
!> this subroutine initializes the misc variables.
subroutine Init_MiscVars( p, u, y, m, ErrStat, ErrMsg )
   type(BD_ParameterType),       intent(in   )  :: p                 !< Parameters
   type(BD_InputType),           intent(inout)  :: u                 !< Inputs   ! intent(out) because I'm copying it
   type(BD_OutputType),          intent(inout)  :: y                 !< Outputs  ! intent(out) because I'm copying it
   type(BD_MiscVarType),         intent(inout)  :: m                 !< misc/optimization variables
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None
   
   
   
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'Init_OtherStates'
   
   ErrStat = ErrID_None
   ErrMsg  = ""
   
   m%Un_Sum = -1
   !if (p%analysis_type == BD_DYNAMIC_ANALYSIS) then
         ! allocate arrays at initialization so we don't waste so much time on memory allocation/deallocation on each step
      
      CALL AllocAry(m%StifK_LU,p%dof_total-6,p%dof_total-6,'StifK_LU',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%RHS_LU,  p%dof_total-6,              'RHS_LU',  ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      CALL AllocAry(m%StifK,p%dof_total,p%dof_total,'StifK',      ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%MassM,p%dof_total,p%dof_total,'MassM',      ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%RHS,              p%dof_total,'RHS',        ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%F_PointLoad,      p%dof_total,'F_PointLoad',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%indx,             p%dof_total,'indx',       ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      CALL AllocAry(m%Nuuu, p%dof_elem,            'Nuuu', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%Nrrr, p%rot_elem,            'Nrrr', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%Nvvv, p%dof_elem,            'Nvvv', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%Naaa, p%dof_elem,            'Naaa', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%elf,  p%dof_elem,             'elf', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%elk,  p%dof_elem,p%dof_elem,  'elk', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%elg,  p%dof_elem,p%dof_elem,  'elg', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%elm,  p%dof_elem,p%dof_elem,  'elm', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%EStif0_GL, 6,6,p%ngp,   'EStif0_GL', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%EMass0_GL, 6,6,p%ngp,   'EMass0_GL', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL AllocAry(m%DistrLoad_GL,6,p%ngp,'DistrLoad_GL', ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
            
   !end if
   
   ! create copy of u%DistrLoad at y%BldMotion locations (for WriteOutput only)
   if (p%OutInputs) then
      
         ! y%BldMotion and u%DistrLoad are not siblings, so we need to create  
         ! mapping to output u%DistrLoad values at y%BldMotion nodes 
         ! (not making these new meshes siblings of old ones because FAST needs to
         ! do this same trick and we can't have more than one sibling of a mesh)
                 
      CALL MeshCopy ( SrcMesh  = y%BldMotion                  &
                    , DestMesh = m%u_DistrLoad_at_y           &
                    , CtrlCode = MESH_COUSIN                  &  ! Like a sibling, except using new memory for position/refOrientation and elements
                    , IOS      = COMPONENT_INPUT              &
                    , Force    = .TRUE.                       &
                    , Moment   = .TRUE.                       &
                    , ErrStat  = ErrStat2                     &
                    , ErrMess  = ErrMsg2                      )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      CALL MeshCopy ( SrcMesh  = u%DistrLoad                  &
                    , DestMesh = m%y_BldMotion_at_u           &
                    , CtrlCode = MESH_COUSIN                  &
                    , IOS      = COMPONENT_OUTPUT             &
                    , Orientation     = .TRUE.                &
                    , TranslationDisp = .TRUE.                &
                    , ErrStat         = ErrStat2              &
                    , ErrMess         = ErrMsg2               )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
         
      CALL MeshMapCreate( u%DistrLoad, m%u_DistrLoad_at_y, m%Map_u_DistrLoad_to_y, ErrStat2, ErrMsg2 )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      CALL MeshMapCreate( y%BldMotion, m%y_BldMotion_at_u, m%Map_y_BldMotion_to_u, ErrStat2, ErrMsg2 )
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
               
      m%u_DistrLoad_at_y%remapFlag = .false.
      m%y_BldMotion_at_u%remapFlag = .false.
   end if
      
      ! create copy of inputs, which will be converted to internal BeamDyn coordinate system 
      ! (put in miscVars so we don't have to create new meshes each call)
   CALL BD_CopyInput(u, m%u, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   CALL BD_CopyInput(u, m%u2, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      
end subroutine Init_MiscVars   
!-----------------------------------------------------------------------------------------------------------------------------------
!> this subroutine initializes the other states.
subroutine Init_OtherStates( p, OtherState, ErrStat, ErrMsg )
   type(BD_ParameterType),       intent(in   )  :: p                 !< Parameters
   type(BD_OtherStateType),      intent(inout)  :: OtherState        !< Other states
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None
   
   
   
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'Init_OtherStates'
   
   ErrStat = ErrID_None
   ErrMsg  = ""

        
   ! Allocate other states: Acceleration and algorithm accelerations for generalized-alpha time integator
   CALL AllocAry(OtherState%acc,p%dof_total,'OtherState%acc',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(OtherState%xcc,p%dof_total,'OtherState%xcc',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   if (ErrStat>=AbortErrLev) return   
            
   OtherState%InitAcc = .false. ! accelerations have not been initialized, yet
      
   OtherState%acc(:) = 0.0_BDKi
   OtherState%xcc(:) = 0.0_BDKi
            
end subroutine Init_OtherStates   
!-----------------------------------------------------------------------------------------------------------------------------------
!> this subroutine initializes the continuous states.
subroutine Init_ContinuousStates( p, u, x, ErrStat, ErrMsg )
   type(BD_ParameterType),       intent(inout)  :: p                 !< Parameters !sets the copy-of-state values
   type(BD_InputType),           intent(inout)  :: u                 !< Inputs  !intent(out) because of mesh copy, otherwise not changed
   type(BD_ContinuousStateType), intent(inout)  :: x                 !< Continuous states
   integer(IntKi),               intent(  out)  :: ErrStat           !< Error status of the operation
   character(*),                 intent(  out)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None
   
   
   TYPE(BD_InputType)                           :: u_tmp             ! A copy of the initial input (guess), converted to BeamDyn internal coordinates
   integer(intKi)                               :: ErrStat2          ! temporary Error status
   character(ErrMsgLen)                         :: ErrMsg2           ! temporary Error message
   character(*), parameter                      :: RoutineName = 'Init_ContinuousStates'
   
   
   ErrStat = ErrID_None
   ErrMsg  = ""

   ! Allocate continuous states
   CALL AllocAry(x%q,      p%dof_total,'x%q',      ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(x%dqdt,   p%dof_total,'x%dqdt',   ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
   x%q(:)    = 0.0_BDKi
   x%dqdt(:) = 0.0_BDKi
         
   
      ! create copy of inputs, u, to convert to BeamDyn-internal system inputs, u_tmp, which is used to initialize states:
   CALL BD_CopyInput(u, u_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
      ! convert to BeamDyn-internal system inputs, u_tmp:      
   CALL BD_InputGlobalLocal(p,u_tmp,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   
      ! initialize states, given parameters and initial inputs (in BD coordinates)
   CALL BD_CalcIC(u_tmp,p,x,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   call cleanup()
   
contains
   subroutine cleanup()
      call BD_DestroyInput( u_tmp, ErrStat2, ErrMsg2)
   end subroutine cleanup   
end subroutine Init_ContinuousStates   
!-----------------------------------------------------------------------------------------------------------------------------------
!> This routine is called at the end of the simulation.
SUBROUTINE BD_End( u, p, x, xd, z, OtherState, y, m, ErrStat, ErrMsg )

   TYPE(BD_InputType),           INTENT(INOUT)  :: u           !< System inputs
   TYPE(BD_ParameterType),       INTENT(INOUT)  :: p           !< Parameters
   TYPE(BD_ContinuousStateType), INTENT(INOUT)  :: x           !< Continuous states
   TYPE(BD_DiscreteStateType),   INTENT(INOUT)  :: xd          !< Discrete states
   TYPE(BD_ConstraintStateType), INTENT(INOUT)  :: z           !< Constraint states
   TYPE(BD_OtherStateType),      INTENT(INOUT)  :: OtherState  !< Other states
   TYPE(BD_OutputType),          INTENT(INOUT)  :: y           !< System outputs
   TYPE(BD_MiscVarType),         INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),               INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""

   ! Place any last minute operations or calculations here:

   ! Close files here:
   if (m%Un_Sum > 0) CLOSE(m%Un_Sum)

   
   ! Destroy the input data:

   CALL BD_DestroyInput( u, ErrStat, ErrMsg )

   ! Destroy the parameter data:

   CALL BD_DestroyParam( p, ErrStat, ErrMsg )

   ! Destroy the state data:

   CALL BD_DestroyContState(   x,           ErrStat, ErrMsg )
   CALL BD_DestroyDiscState(   xd,          ErrStat, ErrMsg )
   CALL BD_DestroyConstrState( z,           ErrStat, ErrMsg )
   CALL BD_DestroyOtherState(  OtherState,  ErrStat, ErrMsg )

   ! Destroy misc data
   CALL BD_DestroyMisc(  m,  ErrStat, ErrMsg )
   
   ! Destroy the output data:

   CALL BD_DestroyOutput( y, ErrStat, ErrMsg )

END SUBROUTINE BD_End
!-----------------------------------------------------------------------------------------------------------------------------------
!> This is a loose coupling routine for solving constraint states, integrating continuous states, and updating discrete and other 
!! states. Continuous, constraint, discrete, and other states are updated to values at t + Interval.
SUBROUTINE BD_UpdateStates( t, n, u, utimes, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )

   REAL(DbKi),                      INTENT(IN   ) :: t          !< Current simulation time in seconds
   INTEGER(IntKi),                  INTENT(IN   ) :: n          !< Current simulation time step n = 0,1,...
   TYPE(BD_InputType),              INTENT(INOUT) :: u(:)       !< Inputs at utimes
   REAL(DbKi),                      INTENT(IN   ) :: utimes(:)  !< Times associated with u(:), in seconds
   TYPE(BD_ParameterType),          INTENT(IN   ) :: p          !< Parameters
   TYPE(BD_ContinuousStateType),    INTENT(INOUT) :: x          !< Input: Continuous states at t;
                                                                !!   Output: Continuous states at t + dt
   TYPE(BD_DiscreteStateType),      INTENT(INOUT) :: xd         !< Input: Discrete states at t;
                                                                !!   Output: Discrete states at t + dt
   TYPE(BD_ConstraintStateType),    INTENT(INOUT) :: z          !< Input: Initial guess of constraint states at t + dt;
                                                                !!   Output: Constraint states at t + dt
   TYPE(BD_OtherStateType),         INTENT(INOUT) :: OtherState !< Other states: Other states at t;
                                                                !!   Output: Other states at t + dt
   TYPE(BD_MiscVarType),            INTENT(INOUT) :: m          !< misc/optimization variables
   INTEGER(IntKi),                  INTENT(  OUT) :: ErrStat    !< Error status of the operation
   CHARACTER(*),                    INTENT(  OUT) :: ErrMsg     !< Error message if ErrStat /= ErrID_None

   
   
   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""
   
         
   IF(p%analysis_type == BD_DYNAMIC_ANALYSIS) THEN
       CALL BD_GA2( t, n, u, utimes, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )
   ELSEIF(p%analysis_type == BD_STATIC_ANALYSIS) THEN
       CALL BD_Static( t, n, u, utimes, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )
   ENDIF

END SUBROUTINE BD_UpdateStates
!-----------------------------------------------------------------------------------------------------------------------------------
!> Routine for computing outputs, used in both loose and tight coupling.
SUBROUTINE BD_CalcOutput( t, u, p, x, xd, z, OtherState, y, m, ErrStat, ErrMsg )

   REAL(DbKi),                   INTENT(IN   )  :: t           !< Current simulation time in seconds
   TYPE(BD_InputType),           INTENT(INOUT)  :: u           !< Inputs at t
   TYPE(BD_ParameterType),       INTENT(IN   )  :: p           !< Parameters
   TYPE(BD_ContinuousStateType), INTENT(IN   )  :: x           !< Continuous states at t
   TYPE(BD_DiscreteStateType),   INTENT(IN   )  :: xd          !< Discrete states at t
   TYPE(BD_ConstraintStateType), INTENT(IN   )  :: z           !< Constraint states at t
   TYPE(BD_OtherStateType),      INTENT(IN   )  :: OtherState  !< Other states at t
   TYPE(BD_OutputType),          INTENT(INOUT)  :: y           !< Outputs computed at t (Input only so that mesh con-
                                                               !!   nectivity information does not have to be recalculated)
   TYPE(BD_MiscVarType),         INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),               INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   TYPE(BD_OtherStateType)                      :: OS_tmp
   TYPE(BD_ContinuousStateType)                 :: x_tmp
   INTEGER(IntKi)                               :: i
   INTEGER(IntKi)                               :: j
   INTEGER(IntKi)                               :: temp_id
   INTEGER(IntKi)                               :: temp_id2
   REAL(BDKi)                                   :: cc(3)
   REAL(BDKi)                                   :: cc0(3)
   REAL(BDKi)                                   :: temp_cc(3)
   REAL(BDKi)                                   :: temp_R(3,3)
   REAL(BDKi)                                   :: temp6(6)
   REAL(BDKi)                                   :: temp_Force(p%dof_total)
   REAL(ReKi)                                   :: AllOuts(0:MaxOutPts)
   !REAL(BDKi)                                   :: temp_ReactionForce(6)
   INTEGER(IntKi)                               :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                         :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                      :: RoutineName = 'BD_CalcOutput'
   
   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""
   AllOuts = 0.0_ReKi

   CALL BD_CopyContState(x, x_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CopyOtherState(OtherState, OS_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
   CALL BD_CopyInput(u, m%u, MESH_UPDATECOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   ! Actuator
   IF( p%UsePitchAct ) THEN
       CALL PitchActuator_SetBC(p, m%u, xd, AllOuts)
   ENDIF
   ! END Actuator
   
   CALL BD_CopyInput(m%u, m%u2, MESH_UPDATECOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if

      ! set y%BldMotion%TranslationDisp, y%BldMotion%Orientation, y%BldMotion%TranslationVel, and y%BldMotion%RotationVel:
   CALL Set_BldMotion_NoAcc(p, x, y, ErrStat2, ErrMsg2)      
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

      ! calculate y%BldMotion accelerations:
   CALL BD_InputGlobalLocal(p,m%u,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_BoundaryGA2(x_tmp,p,m%u,t,OS_tmp,m,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   IF(p%analysis_type .EQ. BD_DYNAMIC_ANALYSIS) THEN
       CALL BD_CalcForceAcc(m%u,p,m,x_tmp,OS_tmp,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       DO i=1,p%elem_total
           DO j=1,p%node_elem
               temp_id = ((i-1)*(p%node_elem-1)+j-1)*p%dof_node
               temp_id2= (i-1)*p%node_elem+j
               IF(i .EQ. 1 .AND. j .EQ. 1) THEN
                   temp6(1:3) = m%u%RootMotion%TranslationAcc(1:3,1)
                   temp6(4:6) = m%u%RootMotion%RotationAcc(1:3,1)
               ELSE
                   temp6(1:3) = OS_tmp%Acc(temp_id+1:temp_id+3)
                   temp6(4:6) = OS_tmp%Acc(temp_id+4:temp_id+6)
               ENDIF
                   temp_cc(:) = MATMUL(p%GlbRot,temp6(1:3))
                   y%BldMotion%TranslationAcc(1,temp_id2) = temp_cc(2)
                   y%BldMotion%TranslationAcc(2,temp_id2) = temp_cc(3)
                   y%BldMotion%TranslationAcc(3,temp_id2) = temp_cc(1)
                   temp_cc(:) = MATMUL(p%GlbRot,temp6(4:6))
                   y%BldMotion%RotationAcc(1,temp_id2) = temp_cc(2)
                   y%BldMotion%RotationAcc(2,temp_id2) = temp_cc(3)
                   y%BldMotion%RotationAcc(3,temp_id2) = temp_cc(1)
           ENDDO
       ENDDO
       CALL BD_DynamicSolutionForce(x_tmp%q,x_tmp%dqdt,OS_tmp%Acc, m%u, p, m, temp_Force,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ELSEIF(p%analysis_type .EQ. BD_STATIC_ANALYSIS) THEN
       CALL BD_StaticSolutionForce( x%q,x%dqdt,p, m, m%u,temp_Force,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ENDIF

   IF(p%analysis_type .EQ. BD_DYNAMIC_ANALYSIS) THEN
       temp6(1:6) = -OS_tmp%Acc(1:6)
       temp_cc(:) = MATMUL(p%GlbRot,temp6(1:3))
       y%ReactionForce%Force(1,1) = temp_cc(2)
       y%ReactionForce%Force(2,1) = temp_cc(3)
       y%ReactionForce%Force(3,1) = temp_cc(1)
       temp_cc(:) = MATMUL(p%GlbRot,temp6(4:6))
       y%ReactionForce%Moment(1,1) = temp_cc(2)
       y%ReactionForce%Moment(2,1) = temp_cc(3)
       y%ReactionForce%Moment(3,1) = temp_cc(1)
   ENDIF
   DO i=1,p%node_total
       temp_id = (i-1)*p%dof_node
       temp6(:) = temp_Force(temp_id+1:temp_id+6)
       temp_cc(:) = MATMUL(p%GlbRot,temp6(1:3))
       y%BldForce%Force(1,i) = temp_cc(2)
       y%BldForce%Force(2,i) = temp_cc(3)
       y%BldForce%Force(3,i) = temp_cc(1)
       temp_cc(:) = MATMUL(p%GlbRot,temp6(4:6))
       y%BldForce%Moment(1,i) = temp_cc(2)
       y%BldForce%Moment(2,i) = temp_cc(3)
       y%BldForce%Moment(3,i) = temp_cc(1)
   ENDDO

   !-------------------------------------------------------   
   !  compute RootMxr and RootMyr for ServoDyn and
   !  get values to output to file:  
   !-------------------------------------------------------   
   ! Actuator
   call Calc_WriteOutput( p, AllOuts, y, m, ErrStat2, ErrMsg2 )  !uses m%u2  
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
    
   y%RootMxr = AllOuts( RootMxr )
   y%RootMyr = AllOuts( RootMyr )
   
   !...............................................................................................................................   
   ! Place the selected output channels into the WriteOutput(:) array with the proper sign:
   !...............................................................................................................................   

   do i = 1,p%NumOuts  ! Loop through all selected output channels
      y%WriteOutput(i) = p%OutParam(i)%SignM * AllOuts( p%OutParam(i)%Indx )
   end do             ! i - All selected output channels
      
   
   call cleanup()
   return
   
contains
   subroutine cleanup()
   ! Actuator
      CALL BD_DestroyContState(x_tmp, ErrStat2, ErrMsg2 )
      CALL BD_DestroyOtherState(OS_tmp, ErrStat2, ErrMsg2 )
   end subroutine cleanup 
END SUBROUTINE BD_CalcOutput
!-----------------------------------------------------------------------------------------------------------------------------------
!> Routine for updating discrete states
SUBROUTINE BD_UpdateDiscState( t, n, u, p, x, xd, z, OtherState, m, ErrStat, ErrMsg )

   REAL(DbKi),                        INTENT(IN   )  :: t           !< Current simulation time in seconds
   INTEGER(IntKi),                    INTENT(IN   )  :: n           !< Current step of the simulation: t = n*dt
   TYPE(BD_InputType),                INTENT(IN   )  :: u           !< Inputs at t
   TYPE(BD_ParameterType),            INTENT(IN   )  :: p           !< Parameters
   TYPE(BD_ContinuousStateType),      INTENT(IN   )  :: x           !< Continuous states at t
   TYPE(BD_DiscreteStateType),        INTENT(INOUT)  :: xd          !< Input: Discrete states at t;
                                                                    !!   Output: Discrete states at t + dt
   TYPE(BD_ConstraintStateType),      INTENT(IN   )  :: z           !< Constraint states at t
   TYPE(BD_OtherStateType),           INTENT(IN   )  :: OtherState  !< Other states at t
   TYPE(BD_MiscVarType),              INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   ! local variables
   REAL(BDKi)                                        :: temp_R(3,3) 
   REAL(BDKi)                                        :: Hub_theta_Root(3) 
   REAL(BDKi)                                        :: u_theta_pitch 
   
      ! Initialize ErrStat

      ErrStat = ErrID_None
      ErrMsg  = ""

      ! Update discrete states here:
      
! Actuator
   IF( p%UsePitchAct ) THEN
      !bjj: note that we've cheated a bit here because we have inputs at t+dt
       temp_R = MATMUL(u%RootMotion%Orientation(:,:,1),TRANSPOSE(u%HubMotion%Orientation(:,:,1)))
       Hub_theta_Root = EulerExtract(temp_R)
       u_theta_pitch = -Hub_theta_Root(3)
              
       xd%thetaP  = p%torqM(1,1)*xd%thetaP + p%torqM(1,2)*xd%thetaPD + &
                                           p%torqM(1,2)*(p%pitchK*p%dt/p%pitchJ)*(-Hub_theta_Root(3))
       xd%thetaPD = p%torqM(2,1)*xd%thetaP + p%torqM(2,2)*xd%thetaPD + &
                                             p%torqM(2,2)*(p%pitchK*p%dt/p%pitchJ)*(-Hub_theta_Root(3))
       

   ENDIF
! END Actuator      
      
END SUBROUTINE BD_UpdateDiscState
!-----------------------------------------------------------------------------------------------------------------------------------
!> Routine for solving for the residual of the constraint state equations
SUBROUTINE BD_CalcConstrStateResidual( t, u, p, x, xd, z, OtherState, m, Z_residual, ErrStat, ErrMsg )

   REAL(DbKi),                        INTENT(IN   )  :: t           !< Current simulation time in seconds
   TYPE(BD_InputType),                INTENT(IN   )  :: u           !< Inputs at t
   TYPE(BD_ParameterType),            INTENT(IN   )  :: p           !< Parameters
   TYPE(BD_ContinuousStateType),      INTENT(IN   )  :: x           !< Continuous states at t
   TYPE(BD_DiscreteStateType),        INTENT(IN   )  :: xd          !< Discrete states at t
   TYPE(BD_ConstraintStateType),      INTENT(IN   )  :: z           !< Constraint states at t (possibly a guess)
   TYPE(BD_OtherStateType),           INTENT(IN   )  :: OtherState  !< Other states at t
   TYPE(BD_ConstraintStateType),      INTENT(  OUT)  :: Z_residual  !< Residual of the constraint state equations using
                                                                    !!     the input values described above
   TYPE(BD_MiscVarType),              INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None


   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""


   ! Solve for the constraint states here:

   Z_residual%DummyConstrState = 0

   END SUBROUTINE BD_CalcConstrStateResidual
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine output elemental nodal quantity vector given global quantity vector
SUBROUTINE BD_ElemNodalDisp(uu,node_elem,dof_node,nelem,Nu,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: uu(:) 
   INTEGER(IntKi),INTENT(IN   ):: node_elem 
   INTEGER(IntKi),INTENT(IN   ):: dof_node 
   INTEGER(IntKi),INTENT(IN   ):: nelem 
   REAL(BDKi),    INTENT(  OUT):: Nu(:) 
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi):: i ! Index counter
   INTEGER(IntKi):: j ! Index counter
   INTEGER(IntKi):: temp_id1 ! Counter
   INTEGER(IntKi):: temp_id2 ! Counter

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=1,node_elem
       DO j=1,dof_node
           temp_id1 = (i-1)*dof_node+j
           temp_id2 = ((nelem - 1)*(node_elem-1)+i-1)*dof_node+j
           Nu(temp_id1) = uu(temp_id2)
       ENDDO
   ENDDO

END SUBROUTINE BD_ElemNodalDisp
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the relative rotation at each node 
!! in a finite element with respects to the first node.
SUBROUTINE BD_NodalRelRot(Nu,node_elem,dof_node,Nr,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: Nu(:) 
   INTEGER(IntKi),INTENT(IN   ):: node_elem
   INTEGER(IntKi),INTENT(IN   ):: dof_node
   REAL(BDKi),    INTENT(  OUT):: Nr(:) 
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i 
   INTEGER(IntKi)              :: k
   INTEGER(IntKi)              :: temp_id 
   REAL(BDKi)                  :: Nu_temp1(3)
   REAL(BDKi)                  :: Nu_temp(3)
   REAL(BDKi)                  :: Nr_temp(3)
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_NodalRelRot'

   ErrStat = ErrID_None
   ErrMsg  = ""

   Nr = 0.0_BDKi
   Nu_temp1(:) = 0.0_BDKi
   Nu_temp1(:) = Nu(4:6)
   DO i=1,node_elem
       temp_id = (i - 1) * dof_node
       DO k=1,3
           Nu_temp(k) = Nu(temp_id+k+3)
       ENDDO
       CALL BD_CrvCompose(Nr_temp,Nu_temp1,Nu_temp,1,ErrStat2,ErrMsg2) !This doesn't currently throw an error, so I'm going to ignore it
       DO k=1,3
           temp_id = (i-1)*3+k
           Nr(temp_id) = Nr_temp(k)
       ENDDO
   ENDDO


END SUBROUTINE BD_NodalRelRot
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_ElementMatrixGA2(Nuuu,Nrrr,Nvvv,Naaa,           &
                               EStif0_GL,EMass0_GL,gravity,DistrLoad_GL,&
                               damp_flag,beta,                          &
                               ngp,gw,hhx,hpx,Jaco,uu0,E10,             &
                               node_elem,dof_node,fact,elk,elf,elm,elg, &
                               ErrStat,ErrMsg)

   REAL(BDKi),     INTENT(IN   ):: Nuuu(:)
   REAL(BDKi),     INTENT(IN   ):: Nrrr(:)
   REAL(BDKi),     INTENT(IN   ):: Nvvv(:)
   REAL(BDKi),     INTENT(IN   ):: Naaa(:)
   REAL(BDKi),     INTENT(IN   ):: EStif0_GL(:,:,:)
   REAL(BDKi),     INTENT(IN   ):: EMass0_GL(:,:,:)
   REAL(BDKi),     INTENT(IN   ):: gravity(:)
   REAL(BDKi),     INTENT(IN   ):: DistrLoad_GL(:,:)
   INTEGER(IntKi), INTENT(IN   ):: damp_flag
   REAL(BDKi),     INTENT(IN   ):: beta(:)
   INTEGER(IntKi), INTENT(IN   ):: ngp
   REAL(BDKi),     INTENT(IN   ):: gw(:)
   REAL(BDKi),     INTENT(IN   ):: hhx(:,:)
   REAL(BDKi),     INTENT(IN   ):: hpx(:,:)
   REAL(BDKi),     INTENT(IN   ):: Jaco(:)
   REAL(BDKi),     INTENT(IN   ):: uu0(:)
   REAL(BDKi),     INTENT(IN   ):: E10(:)
   INTEGER(IntKi), INTENT(IN   ):: node_elem
   INTEGER(IntKi), INTENT(IN   ):: dof_node
   LOGICAL,        INTENT(IN   ):: fact
   REAL(BDKi),     INTENT(  OUT):: elk(:,:)
   REAL(BDKi),     INTENT(  OUT):: elf(:)
   REAL(BDKi),     INTENT(  OUT):: elm(:,:)
   REAL(BDKi),     INTENT(  OUT):: elg(:,:)
   INTEGER(IntKi), INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),   INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                   :: RR0(3,3)
   REAL(BDKi)                   :: kapa(3)
   REAL(BDKi)                   :: E1(3)
   REAL(BDKi)                   :: Stif(6,6)
   REAL(BDKi)                   :: cet
   REAL(BDKi)                   :: uuu(6)
   REAL(BDKi)                   :: uup(3)
   REAL(BDKi)                   :: Fc(6)
   REAL(BDKi)                   :: Fd(6)
   REAL(BDKi)                   :: Fg(6)
   REAL(BDKi)                   :: Oe(6,6)
   REAL(BDKi)                   :: Pe(6,6)
   REAL(BDKi)                   :: Qe(6,6)
   REAL(BDKi)                   :: Sd(6,6)
   REAL(BDKi)                   :: Od(6,6)
   REAL(BDKi)                   :: Pd(6,6)
   REAL(BDKi)                   :: Qd(6,6)
   REAL(BDKi)                   :: betaC(6,6)
   REAL(BDKi)                   :: Gd(6,6)
   REAL(BDKi)                   :: Xd(6,6)
   REAL(BDKi)                   :: Yd(6,6)
   REAL(BDKi)                   :: vvv(6)
   REAL(BDKi)                   :: vvp(6)
   REAL(BDKi)                   :: aaa(6)
   REAL(BDKi)                   :: mmm
   REAL(BDKi)                   :: mEta(3)
   REAL(BDKi)                   :: rho(3,3)
   REAL(BDKi)                   :: Fi(6)
   REAL(BDKi)                   :: Mi(6,6)
   REAL(BDKi)                   :: Ki(6,6)
   REAL(BDKi)                   :: Gi(6,6)
   INTEGER(IntKi)               :: igp
   INTEGER(IntKi)               :: i
   INTEGER(IntKi)               :: j
   INTEGER(IntKi)               :: m
   INTEGER(IntKi)               :: n
   INTEGER(IntKi)               :: temp_id1
   INTEGER(IntKi)               :: temp_id2
   INTEGER(IntKi)               :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)         :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER      :: RoutineName = 'BD_ElementMatrixGA2'

   ErrStat  = ErrID_None
   ErrMsg   = ""
   elk(:,:) = 0.0_BDKi
   elf(:)   = 0.0_BDKi
   elg(:,:) = 0.0_BDKi
   elm(:,:) = 0.0_BDKi

   DO igp=1,ngp

       temp_id1 = (igp-1)*dof_node
       temp_id2 = (igp-1)*dof_node/2
       Stif(1:6,1:6) = EStif0_GL(1:6,1:6,igp)
       CALL BD_GaussPointData(hhx(:,igp),hpx(:,igp),Jaco(igp),Nuuu,Nrrr,&
             uu0(temp_id1+1:temp_id1+6),E10(temp_id2+1:temp_id2+3),node_elem,dof_node,&
             uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       mmm          =  EMass0_GL(1,1,igp)
       mEta(1)      =  0.0_BDKi
       mEta(2)      = -EMass0_GL(1,6,igp)
       mEta(3)      =  EMass0_GL(1,5,igp)
       rho          =  EMass0_GL(4:6,4:6,igp)
       CALL BD_GaussPointDataMass(hhx(:,igp),hpx(:,igp),Jaco(igp),Nvvv,Naaa,RR0,node_elem,dof_node,&
                                  vvv,aaa,vvp,mEta,rho,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_InertialForce(mmm,mEta,rho,vvv,aaa,fact,Fi,Mi,Gi,Ki,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(damp_flag .NE. 0) THEN
           CALL BD_DissipativeForce(beta,Stif,vvv,vvp,E1,fact,Fc,Fd,Sd,Od,Pd,Qd,&
                                    betaC,Gd,Xd,Yd,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDIF
       CALL BD_GravityForce(mmm,mEta,gravity,Fg,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       Fd(:) = Fd(:) - Fg(:) - DistrLoad_GL(:,igp)

       IF(fact) THEN
           DO i=1,node_elem
               DO j=1,node_elem
                  DO n=1,dof_node
                     temp_id2 = (j-1)*dof_node+n
                        DO m=1,dof_node
                           temp_id1 = (i-1)*dof_node+m
                           elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                              hhx(i,igp)*Qe(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                           elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                              hhx(i,igp)*Pe(m,n)*hpx(j,igp)*gw(igp)
                           elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                              hpx(i,igp)*Oe(m,n)*hhx(j,igp)*gw(igp)
                           elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                              hpx(i,igp)*Stif(m,n)*hpx(j,igp)*gw(igp)/Jaco(igp)
                           elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                              hhx(i,igp)*Ki(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                           elm(temp_id1,temp_id2) = elm(temp_id1,temp_id2) + &
                              hhx(i,igp)*Mi(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                           elg(temp_id1,temp_id2) = elg(temp_id1,temp_id2) + &
                              hhx(i,igp)*Gi(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                       ENDDO
                   ENDDO
               ENDDO
           ENDDO

           IF(damp_flag .NE. 0) THEN
               DO i=1,node_elem
                   DO j=1,node_elem
                      DO n=1,dof_node
                         temp_id2 = (j-1)*dof_node+n
                            DO m=1,dof_node
                               temp_id1 = (i-1)*dof_node+m
                                   elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                                      hhx(i,igp)*Qd(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                                   elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                                      hhx(i,igp)*Pd(m,n)*hpx(j,igp)*gw(igp)
                                   elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                                      hpx(i,igp)*Od(m,n)*hhx(j,igp)*gw(igp)
                                   elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                                      hpx(i,igp)*Sd(m,n)*hpx(j,igp)*gw(igp)/Jaco(igp)
                                   elg(temp_id1,temp_id2) = elg(temp_id1,temp_id2) + &
                                      hhx(i,igp)*Xd(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                                   elg(temp_id1,temp_id2) = elg(temp_id1,temp_id2) + &
                                      hhx(i,igp)*Yd(m,n)*hpx(j,igp)*gw(igp)
                                   elg(temp_id1,temp_id2) = elg(temp_id1,temp_id2) + &
                                      hpx(i,igp)*Gd(m,n)*hhx(j,igp)*gw(igp)
                                   elg(temp_id1,temp_id2) = elg(temp_id1,temp_id2) + &
                                      hpx(i,igp)*betaC(m,n)*hpx(j,igp)*gw(igp)/Jaco(igp)
                           ENDDO
                       ENDDO
                   ENDDO
               ENDDO
           ENDIF
 
       ENDIF

       DO i=1,node_elem
           DO j=1,dof_node
               temp_id1 = (i-1) * dof_node+j
               elf(temp_id1) = elf(temp_id1) - hhx(i,igp)*Fd(j)*Jaco(igp)*gw(igp)
               elf(temp_id1) = elf(temp_id1) - hpx(i,igp)*Fc(j)*gw(igp)
               elf(temp_id1) = elf(temp_id1) - hhx(i,igp)*Fi(j)*Jaco(igp)*gw(igp)
           ENDDO
       ENDDO


   ENDDO

   if (ErrStat >= AbortErrLev) then
       return
   end if

   RETURN

END SUBROUTINE BD_ElementMatrixGA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes initial Gauss point values: uu0, E10, and Stif
SUBROUTINE BD_GaussPointDataAt0(hhx,hpx,Jaco,Nuu0,Nrr0,node_elem,dof_node,uu0,E10,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: hhx(:)         !< Shape function
   REAL(BDKi),    INTENT(IN   ):: hpx(:)         !< Derivative of shape function
   REAL(BDKi),    INTENT(IN   ):: Jaco           !< Jacobian value
   REAL(BDKi),    INTENT(IN   ):: Nuu0(:)        !< Element initial nodal position array
   REAL(BDKi),    INTENT(IN   ):: Nrr0(:)        !< Element initial nodal relative rotation array
   INTEGER(IntKi),INTENT(IN   ):: node_elem      !< Number of node in one element
   INTEGER(IntKi),INTENT(IN   ):: dof_node       !< DoF per node (=6)
   REAL(BDKi),    INTENT(  OUT):: uu0(:)         !< Initial position array at Gauss point
   REAL(BDKi),    INTENT(  OUT):: E10(:)         !< E10 = x_0^\prime at Gauss point
   INTEGER(IntKi),INTENT(  OUT):: ErrStat        !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg         !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: hhi
   REAL(BDKi)                  :: hpi
   REAL(BDKi)                  :: rot0_temp(3)
   REAL(BDKi)                  :: rotu_temp(3)
   REAL(BDKi)                  :: rot_temp(3)
   REAL(BDKi)                  :: R0_temp(3,3)
   INTEGER(IntKi)              :: inode
   INTEGER(IntKi)              :: temp_id
   INTEGER(IntKi)              :: temp_id2
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_GaussPointDataAt0'

   ErrStat = ErrID_None
   ErrMsg  = ""

   uu0(:) = 0.0_BDKi
   E10(:) = 0.0_BDKi
   DO inode=1,node_elem
       hhi = hhx(inode)
       hpi = hpx(inode)/Jaco
       temp_id = (inode-1)*dof_node
       temp_id2 = (inode-1)*dof_node/2
       DO i=1,3
           uu0(i) = uu0(i) + hhi*Nuu0(temp_id+i)
           uu0(i+3) = uu0(i+3) + hhi*Nrr0(temp_id2+i)
!           E10(i) = E10(i) + hpi*Nuu0(temp_id+i)
       ENDDO
   ENDDO

   rot0_temp = 0.0_BDKi
   rotu_temp = 0.0_BDKi
   DO i=1,3
       rot0_temp(i) = Nuu0(i+3)
       rotu_temp(i) = uu0(i+3)
   ENDDO
   rot_temp = 0.0_BDKi
   CALL BD_CrvCompose(rot_temp,rot0_temp,rotu_temp,0,ErrStat2,ErrMsg2)
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   DO i=1,3
       uu0(i+3) = rot_temp(i)
   ENDDO

   R0_temp = 0.0_BDKi
   CALL BD_CrvMatrixR(uu0(4:6),R0_temp,ErrStat2,ErrMsg2)
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   E10(:) = R0_temp(:,1)

END SUBROUTINE BD_GaussPointDataAt0
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes Gauss point values: 1) uuu, 2) uup, 3) E1
!! 4) RR0, 5) kapa, 6) Stif, and 7) cet
SUBROUTINE BD_GaussPointData(hhx,hpx,Jaco,Nuuu,Nrrr,uu0,E10,node_elem,dof_node,&
                             uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: hhx(:)      !< Shape function
   REAL(BDKi),    INTENT(IN   ):: hpx(:)      !< Derivative of shape function
   REAL(BDKi),    INTENT(IN   ):: Jaco        !< Jacobian
   REAL(BDKi),    INTENT(IN   ):: Nuuu(:)     !< Element nodal displacement array
   REAL(BDKi),    INTENT(IN   ):: Nrrr(:)     !< Element nodal relative rotation array
   REAL(BDKi),    INTENT(IN   ):: uu0(:)      !< Initial position array at Gauss point
   REAL(BDKi),    INTENT(IN   ):: E10(:)      !< E10 = x_0^\prime at Gauss point
   INTEGER(IntKi),INTENT(IN   ):: node_elem   !< Number of node in one element
   INTEGER(IntKi),INTENT(IN   ):: dof_node    !< Number of DoF per node (=6)
   REAL(BDKi),    INTENT(  OUT):: uuu(:)      !< Displacement(and rotation)  arrary at Gauss point
   REAL(BDKi),    INTENT(  OUT):: uup(:)      !< Derivative of displacement wrt axix at Gauss point
   REAL(BDKi),    INTENT(  OUT):: E1(:)       !< E1 = x_0^\prime + u^\prime at Gauss point
   REAL(BDKi),    INTENT(  OUT):: RR0(:,:)    !< Rotation tensor at Gauss point
   REAL(BDKi),    INTENT(  OUT):: kapa(:)     !< Curvature starin vector at Gauss point
   REAL(BDKi),    INTENT(  OUT):: cet         !< Extension-torsion coefficient at Gauss point
   REAL(BDKi),    INTENT(  OUT):: Stif(:,:)   !< C/S stiffness matrix resolved in inertial frame at Gauss point
   INTEGER(IntKi),INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: rrr(3)
   REAL(BDKi)                  :: rrp(3)
   REAL(BDKi)                  :: hhi
   REAL(BDKi)                  :: hpi
   REAL(BDKi)                  :: cc(3)
   REAL(BDKi)                  :: rotu_temp(3)
   REAL(BDKi)                  :: rot_temp(3)
   REAL(BDKi)                  :: rot0_temp(3)
   REAL(BDKi)                  :: Wrk(3,3)
   REAL(BDKi)                  :: tempR6(6,6)
   INTEGER(IntKi)              :: inode
   INTEGER(IntKi)              :: temp_id
   INTEGER(IntKi)              :: temp_id2
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_GaussPointData'

   ErrStat = ErrID_None
   ErrMsg  = ""

   uuu = 0.0_BDKi
   uup = 0.0_BDKi
   rrr = 0.0_BDKi
   rrp = 0.0_BDKi
   DO inode=1,node_elem
       hhi = hhx(inode)
       hpi = hpx(inode)/Jaco
       temp_id = (inode-1)*dof_node
       temp_id2 = (inode-1)*dof_node/2
       DO i=1,3
           uuu(i) = uuu(i) + hhi*Nuuu(temp_id+i)
           uup(i) = uup(i) + hpi*Nuuu(temp_id+i)
           rrr(i) = rrr(i) + hhi*Nrrr(temp_id2+i)
           rrp(i) = rrp(i) + hpi*Nrrr(temp_id2+i)
       ENDDO
   ENDDO

   E1 = 0.0_BDKi
   rotu_temp = 0.0_BDKi
   DO i=1,3
       E1(i) = E10(i) + uup(i)
       rotu_temp(i) = Nuuu(i+3)
   ENDDO
   rot_temp(:)  = 0.0_BDKi
   rot0_temp(:) = 0.0_BDKi
   CALL BD_CrvCompose(rot_temp,rotu_temp,rrr,0,ErrStat2,ErrMsg2)
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   DO i=1,3
       uuu(i+3) = rot_temp(i)
       rot0_temp(i) = uu0(i+3)
   ENDDO

   cc = 0.0_BDKi
   RR0 = 0.0_BDKi
   CALL BD_CrvCompose(cc,rot_temp,rot0_temp,0,ErrStat2,ErrMsg2)
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CrvMatrixR(cc,RR0,ErrStat2,ErrMsg2)
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   tempR6 = 0.0_BDKi
   DO i=1,3
       DO j=1,3
           tempR6(i,j) = RR0(i,j)
           tempR6(i+3,j+3) = RR0(i,j)
       ENDDO
   ENDDO

   cet = 0.0_BDKi
   cet = Stif(5,5) + Stif(6,6)
   Stif = MATMUL(tempR6,MATMUL(Stif,TRANSPOSE(tempR6)))

   Wrk = 0.0_BDKi
   kapa = 0.0_BDKi
   CALL BD_CrvMatrixH(rrr,Wrk)
   cc = MATMUL(Wrk,rrp)
   CALL BD_CrvMatrixR(rotu_temp,Wrk,ErrStat2,ErrMsg2)
   kapa = MATMUL(Wrk,cc)

END SUBROUTINE BD_GaussPointData
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the elastic forces Fc and Fd
!! It also calcuates the linearized matrices Oe, Pe, and Qe for N-R algorithm
SUBROUTINE BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: E1(:)
   REAL(BDKi),    INTENT(IN   ):: RR0(:,:)
   REAL(BDKi),    INTENT(IN   ):: kapa(:)
   REAL(BDKi),    INTENT(IN   ):: Stif(:,:)
   REAL(BDKi),    INTENT(IN   ):: cet
   LOGICAL,       INTENT(IN   ):: fact
   REAL(BDKi),    INTENT(  OUT):: Fc(:)
   REAL(BDKi),    INTENT(  OUT):: Fd(:)
   REAL(BDKi),    INTENT(  OUT):: Oe(:,:)
   REAL(BDKi),    INTENT(  OUT):: Pe(:,:)
   REAL(BDKi),    INTENT(  OUT):: Qe(:,:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: eee(6)
   REAL(BDKi)                  :: fff(6)
   REAL(BDKi)                  :: tempS(3)
   REAL(BDKi)                  :: tempK(3)
   REAL(BDKi)                  :: Wrk(3)
   REAL(BDKi)                  :: e1s
   REAL(BDKi)                  :: k1s
   REAL(BDKi)                  :: Wrk33(3,3)
   REAL(BDKi)                  :: C11(3,3)
   REAL(BDKi)                  :: C12(3,3)
   REAL(BDKi)                  :: C21(3,3)
   REAL(BDKi)                  :: C22(3,3)
   REAL(BDKi)                  :: epsi(3,3)
   REAL(BDKi)                  :: mu(3,3)
   INTEGER(IntKi)              :: i

   ErrStat = ErrID_None
   ErrMsg  = ""

   eee(:)   = 0.0_BDKi
   tempS(:) = 0.0_BDKi
   tempK(:) = 0.0_BDKi
   DO i=1,3
       eee(i) = E1(i) - RR0(i,1)
       eee(i+3) = kapa(i)

       tempS(i) = eee(i)
       tempK(i) = eee(i+3)
   ENDDO
   fff = 0.0_BDKi
   fff = MATMUL(Stif,eee)

   Wrk(:) = 0.0_BDKi
   Wrk(:) = MATMUL(TRANSPOSE(RR0),tempS)
   e1s = Wrk(1)      !epsilon_{11} in material basis

   Wrk(:) = 0.0_BDKi
   Wrk(:) = MATMUL(TRANSPOSE(RR0),tempK)
   k1s = Wrk(1)      !kapa_{1} in material basis

   ! Incorporate extension-twist coupling
   DO i=1,3
       fff(i) = fff(i) + 0.5_BDKi*cet*k1s*k1s*RR0(i,1)
       fff(i+3) = fff(i+3) + cet*e1s*k1s*RR0(i,1)
   ENDDO

   Fc(:)    = 0.0_BDKi
   Fc(:)    = fff(:)
   Wrk(:)   = 0.0_BDKi
   Wrk(1:3) = fff(1:3)
   Fd(:)    = 0.0_BDKi
   Fd(4:6)  = MATMUL(TRANSPOSE(BD_Tilde(E1)),Wrk)

   IF(fact) THEN
       C11(:,:) = 0.0_BDKi
       C12(:,:) = 0.0_BDKi
       C21(:,:) = 0.0_BDKi
       C22(:,:) = 0.0_BDKi
       C11(1:3,1:3) = Stif(1:3,1:3)
       C12(1:3,1:3) = Stif(1:3,4:6)
       C21(1:3,1:3) = Stif(4:6,1:3)
       C22(1:3,1:3) = Stif(4:6,4:6)

       Wrk = 0.0_BDKi
       DO i=1,3
           Wrk(i) = RR0(i,1)
       ENDDO
       Wrk33(:,:) = 0.0_BDKi
       Wrk33(:,:) = OuterProduct(Wrk,Wrk)
       C12(:,:) = C12(:,:) + cet*k1s*Wrk33(:,:) 
       C21(:,:) = C21(:,:) + cet*k1s*Wrk33(:,:)
       C22(:,:) = C22(:,:) + cet*e1s*Wrk33(:,:)

       epsi(:,:) = 0.0_BDKi
       mu(:,:)   = 0.0_BDKi
       epsi(:,:) = MATMUL(C11,BD_Tilde(E1))
       mu(:,:)   = MATMUL(C21,BD_Tilde(E1))

       Wrk(:) = 0.0_BDKi
       Oe(:,:)     = 0.0_BDKi
       Oe(1:3,4:6) = epsi(1:3,1:3)
       Oe(4:6,4:6) = mu(1:3,1:3)

       Wrk(1:3) = fff(1:3)
       Oe(1:3,4:6) = Oe(1:3,4:6) - BD_Tilde(Wrk)
       Wrk(:) = 0.0_BDKi
       Wrk(1:3) = fff(4:6)
       Oe(4:6,4:6) = Oe(4:6,4:6) - BD_Tilde(Wrk)

       Wrk(: ) = 0.0_BDKi
       Pe(:,:) = 0.0_BDKi
       Wrk(1:3) = fff(1:3)
       Pe(4:6,1:3) = BD_Tilde(Wrk) + TRANSPOSE(epsi)
       Pe(4:6,4:6) = TRANSPOSE(mu)

       Wrk33(:,:) = 0.0_BDKi
       Qe(:,:)    = 0.0_BDKi
       Wrk33(1:3,1:3) = Oe(1:3,4:6)
       Qe(4:6,4:6) = MATMUL(TRANSPOSE(BD_Tilde(E1)),Wrk33)
   ENDIF

END SUBROUTINE BD_ElasticForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the mass quantities at the Gauss point
!! 1) velocity; 2) acceleration; 3) derivative of velocity wrt axis
!! 4) mass matrix components (mmm,mEta,rho)
SUBROUTINE BD_GaussPointDataMass(hhx,hpx,Jaco,Nvvv,Naaa,RR0,node_elem,dof_node,&
                                 vvv,aaa,vvp,mEta,rho,ErrStat,ErrMsg)
   REAL(BDKi),     INTENT(IN   ):: hhx(:)
   REAL(BDKi),     INTENT(IN   ):: hpx(:)
   REAL(BDKi),     INTENT(IN   ):: Jaco
   REAL(BDKi),     INTENT(IN   ):: Nvvv(:)
   REAL(BDKi),     INTENT(IN   ):: Naaa(:)
   REAL(BDKi),     INTENT(IN   ):: RR0(:,:)
   INTEGER(IntKi), INTENT(IN   ):: node_elem
   INTEGER(IntKi), INTENT(IN   ):: dof_node
   REAL(BDKi),     INTENT(  OUT):: vvv(:)
   REAL(BDKi),     INTENT(  OUT):: vvp(:)
   REAL(BDKi),     INTENT(  OUT):: aaa(:)
   REAL(BDKi),     INTENT(INOUT):: mEta(:)
   REAL(BDKi),     INTENT(INOUT):: rho(:,:)
   INTEGER(IntKi), INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),   INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                   :: hhi
   REAL(BDKi)                   :: hpi
   INTEGER(IntKi)               :: inode
   INTEGER(IntKi)               :: temp_id
   INTEGER(IntKi)               :: i

   ErrStat = ErrID_None
   ErrMsg  = ""
   vvv(:) = 0.0_BDKi
   vvp(:) = 0.0_BDKi
   aaa(:) = 0.0_BDKi

   DO inode=1,node_elem
       hhi = hhx(inode)
       hpi = hpx(inode)/Jaco
       temp_id = (inode-1)*dof_node
       DO i=1,dof_node
           vvv(i) = vvv(i) + hhi * Nvvv(temp_id+i)
           vvp(i) = vvp(i) + hpi * Nvvv(temp_id+i)
           aaa(i) = aaa(i) + hhi * Naaa(temp_id+i)
       ENDDO
   ENDDO

   mEta = MATMUL(RR0,mEta)
   rho = MATMUL(RR0,MATMUL(rho,TRANSPOSE(RR0)))

END SUBROUTINE BD_GaussPointDataMass
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the inertial force Fi
!! It also calcuates the linearized matrices Mi, Gi, and Ki for N-R algorithm
SUBROUTINE BD_InertialForce(m00,mEta,rho,vvv,aaa,fact,Fi,Mi,Gi,Ki,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: m00
   REAL(BDKi),    INTENT(IN   ):: mEta(:)
   REAL(BDKi),    INTENT(IN   ):: rho(:,:)
   REAL(BDKi),    INTENT(IN   ):: vvv(:)
   REAL(BDKi),    INTENT(IN   ):: aaa(:)
   LOGICAL,       INTENT(IN   ):: fact
   REAL(BDKi),    INTENT(  OUT):: Fi(6)
   REAL(BDKi),    INTENT(  OUT):: Mi(6,6)
   REAL(BDKi),    INTENT(  OUT):: Gi(6,6)
   REAL(BDKi),    INTENT(  OUT):: Ki(6,6)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: beta(3)
   REAL(BDKi)                  :: gama(3)
   REAL(BDKi)                  :: nu(3)
   REAL(BDKi)                  :: epsi(3,3)
   REAL(BDKi)                  :: mu(3,3)
   REAL(BDKi)                  :: ome(3)
   REAL(BDKi)                  :: omd(3)
   REAL(BDKi)                  :: tempV(3)
   REAL(BDKi)                  :: tempA(3)
   INTEGER(IntKi)              :: i

   ErrStat = ErrID_None
   ErrMsg  = ""
   Fi(:)   = 0.0_BDKi
   Mi(:,:) = 0.0_BDKi
   Gi(:,:) = 0.0_BDKi
   Ki(:,:) = 0.0_BDKi

   ome(:) = vvv(4:6)
   omd(:) = aaa(4:6)
   tempV(:) = vvv(1:3)
   tempA(:) = aaa(1:3)

   beta = MATMUL(BD_Tilde(ome),mEta)
   gama = MATMUL(rho,ome)
   nu = MATMUL(rho,omd)

   !Compute Fi
   Fi(1:3)= m00*tempA+MATMUL(BD_Tilde(omd),mEta)+MATMUL(BD_Tilde(ome),beta)
   Fi(4:6) = MATMUL(BD_Tilde(mEta),tempA) + nu + MATMUL(BD_Tilde(ome),gama)

   IF(fact) THEN
       !Mass Matrix
       Mi = 0.0_BDKi
       DO i=1,3
           Mi(i,i) = m00
       ENDDO
       Mi(1:3,4:6) = TRANSPOSE(BD_Tilde(mEta))
       Mi(4:6,1:3) = BD_Tilde(mEta)
       Mi(4:6,4:6) = rho

       !Gyroscopic Matrix
       Gi = 0.0_BDKi
       epsi = MATMUL(BD_Tilde(ome),rho)
       mu = MATMUL(BD_Tilde(ome),TRANSPOSE(BD_Tilde(mEta)))
       Gi(1:3,4:6) = TRANSPOSE(BD_Tilde(beta)) + mu
       Gi(4:6,4:6) = epsi - BD_Tilde(gama)

       !Stiffness Matrix
       Ki = 0.0_BDKi
       Ki(1:3,4:6) = MATMUL(BD_Tilde(omd),TRANSPOSE(BD_Tilde(mEta))) +&
                    &MATMUL(BD_Tilde(ome),mu)
       Ki(4:6,4:6) = MATMUL(BD_Tilde(tempA),BD_Tilde(mEta)) + &
                    &MATMUL(rho,BD_Tilde(omd)) - BD_Tilde(nu) +&
                    &MATMUL(epsi,BD_Tilde(ome)) - &
                    &MATMUL(BD_Tilde(ome),BD_Tilde(gama))
   ENDIF

END SUBROUTINE BD_InertialForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the dissipative forces and added it to Fc and Fd
!! It also calcuates the linearized matrices Sd, Od, Pd and Qd 
!! betaC, Gd, Xd, Yd for N-R algorithm
SUBROUTINE BD_DissipativeForce(beta,Stiff,vvv,vvp,E1,fact,Fc,Fd,&
                                  Sd,Od,Pd,Qd,betaC,Gd,Xd,Yd, &
                                  ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: beta(:)
   REAL(BDKi),    INTENT(IN   ):: Stiff(:,:)
   REAL(BDKi),    INTENT(IN   ):: vvv(:)
   REAL(BDKi),    INTENT(IN   ):: vvp(:)
   REAL(BDKi),    INTENT(IN   ):: E1(:)
   LOGICAL,       INTENT(IN   ):: fact
   REAL(BDKi),    INTENT(INOUT):: Fc(:)
   REAL(BDKi),    INTENT(INOUT):: Fd(:)
   REAL(BDKi),    INTENT(  OUT):: Sd(:,:)
   REAL(BDKi),    INTENT(  OUT):: Od(:,:)
   REAL(BDKi),    INTENT(  OUT):: Pd(:,:)
   REAL(BDKi),    INTENT(  OUT):: Qd(:,:)
   REAL(BDKi),    INTENT(  OUT):: betaC(:,:)
   REAL(BDKi),    INTENT(  OUT):: Gd(:,:)
   REAL(BDKi),    INTENT(  OUT):: Xd(:,:)
   REAL(BDKi),    INTENT(  OUT):: Yd(:,:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: ome(3)
   REAL(BDKi)                  :: eed(6)
   REAL(BDKi)                  :: ffd(6)
   REAL(BDKi)                  :: D11(3,3)
   REAL(BDKi)                  :: D12(3,3)
   REAL(BDKi)                  :: D21(3,3)
   REAL(BDKi)                  :: D22(3,3)
   REAL(BDKi)                  :: b11(3,3)
   REAL(BDKi)                  :: b12(3,3)
   REAL(BDKi)                  :: alpha(3,3)
   REAL(BDKi)                  :: temp_b(6,6)
   INTEGER(IntKi)              :: i

   ErrStat    = ErrID_None
   ErrMsg     = ""
   Sd(:,:)    = 0.0_BDKi
   Od(:,:)    = 0.0_BDKi
   Pd(:,:)    = 0.0_BDKi
   Qd(:,:)    = 0.0_BDKi
   betaC(:,:) = 0.0_BDKi
   Gd(:,:)    = 0.0_BDKi
   Xd(:,:)    = 0.0_BDKi
   Yd(:,:)    = 0.0_BDKi

   ome(1:3) = vvv(4:6)
   ! Compute strain rates
   eed(1:6) = vvp(1:6)
   eed(1:3) = eed(1:3) + MATMUL(BD_Tilde(E1),ome)

   ! Compute damping matrix
   temp_b(:,:) = 0.0_BDKi
   DO i=1,6
       temp_b(i,i) = beta(i)
   ENDDO
   betaC(1:6,1:6) = MATMUL(temp_b,Stiff(:,:))
   D11(1:3,1:3) = betaC(1:3,1:3)
   D12(1:3,1:3) = betaC(1:3,4:6)
   D21(1:3,1:3) = betaC(4:6,1:3)
   D22(1:3,1:3) = betaC(4:6,4:6)

   ! Compute dissipative force
   ffd(1:6) = MATMUL(betaC,eed)
   Fc(1:6) = Fc(1:6) + ffd(1:6)
   Fd(4:6) = Fd(4:6) + MATMUL(BD_Tilde(ffd(1:3)),E1)

   IF(fact) THEN
       ! Compute stiffness matrix Sd
       Sd(1:3,1:3) = MATMUL(D11,TRANSPOSE(BD_Tilde(ome)))
       Sd(1:3,4:6) = MATMUL(D12,TRANSPOSE(BD_Tilde(ome)))
       Sd(4:6,1:3) = MATMUL(D21,TRANSPOSE(BD_Tilde(ome)))
       Sd(4:6,4:6) = MATMUL(D22,TRANSPOSE(BD_Tilde(ome)))

       ! Compute stiffness matrix Pd
       Pd(:,:) = 0.0_BDKi
       b11(1:3,1:3) = MATMUL(TRANSPOSE(BD_Tilde(E1)),D11)
       b12(1:3,1:3) = MATMUL(TRANSPOSE(BD_Tilde(E1)),D12)
       Pd(4:6,1:3) = BD_Tilde(ffd(1:3)) + MATMUL(b11,TRANSPOSE(BD_Tilde(ome)))
       Pd(4:6,1:3) = MATMUL(b12,TRANSPOSE(BD_Tilde(ome)))

       ! Compute stiffness matrix Od
       alpha(1:3,1:3) = BD_Tilde(vvp(1:3)) - MATMUL(BD_Tilde(ome),BD_Tilde(E1))
       Od(1:3,4:6) = MATMUL(D11,alpha) - BD_Tilde(ffd(1:3))
       Od(4:6,4:6) = MATMUL(D21,alpha) - BD_Tilde(ffd(4:6))

       ! Compute stiffness matrix Qd
       Qd(4:6,4:6) = MATMUL(TRANSPOSE(BD_Tilde(E1)),Od(1:3,4:6))

       ! Compute gyroscopic matrix Gd
       Gd(1:3,4:6) = TRANSPOSE(b11)
       Gd(4:6,4:6) = TRANSPOSE(b12)

       ! Compute gyroscopic matrix Xd
       Xd(4:6,4:6) = MATMUL(TRANSPOSE(BD_Tilde(E1)),Gd(1:3,4:6))

       ! Compute gyroscopic matrix Yd
       Yd(4:6,1:3) = b11
       Yd(4:6,4:6) = b12
   ENDIF

END SUBROUTINE BD_DissipativeForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the gravity forces Fg
SUBROUTINE BD_GravityForce(m00,mEta,grav,Fg,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: m00
   REAL(BDKi),    INTENT(IN   ):: mEta(:)
   REAL(BDKi),    INTENT(IN   ):: grav(:)
   REAL(BDKi),    INTENT(  OUT):: Fg(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   ErrStat = ErrID_None
   ErrMsg  = ""
   Fg(:)   = 0.0_BDKi

   Fg(1:3) = m00 * grav(1:3)
   Fg(4:6) = MATMUL(BD_Tilde(mEta),grav)

END SUBROUTINE BD_GravityForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine assembles total stiffness matrix.
SUBROUTINE BD_AssembleStiffK(nelem,node_elem,dof_elem,dof_node,ElemK,GlobalK,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: ElemK(:,:)    !< Element  matrix
   INTEGER(IntKi),INTENT(IN   ):: nelem         !< Number of elements
   INTEGER(IntKi),INTENT(IN   ):: node_elem     !< Nodes per element
   INTEGER(IntKi),INTENT(IN   ):: dof_elem      !< Degrees of freedom per element
   INTEGER(IntKi),INTENT(IN   ):: dof_node      !< Degrees of freedom per node
   REAL(BDKi),    INTENT(INOUT):: GlobalK(:,:)  !< Global stiffness matrix
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: temp_id1
   INTEGER(IntKi)              :: temp_id2

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=1,dof_elem
       temp_id1 = (nelem-1)*(node_elem-1)*dof_node+i
       DO j=1,dof_elem
           temp_id2 = (nelem-1)*(node_elem-1)*dof_node+j
           GlobalK(temp_id1,temp_id2) = GlobalK(temp_id1,temp_id2) + ElemK(i,j)
       ENDDO
   ENDDO

END SUBROUTINE BD_AssembleStiffK
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine assembles global force vector.
SUBROUTINE BD_AssembleRHS(nelem,dof_elem,node_elem,dof_node,ElemRHS,GlobalRHS,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: ElemRHS(:)    !< Total element force (Fc, Fd, Fb)
   INTEGER(IntKi),INTENT(IN   ):: nelem         !< Number of elements
   INTEGER(IntKi),INTENT(IN   ):: dof_elem      !< Degrees of freedom per element
   INTEGER(IntKi),INTENT(IN   ):: node_elem     !< Nodes per element
   INTEGER(IntKi),INTENT(IN   ):: dof_node      !< Degrees of freedom per node
   REAL(BDKi),    INTENT(INOUT):: GlobalRHS(:)  !< Global force vector
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: temp_id

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=1,dof_elem
       temp_id = (nelem-1)*(node_elem-1)*dof_node+i
       GlobalRHS(temp_id) = GlobalRHS(temp_id)+ElemRHS(i)
   ENDDO

END SUBROUTINE BD_AssembleRHS
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine updates the 1) displacements/rotations(uf)
!! 2) linear/angular velocities(vf); 3) linear/angular accelerations(af); and 
!! 4) algorithmic accelerations(xf) given the increments obtained through
!! N-R algorithm
SUBROUTINE BD_UpdateDynamicGA2(ainc,uf,vf,af,xf,coef,node_total,dof_node,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: ainc(:)
   REAL(DbKi),    INTENT(IN   ):: coef(:)
   INTEGER(IntKi),INTENT(IN   ):: node_total
   INTEGER(IntKi),INTENT(IN   ):: dof_node
   REAL(BDKi),    INTENT(INOUT):: uf(:)
   REAL(BDKi),    INTENT(INOUT):: vf(:)
   REAL(BDKi),    INTENT(INOUT):: af(:)
   REAL(BDKi),    INTENT(INOUT):: xf(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: rotf_temp(3)
   REAL(BDKi)                  :: roti_temp(3)
   REAL(BDKi)                  :: rot_temp(3)
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: temp_id
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_UpdateDynamicGA2'

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=2, node_total
       temp_id = (i - 1) * dof_node
       rotf_temp = 0.0_BDKi
       roti_temp = 0.0_BDKi
       rot_temp = 0.0_BDKi
       DO j = 1, 3
           uf(temp_id+j) = uf(temp_id+j) + coef(8) * ainc(temp_id+j)
           rotf_temp(j) = uf(temp_id+3+j)
           roti_temp(j) = coef(8) * ainc(temp_id+3+j)
       ENDDO
       CALL BD_CrvCompose(rot_temp,roti_temp,rotf_temp,0,ErrStat2,ErrMsg2)
       DO j = 1, 3
           uf(temp_id+3+j) = rot_temp(j)
       ENDDO

       DO j=1, 6
           vf(temp_id+j) = vf(temp_id+j) + coef(7) * ainc(temp_id+j)
           af(temp_id+j) = af(temp_id+j) + ainc(temp_id+j)
           xf(temp_id+j) = xf(temp_id+j) + coef(9) * ainc(temp_id+j)
       ENDDO
   ENDDO

END SUBROUTINE BD_UpdateDynamicGA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes Global mass matrix and force vector for the beam.
SUBROUTINE BD_GenerateDynamicElementAcc(uuN,vvN,u, p, m, ErrStat, ErrMsg)

   REAL(BDKi),            INTENT(IN   ):: uuN(:)       !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(IN   ):: vvN(:)       !< Velocity of Mass 1: m/s
   TYPE(BD_InputType),    INTENT(IN   ):: u            !< Inputs at t
   TYPE(BD_ParameterType),INTENT(IN   ):: p            !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m            !< Misc/optimization variables
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat      !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg       !< Error message if ErrStat /= ErrID_None

   
   INTEGER(IntKi)                  :: nelem ! number of elements
!   INTEGER(IntKi)                  :: i ! Index counter
   INTEGER(IntKi)                  :: j ! Index counter
   INTEGER(IntKi)                  :: temp_id ! Index counter
   INTEGER(IntKi)                  :: temp_id2 ! Index counter
   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER         :: RoutineName = 'BD_GenerateDynamicElementAcc'

   ErrStat    = ErrID_None
   ErrMsg     = ""
   m%RHS(:)     = 0.0_BDKi
   m%MassM(:,:) = 0.0_BDKi


   DO nelem=1,p%elem_total
      
       CALL BD_ElemNodalDisp(uuN,p%node_elem,p%dof_node,nelem,m%Nuuu,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_NodalRelRot(m%Nuuu,p%node_elem,p%dof_node,m%Nrrr,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElemNodalDisp(vvN,p%node_elem,p%dof_node,nelem,m%Nvvv,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       if (ErrStat >= AbortErrLev) return

       IF(p%quadrature .EQ. 1) THEN
           temp_id = (nelem-1)*p%ngp + 1
           temp_id2 = (nelem-1)*p%ngp
       ELSEIF(p%quadrature .EQ. 2) THEN
           temp_id = (nelem-1)*p%ngp
           temp_id2= temp_id
       ENDIF

       DO j=1,p%ngp
           m%EStif0_GL(:,:,j)    = p%Stif0_GL(1:6,1:6,temp_id2+j)
           m%EMass0_GL(:,:,j)    = p%Mass0_GL(1:6,1:6,temp_id2+j)
           m%DistrLoad_GL(1:3,j) = u%DistrLoad%Force(1:3,temp_id+j)
           m%DistrLoad_GL(4:6,j) = u%DistrLoad%Moment(1:3,temp_id+j)
       ENDDO

       CALL BD_ElementMatrixAcc(m%Nuuu,m%Nrrr,m%Nvvv,&
                                m%EStif0_GL,m%EMass0_GL,p%gravity,m%DistrLoad_GL,&
                                p%ngp,p%GLw,p%Shp,p%Der,p%Jacobian(:,nelem),p%uu0(:,nelem),p%E10(:,nelem),&
                                p%node_elem,p%dof_node,p%damp_flag,p%beta,&
                                m%elf,m%elm,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       CALL BD_AssembleStiffK(nelem,p%node_elem,p%dof_elem,p%dof_node,m%elm, m%MassM,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_AssembleRHS(nelem,p%dof_elem,p%node_elem,p%dof_node,m%elf, m%RHS,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       if (ErrStat >= AbortErrLev) return

   ENDDO

   RETURN

END SUBROUTINE BD_GenerateDynamicElementAcc
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine total element forces and mass matrices
SUBROUTINE BD_ElementMatrixAcc(Nuuu,Nrrr,Nvvv,&
                               EStif0_GL,EMass0_GL,gravity,DistrLoad_GL,&
                               ngp,gw,hhx,hpx,Jaco,uu0,E10,   &
                               node_elem,dof_node,damp_flag,beta,&
                               elf,elm,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: Nuuu(:)             !< Nodal displacement of Mass 1 for each element
   REAL(BDKi),    INTENT(IN   ):: Nrrr(:)             !< Nodal rotation parameters for displacement of Mass 1
   REAL(BDKi),    INTENT(IN   ):: Nvvv(:)             !< Nodal velocity of Mass 1: m/s for each element
   REAL(BDKi),    INTENT(IN   ):: EStif0_GL(:,:,:)    !< Nodal material properties for each element
   REAL(BDKi),    INTENT(IN   ):: EMass0_GL(:,:,:)    !< Nodal material properties for each element
   REAL(BDKi),    INTENT(IN   ):: gravity(:)          !< gravitational acceleration
   REAL(BDKi),    INTENT(IN   ):: DistrLoad_GL(:,:)   !< Nodal material properties for each element
   INTEGER(IntKi),INTENT(IN   ):: ngp                 !< Number of Gauss points
   REAL(BDKi),    INTENT(IN   ):: gw(:)
   REAL(BDKi),    INTENT(IN   ):: hhx(:,:)
   REAL(BDKi),    INTENT(IN   ):: hpx(:,:)
   REAL(BDKi),    INTENT(IN   ):: Jaco(:)
   REAL(BDKi),    INTENT(IN   ):: uu0(:)
   REAL(BDKi),    INTENT(IN   ):: E10(:)
   INTEGER(IntKi),INTENT(IN   ):: node_elem           !< Node per element
   INTEGER(IntKi),INTENT(IN   ):: dof_node            !< Degrees of freedom per node
   INTEGER(IntKi),INTENT(IN   ):: damp_flag           !< Degrees of freedom per node
   REAL(BDKi),    INTENT(IN   ):: beta(:)
   REAL(BDKi),    INTENT(  OUT):: elf(:)              !< Total element force (Fd, Fc, Fb)
   REAL(BDKi),    INTENT(  OUT):: elm(:,:)            !< Total element mass matrix
   INTEGER(IntKi),INTENT(  OUT):: ErrStat             !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg              !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: temp_Naaa(dof_node*node_elem)
   REAL(BDKi)                  :: RR0(3,3)
   REAL(BDKi)                  :: kapa(3)
   REAL(BDKi)                  :: E1(3)
   REAL(BDKi)                  :: Stif(6,6)
   REAL(BDKi)                  :: cet
   REAL(BDKi)                  :: uuu(6)
   REAL(BDKi)                  :: uup(3)
   REAL(BDKi)                  :: Fc(6)
   REAL(BDKi)                  :: Fd(6)
   REAL(BDKi)                  :: Fg(6)
   REAL(BDKi)                  :: vvv(6)
   REAL(BDKi)                  :: vvp(6)
   REAL(BDKi)                  :: mmm
   REAL(BDKi)                  :: mEta(3)
   REAL(BDKi)                  :: rho(3,3)
   REAL(BDKi)                  :: Fb(6)
   REAL(BDKi)                  :: Mi(6,6)
   REAL(BDKi)                  :: Oe(6,6)
   REAL(BDKi)                  :: Pe(6,6)
   REAL(BDKi)                  :: Qe(6,6)
   REAL(BDKi)                  :: Sd(6,6)
   REAL(BDKi)                  :: Od(6,6)
   REAL(BDKi)                  :: Pd(6,6)
   REAL(BDKi)                  :: Qd(6,6)
   REAL(BDKi)                  :: betaC(6,6)
   REAL(BDKi)                  :: Gd(6,6)
   REAL(BDKi)                  :: Xd(6,6)
   REAL(BDKi)                  :: Yd(6,6)
   REAL(BDKi)                  :: temp_aaa(6)
   LOGICAL                     :: fact
   INTEGER(IntKi)              :: igp
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: m
   INTEGER(IntKi)              :: n
   INTEGER(IntKi)              :: temp_id1
   INTEGER(IntKi)              :: temp_id2
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_ElementMatrixAcc'

   ErrStat   = ErrID_None
   ErrMsg    = ""
   elf(:)    = 0.0_BDKi
   elm(:,:)  = 0.0_BDKi
   temp_Naaa = 0.0_BDKi
   
   fact = .FALSE.

   DO igp=1,ngp

       temp_id1 = (igp-1)*dof_node
       temp_id2 = (igp-1)*dof_node/2
       Stif(:,:) = 0.0_BDKi
       Stif(1:6,1:6) = EStif0_GL(1:6,1:6,igp)
       CALL BD_GaussPointData(hhx(:,igp),hpx(:,igp),Jaco(igp),Nuuu,Nrrr,&
             uu0(temp_id1+1:temp_id1+6),E10(temp_id2+1:temp_id2+3),node_elem,dof_node,&
             uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       mmm          = 0.0_BDKi
       rho          = 0.0_BDKi
       mmm          = EMass0_GL(1,1,igp)
       mEta(1)      = 0.0_BDKi
       mEta(2)      = -EMass0_GL(1,6,igp)
       mEta(3)      =  EMass0_GL(1,5,igp)
       rho(1:3,1:3) = EMass0_GL(4:6,4:6,igp)
       CALL BD_GaussPointDataMass(hhx(:,igp),hpx(:,igp),Jaco(igp),Nvvv,temp_Naaa,RR0,&
             node_elem,dof_node, vvv,temp_aaa,vvp,mEta,rho,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_MassMatrix(mmm,mEta,rho,Mi,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_GyroForce(mEta,rho,vvv,Fb,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_GravityForce(mmm,mEta,gravity,Fg,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(damp_flag .NE. 0) THEN
           CALL BD_DissipativeForce(beta,Stif,vvv,vvp,E1,fact,Fc,Fd,Sd,Od,Pd,Qd,&
                                    betaC,Gd,Xd,Yd,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDIF

       Fd(:) = Fd(:) + Fb(:) - DistrLoad_GL(:,igp) - Fg(:)

       DO i=1,node_elem
           DO j=1,node_elem
               DO m=1,dof_node
                   temp_id1 = (i-1)*dof_node+m
                   DO n=1,dof_node
                       temp_id2 = (j-1)*dof_node+n
                       elm(temp_id1,temp_id2) = elm(temp_id1,temp_id2) + hhx(i,igp)*Mi(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                   ENDDO
               ENDDO
           ENDDO
       ENDDO
       DO i=1,node_elem
           DO j=1,dof_node
               temp_id1 = (i-1) * dof_node+j
               elf(temp_id1) = elf(temp_id1) - hpx(i,igp)*Fc(j)*gw(igp)
               elf(temp_id1) = elf(temp_id1) - hhx(i,igp)*Fd(j)*Jaco(igp)*gw(igp)
           ENDDO
       ENDDO

       if (ErrStat >= AbortErrLev) then
          return
       end if

   ENDDO

   RETURN

END SUBROUTINE BD_ElementMatrixAcc
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the mass matrix.
SUBROUTINE BD_MassMatrix(m00,mEta,rho,Mi,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: m00        !< Mass density at Gauss point
   REAL(BDKi),    INTENT(IN   ):: mEta(:)    !< m\Eta resolved in inertia frame at Gauss point
   REAL(BDKi),    INTENT(IN   ):: rho(:,:)   !< Tensor of inertia resolved in inertia frame at Gauss point
   REAL(BDKi),    INTENT(  OUT):: Mi(:,:)    !< Mass matrix
   INTEGER(IntKi),INTENT(  OUT):: ErrStat    !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg     !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i

   ErrStat = ErrID_None
   ErrMsg  = ""
   Mi(:,:) = 0.0_BDKi

   DO i=1,3
       Mi(i,i) = m00
   ENDDO
   Mi(1:3,4:6) = TRANSPOSE(BD_Tilde(mEta))
   Mi(4:6,1:3) = BD_Tilde(mEta)
   Mi(4:6,4:6) = rho


END SUBROUTINE BD_MassMatrix
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes gyroscopic forces
SUBROUTINE BD_GyroForce(mEta,rho,vvv,Fb,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: mEta(:)       !< m\Eta resolved in inertia frame at Gauss point
   REAL(BDKi),    INTENT(IN   ):: rho(:,:)      !< Tensor of inertia resolved in inertia frame at Gauss point
   REAL(BDKi),    INTENT(IN   ):: vvv(:)        !< Velocities at Gauss point (including linear and angular velocities)
   REAL(BDKi),    INTENT(  OUT):: Fb(:)         !< Gyroscopic forces
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   REAL(BDKi)                  :: Bi(6,6)
   REAL(BDKi)                  :: ome(3)
   REAL(BDKi)                  :: temp33(3,3)
   REAL(BDKi)                  :: temp6(6)

   ErrStat = ErrID_None
   ErrMsg  = ""
   Fb(:)   = 0.0_BDKi

   ome = 0.0_BDKi
   ome(:) = vvv(4:6)
   Bi= 0.0_BDKi
   temp33 = 0.0_BDKi
   temp33 = MATMUL(BD_Tilde(ome),TRANSPOSE(BD_Tilde(mEta)))
   DO i=1,3
       DO j=1,3
           Bi(i,j+3) = temp33(i,j)
       ENDDO
   ENDDO
   temp33 = 0.0_BDKi
   temp33 = MATMUL(BD_Tilde(ome),rho)
   DO i=1,3
       DO j=1,3
           Bi(i+3,j+3) = temp33(i,j)
       ENDDO
   ENDDO

   temp6 = 0.0_BDKi
   temp6(1:6) = vvv(1:6)

   Fb(:) = MATMUL(Bi,temp6)

END SUBROUTINE BD_GyroForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates elemetal internal forces
SUBROUTINE BD_ElementMatrixForce(Nuuu,Nrrr,Nvvv,&
                                 EStif0_GL,EMass0_GL,     &
                                 damp_flag,beta,          &
                                 ngp,gw,hhx,hpx,Jaco,uu0,E10,&
                                 node_elem,dof_node,elf,&
                                 ErrStat,ErrMsg)

   REAL(BDKi),     INTENT(IN   ):: Nuuu(:)          !< Nodal displacement of Mass 1 for each element
   REAL(BDKi),     INTENT(IN   ):: Nrrr(:)          !< Nodal rotation parameters for displacement of Mass 1
   REAL(BDKi),     INTENT(IN   ):: Nvvv(:)          !< Nodal velocity of Mass 1: m/s for each element
   REAL(BDKi),     INTENT(IN   ):: EStif0_GL(:,:,:) !< Nodal material properties for each element
   REAL(BDKi),     INTENT(IN   ):: EMass0_GL(:,:,:) !< Nodal material properties for each element
   INTEGER(IntKi), INTENT(IN   ):: damp_flag        !< Number of Gauss points
   REAL(BDKi),     INTENT(IN   ):: beta(:)
   INTEGER(IntKi), INTENT(IN   ):: ngp              !< Number of Gauss points
   REAL(BDKi),     INTENT(IN   ):: gw(:)
   REAL(BDKi),     INTENT(IN   ):: hhx(:,:)
   REAL(BDKi),     INTENT(IN   ):: hpx(:,:)
   REAL(BDKi),     INTENT(IN   ):: Jaco(:)
   REAL(BDKi),     INTENT(IN   ):: uu0(:)
   REAL(BDKi),     INTENT(IN   ):: E10(:)
   INTEGER(IntKi), INTENT(IN   ):: node_elem        !< Node per element
   INTEGER(IntKi), INTENT(IN   ):: dof_node         !< Degrees of freedom per node
   REAL(BDKi),     INTENT(  OUT):: elf(:)           !< Total element force (Fd, Fc, Fb)
   INTEGER(IntKi), INTENT(  OUT):: ErrStat          !< Error status of the operation
   CHARACTER(*),   INTENT(  OUT):: ErrMsg           !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                   :: temp_Naaa(dof_node*node_elem)
   REAL(BDKi)                   :: RR0(3,3)
   REAL(BDKi)                   :: kapa(3)
   REAL(BDKi)                   :: E1(3)
   REAL(BDKi)                   :: Stif(6,6)
   REAL(BDKi)                   :: cet
   REAL(BDKi)                   :: uuu(6)
   REAL(BDKi)                   :: uup(3)
   REAL(BDKi)                   :: Fc(6)
   REAL(BDKi)                   :: Fd(6)
   REAL(BDKi)                   :: Oe(6,6)
   REAL(BDKi)                   :: Pe(6,6)
   REAL(BDKi)                   :: Qe(6,6)
   REAL(BDKi)                   :: vvv(6)
   REAL(BDKi)                   :: vvp(6)
   REAL(BDKi)                   :: mmm
   REAL(BDKi)                   :: mEta(3)
   REAL(BDKi)                   :: rho(3,3)
   REAL(BDKi)                   :: Fb(6)
   REAL(BDKi)                   :: Sd(6,6)
   REAL(BDKi)                   :: Od(6,6)
   REAL(BDKi)                   :: Pd(6,6)
   REAL(BDKi)                   :: Qd(6,6)
   REAL(BDKi)                   :: betaC(6,6)
   REAL(BDKi)                   :: Gd(6,6)
   REAL(BDKi)                   :: Xd(6,6)
   REAL(BDKi)                   :: Yd(6,6)
   REAL(BDKi)                   :: temp_aaa(6)
   LOGICAL                      :: fact
   INTEGER(IntKi)               :: igp
   INTEGER(IntKi)               :: i
   INTEGER(IntKi)               :: j
   INTEGER(IntKi)               :: temp_id1
   INTEGER(IntKi)               :: temp_id2
   INTEGER(IntKi)               :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)         :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER      :: RoutineName = 'BD_ElememntMatrixForce'

   ErrStat   = ErrID_None
   ErrMsg    = ""
   elf       = 0.0_BDKi
   temp_Naaa = 0.0_BDKi
   
   fact = .FALSE.

   DO igp=1,ngp

       temp_id1 = (igp-1)*dof_node
       temp_id2 = (igp-1)*dof_node/2
       Stif(:,:) = 0.0_BDKi
       Stif(1:6,1:6) = EStif0_GL(1:6,1:6,igp)
       CALL BD_GaussPointData(hhx(:,igp),hpx(:,igp),Jaco(igp),Nuuu,Nrrr,&
               uu0(temp_id1+1:temp_id1+6),E10(temp_id2+1:temp_id2+3),node_elem,dof_node,&
               uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       mmm          =  EMass0_GL(1,1,igp)
       mEta(1)      =  0.0_BDKi
       mEta(2)      = -EMass0_GL(1,6,igp)
       mEta(3)      =  EMass0_GL(1,5,igp)
       rho          =  EMass0_GL(4:6,4:6,igp)
       CALL BD_GaussPointDataMass(hhx(:,igp),hpx(:,igp),Jaco(igp),Nvvv,temp_Naaa,RR0,&
             node_elem,dof_node, vvv,temp_aaa,vvp,mEta,rho,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(damp_flag .EQ. 1) THEN
           CALL BD_DissipativeForce(beta,Stif,vvv,vvp,E1,fact,Fc,Fd,Sd,Od,Pd,Qd,&
                                    betaC,Gd,Xd,Yd,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDIF
       CALL BD_GyroForce(mEta,rho,vvv,Fb,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       DO i=1,node_elem
           DO j=1,dof_node
               temp_id1 = (i-1) * dof_node+j
               elf(temp_id1) = elf(temp_id1) + hhx(i,igp)*Fb(j)*Jaco(igp)*gw(igp)
               elf(temp_id1) = elf(temp_id1) + hhx(i,igp)*Fd(j)*Jaco(igp)*gw(igp)
               elf(temp_id1) = elf(temp_id1) + hpx(i,igp)*Fc(j)*gw(igp)
           ENDDO
       ENDDO

       if (ErrStat >= AbortErrLev) then
          return
       end if

   ENDDO

   RETURN

END SUBROUTINE BD_ElementMatrixForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes Global mass matrix and force vector to 
!! calculate the forces along the beam
SUBROUTINE BD_GenerateDynamicElementForce(uuN,vvN,aaN, u, p, m, RHS,ErrStat,ErrMsg)
   REAL(BDKi),            INTENT(IN   ):: uuN(:)       !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(IN   ):: vvN(:)       !< Velocity of Mass 1: m/s
   REAL(BDKi),            INTENT(IN   ):: aaN(:)       !< Velocity of Mass 1: m/s
   TYPE(BD_InputType),    INTENT(IN   ):: u            !< Inputs at t
   TYPE(BD_ParameterType),INTENT(IN   ):: p            !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m            !< misc/optimization variables      
   REAL(BDKi),            INTENT(  OUT):: RHS(:)       !< Right hand side of the equation Ax=B
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat      !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg       !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                   :: nelem        ! number of elements
   INTEGER(IntKi)                   :: j            ! Index counter
   INTEGER(IntKi)                   :: temp_id      ! Index counter
   INTEGER(IntKi)                   :: temp_id2
   INTEGER(IntKi)                   :: ErrStat2     ! Temporary Error status
   CHARACTER(ErrMsgLen)             :: ErrMsg2      ! Temporary Error message
   CHARACTER(*), PARAMETER          :: RoutineName = 'BD_GenerateDynamicElementForce'

   ErrStat    = ErrID_None
   ErrMsg     = ""
   RHS(:)     = 0.0_BDKi


   DO nelem=1,p%elem_total
       CALL BD_ElemNodalDisp(uuN,p%node_elem,p%dof_node,nelem,m%Nuuu,ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_NodalRelRot(m%Nuuu,p%node_elem,p%dof_node,m%Nrrr,ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElemNodalDisp(vvN,p%node_elem,p%dof_node,nelem,m%Nvvv,ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElemNodalDisp(aaN,p%node_elem,p%dof_node,nelem,m%Naaa,ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(p%quadrature .EQ. 1) THEN
           temp_id = (nelem-1)*p%ngp + 1
           temp_id2 = (nelem-1)*p%ngp
       ELSEIF(p%quadrature .EQ. 2) THEN
           temp_id = (nelem-1)*p%ngp
           temp_id2= temp_id
       ENDIF

       DO j=1,p%ngp
           m%EStif0_GL(1:6,1:6,j) = p%Stif0_GL(1:6,1:6,temp_id2+j)
           m%EMass0_GL(1:6,1:6,j) = p%Mass0_GL(1:6,1:6,temp_id2+j)
           m%DistrLoad_GL(1:3,j) = u%DistrLoad%Force(1:3,temp_id+j)
           m%DistrLoad_GL(4:6,j) = u%DistrLoad%Moment(1:3,temp_id+j)
       ENDDO

       CALL BD_ElementMatrixForce(m%Nuuu,m%Nrrr,m%Nvvv,&
                                  m%EStif0_GL,m%EMass0_GL,     &
                                  p%damp_flag,p%beta,          &
                                  p%ngp,p%GLw,p%Shp,p%Der,p%Jacobian(:,nelem),p%uu0(:,nelem),p%E10(:,nelem),&
                                  p%node_elem,p%dof_node,m%elf,&
                                  ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       CALL BD_AssembleRHS(nelem,p%dof_elem,p%node_elem,p%dof_node,m%elf,RHS,ErrStat2,ErrMsg2)
           CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       if (ErrStat >= AbortErrLev) return

   ENDDO

   RETURN

END SUBROUTINE BD_GenerateDynamicElementForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the finite-element nodal forces along the beam
!! Nodal forces = \f$C \dot{u} + K u\f$
SUBROUTINE BD_DynamicSolutionForce(uuN,vvN,aaN, u, p, m, Force,ErrStat,ErrMsg)

   REAL(BDKi),            INTENT(IN   ):: uuN(:)       !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(IN   ):: vvN(:)       !< Velocity of Mass 1: m/s
   REAL(BDKi),            INTENT(IN   ):: aaN(:)       !< Velocity of Mass 1: m/s
   TYPE(BD_InputType),    INTENT(IN   ):: u            !< Inputs at t   
   TYPE(BD_ParameterType),INTENT(IN   ):: p            !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m            !< misc/optimization variables      
   REAL(BDKi),            INTENT(  OUT):: Force(:)     !< finite-element nodal forces along the beam
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat      !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg       !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                   :: ErrStat2     ! Temporary Error status
   CHARACTER(ErrMsgLen)             :: ErrMsg2      ! Temporary Error message
   CHARACTER(*), PARAMETER          :: RoutineName = 'BD_DynamicSolutionForce'

   ErrStat = ErrID_None
   ErrMsg  = ""


   CALL BD_GenerateDynamicElementForce(uuN,vvN,aaN,u, p, m, Force,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   if (ErrStat >= AbortErrLev) RETURN


END SUBROUTINE BD_DynamicSolutionForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> calculate Lagrangian interpolant tensor at ns points where basis
!! functions are assumed to be associated with (np+1) GLL points on
!! [-1,1]
SUBROUTINE BD_diffmtc(np,ns,spts,npts,hhx,hpx,ErrStat,ErrMsg)
   INTEGER(IntKi),INTENT(IN   ):: np            !< polynomial order of basis functions
   INTEGER(IntKi),INTENT(IN   ):: ns            !< number of points at which to eval shape/deriv
   REAL(BDKi),    INTENT(IN   ):: spts(:)       !< spts(ns): location of ns points at which to eval
   REAL(BDKi),    INTENT(IN   ):: npts(:)       !< npts(np+1): location of the (np+1) GLL points
   REAL(BDKi),    INTENT(  OUT):: hhx(:,:)      !< ps(np+1,ns): (np+1) shape functions evaluated at ns points
   REAL(BDKi),    INTENT(  OUT):: hpx(:,:)      !< dPhis(np+1,ns): derivative evaluated at ns points 
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: dPhis(np+1,ns)   ! bjj: why not use hpx  
   REAL(BDKi)                  :: Ps(np+1,ns)      ! bjj: why not use hhx
   REAL(BDKi)                  :: dnum
   REAL(BDKi)                  :: den
   REAL(BDKi),        PARAMETER:: eps = SQRT(EPSILON(eps)) !1.0D-08
   INTEGER(IntKi)              :: l
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: k

   ErrStat = ErrID_None
   ErrMsg  = ""

   do j = 1,ns  
      do l = 1,np+1
         
       if ((abs(spts(j)-1.).LE.eps).AND.(l.EQ.np+1)) then
         dPhis(l,j) = REAL((np+1)*np, BDKi)/4.0_BDKi
       elseif ((abs(spts(j)+1.).LE.eps).AND.(l.EQ.1)) then
         dPhis(l,j) = -REAL((np+1)*np, BDKi)/4.0_BDKi
       elseif (abs(spts(j)-npts(l)).LE.eps) then
         dPhis(l,j) = 0.0_BDKi
       else
         dPhis(l,j) = 0.0_BDKi
         den = 1.0_BDKi          
         do i = 1,np+1
           if (i.NE.l) then
             den = den*(npts(l)-npts(i))
           endif
           dnum = 1.0_BDKi
           do k = 1,np+1
             if ((k.NE.l).AND.(k.NE.i).AND.(i.NE.l)) then
               dnum = dnum*(spts(j)-npts(k))
             elseif (i.EQ.l) then
               dnum = 0.0_BDKi
             endif
           enddo
           dPhis(l,j) = dPhis(l,j) + dnum
         enddo
         dPhis(l,j) = dPhis(l,j)/den
       endif
     enddo
   enddo

   do j = 1,ns  
      do l = 1,np+1
         
       if(abs(spts(j)-npts(l)).LE.eps) then
         Ps(l,j) = 1.0_BDKi
       else
         dnum = 1.0_BDKi
         den  = 1.0_BDKi
         do k = 1,np+1
           if (k.NE.l) then
             den  = den *(npts(l) - npts(k))
             dnum = dnum*(spts(j) - npts(k))
           endif
         enddo
         Ps(l,j) = dnum/den
       endif
     enddo
   enddo

   hhx(:,:) = Ps(:,:)
   hpx(:,:) = dPhis(:,:)

 END SUBROUTINE BD_diffmtc
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the segment length, member length, and total length of a beam.
!! It also computes the ration between the segment/member and total length.
!! Segment: defined by two adjacent key points
SUBROUTINE BD_ComputeMemberLength(member_total,kp_member,kp_coordinate,&
                                  Coef,seg_length,member_length,total_length,&
                                  ErrStat,ErrMsg)
   INTEGER(IntKi),INTENT(IN   ):: member_total
   INTEGER(IntKi),INTENT(IN   ):: kp_member(:)
   REAL(BDKi),    INTENT(IN   ):: Coef(:,:,:)
   REAL(BDKi),    INTENT(IN   ):: kp_coordinate(:,:)
   REAL(BDKi),    INTENT(  OUT):: seg_length(:,:)
   REAL(BDKi),    INTENT(  OUT):: member_length(:,:)
   REAL(BDKi),    INTENT(  OUT):: total_length
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: eta0
   REAL(BDKi)                  :: eta1
   REAL(BDKi)                  :: temp_pos0(3)
   REAL(BDKi)                  :: temp_pos1(3)
   REAL(BDKi)                  :: sample_step
   REAL(BDKi)                  :: temp
   INTEGER(IntKi)              :: sample_total
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: k
   INTEGER(IntKi)              :: m
   INTEGER(IntKi)              :: temp_id
   INTEGER(IntKi)              :: id0
   INTEGER(IntKi)              :: id1

   ErrStat = ErrID_None
   ErrMsg  = ""

   sample_total = 3 !1001

   temp_id = 0
   DO i=1,member_total
       IF(i .EQ. 1) THEN
           id0 = 1
           id1 = kp_member(i)
       ELSE
           id0 = id1
           id1 = id0 + kp_member(i) - 1
       ENDIF
       DO m=1,kp_member(i)-1
           temp_id = temp_id + 1
           sample_step = (kp_coordinate(id0+m,1) - kp_coordinate(id0+m-1,1))/(sample_total-1)
           DO j=1,sample_total-1
               eta0 = kp_coordinate(temp_id,1) + (j-1)*sample_step
               eta1 = kp_coordinate(temp_id,1) + j*sample_step
               DO k=1,3
                   temp_pos0(k) = Coef(temp_id,1,k) + Coef(temp_id,2,k)*eta0 + Coef(temp_id,3,k)*eta0*eta0 + Coef(temp_id,4,k)*eta0*eta0*eta0
                   temp_pos1(k) = Coef(temp_id,1,k) + Coef(temp_id,2,k)*eta1 + Coef(temp_id,3,k)*eta1*eta1 + Coef(temp_id,4,k)*eta1*eta1*eta1
               ENDDO
               temp_pos1(:) = temp_pos1(:) - temp_pos0(:)
               seg_length(temp_id,1) = seg_length(temp_id,1) + SQRT(DOT_PRODUCT(temp_pos1,temp_pos1))
               member_length(i,1) = member_length(i,1) + SQRT(DOT_PRODUCT(temp_pos1,temp_pos1))
           ENDDO
       ENDDO
       total_length = total_length + member_length(i,1)
   ENDDO

   temp_id = 0
   DO i=1,member_total
       temp = 0.0_BDKi
       DO j=1,kp_member(i)-1
           temp_id = temp_id + 1
           IF(j == 1) THEN
               seg_length(temp_id,2) = 0.0_BDKi
           ELSE
               seg_length(temp_id,2) = seg_length(temp_id-1,3)
           ENDIF
           temp = temp + seg_length(temp_id,1)
           seg_length(temp_id,3) = temp/member_length(i,1)
       ENDDO
   ENDDO

   DO i=1,member_total
       member_length(i,2) = member_length(i,1)/total_length
   ENDDO


END SUBROUTINE BD_ComputeMemberLength
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the initial nodal locations given the coefficients for
!! cubic spline fit. It also computes the unit tangent vector e1 for further use.
SUBROUTINE BD_ComputeIniNodalPosition(Coef,eta,PosiVec,e1,Twist_Angle,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: Coef(:,:)     !< Coefficients for cubic spline interpolation
   REAL(BDKi),    INTENT(IN   ):: eta           !< Nodal location in [0,1] 
   REAL(BDKi),    INTENT(  OUT):: PosiVec(:)    !< Physical coordinates of GLL points in blade frame
   REAL(BDKi),    INTENT(  OUT):: e1(:)         !< Tangent vector
   REAL(BDKi),    INTENT(  OUT):: Twist_Angle   !< Twist angle at PosiVec
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)              :: i

   ErrStat = ErrID_None
   ErrMsg  = ""

   PosiVec = 0.0_BDKi
   e1 = 0.0_BDKi
   DO i=1,3
       PosiVec(i) = Coef(i,1) + Coef(i,2)*eta + Coef(i,3)*eta*eta + Coef(i,4)*eta*eta*eta
       e1(i) = Coef(i,2) + 2.0_BDKi*Coef(i,3)*eta + 3.0_BDKi*Coef(i,4)*eta*eta
   ENDDO
   e1 = e1/TwoNorm(e1)
   Twist_Angle = 0.0_BDKi
   Twist_Angle = Coef(4,1) + Coef(4,2)*eta + Coef(4,3)*eta*eta + Coef(4,4)*eta*eta*eta

END SUBROUTINE BD_ComputeIniNodalPosition
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes initial CRV parameters
!! given geometry information
SUBROUTINE BD_ComputeIniNodalCrv(e1,phi,cc,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: e1(:)       !< Unit tangent vector
   REAL(BDKi),    INTENT(IN   ):: phi         !< Initial twist angle
   REAL(BDKi),    INTENT(  OUT):: cc(:)       !< Initial Crv Parameter
   INTEGER(IntKi),INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: e2(3)                     ! Unit normal vector
   REAL(BDKi)                  :: e3(3)                     ! Unit e3 = e1 * e2, cross-product
   REAL(BDKi)                  :: Rr(3,3)                   ! Initial rotation matrix
   REAL(BDKi)                  :: temp
   REAL(BDKi)                  :: temp2
   REAL(BDKi)                  :: Delta
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_ComputeIniNodalCrv'

   ErrStat = ErrID_None
   ErrMsg  = ""

   Rr = 0.0_BDKi
   DO i=1,3
       Rr(i,1) = e1(i)
   ENDDO

   e2 = 0.0_BDKi
   temp = phi*D2R_D  ! convert to radians
   temp2 = ((e1(2)*COS(temp) + e1(3)*SIN(temp))/e1(1))
   Delta = SQRT(1.0_BDKi + temp2*temp2)
   e2(1) = -(e1(2)*COS(temp)+e1(3)*SIN(temp))/e1(1)
   e2(2) = COS(temp)
   e2(3) = SIN(temp)
   e2 = e2/Delta
   DO i=1,3
       Rr(i,2) = e2(i)
   ENDDO

   e3 = 0.0_BDKi
   e3 = Cross_Product(e1,e2)
   DO i=1,3
       Rr(i,3) = e3(i)
   ENDDO

   CALL BD_CrvExtractCrv(Rr,cc,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

END SUBROUTINE BD_ComputeIniNodalCrv
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the coefficients for cubie-spline fit
!! given key point locations. Clamped conditions are used at the
!! two end nodes: f''(0) = f''(1) = 0 
SUBROUTINE BD_ComputeIniCoef(kp_member,kp_coord,Coef,ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: kp_coord(:,:) !< Keypoints coordinates
   INTEGER(IntKi),INTENT(IN   ):: kp_member     !< Number of kps of each member
   REAL(BDKi),    INTENT(  OUT):: Coef(:,:,:)   !< Coefficients for cubie spline interpolation
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   REAL(BDKi),      ALLOCATABLE:: K(:,:)
   REAL(BDKi),      ALLOCATABLE:: RHS(:)
   INTEGER(IntKi),  ALLOCATABLE:: indx(:)
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: m
   INTEGER(IntKi)              :: temp_id1
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_ComputeIniCoef'

   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL AllocAry( K, 4*(kp_member-1), 4*(kp_member-1), 'Coefficient matrix', ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry( RHS, 4*(kp_member-1),  'RHS', ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry( indx, 4*(kp_member-1),  'IPIV', ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   if (ErrStat < AbortErrLev) then
      
      DO i=1,4
          K(:,:) = 0.0_BDKi
          RHS(:) = 0.0_BDKi

          K(1,3) = 2.0_BDKi
          K(1,4) = 6.0_BDKi*kp_coord(1,1)
          RHS(1) = 0.0_BDKi
          DO j=1,kp_member-2
              temp_id1 = (j-1)*4
              K(temp_id1+2,temp_id1+1) = 1.0_BDKi
              K(temp_id1+2,temp_id1+2) = kp_coord(j,1)
              K(temp_id1+2,temp_id1+3) = kp_coord(j,1)**2
              K(temp_id1+2,temp_id1+4) = kp_coord(j,1)**3
              K(temp_id1+3,temp_id1+1) = 1.0_BDKi
              K(temp_id1+3,temp_id1+2) = kp_coord(j+1,1)
              K(temp_id1+3,temp_id1+3) = kp_coord(j+1,1)**2
              K(temp_id1+3,temp_id1+4) = kp_coord(j+1,1)**3
              K(temp_id1+4,temp_id1+2) = 1.0_BDKi
              K(temp_id1+4,temp_id1+3) = 2.0_BDKi*kp_coord(j+1,1)
              K(temp_id1+4,temp_id1+4) = 3.0_BDKi*kp_coord(j+1,1)**2
              K(temp_id1+4,temp_id1+6) = -1.0_BDKi
              K(temp_id1+4,temp_id1+7) = -2.0_BDKi*kp_coord(j+1,1)
              K(temp_id1+4,temp_id1+8) = -3.0_BDKi*kp_coord(j+1,1)**2
              K(temp_id1+5,temp_id1+3) = 2.0_BDKi
              K(temp_id1+5,temp_id1+4) = 6.0_BDKi*kp_coord(j+1,1)
              K(temp_id1+5,temp_id1+7) = -2.0_BDKi
              K(temp_id1+5,temp_id1+8) = -6.0_BDKi*kp_coord(j+1,1)
              RHS(temp_id1+2) = kp_coord(j,i)
              RHS(temp_id1+3) = kp_coord(j+1,i)
          ENDDO
          temp_id1 = (kp_member-2)*4
          K(temp_id1+2,temp_id1+1) = 1.0_BDKi
          K(temp_id1+2,temp_id1+2) = kp_coord(kp_member-1,1)
          K(temp_id1+2,temp_id1+3) = kp_coord(kp_member-1,1)**2
          K(temp_id1+2,temp_id1+4) = kp_coord(kp_member-1,1)**3
          K(temp_id1+3,temp_id1+1) = 1.0_BDKi
          K(temp_id1+3,temp_id1+2) = kp_coord(kp_member,1)
          K(temp_id1+3,temp_id1+3) = kp_coord(kp_member,1)**2
          K(temp_id1+3,temp_id1+4) = kp_coord(kp_member,1)**3
          K(temp_id1+4,temp_id1+3) = 2.0_BDKi
          K(temp_id1+4,temp_id1+4) = 6.0_BDKi*kp_coord(kp_member,1)
          RHS(temp_id1+2) = kp_coord(kp_member-1,i)
          RHS(temp_id1+3) = kp_coord(kp_member,i)
          RHS(temp_id1+4) = 0.0_BDKi
          CALL LAPACK_getrf( 4*(kp_member-1), 4*(kp_member-1), K,indx, ErrStat2, ErrMsg2) 
             CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          CALL LAPACK_getrs( 'N',4*(kp_member-1), K,indx,RHS, ErrStat2, ErrMsg2) 
             CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          DO j=1,kp_member-1
              DO m=1,4
                  temp_id1 = (j-1)*4+m
                  Coef(j,m,i) = RHS(temp_id1)
              ENDDO
          ENDDO
      ENDDO
      
   end if ! temp arrays are allocated
   

   if (allocated(K   )) deallocate(K)
   if (allocated(RHS )) deallocate(RHS)
   if (allocated(indx)) deallocate(indx)

END SUBROUTINE BD_ComputeIniCoef
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_Static(t,n,u,utimes,p,x,xd,z,OtherState,m,ErrStat,ErrMsg)

   REAL(DbKi),                      INTENT(IN   ):: t           !< Current simulation time in seconds
   INTEGER(IntKi),                  INTENT(IN   ):: n           !< time step number
   REAL(DbKi),                      INTENT(IN   ):: utimes(:)   !< times of input
   TYPE(BD_ParameterType),          INTENT(IN   ):: p           !< Parameters
   TYPE(BD_DiscreteStateType),      INTENT(IN   ):: xd          !< Discrete states at t
   TYPE(BD_ConstraintStateType),    INTENT(IN   ):: z           !< Constraint states at t (possibly a guess)
   TYPE(BD_OtherStateType),         INTENT(INOUT):: OtherState  !< Other states at t
   TYPE(BD_MiscVarType),            INTENT(INOUT):: m           !< misc/optimization variables
   TYPE(BD_ContinuousStateType),    INTENT(INOUT):: x           !< Continuous states at t on input at t + dt on output
   TYPE(BD_InputType),              INTENT(INOUT):: u(:)        !< Inputs at t
   INTEGER(IntKi),                  INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),                    INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   TYPE(BD_InputType)                            :: u_interp
   TYPE(BD_InputType)                            :: u_temp
   INTEGER(IntKi)                                :: i
   INTEGER(IntKi)                                :: j
   INTEGER(IntKi)                                :: k
   INTEGER(IntKi)                                :: piter
   REAL(BDKi)                                    :: gravity_temp(3)
   INTEGER(IntKi)                                :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                          :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                       :: RoutineName = 'BD_Static'

   ErrStat = ErrID_None
   ErrMsg  = ""

      ! allocate space for input type (mainly for meshes)
   CALL BD_CopyInput(u(2),u_interp,MESH_NEWCOPY,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat, ErrMsg, RoutineName)
   CALL BD_CopyInput(u(2),u_temp,MESH_NEWCOPY,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat, ErrMsg, RoutineName)
   
   if (ErrStat >= AbortErrLev) then
      call cleanup()
      return
   end if
         
   call BD_Input_extrapinterp( u, utimes, u_interp, t, ErrStat2, ErrMsg2 )
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
         
   CALL BD_InputGlobalLocal(p,u_interp,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat, ErrMsg, RoutineName)
   ! Incorporate boundary conditions
   CALL BD_BoundaryGA2(x,p,u_interp,t,OtherState,m,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat, ErrMsg, RoutineName)

   if (ErrStat >= AbortErrLev) then
      call cleanup()
      return
   end if
   i = 1
   piter = 0
   DO WHILE(i .NE. 0)
       k=i
       DO j=1,k
           u_temp%PointLoad%Force(:,:) = u_interp%PointLoad%Force(:,:)/i*j
           u_temp%PointLoad%Moment(:,:) = u_interp%PointLoad%Moment(:,:)/i*j
           u_temp%DistrLoad%Force(:,:) = u_interp%DistrLoad%Force(:,:)/i*j
           u_temp%DistrLoad%Moment(:,:) = u_interp%DistrLoad%Moment(:,:)/i*j
           gravity_temp(:) = p%gravity(:)/i*j
           CALL BD_StaticSolution(x%q, gravity_temp, u_temp, p, m, piter, ErrStat2, ErrMsg2)
               call SetErrStat(ErrStat2,ErrMsg2,ErrStat, ErrMsg, RoutineName)
           IF(p%niter .EQ. piter) EXIT
       ENDDO
       IF(piter .LT. p%niter) THEN
           i=0
       ELSE
           IF(i .EQ. p%niter) THEN
               call SetErrStat( ErrID_Fatal, "Solution does not converge after the maximum number of load steps.", &
                                ErrStat,ErrMsg, RoutineName)
               CALL WrScr( "Maxium number of load steps reached. Exit BeamDyn")
               EXIT
           ENDIF
           i=i+1
           call WrScr( "Warning: Load may be too large, BeamDyn will attempt to solve with additional steps.")
           call WrScr( "  Load_Step="//trim(num2lstr(i)) )
           x%q = 0.0_BDKi
       ENDIF
   ENDDO
   
   if (ErrStat >= AbortErrLev) then
      call cleanup()
      return
   end if

   call cleanup()
   return
   
contains
   subroutine cleanup()
      CALL BD_DestroyInput(u_interp, ErrStat2, ErrMsg2 )
      CALL BD_DestroyInput(u_temp,   ErrStat2, ErrMsg2 )
   end subroutine cleanup
END SUBROUTINE BD_Static
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_StaticSolution( uuNf,gravity,u, p, m, piter, ErrStat,ErrMsg)

   REAL(BDKi),            INTENT(IN   ):: gravity(:)  !< not the same as p%gravity
   TYPE(BD_InputType),    INTENT(IN   ):: u           !< inputs
   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables
      
   REAL(BDKi),            INTENT(INOUT):: uuNf(:)
   INTEGER(IntKi),        INTENT(  OUT):: piter       !< ADDED piter AS OUTPUT
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   ! local variables
   REAL(BDKi),          ALLOCATABLE:: ui(:)
   REAL(BDKi)                      :: Eref
   REAL(BDKi)                      :: Enorm
   INTEGER(IntKi)                  :: i
   INTEGER(IntKi)                  :: j
   INTEGER(IntKi)                  :: k
   INTEGER(IntKi)                  :: temp_id
   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER         :: RoutineName = 'BD_StaticSolution'
   
   ErrStat = ErrID_None
   ErrMsg  = ""
   
   CALL AllocAry(ui,      p%dof_total,'Increment vector',ErrStat2,ErrMsg2); CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if

   Eref = 0.0_BDKi
   DO i=1,p%niter
       piter=i 
       CALL BD_GenerateStaticElement(uuNf, gravity, u, p, m, ErrStat2, ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       DO j=1,p%node_total
           temp_id = (j-1)*p%dof_node
           m%RHS(temp_id+1:temp_id+3) = m%RHS(temp_id+1:temp_id+3) + u%Pointload%Force(1:3,j)
           m%RHS(temp_id+4:temp_id+6) = m%RHS(temp_id+4:temp_id+6) + u%Pointload%Moment(1:3,j)
       ENDDO

       DO j=1,p%dof_total-6
           m%RHS_LU(j) = m%RHS(j+6)
       ENDDO
       DO k=1,p%dof_total-6
          DO j=1,p%dof_total-6
             m%StifK_LU(j,k) = m%StifK(j+6,k+6)
          ENDDO
       ENDDO

       CALL LAPACK_getrf( p%dof_total-6, p%dof_total-6, m%StifK_LU, m%indx, ErrStat2, ErrMsg2) 
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL LAPACK_getrs( 'N',p%dof_total-6, m%StifK_LU, m%indx, m%RHS_LU, ErrStat2, ErrMsg2) 
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       ui(:) = 0.0_BDKi
       DO j=1,p%dof_total-6
           ui(j+6) = m%RHS_LU(j)
       ENDDO

       CALL BD_StaticUpdateConfiguration(ui,uuNf,p%node_total,p%dof_node,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       
       IF(i .EQ. 1) THEN
           Eref = SQRT(abs(DOT_PRODUCT(m%RHS_LU, m%RHS(7:p%dof_total))))*p%tol
           IF(Eref .LE. p%tol) THEN
               CALL Cleanup()
               RETURN
           ENDIF
       ELSE  !IF(i .GT. 1) THEN
           Enorm = SQRT(abs(DOT_PRODUCT(m%RHS_LU, m%RHS(7:p%dof_total))))
           IF(Enorm .LE. Eref) THEN
               CALL Cleanup()
               RETURN
           ENDIF
       ENDIF

   ENDDO

   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if

   CALL Cleanup()
   RETURN

contains
      subroutine Cleanup()

         if (allocated(ui         )) deallocate(ui         )

      end subroutine Cleanup
END SUBROUTINE BD_StaticSolution
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_GenerateStaticElement( uuNf, gravity, u, p, m, ErrStat, ErrMsg)

   REAL(BDKi),            INTENT(IN   ):: uuNf(:)
   REAL(BDKi),            INTENT(IN   ):: gravity(:)
   TYPE(BD_InputType),    INTENT(IN   ):: u
   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables
   
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                  :: nelem
   INTEGER(IntKi)                  :: j
   INTEGER(IntKi)                  :: temp_id
   INTEGER(IntKi)                  :: temp_id2
   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER         :: RoutineName = 'BD_GenerateStaticElement'

   ErrStat    = ErrID_None
   ErrMsg     = ""
   m%StifK(:,:) = 0.0_BDKi
   m%RHS(:)     = 0.0_BDKi

   DO nelem=1,p%elem_total
       CALL BD_ElemNodalDisp(uuNf,p%node_elem,p%dof_node,nelem,m%Nuuu,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_NodalRelRot(m%Nuuu,p%node_elem,p%dof_node,m%Nrrr,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(p%quadrature .EQ. 1) THEN
           temp_id = (nelem-1)*p%ngp + 1
           temp_id2 = (nelem-1)*p%ngp
       ELSEIF(p%quadrature .EQ. 2) THEN
           temp_id = (nelem-1)*p%ngp
           temp_id2= temp_id
       ENDIF

       DO j=1,p%ngp
           m%EStif0_GL(   :,:,j) = p%Stif0_GL(1:6,1:6,temp_id2+j)
           m%EMass0_GL(   :,:,j) = p%Mass0_GL(1:6,1:6,temp_id2+j)
           m%DistrLoad_GL(1:3,j) = u%DistrLoad%Force(1:3,temp_id+j)
           m%DistrLoad_GL(4:6,j) = u%DistrLoad%Moment(1:3,temp_id+j)
       ENDDO
       CALL BD_StaticElementMatrix(m%Nuuu,m%Nrrr,&
               m%DistrLoad_GL,gravity,m%EMass0_GL,m%EStif0_GL,&
               p%ngp,p%GLw,p%Shp,p%Der,p%Jacobian(:,nelem),p%uu0(:,nelem),p%E10(:,nelem),&
               p%node_elem,p%dof_node,m%elk,m%elf,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       CALL BD_AssembleStiffK(nelem,p%node_elem,p%dof_elem,p%dof_node,m%elk,m%StifK,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_AssembleRHS(nelem,p%dof_elem,p%node_elem,p%dof_node,m%elf,m%RHS,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ENDDO

   !if (ErrStat >= AbortErrLev) return
   RETURN

END SUBROUTINE BD_GenerateStaticElement
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_StaticElementMatrix(Nuuu,Nrrr,Distr_GL,gravity,&
                                  EMass0_GL,EStif0_GL,&
                                  ngp,gw,hhx,hpx,Jaco,uu0,E10,&
                                  node_elem,dof_node,elk,elf,&
                                  ErrStat,ErrMsg)

   REAL(BDKi),    INTENT(IN   ):: Nuuu(:)
   REAL(BDKi),    INTENT(IN   ):: Nrrr(:)
   REAL(BDKi),    INTENT(IN   ):: Distr_GL(:,:)
   REAL(BDKi),    INTENT(IN   ):: gravity(:)
   REAL(BDKi),    INTENT(IN   ):: EMass0_GL(:,:,:)
   REAL(BDKi),    INTENT(IN   ):: EStif0_GL(:,:,:)
   INTEGER(IntKi),INTENT(IN   ):: ngp
   REAL(BDKi),    INTENT(IN   ):: gw(:)
   REAL(BDKi),    INTENT(IN   ):: hhx(:,:)
   REAL(BDKi),    INTENT(IN   ):: hpx(:,:)
   REAL(BDKi),    INTENT(IN   ):: Jaco(:)
   REAL(BDKi),    INTENT(IN   ):: uu0(:)
   REAL(BDKi),    INTENT(IN   ):: E10(:)
   INTEGER(IntKi),INTENT(IN   ):: node_elem
   INTEGER(IntKi),INTENT(IN   ):: dof_node
   REAL(BDKi),    INTENT(  OUT):: elk(:,:)
   REAL(BDKi),    INTENT(  OUT):: elf(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: temp_Nvvv(dof_node*node_elem)
   REAL(BDKi)                  :: temp_Naaa(dof_node*node_elem)
   REAL(BDKi)                  :: RR0(3,3)
   REAL(BDKi)                  :: kapa(3)
   REAL(BDKi)                  :: E1(3)
   REAL(BDKi)                  :: Stif(6,6)
   REAL(BDKi)                  :: cet
   REAL(BDKi)                  :: mmm
   REAL(BDKi)                  :: mEta(3)
   REAL(BDKi)                  :: rho(3,3)
   REAL(BDKi)                  :: uuu(6)
   REAL(BDKi)                  :: uup(3)
   REAL(BDKi)                  :: vvv(6)
   REAL(BDKi)                  :: vvp(6)
   REAL(BDKi)                  :: Fc(6)
   REAL(BDKi)                  :: Fd(6)
   REAL(BDKi)                  :: Fg(6)
   REAL(BDKi)                  :: Oe(6,6)
   REAL(BDKi)                  :: Pe(6,6)
   REAL(BDKi)                  :: Qe(6,6)
   REAL(BDKi)                  :: aaa(6)
   LOGICAL                     :: fact
   INTEGER(IntKi)              :: igp
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: m
   INTEGER(IntKi)              :: n
   INTEGER(IntKi)              :: temp_id1
   INTEGER(IntKi)              :: temp_id2
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_StaticElementMatrix'

   ErrStat  = ErrID_None
   ErrMsg   = ""
   elk(:,:) = 0.0_BDKi
   elf(:)   = 0.0_BDKi

      ! initialize for use in BD_GaussPointDataMass (though they are used to calculate vvv,aaa,vvp, which aren't technically needed)
   temp_Nvvv = 0.0_BDKi
   temp_Naaa = 0.0_BDKi
   
   fact = .TRUE.


   DO igp=1,ngp

       temp_id1 = (igp-1)*dof_node
       temp_id2 = (igp-1)*dof_node/2
       Stif(1:6,1:6) = EStif0_GL(1:6,1:6,igp)
       CALL BD_GaussPointData(hhx(:,igp),hpx(:,igp),Jaco(igp),Nuuu,Nrrr,&
             uu0(temp_id1+1:temp_id1+6),E10(temp_id2+1:temp_id2+3),node_elem,dof_node,&
             uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       mmm          = EMass0_GL(1,1,igp)
       mEta(1)      = 0.0_BDKi
       mEta(2)      =-EMass0_GL(1,6,igp)
       mEta(3)      = EMass0_GL(1,5,igp)
       rho(1:3,1:3) = EMass0_GL(4:6,4:6,igp)
       CALL BD_GaussPointDataMass(hhx(:,igp),hpx(:,igp),Jaco(igp),temp_Nvvv,temp_Naaa,RR0,&
             node_elem,dof_node,vvv,aaa,vvp,mEta,rho,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_GravityForce(mmm,mEta,gravity,Fg,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       Fd(:) = Fd(:) - Fg(:) - Distr_GL(:,igp)

       DO i=1,node_elem
           DO j=1,node_elem
               DO m=1,dof_node
                   temp_id1 = (i-1)*dof_node+m
                   DO n=1,dof_node
                       temp_id2 = (j-1)*dof_node+n
                       elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                          hhx(i,igp)*Qe(m,n)*hhx(j,igp)*Jaco(igp)*gw(igp)
                       elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                          hhx(i,igp)*Pe(m,n)*hpx(j,igp)*gw(igp)
                       elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                          hpx(i,igp)*Oe(m,n)*hhx(j,igp)*gw(igp)
                       elk(temp_id1,temp_id2) = elk(temp_id1,temp_id2) + &
                          hpx(i,igp)*Stif(m,n)*hpx(j,igp)*gw(igp)/Jaco(igp)
                   ENDDO
               ENDDO
           ENDDO
       ENDDO


       DO i=1,node_elem
           DO j=1,dof_node
               temp_id1 = (i-1) * dof_node+j
               elf(temp_id1) = elf(temp_id1) - hhx(i,igp)*Fd(j)*Jaco(igp)*gw(igp)
               elf(temp_id1) = elf(temp_id1) - hpx(i,igp)*Fc(j)*gw(igp)
           ENDDO
       ENDDO

   ENDDO

   if (ErrStat >= AbortErrLev) then
       return
   end if
 
   RETURN

END SUBROUTINE BD_StaticElementMatrix
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine updates the static configuration
!! given incremental value calculated by the 
!! Newton-Raphson algorithm
SUBROUTINE BD_StaticUpdateConfiguration(uinc,uf,node_total,dof_node,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: uinc(:)
   INTEGER(IntKi),INTENT(IN   ):: node_total
   INTEGER(IntKi),INTENT(IN   ):: dof_node
   REAL(BDKi),    INTENT(INOUT):: uf(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: rotf_temp(3)
   REAL(BDKi)                  :: roti_temp(3)
   REAL(BDKi)                  :: rot_temp(3)
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: temp_id
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_StaticUpdateConfiguration'

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=1, node_total
       temp_id   = (i - 1) * dof_node
       rotf_temp = 0.0_BDKi
       roti_temp = 0.0_BDKi
       rot_temp  = 0.0_BDKi
       DO j=1,3
           uf(temp_id+j) = uf(temp_id+j) + uinc(temp_id+j)
           rotf_temp(j)  = uf(temp_id+3+j)
           roti_temp(j)  = uinc(temp_id+3+j)
       ENDDO
       CALL BD_CrvCompose(rot_temp,roti_temp,rotf_temp,0,ErrStat2,ErrMsg2)
       DO j=1,3
           uf(temp_id+3+j) = rot_temp(j)
       ENDDO
   ENDDO

END SUBROUTINE BD_StaticUpdateConfiguration
!-----------------------------------------------------------------------------------------------------------------------------------
! This subroutine calculates the internal nodal forces at each finite-element 
! nodes along beam axis. \n
! Nodal forces = K u
SUBROUTINE BD_StaticSolutionForce(uuN,vvN, p, m, u, Force, ErrStat,ErrMsg)

   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables
   TYPE(BD_InputType),    INTENT(IN   ):: u           !< Inputs at t
   REAL(BDKi),            INTENT(IN   ):: uuN(:)      !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(IN   ):: vvN(:)      !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(  OUT):: Force(:)
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*),          PARAMETER:: RoutineName = 'BD_StaticSolutionForce'

   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL BD_GenerateStaticElementForce(uuN,vvN,p, m, u, Force,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   IF(ErrStat >= AbortErrLev) RETURN

END SUBROUTINE BD_StaticSolutionForce
!-----------------------------------------------------------------------------------------------------------------------------------
! This subroutine calculates the internal nodal forces at each finite-element 
! nodes along beam axis \n
! Nodal forces = K u
SUBROUTINE BD_GenerateStaticElementForce(uuN,vvN, p, m, u, RHS, ErrStat,ErrMsg)
                                         
   REAL(BDKi),            INTENT(IN   ):: uuN(:)       !< Displacement of Mass 1: m
   REAL(BDKi),            INTENT(IN   ):: vvN(:)       !< Displacement of Mass 1: m
   TYPE(BD_ParameterType),INTENT(IN   ):: p            !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m            !< misc/optimization variables
   TYPE(BD_InputType),    INTENT(IN   ):: u            !< Inputs at t
   REAL(BDKi),            INTENT(  OUT):: RHS(:)       !< Right hand side of the equation Ax=B
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat      !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg       !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                :: nelem ! number of elements
   INTEGER(IntKi)                :: j ! Index counter
   INTEGER(IntKi)                :: temp_id ! Index counter
   INTEGER(IntKi)                :: temp_id2
   INTEGER(IntKi)                :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)          :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*),        PARAMETER:: RoutineName = 'BD_GenerateStaticElementForce'

   ErrStat = ErrID_None
   ErrMsg  = ""
   RHS(:)  = 0.0_BDKi


   DO nelem=1,p%elem_total
       CALL BD_ElemNodalDisp(uuN,p%node_elem,p%dof_node,nelem,m%Nuuu,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_NodalRelRot(m%Nuuu,p%node_elem,p%dof_node,m%Nrrr,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElemNodalDisp(vvN,p%node_elem,p%dof_node,nelem,m%Nvvv,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       IF(p%quadrature .EQ. 1) THEN
           temp_id = (nelem-1)*p%ngp + 1
           temp_id2 = (nelem-1)*p%ngp
       ELSEIF(p%quadrature .EQ. 2) THEN
           temp_id = (nelem-1)*p%ngp
           temp_id2= temp_id
       ENDIF

       DO j=1,p%ngp
           m%EStif0_GL(:,:,j)    = p%Stif0_GL(1:6,1:6,temp_id2+j)
           m%EMass0_GL(:,:,j)    = p%Mass0_GL(1:6,1:6,temp_id2+j)
           m%DistrLoad_GL(1:3,j) = u%DistrLoad%Force(1:3,temp_id+j)
           m%DistrLoad_GL(4:6,j) = u%DistrLoad%Moment(1:3,temp_id+j)
       ENDDO
       CALL BD_StaticElementMatrixForce(m%Nuuu,m%Nrrr,m%EStif0_GL,p%ngp,p%GLw,p%Shp,p%Der,p%Jacobian(:,nelem),p%uu0(:,nelem),p%E10(:,nelem),&
               p%node_elem,p%dof_node,m%elf,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       CALL BD_AssembleRHS(nelem,p%dof_elem,p%node_elem,p%dof_node,m%elf,RHS,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   ENDDO

   RETURN

END SUBROUTINE BD_GenerateStaticElementForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates elemental internal node force for static analysis
SUBROUTINE BD_StaticElementMatrixForce(Nuuu,Nrrr,EStif0_GL,&
              ngp,gw,hhx,hpx,Jaco,uu0,E10,                     &
              node_elem,dof_node,elf,ErrStat,ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: Nuuu(:)          !< Nodal displacement of Mass 1 for each element
   REAL(BDKi),    INTENT(IN   ):: Nrrr(:)          !< Nodal rotation parameters for displacement of Mass 1
   REAL(BDKi),    INTENT(IN   ):: EStif0_GL(:,:,:) !< Nodal material properties for each element
   INTEGER(IntKi),INTENT(IN   ):: ngp              !< Number of Gauss points
   REAL(BDKi),    INTENT(IN   ):: gw(:)
   REAL(BDKi),    INTENT(IN   ):: hhx(:,:)
   REAL(BDKi),    INTENT(IN   ):: hpx(:,:)
   REAL(BDKi),    INTENT(IN   ):: Jaco(:)
   REAL(BDKi),    INTENT(IN   ):: uu0(:)
   REAL(BDKi),    INTENT(IN   ):: E10(:)
   INTEGER(IntKi),INTENT(IN   ):: node_elem        !< Node per element
   INTEGER(IntKi),INTENT(IN   ):: dof_node         !< Degrees of freedom per node
   REAL(BDKi),    INTENT(  OUT):: elf(:)           !< Total element force (Fd, Fc, Fb)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat          !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg           !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: RR0(3,3)
   REAL(BDKi)                  :: kapa(3)
   REAL(BDKi)                  :: E1(3)
   REAL(BDKi)                  :: Stif(6,6)
   REAL(BDKi)                  :: cet
   REAL(BDKi)                  :: uuu(6)
   REAL(BDKi)                  :: uup(3)
   REAL(BDKi)                  :: Fc(6)
   REAL(BDKi)                  :: Fd(6)
   REAL(BDKi)                  :: Oe(6,6)
   REAL(BDKi)                  :: Pe(6,6)
   REAL(BDKi)                  :: Qe(6,6)
   LOGICAL                     :: fact
   INTEGER(IntKi)              :: igp
   INTEGER(IntKi)              :: i
   INTEGER(IntKi)              :: j
   INTEGER(IntKi)              :: temp_id1
   INTEGER(IntKi)              :: temp_id2
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_StaticElementMatrixForce'

   ErrStat  = ErrID_None
   ErrMsg   = ""
   elf(:)   = 0.0_BDKi

   fact = .FALSE.

   DO igp=1,ngp

       temp_id1 = (igp - 1) * dof_node
       temp_id2 = (igp - 1) * (dof_node/2)
       Stif(:,:) = 0.0_BDKi
       Stif(1:6,1:6) = EStif0_GL(1:6,1:6,igp)
       CALL BD_GaussPointData(hhx(:,igp),hpx(:,igp),Jaco(igp),Nuuu,Nrrr,&
             uu0(temp_id1+1:temp_id1+6),E10(temp_id2+1:temp_id2+3),node_elem,dof_node,&
             uuu,uup,E1,RR0,kapa,Stif,cet,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElasticForce(E1,RR0,kapa,Stif,cet,fact,Fc,Fd,Oe,Pe,Qe,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       DO i=1,node_elem
           DO j=1,dof_node
               temp_id1 = (i-1) * dof_node+j
               elf(temp_id1) = elf(temp_id1) + hhx(i,igp)*Fd(j)*Jaco(igp)*gw(igp)
               elf(temp_id1) = elf(temp_id1) + hpx(i,igp)*Fc(j)*gw(igp)
           ENDDO
       ENDDO
   ENDDO

   if (ErrStat >= AbortErrLev) then
       return
   end if

   RETURN

END SUBROUTINE BD_StaticElementMatrixForce
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine performs time marching from t_i to t_f
SUBROUTINE BD_GA2(t,n,u,utimes,p,x,xd,z,OtherState,m,ErrStat,ErrMsg)

   REAL(DbKi),                        INTENT(IN   )  :: t           !< Current simulation time in seconds
   INTEGER(IntKi),                    INTENT(IN   )  :: n           !< time step number
   TYPE(BD_InputType),                INTENT(INOUT)  :: u(:)        !< Inputs at t
   REAL(DbKi),                        INTENT(IN   )  :: utimes(:)   !< times of input
   TYPE(BD_ParameterType),            INTENT(IN   )  :: p           !< Parameters
   TYPE(BD_ContinuousStateType),      INTENT(INOUT)  :: x           !< Continuous states at t on input at t + dt on output
   TYPE(BD_DiscreteStateType),        INTENT(INOUT)  :: xd          !< Discrete states at t
   TYPE(BD_ConstraintStateType),      INTENT(IN   )  :: z           !< Constraint states at t (possibly a guess)
   TYPE(BD_OtherStateType),           INTENT(INOUT)  :: OtherState  !< Other states at t on input; at t+dt on outputs
   TYPE(BD_MiscVarType),              INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),                    INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                      INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   ! local variables
   TYPE(BD_ContinuousStateType)                       :: x_tmp      ! Holds temporary modification to x
   TYPE(BD_OtherStateType     )                       :: OS_tmp     ! Holds temporary modification to x
   TYPE(BD_InputType)                                 :: u_interp   ! interpolated value of inputs
   INTEGER(IntKi)                                     :: ErrStat2   ! Temporary Error status
   CHARACTER(ErrMsgLen)                               :: ErrMsg2    ! Temporary Error message
   CHARACTER(*), PARAMETER                            :: RoutineName = 'BD_GA2'

   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL BD_CopyInput(u(1), u_interp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
         
   CALL BD_CopyContState(x, x_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName) 
      
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
   ! initialize accelerations here:
!   if ( .not. OtherState%InitAcc) then
   if ( n .EQ. 0 .or. .not. OtherState%InitAcc) then
      !Qi, call something to initialize
      call BD_Input_extrapinterp( u, utimes, u_interp, t, ErrStat2, ErrMsg2 )
          call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
      CALL BD_InitAcc( t, u_interp, p, x_tmp, OtherState, m, ErrStat2, ErrMsg2)
          call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
      OtherState%InitAcc = .true. 

      if (m%Un_Sum > 0) then
         ! Transform quantities from global frame to local (blade) frame
         CALL BD_InputGlobalLocal(p,u_interp,ErrStat2,ErrMsg2)
            call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
      
         ! Incorporate boundary conditions
         CALL BD_BoundaryGA2(x,p,u_interp,t,OtherState,m,ErrStat2,ErrMsg2)
               call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)

         ! find x, acc, and xcc at t+dt
         CALL BD_ComputeMKGA2( x%q,x%dqdt,OtherState%acc,OtherState%xcc,u_interp, p, m, ErrStat2, ErrMsg2)
            call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)

         WRITE(m%Un_Sum,'()')
         CALL WrMatrix(m%StifK,m%Un_Sum, p%OutFmt, 'Full stiffness matrix')
         WRITE(m%Un_Sum,'()')
         CALL WrMatrix(m%MassM, m%Un_Sum, p%OutFmt, 'Full mass matrix')
          
          CLOSE(m%Un_Sum)
          m%Un_Sum = -1
      end if
      
   end if

   CALL BD_CopyOtherState(OtherState, OS_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if

   call BD_Input_extrapinterp( u, utimes, u_interp, t+p%dt, ErrStat2, ErrMsg2 )
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)

   CALL BD_UpdateDiscState( t, n, u_interp, p, x, xd, z, OtherState, m, ErrStat2, ErrMsg2 )
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
            
! Actuator
   IF( p%UsePitchAct ) THEN
      CALL PitchActuator_SetBC(p, u_interp, xd)      
   ENDIF
! END Actuator

   ! GA2: prediction        
   CALL BD_TiSchmPredictorStep( x_tmp%q,x_tmp%dqdt,OS_tmp%acc,OS_tmp%xcc,             &
                                p%coef,p%dt,x%q,x%dqdt,OtherState%acc,OtherState%xcc, &
                                p%node_total,p%dof_node, ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
   ! Transform quantities from global frame to local (blade) frame
   CALL BD_InputGlobalLocal(p,u_interp,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
   
   ! Incorporate boundary conditions
   CALL BD_BoundaryGA2(x,p,u_interp,t+p%dt,OtherState,m,ErrStat2,ErrMsg2)
         call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)

   ! find x, acc, and xcc at t+dt
   CALL BD_DynamicSolutionGA2( x%q,x%dqdt,OtherState%acc,OtherState%xcc,u_interp, p, m, ErrStat2, ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)

   call cleanup()
   return
   
contains
   subroutine cleanup()
      CALL BD_DestroyInput(u_interp, ErrStat2, ErrMsg2)
      CALL BD_DestroyContState(x_tmp, ErrStat2, ErrMsg2 )
      CALL BD_DestroyOtherState(OS_tmp, ErrStat2, ErrMsg2 )
   end subroutine cleanup   
END SUBROUTINE BD_GA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the predicted values (initial guess)
!! of u,v,acc, and xcc in generalized-alpha algorithm
SUBROUTINE BD_TiSchmPredictorStep(uuNi,vvNi,aaNi,xxNi,coef,deltat,&
                uuNf,vvNf,aaNf,xxNf,node_total,dof_node, &
                ErrStat, ErrMsg)
   REAL(BDKi),    INTENT(IN   ):: uuNi(:)
   REAL(BDKi),    INTENT(IN   ):: vvNi(:)
   REAL(BDKi),    INTENT(IN   ):: aaNi(:)
   REAL(BDKi),    INTENT(IN   ):: xxNi(:)
   REAL(DbKi),    INTENT(IN   ):: deltat
   REAL(DbKi),    INTENT(IN   ):: coef(:)
   REAL(BDKi),    INTENT(INOUT):: uuNf(:)
   REAL(BDKi),    INTENT(INOUT):: vvNf(:)
   REAL(BDKi),    INTENT(INOUT):: aaNf(:)
   REAL(BDKi),    INTENT(INOUT):: xxNf(:)
   INTEGER(IntKi),INTENT(IN   ):: node_total
   INTEGER(IntKi),INTENT(IN   ):: dof_node
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  ::vi
   REAL(BDKi)                  ::ai
   REAL(BDKi)                  ::xi
   REAL(BDKi)                  ::tr(6)
   REAL(BDKi)                  ::tr_temp(3)
   REAL(BDKi)                  ::uuNi_temp(3)
   REAL(BDKi)                  ::rot_temp(3)
   INTEGER                     ::i
   INTEGER                     ::j
   INTEGER                     ::temp_id
   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_TimSchmPredictorStep'

   ErrStat = ErrID_None
   ErrMsg  = ""

   DO i=1,node_total

       DO j=1,6
           temp_id = (i - 1) * dof_node + j
           vi = vvNi(temp_id)
           ai = aaNi(temp_id)
           xi = xxNi(temp_id)
           tr(j) = deltat * vi + coef(1) * ai + coef(2) * xi
           vvNf(temp_id) = vi + coef(3) * ai + coef(4) * xi
           aaNf(temp_id) = 0.0_BDKi
           xxNf(temp_id) = coef(5) * ai + coef(6) * xi
       ENDDO

       tr_temp = 0.0_BDKi
       uuNi_temp = 0.0_BDKi
       DO j=1,3
           temp_id = (i - 1) * dof_node + j
           uuNf(temp_id) = uuNi(temp_id) + tr(j)
           tr_temp(j) = tr(j+3)
           uuNi_temp(j) = uuNi(temp_id + 3)
       ENDDO
       rot_temp = 0.0_BDKi
       CALL BD_CrvCompose(rot_temp,tr_temp,uuNi_temp,0,ErrStat2,ErrMsg2)
         call SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,RoutineName)
       DO j=1,3
           temp_id = (i - 1) * dof_node +j
           uuNf(temp_id + 3) = rot_temp(j)
       ENDDO

   ENDDO

END SUBROUTINE BD_TiSchmPredictorStep
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calculates the coefficients used in generalized-alpha
!! time integrator
SUBROUTINE BD_TiSchmComputeCoefficients(rhoinf,deltat,coef,ErrStat,ErrMsg)

   REAL(DbKi),    INTENT(IN   ):: rhoinf
   REAL(DbKi),    INTENT(IN   ):: deltat
   REAL(DbKi),    INTENT(  OUT):: coef(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None

   REAL(DbKi)                  :: tr0
   REAL(DbKi)                  :: tr1
   REAL(DbKi)                  :: tr2
   REAL(DbKi)                  :: alfam
   REAL(DbKi)                  :: alfaf
   REAL(DbKi)                  :: gama
   REAL(DbKi)                  :: beta
   REAL(DbKi)                  :: oalfaM
   REAL(DbKi)                  :: deltat2
   CHARACTER(*),      PARAMETER:: RoutineName = 'BD_TiSchmComputeCoefficients'

   ErrStat = ErrID_None
   ErrMsg  = ""

   tr0 = rhoinf + 1.0_BDKi
   alfam = (2.0_BDKi * rhoinf - 1.0_BDKi) / tr0
   alfaf = rhoinf / tr0
   gama = 0.5_BDKi - alfam + alfaf
   beta = 0.25 * (1.0_BDKi - alfam + alfaf) * (1.0_BDKi - alfam + alfaf)

   deltat2 = deltat * deltat
   oalfaM = 1.0_BDKi - alfam
   tr0 = alfaf / oalfaM
   tr1 = alfam / oalfaM
   tr2 = (1.0_BDKi - alfaf) / oalfaM

   coef(1) = beta * tr0 * deltat2
   coef(2) = (0.5_BDKi - beta/oalfaM) * deltat2
   coef(3) = gama * tr0 * deltat
   coef(4) = (1.0_BDKi - gama / oalfaM) * deltat
   coef(5) = tr0
   coef(6) = -tr1
   coef(7) = gama * tr2 * deltat
   coef(8) = beta * tr2 * deltat2
   coef(9) = tr2

END SUBROUTINE BD_TiSchmComputeCoefficients
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine applies the prescribed boundary conditions
!! into states and otherstates at the root finite element node
SUBROUTINE BD_BoundaryGA2(x,p,u,t,OtherState,m, ErrStat,ErrMsg)

   TYPE(BD_InputType),           INTENT(IN   )  :: u           !< Inputs at t
   REAL(DbKi),                   INTENT(IN   )  :: t           !< time (s)
   TYPE(BD_ContinuousStateType), INTENT(INOUT)  :: x           !< Continuous states at t
   TYPE(BD_ParameterType),       INTENT(IN   )  :: p           !< Inputs at t
   TYPE(BD_OtherStateType),      INTENT(INOUT)  :: OtherState  !< Continuous states at t
   TYPE(BD_MiscVarType),         INTENT(INOUT)  :: m           !< misc/optimization variables
   INTEGER(IntKi),               INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                                   :: temp_cc(3)
   REAL(BDKi)                                   :: temp3(3)
   REAL(BDKi)                                   :: temp33(3,3)
   INTEGER(IntKi)                               :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                         :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                      :: RoutineName = 'BD_BoundaryGA2'

   ErrStat = ErrID_None
   ErrMsg = ""
   
   ! Root displacements
   x%q(1:3) = u%RootMotion%TranslationDisp(1:3,1)
   ! Root rotations
   temp33=u%RootMotion%Orientation(:,:,1) !possible type conversion
   CALL BD_CrvExtractCrv(temp33,temp3,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CrvCompose(temp_cc,temp3,p%Glb_crv,2,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   x%q(4:6) = MATMUL(TRANSPOSE(p%GlbRot),temp_cc)
   ! Root velocities/angular velocities and accelerations/angular accelerations
   x%dqdt(1:3) = u%RootMotion%TranslationVel(1:3,1)
   x%dqdt(4:6) = u%Rootmotion%RotationVel(1:3,1)
   OtherState%acc(1:3) = u%RootMotion%TranslationAcc(1:3,1)
   OtherState%acc(4:6) = u%RootMotion%RotationAcc(1:3,1)

END SUBROUTINE BD_BoundaryGA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine perform time-marching in one interval
!! Given states (u,v) and accelerations (acc,xcc) at the initial of a time step (t_i),
!! it returns the values of states and accelerations at the end of a time step (t_f)
SUBROUTINE BD_DynamicSolutionGA2( uuNf,vvNf,aaNf,xxNf, u, p, m, ErrStat, ErrMsg)

   TYPE(BD_InputType), INTENT(IN   ):: u
   REAL(BDKi),         INTENT(INOUT):: uuNf(:)
   REAL(BDKi),         INTENT(INOUT):: vvNf(:)
   REAL(BDKi),         INTENT(INOUT):: aaNf(:)
   REAL(BDKi),         INTENT(INOUT):: xxNf(:)
   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables   
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                   :: ErrStat2    ! Temporary Error status
   CHARACTER(ErrMsgLen)             :: ErrMsg2     ! Temporary Error message
   CHARACTER(*), PARAMETER          :: RoutineName = 'BD_DynamicSolutionGA2'         
   REAL(BDKi),           ALLOCATABLE:: DampG(:,:)
   REAL(BDKi),           ALLOCATABLE:: ai(:)
   REAL(DbKi)                       :: Eref
   REAL(DbKi)                       :: Enorm
   INTEGER(IntKi)                   :: i
   INTEGER(IntKi)                   :: j
   INTEGER(IntKi)                   :: k
   INTEGER(IntKi)                   :: temp_id
   LOGICAL                          :: fact

   ErrStat = ErrID_None
   ErrMsg  = ""
   

   CALL AllocAry(DampG,p%dof_total,p%dof_total,'Damping Matrix',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
   CALL AllocAry(ai,p%dof_total,'Increment vector',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if

   Eref = 0.0_BDKi
   DO i=1,p%niter

       IF(MOD(i-1,p%n_fact) .EQ. 0) THEN
           fact = .TRUE.
       ELSE
           fact = .FALSE.
       ENDIF

       CALL BD_GenerateDynamicElementGA2(uuNf,vvNf,aaNf, p, m, u,fact,DampG, ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
          if (ErrStat >= AbortErrLev) then
              call Cleanup()
              return
          end if

      DO j=1,p%node_total
         temp_id = (j-1)*p%dof_node
         m%F_PointLoad(temp_id+1:temp_id+3) = u%PointLoad%Force(1:3,j)
         m%F_PointLoad(temp_id+4:temp_id+6) = u%PointLoad%Moment(1:3,j)
      ENDDO
      m%RHS(:) = m%RHS(:) + m%F_PointLoad(:)
      DO j=1,p%dof_total-6
         m%RHS_LU(j) = m%RHS(j+6)
      ENDDO
   
      IF(fact) THEN
          m%StifK = m%MassM + p%coef(7) * DampG + p%coef(8) * m%StifK
          
         DO k=1,p%dof_total-6
            DO j=1,p%dof_total-6
               m%StifK_LU(j,k) = m%StifK(j+6,k+6)
            ENDDO
         ENDDO
          
         CALL LAPACK_getrf( p%dof_total-6, p%dof_total-6, m%StifK_LU, m%indx, ErrStat2, ErrMsg2) ! note m%indx is allocated larger than necessary (to allow us to use it in multiple places)
         CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
             if (ErrStat >= AbortErrLev) then
                 call Cleanup()
                 return
             end if
      ENDIF
      CALL LAPACK_getrs( 'N',p%dof_total-6, m%StifK_LU, m%indx, m%RHS_LU, ErrStat2, ErrMsg2) 
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

      ai = 0.0_BDKi
      DO j=1,p%dof_total-6
         ai(j+6) = m%RHS_LU(j)
      ENDDO
          
          
       Enorm = SQRT(abs(DOT_PRODUCT(m%RHS_LU, m%RHS(7:p%dof_total))))
          
       IF(i==1) THEN
           Eref = Enorm*p%tol
           IF(Enorm .LE. 1.0_DbKi) THEN
               CALL Cleanup()
               RETURN
           ENDIF
       ELSE 
           IF(Enorm .LE. Eref) THEN
               CALL Cleanup()
               RETURN
           ENDIF
       ENDIF

       CALL BD_UpdateDynamicGA2(ai,uuNf,vvNf,aaNf,xxNf,p%coef,p%node_total,p%dof_node,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   ENDDO
   
   CALL setErrStat( ErrID_Fatal, "Solution does not converge after the maximum number of iterations", ErrStat, ErrMsg, RoutineName)
   CALL Cleanup()
   RETURN

contains
      subroutine Cleanup()

         if (allocated(DampG      )) deallocate(DampG      )
         if (allocated(ai         )) deallocate(ai         )

      end subroutine Cleanup
END SUBROUTINE BD_DynamicSolutionGA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine perform time-marching in one interval
!! Given states (u,v) and accelerations (acc,xcc) at the initial of a time step (t_i),
!! it returns the values of states and accelerations at the end of a time step (t_f)
SUBROUTINE BD_ComputeMKGA2( uuNf,vvNf,aaNf,xxNf, u, p, m, ErrStat, ErrMsg)

   TYPE(BD_InputType), INTENT(IN   ):: u
   REAL(BDKi),         INTENT(INOUT):: uuNf(:)
   REAL(BDKi),         INTENT(INOUT):: vvNf(:)
   REAL(BDKi),         INTENT(INOUT):: aaNf(:)
   REAL(BDKi),         INTENT(INOUT):: xxNf(:)
   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables   
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                   :: ErrStat2    ! Temporary Error status
   CHARACTER(ErrMsgLen)             :: ErrMsg2     ! Temporary Error message
   CHARACTER(*), PARAMETER          :: RoutineName = 'BD_ComputeMKGA2'         
   REAL(BDKi),           ALLOCATABLE:: DampG(:,:)
   INTEGER(IntKi)                   :: i
   INTEGER(IntKi)                   :: j
   INTEGER(IntKi)                   :: k


   ErrStat = ErrID_None
   ErrMsg  = ""
   

   CALL AllocAry(DampG,p%dof_total,p%dof_total,'Damping Matrix',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
  
   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if

   CALL BD_GenerateDynamicElementGA2(uuNf,vvNf,aaNf, p, m, u,.TRUE.,DampG, ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
          call Cleanup()
          return
      end if
   CALL Cleanup()
   RETURN

contains
      subroutine Cleanup()

         if (allocated(DampG      )) deallocate(DampG      )

      end subroutine Cleanup
END SUBROUTINE BD_ComputeMKGA2
!-----------------------------------------------------------------------------------------------------------------------------------
! this routine computes m%MassM, m%RHS, m%StifK
SUBROUTINE BD_GenerateDynamicElementGA2(uuNf,vvNf,aaNf, p, m,         &
                                        u,fact,DampG, &
                                        ErrStat,ErrMsg)

   REAL(BDKi),        INTENT(IN   ):: uuNf(:)
   REAL(BDKi),        INTENT(IN   ):: vvNf(:)
   REAL(BDKi),        INTENT(IN   ):: aaNf(:)
   TYPE(BD_InputType),INTENT(IN   ):: u
   LOGICAL,           INTENT(IN   ):: fact
   REAL(BDKi),        INTENT(  OUT):: DampG(:,:)
   
   TYPE(BD_ParameterType),INTENT(IN   ):: p           !< Parameters
   TYPE(BD_MiscVarType),  INTENT(INOUT):: m           !< misc/optimization variables      
   INTEGER(IntKi),        INTENT(  OUT):: ErrStat     !< Error status of the operation
   CHARACTER(*),          INTENT(  OUT):: ErrMsg      !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                  :: nelem
   INTEGER(IntKi)                  :: j
   INTEGER(IntKi)                  :: temp_id
   INTEGER(IntKi)                  :: temp_id2
   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*),          PARAMETER:: RoutineName = 'BD_GenerateDynamicElementGA2'

   ErrStat    = ErrID_None
   ErrMsg     = ""
   
      ! must initialize these because BD_AssembleStiffK and BD_AssembleRHS are INOUT
   DampG(:,:) = 0.0_BDKi
   m%StifK = 0.0_BDKi
   m%MassM = 0.0_BDKi
   m%RHS = 0.0_BDKi


   DO nelem=1,p%elem_total
       CALL BD_ElemNodalDisp(uuNf,p%node_elem,p%dof_node,nelem,m%Nuuu,ErrStat2,ErrMsg2) ! set m%Nuuu
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_NodalRelRot(m%Nuuu,p%node_elem,p%dof_node,m%Nrrr,ErrStat2,ErrMsg2)       ! set m%Nrrr
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )          
       CALL BD_ElemNodalDisp(vvNf,p%node_elem,p%dof_node,nelem,m%Nvvv,ErrStat2,ErrMsg2) ! set m%Nvvv
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       CALL BD_ElemNodalDisp(aaNf,p%node_elem,p%dof_node,nelem,m%Naaa,ErrStat2,ErrMsg2) ! set m%Naaa
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       IF(p%quadrature .EQ. 1) THEN
           temp_id = (nelem-1)*p%ngp + 1
           temp_id2 = (nelem-1)*p%ngp
       ELSEIF(p%quadrature .EQ. 2) THEN
           temp_id = (nelem-1)*p%ngp
           temp_id2= temp_id
       ENDIF

       DO j=1,p%ngp
           m%EStif0_GL(:,:,j) = p%Stif0_GL(1:6,1:6,temp_id2+j)
           m%EMass0_GL(:,:,j) = p%Mass0_GL(1:6,1:6,temp_id2+j)
           m%DistrLoad_GL(1:3,j) = u%DistrLoad%Force(1:3,temp_id+j)
           m%DistrLoad_GL(4:6,j) = u%DistrLoad%Moment(1:3,temp_id+j)
       ENDDO
            
         ! compute m%elk,m%elf,m%elm,m%elg:     
       CALL BD_ElementMatrixGA2(m%Nuuu,m%Nrrr,m%Nvvv,m%Naaa,&
                              m%EStif0_GL,m%EMass0_GL,p%gravity,m%DistrLoad_GL,         &
                              p%damp_flag,p%beta,                                   &
                              p%ngp,p%GLw,p%Shp,p%Der,p%Jacobian(:,nelem),p%uu0(:,nelem),p%E10(:,nelem),&
                              p%node_elem,p%dof_node,fact,m%elk,m%elf,m%elm,m%elg,          &
                              ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
       IF(fact) THEN
           CALL BD_AssembleStiffK(nelem,p%node_elem,p%dof_elem,p%dof_node,m%elk,m%StifK,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
           CALL BD_AssembleStiffK(nelem,p%node_elem,p%dof_elem,p%dof_node,m%elm,m%MassM,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
           CALL BD_AssembleStiffK(nelem,p%node_elem,p%dof_elem,p%dof_node,m%elg,DampG,ErrStat2,ErrMsg2)
              CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       ENDIF
       CALL BD_AssembleRHS(nelem,p%dof_elem,p%node_elem,p%dof_node,m%elf,m%RHS,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

      if (ErrStat >= AbortErrLev) return
   ENDDO

   RETURN

END SUBROUTINE BD_GenerateDynamicElementGA2
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine tranforms the folloing quantities in Input data structure
!! from global frame to local (blade) frame:
!! 1 Displacements; 2 Linear/Angular velocities; 3 Linear/Angular accelerations
!! 4 Point forces/moments; 5 Distributed forces/moments
!! It also transforms the DCM to rotation tensor in the input data structure
SUBROUTINE BD_InputGlobalLocal( p, u, ErrStat, ErrMsg)

   TYPE(BD_ParameterType), INTENT(IN   ):: p
   TYPE(BD_InputType),     INTENT(INOUT):: u
   INTEGER(IntKi),         INTENT(  OUT):: ErrStat       ! Error status of the operation
   CHARACTER(*),           INTENT(  OUT):: ErrMsg        ! Error message if ErrStat /= ErrID_None
                                                           ! 1: Blade to Global
   REAL(BDKi)                           :: temp33(3,3)
   REAL(BDKi)                           :: temp_v(3)
   REAL(BDKi)                           :: temp_v2(3)
   INTEGER(IntKi)                       :: i
   INTEGER(IntKi)                       :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                 :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER              :: RoutineName = 'BD_InputGlobalLocal'

   ErrStat = ErrID_None
   ErrMsg  = ""

   temp_v(:) = u%RootMotion%TranslationDisp(:,1)
   u%RootMotion%TranslationDisp(1,1) = temp_v(3) 
   u%RootMotion%TranslationDisp(2,1) = temp_v(1) 
   u%RootMotion%TranslationDisp(3,1) = temp_v(2) 
   temp_v(:) = u%RootMotion%TranslationVel(:,1)
   u%RootMotion%TranslationVel(1,1) = temp_v(3) 
   u%RootMotion%TranslationVel(2,1) = temp_v(1) 
   u%RootMotion%TranslationVel(3,1) = temp_v(2) 
   temp_v(:) = u%RootMotion%RotationVel(:,1)
   u%RootMotion%RotationVel(1,1) = temp_v(3) 
   u%RootMotion%RotationVel(2,1) = temp_v(1) 
   u%RootMotion%RotationVel(3,1) = temp_v(2) 
   temp_v(:) = u%RootMotion%TranslationAcc(:,1)
   u%RootMotion%TranslationAcc(1,1) = temp_v(3) 
   u%RootMotion%TranslationAcc(2,1) = temp_v(1) 
   u%RootMotion%TranslationAcc(3,1) = temp_v(2) 
   temp_v(:) = u%RootMotion%RotationAcc(:,1)
   u%RootMotion%RotationAcc(1,1) = temp_v(3) 
   u%RootMotion%RotationAcc(2,1) = temp_v(1) 
   u%RootMotion%RotationAcc(3,1) = temp_v(2) 
   ! Transform Root Motion from Global to Local (Blade) frame
   u%RootMotion%TranslationDisp(:,1) = MATMUL(u%RootMotion%TranslationDisp(:,1),p%GlbRot)  ! = MATMUL(TRANSPOSE(p%GlbRot),u%RootMotion%TranslationDisp(:,1))
   u%RootMotion%TranslationVel(:,1)  = MATMUL(u%RootMotion%TranslationVel( :,1),p%GlbRot)  ! = MATMUL(TRANSPOSE(p%GlbRot),u%RootMotion%TranslationVel(:,1))
   u%RootMotion%RotationVel(:,1)     = MATMUL(u%RootMotion%RotationVel(    :,1),p%GlbRot)  ! = MATMUL(TRANSPOSE(p%GlbRot),u%RootMotion%RotationVel(:,1))
   u%RootMotion%TranslationAcc(:,1)  = MATMUL(u%RootMotion%TranslationAcc( :,1),p%GlbRot)  ! = MATMUL(TRANSPOSE(p%GlbRot),u%RootMotion%TranslationAcc(:,1))
   u%RootMotion%RotationAcc(:,1)     = MATMUL(u%RootMotion%RotationAcc(    :,1),p%GlbRot)  ! = MATMUL(TRANSPOSE(p%GlbRot),u%RootMotion%RotationAcc(:,1))
   ! Transform DCM to Rotation Tensor (RT)
   temp33 = TRANSPOSE(u%RootMotion%Orientation(:,:,1)) !possible type conversion
   CALL BD_CrvExtractCrv(temp33,temp_v,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   temp_v2(1) = temp_v(3)
   temp_v2(2) = temp_v(1)
   temp_v2(3) = temp_v(2)
   CALL BD_CrvMatrixR(temp_v2,temp33,ErrStat2,ErrMsg2)
   u%RootMotion%Orientation(:,:,1)=temp33 !possible type conversion
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   ! Transform Applied Forces from Global to Local (Blade) frame
   DO i=1,p%node_total
       temp_v(:) = u%PointLoad%Force(1:3,i)
       u%PointLoad%Force(1,i) = temp_v(3)
       u%PointLoad%Force(2,i) = temp_v(1)
       u%PointLoad%Force(3,i) = temp_v(2)
       u%PointLoad%Force(1:3,i)  = MATMUL(u%PointLoad%Force(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%PointLoad%Force(:,i))
       temp_v(:) = u%PointLoad%Moment(1:3,i)
       u%PointLoad%Moment(1,i) = temp_v(3)
       u%PointLoad%Moment(2,i) = temp_v(1)
       u%PointLoad%Moment(3,i) = temp_v(2)
       u%PointLoad%Moment(1:3,i) = MATMUL(u%PointLoad%Moment(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%PointLoad%Moment(:,i))
   ENDDO
   IF(p%quadrature .EQ. 1) THEN
       DO i=1,p%ngp * p%elem_total + 2
           temp_v(:) = u%DistrLoad%Force(1:3,i)
           u%DistrLoad%Force(1,i) = temp_v(3)
           u%DistrLoad%Force(2,i) = temp_v(1)
           u%DistrLoad%Force(3,i) = temp_v(2)
           u%DistrLoad%Force(1:3,i)  = MATMUL(u%DistrLoad%Force(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%DistrLoad%Force(:,i))
           temp_v(:) = u%DistrLoad%Moment(1:3,i)
           u%DistrLoad%Moment(1,i) = temp_v(3)
           u%DistrLoad%Moment(2,i) = temp_v(1)
           u%DistrLoad%Moment(3,i) = temp_v(2)
           u%DistrLoad%Moment(1:3,i) = MATMUL(u%DistrLoad%Moment(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%DistrLoad%Moment(:,i))
       ENDDO
   ELSEIF(p%quadrature .EQ. 2) THEN
       DO i=1,p%ngp
           temp_v(:) = u%DistrLoad%Force(1:3,i)
           u%DistrLoad%Force(1,i) = temp_v(3)
           u%DistrLoad%Force(2,i) = temp_v(1)
           u%DistrLoad%Force(3,i) = temp_v(2)
           u%DistrLoad%Force(1:3,i)  = MATMUL(u%DistrLoad%Force(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%DistrLoad%Force(:,i))
           temp_v(:) = u%DistrLoad%Moment(1:3,i)
           u%DistrLoad%Moment(1,i) = temp_v(3)
           u%DistrLoad%Moment(2,i) = temp_v(1)
           u%DistrLoad%Moment(3,i) = temp_v(2)
           u%DistrLoad%Moment(1:3,i) = MATMUL(u%DistrLoad%Moment(:,i),p%GlbRot) !=MATMUL(TRANSPOSE(p%GlbRot),u%DistrLoad%Moment(:,i)) 
       ENDDO
   ENDIF

END SUBROUTINE BD_InputGlobalLocal
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes the initial states
!! Rigid body assumption is used in initialization of the states.
!! The initial displacements/rotations and linear velocities are 
!! set to the root value; the angular velocities over the beam 
!! are computed based on rigid body rotation: \omega = v_{root} \times r_{pos}
SUBROUTINE BD_CalcIC( u, p, x, ErrStat, ErrMsg)

   TYPE(BD_InputType),           INTENT(INOUT):: u             !< Inputs at t
   TYPE(BD_ParameterType),       INTENT(IN   ):: p             !< Parameters
   TYPE(BD_ContinuousStateType), INTENT(INOUT):: x             !< Continuous states at t

   INTEGER(IntKi),               INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                             :: i
   INTEGER(IntKi)                             :: j
   INTEGER(IntKi)                             :: k
   INTEGER(IntKi)                             :: temp_id
   INTEGER(IntKi)                             :: temp_id2
   REAL(BDKi)                                 :: temp3(3)
   REAL(BDKi)                                 :: temp_p0(3)
   REAL(BDKi)                                 :: temp_rv(3)
   REAL(BDKi)                                 :: temp_R(3,3)
   REAL(BDKi)                                 :: GlbRot_TransVel(3)           ! = MATMUL(p%GlbRot,u%RootMotion%TranslationVel(:,1))
   REAL(BDKi)                                 :: GlbRot_RotVel_tilde(3,3)     ! = BD_Tilde(MATMUL(p%GlbRot,u%RootMotion%RotationVel(:,1)))
   REAL(BDKi)                                 :: temp33(3,3)
   INTEGER(IntKi)                             :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                       :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                    :: RoutineName = 'BD_CalcIC'

   ErrStat = ErrID_None
   ErrMsg  = ""

   temp33=u%RootMotion%Orientation(:,:,1) ! possible type conversion
   CALL BD_CrvExtractCrv(temp33,temp3,ErrStat2,ErrMsg2) !returns temp3
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CrvCompose(temp_rv,temp3,p%Glb_crv,2,ErrStat2,ErrMsg2)  !returns temp_rv
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CrvMatrixR(temp_rv,temp_R,ErrStat2,ErrMsg2) !returns temp_R
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      
      
   !Initialize displacements and rotations
   k = 1 !when i=1, k=1
   DO i=1,p%elem_total
      DO j=k,p%node_elem
         temp_id = (j-1)*p%dof_node
         temp_p0 = MATMUL(p%GlbRot,p%uuN0(temp_id+1:temp_id+3,i))
         temp_p0 = MATMUL(temp_R,temp_p0) - temp_p0
         temp_p0 = MATMUL(temp_p0,p%GlbRot) != transpose(MATMUL(transpose(temp_p0),p%GlbRot)) = MATMUL(TRANSPOSE(p%GlbRot),temp_p0)  [transpose of a 1-d array temp_p0 is temp_p0]
         
         temp_id = ((i-1)*(p%node_elem-1)+j-1)*p%dof_node
         x%q(temp_id+1:temp_id+3) = u%RootMotion%TranslationDisp(1:3,1) + temp_p0
      ENDDO
      k = 2 ! start j loop at k=2 for remaining elements (i>1)
   ENDDO
   
   k = 1 !when i=1, k=1
   DO i=1,p%elem_total
      DO j=k,p%node_elem
         temp_id = ((i-1)*(p%node_elem-1)+j-1)*p%dof_node
         x%q(temp_id+4:temp_id+6) = MATMUL(temp_rv,p%GlbRot) != transpose(MATMUL(TRANSPOSE(temp_rv),p%GlbRot) = MATMUL(TRANSPOSE(p%GlbRot),temp_rv) because temp_rv is 1-dimension
      ENDDO
      k = 2 ! start j loop at k=2 for remaining elements (i>1)
   ENDDO

   !Initialize velocities and angular velocities
   x%dqdt(:) = 0.0_BDKi
   
   ! these values don't change in the loop:
   GlbRot_TransVel     = MATMUL(p%GlbRot,u%RootMotion%TranslationVel(:,1))
   GlbRot_RotVel_tilde = BD_Tilde(MATMUL(p%GlbRot,u%RootMotion%RotationVel(:,1)))
   k=1 !when i=1, k=1
   DO i=1,p%elem_total
      DO j=k,p%node_elem
         temp_id = (j-1)*p%dof_node
         temp_id2 = ((i-1)*(p%node_elem-1)+j-1)*p%dof_node
         
         temp3 = MATMUL(p%GlbRot, p%uuN0(temp_id+1:temp_id+3,i) + x%q(temp_id2+1:temp_id2+3) )
         temp3 = GlbRot_TransVel + MATMUL(GlbRot_RotVel_tilde,temp3)
         
         temp_id = ((i-1)*(p%node_elem-1)+j-1)*p%dof_node
         x%dqdt(temp_id2+1:temp_id2+3) = MATMUL(temp3,p%GlbRot) ! = transpose(MATMUL(transpose(temp3),p%GlbRot)) = MATMUL(TRANSPOSE(p%GlbRot),temp3)  because temp3 is 1-dimension
         x%dqdt(temp_id2+4:temp_id2+6) = u%RootMotion%RotationVel(1:3,1)
      ENDDO
      k = 2 ! start j loop at k=2 for remaining elements (i>1)
   ENDDO

END SUBROUTINE BD_CalcIC
!-----------------------------------------------------------------------------------------------------------------------------------
!> Routine for computing derivatives of continuous states.
!! This subroutine calculates the reaction forces/moments at the root
!! and the accelerations at all other FE points along the beam
SUBROUTINE BD_CalcForceAcc( u, p, m, x, OtherState, ErrStat, ErrMsg)

   TYPE(BD_InputType),           INTENT(IN   ):: u             !< Inputs at t
   TYPE(BD_ParameterType),       INTENT(IN   ):: p             !< Parameters
   TYPE(BD_MiscVarType),         INTENT(INOUT):: m             !< Misc/optimization variables
   TYPE(BD_ContinuousStateType), INTENT(IN   ):: x             !< Continuous states at t
   TYPE(BD_OtherStateType),      INTENT(INOUT):: OtherState    !< Other states at t
   INTEGER(IntKi),               INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                             :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                       :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                    :: RoutineName = 'BD_CalcForceAcc'

   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL BD_SolutionForceAcc(x%q,x%dqdt,u, p, m, OtherState%Acc,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   if (ErrStat >= AbortErrLev) RETURN

END SUBROUTINE BD_CalcForceAcc
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine calls other subroutines to apply the force, build the beam element
!! stiffness and mass matrices, build nodal force vector.  The output of this subroutine
!! is the second time derivative of state "q".
SUBROUTINE BD_SolutionForceAcc(uuN,vvN,u, p, m, Acc,ErrStat,ErrMsg)

   TYPE(BD_InputType),           INTENT(IN   ):: u             !< Inputs at t
   TYPE(BD_ParameterType),       INTENT(IN   ):: p             !< Parameters
   TYPE(BD_MiscVarType),         INTENT(INOUT):: m             !< Misc/optimization variables
   REAL(BDKi),                   INTENT(IN   ):: uuN(:)        !< Displacement of Mass 1: m
   REAL(BDKi),                   INTENT(IN   ):: vvN(:)        !< Velocity of Mass 1: m/s
   REAL(BDKi),                   INTENT(  OUT):: Acc(:)
   INTEGER(IntKi),               INTENT(  OUT):: ErrStat       !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT):: ErrMsg        !< Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                             :: j
   INTEGER(IntKi)                             :: k
   INTEGER(IntKi)                             :: temp_id
   REAL(BDKi)                                 :: temp6(6)
   INTEGER(IntKi)                             :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                       :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                    :: RoutineName = 'BD_SolutionForceAcc'

   ErrStat = ErrID_None
   ErrMsg  = ""


   CALL BD_GenerateDynamicElementAcc(uuN,vvN,u, p, m, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   DO j=1,p%node_total
       temp_id = (j-1)*p%dof_node
       m%F_PointLoad(temp_id+1:temp_id+3) = u%PointLoad%Force(1:3,j)
       m%F_PointLoad(temp_id+4:temp_id+6) = u%PointLoad%Moment(1:3,j)
   ENDDO
   temp6(1:3) = u%RootMotion%TranslationAcc(1:3,1)
   temp6(4:6) = u%RootMotion%RotationAcc(1:3,1)
   m%RHS(:)   = m%RHS(:) + m%F_PointLoad(:)
   m%RHS(1:6) = m%RHS(1:6) - MATMUL(m%MassM(1:6,1:6),temp6)
   m%RHS(7:p%dof_total) = m%RHS(7:p%dof_total) - MATMUL(m%MassM(7:p%dof_total,1:6),temp6)
   DO j=1,p%dof_total
       DO k=1,6
           m%MassM(j,k) = 0.0_BDKi
       ENDDO
   ENDDO
   DO j=1,6
       m%MassM(j,j) = -1.0_BDKi
   ENDDO

   CALL LAPACK_getrf( p%dof_total, p%dof_total, m%MassM, m%indx, ErrStat2, ErrMsg2) 
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
    CALL LAPACK_getrs( 'N',p%dof_total, m%MassM, m%indx, m%RHS,ErrStat2, ErrMsg2) 
       CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   if (ErrStat >= AbortErrLev) return

   Acc(:) = m%RHS(:)

   RETURN
END SUBROUTINE BD_SolutionForceAcc
!-----------------------------------------------------------------------------------------------------------------------------------
!! Routine for computing outputs, used in both loose and tight coupling.
SUBROUTINE BD_InitAcc( t, u, p, x, OtherState, m, ErrStat, ErrMsg )

   REAL(DbKi),                   INTENT(IN   )  :: t           !< Current simulation time in seconds
   TYPE(BD_InputType),           INTENT(INOUT)  :: u           !< Inputs at t
   TYPE(BD_ParameterType),       INTENT(IN   )  :: p           !< Parameters
   TYPE(BD_ContinuousStateType), INTENT(IN   )  :: x           !< Continuous states at t
   TYPE(BD_OtherStateType),      INTENT(INOUT)  :: OtherState  !< Other states at t
   TYPE(BD_MiscVarType),         INTENT(INOUT)  :: m           !< Misc/optimization variables
   INTEGER(IntKi),               INTENT(  OUT)  :: ErrStat     !< Error status of the operation
   CHARACTER(*),                 INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

   TYPE(BD_OtherStateType)                      :: OS_tmp
   TYPE(BD_ContinuousStateType)                 :: x_tmp
   INTEGER(IntKi)                               :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)                         :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER                      :: RoutineName = 'BD_InitAcc'
   
   ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL BD_CopyContState(x, x_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_CopyOtherState(OtherState, OS_tmp, MESH_NEWCOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )   
   CALL BD_CopyInput(u, m%u, MESH_UPDATECOPY, ErrStat2, ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
      if (ErrStat >= AbortErrLev) then
         call cleanup()
         return
      end if
      
   CALL BD_InputGlobalLocal(p,m%u,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL BD_BoundaryGA2(x_tmp,p,m%u,t,OS_tmp,m,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

   CALL BD_CalcForceAcc(m%u,p,m,x_tmp,OS_tmp,ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
       
   OtherState%Acc(:)   = OS_tmp%Acc(:)
   OtherState%Acc(1:3) = m%u%RootMotion%TranslationAcc(1:3,1)
   OtherState%Acc(4:6) = m%u%RootMotion%RotationAcc(1:3,1)
   OtherState%Xcc(:)   = OtherState%Acc(:)

   call cleanup()
   return
   
contains
   subroutine cleanup()
      CALL BD_DestroyContState(x_tmp, ErrStat2, ErrMsg2 )
      CALL BD_DestroyOtherState(OS_tmp, ErrStat2, ErrMsg2 )
   end subroutine cleanup 
END SUBROUTINE BD_InitAcc
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine computes Global mass matrix and force vector for the beam.
SUBROUTINE BD_ComputeBladeMassNew(Mass0,GaussPos,         &
                                  elem_total,node_elem,dof_node,&
                                  quadrature,ngp,gw,Jaco,&
                                  blade_mass,blade_CG,blade_IN,ErrStat,ErrMsg)

   REAL(BDKi),        INTENT(IN   ):: Mass0(:,:,:)    !< Element stiffness matrix
   REAL(BDKi),        INTENT(IN   ):: GaussPos(:,:)   !< Initial position vector
   INTEGER(IntKi),    INTENT(IN   ):: elem_total      !< Total number of elements
   INTEGER(IntKi),    INTENT(IN   ):: node_elem       !< Node per element
   INTEGER(IntKi),    INTENT(IN   ):: dof_node        !< Degrees of freedom per node
   INTEGER(IntKi),    INTENT(IN   ):: quadrature
   INTEGER(IntKi),    INTENT(IN   ):: ngp             !< Number of Gauss points
   REAL(BDKi),        INTENT(IN   ):: gw(:) 
   REAL(BDKi),        INTENT(IN   ):: Jaco(:,:) 
   REAL(BDKi),        INTENT(  OUT):: blade_mass      !< Mass matrix
   REAL(BDKi),        INTENT(  OUT):: blade_CG(:)     !< Mass matrix
   REAL(BDKi),        INTENT(  OUT):: blade_IN(:,:)   !< Mass matrix
   INTEGER(IntKi),    INTENT(  OUT):: ErrStat         !< Error status of the operation
   CHARACTER(*),      INTENT(  OUT):: ErrMsg          !< Error message if ErrStat /= ErrID_None

   REAL(BDKi),          ALLOCATABLE:: NGPpos(:,:)
   REAL(BDKi)                      :: elem_mass
   REAL(BDKi)                      :: elem_CG(3)
   REAL(BDKi)                      :: elem_IN(3,3)
   REAL(BDKi),          ALLOCATABLE:: EMass0_GL(:,:,:)
   INTEGER(IntKi)                  :: dof_elem ! Degree of freedom per node
   INTEGER(IntKi)                  :: nelem ! number of elements
   INTEGER(IntKi)                  :: j ! Index counter
   INTEGER(IntKi)                  :: temp_id ! Index counter
   INTEGER(IntKi)                  :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)            :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER         :: RoutineName = 'BD_ComputeBladeMassNew'

   ErrStat    = ErrID_None
   ErrMsg     = ""
   blade_mass = 0.0_BDKi

   dof_elem = dof_node * node_elem

   CALL AllocAry(NGPpos,3,ngp,'NGPpos',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   CALL AllocAry(EMass0_GL,6,6,ngp,'EMass0_GL',ErrStat2,ErrMsg2)
      CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )
   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if
   NGPpos(:,:)  = 0.0_BDKi
   EMass0_GL(:,:,:)  = 0.0_BDKi
   elem_mass= 0.0_BDKi
   elem_CG(:)= 0.0_BDKi
   elem_IN(:,:)= 0.0_BDKi

   DO nelem=1,elem_total

       temp_id = (nelem-1)*ngp
       DO j=1,ngp
           EMass0_GL(1:6,1:6,j) = Mass0(1:6,1:6,temp_id+j)
           IF(quadrature .EQ. 1) THEN
               NGPpos(1:3,j) = GaussPos(1:3,temp_id+j+1)
           ELSEIF(quadrature .EQ. 2) THEN
               NGPpos(1:3,j) = GaussPos(1:3,temp_id+j)
           ENDIF 
       ENDDO

       CALL BD_ComputeElementMass(NGPpos,EMass0_GL,&
                                  ngp,gw,Jaco(:,nelem),&
                                  elem_mass,elem_CG,elem_IN,ErrStat2,ErrMsg2)
          CALL SetErrStat( ErrStat2, ErrMsg2, ErrStat, ErrMsg, RoutineName )

       blade_mass = blade_mass + elem_mass
       blade_CG(:) = blade_CG(:) + elem_CG(:)
       blade_IN(:,:) = blade_IN(:,:) + elem_IN(:,:)

   ENDDO

   if (ErrStat >= AbortErrLev) then
       call Cleanup()
       return
   end if

   blade_CG(:) = blade_CG(:) / blade_mass

   CALL Cleanup()
   RETURN

contains
      subroutine Cleanup()

         if (allocated(NGPpos      )) deallocate(NGPpos      )
         if (allocated(EMass0_GL   )) deallocate(EMass0_GL   )

      end subroutine Cleanup

END SUBROUTINE BD_ComputeBladeMassNew
!-----------------------------------------------------------------------------------------------------------------------------------
!> This subroutine total element forces and mass matrices
SUBROUTINE BD_ComputeElementMass(NGPpos,EMass0_GL,&
                                 ngp,gw,Jaco,&
                                 elem_mass,elem_CG,elem_IN,ErrStat,ErrMsg)

   REAL(BDKi),INTENT(IN   )    :: NGPpos(:,:)
   REAL(BDKi),INTENT(IN   )    :: EMass0_GL(:,:,:) !< Nodal material properties for each element
   REAL(BDKi),INTENT(  OUT)    :: elem_mass        !< Total element force (Fd, Fc, Fb)
   REAL(BDKi),INTENT(  OUT)    :: elem_CG(:)
   REAL(BDKi),INTENT(  OUT)    :: elem_IN(:,:)
   INTEGER(IntKi),INTENT(IN   ):: ngp              !< Number of Gauss points
   REAL(BDKi),    INTENT(IN   ):: gw(:)
   REAL(BDKi),    INTENT(IN   ):: Jaco(:)
   INTEGER(IntKi),INTENT(  OUT):: ErrStat          !< Error status of the operation
   CHARACTER(*),  INTENT(  OUT):: ErrMsg           !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                  :: mmm
   INTEGER(IntKi)              :: igp
!   INTEGER(IntKi)              :: ErrStat2                     ! Temporary Error status
!   CHARACTER(ErrMsgLen)        :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER     :: RoutineName = 'BD_ComputeElementMass'

   ErrStat  = ErrID_None
   ErrMsg   = ""
   elem_mass  = 0.0_BDKi
   elem_CG(:) = 0.0_BDKi
   elem_IN(:,:) = 0.0_BDKi


   DO igp=1,ngp

       mmm  = 0.0_BDKi
       mmm  = EMass0_GL(1,1,igp)

       elem_mass = elem_mass + gw(igp) * Jaco(igp) * mmm
       elem_CG(1:3) = elem_CG(1:3) + gw(igp) * Jaco(igp) * mmm * NGPpos(1:3,igp)
       elem_IN(1:3,1:3) = elem_IN(1:3,1:3) + gw(igp) * Jaco(igp) * mmm * &
                          MATMUL(BD_Tilde(NGPpos(1:3,igp)),TRANSPOSE(BD_Tilde(NGPpos(1:3,igp))))

   ENDDO


   RETURN

END SUBROUTINE BD_ComputeElementMass
!-----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE BD_InitShpDerJaco(quadrature,GL,GLL,uuN0,&
               node_elem,elem_total,dof_node,ngp,&
               refine,kp_member,&
               hhx,hpx,TZw,Jacobian,&
               ErrStat,ErrMsg)

   REAL(BDKi),         INTENT(INOUT):: GL(:)          !< GL(Gauss) point locations
   REAL(BDKi),         INTENT(IN   ):: GLL(:)         !< GLL point locations
   REAL(BDKi),         INTENT(IN   ):: uuN0(:,:)      !< Initial position vector
   INTEGER(IntKi),     INTENT(IN   ):: quadrature     !< Quadrature method
   INTEGER(IntKi),     INTENT(IN   ):: node_elem      !< Nodes per element
   INTEGER(IntKi),     INTENT(IN   ):: elem_total     !< Total number of elements
   INTEGER(IntKi),     INTENT(IN   ):: dof_node
   INTEGER(IntKi),     INTENT(IN   ):: ngp            !< Number of quadrature points
   INTEGER(IntKi),     INTENT(IN   ):: refine         !< TZ refinement parameter
   INTEGER(IntKi),     INTENT(IN   ):: kp_member(:)   !< Number of key points in each member
   REAL(BDKi),         INTENT(  OUT):: hhx(:,:)       !< Shape function matrix
   REAL(BDKi),         INTENT(  OUT):: hpx(:,:)       !< Derivative of shape function matrix
   REAL(BDKi),         INTENT(  OUT):: TZw(:)         !< TZ weight functions 
   REAL(BDKi),         INTENT(  OUT):: Jacobian(:,:)  !< Jacobians at each quadrature point
   INTEGER(IntKi),     INTENT(  OUT):: ErrStat        !< Error status of the operation
   CHARACTER(*),       INTENT(  OUT):: ErrMsg         !< Error message if ErrStat /= ErrID_None

   REAL(BDKi)                       :: temp1
   REAL(BDKi)                       :: temp2
   REAL(BDKi)                       :: Gup0(3)
   INTEGER(IntKi)                   :: temp_id
   INTEGER(IntKi)                   :: temp_id0
   INTEGER(IntKi)                   :: temp_id1
   INTEGER(IntKi)                   :: id0
   INTEGER(IntKi)                   :: id1
   INTEGER(IntKi)                   :: inode
   INTEGER(IntKi)                   :: i
   INTEGER(IntKi)                   :: j
   INTEGER(IntKi)                   :: m

   INTEGER(IntKi)                   :: ErrStat2                     ! Temporary Error status
   CHARACTER(ErrMsgLen)             :: ErrMsg2                      ! Temporary Error message
   CHARACTER(*), PARAMETER          :: RoutineName = 'BD_InitShpDerJaco'

   ErrStat = ErrID_None
   ErrMsg  = ""
   
   IF(quadrature .EQ. 2) THEN
       DO j=1,ngp
           temp_id = 0
           id0 = 1
           id1 = kp_member(1)
           temp_id0 = (id0 - 1)*refine + 1
           temp_id1 = (id1 - 1)*refine + 1
           IF(j .EQ. 1) THEN
               temp1 = -1.0_BDKi + (GL(temp_id0+j-1) - GL(temp_id0))*2.0_BDKi/ &
                                       (GL(temp_id1) - GL(temp_id0))
               temp2 = -1.0_BDKi + (GL(temp_id0+j) - GL(temp_id0))*2.0_BDKi/ &
                                     (GL(temp_id1) - GL(temp_id0))
               TZw(j) = 0.5_BDKi * (temp2 - temp1)
           ELSEIF(j .EQ. ngp) THEN
               temp1 = -1.0_BDKi + (GL(temp_id1-1) - GL(temp_id0))*2.0_BDKi/ &
                                   (GL(temp_id1  ) - GL(temp_id0))
               temp2 = -1.0_BDKi + (GL(temp_id1) - GL(temp_id0))*2.0_BDKi/ &
                                   (GL(temp_id1) - GL(temp_id0))
               TZw(j) = 0.5_BDKi * (temp2 - temp1)
           ELSE 
               temp1 = -1.0_BDKi + (GL(temp_id0+j-2) - GL(temp_id0))*2.0_BDKi/ &
                                   (GL(temp_id1) - GL(temp_id0))
               temp2 = -1.0_BDKi + (GL(temp_id0+j) - GL(temp_id0))*2.0_BDKi/ &
                                   (GL(temp_id1) - GL(temp_id0))
               TZw(j) = 0.5_BDKi * (temp2 - temp1)
           ENDIF
       ENDDO
       GL(:) = 2.0_BDKi*GL(:) - 1.0_BDKi
   ENDIF

   CALL BD_diffmtc(node_elem-1,ngp,GL,GLL,hhx,hpx,ErrStat2,ErrMsg2)
      call SetErrStat(ErrStat2,ErrMsg2, ErrStat, ErrMsg, RoutineName)

   DO i = 1,elem_total
       DO j = 1, ngp
           Gup0(:) = 0.0_BDKi
           DO inode=1,node_elem
               temp_id = (inode-1)*dof_node
               DO m=1,3
                   Gup0(m) = Gup0(m) + hpx(inode,j)*uuN0(temp_id+m,i)
               ENDDO
           ENDDO

           Jacobian(j,i) = SQRT(DOT_PRODUCT(Gup0,Gup0))

       ENDDO
   ENDDO

END SUBROUTINE BD_InitshpDerJaco
!-----------------------------------------------------------------------------------------------------------------------------------
!> This routine alters the RootMotion inputs based on the pitch-actuator parameters and discrete states
SUBROUTINE PitchActuator_SetBC(p, u, xd, AllOuts)

   TYPE(BD_ParameterType),    INTENT(IN   )  :: p                                 !< The module parameters
   TYPE(BD_InputType),        INTENT(INOUT)  :: u                                 !< inputs
   TYPE(BD_DiscreteStateType),INTENT(IN   )  :: xd                                !< The module discrete states
   REAL(ReKi),       OPTIONAL,INTENT(INOUT)  :: AllOuts(0:)                       !< all output array for writing to file
   ! local variables
   REAL(BDKi)                                :: temp_R(3,3)
   REAL(BDKi)                                :: temp_cc(3)
   REAL(BDKi)                                :: u_theta_pitch
   REAL(BDKi)                                :: thetaP
   REAL(BDKi)                                :: omegaP
   REAL(BDKi)                                :: alphaP
   
   
   temp_R = MATMUL(u%RootMotion%Orientation(:,:,1),TRANSPOSE(u%HubMotion%Orientation(:,:,1)))
   temp_cc = EulerExtract(temp_R)   != Hub_theta_Root
   u_theta_pitch = -temp_cc(3)
       
   thetaP = xd%thetaP
   omegaP = xd%thetaPD
   alphaP = -(p%pitchK/p%pitchJ) * xd%thetaP - (p%pitchC/p%pitchJ) * xd%thetaPD + (p%pitchK/p%pitchJ) * u_theta_pitch
       
   ! Calculate new root motions for use as BeamDyn boundary conditions:       
   !note: we alter the orientation last because we need the input (before actuator) root orientation for the rotational velocity and accelerations
   u%RootMotion%RotationVel(:,1) = u%RootMotion%RotationVel(:,1) - omegaP * u%RootMotion%Orientation(3,:,1)
   u%RootMotion%RotationAcc(:,1) = u%RootMotion%RotationAcc(:,1) - alphaP * u%RootMotion%Orientation(3,:,1)

   temp_cc(3) = -thetaP
   temp_R = EulerConstruct(temp_cc)       
   u%RootMotion%Orientation(:,:,1) = MATMUL(temp_R,u%HubMotion%Orientation(:,:,1))
       
   if (present(AllOuts)) then
      AllOuts(PAngInp) = u_theta_pitch
      AllOuts(PAngAct) = thetaP
      AllOuts(PRatAct) = omegaP
      AllOuts(PAccAct) = alphaP
   end if
   
   
   
END SUBROUTINE PitchActuator_SetBC
!-----------------------------------------------------------------------------------------------------------------------------------
END MODULE BeamDyn

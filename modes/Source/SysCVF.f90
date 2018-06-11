MODULE SysSubs
CONTAINS

!=======================================================================
SUBROUTINE FindLine ( Str , MaxLen , StrEnd )


!  This routine finds one line of text with a maximum length of
!  MaxLen from the Str.  It tries to break the line at a blank.


IMPLICIT        NONE

INTEGER         StrEnd
INTEGER         IC
INTEGER         MaxLen

CHARACTER(*)    Str



StrEnd = MaxLen

IF ( LEN_TRIM( Str ) > MaxLen )  THEN

   DO IC=MaxLen,1,-1

      IF ( Str(IC:IC) == ' ' )  THEN
         StrEnd = IC-1
         DO WHILE ( Str(StrEnd:StrEnd) == ' ' )
            StrEnd = StrEnd - 1
         ENDDO
         EXIT
      ENDIF

   ENDDO ! IC

ENDIF


RETURN
END SUBROUTINE FindLine
!=======================================================================
SUBROUTINE FlushOut ( Unit )


!  This subroutine flushes the buffer on the specified Unit.
!  It is especially useful when printing "running..." type
!  messages.  By making this a separate routine, we isolate
!  ourselves from the OS and make porting easier.


IMPLICIT        NONE

INTEGER         Unit



CALL FLUSH ( Unit )


RETURN
END SUBROUTINE FlushOut
!=======================================================================
SUBROUTINE Get_Arg ( Arg_Num , Arg , Error )


!  This routine gets argument #Arg_Num from the command line.


IMPLICIT        NONE

INTEGER         Arg_Num
INTEGER         Status

LOGICAL         Error

CHARACTER(*)    Arg



CALL GETARG ( Arg_Num , Arg )

IF ( LEN_TRIM( Arg ) .GT. 0 )  THEN
   Error = .FALSE.
ELSE
   Error = .TRUE.
ENDIF


RETURN
END SUBROUTINE Get_Arg
!=======================================================================
SUBROUTINE Get_Arg_Num ( Arg_Num )


!  This routine gets the number of command line arguments.


!USE             portlib

IMPLICIT        NONE

INTEGER         Arg_Num



Arg_Num = IARGC()


RETURN
END SUBROUTINE Get_Arg_Num
!=======================================================================
SUBROUTINE OpenCon


!  This routine opens the console for standard output.


USE             SysMod

IMPLICIT        NONE



OPEN ( UC , FILE='CON' , STATUS='UNKNOWN' )

CALL FlushOut ( UC )


RETURN
END SUBROUTINE OpenCon
!=======================================================================
SUBROUTINE UsrAlarm


!  This routine generates an alarm to warn the user that
!  something went wrong.


IMPLICIT        NONE



CALL WrML ( CHAR( 7 ) )


RETURN
END SUBROUTINE UsrAlarm
!=======================================================================
SUBROUTINE WrML ( Str )


!  This routine writes out a string in the middle of a line.


USE             SysMod

IMPLICIT        NONE

CHARACTER(*)    Str



CALL WrNR ( Str )


RETURN
END SUBROUTINE WrML
!=======================================================================
SUBROUTINE WrNR ( Str )


!  This routine writes out a string to the screen without fol-
!  lowing it with a new line.


USE             SysMod

IMPLICIT        NONE

CHARACTER(*)    Str



WRITE (UC,'(1X,A,$)')  Str


RETURN
END SUBROUTINE WrNR
!=======================================================================
SUBROUTINE WrScr ( Str )


!  This routine writes out a string to the screen.


USE                 SysMod

IMPLICIT            NONE

INTEGER             Beg
INTEGER             Indent
INTEGER             LStr
INTEGER             MaxLen

CHARACTER(10)       Frm
CHARACTER( *)       Str



!  Find the amount of indent.  Create format.

MaxLen = 78
Indent = LEN_TRIM( Str ) - LEN_TRIM( ADJUSTL( Str ) )
MaxLen = MaxLen - Indent
Frm    = '(1X,  P,A)'

WRITE (Frm(5:6),'(I2)')  Indent


!  Break long messages into multiple lines.

Beg  = Indent + 1
LStr = LEN_TRIM( Str(Beg:) )

DO WHILE ( Lstr > MaxLen )

    CALL FindLine ( Str(Beg:) , MaxLen , LStr )

    WRITE (UC,Frm)  TRIM( ADJUSTL( Str(Beg:Beg+LStr-1) ) )

    Beg  = Beg + LStr + 1
    LStr = LEN_TRIM( Str(Beg:) )

ENDDO

WRITE (UC,Frm)  TRIM( ADJUSTL( Str(Beg:Beg+LStr-1) ) )


RETURN
END SUBROUTINE WrScr
!=======================================================================

END MODULE SysSubs

MODULE GenSubs
CONTAINS

!=======================================================================
SUBROUTINE Abort ( Message )


   ! This routine outputs fatal Error messages and stops the program.


USE             GenMod
USE             SysSubs

IMPLICIT        NONE

CHARACTER(*)    Message



CALL UsrAlarm
CALL WrScr  ( ' '//Message )
CALL WrScr1 ( ' Aborting '//ProgName//'.' )
CALL WrScr  ( ' ' )
CALL EXIT   ( 1 )


RETURN
END SUBROUTINE Abort
!=======================================================================
FUNCTION CurDate( )


   ! This function returns a character string encoded with the date
   ! in the form dd-mmm-ccyy.


IMPLICIT        NONE

CHARACTER( 8)   CDate
CHARACTER(11)   CurDate


   ! Call the system date function.

CALL DATE_AND_TIME ( CDate )


   ! Parse out the day.

CurDate(1:3) = CDate(7:8)//'-'


   ! Parse out the month.

SELECT CASE ( CDate(5:6) )
   CASE ( '01' )
      CurDate(4:6) = 'Jan'
   CASE ( '02' )
      CurDate(4:6) = 'Feb'
   CASE ( '03' )
      CurDate(4:6) = 'Mar'
   CASE ( '04' )
      CurDate(4:6) = 'Apr'
   CASE ( '05' )
      CurDate(4:6) = 'May'
   CASE ( '06' )
      CurDate(4:6) = 'Jun'
   CASE ( '07' )
      CurDate(4:6) = 'Jul'
   CASE ( '08' )
      CurDate(4:6) = 'Aug'
   CASE ( '09' )
      CurDate(4:6) = 'Sep'
   CASE ( '10' )
      CurDate(4:6) = 'Oct'
   CASE ( '11' )
      CurDate(4:6) = 'Nov'
   CASE ( '12' )
      CurDate(4:6) = 'Dec'
END SELECT


   ! Parse out the year.

CurDate(7:11) = '-'//CDate(1:4)


RETURN
END FUNCTION CurDate
!=======================================================================
FUNCTION CurTime( )


   ! This function returns a character string encoded with the time
   ! in the form "hh:mm:ss".


IMPLICIT        NONE

CHARACTER(11)   CTime
CHARACTER( 8)   CurTime


CALL DATE_AND_TIME ( TIME=CTime )

CurTime = CTime(1:2)//':'//CTime(3:4)//':'//CTime(5:6)


RETURN
END FUNCTION CurTime
!=======================================================================
FUNCTION Flt2LStr ( FltNum )


   ! This function converts a floating point number to a left-aligned
   ! string.  It eliminates trailing zeroes and even the decimal
   ! point if it is not a fraction.


IMPLICIT		     NONE

REAL		        FltNum

INTEGER		     IC

CHARACTER*(15)   Flt2LStr


   ! Return a 0 if that's what we have.

IF ( FltNum == 0.0 )  THEN
	Flt2LStr = '0'
	RETURN
ENDIF


   ! Write the number into the string using G format and left justify it.

WRITE (Flt2LStr,'(1PG15.5)')  FltNum

Flt2LStr = ADJUSTL( Flt2LStr )


   ! Replace trailing zeros and possibly the decimal point with blanks.
   ! Stop trimming once we find the decimal point or a nonzero.

DO IC=LEN_TRIM( Flt2LStr ),1,-1

	IF ( Flt2LStr(IC:IC) == '.' )  THEN
	   Flt2LStr(IC:IC) = ' '
	   RETURN
	ELSEIF ( Flt2LStr(IC:IC) /= '0' )  THEN
      RETURN
	ENDIF

	Flt2LStr(IC:IC) = ' '

ENDDO ! IC


RETURN
END FUNCTION Flt2LStr
!=======================================================================
SUBROUTINE PremEOF ( Fil , Message)


   ! This routine prints out an EOF message and aborts the program.


USE              GenMod
USE              SysSubs

IMPLICIT     NONE

CHARACTER(*)    Fil
CHARACTER(*)    Message



CALL WrScr1 ( ' Premature EOF for file "'//TRIM( Fil )//'.' )
CALL Abort  ( Message )


RETURN
END SUBROUTINE PremEOF
!=======================================================================
SUBROUTINE WrScr1 ( Str )


   ! This routine writes out a string to the screen after a blank line.


USE            SysSubs

IMPLICIT       NONE

CHARACTER(*)   Str



CALL WrScr ( ' ' )
CALL WrScr ( Str )


RETURN
END SUBROUTINE WrScr1
!=======================================================================

END MODULE GenSubs

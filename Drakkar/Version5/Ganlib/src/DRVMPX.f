*DECK DRVMPX
      SUBROUTINE DRVMPX(NENTRY,HENTRY,IENTRY,JENTRY,KENTRY)
*
*-----------------------------------------------------------------------
*
* STANDARD MULTIPLICATION MODULE.
*
* INPUT/OUTPUT PARAMETERS:
*  NENTRY : NUMBER OF LINKED LISTS AND FILES USED BY THE MODULE.
*  HENTRY : CHARACTER*12 NAME OF EACH LINKED LIST OR FILE.
*  IENTRY : =0 CLE-2000 VARIABLE; =1 LINKED LIST; =2 XSM FILE;
*           =3 SEQUENTIAL BINARY FILE; =4 SEQUENTIAL ASCII FILE.
*  JENTRY : =0 THE LINKED LIST OR FILE IS CREATED.
*           =1 THE LINKED LIST OR FILE IS OPEN FOR MODIFICATIONS;
*           =2 THE LINKED LIST OR FILE IS OPEN IN READ-ONLY MODE.
*  KENTRY : =FILE UNIT NUMBER; =LINKED LIST ADDRESS OTHERWISE.
*           DIMENSION HENTRY(NENTRY),IENTRY(NENTRY),JENTRY(NENTRY),
*           KENTRY(NENTRY)
*
*-------------------------------------- AUTHOR: A. HEBERT ; 23/07/94 ---
*
      USE GANLIB
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER NENTRY,IENTRY(NENTRY),JENTRY(NENTRY)
      TYPE(C_PTR) KENTRY(NENTRY)
      CHARACTER HENTRY(NENTRY)*12
*----
*  LOCAL VARIABLES
*----
      TYPE(C_PTR) IPLIST1
      CHARACTER HSMG*131,TEXT4*4,TEXT12*12
      DOUBLE PRECISION DFLOTT
*
* PARAMETER VALIDATION.
      IF(NENTRY.EQ.0) CALL XABORT('DRVMPX: ONE PARAMETER EXPECTED.')
      TEXT12=HENTRY(1)
      IF((JENTRY(1).EQ.2).OR.(IENTRY(1).GT.2)) CALL XABORT('DRVMPX: LIN'
     1 //'KED LIST OR XSM FILE IN CREATION OR MODIFICATION MODE EXPECTE'
     2 //'D AT LHS ('//TEXT12//').')
*
* COPY THE RHS INTO THE LHS.
      IF(JENTRY(1).EQ.0) THEN
         IF(NENTRY.LE.1) CALL XABORT('DRVMPX: TWO PARAMETERS EXPECTED.')
         IF((JENTRY(2).NE.2).OR.(IENTRY(2).GT.2)) CALL XABORT('DRVMPX: '
     1   //'LINKED LIST OR XSM FILE IN READ-ONLY MODE EXPECTED AT RHS.')
         NUNIT=KDROPN('DUMMYSQ',0,2,0)
         IF(NUNIT.LE.0) CALL XABORT('DRVMPX: KDROPN FAILURE.')
         CALL LCMEXP(KENTRY(2),0,NUNIT,1,1)
         REWIND(NUNIT)
         CALL LCMEXP(KENTRY(1),0,NUNIT,1,2)
         IERR=KDRCLS(NUNIT,2)
         IF(IERR.LT.0) THEN
            WRITE(HSMG,'(29HDRVMPX: KDRCLS FAILURE. IERR=,I3)') IERR
            CALL XABORT(HSMG)
         ENDIF
      ENDIF
*
* READ THE REAL NUMBER
      CALL REDGET(ITYP,NITMA,FLOTT,TEXT4,DFLOTT)
      IF(ITYP.NE.2) CALL XABORT('DRVMPX: REAL DATA EXPECTED.')
      CALL REDGET(ITYP,NITMA,FLOTT,TEXT4,DFLOTT)
      IF((ITYP.NE.3).OR.(TEXT4.NE.';')) THEN
         CALL XABORT('DRVMPX: ; EXPECTED.')
      ENDIF
*
* PERFORM THE MULTIPLICATION.
      IPLIST1=KENTRY(1)
      CALL LCMULT(IPLIST1,FLOTT)
      RETURN
      END

*DECK DLEAK
      SUBROUTINE DLEAK(NENTRY,HENTRY,IENTRY,JENTRY,KENTRY)
*
*-----------------------------------------------------------------------
*
*Purpose:
* Create a delta Macrolib with respect to leakage information.
*
*Copyright:
* Copyright (C) 2012 Ecole Polytechnique de Montreal.
*
*Author(s): 
* A. Hebert
*
*Parameters: input
* NENTRY  number of data structures transfered to this module.
* HENTRY  name of the data structures.
* IENTRY  data structure type where:
*         IENTRY=1 for LCM memory object;
*         IENTRY=2 for XSM file;
*         IENTRY=3 for sequential binary file;
*         IENTRY=4 for sequential ASCII file.
* JENTRY  access permission for the data structure where:
*         JENTRY=0 for a data structure in creation mode;
*         JENTRY=1 for a data structure in modifications mode;
*         JENTRY=2 for a data structure in read-only mode.
* KENTRY  data structure pointer.
*
*Comments:
* None
*-----------------------------------------------------------------------
*
      USE GANLIB
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER NENTRY,IENTRY(NENTRY),JENTRY(NENTRY)
      CHARACTER HENTRY(NENTRY)*12
      TYPE(C_PTR) KENTRY(NENTRY)
*----
*  LOCAL VARIABLES
*----
      PARAMETER(NSTATE=40)
      CHARACTER HSIGN*12,TEXT12*12
      DOUBLE PRECISION DFLOTT
      INTEGER ISTATE(NSTATE)
      DOUBLE PRECISION OPTPRR(NSTATE)
      TYPE(C_PTR) IPOPT,IPNEW,IPOLD,JPNEW,JPOLD,KPNEW,KPOLD,LPNEW,MPNEW
      INTEGER, ALLOCATABLE, DIMENSION(:) :: IJJ,NJJ
      REAL, ALLOCATABLE, DIMENSION(:) :: GAR,PER
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: VARV,WEI
*----
*  PARAMETER VALIDATION
*----
      IF(NENTRY.NE.3)CALL XABORT('DLEAK: THREE PARAMETERS EXPECTED.')
      IF((IENTRY(1).NE.1).AND.(IENTRY(1).NE.2))CALL XABORT('@DLEAK'
     1 //': LCM OBJECT EXPECTED AT LHS.')
      IF(JENTRY(1).EQ.0)THEN
        HSIGN='L_MACROLIB'
        CALL LCMPTC(KENTRY(1),'SIGNATURE',12,1,HSIGN)
      ELSE
        CALL XABORT('DLEAK: EMPTY DELTA MACROLIB EXPECTED AT LHS.')
      ENDIF
      IPNEW=KENTRY(1)
      IF((IENTRY(2).NE.1).AND.(IENTRY(2).NE.2))CALL XABORT('DLEAK: LC'
     1 //'M OBJECT EXPECTED AT LHS.')
      IF(JENTRY(2).EQ.0)THEN
        HSIGN='L_OPTIMIZE'
        CALL LCMPTC(KENTRY(2),'SIGNATURE',12,1,HSIGN)
      ELSE
        CALL XABORT('DLEAK: EMPTY OPTIMIZE OBJECT EXPECTED AT LHS.')
      ENDIF
      IPOPT=KENTRY(2)
      IF((IENTRY(3).NE.1).AND.(IENTRY(3).NE.2))CALL XABORT('DLEAK: LC'
     1 //'M OBJECT EXPECTED AT RHS.')
      IF(JENTRY(3).NE.2)CALL XABORT('DLEAK: MACROLIB IN READ-ONLY MOD'
     1 //'E EXPECTED AT RHS.')
      CALL LCMGTC(KENTRY(3),'SIGNATURE',12,1,HSIGN)
      IF(HSIGN.NE.'L_MACROLIB')THEN
        CALL XABORT('DLEAK: SIGNATURE OF '//HENTRY(3)//' IS '//HSIGN//
     1  '. L_MACROLIB EXPECTED.')
      ENDIF
      IPOLD=KENTRY(3)
      CALL LCMGET(IPOLD,'STATE-VECTOR',ISTATE)
      NGRP=ISTATE(1)
      NMIX=ISTATE(2)
      ILEAK=ISTATE(9)
*----
*  READ THE INPUT DATA
*----
      IMPX=1
      ITYPE=0
      IDELTA=0
      NGR1=1
      NGR2=NGRP
      IBM1=1
      IBM2=NMIX
   20 CALL REDGET(INDIC,NITMA,FLOTT,TEXT12,DFLOTT)
      IF(INDIC.EQ.10) GO TO 30
      IF(INDIC.NE.3) CALL XABORT('DLEAK: CHARACTER DATA EXPECTED(1).')
      IF(TEXT12.EQ.'EDIT') THEN
*       READ THE PRINT INDEX.
        CALL REDGET(INDIC,IMPX,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.1) CALL XABORT('DLEAK: INTEGER DATA EXPECTED(1).')
      ELSE IF(TEXT12.EQ.'TYPE') THEN
*       READ THE TYPE OF LEAKAGE.
        CALL REDGET(INDIC,NITMA,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.3) CALL XABORT('DLEAK: CHARACTER DATA EXPECTED(2).')
        IF(TEXT12.EQ.'DIFF') THEN
          ITYPE=1
        ELSE IF(TEXT12.EQ.'NTOT1') THEN
          ITYPE=2
        ELSE
          CALL XABORT('DLEAK: INVALID TYPE OF CROSS SECTION.')
        ENDIF
      ELSE IF(TEXT12.EQ.'DELTA') THEN
*       READ THE TYPE OF DELTA.
        CALL REDGET(INDIC,NITMA,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.3) CALL XABORT('DLEAK: CHARACTER DATA EXPECTED(3).')
        IF(TEXT12.EQ.'VALUE') THEN
          IDELTA=1
        ELSE IF(TEXT12.EQ.'FACTOR') THEN
          IDELTA=2
        ELSE
          CALL XABORT('DLEAK: INVALID DELTA TYPE.')
        ENDIF
      ELSE IF(TEXT12.EQ.'MIXMIN') THEN
*       READ THE MINIMUM MIXTURE INDEX.
        CALL REDGET(INDIC,IBM1,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.1) CALL XABORT('DLEAK: INTEGER DATA EXPECTED(2).')
        IF((IBM1.LE.0).OR.(IBM1.GT.NMIX)) CALL XABORT('DLEAK: INVALID '
     1  //'VALUE OF MIXMIN.')
      ELSE IF(TEXT12.EQ.'MIXMAX') THEN
*       READ THE MAXIMUM MIXTURE INDEX.
        CALL REDGET(INDIC,IBM2,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.1) CALL XABORT('DLEAK: INTEGER DATA EXPECTED(3).')
        IF((IBM2.LT.IBM1).OR.(IBM2.GT.NMIX)) CALL XABORT('DLEAK: INVAL'
     1  //'ID VALUE OF MIXMAX.')
      ELSE IF(TEXT12.EQ.'GRPMIN') THEN
*       READ THE MINIMUM GROUP INDEX.
        CALL REDGET(INDIC,NGR1,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.1) CALL XABORT('DLEAK: INTEGER DATA EXPECTED(4).')
        IF((NGR1.LE.0).OR.(NGR1.GT.NGRP)) CALL XABORT('DLEAK: INVALID '
     1  //'VALUE OF GRPMIN.')
      ELSE IF(TEXT12.EQ.'GRPMAX') THEN
*       READ THE MAXIMUM GROUP INDEX.
        CALL REDGET(INDIC,NGR2,FLOTT,TEXT12,DFLOTT)
        IF(INDIC.NE.1) CALL XABORT('DLEAK: INTEGER DATA EXPECTED(5).')
        IF((NGR2.LT.NGR1).OR.(NGR2.GT.NGRP)) CALL XABORT('DLEAK: INVAL'
     1  //'ID VALUE OF GRPMAX.')
      ELSE IF(TEXT12.EQ.';') THEN
        GO TO 30
      ELSE
        CALL XABORT('DLEAK: '//TEXT12//' IS AN INVALID KEYWORD.')
      ENDIF
      GO TO 20
   30 IF(ITYPE.EQ.0) CALL XABORT('DLEAK: LEAKAGE TYPE NOT SET.')
      IF(IDELTA.EQ.0) CALL XABORT('DLEAK: DELTA TYPE NOT SET.')
      IF(IBM2.LT.IBM1) CALL XABORT('DLEAK: INVALID MIXTURE INDICES.')
      IF(NGR2.LT.NGR1) CALL XABORT('DLEAK: INVALID GROUP INDICES.')
      IF((ITYPE.EQ.1).AND.(ILEAK.EQ.0)) CALL XABORT('DLEAK: NO LEAKAGE'
     1 //' ON INPUT MACROLIB.')
      NPERT=(IBM2-IBM1+1)*(NGR2-NGR1+1)
      IF(IMPX.GT.0) WRITE(6,'(/36H DLEAK: NUMBER OF CROSS-SECTION PERT,
     1 10HURBATIONS=,I5)') NPERT
*----
*  SET THE PERTURBED MACROLIB
*----
      ALLOCATE(VARV(NPERT),WEI(NPERT))
      JPNEW=LCMLID(IPNEW,'STEP',NPERT)
      JPOLD=LCMGID(IPOLD,'GROUP')
      IPERT=0
      ALLOCATE(IJJ(NMIX),NJJ(NMIX),GAR(NMIX),PER(NMIX))
      DO 50 IGRP=NGR1,NGR2
      DO 50 IBMP=IBM1,IBM2
      IPERT=IPERT+1
      KPNEW=LCMDIL(JPNEW,IPERT)
      LPNEW=LCMLID(KPNEW,'GROUP',NGRP)
      DO 50 IGR=1,NGRP
      MPNEW=LCMDIL(LPNEW,IGR)
      KPOLD=LCMGIL(JPOLD,IGR)
      CALL XDRSET(GAR,NMIX,0.0)
      CALL XDISET(NJJ,NMIX,1)
      DO 40 IMIX=1,NMIX
   40 IJJ(IMIX)=IGR
      CALL LCMPUT(MPNEW,'NTOT0',NMIX,2,GAR)
      CALL LCMPUT(MPNEW,'SIGS00',NMIX,2,GAR)
      CALL LCMPUT(MPNEW,'SIGW00',NMIX,2,GAR)
      CALL LCMPUT(MPNEW,'SCAT00',NMIX,2,GAR)
      CALL LCMPUT(MPNEW,'NJJS00',NMIX,1,NJJ)
      CALL LCMPUT(MPNEW,'IJJS00',NMIX,1,IJJ)
      CALL LCMPUT(MPNEW,'IPOS00',NMIX,1,NJJ)
      CALL XDRSET(PER,NMIX,0.0)
      IF((IDELTA.EQ.1).AND.(ITYPE.EQ.1).AND.(ILEAK.EQ.1)) THEN
         IF(IGR.EQ.IGRP) PER(IBMP)=1.0
         CALL LCMPUT(MPNEW,'DIFF',NMIX,2,PER)
         CALL LCMGET(KPOLD,'DIFF',GAR)
         IF(IGR.EQ.IGRP) VARV(IPERT)=GAR(IBMP)
      ELSE IF((IDELTA.EQ.1).AND.(ITYPE.EQ.1).AND.(ILEAK.EQ.2)) THEN
         IF(IGR.EQ.IGRP) PER(IBMP)=1.0
         CALL LCMPUT(MPNEW,'DIFFX',NMIX,2,PER)
         CALL LCMPUT(MPNEW,'DIFFY',NMIX,2,PER)
         CALL LCMPUT(MPNEW,'DIFFZ',NMIX,2,PER)
         CALL LCMGET(KPOLD,'DIFFX',GAR)
         IF(IGR.EQ.IGRP) VARV(IPERT)=GAR(IBMP)
      ELSE IF((IDELTA.EQ.1).AND.(ITYPE.EQ.2)) THEN
         IF(IGR.EQ.IGRP) PER(IBMP)=1.0
         CALL LCMPUT(MPNEW,'NTOT1',NMIX,2,PER)
         CALL LCMLEN(KPOLD,'NTOT1',ILONG,ITYLCM)
         IF(ILONG.NE.0) THEN
           CALL LCMGET(KPOLD,'NTOT1',GAR)
         ELSE
           CALL LCMGET(KPOLD,'NTOT0',GAR)
         ENDIF
         IF(IGR.EQ.IGRP) VARV(IPERT)=GAR(IBMP)
      ELSE IF((IDELTA.EQ.2).AND.(ITYPE.EQ.1).AND.(ILEAK.EQ.1)) THEN
         CALL LCMGET(KPOLD,'DIFF',GAR)
         IF(IGR.EQ.IGRP) PER(IBMP)=GAR(IBMP)
         CALL LCMPUT(MPNEW,'DIFF',NMIX,2,PER)
         IF(IGR.EQ.IGRP) VARV(IPERT)=1.0D0
         IF(IGR.EQ.IGRP) WEI(IPERT)=GAR(IBMP)**2
      ELSE IF((IDELTA.EQ.2).AND.(ITYPE.EQ.1).AND.(ILEAK.EQ.2)) THEN
         CALL LCMGET(KPOLD,'DIFFX',GAR)
         IF(IGR.EQ.IGRP) PER(IBMP)=GAR(IBMP)
         CALL LCMPUT(MPNEW,'DIFFX',NMIX,2,PER)
         CALL LCMPUT(MPNEW,'DIFFY',NMIX,2,PER)
         CALL LCMPUT(MPNEW,'DIFFZ',NMIX,2,PER)
         IF(IGR.EQ.IGRP) VARV(IPERT)=1.0D0
         IF(IGR.EQ.IGRP) WEI(IPERT)=GAR(IBMP)**2
      ELSE IF((IDELTA.EQ.2).AND.(ITYPE.EQ.2)) THEN
         CALL LCMLEN(KPOLD,'NTOT1',ILONG,ITYLCM)
         IF(ILONG.NE.0) THEN
           CALL LCMGET(KPOLD,'NTOT1',GAR)
         ELSE
           CALL LCMGET(KPOLD,'NTOT0',GAR)
         ENDIF
         IF(IGR.EQ.IGRP) PER(IBMP)=GAR(IBMP)
         CALL LCMPUT(MPNEW,'NTOT1',NMIX,2,PER)
         IF(IGR.EQ.IGRP) VARV(IPERT)=1.0D0
         IF(IGR.EQ.IGRP) WEI(IPERT)=GAR(IBMP)**2
      ENDIF
   50 CONTINUE
      DEALLOCATE(PER,GAR,NJJ,IJJ)
*----
*  SET THE PERTURBED MACROLIB STATE-VECTOR
*----
      CALL XDISET(ISTATE,NSTATE,0)
      ISTATE(1)=NGRP
      ISTATE(2)=NMIX
      ISTATE(3)=1
      ISTATE(9)=ILEAK
      ISTATE(11)=NPERT
      CALL LCMPUT(IPNEW,'STATE-VECTOR',NSTATE,1,ISTATE)
      IF(IMPX.GT.1) CALL LCMLIB(IPNEW)
*----
*  PUT OPTIMIZE OBJECT INFORMATION
*----
      CALL LCMPUT(IPOPT,'VAR-VALUE',NPERT,4,VARV)
      IF(IDELTA.EQ.2) CALL LCMPUT(IPOPT,'VAR-WEIGHT',NPERT,4,WEI)
      DEALLOCATE(WEI,VARV)
      CALL XDISET(ISTATE,NSTATE,0)
      ISTATE(1)=NGRP
      ISTATE(2)=NMIX
      ISTATE(3)=ITYPE
      ISTATE(4)=IDELTA
      ISTATE(5)=NGR1
      ISTATE(6)=NGR2
      ISTATE(7)=IBM1
      ISTATE(8)=IBM2
      IF(IMPX.GT.0) WRITE(6,100) (ISTATE(I),I=1,8)
      CALL LCMPUT(IPOPT,'DEL-STATE',NSTATE,1,ISTATE)
      CALL XDISET(ISTATE,NSTATE,0)
      ISTATE(1)=NPERT
      ISTATE(2)=0
      ISTATE(3)=1
      ISTATE(4)=0
      ISTATE(5)=0
      ISTATE(6)=2
      ISTATE(9)=2
      ISTATE(10)=0
      CALL LCMPUT(IPOPT,'STATE-VECTOR',NSTATE,1,ISTATE)
      CALL XDDSET(OPTPRR,NSTATE,0.0D0)
      OPTPRR(1)=1.0
      OPTPRR(2)=0.1
      OPTPRR(3)=1.0E-4
      OPTPRR(4)=1.0E-4
      OPTPRR(5)=1.0E-4
      CALL LCMPUT(IPOPT,'OPT-PARAM-R',NSTATE,4,OPTPRR)
      RETURN
*
  100 FORMAT(/18H DEL-STATE OPTIONS/18H -----------------/
     1 7H NGRP  ,I8,28H   (NUMBER OF ENERGY GROUPS)/
     2 7H NMIX  ,I8,32H   (NUMBER OF MATERIAL MIXTURES)/
     3 7H ITYPE ,I8,29H   (=1/2: USE DIFF/USE NTOT1)/
     4 7H IDELTA,I8,31H   (=1/2: USE VALUE/USE FACTOR)/
     5 7H NGR1  ,I8,24H   (MINIMUM GROUP INDEX)/
     6 7H NGR2  ,I8,24H   (MAXIMUM GROUP INDEX)/
     7 7H IBM1  ,I8,26H   (MINIMUM MIXTURE INDEX)/
     8 7H IBM2  ,I8,26H   (MAXIMUM MIXTURE INDEX))
      END

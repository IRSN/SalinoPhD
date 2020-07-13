*DECK SPH
      SUBROUTINE SPH(NENTRY,HENTRY,IENTRY,JENTRY,KENTRY)
*
*-----------------------------------------------------------------------
*
*Purpose:
* superhomogeneisation (SPH) procedure.
*
*Copyright:
* Copyright (C) 2011 Ecole Polytechnique de Montreal
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
*Author(s): A. Hebert
*
*Parameters: input/output
* NENTRY  number of LCM objects or files used by the operator.
* HENTRY  name of each LCM object or file:
*         HENTRY(1): Edition (L_EDIT), Microlib (L_LIBRARY),
*         Macrolib (L_MACROLIB) or Saphyb (L_SAPHYB) object;
*         HENTRY(I): I>1 read-only type (Edition (L_EDIT) and/or
*         L_MACROLIB and/or L_LIBRARY and/or L_SAPHYB and/or L_TRACK).
* IENTRY  type of each LCM object or file:
*         =1 LCM memory object; =2 XSM file; =3 sequential binary file;
*         =4 sequential ascii file.
* JENTRY  access of each LCM object or file:
*         =0 the LCM object or file is created;
*         =1 the LCM object or file is open for modifications;
*         =2 the LCM object or file is open in read-only mode.
* KENTRY  LCM object address or file unit number.
*
*-----------------------------------------------------------------------
*
      USE GANLIB
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER      NENTRY,IENTRY(NENTRY),JENTRY(NENTRY)
      TYPE(C_PTR)  KENTRY(NENTRY)
      CHARACTER    HENTRY(NENTRY)*12
*----
*  LOCAL VARIABLES
*----
      PARAMETER(NSTATE=40,IOUT=6,MAXISD=400)
      INTEGER ISTATE(NSTATE),DIMSAP(50)
      CHARACTER CNDOOR*12,HSIGN*12,HSMG*131,TEXT12*12,HEDIT*12,HEQUI*4,
     1 HMASL*4,HEQNAM*80
      LOGICAL LARM,LTEMP,LNEW
      REAL REALIR
      DOUBLE PRECISION DFLOT
      TYPE(C_PTR) IPTRK,IPFLX,IPOUT,IPRHS,IPMICR,IPMACR,IPSAP,JPMAC,
     1 KPMAC,IPEDIT,IPSPH,IPCPO
      REAL, ALLOCATABLE, DIMENSION(:) :: SPH2,WORK1,WORK2,SPOLD
*----
*  PARAMETER VALIDATION.
*----
      IPTRK=C_NULL_PTR
      IFTRK=0
      IPFLX=C_NULL_PTR
      IF(NENTRY.EQ.0) CALL XABORT('SPH: MISSING PARAMETERS(1).')
      IMIN=1
      IF((IENTRY(1).LE.2).AND.(JENTRY(1).EQ.0)) THEN
         IMIN=3
         IPOUT=KENTRY(1)
         IF(NENTRY.EQ.1) CALL XABORT('SPH: MISSING PARAMETERS(2).')
         IF((IENTRY(2).LE.2).AND.(JENTRY(2).EQ.2)) THEN
            IPRHS=KENTRY(2)
         ELSE
            CALL XABORT('SPH: LHS LCM OBJECT EXPECTED.')
         ENDIF
      ELSE IF((IENTRY(1).LE.2).AND.(JENTRY(1).EQ.1)) THEN
         IMIN=2
         IPOUT=KENTRY(1)
         IPRHS=IPOUT
      ELSE
         CALL XABORT('SPH: RHS LCM OBJECT EXPECTED.')
      ENDIF
      CALL LCMGTC(KENTRY(IMIN-1),'SIGNATURE',12,1,HSIGN)
      ITYPE=0
      IF(HSIGN.EQ.'L_EDIT') THEN
         ITYPE=1
      ELSE IF(HSIGN.EQ.'L_LIBRARY') THEN
         ITYPE=2
      ELSE IF(HSIGN.EQ.'L_MACROLIB') THEN
         ITYPE=3
      ELSE IF(HSIGN.EQ.'L_SAPHYB') THEN
         ITYPE=4
      ELSE IF(HSIGN.EQ.'L_MULTICOMPO') THEN
         ITYPE=5
      ELSE
         CALL XABORT('SPH: L_EDIT, L_LIBRARY, L_MACROLIB OR L_SAPHYB E'
     1   //'XPECTED AT FIRST RHS PARAMETER.')
      ENDIF
      DO 10 I=IMIN,NENTRY
      IF((IENTRY(I).LE.2).AND.(JENTRY(I).EQ.2)) THEN
         CALL LCMGTC(KENTRY(I),'SIGNATURE',12,1,HSIGN)
         IF(HSIGN.EQ.'L_TRACK') THEN
            IPTRK=KENTRY(I)
         ELSE IF(HSIGN.EQ.'L_FLUX') THEN
            IPFLX=KENTRY(I)
         ELSE
            WRITE(HSMG,'(40HSPH: UNKNOWN TYPE OF PARAMETER(1). NAME=,
     1      A12,11H<--- HSIGN=,A12,5H<---.)') HENTRY(I),HSIGN
            CALL XABORT(HSMG)
         ENDIF
      ELSE IF((IENTRY(I).EQ.3).AND.(JENTRY(I).EQ.2)) THEN
         IFTRK=FILUNIT(KENTRY(I))
      ELSE
         WRITE(HSMG,'(40HSPH: UNKNOWN TYPE OF PARAMETER(2). NAME=,A12,
     1   5H<---.)') HENTRY(I)
         CALL XABORT(HSMG)
      ENDIF
   10 CONTINUE
*----
*  INITIALIZE OR RECOVER EXISTING SPH STATE-VECTOR
*----
      IF(ITYPE.EQ.1) THEN
*        TRY TO RECOVER SPH STATE-VECTOR FROM LAST-EDIT DIRECTORY
         CALL LCMGTC(IPRHS,'LAST-EDIT',12,1,HEDIT)
         IF(IPRINT.GT.0) THEN
            WRITE(6,'(32H SPH: STEP UP L_EDIT DIRECTORY '',A,5H''(1).)')
     1      HEDIT
         ENDIF
         IPEDIT=IPRHS
         IPMICR=LCMGID(IPEDIT,HEDIT)
         IPMACR=LCMGID(IPMICR,'MACROLIB')
         CALL LCMLEN(IPMICR,'SIGNATURE',ILONG,ITYLCM)
         IF(ILONG.EQ.0) IPMICR=C_NULL_PTR
         IPSAP=C_NULL_PTR
      ELSE IF(ITYPE.EQ.2) THEN
         IPEDIT=C_NULL_PTR
         IPMICR=IPRHS
         IPMACR=LCMGID(IPMICR,'MACROLIB')
         IPSAP=C_NULL_PTR
      ELSE IF(ITYPE.EQ.3) THEN
         IPEDIT=C_NULL_PTR
         IPMICR=C_NULL_PTR
         IPMACR=IPRHS
         IPSAP=C_NULL_PTR
      ELSE IF((ITYPE.EQ.4).OR.(ITYPE.EQ.5)) THEN
         IPEDIT=C_NULL_PTR
         IPMICR=C_NULL_PTR
         IPMACR=C_NULL_PTR
         IPSAP=IPRHS
      ENDIF
      ILEN=0
      IF(C_ASSOCIATED(IPMACR)) CALL LCMLEN(IPMACR,'SPH',ILEN,ITYLCM)
      IF(ILEN.NE.0) THEN
         IPSPH=LCMGID(IPMACR,'SPH')
         CALL LCMGET(IPSPH,'STATE-VECTOR',ISTATE)
         NSPH=ISTATE(1)
         KSPH=ISTATE(2)
         MAXIT=ISTATE(3)
         MAXNBI=ISTATE(4)
         ILHS=ISTATE(5)
         IMC=ISTATE(6)
         IGRMIN=ISTATE(7)
         IGRMAX=ISTATE(8)
         IF(NSPH.GE.2) THEN
            CALL LCMGTC(IPSPH,'SPH$TRK',12,1,CNDOOR)
            CALL LCMGET(IPSPH,'SPH-EPSILON',EPSPH)
         ELSE
            CNDOOR=' '
            EPSPH=0.0
         ENDIF
         LARM=(NSPH.EQ.4)
      ELSE
         NSPH=3
         KSPH=1
         MAXIT=200
         MAXNBI=10
         ILHS=0
         IMC=2
         IGRMIN=1
         IGRMAX=HUGE(IGRMAX)
         EPSPH=1.0E-4
         CNDOOR=' '
         LARM=.FALSE.
      ENDIF
*----
*  SET CNDOOR, IMC AND NSPH TO CONSISTENT VALUES
*----
       IF((NSPH.GE.2).AND.(C_ASSOCIATED(IPTRK))) THEN
         CALL LCMGTC(IPTRK,'SIGNATURE',12,1,TEXT12)
         IF(TEXT12.NE.'L_TRACK') THEN
            CALL XABORT('SPH: TRACKING DATA STRUCTURE EXPECTED.')
         ENDIF
         CALL LCMGTC(IPTRK,'TRACK-TYPE',12,1,CNDOOR)
         IMC=2
         IF(CNDOOR.EQ.'SYBIL') THEN
*           SYBIL TRANSPORT-TRANSPORT EQUIVALENCE
            NSPH=3
            IF(LARM) NSPH=4
         ELSE IF(CNDOOR.EQ.'NXT') THEN
*           NXT TRANSPORT-TRANSPORT EQUIVALENCE
            NSPH=3
            IF(IFTRK.EQ.0) CALL XABORT('SPH: MISSING TRACKING FILE')
         ELSE IF(CNDOOR.EQ.'EXCELL') THEN
*           EXCELL TRANSPORT-TRANSPORT EQUIVALENCE
            NSPH=3
            IF(IFTRK.EQ.0) CALL XABORT('SPH: MISSING TRACKING FILE')
         ELSE IF(CNDOOR.EQ.'MCCG') THEN
*           MCCG TRANSPORT-TRANSPORT EQUIVALENCE
            NSPH=4
            IF(IFTRK.EQ.0) CALL XABORT('SPH: MISSING TRACKING FILE')
         ELSE IF(CNDOOR.EQ.'SN') THEN
*           SN TRANSPORT-TRANSPORT EQUIVALENCE
            NSPH=4
         ELSE IF(CNDOOR.EQ.'BIVAC') THEN
*           BIVAC TRANSPORT-DIFFUSION EQUIVALENCE
            NSPH=4
            IMC=1
         ELSE IF(CNDOOR.EQ.'TRIVAC') THEN
*           TRIVAC TRANSPORT-DIFFUSION EQUIVALENCE
            NSPH=4
            IMC=1
         ELSE
            CALL XABORT('SPH: '//CNDOOR//' IS AN INVALID TRACKING MODU'
     >      //'LE')
         ENDIF
      ENDIF
*----
*  SPH DIRECTIVE ANALYSIS
*----
      IPRINT=1
      HEDIT=' '
      HEQUI=' '
      HEQNAM=' '
      ICAL=0
      B2=0.0
   20 CALL REDGET(ITYPLU,INTLIR,REALIR,TEXT12,DFLOT)
      IF(ITYPLU.EQ.10) GO TO 50
      IF(ITYPLU.NE.3) CALL XABORT('SPH: READ ERROR - CHARACTER VA'
     > //'RIABLE EXPECTED')
   30 IF(TEXT12.EQ.';') THEN
         GO TO 50
      ELSE IF(TEXT12.EQ.'EDIT') THEN
         CALL REDGET(ITYPLU,IPRINT,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.NE.1) CALL XABORT('SPH: READ ERROR - INTEGER'
     >   //' VARIABLE EXPECTED')
      ELSE IF(TEXT12.EQ.'IDEM') THEN
         ILHS=0
      ELSE IF(TEXT12.EQ.'MICRO') THEN
         IF((ITYPE.EQ.3).OR.(ITYPE.EQ.4)) THEN
            CALL XABORT('SPH: UNABLE TO PRODUCE A MICROLIB')
         ENDIF
         ILHS=2
      ELSE IF(TEXT12.EQ.'MACRO') THEN
         ILHS=3
      ELSE IF(TEXT12.EQ.'ASYM') THEN
         CALL REDGET(ITYPLU,INTLIR,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.NE.1) CALL XABORT('SPH: READ ERROR - INTEGER V'
     >   //'ARIABLE EXPECTED')
         IF(INTLIR.LE.0) CALL XABORT('SPH: INVALID ASYMPTOTIC MIX'
     >   //'TURE SET')
         KSPH=-INTLIR
      ELSE IF(TEXT12.EQ.'STD') THEN
         KSPH=1
      ELSE IF(TEXT12.EQ.'SELE_ALB') THEN
         KSPH=2
      ELSE IF(TEXT12.EQ.'SELE_FD') THEN
         KSPH=3
      ELSE IF(TEXT12.EQ.'SELE_EDF') THEN
         KSPH=4
      ELSE IF(TEXT12.EQ.'SELE_MWG') THEN
         KSPH=6
      ELSE IF(TEXT12.EQ.'OFF') THEN
*        NO SPH CORRECTION PERFORMED
         NSPH=0
         KSPH=0
         CNDOOR=' '
      ELSE IF(TEXT12.EQ.'SPRD') THEN
*        THE SPH FACTORS ARE READ FROM INPUT
         NSPH=1
         KSPH=0
         CNDOOR=' '
         CALL REDGET(ITYPLU,NMERGO,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.EQ.3) THEN
           NSPH=0
           GO TO 30
         ELSE IF(ITYPLU.NE.1) THEN
           CALL XABORT('SPH: READ ERROR - INTEGER VARIABLE EXPECTED')
         ENDIF
         CALL REDGET(ITYPLU,NGCONO,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.NE.1) CALL XABORT('SPH: READ ERROR - INTEGER'
     >   //' VARIABLE EXPECTED')
         ALLOCATE(SPOLD(NMERGO*NGCONO))
         DO I=1,NMERGO*NGCONO
           CALL REDGET(ITYPLU,INTLIR,SPOLD(I),TEXT12,DFLOT)
           IF(ITYPLU.NE.2) CALL XABORT('SPH: READ ERROR - REAL'
     >     //' VARIABLE EXPECTED')
         ENDDO
      ELSE IF(TEXT12.EQ.'HOMO') THEN
*        HOMOGENEOUS MACRO CALCULATION (NO ITERATIONS ARE PERFORMED)
         NSPH=2
         KSPH=0
         CNDOOR=' '
      ELSE IF(TEXT12.EQ.'ALBS') THEN
         NSPH=2
         KSPH=5
         CNDOOR=' '
      ELSE IF(TEXT12.EQ.'PN') THEN
         IMC=1
      ELSE IF(TEXT12.EQ.'SN') THEN
         IMC=2
      ELSE IF(TEXT12.EQ.'ITER') THEN
*        SPH ITERATION MAIN CONTROL PARAMETERS
   40    CALL REDGET(ITYPLU,INTLIR,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.EQ.1) THEN
            MAXIT=INTLIR
         ELSE IF(ITYPLU.EQ.2) THEN
            EPSPH=REALIR
         ELSE IF(ITYPLU.EQ.3) THEN
            GO TO 30
         ENDIF
         GO TO 40
      ELSE IF(TEXT12.EQ.'MAXNB') THEN
*        SPH ITERATION AUXILIARY CONTROL PARAMETERS
         CALL REDGET(ITYPLU,MAXNBI,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.NE.1) CALL XABORT('SPH: READ ERROR - INTEGER'
     >   //' VARIABLE EXPECTED')
      ELSE IF(TEXT12.EQ.'BELL') THEN
         IF(IMC.NE.2) CALL XABORT('SPH: SN OPTION MANDATORY')
         IMC=3
      ELSE IF(TEXT12.EQ.'ARM') THEN
         LARM=.TRUE.
      ELSE IF(TEXT12.EQ.'STEP') THEN
         CALL REDGET(ITYPLU,INTLIR,REALIR,TEXT12,DFLOT)
         IF(ITYPLU.NE.3) CALL XABORT('SPH: READ ERROR - CHARACTER'
     >   //' VARIABLE EXPECTED')
         IF(TEXT12.EQ.'UP') THEN
            IF((ITYPE.NE.1).AND.(ITYPE.NE.5)) THEN
              CALL XABORT('SPH: L_EDIT OR L_MULTICOMPO EXPECTED AT RHS')
            ENDIF
            CALL REDGET(ITYPLU,INTLIR,REALIR,HEDIT,DFLOT)
            IF(ITYPLU.NE.3) CALL XABORT('SPH: READ ERROR - CHARACTER'
     >      //' VARIABLE EXPECTED')
         ELSE IF(TEXT12.EQ.'AT') THEN
            IF((ITYPE.NE.4).AND.(ITYPE.NE.5)) THEN
               CALL XABORT('SPH: L_SAPHYB OR L_MULTICOMPO EXPECTED AT '
     >         //'RHS')
            ENDIF
            CALL REDGET(ITYPLU,ICAL,REALIR,TEXT12,DFLOT)
            IF(ITYPLU.NE.1) CALL XABORT('SPH: READ ERROR - INTEGER'
     >      //' VARIABLE EXPECTED')
            IF(ICAL.LE.0) CALL XABORT('SPH: INVALID VALUE OF ICAL')
         ELSE
            CALL XABORT('SPH: KEYWORD UP OR AT EXPECTED')
         ENDIF
      ELSE IF(TEXT12.EQ.'EQUI') THEN
         IF(ITYPE.NE.4) CALL XABORT('SPH: L_SAPHYB EXPECTED AT RHS')
         CALL REDGET(ITYPLU,INTLIR,REALIR,HEQUI,DFLOT)
         IF(ITYPLU.NE.3) CALL XABORT('SPH: READ ERROR - CHARACTER'
     >   //' VARIABLE EXPECTED')
      ELSE IF(TEXT12.EQ.'LOCNAM') THEN
         IF(ITYPE.NE.4) CALL XABORT('SPH: L_SAPHYB EXPECTED AT RHS')
         IF(HEQUI.EQ.' ') CALL XABORT('SPH: HEQUI IS NOT DEFINED')
         CALL REDGET(ITYPLU,INTLIR,REALIR,HEQNAM,DFLOT)
         IF(ITYPLU.NE.3) CALL XABORT('SPH: READ ERROR - CHARACTER'
     >   //' VARIABLE EXPECTED')
      ELSE IF(TEXT12.EQ.'LEAK') THEN
        CALL REDGET(ITYPLU,NITMA,B2,TEXT12,DFLOT)
        IF(ITYPLU.NE.2) CALL XABORT('SPH: REAL DATA EXPECTED.')
      ELSE IF(TEXT12.EQ.'GRMIN') THEN
        CALL REDGET(ITYPLU,IGRMIN,REALIR,TEXT12,DFLOT)
        IF(ITYPLU.NE.1) CALL XABORT('SPH: INTEGER DATA EXPECTED.')
      ELSE IF(TEXT12.EQ.'GRMAX') THEN
        CALL REDGET(ITYPLU,IGRMAX,REALIR,TEXT12,DFLOT)
        IF(ITYPLU.NE.1) CALL XABORT('SPH: INTEGER DATA EXPECTED.')
      ELSE
         CALL XABORT('SPH: INVALID KEYWORD='//TEXT12)
      ENDIF
      GO TO 20
*----
*  RESET TO MICROLIB IN DIRECTORY HEDIT
*----
   50 IF(ITYPE.EQ.1) THEN
         IF(HEDIT.EQ.' ') CALL LCMGTC(IPEDIT,'LAST-EDIT',12,1,HEDIT)
         IF(IPRINT.GT.0) THEN
            WRITE(6,'(32H SPH: STEP UP L_EDIT DIRECTORY '',A,5H''(2).)')
     1      HEDIT
         ENDIF
         CALL LCMLEN(IPEDIT,HEDIT,ILONG,ITYLCM)
         IF(ILONG.EQ.0) THEN
            CALL LCMLIB(IPEDIT)
            CALL XABORT('SPH: MISSING DIRECTORY: '//HEDIT)
         ENDIF
         IPMICR=LCMGID(IPEDIT,HEDIT)
         IPMACR=LCMGID(IPMICR,'MACROLIB')
         CALL LCMLEN(IPMICR,'SIGNATURE',ILONG,ITYLCM)
         IF(ILONG.EQ.0) IPMICR=C_NULL_PTR
         IPSAP=C_NULL_PTR
      ENDIF
*----
*  SET POINTERS TO MACROLIB (IPMACR) AND OUTPUT (IPOUT) LCM OBJECTS
*----
      IF(ILHS.EQ.0) THEN
         ILHS2=ITYPE
      ELSE
         ILHS2=ILHS
      ENDIF
      IF((C_ASSOCIATED(IPRHS,IPOUT)).AND.(ITYPE.NE.ILHS2)) THEN
         IF(ILHS2.EQ.1) THEN
            CALL XABORT('SPH: CANNOT EXTRACT AN EDITION OBJECT FROM A '
     >      //'LCM OBJECT IN MODIFICATION MODE.')
         ELSE IF(ILHS2.EQ.2) THEN
            CALL XABORT('SPH: CANNOT EXTRACT A MICROLIB FROM A LCM OBJ'
     >      //'ECT IN MODIFICATION MODE.')
         ELSE IF(ILHS2.EQ.3) THEN
            CALL XABORT('SPH: CANNOT EXTRACT A MACROLIB FROM A LCM OBJ'
     >      //'ECT IN MODIFICATION MODE.')
         ELSE IF(ILHS2.EQ.4) THEN
            CALL XABORT('SPH: CANNOT EXTRACT A SAPHYB FROM A LCM OBJEC'
     >      //'T IN MODIFICATION MODE.')
         ELSE IF(ILHS2.EQ.5) THEN
            CALL XABORT('SPH: CANNOT EXTRACT A MULTICOMPO FROM A LCM O'
     >      //'BJECT IN MODIFICATION MODE.')
         ENDIF
      ELSE IF((.NOT.C_ASSOCIATED(IPRHS,IPOUT)).AND.(ILHS2.EQ.1)) THEN
         IF(.NOT.C_ASSOCIATED(IPEDIT)) CALL XABORT('SPH: NO EDITION OB'
     >   //'JECT ON RHS')
         CALL LCMEQU(IPEDIT,IPOUT)
         IF(IPRINT.GT.0) THEN
            WRITE(6,'(32H SPH: STEP UP L_EDIT DIRECTORY '',A,5H''(3).)')
     >      HEDIT
         ENDIF
         IPEDIT=IPOUT
         IPMICR=LCMGID(IPEDIT,HEDIT)
         IPMACR=LCMGID(IPMICR,'MACROLIB')
         CALL LCMLEN(IPMICR,'SIGNATURE',ILONG,ITYLCM)
         IF(ILONG.EQ.0) IPMICR=C_NULL_PTR
      ELSE IF((.NOT.C_ASSOCIATED(IPRHS,IPOUT)).AND.(ILHS2.EQ.2)) THEN
         IF(ITYPE.EQ.2) THEN
            IF(.NOT.C_ASSOCIATED(IPMICR)) CALL XABORT('SPH: NO MICROLI'
     >      //'B ON RHS')
            CALL LCMEQU(IPMICR,IPOUT)
            IPMACR=LCMGID(IPMICR,'MACROLIB')
         ELSE IF(ITYPE.EQ.5) THEN
            IPMACR=C_NULL_PTR
         ELSE
            CALL XABORT('SPH: RHS CANNOT BE CONVERTED TO A MICROLIB')
         ENDIF
         IPEDIT=C_NULL_PTR
         IPMICR=IPOUT
      ELSE IF((.NOT.C_ASSOCIATED(IPRHS,IPOUT)).AND.(ILHS2.EQ.3)) THEN
         IF((ITYPE.NE.4).AND.(ITYPE.NE.5)) CALL LCMEQU(IPMACR,IPOUT)
         IPEDIT=C_NULL_PTR
         IPMICR=C_NULL_PTR
         IPMACR=IPOUT
      ELSE IF((.NOT.C_ASSOCIATED(IPRHS,IPOUT)).AND.(ILHS2.EQ.4)) THEN
         IF(.NOT.C_ASSOCIATED(IPSAP)) CALL XABORT('SPH: NO SAPHYB ON R'
     >   //'HS')
         CALL LCMEQU(IPSAP,IPOUT)
         IPEDIT=C_NULL_PTR
         IPMICR=C_NULL_PTR
         IPMACR=C_NULL_PTR
      ELSE IF((.NOT.C_ASSOCIATED(IPRHS,IPOUT)).AND.(ILHS2.EQ.5)) THEN
         IF(.NOT.C_ASSOCIATED(IPSAP)) CALL XABORT('SPH: NO MULTICOMPO '
     >   //'ON RHS')
         CALL LCMEQU(IPSAP,IPOUT)
         IPEDIT=C_NULL_PTR
         IPMICR=C_NULL_PTR
         IPMACR=C_NULL_PTR
      ENDIF
*----
*  BUILD A MACROLIB IF NEEDED, ASSIGN AND INITIALIZE SPH-FACTOR ARRAY
*----
      LTEMP=.FALSE.
      IF(ITYPE.EQ.4) THEN
*        A Saphyb is given at RHS
         IF(ILHS2.EQ.3) THEN
            IPMACR=IPOUT
         ELSE IF(ILHS2.EQ.4) THEN
            LTEMP=.TRUE.
            CALL LCMOP(IPMACR,'*TEMPORARY*',0,1,0)
         ELSE
            CALL XABORT('SPH: OPTION NOT IMPLEMENTED(1).')
         ENDIF
         CALL LCMLEN(IPSAP,'DIMSAP',ILENG,ITYLCM)
         IF(ILENG.EQ.0) CALL XABORT('SPH: INVALID SAPHYB.')
         CALL LCMGET(IPSAP,'DIMSAP',DIMSAP)
         NMERGE=DIMSAP(7)   ! number of mixtures
         NGCOND=DIMSAP(20)  ! number of energy groups
         ALLOCATE(SPH2(NMERGE*NGCOND))
         HMASL=' '
         CALL SPHSAP(IPSAP,IPMACR,ICAL,IPRINT,HEQUI,HMASL,NMERGE,NGCOND,
     >   SPH2)
         NALBP=0  ! no albedo correction
      ELSE IF(ITYPE.EQ.5) THEN
*        A Multicompo is given at RHS
         IF(ILHS2.EQ.2) THEN
            IPMICR=IPOUT
         ELSE IF((ILHS2.EQ.3).OR.(ILHS2.EQ.5)) THEN
            LTEMP=.TRUE.
            CALL LCMOP(IPMICR,'*TEMPORARY*',0,1,0)
         ELSE
            CALL XABORT('SPH: OPTION NOT IMPLEMENTED(2).')
         ENDIF
         IF(HEDIT.EQ.' ') HEDIT='default'
         IF(IPRINT.GT.0) THEN
            WRITE(6,'(38H SPH: STEP UP L_MULTICOMPO DIRECTORY '',A,
     1      2H''.)') HEDIT
         ENDIF
         IPCPO=LCMGID(IPSAP,HEDIT)
         CALL LCMLEN(IPCPO,'STATE-VECTOR',ILENG,ITYLCM)
         IF(ILENG.EQ.0) CALL XABORT('SPH: INVALID MULTICOMPO.')
         CALL LCMGET(IPCPO,'STATE-VECTOR',ISTATE)
         NMERGE=ISTATE(1)  ! number of mixtures
         NGCOND=ISTATE(2)  ! number of energy groups
         MAXISO=MAXISD*NMERGE
         CALL SPHCPO(MAXISO,IPMICR,IPCPO,NMERGE,NGCOND,IPRINT,ICAL)
         IPMACR=LCMGID(IPMICR,'MACROLIB')
         IF(ILHS2.EQ.3) CALL LCMEQU(IPMACR,IPOUT)
         ALLOCATE(SPH2(NMERGE*NGCOND))
         CALL XDRSET(SPH2,NMERGE*NGCOND,1.0)
         NALBP=0  ! no albedo correction
      ELSE
*        A Edition/Microlib/Macrolib is given at RHS
         CALL LCMGET(IPMACR,'STATE-VECTOR',ISTATE)
         NGCOND=ISTATE(1)
         NMERGE=ISTATE(2)
         NALBP=ISTATE(8)
         ALLOCATE(SPH2((NMERGE+NALBP)*NGCOND))
         CALL XDRSET(SPH2,(NMERGE+NALBP)*NGCOND,1.0)
      ENDIF
      IF(IGRMIN.GT.NGCOND) CALL XABORT('SPH: IGRMIN OVERFLOW.')
      IGRMAX=MIN(IGRMAX,NGCOND)
*----
*  STORE SPH-RELATED INFORMATION
*----
      IF(NSPH.GT.0) THEN
         IF(.NOT.C_ASSOCIATED(IPMACR)) CALL XABORT('SPH: MISSING MACRO'
     >   //'LIB.')
         IPSPH=LCMDID(IPMACR,'SPH')
         IF(NSPH.GE.2) THEN
            CALL LCMPTC(IPSPH,'SPH$TRK',12,1,CNDOOR)
            CALL LCMPUT(IPSPH,'SPH-EPSILON',1,2,EPSPH)
         ENDIF
         CALL XDISET(ISTATE,NSTATE,0)
         ISTATE(1)=NSPH
         ISTATE(2)=KSPH
         ISTATE(3)=MAXIT
         ISTATE(4)=MAXNBI
         ISTATE(5)=ILHS
         ISTATE(6)=IMC
         ISTATE(7)=IGRMIN
         ISTATE(8)=IGRMAX
         CALL LCMPUT(IPSPH,'STATE-VECTOR',NSTATE,1,ISTATE)
         IF(IPRINT.GT.0) WRITE(IOUT,200) (ISTATE(I),I=1,8),EPSPH,CNDOOR
      ENDIF
*----
*  COMPUTE SPH FACTORS
*----
      IF(NSPH.EQ.1) THEN
        IF(NMERGE+NALBP.NE.NMERGO) CALL XABORT('SPH: INVALID NUMBER OF'
     >  //' REGIONS AFTER SPRD.')
        IF(NGCOND.NE.NGCONO) CALL XABORT('SPH: INVALID NUMBER OF GROUP'
     >  //'S AFTER SPRD.')
        DO I=1,(NMERGE+NALBP)*NGCOND
          SPH2(I)=SPOLD(I)
        ENDDO
        DEALLOCATE(SPOLD)
      ELSE IF(NSPH.GE.2) THEN
        CALL LCMLEN(IPMACR,'SPH',ILONG,ITYLCM)
        IF(ILONG.EQ.0) THEN
           CALL LCMLIB(IPMACR)
           CALL XABORT('SPH: NO SPH DIRECTORY AVAILABLE.')
        ENDIF
        CALL SPHDRV(IPTRK,IFTRK,IPMACR,IPFLX,IPRINT,IMC,NGCOND,NMERGE,
     >  NALBP,IGRMIN,IGRMAX,SPH2)
      ENDIF
*----
*  APPLY SPH CORRECTION
*----
      IF((ILHS2.LE.3).AND.(.NOT.C_ASSOCIATED(IPMICR))) THEN
*       Correction of Macrolib information
        CALL LCMGET(IPMACR,'STATE-VECTOR',ISTATE)
        NIFISS=ISTATE(4)
        NED=ISTATE(5)
        CALL SPHCMA(IPMACR,IPRINT,IMC,NMERGE,NGCOND,NIFISS,NED,NALBP,
     >  SPH2)
      ELSE IF(ILHS2.LE.3) THEN
*       Correction of Microlib information
        CALL LCMGET(IPMICR,'STATE-VECTOR',ISTATE)
        NISOT=ISTATE(2)
        NL=ISTATE(4)
        NED=ISTATE(13)
        NDEL=ISTATE(19)
        NW=MAX(1,ISTATE(25))
        ISTATE(25)=NW
        CALL LCMPUT(IPMICR,'STATE-VECTOR',NSTATE,1,ISTATE)
        CALL SPHCMI(IPMICR,IPRINT,IMC,NMERGE,NISOT,NGCOND,NL,NW,NED,
     >  NDEL,NALBP,SPH2)
      ELSE IF((ILHS2.EQ.4).AND.(HEQUI.NE.' ')) THEN
*----
*  STORE A NEW SET OF SPH FACTORS IN THE SAPHYB
*----
        LNEW=(.NOT.C_ASSOCIATED(IPRHS,IPOUT))
        CALL SPHSTO(IPOUT,ICAL,IPRINT,LNEW,HEQUI,HEQNAM,NMERGE,NGCOND,
     >  SPH2)
      ELSE IF(ILHS2.EQ.5) THEN
*----
*  APPLY A NEW SET OF SPH FACTORS IN THE MULTICOMPO
*----
        IPCPO=LCMGID(IPOUT,HEDIT)
        CALL SPHSCO(IPCPO,ICAL,IPRINT,IMC,NMERGE,NGCOND,SPH2)
      ENDIF
*----
*  RELEASE MEMORY ALLOCATED FOR MACROLIB/MICROLIB AND SPH FACTORS
*----
      IF((C_ASSOCIATED(IPMICR)).AND.LTEMP) THEN
        CALL LCMCL(IPMICR,2)
      ELSE IF(LTEMP) THEN
        CALL LCMCL(IPMACR,2)
      ENDIF
      DEALLOCATE(SPH2)
*----
*  INCLUDE LEAKAGE IN THE MACROLIB (USED ONLY FOR NON-REGRESSION TESTS)
*----
      IF(B2.NE.0.0) THEN
        IF(ILHS2.EQ.1) THEN
           CALL LCMLEN(IPOUT,HEDIT,ILONG,ITYLCM)
           IF(ILONG.EQ.0) THEN
              CALL LCMLIB(IPEDIT)
              CALL XABORT('SPH: MISSING DIRECTORY: '//HEDIT)
           ENDIF
           IPMICR=LCMGID(IPOUT,HEDIT)
           IPMACR=LCMGID(IPMICR,'MACROLIB')
        ELSE IF(ILHS2.EQ.2) THEN
           IPMACR=LCMGID(IPOUT,'MACROLIB')
        ELSE IF(ILHS2.EQ.3) THEN
           IPMACR=IPOUT
        ELSE
           CALL XABORT('SPH: LHS MACROLIB EXPECTED WITH LEAK OPTION.')
        ENDIF
        CALL LCMGET(IPMACR,'STATE-VECTOR',ISTATE)
        NGRP=ISTATE(1)
        NMIX=ISTATE(2)
        JPMAC=LCMGID(IPMACR,'GROUP')
        ALLOCATE(WORK1(NMIX),WORK2(NMIX))
        DO 70 IGR=1,NGRP
          KPMAC=LCMGIL(JPMAC,IGR)
          CALL LCMGET(KPMAC,'NTOT0',WORK1)
          CALL LCMGET(KPMAC,'DIFF',WORK2)
          DO 60 IBM=1,NMIX
   60     WORK1(IBM)=WORK1(IBM)+B2*WORK2(IBM)
          CALL LCMPUT(KPMAC,'NTOT0',NMIX,2,WORK1)
   70   CONTINUE
        DEALLOCATE(WORK2,WORK1)
      ENDIF
      IF(IPRINT.GT.5) CALL LCMLIB(IPOUT)
      RETURN
*
  200 FORMAT(/20H SPH-RELATED OPTIONS/1X,19(1H-)/
     1  7H NSPH  ,I8,47H   (=0: NO SPH CORRECTION; =1: READ SPH FACTORS,
     2  32H; >1: TYPE OF MACRO-CALCULATION)/
     3  7H KSPH  ,I8,47H   (<0: ASYMPTOTIC SPH NORMALIZATION; =1: AVERA,
     4  54HGE FLUX SPH NORMALIZATION; >1: SELENGUT NORMALIZATION)/
     5  7H MAXIT ,I8,37H   (MAXIMUM NUMBER OF SPH ITERATIONS)/
     6  7H MAXNBI,I8,47H   (MAXIMUM NUMBER OF BAD ITERATIONS BEFORE ABO,
     7  6HRTING)/
     8  7H ILHS  ,I8,47H   (=0/1/2/3: PRODUCE A RHS-TYPE/EDITION/MICROL,
     9  19HIB/MACROLIB AT LHS)/
     1  7H IMC   ,I8,47H   (=1/2/3: PN-TYPE/SN-PIJ-MOC-TYPE CORRECTION/,
     2  32HPIJ-TYPE WITH BELL ACCELERATION)/
     3  7H IGRMIN,I8,27H   (FIRST GROUP TO PROCESS)/
     4  7H IGRMAX,I8,26H   (LAST GROUP TO PROCESS)/
     5  8H EPSPH  ,1P,E7.1,26H   (CONVERGENCE CRITERION)/
     6  8H CNDOOR ,A8,37H  (MACRO-CALCULATION TRACKING MODULE))
      END
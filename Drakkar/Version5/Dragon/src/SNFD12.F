*DECK SNFD12
      SUBROUTINE SNFD12(IOMP,NUN,NGRP,NGEFF,IMPX,INCONV,INGIND,LX,LY,
     1 IELEM,NMAT,NPQ,NSCT,MAT,VOL,TOTAL,NCODE,ZCODE,QEXT,LFIXUP,DU,DE,
     2 W,MRM,MRMY,DB,DA,PL,FUNKNO)
*
*-----------------------------------------------------------------------
*
*Purpose:
* perform one inner iteration for solving SN equations in 2D Cartesian
* geometry for the HODD method. Domino-type multithreading. Albedo
* boundary conditions.
*
*Copyright:
* Copyright (C) 2020 Ecole Polytechnique de Montreal
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version
*
*Author(s): A. Hebert
*
*Parameters: input
* IOMP    number of cells per axis in a Domino macrocell.
* NUN     total number of unknowns in vector FUNKNO.
* NGRP    number of energy groups.
* NGEFF   dimension of arrays INCONV and INGIND.
* IMPX    print flag (equal to zero for no print).
* INCONV  energy group convergence flag (set to .false. if converged).
* INGIND  energy group index assign to 1:NGEFF arrays.
* LX      number of meshes along X axis.
* LY      number of meshes along Y axis.
* IELEM   measure of order of the spatial approximation polynomial:
*         =1: constant - classical diamond scheme - default for HODD;
*         =2: linear;
*         =3: parabolic.
* NMAT    number of material mixtures.
* NPQ     number of SN directions in four octants (including zero-weight
*         directions).
* NSCT    maximum number of spherical harmonics moments of the flux.
* MAT     material mixture index in each region.
* VOL     volumes of each region.
* TOTAL   macroscopic total cross sections.
* NCODE   boundary condition indices.
* ZCODE   albedos.
* QEXT    Legendre components of the fixed source.
* LFIXUP  flag to enable negative flux fixup.
* DU      first direction cosines ($\mu$).
* DE      second direction cosines ($\eta$).
* W       weights.
* MRM     quadrature index.
* MRMY    quadrature index.
* DB      diamond-scheme parameter.
* DA      diamond-scheme parameter.
* PL      discrete values of the spherical harmonics corresponding
*         to the 2D SN quadrature.
* FUNKNO  unknown vector.
*
*Parameters: output
* FUNKNO  unknown vector.
*
*-----------------------------------------------------------------------
*
#if defined(_OPENMP)
      USE omp_lib
#endif
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER IOMP,NUN,NGRP,NGEFF,IMPX,INGIND(NGEFF),LX,LY,IELEM,NMAT,
     1 NPQ,NSCT,MAT(LX,LY),NCODE(4),MRM(NPQ),MRMY(NPQ)
      LOGICAL INCONV(NGEFF)
      REAL VOL(LX,LY),TOTAL(0:NMAT,NGRP),ZCODE(4),QEXT(NUN,NGRP),
     1 DU(NPQ),DE(NPQ),W(NPQ),DB(LX,NPQ),DA(LX,LY,NPQ),PL(NSCT,NPQ),
     2 FUNKNO(NUN,NGRP)
      LOGICAL LFIXUP
*----
*  LOCAL VARIABLES
*----
      INTEGER NPQD(4),IIND(4)
      DOUBLE PRECISION Q(IELEM**2),Q2(IELEM**2,(IELEM**2)+1),VT,CONST0,
     1 CONST1,CONST2
      PARAMETER(IUNOUT=6,RLOG=1.0E-8,PI=3.141592654)
*----
*  ALLOCATABLE ARRAYS
*----
      INTEGER, ALLOCATABLE, DIMENSION(:,:) :: INDANG
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: FLUX
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:,:,:) :: XNI,XNJ
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:,:,:,:) :: FLUX_G
*----
*  SCRATCH STORAGE ALLOCATION
*----
      ALLOCATE(INDANG(NPQ,4))
      ALLOCATE(XNI(IELEM,LY,NPQ,NGEFF),XNJ(IELEM,LX,NPQ,NGEFF),
     1 FLUX(IELEM**2,NSCT),FLUX_G(IELEM**2,NSCT,LX,LY,NGEFF))
*----
*  DEFINITION OF CONSTANTS.
*----
      NMX=1+(LX-1)/IOMP
      NMY=1+(LY-1)/IOMP
      L4=IELEM*IELEM*LX*LY*NSCT
      CONST0=2.0D0*DSQRT(3.0D0)
      CONST1=2.0D0*DSQRT(5.0D0)
      CONST2=2.0D0*DSQRT(15.0D0)
*----
*  PARAMETER VALIDATION.
*----
      IF(IELEM.GT.3) CALL XABORT('SNFD12: INVALID IELEM (DIAM) VALUE. '
     1 //'CHECK INPUT DATA FILE.')
*----
*  SET OCTANT SWAPPING ORDER.
*----
      NPQD(:4)=0
      INDANG(:NPQ,:4)=0
      DO M=1,NPQ
        VU=DU(M)
        VE=DE(M)
        IF((VU.GE.0.0).AND.(VE.GE.0.0)) THEN
          IND=1
          JND=4
        ELSE IF((VU.LE.0.0).AND.(VE.GE.0.0)) THEN
          IND=2
          JND=3
        ELSE IF((VU.LE.0.0).AND.(VE.LE.0.0)) THEN
          IND=3
          JND=1
        ELSE
          IND=4
          JND=2
        ENDIF
        IIND(JND)=IND
        NPQD(IND)=NPQD(IND)+1
        INDANG(NPQD(IND),IND)=M
      ENDDO
*----
*  MAIN LOOP OVER OCTANTS.
*----
      FLUX_G(:IELEM**2,:NSCT,:LX,:LY,:NGEFF)=0.0D0
      DO 240 JND=1,4
      IND=IIND(JND)
*----
*  PRELIMINARY LOOPS FOR SETTING BOUNDARY CONDITIONS.
*----
*$OMP  PARALLEL DO
*$OMP1 PRIVATE(M,IG,WEIGHT,M1,E1,IOF,JOF,ITID,IEL,I,J)
*$OMP2 SHARED(FUNKNO) COLLAPSE(2)
      DO 70 IGEFF=1,NGEFF
      DO 60 IPQD=1,NPQD(IND)
      IF(.NOT.INCONV(IGEFF)) GO TO 60
      M=INDANG(IPQD,IND)
      IG=INGIND(IGEFF)
      WEIGHT=W(M)
      IF((NCODE(1).NE.4).AND.(WEIGHT.EQ.0.0)) THEN
         M1=MRM(M)
         DO 15 IEL=1,IELEM
         DO 10 J=1,LY
         IOF=(M-1)*IELEM*LY+(J-1)*IELEM+IEL
         JOF=(M1-1)*IELEM*LY+(J-1)*IELEM+IEL
         FUNKNO(L4+IOF,IG)=FUNKNO(L4+JOF,IG)
   10    CONTINUE
   15    CONTINUE
      ELSE IF((NCODE(1).NE.4).AND.(DU(M).GT.0.0)) THEN
         M1=MRM(M)
         DO 30 IEL=1,IELEM
         DO 20 J=1,LY
         IOF=(M-1)*IELEM*LY+(J-1)*IELEM+IEL
         JOF=(M1-1)*IELEM*LY+(J-1)*IELEM+IEL
         E1=FUNKNO(L4+IOF,IG)
         FUNKNO(L4+IOF,IG)=FUNKNO(L4+JOF,IG)
         FUNKNO(L4+JOF,IG)=E1
   20    CONTINUE
   30    CONTINUE
      ENDIF
      IF((NCODE(3).NE.4).AND.(DE(M).GT.0)) THEN
         M1=MRMY(M)
         DO 50 IEL=1,IELEM
         DO 40 I=1,LX
         IOF=(M-1)*IELEM*LX+(I-1)*IELEM+IEL
         JOF=(M1-1)*IELEM*LX+(I-1)*IELEM+IEL
         E1=FUNKNO(L4+IELEM*LY*NPQ+IOF,IG)
         FUNKNO(L4+IELEM*LY*NPQ+IOF,IG)=FUNKNO(L4+IELEM*LY*NPQ+JOF,IG)
         FUNKNO(L4+IELEM*LY*NPQ+JOF,IG)=E1
   40    CONTINUE
   50    CONTINUE
      ENDIF
   60 CONTINUE
   70 CONTINUE
*$OMP END PARALLEL DO
*----
*  DOMINO DIAGONAL LOOP
*----
      CALL XDDSET(XNI,IELEM*LY*NPQ*NGEFF,0.0D0)
      CALL XDDSET(XNJ,IELEM*LX*NPQ*NGEFF,0.0D0)
      DO 230 IDI=1,NMX+NMY-1
*----
*  MAIN SWAPPING LOOPS FOR SN FLUX CALCULATION
*----
*$OMP  PARALLEL DO
*$OMP1 PRIVATE(ITID,FLUX,M,IG,IMX,IMY,Q,Q2,IOF,IER,JJ,IEL,JEL,I,J,K,VT)
*$OMP2 SHARED(FUNKNO,XNI,XNJ) REDUCTION(+:FLUX_G)
*$OMP3 COLLAPSE(3)
      DO 220 IGEFF=1,NGEFF
      DO 210 IPQD=1,NPQD(IND)
      DO 200 II=MAX(1,IDI-NMY+1),MIN(NMX,IDI)
#if defined(_OPENMP)
        ITID=omp_get_thread_num()
#else
        ITID=0
#endif
      JJ=IDI-II+1
      IF(IMPX.GT.5) WRITE(IUNOUT,400) ITID,IGEFF,IPQD,II,JJ
      IF(.NOT.INCONV(IGEFF)) GO TO 200
      IG=INGIND(IGEFF)
      M=INDANG(IPQD,IND)
      IF(W(M).EQ.0.0) GO TO 200
      IF(II.EQ.1) THEN
        DO 90 IMY=1,MIN(IOMP,LY-(JJ-1)*IOMP)
        J=(JJ-1)*IOMP+IMY
        IF((IND.EQ.3).OR.(IND.EQ.4)) J=LY+1-J
        DO 80 IEL=1,IELEM
        IOF=(M-1)*IELEM*LY+(J-1)*IELEM+IEL
        IF((IND.EQ.1).OR.(IND.EQ.4)) THEN
          XNI(IEL,J,IPQD,IGEFF)=FUNKNO(L4+IOF,IG)*ZCODE(1)
        ELSE
          XNI(IEL,J,IPQD,IGEFF)=FUNKNO(L4+IOF,IG)*ZCODE(2)
        ENDIF
   80   CONTINUE
   90   CONTINUE
      ENDIF
      IF(JJ.EQ.1) THEN
        DO 110 IMX=1,MIN(IOMP,LX-(II-1)*IOMP)
        I=(II-1)*IOMP+IMX
        IF((IND.EQ.2).OR.(IND.EQ.3)) I=LX+1-I
        DO 100 IEL=1,IELEM
        IOF=(M-1)*IELEM*LX+(I-1)*IELEM+IEL
        IF((IND.EQ.1).OR.(IND.EQ.2)) THEN
          XNJ(IEL,I,IPQD,IGEFF)=FUNKNO(L4+IELEM*LY*NPQ+IOF,IG)*ZCODE(3)
        ELSE
          XNJ(IEL,I,IPQD,IGEFF)=FUNKNO(L4+IELEM*LY*NPQ+IOF,IG)*ZCODE(4)
        ENDIF
  100   CONTINUE
  110   CONTINUE
      ENDIF
*---
      DO 190 IMX=1,MIN(IOMP,LX-(II-1)*IOMP)
      I=(II-1)*IOMP+IMX
      IF((IND.EQ.2).OR.(IND.EQ.3)) I=LX+1-I
      DO 180 IMY=1,MIN(IOMP,LY-(JJ-1)*IOMP)
      J=(JJ-1)*IOMP+IMY
      IF((IND.EQ.3).OR.(IND.EQ.4)) J=LY+1-J
      FLUX(:IELEM**2,:NSCT)=0.0D0
      IF(MAT(I,J).EQ.0) GO TO 200
      DO 125 IEL=1,IELEM**2
      Q(IEL)=0.0D0
      DO 120 K=1,NSCT
      IOF=((J-1)*LX*NSCT+(I-1)*NSCT+(K-1))*IELEM*IELEM+IEL
      Q(IEL)=Q(IEL)+QEXT(IOF,IG)*PL(K,M)/(4.0D0*PI)
  120 CONTINUE
  125 CONTINUE
      VT=VOL(I,J)*TOTAL(MAT(I,J),IG)
      CALL XDDSET(Q2,(IELEM**2)*((IELEM**2)+1),0.0D0)
      IF(IELEM.EQ.1) THEN
        Q2(1,1)=2.0D0*ABS(DA(I,J,M))+2.0D0*ABS(DB(I,M))+VT
        Q2(1,2)=2.0D0*ABS(DA(I,J,M))*XNI(1,J,IPQD,IGEFF)+2.0D0*
     1          ABS(DB(I,M))*XNJ(1,I,IPQD,IGEFF)+VOL(I,J)*Q(1)
      ELSE IF(IELEM.EQ.2) THEN
        Q2(1,1)=VT
        Q2(2,1)=CONST0*DA(I,J,M)
        Q2(2,2)=-VT-6.0D0*ABS(DA(I,J,M))
        Q2(3,1)=CONST0*DB(I,M)
        Q2(3,3)=-VT-6.0D0*ABS(DB(I,M))
        Q2(4,2)=-CONST0*DB(I,M)
        Q2(4,3)=-CONST0*DA(I,J,M)
        Q2(4,4)=VT+6.0D0*ABS(DA(I,J,M))+6.0D0*ABS(DB(I,M))
*       ------
        Q2(1,5)=VOL(I,J)*Q(1)
        Q2(2,5)=-VOL(I,J)*Q(2)+CONST0*DA(I,J,M)*XNI(1,J,IPQD,IGEFF)
        Q2(3,5)=-VOL(I,J)*Q(3)+CONST0*DB(I,M)*XNJ(1,I,IPQD,IGEFF)
        Q2(4,5)=VOL(I,J)*Q(4)-CONST0*DA(I,J,M)*XNI(2,J,IPQD,IGEFF)-
     1          CONST0*DB(I,M)*XNJ(2,I,IPQD,IGEFF)
      ELSE IF(IELEM.EQ.3) THEN
        Q2(1,1)=VT+2.0D0*ABS(DA(I,J,M))+2.0D0*ABS(DB(I,M))
        Q2(2,2)=-VT-2.0D0*ABS(DB(I,M))
        Q2(3,1)=CONST1*ABS(DA(I,J,M))
        Q2(3,2)=-CONST2*DA(I,J,M)
        Q2(3,3)=VT+1.0D1*ABS(DA(I,J,M))+2.0D0*ABS(DB(I,M))
        Q2(4,4)=-VT-2.0D0*ABS(DA(I,J,M))
        Q2(5,5)=VT
        Q2(6,4)=-CONST1*ABS(DA(I,J,M))
        Q2(6,5)=CONST2*DA(I,J,M)
        Q2(6,6)=-VT-1.0D1*ABS(DA(I,J,M))
        Q2(7,1)=CONST1*ABS(DB(I,M))
        Q2(7,4)=-CONST2*DB(I,M)
        Q2(7,7)=VT+2.0D0*ABS(DA(I,J,M))+1.0D1*ABS(DB(I,M))
        Q2(8,2)=-CONST1*ABS(DB(I,M))
        Q2(8,5)=CONST2*DB(I,M)
        Q2(8,8)=-VT-1.0D1*ABS(DB(I,M))
        Q2(9,3)=CONST1*ABS(DB(I,M))
        Q2(9,6)=-CONST2*DB(I,M)
        Q2(9,7)=CONST1*ABS(DA(I,J,M))
        Q2(9,8)=-CONST2*DA(I,J,M)
        Q2(9,9)=VT+1.0D1*ABS(DA(I,J,M))+1.0D1*ABS(DB(I,M))
*       ------
        Q2(1,10)=VOL(I,J)*Q(1)+2.0D0*ABS(DA(I,J,M))*XNI(1,J,IPQD,IGEFF)
     1           +2.0D0*ABS(DB(I,M))*XNJ(1,I,IPQD,IGEFF)
        Q2(2,10)=-VOL(I,J)*Q(2)-2.0D0*ABS(DB(I,M))*XNJ(2,I,IPQD,IGEFF)
        Q2(3,10)=VOL(I,J)*Q(3)+CONST1*ABS(DA(I,J,M))*XNI(1,J,IPQD,IGEFF)
     1           +2.0D0*ABS(DB(I,M))*XNJ(3,I,IPQD,IGEFF)
        Q2(4,10)=-VOL(I,J)*Q(4)-2.0D0*ABS(DA(I,J,M))*XNI(2,J,IPQD,IGEFF)
        Q2(5,10)=VOL(I,J)*Q(5)
        Q2(6,10)=-VOL(I,J)*Q(6)-CONST1*ABS(DA(I,J,M))*
     1           XNI(2,J,IPQD,IGEFF)
        Q2(7,10)=VOL(I,J)*Q(7)+2.0D0*ABS(DA(I,J,M))*XNI(3,J,IPQD,IGEFF)
     1           +CONST1*ABS(DB(I,M))*XNJ(1,I,IPQD,IGEFF)
        Q2(8,10)=-VOL(I,J)*Q(8)-CONST1*ABS(DB(I,M))*XNJ(2,I,IPQD,IGEFF)
        Q2(9,10)=VOL(I,J)*Q(9)+CONST1*ABS(DA(I,J,M))*XNI(3,J,IPQD,IGEFF)
     1           +CONST1*ABS(DB(I,M))*XNJ(3,I,IPQD,IGEFF)
      ENDIF
      DO 135 IEL=1,IELEM**2
      DO 130 JEL=IEL+1,IELEM**2
      Q2(IEL,JEL)=Q2(JEL,IEL)
  130 CONTINUE
  135 CONTINUE
      CALL ALSBD(IELEM**2,1,Q2,IER,IELEM**2)
      IF(IER.NE.0) CALL XABORT('SNFD12: SINGULAR MATRIX.')
      IF(IELEM.EQ.1) THEN
        IF(LFIXUP.AND.(Q2(1,2).LE.RLOG)) Q2(1,2)=0.0
        XNI(1,J,IPQD,IGEFF)=2.0D0*Q2(1,2)-XNI(1,J,IPQD,IGEFF)
        XNJ(1,I,IPQD,IGEFF)=2.0D0*Q2(1,2)-XNJ(1,I,IPQD,IGEFF)
        IF(LFIXUP.AND.(XNI(1,J,IPQD,IGEFF).LE.RLOG))
     1  XNI(1,J,IPQD,IGEFF)=0.0
        IF(LFIXUP.AND.(XNJ(1,I,IPQD,IGEFF).LE.RLOG))
     1  XNJ(1,I,IPQD,IGEFF)=0.0
      ELSE IF(IELEM.EQ.2) THEN
        XNI(1,J,IPQD,IGEFF)=XNI(1,J,IPQD,IGEFF)+SIGN(1.0,DU(M))*CONST0*
     1  Q2(2,5)
        XNI(2,J,IPQD,IGEFF)=XNI(2,J,IPQD,IGEFF)+SIGN(1.0,DU(M))*CONST0*
     1  Q2(4,5)
        XNJ(1,I,IPQD,IGEFF)=XNJ(1,I,IPQD,IGEFF)+SIGN(1.0,DE(M))*CONST0*
     1  Q2(3,5)
        XNJ(2,I,IPQD,IGEFF)=XNJ(2,I,IPQD,IGEFF)+SIGN(1.0,DE(M))*CONST0*
     1  Q2(4,5)
      ELSE IF(IELEM.EQ.3) THEN
        XNI(1,J,IPQD,IGEFF)=2.0D0*Q2(1,10)+CONST1*Q2(3,10)-
     1  XNI(1,J,IPQD,IGEFF)
        XNI(2,J,IPQD,IGEFF)=2.0D0*Q2(4,10)+CONST1*Q2(6,10)-
     1  XNI(2,J,IPQD,IGEFF)
        XNI(3,J,IPQD,IGEFF)=2.0D0*Q2(7,10)+CONST1*Q2(9,10)-
     1  XNI(3,J,IPQD,IGEFF)
        XNJ(1,I,IPQD,IGEFF)=2.0D0*Q2(1,10)+CONST1*Q2(7,10)-
     1  XNJ(1,I,IPQD,IGEFF)
        XNJ(2,I,IPQD,IGEFF)=2.0D0*Q2(2,10)+CONST1*Q2(8,10)-
     1  XNJ(2,I,IPQD,IGEFF)
        XNJ(3,I,IPQD,IGEFF)=2.0D0*Q2(3,10)+CONST1*Q2(9,10)-
     1  XNJ(3,I,IPQD,IGEFF)
      ENDIF
      DO 150 K=1,NSCT
      DO 140 IEL=1,IELEM**2
      FLUX(IEL,K)=FLUX(IEL,K)+2.0D0*W(M)*Q2(IEL,IELEM**2+1)*PL(K,M)
  140 CONTINUE
  150 CONTINUE
      IF((II-1)*IOMP+IMX.EQ.LX) THEN
        DO 160 IEL=1,IELEM
        IOF=(M-1)*IELEM*LY+(J-1)*IELEM+IEL
        FUNKNO(L4+IOF,IG)=REAL(XNI(IEL,J,IPQD,IGEFF))
  160   CONTINUE
      ENDIF
      IF((JJ-1)*IOMP+IMY.EQ.LY) THEN
        DO 170 IEL=1,IELEM
        IOF=(M-1)*IELEM*LX+(I-1)*IELEM+IEL
        FUNKNO(L4+IELEM*LY*NPQ+IOF,IG)=REAL(XNJ(IEL,I,IPQD,IGEFF))
  170   CONTINUE
      ENDIF
      FLUX_G(:,:,I,J,IGEFF)=FLUX_G(:,:,I,J,IGEFF)+FLUX(:,:)
  180 CONTINUE
  190 CONTINUE
  200 CONTINUE
  210 CONTINUE
  220 CONTINUE
*$OMP END PARALLEL DO
  230 CONTINUE
  240 CONTINUE
      DO 250 IGEFF=1,NGEFF
        IF(.NOT.INCONV(IGEFF)) GO TO 250
        IG=INGIND(IGEFF)
        FUNKNO(:L4,IG)=
     1  RESHAPE(REAL(FLUX_G(:IELEM**2,:NSCT,:LX,:LY,IGEFF)), (/ L4 /) )
  250 CONTINUE
*----
*  SCRATCH STORAGE DEALLOCATION
*----
      DEALLOCATE(FLUX_G,FLUX,XNJ,XNI)
      DEALLOCATE(INDANG)
      RETURN
*
  400 FORMAT(16H SNFD12: thread=,I8,12H --->(group=,I4,7H angle=,I4,
     1 11H macrocell=,2I5,1H))
      END

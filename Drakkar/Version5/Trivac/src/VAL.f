*DECK VAL
      SUBROUTINE VAL(NENTRY,HENTRY,IENTRY,JENTRY,KENTRY)
*
*-----------------------------------------------------------------------
*
*Purpose:
* interpolate the flux distribution.
*
*Copyright:
* Copyright (C) 2002 Ecole Polytechnique de Montreal
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version
*
*Author(s): R. Chambon
*
*Parameters: input/output
* NENTRY  number of LCM objects or files used by the operator.
* HENTRY  name of each LCM object or file:
*         HENTRY(1): create type(L_FVIEW);
*         HENTRY(2): read-only type(L_TRACK);
*         HENTRY(3): read-only type(L_FLUX).
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
      IMPLICIT NONE
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER      NENTRY,IENTRY(NENTRY),JENTRY(NENTRY)
      TYPE(C_PTR)  KENTRY(NENTRY)
      CHARACTER    HENTRY(NENTRY)*12
*----
*  LOCAL VARIABLES
*----
      INTEGER NSTATE
      PARAMETER (NSTATE=40)
      CHARACTER TEXT12*12,HSIGN*12,CMODUL*12
      INTEGER INDIC,NITMA
      DOUBLE PRECISION DFLOT
      REAL FLOT
      REAL DX,DY,DZ
      LOGICAL L3D
      INTEGER IGP(NSTATE),IFL(NSTATE),IFV(NSTATE),NXD,NYD,NZD,IELEM,NUN,
     1  IMPX,DIM,NG,NLF,NXI,NYI,NZI,NREG,ICHX,IDIM,ITYPE,L4,MAXKN,MKN,
     2  LC,ITYLCM,IREG
      INTEGER I,IG,J,K
      REAL E(25)
      TYPE(C_PTR) IPFVW,IPTRK,IPFLU,JPFLU,JPFVW
      INTEGER, DIMENSION(:), ALLOCATABLE :: MAT,KFLX,KN
      REAL, DIMENSION(:), ALLOCATABLE :: XX,YY,ZZ,MXD,MYD,MZD,MXI,MYI,
     1 MZI,FLXD,XXX,YYY,ZZZ
      REAL, DIMENSION(:,:), ALLOCATABLE :: FXYZ
*----
*  PARAMETER VALIDATION
*----
      IF(NENTRY.NE.3) CALL XABORT('VAL: 3 PARAMETERS EXPECTED.')
      IF((IENTRY(1).NE.1).AND.(IENTRY(1).NE.2)) CALL XABORT('FLD: LCM '
     1 //'OBJECT EXPECTED AT LHS.')
      IF(JENTRY(1).NE.0) CALL XABORT('VAL: ENTRY IN CREATE MODE '
     1 //'EXPECTED.')
      IPFVW=KENTRY(1)
      DO I=2,3
        IF(JENTRY(I).NE.2) CALL XABORT('VAL: LCM OBJECT IN READ-ONLY '
     1 //'MODE EXPECTED AT RHS.')
        CALL LCMGTC(KENTRY(I),'SIGNATURE',12,1,HSIGN)
        IF(HSIGN.EQ.'L_FLUX') THEN
           IPFLU=KENTRY(I)
        ELSEIF(HSIGN.EQ.'L_TRACK') THEN
           IPTRK=KENTRY(I)
           CALL LCMGTC(IPTRK,'TRACK-TYPE',12,1,CMODUL)
        ELSE
           TEXT12=HENTRY(I)
           CALL XABORT('VAL: SIGNATURE OF '//TEXT12//' IS '//HSIGN//
     1     '. L_FLUX or L_TRACK EXPECTED.')
        ENDIF
      ENDDO
      HSIGN='L_FVIEW'
      CALL LCMPTC(KENTRY(1),'SIGNATURE',12,1,HSIGN)
      L3D=.TRUE.
*----
*  RECOVER GENERAL TRACKING INFORMATION
*----
      CALL LCMGET(IPTRK,'STATE-VECTOR',IGP)
      NREG=IGP(1)
      NUN=IGP(2)
      ITYPE=IGP(6)
      NLF=0
      ICHX=0
      IDIM=1
      IF((ITYPE.EQ.5).OR.(ITYPE.EQ.6).OR.(ITYPE.EQ.8)) IDIM=2
      IF((ITYPE.EQ.7).OR.(ITYPE.EQ.9)) IDIM=3
      IF(CMODUL.EQ.'BIVAC') THEN
         L3D=.FALSE.
         IELEM=IGP(8)
         NLF=IGP(14)
         NXD=IGP(12)
         NYD=IGP(13)
         NZD=1
         CALL XABORT('VAL: BIVAC is currently not supported.')
      ELSE IF(CMODUL.EQ.'TRIVAC') THEN
         L3D=.TRUE.
         IELEM=IGP(9)
         L4=IGP(11)
         ICHX=IGP(12)
         NLF=IGP(30)
         NXD=IGP(14)
         NYD=IGP(15)
         NZD=IGP(16)
         IF(NZD.EQ.0) L3D=.FALSE.
         NZD=MAX(1,NZD)
      ENDIF
      ALLOCATE(MAT(NREG),KFLX(NREG))
      CALL LCMGET(IPTRK,'MATCOD',MAT)
      CALL LCMGET(IPTRK,'KEYFLX',KFLX)
      ALLOCATE(MXD(NXD+1),MYD(NYD+1),MZD(NZD+1))
      ALLOCATE(XX(NREG),YY(NREG),ZZ(NREG))
      CALL LCMGET(IPTRK,'XX',XX)
      CALL LCMGET(IPTRK,'YY',YY)
      IF(L3D) CALL LCMGET(IPTRK,'ZZ',ZZ)
*
      CALL LCMGET(IPFLU,'STATE-VECTOR',IFL)
      NG=IFL(1)
*----
*  READ INPUTS
*----
      IMPX=0
      DX=1.
      DY=1.
      DZ=1.
   10 CALL REDGET(INDIC,NITMA,FLOT,TEXT12,DFLOT)
      IF(INDIC.NE.3) CALL XABORT('VAL: character data expected.')
      IF(TEXT12.EQ.'EDIT') THEN
        CALL REDGET(INDIC,IMPX,FLOT,TEXT12,DFLOT)
        IF(INDIC.NE.1) CALL XABORT('VAL: integer data expected.')
      ELSE IF(TEXT12.EQ.'MODE') THEN
        CALL REDGET(INDIC,NITMA,FLOT,TEXT12,DFLOT)
        IF(INDIC.NE.1) CALL XABORT('VAL: integer data expected.')
        JPFLU=LCMGID(IPFLU,'MODE')
        IPFLU=LCMGIL(JPFLU,NITMA)
      ELSE IF(TEXT12.EQ.'DIM') THEN
        CALL REDGET(INDIC,DIM,FLOT,TEXT12,DFLOT)
        IF((DIM.LE.1).OR.(DIM.GE.4)) CALL XABORT('VAL: DIM .ne. 2 or 3'
     1   //' expected.')
        CALL REDGET(INDIC,NITMA,DX,TEXT12,DFLOT)
        CALL REDGET(INDIC,NITMA,DY,TEXT12,DFLOT)
        IF(DIM.EQ.3) CALL REDGET(INDIC,NITMA,DZ,TEXT12,DFLOT)
      ELSE IF(TEXT12.EQ.';') THEN
        GO TO 20
      ELSE
        CALL XABORT('VAL: unknownn keyword-->'//TEXT12)
      ENDIF
      GO TO 10
*----
*  Get Data in L_TRACK
*----
*     compute X and Y mesh from L_TRACK
   20 ALLOCATE(XXX(NXD),YYY(NYD))
      CALL XDRSET(XXX,NXD,0.0)
      CALL XDRSET(YYY,NYD,0.0)
      IREG=0
      IF(L3D) THEN
        ALLOCATE(ZZZ(NZD))
        CALL XDRSET(ZZZ,NZD,0.0)
        DO K=1,NZD
          DO J=1,NYD
            DO I=1,NXD
              IREG=IREG+1
              IF(XX(IREG).NE.0.0) THEN
                IF(XXX(I).EQ.0.0) THEN
                  XXX(I)=XX(IREG)
                ELSE IF(ABS(XXX(I)-XX(IREG)).GT.1.0E-6) THEN
                  CALL XABORT('VAL: inconsistent tracking in X')
                ENDIF
              ENDIF
              IF(YY(IREG).NE.0.0) THEN
                IF(YYY(J).EQ.0.0) THEN
                  YYY(J)=YY(IREG)
                ELSE IF(ABS(YYY(J)-YY(IREG)).GT.1.0E-6) THEN
                  CALL XABORT('VAL: inconsistent tracking in Y')
                ENDIF
              ENDIF
              IF(ZZ(IREG).NE.0.0) THEN
                IF(ZZZ(K).EQ.0.0) THEN
                  ZZZ(K)=ZZ(IREG)
                ELSE IF(ABS(ZZZ(K)-ZZ(IREG)).GT.1.0E-6) THEN
                  CALL XABORT('VAL: inconsistent tracking in Z')
                ENDIF
              ENDIF
            ENDDO
          ENDDO
        ENDDO
      ELSE
        DO J=1,NYD
          DO I=1,NXD
            IREG=IREG+1
            IF(XX(IREG).NE.0.0) THEN
              IF(XXX(I).EQ.0.0) THEN
                XXX(I)=XX(IREG)
              ELSE IF(ABS(XXX(I)-XX(IREG)).GT.1.0E-6) THEN
                CALL XABORT('VAL: inconsistent tracking in X')
              ENDIF
            ENDIF
            IF(YY(IREG).NE.0.0) THEN
              IF(YYY(J).EQ.0.0) THEN
                YYY(J)=YY(IREG)
              ELSE IF(ABS(YYY(J)-YY(IREG)).GT.1.0E-6) THEN
                CALL XABORT('VAL: inconsistent tracking in Y')
              ENDIF
            ENDIF
          ENDDO
        ENDDO
      ENDIF
      IF(IREG.NE.NREG) CALL XABORT('VAL: invalid tracking')
      MXD(1)=0.0
      MYD(1)=0.0
      MZD(1)=0.0
      DO I=1,NXD
        MXD(I+1)=MXD(I)+XXX(I)
      ENDDO
      MYD(1)=0.0
      DO I=1,NYD
        MYD(I+1)=MYD(I)+YYY(I)
      ENDDO
      MZD(1)=0.0
      IF(L3D) THEN
        DO I=1,NZD
          MZD(I+1)=MZD(I)+ZZZ(I)
        ENDDO
        DEALLOCATE(ZZZ)
      ELSE
        MZD(2)=0.0
      ENDIF
      DEALLOCATE(YYY,XXX)
*----
*  Perform interpolation
*----
*     Compute points to interpolate
      NXI=INT((MXD(NXD+1)-MXD(1))/DX)+1
      NYI=INT((MYD(NYD+1)-MYD(1))/DY)+1
      NZI=INT((MZD(NZD+1)-MZD(1))/DZ)+1
      ALLOCATE(MXI(NXI),MYI(NYI),MZI(NZI))
      ALLOCATE(FXYZ(NXI*NYI*NZI,NG))
      DO I=1,NXI
        MXI(I)=MXD(1)+DX*REAL(I-1)
      ENDDO
      DO I=1,NYI
        MYI(I)=MYD(1)+DY*REAL(I-1)
      ENDDO
      DO I=1,NZI
        MZI(I)=MZD(1)+DZ*REAL(I-1)
      ENDDO
      JPFLU=LCMGID(IPFLU,'FLUX')
*     Get Data in L_FLUX
      ALLOCATE(FLXD(NUN))
      DO IG=1,NG
        CALL LCMGDL(JPFLU,IG,FLXD)
*       Perform interpolation
        IF(L3D) THEN
          IF(ICHX.EQ.1) THEN
*           Variational collocation method
            CALL LCMLEN(IPTRK,'KN',MAXKN,ITYLCM)
            MKN=MAXKN/(NXD*NYD*NZD)
            ALLOCATE(KN(MAXKN))
            CALL LCMGET(IPTRK,'KN',KN)
            CALL LCMSIX(IPTRK,'BIVCOL',1)
            CALL LCMLEN(IPTRK,'T',LC,ITYLCM)
            CALL LCMGET(IPTRK,'E',E)
            CALL LCMSIX(IPTRK,' ',2)
            CALL VALUE2(LC,MKN,NXD,NYD,NZD,L4,MXI,MYI,MZI,MXD,MYD,MZD,
     1      FLXD,MAT,KN,NXI,NYI,NZI,E,FXYZ(1,IG))
            DEALLOCATE(KN)
          ELSE IF(ICHX.EQ.2) THEN
*           Raviart-Thomas finite element method
            CALL VALUE4(IELEM,NUN,NXD,NYD,NZD,MXI,MYI,MZI,MXD,MYD,MZD,
     1      FLXD,MAT,KFLX,NXI,NYI,NZI,FXYZ(1,IG))
          ELSE IF(ICHX.EQ.3) THEN
*           Nodal collocation method (MCFD)
            CALL VALUE1(IDIM,NXD,NYD,NZD,L4,MXI,MYI,MZI,MXD,MYD,MZD,
     1      FLXD,MAT,IELEM,NXI,NYI,NZI,FXYZ(1,IG))
          ELSE
            CALL XABORT('VAL: INTERPOLATION NOT IMPLEMENTED(1).')
          ENDIF
        ELSE
          IF(ICHX.EQ.1) THEN
*           Variational collocation method
            CALL LCMLEN(IPTRK,'KN',MAXKN,ITYLCM)
            MKN=MAXKN/(NXD*NYD)
            ALLOCATE(KN(MAXKN))
            CALL LCMGET(IPTRK,'KN',KN)
            CALL LCMSIX(IPTRK,'BIVCOL',1)
            CALL LCMLEN(IPTRK,'T',LC,ITYLCM)
            CALL LCMGET(IPTRK,'E',E)
            CALL LCMSIX(IPTRK,' ',2)
            CALL VALU2B(LC,MKN,NXD,NYD,L4,MXI,MYI,MXD,MYD,FLXD,MAT,KN,
     1      NXI,NYI,E,FXYZ(1,IG))
          ELSE IF(ICHX.EQ.2) THEN
*           Raviart-Thomas finite element method
            CALL VALU4B(IELEM,NUN,NXD,NYD,MXI,MYI,MXD,MYD,FLXD,MAT,
     1      KFLX,NXI,NYI,FXYZ(1,IG))
          ELSE IF(ICHX.EQ.3) THEN
*           Nodal collocation method (MCFD)
            CALL VALU1B(IDIM,NXD,NYD,L4,MXI,MYI,MXD,MYD,FLXD,MAT,IELEM,
     1      NXI,NYI,FXYZ(1,IG))
          ELSE
            CALL XABORT('VAL: INTERPOLATION NOT IMPLEMENTED(2).')
          ENDIF
        ENDIF
      ENDDO
*----
*  Save results
*----
      CALL LCMPUT(IPFVW,'MXI',NXI,2,MXI)
      CALL LCMPUT(IPFVW,'MYI',NYI,2,MYI)
      CALL LCMPUT(IPFVW,'MZI',NZI,2,MZI)
      CALL XDISET(IFV,NSTATE,0)
      IFV(1)=NG
      IFV(2)=NXI
      IFV(3)=NYI
      IFV(4)=NZI
      CALL LCMPUT(IPFVW,'STATE-VECTOR',NSTATE,1,IFV)
      JPFVW=LCMLID(IPFVW,'FLUX',NG)
      DO IG=1,NG
        CALL LCMPDL(JPFVW,IG,NXI*NYI*NZI,2,FXYZ(1,IG))
      ENDDO
*----
*  Save results
*----
      IF(IMPX.GE.1)THEN
        WRITE(6,*) 'Mesh along X-direction'
        WRITE(6,*) (MXI(I),I=1,NXI)
        WRITE(6,*) 'Mesh along Y-direction'
        WRITE(6,*) (MYI(I),I=1,NYI)
        WRITE(6,*) 'Mesh along Z-direction'
        WRITE(6,*) (MZI(I),I=1,NZI)
        IF(IMPX.GE.2)THEN
          WRITE(6,*) 'Flux distribution:'
          DO IG=1,NG
            WRITE(6,*) 'Group',IG
            DO K=1,NZI
              WRITE(6,*) 'Plane',K
              DO J=1,NYI
                WRITE(6,*) (FXYZ(I+(J-1+(K-1)*NYI)*NXI,IG),I=1,NXI)
              ENDDO
            ENDDO
          ENDDO
        ENDIF
      ENDIF
*----
*  RELEASE GENERAL TRACKING INFORMATION
*----
      DEALLOCATE(FLXD)
      DEALLOCATE(FXYZ)
      DEALLOCATE(MXI,MYI,MZI)
      DEALLOCATE(MXD,MYD,MZD)
      DEALLOCATE(XX,YY,ZZ)
      DEALLOCATE(KFLX,MAT)
      RETURN
      END

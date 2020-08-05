*DECK XELPR3
      SUBROUTINE XELPR3(IPTRK,IZ,NZP)
*
*-----------------------------------------------------------------------
*
*Purpose:
* Create 2D projection (EXCELT geometry analysis) of a 3D prismatic
* geometry
*
*Copyright:
* Copyright (C) 2002 Ecole Polytechnique de Montreal
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
*Author(s): R. Le Tellier
*
*Parameters: input
* IPTRK   pointer to the excell tracking (L_TRACK).
* IZ      projection axis.
*
*Parameters: output
* NZP     number of IZ-plans.
*
*-----------------------------------------------------------------------
*
      USE GANLIB
      IMPLICIT NONE
*----
*  SUBROUTINE ARGUMENTS
*----
      TYPE(C_PTR) IPTRK
      INTEGER IZ,NZP
*----
*  LOCAL VARIABLES
*----
      INTEGER NSTATE,IOUT
      PARAMETER(NSTATE=40,IOUT=6)
      INTEGER GSTATE(NSTATE),ESTATE(NSTATE),ICODE(6),NCODE(6),KSIGN(3),
     1 KTYPE(3),LCLSYM(3)
      INTEGER IX,IY,NDIM,N3MS,N3MR,LDIM,LMESH,N3RS,I,N2MS,N2MR,
     1 N2RS,N3R,N3S,NFI
      REAL ALBEDO(6)
      INTEGER, ALLOCATABLE, DIMENSION(:) :: MINDIM,MAXDIM,ICORD,MATALB,
     1 KEYMRG,INDEX,MIN2,MAX2,ICOR2,MAT2,KEY2,IND2,IND2T3,MATMRG
      REAL, ALLOCATABLE, DIMENSION(:) :: REMESH,VOLSUR,REM2,VOL2,ZCOR,
     1 VOLMRG
*---
      IF (IZ.EQ.3) THEN
         IX=1
         IY=2
      ELSEIF (IZ.EQ.2) THEN
         IX=3
         IY=1
      ELSEIF (IZ.EQ.1) THEN
         IX=2
         IY=3
      ELSE
         CALL XABORT('XELPR3: ILLEGAL PROJECTION AXIS')
      ENDIF
*---
* RECOVER INFORMATION FROM EXCELL 3D GEOMETRY ANALYSIS
*---
      CALL LCMGET(IPTRK,'SIGNATURE',KSIGN)
      CALL LCMGET(IPTRK,'TRACK-TYPE',KTYPE)
      CALL XDISET(GSTATE,NSTATE,0)
      CALL LCMGET(IPTRK,'STATE-VECTOR',GSTATE)
      CALL LCMGET(IPTRK,'ICODE',ICODE)
      CALL LCMGET(IPTRK,'NCODE',NCODE)
      CALL LCMPUT(IPTRK,'NCODE',6,1,NCODE)     
      CALL LCMGET(IPTRK,'ALBEDO',ALBEDO)
      CALL LCMSIX(IPTRK,'EXCELL',1)
      CALL XDISET(ESTATE,NSTATE,0)
      CALL LCMGET(IPTRK,'STATE-VECTOR',ESTATE)
      NDIM=ESTATE(1)
      IF (NDIM.NE.3) 
     1   CALL XABORT('XELPR3: NON 3D GEOMETRY')
      N3MS=ESTATE(2)
      N3MR=ESTATE(3)
      LDIM=ESTATE(4)
      LMESH=ESTATE(5)
      N3RS=ESTATE(6)
      LCLSYM(1)=ESTATE(8)
      LCLSYM(2)=ESTATE(9)
      LCLSYM(3)=ESTATE(10)
      ALLOCATE(MINDIM(LDIM),MAXDIM(LDIM),ICORD(LDIM),MATALB(N3RS),
     1 KEYMRG(N3RS),INDEX(4*N3RS))
      ALLOCATE(REMESH(LMESH),VOLSUR(N3RS))
      CALL LCMGET(IPTRK,'MINDIM',MINDIM)
      CALL LCMGET(IPTRK,'MAXDIM',MAXDIM)
      CALL LCMGET(IPTRK,'ICORD',ICORD)
      CALL LCMGET(IPTRK,'REMESH',REMESH)
      CALL LCMGET(IPTRK,'VOLSUR',VOLSUR)
      CALL LCMGET(IPTRK,'MATALB',MATALB)
      CALL LCMGET(IPTRK,'KEYMRG',KEYMRG)
      CALL LCMGET(IPTRK,'INDEX',INDEX)
      CALL LCMSIX(IPTRK,' ',2)
*--- 
* CHECK FOR CYLINDER ORIENTATION
*---
      IF (LDIM.GT.3) THEN
         DO I=3,LDIM-1
            IF (ICORD(I+1).NE.IZ)
     1         CALL XABORT('XELPR3: NON Z-PRISMATIC GEOMETRY')
         ENDDO
      ENDIF
*---
* CONSTRUCT 2D GEOMETRY ANALYSIS AND (2D,Z)->3D INDEX 
*---
      CALL LCMSIX(IPTRK,'PROJECTION',1)
      CALL LCMPUT(IPTRK,'SIGNATURE',3,3,KSIGN)
      CALL LCMPUT(IPTRK,'TRACK-TYPE',3,3,KTYPE)
      NZP=MAXDIM(IZ)-MINDIM(IZ)
      N2MR=N3MR/NZP
      N2MS=(N3MS-2*N2MR)/NZP
      N2RS=N2MR+N2MS+1
      GSTATE(1)=N2MR
      GSTATE(2)=N2MR
      GSTATE(5)=N2MS
      GSTATE(7)=1
      GSTATE(8)=1
      CALL LCMPUT(IPTRK,'STATE-VECTOR',NSTATE,1,GSTATE)
      CALL LCMPUT(IPTRK,'ICODE',6,1,ICODE)
      CALL LCMPUT(IPTRK,'NCODE',6,1,NCODE)
      CALL LCMPUT(IPTRK,'ALBEDO',6,2,ALBEDO)
      CALL LCMSIX(IPTRK,'EXCELL',1)
      ALLOCATE(MIN2(LDIM),MAX2(LDIM),ICOR2(LDIM),MAT2(N2RS),KEY2(N2RS),
     1 IND2(4*N2RS),IND2T3(N2RS*(NZP+2)),MATMRG(N3RS))
      ALLOCATE(REM2(LMESH),VOL2(N2RS),ZCOR(NZP+1),VOLMRG(N3RS))
      CALL XEL3T2(IX,IY,IZ,LDIM,N3MS,N3MR,N3RS,LMESH,NZP,N2MS,N2MR,
     1     N2RS,N3S,N3R,NFI,MINDIM,MAXDIM,REMESH,VOLSUR,MATALB,KEYMRG,
     2     INDEX,MAX2,MIN2,ICOR2,REM2,VOL2,MAT2,KEY2,IND2,IND2T3,
     3     MATMRG,VOLMRG,ZCOR)
      ESTATE(1)=2
      ESTATE(2)=N2MS
      ESTATE(3)=N2MR
      ESTATE(6)=N2RS
      ESTATE(8)=LCLSYM(IX)
      ESTATE(9)=LCLSYM(IY)
      ESTATE(10)=LCLSYM(IZ)
      CALL LCMPUT(IPTRK,'MINDIM',LDIM,1,MIN2)
      CALL LCMPUT(IPTRK,'MAXDIM',LDIM,1,MAX2)
      CALL LCMPUT(IPTRK,'ICORD',LDIM,1,ICOR2)
      CALL LCMPUT(IPTRK,'INDEX',4*N2RS,1,IND2)
      CALL LCMPUT(IPTRK,'REMESH',LMESH,2,REM2)
      CALL LCMPUT(IPTRK,'KEYMRG',N2RS,1,KEY2)
      CALL LCMPUT(IPTRK,'MATALB',N2RS,1,MAT2)
      CALL LCMPUT(IPTRK,'VOLSUR',N2RS,2,VOL2)
      CALL LCMPUT(IPTRK,'STATE-VECTOR',NSTATE,1,ESTATE)
      CALL LCMSIX(IPTRK,' ',2)
      CALL LCMPUT(IPTRK,'MATALB',NFI,1,MATMRG)
      CALL LCMPUT(IPTRK,'VOLSUR',NFI,2,VOLMRG)
      CALL LCMPUT(IPTRK,'ZCOORD',NZP+1,2,ZCOR)
      CALL LCMPUT(IPTRK,'IND2T3',N2RS*(NZP+2),1,IND2T3)
      CALL LCMSIX(IPTRK,' ',2)
      DEALLOCATE(VOLMRG,ZCOR,VOL2,REM2)
      DEALLOCATE(MATMRG,IND2T3,IND2,KEY2,MAT2,ICOR2,MAX2,MIN2)
*
      DEALLOCATE(VOLSUR,REMESH)
      DEALLOCATE(INDEX,KEYMRG,MATALB,ICORD,MAXDIM,MINDIM)
*
      RETURN
      END

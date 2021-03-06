*DECK AXGXCW
      SUBROUTINE AXGXCW(IPGEOM,IPTRKM,IPRINT,GEONAM,ISYMM )
C
C----
C  1- PROGRAMME STATISTICS:
C      NAME     : AXGXCW
C      USE      : ANALYSE XEL GEOMETRY - XCWTRK module
C      AUTHOR   : G.MARLEAU
C      CREATED  : 2001/10/30
C                 extracted from XCWTRK since this part 
C                 of the routine is called by the modules
C                 PSP, EDI, EXCELT and EXCELL.
C
C
C  2- ROUTINE PARAMETERS:
C     IPGEOM : GEOMETRY DATA STRUCTURES POINTER
C              ***> INTEGER IPGEOM
C     IPTRKM : TRACKING DATA STRUCTURES POINTER         
C              ***> INTEGER IPTRKM
C     IPRINT : PRINT LEVEL                              
C              ***> INTEGER IPRINT
C     GEONAM : GEOMETRY NAME
C              ***> CHARACTER*12 GEONAM
C     ISYMM  : GEOMETRY SYMMETRY
c              ***> INTEGER ISYMM
C----
C
      USE          GANLIB
      IMPLICIT     NONE
      INTEGER      IOUT,NALB,MREGIO,NSTATE
      PARAMETER   (IOUT=6,NALB=6,MREGIO=100000,NSTATE=40)
C----
C  ROUTINE PARAMETERS
C----
      TYPE(C_PTR)  IPGEOM,IPTRKM
      INTEGER      IPRINT,ISYMM
      CHARACTER*12 GEONAM
C----
C  INTEGER ALLOCATABLE ARRAYS
C----
      INTEGER, ALLOCATABLE, DIMENSION(:) :: KEYMRG,MATALB,NRINFO,NRODS,
     > NRODR,NXRS,NXRI,MATRT 
C----
C  REAL ALLOCATABLE ARRAYS
C----
      REAL, ALLOCATABLE, DIMENSION(:) :: VOLSUR,RAN,RODS,RODR
C----
C  LOCAL VARIABLES
C---- 
      LOGICAL      ILK
      INTEGER      NCODE(NALB),ICODE(NALB)
      REAL         ZCODE(NALB),ALBEDO(NALB) 
      INTEGER      ISTATE(NSTATE)
      INTEGER      NDIM  ,NSUR  ,NVOL  ,MAXJ  ,IROT  ,NBAN  ,
     >             MNAN  ,NRT   ,MSROD ,MAROD ,NSURF ,NSURX ,
     >             NMAT  ,NUNK
      REAL         RADMIN,COTE  
C----
C  SET POSITION VECTOR AND READ ISTATE
C----
      IF(IPRINT.GT.0) THEN
        WRITE(6,'(/26H AXGXCW: PROCESS GEOMETRY ,A12)') GEONAM
      ENDIF
      CALL XDISET(ISTATE,NSTATE,0)
      CALL LCMGET(IPGEOM,'STATE-VECTOR',ISTATE)
      NDIM=2
      IF(ISTATE(1).EQ.3) THEN
        NSUR=1
      ELSE IF(ISTATE(1).EQ.20) THEN
        NSUR=4
      ELSE IF(ISTATE(1).EQ.24) THEN
        NSUR=6
      ENDIF
      MAXJ=1
      IROT=0
      CALL XCGDIM(IPGEOM,MREGIO,NSUR  ,IROT  ,ISYMM ,MAXJ  ,
     >            NVOL  ,NBAN  ,MNAN  ,NRT   ,MSROD ,MAROD ,
     >            NSURF )
C----
C  CHECK FOR SYMMETRY
C----
      NSURX=NSUR
      IF(ISYMM.GT.1) THEN
        IF(NSURX.EQ.4) THEN
          IROT=-ISYMM-400
        ELSE IF(NSURX.EQ.6) THEN
          IROT=-ISYMM-600
        ELSE
          IROT=-ISYMM-100
        ENDIF
        NSUR=1
      ENDIF
C----
C  ALLOCATE MEMORY FOR PROCESSING GEOMETRY INFORMATION
C----
      ALLOCATE(KEYMRG(NSUR+NVOL+1),MATALB(NSUR+NVOL+1),NRINFO(2*MNAN),
     > NRODS(3*NRT),NRODR(NRT),NXRS(NRT),NXRI(NRT*NBAN))
      ALLOCATE(VOLSUR(NSUR+NVOL+1),RAN(NBAN),RODS(2*NRT),
     > RODR(MSROD*NRT))
C
      CALL XCGGEO(IPGEOM,IROT  ,NSUR  ,NVOL  ,NBAN  ,MNAN  ,
     >            NRT   ,MSROD ,IPRINT,ILK   ,NMAT  ,RAN   ,
     >            NRODS ,RODS  ,NRODR ,RODR  ,NRINFO,MATALB,
     >            VOLSUR,COTE  ,RADMIN,NCODE ,ICODE ,ZCODE ,
     >            ALBEDO,KEYMRG,NXRS  ,NXRI)
C----
C  BUILD BOUNDARY CONDITION MATRIX FOR REFLECTION AND TRANSMISSION
C----
      ALLOCATE(MATRT(NSUR))
      CALL XCGBCM(IPTRKM,NSUR  ,NCODE ,MATRT )
C----
C  SAVE TRACKING FOR CLUSTER GEOMETRY
C----
      CALL XDISET(ISTATE,NSTATE,0)
      NUNK=NVOL+NSUR+1
      ISTATE(1)=NDIM
      ISTATE(2)=NSUR
      ISTATE(3)=NVOL
      ISTATE(4)=NSURX
      ISTATE(5)=NBAN
      ISTATE(6)=NUNK
      ISTATE(7)=NRT
      ISTATE(8)=MSROD
      ISTATE(9)=MAROD
      ISTATE(10)=MNAN
      CALL LCMSIX(IPTRKM,'EXCELL      ',1)
      CALL LCMPUT(IPTRKM,'STATE-VECTOR',NSTATE   ,1,ISTATE)
      CALL LCMPUT(IPTRKM,'RAN         ',NBAN     ,2,RAN   )
      IF(NSURX .EQ. 4)
     >CALL LCMPUT(IPTRKM,'COTE        ',1        ,2,COTE  )
      CALL LCMPUT(IPTRKM,'RADMIN      ',1        ,2,RADMIN)
      CALL LCMPUT(IPTRKM,'NRODS       ',3*NRT    ,1,NRODS )
      CALL LCMPUT(IPTRKM,'RODS        ',2*NRT    ,2,RODS  )
      CALL LCMPUT(IPTRKM,'NRODR       ',NRT      ,1,NRODR )
      CALL LCMPUT(IPTRKM,'RODR        ',MSROD*NRT,2,RODR  )
      CALL LCMPUT(IPTRKM,'NRINFO      ',2*NBAN   ,1,NRINFO)
      CALL LCMPUT(IPTRKM,'NXRI        ',NRT*NBAN ,1,NXRI  )
      CALL LCMPUT(IPTRKM,'NXRS        ',NRT      ,1,NXRS  )
      CALL LCMPUT(IPTRKM,'KEYMRG      ',NUNK     ,1,KEYMRG)
      CALL LCMPUT(IPTRKM,'MATALB      ',NUNK     ,1,MATALB)
      CALL LCMPUT(IPTRKM,'VOLSUR      ',NUNK     ,2,VOLSUR)
      CALL LCMSIX(IPTRKM,'EXCELL      ',2)
      CALL LCMPUT(IPTRKM,'ALBEDO      ',6        ,2,ALBEDO)
      CALL LCMPUT(IPTRKM,'ICODE       ',6        ,1,ICODE )
      CALL LCMPUT(IPTRKM,'NCODE       ',6        ,1,NCODE )
C----
C  RELEASE BLOCKS FOR GEOMETRY
C----
      DEALLOCATE(MATRT)
      DEALLOCATE(RODR,RODS,RAN,VOLSUR)
      DEALLOCATE(NXRI,NXRS,NRODR,NRODS,NRINFO,MATALB,KEYMRG)
      RETURN
      END

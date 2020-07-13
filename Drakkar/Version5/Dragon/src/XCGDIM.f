*DECK XCGDIM
      SUBROUTINE XCGDIM(IPGEOM,MREGIO,NSOUT,IROT,IAPP,MAXJ,NVOL,
     >                  NBAN,MNAN,NRT,MSROD,MAROD,NSURF)
C
C----------------------------------------------------------------------
C
C 1-  SUBROUTINE STATISTICS:
C
C          NAME      -> XCGDIM
C          USE       -> INITIALIZE DIMENSION FOR 2-D CLUSTER GEOMETRY
C          DATE      -> 14-06-1990
C          AUTHOR    -> G. MARLEAU
C
C 2-  PARAMETERS:
C
C INPUT
C  IPGEOM  : POINTER TO THE GEOMETRY                       I
C  MREGIO  : MAXIMUM NUMBER OF REGIONS                     I
C  NSOUT   : NUMBER OF SURFACE FOR OUTER REGION            I
C  IROT    : TYPE OF PIJ RECONSTRUCTION                    I
C            IROT = 0 -> CP CALCULATIONS
C            IROT = 1 -> DIRECT JPM RECONSTRUCTION
C            IROT=  2 -> ROT2 TYPE RECONSTRUCTION
C  IAPP    : TYPE OF SURFACE CONDITIONS                    I
C            LEVEL OF DP APPROXIMATION FOR JPM
C            IAPP = 1 -> DP0 ALL
C            IAPP = 2 -> DP1 ALL (DEFAULT)
C            IAPP = 3 -> DP1 INSIDE DP0 OUTSIDE
C            SYMMETRY CONDITIONS FOR CP
C  MAXJ    : MAXIMUM NUMBER OF CURRENTS                    I
C            UNUSED FOR CP CALCULATIONS
C OUTPUT
C  NVOL    : NUMBER OF REGIONS                             I
C  NBAN    : NUMBER OF CONCENTRIC REGIONS                  I
C  MNAN    : MAXIMUM NUNBER OF RADIUS TO READ              I
C  NRT     : NUMBER OF ROD TYPES                           I
C  MSROD   : MAXIMUM NUMBER OF SUBRODS PER RODS            I
C  MAROD   : MAXIMUM NUMBER OF RODS AN ANNULUS             I
C  NSURF   : MAXIMUM NUMBER REAL SURFACES                  I
C            UNUSED FOR CP CALCULATION
C
C----------------------------------------------------------------------
C
      USE         GANLIB
      PARAMETER  (NSTATE=40)
      TYPE(C_PTR) IPGEOM
      INTEGER     MREGIO,NSOUT,IROT,IAPP,MAXJ,NVOL,
     >            NBAN,MNAN,NRT,MSROD,MAROD,NSURF,ISTATE(NSTATE)
      CHARACTER   CMSG*131,TEXT12*12
C----
C  ALLOCATABLE ARRAYS
C----
      INTEGER, ALLOCATABLE, DIMENSION(:) :: JSPLIT,JGEOM
C----
C  CHECK FOR VALID IROT AND GEOMETRY
C----
      IF(IROT.GT.2.OR.IROT.LT.0)
     >  CALL XABORT('XCGDIM: UNABLE TO PROCESS THE GEOMETRY.')
      CALL XDRSET(ISTATE,NSTATE,0)
      CALL LCMGET(IPGEOM,'STATE-VECTOR',ISTATE)
C----
C  CHECK FOR INVALID GEOMETRY OPTIONS
C  ISTATE( 8) -> CELL IS INVALID
C  ISTATE(10) -> MERGE IS INVALID
C  ISTATE(11) -> SPLIT IS INVALID FOR CLUSTER ANNULUS
C----
      IF ( (ISTATE(8).NE.0).OR.(ISTATE(10).NE.0) )
     >     CALL XABORT('XCGDIM: UNABLE TO PROCESS THE GEOMETRY.')
      IF(ISTATE(11).EQ.0) THEN
        NVOL=ISTATE(6)
      ELSE
        CALL LCMLEN(IPGEOM,'SPLITR',NSPLIT,ITYPE)
        IF(ITYPE.NE.1)
     >    CALL XABORT('XCGDIM: SPLIT RECORD ON LCM IS NOT INTEGER')
        ALLOCATE(JSPLIT(NSPLIT))
        CALL LCMGET(IPGEOM,'SPLITR',JSPLIT)
        IF(NSOUT.GT.1) THEN
          NVOL=1
        ELSE
          NVOL=0
        ENDIF
        DO 135 ISPLIT=1,NSPLIT
          NVOL=NVOL+ABS(JSPLIT(ISPLIT))
 135    CONTINUE
        DEALLOCATE(JSPLIT)
      ENDIF
      NBAN=NVOL
      MNAN=NBAN+1
      IF(NSOUT.EQ.4) THEN
        MNAN=MNAN+3
      ENDIF
      IF(NSOUT.EQ.4) THEN
        NSURF=2*NVOL+2
      ELSE IF(NSOUT.EQ.6) THEN
        NSURF=2*NVOL+4
      ELSE
        NSURF=2*NVOL-1
      ENDIF
C----
C  COUNT NUMBER OF ROD TYPES IN CLUSTER
C----
      CALL LCMLEN(IPGEOM,'CLUSTER',ILONG,ITYPE)
      IF(ITYPE.NE.3)
     >   CALL XABORT('XCGDIM: CLUSTER RECORD ON LCM IS NOT CHARACTER')
      NRT=ILONG/3
      IF(ISTATE(9).LT.NRT) THEN
        WRITE(CMSG,9001) ISTATE(9),NRT
        CALL XABORT(CMSG)
      ENDIF
      ALLOCATE(JGEOM(ILONG))
      IPOS=1
      MSROD=1
      MAROD=1
      CALL LCMGET(IPGEOM,'CLUSTER',JGEOM)
C----
C  FOR EACH ROD TYPE FIND NUMBER OF SUBRODS AND NUMBER OF PINS
C----
      DO 120 IRT=1,NRT
        WRITE(TEXT12(1:4),'(A4)')  JGEOM(IPOS)
        WRITE(TEXT12(5:8),'(A4)')  JGEOM(IPOS+1)
        WRITE(TEXT12(9:12),'(A4)') JGEOM(IPOS+2)
        IPOS=IPOS+3
        CALL LCMSIX(IPGEOM,TEXT12,1)
        CALL XDRSET(ISTATE,NSTATE,0)
        CALL LCMGET(IPGEOM,'STATE-VECTOR',ISTATE)
        CALL LCMGET(IPGEOM,'RPIN',RPIN)
        CALL LCMGET(IPGEOM,'NPIN',NPIN)
        MAROD=MAX(MAROD,NPIN)
        IF(RPIN.EQ.0.0) THEN
          IROTS=1
        ELSE
          IROTS=IROT
        ENDIF
        IF(ISTATE(1).NE.3) THEN
          WRITE(CMSG,9002) ISTATE(1)
          CALL XABORT(CMSG)
        ENDIF
        IF(ISTATE(11).EQ.0) THEN
          NVOL=NVOL+ISTATE(6)
          NMSROD=ISTATE(6)
          IF(IROT.GT.0) NSURF=NSURF+2*IROTS*ISTATE(6)
        ELSE
          CALL LCMLEN(IPGEOM,'SPLITR',NSPLIT,ITYPE)
          IF(ITYPE.NE.1)
     >      CALL XABORT('XCGDIM: SPLIT RECORD ON LCM IS NOT INTEGER')
          ALLOCATE(JSPLIT(NSPLIT))
          CALL LCMGET(IPGEOM,'SPLITR',JSPLIT)
          NMSROD=0
          DO 130 ISPLIT=1,NSPLIT
            NMSROD=NMSROD+ABS(JSPLIT(ISPLIT))
            NVOL=NVOL+ABS(JSPLIT(ISPLIT))
 130      CONTINUE
          IF(IROT.GT.0) NSURF=NSURF+2*IROTS*NMSROD
          DEALLOCATE(JSPLIT)
        ENDIF
        MSROD=MAX(MSROD,NMSROD)
        CALL LCMSIX(IPGEOM,' ',2)
 120  CONTINUE
      MNAN=MAX(MNAN,MSROD+1)
      DEALLOCATE(JGEOM)
C----
C  CHECK IF NUMBER OF REGIONS IS ADEQUATE
C----
      IF (NVOL.GT.MREGIO) THEN
        WRITE(CMSG,9003) MREGIO,NVOL
        CALL XABORT(CMSG)
      ENDIF
      IF(IROT.GT.0) THEN
        IF(IAPP.EQ.3) THEN
          IAPPR=2
        ELSE
          IAPPR=IAPP
        ENDIF
        IF(NSOUT.EQ.4) THEN
          NSURF=NSURF*IAPPR+4
        ELSE IF(NSOUT.EQ.6) THEN
          NSURF=NSURF*IAPPR+6
        ELSE
        NSURF=NSURF*IAPPR
        ENDIF
        IF(MAXJ.LT.NSURF) THEN
          WRITE(CMSG,9004) NSURF,MAXJ
          CALL XABORT(CMSG)
        ENDIF
      ELSE
        NSURF=1
        IF(NSOUT.EQ.6) THEN
          CALL LCMGET(IPGEOM,'IHEX',IHEX)
          IF(IHEX.EQ.1) THEN
            IAPP=12
          ELSE IF(IHEX.EQ.3) THEN
            IAPP=6
          ENDIF
        ENDIF
      ENDIF
      RETURN
C----
C  ERROR MESSAGES FORMATS
C----
 9001 FORMAT('XCGDIM: ONLY ',I10,5X,'SUB GEOMETRIES ON LCM WHILE ',5X,
     >       I10,5X,'SUB GEOMETRIES ARE REQUIRED BY CLUSTER')
 9002 FORMAT('XCGDIM: ',I10,5X,'IS AN ILLEGAL GEOMETRY INSIDE CLUSTER')
 9003 FORMAT('XCGDIM: MAXIMUM NUMBER OF REGION ALLOCATED =',I10,
     >       5X,'NUMBER OF REGION REQUIRED =',I10)
 9004 FORMAT('XCGDIM: NUMBER OF CURRENT=',I10,5X,'IS LARGER THAN ',
     >'ALLOWED MAXIMUM VALUE MAXJ=',I10)
      END
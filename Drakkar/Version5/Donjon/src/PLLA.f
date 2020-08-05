*DECK PLLA
      SUBROUTINE PLLA(IPOPT,N0,M0,APLUS,PDG,BPLUS,INPLUS,XDROIT,FCOST,
     > GF,XOBJ,IMPR,EPSIM,NCST,GRAD,CONTR,INEGAL,IERR)
*
*-----------------------------------------------------------------------
*
*Purpose:
* Solves the quasi-linear problem using the augmented Lagrangian.
* PLLA = Linear Programmation Augmented Lagrangian
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
*Parameters: input/ouput
* IPOPT   pointer to the L_OPTIMIZE object.
* N0      number of control variables.
* M0      number of constraints.
* APLUS   coefficient matrix for the linear constraints.
* PDG     weights assigned to control variables in the quadratic
*         constraint.
* BPLUS   right hand sides corresponding to the coefficient matrix.
* INPLUS  constraint relations (=-1 for .GE.; =0 for .EQ.; =1 for .LE.).
* XDROIT  quadratic constraint radius squared.
* FCOST   costs of control variables.
* GF      objective function.
* XOBJ    control variables.
* IMPR    print flag.
* EPSIM   tolerence used for inner linear SIMPLEX calculation.
* NCST    number of constraints.
* GRAD    linearized gradients (GRAD(:,1) are control variable costs
*         and GRAD(:,2:NCST+1) are linear constraint coefficients).
* CONTR   constraint right hand sides.
* INEGAL  constraint relations (=-1 for .GE.; =0 for .EQ.; =1 for .LE.).
*
*Parameters: ouput
* IERR    return code (=0: normal completion).
*
*-----------------------------------------------------------------------
*
      USE GANLIB
      IMPLICIT NONE
*----
*  SUBROUTINE ARGUMENTS
*----
      TYPE(C_PTR) IPOPT
      INTEGER N0,M0,INPLUS(M0+1),IMPR,NCST,INEGAL(NCST),IERR
      DOUBLE PRECISION PDG(N0),BPLUS(M0+2),XDROIT,XOBJ(N0),EPSIM,
     > GRAD(N0,NCST+1),CONTR(NCST),APLUS(M0+2,M0+N0+1),GF(N0),FCOST
*----
*  LOCAL VARIABLES
*----
      INTEGER   ITERMX,LENGT,ITYP,I,J,K,ITER,NPM,M0B
      PARAMETER (ITERMX=10)
      LOGICAL   LCST(NCST),LCST2(NCST),LTST
      DOUBLE PRECISION LACOST,NORM,CRIT,LA0E
      INTEGER, ALLOCATABLE, DIMENSION(:) :: INPL2
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: LAFAC,CSTWGT,B2,
     > CONTR2,LAGF
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: APLUS2
*----
*  SCRATCH STORAGE ALLOCATION
*----
      ALLOCATE(INPL2(M0-NCST+1))
      ALLOCATE(LAFAC(NCST),CSTWGT(NCST),B2(M0-NCST+2),CONTR2(NCST))
      ALLOCATE(LAGF(N0),APLUS2(M0-NCST+1,N0+M0-NCST))
*----
*  STEP 0: INITIALIZATION
*  NPM: SIZE OF THE LINEARIZED SYSTEM.
*  M0B: NUMBER OF LINEARIZED CONSTRAINTS FOR THE LA ALGORITHM.
*       CORRESPONDS TO THE NUMBER OF POSSIBLY ACTIVE BOUNDS.
*----
      NPM=(M0+1)+N0
      M0B=M0-NCST
      IF(NCST.GT.0) THEN
         CALL LCMLEN(IPOPT,'F-LA-MULT',LENGT,ITYP)
         IF(LENGT.EQ.0) THEN
            CALL XABORT('PLLA: LAGRANGIAN FACTORS NON INITIALIZED')
         ELSEIF(LENGT.EQ.NCST) THEN
            CALL LCMGET(IPOPT,'F-LA-MULT',LAFAC)
         ELSE
            CALL XABORT('PLLA: WRONG NUMBER OF LA COEFFICIENTS')
         ENDIF
         CALL LCMLEN(IPOPT,'CST-WEIGHT',LENGT,ITYP)
         IF(LENGT.EQ.0) THEN
            CALL XABORT('PLLA: CONSTRAINTS PENALTIES NON INITIALIZED')
         ELSEIF(LENGT.EQ.NCST) THEN
            CALL LCMGET(IPOPT,'CST-WEIGHT',CSTWGT)
         ELSE
            CALL XABORT('PLLA: WRONG NUMBER OF CONSTRAINT WEIGHTS')
         ENDIF
         DO 10 J=1,NCST
   10    CONTR2(J)=-CONTR(J)
         CALL XDLSET(LCST2,NCST,.TRUE.)
         CALL XDLSET(LCST,NCST,.TRUE.)
      ENDIF
      CALL XDDSET(XOBJ,N0,0.0D0)
*----
*  INTERNAL ITERATIONS FOR THE LINEAR PROBLEM
*----
      ITER=0
   99 ITER=ITER+1
      LTST=.TRUE.
*----
*  STEP 1: LA FUNCTION EVALUATION
*----
      DO 110 J=1,NCST
         IF(INEGAL(J).NE.0) THEN
            CRIT=CONTR2(J)
            DO 100 I=1,N0
               CRIT=CRIT+GRAD(I,J+1)*XOBJ(I)
  100          CONTINUE
            CRIT=CSTWGT(J)*INEGAL(J)*CRIT+LAFAC(J)
            LCST(J)=(CRIT.LE.0.0)
         ENDIF
  110    CONTINUE

      DO 150 I=1,N0
         LAGF(I)=GF(I)
         DO 140 J=1,NCST
            IF(INEGAL(J).EQ.0) THEN
              LAGF(I)=LAGF(I)+GRAD(I,J+1)*(LAFAC(J)+CSTWGT(J)*CONTR2(J))
            ELSEIF(.NOT.LCST(J)) THEN
              LAGF(I)=LAGF(I)+INEGAL(J)*GRAD(I,J+1)
     1                       *(CSTWGT(J)*INEGAL(J)*CONTR2(J)+2*LAFAC(J))
            ENDIF
  140       CONTINUE
  150    CONTINUE

      LACOST=FCOST
      DO 160 J=1,NCST
         IF(INEGAL(J).EQ.0) THEN
            LACOST=LACOST+(LAFAC(J)+CSTWGT(J)/2.0*CONTR2(J))*CONTR2(J)
         ELSEIF(.NOT.LCST(J)) THEN
            LACOST=LACOST+INEGAL(J)*CONTR2(J)*2.0*LAFAC(J)
     1                   +CSTWGT(J)/2.0*CONTR2(J)**2
         ELSE
            LACOST=LACOST-3.0*LAFAC(J)**2/2.0/CSTWGT(J)
         ENDIF
  160    CONTINUE
      IF(ITER.EQ.1) LA0E=LACOST
      IF(IMPR.GE.3) THEN
         WRITE(6,*) 'GF',(GF(I),I=1,N0)
         WRITE(6,*) 'LAGF',(LAGF(I),I=1,N0)
         WRITE(6,*) 'PDG',(PDG(I),I=1,N0)
         WRITE(6,*) 'LACOST',LACOST,'M0B',M0B,'XDROIT',XDROIT
      ENDIF
*----
*  STEP 2: SOLUTION
*                         k,l
*               compute DX
*  case 1
*  If there is no constraints for the LA problem (M0B=0), 
*  then the solution is obvious: on the hypersphere(radius XDROIT) 
*  in the direction LAGF
*----
      IF(M0B.EQ.0) THEN
*
      NORM=0.0
      DO 200 I=1,N0
  200    NORM=NORM+LAGF(I)**2/PDG(I)
      NORM=NORM**0.5
*
      IF(NORM.EQ.0.0) THEN
         CALL XDDSET(XOBJ,N0,0.0D0)
      ELSE
         DO 210 I=1,N0
  210       XOBJ(I)=-XDROIT**0.5*LAGF(I)/PDG(I)/NORM
      ENDIF
*----
*  CASE 2
*  SOLUTION WITH THE LEMKE METHOD
*----
      ELSE
*
      DO 260 K=1,M0B
         DO 250 I=1,N0
  250       APLUS2(K,I)=APLUS(NCST+K,I)
         B2(K)=BPLUS(NCST+K)
         INPL2(K)=INPLUS(NCST+K)
  260    CONTINUE
      DO 270 I=1,N0
         APLUS2(M0B+1,I) = 0.0D0
  270    CONTINUE
      BPLUS(M0B+1)   = 0.0
      INPL2(M0B+1)  = 0
*
      CALL PLMAP2(N0,M0B,APLUS2,PDG,B2,INPL2,XDROIT,LAGF,LACOST,XOBJ,2,
     > EPSIM,IMPR,IERR)
*
      ENDIF
      DO 410 J=1,NCST
         IF(INEGAL(J).NE.0) THEN
            CRIT=CONTR2(J)
            DO 400 I=1,N0
               CRIT=CRIT+GRAD(I,J+1)*XOBJ(I)
  400          CONTINUE
            CRIT=CSTWGT(J)*INEGAL(J)*CRIT+LAFAC(J)
            LCST2(J)=(CRIT.LE.0.0)
         ENDIF
  410    CONTINUE
      
      IF((IMPR.GE.2).AND.(NCST.GT.0)) THEN
         WRITE(6,*) (LCST(J),J=1,NCST)
         WRITE(6,*) (LCST2(J),J=1,NCST)
      ENDIF
      DO 420 J=1,NCST
         LTST=LTST.AND.(LCST(J).EQV.LCST2(J))
  420    CONTINUE

      IF((.NOT.LTST) .AND.(ITER.LE.ITERMX)) GO TO 99
*----
*                  k,l
*    STEP 3: SAVE L
*                  a
*----
      CALL LCMSIX(IPOPT,'OLD-VALUE',1)
      CALL LCMPUT(IPOPT,'F-LA-EVAL',1,4,LA0E)
      IF(IMPR.GE.1)   WRITE(6,*) 'LAGF',(LAGF(I),I=1,N0)
      CALL LCMPUT(IPOPT,'DF-LA-PENAL',N0,4,LAGF)
      CALL LCMSIX(IPOPT,' ',0)
*
      IF(IMPR.GE.1) WRITE(6,*) 'Dvar',(XOBJ(I),I=1,N0)
*----
*  SCRATCH STORAGE DEALLOCATION
*----
      DEALLOCATE(APLUS2,LAGF)
      DEALLOCATE(CONTR2,B2,CSTWGT,LAFAC)
      DEALLOCATE(INPL2)
      RETURN
      END

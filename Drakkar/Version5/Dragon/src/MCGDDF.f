*DECK MCGDDF
      SUBROUTINE MCGDDF(N,K,M,NOM,NZON,H,XST,B)
*
*-----------------------------------------------------------------------
*
*Purpose:
* Calculate coefficients of a track for the characteristics integration.
* Diamond-Differencing scheme without fix-up.
* 'source term isolation' option turned on.
*
*Copyright:
* Copyright (C) 2002 Ecole Polytechnique de Montreal
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version
*
*Author(s): R. Le Tellier
*
*Parameters: input
* N       number of elements in the current track.
* K       total number of volumes for which specific values
*         of the neutron flux and reactions rates are required.
* M       number of material mixtures.
* NOM     vector containing the region number of the different segments
*         of this track.
* NZON    index-number of the mixture type assigned to each volume.
* H       vector containing the lenght of the different segments of this
*         track.
* XST     macroscopic total cross section.
*
*Parameters: output
* B       undefined.
*
*-----------------------------------------------------------------------
*
      IMPLICIT NONE
*----
*  SUBROUTINE ARGUMENTS
*----
      INTEGER N,K,M,NOM(N),NZON(K)
      REAL XST(0:M)
      DOUBLE PRECISION H(N),B(N)
*---
* LOCAL VARIABLES
*---
      INTEGER I,NOMI,NZI
      DOUBLE PRECISION TAUD,HID
*
      DO I=2,N-1
         NOMI=NOM(I)
         NZI=NZON(NOMI)
         HID=H(I)
         TAUD=HID*XST(NZI)
         B(I)=2.D0*HID/(2.D0+TAUD)
      ENDDO
*
      RETURN
      END

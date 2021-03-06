!======================================================================!
  REAL FUNCTION UserWRms(y)
!----------------------------------------------------------------------!
!   Prescribes mean normal velocity fluctuations for the channel.      !
!----------------------------------------------------------------------!
  IMPLICIT NONE
!-----------------------------[Parameters]-----------------------------!
  REAL :: y
!--------------------------------[CVS]---------------------------------!
!  $Id: UserWRms.f90,v 1.4 2002/10/30 16:30:03 niceno Exp $  
!  $Source: /home/muhamed/.CVSROOT/T-Rex/User/UserWRms.f90,v $  
!======================================================================!
!   Wall is at y=0, and centerline at y=1                              !
!----------------------------------------------------------------------!

  UserWRms =                                                        &
   -1.030111e+003  * y**9  +  4.912363e+003  * y**8                 &
   -9.890964e+003  * y**7  +  1.092610e+004  * y**6                 &
   -7.188233e+003  * y**5  +  2.842998e+003  * y**4                 &
   -6.326466e+002  * y**3  +  5.750007e+001  * y**2                 &
   +3.613158e+000  * y**1  -  1.078184e-002

  END FUNCTION UserWRms

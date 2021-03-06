!=====================================================================!
  SUBROUTINE CalcStresses(var, PHI,             &
		      dPHIdx, dPHIdy, dPHIdz)
!----------------------------------------------------------------------!
! Discretizes and solves momentum transport equations for k, eps etc.. !
! It was derived from NewUVW and not from CalcSc which might look
! reasonable, but in fact, in two-material cases
!----------------------------------------------------------------------!
!------------------------------[Modules]-------------------------------!
  USE all_mod
  USE pro_mod
  USE les_mod
  USE rans_mod
  USE par_mod
!----------------------------------------------------------------------!
  IMPLICIT NONE
!-----------------------------[Parameters]-----------------------------!
  INTEGER       :: var
  TYPE(Unknown) :: PHI
  REAL          :: dPHIdx(-NbC:NC), dPHIdy(-NbC:NC), dPHIdz(-NbC:NC)
!-------------------------------[Locals]-------------------------------!
  INTEGER :: s, c, c1, c2, niter, miter, mat
  REAL    :: Fex, Fim, TDiffS, VIStur 
  REAL    :: PHIs
  REAL    :: A0, A12, A21
  REAL    :: error
  REAL    :: VISeff
  REAL    :: dPHIdxS, dPHIdyS, dPHIdzS
  REAL    :: VIStS, TDiff_im, TDiff_ex, TDiff_coef, TDiffx, TDiffy,TDiffz
  REAL    :: uuS, vvS, wwS, uvS, uwS, vwS
!--------------------------------[CVS]---------------------------------!
!  $Id: CalcTurb.f90,v 1.18 2009/06/30 11:55:35 IUS\mhadziabdic Exp $  
!  $Source: /home/IUS/mhadziabdic/.CVSROOT/T-Rex/Process/CalcTurb.f90,v $    
!----------------------------------------------------------------------!
!                                                                      ! 
!  The form of equations which are solved:                             !   
!                                                                      !
!     /               /                /                     /         !
!    |     dPHI      |                | mu_eff              |          !
!    | rho ---- dV + | rho u PHI dS = | ------ DIV PHI dS + | G dV     !
!    |      dt       |                |  sigma              |          !
!   /               /                /                     /           !
!                                                                      !
!======================================================================!


  Aval = 0.0

  b=0.0

!----- This is important for "copy" boundary conditions. Find out why !
  do c=-NbC,-1
    Abou(c)=0.0
  end do

!-----------------------------------------! 
!     Initialize variables and fluxes     !
!-----------------------------------------! 

!----- old values (o and oo)
  if(ini == 1) then
    do c=1,NC
      PHI % oo(c)  = PHI % o(c)
      PHI % o (c)  = PHI % n(c)
      PHI % Coo(c) = PHI % Co(c)
      PHI % Co (c) = 0.0 
      PHI % Doo(c) = PHI % Do(c)
      PHI % Do (c) = 0.0 
      PHI % Xoo(c) = PHI % Xo(c)
      PHI % Xo (c) = PHI % X(c) 
    end do
  end if

!====================!
!                    !
!     Convection     !
!                    !
!====================!

!----- Compute PHImax and PHImin
  do mat=1,Nmat
    if(BLEND_TUR(mat) /= NO) then
      call CalMinMax(PHI % n)  ! or PHI % o ???
      goto 1
    end if
  end do

!----- new values
1 do c=1,NC
    PHI % C(c)    = 0.0
    PHI % X(c)    = 0.0
  end do


!--------------------------------!
!     Spatial Discretization     !
!--------------------------------!

  do s=1,NS

    c1=SideC(1,s)
    c2=SideC(2,s) 

!----- velocities on "orthogonal" cell centers 
    if(c2  > 0 .or. c2  < 0.and.TypeBC(c2) == BUFFER) then
      PHIs=f(s)*PHI % n(c1) + (1.0-f(s))*PHI % n(c2)

    if(BLEND_TUR(material(c1)) /= NO .or. BLEND_TUR(material(c2)) /= NO) then
      call ConvScheme(PHIs, s, PHI % n, dPHIdx, dPHIdy, dPHIdz, Dx, Dy, Dz, &
                      max(BLEND_TUR(material(c1)),BLEND_TUR(material(c2))) ) 
    end if 

!---- Central differencing for convection 
      if(ini == 1) then 
	if(c2  > 0) then
	  PHI % Co(c1)=PHI % Co(c1)-Flux(s)*PHIs
	  PHI % Co(c2)=PHI % Co(c2)+Flux(s)*PHIs
	else
	  PHI % Co(c1)=PHI % Co(c1)-Flux(s)*PHIs
	endif 
      end if
      if(c2  > 0) then
	PHI % C(c1)=PHI % C(c1)-Flux(s)*PHIs
	PHI % C(c2)=PHI % C(c2)+Flux(s)*PHIs
      else
	PHI % C(c1)=PHI % C(c1)-Flux(s)*PHIs
      endif 

!---- Upwind 
      if(BLEND_TUR(material(c1)) /= NO .or. BLEND_TUR(material(c2)) /= NO) then
	if(Flux(s)  < 0) then   ! from c2 to c1
	  PHI % X(c1)=PHI % X(c1)-Flux(s)*PHI % n(c2)
	  if(c2  > 0) then
	    PHI % X(c2)=PHI % X(c2)+Flux(s)*PHI % n(c2)
	  endif
	else 
	  PHI % X(c1)=PHI % X(c1)-Flux(s)*PHI % n(c1)
	  if(c2  > 0) then
	    PHI % X(c2)=PHI % X(c2)+Flux(s)*PHI % n(c1)
	  endif
	end if
      end if   ! BLEND_TUR 
    else       ! c2 < 0
!=================================================
!   I excluded this for the inflow-outflow 
!-------------------------------------------------
!   CUi(c1) = CUi(c1)-Flux(s)*PHI(c2) corrected !
!---- Full upwind
!      if(TypeBC(c2) == OUTFLOW) then
!	if(BLEND_TUR == YES) then
!	  if(Flux(s)  < 0) then   ! from c2 to c1
!	    XUi(c1)=XUi(c1)-Flux(s)*PHI(c2)
!	  else 
!	    XUi(c1)=XUi(c1)-Flux(s)*PHI(c1)
!	  end if 
!	end if ! BLEND_TUR = YES
!      end if   ! OUTFLOW
!=================================================
    end if     ! c2 > 0 
  end do    ! through sides

!---------------------------------!
!     Temporal discretization     !
!---------------------------------!

!----- Adams-Bashforth scheeme for convective fluxes
  if(CONVEC == AB) then
    do c=1,NC
      b(c) = b(c) + URFC_Tur(material(c)) * &
                    (1.5*PHI % Co(c) - 0.5*PHI % Coo(c) - PHI % X(c))
    end do  
  endif

!----- Crank-Nicholson scheeme for convective fluxes
  if(CONVEC == CN) then
    do c=1,NC
      b(c) = b(c) + URFC_Tur(material(c)) * &
                    (0.5 * ( PHI % C(c) + PHI % Co(c) ) - PHI % X(c))
    end do  
  endif

!----- Fully implicit treatment of convective fluxes 
  if(CONVEC == FI) then
    do c=1,NC
      b(c) = b(c) + URFC_Tur(material(c)) * &
                    (PHI % C(c) - PHI % X(c))
    end do  
  end if     
	    
!----------------------------------------------------!
!     Browse through all the faces, where else ?     !
!----------------------------------------------------!

!----- new values
  do c=1,NC
    PHI % X(c) = 0.0
  end do
  
!========================================!
!                                        !  
!     Source terms and wall function     !
!     (Check if it is good to call it    !
!      before the under relaxation ?)    !
!                                        !
!========================================!


!==================!
!                  !
!     Difusion     !
!                  !
!==================!

!--------------------------------!
!     Spatial Discretization     !
!--------------------------------!
  do s=1,NS       

    c1=SideC(1,s)
    c2=SideC(2,s)   

!--- VIStur is used to make diaginal element more dominant.
!--- This contribution is later substracted.
!---------------------------------------------------------  

    VIStS = fF(s)*VISt(c1) + (1.0-fF(s))*VISt(c2)
    VISeff = VISc + VIStS

    dPHIdxS = fF(s)*dPHIdx(c1) + (1.0-fF(s))*dPHIdx(c2)
    dPHIdyS = fF(s)*dPHIdy(c1) + (1.0-fF(s))*dPHIdy(c2)
    dPHIdzS = fF(s)*dPHIdz(c1) + (1.0-fF(s))*dPHIdz(c2)


!---- Total (exact) diffusive flux plus turb. diffusion
    Fex=VISeff*(dPHIdxS*Sx(s) + dPHIdyS*Sy(s) + dPHIdzS*Sz(s)) 

    A0 = VISeff * Scoef(s) 

!---- implicit diffusive flux
!.... this is a very crude approximation: Scoef is not
!.... corrected at interface between materials
    Fim=( dPHIdxS*Dx(s)                      &
	 +dPHIdyS*Dy(s)                      &
	 +dPHIdzS*Dz(s))*A0

!---- this is yet another crude approximation:
!.... A0 is calculated approximatelly
!    if( StateMat(material(c1))==FLUID .and.  &  ! 2mat
!        StateMat(material(c2))==SOLID        &  ! 2mat
!        .or.                                 &  ! 2mat 
!        StateMat(material(c1))==SOLID .and.  &  ! 2mat
!        StateMat(material(c2))==FLUID ) then    ! 2mat
!      A0 = A0 + A0                              ! 2mat
!    end if                                      ! 2mat

!---- straight diffusion part 
    if(ini == 1) then
      if(c2  > 0) then
	PHI % Do(c1) = PHI % Do(c1) + (PHI % n(c2)-PHI % n(c1))*A0   
	PHI % Do(c2) = PHI % Do(c2) - (PHI % n(c2)-PHI % n(c1))*A0    
      else
	if(TypeBC(c2) /= SYMMETRY) then
	  PHI % Do(c1) = PHI % Do(c1) + (PHI % n(c2)-PHI % n(c1))*A0   
	end if 
      end if 
    end if

!---- cross diffusion part
    PHI % X(c1) = PHI % X(c1) + Fex - Fim 
    if(c2  > 0) then
      PHI % X(c2) = PHI % X(c2) - Fex + Fim 
    end if 

!----- calculate the coefficients for the sysytem matrix
    if( (DIFFUS == CN) .or. (DIFFUS == FI) ) then  

      if(DIFFUS  ==  CN) then       ! Crank Nicholson
	A12 = 0.5 * A0 
	A21 = 0.5 * A0 
      end if

      if(DIFFUS  ==  FI) then       ! Fully implicit
	A12 = A0 
	A21 = A0 
      end if

      if(BLEND_TUR(material(c1)) /= NO .or. BLEND_TUR(material(c2)) /= NO) then
	A12 = A12  - min(Flux(s), real(0.0)) 
	A21 = A21  + max(Flux(s), real(0.0))
      endif

!----- fill the system matrix
      if(c2  > 0) then
	Aval(SidAij(1,s)) = Aval(SidAij(1,s)) - A12
	Aval(Adia(c1))    = Aval(Adia(c1))    + A12
	Aval(SidAij(2,s)) = Aval(SidAij(2,s)) - A21
	Aval(Adia(c2))    = Aval(Adia(c2))    + A21
      else if(c2  < 0) then
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -!
! Outflow is not included because it was causing problems     !
! Convect is commented because for turbulent scalars convect 
! outflow is treated as classic outflow.
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -! 
	if((TypeBC(c2) == INFLOW).or.                     &
           (TypeBC(c2) == WALL).or.                       &
!!!           (TypeBC(c2) == CONVECT).or.                    &
	   (TypeBC(c2) == WALLFL) ) then                                
	  Aval(Adia(c1)) = Aval(Adia(c1)) + A12
	  b(c1) = b(c1) + A12 * PHI % n(c2)
	else if( TypeBC(c2) == BUFFER ) then  
	  Aval(Adia(c1)) = Aval(Adia(c1)) + A12
	  Abou(c2) = - A12  ! cool parallel stuff
	endif
      end if     

    end if

  end do  ! through sides

  if(MODE/=HYB) then
!
! Turbulent diffusion term
!
    if(var==13) then
      CmuD = 0.18        
    else
      CmuD = 0.22
    end if         
    do c=1,NC
      VAR1x(c) = CmuD/PHI % Sigma*Tsc(c)*&
                 (uu%n(c)*dPHIdx(c)+uv%n(c)*dPHIdy(c)+uw%n(c)*dPHIdz(c))!-VISt(c)*dPHIdx(c)

      VAR1y(c) = CmuD/PHI % Sigma*Tsc(c)*&
                 (uv%n(c)*dPHIdx(c)+vv%n(c)*dPHIdy(c)+vw%n(c)*dPHIdz(c))!-VISt(c)*dPHIdy(c)

      VAR1z(c) = CmuD/PHI % Sigma*Tsc(c)*&
                 (uw%n(c)*dPHIdx(c)+vw%n(c)*dPHIdy(c)+ww%n(c)*dPHIdz(c))!-VISt(c)*dPHIdz(c)
    end do

    call GraPhi(VAR1x,1,VAR2x,.TRUE.)
    call GraPhi(VAR1y,2,VAR2y,.TRUE.)
    call GraPhi(VAR1z,3,VAR2z,.TRUE.)

    do c=1,NC
      b(c) = b(c) + (VAR2x(c)+VAR2y(c)+VAR2z(c))*volume(c)
    end do

!
! Here we clean up transport equation from the false diffusion
!
    do s=1,NS

      c1=SideC(1,s)
      c2=SideC(2,s)

      VISeff = (fF(s)*VISt(c1)+(1.0-fF(s))*VISt(c2))

      dPHIdxS = fF(s)*dPHIdx(c1) + (1.0-fF(s))*dPHIdx(c2)
      dPHIdyS = fF(s)*dPHIdy(c1) + (1.0-fF(s))*dPHIdy(c2)
      dPHIdzS = fF(s)*dPHIdz(c1) + (1.0-fF(s))*dPHIdz(c2)
      Fex=VISeff*(dPHIdxS*Sx(s) + dPHIdyS*Sy(s) + dPHIdzS*Sz(s))
      A0 = VISeff * Scoef(s)
      Fim=( dPHIdxS*Dx(s)                      &
         +dPHIdyS*Dy(s)                      &
         +dPHIdzS*Dz(s))*A0

      b(c1) = b(c1) - VISeff*(PHI%n(c2)-PHI%n(c1))*Scoef(s)- Fex + Fim
      if(c2  > 0) then
        b(c2) = b(c2) + VISeff*(PHI%n(c2)-PHI%n(c1))*Scoef(s)+ Fex - Fim
      end if
    end do
  end if
!---------------------------------!
!     Temporal discretization     !
!---------------------------------!

!----- Adams-Bashfort scheeme for diffusion fluxes
  if(DIFFUS == AB) then 
    do c=1,NC
      b(c) = b(c) + 1.5 * PHI % Do(c) - 0.5 * PHI % Doo(c)
    end do  
  end if

!----- Crank-Nicholson scheme for difusive terms
  if(DIFFUS == CN) then 
    do c=1,NC
      b(c) = b(c) + 0.5 * PHI % Do(c)
    end do  
  end if
		 
!----- Fully implicit treatment for difusive terms
!      is handled via the linear system of equations 

!----- Adams-Bashfort scheeme for cross diffusion 
  if(CROSS == AB) then
    do c=1,NC
      b(c) = b(c) + 1.5 * PHI % Xo(c) - 0.5 * PHI % Xoo(c)
    end do 
  end if
    
!----- Crank-Nicholson scheme for cross difusive terms
  if(CROSS == CN) then
    do c=1,NC
      b(c) = b(c) + 0.5 * PHI % X(c) + 0.5 * PHI % Xo(c)
    end do 
  end if

!----- Fully implicit treatment for cross difusive terms
  if(CROSS == FI) then
    do c=1,NC
      b(c) = b(c) + PHI % X(c) 
    end do 
  end if

!========================!
!                        !
!     Inertial terms     !
!                        !
!========================!

!----- Two time levels; Linear interpolation
  if(INERT == LIN) then
    do c=1,NC
      A0 = DENc(material(c))*volume(c)/dt
      Aval(Adia(c)) = Aval(Adia(c)) + A0
      b(c) = b(c) + A0 * PHI % o(c)
    end do
  end if

!----- Three time levels; parabolic interpolation
  if(INERT == PAR) then
    do c=1,NC
      A0 = DENc(material(c))*volume(c)/dt
      Aval(Adia(c)) = Aval(Adia(c)) + 1.5 * A0
      b(c) = b(c) + 2.0*A0 * PHI % o(c) - 0.5*A0 * PHI % oo(c)
    end do
  end if

!  do c=1,NC                                         ! 2mat
!    if(StateMat(material(c))==SOLID) then           ! 2mat
!      b(c)          = 0.0                           ! 2mat
!    end if                                          ! 2mat
!  end do                                            ! 2mat

!---- Disconnect the SOLID cells from FLUID system  ! 2mat
!  do s=1,NS                                         ! 2mat
!    c1=SideC(1,s)                                   ! 2mat
!    c2=SideC(2,s)                                   ! 2mat
!    if(c2>0 .or. c2<0.and.TypeBC(c2)==BUFFER) then  ! 2mat
!      if(c2 > 0) then ! => not buffer               ! 2mat
!        if(StateMat(material(c1)) == SOLID) then    ! 2mat
!          Aval(SidAij(1,s)) = 0.0                   ! 2mat 
!          Aval(SidAij(2,s)) = 0.0                   ! 2mat
!        end if                                      ! 2mat 
!        if(StateMat(material(c2)) == SOLID) then    ! 2mat
!          Aval(SidAij(2,s)) = 0.0                   ! 2mat
!          Aval(SidAij(1,s)) = 0.0                   ! 2mat 
!        end if                                      ! 2mat 
!      else            ! => buffer region            ! 2mat 
!        if(StateMat(material(c1)) == SOLID .or.  &  ! 2mat
!           StateMat(material(c2)) == SOLID) then    ! 2mat
!          Abou(c2) = 0.0                            ! 2mat
!        end if                                      ! 2mat 
!      end if                                        ! 2mat
!    end if                                          ! 2mat
!  end do                                            ! 2mat

   if(SIMULA==EBM) then 
     call SourcesEBM(var)
!   else
!     call SourcesHJ(var)        
   end if                
!=====================================!
!                                     !
!     Solve the equations for PHI     !
!                                     !    
!=====================================!
  do c=1,NC
    b(c) = b(c) + Aval(Adia(c)) * (1.0-PHI % URF)*PHI % n(c) / PHI % URF
    Aval(Adia(c)) = Aval(Adia(c)) / PHI % URF
!?????? Asave(c) = Aval(Adia(c)) ??????
  end do

  if(ALGOR == SIMPLE)   miter=30
  if(ALGOR == FRACT)    miter=5

  niter=miter
  call bicg(NC, Nbc, NONZERO, Aval,Acol,Arow,Adia,Abou,   &
	   PHI % n, b, PREC,                             &
	   niter,PHI % STol, res(var), error)

!k-eps  if(var == 1) then
!k-eps    write(LineRes(17:28), '(1PE12.3)') res(var) 
!k-eps    write(LineRes(77:80), '(I4)')      niter 
!k-eps  end if


  if (var .eq. 13) then
    if(this < 2) write(*,*) 'Eps ', var, res(var), niter 
  elseif(var .eq. 11) then
    if(this < 2) write(*,*) 'vw  ', var, res(var), niter 
  elseif(var .eq. 10) then
    if(this < 2) write(*,*) 'uw  ', var, res(var), niter 
  elseif(var .eq.  9) then
    if(this < 2) write(*,*) 'uv  ', var, res(var), niter 
  elseif(var .eq.  8) then
    if(this < 2) write(*,*) 'ww  ', var, res(var), niter 
  elseif(var .eq.  7) then
    if(this < 2) write(*,*) 'vv  ', var, res(var), niter 
  elseif(var .eq.  6) then
    if(this < 2) write(*,*) 'uu  ', var, res(var), niter 
  end if

!  if(var == 13) then
!    do c= 1, NC
!     if( PHI%n(c)<0.0)then
!       PHI%n(c) = PHI%o(c)
!       write(*,*)'Eps negativan', PHI%n(c)
!     end if
!    end do
!  end if

  if(var == 6.or.var == 7.or.var == 8) then
    do c= 1, NC
     if(PHI%n(c)<0.0)then
       PHI%n(c) = PHI%o(c)
     end if
    end do
  end if

  call Exchng(PHI % n)

  RETURN

  END SUBROUTINE CalcStresses

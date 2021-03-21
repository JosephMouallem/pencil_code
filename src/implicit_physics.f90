! $Id$
!
! This module solves the radiative diffusion implicitly thanks
! to an Alternate Direction Implicit Scheme (ADI) in a D'Yakonov
! form
!     lambda_x T(n+1/2) = lambda_x + lambda_z
!     lambda_z T(n+1) = T(n+1/2)
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lADI = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 1
! COMMUNICATED AUXILIARIES 1
!
!***************************************************************
module ImplicitPhysics
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages, only: svn_id, fatal_error, warning
  use General, only: tridag, cyclic
!
  implicit none
!
  include 'implicit_physics.h'
!
  interface heatcond_TT ! Overload subroutine `hcond_TT' function
    module procedure heatcond_TT_0d  ! get one value (hcond, dhcond)
    module procedure heatcond_TT_1d  ! get 1d-arrays (hcond, dhcond)
    module procedure heatcond_TT_2d  ! get 2d-arrays (hcond, dhcond)
  end interface
!
  real, pointer :: hcond0, Fbot, hcond1, hcond2, widthlnTT
  logical, pointer :: lADI_mixed, lmultilayer
  real :: Tbump, Kmax, Kmin, hole_slope, hole_width, hole_alpha
  real :: dx_2, dy_2, dz_2, cp1
  logical :: lyakonov=.true.
!
  real, dimension(mz) :: hcondz, dhcondz
!
  contains
!***********************************************************************
    subroutine register_implicit_physics()
!
!  Initialise variables which should know that we solve the
!  compressible hydro equations: ilnrho; increase nvar accordingly.
!
!  03-mar-2010/dintrans: coded
!
      use FArrayManager, only: farray_register_auxiliary
!
      call farray_register_auxiliary('TTold',iTTold,communicated=.true.)
      print*, 'iTTold=', iTTold
!
!  Identify version number (generated automatically by SVN).
!
      if (lroot) call svn_id( &
       "$Id$")
!
    endsubroutine register_implicit_physics
!***********************************************************************
    subroutine initialize_implicit_physics(f)
!
      use SharedVariables, only: get_shared_variable
      use MpiComm, only: stop_it
      use EquationOfState, only: get_cp1
      use Gravity, only: z1, z2
      use Sub, only: step,der_step,write_zprof
!
      implicit none
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(:), pointer :: hole_params
      real, dimension(mz) :: profz
!
      call get_shared_variable('hcond0', hcond0, caller='initialize_implicit_physics')
      call get_shared_variable('hcond1', hcond1)
      call get_shared_variable('hcond2', hcond2)
      call get_shared_variable('widthlnTT', widthlnTT)
      call get_shared_variable('lmultilayer', lmultilayer)
      print*,'***********************************'
      print*, hcond0, hcond1, hcond2, widthlnTT, lmultilayer
      print*,'***********************************'
      call get_shared_variable('Fbot', Fbot)
      call get_shared_variable('lADI_mixed', lADI_mixed)
      call get_shared_variable('hole_params', hole_params)
      Tbump=hole_params(1)
      Kmin=hole_params(2)
      Kmax=hole_params(3)
      hole_slope=hole_params(4)
      hole_width=hole_params(5)
      hole_alpha=(Kmax-Kmin)/(pi/2.+atan(hole_slope*hole_width**2))
      if (lroot .and. ldebug) then
        print*, '************ hole parameters ************'
        print*,'Tbump, Kmax, Kmin, hole_slope, hole_width, hole_alpha=', &
               Tbump, Kmax, Kmin, hole_slope, hole_width, hole_alpha
        print*, '*****************************************'
      endif
!
      if (lrun) then
! hcondADI is dynamically shared with boundcond() for the 'c3' BC
        call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
      else
        hcondADI=spread(Kmax, 1, mx)
      endif
!
! variables that are needed everywhere in this module
!
      call get_cp1(cp1)
      if (dx>0.) then
         dx_2 = 1.0 / dx**2
      else
         dx_2 = 0.0
      endif
      if (dy>0.) then
         dy_2 = 1.0 / dy**2
      else
         dy_2 = 0.0
      endif
      if (dz>0.) then
         dz_2 = 1.0 / dz**2
      else
         dz_2 = 0.0
      endif
!
      if (lrun) then
        if (lmultilayer) then
          profz = 1. + (hcond1-1.)*step(z,z1,-widthlnTT) &
                   + (hcond2-1.)*step(z,z2,widthlnTT)
          hcondz = hcond0*profz
          dhcondz = (hcond1-1.)*der_step(z,z1,-widthlnTT) &
                   + (hcond2-1.)*der_step(z,z2,widthlnTT)
          dhcondz = hcond0*dhcondz
        else
          hcondz=hcond0
          dhcondz=0.0
        endif
        call write_zprof('hcond',hcondz)
        call write_zprof('dhcond',dhcondz)
      endif
!
    endsubroutine initialize_implicit_physics
!***********************************************************************
    subroutine calc_heatcond_ADI(f)
!
!  10-sep-07/gastine+dintrans: wrapper to the two possible ADI subroutines
!  ADI_Kconst: constant radiative conductivity
!  ADI_Kprof: radiative conductivity depends on T, i.e. hcond(T)
!  02/05/14-dintrans: added the polytropic superposed layers (MPI or not)
!
      implicit none
!
      real, dimension(mx,my,mz,mfarray) :: f
!
      if (hcond0 /= impossible) then
!
! polytropic setup (single layer or superposed layers)
!
        if (nx == 1) then
           if (lmultilayer) then
             call crank_Kprof(f)
           else
             call crank_Kconst(f)
           endif
        else
          if (nprocz>1) then
             if (lmultilayer) then
               call ADI_poly_MPI(f)
             else
               call ADI_Kconst_MPI(f)
             endif
          else
            if (lyakonov) then
               if (lmultilayer) then
                  call ADI_poly(f)
               else
                  call ADI_Kconst_yakonov(f)
               endif
            else
              call ADI_Kconst(f)
            endif
          endif
        endif
      else
!
! kappa-mechanism with a conductivity hollow
!
        if (nx == 1) then
          if (lADI_mixed) then
            call ADI_Kprof_1d_mixed(f)
          else
            call ADI_Kprof_1d(f)
          endif
        else
          if (nprocz>1) then
            call ADI_Kprof_MPI(f)
          else
            if (lADI_mixed) then
              call ADI_Kprof_mixed(f)
            else
              call ADI_Kprof(f)
            endif
          endif
        endif
      endif
!
    endsubroutine calc_heatcond_ADI
!***********************************************************************
    subroutine ADI_Kconst(f)
!
!  08-Sep-07/gastine+dintrans: coded
!  2-D ADI scheme for the radiative diffusion term (see
!  Peaceman & Rachford 1955). Each direction is solved implicitly:
!
!    (1-dt/2*Lambda_x)*T^(n+1/2) = (1+dt/2*Lambda_y)*T^n + source/2
!    (1-dt/2*Lambda_y)*T^(n+1)   = (1+dt/2*Lambda_x)*T^(n+1/2) + source/2
!
!  where Lambda_x and Lambda_y denote diffusion operators and the source
!  term comes from the explicit advance.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz) :: finter, source, rho, TT
      real, dimension(nx)    :: ax, bx, cx, wx, rhsx, workx
      real, dimension(nz)    :: az, bz, cz, wz, rhsz, workz
      real    :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
!  first update all the ghost zones in the f-array
!
      call update_ghosts(f)
!
      TT=f(:,4,:,iTTold)
      source=(f(:,4,:,ilnTT)-TT)/dt
      if (ldensity) then
        rho=exp(f(:,4,:,ilnrho))
      else
        rho=1.
      endif
!
!  row dealt implicitly
!
      do j=n1,n2
        wx=dt*gamma*hcond0*cp1/rho(l1:l2,j)
        ax=-wx*dx_2/2.
        bx=1.+wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,j)+wx*dz_2/2.*                         &
             (TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))    &
             +dt/2.*source(l1:l2,j)
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax, bx, cx, aalpha, bbeta, rhsx, workx, nx)
        finter(l1:l2,j)=workx
      enddo
!
! finter must be periodic in the x-direction
!
      finter(1:l1-1,:)=finter(l2i:l2,:)
      finter(l2+1:mx,:)=finter(l1:l1i,:)
!
!  columns dealt implicitly
!
      do i=l1,l2
        wz=dt*gamma*hcond0*cp1/rho(i,n1:n2)
        az=-wz*dz_2/2.
        bz=1.+wz*dz_2
        cz=az
        rhsz=finter(i,n1:n2)+wz*dx_2/2.*                               &
             (finter(i+1,n1:n2)-2.*finter(i,n1:n2)+finter(i-1,n1:n2))  &
             +dt/2.*source(i,n1:n2)
        !
        ! z boundary conditions
        ! Always constant temperature at the top
        !
        bz(nz)=1. ; az(nz)=0.
        rhsz(nz)=cs2top/gamma_m1
        select case (bcz12(ilnTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1.  ; cz(1)=0.
            rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom
          case ('c1')
            bz(1)=1.   ; cz(1)=-1
            rhsz(1)=dz*Fbot/hcond0
! we can use here the second-order relation for the first derivative:
! (T_{j+1}-T_{j_1})/2dz = dT/dz --> T_{j-1} = T_{j+1} - 2*dz*dT/dz
! and insert this expression in the difference relation to eliminate T_{j-1}:
! a_{j-1}*T_{j-1} + b_j T_j + c_{j+1}*T_{j+1} = RHS
!           cz(1)=cz(1)+az(1)
!           rhsz(1)=rhsz(1)-2.*az(1)*dz*Fbot/hcond0
          case default
           call fatal_error('ADI_Kconst','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az, bz, cz, rhsz, workz, err, msg)
        if (err) call warning('ADI_Kconst', trim(msg))
        f(i,4,n1:n2,ilnTT)=workz
      enddo
!
    endsubroutine ADI_Kconst
!***********************************************************************
    subroutine ADI_Kprof(f)
!
!  10-Sep-07/gastine+dintrans: coded
!  2-D ADI scheme for the radiative diffusion term where the radiative
!  conductivity depends on T (uses heatcond_TT to compute hcond _and_
!  dhcond). The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*J_x)*lambda = f_x(T^n) + f_y(T^n) + source
!    (1-dt/2*J_y)*beta   = lambda
!    T^(n+1) = T^n + dt*beta
!
!    where J_x and J_y denote Jacobian matrices df/dT.
!
      use EquationOfState, only: gamma
!
      implicit none
!
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz) :: source, hcond, dhcond, finter, val, TT, rho
      real, dimension(nx)    :: ax, bx, cx, wx, rhsx, workx
      real, dimension(nz)    :: az, bz, cz, wz, rhsz, workz
      real    :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      source=(f(:,4,:,ilnTT)-f(:,4,:,iTTold))/dt
! BC important not for the x-direction (always periodic) but for
! the z-direction as we must impose the 'c3' BC at the 2nd-order
! before going in the implicit stuff
      call heatcond_TT(f(:,4,:,iTTold), hcond, dhcond)
      call boundary_ADI(f(:,4,:,iTTold), hcond(:,n1))
      TT=f(:,4,:,iTTold)
      if (ldensity) then
        rho=exp(f(:,4,:,ilnrho))
      else
        rho=1.
      endif
!
!  rows dealt implicitly
!
      do j=n1,n2
       wx=cp1*gamma/rho(l1:l2,j)
! ax=-dt/2*J_x for i=i-1 (lower diagonal)
       ax=-dt*wx*dx_2/4.*(dhcond(l1-1:l2-1,j)    &
         *(TT(l1-1:l2-1,j)-TT(l1:l2,j))          &
         +hcond(l1-1:l2-1,j)+hcond(l1:l2,j))
! bx=1-dt/2*J_x for i=i (main diagonal)
       bx=1.+dt*wx*dx_2/4.*(dhcond(l1:l2,j)      &
         *(2.*TT(l1:l2,j)-TT(l1-1:l2-1,j)        &
         -TT(l1+1:l2+1,j))+2.*hcond(l1:l2,j)     &
         +hcond(l1+1:l2+1,j)+hcond(l1-1:l2-1,j))
! cx=-dt/2*J_x for i=i+1 (upper diagonal)
       cx=-dt*wx*dx_2/4.*(dhcond(l1+1:l2+1,j)    &
          *(TT(l1+1:l2+1,j)-TT(l1:l2,j))         &
          +hcond(l1:l2,j)+hcond(l1+1:l2+1,j))
! rhsx=f_y(T^n) + f_x(T^n) (Eq. 3.6)
! do first f_y(T^n)
       rhsx=wx*dz_2/2.*((hcond(l1:l2,j+1)        &
           +hcond(l1:l2,j))*(TT(l1:l2,j+1)       &
           -TT(l1:l2,j))-(hcond(l1:l2,j)         &
           +hcond(l1:l2,j-1))                    &
           *(TT(l1:l2,j)-TT(l1:l2,j-1)))
! then add f_x(T^n)
       rhsx=rhsx+wx*dx_2/2.*((hcond(l1+1:l2+1,j)         &
         +hcond(l1:l2,j))*(TT(l1+1:l2+1,j)-TT(l1:l2,j))  &
           -(hcond(l1:l2,j)+hcond(l1-1:l2-1,j))          &
           *(TT(l1:l2,j)-TT(l1-1:l2-1,j)))+source(l1:l2,j)
!
! x boundary conditions: periodic
       aalpha=cx(nx) ; bbeta=ax(1)
       call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,workx,nx)
       finter(l1:l2,j)=workx(1:nx)
      enddo
!
!  columns dealt implicitly
!
      do i=l1,l2
       wz=dt*cp1*gamma*dz_2/rho(i,n1:n2)
       az=-wz/4.*(dhcond(i,n1-1:n2-1)   &
         *(TT(i,n1-1:n2-1)-TT(i,n1:n2)) &
         +hcond(i,n1-1:n2-1)+hcond(i,n1:n2))
!
       bz=1.+wz/4.*(dhcond(i,n1:n2)*             &
         (2.*TT(i,n1:n2)-TT(i,n1-1:n2-1)         &
         -TT(i,n1+1:n2+1))+2.*hcond(i,n1:n2)     &
         +hcond(i,n1+1:n2+1)+hcond(i,n1-1:n2-1))
!
       cz=-wz/4.*(dhcond(i,n1+1:n2+1)            &
         *(TT(i,n1+1:n2+1)-TT(i,n1:n2))          &
         +hcond(i,n1:n2)+hcond(i,n1+1:n2+1))
!
       rhsz=finter(i,n1:n2)
!
! z boundary conditions
! Constant temperature at the top: T^(n+1)-T^n=0
       bz(nz)=1. ; az(nz)=0.
       rhsz(nz)=0.
! bottom
       select case (bcz12(ilnTT,1))
! Constant temperature at the bottom: T^(n+1)-T^n=0
         case ('cT')
          bz(1)=1. ; cz(1)=0.
          rhsz(1)=0.
! Constant flux at the bottom
         case ('c3')
          bz(1)=1. ; cz(1)=-1.
          rhsz(1)=0.
         case default
          call fatal_error('ADI_Kprof','bcz on TT must be cT or c3')
       endselect
!
       call tridag(az,bz,cz,rhsz,workz,err,msg)
       if (err) call warning('ADI_Kprof', trim(msg))
       val(i,n1:n2)=workz(1:nz)
      enddo
!
      f(:,4,:,ilnTT)=f(:,4,:,iTTold)+dt*val
!
! update hcond used for the 'c3' condition in boundcond.f90
!
      call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
!
    endsubroutine ADI_Kprof
!***********************************************************************
    subroutine ADI_Kprof_MPI(f)
!
!  15-jan-10/gastine: coded
!  2-D ADI scheme for the radiative diffusion term where the radiative
!  conductivity depends on T (uses heatcond_TT to compute hcond _and_
!  dhcond). The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*J_x)*lambda = f_x(T^n) + f_z(T^n) + source
!    (1-dt/2*J_z)*beta   = lambda
!    T^(n+1) = T^n + dt*beta
!
!    where J_x and J_z denote Jacobian matrices df/dT.
!  08-mar-2010/dintrans: added the case of a non-square domain (ibox-loop)
!  21-aug-2010/dintrans: simplified version that uses Anders' original
!    transp_xz and transp_zx subroutines
!
      use EquationOfState, only: gamma
      use Mpicomm, only: transp_xz, transp_zx
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer, parameter :: mzt=nzgrid+2*nghost
      integer, parameter :: n1t=nghost+1, n2t=n1t+nzgrid-1
      integer, parameter :: nxt=nx/nprocz
      integer :: i ,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz)   :: source, hcond, dhcond, finter, TT, rho
      real, dimension(mzt,nxt) :: hcondt, dhcondt, fintert, TTt, rhot, valt
      real, dimension(nx,nz)   :: val
      real, dimension(nx)      :: ax, bx, cx, wx, rhsx, workx
      real, dimension(nzgrid)  :: az, bz, cz, wz, rhsz, workz
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
!  It is necessary to communicate ghost-zones points between
!  processors to ensure a correct transposition of these ghost
!  zones. It is needed by rho,rhot and source,sourcet.
!
      call update_ghosts(f)
      source=(f(:,4,:,ilnTT)-f(:,4,:,iTTold))/dt
!
! BC important not for the x-direction (always periodic) but for
! the z-direction as we must impose the 'c3' BC at the 2nd-order
! before going in the implicit stuff
!
      TT=f(:,4,:,iTTold)
      call heatcond_TT(TT, hcond, dhcond)
      call boundary_ADI(TT, hcond(:,n1))
      if (ldensity) then
        rho=exp(f(:,4,:,ilnrho))
      else
        rho=1.
      endif
!
! rows dealt implicitly
!
      do j=n1,n2
        wx=cp1*gamma/rho(l1:l2,j)
! ax=-dt/2*J_x for i=i-1 (lower diagonal)
        ax=-dt*wx*dx_2/4.*(dhcond(l1-1:l2-1,j)     &
           *(TT(l1-1:l2-1,j)-TT(l1:l2,j))          &
           +hcond(l1-1:l2-1,j)+hcond(l1:l2,j))
! bx=1-dt/2*J_x for i=i (main diagonal)
        bx=1.+dt*wx*dx_2/4.*(dhcond(l1:l2,j)       &
           *(2.*TT(l1:l2,j)-TT(l1-1:l2-1,j)        &
           -TT(l1+1:l2+1,j))+2.*hcond(l1:l2,j)     &
           +hcond(l1+1:l2+1,j)+hcond(l1-1:l2-1,j))
! cx=-dt/2*J_x for i=i+1 (upper diagonal)
        cx=-dt*wx*dx_2/4.*(dhcond(l1+1:l2+1,j)     &
           *(TT(l1+1:l2+1,j)-TT(l1:l2,j))          &
           +hcond(l1:l2,j)+hcond(l1+1:l2+1,j))
! rhsx=f_z(T^n) + f_x(T^n) (Eq. 3.6)
! do first f_z(T^n)
        rhsx=wx*dz_2/2.*((hcond(l1:l2,j+1)         &
             +hcond(l1:l2,j))*(TT(l1:l2,j+1)       &
             -TT(l1:l2,j))-(hcond(l1:l2,j)         &
             +hcond(l1:l2,j-1))                    &
             *(TT(l1:l2,j)-TT(l1:l2,j-1)))
! then add f_x(T^n)
        rhsx=rhsx+wx*dx_2/2.*((hcond(l1+1:l2+1,j)            &
             +hcond(l1:l2,j))*(TT(l1+1:l2+1,j)-TT(l1:l2,j))  &
             -(hcond(l1:l2,j)+hcond(l1-1:l2-1,j))            &
             *(TT(l1:l2,j)-TT(l1-1:l2-1,j)))+source(l1:l2,j)
!
! periodic boundary conditions in the x-direction
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax, bx, cx, aalpha, bbeta, rhsx, workx, nx)
        finter(l1:l2,j)=workx(1:nx)
      enddo
!
! do the transpositions x <--> z
!
      call transp_xz(finter(l1:l2,n1:n2), fintert(n1t:n2t,:))
      call transp_xz(rho(l1:l2,n1:n2), rhot(n1t:n2t,:))
      call transp_xz(TT(l1:l2,n1:n2), TTt(n1t:n2t,:))
      call heatcond_TT(TTt, hcondt, dhcondt)
!
      do i=1,nxt
        wz=dt*cp1*gamma*dz_2/rhot(n1t:n2t,i)
        az=-wz/4.*(dhcondt(n1t-1:n2t-1,i)            &
           *(TTt(n1t-1:n2t-1,i)-TTt(n1t:n2t,i))      &
           +hcondt(n1t-1:n2t-1,i)+hcondt(n1t:n2t,i))
!
        bz=1.+wz/4.*(dhcondt(n1t:n2t,i)*                 &
           (2.*TTt(n1t:n2t,i)-TTt(n1t-1:n2t-1,i)         &
           -TTt(n1t+1:n2t+1,i))+2.*hcondt(n1t:n2t,i)     &
           +hcondt(n1t+1:n2t+1,i)+hcondt(n1t-1:n2t-1,i))
!
        cz=-wz/4.*(dhcondt(n1t+1:n2t+1,i)            &
           *(TTt(n1t+1:n2t+1,i)-TTt(n1t:n2t,i))      &
           +hcondt(n1t:n2t,i)+hcondt(n1t+1:n2t+1,i))
!
        rhsz=fintert(n1t:n2t,i)
!
! z boundary conditions
! Constant temperature at the top: T^(n+1)-T^n=0
!
        bz(nzgrid)=1. ; az(nzgrid)=0.
        rhsz(nzgrid)=0.
! bottom
        select case (bcz12(ilnTT,1))
! Constant temperature at the bottom: T^(n+1)-T^n=0
          case ('cT')
            bz(1)=1. ; cz(1)=0.
            rhsz(1)=0.
! Constant flux at the bottom
          case ('c3')
            bz(1)=1. ; cz(1)=-1.
            rhsz(1)=0.
          case default
            call fatal_error('ADI_Kprof','bcz on TT must be cT or c3')
        endselect
        call tridag(az, bz, cz, rhsz, workz, err, msg)
        if (err) call warning('ADI_Kprof', trim(msg))
        valt(n1t:n2t,i)=workz(1:nzgrid)
      enddo ! i
!
! come back on the grid (x,z)
!
      call transp_zx(valt(n1t:n2t,:), val)
      f(l1:l2,4,n1:n2,ilnTT)=f(l1:l2,4,n1:n2,iTTold)+dt*val
!
! update hcond used for the 'c3' condition in boundcond.f90
!
      if (iproc==0) call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
!
    endsubroutine ADI_Kprof_MPI
!***********************************************************************
    subroutine boundary_ADI(f_2d, hcond)
!
! 13-Sep-07/gastine: computed two different types of boundary
! conditions for the implicit solver:
!     - Always periodic in x-direction
!     - Possibility to choose between 'cT' and 'c3' in z direction
! Note: 'c3' means that the flux is constant at the *bottom only*
!
      implicit none
!
      real, dimension(mx,mz) :: f_2d
      real, dimension(mx), optional :: hcond
!
! x-direction: periodic
!
      f_2d(1:l1-1,:)=f_2d(l2i:l2,:)
      f_2d(l2+1:mx,:)=f_2d(l1:l1i,:)
!
! top boundary condition z=z(n2): always constant temperature
!
      if (llast_proc_z) then
        f_2d(:,n2+1)=2.*f_2d(:,n2)-f_2d(:,n2-1)
      endif
!
! bottom bondary condition z=z(n1): constant T or imposed flux dT/dz
!
      if (iproc==0) then
      select case (bcz12(ilnTT,1))
        case ('cT') ! constant temperature
          f_2d(:,n1-1)=2.*f_2d(:,n1)-f_2d(:,n1+1)
        case ('c3') ! constant flux
          if (.not. present(hcond)) then
            f_2d(:,n1-1)=f_2d(:,n1+1)+2.*dz*Fbot/hcond0
          else
            f_2d(:,n1-1)=f_2d(:,n1+1)+2.*dz*Fbot/hcond(:)
          endif
      endselect
      endif
!
    endsubroutine boundary_ADI
!***********************************************************************
    subroutine crank_Kconst(f)
!
! 18-sep-07/dintrans: coded
! Implicit Crank Nicolson scheme in 1-D for a constant K.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mz) :: TT
      real, dimension(nz) :: az, bz, cz, rhsz, wz
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f,iTT)
      TT=f(4,4,:,iTT)
!
      wz(:)=dt*dz_2*gamma*cp1*hcond0*exp(-f(4,4,n1:n2,ilnrho))
      az(:)=-0.5*wz
      bz(:)=1.+wz
      cz(:)=az
      do n=n1,n2
        rhsz(n-nghost)=TT(n)+0.5*wz(n-nghost)*(TT(n+1)-2.*TT(n)+TT(n-1))
      enddo
      bz(nz)=1. ; az(nz)=0. ; rhsz(nz)=cs2top/gamma_m1 ! T = Ttop
      if (bcz12(iTT,1)=='cT') then
        bz(1)=1. ; cz(1)=0.  ; rhsz(1)=cs2bot/gamma_m1 ! T = Tbot
      else
!        cz(1)=2.*cz(1) ; rhsz(1)=rhsz(1)+wz(1)*dz*Fbot/hcond0  ! T' = -Fbot/K
        bz(1)=1. ; cz(1)=-1. ; rhsz(1)=dz*Fbot/hcond0  ! T' = -Fbot/K
      endif
      call tridag(az, bz, cz, rhsz, f(4,4,n1:n2,iTT), err, msg)
      if (err) call warning('crank_Kconst', trim(msg))
!
    endsubroutine crank_Kconst
!***********************************************************************
    subroutine ADI_Kprof_1d(f)
!
! 18-sep-07/dintrans: coded
! Implicit 1-D case for a temperature-dependent conductivity K(T).
! Not really an ADI but keep the generic name for commodity.
!
      use EquationOfState, only: gamma
!
      implicit none
!
      integer :: j, jj
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mz) :: source, rho, TT, hcond, dhcond
      real, dimension(nz) :: a, b, c, rhs, work
      real :: wz, hcondp, hcondm
      logical :: err
      character(len=255) :: msg
!
      source=(f(4,4,:,ilnTT)-f(4,4,:,iTTold))/dt
      rho=exp(f(4,4,:,ilnrho))
!
! need to set up the 'c3' BC at the 2nd-order before the implicit stuff
!
      call heatcond_TT(f(4,4,:,iTTold), hcond, dhcond)
      hcondADI=spread(hcond(1), 1, mx)
      call boundary_ADI(f(:,4,:,iTTold), hcondADI)
      TT=f(4,4,:,iTTold)
!
      do j=n1,n2
        jj=j-nghost
        wz=dt*dz_2*gamma*cp1/rho(j)
        hcondp=hcond(j+1)+hcond(j)
        hcondm=hcond(j)+hcond(j-1)
!
        a(jj)=-wz/4.*(hcondm-dhcond(j-1)*(TT(j)-TT(j-1)))
        b(jj)=1.-wz/4.*(-hcondp-hcondm+dhcond(j)*(TT(j+1)-2.*TT(j)+TT(j-1)))
        c(jj)=-wz/4.*(hcondp+dhcond(j+1)*(TT(j+1)-TT(j)))
        rhs(jj)=wz/2.*(hcondp*(TT(j+1)-TT(j))-hcondm*(TT(j)-TT(j-1))) &
                +dt*source(j)
!
! Always constant temperature at the top: T^(n+1)-T^n = 0
!
        b(nz)=1. ; a(nz)=0.
        rhs(nz)=0.
        if (bcz12(ilnTT,1)=='cT') then
! Constant temperature at the bottom
          b(1)=1. ; c(1)=0.
          rhs(1)=0.
        else
! Constant flux at the bottom: d/dz [T^(n+1)-T^n] = 0
          b(1)=1.  ; c(1)=-1.
          rhs(1)=0.
        endif
      enddo
      call tridag(a, b, c, rhs, work, err, msg)
      if (err) call warning('ADI_Kprof_1d', trim(msg))
      f(4,4,n1:n2,ilnTT)=f(4,4,n1:n2,iTTold)+work
!
! Update the bottom value of hcond used for the 'c3' BC in boundcond
!
      call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
!
    endsubroutine ADI_Kprof_1d
!***********************************************************************
    subroutine ADI_Kconst_MPI(f)
!
!  04-sep-2009/dintrans: coded
!  Parallel version of the ADI scheme for the K=cte case.
!  Note: this is the parallelisation of the Yakonov form *only*.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Mpicomm, only: transp_xz, transp_zx
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer, parameter :: nxt=nx/nprocz
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz)      :: finter, rho1, TT
      real, dimension(nzgrid,nxt) :: fintert, rho1t, wtmp
      real, dimension(nx)         :: ax, bx, cx, wx, rhsx
      real, dimension(nzgrid)     :: az, bz, cz, wz, rhsz
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f,iTT)
      TT=f(:,4,:,iTT)
      if (ldensity) then
        rho1=exp(-f(:,4,:,ilnrho))
      else
        rho1=1.
      endif
!
! Rows dealt implicitly
!
      do j=n1,n2
        wx=0.5*dt*cp1*gamma*hcond0*rho1(l1:l2,j)
        ax=-wx*dx_2
        bx=1.+2.*wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,j) &
          +wx*dx_2*(TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j)) &
          +wx*dz_2*(TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax, bx, cx, aalpha, bbeta, rhsx, finter(l1:l2,j), nx)
      enddo
!
! Do the transpositions x <--> z
!
      call transp_xz(finter(l1:l2,n1:n2), fintert)
      call transp_xz(rho1(l1:l2,n1:n2), rho1t)
!
! Columns dealt implicitly
!
      do i=1,nxt
        wz=0.5*dz_2*dt*cp1*gamma*hcond0*rho1t(:,i)
        az=-wz
        bz=1.+2.*wz
        cz=az
        rhsz=fintert(:,i)
        !
        ! z boundary conditions
        ! Always constant temperature at the top
        !
        bz(nzgrid)=1. ; az(nzgrid)=0. ; rhsz(nzgrid)=cs2top/gamma_m1
        select case (bcz12(iTT,1))
          case ('cT') ! Constant temperature at the bottom
            bz(1)=1.  ; cz(1)=0.  ; rhsz(1)=cs2bot/gamma_m1
          case ('c1') ! Constant flux at the bottom
            bz(1)=1.  ; cz(1)=-1. ; rhsz(1)=dz*Fbot/hcond0
          case default
            call fatal_error('ADI_Kconst_MPI','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az, bz, cz, rhsz, wtmp(:,i), err, msg)
        if (err) call warning('ADI_Kconst_MPI', trim(msg))
      enddo
      call transp_zx(wtmp, f(l1:l2,4,n1:n2,iTT))
!
    endsubroutine ADI_Kconst_MPI
!***********************************************************************
    subroutine heatcond_TT_2d(TT, hcond, dhcond)
!
! 07-Sep-07/gastine: computed 2-D radiative conductivity hcond(T) with
! its derivative dhcond=dhcond(T)/dT.
!
      implicit none
!
      real, dimension(:,:), intent(in) :: TT
      real, dimension(:,:), intent(out) :: hcond
      real, dimension(:,:), optional :: dhcond
!
      hcond=hole_slope*(TT-Tbump-hole_width)*(TT-Tbump+hole_width)
      if (present(dhcond)) &
        dhcond=2.*hole_alpha/(1.+hcond**2)*hole_slope*(TT-Tbump)
      hcond=Kmax+hole_alpha*(-pi/2.+atan(hcond))
!
    endsubroutine heatcond_TT_2d
!***********************************************************************
    subroutine heatcond_TT_1d(TT, hcond, dhcond)
!
! 18-Sep-07/dintrans: computed 1-D radiative conductivity
! hcond(T) with its derivative dhcond=dhcond(T)/dT.
!
      implicit none
!
      real, dimension(:), intent(in) :: TT
      real, dimension(:), intent(out) :: hcond
      real, dimension(:), optional :: dhcond
!
      hcond=hole_slope*(TT-Tbump-hole_width)*(TT-Tbump+hole_width)
      if (present(dhcond)) &
        dhcond=2.*hole_alpha/(1.+hcond**2)*hole_slope*(TT-Tbump)
      hcond=Kmax+hole_alpha*(-pi/2.+atan(hcond))
!
    endsubroutine heatcond_TT_1d
!***********************************************************************
    subroutine heatcond_TT_0d(TT, hcond, dhcond)
!
! 07-Sep-07/gastine: computed the radiative conductivity hcond(T)
! with its derivative dhcond=dhcond(T)/dT at a given temperature.
!
      implicit none
!
      real, intent(in) :: TT
      real, intent(out) :: hcond
      real, optional :: dhcond
!
      hcond=hole_slope*(TT-Tbump-hole_width)*(TT-Tbump+hole_width)
      if (present(dhcond)) &
        dhcond=2.*hole_alpha/(1.+hcond**2)*hole_slope*(TT-Tbump)
      hcond=Kmax+hole_alpha*(-pi/2.+atan(hcond))
!
    endsubroutine heatcond_TT_0d
!***********************************************************************
    subroutine ADI_Kprof_1d_mixed(f)
!
! 28-feb-10/dintrans: coded
! Simpler version where a part of the radiative diffusion term is
! computed during the explicit advance.
!
      use EquationOfState, only: gamma
!
      implicit none
!
      integer :: j, jj
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mz) :: source, TT, hcond, dhcond, dLnhcond, chi
      real, dimension(nz) :: a, b, c, rhs, work
      real :: wz
      logical :: err
      character(len=255) :: msg
!
      source=(f(4,4,:,ilnTT)-f(4,4,:,iTTold))/dt
      call heatcond_TT(f(4,4,:,iTTold), hcond, dhcond)
!
! need to set up the 'c3' BC at the 2nd-order before the implicit stuff
!
      hcondADI=spread(hcond(1), 1, mx)
      call boundary_ADI(f(:,4,:,iTTold), hcondADI)
      TT=f(4,4,:,iTTold)
      if (ldensity) then
        chi=cp1*hcond/exp(f(4,4,:,ilnrho))
      else
        chi=cp1*hcond
      endif
      dLnhcond=dhcond/hcond
!
      do j=n1,n2
        jj=j-nghost
        wz=dt*dz_2*gamma*chi(j)
!
        a(jj)=-wz/2.
        b(jj)=1.-wz/2.*(-2.+dLnhcond(j)*(TT(j+1)-2.*TT(j)+TT(j-1)))
        c(jj)=-wz/2.
        rhs(jj)=wz*(TT(j+1)-2.*TT(j)+TT(j-1))+dt*source(j)
!
! Always constant temperature at the top: T^(n+1)-T^n = 0
!
        b(nz)=1. ; a(nz)=0.
        rhs(nz)=0.
        if (bcz12(ilnTT,1)=='cT') then
! Constant temperature at the bottom
          b(1)=1. ; c(1)=0.
          rhs(1)=0.
        else
! Constant flux at the bottom: d/dz [T^(n+1)-T^n] = 0
          b(1)=1.  ; c(1)=-1.
          rhs(1)=0.
        endif
      enddo
!
      call tridag(a, b, c, rhs, work, err, msg)
      if (err) call warning('ADI_Kprof_1d_mixed', trim(msg))
      f(4,4,n1:n2,ilnTT)=f(4,4,n1:n2,iTTold)+work
!
! Update the bottom value of hcond used for the 'c3' BC in boundcond
!
      call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
!
    endsubroutine ADI_Kprof_1d_mixed
!***********************************************************************
    subroutine ADI_Kprof_mixed(f)
!
!  28-fev-2010/dintrans: coded
!  simpler version where one part of the radiative diffusion term is
!  computed during the explicit step. The implicit part remains
!  of Yakonov's form:
!
!    (1-dt/2*J_x)*lambda = f_x(T^n) + f_z(T^n) + source
!    (1-dt/2*J_y)*beta   = lambda
!    T^(n+1) = T^n + dt*beta
!
!    where J_x and J_y denote Jacobian matrices df/dT.
!
      use EquationOfState, only: gamma
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz) :: source, hcond, dhcond, finter, val, TT, &
                                chi, dLnhcond
      real, dimension(nx)    :: ax, bx, cx, wx, rhsx, workx
      real, dimension(nz)    :: az, bz, cz, wz, rhsz, workz
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f)
!
      source=(f(:,4,:,ilnTT)-f(:,4,:,iTTold))/dt
! BC important not for the x-direction (always periodic) but for
! the z-direction as we must impose the 'c3' BC at the 2nd-order
! before going in the implicit stuff
      call heatcond_TT(f(:,4,:,iTTold), hcond, dhcond)
      call boundary_ADI(f(:,4,:,iTTold), hcond(:,n1))
      TT=f(:,4,:,iTTold)
      if (ldensity) then
        chi=cp1*hcond/exp(f(:,4,:,ilnrho))
!        chi=cp1*hcond0/exp(f(:,4,:,ilnrho))
      else
        chi=cp1*hcond
      endif
      dLnhcond=dhcond/hcond
!      dLnhcond=0.
!
! rows in the x-direction dealt implicitly
!
      do j=n1,n2
        wx=gamma*chi(l1:l2,j)
        ax=-dt/2.*wx*dx_2
        bx=1.-dt/2.*wx*dx_2*(-2.+dLnhcond(l1:l2,j)* &
           (TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j)))
        cx=-dt/2.*wx*dx_2
! rhsx=f_x(T^n) + f_z(T^n) + source
! do first f_z(T^n)
        rhsx=wx*dz_2*(TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))
! then add f_x(T^n) + source
        rhsx=rhsx+wx*dx_2*(TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j)) &
             +source(l1:l2,j)
!
! periodic boundary conditions in x --> cyclic matrix
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,workx,nx)
        finter(l1:l2,j)=workx
      enddo
!
! columns in the z-direction dealt implicitly
!
      do i=l1,l2
        wz=dt*gamma*dz_2*chi(i,n1:n2)
        az=-wz/2.
        bz=1.-wz/2.*(-2.+dLnhcond(i,n1:n2)*    &
          (TT(i,n1+1:n2+1)-2.*TT(i,n1:n2)+TT(i,n1-1:n2-1)))
        cz=-wz/2.
        rhsz=finter(i,n1:n2)
!
! z boundary conditions
! Constant temperature at the top: T^(n+1)-T^n=0
       bz(nz)=1. ; az(nz)=0.
       rhsz(nz)=0.
! bottom
       select case (bcz12(ilnTT,1))
! Constant temperature at the bottom: T^(n+1)-T^n=0
         case ('cT')
          bz(1)=1. ; cz(1)=0.
          rhsz(1)=0.
! Constant flux at the bottom
         case ('c3')
          bz(1)=1. ; cz(1)=-1.
          rhsz(1)=0.
         case default
          call fatal_error('ADI_Kprof_mixed','bcz on TT must be cT or c3')
       endselect
!
       call tridag(az,bz,cz,rhsz,workz,err,msg)
       if (err) call warning('ADI_Kprof_mixed', trim(msg))
       val(i,n1:n2)=workz(1:nz)
      enddo
!
      f(:,4,:,ilnTT)=f(:,4,:,iTTold)+dt*val
!
! update hcond used for the 'c3' condition in boundcond.f90
!
      call heatcond_TT(f(:,4,n1,ilnTT), hcondADI)
!
    endsubroutine ADI_Kprof_mixed
!***********************************************************************
    subroutine ADI_Kconst_yakonov(f)
!
!  26-Jan-2011/dintrans: coded
!  2-D ADI scheme for the radiative diffusion term for a constant
!  radiative conductivity K. The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*Lamba_x)*T^(n+1/2) = Lambda_x(T^n) + Lambda_z(T^n)
!    (1-dt/2*Lamba_z)*T^(n+1)   = T^(n+1/2)
!
!  where Lambda_x and Lambda_z denote diffusion operators.
!  Note: this form is more adapted for a parallelisation compared the
!  Peaceman & Rachford one.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz) :: finter, TT, rho1
      real, dimension(nx)    :: ax, bx, cx, wx, rhsx, workx
      real, dimension(nz)    :: az, bz, cz, wz, rhsz, workz
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f)
      TT=f(:,4,:,iTT)
      if (ldensity) then
        rho1=exp(-f(:,4,:,ilnrho))
      else
        rho1=1.
      endif
!
!  rows dealt implicitly
!
      do j=n1,n2
        wx=dt*cp1*gamma*hcond0*rho1(l1:l2,j)
        ax=-wx*dx_2/2.
        bx=1.+wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,j)+ &
             wx*dz_2/2.*(TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))
        rhsx=rhsx+wx*dx_2/2.*                                 &
             (TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j))
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,workx,nx)
        finter(l1:l2,j)=workx
      enddo
!
!  columns dealt implicitly
!
      do i=l1,l2
        wz=dt*cp1*gamma*hcond0*dz_2*rho1(i,n1:n2)
        az=-wz/2.
        bz=1.+wz
        cz=az
        rhsz=finter(i,n1:n2)
!
! z boundary conditions
!
! Constant temperature at the top
        bz(nz)=1. ; az(nz)=0.
        rhsz(nz)=cs2top/gamma_m1
! bottom
        select case (bcz12(iTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1. ; cz(1)=0.
            rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom: c1 condition
          case ('c1')
            bz(1)=1.   ; cz(1)=-1.
            rhsz(1)=dz*Fbot/hcond0
          case default
            call fatal_error('ADI_Kconst_yakonov','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az,bz,cz,rhsz,workz,err,msg)
        if (err) call warning('ADI_Kconst_yakonov', trim(msg))
        f(i,4,n1:n2,iTT)=workz
      enddo
!
    endsubroutine ADI_Kconst_yakonov
!***********************************************************************
    subroutine crank_Kprof(f)
!
! 01-may-14/dintrans: coded
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mz) :: TT, rho1
      real, dimension(nz) :: az, bz, cz, rhsz, chi, dchi
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f,iTT)
      TT=f(4,4,:,iTT)
      rho1=exp(-f(4,4,:,ilnrho))
!
      chi=0.5*dt*dz_2*gamma*cp1*hcondz(n1:n2)*rho1(n1:n2)
      dchi=0.25*dt/dz*gamma*cp1*dhcondz(n1:n2)*rho1(n1:n2)
      az=-chi+dchi
      bz=1.+2.*chi
      cz=-chi-dchi
      do n=n1,n2
        rhsz(n-nghost)=TT(n)+chi(n-nghost)*(TT(n+1)-2.*TT(n)+TT(n-1)) &
                            +dchi(n-nghost)*(TT(n+1)-TT(n-1))
      enddo
      bz(nz)=1. ; az(nz)=0. ; rhsz(nz)=cs2top/gamma_m1 ! T = Ttop
      if (bcz12(iTT,1)=='cT') then
        bz(1)=1. ; cz(1)=0.  ; rhsz(1)=cs2bot/gamma_m1 ! T = Tbot
      else
!        cz(1)=2.*cz(1) ; rhsz(1)=rhsz(1)+wz(n1)*dz*Fbot/hcondz(n1)  ! T' = -Fbot/K
        bz(1)=1. ; cz(1)=-1. ; rhsz(1)=dz*Fbot/hcondz(n1)  ! T' = -Fbot/K
      endif
      call tridag(az, bz, cz, rhsz, f(4,4,n1:n2,iTT), err, msg)
      if (err) call warning('crank_Kprof', trim(msg))
!
    endsubroutine crank_Kprof
!***********************************************************************
    subroutine ADI_poly(f)
!
!  01-may-14/dintrans: coded
!  2-D ADI scheme for the radiative diffusion term for a variable
!  radiative conductivity K(z). The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*Lamba_x)*T^(n+1/2) = T^n + Lambda_x(T^n) + Lambda_z(T^n)
!    (1-dt/2*Lamba_z)*T^(n+1)   = T^(n+1/2)
!
!  where Lambda_x and Lambda_z denote diffusion operators.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer :: i,j
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz) :: finter, rho1, TT, chi, dchi
      real, dimension(nx)    :: ax, bx, cx, wx, rhsx, wx1
      real, dimension(nz)    :: az, bz, cz, wz, rhsz, wz1
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f)
      TT=f(:,4,:,iTT)
      rho1=exp(-f(:,4,:,ilnrho))
!
! x-direction
!
      do j=n1,n2
        chi(l1:l2,j)=dt*cp1*gamma*hcondz(j)*rho1(l1:l2,j)
        dchi(l1:l2,j)=dt*cp1*gamma*dhcondz(j)*rho1(l1:l2,j)
        wx=0.5*chi(l1:l2,j)
        wx1=0.25*dchi(l1:l2,j)
        ax=-wx*dx_2
        bx=1.+2.*wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,j)   &
            +wx*dx_2*(TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j)) &
            +wx*dz_2*(TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))     &
            +wx1/dz*(TT(l1:l2,j+1)-TT(l1:l2,j-1))
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,finter(l1:l2,j),nx)
      enddo
!
! z-direction
!
      do i=l1,l2
        wz=0.5*dz_2*chi(i,n1:n2)
        wz1=0.25/dz*dchi(i,n1:n2)
        az=-wz+wz1
        bz=1.+2.*wz
        cz=-wz-wz1
        rhsz=finter(i,n1:n2)
!
! z boundary conditions
!
! Constant temperature at the top
        bz(nz)=1. ; az(nz)=0. ; rhsz(nz)=cs2top/gamma_m1
! bottom
        select case (bcz12(iTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1. ; cz(1)=0. ; rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom: c1 condition
          case ('c1')
            bz(1)=1.   ; cz(1)=-1 ; rhsz(1)=dz*Fbot/hcondz(n1)
          case default
            call fatal_error('ADI_poly','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az,bz,cz,rhsz,f(i,4,n1:n2,iTT),err,msg)
        if (err) call warning('ADI_poly', trim(msg))
      enddo
!
    endsubroutine ADI_poly
!***********************************************************************
    subroutine ADI_poly_MPI(f)
!
!  01-may-14/dintrans: coded
!  Parallel version in the z-direction of ADI_poly.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
      use Mpicomm, only: transp_xz, transp_zx
!
      implicit none
!
      integer :: i,j
      integer, parameter :: nxt=nx/nprocz
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,mz)      :: finter, rho1, TT, chi, dchi
      real, dimension(nx)         :: ax, bx, cx, wx, rhsx, wx1
      real, dimension(nzgrid)     :: az, bz, cz, wz, rhsz, wz1
      real, dimension(nzgrid,nxt) :: fintert, chit, dchit, wtmp
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f,iTT)
      TT=f(:,4,:,iTT)
      rho1=exp(-f(:,4,:,ilnrho))
!
! x-direction
!
      do j=n1,n2
        chi(l1:l2,j)=dt*cp1*gamma*hcondz(j)*rho1(l1:l2,j)
        dchi(l1:l2,j)=dt*cp1*gamma*dhcondz(j)*rho1(l1:l2,j)
        wx=0.5*chi(l1:l2,j)
        wx1=0.25*dchi(l1:l2,j)
        ax=-wx*dx_2
        bx=1.+2.*wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,j)    &
            +wx*dx_2*(TT(l1+1:l2+1,j)-2.*TT(l1:l2,j)+TT(l1-1:l2-1,j)) &
            +wx*dz_2*(TT(l1:l2,j+1)-2.*TT(l1:l2,j)+TT(l1:l2,j-1))     &
            +wx1/dz*(TT(l1:l2,j+1)-TT(l1:l2,j-1))
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,finter(l1:l2,j),nx)
      enddo
!
! do the transpositions x <--> z
!
      call transp_xz(finter(l1:l2,n1:n2), fintert)
      call transp_xz(chi(l1:l2,n1:n2), chit)
      call transp_xz(dchi(l1:l2,n1:n2), dchit)
!
! z-direction
!
      do i=1,nxt
        wz=0.5*dz_2*chit(:,i)
        wz1=0.25/dz*dchit(:,i)
        az=-wz+wz1
        bz=1.+2.*wz
        cz=-wz-wz1
        rhsz=fintert(:,i)
!
! z boundary conditions
!
! Constant temperature at the top
        bz(nzgrid)=1. ; az(nzgrid)=0. ; rhsz(nzgrid)=cs2top/gamma_m1
! bottom
        select case (bcz12(iTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1. ; cz(1)=0. ; rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom: c1 condition
          case ('c1')
!            bz(1)=1.   ; cz(1)=-1 ; rhsz(1)=dz*Fbot/hcondz(n1)
            bz(1)=1.   ; cz(1)=-1. ; rhsz(1)=dz*Fbot/hcond0
          case default
            call fatal_error('ADI_poly_MPI','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az,bz,cz,rhsz,wtmp(:,i),err,msg)
        if (err) call warning('ADI_poly_MPI', trim(msg))
      enddo
      call transp_zx(wtmp, f(l1:l2,4,n1:n2,iTT))
!
    endsubroutine ADI_poly_MPI
!***********************************************************************
    subroutine ADI3D(f)
!
!  02-may-14/dintrans: coded
!  3-D ADI scheme for the radiative diffusion term for a variable
!  radiative conductivity K(z). The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*L_x)*T^(n+1/3) = T^n + L_x(T^n) + + L_y(T^n) + L_z(T^n) + source
!    (1-dt/2*L_y)*T^(n+2/3) = T^(n+1/3)
!    (1-dt/2*L_z)*T^(n+1)   = T^(n+2/3)
!
!  where L_x, L_y and L_z denote diffusion operators and the source
!  term comes from the explicit advance.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
!
      implicit none
!
      integer :: l,m,n
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,my,mz) :: source, finterx, fintery, TT, chi, dchi
      real, dimension(nx)     :: ax, bx, cx, rhsx, wx, wx1
      real, dimension(ny)     :: ay, by, cy, rhsy, wy, wy1
      real, dimension(nz)     :: az, bz, cz, rhsz, wz, wz1
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f)
!
      source=(f(:,:,:,ilnTT)-f(:,:,:,iTTold))/dt
      TT=f(:,:,:,iTTold)
!
!  x-direction
!
      do n=n1,n2
      do m=m1,m2
        chi(l1:l2,m,n)=dt*cp1*gamma*hcondz(n)/exp(f(l1:l2,m,n,ilnrho))
        dchi(l1:l2,m,n)=dt*cp1*gamma*dhcondz(n)/exp(f(l1:l2,m,n,ilnrho))
        wx=0.5*chi(l1:l2,m,n)
        wx1=0.25*dchi(l1:l2,m,n)
        ax=-wx*dx_2
        bx=1.+2.*wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,m,n)+ &
             wx*dz_2*(TT(l1:l2,m,n+1)-2.*TT(l1:l2,m,n)+TT(l1:l2,m,n-1)) &
            +wx1/dz*(TT(l1:l2,m,n+1)-TT(l1:l2,m,n-1))                   &
            +wx*dy_2*(TT(l1:l2,m+1,n)-2.*TT(l1:l2,m,n)+TT(l1:l2,m-1,n))
        rhsx=rhsx+wx*dx_2*                                    &
             (TT(l1+1:l2+1,m,n)-2.*TT(l1:l2,m,n)+TT(l1-1:l2-1,m,n)) &
             +dt*source(l1:l2,m,n)
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,finterx(l1:l2,m,n),nx)
      enddo
      enddo
!
!  y-direction
!
      do n=n1,n2
      do l=l1,l2
        wy=0.5*chi(l,m1:m2,n)
        wy1=0.25*dchi(l,m1:m2,n)
        ay=-wy*dy_2
        by=1.+2.*wy*dy_2
        cy=ay
        rhsy=finterx(l,m1:m2,n)
!
! y boundary conditions: periodic
!
        aalpha=cy(ny) ; bbeta=ay(1)
        call cyclic(ay,by,cy,aalpha,bbeta,rhsy,fintery(l,m1:m2,n),ny)
      enddo
      enddo
!
!  z-direction
!
      do m=m1,m2
      do l=l1,l2
        wz=0.5*dz_2*chi(l,m,n1:n2)
        wz1=0.25/dz*dchi(l,m,n1:n2)
        az=-wz+wz1
        bz=1.+2.*wz
        cz=-wz-wz1
        rhsz=fintery(l,m,n1:n2)
!
! z boundary conditions
!
! Constant temperature at the top
        bz(nz)=1. ; az(nz)=0. ; rhsz(nz)=cs2top/gamma_m1
! bottom
        select case (bcz12(ilnTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1. ; cz(1)=0. ; rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom: c1 condition
          case ('c1')
            bz(1)=1.   ; cz(1)=-1 ; rhsz(1)=dz*Fbot/hcondz(n1)
          case default
            call fatal_error('ADI_poly','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az,bz,cz,rhsz,f(l,m,n1:n2,ilnTT),err,msg)
        if (err) call warning('ADI_poly', trim(msg))
      enddo
      enddo
!
    endsubroutine ADI3D
!***********************************************************************
    subroutine ADI3D_MPI(f)
!
!  02-may-14/dintrans: coded
!  3-D ADI scheme for the radiative diffusion term for a variable
!  radiative conductivity K(z). The ADI scheme is of Yakonov's form:
!
!    (1-dt/2*L_x)*T^(n+1/3) = T^n + L_x(T^n) + + L_y(T^n) + L_z(T^n) + source
!    (1-dt/2*L_y)*T^(n+2/3) = T^(n+1/3)
!    (1-dt/2*L_z)*T^(n+1)   = T^(n+2/3)
!
!  where L_x, L_y and L_z denote diffusion operators and the source
!  term comes from the explicit advance.
!
      use EquationOfState, only: gamma, gamma_m1, cs2bot, cs2top
      use Boundcond, only: update_ghosts
      use Mpicomm, only: transp_xz, transp_zx
!
      implicit none
!
      integer, parameter :: nxt=nx/nprocz
      integer :: l,m,n
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(mx,my,mz) :: source, finterx, fintery, TT, chi, dchi
      real, dimension(nx)     :: ax, bx, cx, rhsx, wx, wx1
      real, dimension(ny)     :: ay, by, cy, rhsy, wy, wy1
      real, dimension(nzgrid) :: az, bz, cz, rhsz, wz, wz1
      real, dimension(nzgrid,nxt) :: finteryt, chit, dchit, wtmp
      real :: aalpha, bbeta
      logical :: err
      character(len=255) :: msg
!
      call update_ghosts(f)
!
      source=(f(:,:,:,ilnTT)-f(:,:,:,iTTold))/dt
      TT=f(:,:,:,iTTold)
!
!  x-direction
!
      do n=n1,n2
      do m=m1,m2
        chi(l1:l2,m,n)=dt*cp1*gamma*hcondz(n)/exp(f(l1:l2,m,n,ilnrho))
        dchi(l1:l2,m,n)=dt*cp1*gamma*dhcondz(n)/exp(f(l1:l2,m,n,ilnrho))
        wx=0.5*chi(l1:l2,m,n)
        wx1=0.25*dchi(l1:l2,m,n)
        ax=-wx*dx_2
        bx=1.+2.*wx*dx_2
        cx=ax
        rhsx=TT(l1:l2,m,n)+ &
             wx*dz_2*(TT(l1:l2,m,n+1)-2.*TT(l1:l2,m,n)+TT(l1:l2,m,n-1)) &
            +wx1/dz*(TT(l1:l2,m,n+1)-TT(l1:l2,m,n-1))                   &
            +wx*dy_2*(TT(l1:l2,m+1,n)-2.*TT(l1:l2,m,n)+TT(l1:l2,m-1,n))
        rhsx=rhsx+wx*dx_2*                                    &
             (TT(l1+1:l2+1,m,n)-2.*TT(l1:l2,m,n)+TT(l1-1:l2-1,m,n)) &
             +dt*source(l1:l2,m,n)
!
! x boundary conditions: periodic
!
        aalpha=cx(nx) ; bbeta=ax(1)
        call cyclic(ax,bx,cx,aalpha,bbeta,rhsx,finterx(l1:l2,m,n),nx)
      enddo
      enddo
!
!  y-direction
!
      do n=n1,n2
      do l=l1,l2
        wy=0.5*chi(l,m1:m2,n)
        wy1=0.25*dchi(l,m1:m2,n)
        ay=-wy*dy_2
        by=1.+2.*wy*dy_2
        cy=ay
        rhsy=finterx(l,m1:m2,n)
!
! y boundary conditions: periodic
!
        aalpha=cy(ny) ; bbeta=ay(1)
        call cyclic(ay,by,cy,aalpha,bbeta,rhsy,fintery(l,m1:m2,n),ny)
      enddo
      enddo
!
!  z-direction
!
      do m=m1,m2
      call transp_xz(fintery(l1:l2,m,n1:n2), finteryt)
      call transp_xz(chi(l1:l2,m,n1:n2), chit)
      call transp_xz(dchi(l1:l2,m,n1:n2), dchit)
      do l=1,nxt
        wz=0.5*dz_2*chit(:,l)
        wz1=0.25/dz*dchit(:,l)
        az=-wz+wz1
        bz=1.+2.*wz
        cz=-wz-wz1
        rhsz=finteryt(:,l)
!
! z boundary conditions
!
! Constant temperature at the top
        bz(nzgrid)=1. ; az(nzgrid)=0. ; rhsz(nzgrid)=cs2top/gamma_m1
! bottom
        select case (bcz12(ilnTT,1))
          ! Constant temperature at the bottom
          case ('cT')
            bz(1)=1. ; cz(1)=0. ; rhsz(1)=cs2bot/gamma_m1
          ! Constant flux at the bottom: c1 condition
          case ('c1')
!            bz(1)=1.   ; cz(1)=-1 ; rhsz(1)=dz*Fbot/hcondz(n1)
            bz(1)=1.   ; cz(1)=-1 ; rhsz(1)=dz*Fbot/hcond0
          case default
            call fatal_error('ADI_poly','bcz on TT must be cT or c1')
        endselect
!
        call tridag(az,bz,cz,rhsz,wtmp(:,l),err,msg)
        if (err) call warning('ADI_poly', trim(msg))
      enddo
      call transp_zx(wtmp, f(l1:l2,m,n1:n2,ilnTT))
      enddo
!
    endsubroutine ADI3D_MPI
!***********************************************************************
endmodule ImplicitPhysics

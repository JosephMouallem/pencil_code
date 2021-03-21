
! $Id$
!
!  This module incorporates all the modules used for Natalia's
!  aerosol simulations
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of special_dummies.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED ppsf(ndustspec); pp
!
!***************************************************************
!
!-------------------------------------------------------------------
!
! HOW TO USE THIS FILE
! --------------------
!
! The rest of this file may be used as a template for your own
! special module.  Lines which are double commented are intended
! as examples of code.  Simply fill out the prototypes for the
! features you want to use.
!
! Save the file with a meaningful name, eg. geo_kws.f90 and place
! it in the $PENCIL_HOME/src/special directory.  This path has
! been created to allow users ot optionally check their contributions
! in to the Pencil-Code CVS repository.  This may be useful if you
! are working on/using the additional physics with somebodyelse or
! may require some assistance from one of the main Pencil-Code team.=spline_integral(dsize,init_distr)
!
! To use your additional physics code edit the Makefile.local in
! the src directory under the run directory in which you wish to
! use your additional physics.  Add a line with all the module
! selections to say something like:
!
!    SPECIAL=special/atmosphere
!
! Where nstar it replaced by the filename of your new module
! upto and not including the .f90
!
!--------------------------------------------------------------------
!
module Special
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages
!  use Dustdensity
  use EquationOfState
!
  implicit none
!
  include '../special.h'
!
  ! input parameters
  logical :: lbuoyancy_x=.false.,lbuoyancy_y=.false.
  logical :: lbuoyancy_z=.false.,lbuoyancy_z_model=.false.
!
  character (len=labellen) :: initstream='default'
  real, dimension(ndustspec) :: dsize, init_distr2
  real, dimension(mx,ndustspec) :: init_distr
  real, dimension(ndustspec0) :: Ntot_i
  real :: Rgas, Rgas_unit_sys=1.
  integer :: ind_H2O, ind_N2
  real :: sigma=1., Period=1.
  real :: dsize_max=0.,dsize_min=0.
  real :: dsize0_max=0.,dsize0_min=0., UY_ref=0.
  real :: TT2=0., TT1=0., dYw=1., pp_init=3.013e5
  logical :: lbuffer_zone_T=.false., lbuffer_zone_chem=.false.
  logical :: lbuffer_zone_uy=.false., lbuffer_zone_uz=.false.
  logical :: llognormal=.false., lACTOS=.false.
  logical :: lsmall_part=.false.,  llarge_part=.false., lsmall_large_part=.false.
  logical :: laverage=.false., lgrav_LES=.false.
  logical :: lboundary_layer=.false., lLES=.false.
!
  real :: rho_w=1.0, rho_s=3.,  Dwater=22.0784e-2,  m_w=18., m_s=60.,AA=0.66e-4
  real :: nd0, r0, r02, delta, uy_bz, ux_bz,  dYw1, dYw2, PP, Ntot=1e3
  real :: lnTT1, lnTT2, Ntot_ratio=1., Ntot_input, TT0, qwater0, aerosol_present=1.
  real :: logrho_ref_bot, logrho_ref2_bot, logrho_ref_top, logrho_ref2_top, TT_ref_top, TT_ref_bot, t_final
  real :: uz_ref_top=0., uz_ref_bot=0., uz_bc=0.
  real :: ux_ref_top=0., uy_ref_top=0., T_ampl
  real :: bc_lnrho_aver_final, bc_qv_aver_final
  real :: rotat_position=0.
  real :: rotat_ux=0., rotat_uy=0., ux_bot=0., uy_bot=0.
!
! Keep some over used pencils
!
! start parameters
  namelist /special_init_pars/  &
      lbuoyancy_z,lbuoyancy_x,lbuoyancy_y, sigma, Period,dsize_max,dsize_min, lbuoyancy_z_model,&
      TT2,TT1,dYw,lbuffer_zone_T, lbuffer_zone_chem, pp_init, dYw1, dYw2, &
      nd0, r0, r02, delta,lbuffer_zone_uy,ux_bz,uy_bz,dsize0_max,dsize0_min, Ntot,  PP, TT0, qwater0, aerosol_present, &
      lACTOS, lsmall_part,  llarge_part, lsmall_large_part, Ntot_ratio, UY_ref, llognormal, Ntot_input, &
      laverage, lbuffer_zone_uz, logrho_ref_top, logrho_ref2_top, TT_ref_top, TT_ref_bot, &
      t_final, logrho_ref_bot, logrho_ref2_bot, lgrav_LES, uz_ref_bot,uz_ref_top, uz_bc, &
      ux_ref_top, uy_ref_top, bc_lnrho_aver_final, bc_qv_aver_final, T_ampl, &
      lboundary_layer, rotat_position, rotat_ux, rotat_uy, ux_bot, uy_bot, lLES

! run parameters
  namelist /special_run_pars/  &
      lbuoyancy_z,lbuoyancy_x, sigma,dYw,lbuffer_zone_uy, lbuffer_zone_T, lnTT1, lnTT2
!
!
  integer :: idiag_dtcrad=0
  integer :: idiag_dtchi=0
!
  contains
!
!***********************************************************************
    subroutine register_special()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!
!  6-oct-03/tony: coded
!
      use Cdata
   !   use Density
      use EquationOfState
      use Mpicomm
!
      logical, save :: first=.true.
!
! A quick sanity check
!
      if (.not. first) call stop_it('register_special called twice')
      first = .false.
!
!!
!! MUST SET lspecial = .true. to enable use of special hooks in the Pencil-Code
!!   THIS IS NOW DONE IN THE HEADER ABOVE
!
!
!
!!
!! Set any required f-array indexes to the next available slot
!!
!!
!      iSPECIAL_VARIABLE_INDEX = nvar+1             ! index to access entropy
!      nvar = nvar+1
!
!      iSPECIAL_AUXILIARY_VARIABLE_INDEX = naux+1             ! index to access entropy
!      naux = naux+1
!
!
!  identify CVS/SVN version information:
!
      if (lroot) call svn_id( &
           "$Id$")
!
!
!  Perform some sanity checks (may be meaningless if certain things haven't
!  been configured in a custom module but they do no harm)
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_special: naux > maux')
      endif
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_special: nvar > mvar')
      endif
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f)
!
!  called by run.f90 after reading parameters, but before the time loop
!
!  06-oct-03/tony: coded
!
      use EquationOfState

      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: k,i
      real :: ddsize, Ntot_
      real, dimension (ndustspec) :: lnds,dsize_
!
!  Initialize any module variables which are parameter dependent
!
      if (unit_system == 'cgs') then
        Rgas_unit_sys = k_B_cgs/m_u_cgs
        Rgas=Rgas_unit_sys*unit_temperature/unit_velocity**2
      endif
!
      do k=1,nchemspec
      !  if (trim(varname(ichemspec(k)))=='CLOUD') then
      !    ind_cloud=k
      !  endif
        if (trim(varname(ichemspec(k)))=='H2O') then
          ind_H2O=k
        endif
        if (trim(varname(ichemspec(k)))=='N2') then
          ind_N2=k
        endif
!
      enddo
!
      print*,'special: water index', ind_H2O
      print*,'special: N2 index', ind_N2
!
!
      call set_init_parameters(Ntot,dsize,init_distr,init_distr2)
!
    endsubroutine initialize_special
!***********************************************************************
    subroutine init_special(f)
!
!  initialise special condition; called from start.f90
!  06-oct-2003/tony: coded
!
      use Cdata
   !   use Density
      use EquationOfState
      use Mpicomm
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      intent(inout) :: f
!
!!
!      select case (initstream)
!        case ('flame_spd')
!         call flame_spd(f)
!        case ('default')
!          if (lroot) print*,'init_special: Default  setup'
!        case default
!
!  Catch unknown values
!
!          if (lroot) print*,'init_special: No such value for initstream: ', trim(initstream)
!          call stop_it("")
!      endselect
!
!

!
    endsubroutine init_special
!***********************************************************************
    subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
      use Cdata
!
!
!
    endsubroutine pencil_criteria_special
!***********************************************************************
    subroutine dspecial_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
!
!  Due to the multi-step Runge Kutta timestepping used one MUST always
!  add to the present contents of the df array.  NEVER reset it to zero.
!
!  several precalculated Pencils of information are passed if for
!  efficiency.
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Diagnostics
      use Mpicomm
      use Sub
   !   use Global
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
!
      intent(in) :: f,p
      intent(inout) :: df

      real, dimension(nx) :: diffus_chi
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'dspecial_dt: SOLVE dSPECIAL_dt'
!!      if (headtt) call identify_bcs('ss',iss)
!
!!
!! SAMPLE DIAGNOSTIC IMPLEMENTATION
!!
      if (ldiagnos) then
        if (idiag_dtcrad/=0) &
          call max_mn_name(sqrt(advec_crad2)/cdt,idiag_dtcrad,l_dt=.true.)
        if (idiag_dtchi/=0) & !! diffus_chi not calculated here
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi,l_dt=.true.)
      endif
!
! Keep compiler quiet by ensuring every parameter is used
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine dspecial_dt
!***********************************************************************
    subroutine read_special_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=special_init_pars, IOSTAT=iostat)
!
    endsubroutine read_special_init_pars
!***********************************************************************
    subroutine write_special_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=special_init_pars)
!
    endsubroutine write_special_init_pars
!***********************************************************************
    subroutine read_special_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=special_run_pars, IOSTAT=iostat)
!
    endsubroutine read_special_run_pars
!***********************************************************************
    subroutine write_special_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=special_run_pars)
!
    endsubroutine write_special_run_pars
!***********************************************************************
    subroutine rprint_special(lreset,lwrite)
!
!  reads and registers print parameters relevant to special
!
!   06-oct-03/tony: coded
!
      use Diagnostics
      use FArrayManager, only: farray_index_append
!
!  define diagnostics variable
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_dtcrad=0
        idiag_dtchi=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtcrad',idiag_dtcrad)
        call parse_name(iname,cname(iname),cform(iname),'dtchi',idiag_dtchi)
      enddo
!
!  write column where which magnetic variable is stored
      if (lwr) then
        call farray_index_append('i_dtcrad',idiag_dtcrad)
        call farray_index_append('i_dtchi',idiag_dtchi)
      endif
!
    endsubroutine rprint_special
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!   06-oct-03/tony: coded
!
      use Cdata
      ! use Viscosity
      use EquationOfState
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
!   16-jul-06/natalia: coded
!
      use Cdata
      use Sub, only: dot
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      real :: gg=9.81e2!,  qwater0=9.9e-3
      real :: eps=0.5 !!????????????????????????
      real :: rho_water=1., const_tmp=0.
!
      real, dimension (mx) :: func_x
      real, dimension (nx) ::  TT
      real, dimension(nx) :: g2TT
      real, dimension (my) :: u_profile
      real    :: del,width
      integer :: l_sz
      integer :: i, j, k  !, sz_l_y,sz_r_y,
      integer ::  mm1,mm2, sz_y, nn1, nn2, sz_z
      real    :: dt1, bs,Ts,dels, logrho_tmp, tmp, tmp2
      logical :: lzone_left, lzone_right
!

      if (lgrav_LES) then
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz) - gg
      endif

       const_tmp=4./3.*PI*rho_water
      if (lbuoyancy_z) then
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)&
             + gg*((p%TT(:)-TT0)/TT0 &
             + (1./p%mu1/18.-1.)*(f(l1:l2,m,n,ichemspec(ind_H2O))-qwater0) &
             - p%fcloud(:) &
            )
      elseif (lbuoyancy_z_model) then
        bs=gg*(293.-290.)/293.*100.
        Ts=((293.+290.)/2.-290.)/(293.-290.)
        TT=(p%TT(:)-290.)/(293.-290.)
        dels=100.*0.1/Lxyz(1)
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)&
             - bs*TT/Ts + bs/(1.-Ts)/Ts*dels*log(exp((TT-Ts)/dels)+1.)
      elseif (lbuoyancy_x) then
        df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)&
             + gg*((p%TT(:)-TT0)/TT0 &
             + (1./p%mu1/18.-1.)*(f(l1:l2,m,n,ichemspec(ind_H2O))-qwater0) &
             - p%fcloud(:) &
            )
      elseif (lbuoyancy_y) then
        df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)&
             + gg*((p%TT(:)-TT0)/TT0 &
             + (1./p%mu1/18.-1.)*(f(l1:l2,m,n,ichemspec(ind_H2O))-qwater0) &
             - p%fcloud(:)*aerosol_present &
            )
      endif
!
       dt1=1./(5.*dt)
       del=0.1
!
         lzone_left=.false.
         lzone_right=.false.
         sz_y=int(del*nygrid)
!
        if (lbuffer_zone_uy .and. (nygrid/=1)) then
        do j=1,2
!
         if (j==1) then
            mm1=nygrid-sz_y
            mm2=nygrid
!
           if ((y(m) >= ygrid(mm1)) .and. (y(m) <= ygrid(mm2))) lzone_right=.true.
           if (lzone_right) then
!             dt1=(m-(m2-sz_y))/sz_y/(8.*dt)
!             df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-(f(l1:l2,m,n,iuy)-UY_ref)*dt1
!             df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-(f(l1:l2,m,n,iux)-UY_ref)*dt1
!             df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)-(f(l1:l2,m,n,ilnTT)-alog(lnTT2))*dt1
           endif
         else if (j==2) then
           mm1=1
           mm2=sz_y
           if ((y(m) >= ygrid(mm1)) .and. (y(m) <= ygrid(mm2))) lzone_left=.true.
           if (lzone_left) then
!             dt1=(sz_y-m)/(sz_y-1)/(8.*dt)
!             df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-(f(l1:l2,m,n,iuy)-0.)*dt1
!             df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-(f(l1:l2,m,n,iux)-UY_ref)*dt1
!             df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)-(f(l1:l2,m,n,ilnTT)-alog(lnTT1))*dt1
           endif
         endif
!
        enddo
        endif

        if (lbuffer_zone_uz .and. (nzgrid/=1)) then

        sz_z=int(del*nzgrid)
        do j=1,2
!
         if (j==1) then
            nn1=nzgrid-sz_z
            nn2=nzgrid
!
           if ((z(n) >= zgrid(nn1)) .and. (z(n) <= zgrid(nn2))) lzone_right=.true.
           if (lzone_right) then

!               df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-(f(l1:l2,m,n,iuz)-0.)*dt1


!              df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-(f(l1:l2,m,n,iux)-0.)*dt1
!              df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-(f(l1:l2,m,n,iuy)-0.)*dt1


!               df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)  &
!                   -(f(l1:l2,m,n,ilnTT)-f(l1:l2,m,nn2,ilnTT))*dt1

!
           endif
!
         elseif (j==2) then
            nn1=1
            nn2=sz_z
!
           if ((z(n) >= zgrid(nn1)) .and. (z(n) <= zgrid(nn2))) lzone_left=.true.
           if (lzone_left) then

!              df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-(f(l1:l2,m,n,iuz)-0.)*dt1
!!!!!!!!!!!!!!!!!!!!!!!!!!
!              df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-(f(l1:l2,m,n,iux)-ux_bot)*dt1
!              df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-(f(l1:l2,m,n,iuy)-uy_bot)*dt1
!
!              df(l1:l2,m,n,ilnTT)=df(l1:l2,m,n,ilnTT)  &
!                 -(f(l1:l2,m,n,ilnTT)-f(l1:l2,m,n1,ilnTT))*dt1
!
!
            do k=1, nchemspec
            do i=l1,l2

               df(i,m,n,ichemspec(k))=df(i,m,n,ichemspec(k))  &
                     -(f(i,m,n,ichemspec(k)) &
                -(0.5*f(i,m,nn1,ichemspec(k))+0.5*f(i,m,nn2,ichemspec(k))))*dt1

            enddo
            enddo

!           if ((z(n) >= zgrid(nn2-3)) .and. (z(n) <= zgrid(nn2-1))) then
!             df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)-(f(l1:l2,m,n,iuz)-0.)*dt1
!           endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!

      !             call dot(p%glnTT,p%glnTT,g2TT)
 !             df(l1:l2,m,n,ilnTT)=  &
 !              1e-4*(0.15*dxmax)**2.*sqrt(2*p%sij2)/.3*(p%del2lnTT+g2TT)

!
           endif

         endif
!
        enddo
        endif

       if (lboundary_layer) then
         if (z(n)>rotat_position) then
            df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)-(f(l1:l2,m,n,iux)-rotat_ux)*dt1
            df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-(f(l1:l2,m,n,iuy)-rotat_uy)*dt1
         endif
       endif
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_energy(f,df,p)
!
      use Cdata
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      integer :: l_sz, mm1,mm2, sz_y
      real, dimension (mx) :: func_x
      integer :: i, j,  sz_l_x,sz_r_x,ll1,ll2, ll1_, ll2_
      real :: dt1, lnTT_ref
      real :: del
      logical :: lzone=.false., lzone_left, lzone_right, lnoACTOS=.true.
!
          df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) &
               + 2.5e6/1005.*p%ccondens*p%TT1
!
!
! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_energy
!***********************************************************************
   subroutine special_calc_chemistry(f,df,p)
!
      use Cdata
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      integer :: l_sz
      integer :: j,  sz_l_x,sz_r_x,ll1,ll2,lll1,lll2
      real :: dt1, lnTT_ref
      real :: del
      logical :: lzone=.false., lzone_left, lzone_right
!

       dt1=1./(3.*dt)
       del=0.1
!
!
         lzone_left=.false.
         lzone_right=.false.
!
        if (lbuffer_zone_chem) then
        do j=1,2
         if (ind_H2O>0) lzone=.true.
         if ((j==1) .and. (x(l2)==xyz0(1)+Lxyz(1))) then
           sz_r_x=l2-int(del*nxgrid)
           ll1=sz_r_x;  ll2=l2
           lll1=ll1-3; lll2=ll2-3
           lzone_right=.true.
!              df(ll1:ll2,m,n,iuy)=  &
 !               df(ll1:ll2,m,n,iuy) &
 !              +(f(ll1:ll2,m,n,iuy) -0.)*dt1/5.
!
         elseif ((j==2) .and. ((x(l1)==xyz0(1)))) then
           sz_l_x=int(del*nxgrid)+l1
           ll1=l1;  ll2=sz_l_x
           lll1=ll1-3;  lll2=ll2-3
           lzone_left=.true.
!               df(ll1:ll2,m,n,iuy)=  &
!                df(ll1:ll2,m,n,iuy) &
!               +(f(ll1:ll2,m,n,iuy) -0.)*dt1
!
         endif
!
         if ((lzone .and. lzone_right)) then
!           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll2,ind_H2O)/p%pp(lll2))*dt1

!           df(ll1:ll2,m,n,ichemspec(ind_N2))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_N2)) &
!               +(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1:lll2))*dt1
!            df(ll1:ll2,m,n,iux)=  &
!                df(ll1:ll2,m,n,iux) &
!               +(f(ll1:ll2,m,n,iux) -2.)*dt1/4.
         endif
        if ((lzone .and. lzone_left)) then
          if (dYw==1) then
           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1)*dYw)*dt1
               -p%ppsf(lll1:lll2,ind_H2O)/pp_init)*dt1
!
          else
           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -p%ppsf(lll1,ind_H2O)/p%pp(lll1)*dYw)*dt1
          endif
!           df(ll1:ll2,m,n,ichemspec(ind_N2))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_N2)) &
!               +(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1:lll2))*dt1
!

!
         endif
!
        enddo
        endif
!
! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_chemistry
!***********************************************************************
    subroutine special_calc_pscalar(f,df,p)
!
     use Cdata
     use General, only: spline_integral
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      real, dimension (nx,ndustspec) :: f_tmp
      real, dimension (ndustspec) :: ff_tmp,ttt
      integer :: k,i
!
        if (lpscalar) then
           do i=1,nx
          do k=1,ndustspec
           ff_tmp(k)= (p%ppwater(i)-p%ppsf(i,k)) &
              *f(l1+i-1,m,n,ind(k))/dsize(k)
          enddo
!
           ttt= spline_integral(dsize,ff_tmp)
           ttt(ndustspec)=ttt(ndustspec)/(dsize(ndustspec)-dsize(1))
!
           df(l1+i-1,m,n,ilncc) = df(l1+i-1,m,n,ilncc) &
               - p%rho(i)/Ntot*(Dwater*m_w/Rgas/p%TT(i)/rho_w) &
               *ttt(ndustspec)
          enddo
!
        endif
!
    endsubroutine  special_calc_pscalar
!***********************************************************************
    subroutine special_boundconds(f,bc)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      type (boundary_condition) :: bc
!
!
!
      select case (bc%bcname)
         case ('stm')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_stream_x(f,-1, bc)
           case (iBC_X_BOT)
             call bc_stream_x(f,-1, bc)
         endselect
         bc%done=.true.
         case ('cou')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_cos_ux(f,bc)
           case (iBC_X_BOT)
             call bc_cos_ux(f,bc)
           case (iBC_Y_TOP)
             call bc_cos_uy(f,bc)
           case (iBC_Y_BOT)
             call bc_cos_uy(f,bc)
         endselect
         bc%done=.true.
         case ('aer')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_aerosol_x(f,bc)
           case (iBC_X_BOT)
             call bc_aerosol_x(f,bc)
           case (iBC_Y_TOP)
             call bc_aerosol_y(f,bc)
           case (iBC_Y_BOT)
             call bc_aerosol_y(f,bc)
         endselect
         bc%done=.true.
         case ('sat')
         select case (bc%location)
           case (iBC_X_BOT)
!             call bc_satur_x(f,bc)
         endselect
         bc%done=.true.
         case ('ffz')
         select case (bc%location)
           case (iBC_Z_BOT)
             call bc_file_z_special(f,bc)
           case (iBC_Z_TOP)
             call bc_file_z_special(f,bc)
         endselect
         bc%done=.true.
      endselect
!
    endsubroutine special_boundconds
!***********************************************************************
   subroutine special_after_timestep(f,df,dt_,llast)
!
!  Possibility to modify the f and df after df is updated.
!  Used for the Fargo shift, for instance.
!
!  27-nov-08/wlad: coded
!
!
      use General, only: spline_integral, spline

!      use Dustdensity
!
      logical, intent(in) :: llast
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      real, dimension(mx,my,mz,mvar), intent(inout) :: df
      real, intent(in) :: dt_
      integer :: k,i,i1,i2,i3
      integer :: j
      real, dimension (ndustspec) :: S,x2
!
      if (.not. ldustdensity_log) then
      do i1=l1,l2
      do i2=m1,m2
      do i3=n1,n2
!
         do k=1,ndustspec
          if (f(i1,i2,i3,ind(k))<1e-10) f(i1,i2,i3,ind(k))=1e-10
            if (ldcore) then
              do i=1, ndustspec0
                if (f(i1,i2,i3,idcj(k,i))<1) f(i1,i2,i3,idcj(k,i))=1.
              enddo
            endif
          enddo
!
      enddo
      enddo
      enddo
      endif
!
     if (lACTOS) then
       call dustspec_normalization_(f)
     endif
!
    endsubroutine  special_after_timestep
!***********************************************************************
    subroutine dustspec_normalization_(f)
!
!   20-sep-10/Natalia: coded
!   renormalization of the dust species
!   called in special_after_timestep
!
      use General, only: spline_integral
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (ndustspec) :: ff_tmp, ttt, ttt2
      integer :: k,i,i1,i2,i3
!
      do i3=n1,n2
      do i1=l1,l2
      do i2=m1,m2
!
        if (ldcore) then
!
         do k=1,ndustspec
             ff_tmp(k)=f(i1,i2,i3,ind(k))
         enddo
           ttt2= spline_integral(dsize,ff_tmp)*exp(f(i1,i2,i3,ilnrho))
        do i=1,ndustspec0
          do k=1,ndustspec
            ff_tmp(k)=f(i1,i2,i3,idcj(k,i))
          enddo
            ttt= spline_integral(dsize,ff_tmp)*exp(f(i1,i2,i3,ilnrho))
          do k=1,ndustspec
           Ntot_i(i)=Ntot/ndustspec0
           f(i1,i2,i3,idcj(k,i))=f(i1,i2,i3,idcj(k,i))*Ntot_i(i)/ttt(ndustspec)
!            f(i1,i2,i3,idcj(k,i))=f(i1,i2,i3,idcj(k,i)) &
!             *(ttt2(ndustspec)*dds0(i)/(dsize0_max-dsize0_min)) /ttt(ndustspec)
          enddo
        enddo
!
          do i=1,ndustspec0
          do k=1,ndustspec
!            f(i1,i2,i3,idcj(k,i))=f(i1,i2,i3,idcj(k,i)) &
!                   *Ntot_i(i)/(ttt(ndustspec)*dds0(i)/(dsize0_max-dsize0_min))
!
          enddo
          enddo
!
         do k=1,ndustspec
           f(i1,i2,i3,ind(k))=f(i1,i2,i3,ind(k))*Ntot/ttt2(ndustspec)
         enddo
 !
        elseif (lLES) then
          if (.not. ldustdensity_log) then
            do k=1,ndustspec
              ff_tmp(k)=f(i1,i2,i3,ind(k))
            enddo
              ttt= spline_integral(dsize,ff_tmp)*exp(f(i1,i2,i3,ilnrho))
            do k=1,ndustspec
              if (z(i3)>rotat_position) then
                f(i1,i2,i3,ind(k))=f(i1,i2,i3,ind(k))*0.2*Ntot/ttt(ndustspec)
              else
                f(i1,i2,i3,ind(k))=f(i1,i2,i3,ind(k))*Ntot/ttt(ndustspec)
              endif
            enddo
          endif
        else
          if (.not. ldustdensity_log) then
            do k=1,ndustspec
              ff_tmp(k)=f(i1,i2,i3,ind(k))
            enddo
              ttt= spline_integral(dsize,ff_tmp)*exp(f(i1,i2,i3,ilnrho))
            do k=1,ndustspec
              f(i1,i2,i3,ind(k))=f(i1,i2,i3,ind(k))*Ntot/ttt(ndustspec)
            enddo
          endif
!
       endif

      enddo
      enddo
      enddo
!
    endsubroutine dustspec_normalization_
!***********************************************************************
!-----------------------------------------------------------------------
!
!  PRIVATE UTITLITY ROUTINES
!
!***********************************************************************
   subroutine density_init(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
    endsubroutine density_init
!***************************************************************
    subroutine entropy_init(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      endsubroutine entropy_init
!***********************************************************************
      subroutine velocity_init(f)
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
    endsubroutine  velocity_init
!***********************************************************************
!   INITIAL CONDITIONS
!
!**************************************************************************
!       BOUNDARY CONDITIONS
!**************************************************************************
  subroutine bc_stream_x(f,sgn,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: sgn
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2, rad_2
      real, dimension (2) :: jet_center=0.
      real, dimension (my,mz) :: u_profile
!
      do jjj=1,my
      do kkk=1,mz
         rad_2=((y(jjj)-jet_center(1))**2+(z(kkk)-jet_center(1))**2)
         u_profile(jjj,kkk)=exp(-rad_2/sigma**2)
      enddo
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
      ! bottom boundary
        f(l1,m1:m2,n1:n2,vr) = value1*u_profile(m1:m2,n1:n2)
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)+sgn*f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
      ! top boundary
        f(l2,m1:m2,n1:n2,vr) = value2*u_profile(m1:m2,n1:n2)
        do i=1,nghost; f(l2+i,:,:,vr)=2*f(l2,:,:,vr)+sgn*f(l2-i,:,:,vr); enddo
      else
        print*, "bc_BL_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_stream_x
!********************************************************************
  subroutine bc_cos_ux(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2
      real, dimension (my,mz) :: u_profile
!
      do jjj=1,my
         u_profile(jjj,:)=cos(Period*PI*y(jjj)/Lxyz(2))
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
      ! bottom boundary
        f(l1,m1:m2,n1:n2,vr) = value1*u_profile(m1:m2,n1:n2)
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
      ! top boundary
        f(l2,m1:m2,n1:n2,vr) = value2*u_profile(m1:m2,n1:n2)
        do i=1,nghost; f(l2+i,:,:,vr)=2*f(l2,:,:,vr)-f(l2-i,:,:,vr); enddo
!
      else
        print*, "bc_cos_ux: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_cos_ux
!********************************************************************
 subroutine bc_cos_uy(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2
      real, dimension (mx,mz) :: u_profile
!
      do jjj=1,mx
         u_profile(jjj,:)=cos(Period*PI*x(jjj)/Lxyz(1))
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_Y_BOT) then
      ! bottom boundary
        f(l1:l2,m1,n1:n2,vr) = value1*u_profile(l1:l2,n1:n2)
        do i=0,nghost; f(:,m1-i,:,vr)=2*f(:,m1,:,vr)-f(:,m1+i,:,vr); enddo
      elseif (bc%location==iBC_Y_TOP) then
      ! top boundary
        f(l1:l2,m2,n1:n2,vr) = value2*u_profile(l1:l2,n1:n2)
        do i=1,nghost; f(:,m2+i,:,vr)=2*f(:,m2,:,vr)-f(:,m2-i,:,vr); enddo
      else
        print*, "bc_cos_uy: ", bc%location, " should be `top(", &
                        iBC_Y_TOP,")' or `bot(",iBC_Y_BOT,")'"
      endif
!
    endsubroutine bc_cos_uy
!********************************************************************
 subroutine bc_aerosol_x(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr,k
      integer :: jjj,kkk
      real :: value1, value2
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
! bottom boundary
        if (vr==ind(1)) then
          do k=1,ndustspec
            f(l1,m1:m2,n1:n2,ind(k))= init_distr(l1,k)
          enddo
          do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
        endif
      elseif (bc%location==iBC_X_TOP) then
! top boundary
        if (vr==ind(1)) then
!        f(l2+1,:,:,ind)=0.2   *(  9*f(l2,:,:,ind)-  4*f(l2-2,:,:,ind) &
!                       - 3*f(l2-3,:,:,ind)+ 3*f(l2-4,:,:,ind))
!        f(l2+2,:,:,ind)=0.2   *( 15*f(l2,:,:,ind)- 2*f(l2-1,:,:,ind)  &
!                 -  9*f(l2-2,:,:,ind)- 6*f(l2-3,:,:,ind)+ 7*f(l2-4,:,:,ind))
!        f(l2+3,:,:,ind)=1./35.*(157*f(l2,:,:,ind)-33*f(l2-1,:,:,ind)  &
!                       -108*f(l2-2,:,:,ind) -68*f(l2-3,:,:,ind)+87*f(l2-4,:,:,ind))
!
        do i=1,nghost; f(l2+i,:,:,ind)=2*f(l2,:,:,ind)-f(l2-i,:,:,ind); enddo
        endif
        if (vr==imd(1)) then
        f(l2+1,:,:,imd)=0.2   *(  9*f(l2,:,:,imd)-  4*f(l2-2,:,:,imd) &
                       - 3*f(l2-3,:,:,imd)+ 3*f(l2-4,:,:,imd))
        f(l2+2,:,:,imd)=0.2   *( 15*f(l2,:,:,imd)- 2*f(l2-1,:,:,imd)  &
                 -  9*f(l2-2,:,:,imd)- 6*f(l2-3,:,:,imd)+ 7*f(l2-4,:,:,imd))
        f(l2+3,:,:,imd)=1./35.*(157*f(l2,:,:,imd)-33*f(l2-1,:,:,imd)  &
                       -108*f(l2-2,:,:,imd) -68*f(l2-3,:,:,imd)+87*f(l2-4,:,:,imd))
        endif
      else
        print*, "bc_BL_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_aerosol_x
!********************************************************************
 subroutine bc_aerosol_y(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr,k,m1p1,m1p2,m1p3,m1p4,m2p1,m2p2,m2p3,m2p4
      integer :: jjj,kkk,m1m1,m1m2,m1m3,m1m4,m2m1,m2m2,m2m3,m2m4
      real :: value1, value2
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_Y_BOT) then
        m1m1=m1-1; m1m2=m1-2; m1m3=m1-3; m1m4=m1-4
        m1p1=m1+1; m1p2=m1+2; m1p3=m1+3; m1p4=m1+4
!
! bottom boundary
        if (vr>=iuud(1)+3) then

        f(:,m1m1,:,ind)=0.2   *(  9*f(:,m1,:,ind)-  4*f(:,m1p2,:,ind) &
                       - 3*f(:,m1p3,:,ind)+ 3*f(:,m1p4,:,ind))
        f(:,m1m2,:,ind)=0.2   *( 15*f(:,m1,:,ind)- 2*f(:,m1+1,:,ind)  &
                 -  9*f(:,m1p2,:,ind)- 6*f(:,m1p3,:,ind)+ 7*f(:,m1p4,:,ind))
        f(:,m1m3,:,ind)=1./35.*(157*f(:,m1,:,ind)-33*f(:,m1p1,:,ind)  &
                       -108*f(:,m1p2,:,ind) -68*f(:,m1p3,:,ind)+87*f(:,m1p4,:,ind))
        endif
        if (vr==iuud(1)+4) then
        f(:,m1m1,:,imd)=0.2   *(  9*f(:,m1,:,imd)-  4*f(:,m1p2,:,imd) &
                       - 3*f(:,m1p3,:,imd)+ 3*f(:,m1p4,:,imd))
        f(:,m1m2,:,imd)=0.2   *( 15*f(:,m1,:,imd)- 2*f(:,m1p1,:,imd)  &
                 -  9*f(:,m1p2,:,imd)- 6*f(:,m1p3,:,imd)+ 7*f(:,m1p4,:,imd))
        f(:,m1m3,:,imd)=1./35.*(157*f(:,m1,:,imd)-33*f(:,m1p1,:,imd)  &
                       -108*f(:,m1p2,:,imd) -68*f(:,m1p3,:,imd)+87*f(:,m1p4,:,imd))
        endif
      elseif (bc%location==iBC_Y_TOP) then
        m2m1=m2-1; m2m2=m2-2; m2m3=m2-3; m2m4=m2-4
        m2p1=m2+1; m2p2=m2+2; m2p3=m2+3; m2p4=m2+4
! top boundary
        if (vr>=iuud(1)+3) then
        f(:,m2p1,:,ind)=0.2   *(  9*f(:,m2,:,ind)-  4*f(:,m2m2,:,ind) &
                       - 3*f(:,m2m3,:,ind)+ 3*f(:,m2m4,:,ind))
        f(:,m2p2,:,ind)=0.2   *( 15*f(:,m2,:,ind)- 2*f(:,m2m1,:,ind)  &
                 -  9*f(:,m2m2,:,ind)- 6*f(:,m2m3,:,ind)+ 7*f(:,m2m4,:,ind))
        f(:,m2p3,:,ind)=1./35.*(157*f(:,m2,:,ind)-33*f(:,m2m1,:,ind)  &
                       -108*f(:,m2m2,:,ind) -68*f(:,m2m3,:,ind)+87*f(:,m2m4,:,ind))
        endif
        if (vr==iuud(1)+4) then
        f(:,m2p1,:,imd)=0.2   *(  9*f(:,m2,:,imd)-  4*f(:,m2m2,:,imd) &
                       - 3*f(:,m2m3,:,imd)+ 3*f(:,m2m4,:,imd))
        f(:,m2p2,:,imd)=0.2   *( 15*f(:,m2,:,imd)- 2*f(:,m2m1,:,imd)  &
                 -  9*f(:,m2m2,:,imd)- 6*f(:,m2m3,:,imd)+ 7*f(:,m2m4,:,imd))
        f(:,m2p3,:,imd)=1./35.*(157*f(:,m2,:,imd)-33*f(:,m2m1,:,imd)  &
                       -108*f(:,m2m2,:,imd) -68*f(:,m2m3,:,imd)+87*f(:,m2m4,:,imd))
        endif
      else
        print*, "bc_BL_y: ", bc%location, " should be `top(", &
                        iBC_Y_TOP,")' or `bot(",iBC_Y_BOT,")'"
      endif
!
    endsubroutine bc_aerosol_y
!********************************************************************
subroutine bc_satur_x(f,bc)
!
! Natalia
!
    use Cdata
    use Mpicomm, only: stop_it
!
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      real, dimension (my,mz) :: sum_Y, pp_sat
      integer :: i,j,vr,k, iter
      integer :: jjj,kkk
      real :: value1, value2, air_mass_1, air_mass_2
      real :: psat1, psat2, sum1, sum2, init_water_1, init_water_2
      real, dimension(nchemspec) :: init_Yk_1, init_Yk_2
      real :: psf_1, psf_2, T_tmp, tmp
      real ::  Rgas_loc=8.314472688702992E+7
      real :: aa0= 6.107799961, aa1= 4.436518521e-1
      real :: aa2= 1.428945805e-2, aa3= 2.650648471e-4
      real :: aa4= 3.031240396e-6, aa5= 2.034080948e-8, aa6= 6.136820929e-11
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
!
! bottom boundary
!
!
     call stop_it('something is wrong. check carefully')
!
     if ((vr==ichemspec(ind_H2O)) .or. (vr==ichemspec(ind_N2))) then
!
       do j=1,nchemspec
         init_Yk_1(j)=f(l1,m1,n1,ichemspec(j))
         init_Yk_2(j)=f(l1,m1,n1,ichemspec(j))
       enddo
!
!       psat1=6.035e12*exp(-5938./TT1)
!       psat2=6.035e12*exp(-5938./TT2)
!
         T_tmp=TT1-273.15
         psat1=(aa0 + aa1*T_tmp  + aa2*T_tmp**2  &
                  + aa3*T_tmp**3 + aa4*T_tmp**4  &
                  + aa5*T_tmp**5 + aa6*T_tmp**6)*1e3
         T_tmp=TT2-273.15
         psat2=(aa0 + aa1*T_tmp  + aa2*T_tmp**2  &
                  + aa3*T_tmp**3 + aa4*T_tmp**4  &
                  + aa5*T_tmp**5 + aa6*T_tmp**6)*1e3
!
      psf_1=psat1
      if (r0/=0.) then
       psf_2=psat2
      else
       psf_2=psat2
      endif
!
!
! Recalculation of the air_mass for different boundary conditions
!
!
!
!           air_mass_1=0
!           do k=1,nchemspec
!             air_mass_1=air_mass_1+init_Yk_1(k)/species_constants(k,imass)
!           enddo
!           air_mass_1=1./air_mass_1
!
!           air_mass_2=0
!           do k=1,nchemspec
!             air_mass_2=air_mass_2+init_Yk_2(k)/species_constants(k,imass)
!           enddo
!           air_mass_2=1./air_mass_2
        do iter=1,3
!
!
!           air_mass_2=0
!           do k=1,nchemspec
!             air_mass_2=air_mass_2+init_Yk_2(k)/species_constants(k,imass)
!           enddo
!           air_mass_2=1./air_mass_2
!
!           init_Yk_1(ind_H2O)=psf_1/(exp(f(l1,m1,n1,ilnrho))*Rgas_loc*TT1/18.)*dYw1
!           init_Yk_2(ind_H2O)=psf_2/(exp(f(l2,m2,n2,ilnrho))*Rgas_loc*TT2/18.)*dYw2
!
           init_Yk_1(ind_H2O)=psf_1/(PP*air_mass_1/18.)*dYw1
           init_Yk_2(ind_H2O)=psf_2/(PP*air_mass_2/18.)*dYw2
!
!
!
           sum1=0.
           sum2=0.
           do k=1,nchemspec
            if (k/=ind_N2) then
              sum1=sum1+init_Yk_1(k)
              sum2=sum2+init_Yk_2(k)
            endif
           enddo
!
           init_Yk_1(ind_N2)=1.-sum1
           init_Yk_2(ind_N2)=1.-sum2
!

!           tmp=0.
!           do k=1,nchemspec
!             tmp=tmp+init_Yk_1(k)/species_constants(k,imass)
!           enddo
!           air_mass_1=1./tmp
!
!           tmp=0.
!           do k=1,nchemspec
!             tmp=tmp+init_Yk_2(k)/species_constants(k,imass)
!           enddo
!           air_mass_2=1./tmp
!
!
!
!print*,'special', air_mass_1, init_Yk_1(ind_H2O), iter, vr, ichemspec(ind_H2O)
!
        enddo
!
           init_water_1=init_Yk_1(ind_H2O)
           init_water_2=init_Yk_2(ind_H2O)
!
! End of Recalculation of the air_mass for different boundary conditions
!
        endif
!
        if (vr==ichemspec(ind_H2O)) then
          f(l1,:,:,ichemspec(ind_H2O))=init_water_1
        elseif (vr==ichemspec(ind_N2)) then
          f(l1,:,:,ichemspec(ind_N2))=init_Yk_1(ind_N2)
        elseif ((vr>=ind(1)) .and. (vr<=ind(ndustspec))) then
!
      do k=1,ndustspec
           f(l1,:,:,ind(k))=Ntot/0.856E-03/(2.*pi)**0.5/dsize(k)/alog(delta) &
              *exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))
          enddo
        endif
!
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
! top boundary
!
      else
        print*, "bc_satur_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_satur_x
!********************************************************************
    subroutine special_before_boundary(f)
!
!   Possibility to modify the f array before the boundaries are
!   communicated.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-jul-06/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine special_before_boundary
!
!********************************************************************
   subroutine set_init_parameters(Ntot_,dsize,init_distr, init_distr2)
!

     use General, only:  spline, spline_integral

      real, dimension (ndustspec), intent(out) :: dsize, init_distr2
      real, dimension (mx,ndustspec), intent(out) :: init_distr
      real, dimension (ndustspec) ::  lnds, ttt
      real, dimension (9) ::  X,Y
      real, dimension (5) ::  X_tmp, Y_tmp
       real, dimension (1) ::   x2, s
       real, dimension (6) ::   coeff
       real, dimension (76) :: nd_data,dsize_data
      integer :: i,k
      real :: ddsize, tmp
      real, intent(out) :: Ntot_
 !
       ddsize=(alog(dsize_max)-alog(dsize_min))/(ndustspec-1)
       do i=0,(ndustspec-1)
         lnds(i+1)=alog(dsize_min)+i*ddsize
         dsize(i+1)=exp(lnds(i+1))
       enddo
!
       if (lACTOS) then
         nd_data=[339.575456246242, 720.208321148821, 2286.01480884891, 3839.39274704826, &
                5864.54364319772, 8239.59202946498, 10855.9261236828, 13505.8296100921, &
                15262.5613594914, 15896.5311592612, 15796.9043080092, 14853.4889078194, &
                 13255.369567693, 11726.7023256169, 10552.7448431257, 9307.63526706903, &
                8118.26518966436, 6995.10946318942, 5993.02856284546, 5118.37064523768, &
                4422.52904252487, 3935.96466660051, 3634.6812081956,  3477.07759947373, &
                3440.23195994515, 3475.40440559785, 3587.70531563689, 3744.91042045072, &
                3945.87051285192, 4171.46609214788, 4403.32906429245, 4572.73561968173, &
                4636.88643983139, 4521.1517139183,  4214.20219111043, 3779.45689610094, &
                3250.07494170188, 2696.02268576671, 2212.75051547427, 1839.06586003548, &
                1548.51189457816, 1347.16729619229, 1220.06504500019, 1137.13466917878, &
                1082.84686635548, 1049.87624011505, 1031.03087444599, 1014.65981960217, &
                   993.711611277, 968.016439185171, 942.248672049366,  916.81477658502, &
                886.310990911619, 851.143047833488, 809.803333732227, 759.646150955402, &
                 690.48152050471, 617.249743920501,   540.8694284355, 455.712062357517, &
                380.996905959608, 70.8851122528869, 83.3072413129704, 74.3453450822443, &
                72.6488698200733,  61.894807937821,  47.697600795739, 36.9683158893019, &
                27.8160000556516, 16.0116934313036,  10.575710375307, 7.62746384792302, &
                4.37655374527983, 2.21561698388422, 1.92235157186522, 0.654667507529657]

         dsize_data=[5.43, 5.77, 6.14, 6.54, 6.96, 7.4, 7.88, 8.38, 8.92, 9.49, 10.1, 10.75, &
               11.44, 12.17, 12.95, 13.78, 14.67, 15.61, 16.61, 17.68, 18.81, 20.02, 21.3, 22.67,&
               24.12, 25.67, 27.32, 29.07, 30.93, 32.92, 35.03, 37.27, 39.66, 42.21, 44.92, 47.8, &
               50.86, 54.13, 57.6, 61.29, 65.22, 69.41, 73.86, 78.6, 83.64, 89., 94.71, 100.79,&
               107.25, 114.13, 121.45, 129.24, 137.53, 146.35, 155.74, 165.73, 176.36, 187.67,&
               199.71, 212.52, 226.15, 304.42, 356.429, 417.324, 488.622, 572.102, 669.844, 784.284,&
               918.276, 1075.161, 1258.848, 1473.918, 1725.732, 2020.567, 2365.775, 2769.959]
!
         nd_data=nd_data*Ntot_ratio
         dsize_data=dsize_data*1e-7/2.
!
           do k=1,ndustspec
             do i=2,76
               if ((dsize(k)>=dsize_data(i-1)) .and. (dsize(k)<dsize_data(i))) then
                 init_distr2(k)=((nd_data(i)-nd_data(i-1))&
                          /(dsize_data(i)-dsize_data(i-1))*(dsize(k)-dsize_data(i-1))+nd_data(i-1))/dsize(k)
               endif
             enddo
               init_distr(:,k)=init_distr2(k)
           enddo
!
           if (llarge_part) then
             do k=1,ndustspec
               init_distr(:,k)= 31.1443*exp(-0.5*((2.*dsize(k)/1e-4-17.6595)/6.25204)**2)-0.0349555
             enddo
           elseif (lsmall_part) then
             do k=1,ndustspec
               init_distr(:,k)= Ntot/(2.*pi)**0.5/dsize(k)/alog(delta) &
                      * exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))
             enddo
           elseif (lsmall_large_part) then
             do k=1,ndustspec
               init_distr(:,k)= 31.1443*exp(-0.5*((2.*dsize(k)/1e-4-17.6595)/6.25204)**2)-0.0349555
               init_distr(:,k)=init_distr(:,k) &
                         + Ntot/(2.*pi)**0.5/dsize(k)/alog(delta) &
                      * exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))
             enddo
           elseif (llognormal) then
             if ((r0 /= 0.) .and. (delta /=0.) .and. (Ntot_input /=0.)) then
               do k=1,ndustspec
                  init_distr(:,k)=Ntot_input/(2.*pi)**0.5/dsize(k)/alog(delta) &
                     *exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))!+0.0001
                 init_distr2(k)=Ntot_input/(2.*pi)**0.5/dsize(k)/alog(delta) &
                     *exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))
               enddo
             endif
           endif
!
!  no ACTOS
!
       else
         if (r0 /= 0.) then
           do k=1,ndustspec
             init_distr(:,k)=Ntot/(2.*pi)**0.5/dsize(k)/alog(delta) &
                 *exp(-(alog(2.*dsize(k))-alog(2.*r0))**2/(2.*(alog(delta))**2))!+0.0001
           enddo
         endif
       endif
!
        if (lACTOS) then
            ttt=spline_integral(dsize,init_distr2)
            Ntot_=ttt(ndustspec)
            Ntot =Ntot_
            print*,'Ntot=',Ntot
        else
          Ntot_=Ntot
        endif
!
     endsubroutine set_init_parameters
!***********************************************************************
    subroutine bc_file_z_special(f,bc)

       use Cdata
!
      type (boundary_condition) :: bc
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension(64), save :: bc_T_array_bot, bc_u_array_bot
      real, dimension(64), save :: bc_T_array_top, bc_u_array_top
      real, dimension(64), save :: bc_qv_array_bot
      real, dimension (66) :: tmp, tmp2, tmp3
      real, dimension (60)  :: time_top, time_bot
      integer :: i,j,ii,statio_code,vr, i1,i2, io_code, stat
      integer ::  ll1,ll2,mm1,mm2
      integer :: time_position_top, time_position_bot
      real ::  bc_T_aver_top, bc_u_aver_top, bc_T_aver2_top, bc_u_aver2_top
      real ::  bc_T_aver_bot, bc_u_aver_bot, bc_T_aver2_bot, bc_u_aver2_bot
      real ::  bc_qv_aver_bot,  bc_qv_aver2_bot
      real ::  bc_T_aver_final, bc_u_aver_final, bc_qv_aver_final
      real :: lbc,frac, ttt, bc_T_final_top, bc_u_final_top
      logical, save :: lbc_file_top=.true., lbc_file_bot=.true.
      real :: t1,t2, pp_tmp
!
!   'NNNNNN
!      if (lroot) then
      do i = 1,60
        time_bot(i)=(i-1)*1800.
        time_top(i)=(i-1)*7200.
      enddo

!      endif


      vr=bc%ivar
!
     if (bc%location==iBC_Z_BOT) then

       do i = 1,60
!
         t1=time_bot(i)
         t2=time_bot(i+1)
         if ((t>=t1) .and. (t<t2)) then
           time_position_bot=i
         endif
!        if (t>=time_top(i)) .and. (t<time_top(i+1)) then
!          time_position=i
!        endif
!
       enddo
!
        if (lbc_file_bot) then
!          if (lroot) then
!
            print*,'opening *1.dat'
            open(9,file='T1.dat')
            open(99,file='w1.dat')
            open(999,file='qv.dat')
!
            do i = 1,37
             read(9,*,iostat=io_code) (tmp(ii),ii=1,2)
             read(99,*,iostat=io_code) (tmp2(ii),ii=1,2)
             read(999,*,iostat=io_code) (tmp3(ii),ii=1,2)
             bc_T_array_bot(i)=tmp(2)
             bc_u_array_bot(i)=tmp2(2)
             bc_qv_array_bot(i)=tmp3(2)
            enddo
!
            close(9)
            close(99)
            close(999)
            print*,'closing file'
!          endif
          lbc_file_bot=.false.
        endif
!
           do i = 1,37
            if (i==time_position_bot) then
              bc_T_aver_bot=bc_T_array_bot(i)
              bc_u_aver_bot=bc_u_array_bot(i)
              bc_qv_aver_bot=bc_qv_array_bot(i)
              bc_T_aver2_bot=bc_T_array_bot(i+1)
              bc_u_aver2_bot=bc_u_array_bot(i+1)
              bc_qv_aver2_bot=bc_qv_array_bot(i+1)
            endif
           enddo
!
!      print*,'time_position_bot=', time_position_bot, time_bot(time_position_bot)
!      print*, bc_T_aver_bot, bc_T_aver2_bot
!
         bc_T_aver_final=bc_T_aver_bot  &
                +(t-time_bot(time_position_bot)) &
                /(time_bot(time_position_bot+1)-time_bot(time_position_bot))    &
                *(bc_T_aver2_bot-bc_T_aver_bot)

!           bc_T_aver_final=bc_T_aver_bot

         bc_u_aver_final=bc_u_aver_bot  &
               +(t-time_bot(time_position_bot)) &
               /(time_bot(time_position_bot+1)-time_bot(time_position_bot))    &
               *(bc_u_aver2_bot-bc_u_aver_bot)


         bc_qv_aver_final=bc_qv_aver_bot  &
               +(t-time_bot(time_position_bot)) &
               /(time_bot(time_position_bot+1)-time_bot(time_position_bot))    &
               *(bc_qv_aver2_bot-bc_qv_aver_bot)

!

!    print*,time_bot(time_position_bot-1),t,time_bot(time_position_bot)
!    print*, bc_T_aver_bot,bc_T_aver_final, bc_T_aver2_bot

       if (vr==ilnTT) then
!
          ll1=(x(l1)-xyz0(1))/dx+1
          ll2=(x(l2)-xyz0(1))/dx+1
          mm1=(y(m1)-xyz0(2))/dy+1
          mm2=(y(m2)-xyz0(2))/dy+1
!
          do j=l1,l2
            i2=ll1+j-4
          do i=m1,m2
            i1=mm1+i-4
!             pp_tmp=bc_T_aver_final*exp(f(j,i,n1,ilnrho))*8.31e7/29.
            f(j,i,n1,vr)=alog(bc_T_aver_final  &
                 +T_ampl*sin(Period*PI*x(j)/Lxyz(1))*cos(Period*PI*y(j)/Lxyz(2)))
!             f(j,i,n1,vr)=alog(bc_T_aver_final*(1e6/pp_tmp)**0.286)
          enddo
          enddo
!
          do i=1,nghost; f(:,:,n1-i,vr)=2*f(:,:,n1,vr)-f(:,:,n1+i,vr); enddo
!

        elseif (vr==ichemspec(ind_H2O)) then
!
          do j=l1,l2
          do i=m1,m2
            f(j,i,n1,vr)=bc_qv_aver_final
          enddo
          enddo

          do i=1,nghost; f(:,:,n1-i,vr)=2*f(:,:,n1,vr)-f(:,:,n1+i,vr); enddo
!
        elseif (vr==iuz) then
!
           ll1=(x(l1)-xyz0(1))/dx+1
           ll2=(x(l2)-xyz0(1))/dx+1
           mm1=(y(m1)-xyz0(2))/dy+1
           mm2=(y(m2)-xyz0(2))/dy+1
!
           do j=l1,l2
           do i=m1,m2
!              f(j,i,n1,vr)=bc_u_aver_final &
!                  *bc_T_aver_final/exp(f(j,i,n1,ilnTT))

           if (nxgrid>1) then
               f(j,i,n1,vr)=sin(Period*PI*x(j)/Lxyz(1))*uz_bc
           else
             f(j,i,n1,vr)=bc_u_aver_final*bc_T_aver_final/exp(f(j,i,n1,ilnTT))
           endif

           enddo
           enddo
!
!     print*, bc_T_x_adopt(ll1,mm1),bc_T_x_adopt(ll2,mm1)
!
          do i=1,nghost; f(:,:,n1-i,vr)=2*f(:,:,n1,vr)-f(:,:,n1+i,vr); enddo
      elseif (vr==iux) then
!
           ll1=(x(l1)-xyz0(1))/dx+1
           ll2=(x(l2)-xyz0(1))/dx+1
           mm1=(y(m1)-xyz0(2))/dy+1
           mm2=(y(m2)-xyz0(2))/dy+1
!
           do j=l1,l2
           do i=m1,m2
               f(j,i,n1,vr)=10.*bc_T_aver_final/exp(f(j,i,n1,ilnTT))
           enddo
           enddo
!
          do i=1,nghost; f(:,:,n1-i,vr)=2*f(:,:,n1,vr)-f(:,:,n1+i,vr); enddo
        elseif (vr==iuy) then
!
           ll1=(x(l1)-xyz0(1))/dx+1
           ll2=(x(l2)-xyz0(1))/dx+1
           mm1=(y(m1)-xyz0(2))/dy+1
           mm2=(y(m2)-xyz0(2))/dy+1
!
           do j=l1,l2
           do i=m1,m2
              f(j,i,n1,vr)=10.*bc_T_aver_final/exp(f(j,i,n1,ilnTT))
           enddo
           enddo
!
          do i=1,nghost; f(:,:,n1-i,vr)=2*f(:,:,n1,vr)-f(:,:,n1+i,vr); enddo
!
        endif
      elseif (bc%location==iBC_Z_TOP) then
!
       do i = 1,60
         t1=time_top(i)
         t2=time_top(i+1)
         if ((t>=t1) .and. (t<t2)) then
           time_position_top=i
         endif
       enddo
!
       if (lbc_file_top) then
!       if (lroot) then
!
         print*,'opening *_top.dat'
         open(9,file='T_top.dat')
         open(99,file='w_top.dat')
!
         do i = 1,37
           read(9,*,iostat=io_code) (tmp(ii),ii=1,2)
           read(99,*,iostat=io_code) (tmp2(ii),ii=1,2)
           bc_T_array_top(i)=tmp(2)
           bc_u_array_top(i)=tmp2(2)
         enddo
!
          close(9)
          close(99)
          print*,'closing file'

!       endif
        lbc_file_top=.false.
!
       endif
!
          do i = 1,37
            if (i==time_position_top) then
              bc_T_aver_top=bc_T_array_top(i)
              bc_u_aver_top=bc_u_array_top(i)
              bc_T_aver2_top=bc_T_array_top(i+1)
              bc_u_aver2_top=bc_u_array_top(i+1)
            endif
           enddo
!
        bc_T_final_top=bc_T_aver_top  &
               +(t-time_top(time_position_top)) &
               /(time_top(time_position_top+1)-time_top(time_position_top))    &
               *(bc_T_aver2_top-bc_T_aver_top)
!
        bc_u_final_top=bc_u_aver_top  &
               +(t-time_top(time_position_top)) &
               /(time_top(time_position_top+1)-time_top(time_position_top))    &
               *(bc_u_aver2_top-bc_u_aver_top)

!    print*, time_position_top
!    print*,time_top(time_position_top-1),t,time_top(time_position_top)
!    print*, bc_T_aver_top,bc_T_final_top, bc_T_aver2_top
!
!
       if (vr==ilnTT) then
!
          ll1=(x(l1)-xyz0(1))/dx+1
          ll2=(x(l2)-xyz0(1))/dx+1
          mm1=(y(m1)-xyz0(2))/dy+1
          mm2=(y(m2)-xyz0(2))/dy+1
!
          do j=l1,l2
            i2=ll1+j-4
          do i=m1,m2
            i1=mm1+i-4
            f(j,i,n2,vr)=alog(bc_T_final_top)
          enddo
          enddo

!          print*,'bc_T_aver_top=',bc_T_aver_top
!
          do i=1,nghost; f(:,:,n2+i,vr)=2*f(:,:,n2,vr)-f(:,:,n2-i,vr); enddo
!
        elseif (vr==iuz) then
!
           ll1=(x(l1)-xyz0(1))/dx+1
           ll2=(x(l2)-xyz0(1))/dx+1
           mm1=(y(m1)-xyz0(2))/dy+1
           mm2=(y(m2)-xyz0(2))/dy+1
!
           do j=l1,l2
           do i=m1,m2
!            f(j,i,n2,vr)=bc_u_final_top*bc_T_final_top/exp(f(j,i,n2,ilnTT))
!            f(j,i,n2,vr)=2481.*bc_T_final_top/exp(f(j,i,n2,ilnTT))

            if (nxgrid>1) then
              f(j,i,n2,vr)=sin(Period*PI*x(j)/Lxyz(1))*uz_bc
            endif
!
           enddo
           enddo

!
!     print*, bc_T_x_adopt(ll1,mm1),bc_T_x_adopt(ll2,mm1)
!
          do i=1,nghost; f(:,:,n2+i,vr)=2*f(:,:,n2,vr)-f(:,:,n2-i,vr); enddo
        endif
!
      else
      endif
    endsubroutine bc_file_z_special
!***********************************************************************
!********************************************************************
!
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include '../special_dummies.inc'
!********************************************************************
!
endmodule Special

! $Id: cosmicray_nolog.f90 19193 2012-06-30 12:55:46Z wdobler $
!
!  This modules solves the cosmic ray energy density equation.
!  It follows the description of Hanasz & Lesch (2002,2003) as used in their
!  ZEUS 3D implementation.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lcosmicray = .true.
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED ecr; ecr1; gecr(3); ugecr; bgecr; bglnrho
!
!***************************************************************
module Cosmicray
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages
!
  implicit none
!
  include 'cosmicray.h'
!
  character (len=labellen) :: initecr='zero', initecr2='zero'
!
  real :: gammacr=4./3.,gammacr1, Jcr_param=0.
  real :: amplecr=.1,widthecr=.5,ecr_min=0.,ecr_const=0.
  real :: x_pos_cr=.0,y_pos_cr=.0,z_pos_cr=.0
  real :: x_pos_cr2=.0,y_pos_cr2=.0,z_pos_cr2=.0,ampl_Qcr2=0.
  real :: amplecr2=0.,kx_ecr=1.,ky_ecr=1.,kz_ecr=1.,radius_ecr=1.,epsilon_ecr=0.
  logical :: lnegl = .false.
  logical :: lvariable_tensor_diff = .false.
  logical :: lalfven_advect = .false.
!
  namelist /cosmicray_init_pars/ &
       initecr,initecr2,amplecr,amplecr2,kx_ecr,ky_ecr,kz_ecr, &
       radius_ecr,epsilon_ecr,widthecr,ecr_const, &
       gammacr, lnegl, lvariable_tensor_diff,x_pos_cr,y_pos_cr,z_pos_cr, &
       x_pos_cr2, y_pos_cr2, z_pos_cr2
!
  real :: cosmicray_diff=0., Kperp=0., Kpara=0., ampl_Qcr=0.
  real :: limiter_cr=1.,blimiter_cr=0.
  logical :: simplified_cosmicray_tensor=.false.
  logical :: luse_diff_constants = .false.
!
  namelist /cosmicray_run_pars/ &
       cosmicray_diff,Kperp,Kpara, &
       gammacr,simplified_cosmicray_tensor,lnegl,lvariable_tensor_diff, &
       luse_diff_constants,ampl_Qcr,ampl_Qcr2, &
       limiter_cr,blimiter_cr, &
       lalfven_advect
!
  integer :: idiag_ecrm=0,idiag_ecrmax=0,idiag_ecrpt=0
  integer :: idiag_ecrdivum=0
  integer :: idiag_kmax=0
!
  contains
!
!***********************************************************************
    subroutine register_cosmicray()
!
!  Initialise variables which should know that we solve for active
!  scalar: iecr - the cosmic ray energy density; increase nvar accordingly
!
!  09-oct-03/tony: coded
!
      use FArrayManager
!
      call farray_register_pde('ecr',iecr)
!
!  Identify version number.
!
      if (lroot) call svn_id( &
          "$Id: cosmicray_nolog.f90 19193 2012-06-30 12:55:46Z wdobler $")
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',ecr $'
          if (nvar == mvar) write(4,*) ',ecr'
        else
          write(4,*) ',ecr $'
        endif
        write(15,*) 'ecr = fltarr(mx,my,mz)*one'
      endif
!
    endsubroutine register_cosmicray
!***********************************************************************
    subroutine initialize_cosmicray(f)
!
!  Perform any necessary post-parameter read initialization
!  Dummy routine
!
!  09-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
!  initialize gammacr1
!
      gammacr1=gammacr-1.
      if (lroot) print*,'gammacr1=',gammacr1
!
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_cosmicray
!***********************************************************************
    subroutine init_ecr(f)
!
!  initialise cosmic ray energy density field; called from start.f90
!
!   09-oct-03/tony: coded
!
      use Mpicomm
      use Sub
      use Initcond
      use InitialCondition, only: initial_condition_ecr
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      select case (initecr)
        case ('zero'); f(:,:,:,iecr)=0.
        case ('constant'); f(:,:,:,iecr)=ecr_const
        case ('const_ecr'); f(:,:,:,iecr)=ecr_const
        case ('blob'); call blob(amplecr,f,iecr,radius_ecr,x_pos_cr,y_pos_cr,0.)
        case ('gaussian-x'); call gaussian(amplecr,f,iecr,kx=kx_ecr)
        case ('gaussian-y'); call gaussian(amplecr,f,iecr,ky=ky_ecr)
        case ('gaussian-z'); call gaussian(amplecr,f,iecr,kz=kz_ecr)
        case ('parabola-x'); call parabola(amplecr,f,iecr,kx=kx_ecr)
        case ('parabola-y'); call parabola(amplecr,f,iecr,ky=ky_ecr)
        case ('parabola-z'); call parabola(amplecr,f,iecr,kz=kz_ecr)
        case ('gaussian-noise'); call gaunoise(amplecr,f,iecr,iecr)
        case ('wave-x'); call wave(amplecr,f,iecr,kx=kx_ecr)
        case ('wave-y'); call wave(amplecr,f,iecr,ky=ky_ecr)
        case ('wave-z'); call wave(amplecr,f,iecr,kz=kz_ecr)
        case ('propto-ux'); call wave_uu(amplecr,f,iecr,kx=kx_ecr)
        case ('propto-uy'); call wave_uu(amplecr,f,iecr,ky=ky_ecr)
        case ('propto-uz'); call wave_uu(amplecr,f,iecr,kz=kz_ecr)
        case ('tang-discont-z')
          print*,'init_ecr: widthecr=',widthecr
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iecr)=-1.+2.*0.5*(1.+tanh(z(n)/widthecr))
          enddo; enddo
        case ('hor-tube'); call htube2(amplecr,f,iecr,iecr,radius_ecr,epsilon_ecr)
        case default; call stop_it('init_ecr: bad initecr='//trim(initecr))
      endselect
!
!  superimpose something else
!
      select case (initecr2)
        case ('wave-x'); call wave(amplecr2,f,iecr,kx=kx_ecr)
        case ('wave-y'); call wave(amplecr2,f,iecr,ky=ky_ecr)
        case ('wave-z'); call wave(amplecr2,f,iecr,kz=kz_ecr)
        case ('constant'); f(:,:,:,iecr)=f(:,:,:,iecr)+ecr_const
        case ('blob2'); call blob(amplecr,f,iecr,radius_ecr,x_pos_cr2,y_pos_cr2,0.)
      endselect
!
!  Interface for user's own initial condition
!
      if (linitial_condition) call initial_condition_ecr(f)
!
    endsubroutine init_ecr
!***********************************************************************
    subroutine pencil_criteria_cosmicray()
!
!  The current module's criteria for which pencils are needed
!
!  20-nov-04/anders: coded
!
      lpenc_requested(i_ecr)=.true.
      lpenc_requested(i_ugecr)=.true.
      lpenc_requested(i_divucr)=.true.
      lpenc_diagnos(i_ecr)=.true.
!
    endsubroutine pencil_criteria_cosmicray
!***********************************************************************
    subroutine pencil_interdep_cosmicray(lpencil_in)
!
!  Set all pencils that input pencil array depends on.
!  The most basic pencils should come last (since other pencils chosen
!  here because of dependence may depend on more basic pencils).
!
!  20-11-04/anders: coded
!
      use EquationOfState, only: gamma_m1
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_ugecr)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_gecr)=.true.
      endif
      if (lpencil_in(i_bgecr)) then
        lpencil_in(i_bb)=.true.
        lpencil_in(i_gecr)=.true.
      endif
      if (lpencil_in(i_bglnrho)) then
        lpencil_in(i_bb)=.true.
        lpencil_in(i_glnrho)=.true.
      endif
!
    endsubroutine pencil_interdep_cosmicray
!***********************************************************************
    subroutine calc_pencils_cosmicray(f,p)
!
!  Calculate cosmicray pencils
!
!  20-11-04/anders: coded
!
      use EquationOfState, only: gamma,gamma_m1,cs20,lnrho0
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
! ecr
      if (lpencil(i_ecr)) p%ecr=f(l1:l2,m,n,iecr)
! ecr1
      if (lpencil(i_ecr1)) p%ecr1=1./f(l1:l2,m,n,iecr)
! gecr
      if (lpencil(i_gecr)) call grad(f,iecr,p%gecr)
! ugecr
      if (lpencil(i_ugecr)) call dot_mn(p%uu,p%gecr,p%ugecr)
!
    endsubroutine calc_pencils_cosmicray
!***********************************************************************
    subroutine decr_dt(f,df,p)
!
!  cosmic ray evolution
!  calculate decr/dt + div(u.ecr - flux) = -pcr*divu = -(gammacr-1)*ecr*divu
!  solve as decr/dt + u.grad(ecr) = -gammacr*ecr*divu + div(flux)
!  add du = ... - (1/rho)*grad(pcr) to momentum equation
!  Alternatively, use w
!
!   09-oct-03/tony: coded
!
      use Diagnostics
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      integer :: j
!
      intent (in) :: f,p
      intent (out) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'SOLVE decr_dt'
      if (headtt) call identify_bcs('ecr',iecr)
!
!  tensor diffusion, or, alternatively scalar diffusion or no diffusion
!
      if (lcosmicrayflux)then
        df(l1:l2,m,n,iecr) = df(l1:l2,m,n,iecr) - p%ecr*p%divucr - p%ugecr
      else
        call fatal_error('cosmicray','must have lcosmicrayflux')
      endif
!
!  diagnostics
!
!  output for double and triple correlators (assume z-gradient of cc)
!  <u_k u_j d_j c> = <u_k c uu.gradecr>
!
      if (ldiagnos) then
        if (idiag_ecrdivum/=0) call sum_mn_name(p%ecr*p%divu,idiag_ecrdivum)
        if (idiag_ecrm/=0) call sum_mn_name(p%ecr,idiag_ecrm)
        if (idiag_ecrmax/=0) call max_mn_name(p%ecr,idiag_ecrmax)
        if (idiag_ecrpt/=0) call save_name(p%ecr(lpoint-nghost),idiag_ecrpt)
      endif
!
    endsubroutine decr_dt
!***********************************************************************
    subroutine read_cosmicray_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=cosmicray_init_pars, IOSTAT=iostat)
!
    endsubroutine read_cosmicray_init_pars
!***********************************************************************
    subroutine write_cosmicray_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=cosmicray_init_pars)
!
    endsubroutine write_cosmicray_init_pars
!***********************************************************************
    subroutine read_cosmicray_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=cosmicray_run_pars, IOSTAT=iostat)
!
    endsubroutine read_cosmicray_run_pars
!***********************************************************************
    subroutine write_cosmicray_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=cosmicray_run_pars)
!
    endsubroutine write_cosmicray_run_pars
!***********************************************************************
    subroutine rprint_cosmicray(lreset,lwrite)
!
!  reads and registers print parameters relevant for cosmic rays
!
!   6-jul-02/axel: coded
!
      use Diagnostics
      use FArrayManager, only: farray_index_append
!
      integer :: iname,inamez
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_ecrm=0; idiag_ecrdivum=0; idiag_ecrmax=0; idiag_kmax=0
        idiag_ecrpt=0
        cformv=''
      endif
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'ecrm',idiag_ecrm)
        call parse_name(iname,cname(iname),cform(iname),&
            'ecrdivum',idiag_ecrdivum)
        call parse_name(iname,cname(iname),cform(iname),'ecrmax',idiag_ecrmax)
        call parse_name(iname,cname(iname),cform(iname),'ecrpt',idiag_ecrpt)
        call parse_name(iname,cname(iname),cform(iname),'kmax',idiag_kmax)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
!        call parse_name(inamez,cnamez(inamez),cformz(inamez),'ecrmz',idiag_ecrmz)
      enddo
!
!  check for those quantities for which we want video slices
!
      if (lwrite_slices) then
        where(cnamev=='ecr') cformv='DEFINED'
      endif
!
!  write column where which cosmic ray variable is stored
!
      if (lwr) then
        call farray_index_append('iecr',iecr)
      endif
!
    endsubroutine rprint_cosmicray
!***********************************************************************
    subroutine get_slices_cosmicray(f,slices)
!
!  Write slices for animation of Cosmicray variables.
!
!  26-jul-06/tony: coded
!
      use Slices_methods, only: assign_slices_scal
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
!  Loop over slices
!
      select case (trim(slices%name))
!
!  Cosmic ray energy density.
!
        case ('ecr'); call assign_slices_scal(slices,f,iecr)
!
      endselect
!
    endsubroutine get_slices_cosmicray
!***********************************************************************
    subroutine impose_ecr_floor(f)
!
!  dummy routine
!
!  29-jun-15/axel: adapted from cosmicray.f90
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine impose_ecr_floor
!***********************************************************************
endmodule Cosmicray

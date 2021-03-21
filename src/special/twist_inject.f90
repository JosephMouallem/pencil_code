! $Id$
!
!  This module provide a way for users to specify custom
!  (i.e. not in the standard Pencil Code) physics, diagnostics etc.
!
!  The module provides a set of standard hooks into the Pencil-Code and
!  currently allows the following customizations:
!
!  Description                                     | Relevant function call
!  ---------------------------------------------------------------------------
!  Special variable registration                   | register_special
!    (pre parameter read)                          |
!  Special variable initialization                 | initialize_special
!    (post parameter read)                         |
!  Special variable finalization                   | finalize_special
!    (deallocation, etc.)                          |
!                                                  |
!  Special initial condition                       | init_special
!   this is called last so may be used to modify   |
!   the mvar variables declared by this module     |
!   or optionally modify any of the other f array  |
!   variables.  The latter, however, should be     |
!   avoided where ever possible.                   |
!                                                  |
!  Special term in the mass (density) equation     | special_calc_density
!  Special term in the momentum (hydro) equation   | special_calc_hydro
!  Special term in the entropy equation            | special_calc_entropy
!  Special term in the induction (magnetic)        | special_calc_magnetic
!     equation                                     |
!                                                  |
!  Special equation                                | dspecial_dt
!    NOT IMPLEMENTED FULLY YET - HOOKS NOT PLACED INTO THE PENCIL-CODE
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of special_dummies.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 1
!
!***************************************************************
!
! HOW TO USE THIS FILE
! --------------------
!
! Change the line above to
!   lspecial = .true.
! to enable use of special hooks.
!
! The rest of this file may be used as a template for your own
! special module.  Lines which are double commented are intended
! as examples of code.  Simply fill out the prototypes for the
! features you want to use.
!
! Save the file with a meaningful name, eg. geo_kws.f90 and place
! it in the $PENCIL_HOME/src/special directory.  This path has
! been created to allow users ot optionally check their contributions
! in to the Pencil-Code SVN repository.  This may be useful if you
! are working on/using the additional physics with somebodyelse or
! may require some assistance from one of the main Pencil-Code team.
!
! To use your additional physics code edit the Makefile.local in
! the src directory under the run directory in which you wish to
! use your additional physics.  Add a line with all the module
! selections to say something like:
!
!   SPECIAL=special/geo_kws
!
! Where geo_kws it replaced by the filename of your new module
! upto and not including the .f90
!
module Special
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages, only: svn_id, fatal_error
!
  implicit none
!
  include '../special.h'
!
  real :: fring=0.0d0,r0=0.2,tilt=0.0,width=0.02,&
          dIring=0.0,dposx=0.0,dposz=0.0,dtilt=0.0,Ilimit=0.15,poslimit=0.98
  real :: posy=0.0,alpha=1.25
  real, save :: posx,posz,Iring
  integer :: nwid=1,nwid2=1,nlf=4
  logical :: lset_boundary_emf=.false.,lupin=.false.
  real, dimension (mx) :: x12,dx12
  namelist /special_run_pars/ Iring,dIring,fring,r0,width,nwid,nwid2,&
           posx,dposx,posy,posz,dposz,tilt,dtilt,Ilimit,poslimit,&
           lset_boundary_emf,lupin,nlf
!
! Declare index of new variables in f array (if any).
!
!!   integer :: ispecial=0
   integer :: ispecaux=0
!
!! Diagnostic variables (needs to be consistent with reset list below).
!
   integer :: idiag_posx=0,idiag_Iring=0,idiag_posz=0
!
  contains
!***********************************************************************
    subroutine register_special()
!
!  Set up indices for variables in special modules.
!
!  6-oct-03/tony: coded
!
      use FArrayManager
      if (lroot) call svn_id( &
           "$Id$")
!!
!      if (ldensity.and..not.ldensity_nolog) &
!      call farray_register_auxiliary('specaux',ispecaux)
!!      call farray_register_pde('special',ispecial)
!!      call farray_register_auxiliary('specaux',ispecaux,communicated=.true.)
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f)
!
!  Called after reading parameters, but before the time loop.
!
!  06-oct-03/tony: coded
!
      use Sub, only: gij,curl_mn
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx,3) :: aa,pbb
      real, dimension(nx,3,3) :: aij
      real, dimension(3) :: tmpv,vv,uu,bb,uxb
      integer :: i
!!
!! x[l1:l2]+0.5/dx_1[l1:l2]-0.25*dx_tilde[l1:l2]/dx_1[l1:l2]^2
!!
!      dx12=0.0
!      if (lrun) then
!        if (lroot) print*,'initialize_special: Set up half grid x12, y12, z12'
!!
!        x12     =x+0.5/dx_1-0.25*dx_tilde/dx_1**2
!        dx12(l1-2:l2+2) =x12(l1-1:l2+3)-x12(l1-2:l2+2)   
!        f(:,:,:,ispecaux)=0.0d0
!        do n=n1,n2
!          do m=m1,m2
!            call gij(f,iaa,aij,1)
!! bb
!            call curl_mn(aij,pbb,aa)
!            f(l1:l2,m,n,ibx  :ibz  )=pbb
!          enddo
!        enddo
!      else
      call keep_compiler_quiet(f)
!!
!      endif
!!
    endsubroutine initialize_special
!***********************************************************************
    subroutine finalize_special(f)
!
!  Called right before exiting.
!
!  14-aug-2011/Bourdin.KIS: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine finalize_special
!***********************************************************************
    subroutine init_special(f)
!
!  initialise special condition; called from start.f90
!  06-oct-2003/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      intent(inout) :: f
!!
!!  SAMPLE IMPLEMENTATION
!!
!!      select case (initspecial)
!!        case ('nothing'); if (lroot) print*,'init_special: nothing'
!!        case ('zero', '0'); f(:,:,:,iSPECIAL_VARIABLE_INDEX) = 0.
!!        case default
!!          call fatal_error("init_special: No such value for initspecial:" &
!!              ,trim(initspecial))
!!      endselect
!
      call keep_compiler_quiet(f)
!
    endsubroutine init_special
!***********************************************************************
    subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
      lpenc_requested(i_y_mn)=.true.
    endsubroutine pencil_criteria_special
!***********************************************************************
    subroutine pencil_interdep_special(lpencil_in)
!
!  Interdependency among pencils provided by this module are specified here.
!
!  18-07-06/tony: coded
!
      logical, dimension(npencils), intent(inout) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_special
!***********************************************************************
    subroutine calc_pencils_special(f,p)
!
!  Calculate Special pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  24-nov-04/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_special
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
!  Several precalculated Pencils of information are passed for
!  efficiency.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent(in) :: f,p
      intent(inout) :: df
!
!  Identify module and boundary conditions.
!
      if (headtt.or.ldebug) print*,'dspecial_dt: SOLVE dspecial_dt'
!!      if (headtt) call identify_bcs('special',ispecial)
!
!!
!! SAMPLE DIAGNOSTIC IMPLEMENTATION
!!
!!      if (ldiagnos) then
!!        if (idiag_SPECIAL_DIAGNOSTIC/=0) then
!!          call sum_mn_name(MATHEMATICAL EXPRESSION,idiag_SPECIAL_DIAGNOSTIC)
!!! see also integrate_mn_name
!!        endif
!!      endif
!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine dspecial_dt
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
!  Reads and registers print parameters relevant to special.
!
!  06-oct-03/tony: coded
!
      use Diagnostics
      use FArrayManager, only: farray_index_append
!
      integer :: iname
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
        idiag_posx=0
        idiag_posz=0
        idiag_Iring=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),&
            'posx',idiag_posx)
        call parse_name(iname,cname(iname),cform(iname),&
            'posz',idiag_posz)
        call parse_name(iname,cname(iname),cform(iname),&
            'Iring',idiag_Iring)
      enddo
!  write column where which magnetic variable is stored
      if (lwr) then
        call farray_index_append('idiag_posx',idiag_posx)
        call farray_index_append('idiag_posz',idiag_posz)
        call farray_index_append('idiag_Iring',idiag_Iring)
      endif
!!
    endsubroutine rprint_special
!***********************************************************************
    subroutine get_slices_special(f,slices)
!
!  Write slices for animation of Special variables.
!
!  26-jun-06/tony: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices%ready)
!
    endsubroutine get_slices_special
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  momentum equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  continuity equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      real, dimension (nx) :: fdiff
      type (pencil_case), intent(in) :: p
!
      if (ispecaux/=0) then
      if (headtt) print*,'special_calc_density: call div_diff_flux'
      if (ldensity_nolog) then
        call div_diff_flux(f,irho,p,fdiff)
        if (lfirst_proc_x.and.lfrozen_bot_var_x(irho)) then
!
!  Density is frozen at boundary
!
          df(l1+1:l2,m,n,irho) = df(l1+1:l2,m,n,irho) + fdiff(2:nx)
        else
          df(l1:l2,m,n,irho) = df(l1:l2,m,n,irho) + fdiff
        endif
      else
!
! Store the diffusive flux in a special aux array to be added later to
! log-density in special_after_timestep
!
        call div_diff_flux(f,ilnrho,p,fdiff)
        if (lfirst_proc_x.and.lfrozen_bot_var_x(ilnrho)) then
          f(l1,m,n,ispecaux) = 0.0
          f(l1+1:l2,m,n,ispecaux) = fdiff(2:nx)
        else
          f(l1:l2,m,n,ispecaux) = fdiff
        endif
      endif
      endif
    
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_dustdensity(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  continuity equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,ilnrho) = df(l1:l2,m,n,ilnrho) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_dustdensity
!***********************************************************************
    subroutine special_calc_entropy(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  entropy equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,ient) = df(l1:l2,m,n,ient) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_entropy
!***********************************************************************
    subroutine special_calc_magnetic(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  induction equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_magnetic
!***********************************************************************
    subroutine special_calc_pscalar(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  passive scalar equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array.
!
!  15-jun-09/anders: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,ilncc) = df(l1:l2,m,n,ilncc) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_pscalar
!***********************************************************************
    subroutine special_calc_particles(fp)
!
!  Called before the loop, in case some particle value is needed
!  for the special density/hydro/magnetic/entropy.
!
!  20-nov-08/wlad: coded
!
      real, dimension (:,:), intent(in) :: fp
!
      call keep_compiler_quiet(fp)
!
    endsubroutine special_calc_particles
!***********************************************************************
    subroutine special_calc_chemistry(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  induction equation.
!
!
!  15-sep-10/natalia: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!!
!!  SAMPLE IMPLEMENTATION (remember one must ALWAYS add to df).
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_chemistry
!***********************************************************************
    subroutine special_before_boundary(f)
!
!  Possibility to modify the f array before the boundaries are
!  communicated.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array
!
!  06-jul-06/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine special_before_boundary
!***********************************************************************
    subroutine special_boundconds(f,bc)
!
!  Some precalculated pencils of data are passed in for efficiency,
!  others may be calculated directly from the f array.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      character (len=3) :: topbot
      type (boundary_condition), intent(inout) :: bc
      integer :: j
!
      select case (bc%bcname)
      case ('nfc')
      j=bc%ivar
        select case (bc%location)
        case (iBC_X_TOP)
          topbot='top'
          call bc_nfc_x(f,topbot,j)
      bc%done=.true.
        case (iBC_X_BOT)
          topbot='bot'
          call bc_nfc_x(f,topbot,j)
      bc%done=.true.
        end select
      case ('go')
      j=bc%ivar
        select case (bc%location)
        case (iBC_X_TOP)
          topbot='top'
          call bc_go_x(f,topbot,j)
      bc%done=.true.
        case (iBC_X_BOT)
          topbot='bot'
          call bc_go_x(f,topbot,j)
      bc%done=.true.
        end select
      end select

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
      use Deriv, only: der
      use EquationOfState, only: cs0, rho0, get_cp1,gamma,gamma_m1
      use Mpicomm, only: mpibcast_double,mpibcast_logical
      use Diagnostics, only: save_name
      use Sub, only: cross,gij,curl_mn
!
      logical, intent(in) :: llast
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      real, dimension(mx,my,mz,mvar), intent(inout) :: df
      real, intent(in) :: dt_
      real, dimension(mx,my,mz):: rho_tmp
      real, dimension(nx) :: dfy,dfz
      real, dimension (nx,3) :: aa,pbb
      real, dimension(nx,3,3) :: aij
      real, dimension(3) :: tmpv,vv,uu,bb,uxb
      real :: xi,xx0,yy0,zz0,xx1,yy1,zz1,dist,distxy,distyz,phi,rr,r1,&
              prof,ymid,zmid,umax,cs2,rho_corr,cp1
      real :: tmpx,tmpy,tmpz,posxold,Iringold,poszold
      logical :: lring=.true.
      integer :: l,k,ig
!
!  IMPLEMENTATION OF INSERTION OF BIPOLES (Non-Potential part)
!  (Yeates, Mackay and van Ballegooijen 2008, Sol. Phys, 247, 103)
!
      ymid=0.5*(xyz0(2)+xyz1(2))
      zmid=0.5*(xyz0(3)+xyz1(3))
      if (lroot) then
        posxold=posx
        poszold=posz
        Iringold=Iring
        if (posxold.gt.poslimit) dposx=0.0
        if (poszold.gt.poslimit) dposz=0.0
        if (Iringold.gt.Ilimit) dIring=0.0
        if (lupin.and.(posxold.gt.1.0)) lring=.false.
        posx=posx+dposx*dt_
        posz=posz+dposz*dt_
        Iring=Iring+dIring*dt_
        tilt=tilt+dtilt*dt_
      endif
      call mpibcast_double(posxold)
      call mpibcast_double(posx)
      call mpibcast_double(dposx)
      call mpibcast_double(poszold)
      call mpibcast_double(posz)
      call mpibcast_double(dposz)
      call mpibcast_double(Iringold)
      call mpibcast_double(Iring)
      call mpibcast_double(dIring)
      call mpibcast_logical(lring)
      if (ldiagnos) then
        if (idiag_posx/=0) &
          call save_name(posx,idiag_posx)
        if (idiag_Iring/=0) &
          call save_name(Iring,idiag_Iring)
        if (idiag_posz/=0) &
          call save_name(posz,idiag_posz)
      endif
      call get_cp1(cp1)
!
      if (lfirst_proc_z.and.lcartesian_coords) then
        n=n1
        do m=m1,m2
          yy0=y(m)
          do l=l1,l2 
            xx0=x(l)
              do ig=0,nghost
                zz0=z(n1-ig)
          ! Calculate D^(-1)*(xxx-disp)
                zz1=zz0-posz
                xx1=cos(tilt*pi/180.0)*(xx0-posx)+sin(tilt*pi/180.0)*(yy0-posy)
                yy1=-sin(tilt*pi/180.0)*(xx0-posx)+cos(tilt*pi/180.0)*(yy0-posy)
                if (dposz.ne.0) then
! Set up new ring
                    call norm_ring(xx1,yy1,zz1,fring,Iring,r0,width,nwid,tmpv,PROFILE='gaussian')
            ! calculate D*tmpv
                  bb(1)=cos(tilt*pi/180.0)*tmpv(1)-sin(tilt*pi/180.0)*tmpv(2)
                  bb(2)=sin(tilt*pi/180.0)*tmpv(1)+cos(tilt*pi/180.0)*tmpv(2)
                  bb(3)=tmpv(3)
          ! Calculate D^(-1)*(xxx-disp)
                  if (lring) then
                    distyz=sqrt((sqrt(xx1**2+zz1**2)-r0)**2+yy1**2)
                  else
                    if (zz1.gt.0) then
                      distyz=sqrt((sqrt(xx1**2+zz1**2)-r0)**2+yy1**2)
                    else
                      distyz=sqrt((sqrt(xx1**2+(zz0-xyz0(3))**2)-r0)**2+yy1**2)
                    endif
                  endif
                  if (distyz.lt.nwid2*width) then
                    vv(1)=0.0
                    vv(2)=0.0
                    vv(3)=dposz
!                    cs2=cs0**2*(exp(gamma*f(l1,m1,n1,iss)*cp1+gamma_m1*(f(l1,m1,n1,ilnrho)-alog(rho0))))
!                    rho_corr=1.-0.5*(bb(1)**2+bb(2)**2+bb(3)**2)*mu01*gamma/(exp(f(l1,m1,n1,ilnrho))*cs2)
!                    rho_corr=1.0
!                    f(l,m,n1-ig,ilnrho)=f(l1,m1,n1-ig,ilnrho)+alog(rho_corr)
!
! make tube buoyant? Add density deficit at bottom boundary
!
                  else
                    vv=0.0
                  endif
                  uu(1)=cos(tilt*pi/180.0)*vv(1)-sin(tilt*pi/180.0)*vv(2)
                  uu(2)=sin(tilt*pi/180.0)*vv(1)+cos(tilt*pi/180.0)*vv(2)
                  uu(3)=vv(3)
!
! Uniform translation velocity for induction equation at boundary
!
                    
                  if (iuu.ne.0) then 
                    if (distyz.lt.nwid2*width) then
                      f(l,m,n1-ig,iux) = uu(1)  
                      f(l,m,n1-ig,iuy) = uu(2)  
                      f(l,m,n1-ig,iuz) = uu(3)  
!                      if (ig.eq.0) print*, l,m,uu(3)
                    else 
                      call set_hydrostatic_velocity(f,dt_,l,m,ig)
                    endif
                  endif
                  call cross(uu,bb,uxb)
                  f(l,m,n1-ig,iax:iaz)=f(l,m,n1-ig,iax:iaz)+uxb(1:3)*dt_
!                  if (ig.eq.0.and.maxval(abs(uxb))>tini) print*, l,m,uxb(1),uxb(2),uxb(3)
                else
                  if (iuu.ne.0) call set_hydrostatic_velocity(f,dt_,l,m,ig)
                endif

              enddo
          enddo
        enddo
        if (lset_boundary_emf) then
          do m=m1,m2
            call bc_emf_z(f,df,dt_,'top',iax)
            call bc_emf_z(f,df,dt_,'top',iay)
            call bc_emf_z(f,df,dt_,'top',iaz)
          enddo
        endif
      else
! 
        if (lfirst_proc_x.and.lspherical_coords) then
          do n=n1,n2
            do m=m1,m2
!
!  Then set up the helical field
!
              call gij(f,iaa,aij,1)
! bb
              call curl_mn(aij,pbb,aa)
              f(l1:l2,m,n,ibx  :ibz  )=pbb
              do ig=0,nghost
                xx0=x(l1-ig)*sinth(m)*cos(z(n))
                yy0=x(l1-ig)*sinth(m)*sin(z(n))
                zz0=x(l1-ig)*costh(m)
          ! Calculate D^(-1)*(xxx-disp)
                xx1=xx0-posx
                yy1=cos(tilt*pi/180.0)*(yy0-posy)+sin(tilt*pi/180.0)*(zz0-posz)
                zz1=-sin(tilt*pi/180.0)*(yy0-posy)+cos(tilt*pi/180.0)*(zz0-posz)
                if (dposx.ne.0.or.dtilt.ne.0) then
                  dist=sqrt(xx0**2+yy0**2+zz0**2)
                  distxy=sqrt(xx0**2+yy0**2)
! Set up new ring
                  if (lring) then
                    call norm_ring(xx1,yy1,zz1,fring,Iring,r0,width,nwid,tmpv,PROFILE='gaussian')
                  else
                    call norm_upin(xx1,yy1,zz1,fring,Iring,r0,width,nwid,tmpv,PROFILE='gaussian')
                  endif
            ! calculate D*tmpv
                  tmpx=tmpv(1)
                  tmpy=cos(tilt*pi/180.0)*tmpv(2)-sin(tilt*pi/180.0)*tmpv(3)
                  tmpz=sin(tilt*pi/180.0)*tmpv(2)+cos(tilt*pi/180.0)*tmpv(3)
                  bb(1)=(xx0*tmpx/dist+yy0*tmpy/dist+zz0*tmpz/dist)
                  bb(2)= (xx0*zz0*tmpx/(dist*distxy)+yy0*zz0*tmpy/(dist*distxy) &
                      -distxy*tmpz/dist)
                  bb(3) = (-yy0*tmpx/distxy+xx0*tmpy/distxy)
                endif
!
                if (iuu.ne.0) then
                  if (dposx.ne.0) then
          ! Calculate D^(-1)*(xxx-disp)
                    if (lring) then
                      distyz=sqrt((sqrt(xx1**2+yy1**2)-r0)**2+zz1**2)
                    else
                      if (xx1.gt.0.0) then
                        distyz=sqrt((sqrt(xx1**2+yy1**2)-r0)**2+zz1**2)
                      else
                        distyz=sqrt((sqrt((xx0-1.0d0)**2+yy1**2)-r0)**2+zz1**2)
                      endif
                    endif
                    if (distyz.lt.nwid2*width) then
                      vv(1)=dposx
                      vv(2)=0.0
                      vv(3)=0.0
                    else
                      vv=0.0
                    endif
                    tmpx=vv(1)
                    tmpy=cos(tilt*pi/180.0)*vv(2)-sin(tilt*pi/180.0)*vv(3)
                    tmpz=sin(tilt*pi/180.0)*vv(2)+cos(tilt*pi/180.0)*vv(3)
                    f(l1-ig,m,n,iux) = (xx0*tmpx/dist+yy0*tmpy/dist+zz0*tmpz/dist)
                    f(l1-ig,m,n,iuy) = (xx0*zz0*tmpx/(dist*distxy)+yy0*zz0*tmpy/(dist*distxy) &
                        -distxy*tmpz/dist)
                    f(l1-ig,m,n,iuz) = (-yy0*tmpx/distxy+xx0*tmpy/distxy)
                  else if (dIring.eq.0.0.and.dposx.eq.0) then
                      f(l1-ig,m,n,iux:iuz)=0.0
                  endif
                endif
!
! Uniform translation velocity for induction equation at boundary
!
                if (dposx.ne.0) then
                  vv(1)=dposx
                  vv(2)=0.0
                  vv(3)=0.0
                  tmpx=vv(1)
                  tmpy=cos(tilt*pi/180.0)*vv(2)-sin(tilt*pi/180.0)*vv(3)
                  tmpz=sin(tilt*pi/180.0)*vv(2)+cos(tilt*pi/180.0)*vv(3)
                  uu(1) = (xx0*tmpx/dist+yy0*tmpy/dist+zz0*tmpz/dist)
                  uu(2) = (xx0*zz0*tmpx/(dist*distxy)+yy0*zz0*tmpy/(dist*distxy) &
                        -distxy*tmpz/dist)
                  uu(3) = (-yy0*tmpx/distxy+xx0*tmpy/distxy)
                  call cross(uu,bb,uxb)
                  f(l1-ig,m,n,iax:iaz)=f(l1-ig,m,n,iax:iaz)+uxb(1:3)*dt_
                else
                  uu=0.0
                endif
              enddo
!
            enddo
          enddo
!
!  Add slope limted diffusive flux to log density
!
!          if (.not.ldensity_nolog) then
!            rho_tmp(l1:l2,m1:m2,n1:n2)=exp(f(l1:l2,m1:m2,n1:n2,ilnrho))+f(l1:l2,m1:m2,n1:n2,ispecaux)*dt_
!            f(l1:l2,m1:m2,n1:n2,ilnrho)=log(rho_tmp(l1:l2,m1:m2,n1:n2))
!          endif
        endif
        if (lset_boundary_emf) then
          do m=m1,m2
            do n=n1,n2
              call bc_emf_x(f,df,dt_,'top',iax)
              call bc_emf_x(f,df,dt_,'top',iay)
              call bc_emf_x(f,df,dt_,'top',iaz)
            enddo
          enddo
        endif
      endif
!
    endsubroutine  special_after_timestep
!***********************************************************************
    subroutine norm_ring(xx1,yy1,zz1,fring,Iring,r0,width,nwid,vv,profile)
!
!  Generate vector potential for a flux ring of magnetic flux FRING,
!  current Iring (not correctly normalized), radius R0 and thickness
!  WIDTH in normal orientation (lying in the x-y plane, centred at (0,0,0)).
!
!   1-may-02/wolf: coded (see the manual, Section C.3)
!   7-jun-09/axel: added gaussian and constant (or box) profiles
!
      use Mpicomm, only: stop_it
      use Sub, only: erfunc
!
      real, dimension (3) :: vv,uu
      real :: xx1,yy1,zz1,phi,tmp,pomega
      real :: fring,Iring,r0,width,br,bphi
      integer :: nwid
      character (len=*) :: profile
!
!  magnetic ring, define r-R
!
      if (lcartesian_coords) then
        tmp = sqrt(xx1**2+zz1**2)-r0
        pomega=sqrt(tmp**2+yy1**2)
        phi = atan2(xx1,zz1)
      else if (lspherical_coords) then
        tmp = sqrt(xx1**2+yy1**2)-r0
        pomega=sqrt(tmp**2+zz1**2)
        phi = atan2(yy1,xx1)
      endif
!
!  choice of different profile functions
!
      select case (profile)
!
!  gaussian profile, exp(-.5*(x/w)^2)/(sqrt(2*pi)*eps),
!  so its derivative is .5*(1.+erf(-x/(sqrt(2)*eps))
!
      case ('gaussian')
            if (pomega.lt.nwid*width) then
              if (lcartesian_coords) then
                br=Iring*fring*yy1*exp(-(pomega/width)**2)/(tmp+r0)
                bphi=width*fring/(tmp+r0)*exp(-(pomega/width)**2)
                uu(1) =  cos(phi)*br-sin(phi)*bphi
                uu(2) =  sin(phi)*br+cos(phi)*bphi
                uu(3) =  -Iring*fring*( & 
                       tmp/(tmp+r0))*exp(-(pomega/width)**2)
! Not
! Rotate about x axis by 90 deg, y-> z and z-> -y
!
                vv(1) =  sin(phi)*br+cos(phi)*bphi
                vv(2) =  -Iring*fring*( & 
                       tmp/(tmp+r0))*exp(-(pomega/width)**2)
                vv(3) =  cos(phi)*br-sin(phi)*bphi
              else if (lspherical_coords) then
                br=Iring*fring*zz1*exp(-(pomega/width)**2)/(tmp+r0)
                bphi=width*fring/(tmp+r0)*exp(-(pomega/width)**2)
                vv(1) =  cos(phi)*br-sin(phi)*bphi
                vv(2) =  sin(phi)*br+cos(phi)*bphi
                vv(3) =  -Iring*fring*( & 
                       tmp/(tmp+r0))*exp(-(pomega/width)**2)
              endif  
            else
                vv(1)=0.0
                vv(2)=0.0
                vv(3)=0.0
            endif
      case default
        call stop_it('norm_ring: No such fluxtube profile')
      endselect
!
    endsubroutine norm_ring
!***********************************************************************
    subroutine norm_upin(xx1,yy1,zz1,fring,Iring,r0,width,nwid,vv,profile)
!
!  Generate vector potential for a flux ring of magnetic flux FRING,
!  current Iring , radius R0 and thickness
!  WIDTH in normal orientation (lying in the x-y plane, centred at (0,0,0)).
!
!   1-may-02/wolf: coded (see the manual, Section C.3)
!   7-jun-09/axel: added gaussian and constant (or box) profiles
!
      use Mpicomm, only: stop_it
      use Sub, only: erfunc
!
      real, dimension (3) :: vv
      real :: xx1,yy1,zz1,phi,tmp,pomega
      real :: fring,Iring,r0,width,br,bphi
      integer :: nwid
      character (len=*) :: profile
!
!  magnetic ring, define r-R
!
      tmp = sqrt(yy1**2)-r0
      pomega=sqrt(tmp**2+zz1**2)
      if (yy1.ge.0)  then
        phi = pi/2
      else
        phi=3*pi/2
      endif
!
!  choice of different profile functions
!
      select case (profile)
!
!  gaussian profile, exp(-.5*(x/w)^2)/(sqrt(2*pi)*eps),
!  so its derivative is .5*(1.+erf(-x/(sqrt(2)*eps))
!
      case ('gaussian')
            if (pomega.lt.nwid*width) then
              br=Iring*fring*zz1*exp(-(pomega/width)**2)/abs(yy1)
              bphi=width*fring/(tmp+r0)*exp(-(pomega/width)**2)
              vv(1) =  cos(phi)*br-sin(phi)*bphi
              vv(2) =  sin(phi)*br+cos(phi)*bphi
              vv(3) =  -Iring*fring*exp(-(pomega/width)**2)*(tmp/abs(yy1)+width**2/(2*yy1**2))
            else
              vv(1)=0.0
              vv(2)=0.0
              vv(3)=0.0
            endif
      case default
        call stop_it('norm_upin: No such fluxtube profile')
      endselect
!
    endsubroutine norm_upin
!***********************************************************************
    subroutine find_umax(f,umax)
!
!  Find the absolute maximum of the velocity.
!
!  19-aug-2011/ccyang: coded
!  13-sep-2012/piyali: Added this routine from hydro since
!  initial_condition cannot use
!  the hydro module because of Makefile.depend
!
      use Mpicomm, only: mpiallreduce_max, MPI_COMM_WORLD
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, intent(out) :: umax
!
      real :: umax1
!
!  Find the maximum.
!
      umax1 = sqrt(maxval(f(l1,m1:m2,n1:n2,iux)**2 &
                        + f(l1,m1:m2,n1:n2,iuy)**2 &
                        + f(l1,m1:m2,n1:n2,iuz)**2))
      call mpiallreduce_max(umax1, umax, comm=MPI_COMM_WORLD)
!
    endsubroutine find_umax
!***********************************************************************
    subroutine bc_nfc_x(f,topbot,j)
!
!  Normal-field (or angry-hedgehog) boundary condition for spherical
!  coordinate system.
!  d_r(A_{\theta}) = -A_{\theta}/r  with A_r = 0 sets B_{r} to zero
!  in spherical coordinate system.
!  (compare with next subroutine sfree )
!
!  25-Aug-2012/piyali: adapted from bc_set_nfr_x
!
      character (len=bclen), intent (in) :: topbot
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      real, dimension(3,3) :: mat
      real, dimension(3) :: rhs
      real :: x2,x3
      integer, intent (in) :: j
      integer :: k
!
      select case (topbot)
!
      case ('bot')               ! bottom boundary
        do k=1,nghost
          if (lfirst_proc_x) &
          f(l1-k,:,:,j)= f(l1+k,:,:,j)*(x(l1+k)/x(l1-k))
        enddo
!
     case ('top')               ! top boundary
       if (llast_proc_x) then
         x2=x(l2+1)
         x3=x(l2+2)
         do m=m1, m2
           do n=n1,n2
             mat(1,1:3)=[2*x2*(60*dx+197*x3),x2*(60*dx+167*x3),-(6*x2*x3)]/ &
                       (7500*dx*x2+10020*dx*x3+24475*x2*x3+3600*dx**2)
!
             mat(2,1:3)=[-10*x3*(12*dx+x2), 120*x2*x3, x3*(12*dx+25*x2)]/ &
                       (1500*dx*x2+2004*dx*x3+4895*x2*x3+720*dx**2)
!
             mat(3,1:3)=[420*dx*x2+924*dx*x3+1259*x2*x3+720*dx**2,   &
                       -(9*x2*(60*dx+47*x3)), 9*x3*(12*dx+31*x2)]/ &
                       (1500*dx*x2+2004*dx*x3+4895*x2*x3+720*dx**2)
!
             rhs(1)=-f(l2,m,n,j)*60*dx/x(l2)+45*f(l2-1,m,n,j)-9*f(l2-2,m,n,j)+f(l2-3,m,n,j)
             rhs(2)=f(l2,m,n,j)*80-30*f(l2-1,m,n,j)+8*f(l2-2,m,n,j)-f(l2-3,m,n,j)
             rhs(3)=-f(l2,m,n,j)*100+50*f(l2-1,m,n,j)-15*f(l2-2,m,n,j)+2*f(l2-3,m,n,j)
             f(l2+1:l2+3,m,n,j)=matmul(mat,rhs)
           enddo
         enddo
       endif

!
      case default
        print*, "bc_nfc_x: ", topbot, " should be 'top' or 'bot'"
!
      endselect
!
    endsubroutine bc_nfc_x
!***********************************************************************
    subroutine bc_emf_x(f,df,dt_,topbot,j)
!
      character (len=bclen), intent (in) :: topbot
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      real, dimension (mx,my,mz,mvar), intent(in) :: df
      real, intent(in) :: dt_
      integer, intent (in) :: j
      integer :: i
      select case (topbot)
!
      case ('bot')               ! bottom boundary
        print*, "bc_emf_x: ", topbot, " should be 'top'"
      case ('top')               ! top boundary
        if (llast_proc_x) then
          do i=1,nghost
            f(l2+i,m,n,j)=f(l2+i,m,n,j)+df(l2,m,n,j)*dt_ 
          enddo
        endif
      
      case default
        print*, "bc_emf_x: ", topbot, " should be 'top'"
      endselect
    endsubroutine bc_emf_x
!***********************************************************************
    subroutine bc_emf_z(f,df,dt_,topbot,j)
!
      character (len=bclen), intent (in) :: topbot
      real, dimension (mx,my,mz,mfarray), intent (inout) :: f
      real, dimension (mx,my,mz,mvar), intent(in) :: df
      real, intent(in) :: dt_
      integer, intent (in) :: j
      integer :: i
      select case (topbot)
!
      case ('bot')               ! bottom boundary
        print*, "bc_emf_z: ", topbot, " should be 'top'"
      case ('top')               ! top boundary
        if (llast_proc_z) then
          do i=1,nghost
            f(l1:l2,m,n2+i,j)=f(l1:l2,m,n2+i,j)+df(l1:l2,m,n2,j)*dt_ 
          enddo
        endif
      
      case default
        print*, "bc_emf_z: ", topbot, " should be 'top'"
      endselect
!
    endsubroutine bc_emf_z
!***********************************************************************
    subroutine set_hydrostatic_velocity(f,dt_,l,m,ig)
!
! vz=(-dP/dz/rho-gravz)*dt_
!
      use EquationOfState, only: cs0, rho0, get_cp1,gamma,gamma_m1
      use Gravity, only: gravz
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, intent(in) :: dt_
      integer, intent(in) :: l,m,ig
      real :: Pres_p1,Pres_m1,cp1
!
!
      call get_cp1(cp1)
!
      if (ig.lt.3) then
        Pres_p1=cs0**2*(exp(gamma*f(l,m,n1-ig+1,iss)*cp1+gamma*&
                   (f(l,m,n1-ig+1,ilnrho)-alog(rho0))))/gamma
        Pres_m1=cs0**2*(exp(gamma*f(l,m,n1-ig-1,iss)*cp1+gamma*&
                   (f(l,m,n1-ig-1,ilnrho)-alog(rho0))))/gamma
        f(l,m,n1-ig,iuz)=((Pres_m1-Pres_p1)*dz_1(n1-ig)/exp(f(l,m,n1-ig,ilnrho))+gravz)*dt_
        if (f(l,m,n1,iuz) < 0) then 
          call bc_sym_z(f,l,m,iux,ig,+1,'bot')
          call bc_sym_z(f,l,m,iuy,ig,+1,'bot')
        else
          call bc_sym_z(f,l,m,iux,ig,-1,'bot')
          call bc_sym_z(f,l,m,iuy,ig,-1,'bot')
        endif
      endif
!
    endsubroutine set_hydrostatic_velocity
!***********************************************************************
    subroutine bc_sym_z(f,l,m,j,i,sgn,topbot,rel)
!
!  Symmetry boundary conditions.
!  (f,-1,topbot,j)            --> antisymmetry             (f  =0)
!  (f,+1,topbot,j)            --> symmetry                 (f' =0)
!  (f,-1,topbot,j,REL=.true.) --> generalized antisymmetry (f''=0)
!  Don't combine rel=T and sgn=1, that wouldn't make much sense.
!
!  11-nov-02/wolf: coded
!  10-apr-05/axel: added val argument
!
      character (len=bclen) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: sgn,i,j,l,m
      logical, optional :: rel
      logical :: relative
!
      if (present(rel)) then; relative=rel; else; relative=.false.; endif
!
      select case (topbot)
!
      case ('bot')               ! bottom boundary
        if (relative) then
          f(l,m,n1-i,j)=2*f(l,m,n1,j)+sgn*f(l,m,n1+i,j)
        else
          f(l,m,n1-i,j)=              sgn*f(l,m,n1+i,j)
          if (sgn<0) f(l,m,n1,j) = 0. ! set bdry value=0 (indep of initcond)
        endif
!
      case ('top')               ! top boundary
        if (relative) then
          f(l,m,n2+i,j)=2*f(l,m,n2,j)+sgn*f(l,m,n2-i,j)
        else
          f(l,m,n2+i,j)=              sgn*f(l,m,n2-i,j)
          if (sgn<0) f(l,m,n2,j) = 0. ! set bdry value=0 (indep of initcond)
        endif
!
      case default
        print*, "bc_sym_z: ", topbot, " should be 'top' or 'bot'"
!
      endselect
!
    endsubroutine bc_sym_z
!***********************************************************************
    subroutine bc_go_x(f,topbot,j,lforce_ghost)
!
!  Outflow boundary conditions.
!
!  If the velocity vector points out of the box, the velocity boundary
!  condition is set to 's', otherwise it is set to 'a'.
!  If 'lforce_ghost' is true, the boundary and ghost cell values are forced
!  to not point inwards. Otherwise the boundary value is forced to be 0.
!
!  14-jun-2011/axel: adapted from bc_outflow_z
!  17-sep-2012/piyali: adapted from bc_outflow_x
!
      character (len=bclen) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: j
      logical, optional :: lforce_ghost
!
      integer :: i, iy, iz
      logical :: lforce
!
      lforce = .false.
      if (present (lforce_ghost)) lforce = lforce_ghost
!
      select case (topbot)
!
!  Bottom boundary.
!
      case ('bot')
        do iy=1,my; do iz=1,mz
          if (f(l1,iy,iz,j)<0.0) then  ! 's'
            do i=1,nghost; f(l1-i,iy,iz,j)=+f(l1+i,iy,iz,j); enddo
          else                         ! 'a'
            do i=1,nghost; f(l1-i,iy,iz,j)=-f(l1+i,iy,iz,j); enddo
            f(l1,iy,iz,j)=0.0
          endif
          if (lforce) then
            do i = 1, nghost
              if (f(l1-i,iy,iz,j) > 0.0) f(l1-i,iy,iz,j) = 0.0
            enddo
          endif
        enddo; enddo
!
!  Top boundary.
!
      case ('top')
        if (llast_proc_x) then
          do iy=1,my
          do iz=1,mz
            if (f(l2,iy,iz,j)>0.0) then
              do i=1,nghost
!                f(l2+i,iy,iz,j)=+f(l2-i,iy,iz,j)
                f(l2+i,iy,iz,j)=+f(l2,iy,iz,j)
              enddo
            else
              do i=1,nghost 
!                f(l2+i,iy,iz,j)=-f(l2-i,iy,iz,j)
                f(l2+i,iy,iz,j)=0.0
              enddo
!              f(l2,iy,iz,j)=0.0
              if (lforce) then
                do i = 1, nghost
                  if (f(l2+i,iy,iz,j) < 0.0) f(l2+i,iy,iz,j) = 0.0
                enddo
              endif
            endif
          enddo
          enddo
        endif
!
!  Default.
!
      case default
        print*, "bc_go_x: ", topbot, " should be 'top' or 'bot'"
!
      endselect
!
    endsubroutine bc_go_x
!*******************************************************************************
    subroutine div_diff_flux(f,j,p,div_flux)
      intent(in) :: f,j
!      intent(out) :: flux_im12,flux_ip12,div_flux
      intent(out) :: div_flux
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx,3) :: flux_im12,flux_ip12
      real, dimension (nx,3) :: cmax_im12,cmax_ip12
      real, dimension (nx) :: div_flux
      real, dimension (nx) :: fim12_l,fim12_r,fip12_l,fip12_r
      real, dimension (nx) :: fim1,fip1,rfac,q1
      type (pencil_case), intent(in) :: p
      integer :: i,j,k
!
! First set the diffusive flux = cmax*(f_R-f_L) at half grid points
!
        fim1=0
        fip1=0
        fim12_l=0
        fim12_r=0
        fip12_l=0
        fip12_r=0
        cmax_ip12=0
        cmax_im12=0
      do k=1,3
!
!
        call slope_lim_lin_interpol(f,j,fim12_l,fim12_r,fip12_l,fip12_r,&
                                   fim1,fip1,k)      
        call characteristic_speed(f,p,cmax_im12,cmax_ip12,k)
        do ix=1,nx
          if (ldensity_nolog) then
            rfac(ix)=abs(fim12_r(ix)-fim12_l(ix))/(abs(f(ix+nghost,m,n,j)-&
             fim1(ix))+tini)
          else
            rfac(ix)=abs(fim12_r(ix)-fim12_l(ix))/(abs(exp(f(ix+nghost,m,n,j))-&
             fim1(ix))+tini)
          endif
          q1(ix)=(min1(1.0,alpha*rfac(ix)))**nlf
        enddo
        flux_im12(:,k)=0.5*cmax_im12(:,k)*q1*(fim12_r-fim12_l)
        do ix=1,nx
          if (ldensity_nolog) then
            rfac(ix)=abs(fip12_r(ix)-fip12_l(ix))/(abs(fip1(ix)-&
            f(ix+nghost,m,n,j))+tini)
          else
            rfac(ix)=abs(fip12_r(ix)-fip12_l(ix))/(abs(fip1(ix)-&
            exp(f(ix+nghost,m,n,j)))+tini)
          endif
          q1(ix)=(min1(1.0,alpha*rfac(ix)))**nlf
        enddo
        flux_ip12(:,k)=0.5*cmax_ip12(:,k)*q1*(fip12_r-fip12_l)
      enddo
!        if (abs(z(n)+0.00068366832).lt.1.0e-6.and.abs(y(m)-1.5262493).lt.1.0e-6) then
!          if (lfirst_proc_x) then
!          print*, 'flux_1:'
!          print*, cmax_im12(3,1),cmax_ip12(3,1),flux_ip12(3,1),flux_im12(3,1)
!          print*, 'flux_2:'
!          print*, cmax_im12(3,2),cmax_ip12(3,2),flux_ip12(3,2),flux_im12(3,2)
!          print*, 'flux_3:'
!          print*, cmax_im12(3,3),cmax_ip12(3,3),flux_ip12(3,3),flux_im12(3,3)
!          endif
!        endif
!
! Now calculate the 2nd order divergence
!
      if (lspherical_coords) then
        div_flux=0.0
        div_flux=div_flux+(x12(l1:l2)**2*flux_ip12(:,1)-x12(l1-1:l2-1)**2*flux_im12(:,1))&
                 /(x(l1:l2)**2*(x12(l1:l2)-x12(l1-1:l2-1))) &
        +(sin(y(m)+0.5*dy)*flux_ip12(:,2)-&
                sin(y(m)-0.5*dy)*flux_im12(:,2))/(x(l1:l2)*sin(y(m))*dy) &
            +(flux_ip12(:,3)-flux_im12(:,3))/(x(l1:l2)*sin(y(m))*dz)
!        if (abs(z(n)+0.00068366832).lt.1.0e-6.and.abs(y(m)-1.5262493).lt.1.0e-6) then
!          if (lfirst_proc_x) then
!          print*, 'div_flux:'
!          print*, div_flux(2),div_flux(3)
!          endif
!        endif
      else
        call fatal_error('twist_inject:div_diff_flux','Not coded for cartesian and cylindrical')
      endif
!
    endsubroutine div_diff_flux
!*******************************************************************************
    subroutine slope_lim_lin_interpol(f,j,fim12_l,fim12_r,fip12_l,fip12_r,fim1,&
                                     fip1,k)
!
! Reconstruction of a scalar by slope limited linear interpolation
! Get values at half grid points l+1/2,m+1/2,n+1/2 depending on case(k)
!
      intent(in) :: f,k,j
      intent(out) :: fim12_l,fim12_r,fip12_l,fip12_r
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: fim12_l,fim12_r,fip12_l,fip12_r,fim1,fip1
      real, dimension (nx) :: delfy,delfz,delfyp1,delfym1,delfzp1,delfzm1
      real, dimension (0:nx+1) :: delfx
      integer :: j,k
      integer :: i,ix
      real :: tmp0,tmp1,tmp2,tmp3
! x-component
      select case (k)
        case(1)
! Special case of non uniform grid only in the radial direction
        if (ldensity_nolog) then
          do i=l1-1,l2+1
            ix=i-nghost
            tmp1=(f(i,m,n,j)-f(i-1,m,n,j))/(x(i)-x(i-1))
            tmp2=(f(i+1,m,n,j)-f(i,m,n,j))/(x(i+1)-x(i))
            delfx(ix) = minmod(tmp1,tmp2)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = f(i-1,m,n,j)+delfx(ix-1)*(x(i)-x(i-1))
            fim12_r(ix) = f(i,m,n,j)-delfx(ix)*(x(i)-x(i-1))
            fip12_l(ix) = f(i,m,n,j)+delfx(ix)*(x(i+1)-x(i))
            fip12_r(ix) = f(i+1,m,n,j)-delfx(ix+1)*(x(i+1)-x(i))
            fim1(ix) = f(i-1,m,n,j)
            fip1(ix) = f(i+1,m,n,j)
          enddo
        else
          do i=l1-1,l2+1
            ix=i-nghost
            tmp1=(exp(f(i,m,n,j))-exp(f(i-1,m,n,j)))/(x(i)-x(i-1))
            tmp2=(exp(f(i+1,m,n,j))-exp(f(i,m,n,j)))/(x(i+1)-x(i))
            delfx(ix) = minmod(tmp1,tmp2)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = exp(f(i-1,m,n,j))+delfx(ix-1)*(x(i)-x(i-1))
            fim12_r(ix) = exp(f(i,m,n,j))-delfx(ix)*(x(i)-x(i-1))
            fip12_l(ix) = exp(f(i,m,n,j))+delfx(ix)*(x(i+1)-x(i))
            fip12_r(ix) = exp(f(i+1,m,n,j))-delfx(ix+1)*(x(i+1)-x(i))
            fim1(ix) = exp(f(i-1,m,n,j))
            fip1(ix) = exp(f(i+1,m,n,j))
          enddo
        endif
! y-component
        case(2)
        if (ldensity_nolog) then
          do i=l1,l2
            ix=i-nghost
            tmp0=f(i,m-1,n,j)-f(i,m-2,n,j)
            tmp1=f(i,m,n,j)-f(i,m-1,n,j)
            delfym1(ix) = minmod(tmp0,tmp1)
            tmp2=f(i,m+1,n,j)-f(i,m,n,j)
            delfy(ix) = minmod(tmp1,tmp2)
            tmp3=f(i,m+2,n,j)-f(i,m+1,n,j)
            delfyp1(ix) = minmod(tmp2,tmp3)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = f(i,m-1,n,j)+delfym1(ix)
            fim12_r(ix) = f(i,m,n,j)-delfy(ix)
            fip12_l(ix) = f(i,m,n,j)+delfy(ix)
            fip12_r(ix) = f(i,m+1,n,j)-delfyp1(ix)
            fim1(ix) = f(i,m-1,n,j)
            fip1(ix) = f(i,m+1,n,j)
          enddo
        else
          do i=l1,l2
            ix=i-nghost
            tmp0=exp(f(i,m-1,n,j))-exp(f(i,m-2,n,j))
            tmp1=exp(f(i,m,n,j))-exp(f(i,m-1,n,j))
            delfym1(ix) = minmod(tmp0,tmp1)
            tmp2=exp(f(i,m+1,n,j))-exp(f(i,m,n,j))
            delfy(ix) = minmod(tmp1,tmp2)
            tmp3=exp(f(i,m+2,n,j))-exp(f(i,m+1,n,j))
            delfyp1(ix) = minmod(tmp2,tmp3)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = exp(f(i,m-1,n,j))+delfym1(ix)
            fim12_r(ix) = exp(f(i,m,n,j))-delfy(ix)
            fip12_l(ix) = exp(f(i,m,n,j))+delfy(ix)
            fip12_r(ix) = exp(f(i,m+1,n,j))-delfyp1(ix)
            fim1(ix) = exp(f(i,m-1,n,j))
            fip1(ix) = exp(f(i,m+1,n,j))
          enddo
        endif
! z-component
        case(3)
        if (ldensity_nolog) then
          do i=l1,l2
            ix=i-nghost
            tmp0=f(i,m,n-1,j)-f(i,m,n-2,j)
            tmp1=f(i,m,n,j)-f(i,m,n-1,j)
            delfzm1(ix) = minmod(tmp0,tmp1)
            tmp2=f(i,m,n+1,j)-f(i,m,n,j)
            delfz(ix) = minmod(tmp1,tmp2)
            tmp3=f(i,m,n+2,j)-f(i,m,n+1,j)
            delfzp1(ix) = minmod(tmp2,tmp3)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = f(i,m,n-1,j)+delfzm1(ix)
            fim12_r(ix) = f(i,m,n,j)-delfz(ix)
            fip12_l(ix) = f(i,m,n,j)+delfz(ix)
            fip12_r(ix) = f(i,m,n+1,j)-delfzp1(ix)
            fim1(ix) = f(i,m,n-1,j)
            fip1(ix) = f(i,m,n+1,j)
          enddo
        else
          do i=l1,l2
            ix=i-nghost
            tmp0=exp(f(i,m,n-1,j))-exp(f(i,m,n-2,j))
            tmp1=exp(f(i,m,n,j))-exp(f(i,m,n-1,j))
            delfzm1(ix) = minmod(tmp0,tmp1)
            tmp2=exp(f(i,m,n+1,j))-exp(f(i,m,n,j))
            delfz(ix) = minmod(tmp1,tmp2)
            tmp3=exp(f(i,m,n+2,j))-exp(f(i,m,n+1,j))
            delfzp1(ix) = minmod(tmp2,tmp3)
          enddo
          do i=l1,l2
            ix=i-nghost
            fim12_l(ix) = exp(f(i,m,n-1,j))+delfzm1(ix)
            fim12_r(ix) = exp(f(i,m,n,j))-delfz(ix)
            fip12_l(ix) = exp(f(i,m,n,j))+delfz(ix)
            fip12_r(ix) = exp(f(i,m,n+1,j))-delfzp1(ix)
            fim1(ix) = exp(f(i,m,n-1,j))
            fip1(ix) = exp(f(i,m,n+1,j))
          enddo
        endif
        case default
          call fatal_error('twist_inject:slope_lim_lin_interpol','wrong component')
        endselect
!
    endsubroutine slope_lim_lin_interpol
!***********************************************************************
    subroutine characteristic_speed(f,p,cmax_im12,cmax_ip12,k)
      intent(in) :: f,k
      intent(out) :: cmax_im12,cmax_ip12
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx,3) :: cmax_im12,cmax_ip12
      real, dimension (nx) :: b1_tmp,b2_tmp,b3_tmp,rho_tmp
      real, dimension (0:nx) :: b1_xtmp,b2_xtmp,b3_xtmp,rho_xtmp
      type (pencil_case), intent(in) :: p
      integer :: k
      integer :: i,ix
!
      select case (k)
! x-component
        case(1)
          b1_xtmp=0.5*(f(l1-1:l2,m,n,ibx)+f(l1:l2+1,m,n,ibx))
          b2_xtmp=0.5*(f(l1-1:l2,m,n,iby)+f(l1:l2+1,m,n,iby))
          b3_xtmp=0.5*(f(l1-1:l2,m,n,ibz)+f(l1:l2+1,m,n,ibz))
          if (ldensity_nolog) then
          rho_xtmp=0.5*(f(l1-1:l2,m,n,irho)+f(l1:l2+1,m,n,irho))
          else
          rho_xtmp=0.5*(exp(f(l1-1:l2,m,n,ilnrho))+exp(f(l1:l2+1,m,n,ilnrho)))
          endif
          cmax_im12(:,1)=sqrt(b1_xtmp(0:nx-1)**2+b2_xtmp(0:nx-1)**2+b3_xtmp(0:nx-1)**2)/sqrt(rho_xtmp(0:nx-1))+sqrt(p%cs2)
          cmax_ip12(:,1)=sqrt(b1_xtmp(1:nx)**2+b2_xtmp(1:nx)**2+b3_xtmp(1:nx)**2)/sqrt(rho_xtmp(1:nx))+sqrt(p%cs2)
! y-component
        case(2)
          b1_tmp=0.5*(f(l1:l2,m-1,n,ibx)+f(l1:l2,m,n,ibx))
          b2_tmp=0.5*(f(l1:l2,m-1,n,iby)+f(l1:l2,m,n,iby))
          b3_tmp=0.5*(f(l1:l2,m-1,n,ibz)+f(l1:l2,m,n,ibz))
          if (ldensity_nolog) then
            rho_tmp=0.5*(f(l1:l2,m-1,n,irho)+f(l1:l2,m,n,irho))
          else
            rho_tmp=0.5*(exp(f(l1:l2,m-1,n,ilnrho))+exp(f(l1:l2,m,n,ilnrho)))
          endif
          cmax_im12(:,2)=sqrt(b1_tmp**2+b2_tmp**2+b3_tmp**2)/sqrt(rho_tmp)+sqrt(p%cs2)
          b1_tmp=0.5*(f(l1:l2,m,n,ibx)+f(l1:l2,m+1,n,ibx))
          b2_tmp=0.5*(f(l1:l2,m,n,iby)+f(l1:l2,m+1,n,iby))
          b3_tmp=0.5*(f(l1:l2,m,n,ibz)+f(l1:l2,m+1,n,ibz))
          if (ldensity_nolog) then
            rho_tmp=0.5*(f(l1:l2,m,n,irho)+f(l1:l2,m+1,n,irho))
          else
            rho_tmp=0.5*(exp(f(l1:l2,m,n,ilnrho))+exp(f(l1:l2,m+1,n,ilnrho)))
          endif
          cmax_ip12(:,2)=sqrt(b1_tmp**2+b2_tmp**2+b3_tmp**2)/sqrt(rho_tmp)+sqrt(p%cs2)
! z-component
        case(3)
          b1_tmp=0.5*(f(l1:l2,m,n-1,ibx)+f(l1:l2,m,n,ibx))
          b2_tmp=0.5*(f(l1:l2,m,n-1,iby)+f(l1:l2,m,n,iby))
          b3_tmp=0.5*(f(l1:l2,m,n-1,ibz)+f(l1:l2,m,n,ibz))
          if (ldensity_nolog) then
            rho_tmp=0.5*(f(l1:l2,m,n-1,irho)+f(l1:l2,m,n,irho))
          else
            rho_tmp=0.5*(exp(f(l1:l2,m,n-1,ilnrho))+exp(f(l1:l2,m,n,ilnrho)))
          endif
          cmax_im12(:,3)=sqrt(b1_tmp**2+b2_tmp**2+b3_tmp**2)/sqrt(rho_tmp)+sqrt(p%cs2)
          b1_tmp=0.5*(f(l1:l2,m,n,ibx)+f(l1:l2,m,n+1,ibx))
          b2_tmp=0.5*(f(l1:l2,m,n,iby)+f(l1:l2,m,n+1,iby))
          b3_tmp=0.5*(f(l1:l2,m,n,ibz)+f(l1:l2,m,n+1,ibz))
          if (ldensity_nolog) then
            rho_tmp=0.5*(f(l1:l2,m,n,irho)+f(l1:l2,m,n+1,irho))
          else
            rho_tmp=0.5*(exp(f(l1:l2,m,n,ilnrho))+exp(f(l1:l2,m,n+1,ilnrho)))
          endif
          cmax_ip12(:,3)=sqrt(b1_tmp**2+b2_tmp**2+b3_tmp**2)/sqrt(rho_tmp)+sqrt(p%cs2)
        endselect
    endsubroutine characteristic_speed
!***********************************************************************
    real function minmod(a,b)
!
!  minmod=max(0,min(abs(a),sign(1,a)*b))
!
      real :: a,b
!
      minmod=sign(0.5,a)*max(0.0,min(abs(a),sign(1.0,a)*b))
!
    endfunction minmod
!***********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include '../special_dummies.inc'
!********************************************************************
endmodule Special

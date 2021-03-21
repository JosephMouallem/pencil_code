! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
!***************************************************************
!
  module special

    use Cparam

    external caller
    external caller0
    integer, external :: dlopen_c
    integer, external :: dlsym_c
    character(LEN=128), external :: dlerror_c
    external dlclose_c

    integer, parameter :: I_REGISTER_SPECIAL=1,  &
                          I_REGISTER_PARTICLES_SPECIAL=2,  &
                          I_INITIALIZE_SPECIAL=3,  &
                          I_FINALIZE_SPECIAL=4,  &
                          I_READ_SPECIAL_INIT_PARS=5,  &
                          I_WRITE_SPECIAL_INIT_PARS=6,  &
                          I_READ_SPECIAL_RUN_PARS=7,  &
                          I_WRITE_SPECIAL_RUN_PARS=8,  &
                          I_RPRINT_SPECIAL=9,  &
                          I_GET_SLICES_SPECIAL=10,  &
                          I_INIT_SPECIAL=11,  &
                          I_DSPECIAL_DT=12,  &
                          I_CALC_PENCILS_SPECIAL=13,  &
                          I_PENCIL_CRITERIA_SPECIAL=14,  &
                          I_PENCIL_INTERDEP_SPECIAL=15,  &
                          I_SPECIAL_CALC_HYDRO=16, &
                          I_SPECIAL_CALC_DENSITY=17, &
                          I_SPECIAL_CALC_DUSTDENSITY=18, &
                          I_SPECIAL_CALC_ENERGY=19, &
                          I_SPECIAL_CALC_MAGNETIC=20, &
                          I_SPECIAL_CALC_PSCALAR=21, &
                          I_SPECIAL_CALC_PARTICLES=22, &
                          I_SPECIAL_CALC_PARTICLES_BFRE_BDARY=23,  &
                          I_SPECIAL_CALC_CHEMISTRY=24, &
                          I_SPECIAL_BOUNDCONDS=25,  &
                          I_SPECIAL_BEFORE_BOUNDARY=26,  &
                          I_SPECIAL_AFTER_BOUNDARY=27,  &
                          I_SPECIAL_AFTER_TIMESTEP=28,  &
                          I_SET_INIT_PARAMETERS=29  
    
    integer, parameter :: n_subroutines=29
    integer, parameter :: n_special_modules_max=50
!
    integer :: n_special_modules
    character(LEN=256) :: special_modules_list = ' '
    character(LEN=29), dimension(n_subroutines) :: special_subroutines=(/ &
                           'register_special            ', &
                           'register_particles_special  ', &
                           'initialize_special          ', &
                           'finalize_special            ', &
                           'read_special_init_pars      ', &
                           'write_special_init_pars     ', &
                           'read_special_run_pars       ', &
                           'write_special_run_pars      ', &
                           'rprint_special              ', &
                           'get_slices_special          ', &
                           'init_special                ', &
                           'dspecial_dt                 ', &
                           'calc_pencils_special        ', &
                           'pencil_criteria_special     ', &
                           'pencil_interdep_special     ', &
                           'special_calc_hydro          ', &
                           'special_calc_density        ', &
                           'special_calc_dustdensity    ', &
                           'special_calc_energy         ', &
                           'special_calc_magnetic       ', &
                           'special_calc_pscalar        ', &
                           'special_calc_particles      ', &
                           'special_particles_bfre_bdary', &
                           'special_calc_chemistry      ', &
                           'special_boundconds          ', &
                           'special_before_boundary     ', &
                           'special_after_boundary      ', &
                           'special_after_timestep      ', &
                           'set_init_parameters         '    /)

    integer(KIND=ikind8) :: libhandle
    integer(KIND=ikind8), dimension(n_special_modules_max,n_subroutines) :: special_sub_handles

    contains
!****************************************************************************
  subroutine initialize_mult_special

    use General, only: parser
    use Messages, only: fatal_error

    integer, parameter :: unit=11
    integer, parameter :: RTLD_LAZY=0, RTLD_NOW=0  !!!

    character(LEN=128) :: line
    integer :: istart,i,j
    character(LEN=40), dimension(n_special_modules_max) :: special_modules
    character(LEN=128) :: error

    n_special_modules=parser(special_modules_list,special_modules,' ')

    libhandle=dlopen_c('special.dll',RTLD_NOW)
    if (handle==0) &
      call fatal_error('setup_mult_special',dlerror_c())
    
    error=dlerror_c()

    do i=1,n_special_modules
      do j=1,n_subroutines
        sub_handle=dlsym_c(handle,trim(special_modules(i)//'_mp_'//trim(special_subroutines(j))//'_'//char(0)))
        if (handle==0) &
          call fatal_error('setup_mult_special','Error for symbol '// &
          trim(special_subroutines(j))//' in module '//trim(special_modules(i)//dlerror_c()))                                                                                               
        special_sub_handles(i,j) = sub_handle
      enddo
    enddo

  endsubroutine initialize_mult_special
!***********************************************************************
  subroutine finalize_mult_special

    call dlclose_c(libhandle)

  endsubroutine finalize_mult_special
!***********************************************************************
    subroutine register_special
!
!  Set up indices for variables in special modules.
!
!  6-oct-03/tony: coded
!
      integer :: i
!
      do i=1,n_special_modules
        call caller0(special_sub_handles(i,I_REGISTER_SPECIAL))
      enddo
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f)
!
!  Called after reading parameters, but before the time loop.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_INITIALIZE_SPECIAL),1,f)
      enddo
!
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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_FINALIZE_SPECIAL),1,f)
      enddo
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
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_INIT_SPECIAL),1,f)
      enddo
!
    endsubroutine init_special
!***********************************************************************
    subroutine pencil_criteria_special
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
      integer :: i
!
      do i=1,n_special_modules
        call caller0(special_sub_handles(i,I_PENCIL_CRITERIA_SPECIAL))
      enddo

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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_PENCIL_INTERDEP_SPECIAL),1,lpencil_in)
      enddo
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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_CALC_PENCILS_SPECIAL),2,f,p)
      enddo
!
    endsubroutine calc_pencils_special
!***********************************************************************
    subroutine dspecial_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_DSPECIAL_DT),3,f,df,p)
      enddo
!
    endsubroutine dspecial_dt
!****************************************************************************
    subroutine register_particles_special(npvar)
!
!  Set up indices for particle variables in special modules.
!
!  4-jan-14/tony: coded
!
      integer :: npvar
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_REGISTER_PARTICLES_SPECIAL),1,npvar)
      enddo
!
    endsubroutine register_particles_special
!*********************************************************************** 
    subroutine read_special_init_pars(iostat)
!
      integer, intent(out) :: iostat
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_READ_SPECIAL_INIT_PARS),1,iostat)
      enddo
!
    endsubroutine read_special_init_pars
!*********************************************************************** 
    subroutine write_special_init_pars(unit)
!
      integer, intent(in) :: unit
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_WRITE_SPECIAL_INIT_PARS),1,unit)
      enddo
!
    endsubroutine write_special_init_pars
!***********************************************************************
    subroutine read_special_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_READ_SPECIAL_RUN_PARS),1,iostat)
      enddo
!
    endsubroutine read_special_run_pars
!***********************************************************************
    subroutine write_special_run_pars(unit)
!
      integer, intent(in) :: unit
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_WRITE_SPECIAL_RUN_PARS),1,unit)
      enddo
!
    endsubroutine write_special_run_pars
!***********************************************************************
    subroutine rprint_special(lreset,lwrite)
!
!  Reads and registers print parameters relevant to special.
!
!  06-oct-03/tony: coded
!
      use General, only: loptest

      logical :: lreset,lwr
      logical, optional :: lwrite
      integer :: i
!
      lwr = loptest(lwrite)
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
!        idiag_SPECIAL_DIAGNOSTIC=0
      endif
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_RPRINT_SPECIAL),2,lreset,lwrite)
      enddo
!
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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_GET_SLICES_SPECIAL),2,f,slices)
      enddo
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
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_HYDRO),3,f,df,p)
      enddo
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  continuity equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_DENSITY),3,f,df,p)
      enddo
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
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_DUSTDENSITY),3,f,df,p)
      enddo
!
    endsubroutine special_calc_dustdensity
!***********************************************************************
    subroutine special_calc_energy(f,df,p)
!
!  Calculate an additional 'special' term on the right hand side of the
!  energy equation.
!
!  Some precalculated pencils of data are passed in for efficiency
!  others may be calculated directly from the f array
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_ENERGY),3,f,df,p)
      enddo
!
    endsubroutine special_calc_energy
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
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_MAGNETIC),3,f,df,p)
      enddo
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
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_PSCALAR),3,f,df,p)
      enddo
!
    endsubroutine special_calc_pscalar
!*********************************************************************** 
    subroutine special_calc_particles(f,df,fp,dfp,ineargrid)
!
!  Called before the loop, in case some particle value is needed
!  for the special density/hydro/magnetic/entropy.
!
!  20-nov-08/wlad: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (:,:) :: fp
      real, dimension (:,:) :: dfp
      integer, dimension(:,:) :: ineargrid
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_PARTICLES),5,f,df,fp,dfp,ineargrid)
      enddo
!
    endsubroutine special_calc_particles
!*********************************************************************** 
    subroutine special_particles_bfre_bdary(f,fp,ineargrid)
!
!  Called before the loop, in case some particle value is needed
!  for the special density/hydro/magnetic/entropy.
!
!  20-nov-08/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (:,:), intent(in) :: fp
      integer, dimension(:,:) :: ineargrid
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_PARTICLES_BFRE_BDARY),3,f,fp,ineargrid)
      enddo
!
    endsubroutine special_particles_bfre_bdary
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
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_CALC_CHEMISTRY),3,f,df,p)
      enddo
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
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_BEFORE_BOUNDARY),1,f)
      enddo
!
    endsubroutine special_before_boundary
!*********************************************************************** 
    subroutine special_after_boundary(f)
!
!  Possibility to modify the f array after the boundaries are
!  communicated.
!
!  06-jul-06/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_AFTER_BOUNDARY),1,f)
      enddo
!
    endsubroutine special_after_boundary
!*********************************************************************** 
    subroutine special_boundconds(f,bc)
!
!  Some precalculated pencils of data are passed in for efficiency,
!  others may be calculated directly from the f array.
!
!  06-oct-03/tony: coded
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      type (boundary_condition), intent(in) :: bc
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_BOUNDCONDS),2,f,bc)
      enddo
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
      logical, intent(in) :: llast
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
      real, dimension(mx,my,mz,mvar), intent(inout) :: df
      real, intent(in) :: dt_
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SPECIAL_AFTER_TIMESTEP),3,f,df,dt_)
      enddo
!
    endsubroutine special_after_timestep
!*********************************************************************** 
    subroutine set_init_parameters(Ntot,dsize,init_distr,init_distr2)
!
!  Possibility to modify the f and df after df is updated.
!  Used for the Fargo shift, for instance.
!
!  27-nov-08/wlad: coded
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension(ndustspec) :: dsize,init_distr,init_distr2
      real :: Ntot
!
      integer :: i
!
      do i=1,n_special_modules
        call caller(special_sub_handles(i,I_SET_INIT_PARAMETERS),4,Ntot,dsize,init_distr,init_distr2)
      enddo
!
    endsubroutine set_init_parameters
!*********************************************************************** 
  end module

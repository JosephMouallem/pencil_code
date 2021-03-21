!  $Id: fluxring_cylindrical.f90 19341 2012-08-01 12:11:20Z AxelBrandenburg $
!
!  Initial condition (density, magnetic field, velocity) 
!  for magnetohydrostatical equilibrium in a global accretion
!  disk with an imposed (cylindrically symmetric) sound speed 
!  profile in spherical coordinates. 
!
!   9-aug-12/axel: adapted from fluxring_cylindrical.f90
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: linitial_condition = .true.
!
!***************************************************************
module InitialCondition
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages
  use Sub, only: erfunc
!
  implicit none
!
  include '../initial_condition.h'
!
  real :: pi2=2.*pi, pi4=4.*pi, B0_scale=1.
  integer :: l
!
  namelist /initial_condition_pars/ B0_scale
!
  contains
!***********************************************************************
    subroutine register_initial_condition()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!  07-oct-09/wlad: coded
!
!  Identify CVS/SVN version information.
!
      if (lroot) call svn_id( &
           "$Id: fluxring_cylindrical.f90 19341 2012-08-01 12:11:20Z AxelBrandenburg $")
!
    endsubroutine register_initial_condition
!***********************************************************************
    subroutine initial_condition_uu(f)
!
!  Initialize the velocity field.
!
!   9-aug-12/axel: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
!  velocity for Orszag-Tang Vortex
!
      do m=1,my
      do l=1,mx
        f(l,m,:,iux)=-sin(pi2*y(m))
        f(l,m,:,iuy)=+sin(pi2*x(l))
      enddo
      enddo
!
    endsubroutine initial_condition_uu
!***********************************************************************
    subroutine initial_condition_lnrho(f)
!
!  Initialize logarithmic density. init_lnrho 
!  will take care of converting it to linear 
!  density if you use ldensity_nolog
!
!   9-aug-12/axel: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx) :: argum,term1,term2,press,del_lnrho
!
!  constant density, following convention of
!  http://www.astro.princeton.edu/~jstone/Athena/tests/orszag-tang/pagesource.html
!
      if (lroot) print*,'initial_condition_lnrho: OT-vortex'
      f(:,:,:,ilnrho)=alog(25./(36.*pi))
!
    endsubroutine initial_condition_lnrho
!***********************************************************************
    subroutine initial_condition_ss(f)
!
!  Initialize logarithmic density. init_ss 
!  will take care of converting it to linear 
!  density if you use ldensity_nolog
!
!   9-aug-12/axel: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
!  constant density, following convention of
!  http://www.astro.princeton.edu/~jstone/Athena/tests/orszag-tang/pagesource.html
!
      if (lroot) print*,'initial_condition_ss: OT-vortex'
      f(:,:,:,iss)=0.603749
!
    endsubroutine initial_condition_ss
!***********************************************************************
    subroutine initial_condition_aa(f)
!
!  Initialize the magnetic vector potential. Constant plasma 
!  beta magnetic field. 
!
!   9-aug-12/axel: coded

      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real :: B0
!
!  vector potential for Orszag-Tang Vortex
!
      B0=B0_scale/sqrt(pi4)
      do m=1,my
      do l=1,mx
        f(l,m,:,iaz)=B0*(cos(pi4*x(l))/pi4+cos(pi2*y(m))/pi2)
      enddo
      enddo
!
    endsubroutine initial_condition_aa
!***********************************************************************
    subroutine read_initial_condition_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=initial_condition_pars, IOSTAT=iostat)
!
    endsubroutine read_initial_condition_pars
!***********************************************************************
    subroutine write_initial_condition_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=initial_condition_pars)
!
    endsubroutine write_initial_condition_pars
!***********************************************************************
!********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from noinitial_condition.f90 for any    **
!**  InitialCondition routines not implemented in this file        **
!**                                                                **
    include '../initial_condition_dummies.inc'
!********************************************************************
  endmodule InitialCondition

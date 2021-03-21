! $Id$
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
  use Cdata
  use Cparam
  use General, only: keep_compiler_quiet
  use Messages
!
  implicit none
!
  include '../initial_condition.h'
!
  real :: ampluu=0.0
  real :: widthrho=1.0
!
  namelist /initial_condition_pars/ &
      ampluu, widthrho
!
  contains
!***********************************************************************
    subroutine initial_condition_all(f,profiles)
!
!  Initializes all the f arrays in one call. This subroutine is called last.
!
!  10-feb-15/MR: added optional parameter 'profiles' (intended to replace f)
!
      use EquationOfState, only: gamma1, cs20, rho0 
      use Gravity, only: gravz
!      
      real, dimension (mx,my,mz,mfarray), optional, intent(inout):: f
      real, dimension (:,:), optional, intent(out) :: profiles
!      
      real :: P0, rhoprof, Pprof
      integer :: l,n  !loop indices for x and z direction
!
!  Specific 2D mode pertubing u_z, but not near boundaries box
!  Creates the classic RT mushroom bubble
!
      if (lroot) print*, &
          'initial_condition_all: RT-mode, ampluu=', ampluu
      do l=l1,l2; do n=n1,n2
        f(l,m1:m2,n,iuz) = f(l,m1:m2,n,iuz)+ &
            (ampluu/4)*(1+cos(2*pi*x(l)/Lxyz(1)))* &
            (1+cos(2*pi*z(n)/Lxyz(3)))
      enddo; enddo
!
!  Tangential density profile approximating a density jump at z=0
!  rho towards 1 if z<0, rho towards 2 if z>0
!  Width of the jump fixed at 6 gridcells (6*dz)
!
      if (lroot) print*, &
          'initial_condition_all: tangential discontinuity for RT'
      do n=n1,n2
         rhoprof=(widthrho/2)*(tanh(z(n)/(6*dz)) +1) + rho0
         f(l1:l2,m1:m2,n,ilnrho)=log(rhoprof) 
      enddo
!
!  Entropy profile for hydrostatic equilibrium, 
!  given the above density profile
!  NOTE We get gravity from gravity module.
!  Standard values c_P=rho_0=1, gravz=-0.1 and P_0 = 2.5
!
      if (lroot) print*, &
          'initial_condition_all: entropy profile for RT'
      !  Equilibrium pressure P0 from EoS
      P0 = gamma1*rho0*cs20
      do n=n1,n2
        rhoprof=(widthrho/2)*(tanh(z(n)/(6*dz)) +1) + rho0
        Pprof= &
            P0 + gravz*((widthrho/2)+rho0)*z(n) +&
            gravz*(widthrho/2)*(6*dz)*log(cosh(z(n)/(6*dz)))
        f(l1:l2,m1:m2,n,iss) = &
            -log(rhoprof/rho0) + (gamma1)*log(Pprof/P0)
      enddo
!
     if (present(profiles)) then
       call fatal_error('initial_condition_all', &
                        'returning of profiles not implemented')
       call keep_compiler_quiet(profiles)
     endif
!
    endsubroutine initial_condition_all
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
!
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

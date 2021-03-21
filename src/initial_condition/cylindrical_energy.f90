!  $Id$
!
!  Initial condition (density, magnetic field, velocity)
!  for magnetohydrostatical equilibrium in a global accretion
!  disk in a cylindrically symmetric  profile in spherical coordinates.
!  with a polytropic equation of state including entropy equation
!
!  7-dec-12/fadiesis: adapted from noinitial_condition.f90 and fluxring_cylindical.f90
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
  real :: b0,s0,width,p0,eps=1.,mphi=1.,ampl=0.,om=1.,b1=0.,b2=0.,bz=0.,hel=1.,nohel=0.
  real :: omega_exponent=0.,ampl_diffrot=0.,rbreak=0.
  logical :: linitial_diffrot=.false.
!
  namelist /initial_condition_pars/ &
      b0,s0,width,p0,eps,mphi,ampl,om,b1,b2,bz,linitial_diffrot,omega_exponent,&
     ampl_diffrot,hel,nohel,rbreak
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
           "$Id$")
!
    endsubroutine register_initial_condition
!***********************************************************************
    subroutine initial_condition_uu(f)
!
!  Initialize the velocity field.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real,dimension(mx) :: omega_diffrot
!
!
      if(linitial_diffrot) then
      do n=1,mz
        do m=1,my
          omega_diffrot = ampl_diffrot*x**(omega_exponent)
          f(:,m,n,iuy)=f(:,m,n,iuy)+ x*omega_diffrot
        enddo
      enddo
    endif
!

    endsubroutine initial_condition_uu
!***********************************************************************
    subroutine initial_condition_lnrho(f)
!
!  Initialize logarithmic density. init_lnrho
!  will take care of converting it to linear
!  density if you use ldensity_nolog
!
!  07-may-09/wlad: coded
!
      use EquationOfState, only: cs20,gamma,gamma_m1,gamma1
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx) :: argum,term1,term2,press,lnrho0,lnrho,ln
!
      if (lroot) print*,&
           'initial_condition_lnrho: ring'


    endsubroutine initial_condition_lnrho

!***********************************************************************
    subroutine initial_condition_ss(f)
!
!  Initialize entropy.
!
!  07-may-09/wlad: coded
!
      use EquationOfState, only: gamma,gamma_m1,gamma1,cs20,rho0

      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real :: cp,cv,cp1,lnTT0,pp0,TT0
      integer :: irho
      real, dimension (mx) :: argum,term1,term2,press,lnrho,lnTT,TT,rho,lnrho0
!
!  Get the density and use a constant pressure entropy condition
!
     cp=1.
     cp1=1/cp
     cv=gamma1*cp
!

     argum=sqrt2*(x-s0)/width
     term1=s0*width*sqrtpi*sqrt2*erfunc(argum)
     term2=(2.*x**2-width**2)*exp(-argum**2)
     press=p0-(.5*b0/s0)**2*(term1+term2)
     lnrho0=eps*log(press)/gamma

!
     do n=1,mz
       do m=1,my
         f(:,m,n,ilnrho)=f(:,m,n,ilnrho)+lnrho0
       lnrho = f(:,m,n,ilnrho)
       enddo
     enddo

     TT0 = cs20*cp1/gamma_m1 ; lnTT0=log(TT0)
     TT=TT0*(exp(lnrho/lnrho0))**(gamma_m1)
     lnTT = log(TT)
       print*,'gamma,TT0=',gamma,TT0
     do n=1,mz
       do m=1,my
        f(1:mx,m,n,iss)=f(1:mx,m,n,iss) +  cv*(lnTT-gamma_m1*lnrho)
      enddo
     enddo
!
    endsubroutine initial_condition_ss



!***********************************************************************
    subroutine initial_condition_aa(f)
!
!  Initialize the magnetic vector potential. Constant plasma
!  beta magnetic field.
!
!  07-may-09/wlad: coded
!  23-feb-12/fabio: added costant bz to the initial setup

      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx) :: argum,term1,term2,ax,az,ay,fp,fm,f0
!
!  vector potential for the magnetic flux ring
!
      argum=(x-s0)/width
      term1=s0*sqrtpi*erfunc(argum)
      term2=-width*exp(-argum**2)
      az=-(.5*b0/s0)*width*(term1+term2)-b1*x-b2*log(x)
      ay=.5*bz*x
!
      do n=1,mz
        do m=1,my
          f(:,m,n,iaz)= az
          f(:,m,n,iay)=f(:,m,n,iay)+ay
        enddo
      enddo
!
!   perturbation for the initial field
!
      print*,'ampl,rbreak=',ampl,rbreak
      if (rbreak==0) then
        do n=1,mz
          do m=1,my
            ax=ampl*x*(hel*cos(om*z(n))*sin(mphi*y(m))+nohel*sin(om*z(n))*sin(mphi*y(m)))
            az=ampl*x*cos(om*z(n))*cos(mphi*y(m))
            f(:,m,n,iax)=f(:,m,n,iax)+ax
            f(:,m,n,iaz)=f(:,m,n,iaz)+az
          enddo
        enddo
      else
        fp=max(x-rbreak,x-x)
        fm=max(rbreak-x,x-x)
        print*,'iproc,x=',iproc,x
        print*,'iproc,fp=',iproc,fp
        print*,'iproc,fm=',iproc,fm
        do n=1,mz
          do m=1,my
            ax=ampl*cos(om*z(n))*sin(mphi*y(m))
            az=ampl*cos(om*z(n))*cos(mphi*y(m))
            f(:,m,n,iax)=f(:,m,n,iax)+ax*fp-ax*fm
            f(:,m,n,iaz)=f(:,m,n,iaz)+az*fp+az*fm
          enddo
        enddo
      endif

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

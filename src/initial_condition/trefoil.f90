!  $Id$
!
!  Initial condition (density, magnetic field, velocity) 
!  for a particular configuration of magnetic flux rings. 
!
!  07-may-09/wlad: adapted from noinitial_condition.f90
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
!
  implicit none
!
  include '../initial_condition.h'
!
  real :: ampl,width_ring
  character (len=labellen) :: prof='constant'
!
  namelist /initial_condition_pars/ &
      ampl,width_ring,prof
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
!
      call keep_compiler_quiet(f)
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
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_lnrho
!***********************************************************************
    subroutine initial_condition_aa(f)
!
!  Initialize the magnetic vector potential.
!
!  07-may-09/wlad: coded
!
!  Magnetic flux ring which has the form of a trefoil knot. This knot has
!  a linking number 3.
!
!  Created 2009-06-05 by Simon Candelaresi (Iomsn)
!
      use Mpicomm, only: stop_it
      use Poisson
      use Sub
      
      real, dimension (mx,my,mz,mfarray) :: f
      real :: knot_param, circle_param, circle_radius
      real :: delta_knot_param, delta_circle_param, delta_circle_radius
      real, dimension(3) :: knot_pos, circle_pos, tangent, normal
      integer :: domain_width, domain_depth, domain_height
      integer :: l, j, ju
      ! The next 2 variables are used for the uncurling.
      real, dimension (nx,ny,nz,3) :: jj, tmpJ  ! This is phi for poisson.f90
      
!
!  initialize the magnetic flux tube
!
      domain_width = l2-l1; domain_depth = m2-m1; domain_height = n2-n1
!
!  Calculate the minimum step size of the curve parameters 
!  to avoid discretation issues, like mesh points without magnetic field
!     delta_knot_param = (2.*pi)/max(domain_width,domain_depth,domain_height)
!
      delta_knot_param = 1./max(domain_width,domain_depth,domain_height)
      delta_circle_param = delta_knot_param/(width_ring/2.)
      delta_circle_radius = delta_circle_param
!
      knot_param = 0.
!
!  loop which moves along the trefoil knot
!
      do
        if (knot_param .gt. 3.*pi*3./2.+3.) exit
!
!  At which stage of the knot are we?
!
        if (knot_param .le. 1.*pi*3./2. + 0.) then
          knot_pos(1) = -sin(knot_param/3.)**2
          knot_pos(2) = -cos(knot_param)
          knot_pos(3) = sin(knot_param)+1.
          tangent(1) = -2./3.*sin(knot_param/3.)*cos(knot_param/3.)
          tangent(2) = sin(knot_param)
          tangent(3) = cos(knot_param)
        elseif (knot_param .le. 1.*pi*3./2. + 1.) then
          knot_pos(1) = -1.
          knot_pos(2) = -(knot_param-pi*3./2.)
          knot_pos(3) = 0.
          tangent(1) = 0.
          tangent(2) = -1.
          tangent(3) = 0.
        elseif (knot_param .le. 2.*pi*3./2. + 1.) then
          knot_pos(1) = -cos(knot_param-(1.*pi*3./2.+1.))
          knot_pos(2) = -sin(knot_param-(1.*pi*3./2.+1.))-1.
          knot_pos(3) = sin((knot_param-(1.*pi*3./2.+1.))/3.)**2
          tangent(1) = sin(knot_param-(1.*pi*3./2.+1.))
          tangent(2) = -cos(knot_param-(1.*pi*3./2.+1.))
          tangent(3) = 2./3.*sin((knot_param-(1.*pi*3./2.+1.))/3.)*&
              cos((knot_param-(1.*pi*3./2.+1.))/3.)
        elseif (knot_param .le. 2.*pi*3./2. + 2.) then
          knot_pos(1) = -(knot_param-(2.*pi*3./2.+1.))
          knot_pos(2) = 0.
          knot_pos(3) = 1.
          tangent(1) = -1.
          tangent(2) = 0.
          tangent(3) = 0.
        elseif (knot_param .le. 3.*pi*3./2. + 2.) then
          knot_pos(1) = -sin(knot_param-(2.*pi*3./2.+2.))-1.
          knot_pos(2) = -sin((knot_param-(2.*pi*3./2.+2.))/3.)**2
          knot_pos(3) = cos(knot_param-(2.*pi*3./2.+2.))
          tangent(1) = -cos(knot_param-(2.*pi*3./2.+2.))
          tangent(2) = -2./3.*sin((knot_param-(2.*pi*3./2.+2.))/3.)*&
              cos((knot_param-(2.*pi*3./2.+2.))/3.)
          tangent(3) = -sin(knot_param-(2.*pi*3./2.+2.))
        else
          knot_pos(1) = 0.
          knot_pos(2) = -1.
          knot_pos(3) = knot_param-(3.*pi*3./2.+2.)
          tangent(1) = 0.
          tangent(2) = 0.
          tangent(3) = 1.
        endif
        tangent = tangent / sqrt(tangent(1)**2+tangent(2)**2+tangent(3)**2)
!
!  Find vector which is orthogonal (normal) to tangent vector.
!
        if (abs(tangent(1)) .le. 0.5) then
          normal(1) = tangent(1)**2 - 1.0
          normal(2) = tangent(2)*tangent(1)
          normal(3) = tangent(3)*tangent(1)
        elseif (abs(tangent(2)) .le. 0.5) then
          normal(1) = tangent(1)*tangent(2)
          normal(2) = tangent(2)**2 - 1.0
          normal(3) = tangent(3)*tangent(2)
        else
          normal(1) = tangent(1)*tangent(3)
          normal(2) = tangent(2)*tangent(3)
          normal(3) = tangent(3)**2 - 1.0
        endif
!
!  normalize the normal vector
!
        normal = normal / sqrt(normal(1)**2+normal(2)**2+normal(3)**2)
!
        circle_radius = 0.
!
!  loop which changes the circles radius
!
        do
          if (circle_radius .gt. width_ring/2.) exit
          circle_param = 0.
!
!  loop which goes around the circle
!
          do
            if (circle_param .gt. 2.*pi) exit
            circle_pos(1) = knot_pos(1) + circle_radius * &
            ((tangent(1)*tangent(1)*(1-cos(circle_param))+cos(circle_param))*normal(1) + &
            (tangent(1)*tangent(2)*(1-cos(circle_param))-tangent(3)*sin(circle_param))*normal(2) + &
            (tangent(1)*tangent(3)*(1-cos(circle_param))+tangent(2)*sin(circle_param))*normal(3))
            circle_pos(2) = knot_pos(2) + circle_radius * &
            ((tangent(1)*tangent(2)*(1-cos(circle_param))+tangent(3)*sin(circle_param))*normal(1) + &
            (tangent(2)*tangent(2)*(1-cos(circle_param))+cos(circle_param))*normal(2) + &
            (tangent(2)*tangent(3)*(1-cos(circle_param))-tangent(1)*sin(circle_param))*normal(3))
            circle_pos(3) = knot_pos(3) + circle_radius * &
            ((tangent(1)*tangent(3)*(1-cos(circle_param))-tangent(2)*sin(circle_param))*normal(1) + &
            (tangent(2)*tangent(3)*(1-cos(circle_param))+tangent(1)*sin(circle_param))*normal(2) + &
            (tangent(3)*tangent(3)*(1-cos(circle_param))+cos(circle_param))*normal(3))
!
!  Find the corresponding mesh point to this position.
!
            l = nint((circle_pos(1)+pi)/(2.*pi)*domain_width)+1
            m = nint((circle_pos(2)+pi)/(2.*pi)*domain_depth)+1
            n = nint((circle_pos(3)+pi)/(2.*pi)*domain_height)+1
!
!  Write the magnetic field b.
!           magneticField(l,m,n,1:3) = tangent*ampl
            f(l,m,n,iax:iaz) = tangent*ampl
            circle_param = circle_param + delta_circle_param
          enddo
          circle_radius = circle_radius + delta_circle_radius
        enddo
        knot_param = knot_param + delta_knot_param
      enddo
      
!
!  Transform the magnetic field into a vector potential
!

!  Compute curl(B) = J for th ePoisson solver

      do m=m1,m2
         do n=n1,n2
            call curl(f,iaa,jj(:,m-nghost,n-nghost,:))
         enddo
      enddo
      tmpJ = -jj
!  Use the Poisson solver to solve \nabla^2 A = -J for A
      do j=1,3
        call inverse_laplacian(tmpJ(:,:,:,j))
      enddo
      
!  Overwrite the f-array with the correct vector potential A
      do j=1,3
          ju=iaa-1+j
          f(l1:l2,m1:m2,n1:n2,ju) = tmpJ(:,:,:,j)
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

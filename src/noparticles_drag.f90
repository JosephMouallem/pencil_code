! $Id$
!
!  This module takes care of drag forces between particles and gas.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_drag = .false.
!
!***************************************************************
module Particles_drag
!
  use Cparam
  use General, only: keep_compiler_quiet
!
  implicit none
!
  include 'particles_drag.h'
!
  contains
!***********************************************************************
    subroutine register_particles_drag()
!
!  Register this module.
!
!  14-dec-14/ccyang: dummy.
!
    endsubroutine register_particles_drag
!***********************************************************************
    subroutine initialize_particles_drag()
!
!  Perform any post-parameter-read initialization, i.e., calculate
!  derived parameters.
!
!  14-dec-14/ccyang: dummy.
!
    endsubroutine initialize_particles_drag
!***********************************************************************
    subroutine init_particles_drag(f, fp)
!
!  Set some initial conditions for the gas and the particles, if any.
!
!  14-feb-15/ccyang: dummy.
!
      use General, only: keep_compiler_quiet
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mpar_loc,mparray), intent(in) :: fp
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(fp)
!
    endsubroutine init_particles_drag
!***********************************************************************
    subroutine read_particles_drag_init_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_drag_init_pars
!***********************************************************************
    subroutine write_particles_drag_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_drag_init_pars
!***********************************************************************
    subroutine read_particles_drag_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_drag_run_pars
!***********************************************************************
    subroutine write_particles_drag_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_drag_run_pars
!***********************************************************************
    subroutine integrate_drag(f, fp, dt)
!
!  Wrapper for the integration of the drag force between particles and
!  gas.
!
!  24-may-15/ccyang: dummy.
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mpar_loc,mparray), intent(in) :: fp
      real, intent(in) :: dt
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(dt)
!
    endsubroutine integrate_drag
!***********************************************************************
endmodule Particles_drag

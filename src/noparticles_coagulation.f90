! $Id$
!
!  This modules takes care of instantaneous coagulation, shattering,
!  erosion, and bouncing of superparticles.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_coagulation = .false.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************
module Particles_coagulation
!
  use Cdata
  use General, only: keep_compiler_quiet
  use Particles_cdata
!
  implicit none
!
  include 'particles_coagulation.h'
!
  contains
!***********************************************************************
    subroutine initialize_particles_coag(f)
!
!  24-nov-10/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_particles_coag
!***********************************************************************
    subroutine particles_coagulation_timestep(fp,ineargrid)
!
!  30-nov-10/anders: dummy
!
      real, dimension (mpar_loc,mparray) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine particles_coagulation_timestep
!***********************************************************************
    subroutine particles_coagulation_pencils(fp,ineargrid)
!
!  24-nov-10/anders: coded
!
      real, dimension (mpar_loc,mparray) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine particles_coagulation_pencils
!***********************************************************************
    subroutine particles_coagulation_blocks(fp,ineargrid)
!
!  24-nov-10/anders: coded
!
      real, dimension (mpar_loc,mparray) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine particles_coagulation_blocks
!***********************************************************************
    subroutine read_particles_coag_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_coag_run_pars
!***********************************************************************
    subroutine write_particles_coag_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_coag_run_pars
!***********************************************************************
    subroutine rprint_particles_coagulation(lreset,lwrite)
!
!  24-nov-10/anders: coded
!
      logical :: lreset
      logical, optional :: lwrite
!
      call keep_compiler_quiet(lreset,lwrite)
!
    endsubroutine rprint_particles_coagulation
!***********************************************************************
endmodule Particles_coagulation

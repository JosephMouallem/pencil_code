! $Id$
!
!  This module writes information about the local state of the gas at
!  the positions of a selected number of particles.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_stalker=.false.
!
!***************************************************************
module Particles_stalker
!
  use Cdata
  use General, only: keep_compiler_quiet
!
  implicit none
!
  include 'particles_stalker.h'
!
  contains
!***********************************************************************
    subroutine initialize_particles_stalker(f)
!
!  13-nov-07/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_particles_stalker
!***********************************************************************
    subroutine particles_stalker_sub(f,fp,ineargrid)
!
!  13-nov-07/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mpar_loc,mparray) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine particles_stalker_sub
!***********************************************************************
    subroutine read_pstalker_init_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_pstalker_init_pars
!***********************************************************************
    subroutine write_pstalker_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_pstalker_init_pars
!***********************************************************************
    subroutine read_pstalker_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_pstalker_run_pars
!***********************************************************************
    subroutine write_pstalker_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_pstalker_run_pars
!***********************************************************************
endmodule Particles_stalker

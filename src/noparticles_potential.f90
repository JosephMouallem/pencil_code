! $Id: noparticles_potential.f90  $
!
! The no module for particles potential
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_potential=.false.
!
!***************************************************************
module Particles_potential
!
  use Cdata
  use General, only: keep_compiler_quiet
  use Particles_cdata
!
  implicit none
!
  include 'particles_potential.h'
!
  contains
!***********************************************************************
    subroutine register_particles_potential
!
!  Set up indices for access to the fp and dfp arrays
!
!  22-aug-05/anders: dummy
!
    endsubroutine register_particles_potential
!***********************************************************************
    subroutine initialize_particles_potential(fp)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  25-nov-05/anders: coded
!
      real, dimension (mpar_loc,mparray), intent (in) :: fp
!
      call keep_compiler_quiet(fp)
!
    endsubroutine initialize_particles_potential
!***********************************************************************
    subroutine particles_potential_clean_up
!
! dummy subroutine
!
    endsubroutine particles_potential_clean_up
!***********************************************************************
    subroutine pencil_criteria_par_potential
!
!  All pencils that the Particles_radius module depends on are specified here.
!
!  21-nov-06/anders: dummy
!
    endsubroutine pencil_criteria_par_potential
!***********************************************************************
    subroutine dvvp_dt_potential(f,df,fp,dfp,ineargrid)
!
!  Dummy module
!
!  21-nov-06/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mparray) :: fp
      real, dimension (mpar_loc,mpvar) :: dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(dfp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine dvvp_dt_potential
!***********************************************************************
    subroutine dvvp_dt_potential_pencil(f,df,fp,dfp,ineargrid)
!
!  Dummy module
!
!  21-nov-06/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mparray) :: fp
      real, dimension (mpar_loc,mpvar) :: dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(dfp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine dvvp_dt_potential_pencil
!***********************************************************************
    subroutine read_particles_pot_init_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_pot_init_pars
!***********************************************************************
    subroutine write_particles_pot_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_pot_init_pars
!***********************************************************************
    subroutine read_particles_pot_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_pot_run_pars
!***********************************************************************
    subroutine write_particles_pot_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_pot_run_pars
!***********************************************************************
    subroutine rprint_particles_potential(lreset,lwrite)
!
!  Read and register print parameters relevant for particles potential.
!
!  22-aug-05/anders: dummy
!
      use FArrayManager, only: farray_index_append
!
      logical :: lreset, lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
      if (lwr) then
        call farray_index_append('iap', iap)
      endif
!
      call keep_compiler_quiet(lreset)
!
    endsubroutine rprint_particles_potential
!***********************************************************************
endmodule Particles_potential

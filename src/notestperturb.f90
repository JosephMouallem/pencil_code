! $Id$
!
!  test perturbation method
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: ltestperturb = .false.
!
!***************************************************************
module TestPerturb
!
  use General, only: keep_compiler_quiet
!
  implicit none
!
  include 'testperturb.h'
!
  contains
!***********************************************************************
    subroutine register_testperturb
!
!  Dummy routine
!
    endsubroutine register_testperturb
!***********************************************************************
    subroutine initialize_testperturb
!
!  Dummy routine
!
    endsubroutine initialize_testperturb
!***********************************************************************
    subroutine read_testperturb_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_testperturb_run_pars
!***********************************************************************
    subroutine write_testperturb_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_testperturb_run_pars
!***********************************************************************
    subroutine testperturb_begin(f,df)
!
!  Dummy routine
!
      use Cparam, only: mx,my,mz,mfarray,mvar
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
!
      call keep_compiler_quiet(f,df)
!
    endsubroutine testperturb_begin
!***********************************************************************
    subroutine testperturb_finalize(f)
!
!  Dummy routine
!
      use Cparam, only: mx,my,mz,mfarray,mvar
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine testperturb_finalize
!***********************************************************************
    subroutine rprint_testperturb(lreset,lwrite)
!
!  Dummy routine
!
      logical :: lreset
      logical, optional :: lwrite
!
      call keep_compiler_quiet(lreset,lwrite)
!
    endsubroutine rprint_testperturb
!***********************************************************************
endmodule TestPerturb

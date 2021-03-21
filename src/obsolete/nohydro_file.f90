! $Id$

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Hydro

  use Cparam
  use Messages

  implicit none

  include 'hydro.h'

  private

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_u2m=0,idiag_um2=0,idiag_oum=0,idiag_o2m=0
  integer :: idiag_urms=0,idiag_umax=0,idiag_orms=0,idiag_omax=0
  integer :: idiag_Marms=0,idiag_Mamax=0
  integer :: idiag_u2mphi=0,idiag_oumphi=0

  contains

!***********************************************************************
    subroutine register_hydro()
!
!  Initialise variables which should know that we solve the hydro
!  equations: iuu, etc; increase nvar accordingly.
!
!  6-nov-01/wolf: coded
!
      use Cdata
      use Mpicomm, only: lroot,stop_it
      use Sub
!
      lhydro = .false.
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call svn_id( &
           "$RCSfile: nohydro_file.f90,v $", &
           "$Revision: 1.32 $", &
           "$Date: 2008-07-02 00:31:46 $")
!
    endsubroutine register_hydro
!***********************************************************************
    subroutine initialize_hydro(f)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  24-nov-02/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
    endsubroutine initialize_hydro
!***********************************************************************
    subroutine init_uu(f)
!
!  initialise uu and lnrho; called from start.f90
!  Should be located in the Hydro module, if there was one.
!
!   7-jun-02/axel: adapted from hydro
!
      real, dimension (mx,my,mz,mvar) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine init_uu
!***********************************************************************
    subroutine input_array(file,a,dimx,dimy,dimz,dimv)
!
!  Generalized form of input, allows specifying dimension.
!
!  27-sep-03/axel: coded
!
      character (len=*) :: file
      integer :: dimx,dimy,dimz,dimv
      real, dimension (dimx,dimy,dimz,dimv) :: a
!
      integer :: iostat
!
      open(1,FILE=file,FORM='unformatted')
      read(1) a
      close(1)
!
    endsubroutine input_array
!***********************************************************************
    subroutine duu_dt(f,df,uu,u2,divu,rho,rho1,glnrho,uij,bij,shock,gshock)
!
!  velocity evolution, dummy routine
!  This routine is used in kinematic dynamo calculations;
!  allow for different prescribed velocity fields.
!
!   7-jun-02/axel: adapted from hydro
!
      use Cdata
      use Magnetic
      use General
      use Sub
      use IO
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3,3) :: uij,bij
      real, dimension (nx,3) :: uu,glnrho,gshock
      real, dimension (nx) :: u2,divu,rho,rho1,shock
!
      real, save, dimension (nx,ny,nz,3) :: uuu
      logical, save :: first=.true.
      integer :: j
!
      if (kinflow=='file') then
        if (first) then
          print*,'duu_dt: read array uu.dat'
          call input_array(trim(directory)//'/uu.dat',uuu,nx,ny,nz,3)
          first=.false.
        else
          do j=1,3
            uu(:,j)=uuu(:,m-nghost,n-nghost,j)
          enddo
        endif
      elseif (kinflow=='ABC') then
        if (headtt) print*,'ABC flow'
        uu(:,1)=ABC_A*sin(kz_aa*z(n))    +ABC_C*cos(ky_aa*y(m))
        uu(:,2)=ABC_B*sin(kx_aa*x(l1:l2))+ABC_A*cos(kz_aa*z(n))
        uu(:,3)=ABC_C*sin(ky_aa*y(m))    +ABC_B*cos(kx_aa*x(l1:l2))
      else
        if (headtt) print*,'uu=0'
        uu=0.
      endif
!
!  ``uu/dx'' for timestep
!
      if (lfirst.and.ldt) advec_uu=abs(uu(:,1))*dx_1(l1:l2)+ &
                                   abs(uu(:,2))*dy_1(  m  )+ &
                                   abs(uu(:,3))*dz_1(  n  )
      if (headtt.or.ldebug) print*,'duu_dt: max(advec_uu) =',maxval(advec_uu)
!
!  Calculate maxima and rms values for diagnostic purposes
!  (The corresponding things for magnetic fields etc happen inside magnetic etc)
!  The length of the timestep is not known here (--> moved to prints.f90)
!
      if (ldiagnos) then
        call dot2_mn(uu,u2)
        if (idiag_u2m/=0) call sum_mn_name(u2,idiag_u2m)
        if (idiag_um2/=0) call max_mn_name(u2,idiag_um2)
      endif
!
    endsubroutine duu_dt
!***********************************************************************
    subroutine time_integrals_hydro(f,p)
!
!   1-jul-08/axel: dummy
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f,p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine time_integrals_hydro
!***********************************************************************
    subroutine hydro_after_boundary(f)
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine hydro_after_boundary
!***********************************************************************
    subroutine read_hydro_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_hydro_run_pars
!***********************************************************************
    subroutine write_hydro_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_hydro_run_pars
!***********************************************************************
    subroutine read_hydro_run_pars(unit,iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_hydro_run_pars
!***********************************************************************
    subroutine write_hydro_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_hydro_run_pars
!***********************************************************************
    subroutine rprint_hydro(lreset,lwrite)
!
!  reads and registers print parameters relevant for hydro part
!
!   8-jun-02/axel: adapted from hydro
!
      use Cdata
      use FArrayManager, only: farray_index_append
      use Sub
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_u2m=0;idiag_um2=0;idiag_oum=0;idiag_o2m=0
        idiag_u2mphi=0; idiag_oumphi=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if (lroot.and.ip<14) print*,'rprint_nohydro_file: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'u2m',idiag_u2m)
        call parse_name(iname,cname(iname),cform(iname),'um2',idiag_um2)
!       call parse_name(iname,cname(iname),cform(iname),'o2m',idiag_o2m)
!       call parse_name(iname,cname(iname),cform(iname),'oum',idiag_oum)
      enddo
!
!  write column where which hydro variable is stored
!
      if (lwr) then
        call farray_index_append('i_u2m',idiag_u2m)
        call farray_index_append('i_um2',idiag_um2)
        call farray_index_append('i_o2m',idiag_o2m)
        call farray_index_append('i_oum',idiag_oum)
        call farray_index_append('i_urms',idiag_urms)
        call farray_index_append('i_umax',idiag_umax)
        call farray_index_append('i_orms',idiag_orms)
        call farray_index_append('i_omax',idiag_omax)
        call farray_index_append('i_u2mphi',idiag_u2mphi)
        call farray_index_append('i_oumphi',idiag_oumphi)
        call farray_index_append('nname',nname)
        call farray_index_append('iuu',iuu)
        call farray_index_append('iux',iux)
        call farray_index_append('iuy',iuy)
        call farray_index_append('iuz',iuz)
      endif
!
    endsubroutine rprint_hydro
!***********************************************************************
    subroutine calc_mflow
!
!  dummy routine
!
!  19-jul-03/axel: adapted from hydro
!
    endsubroutine calc_mflow
!***********************************************************************

endmodule Hydro

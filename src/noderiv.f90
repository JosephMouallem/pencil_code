! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM integer, parameter :: nghost = 0
!
!***************************************************************
module Deriv
!
  use Messages, only: fatal_error, warning
  use Cdata
!
  implicit none
!
  private
!
  public :: initialize_deriv, finalize_deriv
  public :: der, der2, der3, der4, der5, der6, derij, der5i1j, der5_single
  public :: der6_other, der_pencil, der2_pencil
  public :: der4i2j,der2i2j2k,der3i3j,der3i2j1k,der4i1j1k
  public :: deri_3d_inds
  public :: der_x,der2_x
  public :: der_z,der2_z
  public :: der_upwind1st
  public :: der_onesided_4_slice
  public :: der_onesided_4_slice_other
  public :: der2_minmod
  public :: heatflux_deriv_x
  public :: set_ghosts_for_onesided_ders
  public :: bval_from_neumann, bval_from_3rd, bval_from_4th
!
  real :: der2_coef0, der2_coef1, der2_coef2, der2_coef3
!
  interface der                 ! Overload the der function
    module procedure der_main   ! derivative of an 'mvar' variable
    module procedure der_other  ! derivative of another field
  endinterface
!
  interface der2                 ! Overload the der function
    module procedure der2_main   ! derivative of an 'mvar' variable
    module procedure der2_other  ! derivative of another field
  endinterface
!
  interface derij                 ! Overload the der function
    module procedure derij_main   ! derivative of an 'mvar' variable
    module procedure derij_other  ! derivative of another field
  endinterface
!
  interface  der_onesided_4_slice                ! Overload the der function
    module procedure  der_onesided_4_slice_main  ! derivative of an 'mvar' variable
    module procedure  der_onesided_4_slice_main_pt
    module procedure  der_onesided_4_slice_other ! derivative of another field
    module procedure  der_onesided_4_slice_other_pt
  endinterface
!
  interface bval_from_neumann
    module procedure bval_from_neumann_scl
    module procedure bval_from_neumann_arr
  endinterface
!
  interface bval_from_3rd
    module procedure bval_from_3rd_scl
    module procedure bval_from_3rd_arr
  endinterface
!
  interface bval_from_4th
    module procedure bval_from_4th_scl
    module procedure bval_from_4th_arr
  endinterface
!
  contains
!
!***********************************************************************
    subroutine initialize_deriv
!
!  Dummy routine
!
    endsubroutine initialize_deriv
!***********************************************************************
    subroutine der_main(f, k, df, j, ignoredx)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nx), intent(in) :: df
      integer, intent(in) :: j, k
      logical, intent(in), optional :: ignoredx
!
    endsubroutine der_main
!***********************************************************************
    subroutine der_x(f,df)
!
!  Dummy routine
!
      real, dimension (mx), intent(in)  :: f
      real, dimension (nx), intent(in) :: df
!
    endsubroutine der_x
!***********************************************************************
    subroutine der2_x(f,df2)
!
!  Dummy routine
!
      real, dimension (mx), intent(in)  :: f
      real, dimension (nx), intent(in) :: df2
!
    endsubroutine der2_x
!***********************************************************************
    subroutine der_z(f,df)
!
!  Dummy routine
!
      real, dimension (mz), intent(in)  :: f
      real, dimension (nz), intent(in) :: df
!
    endsubroutine der_z
!***********************************************************************
    subroutine der2_z(f,df2)
!
!  Dummy routine
!
      real, dimension (mz), intent(in)  :: f
      real, dimension (nz), intent(in) :: df2
!
    endsubroutine der2_z
!***********************************************************************
    subroutine der_other(f,df,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real, dimension (:) :: df
      integer :: j
!
    endsubroutine der_other
!***********************************************************************
    subroutine der_pencil(j,pencil,df)
!
!  Dummy routine
!
      real, dimension (:) :: pencil,df
      integer :: j
      intent(in)  :: df, j, pencil
!
    endsubroutine der_pencil
!***********************************************************************
    subroutine der2_main(f,k,df2,j,lwo_line_elem)
!
!  Dummy routine
!
      use General, only: loptest

      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df2,fac,df
      integer :: j,k
      logical, optional :: lwo_line_elem
!
      intent(in)  :: f,df2,k,j,lwo_line_elem
!
    endsubroutine der2_main
!***********************************************************************
    subroutine der2_other(f,df2,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real, dimension (nx) :: df2,fac,df
      integer :: j
!
      intent(in)  :: f,df2,j
!
    endsubroutine der2_other
!***********************************************************************
    subroutine der2_pencil(j,pencil,df2)
!
!  Dummy routine
!
      real, dimension (:) :: pencil,df2
      integer :: j
      intent(in)  :: j, pencil, df2
!
    endsubroutine der2_pencil
!***********************************************************************
    subroutine der3(f,k,df,j,ignoredx)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df,fac
      integer :: j,k
      logical, optional :: ignoredx
      logical :: igndx
      intent(in)  :: f,k,df,j,ignoredx
!
    endsubroutine der3
!***********************************************************************
    subroutine der4(f,k,df,j,ignoredx,upwind)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df
      real :: fac
      integer :: j,k
      logical, optional :: ignoredx,upwind
      logical :: igndx
      intent(in)  :: f,k,j,ignoredx,upwind
!
    endsubroutine der4
!***********************************************************************
    subroutine der5(f,k,df,j,ignoredx)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df
      integer :: j,k
      logical, optional :: ignoredx
      intent(in)  :: f,k,df,j,ignoredx
!
    endsubroutine der5
!***********************************************************************
    subroutine der6(f,k,df,j,ignoredx,upwind)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df,fac
      integer :: j,k
      logical, optional :: ignoredx,upwind
      logical :: igndx,upwnd
      intent(in)  :: f,k,df,j,ignoredx,upwind
!
    endsubroutine der6
!***********************************************************************
    subroutine der2_minmod(f,j,delfk,delfkp1,delfkm1,k)
!
!  Dummy routine
!
      intent(in) :: f,k,j
      intent(in) :: delfk,delfkp1,delfkm1
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: delfk,delfkp1,delfkm1,fac
      real, dimension (nx,-1:1) :: delf
      real, dimension (0:nx+1) :: delfx
      integer :: j,k
      integer :: i,ii,ix
!
    endsubroutine der2_minmod
!***********************************************************************
!   real function minmod(a,b,c)
!
!  Dummy routine
!
!     real :: a,b,c
!
!   endfunction minmod
!***********************************************************************
    subroutine der6_other(f,df,j,ignoredx,upwind)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real, dimension (nx) :: df,fac
      integer :: j
      logical, optional :: ignoredx,upwind
      logical :: igndx,upwnd
      intent(in)  :: f,df,j,ignoredx,upwind
!
    endsubroutine der6_other
!***********************************************************************
    real function der5_single(f,j,dc1)
!
!  Dummy routine
!
      real, dimension(:),  intent(in) :: f, dc1
      integer           ,  intent(in) :: j
!
      der5_single=0.
!
    endfunction der5_single
!***********************************************************************
    subroutine derij_main(f,k,df,i,j,lwo_line_elem)
!
!  Dummy routine
!
      use General, only: loptest
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df,fac
      integer :: i,j,k
      logical, optional :: lwo_line_elem
      intent(in) :: f,k,df,i,j
!
    endsubroutine derij_main
!***********************************************************************
    subroutine derij_other(f,df,i,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real, dimension (nx) :: df,fac
      integer :: i,j
      intent(in)  :: f,df,i,j
!
    endsubroutine derij_other
!***********************************************************************
    subroutine der5i1j(f,k,df,i,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df,fac
      integer :: i,j,k
      intent(in) :: f,k,df,i,j
!
    endsubroutine der5i1j
!***********************************************************************
    subroutine der4i2j(f,k,df,i,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: df,fac
      integer :: i,j,k
      intent(in) :: f,k,df,i,j
!
    endsubroutine der4i2j
!***********************************************************************
    subroutine der2i2j2k(f,k,df)
!      
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray),intent(in) :: f
      real, dimension (nx) :: fac
      integer,intent(in) :: k
      real, dimension(nx), intent(in) :: df
!
    endsubroutine der2i2j2k
!***********************************************************************
    subroutine der3i3j(f,k,df,i,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx), intent(in) :: df
      real, dimension (nx) :: fac
      integer, intent(in) :: k,i,j
!
    endsubroutine der3i3j
!***********************************************************************          
    subroutine der3i2j1k(f,ik,df,i,j,k)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx), intent(in) :: df
      real, dimension (nx) :: fac
      integer, intent(in) :: ik,i,j,k
!
    endsubroutine der3i2j1k
!***********************************************************************
    subroutine der4i1j1k(f,ik,df,i,j,k)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx), intent(in) :: df
      real, dimension (nx) :: fac
      integer, intent(in) :: ik,i,j,k
!
    endsubroutine der4i1j1k
!***********************************************************************
    subroutine der_upwind1st(f,uu,k,df,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx,3) :: uu
      real, dimension (nx) :: df
      integer :: j,k,l
      intent(in)  :: f,uu,k,j
      intent(in) :: df
!
    endsubroutine der_upwind1st
!***********************************************************************
    subroutine der_onesided_4_slice_main(f,sgn,k,df,pos,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (:,:) :: df
      real :: fac
      integer :: pos,k,sgn,j
      intent(in)  :: f,k,pos,sgn,j
      intent(in) :: df
!
    endsubroutine der_onesided_4_slice_main
!***********************************************************************
    subroutine der_onesided_4_slice_main_pt(f,sgn,k,df,lll,mmm,nnn,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real  :: df
      real :: fac
      integer :: pos,lll,mmm,nnn,k,sgn,j
      intent(in)  :: f,k,df,lll,mmm,nnn,sgn,j
!
    endsubroutine der_onesided_4_slice_main_pt
!***********************************************************************
    subroutine der_onesided_4_slice_other(f,sgn,df,pos,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real, dimension (:,:) :: df
      real :: fac
      integer :: pos,sgn,j
      intent(in)  :: f,df,pos,sgn,j
!
    endsubroutine der_onesided_4_slice_other
!***********************************************************************
    subroutine der_onesided_4_slice_other_pt(f,sgn,df,lll,mmm,nnn,j)
!
!  Dummy routine
!
      real, dimension (mx,my,mz) :: f
      real :: df
      real :: fac
      integer :: pos,lll,mmm,nnn,sgn,j
      intent(in)  :: f,df,lll,mmm,nnn,sgn,j
!
    endsubroutine der_onesided_4_slice_other_pt
!***********************************************************************
    subroutine finalize_deriv
!
!  Dummy
!
    endsubroutine finalize_deriv
!***********************************************************************
    subroutine deri_3d_inds(f,df,inds,j,lignored,lnometric)
!
!  dummy routine for compatibility
!
      real, dimension (mx,my,mz)          :: f
      real, dimension (nx)                :: df
      integer                             :: j
      logical,                   optional :: lignored, lnometric
      integer, dimension(nx)              :: inds
!
      intent(in)  :: f,df,j,inds,lignored,lnometric
!
    endsubroutine deri_3d_inds
!************************************************************************
    logical function heatflux_deriv_x(f, inh, fac, topbot)
!
!   dummy routine
!
      real, dimension(mx,my,mz,mfarray), intent(IN):: f
      real, dimension(my,mz)           , intent(IN):: inh
      real                             , intent(IN):: fac
      integer                          , intent(IN):: topbot
!
      heatflux_deriv_x = .true.
!
    endfunction heatflux_deriv_x
!***********************************************************************
    subroutine bval_from_neumann_scl(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real :: val
!
    endsubroutine bval_from_neumann_scl
!***********************************************************************
    subroutine bval_from_3rd_scl(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real :: val
!
    endsubroutine bval_from_3rd_scl
!***********************************************************************
    subroutine bval_from_4th_scl(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real :: val
!
    endsubroutine bval_from_4th_scl
!***********************************************************************
    subroutine set_ghosts_for_onesided_ders(f,topbot,j,idir,l2nd)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      logical, optional :: l2nd
!
    endsubroutine set_ghosts_for_onesided_ders
!***********************************************************************
    subroutine bval_from_neumann_arr(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real, dimension(:,:) :: val
!
    endsubroutine bval_from_neumann_arr
!***********************************************************************
    subroutine bval_from_3rd_arr(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real, dimension(:,:) :: val
!
    endsubroutine bval_from_3rd_arr
!***********************************************************************
    subroutine bval_from_4th_arr(f,topbot,j,idir,val)
!
!  Dummy routine
!
      real, dimension(mx,my,mz,*) :: f
      character(LEN=3) :: topbot
      integer :: j,idir
      real, dimension(:,:) :: val
!
    endsubroutine bval_from_4th_arr
!***********************************************************************
 endmodule Deriv

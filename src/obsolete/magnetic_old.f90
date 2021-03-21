! $Id$
!
!  This modules deals with all aspects of magnetic fields; if no
!  magnetic fields are invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  magnetically relevant subroutines listed in here.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lmagnetic = .true.
!
! MVAR CONTRIBUTION 3
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED aa(3); a2; aij(3,3); bb(3); bbb(3); ab; ua; uxb(3); exa(3)
! PENCILS PROVIDED b2; bij(3,3); del2a(3); graddiva(3); jj(3)
! PENCILS PROVIDED j2; jb; va2; jxb(3); jxbr(3); jxbr2; ub; uxb(3); uxb2
! PENCILS PROVIDED uxj(3); beta; uga(3); djuidjbi; jo
! PENCILS PROVIDED ujxb; oxu(3); oxuxb(3); jxbxb(3); jxbrxb(3)
! PENCILS PROVIDED glnrhoxb(3); del4a(3); del6a(3); oxj(3); diva
! PENCILS PROVIDED jij(3,3); sj; ss12
! PENCILS PROVIDED etava, etaj, etaj2, etajrho
! PENCILS PROVIDED cosjb,jparallel;jperp
! PENCILS PROVIDED cosub
!
!***************************************************************
module Magnetic
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Magnetic_meanfield
  use Messages, only: fatal_error,inevitably_fatal_error,warning,svn_id,timing
!
  implicit none
!
  include 'record_types.h'
  include 'magnetic.h'
!
! Slice precalculation buffers
!
  real, target, dimension (nx,ny,3) :: bb_xy, jj_xy
  real, target, dimension (nx,ny,3) :: bb_xy2, jj_xy2
  real, target, dimension (nx,ny,3) :: bb_xy3, jj_xy3
  real, target, dimension (nx,ny,3) :: bb_xy4, jj_xy4
  real, target, dimension (nx,nz,3) :: bb_xz, jj_xz
  real, target, dimension (ny,nz,3) :: bb_yz, jj_yz
!
  real, target, dimension (nx,ny) :: b2_xy, jb_xy
  real, target, dimension (nx,ny) :: b2_xy2, jb_xy2
  real, target, dimension (nx,ny) :: b2_xy3, jb_xy3
  real, target, dimension (nx,ny) :: b2_xy4, jb_xy4
  real, target, dimension (ny,nz) :: b2_yz, jb_yz
  real, target, dimension (nx,nz) :: b2_xz, jb_xz
!
  real, target, dimension (nx,ny) :: beta_xy
  real, target, dimension (nx,ny) :: beta_xy2
  real, target, dimension (nx,ny) :: beta_xy3
  real, target, dimension (nx,ny) :: beta_xy4
  real, target, dimension (ny,nz) :: beta_yz
  real, target, dimension (nx,nz) :: beta_xz
!
!  xy-averaged field
!
  real, dimension (mz,3) :: aamz
  real, dimension (nz,3) :: bbmz,jjmz
!
! Parameters
!
  integer, parameter :: nresi_max=4
!
  real, dimension (ninit) :: amplaa=0.0, kx_aa=1.0, ky_aa=1.0, kz_aa=1.0
  real, dimension (ninit) :: phasex_aa=0.0, phasey_aa=0.0, phasez_aa=0.0
  character (len=labellen), dimension(ninit) :: initaa='nothing'
  character (len=labellen) :: borderaa='nothing'
  character (len=labellen), dimension(nresi_max) :: iresistivity=''
!
! Input parameters
!
  complex, dimension(3) :: coefaa=(/0.0,0.0,0.0/), coefbb=(/0.0,0.0,0.0/)
  real, dimension(3) :: B_ext=(/0.0,0.0,0.0/), B1_ext, B_ext_inv, B_ext_tmp
  real, dimension(3) :: eta_aniso_hyper3
  real, dimension(nx,3) :: uxbb
  real, target :: zmode=1.0 !(temporary)
  real :: radius=0.1, epsilonaa=0.01, widthaa=0.5, x0aa=0.0, z0aa=0.0
  real :: by_left=0.0, by_right=0.0, bz_left=0.0, bz_right=0.0
  real :: relhel_aa=1.
  real :: bthresh=0.0, bthresh_per_brms=0.0, brms=0.0, bthresh_scl=1.0
  real :: eta_shock=0.0
  real :: eta_va=0., eta_j=0., eta_j2=0., eta_jrho=0., eta_min=0., etaj20=0.
  real :: rhomin_jxb=0.0, va2max_jxb=0.0
  real :: omega_Bz_ext=0.0
  real :: mu_r=-0.5 !(still needed for backwards compatibility)
  real :: mu_ext_pot=-0.5,inclaa=0.0
  real :: mu012=0.5 !(=1/2mu0)
  real :: rescale_aa=0.0
  real :: ampl_B0=0.0, D_smag=0.17, B_ext21, B_ext11
  real :: rmode=1.0, rm_int=0.0, rm_ext=0.0
  real :: nu_ni=0.0, nu_ni1,hall_term=0.0
  real :: initpower_aa=0.0, cutoff_aa=0.0, brms_target=1.0
  real :: rescaling_fraction=1.0
  real :: phase_beltrami=0.0, ampl_beltrami=0.0
  real :: bmz=0, bmz_beltrami_phase=0.0
  real :: taareset=0.0, daareset=0.0
  real :: center1_x=0.0, center1_y=0.0, center1_z=0.0
  real :: fluxtube_border_width=impossible
  real :: eta_jump=0.0
  real :: rnoise_int=impossible,rnoise_ext=impossible
  integer :: nbvec,nbvecmax=nx*ny*nz/4, va2power_jxb=5
  integer :: N_modes_aa=1, naareset
  integer :: nrings=2
  logical :: lpress_equil=.false., lpress_equil_via_ss=.false.
  logical :: lpress_equil_alt=.false.
  logical :: llorentzforce=.true., linduction=.true.
  logical :: lresi_eta_const=.false.
  logical :: lresi_sqrtrhoeta_const=.false.
  logical :: lresi_etaSS=.false.
  logical :: lresi_hyper2=.false.
  logical :: lresi_hyper3=.false.
  logical :: lresi_hyper3_polar=.false.
  logical :: lresi_hyper3_strict=.false.
  logical :: lresi_zdep=.false., lresi_dust=.false., lresi_xydep=.false.
  logical :: lresi_hyper3_aniso=.false.
  logical :: lresi_eta_shock=.false.
  logical :: lresi_eta_shock_perp=.false.
  logical :: lresi_etava=.false.
  logical :: lresi_etaj=.false.
  logical :: lresi_etaj2=.false.
  logical :: lresi_etajrho=.false.
  logical :: lresi_shell=.false.
  logical :: lresi_smagorinsky=.false.
  logical :: lresi_smagorinsky_cross=.false.
  logical :: lresi_anomalous=.false.
  logical :: lresi_spitzer=.false.
  logical, target, dimension (3) :: lfrozen_bb_bot=(/.false.,.false.,.false./)
  logical, target, dimension (3) :: lfrozen_bb_top=(/.false.,.false.,.false./)
  logical :: lohmic_heat=.true., lneutralion_heat=.true.
  logical :: reinitialize_aa=.false.
  logical :: lB_ext_pot=.false.
  logical :: lforce_free_test=.false.
  logical :: lforcing_cont_aa_local=.false.
  logical :: lmeanfield_theory=.false.
  logical :: lgauss=.false.
  logical :: lbb_as_aux=.false., ljj_as_aux=.false.
  logical :: lbbt_as_aux=.false., ljjt_as_aux=.false.
  logical :: lbext_curvilinear=.true., lcheck_positive_va2=.false.
  logical :: lreset_aa=.false.
!
  namelist /magnetic_init_pars/ &
      B_ext, lohmic_heat, radius, epsilonaa, x0aa, z0aa, &
      widthaa, by_left, by_right, bz_left, bz_right, &
      relhel_aa, initaa, amplaa, kx_aa, &
      ky_aa, kz_aa, coefaa, coefbb, phasex_aa, phasey_aa, phasez_aa, inclaa, &
      lpress_equil, lpress_equil_via_ss, mu_r, mu_ext_pot, lB_ext_pot, &
      lforce_free_test, ampl_B0, initpower_aa, cutoff_aa, N_modes_aa, rmode, &
      zmode, rm_int, rm_ext, lgauss, lcheck_positive_va2, lbb_as_aux, &
      ljj_as_aux, lbext_curvilinear, lbbt_as_aux, ljjt_as_aux, &
      lneutralion_heat, center1_x, center1_y, center1_z, &
      fluxtube_border_width, va2max_jxb, va2power_jxb, eta_jump,&
      lpress_equil_alt,rnoise_int,rnoise_ext
!
! Run parameters
!
  real :: eta=0.0, eta1=0.0, eta_hyper2=0.0, eta_hyper3=0.0, eta_anom=0.0
  real :: eta_spitzer=0.
  real :: eta_int=0.0, eta_ext=0.0, wresistivity=0.01, eta_xy_max=1.0
  real :: height_eta=0.0, eta_out=0.0
  real :: z_surface=0.0
  real :: tau_aa_exterior=0.0
  real :: sigma_ratio=1.0, eta_width=0.0, eta_z0=1.0, eta_z1=1.0
  real :: alphaSSm=0.0
  real :: k1_ff=1.0, ampl_ff=1.0, swirl=1.0
  real :: k1x_ff=1.0, k1y_ff=1.0, k1z_ff=1.0
  real :: inertial_length=0.0, linertial_2
  real :: forcing_continuous_aa_phasefact=1.0
  real :: forcing_continuous_aa_amplfact=1.0, ampl_fcont_aa=1.0
  real :: LLambda_aa=0.0, vcrit_anom=1.0
  real, dimension(mx,my) :: eta_xy
  real, dimension(mx,my,3) :: geta_xy
  real, dimension(mz) :: coskz,sinkz,eta_z
  real, dimension(mz,3) :: geta_z
  logical :: lfreeze_aint=.false., lfreeze_aext=.false.
  logical :: lweyl_gauge=.false., ladvective_gauge=.false.
  logical :: lupw_aa=.false.
  logical :: lcalc_aamean=.false.
  logical :: lforcing_cont_aa=.false.
  logical :: lelectron_inertia=.false.
  logical :: lremove_mean_emf=.false.
  logical :: lkinematic=.false.
  logical :: luse_Bext_in_b2=.false.
  logical :: lmean_friction=.false.
  logical :: lhalox=.false.
  logical :: lrun_initaa=.false.
  character (len=labellen) :: zdep_profile='fs'
  character (len=labellen) :: eta_xy_profile='schnack89'
  character (len=labellen) :: iforcing_continuous_aa='fixed_swirl'
!
  namelist /magnetic_run_pars/ &
      eta, eta1, eta_hyper2, eta_hyper3, eta_anom, B_ext, omega_Bz_ext, nu_ni, &
      hall_term, lmeanfield_theory, &
      z_surface, &
      tau_aa_exterior, kx_aa, ky_aa, kz_aa, &
      lcalc_aamean, &
      lforcing_cont_aa, lforcing_cont_aa_local, iforcing_continuous_aa, &
      forcing_continuous_aa_phasefact, forcing_continuous_aa_amplfact, k1_ff, &
      ampl_ff, swirl, radius, k1x_ff, k1y_ff, k1z_ff, lcheck_positive_va2, &
      lmean_friction, LLambda_aa, bthresh, bthresh_per_brms, iresistivity, &
      lweyl_gauge, ladvective_gauge, lupw_aa, &
      alphaSSm, &
      eta_ext, eta_shock, eta_va,eta_j, eta_j2, eta_jrho, eta_min, &
      wresistivity, eta_xy_max, rhomin_jxb, va2max_jxb, &
      va2power_jxb, llorentzforce, linduction, reinitialize_aa, rescale_aa, &
      lB_ext_pot, D_smag, brms_target, &
      rescaling_fraction, &
      lfreeze_aint, lfreeze_aext, sigma_ratio, zdep_profile, eta_width, &
      eta_z0, eta_z1,eta_spitzer, &
      borderaa, eta_aniso_hyper3, lelectron_inertia, inertial_length, &
      lbext_curvilinear, lbb_as_aux, ljj_as_aux, lremove_mean_emf, lkinematic, &
      lbbt_as_aux, ljjt_as_aux, lneutralion_heat, lreset_aa, daareset, &
      luse_Bext_in_b2, ampl_fcont_aa, &
      lhalox, vcrit_anom, eta_jump,&
      lrun_initaa
!
! Diagnostic variables (need to be consistent with reset list below)
!
  integer :: idiag_ab_int=0     ! DIAG_DOC: $\int\Av\cdot\Bv\;dV$
  integer :: idiag_jb_int=0     ! DIAG_DOC: $\int\jv\cdot\Bv\;dV$
  integer :: idiag_b2tm=0       ! DIAG_DOC: $\left<\bv(t)\cdot\int_0^t\bv(t')
                                ! DIAG_DOC:   dt'\right>$
  integer :: idiag_bjtm=0       ! DIAG_DOC: $\left<\bv(t)\cdot\int_0^t\jv(t')
                                ! DIAG_DOC:   dt'\right>$
  integer :: idiag_jbtm=0       ! DIAG_DOC: $\left<\jv(t)\cdot\int_0^t\bv(t')
                                ! DIAG_DOC:   dt'\right>$
  integer :: idiag_b2ruzm=0     ! DIAG_DOC: $\left<\Bv^2\rho u_z\right>$
  integer :: idiag_b2uzm=0      ! DIAG_DOC: $\left<\Bv^2u_z\right>$
  integer :: idiag_ubbzm=0      ! DIAG_DOC: $\left<(\uv\cdot\Bv)B_z\right>$
  integer :: idiag_b1m=0        ! DIAG_DOC: $\left<|\Bv|\right>$
  integer :: idiag_b2m=0        ! DIAG_DOC: $\left<\Bv^2\right>$
  integer :: idiag_bm2=0        ! DIAG_DOC: $\max(\Bv^2)$
  integer :: idiag_j2m=0        ! DIAG_DOC: $\left<\jv^2\right>$
  integer :: idiag_jm2=0        ! DIAG_DOC: $\max(\jv^2)$
  integer :: idiag_abm=0        ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$
  integer :: idiag_abumx=0      ! DIAG_DOC: $\left<u_x\Av\cdot\Bv\right>$
  integer :: idiag_abumy=0      ! DIAG_DOC: $\left<u_y\Av\cdot\Bv\right>$
  integer :: idiag_abumz=0      ! DIAG_DOC: $\left<u_z\Av\cdot\Bv\right>$
  integer :: idiag_abmh=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (temp)
  integer :: idiag_abmn=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (north)
  integer :: idiag_abms=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (south)
  integer :: idiag_abrms=0      ! DIAG_DOC: $\left<(\Av\cdot\Bv)^2\right>^{1/2}$
  integer :: idiag_ajm=0        ! DIAG_DOC: $\left<\jv\cdot\Av\right>$
  integer :: idiag_jbm=0        ! DIAG_DOC: $\left<\jv\cdot\Bv\right>$
  integer :: idiag_jbmh=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (temp)
  integer :: idiag_jbmn=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (north)
  integer :: idiag_jbms=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>$ (south)
  integer :: idiag_ubm=0        ! DIAG_DOC: $\left<\uv\cdot\Bv\right>$
  integer :: idiag_dubrms=0     ! DIAG_DOC: $\left<(\uv-\Bv)^2\right>^{1/2}$
  integer :: idiag_dobrms=0     ! DIAG_DOC: $\left<(\boldsymbol{\omega}-\Bv)^2\right>^{1/2}$
  integer :: idiag_uxbxm=0      ! DIAG_DOC: $\left<u_xB_x\right>$
  integer :: idiag_uybym=0      ! DIAG_DOC: $\left<u_yB_y\right>$
  integer :: idiag_uzbzm=0      ! DIAG_DOC: $\left<u_zB_z\right>$
  integer :: idiag_cosubm=0     ! DIAG_DOC: $\left<\Uv\cdot\Bv/(|\Uv|\,|\Bv|)\right>$
  integer :: idiag_uam=0        ! DIAG_DOC: $\left<\uv\cdot\Av\right>$
  integer :: idiag_ujm=0        ! DIAG_DOC: $\left<\uv\cdot\Jv\right>$
  integer :: idiag_fbm=0        ! DIAG_DOC: $\left<\fv\cdot\Bv\right>$
  integer :: idiag_fxbxm=0      ! DIAG_DOC: $\left<f_x B_x\right>$
  integer :: idiag_epsM=0       ! DIAG_DOC: $\left<2\eta\mu_0\jv^2\right>$
  integer :: idiag_epsAD=0      ! DIAG_DOC: $\left<\rho^{-1} t_{\rm AD} (\vec{J}\times\vec{B})^2\right>$ (heating by ion-neutrals friction)
  integer :: idiag_bxpt=0       ! DIAG_DOC: $B_x(x_0,y_0,z_0,t)$
  integer :: idiag_bypt=0       ! DIAG_DOC: $B_y(x_0,y_0,z_0,t)$
  integer :: idiag_bzpt=0       ! DIAG_DOC: $B_z(x_0,y_0,z_0,t)$
  integer :: idiag_Expt=0       ! DIAG_DOC: ${\cal E}_x(x_0,y_0,z_0,t)$
  integer :: idiag_Eypt=0       ! DIAG_DOC: ${\cal E}_y(x_0,y_0,z_0,t)$
  integer :: idiag_Ezpt=0       ! DIAG_DOC: ${\cal E}_z(x_0,y_0,z_0,t)$
  integer :: idiag_epsM_LES=0   ! DIAG_DOC:
  integer :: idiag_aybym2=0     ! DIAG_DOC:
  integer :: idiag_exaym2=0     ! DIAG_DOC:
  integer :: idiag_exabot=0     ! DIAG_DOC: $\int\Ev\times\Av\,dS|_{\rm bot}$
  integer :: idiag_exatop=0     ! DIAG_DOC: $\int\Ev\times\Av\,dS|_{\rm top}$
  integer :: idiag_exjm2=0      ! DIAG_DOC:
  integer :: idiag_emag=0       ! DIAG_DOC: $\int_V{1\over2\mu_0}\Bv^2\, dV$
  integer :: idiag_brms=0       ! DIAG_DOC: $\left<\Bv^2\right>^{1/2}$
  integer :: idiag_bmax=0       ! DIAG_DOC: $\max(|\Bv|)$
  integer :: idiag_bxmin=0      ! DIAG_DOC: $\min(|B_x|)$
  integer :: idiag_bymin=0      ! DIAG_DOC: $\min(|B_y|)$
  integer :: idiag_bzmin=0      ! DIAG_DOC: $\min(|B_z|)$
  integer :: idiag_bxmax=0      ! DIAG_DOC: $\max(|B_x|)$
  integer :: idiag_bymax=0      ! DIAG_DOC: $\max(|B_y|)$
  integer :: idiag_bzmax=0      ! DIAG_DOC: $\max(|B_z|)$
  integer :: idiag_jrms=0       ! DIAG_DOC: $\left<\jv^2\right>^{1/2}$
  integer :: idiag_jmax=0       ! DIAG_DOC: $\max(|\jv|)$
  integer :: idiag_vArms=0      ! DIAG_DOC: $\left<\Bv^2/\varrho\right>^{1/2}$
  integer :: idiag_vAmax=0      ! DIAG_DOC: $\max(\Bv^2/\varrho)^{1/2}$
  integer :: idiag_dtb=0        ! DIAG_DOC: $\delta t / [c_{\delta t}\,\delta x
                                ! DIAG_DOC:   /v_{\rm A,max}]$
                                ! DIAG_DOC:   \quad(time step relative to
                                ! DIAG_DOC:   Alfv{\'e}n time step;
                                ! DIAG_DOC:   see \S~\ref{time-step})
  integer :: idiag_dteta=0      ! DIAG_DOC: $\delta t/[c_{\delta t,{\rm v}}\,
                                ! DIAG_DOC:   \delta x^2/\eta_{\rm max}]$
                                ! DIAG_DOC:   \quad(time step relative to
                                ! DIAG_DOC:   resistive time step;
                                ! DIAG_DOC:   see \S~\ref{time-step})
  integer :: idiag_axm=0        ! DIAG_DOC:
  integer :: idiag_aym=0        ! DIAG_DOC:
  integer :: idiag_azm=0        ! DIAG_DOC:
  integer :: idiag_arms=0       ! DIAG_DOC:
  integer :: idiag_amax=0       ! DIAG_DOC:
  integer :: idiag_beta1m=0     ! DIAG_DOC: $\left<\Bv^2/(2\mu_0 p)\right>$
                                ! DIAG_DOC:   \quad(mean inverse plasma beta)
  integer :: idiag_beta1max=0   ! DIAG_DOC: $\max[\Bv^2/(2\mu_0 p)]$
                                ! DIAG_DOC:   \quad(maximum inverse plasma beta)
  integer :: idiag_bxm=0        ! DIAG_DOC: $\left<\left<B\right>_{yz}^2\right>_x^{1/2}$
  integer :: idiag_bym=0        ! DIAG_DOC: $\left<\left<B\right>_{zx}^2\right>_y^{1/2}$
  integer :: idiag_bzm=0        ! DIAG_DOC: $\left<\left<B\right>_{xy}^2\right>_z^{1/2}$
  integer :: idiag_bx2m=0       ! DIAG_DOC: $\left<B_x^2\right>$
  integer :: idiag_by2m=0       ! DIAG_DOC: $\left<B_y^2\right>$
  integer :: idiag_bz2m=0       ! DIAG_DOC: $\left<B_z^2\right>$
  integer :: idiag_bx2mx=0      ! DIAG_DOC: $\left<B_x^2\right>_{yz}$
  integer :: idiag_by2mx=0      ! DIAG_DOC: $\left<B_y^2\right>_{yz}$
  integer :: idiag_bz2mx=0      ! DIAG_DOC: $\left<B_z^2\right>_{yz}$
  integer :: idiag_bxbym=0      ! DIAG_DOC: $\left<B_x B_y\right>$
  integer :: idiag_bxbymx=0     ! DIAG_DOC: $\left<B_x B_y\right>_{yz}$
  integer :: idiag_bxbzm=0      ! DIAG_DOC:
  integer :: idiag_bybzm=0      ! DIAG_DOC:
  integer :: idiag_djuidjbim=0  ! DIAG_DOC:
  integer :: idiag_bxbymy=0     ! DIAG_DOC:
  integer :: idiag_bxbzmy=0     ! DIAG_DOC:
  integer :: idiag_bybzmy=0     ! DIAG_DOC:
  integer :: idiag_bxbymz=0     ! DIAG_DOC:
  integer :: idiag_bxbzmz=0     ! DIAG_DOC:
  integer :: idiag_bybzmz=0     ! DIAG_DOC:
  integer :: idiag_b2mz=0       ! DIAG_DOC:
  integer :: idiag_axmz=0       ! DIAG_DOC: $\left<{\cal A}_x\right>_{xy}$
  integer :: idiag_aymz=0       ! DIAG_DOC: $\left<{\cal A}_y\right>_{xy}$
  integer :: idiag_azmz=0       ! DIAG_DOC: $\left<{\cal A}_z\right>_{xy}$
  integer :: idiag_abuxmz=0     ! DIAG_DOC: $\left<(\Av \cdot \Bv) u_x \right>_{xy}$
  integer :: idiag_abuymz=0     ! DIAG_DOC: $\left<(\Av \cdot \Bv) u_y \right>_{xy}$
  integer :: idiag_abuzmz=0     ! DIAG_DOC: $\left<(\Av \cdot \Bv) u_z \right>_{xy}$
  integer :: idiag_uabxmz=0     ! DIAG_DOC: $\left<(\uv \cdot \Av) B_x \right>_{xy}$
  integer :: idiag_uabymz=0     ! DIAG_DOC: $\left<(\uv \cdot \Av) B_y \right>_{xy}$
  integer :: idiag_uabzmz=0     ! DIAG_DOC: $\left<(\uv \cdot \Av) B_z \right>_{xy}$
  integer :: idiag_bbxmz=0      ! DIAG_DOC: $\left<{\cal B}'_x\right>_{xy}$
  integer :: idiag_bbymz=0      ! DIAG_DOC: $\left<{\cal B}'_y\right>_{xy}$
  integer :: idiag_bbzmz=0      ! DIAG_DOC: $\left<{\cal B}'_z\right>_{xy}$
  integer :: idiag_bxmz=0       ! DIAG_DOC: $\left<{\cal B}_x\right>_{xy}$
  integer :: idiag_bymz=0       ! DIAG_DOC: $\left<{\cal B}_y\right>_{xy}$
  integer :: idiag_bzmz=0       ! DIAG_DOC: $\left<{\cal B}_z\right>_{xy}$
  integer :: idiag_jxmz=0       ! DIAG_DOC: $\left<{\cal J}_x\right>_{xy}$
  integer :: idiag_jymz=0       ! DIAG_DOC: $\left<{\cal J}_y\right>_{xy}$
  integer :: idiag_jzmz=0       ! DIAG_DOC: $\left<{\cal J}_z\right>_{xy}$
  integer :: idiag_Exmz=0       ! DIAG_DOC: $\left<{\cal E}_x\right>_{xy}$
  integer :: idiag_Eymz=0       ! DIAG_DOC: $\left<{\cal E}_y\right>_{xy}$
  integer :: idiag_Ezmz=0       ! DIAG_DOC: $\left<{\cal E}_z\right>_{xy}$
  integer :: idiag_bmx=0        ! DIAG_DOC: $\left<\left<\Bv\right>_{yz}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $yz$-averaged
                                ! DIAG_DOC:   mean field)
  integer :: idiag_bmy=0        ! DIAG_DOC: $\left<\left<\Bv\right>_{xz}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $xz$-averaged
                                ! DIAG_DOC:   mean field)
  integer :: idiag_bmz=0        ! DIAG_DOC: $\left<\left<\Bv\right>_{xy}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $xy$-averaged
                                ! DIAG_DOC:   mean field)
  integer :: idiag_bmzS2=0      ! DIAG_DOC: $\left<\left<\Bv_S\right>_{xy}^2\right>$
  integer :: idiag_bmzA2=0      ! DIAG_DOC: $\left<\left<\Bv_A\right>_{xy}^2\right>$
  integer :: idiag_jmx=0        ! DIAG_DOC: $\left<\left<\Jv\right>_{yz}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $yz$-averaged
                                ! DIAG_DOC:   mean current density)
  integer :: idiag_jmy=0        ! DIAG_DOC: $\left<\left<\Jv\right>_{xz}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $xz$-averaged
                                ! DIAG_DOC:   mean current density)
  integer :: idiag_jmz=0        ! DIAG_DOC: $\left<\left<\Jv\right>_{xy}^2
                                ! DIAG_DOC:   \right>^{1/2}$
                                ! DIAG_DOC:   \quad(energy of $xy$-averaged
                                ! DIAG_DOC:   mean current density)
  integer :: idiag_bmzph=0      ! DIAG_DOC: Phase of a Beltrami field
  integer :: idiag_bmzphe=0     ! DIAG_DOC: Error of phase of a Beltrami field
  integer :: idiag_bsinphz=0    ! DIAG_DOC: sine of phase of a Beltrami field
  integer :: idiag_bcosphz=0    ! DIAG_DOC: cosine of phase of a Beltrami field
  integer :: idiag_emxamz3=0    ! DIAG_DOC: $\left<\left<\Ev\right>_{xy}\times\left<\Av\right>_{xy}
                                ! DIAG_DOC:   \right>$ \quad($xy$-averaged
                                ! DIAG_DOC:   mean field helicity flux)
  integer :: idiag_embmz=0      ! DIAG_DOC: $\left<\left<\Ev\right>_{xy}\cdot\left<\Bv\right>_{xy}
                                ! DIAG_DOC:   \right>$ \quad($xy$-averaged
                                ! DIAG_DOC:   mean field helicity production )
  integer :: idiag_ambmz=0      ! DIAG_DOC: $\left<\left<\Av\right>_{xy}\cdot\left<\Bv\right>_{xy}\right>$
                                ! DIAG_DOC:   \quad (magnetic helicity of $xy$-averaged mean field)
  integer :: idiag_ambmzh=0     ! DIAG_DOC: $\left<\left<\Av\right>_{xy}\cdot\left<\Bv\right>_{xy}\right>$
                                ! DIAG_DOC:   \quad (magnetic helicity of $xy$-averaged mean field, temp)
  integer :: idiag_ambmzn=0     ! DIAG_DOC: $\left<\left<\Av\right>_{xy}\cdot\left<\Bv\right>_{xy}\right>$
                                ! DIAG_DOC:   \quad (magnetic helicity of $xy$-averaged mean field, north)
  integer :: idiag_ambmzs=0     ! DIAG_DOC: $\left<\left<\Av\right>_{xy}\cdot\left<\Bv\right>_{xy}\right>$
                                ! DIAG_DOC:   \quad (magnetic helicity of $xy$-averaged mean field, south)
  integer :: idiag_jmbmz=0      ! DIAG_DOC: $\left<\left<\Jv\right>_{xy}\cdot\left<\Bv\right>_{xy}
                                ! DIAG_DOC:   \right>$ \quad(current helicity
                                ! DIAG_DOC:   of $xy$-averaged mean field)
  integer :: idiag_kx_aa=0      ! DIAG_DOC: $k_x$
  integer :: idiag_kmz=0        ! DIAG_DOC: $\left<\left<\Jv\right>_{xy}\cdot\left<\Bv\right>_{xy}\right>/
                                ! DIAG_DOC:  \left<\left<\Bv\right>_{xy}^2\right>$
  integer :: idiag_bx2my=0      ! DIAG_DOC: $\left< B_x^2 \right>_{xz}$
  integer :: idiag_by2my=0      ! DIAG_DOC: $\left< B_y^2 \right>_{xz}$
  integer :: idiag_bz2my=0      ! DIAG_DOC: $\left< B_z^2 \right>_{xz}$
  integer :: idiag_bx2mz=0      ! DIAG_DOC: $\left< B_x^2 \right>_{xy}$
  integer :: idiag_by2mz=0      ! DIAG_DOC: $\left< B_y^2 \right>_{xy}$
  integer :: idiag_bz2mz=0      ! DIAG_DOC: $\left< B_z^2 \right>_{xy}$
  integer :: idiag_bx2rmz=0     ! DIAG_DOC: $\left< B_x^2/\varrho \right>_{xy}$
  integer :: idiag_by2rmz=0     ! DIAG_DOC: $\left< B_y^2/\varrho \right>_{xy}$
  integer :: idiag_bz2rmz=0     ! DIAG_DOC: $\left< B_z^2/\varrho \right>_{xy}$
  integer :: idiag_jbmz=0       ! DIAG_DOC: $\left<\Jv\cdot\Bv\right>|_{xy}$
  integer :: idiag_abmz=0       ! DIAG_DOC: $\left<\Av\cdot\Bv\right>|_{xy}$
  integer :: idiag_uamz=0       ! DIAG_DOC: $\left<\uv\cdot\Av\right>|_{xy}$
  integer :: idiag_examz1=0     ! DIAG_DOC: $\left<\Ev\times\Av\right>_{xy}|_x$
  integer :: idiag_examz2=0     ! DIAG_DOC: $\left<\Ev\times\Av\right>_{xy}|_y$
  integer :: idiag_examz3=0     ! DIAG_DOC: $\left<\Ev\times\Av\right>_{xy}|_z$
  integer :: idiag_bxmxy=0      ! DIAG_DOC: $\left< B_x \right>_{xy}$
  integer :: idiag_bymxy=0      ! DIAG_DOC: $\left< B_y \right>_{xy}$
  integer :: idiag_bzmxy=0      ! DIAG_DOC: $\left< B_z \right>_{xy}$
  integer :: idiag_jxmxy=0      ! DIAG_DOC: $\left< J_x \right>_{xy}$
  integer :: idiag_jymxy=0      ! DIAG_DOC: $\left< J_y \right>_{xy}$
  integer :: idiag_jzmxy=0      ! DIAG_DOC: $\left< J_z \right>_{xy}$
  integer :: idiag_axmxz=0      ! DIAG_DOC: $\left< A_x \right>_{xz}$
  integer :: idiag_aymxz=0      ! DIAG_DOC: $\left< A_y \right>_{xz}$
  integer :: idiag_azmxz=0      ! DIAG_DOC: $\left< A_z \right>_{xz}$
  integer :: idiag_bxmxz=0      ! DIAG_DOC: $\left< B_x \right>_{xz}$
  integer :: idiag_bymxz=0      ! DIAG_DOC: $\left< B_y \right>_{xz}$
  integer :: idiag_bzmxz=0      ! DIAG_DOC: $\left< B_z \right>_{xz}$
  integer :: idiag_bx2mxz=0     ! DIAG_DOC: $\left< B_x^2 \right>_{xz}$
  integer :: idiag_by2mxz=0     ! DIAG_DOC: $\left< B_y^2 \right>_{xz}$
  integer :: idiag_bz2mxz=0     ! DIAG_DOC: $\left< B_z^2 \right>_{xz}$
  integer :: idiag_bx2mxy=0     ! DIAG_DOC: $\left< B_x^2 \right>_{z}$
  integer :: idiag_by2mxy=0     ! DIAG_DOC: $\left< B_y^2 \right>_{z}$
  integer :: idiag_bz2mxy=0     ! DIAG_DOC: $\left< B_z^2 \right>_{z}$
  integer :: idiag_bxbymxy=0    ! DIAG_DOC: $\left< B_x B_y \right>_{z}$
  integer :: idiag_bxbzmxy=0    ! DIAG_DOC: $\left< B_x B_z \right>_{z}$
  integer :: idiag_bybzmxy=0    ! DIAG_DOC: $\left< B_y B_z \right>_{z}$
  integer :: idiag_bxbymxz=0    ! DIAG_DOC: $\left< B_x B_y \right>_{y}$
  integer :: idiag_bxbzmxz=0    ! DIAG_DOC: $\left< B_x B_z \right>_{y}$
  integer :: idiag_bybzmxz=0    ! DIAG_DOC: $\left< B_y B_z \right>_{y}$
  integer :: idiag_uxbm=0       ! DIAG_DOC: $\left<\uv\times\Bv\right>\cdot\Bv_0/B_0^2$
  integer :: idiag_jxbm=0       ! DIAG_DOC: $\left<\jv\times\Bv\right>\cdot\Bv_0/B_0^2$
  integer :: idiag_oxuxbm=0     ! DIAG_DOC:
  integer :: idiag_jxbxbm=0     ! DIAG_DOC:
  integer :: idiag_gpxbm=0      ! DIAG_DOC:
  integer :: idiag_uxDxuxbm=0   ! DIAG_DOC:
  integer :: idiag_jbmphi=0     ! PHIAVG_DOC: $\left<\Jv\cdot\Bv\right>_\varphi$
  integer :: idiag_b3b21m=0     ! DIAG_DOC: $\left<B_3 B_{2,1} \right>$
  integer :: idiag_b1b32m=0     ! DIAG_DOC: $\left<B_1 B_{3,2} \right>$
  integer :: idiag_b2b13m=0     ! DIAG_DOC: $\left<B_2 B_{1,3} \right>$
  integer :: idiag_udotxbm=0    ! DIAG_DOC:
  integer :: idiag_uxbdotm=0    ! DIAG_DOC:
  integer :: idiag_uxbmx=0      ! DIAG_DOC: $\left<(\uv\times\Bv)_x\right>$
  integer :: idiag_uxbmy=0      ! DIAG_DOC: $\left<(\uv\times\Bv)_y\right>$
  integer :: idiag_uxbmz=0      ! DIAG_DOC: $\left<(\uv\times\Bv)_z\right>$
  integer :: idiag_jxbmx=0      ! DIAG_DOC: $\left<(\jv\times\Bv)_x\right>$
  integer :: idiag_jxbmy=0      ! DIAG_DOC: $\left<(\jv\times\Bv)_y\right>$
  integer :: idiag_jxbmz=0      ! DIAG_DOC: $\left<(\jv\times\Bv)_z\right>$
  integer :: idiag_uxbcmx=0     ! DIAG_DOC:
  integer :: idiag_uxbcmy=0     ! DIAG_DOC:
  integer :: idiag_uxbsmx=0     ! DIAG_DOC:
  integer :: idiag_uxbsmy=0     ! DIAG_DOC:
  integer :: idiag_examx=0      ! DIAG_DOC: $\left<\Ev\times\Av\right>|_x$
  integer :: idiag_examy=0      ! DIAG_DOC: $\left<\Ev\times\Av\right>|_y$
  integer :: idiag_examz=0      ! DIAG_DOC: $\left<\Ev\times\Av\right>|_z$
  integer :: idiag_exjmx=0      ! DIAG_DOC: $\left<\Ev\times\Jv\right>|_x$
  integer :: idiag_exjmy=0      ! DIAG_DOC: $\left<\Ev\times\Jv\right>|_y$
  integer :: idiag_exjmz=0      ! DIAG_DOC: $\left<\Ev\times\Jv\right>|_z$
  integer :: idiag_dexbmx=0     ! DIAG_DOC: $\left<\nabla\times\Ev\times\Bv\right>|_x$
  integer :: idiag_dexbmy=0     ! DIAG_DOC: $\left<\nabla\times\Ev\times\Bv\right>|_y$
  integer :: idiag_dexbmz=0     ! DIAG_DOC: $\left<\nabla\times\Ev\times\Bv\right>|_z$
  integer :: idiag_phibmx=0     ! DIAG_DOC: $\left<\phi\Bv\right>|_x$
  integer :: idiag_phibmy=0     ! DIAG_DOC: $\left<\phi\Bv\right>|_y$
  integer :: idiag_phibmz=0     ! DIAG_DOC: $\left<\phi\Bv\right>|_z$
  integer :: idiag_uxjm=0       ! DIAG_DOC:
  integer :: idiag_brmphi=0     ! PHIAVG_DOC: $\left<B_\varpi\right>_\varphi$
                                ! PHIAVG_DOC: [cyl.\ polar coords
                                ! PHIAVG_DOC:  $(\varpi,\varphi,z)$]
  integer :: idiag_bpmphi=0     ! PHIAVG_DOC: $\left<B_\varphi\right>_\varphi$
  integer :: idiag_bzmphi=0     ! PHIAVG_DOC: $\left<B_z\right>_\varphi$
  ! For the manual: bbmphi      ! PHIAVG_DOC: shorthand for \var{brmphi},
                                ! PHIAVG_DOC: \var{bpmphi} and \var{bzmphi}
                                ! PHIAVG_DOC: together
  integer :: idiag_b2mphi=0     ! PHIAVG_DOC: $\left<\Bv^2\right>_\varphi$
  integer :: idiag_brsphmphi=0  ! PHIAVG_DOC: $\left<B_r\right>_\varphi$
  integer :: idiag_bthmphi=0    ! PHIAVG_DOC: $\left<B_\vartheta\right>_\varphi$
  integer :: idiag_uxbrmphi=0   ! PHIAVG_DOC:
  integer :: idiag_uxbpmphi=0   ! PHIAVG_DOC:
  integer :: idiag_uxbzmphi=0   ! PHIAVG_DOC:
  integer :: idiag_b2divum=0    ! DIAG_DOC: $\left<\Bv^2\nabla\cdot\uv\right>$
  integer :: idiag_ujxbm=0      ! DIAG_DOC: $\left<\uv\cdot(\Jv\times\Bv\right>$
  integer :: idiag_jxbrmphi=0   ! PHIAVG_DOC:
  integer :: idiag_jxbpmphi=0   ! PHIAVG_DOC:
  integer :: idiag_jxbzmphi=0   ! PHIAVG_DOC:
  integer :: idiag_jxbrxm=0     ! DIAG_DOC:
  integer :: idiag_jxbrym=0     ! DIAG_DOC:
  integer :: idiag_jxbrzm=0     ! DIAG_DOC:
  integer :: idiag_jxbr2m=0     ! DIAG_DOC: $\left<(\Jv\times\Bv/\rho)^2\right>$
  integer :: idiag_jxbrxmx=0    ! DIAG_DOC:
  integer :: idiag_jxbrymx=0    ! DIAG_DOC:
  integer :: idiag_jxbrzmx=0    ! DIAG_DOC:
  integer :: idiag_jxbrxmy=0    ! DIAG_DOC:
  integer :: idiag_jxbrymy=0    ! DIAG_DOC:
  integer :: idiag_jxbrzmy=0    ! DIAG_DOC:
  integer :: idiag_jxbrxmz=0    ! DIAG_DOC:
  integer :: idiag_jxbrymz=0    ! DIAG_DOC:
  integer :: idiag_jxbrzmz=0    ! DIAG_DOC:
  integer :: idiag_armphi=0     ! PHIAVG_DOC:
  integer :: idiag_apmphi=0     ! PHIAVG_DOC:
  integer :: idiag_azmphi=0     ! PHIAVG_DOC:
  integer :: idiag_uxBrms=0     ! DIAG_DOC:
  integer :: idiag_Bresrms=0    ! DIAG_DOC:
  integer :: idiag_Rmrms=0      ! DIAG_DOC:
  integer :: idiag_jfm=0        ! DIAG_DOC:
  integer :: idiag_brbpmr=0     ! DIAG_DOC:
  integer :: idiag_vA2m=0       ! DIAG_DOC:
  integer :: idiag_b2mr=0       ! DIAG_DOC:
  integer :: idiag_brmr=0       ! DIAG_DOC:
  integer :: idiag_bpmr=0       ! DIAG_DOC:
  integer :: idiag_bzmr=0       ! DIAG_DOC:
  integer :: idiag_armr=0       ! DIAG_DOC:
  integer :: idiag_apmr=0       ! DIAG_DOC:
  integer :: idiag_azmr=0       ! DIAG_DOC:
  integer :: idiag_bxmx=0       ! DIAG_DOC:
  integer :: idiag_bymx=0       ! DIAG_DOC:
  integer :: idiag_bzmx=0       ! DIAG_DOC:
  integer :: idiag_bxmy=0       ! DIAG_DOC:
  integer :: idiag_bymy=0       ! DIAG_DOC:
  integer :: idiag_bzmy=0       ! DIAG_DOC:
  integer :: idiag_mflux_x=0    ! DIAG_DOC:
  integer :: idiag_mflux_y=0    ! DIAG_DOC:
  integer :: idiag_mflux_z=0    ! DIAG_DOC:
  integer :: idiag_bmxy_rms=0   ! DIAG_DOC: $\sqrt{[\left<b_x\right>_z(x,y)]^2 +
                                ! DIAG_DOC: [\left<b_y\right>_z(x,y)]^2 +
                                ! DIAG_DOC: [\left<b_z\right>_z(x,y)]^2} $
  integer :: idiag_etasmagm=0   ! DIAG_DOC: Mean of Smagorinsky resistivity
  integer :: idiag_etasmagmin=0 ! DIAG_DOC: Min of Smagorinsky resistivity
  integer :: idiag_etasmagmax=0 ! DIAG_DOC: Max of Smagorinsky resistivity
  integer :: idiag_etavamax=0   ! DIAG_DOC: Max of artificial resistivity
                                ! DIAG_DOC: $\eta\sim v_A$
  integer :: idiag_etajmax=0    ! DIAG_DOC: Max of artificial resistivity
                                ! DIAG_DOC: $\eta\sim J / \sqrt{\rho}$
  integer :: idiag_etaj2max=0   ! DIAG_DOC: Max of artificial resistivity
                                ! DIAG_DOC: $\eta\sim J^2 / \rho$
  integer :: idiag_etajrhomax=0 ! DIAG_DOC: Max of artificial resistivity
                                ! DIAG_DOC: $\eta\sim J / \rho$
  integer :: idiag_cosjbm=0     ! DIAG_DOC: $\left<\Jv\cdot\Bv/(|\Jv|\,|\Bv|)\right>$
  integer :: idiag_jparallelm=0 ! DIAG_DOC: Mean value of the component
                                ! DIAG_DOC: of J parallel to B
  integer :: idiag_jperpm=0     ! DIAG_DOC: Mean value of the component
                                ! DIAG_DOC: of J perpendicular to B
  integer :: idiag_brmsn=0,idiag_brmss=0,idiag_brmsh=0
  integer :: idiag_Exmxz=0      ! DIAG_DOC: $\left<{\cal E}_x\right>_{y}$
  integer :: idiag_Eymxz=0      ! DIAG_DOC: $\left<{\cal E}_y\right>_{y}$
  integer :: idiag_Ezmxz=0      ! DIAG_DOC: $\left<{\cal E}_z\right>_{y}$
  integer :: idiag_etatotalmx=0 ! DIAG_DOC: $\left<\eta\right>_{yz}$
  integer :: idiag_etatotalmz=0 ! DIAG_DOC: $\left<\eta\right>_{xy}$
!
  contains
!***********************************************************************
    subroutine register_magnetic()
!
!  Initialise variables which should know that we solve for the vector
!  potential: iaa, etc; increase nvar accordingly
!
!  1-may-02/wolf: coded
!
      use FArrayManager, only: farray_register_pde
!
      call farray_register_pde('aa',iaa,vector=3)
      iax = iaa; iay = iaa+1; iaz = iaa+2
!
!  Identify version number.
!
      if (lroot) call svn_id( &
          "$Id$")
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',aa $'
          if (nvar == mvar) write(4,*) ',aa'
        else
          write(4,*) ',aa $'
        endif
        write(15,*) 'aa = fltarr(mx,my,mz,3)*one'
      endif
!
    endsubroutine register_magnetic
!***********************************************************************
    subroutine initialize_magnetic(f)
!
!  Perform any post-parameter-read initialization
!
!  24-nov-02/tony: dummy routine - nothing to do at present
!  20-may-03/axel: reinitialize_aa added
!
      use Magnetic_meanfield, only: initialize_magnetic_mf
      use BorderProfiles, only: request_border_driving
      use FArrayManager
      use SharedVariables, only: put_shared_variable
      use EquationOfState, only: cs0
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i,ierr
!
!  Precalculate 1/mu (moved here from register.f90)
!
      mu01=1./mu0
      mu012=.5*mu01
!
!  Precalculate eta if 1/eta (==eta1) is given instead
!
      if (eta1/=0.0) then
        eta=1./eta1
      endif
!
!  Precalculate 1/inertial_length^2
!
      if (inertial_length/=0.0) then
        linertial_2 = inertial_length**(-2)
      else
        linertial_2 = 0.0
        ! make sure not to use this value by checking that
        ! (inertial_length /= 0.)...
      endif
!
!  Precalculate 1/nu_ni
!
      if (nu_ni/=0.0) then
        nu_ni1=1./nu_ni
      else
        nu_ni1=0.0
      endif
!
!  calculate B_ext21 = 1/B_ext**2 and the unit vector B1_ext = B_ext/|B_ext|
!  Also calculate B_ext_inv = B_ext/|B_ext|^2
!
      B_ext21=B_ext(1)**2+B_ext(2)**2+B_ext(3)**2
      if (B_ext21/=0.0) then
        B_ext21=1/B_ext21
      else
        B_ext21=1.0
      endif
      B_ext11=sqrt(B_ext21)
      B1_ext=B_ext*B_ext11
      B_ext_inv=B_ext*B_ext21
!
!  rescale magnetic field by a factor reinitialize_aa
!
      if (reinitialize_aa) then
        f(:,:,:,iax:iaz)=rescale_aa*f(:,:,:,iax:iaz)
      endif
!
!  set lrescaling_magnetic=T if linit_aa=T
!
      if (lreset_aa) then
        lrescaling_magnetic=.true.
      endif
!
      if (lfreeze_aint) lfreeze_varint(iax:iaz) = .true.
      if (lfreeze_aext) lfreeze_varext(iax:iaz) = .true.
!
!  Initialize resistivity.
!
      if (iresistivity(1)=='') iresistivity(1)='eta-const'  ! default
      lresi_eta_const=.false.
      lresi_sqrtrhoeta_const=.false.
      lresi_hyper2=.false.
      lresi_hyper3=.false.
      lresi_hyper3_polar=.false.
      lresi_hyper3_strict=.false.
      lresi_hyper3_aniso=.false.
      lresi_eta_shock=.false.
      lresi_eta_shock_perp=.false.
      lresi_etava=.false.
      lresi_etaj=.false.
      lresi_etaj2=.false.
      lresi_etajrho=.false.
      lresi_smagorinsky=.false.
      lresi_smagorinsky_cross=.false.
      lresi_anomalous=.false.
      lresi_spitzer=.false.
!
      do i=1,nresi_max
        select case (iresistivity(i))
        case ('eta-const')
          if (lroot) print*, 'resistivity: constant eta'
          lresi_eta_const=.true.
        case ('sqrtrhoeta-const')
          if (lroot) print*, 'resistivity: constant sqrt(rho)*eta'
          lresi_sqrtrhoeta_const=.true.
        case ('etaSS')
          if (lroot) print*, 'resistivity: etaSS (Shakura-Sunyaev)'
          lresi_etaSS=.true.
        case ('hyper2')
          if (lroot) print*, 'resistivity: hyper2'
          lresi_hyper2=.true.
        case ('hyper3')
          if (lroot) print*, 'resistivity: hyper3'
          lresi_hyper3=.true.
        case ('hyper3_cyl','hyper3-cyl','hyper3_sph','hyper3-sph')
          if (lroot) print*, 'resistivity: hyper3 curvilinear'
          lresi_hyper3_polar=.true.
        case ('hyper3_strict')
          if (lroot) print*, 'resistivity: strict hyper3 with positive definite heating rate'
          lresi_hyper3_strict=.true.
        case ('xydep')
          if (lroot) print*, 'resistivity: xy-dependent'
          lresi_xydep=.true.
          call eta_xy_dep(eta_xy,geta_xy,eta_xy_profile)
        case ('zdep')
          if (lroot) print*, 'resistivity: z-dependent'
          lresi_zdep=.true.
          call eta_zdep(eta_z,geta_z,zdep_profile)
        case ('dust')
          if (lroot) print*, 'resistivity: depending on dust density'
          lresi_dust=.true.
        case ('hyper3-aniso')
          if (lroot) print*, 'resistivity: hyper3_aniso'
          lresi_hyper3_aniso=.true.
        case ('shell')
          if (lroot) print*, 'resistivity: shell'
          lresi_shell=.true.
        case ('shock','eta-shock')
          if (lroot) print*, 'resistivity: shock'
          lresi_eta_shock=.true.
          if (.not. lshock) &
              call fatal_error('initialize_magnetic', &
              'shock resistivity, but module setting SHOCK=noshock')
        case ('shock-perp')
          if (lroot) print*, 'resistivity: shock_perp'
          lresi_eta_shock_perp=.true.
          if (.not. lshock) &
              call fatal_error('initialize_magnetic', &
              'shock resistivity, but module setting SHOCK=noshock')
        case ('eta_va')
          if (lroot) print*, 'resistivity: eta_va'
          lresi_etava=.true.
        case ('eta_j')
          if (lroot) print*, 'resistivity: eta_j'
          lresi_etaj=.true.
        case ('eta_j2')
          if (lroot) print*, 'resistivity: eta_j2'
          lresi_etaj2=.true.
          etaj20 = eta_j2 * mu0**2 * dxmax**3 / cs0
        case ('eta_jrho')
          if (lroot) print*, 'resistivity: eta_jrho'
          lresi_etajrho=.true.
        case ('smagorinsky')
          if (lroot) print*, 'resistivity: smagorinsky'
          lresi_smagorinsky=.true.
        case ('smagorinsky-cross')
          if (lroot) print*, 'resistivity: smagorinsky_cross'
          lresi_smagorinsky_cross=.true.
        case ('anomalous')
          if (lroot) print*, 'resistivity: anomalous'
          lresi_anomalous=.true.
        case ('spitzer')
          if (lroot) print*, 'resistivity: temperature dependent (Spitzer 1969)'
          lresi_spitzer=.true.
        case ('none')
          ! do nothing
        case ('')
          ! do nothing
        case default
          if (lroot) print*, 'No such value for iresistivity(',i,'): ', &
              trim(iresistivity(i))
          call fatal_error('initialize_magnetic','')
        endselect
      enddo
!
!  If we're timestepping, die or warn if the the resistivity coefficient that
!  corresponds to the chosen resistivity type is not set.
!
      if (lrun) then
        if (lresi_eta_const.and.(eta==0.0)) &
            call warning('initialize_magnetic', &
            'Resistivity coefficient eta is zero!')
        if (lresi_sqrtrhoeta_const.and.(eta==0.0)) &
            call warning('initialize_magnetic', &
            'Resistivity coefficient eta is zero!')
        if (lresi_hyper2.and.eta_hyper2==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_hyper2 is zero!')
        if (lresi_hyper3.and.eta_hyper3==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_hyper3 is zero!')
        if (lresi_hyper3_polar.and.eta_hyper3==0.0) &
             call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_hyper3 is zero!')
        if (lresi_hyper3_strict.and.eta_hyper3==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_hyper3 is zero!')
        if ( (lresi_hyper3_aniso) .and.  &
             ((eta_aniso_hyper3(1)==0.0 .and. nxgrid/=1 ).or. &
              (eta_aniso_hyper3(2)==0.0 .and. nygrid/=1 ).or. &
              (eta_aniso_hyper3(3)==0.0 .and. nzgrid/=1 )) ) &
            call fatal_error('initialize_magnetic', &
            'A resistivity coefficient of eta_aniso_hyper3 is zero!')
        if (lresi_eta_shock.and.eta_shock==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_shock is zero!')
        if (lresi_eta_shock_perp.and.eta_shock==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_shock is zero!')
        if (lresi_etava .and. eta_va==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_va is zero!')
        if (lresi_etaj .and. eta_j==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_j is zero!')
        if (lresi_etaj2 .and. eta_j2==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_j2 is zero!')
        if (lresi_etajrho .and. eta_jrho==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_jrho is zero!')
        if (lresi_anomalous.and.eta_anom==0.0) &
            call fatal_error('initialize_magnetic', &
            'Resistivity coefficient eta_anom is zero!')
!        if (lentropy .and. lohmic_heat .and. .not. lresi_eta_const) &
!            call fatal_error('initialize_magnetic', &
!            'Resistivity heating only works with regular resistivity!')
        if (lresi_hyper2.and.lresi_hyper3) &
            call warning('initialize_magnetic', &
            '4th & 6th order hyperdiffusion are both set. ' // &
            'Timestep is currently only sensitive to fourth order.')
      endif
!
!  write profile (uncomment for debugging)
!
!     if (lroot) then
!       do n=n1,n2
!         print*,z(n),eta_z(n)
!       enddo
!     endif
!
!  share eta profile with test-field procedure
!
      if (ltestfield) then
        call put_shared_variable('eta_z',eta_z,ierr)
        call put_shared_variable('geta_z',geta_z,ierr)
      endif
!
!  if meanfield theory is invoked, we need to tell the other routines
!
      call put_shared_variable('lmeanfield_theory',lmeanfield_theory,ierr)
      if (lmeanfield_theory) then
        call put_shared_variable('eta',eta,ierr)
      elseif (lspecial) then
        call put_shared_variable('eta',eta,ierr)
      endif
!
!  Tell the BorderProfiles module if we intend to use border driving, so
!  that the module can request the right pencils.
!
      if (borderaa/='nothing') call request_border_driving()
!
!  Register an extra aux slot for bb if requested (so bb and jj are written
!  to snapshots and can be easily analyzed later). For this to work you
!  must reserve enough auxiliary workspace by setting, for example,
!     ! MAUX CONTRIBUTION 6
!  in the beginning of your src/cparam.local file, *before* setting
!  ncpus, nprocy, etc.
!
!  After a reload, we need to rewrite index.pro, but the auxiliary
!  arrays are already allocated and must not be allocated again.
!
      if (lbb_as_aux) then
        if (ibb==0) then
          call farray_register_auxiliary('bb',ibb,vector=3)
          ibx=ibb
          iby=ibb+1
          ibz=ibb+2
        else
          if (lroot) print*, 'initialize_magnetic: ibb = ', ibb
          call farray_index_append('ibb',ibb)
          call farray_index_append('ibx',ibx)
          call farray_index_append('iby',iby)
          call farray_index_append('ibz',ibz)
        endif
      endif
!
!  do the same for jj (current density)
!
      if (ljj_as_aux) then
        if (ijj==0) then
          call farray_register_auxiliary('jj',ijj,vector=3)
          ijx=ijj
          ijy=ijj+1
          ijz=ijj+2
        else
          if (lroot) print*, 'initialize_magnetic: ijj = ', ijj
          call farray_index_append('ijj',ijj)
          call farray_index_append('ijx',ijx)
          call farray_index_append('ijy',ijy)
          call farray_index_append('ijz',ijz)
        endif
      endif
!
!  After a reload, we need to rewrite index.pro, but the auxiliary
!  arrays are already allocated and must not be allocated again.
!
      if (lbbt_as_aux) then
        if (ibbt==0) then
          call farray_register_auxiliary('bbt',ibbt,vector=3)
          ibxt=ibbt
          ibyt=ibbt+1
          ibzt=ibbt+2
        else
          if (lroot) print*, 'initialize_velocity: ibbt = ', ibbt
          call farray_index_append('ibbt',ibbt)
          call farray_index_append('ibxt',ibxt)
          call farray_index_append('ibyt',ibyt)
          call farray_index_append('ibzt',ibzt)
        endif
      endif
!
      if (ljjt_as_aux) then
        if (ijjt==0) then
          call farray_register_auxiliary('jjt',ijjt,vector=3)
          ijxt=ijjt
          ijyt=ijjt+1
          ijzt=ijjt+2
        else
          if (lroot) print*, 'initialize_velocity: ijjt = ', ijjt
          call farray_index_append('ijjt',ijjt)
          call farray_index_append('ijxt',ijxt)
          call farray_index_append('ijyt',ijyt)
          call farray_index_append('ijzt',ijzt)
        endif
      endif
!
!  Initialize individual modules.
!
      call initialize_magnetic_mf (f)
!
      if (any(initaa=='Alfven-zconst')) then
        call put_shared_variable('zmode',zmode,ierr)
        if (ierr/=0) call fatal_error('initialize_magnetic',&
             'there was a problem when sharing zmode')
      endif
!
      call put_shared_variable('lfrozen_bb_bot',lfrozen_bb_bot,ierr)
      if (ierr/=0) call fatal_error('initialize_magnetic',&
           'there was a problem when sharing lfrozen_bb_bot')
      call put_shared_variable('lfrozen_bb_top',lfrozen_bb_top,ierr)
      if (ierr/=0) call fatal_error('initialize_magnetic',&
           'there was a problem when sharing lfrozen_bb_top')
!
!  calculate cosz and sinz for calculating the phase of a Beltrami field
!  The choice to use k1_ff may not be optimal, but keep it for now.
!
      if (idiag_bsinphz/=0 .or. idiag_bcosphz/=0 &
          .or. idiag_uxbcmx/=0 .or. idiag_uxbcmy/=0 &
          .or. idiag_uxbsmx/=0 .or. idiag_uxbsmy/=0 ) then
        sinkz=sin(k1_ff*z)
        coskz=cos(k1_ff*z)
      endif
!
!  When adding a magnetic field to a snapshot of a nomagnetic simulation,
!  the code allows only the initialization of the field to zero. This
!  hack allows a init_aa (from start.in) to be read and added to the
!  field upon executing run.csh
!
      if (lread_oldsnap_nomag.and.lrun_initaa) then
        if (lroot) then
          print*,'Adding a magnetic field to a previously '//&
              'non-magnetic simulation. The field is given by initaa=',initaa
        endif
        call init_aa(f)
      endif
!
    endsubroutine initialize_magnetic
!***********************************************************************
    subroutine init_aa(f)
!
!  initialise magnetic field; called from start.f90
!  AB: maybe we should here call different routines (such as rings)
!  AB: and others, instead of accummulating all this in a huge routine.
!  We have an init parameter (initaa) to stear magnetic i.c. independently.
!
!   7-nov-2001/wolf: coded
!
      use EquationOfState
      use FArrayManager
      use Gravity, only: gravz, z1, z2
      use Initcond
      use Boundcond
      use InitialCondition, only: initial_condition_aa
      use Mpicomm
      use SharedVariables
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      real, dimension (mz) :: tmp
      real, dimension (nx,3) :: bb
      real, dimension (nx) :: b2,fact,cs2,lnrho_old,ssold,cs2old
      real :: beq2
      integer :: j
!
      do j=1,ninit
!
        select case (initaa(j))
        case ('nothing'); if (lroot .and. j==1) print*,'init_aa: nothing'
        case ('zero', '0'); f(:,:,:,iax:iaz) = 0.0
        case ('rescale'); f(:,:,:,iax:iaz)=amplaa(j)*f(:,:,:,iax:iaz)
        case ('bsiny'); call acosy(amplaa(j),f,iaa,ky_aa(j))
        case ('mode'); call modev(amplaa(j),coefaa,f,iaa,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('modeb'); call modeb(amplaa(j),coefbb,f,iaa,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('sph_constb'); call sph_constb(amplaa(j),f,iaa)
        case ('const_lou'); call const_lou(amplaa(j),f,iaa)
        case ('power_randomphase')
          call power_randomphase(amplaa(j),initpower_aa,cutoff_aa,f,iax,iaz)
        case ('random-isotropic-KS')
          call random_isotropic_KS(initpower_aa,f,iax,N_modes_aa)
        case ('gaussian-noise'); call gaunoise(amplaa(j),f,iax,iaz)
        case ('gaussian-noise-rprof')
          call gaunoise_rprof(amplaa(j),f,iax,iaz,rnoise_int,rnoise_ext)
        case ('gaussian-noise-zprof')
          tmp=amplaa(1)*0.5*(tanh((z-z1)/0.05)-tanh((z-z2)/0.05))
          call gaunoise(tmp,f,iax,iaz)
!
!  Beltrami fields, put k=-k to make sure B=curl(A) has the right phase
!
        case ('Beltrami-x')
               call beltrami(amplaa(j),f,iaa,KX=-kx_aa(j),phase=phasex_aa(j))
        case ('Beltrami-xy')
               call beltrami(amplaa(j),f,iaa,KX=kx_aa(j),phase=phasex_aa(j))
               call beltrami(amplaa(j),f,iaa,KY=-kx_aa(j),phase=phasex_aa(j))
        case ('Beltrami-y'); call beltrami(amplaa(j),f,iaa,KY=-ky_aa(j),phase=phasey_aa(j))
        case ('Beltrami-z'); call beltrami(amplaa(j),f,iaa,KZ=-kz_aa(j),phase=phasez_aa(j))
        case ('Beltrami-x-equ'); call beltrami(amplaa(j),f,iaa,KZ=-kz_aa(j),phase=phasez_aa(j),KX2=2*pi/Lxyz(1))
        case ('Beltrami-y-equ'); call beltrami(amplaa(j),f,iaa,KZ=-kz_aa(j),phase=phasez_aa(j),KY2=2*pi/Lxyz(2))
        case ('Beltrami-z-equ'); call beltrami(amplaa(j),f,iaa,KZ=-kz_aa(j),phase=phasez_aa(j),KZ2=2*pi/Lxyz(3))
!
        case ('Bessel-x'); call bessel_x(amplaa(j),f,iaa,kx_aa(j))
        case ('Bessel_Az-x'); call bessel_az_x(amplaa(j),f,iaa,kx_aa(j))
        case ('propto-ux'); call wave_uu(amplaa(j),f,iaa,kx=kx_aa(j))
        case ('propto-uy'); call wave_uu(amplaa(j),f,iaa,ky=ky_aa(j))
        case ('propto-uz'); call wave_uu(amplaa(j),f,iaa,kz=kz_aa(j))
        case ('diffrot'); call diffrot(amplaa(j),f,iay)
        case ('hor-tube'); call htube(amplaa(j),f,iax,iaz,radius,epsilonaa, &
                                     center1_x,center1_z)
        case ('hor-tube-x'); call htube_x(amplaa(j),f,iax,iaz,radius,epsilonaa, &
                                     center1_y,center1_z)
        case ('hor-tube_erf'); call htube_erf(amplaa(j),f,iax,iaz,radius,epsilonaa, &
                                     center1_x,center1_z,fluxtube_border_width)
        case ('hor-fluxlayer'); call hfluxlayer(amplaa(j),f,iaa,z0aa,widthaa)
        case ('hor-fluxlayer-y'); call hfluxlayer_y(amplaa(j),f,iaa,z0aa,widthaa)
        case ('ver-fluxlayer'); call vfluxlayer(amplaa(j),f,iaa,x0aa,widthaa)
        case ('mag-support'); call magsupport(amplaa(j),f,gravz,cs0,rho0)
        case ('arcade-x'); call arcade_x(amplaa(j),f,iaa,kx_aa(j),kz_aa(j))
        case ('halfcos-Bx'); call halfcos_x(amplaa(j),f,iaa)
        case ('uniform-Bx'); call uniform_x(amplaa(j),f,iaa)
        case ('uniform-By'); call uniform_y(amplaa(j),f,iaa)
        case ('uniform-Bz'); call uniform_z(amplaa(j),f,iaa)
        case ('uniform-Bphi'); call uniform_phi(amplaa(j),f,iaa)
        case ('phi_comp_over_r'); call phi_comp_over_r(amplaa(j),f,iaa)
        case ('phi_comp_over_r_noise')
          call phi_comp_over_r(amplaa(j),f,iaa)
          call gaunoise(1.0e-5*amplaa(j),f,iax,iaz)
        case ('Bz(x)', '3'); call vfield(amplaa(j),f,iaa)
        case ('vfield2'); call vfield2(amplaa(j),f,iaa)
        case ('bipolar'); call bipolar(amplaa(j),f,iaa,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('bipolar_restzero'); call bipolar_restzero(amplaa(j),f,iaa,kx_aa(j),ky_aa(j))
        case ('vecpatternxy'); call vecpatternxy(amplaa(j),f,iaa,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('xjump'); call bjump(f,iaa,by_left,by_right,bz_left,bz_right,widthaa,'x')
        case ('sinxsinz'); call sinxsinz(amplaa(j),f,iaa,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('sinxsinz_Hz'); call sinxsinz(amplaa(j),f,iaa,kx_aa(j),ky_aa(j),kz_aa(j),KKz=kz_aa(j))
        case ('sin2xsin2y'); call sin2x_sin2y_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.)
        case ('cosxcosy'); call cosx_cosy_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.)
        case ('sinxsiny'); call sinx_siny_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.)
        case ('xsiny'); call x_siny_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.)
        case ('x1siny'); call x1_siny_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.,phasey_aa(j))
        case ('sinxcosz'); call sinx_siny_cosz(amplaa(j),f,iay,kx_aa(j),ky_aa(j),kz_aa(j))
        case ('sinycosz'); call cosx_siny_cosz(amplaa(j),f,iax,kx_aa(j),ky_aa(j),0.)
        case ('cosysinz'); call cosy_sinz(amplaa(j),f,iax,ky_aa(j),kz_aa(j))
        case ('x3cosycosz'); call x3_cosy_cosz(amplaa(j),f,iax,ky_aa(j),kz_aa(j))
        case ('Ax=cosysinz'); call cosy_sinz(amplaa(j),f,iax,ky_aa(j),kz_aa(j))
        case ('magnetogram'); call mdi_init(f)
        case ('cosxcoscosy'); call cosx_coscosy_cosz(amplaa(j),f,iaz,kx_aa(j),ky_aa(j),0.)
        case ('crazy', '5'); call crazy(amplaa(j),f,iaa)
!DM
        case ('strange'); call strange(amplaa(j),f,iaa)
        case ('sinwave-x'); call sinwave(amplaa(j),f,iaa,kx=kx_aa(j))
        case ('coswave-Ax-kx'); call coswave(amplaa(j),f,iax,kx=kx_aa(j))
        case ('coswave-Ax-ky'); call coswave(amplaa(j),f,iax,ky=ky_aa(j))
        case ('coswave-Ax-kz'); call coswave(amplaa(j),f,iax,kz=kz_aa(j))
        case ('coswave-Ay-kx'); call coswave(amplaa(j),f,iay,kx=kx_aa(j))
        case ('coswave-Ay-ky'); call coswave(amplaa(j),f,iay,ky=ky_aa(j))
        case ('coswave-Ay-kz'); call coswave(amplaa(j),f,iay,kz=kz_aa(j))
        case ('coswave-Az-kx'); call coswave(amplaa(j),f,iaz,kx=kx_aa(j))
        case ('coswave-Az-ky'); call coswave(amplaa(j),f,iaz,ky=ky_aa(j))
        case ('coswave-Az-kz'); call coswave(amplaa(j),f,iaz,kz=kz_aa(j))
        case ('sinwave-Ay-kz'); call sinwave_phase(f,iay,amplaa(j),kx_aa(j),ky_aa(j),kz_aa(j),phasez_aa(j))
        case ('linear-zx')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iay)=-0.5*amplaa(j)*z(n)**2/Lxyz(3)
          enddo; enddo
        case ('Alfven-x'); call alfven_x(amplaa(j),f,iuu,iaa,ilnrho,kx_aa(j))
        case ('Alfven-y'); call alfven_y(amplaa(j),f,iuu,iaa,ky_aa(j),mu0)
        case ('Alfven-z'); call alfven_z(amplaa(j),f,iuu,iaa,kz_aa(j),mu0)
        case ('Alfven-xy'); call alfven_xy(amplaa(j),f,iuu,iaa,kx_aa(j),ky_aa(j))
        case ('Alfven-xz'); call alfven_xz(amplaa(j),f,iuu,iaa,kx_aa(j),kz_aa(j))
        case ('Alfven-rphi'); call alfven_rphi(amplaa(j),f,rmode)
        case ('Alfven-zconst'); call alfven_zconst(f)
        case ('Alfven-rz'); call alfven_rz(amplaa(j),f,rmode)
        case ('Alfvenz-rot'); call alfvenz_rot(amplaa(j),f,iuu,iaa,kz_aa(j),Omega)
        case ('Alfvenz-rot-shear'); call alfvenz_rot_shear(amplaa(j),f,iuu,iaa,kz_aa(j),Omega)
        case ('sine-bc'); call sine_avoid_boundary(amplaa(j),f,kx_aa(j),rm_int,rm_ext)
        case ('piecewise-dipole'); call piecew_dipole_aa (amplaa(j),inclaa,f,iaa)
        case ('Ferriere-uniform-Bx'); call ferriere_uniform_x(amplaa(j),f,iaa)
        case ('Ferriere-uniform-By'); call ferriere_uniform_y(amplaa(j),f,iaa)
        case ('robertsflow'); call robertsflow(amplaa(j),f,iaa,relhel_aa)
        case ('tony-nohel')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iay)=amplaa(j)/kz_aa(j)*cos(kz_aa(j)*2.*pi/Lz*z(n))
          enddo;enddo
        case ('tony-nohel-yz')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iay)=amplaa(j)/kx_aa(j)*sin(kx_aa(j)*2.*pi/Lx*x(l1:l2))
          enddo;enddo
        case ('tony-hel-xy')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iax)=amplaa(j)/kz_aa(j)*sin(kz_aa(j)*2.*pi/Lz*z(n))
            f(l1:l2,m,n,iay)=amplaa(j)/kz_aa(j)*cos(kz_aa(j)*2.*pi/Lz*z(n))
          enddo;enddo
        case ('tony-hel-yz')
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iay)=amplaa(j)/kx_aa(j)*sin(kx_aa(j)*2.*pi/Lx*x(l1:l2))
            f(l1:l2,m,n,iaz)=amplaa(j)/kx_aa(j)*cos(kx_aa(j)*2.*pi/Lx*x(l1:l2))
          enddo;enddo
        case ('force-free-jet')
          lB_ext_pot=.true.
          call force_free_jet(mu_ext_pot)
        case ('Alfven-circ-x')
!
!  Circularly polarised Alfven wave in x direction.
!
          if (lroot) print*,'init_aa: circular Alfven wave -> x'
          do n=n1,n2; do m=m1,m2
            f(l1:l2,m,n,iay) = amplaa(j)/kx_aa(j)*sin(kx_aa(j)*x(l1:l2))
            f(l1:l2,m,n,iaz) = amplaa(j)/kx_aa(j)*cos(kx_aa(j)*x(l1:l2))
          enddo;enddo
        case ('geo-benchmark-case1','geo-benchmark-case2'); call geo_benchmark_B(f)
!
        case ('torus-test'); call torus_test(amplaa(j),f)
!
        case default
!
!  Catch unknown values
!
          call fatal_error('init_aa', &
              'init_aa value "' // trim(initaa(j)) // '" not recognised')
!
        endselect
!
!  End loop over initial conditions
!
      enddo
!
!  Interface for user's own initial condition
!
      if (linitial_condition) call initial_condition_aa(f)
!
!  allow for pressure equilibrium (for isothermal tube)
!  assume that ghost zones have already been set.
!  corrected expression below for gamma /= 1 case.
!  The beq2 expression for 2*mu0*p is not general yet.
!
      if (lpress_equil.or.lpress_equil_via_ss) then
        if (lroot) print*,'init_aa: adjust lnrho to have pressure equilib; cs0=',cs0
        call boundconds_x(f)
        call initiate_isendrcv_bdry(f)
        call finalize_isendrcv_bdry(f)
        call boundconds_y(f)
        call boundconds_z(f)
        do n=n1,n2
        do m=m1,m2
          call curl(f,iaa,bb)
          call dot2_mn(bb,b2)
          if (gamma==1.0) then
            f(l1:l2,m,n,ilnrho)=log(exp(f(l1:l2,m,n,ilnrho))-b2/(2.*cs0**2))
          else
            beq2=2.*rho0*cs0**2
            fact=max(1.0e-6,1.0-b2/beq2)
            if (lentropy.and.lpress_equil_via_ss) then
              if (lpress_equil_alt) then
                ssold=f(l1:l2,m,n,iss)
                cs2old=cs20*exp(gamma_m1*(f(l1:l2,m,n,ilnrho)-lnrho0) &
                  +gamma*ssold)
                cs2=cs2old-gamma*b2/(beq2*exp(f(l1:l2,m,n,ilnrho)-lnrho0))
                f(l1:l2,m,n,iss)=ssold+gamma1*(log(cs2/cs20)-log(cs2old/cs20))
              else
                f(l1:l2,m,n,iss)=f(l1:l2,m,n,iss)+fact/gamma
              endif
            else
              if (lpress_equil_alt) then
!                cs2(1:nx)=cs0**2*exp((f(l1:l2,m,n,ilnrho)-lnrho0)/mpoly)
                lnrho_old=f(l1:l2,m,n,ilnrho)
                cs2=cs20*exp(gamma_m1*(lnrho_old-lnrho0) &
                  +gamma*f(l1:l2,m,n,iss))
                f(l1:l2,m,n,ilnrho)=log(exp(lnrho_old)-b2*gamma/ &
                  (beq2*cs2(1:nx)))
                f(l1:l2,m,n,iss)=gamma1*(log(cs2/cs20)-&
                  gamma_m1*f(l1:l2,m,n,ilnrho))
              else
                f(l1:l2,m,n,ilnrho)=f(l1:l2,m,n,ilnrho)+fact/gamma_m1
              endif
            endif
          endif
        enddo
        enddo
      endif
!
    endsubroutine init_aa
!***********************************************************************
    subroutine pencil_criteria_magnetic()
!
!   All pencils that the Magnetic module depends on are specified here.
!
!  19-nov-04/anders: coded
!
      use Mpicomm, only: stop_it
!
      lpenc_requested(i_bb)=.true.
      lpenc_requested(i_uxb)=.true.
!
!  need uga always for advective gauge.
!
      if (ladvective_gauge) lpenc_requested(i_uga)=.true.
!
      if (dvid/=0.0) lpenc_video(i_b2)=.true.
      if (dvid/=0.0) lpenc_video(i_jb)=.true.
!
!  jj pencil always needed when in Weyl gauge
!
      if ((hall_term/=0.0.and.ldt).or.height_eta/=0.0.or.ip<=4.or. &
          lweyl_gauge.or.lspherical_coords) &
!  WL: but doesn't seem to be needed for the cylindrical case
          lpenc_requested(i_jj)=.true.
      if (.not.lweyl_gauge) &
          lpenc_requested(i_del2a)=.true.
      if ((.not.lweyl_gauge).and.(lresi_eta_const.or.lresi_shell.or. &
          lresi_eta_shock.or.lresi_smagorinsky.or.lresi_zdep.or. &
          lresi_xydep.or.lresi_smagorinsky_cross.or.lresi_spitzer)) &
          lpenc_requested(i_del2a)=.true.
      if (lresi_sqrtrhoeta_const) then
        lpenc_requested(i_jj)=.true.
        lpenc_requested(i_rho1)=.true.
        if (.not.lweyl_gauge) lpenc_requested(i_del2a)=.true.
      endif
      if (lresi_eta_shock) then
        lpenc_requested(i_shock)=.true.
        if (.not.lweyl_gauge) then
          lpenc_requested(i_gshock)=.true.
          lpenc_requested(i_diva)=.true.
        endif
      endif
      if (lresi_etava) then
        lpenc_requested(i_etava)=.true.
        lpenc_requested(i_jj)=.true.
      endif
      if (lresi_etaj) then
        lpenc_requested(i_etaj)=.true.
        lpenc_requested(i_jj)=.true.
      endif
      if (lresi_etaj2) then
        lpenc_requested(i_etaj2)=.true.
        lpenc_requested(i_jj)=.true.
      endif
      if (lresi_etajrho) then
        lpenc_requested(i_etajrho)=.true.
        lpenc_requested(i_jj)=.true.
      endif
      if (lresi_shell) then
        lpenc_requested(i_r_mn)=.true.
        lpenc_requested(i_evr)=.true.
      endif
      if (lresi_eta_shock_perp) then
        lpenc_requested(i_shock_perp)=.true.
        if (.not.lweyl_gauge) then
          lpenc_requested(i_gshock_perp)=.true.
          lpenc_requested(i_diva)=.true.
        endif
      endif
      if (lresi_spitzer) then
        lpenc_requested(i_lnTT)=.true.
        if (lweyl_gauge) then
          lpenc_requested(i_jj)=.true.
        else
          lpenc_requested(i_glnTT)=.true.
          lpenc_requested(i_del2a)=.true.
          lpenc_requested(i_diva)=.true.
        endif
      endif
!
      if (lupw_aa) then
        lpenc_requested(i_uu)=.true.
        lpenc_requested(i_aij)=.true.
      endif
      if (ladvective_gauge) then
        lpenc_requested(i_aa)=.true.
        lpenc_requested(i_uu)=.true.
        lpenc_requested(i_aij)=.true.
        lpenc_requested(i_uij)=.true.
      endif
      if (lresi_shell .or. lresi_zdep .or. lresi_xydep) lpenc_requested(i_diva)=.true.
      if (lresi_smagorinsky_cross) lpenc_requested(i_jo)=.true.
      if (lresi_hyper2) lpenc_requested(i_del4a)=.true.
      if (lresi_hyper3) lpenc_requested(i_del6a)=.true.
!WL: for the cylindrical case, lpencil_check says graddiva is not needed
      if (lspherical_coords) lpenc_requested(i_graddiva)=.true.
      if (lentropy .or. lresi_smagorinsky .or. ltemperature) then
        lpenc_requested(i_j2)=.true.
      endif
      if (lresi_dust) lpenc_requested(i_rhop)=.true.
      if (lresi_anomalous) then
        lpenc_requested(i_jj)=.true.
        lpenc_requested(i_rho1)=.true.
      endif
!     if (lentropy .or. ltemperature .or. ldt) lpenc_requested(i_rho1)=.true.
!AB: why should ldt require rho1?
      if (lentropy .or. ltemperature) lpenc_requested(i_rho1)=.true.
      if (lentropy .or. ltemperature) lpenc_requested(i_TT1)=.true.
      if (ltemperature) lpenc_requested(i_cv1)=.true.
!
!  ambipolar diffusion
!
      if (nu_ni/=0.0) then
        lpenc_requested(i_va2)=.true.
        lpenc_requested(i_jxbrxb)=.true.
        lpenc_requested(i_jxbr2)=.true.
      endif
      if (hall_term/=0.0) lpenc_requested(i_jxb)=.true.
      if ((lhydro .and. llorentzforce) .or. nu_ni/=0.0) &
          lpenc_requested(i_jxbr)=.true.
      if (lresi_smagorinsky_cross) lpenc_requested(i_oo)=.true.
      if (nu_ni/=0.0) lpenc_requested(i_va2)=.true.
!
!  diagnostics pencils
!
      if (idiag_jxbrxm/=0 .or. idiag_jxbrym/=0 .or. idiag_jxbrzm/=0) &
          lpenc_diagnos(i_jxbr)=.true.
      if (idiag_jxbr2m/=0) lpenc_diagnos(i_jxbr2)=.true.
      if (idiag_jxbrxmx/=0 .or. idiag_jxbrymx/=0 .or. idiag_jxbrzmx/=0 .or. &
          idiag_jxbrxmy/=0 .or. idiag_jxbrymy/=0 .or. idiag_jxbrzmy/=0 .or. &
          idiag_jxbrxmz/=0 .or. idiag_jxbrymz/=0 .or. idiag_jxbrzmz/=0) &
          lpenc_diagnos(i_jxbr)=.true.
!
      if (idiag_b2ruzm/=0) &
          lpenc_diagnos(i_rho)=.true.
!
      if (     idiag_brmphi/=0  .or. idiag_uxbrmphi/=0 .or. idiag_jxbrmphi/=0 &
          .or. idiag_armphi/=0  .or. idiag_brmr/=0     .or. idiag_armr/=0 ) then
        lpenc_diagnos(i_pomx)=.true.
        lpenc_diagnos(i_pomy)=.true.
      endif
!
      if (     idiag_bpmphi/=0  .or. idiag_uxbpmphi/=0 .or. idiag_jxbpmphi/=0 &
          .or. idiag_bpmr/=0    .or. idiag_brbpmr/=0   .or. idiag_apmphi/=0  &
          .or. idiag_apmr/=0 ) then
        lpenc_diagnos(i_phix)=.true.
        lpenc_diagnos(i_phiy)=.true.
      endif
!
      if (idiag_armr/=0 .or. idiag_apmr/=0 .or. idiag_azmr/=0) &
          lpenc_diagnos(i_aa)=.true.
!
      if (idiag_armphi/=0 .or. idiag_apmphi/=0 .or. idiag_azmphi/=0 .or. &
          idiag_axmxz/=0 .or. idiag_aymxz/=0 .or. idiag_azmxz/=0) &
           lpenc_diagnos2d(i_aa)=.true.
!
      if (idiag_aybym2/=0 .or. idiag_exaym2/=0 .or. &
          idiag_examx/=0 .or. idiag_examy/=0 .or. idiag_examz/=0 .or. &
          idiag_examz1/=0 .or. idiag_examz2/=0 .or. idiag_examz3/=0 &
         ) lpenc_diagnos(i_aa)=.true.
      if (idiag_arms/=0 .or. idiag_amax/=0) lpenc_diagnos(i_a2)=.true.
      if (idiag_ab_int/=0 .or. idiag_abm/=0 .or. idiag_abmh/=0 &
          .or. idiag_abmz/=0 .or. idiag_abrms/=0 &
          .or. idiag_abumx/=0 .or. idiag_abumy/=0 .or. idiag_abumz/=0 &
          .or. idiag_abuxmz/=0 .or. idiag_abuymz/=0 .or. idiag_abuzmz/=0 &
         ) lpenc_diagnos(i_ab)=.true.
      if (idiag_uam/=0 .or. idiag_uamz/=0) lpenc_diagnos(i_ua)=.true.
      if (idiag_djuidjbim/=0 .or. idiag_b3b21m/=0 &
          .or. idiag_dexbmx/=0 .or. idiag_dexbmy/=0 .or. idiag_dexbmz/=0 &
          .or. idiag_b1b32m/=0 .or.  idiag_b2b13m/=0) &
          lpenc_diagnos(i_bij)=.true.
      if (idiag_j2m/=0 .or. idiag_jm2/=0 .or. idiag_jrms/=0 .or. &
          idiag_jmax/=0 .or. idiag_epsM/=0 .or. idiag_epsM_LES/=0 .or. &
          idiag_ajm/=0 ) &
          lpenc_diagnos(i_j2)=.true.
      if (idiag_epsAD/=0) lpenc_diagnos(i_jxbr2)=.true.
      if (idiag_jb_int/=0 .or. idiag_jbm/=0 .or. idiag_jbmz/=0) lpenc_diagnos(i_jb)=.true.
      if (idiag_jbmphi/=0) lpenc_diagnos2d(i_jb)=.true.
      if (idiag_vArms/=0 .or. idiag_vAmax/=0 .or. idiag_vA2m/=0) lpenc_diagnos(i_va2)=.true.
      if (idiag_cosubm/=0) lpenc_diagnos(i_cosub)=.true.
      if (idiag_ubm/=0 .or. idiag_ubbzm/=0) lpenc_diagnos(i_ub)=.true.
      if (idiag_djuidjbim/=0 .or. idiag_uxDxuxbm/=0) lpenc_diagnos(i_uij)=.true.
      if (idiag_uxjm/=0) lpenc_diagnos(i_uxj)=.true.
      if (idiag_vArms/=0 .or. idiag_vAmax/=0) lpenc_diagnos(i_va2)=.true.
      if (idiag_uxBrms/=0 .or. idiag_Rmrms/=0) lpenc_diagnos(i_uxb2)=.true.
      if (idiag_beta1m/=0 .or. idiag_beta1max/=0) lpenc_diagnos(i_beta)=.true.
      if (idiag_djuidjbim/=0) lpenc_diagnos(i_djuidjbi)=.true.
      if (idiag_b2divum/=0) lpenc_diagnos(i_divu)=.true.
      if (idiag_b2divum/=0) lpenc_diagnos(i_b2)=.true.
      if (idiag_ujxbm/=0) lpenc_diagnos(i_ujxb)=.true.
      if (idiag_gpxbm/=0) lpenc_diagnos(i_glnrhoxb)=.true.
      if (idiag_jxbxbm/=0) lpenc_diagnos(i_jxbxb)=.true.
      if (idiag_oxuxbm/=0) lpenc_diagnos(i_oxuxb)=.true.
      if (idiag_exaym2/=0 .or. idiag_exjm2/=0 &
          .or. idiag_jmx/=0 .or. idiag_jmy/=0 .or. idiag_jmz/=0 &
          .or. idiag_ambmz/=0 .or. idiag_jmbmz/=0 .or. idiag_kmz/=0 &
          .or. idiag_examx/=0 .or. idiag_examy/=0 .or. idiag_examz/=0 &
          .or. idiag_examz1/=0 .or. idiag_examz2/=0 .or. idiag_examz3/=0 &
          .or. idiag_exjmx/=0 .or. idiag_exjmy/=0 .or. idiag_exjmz/=0 &
         ) lpenc_diagnos(i_jj)=.true.
      if (idiag_examz1/=0 .or. idiag_examz2/=0 .or. idiag_examz3/=0 &
         ) lpenc_diagnos(i_exa)=.true.
      if (idiag_phibmx/=0 .or. idiag_phibmy/=0 .or. idiag_phibmz/=0 &
         ) lpenc_diagnos(i_diva)=.true.
      if (idiag_b2uzm/=0 .or. idiag_b2ruzm/=0 .or. &
          idiag_b1m/=0 .or. idiag_b2m/=0 .or. idiag_bm2/=0 .or. &
          idiag_brmsh/=0 .or. idiag_brmsn/=0 .or. idiag_brmss/=0 .or. &
          idiag_brms/=0 .or. idiag_bmax/=0 .or. &
          idiag_emag/=0 ) &
          lpenc_diagnos(i_b2)=.true.
      if (idiag_etavamax/=0) lpenc_diagnos(i_etava)=.true.
      if (idiag_etajmax/=0) lpenc_diagnos(i_etaj)=.true.
      if (idiag_etaj2max/=0) lpenc_diagnos(i_etaj2)=.true.
      if (idiag_etajrhomax/=0) lpenc_diagnos(i_etajrho)=.true.
      if (idiag_cosjbm/=0) lpenc_diagnos(i_cosjb)=.true.
      if (idiag_cosubm/=0) then
        lpenc_diagnos(i_cosub)=.true.
      endif
      if ((idiag_jparallelm/=0).or.(idiag_jperpm/=0)) then
        lpenc_diagnos(i_cosjb)=.true.
        lpenc_diagnos(i_jparallel)=.true.
        lpenc_diagnos(i_jperp)=.true.
      endif
      if (idiag_b2mphi/=0) lpenc_diagnos2d(i_b2)=.true.
      if (idiag_brsphmphi/=0) lpenc_diagnos2d(i_evr)=.true.
      if (idiag_bthmphi/=0) lpenc_diagnos2d(i_evth)=.true.
      if (lisotropic_advection) lpenc_requested(i_va2)=.true.
      if (idiag_abumx/=0 .or. idiag_abumy/=0 .or. idiag_abumz/=0 &
          .or. idiag_abuxmz/=0 .or. idiag_abuymz/=0 .or. idiag_abuzmz/=0) &
          lpenc_diagnos(i_uu)=.true.
!
!  Check whether right variables are set for half-box calculations.
!
      if (idiag_brmsn/=0 .or. idiag_abmn/=0 .or. idiag_ambmzn/=0 &
          .or. idiag_jbmn/= 0 ) then
        if ((.not.lequatory).and.(.not.lequatorz)) then
          call stop_it("You have to set either of lequatory or lequatorz to true to calculate averages over half the box")
        else
          if (lequatory) write(*,*) 'pencil-criteria_magnetic: box divided along y dirn'
          if (lequatorz) write(*,*) 'pencil-criteria_magnetic: box divided along z dirn'
        endif
      else
      endif
!
!  check for pencil_criteria_magnetic_mf
!
      if (lmeanfield_theory) call pencil_criteria_magnetic_mf()
!
    endsubroutine pencil_criteria_magnetic
!***********************************************************************
    subroutine pencil_interdep_magnetic(lpencil_in)
!
!  Interdependency among pencils from the Magnetic module is specified here.
!
!  19-nov-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_jparallel).or.lpencil_in(i_jperp)) then
        lpencil_in(i_cosjb)=.true.
        lpencil_in(i_jxb)=.true.
      endif
      if (lpencil_in(i_cosjb)) then
        lpencil_in(i_b2)=.true.
        lpencil_in(i_j2)=.true.
        lpencil_in(i_jb)=.true.
      endif
      if (lpencil_in(i_a2)) lpencil_in(i_aa)=.true.
      if (lpencil_in(i_ab)) then
        lpencil_in(i_aa)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_ua)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_aa)=.true.
      endif
      if (lpencil_in(i_va2)) then
        lpencil_in(i_b2)=.true.
        lpencil_in(i_rho1)=.true.
      endif
      if (lpencil_in(i_etava)) lpencil_in(i_va2)=.true.
      if (lpencil_in(i_etaj) .or. lpencil_in(i_etaj2) .or. lpencil_in(i_etajrho)) then
        lpencil_in(i_j2)=.true.
        lpencil_in(i_rho1)=.true.
      endif
      if (lpencil_in(i_j2)) lpencil_in(i_jj)=.true.
      if (lpencil_in(i_uxj)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_jj)=.true.
      endif
      if (lpencil_in(i_jb)) then
        lpencil_in(i_bb)=.true.
        lpencil_in(i_jj)=.true.
      endif
      if (lpencil_in(i_jxbr) .and. va2max_jxb>0) lpencil_in(i_va2)=.true.
      if (lpencil_in(i_jxbr)) then
        lpencil_in(i_jxb)=.true.
        lpencil_in(i_rho1)=.true.
      endif
      if (lpencil_in(i_jxb)) then
        lpencil_in(i_jj)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_uxb2)) lpencil_in(i_uxb)=.true.
      if (lpencil_in(i_uxb)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_cosub)) then
        lpencil_in(i_ub)=.true.
        lpencil_in(i_u2)=.true.
        lpencil_in(i_b2)=.true.
      endif
      if (lpencil_in(i_ub)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_beta)) then
        lpencil_in(i_b2)=.true.
        lpencil_in(i_pp)=.true.
      endif
      if (lpencil_in(i_b2)) lpencil_in(i_bb)=.true.
      if (lpencil_in(i_jj)) lpencil_in(i_bij)=.true.
      if (lpencil_in(i_bb)) then
        if (.not.lcartesian_coords) lpencil_in(i_aa)=.true.
        lpencil_in(i_aij)=.true.
      endif
      if (lpencil_in(i_djuidjbi)) then
        lpencil_in(i_uij)=.true.
        lpencil_in(i_bij)=.true.
      endif
      if (lpencil_in(i_jo)) then
        lpencil_in(i_oo)=.true.
        lpencil_in(i_jj)=.true.
      endif
      if (lpencil_in(i_ujxb)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_jxb)=.true.
      endif
      if (lpencil_in(i_oxu)) then
        lpencil_in(i_oo)=.true.
        lpencil_in(i_uu)=.true.
      endif
      if (lpencil_in(i_oxuxb)) then
        lpencil_in(i_oxu)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_jxbxb)) then
        lpencil_in(i_jxb)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_jxbrxb)) then
        lpencil_in(i_jxbr)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_glnrhoxb)) then
        lpencil_in(i_glnrho)=.true.
        lpencil_in(i_bb)=.true.
      endif
      if (lpencil_in(i_oxj)) then
        lpencil_in(i_oo)=.true.
        lpencil_in(i_jj)=.true.
      endif
      if (lpencil_in(i_jij)) lpencil_in(i_bij)=.true.
      if (lpencil_in(i_sj)) then
        lpencil_in(i_sij)=.true.
        lpencil_in(i_jij)=.true.
      endif
      if (lpencil_in(i_ss12)) lpencil_in(i_sij)=.true.
      if (lpencil_in(i_del2A)) then
        if (lspherical_coords) then
!WL: for the cylindrical case, lpencil_check says these pencils are not needed
          lpencil_in(i_jj)=.true.
          lpencil_in(i_graddivA)=.true.
        endif
      endif
      if (lpencil_in(i_uga)) then
        lpencil_in(i_aij)=.true.
        lpencil_in(i_uu)=.true.
      endif
!
      if (lpencil_in(i_ss12)) lpencil_in(i_sj)=.true.
!
!AB: do we still need these following out-commented lines?
!
!  Pencils bij, del2a and graddiva come in a bundle.
!     if ( lpencil_in(i_bij) .and. &
!         (lpencil_in(i_del2a).or.lpencil_in(i_graddiva)) ) then
!       lpencil_in(i_del2a)=.false.
!       lpencil_in(i_graddiva)=.false.
!     endif
!     if (lpencil_in(i_del2a) .and. &
!         (lpencil_in(i_bij).or.lpencil_in(i_graddiva)) ) then
!       lpencil_in(i_bij)=.false.
!       lpencil_in(i_graddiva)=.false.
!     endif
!
!  check for pencil_interdep_magnetic_mf
!
      if (lmeanfield_theory) call pencil_interdep_magnetic_mf(lpencil_in)
!
    endsubroutine pencil_interdep_magnetic
!***********************************************************************
    subroutine calc_pencils_magnetic(f,p)
!
!  Calculate Magnetic pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  19-nov-04/anders: coded
!
      use Sub
      use Diagnostics, only: sum_mn_name
      use SharedVariables, only: put_shared_variable
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
!      real, dimension (nx,3) :: bb_ext_pot
      real, dimension (nx) :: rho1_jxb
      real, dimension (nx) :: jcrossb2
      real, dimension (nx,3) :: Bk_Bki,tmp_jxb
      real :: B2_ext,c,s,kx,fact
      integer :: i,j,ix
!
      intent(inout) :: f,p
! aa
      if (lpencil(i_aa)) p%aa=f(l1:l2,m,n,iax:iaz)
! a2
      if (lpencil(i_a2)) call dot2_mn(p%aa,p%a2)
! aij
      if (lpencil(i_aij)) call gij(f,iaa,p%aij,1)
! diva
      if (lpencil(i_diva)) call div_mn(p%aij,p%diva,p%aa)
! bb
      if (lpencil(i_bb)) then
        call curl_mn(p%aij,p%bb,p%aa)
!
!  Save field before adding imposed field (for diagnostics).
!
        p%bbb=p%bb
        B2_ext=B_ext(1)**2+B_ext(2)**2+B_ext(3)**2
!
!  Allow external field to precess about z-axis with frequency omega_Bz_ext.
!
        if (B2_ext/=0.0) then
          if (lbext_curvilinear.or.lcartesian_coords) then
!
!  luse_curvilinear_bext is default. The B_ext the user defines in
!  magnetic_init_pars respects the coordinate system of preference
!  which means that B_ext=(0.0,1.0,0.0) is an azimuthal field in cylindrical
!  coordinates and a polar one in spherical.
!
            if (omega_Bz_ext==0.0) then
              B_ext_tmp=B_ext
            elseif (omega_Bz_ext/=0.0) then
              c=cos(omega_Bz_ext*t)
              s=sin(omega_Bz_ext*t)
              B_ext_tmp(1)=B_ext(1)*c-B_ext(2)*s
              B_ext_tmp(2)=B_ext(1)*s+B_ext(2)*c
              B_ext_tmp(3)=B_ext(3)
            endif
          else if (lcylindrical_coords) then
            if (omega_Bz_ext/=0.0) &
                call fatal_error('calc_pencils_magnetic', &
                'precession of the external field not '// &
                'implemented for cylindrical coordinates')
!
!  Transform b_ext to other coordinate systems.
!
            B_ext_tmp(1)=  B_ext(1)*cos(y(m)) + B_ext(2)*sin(y(m))
            B_ext_tmp(2)= -B_ext(1)*sin(y(m)) + B_ext(2)*cos(y(m))
            B_ext_tmp(3)=  B_ext(3)
          else if (lspherical_coords) then
            if (omega_Bz_ext/=0.0) &
                call fatal_error('calc_pencils_magnetic', &
                'precession of the external field not '//&
                'implemented for spherical coordinates')
            B_ext_tmp(1)= B_ext(1)*sinth(m)*cos(z(n)) + B_ext(2)*sinth(m)*sin(z(n)) + B_ext(3)*costh(m)
            B_ext_tmp(2)= B_ext(1)*costh(m)*cos(z(n)) + B_ext(2)*costh(m)*sin(z(n)) - B_ext(3)*sinth(m)
            B_ext_tmp(3)=-B_ext(1)         *sin(z(n)) + B_ext(2)         *cos(z(n))
          endif
!
!  Add the external field.
!
          if (B_ext_tmp(1)/=0.0) p%bb(:,1)=p%bb(:,1)+B_ext_tmp(1)
          if (B_ext_tmp(2)/=0.0) p%bb(:,2)=p%bb(:,2)+B_ext_tmp(2)
          if (B_ext_tmp(3)/=0.0) p%bb(:,3)=p%bb(:,3)+B_ext_tmp(3)
          if (headtt) print*,'calc_pencils_magnetic: B_ext=',B_ext
          if (headtt) print*,'calc_pencils_magnetic: B_ext_tmp=',B_ext_tmp
        endif
!
!  Add the external potential field.
!
!        if (lB_ext_pot) then
!          call get_global(bb_ext_pot,m,n,'B_ext_pot')
!          p%bb=p%bb+bb_ext_pot
!        endif
!
!  Add external B-field.
!
        if (iglobal_bx_ext/=0) p%bb(:,1)=p%bb(:,1)+f(l1:l2,m,n,iglobal_bx_ext)
        if (iglobal_by_ext/=0) p%bb(:,2)=p%bb(:,2)+f(l1:l2,m,n,iglobal_by_ext)
        if (iglobal_bz_ext/=0) p%bb(:,3)=p%bb(:,3)+f(l1:l2,m,n,iglobal_bz_ext)
      endif
!
! b2 (default is that B_ext is not included), but this can be changed
! by setting luse_Bext_in_b2=.true.
!
      if (luse_Bext_in_b2) then
        if (lpencil(i_b2)) call dot2_mn(p%bb,p%b2)
      else
        if (lpencil(i_b2)) call dot2_mn(p%bbb,p%b2)
      endif
! ab
      if (lpencil(i_ab)) call dot_mn(p%aa,p%bbb,p%ab)
      if (lpencil(i_ua)) call dot_mn(p%uu,p%aa,p%ua)
! uxb
      if (lpencil(i_uxb)) then
        call cross_mn(p%uu,p%bb,p%uxb)
        call cross_mn(p%uu,p%bbb,uxbb)
!  add external e-field.
        if (iglobal_ex_ext/=0) p%uxb(:,1)=p%uxb(:,1)+f(l1:l2,m,n,iglobal_ex_ext)
        if (iglobal_ey_ext/=0) p%uxb(:,2)=p%uxb(:,2)+f(l1:l2,m,n,iglobal_ey_ext)
        if (iglobal_ez_ext/=0) p%uxb(:,3)=p%uxb(:,3)+f(l1:l2,m,n,iglobal_ez_ext)
      endif
! exa
      if (lpencil(i_exa)) then
        call cross_mn(-p%uxb+eta*p%jj,p%aa,p%exa)
      endif
! uga
! DM : this requires later attention
      if (lpencil(i_uga)) then
        if (.not.lcartesian_coords) then
          call fatal_error("calc_pencils_magnetic","u_dot_grad A not implemented for non-cartesian coordinates")
        else
          call u_dot_grad(f,iaa,p%aij,p%uu,p%uga,UPWIND=lupw_aa)
        endif
      endif
!
!  bij, del2a, graddiva
!  For non-cartesian coordinates jj is always required for del2a=graddiva-jj
!
      if (lpencil(i_bij) .or. lpencil(i_del2a) .or. lpencil(i_graddiva) .or. &
          lpencil(i_jj) ) then
        if (lcartesian_coords) then
          call gij_etc(f,iaa,p%aa,p%aij,p%bij,p%del2a,p%graddiva)
          if (.not. lpencil(i_bij)) p%bij=0.0      ! Avoid warnings from pencil
          if (.not. lpencil(i_del2A)) p%del2A=0.0  ! consistency check...
          if (.not. lpencil(i_graddiva)) p%graddiva=0.0
!          if (lpencil(i_jj)) call curl_mn(p%bij,p%jj,p%bb)
!DM curl in cartesian does not need p%bb, then it is better not
! to give it.
          if (lpencil(i_jj)) call curl_mn(p%bij,p%jj)
        else
          call gij_etc(f,iaa,p%aa,p%aij,p%bij,GRADDIV=p%graddiva)
          call curl_mn(p%bij,p%jj,p%bb)
          if (lpencil(i_del2a)) p%del2a=p%graddiva-p%jj
!           if (lpencil(i_del2a)) call del2v(f,iaa,p%del2a,p%aij,p%aa)
        endif
      endif
! jj
      if (lpencil(i_jj)) then
        p%jj=mu01*p%jj
!
!  Add external j-field.
!
        if (iglobal_jx_ext/=0) p%jj(:,1)=p%jj(:,1)+f(l1:l2,m,n,iglobal_jx_ext)
        if (iglobal_jy_ext/=0) p%jj(:,2)=p%jj(:,2)+f(l1:l2,m,n,iglobal_jy_ext)
        if (iglobal_jz_ext/=0) p%jj(:,3)=p%jj(:,3)+f(l1:l2,m,n,iglobal_jz_ext)
      endif
! j2
      if (lpencil(i_j2)) call dot2_mn(p%jj,p%j2)
! jb
      if (lpencil(i_jb)) call dot_mn(p%jj,p%bbb,p%jb)
! va2
      if (lpencil(i_va2)) then
        p%va2=p%b2*mu01*p%rho1
        if (lcheck_positive_va2 .and. minval(p%va2)<0.0) then
          print*, 'calc_pencils_magnetic: Alfven speed is imaginary!'
          print*, 'calc_pencils_magnetic: it, itsub, iproc=', it, itsub, iproc
          print*, 'calc_pencils_magnetic: m, y(m), n, z(n)=', m, y(m), n, z(n)
          p%va2=abs(p%va2)
        endif
      endif
! eta_va
      if (lpencil(i_etava)) then
        p%etava = mu0 * eta_va * dxmax * sqrt(p%va2)
        if (eta_min > 0.) where (p%etava < eta_min) p%etava = 0.
      endif
! eta_j
      if (lpencil(i_etaj)) then
        p%etaj = mu0 * eta_j * dxmax**2 * sqrt(mu0 * p%j2 * p%rho1)
        if (eta_min > 0.) where (p%etaj < eta_min) p%etaj = 0.
      endif
! eta_j2
      if (lpencil(i_etaj2)) then
        p%etaj2 = etaj20 * p%j2 * p%rho1
        if (eta_min > 0.) where (p%etaj2 < eta_min) p%etaj2 = 0.
      endif
! eta_jrho
      if (lpencil(i_etajrho)) then
        p%etajrho = mu0 * eta_jrho * dxmax * sqrt(p%j2) * p%rho1
        if (eta_min > 0.) where (p%etajrho < eta_min) p%etajrho = 0.
      endif
! jxb
      if (lpencil(i_jxb)) call cross_mn(p%jj,p%bb,p%jxb)
! jxbr
      if (lpencil(i_jxbr)) rho1_jxb=p%rho1
! cosjb
      if (lpencil(i_cosjb)) then
        do ix=1,nx
          if ((abs(p%j2(ix))<=tini).or.(abs(p%b2(ix))<=tini))then
            p%cosjb(ix)=0.
          else
            p%cosjb(ix)=p%jb(ix)/sqrt(p%j2(ix)*p%b2(ix))
          endif
        enddo
        if (lpencil_check_at_work) then
        ! map penc0 value back to interval [-1,1]
          p%cosjb = modulo(p%cosjb + 1.0, 2.0) - 1
        endif
      endif
! jparallel and jperp
      if (lpencil(i_jparallel).or.lpencil(i_jperp)) then
        p%jparallel=sqrt(p%j2)*p%cosjb
        call dot2_mn(p%jxb,jcrossb2)
        do ix=1,nx
          if ((abs(p%j2(ix))<=tini).or.(abs(p%b2(ix))<=tini))then
            p%jperp=0
          else
            p%jperp=sqrt(jcrossb2(ix))/sqrt(p%b2(ix))
          endif
        enddo
      endif
! jxbr
      if (lpencil(i_jxbr)) then
        rho1_jxb=p%rho1
!
!  Set rhomin_jxb>0 in order to limit the jxb term at very low densities.
!  Set va2max_jxb>0 in order to limit the jxb term at very high Alfven speeds.
!  Set va2power_jxb to an integer value in order to specify the power of the
!  limiting term,
!
        if (rhomin_jxb>0) rho1_jxb=min(rho1_jxb,1/rhomin_jxb)
        if (va2max_jxb>0) then
          rho1_jxb = rho1_jxb &
                   * (1+(p%va2/va2max_jxb)**va2power_jxb)**(-1.0/va2power_jxb)
        endif
        call multsv_mn(rho1_jxb,p%jxb,p%jxbr)
      endif
! jxbr2
      if (lpencil(i_jxbr2)) call dot2_mn(p%jxbr,p%jxbr2)
! ub
      if (lpencil(i_ub)) call dot_mn(p%uu,p%bb,p%ub)
! cosub
      if (lpencil(i_cosub)) then
        do ix=1,nx
          if ((abs(p%u2(ix))<=tini).or.(abs(p%b2(ix))<=tini)) then
            p%cosub(ix)=0.
          else
            p%cosub(ix)=p%ub(ix)/sqrt(p%u2(ix)*p%b2(ix))
          endif
        enddo
        if (lpencil_check) then
        ! map penc0 value back to interval [-1,1]
          p%cosub = modulo(p%cosub + 1.0, 2.0) - 1
        endif
      endif
! uxb2
      if (lpencil(i_uxb2)) call dot2_mn(p%uxb,p%uxb2)
! uxj
      if (lpencil(i_uxj)) call cross_mn(p%uu,p%jj,p%uxj)
! beta
      if (lpencil(i_beta)) p%beta=0.5*p%b2/p%pp
! djuidjbi
      if (lpencil(i_djuidjbi)) call multmm_sc(p%uij,p%bij,p%djuidjbi)
! jo
      if (lpencil(i_jo)) call dot(p%jj,p%oo,p%jo)
! ujxb
      if (lpencil(i_ujxb)) call dot_mn(p%uu,p%jxb,p%ujxb)
! oxu
      if (lpencil(i_oxu)) call cross_mn(p%oo,p%uu,p%oxu)
! oxuxb
      if (lpencil(i_oxuxb)) call cross_mn(p%oxu,p%bb,p%oxuxb)
! jxbxb
      if (lpencil(i_jxbxb)) call cross_mn(p%jxb,p%bb,p%jxbxb)
! jxbrxb
      if (lpencil(i_jxbrxb)) call cross_mn(p%jxbr,p%bb,p%jxbrxb)
! glnrhoxb
      if (lpencil(i_glnrhoxb)) call cross_mn(p%glnrho,p%bb,p%glnrhoxb)
! del4a
      if (lpencil(i_del4a)) call del4v(f,iaa,p%del4a)
! del6a
      if (lpencil(i_del6a)) call del6v(f,iaa,p%del6a)
! oxj
      if (lpencil(i_oxj)) call cross_mn(p%oo,p%jj,p%oxJ)
! jij
      if (lpencil(i_jij)) then
        do j=1,3
          do i=1,3
            p%jij(:,i,j)=.5*(p%bij(:,i,j)+p%bij(:,j,i))
          enddo
        enddo
      endif
! sj
      if (lpencil(i_sj)) call multmm_sc(p%sij,p%jij,p%sj)
! ss12
      if (lpencil(i_ss12)) p%ss12=sqrt(abs(p%sj))
!
!  Store bb in auxiliary variable if requested.
!  Just neccessary immediately before writing snapshots, but how would we
!  know we are?
!
     if (lbb_as_aux) f(l1:l2,m,n,ibx:ibz)=p%bb
     if (ljj_as_aux) f(l1:l2,m,n,ijx:ijz)=p%jj
!
!  Calculate magnetic mean-field pencils.
!  This should always be done after calculating magnetic pencils.
!
      if (lmeanfield_theory) call calc_pencils_magnetic_mf(f,p)
!
    endsubroutine calc_pencils_magnetic
!***********************************************************************
    subroutine daa_dt(f,df,p)
!
!  Magnetic field evolution.
!
!  Calculate dA/dt=uxB+3/2 Omega_0 A_y x_dir -eta mu_0 J.
!  Add jxb/rho to momentum equation.
!  Add eta mu_0 j2/rho to entropy equation.
!
!  22-nov-01/nils: coded
!   1-may-02/wolf: adapted for pencil_modular
!  17-jun-03/ulf:  added bx^2, by^2 and bz^2 as separate diagnostics
!   8-aug-03/axel: introduced B_ext21=1./B_ext**2, and set =1 to avoid div. by 0
!  12-aug-03/christer: added alpha effect (alpha in the equation above)
!  26-may-04/axel: ambipolar diffusion added
!  18-jun-04/axel: Hall term added
!
      use Deriv, only: der6
      use Diagnostics
      use EquationOfState, only: eoscalc
      use Io, only: output_pencil
      use Mpicomm, only: stop_it
      use Special, only: special_calc_magnetic
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx,3) :: geta,uxDxuxb,fres,uxb_upw,tmp2
      real, dimension (nx,3) :: exj,dexb,phib,aa_xyaver,jxbb
      real, dimension (nx,3) :: ujiaj
      real, dimension (nx) :: exabot,exatop
      real, dimension (nx) :: jxb_dotB0,uxb_dotB0
      real, dimension (nx) :: oxuxb_dotB0,jxbxb_dotB0,uxDxuxb_dotB0
      real, dimension (nx) :: uj,aj,phi,dub,dob
      real, dimension (nx) :: uxj_dotB0,b3b21,b1b32,b2b13
      real, dimension (nx) :: sign_jo,rho1_jxb
      real, dimension (nx) :: B1dot_glnrhoxb,tmp1,fb,fxbx
      real, dimension (nx) :: b2t,bjt,jbt
      real, dimension (nx) :: eta_mn,eta_smag,etatotal
      real, dimension (nx) :: fres2,etaSS,penc
      real, dimension (nx) :: vdrift
      real :: tmp,eta_out1
      real, parameter :: OmegaSS=1.0
      integer :: i,j,k,ju,ix
      integer, parameter :: nxy=nxgrid*nygrid
!
      intent(inout)  :: f,p
      intent(inout)  :: df
!
!  Identify module and boundary conditions.
!
      call timing('daa_dt','entered',mnloop=.true.)
      if (headtt.or.ldebug) print*,'daa_dt: SOLVE'
      if (headtt) then
        call identify_bcs('Ax',iax)
        call identify_bcs('Ay',iay)
        call identify_bcs('Az',iaz)
      endif
!
!  Add jxb/rho to momentum equation.
!
      if (lhydro) then
        if (.not.lkinematic) then
          if (llorentzforce) df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+p%jxbr
        endif
      endif
!
!  Restivivity term
!
!  Because of gauge invariance, we can add the gradient of an arbitrary scalar
!  field Phi to the induction equation without changing the magnetic field,
!    dA/dt = u x B - eta j + grad(Phi).
!
!  If lweyl_gauge=T, we choose Phi = const. and solve
!    dA/dt = u x B - eta j.
!
!  Else, if lweyl_gauge=F, we make the gauge choice Phi = eta div(A)
!  and thus solve
!    dA/dt = u x B + eta laplace(A) + div(A) grad(eta).
!
!  Note: lweyl_gauge=T is so far only implemented for some resistivity types.
!
      if (headtt) print*, 'daa_dt: iresistivity=', iresistivity
!
      fres=0.0
      etatotal=0.0
!
      if (lresi_eta_const) then
        if (lweyl_gauge) then
          fres=fres-eta*p%jj
        else
          fres=fres+eta*p%del2a
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta
        etatotal=etatotal+eta
      endif
      if (lresi_sqrtrhoeta_const) then
        if (lweyl_gauge) then
        do j=1,3
          fres(:,j)=fres(:,j)-eta*sqrt(p%rho1)*p%jj(:,j)
        enddo
        else
        do j=1,3
          fres(:,j)=fres(:,j)+eta*sqrt(p%rho1)*p%del2a(:,j)
        enddo
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta*sqrt(p%rho1)
        etatotal=etatotal+eta*sqrt(p%rho1)
      endif
!
!  Shakura-Sunyaev type resistivity (mainly just as a demo to show
!  how resistivity can be made depend on temperature.
!  Since etaSS is nonuniform, we use this contribution only for -etaSS*JJ
!  and keep the constant piece with +eta*del2A. (The divA term is eliminated
!  by a suitable gauge transformation.) A sample run is checked in under
!  pencil-runs/1d-tests/bdecay
!
      if (lresi_etaSS) then
        etaSS=alphaSSm*p%cs2/OmegaSS
        do j=1,3
          fres(:,j)=fres(:,j)+eta*p%del2a(:,j)-etaSS*p%jj(:,j)
        enddo
        if (lfirst.and.ldt) diffus_eta=diffus_eta+etaSS+eta
        etatotal=etatotal+etaSS+eta
      endif
!
      if (lresi_xydep) then
        do j=1,3
          fres(:,j)=fres(:,j)+eta_xy(l1:l2,m)*p%del2a(:,j)+geta_xy(l1:l2,m,j)*p%diva
        enddo
!
!  Time step check for eta_xy part.
!
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_xy_max
        etatotal=etatotal+eta_xy(l1,m)
      endif
!
      if (lresi_zdep) then
        if (lweyl_gauge) then
          fres=fres-eta_z(n)*p%jj
        else
          do j=1,3
            fres(:,j)=fres(:,j)+eta_z(n)*p%del2a(:,j)+geta_z(n,j)*p%diva
          enddo
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_z(n)
        etatotal=etatotal+eta_z(n)
      endif
!
      if (lresi_hyper2) then
        fres=fres+eta_hyper2*p%del4a
        if (lfirst.and.ldt) diffus_eta2=diffus_eta2+eta_hyper2
      endif
!
      if (lresi_hyper3) then
        fres=fres+eta_hyper3*p%del6a
        if (lfirst.and.ldt) diffus_eta3=diffus_eta3+eta_hyper3
      endif
!
      if (lresi_hyper3_polar) then
        do j=1,3
          ju=j+iaa-1
          do i=1,3
            call der6(f,ju,tmp1,i,IGNOREDX=.true.)
            fres(:,j)=fres(:,j)+eta_hyper3*pi4_1*tmp1*dline_1(:,i)**2
          enddo
        enddo
        if (lfirst.and.ldt) &
             diffus_eta3=diffus_eta3+eta_hyper3*pi4_1/dxyz_4
      endif
!
      if (lresi_hyper3_strict) then
        fres=fres+eta_hyper3*f(l1:l2,m,n,ihypres:ihypres+2)
        if (lfirst.and.ldt) diffus_eta3=diffus_eta3+eta_hyper3
      endif
!
      if (lresi_hyper3_aniso) then
         call del6fjv(f,eta_aniso_hyper3,iaa,tmp2)
         fres=fres+tmp2
!  Must divide by dxyz_6 here, because it is multiplied on later.
         if (lfirst.and.ldt) diffus_eta3=diffus_eta3 + &
             (eta_aniso_hyper3(1)*dline_1(:,1)**6 + &
              eta_aniso_hyper3(2)*dline_1(:,2)**6 + &
              eta_aniso_hyper3(3)*dline_1(:,3)**6)/dxyz_6
      endif
!
      if (lresi_shell) then
        call eta_shell(p,eta_mn,geta)
        do j=1,3
          fres(:,j)=fres(:,j)+eta_mn*p%del2a(:,j)+geta(:,j)*p%diva
        enddo
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_mn
        etatotal=etatotal+eta_mn
      endif
!
      if (lresi_eta_shock) then
        if (lweyl_gauge) then
          do i=1,3
            fres(:,i)=fres(:,i)-eta_shock*p%shock*p%jj(:,i)
          enddo
        else
          do i=1,3
            fres(:,i)=fres(:,i)+ &
                eta_shock*(p%shock*p%del2a(:,i)+p%diva*p%gshock(:,i))
          enddo
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_shock*p%shock
        etatotal=etatotal+eta_shock*p%shock
      endif
!
      if (lresi_eta_shock_perp) then
        if (lweyl_gauge) then
          do i=1,3
            fres(:,i)=fres(:,i)-eta_shock*p%shock_perp*p%jj(:,i)
          enddo
        else
          do i=1,3
            fres(:,i)=fres(:,i)+ &
                eta_shock*(p%shock_perp*p%del2a(:,i)+p%diva*p%gshock_perp(:,i))
          enddo
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_shock*p%shock_perp
        etatotal=etatotal+eta_shock*p%shock_perp
      endif
!
      if (lresi_etava) then
        forall (i = 1:3) fres(:,i) = fres(:,i) - p%etava * p%jj(:,i)
        if (lfirst.and.ldt) diffus_eta = diffus_eta + p%etava
        etatotal = etatotal + p%etava
      end if
!
      if (lresi_etaj) then
        forall (i = 1:3) fres(:,i) = fres(:,i) - p%etaj * p%jj(:,i)
        if (lfirst.and.ldt) diffus_eta = diffus_eta + p%etaj
        etatotal = etatotal + p%etaj
      end if
!
      if (lresi_etaj2) then
        forall (i = 1:3) fres(:,i) = fres(:,i) - p%etaj2 * p%jj(:,i)
        if (lfirst.and.ldt) diffus_eta = diffus_eta + p%etaj2
        etatotal = etatotal + p%etaj2
      end if
!
      if (lresi_etajrho) then
        forall (i = 1:3) fres(:,i) = fres(:,i) - p%etajrho * p%jj(:,i)
        if (lfirst.and.ldt) diffus_eta = diffus_eta + p%etajrho
        etatotal = etatotal + p%etajrho
      end if
!
      if (lresi_smagorinsky) then
        eta_smag=(D_smag*dxmax)**2.*sqrt(p%j2)
        call multsv(eta_smag+eta,p%del2a,fres)
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_smag+eta
        etatotal=etatotal+eta_smag+eta
      endif
!
      if (lresi_smagorinsky_cross) then
        sign_jo=1.
        do i=1,nx
          if (p%jo(i) < 0) sign_jo(i)=-1.
        enddo
        eta_smag=(D_smag*dxmax)**2.*sign_jo*sqrt(p%jo*sign_jo)
        call multsv(eta_smag+eta,p%del2a,fres)
        if (lfirst.and.ldt) diffus_eta=diffus_eta+eta_smag+eta
        etatotal=etatotal+eta_smag+eta
      endif
!
!  Anomalous resistivity. Sets in when the ion-electron drift speed is
!  larger than some critical value.
!
      if (lresi_anomalous) then
        vdrift=sqrt(sum(p%jj**2,2))*p%rho1
        if (lweyl_gauge) then
          do i=1,3
            where (vdrift>vcrit_anom) &
                fres(:,i)=fres(:,i)-eta_anom*vdrift/vcrit_anom*p%jj(:,i)
          enddo
        else
          if (lroot) print*, 'daa_dt: must have Weyl gauge for '// &
              'anomalous resistivity'
          call fatal_error('daa_dt','')
        endif
        if (lfirst.and.ldt) then
          where (vdrift>vcrit_anom) &
              diffus_eta=diffus_eta+eta_anom*vdrift/vcrit_anom
        endif
        where (vdrift>vcrit_anom) etatotal=etatotal+eta_anom*vdrift/vcrit_anom
      endif
!
! Temperature dependent resistivity for the solar corona (Spitzer 1969)
!
      if (lresi_spitzer) then
        etatotal = etatotal + eta_spitzer*exp(-1.5*p%lnTT)
        if (lweyl_gauge) then
          do i=1,3
            fres(:,i)=fres(:,i)-eta_spitzer*exp(-1.5*p%lnTT)*p%jj(:,i)
          enddo
        else
          do i=1,3
            fres(:,i)=fres(:,i)+eta_spitzer*(exp(-1.5*p%lnTT)*p%del2a(:,i)-&
                1.5*p%diva*p%glnTT(:,i))
          enddo
        endif
        if (lfirst.and.ldt) then
          diffus_eta=diffus_eta+eta_spitzer*exp(-1.5*p%lnTT)
        endif
      endif
!
!  Ambipolar diffusion in the strong coupling approximation.
!
      if (nu_ni/=0.0) then
        df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)+nu_ni1*p%jxbrxb
        if (lentropy .and. lneutralion_heat) then
          if (pretend_lnTT) then
            df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + p%cv1*p%TT1*nu_ni1*p%jxbr2
          else
            df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + p%TT1*nu_ni1*p%jxbr2
         endif
        endif
        if (lfirst.and.ldt) diffus_eta=diffus_eta+nu_ni1*p%va2
      endif
!
!  Consider here the action of a mean friction term, -LLambda*Abar.
!
      if (lmean_friction) then
        if (nprocx*nprocy==1) then
          do j=1,3
            aa_xyaver(:,j)=sum(f(l1:l2,m1:m2,n,j+iax-1))/nxy
          enddo
          df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)-LLambda_aa*aa_xyaver
        else
          call stop_it("magnetic: lmean_friction works only for nprocxy=1")
        endif
      endif
!
!  Special contributions to this module are called here.
!
      if (lspecial) call special_calc_magnetic(f,df,p)
!
!  Multiply resistivity by Nyquist scale, for resistive time-step.
!
      if (lfirst.and.ldt) then
        diffus_eta =diffus_eta *dxyz_2
        diffus_eta2=diffus_eta2*dxyz_4
        diffus_eta3=diffus_eta3*dxyz_6
        if (ietat/=0) diffus_eta=diffus_eta+maxval(f(l1:l2,m,n,ietat))*dxyz_2
!
        if (headtt.or.ldebug) then
          print*, 'daa_dt: max(diffus_eta)  =', maxval(diffus_eta)
          print*, 'daa_dt: max(diffus_eta2) =', maxval(diffus_eta2)
          print*, 'daa_dt: max(diffus_eta3) =', maxval(diffus_eta3)
        endif
      endif
!
!  Add Ohmic heat to entropy or temperature equation.
!
      if (.not.lkinematic.and.lohmic_heat) then
        if (lentropy) then
          if (pretend_lnTT) then
            df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + &
                p%cv1*etatotal*mu0*p%j2*p%rho1*p%TT1
          else
            df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + &
                      etatotal*mu0*p%j2*p%rho1*p%TT1
          endif
        else if (ltemperature) then
          if (ltemperature_nolog) then
            df(l1:l2,m,n,iTT)   = df(l1:l2,m,n,iTT) + &
                 p%cv1*etatotal*mu0*p%j2*p%rho1
          else
            df(l1:l2,m,n,ilnTT) = df(l1:l2,m,n,ilnTT) + &
                 p%cv1*etatotal*mu0*p%j2*p%rho1*p%TT1
          endif
        endif
      endif
!
!  Switch off diffusion in boundary slice if requested by boundconds.
!
!  Only need to do this on bottommost (topmost) processors
!  and in bottommost (topmost) pencils.
!
      do j=1,3
        if (lfrozen_bb_bot(j).and.lfirst_proc_z .and.n==n1) fres(:,j)=0.
        if (lfrozen_bb_top(j).and.llast_proc_z.and.n==n2) fres(:,j)=0.
      enddo
!
!  Induction equation.
!
      if (.not.lupw_aa) then
        if (linduction) then
          if (ladvective_gauge) then
!
!  Take care of possibility of imposed field.
!
            if (any(B_ext/=0.)) then
              ujiaj(:,1)=p%uu(:,2)*B_ext(3)-p%uu(:,3)*B_ext(2)
              ujiaj(:,2)=p%uu(:,3)*B_ext(1)-p%uu(:,1)*B_ext(3)
              ujiaj(:,3)=p%uu(:,1)*B_ext(2)-p%uu(:,2)*B_ext(1)
            else
              ujiaj=0.
            endif
!
            do j=1,3
              do k=1,3
                ujiaj(:,j)=ujiaj(:,j)+p%aa(:,k)*p%uij(:,k,j)
              enddo
            enddo
            df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)-p%uga-ujiaj+fres
!
!  ladvective_gauge=F, so just the normal uxb term plus resistive term.
!
          else
            df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)+p%uxb+fres
          endif
        endif
      else
!
!  Use upwinding for the advection term.
!
!  We only do upwinding for advection-like terms, u_i f_k,j,
!  for which i=j. This means that for instance in the evolution
!  equation for A_x,
!
!  d(A_x)/dt + u_y A_x,y + u_z A_x,z = u_y A_y,x + u_z A_z,x
!
!  we only do upwinding for the advection-type terms on the
!  left hand side.
!
        if (lupw_aa.and.headtt) then
          print *,'calc_pencils_magnetic: upwinding advection term. '//&
                  'Not well tested; use at own risk!'
        endif
!
!  Add Lorentz force that results from the external field.
!  Note: For now, this only works for uniform external fields.
!
        if (any(B_ext/=0.)) then
          uxb_upw(:,1) = p%uu(:,2)*B_ext(3) - p%uu(:,3)*B_ext(2)
          uxb_upw(:,2) = p%uu(:,3)*B_ext(1) - p%uu(:,1)*B_ext(3)
          uxb_upw(:,3) = p%uu(:,1)*B_ext(2) - p%uu(:,2)*B_ext(1)
        else
          uxb_upw=0.
        endif
!
!  Add u_k A_k,j and `upwinded' advection term.
!  Note: this works currently only in cartesian geometry!
!
        if (ladvective_gauge) then
          ujiaj=0.
          do j=1,3
            do k=1,3
              ujiaj(:,j)=ujiaj(:,j)+p%aa(:,k)*p%uij(:,k,j)
            enddo
            uxb_upw(:,j)=uxb_upw(:,j)-p%uga(:,j)-ujiaj(:,j)
          enddo
!
!  ladvective_gauge=F, so just the normal uxb term plus resistive term.
!
        else
          do j=1,3; do k=1,3
            if (k/=j) then
              uxb_upw(:,j)=uxb_upw(:,j)+p%uu(:,k)*(p%aij(:,k,j)-p%aij(:,j,k))
              call der6(f,iaa+j-1,penc,k,upwind=.true.)
              uxb_upw(:,j) = uxb_upw(:,j) + abs(p%uu(:,k))*penc
            endif
          enddo; enddo
        endif
!
!  Full right hand side of the induction equation.
!
        if (linduction) &
             df(l1:l2,m,n,iax:iaz) = df(l1:l2,m,n,iax:iaz) + uxb_upw + fres
      endif
!
!  Add Hall term.
!
      if (hall_term/=0.0) then
        if (headtt) print*,'daa_dt: hall_term=',hall_term
        df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)-hall_term*p%jxb
        if (lfirst.and.ldt) then
          advec_hall=abs(p%uu(:,1)-hall_term*p%jj(:,1))*dx_1(l1:l2)+ &
                     abs(p%uu(:,2)-hall_term*p%jj(:,2))*dy_1(  m  )+ &
                     abs(p%uu(:,3)-hall_term*p%jj(:,3))*dz_1(  n  )
        endif
        if (headtt.or.ldebug) print*,'daa_dt: max(advec_hall) =',&
                                     maxval(advec_hall)
      endif
!
!  Possibility of adding extra diffusivity in some halo of given geometry.
!  Note that eta_out is total eta in halo (not eta_out+eta).
!
      if (height_eta/=0.0) then
        if (headtt) print*,'daa_dt: height_eta,eta_out,lhalox=',height_eta,eta_out,lhalox
        if (lhalox) then
          do ix=1,nx
            tmp=(x(ix)/height_eta)**2
            eta_out1=eta_out*(1.0-exp(-tmp**5/max(1.0-tmp,1.0e-5)))-eta
          enddo
        else
!         tmp=(z(n)/height_eta)**2
!         eta_out1=eta_out*(1.0-exp(-tmp**5/max(1.0-tmp,1.0e-5)))-eta
          eta_out1=eta_out*0.5*(1.-erfunc((z(n)-height_eta)/eta_width))-eta
        endif
        df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)-(eta_out1*mu0)*p%jj
      endif
!
!  Add possibility of forcing that is not delta-correlated in time.
!
      if (lforcing_cont_aa) df(l1:l2,m,n,iax:iaz)=df(l1:l2,m,n,iax:iaz)+ &
          ampl_fcont_aa*p%fcont
!
!  Add possibility of local forcing that is also not delta-correlated in time.
!
      if (lforcing_cont_aa_local) call forcing_continuous(df,p)
!
!  Possibility of relaxation of A in exterior region.
!
      if (tau_aa_exterior/=0.0) call calc_tau_aa_exterior(f,df)
!
!  Add ``va^2/dx^2'' contribution to timestep.
!  Consider advective timestep only when lhydro=T.
!
      if (lfirst.and.ldt) then
        if (lhydro) then
          rho1_jxb=p%rho1
          if (rhomin_jxb>0) rho1_jxb=min(rho1_jxb,1/rhomin_jxb)
          if (va2max_jxb>0) then
            rho1_jxb = rho1_jxb &
                     * (1+(p%va2/va2max_jxb)**va2power_jxb)**(-1.0/va2power_jxb)
          endif
          if (lspherical_coords) then
            advec_va2=((p%bb(:,1)*dx_1(l1:l2))**2+ &
                       (p%bb(:,2)*dy_1(  m  )*r1_mn)**2+ &
                       (p%bb(:,3)*dz_1(  n  )*r1_mn*sin1th(m))**2)*mu01*rho1_jxb
          elseif (lcylindrical_coords) then
            advec_va2=((p%bb(:,1)*dx_1(l1:l2))**2+ &
                       (p%bb(:,2)*dy_1(  m  )*rcyl_mn1)**2+ &
                       (p%bb(:,3)*dz_1(  n  ))**2)*mu01*rho1_jxb
          else
            advec_va2=((p%bb(:,1)*dx_1(l1:l2))**2+ &
                       (p%bb(:,2)*dy_1(  m  ))**2+ &
                       (p%bb(:,3)*dz_1(  n  ))**2)*mu01*rho1_jxb
          endif
        endif
!
!WL: don't know if this is correct, but it's the only way I can make
!    some 1D and 2D samples work when the non-existent direction has the
!    largest velocity (like a 2D rz slice of a Keplerian disk that rotates
!    on the phi direction)
!    Please check
!
        if (lisotropic_advection) then
          if (lfirst.and.ldt) then
            if ((nxgrid==1).or.(nygrid==1).or.(nzgrid==1)) &
                 advec_va2=sqrt(p%va2*dxyz_2)
          endif
        endif
      endif
!
!  Apply border profiles.
!
      if (lborder_profiles) call set_border_magnetic(f,df,p)
!
!  Call right-hand side for mean-field stuff (do this just before ldiagnos)
!
      if (lmeanfield_theory) call daa_dt_meanfield(f,df,p)
!
!  Calculate diagnostic quantities.
!
      if (ldiagnos) then
        if (idiag_beta1m/=0) call sum_mn_name(p%beta,idiag_beta1m)
        if (idiag_beta1max/=0) call max_mn_name(p%beta,idiag_beta1max)
!
!  Integrate velocity in time, to calculate correlation time later.
!
        if (idiag_b2tm/=0) then
          if (ibbt==0) call stop_it("Cannot calculate b2tm if ibbt==0")
          call dot(p%bb,f(l1:l2,m,n,ibxt:ibzt),b2t)
          call sum_mn_name(b2t,idiag_b2tm)
        endif
!
!  Integrate velocity in time, to calculate correlation time later.
!
        if (idiag_jbtm/=0) then
          if (ibbt==0) call stop_it("Cannot calculate jbtm if ibbt==0")
          call dot(p%jj,f(l1:l2,m,n,ibxt:ibzt),jbt)
          call sum_mn_name(jbt,idiag_jbtm)
        endif
!
!  Integrate velocity in time, to calculate correlation time later.
!
        if (idiag_bjtm/=0) then
          if (ijjt==0) call stop_it("Cannot calculate bjtm if ijjt==0")
          call dot(p%bb,f(l1:l2,m,n,ijxt:ijzt),bjt)
          call sum_mn_name(bjt,idiag_bjtm)
        endif
!
!  Contributions to vertical Poynting vector. Consider them here
!  separately, because the contribution b^2*uz may be a good indicator
!  of magnetic buoyancy.
!
        if (idiag_b2ruzm/=0) call sum_mn_name(p%b2*p%rho*p%uu(:,3),idiag_b2ruzm)
        if (idiag_b2uzm/=0) call sum_mn_name(p%b2*p%uu(:,3),idiag_b2uzm)
        if (idiag_ubbzm/=0) call sum_mn_name(p%ub*p%bb(:,3),idiag_ubbzm)
!
!  Mean squared and maximum squared magnetic field.
!
        if (idiag_b1m/=0) call sum_mn_name(sqrt(p%b2),idiag_b1m)
        if (idiag_b2m/=0) call sum_mn_name(p%b2,idiag_b2m)
        if (idiag_bm2/=0) call max_mn_name(p%b2,idiag_bm2)
        if (idiag_brms/=0) call sum_mn_name(p%b2,idiag_brms,lsqrt=.true.)
        if (idiag_emag/=0) call integrate_mn_name(mu012*p%b2,idiag_emag)
        if (idiag_brmsh/=0) then
          if (lequatory) call sum_mn_name_halfy(p%b2,idiag_brmsh)
          if (lequatorz) call sum_mn_name_halfz(p%b2,idiag_brmsh)
          fname(idiag_brmsn)=fname_half(idiag_brmsh,1)
          fname(idiag_brmss)=fname_half(idiag_brmsh,2)
          itype_name(idiag_brmsn)=ilabel_sum_sqrt
          itype_name(idiag_brmss)=ilabel_sum_sqrt
        endif
        if (idiag_bmax/=0) call max_mn_name(p%b2,idiag_bmax,lsqrt=.true.)
        if (idiag_bxmin/=0) call max_mn_name(-p%bb(:,1),idiag_bxmin,lneg=.true.)
        if (idiag_bymin/=0) call max_mn_name(-p%bb(:,2),idiag_bymin,lneg=.true.)
        if (idiag_bzmin/=0) call max_mn_name(-p%bb(:,3),idiag_bzmin,lneg=.true.)
        if (idiag_bxmax/=0) call max_mn_name(p%bb(:,1),idiag_bxmax)
        if (idiag_bymax/=0) call max_mn_name(p%bb(:,2),idiag_bymax)
        if (idiag_bzmax/=0) call max_mn_name(p%bb(:,3),idiag_bzmax)
        if (idiag_aybym2/=0) &
            call sum_mn_name(2*p%aa(:,2)*p%bb(:,2),idiag_aybym2)
        if (idiag_abm/=0) call sum_mn_name(p%ab,idiag_abm)
        if (idiag_abumx/=0) call sum_mn_name(p%uu(:,1)*p%ab,idiag_abumx)
        if (idiag_abumy/=0) call sum_mn_name(p%uu(:,2)*p%ab,idiag_abumy)
        if (idiag_abumz/=0) call sum_mn_name(p%uu(:,3)*p%ab,idiag_abumz)
        if (idiag_abrms/=0) call sum_mn_name(p%ab**2,idiag_abrms,lsqrt=.true.)
!
!  Hemispheric magnetic helicity of total field.
!  North means 1 and south means 2.
!
        if (idiag_abmh/=0) then
          if (lequatory) call sum_mn_name_halfy(p%ab,idiag_abmh)
          if (lequatorz) call sum_mn_name_halfz(p%ab,idiag_abmh)
          fname(idiag_abmn)=fname_half(idiag_abmh,1)
          fname(idiag_abms)=fname_half(idiag_abmh,2)
          itype_name(idiag_abmn)=ilabel_sum
          itype_name(idiag_abms)=ilabel_sum
        endif
!
!  Hemispheric current helicity of total field.
!  North means 1 and south means 2.
!
        if (idiag_jbmh/=0) then
          if (lequatory) call sum_mn_name_halfy(p%jb,idiag_jbmh)
          if (lequatorz) call sum_mn_name_halfz(p%jb,idiag_jbmh)
          fname(idiag_jbmn)=fname_half(idiag_jbmh,1)
          fname(idiag_jbms)=fname_half(idiag_jbmh,2)
          itype_name(idiag_jbmn)=ilabel_sum
          itype_name(idiag_jbms)=ilabel_sum
        endif
!
!  Mean dot product of forcing and magnetic field, <f.b>.
!
        if (idiag_fbm/=0) then
          call dot(p%fcont,p%bb,fb)
          call sum_mn_name(fb,idiag_fbm)
        endif
!
        if (idiag_fxbxm/=0) then
          fxbx=p%fcont(:,1)*p%bb(:,1)
          call sum_mn_name(fxbx,idiag_fxbxm)
        endif
!
!  Cross helicity (linkage between vortex tubes and flux tubes).
!
        if (idiag_ubm/=0) call sum_mn_name(p%ub,idiag_ubm)
        if (idiag_uxbxm/=0) call sum_mn_name(p%uu(:,1)*p%bb(:,1),idiag_uxbxm)
        if (idiag_uybym/=0) call sum_mn_name(p%uu(:,2)*p%bb(:,2),idiag_uybym)
        if (idiag_uzbzm/=0) call sum_mn_name(p%uu(:,3)*p%bb(:,3),idiag_uzbzm)
        if (idiag_cosubm/=0) call sum_mn_name(p%cosub,idiag_cosubm)
!
!  compute rms value of difference between u and b
!
        if (idiag_dubrms/=0) then
          call dot2(p%uu-p%bb,dub)
          call sum_mn_name(dub,idiag_dubrms,lsqrt=.true.)
        endif
!
!  compute rms value of difference between u and b
!
        if (idiag_dobrms/=0) then
          call dot2(p%oo-p%bb,dob)
          call sum_mn_name(dob,idiag_dobrms,lsqrt=.true.)
        endif
!
!  Field-velocity cross helicity (linkage between velocity and magnetic tubes).
!
        if (idiag_uam/=0) call sum_mn_name(p%ua,idiag_uam)
!
!  Current-vortex cross helicity (linkage between vortex and current tubes).
!
        if (idiag_ujm/=0) then
          call dot (p%uu,p%jj,uj)
          call sum_mn_name(uj,idiag_ujm)
        endif
!
!  rms values of mean field.
!
        if (idiag_bxm/=0) call sum_mn_name(p%bbb(:,1),idiag_bxm)
        if (idiag_bym/=0) call sum_mn_name(p%bbb(:,2),idiag_bym)
        if (idiag_bzm/=0) call sum_mn_name(p%bbb(:,3),idiag_bzm)
        if (idiag_bx2m/=0) call sum_mn_name(p%bbb(:,1)**2,idiag_bx2m)
        if (idiag_by2m/=0) call sum_mn_name(p%bbb(:,2)**2,idiag_by2m)
        if (idiag_bz2m/=0) call sum_mn_name(p%bbb(:,3)**2,idiag_bz2m)
        if (idiag_bxbym/=0) call sum_mn_name(p%bbb(:,1)*p%bbb(:,2),idiag_bxbym)
        if (idiag_bxbzm/=0) call sum_mn_name(p%bbb(:,1)*p%bbb(:,3),idiag_bxbzm)
        if (idiag_bybzm/=0) call sum_mn_name(p%bbb(:,2)*p%bbb(:,3),idiag_bybzm)
        if (idiag_djuidjbim/=0) call sum_mn_name(p%djuidjbi,idiag_djuidjbim)
!
!  Calculate B*sin(phi) = -<Bx*sinkz> + <By*coskz>.
!
        if (idiag_bsinphz/=0) call sum_mn_name(-p%bbb(:,1)*sinkz(n)+p%bbb(:,2)*coskz(n),idiag_bsinphz)
!
!  Calculate B*cos(phi) = <Bx*coskz> + <By*sinkz>.
!
        if (idiag_bcosphz/=0) call sum_mn_name(+p%bbb(:,1)*coskz(n)+p%bbb(:,2)*sinkz(n),idiag_bcosphz)
!
!  Magnetic field components at one point (=pt).
!
        if (lroot.and.m==mpoint.and.n==npoint) then
          if (idiag_bxpt/=0) call save_name(p%bb(lpoint-nghost,1),idiag_bxpt)
          if (idiag_bypt/=0) call save_name(p%bb(lpoint-nghost,2),idiag_bypt)
          if (idiag_bzpt/=0) call save_name(p%bb(lpoint-nghost,3),idiag_bzpt)
          if (idiag_Expt/=0) call save_name(uxbb(lpoint-nghost,1),idiag_Expt)
          if (idiag_Eypt/=0) call save_name(uxbb(lpoint-nghost,2),idiag_Eypt)
          if (idiag_Ezpt/=0) call save_name(uxbb(lpoint-nghost,3),idiag_Ezpt)
        endif
!
!  v_A = |B|/sqrt(rho); in units where mu_0=1
!
        if (idiag_vA2m/=0)  call sum_mn_name(p%va2,idiag_vA2m)
        if (idiag_vArms/=0) call sum_mn_name(p%va2,idiag_vArms,lsqrt=.true.)
        if (idiag_vAmax/=0) call max_mn_name(p%va2,idiag_vAmax,lsqrt=.true.)
        if (idiag_dtb/=0) &
            call max_mn_name(sqrt(advec_va2)/cdt,idiag_dtb,l_dt=.true.)
!
!  Lorentz force.
!
        if (idiag_jxbrxm/=0) call sum_mn_name(p%jxbr(:,1),idiag_jxbrxm)
        if (idiag_jxbrym/=0) call sum_mn_name(p%jxbr(:,2),idiag_jxbrym)
        if (idiag_jxbrzm/=0) call sum_mn_name(p%jxbr(:,3),idiag_jxbrzm)
        if (idiag_jxbr2m/=0) call sum_mn_name(p%jxbr2,idiag_jxbr2m)
!
!  <J.A> for calculating k_effective, for example.
!
        if (idiag_ajm/=0) then
          call dot (p%aa,p%jj,aj)
          call sum_mn_name(aj,idiag_ajm)
        endif
!
!  Output kx_aa for calculating k_effective.
!
        if (idiag_kx_aa/=0) call save_name(kx_aa(1),idiag_kx_aa)
!
!  Helicity integrals.
!
        if (idiag_ab_int/=0) call integrate_mn_name(p%ab,idiag_ab_int)
        if (idiag_jb_int/=0) call integrate_mn_name(p%jb,idiag_jb_int)
!
! <J.B>
!
        if (idiag_jbm/=0) call sum_mn_name(p%jb,idiag_jbm)
        if (idiag_j2m/=0) call sum_mn_name(p%j2,idiag_j2m)
        if (idiag_jm2/=0) call max_mn_name(p%j2,idiag_jm2)
        if (idiag_jrms/=0) call sum_mn_name(p%j2,idiag_jrms,lsqrt=.true.)
        if (idiag_jmax/=0) call max_mn_name(p%j2,idiag_jmax,lsqrt=.true.)
        if (idiag_epsM_LES/=0) call sum_mn_name(eta_smag*p%j2,idiag_epsM_LES)
        if (idiag_dteta/=0)  call max_mn_name(diffus_eta/cdtv,idiag_dteta,l_dt=.true.)
        if (idiag_cosjbm/=0) call sum_mn_name(p%cosjb,idiag_cosjbm)
        if (idiag_jparallelm/=0) call sum_mn_name(p%jparallel,idiag_jparallelm)
        if (idiag_jperpm/=0) call sum_mn_name(p%jperp,idiag_jperpm)
!
!  Resistivity.
!
        if (idiag_etasmagm/=0)   call sum_mn_name(eta_smag,idiag_etasmagm)
        if (idiag_etasmagmin/=0) call max_mn_name(-eta_smag,idiag_etasmagmin,lneg=.true.)
        if (idiag_etasmagmax/=0) call max_mn_name(eta_smag,idiag_etasmagmax)
        if (idiag_etavamax/=0) call max_mn_name(p%etava,idiag_etavamax)
        if (idiag_etajmax/=0) call max_mn_name(p%etaj,idiag_etajmax)
        if (idiag_etaj2max/=0) call max_mn_name(p%etaj2,idiag_etaj2max)
        if (idiag_etajrhomax/=0) call max_mn_name(p%etajrho,idiag_etajrhomax)
!
!  Not correct for hyperresistivity:
!
        if (idiag_epsM/=0) call sum_mn_name(eta*p%j2,idiag_epsM)
!
!  Heating by ion-neutrals friction.
!
        if (idiag_epsAD/=0) call sum_mn_name(nu_ni1*p%rho*p%jxbr2,idiag_epsAD)
!
!  <A>'s, <A^2> and A^2|max
!
        if (idiag_axm/=0) call sum_mn_name(p%aa(:,1),idiag_axm)
        if (idiag_aym/=0) call sum_mn_name(p%aa(:,2),idiag_aym)
        if (idiag_azm/=0) call sum_mn_name(p%aa(:,3),idiag_azm)
        if (idiag_arms/=0) call sum_mn_name(p%a2,idiag_arms,lsqrt=.true.)
        if (idiag_amax/=0) call max_mn_name(p%a2,idiag_amax,lsqrt=.true.)
!
!  Calculate surface integral <2ExA>*dS.
!
        if (idiag_exaym2/=0) call helflux(p%aa,p%uxb,p%jj)
!
!  Calculate surface integral <2ExJ>*dS.
!
        if (idiag_exjm2/=0) call curflux(p%uxb,p%jj)
!--     if (idiag_exjm2/=0) call curflux_dS(p%uxb,p%jj)
!
!  Calculate emf for alpha effect (for imposed field).
!  Note that uxbm means <EMF.B0>/B0^2, so it gives already alpha=EMF/B0.
!
        if (idiag_uxbm/=0 .or. idiag_uxbmx/=0 .or. idiag_uxbmy/=0 &
            .or. idiag_uxbcmx/=0 .or. idiag_uxbcmy/=0 &
            .or. idiag_uxbsmx/=0 .or. idiag_uxbsmy/=0 &
            .or. idiag_uxbmz/=0) then
          call dot(B_ext_inv,p%uxb,uxb_dotB0)
          if (idiag_uxbm/=0) call sum_mn_name(uxb_dotB0,idiag_uxbm)
          if (idiag_uxbmx/=0) call sum_mn_name(uxbb(:,1),idiag_uxbmx)
          if (idiag_uxbmy/=0) call sum_mn_name(uxbb(:,2),idiag_uxbmy)
          if (idiag_uxbmz/=0) call sum_mn_name(uxbb(:,3),idiag_uxbmz)
          if (idiag_uxbcmx/=0) call sum_mn_name(uxbb(:,1)*coskz(n),idiag_uxbcmx)
          if (idiag_uxbcmy/=0) call sum_mn_name(uxbb(:,2)*coskz(n),idiag_uxbcmy)
          if (idiag_uxbsmx/=0) call sum_mn_name(uxbb(:,1)*sinkz(n),idiag_uxbsmx)
          if (idiag_uxbsmy/=0) call sum_mn_name(uxbb(:,2)*sinkz(n),idiag_uxbsmy)
        endif
!
!  Calculate part I of magnetic helicity flux (ExA contribution).
!
        if (idiag_examx/=0 .or. idiag_examy/=0 .or. idiag_examz/=0 .or. &
            idiag_exatop/=0 .or. idiag_exabot/=0) then
          if (idiag_examx/=0) call sum_mn_name(p%exa(:,1),idiag_examx)
          if (idiag_examy/=0) call sum_mn_name(p%exa(:,2),idiag_examy)
          if (idiag_examz/=0) call sum_mn_name(p%exa(:,3),idiag_examz)
!
          if (idiag_exabot/=0) then
            if (z(n)==xyz0(3)) then
              exabot=p%exa(:,3)
            else
              exabot=0.
            endif
            call integrate_mn_name(exabot,idiag_exabot)
          endif
!
          if (idiag_exatop/=0) then
            if (z(n)==xyz1(3)) then
              exatop=p%exa(:,3)
            else
              exatop=0.
            endif
            call integrate_mn_name(exatop,idiag_exatop)
          endif
!
        endif
!
!  Calculate part II of magnetic helicity flux (phi*B contribution).
!
        if (idiag_phibmx/=0 .or. idiag_phibmy/=0 .or. idiag_phibmz/=0) then
          if (lweyl_gauge) then
            phi=0.
          elseif (ladvective_gauge) then
            phi=p%ua
          else
            phi=eta*p%diva
          endif
          call multvs(p%bb,phi,phib)
          if (idiag_phibmx/=0) call sum_mn_name(phib(:,1),idiag_phibmx)
          if (idiag_phibmy/=0) call sum_mn_name(phib(:,2),idiag_phibmy)
          if (idiag_phibmz/=0) call sum_mn_name(phib(:,3),idiag_phibmz)
        endif
!
!  Calculate part I of current helicity flux (for imposed field).
!
        if (idiag_exjmx/=0 .or. idiag_exjmy/=0 .or. idiag_exjmz/=0) then
          call cross_mn(-p%uxb+eta*p%jj,p%jj,exj)
          if (idiag_exjmx/=0) call sum_mn_name(exj(:,1),idiag_exjmx)
          if (idiag_exjmy/=0) call sum_mn_name(exj(:,2),idiag_exjmy)
          if (idiag_exjmz/=0) call sum_mn_name(exj(:,3),idiag_exjmz)
        endif
!
!  Calculate part II of current helicity flux (for imposed field).
!  < curlE x B >|_i  =  < B_{j,i} E_j >
!  Use the full B (with B_ext)
!
        if (idiag_dexbmx/=0 .or. idiag_dexbmy/=0 .or. idiag_dexbmz/=0) then
          call multmv_transp(p%bij,-p%uxb+eta*p%jj,dexb)
          if (idiag_dexbmx/=0) call sum_mn_name(dexb(:,1),idiag_dexbmx)
          if (idiag_dexbmy/=0) call sum_mn_name(dexb(:,2),idiag_dexbmy)
          if (idiag_dexbmz/=0) call sum_mn_name(dexb(:,3),idiag_dexbmz)
        endif
!
!  Calculate <uxj>.B0/B0^2.
!
        if (idiag_uxjm/=0) then
          call dot(B_ext_inv,p%uxj,uxj_dotB0)
          call sum_mn_name(uxj_dotB0,idiag_uxjm)
        endif
!
!  Calculate <u x B>_rms, <resistive terms>_rms, <ratio ~ Rm>_rms.
!
        if (idiag_uxBrms/=0) call sum_mn_name(p%uxb2,idiag_uxBrms,lsqrt=.true.)
        if (idiag_Bresrms/=0 .or. idiag_Rmrms/=0) then
          call dot2_mn(fres,fres2)
          if (idiag_Bresrms/=0) &
              call sum_mn_name(fres2,idiag_Bresrms,lsqrt=.true.)
          if (idiag_Rmrms/=0) &
              call sum_mn_name(p%uxb2/fres2,idiag_Rmrms,lsqrt=.true.)
        endif
!
!  Calculate <b^2*divu>, which is part of <u.(jxb)>.
!  Note that <u.(jxb)>=1/2*<b^2*divu>+<u.bgradb>.
!
        if (idiag_b2divum/=0) call sum_mn_name(p%b2*p%divu,idiag_b2divum)
!
!  Calculate <u.(jxb)>.
!
        if (idiag_ujxbm/=0) call sum_mn_name(p%ujxb,idiag_ujxbm)
!
!  Calculate <jxb>.B_0/B_0^2.
!
        call dot(B_ext_inv,p%jxb,jxb_dotB0)
        if (idiag_jxbm/=0) call sum_mn_name(jxb_dotB0,idiag_jxbm)
        if (idiag_jxbmx/=0.or.idiag_jxbmy/=0.or.idiag_jxbmz/=0) then
          call cross_mn(p%jj,p%bbb,jxbb)
          if (idiag_jxbmx/=0) call sum_mn_name(jxbb(:,1),idiag_jxbmx)
          if (idiag_jxbmy/=0) call sum_mn_name(jxbb(:,2),idiag_jxbmy)
          if (idiag_jxbmz/=0) call sum_mn_name(jxbb(:,3),idiag_jxbmz)
        endif
!
!  Magnetic triple correlation term (for imposed field).
!
        if (idiag_jxbxbm/=0) then
          call dot(B_ext_inv,p%jxbxb,jxbxb_dotB0)
          call sum_mn_name(jxbxb_dotB0,idiag_jxbxbm)
        endif
!
!  Triple correlation from Reynolds tensor (for imposed field).
!
        if (idiag_oxuxbm/=0) then
          call dot(B_ext_inv,p%oxuxb,oxuxb_dotB0)
          call sum_mn_name(oxuxb_dotB0,idiag_oxuxbm)
        endif
!
!  Triple correlation from pressure gradient (for imposed field).
!  (assume cs2=1, and that no entropy evolution is included)
!  This is ok for all applications currently under consideration.
!
        if (idiag_gpxbm/=0) then
          call dot_mn_sv(B1_ext,p%glnrhoxb,B1dot_glnrhoxb)
          call sum_mn_name(B1dot_glnrhoxb,idiag_gpxbm)
        endif
!
!  < u x curl(uxB) > = < E_i u_{j,j} - E_j u_{j,i} >
!   ( < E_1 u2,2 + E1 u3,3 - E2 u2,1 - E3 u3,1 >
!     < E_2 u1,1 + E2 u3,3 - E1 u2,1 - E3 u3,2 >
!     < E_3 u1,1 + E3 u2,2 - E1 u3,1 - E2 u2,3 > )
!
        if (idiag_uxDxuxbm/=0) then
          uxDxuxb(:,1)=p%uxb(:,1)*(p%uij(:,2,2)+p%uij(:,3,3))-p%uxb(:,2)*p%uij(:,2,1)-p%uxb(:,3)*p%uij(:,3,1)
          uxDxuxb(:,2)=p%uxb(:,2)*(p%uij(:,1,1)+p%uij(:,3,3))-p%uxb(:,1)*p%uij(:,1,2)-p%uxb(:,3)*p%uij(:,3,2)
          uxDxuxb(:,3)=p%uxb(:,3)*(p%uij(:,1,1)+p%uij(:,2,2))-p%uxb(:,1)*p%uij(:,1,3)-p%uxb(:,2)*p%uij(:,2,3)
          call dot(B_ext_inv,uxDxuxb,uxDxuxb_dotB0)
          call sum_mn_name(uxDxuxb_dotB0,idiag_uxDxuxbm)
        endif
!
!  alpM11=<b3*b2,1>
!
        if (idiag_b3b21m/=0) then
          b3b21=p%bb(:,3)*p%bij(:,2,1)
          call sum_mn_name(b3b21,idiag_b3b21m)
        endif
!
!  alpM22=<b1*b3,2>
!
        if (idiag_b1b32m/=0) then
          b1b32=p%bb(:,1)*p%bij(:,3,2)
          call sum_mn_name(b1b32,idiag_b1b32m)
        endif
!
!  alpM33=<b2*b1,3>
!
        if (idiag_b2b13m/=0) then
          b2b13=p%bb(:,2)*p%bij(:,1,3)
          call sum_mn_name(b2b13,idiag_b2b13m)
        endif
!
      endif ! endif (ldiagnos)
!
!  1d-averages. Happens at every it1d timesteps, NOT at every it1.
!
      if (l1davgfirst .or. (ldiagnos .and. ldiagnos_need_zaverages)) then
        if (idiag_bxmx/=0)   call yzsum_mn_name_x(p%bb(:,1),idiag_bxmx)
        if (idiag_bymx/=0)   call yzsum_mn_name_x(p%bb(:,2),idiag_bymx)
        if (idiag_bzmx/=0)   call yzsum_mn_name_x(p%bb(:,3),idiag_bzmx)
        if (idiag_bx2mx/=0)  call yzsum_mn_name_x(p%bb(:,1)**2,idiag_bx2mx)
        if (idiag_by2mx/=0)  call yzsum_mn_name_x(p%bb(:,2)**2,idiag_by2mx)
        if (idiag_bz2mx/=0)  call yzsum_mn_name_x(p%bb(:,3)**2,idiag_bz2mx)
        if (idiag_bxbymx/=0) &
            call yzsum_mn_name_x(p%bbb(:,1)*p%bbb(:,2),idiag_bxbymx)
        if (idiag_bxmy/=0)   call xzsum_mn_name_y(p%bb(:,1),idiag_bxmy)
        if (idiag_bymy/=0)   call xzsum_mn_name_y(p%bb(:,2),idiag_bymy)
        if (idiag_bzmy/=0)   call xzsum_mn_name_y(p%bb(:,3),idiag_bzmy)
        if (idiag_bx2my/=0)  call xzsum_mn_name_y(p%bb(:,1)**2,idiag_bx2my)
        if (idiag_by2my/=0)  call xzsum_mn_name_y(p%bb(:,2)**2,idiag_by2my)
        if (idiag_bz2my/=0)  call xzsum_mn_name_y(p%bb(:,3)**2,idiag_bz2my)
        if (idiag_axmz/=0)   call xysum_mn_name_z(p%aa(:,1),idiag_axmz)
        if (idiag_aymz/=0)   call xysum_mn_name_z(p%aa(:,2),idiag_aymz)
        if (idiag_azmz/=0)   call xysum_mn_name_z(p%aa(:,3),idiag_azmz)
        if (idiag_abuxmz/=0) call xysum_mn_name_z(p%ab*p%uu(:,1),idiag_abuxmz)
        if (idiag_abuymz/=0) call xysum_mn_name_z(p%ab*p%uu(:,2),idiag_abuymz)
        if (idiag_abuzmz/=0) call xysum_mn_name_z(p%ab*p%uu(:,3),idiag_abuzmz)
        if (idiag_uabxmz/=0) call xysum_mn_name_z(p%ua*p%bb(:,1),idiag_uabxmz)
        if (idiag_uabymz/=0) call xysum_mn_name_z(p%ua*p%bb(:,2),idiag_uabymz)
        if (idiag_uabzmz/=0) call xysum_mn_name_z(p%ua*p%bb(:,3),idiag_uabzmz)
        if (idiag_bbxmz/=0)  call xysum_mn_name_z(p%bbb(:,1),idiag_bbxmz)
        if (idiag_bbymz/=0)  call xysum_mn_name_z(p%bbb(:,2),idiag_bbymz)
        if (idiag_bbzmz/=0)  call xysum_mn_name_z(p%bbb(:,3),idiag_bbzmz)
        if (idiag_bxmz/=0)   call xysum_mn_name_z(p%bb(:,1),idiag_bxmz)
        if (idiag_bymz/=0)   call xysum_mn_name_z(p%bb(:,2),idiag_bymz)
        if (idiag_bzmz/=0)   call xysum_mn_name_z(p%bb(:,3),idiag_bzmz)
        if (idiag_jxmz/=0)   call xysum_mn_name_z(p%jj(:,1),idiag_jxmz)
        if (idiag_jymz/=0)   call xysum_mn_name_z(p%jj(:,2),idiag_jymz)
        if (idiag_jzmz/=0)   call xysum_mn_name_z(p%jj(:,3),idiag_jzmz)
        if (idiag_Exmz/=0)   call xysum_mn_name_z(p%uxb(:,1),idiag_Exmz)
        if (idiag_Eymz/=0)   call xysum_mn_name_z(p%uxb(:,2),idiag_Eymz)
        if (idiag_Ezmz/=0)   call xysum_mn_name_z(p%uxb(:,3),idiag_Ezmz)
        if (idiag_bx2mz/=0)  call xysum_mn_name_z(p%bb(:,1)**2,idiag_bx2mz)
        if (idiag_by2mz/=0)  call xysum_mn_name_z(p%bb(:,2)**2,idiag_by2mz)
        if (idiag_bz2mz/=0)  call xysum_mn_name_z(p%bb(:,3)**2,idiag_bz2mz)
        if (idiag_bx2rmz/=0) call xysum_mn_name_z(p%bb(:,1)**2*p%rho1,idiag_bx2rmz)
        if (idiag_by2rmz/=0) call xysum_mn_name_z(p%bb(:,2)**2*p%rho1,idiag_by2rmz)
        if (idiag_bz2rmz/=0) call xysum_mn_name_z(p%bb(:,3)**2*p%rho1,idiag_bz2rmz)
        if (idiag_jbmz/=0)   call xysum_mn_name_z(p%jb,idiag_jbmz)
        if (idiag_abmz/=0)   call xysum_mn_name_z(p%ab,idiag_abmz)
        if (idiag_uamz/=0)   call xysum_mn_name_z(p%ua,idiag_uamz)
        if (idiag_etatotalmx/=0) call yzsum_mn_name_x(etatotal,idiag_etatotalmx)
        if (idiag_etatotalmz/=0) call xysum_mn_name_z(etatotal,idiag_etatotalmz)
!
!  Calculate magnetic helicity flux (ExA contribution).
!
        if (idiag_examz1/=0) call xysum_mn_name_z(p%exa(:,1),idiag_examz1)
        if (idiag_examz2/=0) call xysum_mn_name_z(p%exa(:,2),idiag_examz2)
        if (idiag_examz3/=0) call xysum_mn_name_z(p%exa(:,3),idiag_examz3)
!
!  Maxwell stress components.
!
        if (idiag_bxbymy/=0) &
            call xzsum_mn_name_y(p%bbb(:,1)*p%bbb(:,2),idiag_bxbymy)
        if (idiag_bxbzmy/=0) &
            call xzsum_mn_name_y(p%bbb(:,1)*p%bbb(:,3),idiag_bxbzmy)
        if (idiag_bybzmy/=0) &
            call xzsum_mn_name_y(p%bbb(:,2)*p%bbb(:,3),idiag_bybzmy)
        if (idiag_bxbymz/=0) &
            call xysum_mn_name_z(p%bbb(:,1)*p%bbb(:,2),idiag_bxbymz)
        if (idiag_bxbzmz/=0) &
            call xysum_mn_name_z(p%bbb(:,1)*p%bbb(:,3),idiag_bxbzmz)
        if (idiag_bybzmz/=0) &
            call xysum_mn_name_z(p%bbb(:,2)*p%bbb(:,3),idiag_bybzmz)
        if (idiag_jxbrxmx/=0) call yzsum_mn_name_x(p%jxbr(:,1),idiag_jxbrxmx)
        if (idiag_jxbrymx/=0) call yzsum_mn_name_x(p%jxbr(:,2),idiag_jxbrymx)
        if (idiag_jxbrzmx/=0) call yzsum_mn_name_x(p%jxbr(:,3),idiag_jxbrzmx)
        if (idiag_jxbrxmy/=0) call xzsum_mn_name_y(p%jxbr(:,1),idiag_jxbrxmy)
        if (idiag_jxbrymy/=0) call xzsum_mn_name_y(p%jxbr(:,2),idiag_jxbrymy)
        if (idiag_jxbrzmy/=0) call xzsum_mn_name_y(p%jxbr(:,3),idiag_jxbrzmy)
        if (idiag_jxbrxmz/=0) call xysum_mn_name_z(p%jxbr(:,1),idiag_jxbrxmz)
        if (idiag_jxbrymz/=0) call xysum_mn_name_z(p%jxbr(:,2),idiag_jxbrymz)
        if (idiag_jxbrzmz/=0) call xysum_mn_name_z(p%jxbr(:,3),idiag_jxbrzmz)
        if (idiag_b2mz/=0) call xysum_mn_name_z(p%b2,idiag_b2mz)
        if (idiag_b2mr/=0) call phizsum_mn_name_r(p%b2,idiag_b2mr)
        if (idiag_brmr/=0)   &
             call phizsum_mn_name_r(p%bb(:,1)*p%pomx+p%bb(:,2)*p%pomy,idiag_brmr)
        if (idiag_bpmr/=0)   &
             call phizsum_mn_name_r(p%bb(:,1)*p%phix+p%bb(:,2)*p%phiy,idiag_bpmr)
        if (idiag_bzmr/=0)   &
             call phizsum_mn_name_r(p%bb(:,3),idiag_bzmr)
        if (idiag_armr/=0)   &
             call phizsum_mn_name_r(p%aa(:,1)*p%pomx+p%aa(:,2)*p%pomy,idiag_armr)
        if (idiag_apmr/=0)   &
             call phizsum_mn_name_r(p%aa(:,1)*p%phix+p%aa(:,2)*p%phiy,idiag_apmr)
        if (idiag_azmr/=0)   &
             call phizsum_mn_name_r(p%aa(:,3),idiag_azmr)
        if (idiag_mflux_x/=0) &
          call yzintegrate_mn_name_x(p%bb(:,1),idiag_mflux_x)
        if (idiag_mflux_y/=0) &
          call xzintegrate_mn_name_y(p%bb(:,2),idiag_mflux_y)
        if (idiag_mflux_z/=0) &
          call xyintegrate_mn_name_z(p%bb(:,3),idiag_mflux_z)
      endif
!
!  2-D averages.
!  Note that this does not necessarily happen with ldiagnos=.true.
!
      if (l2davgfirst) then
        call phisum_mn_name_rz(p%bb(:,1)*p%pomx+p%bb(:,2)*p%pomy,idiag_brmphi)
        call phisum_mn_name_rz(p%bb(:,1)*p%evr(:,1)+p%bb(:,2)*p%evr(:,2)+ &
                               p%bb(:,3)*p%evr(:,3),idiag_brsphmphi)
        call phisum_mn_name_rz(p%bb(:,1)*p%evth(:,1)+p%bb(:,2)*p%evth(:,2)+ &
                               p%bb(:,3)*p%evth(:,3),idiag_bthmphi)
        call phisum_mn_name_rz(p%bb(:,1)*p%phix+p%bb(:,2)*p%phiy,idiag_bpmphi)
        call phisum_mn_name_rz(p%bb(:,3),idiag_bzmphi)
        call phisum_mn_name_rz(p%b2,idiag_b2mphi)
        if (idiag_jbmphi/=0) call phisum_mn_name_rz(p%jb,idiag_jbmphi)
        if (any((/idiag_uxbrmphi,idiag_uxbpmphi,idiag_uxbzmphi/) /= 0)) then
          call phisum_mn_name_rz(p%uxb(:,1)*p%pomx+p%uxb(:,2)*p%pomy,idiag_uxbrmphi)
          call phisum_mn_name_rz(p%uxb(:,1)*p%phix+p%uxb(:,2)*p%phiy,idiag_uxbpmphi)
          call phisum_mn_name_rz(p%uxb(:,3)                     ,idiag_uxbzmphi)
        endif
        if (any((/idiag_jxbrmphi,idiag_jxbpmphi,idiag_jxbzmphi/) /= 0)) then
          call phisum_mn_name_rz(p%jxb(:,1)*p%pomx+p%jxb(:,2)*p%pomy,idiag_jxbrmphi)
          call phisum_mn_name_rz(p%jxb(:,1)*p%phix+p%jxb(:,2)*p%phiy,idiag_jxbpmphi)
          call phisum_mn_name_rz(p%jxb(:,3)                         ,idiag_jxbzmphi)
        endif
        if (any((/idiag_armphi,idiag_apmphi,idiag_azmphi/) /= 0)) then
          call phisum_mn_name_rz(p%aa(:,1)*p%pomx+p%aa(:,2)*p%pomy,idiag_armphi)
          call phisum_mn_name_rz(p%aa(:,1)*p%phix+p%aa(:,2)*p%phiy,idiag_apmphi)
          call phisum_mn_name_rz(p%aa(:,3)                        ,idiag_azmphi)
        endif
        if (idiag_bxmxy/=0)  call zsum_mn_name_xy(p%bb(:,1),idiag_bxmxy)
        if (idiag_bymxy/=0)  call zsum_mn_name_xy(p%bb(:,2),idiag_bymxy)
        if (idiag_bzmxy/=0)  call zsum_mn_name_xy(p%bb(:,3),idiag_bzmxy)
        if (idiag_jxmxy/=0)  call zsum_mn_name_xy(p%jj(:,1),idiag_jxmxy)
        if (idiag_jymxy/=0)  call zsum_mn_name_xy(p%jj(:,2),idiag_jymxy)
        if (idiag_jzmxy/=0)  call zsum_mn_name_xy(p%jj(:,3),idiag_jzmxy)
        if (idiag_axmxz/=0)  call ysum_mn_name_xz(p%aa(:,1),idiag_axmxz)
        if (idiag_aymxz/=0)  call ysum_mn_name_xz(p%aa(:,2),idiag_aymxz)
        if (idiag_azmxz/=0)  call ysum_mn_name_xz(p%aa(:,3),idiag_azmxz)
        if (idiag_bxmxz/=0)  call ysum_mn_name_xz(p%bb(:,1),idiag_bxmxz)
        if (idiag_bymxz/=0)  call ysum_mn_name_xz(p%bb(:,2),idiag_bymxz)
        if (idiag_bzmxz/=0)  call ysum_mn_name_xz(p%bb(:,3),idiag_bzmxz)
        if (idiag_bx2mxz/=0) call ysum_mn_name_xz(p%bb(:,1)**2,idiag_bx2mxz)
        if (idiag_by2mxz/=0) call ysum_mn_name_xz(p%bb(:,2)**2,idiag_by2mxz)
        if (idiag_bz2mxz/=0) call ysum_mn_name_xz(p%bb(:,3)**2,idiag_bz2mxz)
        if (idiag_bx2mxy/=0) call zsum_mn_name_xy(p%bb(:,1)**2,idiag_bx2mxy)
        if (idiag_by2mxy/=0) call zsum_mn_name_xy(p%bb(:,2)**2,idiag_by2mxy)
        if (idiag_bz2mxy/=0) call zsum_mn_name_xy(p%bb(:,3)**2,idiag_bz2mxy)
        if (idiag_bxbymxy/=0) &
            call zsum_mn_name_xy(p%bb(:,1)*p%bb(:,2),idiag_bxbymxy)
        if (idiag_bxbzmxy/=0) &
            call zsum_mn_name_xy(p%bb(:,1)*p%bb(:,3),idiag_bxbzmxy)
        if (idiag_bybzmxy/=0) &
            call zsum_mn_name_xy(p%bb(:,2)*p%bb(:,3),idiag_bybzmxy)
        if (idiag_bxbymxz/=0) &
            call ysum_mn_name_xz(p%bb(:,1)*p%bb(:,2),idiag_bxbymxz)
        if (idiag_bxbzmxz/=0) &
            call ysum_mn_name_xz(p%bb(:,1)*p%bb(:,3),idiag_bxbzmxz)
        if (idiag_bybzmxz/=0) &
            call ysum_mn_name_xz(p%bb(:,2)*p%bb(:,3),idiag_bybzmxz)
        if (idiag_Exmxz/=0) call ysum_mn_name_xz(p%uxb(:,1),idiag_Exmxz)
        if (idiag_Eymxz/=0) call ysum_mn_name_xz(p%uxb(:,2),idiag_Eymxz)
        if (idiag_Ezmxz/=0) call ysum_mn_name_xz(p%uxb(:,3),idiag_Ezmxz)
      else
!
!  idiag_bxmxy and idiag_bymxy also need to be calculated when
!  ldiagnos and idiag_bmx and/or idiag_bmy, so
!
!  We may need to calculate bxmxy without calculating bmx. The following
!  if condition was messing up calculation of bmxy_rms
!
        if (ldiagnos) then
          if (idiag_bxmxy/=0) call zsum_mn_name_xy(p%bb(:,1),idiag_bxmxy)
          if (idiag_bymxy/=0) call zsum_mn_name_xy(p%bb(:,2),idiag_bymxy)
          if (idiag_bzmxy/=0) call zsum_mn_name_xy(p%bb(:,3),idiag_bzmxy)
          if (idiag_jxmxy/=0) call zsum_mn_name_xy(p%jj(:,1),idiag_jxmxy)
          if (idiag_jymxy/=0) call zsum_mn_name_xy(p%jj(:,2),idiag_jymxy)
          if (idiag_jzmxy/=0) call zsum_mn_name_xy(p%jj(:,3),idiag_jzmxy)
        endif
      endif
!
!  Debug output.
!
      if (headtt .and. lfirst .and. ip<=4) then
        call output_pencil(trim(directory)//'/aa.dat',p%aa,3)
        call output_pencil(trim(directory)//'/bb.dat',p%bb,3)
        call output_pencil(trim(directory)//'/jj.dat',p%jj,3)
        call output_pencil(trim(directory)//'/del2A.dat',p%del2a,3)
        call output_pencil(trim(directory)//'/JxBr.dat',p%jxbr,3)
        call output_pencil(trim(directory)//'/JxB.dat',p%jxb,3)
        call output_pencil(trim(directory)//'/df.dat',df(l1:l2,m,n,:),mvar)
      endif
!
!  Write B-slices for output in wvid in run.f90.
!  Note: ix is the index with respect to array with ghost zones.
!
      if (lvideo.and.lfirst) then
        do j=1,3
          bb_yz(m-m1+1,n-n1+1,j)=p%bb(ix_loc-l1+1,j)
          if (m==iy_loc)  bb_xz(:,n-n1+1,j)=p%bb(:,j)
          if (n==iz_loc)  bb_xy(:,m-m1+1,j)=p%bb(:,j)
          if (n==iz2_loc) bb_xy2(:,m-m1+1,j)=p%bb(:,j)
          if (n==iz3_loc) bb_xy3(:,m-m1+1,j)=p%bb(:,j)
          if (n==iz4_loc) bb_xy4(:,m-m1+1,j)=p%bb(:,j)
        enddo
        do j=1,3
          jj_yz(m-m1+1,n-n1+1,j)=p%jj(ix_loc-l1+1,j)
          if (m==iy_loc)  jj_xz(:,n-n1+1,j)=p%jj(:,j)
          if (n==iz_loc)  jj_xy(:,m-m1+1,j)=p%jj(:,j)
          if (n==iz2_loc) jj_xy2(:,m-m1+1,j)=p%jj(:,j)
          if (n==iz3_loc) jj_xy3(:,m-m1+1,j)=p%jj(:,j)
          if (n==iz4_loc) jj_xy4(:,m-m1+1,j)=p%jj(:,j)
        enddo
        b2_yz(m-m1+1,n-n1+1)=p%b2(ix_loc-l1+1)
        if (m==iy_loc)  b2_xz(:,n-n1+1)=p%b2
        if (n==iz_loc)  b2_xy(:,m-m1+1)=p%b2
        if (n==iz2_loc) b2_xy2(:,m-m1+1)=p%b2
        if (n==iz3_loc) b2_xy3(:,m-m1+1)=p%b2
        if (n==iz4_loc) b2_xy4(:,m-m1+1)=p%b2
        jb_yz(m-m1+1,n-n1+1)=p%jb(ix_loc-l1+1)
        if (m==iy_loc)  jb_xz(:,n-n1+1)=p%jb
        if (n==iz_loc)  jb_xy(:,m-m1+1)=p%jb
        if (n==iz2_loc) jb_xy2(:,m-m1+1)=p%jb
        if (n==iz3_loc) jb_xy3(:,m-m1+1)=p%jb
        if (n==iz4_loc) jb_xy4(:,m-m1+1)=p%jb
        beta_yz(m-m1+1,n-n1+1)=p%beta(ix_loc-l1+1)
        if (m==iy_loc)  beta_xz(:,n-n1+1)=p%beta
        if (n==iz_loc)  beta_xy(:,m-m1+1)=p%beta
        if (n==iz2_loc) beta_xy2(:,m-m1+1)=p%beta
        if (n==iz3_loc) beta_xy3(:,m-m1+1)=p%beta
        if (n==iz4_loc) beta_xy4(:,m-m1+1)=p%beta
        if (bthresh_per_brms/=0) call calc_bthresh
        call vecout(41,trim(directory)//'/bvec',p%bb,bthresh,nbvec)
      endif
      call timing('daa_dt','finished',mnloop=.true.)
!
    endsubroutine daa_dt
!***********************************************************************
    subroutine time_integrals_magnetic(f,p)
!
!  Calculate time_integrals within each pencil (as long as each
!  pencil case p still contains the current data). This routine
!  is now being called at the end of equ.
!
!  28-jun-07/axel+mreinhard: coded
!  24-jun-08/axel: moved call to this routine to the individual pde routines
!   1-jul-08/axel: moved this part to magnetic
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(inout) :: f
      intent(in) :: p
!
      if (ibbt/=0) f(l1:l2,m,n,ibxt:ibzt)=f(l1:l2,m,n,ibxt:ibzt)+dt*p%bb
      if (ijjt/=0) f(l1:l2,m,n,ijxt:ijzt)=f(l1:l2,m,n,ijxt:ijzt)+dt*p%jj
!
    endsubroutine time_integrals_magnetic
!***********************************************************************
    subroutine df_diagnos_magnetic(df,p)
!
!  calculate diagnostics that involves df
!  Here we calculate <du/dt x b> and <u x db/dt>.
!  The latter is calculated as <divu dai/dt> -  <uji daj/dt>
!  This is used in dynamo theory for checking the minimal tau approximation.
!
!  10-oct-06/axel: coded
!
      use Diagnostics, only: sum_mn_name
      use Sub
!
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      real, dimension (nx,3) :: uudot,aadot,udotxb,B1_gradu
      real, dimension (nx) :: B1dot_udotxb,B1dot_uxbdot,B1dot_aadot,uxbdot2
!
      intent(in)  :: df, p
!
!  this routine is only called when ldiagnos=T
!  start with <du/dt x b>
!
      if (idiag_udotxbm/=0) then
        uudot=df(l1:l2,m,n,iux:iuz)
        call cross_mn(uudot,p%bb,udotxb)
        call dot_mn_sv(B1_ext,udotxb,B1dot_udotxb)
        call sum_mn_name(B1dot_udotxb,idiag_udotxbm)
      endif
!
!  next, do <divu dai/dt> -  <uji daj/dt>
!
      if (idiag_uxbdotm/=0) then
        aadot=df(l1:l2,m,n,iax:iaz)
        call dot_mn_sv(B1_ext,aadot,B1dot_aadot)
        call dot_mn_sm(B1_ext,p%uij,B1_gradu)
        call dot_mn(B1_gradu,aadot,uxbdot2)
        B1dot_uxbdot=p%divu*B1dot_aadot-uxbdot2
        call sum_mn_name(B1dot_uxbdot,idiag_uxbdotm)
      endif
!
    endsubroutine df_diagnos_magnetic
!***********************************************************************
    subroutine magnetic_after_boundary(f)
!
!  Calculate <A>, which is needed for test-field methods.
!
!   2-jan-10/axel: adapted from hydro_after_boundary
!
      use Mpicomm, only: mpiallreduce_sum
      use Deriv, only: der_z,der2_z
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: nxy=nxgrid*nygrid
      integer :: n,j
      real :: fact
      real, dimension (mz,3) :: aamz1_tmp
      real, dimension (nz,3) :: gaamz,d2aamz
!
      intent(inout) :: f
!
!  Compute mean field for each component. Include the ghost zones,
!  because they have just been set.
!
      if (lcalc_aamean) then
        fact=1./nxy
        do j=1,3
          do n=1,mz
            aamz(n,j)=fact*sum(f(l1:l2,m1:m2,n,iax+j-1))
          enddo
        enddo
!
!  communication over all processors in the xy plane
!
        if (nprocx>1.or.nprocy>1) then
          call mpiallreduce_sum(aamz,aamz1_tmp,(/mz,3/),idir=12)
          aamz=aamz1_tmp
        endif
!
!  Compute first and second derivatives.
!
        do j=1,3
          call der_z(aamz(:,j),gaamz(:,j))
          call der2_z(aamz(:,j),d2aamz(:,j))
        enddo
!
!  Compute mean magnetic field and current density.
!
        bbmz(:,1)=-gaamz(:,2)
        bbmz(:,2)=+gaamz(:,1)
        bbmz(:,3)=0.
        jjmz(:,1)=-d2aamz(:,1)
        jjmz(:,2)=-d2aamz(:,2)
        jjmz(:,3)=0.
      endif
!
    endsubroutine magnetic_after_boundary
!***********************************************************************
    subroutine set_border_magnetic(f,df,p)
!
!  Calculates the driving term for the border profile
!  of the aa variable.
!
!  28-jul-06/wlad: coded
!
      use BorderProfiles, only: border_driving,set_border_initcond
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: f_target
      integer :: ju,j
!
!  select for different target profiles
!
      select case (borderaa)
!
      case ('zero','0')
        f_target=0.
!
      case ('initial-condition')
        do j=1,3
          ju=j+iaa-1
          call set_border_initcond(f,ju,f_target(:,j))
        enddo
!
      case ('nothing')
        if (lroot.and.ip<=5) &
             print*,"set_border_magnetic: borderaa='nothing'"
!
      case default
        write(unit=errormsg,fmt=*) &
             'set_border_magnetic: No such value for borderaa: ', &
             trim(borderaa)
        call fatal_error('set_border_magnetic',errormsg)
      endselect
!
!  apply border profile
!
      if (borderaa /= 'nothing') then
        do j=1,3
          ju=j+iaa-1
          call border_driving(f,df,p,f_target(:,j),ju)
        enddo
      endif
!
    endsubroutine set_border_magnetic
!***********************************************************************
    subroutine eta_shell(p,eta_mn,geta)
!
!  24-nov-03/dave: coded
!  23-jun-09/axel: generalized to lcylinder_in_a_box
!
      use Sub, only: step, der_step
      use Mpicomm, only: stop_it
!
      type (pencil_case) :: p
      real, dimension (nx) :: eta_mn
      real, dimension (nx) :: prof,eta_r
      real, dimension (nx,3) :: geta
      real :: d_int,d_ext
!
      eta_r=0.
!
      if (eta_int > 0.) then
        d_int = eta_int - eta
      else
        d_int = 0.
      endif
      if (eta_ext > 0.) then
        d_ext = eta_ext - eta
      else
        d_ext = 0.
      endif
!
!  calculate steps in resistivity
!  make this dependent on the geometry used
!
!  (i) lcylinder_in_a_box
!
      if (lcylinder_in_a_box.or.lcylindrical_coords) then
        prof=step(p%rcyl_mn,r_int,wresistivity)
        eta_mn=d_int*(1-prof)
        prof=step(p%rcyl_mn,r_ext,wresistivity)
        eta_mn=eta+eta_mn+d_ext*prof
!
!     calculate radial derivative of steps and gradient of eta
!
        prof=der_step(p%rcyl_mn,r_int,wresistivity)
        eta_r=-d_int*prof
        prof=der_step(p%rcyl_mn,r_ext,wresistivity)
        eta_r=eta_r+d_ext*prof
        geta=p%evr*spread(eta_r,2,3)
!
!  (ii) lsphere_in_a_box
!
      elseif (lsphere_in_a_box.or.lspherical_coords) then
        prof=step(p%r_mn,r_int,wresistivity)
        eta_mn=d_int*(1-prof)
        prof=step(p%r_mn,r_ext,wresistivity)
        eta_mn=eta+eta_mn+d_ext*prof
!
!     calculate radial derivative of steps and gradient of eta
!
        prof=der_step(p%r_mn,r_int,wresistivity)
        eta_r=-d_int*prof
        prof=der_step(p%r_mn,r_ext,wresistivity)
        eta_r=eta_r+d_ext*prof
        geta=p%evr*spread(eta_r,2,3)
!
!  (iii) other cases are not implemented yet
!
      else
        call stop_it("eta_shell works only for spheres or cylinders")
      endif
!
    endsubroutine eta_shell
!***********************************************************************
    subroutine calc_bthresh()
!
!  calculate bthresh from brms, give warnings if there are problems
!
!   6-aug-03/axel: coded
!
!  give warning if brms is not set in prints.in
!
      if (idiag_brms==0) then
        if (lroot.and.lfirstpoint) then
          print*,'calc_bthresh: need to set brms in print.in to get bthresh'
        endif
      endif
!
!  if nvec exceeds nbvecmax (=1/4) of points per processor, then begin to
!  increase scaling factor on bthresh. These settings will stay in place
!  until the next restart
!
      if (nbvec>nbvecmax.and.lfirstpoint) then
        print*,'calc_bthresh: processor ',iproc,': bthresh_scl,nbvec,nbvecmax=', &
                                                   bthresh_scl,nbvec,nbvecmax
        bthresh_scl=bthresh_scl*1.2
      endif
!
!  calculate bthresh as a certain fraction of brms
!
      bthresh=bthresh_scl*bthresh_per_brms*brms
!
    endsubroutine calc_bthresh
!***********************************************************************
    subroutine rescaling_magnetic(f)
!
!  Rescale magnetic field by factor rescale_aa,
!
!  22-feb-05/axel: coded
!  10-feb-09/petri: adapted from testfield
!
      use Sub, only: update_snaptime, read_snaptime
!
      real, dimension (mx,my,mz,mfarray) :: f
      character (len=fnlen) :: file
      logical :: lmagnetic_out
      integer,save :: ifirst=0
!
      intent(inout) :: f
!
!  Reinitialize aa periodically if requested
!
      if (lreset_aa) then
        file=trim(datadir)//'/treset_aa.dat'
        if (ifirst==0) then
          call read_snaptime(trim(file),taareset,naareset,daareset,t)
          if (taareset==0 .or. taareset < t-daareset) then
            taareset=t+daareset
          endif
          ifirst=1
        endif
!
!  Rescale when the time has come
!  (Note that lmagnetic_out and ch are not used here)
!
        if (t >= taareset) then
          f(:,:,:,iax:iaz)=rescale_aa*f(:,:,:,iax:iaz)
          call update_snaptime(file,taareset,naareset,daareset,t,lmagnetic_out)
        endif
      endif
!
    endsubroutine rescaling_magnetic
!***********************************************************************
    subroutine calc_tau_aa_exterior(f,df)
!
!  magnetic field relaxation to zero on time scale tau_aa_exterior within
!  exterior region. For the time being this means z > zgrav.
!
!  29-jul-02/axel: coded
!
      use Gravity, only: zgrav
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real :: scl
      integer :: j
!
      intent(in) :: f
      intent(inout) :: df
!
      if (headtt) print*,'calc_tau_aa_exterior: tau=',tau_aa_exterior
      if (z(n)>zgrav) then
        scl=1./tau_aa_exterior
        do j=iax,iaz
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-scl*f(l1:l2,m,n,j)
        enddo
      endif
!
    endsubroutine calc_tau_aa_exterior
!***********************************************************************
    subroutine sine_avoid_boundary(ampl,f,kr,r0,rn)
!
! Sine field in cylindrical coordinates, used in Armitage 1998
!
!   Bz=B0/r * sin(kr*(r-r0))
!
! And 0 outside of the interval r0-rn
! Code the field and find Aphi through solving the
! tridiagonal system for
!
!  Bz= d/dr Aphi + Aphi/r
!
!  -A_(i-1) + A_(i+1) + 2*A_i*dr/r = 2*dr*Bz
!
!  05-apr-08/wlad : coded
!
      use General, only: tridag
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kr,r0,rn
      integer :: i
      real, dimension (mx) :: a_tri,b_tri,c_tri,rhs,aphi,bz
!
      if (.not.lcylindrical_coords) &
           call stop_it("this IC assumes cylindrical coordinates")
!
      do i=1,mx
        if ((rcyl_mn(i)>=r0).and.(rcyl_mn(i)<=rn)) then
          bz(i)=ampl/rcyl_mn(i) * sin(kr*(rcyl_mn(i)-r0))
        else
          bz(i)=0.
        endif
      enddo
!
      a_tri=-1.
      b_tri=2*dx/x
      c_tri=1.
      rhs=bz*2*dx
!
      a_tri(1) =0.;c_tri(1 )=0.
      a_tri(mx)=0.;c_tri(mx)=0.
!
      call tridag(a_tri,b_tri,c_tri,rhs,aphi)
!
      do m=1,my
      do n=1,mz
        f(:,m,n,iay) = aphi
      enddo
      enddo
!
    endsubroutine sine_avoid_boundary
!***********************************************************************
    subroutine helflux(aa,uxb,jj)
!
!  magnetic helicity flux (preliminary)
!
!  14-aug-03/axel: coded
!
      use Diagnostics
!
      real, dimension (nx,3), intent(in) :: aa,uxb,jj
      real, dimension (nx,3) :: ee
      real, dimension (nx) :: FHx,FHz
      real :: FH
!
      ee=eta*jj-uxb
!
!  calculate magnetic helicity flux in the X and Z directions
!
      FHx=-2*ee(:,3)*aa(:,2)*dsurfyz
      FHz=+2*ee(:,1)*aa(:,2)*dsurfxy
!
!  sum up contribution per pencil
!  and then stuff result into surf_mn_name for summing up all processors.
!
      FH=FHx(nx)-FHx(1)
      if (lfirst_proc_z .and.n==n1) FH=FH-sum(FHz)
      if (llast_proc_z.and.n==n2) FH=FH+sum(FHz)
      call surf_mn_name(FH,idiag_exaym2)
!
    endsubroutine helflux
!***********************************************************************
    subroutine curflux_dS(uxb,jj)
!
!  current helicity flux (preliminary)
!
!  27-nov-03/axel: adapted from helflux
!
      use Diagnostics
!
      real, dimension (nx,3), intent(in) :: uxb,jj
      real, dimension (nx,3) :: ee
      real, dimension (nx) :: FCx,FCz
      real :: FC
!
      ee=eta*jj-uxb
!
!  calculate current helicity flux in the X and Z directions
!  Could speed up by only calculating here boundary points!
!
      FCx=2*(ee(:,2)*jj(:,3)-ee(:,3)*jj(:,2))*dsurfyz
      FCz=2*(ee(:,1)*jj(:,2)-ee(:,2)*jj(:,1))*dsurfxy
!
!  sum up contribution per pencil
!  and then stuff result into surf_mn_name for summing up all processors.
!
      FC=FCx(nx)-FCx(1)
      if (lfirst_proc_z .and.n==n1) FC=FC-sum(FCz)
      if (llast_proc_z.and.n==n2) FC=FC+sum(FCz)
      call surf_mn_name(FC,idiag_exjm2)
!
    endsubroutine curflux_dS
!***********************************************************************
    subroutine curflux(uxb,jj)
!
!  current helicity flux (preliminary)
!
!  27-nov-03/axel: adapted from helflux
!
      use Diagnostics
!
      real, dimension (nx,3), intent(in) :: uxb,jj
      real, dimension (nx,3) :: ee
      real, dimension (nx) :: FCz
!
      ee=eta*jj-uxb
!
!  calculate current helicity flux in the Z direction
!  exj = e1*j2 - e2*j1
!
      FCz=2*(ee(:,1)*jj(:,2)-ee(:,2)*jj(:,1))
      call sum_mn_name(FCz,idiag_exjm2)
!
    endsubroutine curflux
!***********************************************************************
    subroutine read_magnetic_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=magnetic_init_pars, IOSTAT=iostat)
!
!  read namelist for mean-field theory (if invoked)
!
      if (lmeanfield_theory) call read_magnetic_mf_init_pars(iostat)
!
    endsubroutine read_magnetic_init_pars
!***********************************************************************
    subroutine write_magnetic_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=magnetic_init_pars)
!
!  write namelist for mean-field theory (if invoked)
!
      if (lmeanfield_theory) call write_magnetic_mf_init_pars(unit)
!
    endsubroutine write_magnetic_init_pars
!***********************************************************************
    subroutine read_magnetic_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=magnetic_run_pars, IOSTAT=iostat)
!
!  read namelist for mean-field theory (if invoked)
!
      if (lmeanfield_theory) call read_magnetic_mf_run_pars(iostat)
!
    endsubroutine read_magnetic_run_pars
!***********************************************************************
    subroutine write_magnetic_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=magnetic_run_pars)
!
!  write namelist for mean-field theory (if invoked)
!
      if (lmeanfield_theory) call write_magnetic_mf_run_pars(unit)
!
    endsubroutine write_magnetic_run_pars
!***********************************************************************
    subroutine forcing_continuous(df,p)
!
!  add a continuous forcing term (here currently only for localized rotors)
!
!  21-jan-07/axel: adapted from hydro
!  24-feb-09/axel: calls to this routine are now replaced by adding p$fcont
!
      use Diagnostics
      use Mpicomm, only: mpibcast_real
      use Sub
!
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: forcing_rhs
      real, dimension (nx) :: jf,phi
      real, dimension (mx), save :: phix,sinx,cosx
      real, dimension (my), save :: phiy,siny,cosy
      real, dimension (mz), save :: phiz,sinz,cosz
      real, save :: phase_beltrami_before
      real, save :: R2,R12
      type (pencil_case) :: p
      integer, save :: ifirst
      integer :: j,jfff,ifff
      real :: fact
!
!  at the first step, the sin and cos functions are calculated for all
!  x,y,z points and are then saved and used for all subsequent steps
!  and pencils
!
      if (ip<=6) print*,'forcing_continuous: ifirst=',ifirst
      if (ifirst==0) then
        if (iforcing_continuous_aa=='fixed_swirl') then
          if (lroot) print*,'forcing_continuous: fixed_swirl; swirl=',swirl
          R2=radius**2
          R12=1./R2
          phix=exp(-R12*x**2)
          phiy=exp(-R12*y**2)
          phiz=exp(-R12*z**2)
        elseif (iforcing_continuous_aa=='cosxcosz') then
          cosx=cos(k1x_ff*x)
          cosz=cos(k1z_ff*z)
        elseif (iforcing_continuous_aa=='RobertsFlow') then
          if (lroot) print*,'forcing_continuous: RobertsFlow'
          sinx=sin(k1_ff*x); cosx=cos(k1_ff*x)
          siny=sin(k1_ff*y); cosy=cos(k1_ff*y)
        elseif (iforcing_continuous_aa=='Beltrami-z') then
          if (lroot) print*,'forcing_continuous: Beltrami-z'
          ampl_beltrami=ampl_ff
          sinz=sin(k1_ff*z+phase_beltrami)
          cosz=cos(k1_ff*z+phase_beltrami)
        endif
      endif
      ifirst=ifirst+1
      if (ip<=6) print*,'forcing_continuous: dt, ifirst=',dt,ifirst
!
!  at the first meshpoint, and if phase_beltrami is finite,
!  recalculate sinz and cosz for the phase correction of an
!  imposed Beltrami field.
!
      if (lfirstpoint) then
        if (iforcing_continuous_aa=='Beltrami-z') then
          if (phase_beltrami/=phase_beltrami_before) then
            phase_beltrami_before=phase_beltrami
            sinz=sin(k1_ff*z+phase_beltrami)
            cosz=cos(k1_ff*z+phase_beltrami)
          endif
        endif
      endif
!
!  calculate forcing
!
      if (iforcing_continuous_aa=='fixed_swirl') then
        fact=ampl_ff
        phi=2.*R12*fact*phix(l1:l2)*phiy(m)*phiz(n)
        forcing_rhs(:,1)=(-swirl*y(m    )+2.*x(l1:l2)*z(n))*phi
        forcing_rhs(:,2)=(+swirl*x(l1:l2)+2.*y(m    )*z(n))*phi
        forcing_rhs(:,3)=(R2-x(l1:l2)**2-y(m)**2)*2.*R12*phi
      elseif (iforcing_continuous_aa=='cosxcosz') then
        fact=ampl_ff
        forcing_rhs(:,1)=0.
        forcing_rhs(:,2)=fact*cosx(l1:l2)*cosz(n)
        forcing_rhs(:,3)=0.
      elseif (iforcing_continuous_aa=='RobertsFlow') then
        fact=ampl_ff
        forcing_rhs(:,1)=-fact*cosx(l1:l2)*siny(m)
        forcing_rhs(:,2)=+fact*sinx(l1:l2)*cosy(m)
        forcing_rhs(:,3)=+fact*cosx(l1:l2)*cosy(m)*sqrt(2.)
      elseif (iforcing_continuous_aa=='Beltrami-z') then
        fact=-eta*k1_ff*ampl_beltrami
        forcing_rhs(:,1)=fact*cosz(n)
        forcing_rhs(:,2)=fact*sinz(n)
        forcing_rhs(:,3)=0.
      endif
!
!  apply forcing in uncurled induction equation
!
      ifff=iax
      do j=1,3
        jfff=j+ifff-1
        df(l1:l2,m,n,jfff)=df(l1:l2,m,n,jfff)+forcing_rhs(:,j)
      enddo
!
!  diagnostics
!
      if (ldiagnos) then
        if (idiag_jfm/=0) then
          call dot_mn(p%jj,forcing_rhs,jf)
          call sum_mn_name(jf,idiag_jfm)
        endif
      endif
!
    endsubroutine forcing_continuous
!***********************************************************************
    subroutine get_slices_magnetic(f,slices)
!
!  Write slices for animation of Magnetic variables.
!
!  26-jul-06/tony: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
!  Loop over slices
!
      select case (trim(slices%name))
!
!  Magnetic vector potential (code variable)
!
        case ('aa')
          if (slices%index>=3) then
            slices%ready=.false.
          else
            slices%index=slices%index+1
            slices%yz =f(ix_loc,m1:m2 ,n1:n2  ,iax-1+slices%index)
            slices%xz =f(l1:l2 ,iy_loc,n1:n2  ,iax-1+slices%index)
            slices%xy =f(l1:l2 ,m1:m2 ,iz_loc ,iax-1+slices%index)
            slices%xy2=f(l1:l2 ,m1:m2 ,iz2_loc,iax-1+slices%index)
            if (lwrite_slice_xy3) &
                 slices%xy3=f(l1:l2,m1:m2,iz3_loc,iax-1+slices%index)
            if (lwrite_slice_xy4) &
                 slices%xy4=f(l1:l2,m1:m2,iz4_loc,iax-1+slices%index)
            if (slices%index<=3) slices%ready=.true.
          endif
!
!  Magnetic field (derived variable)
!
        case ('bb')
          if (slices%index>=3) then
            slices%ready=.false.
          else
            slices%index=slices%index+1
            slices%yz =>bb_yz(:,:,slices%index)
            slices%xz =>bb_xz(:,:,slices%index)
            slices%xy =>bb_xy(:,:,slices%index)
            slices%xy2=>bb_xy2(:,:,slices%index)
            if (lwrite_slice_xy3) slices%xy3=>bb_xy3(:,:,slices%index)
            if (lwrite_slice_xy4) slices%xy4=>bb_xy4(:,:,slices%index)
            if (slices%index<=3) slices%ready=.true.
          endif
!
!  Current density (derived variable)
!
        case ('jj')
          if (slices%index>=3) then
            slices%ready=.false.
          else
            slices%index=slices%index+1
            slices%yz =>jj_yz(:,:,slices%index)
            slices%xz =>jj_xz(:,:,slices%index)
            slices%xy =>jj_xy(:,:,slices%index)
            slices%xy2=>jj_xy2(:,:,slices%index)
            if (lwrite_slice_xy3) slices%xy3=>jj_xy3(:,:,slices%index)
            if (lwrite_slice_xy4) slices%xy4=>jj_xy4(:,:,slices%index)
            if (slices%index<=3) slices%ready=.true.
          endif
!
!  Magnetic field squared (derived variable)
!
        case ('b2')
          slices%yz =>b2_yz
          slices%xz =>b2_xz
          slices%xy =>b2_xy
          slices%xy2=>b2_xy2
          if (lwrite_slice_xy3) slices%xy3=>b2_xy3
          if (lwrite_slice_xy4) slices%xy4=>b2_xy4
          slices%ready=.true.
!
!  Current density (derived variable)
!
        case ('jb')
          slices%yz =>jb_yz
          slices%xz =>jb_xz
          slices%xy =>jb_xy
          slices%xy2=>jb_xy2
          if (lwrite_slice_xy3) slices%xy3=>jb_xy3
          if (lwrite_slice_xy4) slices%xy4=>jb_xy4
          slices%ready=.true.
!
!  Plasma beta
!
       case ('beta')
          slices%yz =>beta_yz
          slices%xz =>beta_xz
          slices%xy =>beta_xy
          slices%xy2=>beta_xy2
          if (lwrite_slice_xy3) slices%xy3=>beta_xy3
          if (lwrite_slice_xy4) slices%xy4=>beta_xy4
          slices%ready=.true.
!
      endselect
!
    endsubroutine get_slices_magnetic
!***********************************************************************
    subroutine calc_mfield
!
!  calculate mean magnetic field from xy- or z-averages
!
!  19-jun-02/axel: moved from print to here
!   9-nov-02/axel: corrected bxmy(m,j); it used bzmy instead!
!
      use Mpicomm
      use Sub
!
!  For vector output (of bb vectors) we need brms
!  on all processors. It suffices to have this for times when lout=.true.,
!  but we need to broadcast the result to all procs.
!
!  calculate brms (this requires that brms is set in print.in)
!  broadcast result to other processors
!
      if (idiag_brms/=0) then
        if (iproc==0) brms=fname(idiag_brms)
        call mpibcast_real(brms)
      endif
!
!  The following calculation involving spatial averages
!
      if (idiag_bmx/=0) call calc_bmx
      if (idiag_bmy/=0) call calc_bmy
      if (idiag_bmz/=0) call calc_bmz
      if (idiag_bmzS2/=0) call calc_bmzS2
      if (idiag_bmzA2/=0) call calc_bmzA2
      if (idiag_jmx/=0) call calc_jmx
      if (idiag_jmy/=0) call calc_jmy
      if (idiag_jmz/=0) call calc_jmz
      if (idiag_emxamz3/=0) call calc_emxamz3
      if (idiag_embmz/=0) call calc_embmz
      if (idiag_ambmz/=0) call calc_ambmz
      if (idiag_ambmzh/=0) call calc_ambmzh
      if (idiag_jmbmz/=0.or.idiag_kmz/=0) call calc_jmbmz
      if (idiag_bmxy_rms/=0) call calc_bmxy_rms
      if (idiag_bmzph/=0) call calc_bmz_beltrami_phase
!
!  Set the phase of the Beltrami forcing equal to the actual phase
!  of the magnetic field (times forcing_continuous_aa_phasefact).
!  Broadcast the result to other processors.
!
      phase_beltrami=forcing_continuous_aa_phasefact*bmz_beltrami_phase
      call mpibcast_real(phase_beltrami)
!
!  set amplitude to ampl_ff minus a correction term that is
!  proportional to the actual field minus the target field strength,
!  scaled by some forcing_continuous_aa_amplfact, and broadcast, ie
!  A = Atarget - factor*(Aactual-Atarget).
!
      ampl_beltrami=ampl_ff-forcing_continuous_aa_amplfact*(bmz-ampl_ff)
      call mpibcast_real(ampl_beltrami)
!
    endsubroutine calc_mfield
!***********************************************************************
    subroutine calc_bmx
!
!  Magnetic energy in the yz-averaged field. The bymxy and bzmxy must have
!  been calculated, so they are present on the z-root processors.
!
!   6-apr-08/axel: moved from calc_mfield to here
!  26-aug-09/anders: used mpireduce_sum to remove need for nyproc arrays
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real, dimension(nx) :: bymx, bzmx, bmx2
      real, dimension(nx,ny) :: fsumxy
      real :: bmx
!
!  This only works if bymxy and bzmxy are in zaver, so print warning if this is
!  not ok.
!
      if (idiag_bymxy==0.or.idiag_bzmxy==0) then
        if (first) then
          print*, 'calc_mfield: WARNING'
          print*, 'NOTE: to get bmx, set bymxy and bzmxy in zaver'
          print*, 'We proceed, but you will get bmx=0'
        endif
        bmx2=0.0
      else
        if (lfirst_proc_z) then
          call mpireduce_sum(fnamexy(:,:,idiag_bymxy),fsumxy,(/nx,ny/),idir=2)
          bymx=sum(fsumxy,dim=2)/nygrid
          call mpireduce_sum(fnamexy(:,:,idiag_bzmxy),fsumxy,(/nx,ny/),idir=2)
          bzmx=sum(fsumxy,dim=2)/nygrid
        endif
        if (lfirst_proc_yz) then
          call mpireduce_sum(bymx**2+bzmx**2,bmx2,nx,idir=1)
        endif
      endif
!
!  Save the name in the idiag_bmx slot and set first to false.
!  Compute final result only on the root processor.
!
      if (lroot) then
        bmx=sqrt(sum(bmx2)/nxgrid)
        call save_name(bmx,idiag_bmx)
      endif
      first=.false.
!
    endsubroutine calc_bmx
!***********************************************************************
    subroutine calc_bmy
!
!  Magnetic energy in the xz-averaged field. The bxmxy and bzmxy must have
!  been calculated, so they are present on the z-root processors.
!
!   6-apr-08/axel: moved from calc_mfield to here
!  26-aug-09/axel: adapted change of Anders to used mpireduce_sum
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real, dimension(ny) :: bxmy, bzmy, bmy2
      real, dimension(nx,ny) :: fsumxy
      real :: bmy
!
!  This only works if bxmxy and bzmxy are in zaver, so print warning if this is
!  not ok.
!
      if (idiag_bxmxy==0.or.idiag_bzmxy==0) then
        if (first) then
          print*, 'calc_mfield: WARNING'
          print*, 'NOTE: to get bmy, set bxmxy and bzmxy in zaver'
          print*, 'We proceed, but you will get bmy=0'
        endif
        bmy2=0.0
      else
        if (lfirst_proc_z) then
          call mpireduce_sum(fnamexy(:,:,idiag_bxmxy),fsumxy,(/nx,ny/),idir=1)
          bxmy=sum(fsumxy,dim=1)/nxgrid
          call mpireduce_sum(fnamexy(:,:,idiag_bzmxy),fsumxy,(/nx,ny/),idir=1)
          bzmy=sum(fsumxy,dim=1)/nxgrid
        endif
        if (lfirst_proc_xz) then
          call mpireduce_sum(bxmy**2+bzmy**2,bmy2,ny,idir=2)
        endif
      endif
!
!  Save the name in the idiag_bmy slot and set first to false.
!  Compute final result only on the root processor.
!
      if (lroot) then
        bmy=sqrt(sum(bmy2)/nygrid)
        call save_name(bmy,idiag_bmy)
      endif
      first=.false.
!
    endsubroutine calc_bmy
!***********************************************************************
    subroutine calc_bmzS2
!
!  Magnetic energy in anisymmetric part of the horizontally averaged field.
!  The bxmz and bymz must have been calculated, and present on root processor.
!
!   8-mar-10/axel: adapted from bmz
!
      use Diagnostics, only: save_name
!
      logical,save :: first=.true.
      integer :: n_reverse,ipz_reverse
      real :: bxmS,bymS
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_bxmz==0.or.idiag_bymz==0) then
        if (first) then
          print*, 'calc_mfield: WARNING'
          print*, 'NOTE: to get bmzS2, set bxmz and bymz in xyaver'
          print*, 'We proceed, but you will get bmzS2=0'
        endif
        bxmS=0.
        bymS=0.
      else
        bxmS=0.
        bymS=0.
        do n=1,nz
          n_reverse=nz-n+1
          ipz_reverse=ipz !(for now)
          bxmS=bxmS+fnamez(n,ipz+1,idiag_bxmz)+fnamez(n_reverse,ipz_reverse+1,idiag_bxmz)
          bymS=bymS+fnamez(n,ipz+1,idiag_bymz)+fnamez(n_reverse,ipz_reverse+1,idiag_bymz)
        enddo
      endif
!
!  Save the name in the idiag_bmzS slot and set first to false.
!
      call save_name((bxmS**2+bymS**2)/nz**2,idiag_bmzS2)
      first=.false.
!
    endsubroutine calc_bmzS2
!***********************************************************************
    subroutine calc_bmzA2
!
!  Magnetic energy in anisymmetric part of the horizontally averaged field.
!  The bxmz and bymz must have been calculated, and present on root processor.
!
!   8-mar-10/axel: adapted from bmz
!
      use Diagnostics, only: save_name
!
      logical,save :: first=.true.
      integer :: n_reverse,ipz_reverse
      real :: bxmA,bymA
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_bxmz==0.or.idiag_bymz==0) then
        if (first) then
          print*, 'calc_mfield: WARNING'
          print*, 'NOTE: to get bmzA2, set bxmz and bymz in xyaver'
          print*, 'We proceed, but you will get bmzA2=0'
        endif
        bxmA=0.
        bymA=0.
      else
        bxmA=0.
        bymA=0.
        do n=1,nz
          n_reverse=nz-n+1
          ipz_reverse=ipz !(for now)
          bxmA=bxmA+fnamez(n,ipz+1,idiag_bxmz)-fnamez(n_reverse,ipz_reverse+1,idiag_bxmz)
          bymA=bymA+fnamez(n,ipz+1,idiag_bymz)-fnamez(n_reverse,ipz_reverse+1,idiag_bymz)
        enddo
      endif
!
!  Save the name in the idiag_bmzA slot and set first to false.
!
      call save_name((bxmA**2+bymA**2)/nz**2,idiag_bmzA2)
      first=.false.
!
    endsubroutine calc_bmzA2
!***********************************************************************
    subroutine calc_bmz
!
!  Magnetic energy in horizontally averaged field. The bxmz and bymz must have
!  been calculated, so they are present on the root processor.
!
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_bxmz==0.or.idiag_bymz==0) then
        if (first) then
          print*, 'calc_mfield: WARNING'
          print*, 'NOTE: to get bmz, set bxmz and bymz in xyaver'
          print*, 'We proceed, but you will get bmz=0'
        endif
        bmz=0.0
      else
        bmz=sqrt(sum(fnamez(:,:,idiag_bxmz)**2 &
                    +fnamez(:,:,idiag_bymz)**2)/(nz*nprocz))
      endif
!
!  Save the name in the idiag_bmz slot and set first to false.
!
      call save_name(bmz,idiag_bmz)
      first=.false.
!
    endsubroutine calc_bmz
!***********************************************************************
    subroutine calc_jmx
!
!  Magnetic energy in the yz-averaged field. The jymxy and jzmxy must have
!  been calculated, so they are present on the z-root processors.
!
!   6-apr-08/axel: moved from calc_mfield to here
!  28-feb-10/axel: final jmx can only be computed on root processor
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real, dimension(nx) :: jymx,jzmx,jmx2
      real, dimension(nx,ny) :: fsumxy
      real :: jmx
!
!  This only works if jymxy and jzmxy are in zaver, so print warning if this is
!  not ok.
!
      if (idiag_jymxy==0.or.idiag_jzmxy==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get jmx, set jymxy and jzmxy in zaver"
          print*,"We proceed, jut you'll get jmx=0"
        endif
        jmx2=0.
      else
        if (lfirst_proc_z) then
          call mpireduce_sum(fnamexy(:,:,idiag_jymxy),fsumxy,(/nx,ny/),idir=2)
          jymx=sum(fsumxy,dim=2)/nygrid
          call mpireduce_sum(fnamexy(:,:,idiag_jzmxy),fsumxy,(/nx,ny/),idir=2)
          jzmx=sum(fsumxy,dim=2)/nygrid
        endif
        if (lfirst_proc_yz) then
          call mpireduce_sum(jymx**2+jzmx**2,jmx2,nx,idir=1)
        endif
      endif
!
!  Save the name in the idiag_jmx slot and set first to false.
!  Compute final result only on the root processor.
!
      if (lroot) then
        jmx=sqrt(sum(jmx2)/nxgrid)
        call save_name(jmx,idiag_jmx)
      endif
      first=.false.
!
    endsubroutine calc_jmx
!***********************************************************************
    subroutine calc_jmy
!
!  Magnetic energy in the xz-averaged field. The jxmxy and jzmxy must have
!  been calculated, so they are present on the z-root processors.
!
!   6-apr-08/axel: moved from calc_mfield to here
!  28-feb-10/axel: final jmy can only be computed on root processor
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real, dimension(ny) :: jxmy,jzmy,jmy2
      real, dimension(nx,ny) :: fsumxy
      real :: jmy
!
!  This only works if jxmxy and jzmxy are in zaver, so print warning if this is
!  not ok.
!
      if (idiag_jxmxy==0.or.idiag_jzmxy==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get jmy, set jxmxy and jzmxy in zaver"
          print*,"We proceed, but you'll get jmy=0"
        endif
        jmy2=0.
      else
        if (lfirst_proc_z) then
          call mpireduce_sum(fnamexy(:,:,idiag_jxmxy),fsumxy,(/nx,ny/),idir=1)
          jxmy=sum(fsumxy,dim=1)/nxgrid
          call mpireduce_sum(fnamexy(:,:,idiag_jzmxy),fsumxy,(/nx,ny/),idir=1)
          jzmy=sum(fsumxy,dim=1)/nxgrid
        endif
        if (lfirst_proc_xz) then
          call mpireduce_sum(jxmy**2+jzmy**2,jmy2,ny,idir=2)
        endif
      endif
!
!  Save the name in the idiag_jmy slot and set first to false.
!  Compute final result only on the root processor.
!
      if (lroot) then
        jmy=sqrt(sum(jmy2)/nygrid)
        call save_name(jmy,idiag_jmy)
      endif
      first=.false.
!
    endsubroutine calc_jmy
!***********************************************************************
    subroutine calc_jmz
!
!  Magnetic energy in horizontally averaged field. The jxmz and jymz must have
!  been calculated, so they are present on the root processor.
!
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: jmz
!
!  This only works if jxmz and jzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_jxmz==0.or.idiag_jymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get jmz, set jxmz and jymz in xyaver"
          print*,"We proceed, but you'll get jmz=0"
        endif
        jmz=0.
      else
        jmz=sqrt(sum(fnamez(:,:,idiag_jxmz)**2 &
                    +fnamez(:,:,idiag_jymz)**2)/(nz*nprocz))
      endif
!
!  Save the name in the idiag_jmz slot and set first to false.
!
      if (lroot) call save_name(jmz,idiag_jmz)
      first=.false.
!
    endsubroutine calc_jmz
!***********************************************************************
    subroutine calc_embmz
!
!  Magnetic helicity production of mean field. The bxmz and bymz as well as Exmz
!  and Eymz must have been calculated, so they are present on the root
!  processor.
!
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: embmz
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_Exmz==0.or.idiag_Eymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get embmz, set bxmz, bymz, Exmz, and Eymz in xyaver"
          print*,"We proceed, but you'll get embmz=0"
        endif
        embmz=0.
      else
        embmz=sum(fnamez(:,:,idiag_bxmz)*fnamez(:,:,idiag_Exmz) &
                 +fnamez(:,:,idiag_bymz)*fnamez(:,:,idiag_Eymz))/(nz*nprocz)
      endif
!
!  Save the name in the idiag_embmz slot and set first to false.
!
      if (lroot) call save_name(embmz,idiag_embmz)
      first=.false.
!
    endsubroutine calc_embmz
!***********************************************************************
    subroutine calc_emxamz3
!
!  Volume average of magnetic helicity flux of the mean field. The axmz and
!  aymz as well as Exmz and Eymz must have been calculated, so they are present
!  on the root processor.
!
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: emxamz3
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_Exmz==0.or.idiag_Eymz==0.or. &
          idiag_axmz==0.or.idiag_aymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get emxamz3, set axmz, aymz, Exmz, and Eymz in xyaver"
          print*,"We proceed, but you'll get emxamz3=0"
        endif
        emxamz3=0.
      else
        emxamz3=sum(fnamez(:,:,idiag_Exmz)*fnamez(:,:,idiag_aymz) &
                   -fnamez(:,:,idiag_Eymz)*fnamez(:,:,idiag_axmz))/(nz*nprocz)
      endif
!
!  Save the name in the idiag_emxamz3 slot and set first to false.
!
      if (lroot) call save_name(emxamz3,idiag_emxamz3)
      first=.false.
!
    endsubroutine calc_emxamz3
!***********************************************************************
    subroutine calc_ambmz
!
!  Magnetic helicity of the xy-averaged mean field. The bxmz and bymz as well as
!  axmz and aymz must have been calculated, so they are present on the root
!  processor.
!
!  16-may-09/axel: adapted from calc_jmbmz
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: ambmz
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_axmz==0.or.idiag_aymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get ambmz, set bxmz, bymz, axmz, and aymz in xyaver"
          print*,"We proceed, but you'll get ambmz=0"
        endif
        ambmz=0.
      else
        ambmz=sum(fnamez(:,:,idiag_bxmz)*fnamez(:,:,idiag_axmz) &
                 +fnamez(:,:,idiag_bymz)*fnamez(:,:,idiag_aymz))/(nz*nprocz)
      endif
!
!  Save the name in the idiag_ambmz slot and set first to false.
!
      if (lroot) call save_name(ambmz,idiag_ambmz)
      first=.false.
!
    endsubroutine calc_ambmz
!***********************************************************************
    subroutine calc_ambmzh
!
!  Hemispheric magnetic helicity of the xy-averaged mean field. The bxmz and
!  bymz as well as axmz and aymz must have been calculated, so they are present
!  on the root processor.
!
!  16-may-09/axel: adapted from calc_ambmz
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real, dimension(2) :: ambmzh
      real :: ambmz_tmp,fact
      integer :: iprocz
!
!  initialize ambmzh to zero each time, because its two elements
!  are integration counters. If idiag_axmz etc are not set, the
!  routine escapes, but even then it needs to be initialized.
!
      ambmzh=0.
!
!  This only works if bxmz and bzmz are in xyaver,
!  so print warning if this is not ok.
!  Loop over all processors, but don't use (overwrite) ipz for that
!
      if (idiag_axmz==0.or.idiag_aymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get ambmzh, set bxmz, bymz, axmz, and aymz in xyaver"
          print*,"We proceed, but you'll get ambmzh=0"
        endif
      else
        fact=1./(nz*nprocz)
        do n=1,nz
        do iprocz=1,nprocz
          ambmz_tmp=fact*( &
             fnamez(n,iprocz,idiag_bxmz)*fnamez(n,iprocz,idiag_axmz)&
            +fnamez(n,iprocz,idiag_bymz)*fnamez(n,iprocz,idiag_aymz))
          if (z_allprocs(n,iprocz)>=zequator) then
            ambmzh(2)=ambmzh(2)+ambmz_tmp
          else
            ambmzh(1)=ambmzh(1)+ambmz_tmp
          endif
        enddo
        enddo
      endif
!
!  North means 1 and south means 2.
!  save the name in the idiag_ambmz slot
!  and set first to false
!
      if (lroot) call save_name_halfz(ambmzh,idiag_ambmzh)
      fname(idiag_ambmzn)=fname_half(idiag_ambmzh,1)
      fname(idiag_ambmzs)=fname_half(idiag_ambmzh,2)
      itype_name(idiag_ambmzn)=ilabel_save
      itype_name(idiag_ambmzs)=ilabel_save
      first=.false.
!
    endsubroutine calc_ambmzh
!***********************************************************************
    subroutine calc_jmbmz
!
!  Current helicity of the xy-averaged mean field
!  The bxmz and bymz as well as jxmz and jymz must have been calculated,
!  so they are present on the root processor.
!
!  21-apr-08/axel: adapted from calc_embmz
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: jmbmz
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
      if (idiag_jxmz==0.or.idiag_jymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get jmbmz, set bxmz, bymz, jxmz, and jymz in xyaver"
          print*,"We proceed, but you'll get jmbmz=0"
        endif
        jmbmz=0.
      else
        jmbmz=sum(fnamez(:,:,idiag_bxmz)*fnamez(:,:,idiag_jxmz) &
                 +fnamez(:,:,idiag_bymz)*fnamez(:,:,idiag_jymz))/(nz*nprocz)
      endif
!
!  Save the name in the idiag_jmbmz slot and set first to false.
!
      if (lroot) then
        if (idiag_jmbmz/=0) call save_name(jmbmz,idiag_jmbmz)
        if (idiag_kmz/=0) call save_name(jmbmz/bmz**2,idiag_kmz)
      endif
      first=.false.
!
    endsubroutine calc_jmbmz
!***********************************************************************
    subroutine calc_bmxy_rms
!
!  Magnetic energy in z averaged field. The bxmxy, bymxy and bzmxy must have
!  been calculated, so they are present on the root processor.
!
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real,dimension(2) :: b2mxy_local,b2mxy
      real :: bmxy_rms,nVol2d_local,btemp
      integer :: l
!
!  This only works if bxmz and bzmz are in xyaver, so print warning if this is
!  not ok.
!
! stop if this routine is called in cylindrical
      if (lcylindrical_coords) &
             call stop_it("bmxy_rms not yet implemented for cylindrical")
! The following calculation is done only for ipz=0
      bmxy_rms=0
      if (.not.lfirst_proc_z) return
      if (idiag_bxmxy==0.or.idiag_bymxy==0.or.idiag_bzmxy==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"NOTE: to get bmxy_rms, set bxmxy, bymxy and bzmxy in zaver"
          print*,"We proceed, but you'll get bmxy_rms=0"
        endif
        bmxy_rms=0.
      else
!DM: we dont really need the following if, I am going to test
!        if (lfirst_proc_z) then
          b2mxy_local=0
          do l=1,nx
            do m=1,ny
              btemp=fnamexy(l,m,idiag_bxmxy)**2 +&
                    fnamexy(l,m,idiag_bymxy)**2 +&
                    fnamexy(l,m,idiag_bzmxy)**2
              if (lspherical_coords) then
                 btemp=btemp*r2_weight(l)*sinth_weight(m)
                 nvol2d_local=r2_weight(l)*sinth_weight(m)
              endif
              b2mxy_local(1)=b2mxy_local(1)+btemp
              b2mxy_local(2)=b2mxy_local(2)+nVol2d_local
            enddo
          enddo
          call mpireduce_sum(b2mxy_local(:),b2mxy,2,idir=2)
!        endif
        if (lfirst_proc_x) then
          if (lcartesian_coords) bmxy_rms=sqrt(b2mxy(1)/(nxgrid*nygrid))
          if (lspherical_coords) bmxy_rms=sqrt(b2mxy(1)/b2mxy(2))
        endif
      endif
!
!  Save the name in the idiag_bmxy_rms slot and set first to false.
!
      call save_name(bmxy_rms,idiag_bmxy_rms)
      first=.false.
!
    endsubroutine calc_bmxy_rms
!***********************************************************************
    subroutine calc_bmz_beltrami_phase
!
!  The following is useful if the xy-averaged field is a Beltrami field
!  Determine its phase as in B ~ [ cos(kz+phi), sin(kz+phi), 0 ].
!  This means that for positive phi the wave is shifted to the left.
!
!  bxmz, bymz must have been calculated,
!  so they are present on the root processor.
!
!   2-apr-08/MR: introduced phase calculation for Beltrami mean fields
!   6-apr-08/axel: moved from calc_mfield to here
!
      use Diagnostics
      use Mpicomm
!
      logical,save :: first=.true.
      real :: bmz_belphase1,bmz_belphase2
      real, dimension (nz,nprocz), save :: sinz,cosz
      real ::  c, s
      integer :: jprocz
!
      if (first) then
        sinz=sin(k1_ff*z_allprocs); cosz=cos(k1_ff*z_allprocs)
      endif
!
!  print warning if bxmz and bymz are not calculated
!
      if (idiag_bxmz==0.or.idiag_bymz==0) then
        if (first) then
          print*,"calc_mfield: WARNING"
          print*,"to get bmz_beltrami_phase, set bxmz, bymz in zaver"
          print*,"We proceed, but you'll get Beltrami phase bmzpb=0"
        endif
        bmz_beltrami_phase=0.
!
!  add up c = <B_x> cos(kz) and s = <B_x> sin(kz)
!  and determine phase of Beltrami field from <B_x>
!
      else
        c=0.; s=0.
        do jprocz=1,nprocz
          c=c+dot_product(fnamez(:,jprocz,idiag_bxmz),cosz(:,jprocz))
          s=s+dot_product(fnamez(:,jprocz,idiag_bxmz),sinz(:,jprocz))
        enddo
        bmz_belphase1=atan2(-s,c)
!
!  add up c = <B_y> cos(kz) and s = <B_y> sin(kz)
!  and determine phase of Beltrami field from <B_y>
!
        c=0.; s=0.
        do jprocz=1,nprocz
          c=c+dot_product(fnamez(:,jprocz,idiag_bymz),cosz(:,jprocz))
          s=s+dot_product(fnamez(:,jprocz,idiag_bymz),sinz(:,jprocz))
        enddo
        bmz_belphase2=atan2(c,s)
!
!  Difference of both determinations (to estimate error)
!  and take the mean of both calculations (called bmz_beltrami_phase
!  and bmzph in the print.in file, for brevity)
!
        bmz_beltrami_phase=.5*(bmz_belphase1+bmz_belphase2)
      endif
!
!  Save the name in the idiag_bmzph slot; as estimate of the error,
!  calculate also the difference between the two.
!  Finally, set first to false
!
      call save_name(bmz_beltrami_phase,idiag_bmzph)
      if (idiag_bmzphe/=0) &
          call save_name(abs(bmz_belphase1-bmz_belphase2),idiag_bmzphe)
      first=.false.
!
    endsubroutine calc_bmz_beltrami_phase
!***********************************************************************
    subroutine alfven_x(ampl,f,iuu,iaa,ilnrho,kx)
!
!  Alfven wave propagating in the x-direction
!
!  ux = +sink(x-vA*t)
!  Az = -cosk(x-vA*t)*sqrt(rho*mu0)/k
!
!  Alfven and slow magnetosonic are the same here and both incompressible, and
!  a fast magnetosonic (compressible) wave is also excited, but decoupled.
!
!  satisfies the four equations
!  dlnrho/dt = -ux'
!  dux/dt = -cs2*(lnrho)'
!  duy/dt = B0*By'  ==>  duy/dt = -B0*Az''
!  dBy/dt = B0*uy'  ==>  dAz/dt = -B0*ux
!
!   8-nov-03/axel: coded
!  29-apr-03/axel: added sqrt(rho*mu0)/k factor
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx) :: rho,ampl_Az
      real :: ampl,kx,ampl_lr,ampl_ux,ampl_uy
      integer :: iuu,iaa,ilnrho
!
!  Amplitude factors
!
      ampl_lr=+0.
      ampl_ux=+0.
      ampl_uy=+ampl
!
!  ux and Ay.
!  Don't overwrite the density, just add to the log of it.
!
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,ilnrho)=ampl_lr*(sin(kx*x(l1:l2))+f(l1:l2,m,n,ilnrho))
        f(l1:l2,m,n,iuu+0 )=ampl_ux*sin(kx*x(l1:l2))
        f(l1:l2,m,n,iuu+1 )=ampl_uy*sin(kx*x(l1:l2))
        rho=exp(f(l1:l2,m,n,ilnrho))
        ampl_Az=-ampl*sqrt(rho*mu0)/kx
        f(l1:l2,m,n,iaa+2 )=ampl_Az*cos(kx*x(l1:l2))
      enddo; enddo
!
    endsubroutine alfven_x
!***********************************************************************
    subroutine alfven_y(ampl,f,iuu,iaa,ky,mu0)
!
!  Alfven wave propagating in the y-direction; can be used in 2-d runs.
!  ux = cos(ky-ot), for B0y=1 and rho=1.
!  Az = sin(ky-ot), ie Bx=-cos(ky-ot)
!
!  [wd nov-2006: There should be a 1/ky in the aa term here and in
!  alfven_x, I think]
!
!  satisfies the equations
!  dux/dt = Bx'  ==>  dux/dt = -Az''
!  dBx/dt = ux'  ==>  dAz/dt = -ux.
!
!  06-dec-06/wolf: adapted from alfven_z
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,ky,mu0
      integer :: iuu,iaa
!
!  ux and Az
!
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+0) = +ampl*cos(ky*y(m))
        f(l1:l2,m,n,iaa+2) = -ampl*sin(ky*y(m))*sqrt(mu0)/ky
      enddo; enddo
!
    endsubroutine alfven_y
!***********************************************************************
    subroutine alfven_z(ampl,f,iuu,iaa,kz,mu0)
!
!  Alfven wave propagating in the z-direction
!  ux = cos(kz-ot), for B0z=1 and rho=1.
!  Ay = sin(kz-ot), ie Bx=-cos(kz-ot)
!
!  satisfies the equations
!  dux/dt = Bx'  ==>  dux/dt = -Ay''
!  dBx/dt = ux'  ==>  dAy/dt = -ux.
!
!  18-aug-02/axel: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kz,mu0
      integer :: iuu,iaa
!
!  ux and Ay
!
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+0)=+ampl*cos(kz*z(n))
        f(l1:l2,m,n,iaa+1)=+ampl*sin(kz*z(n))*sqrt(mu0)
      enddo; enddo
!
    endsubroutine alfven_z
!***********************************************************************
    subroutine alfven_xy(ampl,f,iuu,iaa,kx,ky)
!
!  Alfven wave propagating in the xy-direction; can be used in 2-d runs.
!  uz = cos(kx*x+ky*y-ot), for B0=(1,1,0) and rho=1.
!  Ax = sin(kx*x+ky*y-ot),
!  Ay = sin(kx*x+ky*y-ot),
!
!  16-jun-07/axel: adapted from alfven_y
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kx,ky,om
      real, parameter :: mu0=1.
      integer :: iuu,iaa
!
!  set ux, Ax, and Ay
!
      om=B_ext(1)*kx+B_ext(2)*ky
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+2)=+ampl*cos(kx*x(l1:l2)+ky*y(m))
        f(l1:l2,m,n,iaa+0)=+ampl*sin(kx*x(l1:l2)+ky*y(m))*sqrt(mu0)/om*B_ext(2)
        f(l1:l2,m,n,iaa+1)=-ampl*sin(kx*x(l1:l2)+ky*y(m))*sqrt(mu0)/om*B_ext(1)
      enddo; enddo
!
    endsubroutine alfven_xy
!***********************************************************************
    subroutine alfven_xz(ampl,f,iuu,iaa,kx,kz)
!
!  Alfven wave propagating in the xz-direction; can be used in 2-d runs.
!  uz = cos(kx*x+kz*z-ot), for B0=(1,1,0) and rho=1.
!  Ax = sin(kx*x+kz*z-ot),
!  Az = sin(kx*x+kz*z-ot),
!
!  16-jun-07/axel: adapted from alfven_xy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kx,kz,om
      real, parameter :: mu0=1.
      integer :: iuu,iaa
!
!  set ux, Ax, and Az
!
      om=B_ext(1)*kx+B_ext(3)*kz
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+2)=+ampl*cos(kx*x(l1:l2)+kz*z(n))
        f(l1:l2,m,n,iaa+0)=+ampl*sin(kx*x(l1:l2)+kz*z(n))*sqrt(mu0)/om*B_ext(2)
        f(l1:l2,m,n,iaa+2)=-ampl*sin(kx*x(l1:l2)+kz*z(n))*sqrt(mu0)/om*B_ext(1)
      enddo; enddo
!
    endsubroutine alfven_xz
!***********************************************************************
    subroutine alfven_rphi(B0,f,mode)
!
!  Alfven wave propagating on radial direction with
!  field pointing to the phi direction.
!
!  Bphi = B0 cos(k r) ==> Az = -1/k B0 sin(k r)
!
!  04-oct-06/wlad: coded
!
      real, dimension(mx,my,mz,mfarray) :: f
      real :: B0,mode
!
      real, dimension(nx) :: rrcyl
      real :: kr
!
      do n=n1,n2; do m=m1,m2
        kr = 2*pi*mode/(r_ext-r_int)
        rrcyl = sqrt(x(l1:l2)**2 + y(m)**2)
        f(l1:l2,m,n,iaz) =  -B0/kr*sin(kr*(rrcyl-r_int))
      enddo; enddo
!
    endsubroutine alfven_rphi
!***********************************************************************
    subroutine alfven_zconst(f)
!
!  Radially variable field pointing in the z direction
!  4 Balbus-Hawley wavelengths in the vertical direction
!
!  Bz=Lz/(8pi)*Omega      ==> Aphi = Lz/(8pi) Omega*r/(2-q)
!
!  The smoothed case should be general, since it reduces
!  to the non-smoothed for r0_pot=0.
!
!  B=C*(r2+r02)^-q ==> Aphi=C/(r*(2-q))*(r2+r02)^(1-q/2)
!
!  04-oct-06/wlad: coded
!
      use Gravity, only: qgshear,r0_pot
      use SharedVariables
      use Mpicomm, only: stop_it
!
      real, dimension(mx,my,mz,mfarray) :: f
!
      real, dimension(nx) :: Aphi, rr
      real, pointer :: plaw
      real :: B0,pblaw
      integer :: ierr
!
      if (lcartesian_coords) then
        B0=Lxyz(3)/(2*zmode*pi)
        do n=n1,n2; do m=m1,m2
          rr=sqrt(x(l1:l2)**2+y(m)**2)
          Aphi=B0/(rr*(2-qgshear))*(rr**2+r0_pot**2)**(1-qgshear/2.)
          f(l1:l2,m,n,iax) =  -Aphi*y(m)/rr
          f(l1:l2,m,n,iay) =   Aphi*x(l1:l2)/rr
        enddo; enddo
      elseif (lcylindrical_coords) then
        call stop_it("alfven_zconst: "//&
            "not implemented for cylindrical coordinates")
      elseif (lspherical_coords) then
        B0=Lxyz(2)/(2*zmode*pi)
        call get_shared_variable('plaw',plaw,ierr)
        if (ierr/=0) call stop_it("alfven_zconst: "//&
            "there was a problem when getting plaw")
        pblaw=1-qgshear-plaw/2.
        do n=n1,n2; do m=m1,m2
          rr=x(l1:l2)
          Aphi=-B0/(pblaw+2)*rr**(pblaw+1)*1
          f(l1:l2,m,n,iax)=0.
          f(l1:l2,m,n,iay)=0.
          f(l1:l2,m,n,iaz)=Aphi/sin(y(m))
        enddo; enddo
!
        call correct_lorentz_force(f,.true.,B0,pblaw)
!
      endif
!
    endsubroutine alfven_zconst
!***********************************************************************
    subroutine alfven_rz(B0,f,mode)
!
!  Alfven wave propagating on radial direction with
!  field pointing to the z direction.
!
!  Bz = B0 cos(k r) ==> Aphi = B0/k sin(k r) + B0/(k2*r)*cos(k r)
!
!  04-oct-06/wlad: coded
!
      use Mpicomm, only: stop_it
!
      real :: B0,mode
      real, dimension(mx,my,mz,mfarray) :: f
!
      real :: kr,k1,const
      real, dimension(nx) :: rrcyl,Aphi
!
      if (headtt) print*,'radial alfven wave propagating on z direction'
      if (.not.lcylinder_in_a_box) &
           call stop_it("alfven_rz, this initial condition works only for embedded cylinders")
!
! Choose between cases. The non-smoothed case is singular in r=0 for the potential, thus
! can only be used if freezing is used with a non-zero r_int. The smoothed case
! has a linear component that prevents singularities and a exponential that prevents
! the field from growing large in the outer disk
!
      do n=n1,n2; do m=m1,m2
        rrcyl = max(sqrt(x(l1:l2)**2 + y(m)**2),tini)
        if (r_int>0.) then
           if (lroot .and. m==m1 .and. n==n1) then
             print*,'freezing is being used, ok to use singular potentials'
             print*,'Bz=B0cos(k.r) ==> Aphi=B0/k*sin(k.r)+B0/(k^2*r)*cos(k r)'
           endif
           kr = 2*pi*mode/(r_ext-r_int)
           Aphi =  B0/kr * sin(kr*(rrcyl-r_int)) + &
                B0/(kr**2*rrcyl)*cos(kr*(rrcyl-r_int))
        else
           if (lroot .and. m==m1 .and. n==n1) print*,'Softened magnetic field in the center'
           if (mode < 5) call stop_it("put more wavelengths in the field")
           kr = 2*pi*mode/r_ext
           k1 = 1. !not tested for other values
           const=B0*exp(1.)*k1/cos(kr/k1)
           Aphi=const/kr*rrcyl*exp(-k1*rrcyl)*sin(kr*rrcyl)
        endif
!
        f(l1:l2,m,n,iax) = Aphi * (-    y(m)/rrcyl)
        f(l1:l2,m,n,iay) = Aphi * ( x(l1:l2)/rrcyl)
!
      enddo; enddo
!
    endsubroutine alfven_rz
!***********************************************************************
    subroutine alfvenz_rot(ampl,f,iuu,iaa,kz,O)
!
!  Alfven wave propagating in the z-direction (with Coriolis force)
!  ux = cos(kz-ot), for B0z=1 and rho=1.
!  Ay = sin(kz-ot), ie Bx=-cos(kz-ot)
!
!  satisfies the equations
!  dux/dt - 2Omega*uy = -Ay''
!  duy/dt + 2Omega*ux = +Ax''
!  dAx/dt = +uy
!  dAy/dt = -ux
!
!  18-aug-02/axel: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kz,O,fac
      integer :: iuu,iaa
!
!  ux, uy, Ax and Ay
!
      if (lroot) print*,'alfvenz_rot: Alfven wave with rotation; O,kz=',O,kz
      fac=-O+sqrt(O**2+kz**2)
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+0)=-ampl*sin(kz*z(n))*fac/kz
        f(l1:l2,m,n,iuu+1)=-ampl*cos(kz*z(n))*fac/kz
        f(l1:l2,m,n,iaa+0)=+ampl*sin(kz*z(n))/kz
        f(l1:l2,m,n,iaa+1)=+ampl*cos(kz*z(n))/kz
      enddo; enddo
!
    endsubroutine alfvenz_rot
!***********************************************************************
    subroutine alfvenz_rot_shear(ampl,f,iuu,iaa,kz,OO)
!
!  Alfven wave propagating in the z-direction (with Coriolis force and shear)
!
!  satisfies the equations
!  dux/dt - 2*Omega*uy = -Ay''
!  duy/dt + (2-q)*Omega*ux = +Ax''
!  dAx/dt = q*Omega*Ay + uy
!  dAy/dt = -ux
!
!  Assume B0=rho0=mu0=1
!
!  28-june-04/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real :: ampl,kz,OO
      complex :: fac
      integer :: iuu,iaa
!
!  ux, uy, Ax and Ay
!
      if (lroot) print*,'alfvenz_rot_shear: '// &
          'Alfven wave with rotation and shear; OO,kz=',OO,kz
      fac=cmplx(OO-sqrt(16*kz**2+OO**2),0.)
      do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,iuu+0)=f(l1:l2,m,n,iuu+0)+ampl*fac/(4*kz)*sin(kz*z(n))
        f(l1:l2,m,n,iuu+1)=f(l1:l2,m,n,iuu+1)+ampl*real(exp(cmplx(0,z(n)*kz))* &
            fac*sqrt(2*kz**2+OO*fac)/(sqrt(2.)*kz*(-6*OO-fac)))
        f(l1:l2,m,n,iaa+0)=ampl*sin(kz*z(n))/kz
        f(l1:l2,m,n,iaa+1)=-ampl*2*sqrt(2.)*aimag(exp(cmplx(0,z(n)*kz))* &
            sqrt(2*kz**2+OO*fac)/(-6*OO-fac)/(cmplx(0,kz)))
      enddo; enddo
!
    endsubroutine alfvenz_rot_shear
!***********************************************************************
    subroutine torus_test(ampl,f)
!
!  Initial field concentrated along torus well inside the computational
!  domain.
!  Implements the same field for cartesian and spherical cordinates.
!  The field is of mixed parity (bb_pol symmetric, bb_tor antisymmetric)
!  and the relative contributions of toroidal and poloidal field are
!  determined by
!    ampl(1) -- bb_pol (through aa_tor)
!    ampl(3) -- bb_tor (through aa_pol)
!  Uses x_max as reference radius.
!
!   05-may-2008/wolf: coded
!
      real :: ampl
      real, dimension (mx,my,mz,mfarray) :: f
!
      real, dimension (nx) :: xxi2,ee
      real, dimension (nx) :: costh,sinth,cosphi,sinphi,ss,rr,aar,aap
      real :: radius,width,r_cent
!
      intent(in)    :: ampl
      intent(inout) :: f
!
      radius = xyz1(1)
      width  = 0.1*radius
      r_cent = 0.6*radius
!
      if (lspherical_coords) then
        do n=n1,n2; do m=m1,m2
          xxi2 = (x(l1:l2)*sin(y(m))-r_cent)**2 + x(l1:l2)**2*cos(y(m))**2
          ee = ampl * exp(-0.5 * xxi2 / width**2)
          f(l1:l2,m,n,iax) = f(l1:l2,m,n,iax) + ee * x(l1:l2)*cos(y(m))
          f(l1:l2,m,n,iaz) = f(l1:l2,m,n,iaz) + ee
        enddo; enddo
      else
        do n=n1,n2; do m=m1,m2
          xxi2 = (sqrt(x(l1:l2)**2+y(m)**2) - r_cent)**2 + z(n)**2
          ee = ampl * exp(-0.5 * xxi2 / width**2)
          aar = z(n) * ee
          aap = ee
          ss = sqrt(x(l1:l2)**2+y(m)**2)
          rr = sqrt(x(l1:l2)**2+y(m)**2+z(n)**2)
          ss = max(ss, tini)
          rr = max(rr, tini)
          costh = z(n)/rr
          sinth = ss/rr
          cosphi   = x(l1:l2)/ss
          sinphi   = y(m)/ss
          f(l1:l2,m,n,iax) = f(l1:l2,m,n,iax) + aar*sinth*cosphi - aap*sinphi
          f(l1:l2,m,n,iay) = f(l1:l2,m,n,iay) + aar*sinth*sinphi + aap*cosphi
          f(l1:l2,m,n,iaz) = f(l1:l2,m,n,iaz) + aar*costh
        enddo; enddo
      endif
!
    endsubroutine torus_test
!***********************************************************************
    subroutine force_free_jet(mu)
!
!  Force free magnetic field configuration for jet simulations
!  with a fixed accretion disc at the bottom boundary.
!
!  The input parameter mu specifies the radial dependency of
!  the magnetic field in the disc.
!
!  Solves the laplace equation in cylindrical coordinates for the
!  phi-component of the vector potential. A_r and A_z are taken to
!  be zero.
!
!    nabla**2 A_phi - A_phi / r**2 = 0
!
!  For the desired boundary condition in the accretion disc
!
!    B_r=B0*r**(mu-1)  (z == 0)
!
!  the solution is
!
!    A_phi = Hypergeometric2F1( (1-mu)/2, (2+mu)/2, 2, xi**2 )
!            *xi*(r**2+z**2)**(mu/2)
!
!  where xi = sqrt(r**2/(r**2+z**2))
!
!  30-may-04/tobi: coded
!
      use Sub, only: hypergeometric2F1,gamma_function
      use Deriv, only: der
      use IO, only: output
!
      real, intent(in) :: mu
      real :: xi2,A_phi
      real :: r2
      real :: B1r_,B1z_,B1
      real, parameter :: tol=10*epsilon(1.0)
      integer :: l
      real, dimension(mx,my,mz) :: Ax_ext,Ay_ext
      !real, dimension(nx,3) :: bb_ext_pot
      !real, dimension(nx) :: bb_x,bb_y,bb_z
!
!  calculate un-normalized |B| at r=r_ref and z=0 for later normalization
!
      if (lroot.and.ip<=5) print*,'FORCE_FREE_JET: calculating normalization'
!
      B1r_=sin(pi*mu/2)*gamma_function(   abs(mu) /2) / &
                        gamma_function((1+abs(mu))/2)
!
      B1z_=cos(pi*mu/2)*gamma_function((1+abs(mu))/2) / &
                        gamma_function((2+abs(mu))/2)
!
      B1=sqrt(4/pi)*r_ref**(mu-1)*sqrt(B1r_**2+B1z_**2)
!
!  calculate external vector potential
!
      if (lroot) print*,'FORCE_FREE_JET: calculating external vector potential'
!
      if (lforce_free_test) then
!
        if (lroot) print*,'FORCE_FREE_JET: using analytic solution for mu=-1'
        do l=1,mx; do m=1,my; do n=1,mz
          Ax_ext=-2*y(m)*(1-z(n)/sqrt(x(l)**2+y(m)**2+z(n)**2))/(x(l)**2+y(m)**2)/B1
          Ay_ext= 2*x(l)*(1-z(n)/sqrt(x(l)**2+y(m)**2+z(n)**2))/(x(l)**2+y(m)**2)/B1
        enddo; enddo; enddo
!
      else
!
        do l=1,mx; do m=1,my; do n=1,mz
          r2=x(l)**2+y(m)**2
          xi2=r2/(r2+z(n)**2)
          A_phi=hypergeometric2F1((1-mu)/2,(2+mu)/2,2.0,xi2,tol) &
               *sqrt(xi2)*sqrt(r2+z(n)**2)**mu/B1
!
          Ax_ext(l,m,n)=-y(m)*A_phi/sqrt(r2)
          Ay_ext(l,m,n)= x(l)*A_phi/sqrt(r2)
        enddo; enddo; enddo
!
      endif
!
!  calculate external magnetic field
!
      if (lroot.and.ip<=5) &
        print*,'FORCE_FREE_JET: calculating the external magnetic field'
!
      do n=n1,n2
      do m=m1,m2
!        call der(Ay_ext,bb_x,3)
!        bb_ext_pot(:,1)=-bb_x
!        call der(Ax_ext,bb_y,3)
!        bb_ext_pot(:,2)= bb_y
!        call der(Ay_ext,bb_z,1)
!        bb_ext_pot(:,3)= bb_z
!        call der(Ax_ext,bb_z,2)
!        bb_ext_pot(:,3)=bb_ext_pot(:,3)-bb_z
!        call set_global(bb_ext_pot,m,n,'B_ext_pot',nx)
      enddo
      enddo
!
      if (ip<=5) then
        call output(trim(directory)//'/Ax_ext.dat',Ax_ext,1)
        call output(trim(directory)//'/Ay_ext.dat',Ay_ext,1)
      endif
!
    endsubroutine force_free_jet
!***********************************************************************
    subroutine piecew_dipole_aa(ampl,inclaa,f,ivar)
!
!  A field that is vertical uniform for r<R_int, inclined dipolar for
!  r>R_ext, and potential in the shell R_int<r<R_ext.
!  This mimics a neutron star just after the Meissner effect forced the
!  internal field to become vertical (aligned with rotation axis).
!
!  AMPL represents mu/4 pi, where  mu = 1/2 Int rr jj dV  is the
!  magnetic moment of the external dipole field.
!  INCLAA is the inclination of the dipolar field.
!
!  Pencilized in order to minimize memory consumption with all the
!  auxiliary variables used.
!
!  23-jul-05/wolf:coded
!
      real, intent(inout), dimension (mx,my,mz,mfarray) :: f
      real, intent(in) :: ampl,inclaa
      real, dimension (nx) :: r_1_mn,r_2_mn,sigma0,sigma1, r_mn
      real :: fact
      real, dimension(2) :: beta(0:1)
      real, dimension(2,3) :: a(0:1,1:3),b(0:1,1:3)
      integer :: ivar
!
      do imn=1,ny*nz
        n=nn(imn)
        m=mm(imn)
        r_mn=sqrt(x(l1:l2)**2+y(m)**2+z(n)**2)
        r_1_mn = 1./max(r_mn,tini)
        r_2_mn = 1./max(r_mn**2,tini)
!
        fact = ampl
        ! beta = [beta_1^0, beta_1^1] combines coefficients for m=0, m=1
        beta =  fact * (/ cos(inclaa), -sin(inclaa)/sqrt(2.) /)
        ! a and b for m=0, m=1 (index 1) and interior, shell, exterior index 2)
        a(0,:) = (/ 1./r_ext**3, 1./r_ext**3                  , 0. /) * beta(0)
        a(1,:) = (/ 0.         , 1./(r_ext**3-r_int**3)       , 0. /) * beta(1)
        !
        b(0,:) = (/ 0.         , 0.                           , 1. /) * beta(0)
        b(1,:) = (/ 0.         , -r_int**3/(r_ext**3-r_int**3), 1. /) * beta(1)
        !
        ! The following could be coded much clearer using elsewhere, but
        ! that is not in F90 (and pgf90 doesn't support F95)
        ! r_in < r < r_ext
        sigma0 = a(0,2)*r_mn + b(0,2)*r_2_mn
        sigma1 = a(1,2)*r_mn + b(1,2)*r_2_mn
        where(r_mn>r_ext) ! r > r_ext
          sigma0 = a(0,3)*r_mn + b(0,3)*r_2_mn
          sigma1 = a(1,3)*r_mn + b(1,3)*r_2_mn
        endwhere
        where(r_mn<r_int) ! r < r_int
          sigma0 = a(0,1)*r_mn + b(0,1)*r_2_mn
          sigma1 = a(1,1)*r_mn + b(1,1)*r_2_mn
        endwhere
        sigma1 = sigma1*sqrt(2.)
        f(l1:l2,m,n,ivar+0) = -sigma0*y(m)*r_1_mn
        f(l1:l2,m,n,ivar+1) =  sigma0*x(l1:l2)*r_1_mn + sigma1*z(n)*r_1_mn
        f(l1:l2,m,n,ivar+2) =                     - sigma1*y(m)*r_1_mn
      enddo
!
    endsubroutine piecew_dipole_aa
!***********************************************************************
    subroutine geo_benchmark_B(f)
!
!  30-june-04/grs: coded
!
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension(nx) :: theta_mn,ar,atheta,aphi,r_mn,phi_mn
      real :: C_int,C_ext,A_int,A_ext
      integer :: j
!
      do imn=1,ny*nz
        n=nn(imn)
        m=mm(imn)
        r_mn=sqrt(x(l1:l2)**2+y(m)**2+z(n)**2)
        theta_mn=acos(spread(z(n),1,nx)/r_mn)
        phi_mn=atan2(spread(y(m),1,nx),x(l1:l2))
!
! calculate ax,ay,az (via ar,atheta,aphi) inside shell (& leave zero outside shell)
!
        do j=1,ninit
           select case (initaa(j))
           case ('geo-benchmark-case1')
              if (lroot .and. imn==1) print*, 'geo_benchmark_B: geo-benchmark-case1'
              C_int=-( -1./63.*r_int**4 + 11./84.*r_int**3*r_ext            &
                     + 317./1050.*r_int**2*r_ext**2                         &
                     - 1./5.*r_int**2*r_ext**2*log(r_int) )
              C_ext=-( -1./63.*r_ext**9 + 11./84.*r_ext**8*r_int            &
                     + 317./1050.*r_ext**7*r_int**2                         &
                     - 1./5.*r_ext**7*r_int**2*log(r_ext) )
              A_int=5./2.*(r_ext-r_int)
              A_ext=5./8.*(r_ext**4-r_int**4)
!
              where (r_mn < r_int)
                ar=C_int*ampl_B0*80.*2.*(3.*sin(theta_mn)**2-2.)*r_mn
                atheta=3.*C_int*ampl_B0*80.*sin(2.*theta_mn)*r_mn
                aphi=ampl_B0*A_int*r_mn*sin(theta_mn)
              endwhere
!
              where (r_mn <= r_ext .and. r_mn >= r_int)
                ar=ampl_B0*80.*2.*(3.*sin(theta_mn)**2-2.)*                 &
                   (   1./36.*r_mn**5 - 1./12.*(r_int+r_ext)*r_mn**4        &
                     + 1./14.*(r_int**2+4.*r_int*r_ext+r_ext**2)*r_mn**3    &
                     - 1./3.*(r_int**2*r_ext+r_int*r_ext**2)*r_mn**2        &
                     - 1./25.*r_int**2*r_ext**2*r_mn                        &
                     + 1./5.*r_int**2*r_ext**2*r_mn*log(r_mn) )
                atheta=-ampl_B0*80.*sin(2.*theta_mn)*                       &
                   (   7./36.*r_mn**5 - 1./2.*(r_int+r_ext)*r_mn**4         &
                     + 5./14.*(r_int**2+4.*r_int*r_ext+r_ext**2)*r_mn**3    &
                     - 4./3.*(r_int**2*r_ext+r_int*r_ext**2)*r_mn**2        &
                     + 2./25.*r_int**2*r_ext**2*r_mn                        &
                     + 3./5.*r_int**2*r_ext**2*r_mn*log(r_mn) )
                aphi=ampl_B0*5./8.*sin(theta_mn)*                           &
                   ( 4.*r_ext*r_mn - 3.*r_mn**2 - r_int**4/r_mn**2 )
              endwhere
!
              where (r_mn > r_ext)
                ar=C_ext*ampl_B0*80.*2.*(3.*sin(theta_mn)**2-2.)/r_mn**4
                atheta=-2.*C_ext*ampl_B0*80.*sin(2.*theta_mn)/r_mn**4
                aphi=ampl_B0*A_ext/r_mn**2*sin(theta_mn)
              endwhere
!
          ! debug checks -- look at a pencil near the centre...
              if (ip<=4 .and. imn==(ny+1)*nz/2) then
                 print*,'r_int,r_ext',r_int,r_ext
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(r_mn), imn, iproc:', &
                      iproc, imn, minval(r_mn), maxval(r_mn)
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(theta_mn), imn, iproc:', &
                      iproc, imn, minval(theta_mn), maxval(theta_mn)
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(phi_mn), imn, iproc:', &
                      iproc, imn, minval(phi_mn), maxval(phi_mn)
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(ar), imn, iproc:', &
                      iproc, imn, minval(ar), maxval(ar)
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(atheta), imn, iproc:', &
                      iproc, imn, minval(atheta), maxval(atheta)
                 write(*,'(a45,2i6,2f15.7)') &
                      'geo_benchmark_B: minmax(aphi), imn, iproc:', &
                      iproc, imn, minval(aphi), maxval(aphi)
              endif
!
           case ('geo-benchmark-case2')
              if (lroot .and. imn==1) print*, 'geo_benchmark_B: geo-benchmark-case2 not yet coded.'
!
           case default
              if (lroot .and. imn==1) print*,'geo_benchmark_B: case not defined!'
              call stop_it("")
           endselect
        enddo
        f(l1:l2,m,n,iax)=sin(theta_mn)*cos(phi_mn)*ar + cos(theta_mn)*cos(phi_mn)*atheta - sin(phi_mn)*aphi
        f(l1:l2,m,n,iay)=sin(theta_mn)*sin(phi_mn)*ar + cos(theta_mn)*sin(phi_mn)*atheta + cos(phi_mn)*aphi
        f(l1:l2,m,n,iaz)=cos(theta_mn)*ar - sin(theta_mn)*atheta
     enddo
!
!
     if (ip<=14) then
        print*,'geo_benchmark_B: minmax(ax) on iproc:', iproc, minval(f(l1:l2,m1:m2,n1:n2,iax)),maxval(f(l1:l2,m1:m2,n1:n2,iax))
        print*,'geo_benchmark_B: minmax(ay) on iproc:', iproc, minval(f(l1:l2,m1:m2,n1:n2,iay)),maxval(f(l1:l2,m1:m2,n1:n2,iay))
        print*,'geo_benchmark_B: minmax(az) on iproc:', iproc, minval(f(l1:l2,m1:m2,n1:n2,iaz)),maxval(f(l1:l2,m1:m2,n1:n2,iaz))
     endif
!
    endsubroutine geo_benchmark_B
!***********************************************************************
    subroutine eta_xy_dep(eta_xy,geta_xy,eta_xy_profile)
!
!   2-jul-2009/koen: creates an xy-dependent resistivity (for RFP studies)
!   (under reconstruction)
      real, dimension(mx,my) :: eta_xy,r2,gradr_eta_xy
      real, dimension(mx,my,3)  :: geta_xy
      character (len=labellen) :: eta_xy_profile
      real :: rmax2,a,w
      integer :: i,j
!
      intent(out) :: eta_xy,geta_xy
!
      select case (eta_xy_profile)
      case ('schnack89')
      do i=1,mx
        do j=1,my
          r2(i,j)=x(i)**2+y(j)**2
        enddo
      enddo
!
!  define eta_xy: radial resistivity profile from Y.L. Ho, S.C. Prager &
!              D.D. Schnack, Phys rev letters vol 62 nr 13 1989
!  and define gradr_eta_xy: 1/r *d_r(eta_xy))
!
!  to prevent numerically impossible diffusivities the value outside rmax2
!  the diffusivity is set to stay below an input value eta_xy_max (> 100*eta),
!  keeping the transition continuous in the first derivative
!
      rmax2=1.
      a=(eta_xy_max-100.*eta)/eta_xy_max
      w=(eta_xy_max-100.*eta)/(5400.*eta)
!
      do i=1,mx
      do j=1,my
!  inside
        if (r2(i,j) < rmax2) then
          eta_xy(i,j) = eta*(1.+9.*(r2(i,j)/rmax2)**15)**2
          gradr_eta_xy= 540.*eta*(1.+9.*(r2(i,j)/rmax2)**15)*(r2(i,j)/rmax2)**14/rmax2**0.5
!  outside
        else
          eta_xy(i,j) = eta_xy_max*(1.-a*exp(-(r2(i,j)**0.5-rmax2**0.5)/w))
          gradr_eta_xy(i,j)= eta_xy_max*(a*exp(-(r2(i,j)**0.5-rmax2**0.5)/w))/w/rmax2**0.5
        endif
!  gradient
          geta_xy(i,j,1) = x(i)*gradr_eta_xy(i,j)
          geta_xy(i,j,2) = y(j)*gradr_eta_xy(i,j)
          geta_xy(i,j,3) = 0.
      enddo
      enddo
!
      endselect
!
    endsubroutine eta_xy_dep
!***********************************************************************
    subroutine eta_zdep(eta_z,geta_z,zdep_profile)
!
!  creates a z-dependent resistivity for protoplanetary disk studies
!
!  12-jul-2005/joishi: coded
!
      use General, only: erfcc
      use Sub, only: step, der_step
!
      real, dimension(mz) :: eta_z,z2
      real, dimension(mz,3) :: geta_z
      character (len=labellen) :: zdep_profile
!      integer :: i
!
      intent(out) :: eta_z,geta_z
!
      select case (zdep_profile)
        case ('fs')
          z2 = z**2.
!  resistivity profile from Fleming & Stone (ApJ 585:908-920)
          eta_z = eta*exp(-z2/2.+sigma_ratio*erfcc(abs(z))/4.)
!
! its gradient:
          geta_z(:,1) = 0.
          geta_z(:,2) = 0.
          geta_z(:,3) = eta_z*(-z-sign(1.,z)*sigma_ratio*exp(-z2)/(2.*sqrt(pi)))
!
        case ('tanh')
!  default to spread gradient over ~5 grid cells.
           if (eta_width == 0.) eta_width = 5.*dz
           eta_z = eta*0.5*(tanh((z + eta_z0)/eta_width) &
             - tanh((z - eta_z0)/eta_width))
!
! its gradient:
           geta_z(:,1) = 0.
           geta_z(:,2) = 0.
           geta_z(:,3) = -eta/(2.*eta_width) * ((tanh((z + eta_z0)/eta_width))**2. &
             - (tanh((z - eta_z0)/eta_width))**2.)
!
!  Single step function
!
        case ('step')
!
!  default to spread gradient over ~5 grid cells.
!
           if (eta_width == 0.) eta_width = 5.*dz
           eta_z = eta + eta*(eta_jump-1.)*step(z,eta_z0,-eta_width)
!
! its gradient:
           geta_z(:,1) = 0.
           geta_z(:,2) = 0.
           geta_z(:,3) = eta*(eta_jump-1.)*der_step(z,eta_z0,-eta_width)
!
!  Two-step function
!
        case ('two_step')
!
!  Default to spread gradient over ~5 grid cells,
!
           if (eta_width == 0.) eta_width = 5.*dz
           eta_z = eta*eta_jump-eta*(eta_jump-1.)* &
             (step(z,eta_z0,eta_width)-step(z,eta_z1,eta_width))
!
!  ... and its gradient. Note that the sign of the second term enters
!  with the opposite sign, because we have used negative eta_width.
!
           geta_z(:,1) = 0.
           geta_z(:,2) = 0.
           geta_z(:,3) = eta*(eta_jump-1.)*( &
             der_step(z,eta_z0,-eta_width)+der_step(z,eta_z1,eta_width))
!
      endselect
!
    endsubroutine eta_zdep
!***********************************************************************
    subroutine correct_lorentz_force(f,lfield,const,pblaw)
!
!  Correct for the magnetic term in the centrifugal force. The
!  pressure gradient was already corrected in the density and temperature
!  modules
!
!  13-nov-08/wlad : coded
!
      use Sub,      only: get_radial_distance
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx)   :: rr_cyl,rr_sph,Btheta
      real, dimension (mx)   :: tmp,uu2,va2,va2r
      real, dimension (mx)   :: rho1,rho1_jxb
      integer                :: i
      logical                :: lheader
      logical                :: lfield
      real :: const,pblaw
!
      if (lroot) print*,'Correcting magnetic terms on the '//&
           'centrifugal force'
!
      if (.not.lspherical_coords) then
        call fatal_error("correct_lorentz_force",&
            "only implemented for spherical coordinates")
        if ((B_ext(1)/=0).or.(B_ext(3)/=0)) then
          call fatal_error("correct_lorentz_force",&
              "only implemented for polar fields")
        endif
      endif
!
      do m=1,my
        do n=1,mz
!
          call get_radial_distance(rr_sph,rr_cyl)
!
          lheader=((m==1).and.(n==1).and.lroot)
!
          !this field also has a magnetic pressure gradient          
          Btheta=const*rr_sph**pblaw/sin(y(m))
!
          rho1=1./f(:,m,n,ilnrho)
!
          uu2=f(:,m,n,iuz)**2
          va2=rho1*(Btheta+B_ext(2))**2
!
          rho1_jxb=rho1
!
!  set rhomin_jxb>0 in order to limit the jxb term at very low densities.
!
          if (rhomin_jxb>0) rho1_jxb=min(rho1_jxb,1/rhomin_jxb)
!
!  set va2max_jxb>0 in order to limit the jxb term at very high Alfven speeds.
!  set va2power_jxb to an integer value in order to specify the power
!  of the limiting term,
!
          if (va2max_jxb>0) then
            rho1_jxb = rho1_jxb &
                * (1+(va2/va2max_jxb)**va2power_jxb)**(-1.0/va2power_jxb)
          endif
          va2r=rho1_jxb*va2
!
          if (lfield) then
            !second term is the magnetic pressure gradient
            tmp=uu2+va2r*(1+2*pblaw/rr_sph)
            !the polar pressure should be
            !-2*cot(theta)/rr * va2r, but I will ignore it
            ! for now. It feedbacks on the density,
            ! so the initial condition for density and field
            ! should be solved iteratively. But as uu>>va, I
            ! will just let the system relax to equilibrium in
            ! runtime.
          else
            tmp=uu2+va2r
          endif
!
!  Make sure the correction does not impede centrifugal equilibrium
!
          do i=1,nx
            if (tmp(i)<0.) then
              if (rr_sph(i) < r_int) then
                !it's inside the frozen zone, so
                !just set tmp to zero and emit a warning
                tmp(i)=0.
                if ((ip<=10).and.lheader) &
                    call warning('correct_lorentz_force','Cannot '//&
                    'have centrifugal equilibrium in the inner '//&
                    'domain. The lorentz force is too strong.')
              else
                print*,'correct_lorentz_force: ',&
                    'cannot have centrifugal equilibrium in the inner ',&
                    'domain. The lorentz force is too strong at ',&
                    'x,y,z=',x(i+nghost),y(m),z(n)
                print*,'the angular frequency here is',tmp(i)
                call fatal_error("","")
              endif
            endif
          enddo
!
!  Correct the velocities
!
          f(:,m,n,iuz)= sqrt(tmp)
!
        enddo
      enddo
!
    endsubroutine correct_lorentz_force
!***********************************************************************
    subroutine remove_mean_emf(f,df)
!
      real, dimension (mx,my,mz,mfarray), intent (in) :: f
      real, dimension (mx,my,mz,mvar), intent (inout) :: df
!
      if (lremove_mean_emf) then
        if (lcartesian_coords) then
          print*,"You are using a cylinder carved in a Cartesian grid"//&
               "if you want to remove the mean emf generated by the "//&
               "uphi x Bz term from the induction equation, use the "//&
               "special/rtime_phiavg.f90 file instead."
          call fatal_error("remove_mean_emf","")
        elseif (lcylindrical_coords) then
          call remove_mean_emf_cylindrical(f,df)
        elseif (lspherical_coords) then
          call remove_mean_emf_spherical(f,df)
        endif
      endif
!
    endsubroutine remove_mean_emf
!***********************************************************************
    subroutine remove_mean_emf_cylindrical(f,df)
!
!  Substract mean emf from the radial component of the induction
!  equation. Activated only when large Bz fields and are present
!  keplerian advection. Due to this u_phi x Bz term, the radial
!  component of the magnetic potential
!  develops a divergence that grows linearly in time. Since it is
!  purely divergent, it is okay analytically. But numerically it leads to
!  problems if this divergent grows bigger than the curl, which it does
!  eventually.
!
!  This is a cylindrical version of the rtime_phiavg special file.
!
!  13-sep-07/wlad: adapted from remove_mean_momenta
!
      use Mpicomm, only: mpiallreduce_sum
      use Sub    , only: curl
!
      real, dimension (mx,my,mz,mfarray), intent (in) :: f
      real, dimension (mx,my,mz,mvar), intent (inout) :: df
      real, dimension (nx,nz) :: fsum_tmp,uxb
      real, dimension (nx,3)  :: pbb
      real, dimension (nx)    :: uu,bb
      real                    :: fac
      integer                 :: nnghost
!
      fac = 1.0/nygrid
!
! Average over phi - the result is a (nr,nz) array
!
      fsum_tmp = 0.
      do m=m1,m2
      do n=n1,n2
        nnghost=n-n1+1
        call curl(f,iaa,pbb)
        bb=pbb(:,3)+B_ext(3)
        uu=f(l1:l2,m,n,iuy)
        fsum_tmp(:,nnghost)=fsum_tmp(:,nnghost)+ fac*uu*bb
      enddo
      enddo
!
! The sum has to be done processor-wise
! Sum over processors of same ipz, and different ipy
!
      call mpiallreduce_sum(fsum_tmp,uxb,(/nx,nz/),idir=2)
!
      do m=m1,m2
        df(l1:l2,m,n1:n2,iax)=df(l1:l2,m,n1:n2,iax)-uxb
      enddo
!
    endsubroutine remove_mean_emf_cylindrical
!***********************************************************************
    subroutine remove_mean_emf_spherical(f,df)
!
!  Substract mean emf from the radial component of the induction
!  equation. Activated only when large Bz fields and keplerian
!  advection are present. Due to this u_phi x Bz term, the radial
!  component of the magnetic potential
!  develops a divergence that grows linearly in time. Since it is
!  purely divergent, it is okay analytically. But numerically it leads to
!  problems if this divergent grows bigger than the curl, which it does
!  eventually.
!
!  This is a cylindrical version of the rtime_phiavg special file.
!
!  13-sep-07/wlad: adapted from remove_mean_momenta
!
      use Mpicomm,  only: mpiallreduce_sum
      use Sub    ,  only: curl
!
      real, dimension (mx,my,mz,mfarray), intent (in) :: f
      real, dimension (mx,my,mz,mvar), intent (inout) :: df
      real, dimension (nx,ny) :: fsum_tmp,uxb
      real, dimension (nx,3)  :: pbb
      real, dimension (nx)    :: uu,bb
      real                    :: fac
      integer                 :: mmghost
!
      fac = 1.0/nzgrid
!
! Average over phi - the result is a (nr,ntht) array
!
      fsum_tmp = 0.
      do n=n1,n2
      do m=m1,m2
        mmghost=m-m1+1
        call curl(f,iaa,pbb)
!
! if lbext_curvilinear is true, then it respects the coordinate
! system defined by the user. B_ext(2) then is the polar field.
!
        if (lbext_curvilinear) then
          bb=pbb(:,2)+B_ext(2)
        else
          !else the field is cartesian, in the z-direction
          call fatal_error("remove_mean_emf_spherical",&
              "not implemented for cartesian fields in spherical coordinates")
        endif
        uu=f(l1:l2,m,n,iuz)
!
        fsum_tmp(:,mmghost)=fsum_tmp(:,mmghost)+ fac*uu*bb
      enddo
      enddo
!
! The sum has to be done processor-wise
! Sum over processors of same ipy, and different ipz
!
      !call mpiallreduce_sum_column(fsum_tmp,uxb,(/nx,ny/))
      call mpiallreduce_sum(fsum_tmp,uxb,(/nx,ny/),idir=3)
!
      do n=n1,n2
      do m=m1,m2
        mmghost=m-m1+1
        if (lbext_curvilinear) then
          ! u\phi times b\theta = -ub \r
          df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)+uxb(:,mmghost)
        else
          ! \z=cos(theta)*\r - sin(theta)\theta
          ! u\phi times b\z = ub*sin \r + ub*cos \theta
          df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-uxb(:,mmghost)*sinth(m)
          df(l1:l2,m,n,iay)=df(l1:l2,m,n,iay)-uxb(:,mmghost)*costh(m)
        endif
      enddo
      enddo
!
    endsubroutine remove_mean_emf_spherical
!***********************************************************************
    subroutine bb_unitvec_shock(f,bb_hat)
!
!  Compute unit vector along the magnetic field.
!  Accurate to 2nd order.
!  Tries to avoid division by zero.
!  Taken from http://nuclear.llnl.gov/CNP/apt/apt/aptvunb.html.
!  If anybody knows a more accurate way of doing this, please modify.
!
!  16-aug-06/tobi: coded
!
      real, dimension (mx,my,mz,mfarray), intent (in) :: f
      real, dimension (mx,3), intent (out) :: bb_hat
!
      !Tobi: Not sure about this value
      real, parameter :: tol=1e-11
!
      real, dimension (mx,3) :: bb,bb2
      real, dimension (mx) :: bb_len,aerr2
      real :: fac
      integer :: j
!
!  Compute magnetic field from vector potential.
!
      bb=0.
!
      if (nxgrid/=1) then
        fac = 1/(2*dx)
        bb(l1-2:l2+2,3) = bb(l1-2:l2+2,3) + fac*( f(l1-1:l2+3,m  ,n  ,iay)   &
                                                - f(l1-3:l2+1,m  ,n  ,iay) )
        bb(l1-2:l2+2,2) = bb(l1-2:l2+2,2) - fac*( f(l1-1:l2+3,m  ,n  ,iaz)   &
                                                - f(l1-3:l2+1,m  ,n  ,iaz) )
      endif
!
      if (nygrid/=1) then
        fac = 1/(2*dy)
        bb(l1-2:l2+2,1) = bb(l1-2:l2+2,1) + fac*( f(l1-2:l2+2,m+1,n  ,iaz)   &
                                                - f(l1-2:l2+2,m-1,n  ,iaz) )
        bb(l1-2:l2+2,3) = bb(l1-2:l2+2,3) - fac*( f(l1-2:l2+2,m+1,n  ,iax)   &
                                                - f(l1-2:l2+2,m-1,n  ,iax) )
      endif
!
      if (nzgrid/=1) then
        fac = 1/(2*dz)
        bb(l1-2:l2+2,2) = bb(l1-2:l2+2,2) + fac*( f(l1-2:l2+2,m  ,n+1,iax)   &
                                                - f(l1-2:l2+2,m  ,n-1,iax) )
        bb(l1-2:l2+2,1) = bb(l1-2:l2+2,1) - fac*( f(l1-2:l2+2,m  ,n+1,iay)   &
                                                - f(l1-2:l2+2,m  ,n-1,iay) )
      endif
!
!  Add external magnetic field.
!
      do j=1,3; bb(:,j) = bb(:,j) + B_ext(j); enddo
!
!  Truncate small components to zero.
!
      bb2 = bb**2
!
      aerr2 = tol**2 * max(sum(bb2,2),1.)
!
      do j=1,3
        where (bb2(:,j) < aerr2)
          bb_hat(:,j) = 0.
        elsewhere
          bb_hat(:,j) = bb(:,j)
        endwhere
      enddo
!
!
!  Get unit vector.
!
      bb_len = sqrt(sum(bb_hat**2,2))
!
      do j=1,3; bb_hat(:,j) = bb_hat(:,j)/(bb_len+tini); enddo
!
    endsubroutine bb_unitvec_shock
!***********************************************************************
    subroutine input_persistent_magnetic(id,lun,done)
!
!  Read in the stored phase and amplitude for the correction of the Beltrami
!  wave forcing.
!
!   5-apr-08/axel: adapted from input_persistent_forcing
!
      integer :: id,lun
      logical :: done
!
      if (id==id_record_MAGNETIC_PHASE) then
        read (lun) phase_beltrami
        done=.true.
        if (lroot) print*,'input_persistent_magnetic: ', phase_beltrami
      elseif (id==id_record_MAGNETIC_AMPL) then
        read (lun) ampl_beltrami
        done=.true.
        if (lroot) print*,'input_persistent_magnetic: ', ampl_beltrami
      endif
!
    endsubroutine input_persistent_magnetic
!***********************************************************************
    subroutine output_persistent_magnetic(lun)
!
!  Write the stored phase and amplitude for the
!  correction of the Beltrami wave forcing
!
!   5-apr-08/axel: adapted from output_persistent_forcing
!
      integer :: lun
!
      if (lroot.and.ip<14.and.lforcing_cont_aa_local) then
        if (phase_beltrami>=0.0) print*, 'output_persistent_magnetic: ', &
            phase_beltrami, ampl_beltrami
      endif
!
!  write details
!
      write (lun) id_record_MAGNETIC_PHASE
      write (lun) phase_beltrami
      write (lun) id_record_MAGNETIC_AMPL
      write (lun) ampl_beltrami
!
    endsubroutine output_persistent_magnetic
!***********************************************************************
    subroutine rprint_magnetic(lreset,lwrite)
!
!  Reads and registers print parameters relevant for magnetic fields.
!
!   3-may-02/axel: coded
!  27-may-02/axel: added possibility to reset list
!
      use Diagnostics
      use FArrayManager, only: farray_index_append
!
      integer :: iname,inamex,inamey,inamez,ixy,ixz,irz,inamer,iname_half
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  Reset everything in case of RELOAD.
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_ab_int=0; idiag_jb_int=0; idiag_b2tm=0; idiag_bjtm=0; idiag_jbtm=0
        idiag_b2uzm=0; idiag_b2ruzm=0; idiag_ubbzm=0; idiag_b1m=0; idiag_b2m=0
        idiag_bm2=0; idiag_j2m=0; idiag_jm2=0
        idiag_abm=0; idiag_abrms=0; idiag_abmh=0
        idiag_abumx=0; idiag_abumy=0; idiag_abumz=0
        idiag_abmn=0; idiag_abms=0; idiag_jbmh=0; idiag_jbmn=0; idiag_jbms=0
        idiag_ajm=0; idiag_cosubm=0; idiag_jbm=0
        idiag_uam=0; idiag_ubm=0; idiag_dubrms=0; idiag_dobrms=0; idiag_ujm=0
        idiag_uxbxm=0; idiag_uybym=0; idiag_uzbzm=0
        idiag_fbm=0; idiag_fxbxm=0; idiag_epsM=0; idiag_epsM_LES=0
        idiag_epsAD=0; idiag_bxpt=0; idiag_bypt=0; idiag_bzpt=0; idiag_Expt=0
        idiag_Eypt=0; idiag_Ezpt=0; idiag_aybym2=0; idiag_exaym2=0
        idiag_exjm2=0; idiag_brms=0; idiag_bmax=0; idiag_jrms=0; idiag_jmax=0
        idiag_vArms=0; idiag_emag=0; idiag_bxmin=0; idiag_bymin=0; idiag_bzmin=0
        idiag_bxmax=0; idiag_bymax=0; idiag_bzmax=0; idiag_vAmax=0; idiag_dtb=0
        idiag_arms=0; idiag_amax=0; idiag_beta1m=0
        idiag_beta1max=0; idiag_bxm=0; idiag_bym=0; idiag_bzm=0; idiag_axm=0
        idiag_aym=0; idiag_azm=0; idiag_bx2m=0; idiag_by2m=0; idiag_bz2m=0
        idiag_bxbymy=0; idiag_bxbzmy=0; idiag_bybzmy=0; idiag_bxbymz=0
        idiag_bxbzmz=0; idiag_bybzmz=0; idiag_b2mz=0
        idiag_jbmz=0; idiag_abmz=0; idiag_uamz=0
        idiag_bxbym=0; idiag_bxbzm=0; idiag_bybzm=0; idiag_djuidjbim=0
        idiag_axmz=0; idiag_aymz=0; idiag_azmz=0; idiag_bxmz=0; idiag_bymz=0
        idiag_abuxmz=0; idiag_abuymz=0; idiag_abuzmz=0
        idiag_uabxmz=0; idiag_uabymz=0; idiag_uabzmz=0
        idiag_bzmz=0; idiag_bmx=0; idiag_bmy=0; idiag_bmz=0; idiag_embmz=0
        idiag_bmzS2=0; idiag_bmzA2=0
        idiag_emxamz3=0; idiag_jmx=0; idiag_jmy=0; idiag_jmz=0; idiag_ambmz=0
        idiag_jmbmz=0; idiag_kmz=0; idiag_kx_aa=0
        idiag_ambmzh=0;idiag_ambmzn=0;idiag_ambmzs=0; idiag_bmzph=0
        idiag_bmzphe=0; idiag_bcosphz=0; idiag_bsinphz=0
        idiag_bx2mz=0; idiag_by2mz=0; idiag_bz2mz=0
        idiag_bx2rmz=0; idiag_by2rmz=0; idiag_bz2rmz=0
        idiag_bxmxy=0; idiag_bymxy=0; idiag_bzmxy=0
        idiag_jxmxy=0; idiag_jymxy=0; idiag_jzmxy=0
        idiag_bx2mxy=0; idiag_by2mxy=0; idiag_bz2mxy=0; idiag_bxbymxy=0
        idiag_bxbzmxy=0; idiag_bybzmxy=0; idiag_bxbymxz=0; idiag_bxbzmxz=0
        idiag_bybzmxz=0; idiag_bxmxz=0; idiag_bymxz=0; idiag_bzmxz=0
        idiag_axmxz=0; idiag_aymxz=0; idiag_azmxz=0; idiag_Exmxz=0
        idiag_Eymxz=0; idiag_Ezmxz=0; idiag_jxbm=0; idiag_uxbm=0; idiag_oxuxbm=0
        idiag_jxbxbm=0; idiag_gpxbm=0; idiag_uxDxuxbm=0
        idiag_uxbmx=0; idiag_uxbmy=0; idiag_uxbmz=0
        idiag_jxbmx=0; idiag_jxbmy=0; idiag_jxbmz=0
        idiag_uxbcmx=0; idiag_uxbsmx=0
        idiag_uxbcmy=0; idiag_uxbsmy=0; idiag_examz1=0; idiag_examz2=0
        idiag_examz3=0; idiag_examx=0; idiag_examy=0; idiag_examz=0
        idiag_exjmx=0; idiag_exjmy=0; idiag_exjmz=0; idiag_dexbmx=0
        idiag_dexbmy=0; idiag_dexbmz=0; idiag_phibmx=0; idiag_phibmy=0
        idiag_phibmz=0; idiag_uxjm=0; idiag_ujxbm=0; idiag_b2divum=0
        idiag_b3b21m=0; idiag_b1b32m=0; idiag_b2b13m=0
        idiag_udotxbm=0; idiag_uxbdotm=0; idiag_brmphi=0; idiag_bpmphi=0
        idiag_bzmphi=0; idiag_b2mphi=0; idiag_jbmphi=0; idiag_uxbrmphi=0
        idiag_uxbpmphi=0; idiag_uxbzmphi=0; idiag_jxbrmphi=0; idiag_jxbpmphi=0
        idiag_jxbzmphi=0; idiag_jxbrxm=0; idiag_jxbrym=0; idiag_jxbrzm=0
        idiag_jxbr2m=0; idiag_jxbrxmx=0; idiag_jxbrymx=0; idiag_jxbrzmx=0
        idiag_jxbrxmy=0; idiag_jxbrymy=0; idiag_jxbrzmy=0; idiag_jxbrxmz=0
        idiag_jxbrymz=0; idiag_jxbrzmz=0; idiag_armphi=0; idiag_apmphi=0
        idiag_azmphi=0; idiag_dteta=0; idiag_uxBrms=0; idiag_Bresrms=0
        idiag_Rmrms=0; idiag_jfm=0; idiag_brbpmr=0; idiag_va2m=0; idiag_b2mr=0
        idiag_brmr=0; idiag_bpmr=0; idiag_bzmr=0; idiag_armr=0; idiag_apmr=0
        idiag_azmr=0; idiag_bxmx=0; idiag_bymx=0; idiag_bzmx=0; idiag_bxmy=0
        idiag_bymy=0; idiag_bzmy=0; idiag_bx2my=0; idiag_by2my=0; idiag_bz2my=0
        idiag_mflux_x=0; idiag_mflux_y=0; idiag_mflux_z=0; idiag_bmxy_rms=0
        idiag_brsphmphi=0; idiag_bthmphi=0; idiag_brmsh=0; idiag_brmsn=0
        idiag_brmss=0; idiag_etatotalmx=0; idiag_etatotalmz=0
        idiag_etavamax=0; idiag_etajmax=0; idiag_etaj2max=0; idiag_etajrhomax=0
      endif
!
!  Check for those quantities that we want to evaluate online.
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'ab_int',idiag_ab_int)
        call parse_name(iname,cname(iname),cform(iname),'jb_int',idiag_jb_int)
        call parse_name(iname,cname(iname),cform(iname),'dteta',idiag_dteta)
        call parse_name(iname,cname(iname),cform(iname),'aybym2',idiag_aybym2)
        call parse_name(iname,cname(iname),cform(iname),'exaym2',idiag_exaym2)
        call parse_name(iname,cname(iname),cform(iname),'exabot',idiag_exabot)
        call parse_name(iname,cname(iname),cform(iname),'exatop',idiag_exatop)
        call parse_name(iname,cname(iname),cform(iname),'exjm2',idiag_exjm2)
        call parse_name(iname,cname(iname),cform(iname),'b2tm',idiag_b2tm)
        call parse_name(iname,cname(iname),cform(iname),'bjtm',idiag_bjtm)
        call parse_name(iname,cname(iname),cform(iname),'jbtm',idiag_jbtm)
        call parse_name(iname,cname(iname),cform(iname),'abm',idiag_abm)
        call parse_name(iname,cname(iname),cform(iname),'abmn',idiag_abmn)
        call parse_name(iname,cname(iname),cform(iname),'abms',idiag_abms)
        call parse_name(iname,cname(iname),cform(iname),'abrms',idiag_abrms)
        call parse_name(iname,cname(iname),cform(iname),'abumx',idiag_abumx)
        call parse_name(iname,cname(iname),cform(iname),'abumy',idiag_abumy)
        call parse_name(iname,cname(iname),cform(iname),'abumz',idiag_abumz)
        call parse_name(iname,cname(iname),cform(iname),'ajm',idiag_ajm)
        call parse_name(iname,cname(iname),cform(iname),'jbm',idiag_jbm)
        call parse_name(iname,cname(iname),cform(iname),'jbmn',idiag_jbmn)
        call parse_name(iname,cname(iname),cform(iname),'jbms',idiag_jbms)
        call parse_name(iname,cname(iname),cform(iname),'ubm',idiag_ubm)
        call parse_name(iname,cname(iname),cform(iname),'dubrms',idiag_dubrms)
        call parse_name(iname,cname(iname),cform(iname),'dobrms',idiag_dobrms)
        call parse_name(iname,cname(iname),cform(iname),'uxbxm',idiag_uxbxm)
        call parse_name(iname,cname(iname),cform(iname),'uybym',idiag_uybym)
        call parse_name(iname,cname(iname),cform(iname),'uzbzm',idiag_uzbzm)
        call parse_name(iname,cname(iname),cform(iname),'cosubm',idiag_cosubm)
        call parse_name(iname,cname(iname),cform(iname),'uam',idiag_uam)
        call parse_name(iname,cname(iname),cform(iname),'ujm',idiag_ujm)
        call parse_name(iname,cname(iname),cform(iname),'fbm',idiag_fbm)
        call parse_name(iname,cname(iname),cform(iname),'fxbxm',idiag_fxbxm)
        call parse_name(iname,cname(iname),cform(iname),'b2ruzm',idiag_b2ruzm)
        call parse_name(iname,cname(iname),cform(iname),'b2uzm',idiag_b2uzm)
        call parse_name(iname,cname(iname),cform(iname),'ubbzm',idiag_ubbzm)
        call parse_name(iname,cname(iname),cform(iname),'b1m',idiag_b1m)
        call parse_name(iname,cname(iname),cform(iname),'b2m',idiag_b2m)
        call parse_name(iname,cname(iname),cform(iname),'bm2',idiag_bm2)
        call parse_name(iname,cname(iname),cform(iname),'j2m',idiag_j2m)
        call parse_name(iname,cname(iname),cform(iname),'jm2',idiag_jm2)
        call parse_name(iname,cname(iname),cform(iname),'epsM',idiag_epsM)
        call parse_name(iname,cname(iname),cform(iname),&
            'epsM_LES',idiag_epsM_LES)
        call parse_name(iname,cname(iname),cform(iname),'epsAD',idiag_epsAD)
        call parse_name(iname,cname(iname),cform(iname),'emag',idiag_emag)
        call parse_name(iname,cname(iname),cform(iname),'brms',idiag_brms)
        call parse_name(iname,cname(iname),cform(iname),'brmsn',idiag_brmsn)
        call parse_name(iname,cname(iname),cform(iname),'brmss',idiag_brmss)
        call parse_name(iname,cname(iname),cform(iname),'bmax',idiag_bmax)
        call parse_name(iname,cname(iname),cform(iname),'bxmin',idiag_bxmin)
        call parse_name(iname,cname(iname),cform(iname),'bymin',idiag_bymin)
        call parse_name(iname,cname(iname),cform(iname),'bzmin',idiag_bzmin)
        call parse_name(iname,cname(iname),cform(iname),'bxmax',idiag_bxmax)
        call parse_name(iname,cname(iname),cform(iname),'bymax',idiag_bymax)
        call parse_name(iname,cname(iname),cform(iname),'bzmax',idiag_bzmax)
        call parse_name(iname,cname(iname),cform(iname),'jrms',idiag_jrms)
        call parse_name(iname,cname(iname),cform(iname),'jmax',idiag_jmax)
        call parse_name(iname,cname(iname),cform(iname),'axm',idiag_axm)
        call parse_name(iname,cname(iname),cform(iname),'aym',idiag_aym)
        call parse_name(iname,cname(iname),cform(iname),'azm',idiag_azm)
        call parse_name(iname,cname(iname),cform(iname),'arms',idiag_arms)
        call parse_name(iname,cname(iname),cform(iname),'amax',idiag_amax)
        call parse_name(iname,cname(iname),cform(iname),'vArms',idiag_vArms)
        call parse_name(iname,cname(iname),cform(iname),'vAmax',idiag_vAmax)
        call parse_name(iname,cname(iname),cform(iname),'vA2m',idiag_vA2m)
        call parse_name(iname,cname(iname),cform(iname),'beta1m',idiag_beta1m)
        call parse_name(iname,cname(iname),cform(iname),'beta1max',idiag_beta1max)
        call parse_name(iname,cname(iname),cform(iname),'dtb',idiag_dtb)
        call parse_name(iname,cname(iname),cform(iname),'bxm',idiag_bxm)
        call parse_name(iname,cname(iname),cform(iname),'bym',idiag_bym)
        call parse_name(iname,cname(iname),cform(iname),'bzm',idiag_bzm)
        call parse_name(iname,cname(iname),cform(iname),'bx2m',idiag_bx2m)
        call parse_name(iname,cname(iname),cform(iname),'by2m',idiag_by2m)
        call parse_name(iname,cname(iname),cform(iname),'bz2m',idiag_bz2m)
        call parse_name(iname,cname(iname),cform(iname),'bxbym',idiag_bxbym)
        call parse_name(iname,cname(iname),cform(iname),'bxbzm',idiag_bxbzm)
        call parse_name(iname,cname(iname),cform(iname),'bybzm',idiag_bybzm)
        call parse_name(iname,cname(iname),cform(iname),'djuidjbim',idiag_djuidjbim)
        call parse_name(iname,cname(iname),cform(iname),'jxbrxm',idiag_jxbrxm)
        call parse_name(iname,cname(iname),cform(iname),'jxbrym',idiag_jxbrym)
        call parse_name(iname,cname(iname),cform(iname),'jxbrzm',idiag_jxbrzm)
        call parse_name(iname,cname(iname),cform(iname),'jxbr2m',idiag_jxbr2m)
        call parse_name(iname,cname(iname),cform(iname),'jxbm',idiag_jxbm)
        call parse_name(iname,cname(iname),cform(iname),'uxbm',idiag_uxbm)
        call parse_name(iname,cname(iname),cform(iname),'uxbmx',idiag_uxbmx)
        call parse_name(iname,cname(iname),cform(iname),'uxbmy',idiag_uxbmy)
        call parse_name(iname,cname(iname),cform(iname),'uxbmz',idiag_uxbmz)
        call parse_name(iname,cname(iname),cform(iname),'jxbmx',idiag_jxbmx)
        call parse_name(iname,cname(iname),cform(iname),'jxbmy',idiag_jxbmy)
        call parse_name(iname,cname(iname),cform(iname),'jxbmz',idiag_jxbmz)
        call parse_name(iname,cname(iname),cform(iname),'uxbcmx',idiag_uxbcmx)
        call parse_name(iname,cname(iname),cform(iname),'uxbcmy',idiag_uxbcmy)
        call parse_name(iname,cname(iname),cform(iname),'uxbsmx',idiag_uxbsmx)
        call parse_name(iname,cname(iname),cform(iname),'uxbsmy',idiag_uxbsmy)
        call parse_name(iname,cname(iname),cform(iname),'examx',idiag_examx)
        call parse_name(iname,cname(iname),cform(iname),'examy',idiag_examy)
        call parse_name(iname,cname(iname),cform(iname),'examz',idiag_examz)
        call parse_name(iname,cname(iname),cform(iname),'exjmx',idiag_exjmx)
        call parse_name(iname,cname(iname),cform(iname),'exjmy',idiag_exjmy)
        call parse_name(iname,cname(iname),cform(iname),'exjmz',idiag_exjmz)
        call parse_name(iname,cname(iname),cform(iname),'dexbmx',idiag_dexbmx)
        call parse_name(iname,cname(iname),cform(iname),'dexbmy',idiag_dexbmy)
        call parse_name(iname,cname(iname),cform(iname),'dexbmz',idiag_dexbmz)
        call parse_name(iname,cname(iname),cform(iname),'phibmx',idiag_phibmx)
        call parse_name(iname,cname(iname),cform(iname),'phibmy',idiag_phibmy)
        call parse_name(iname,cname(iname),cform(iname),'phibmz',idiag_phibmz)
        call parse_name(iname,cname(iname),cform(iname),'uxjm',idiag_uxjm)
        call parse_name(iname,cname(iname),cform(iname),'ujxbm',idiag_ujxbm)
        call parse_name(iname,cname(iname),cform(iname),'b2divum',idiag_b2divum)
        call parse_name(iname,cname(iname),cform(iname),'jxbxbm',idiag_jxbxbm)
        call parse_name(iname,cname(iname),cform(iname),'oxuxbm',idiag_oxuxbm)
        call parse_name(iname,cname(iname),cform(iname),'gpxbm',idiag_gpxbm)
        call parse_name(iname,cname(iname),cform(iname),&
            'uxDxuxbm',idiag_uxDxuxbm)
        call parse_name(iname,cname(iname),cform(iname),'b3b21m',idiag_b3b21m)
        call parse_name(iname,cname(iname),cform(iname),'b1b32m',idiag_b1b32m)
        call parse_name(iname,cname(iname),cform(iname),'b2b13m',idiag_b2b13m)
        call parse_name(iname,cname(iname),cform(iname),'udotxbm',idiag_udotxbm)
        call parse_name(iname,cname(iname),cform(iname),'uxbdotm',idiag_uxbdotm)
        call parse_name(iname,cname(iname),cform(iname),'bmx',idiag_bmx)
        call parse_name(iname,cname(iname),cform(iname),'bmy',idiag_bmy)
        call parse_name(iname,cname(iname),cform(iname),'bmz',idiag_bmz)
        call parse_name(iname,cname(iname),cform(iname),'bmzS2',idiag_bmzS2)
        call parse_name(iname,cname(iname),cform(iname),'bmzA2',idiag_bmzA2)
        call parse_name(iname,cname(iname),cform(iname),'jmx',idiag_jmx)
        call parse_name(iname,cname(iname),cform(iname),'jmy',idiag_jmy)
        call parse_name(iname,cname(iname),cform(iname),'jmz',idiag_jmz)
        call parse_name(iname,cname(iname),cform(iname),'bmzph',idiag_bmzph)
        call parse_name(iname,cname(iname),cform(iname),'bmzphe',idiag_bmzphe)
        call parse_name(iname,cname(iname),cform(iname),'bcosphz',idiag_bcosphz)
        call parse_name(iname,cname(iname),cform(iname),'bsinphz',idiag_bsinphz)
        call parse_name(iname,cname(iname),cform(iname),'emxamz3',idiag_emxamz3)
        call parse_name(iname,cname(iname),cform(iname),'embmz',idiag_embmz)
        call parse_name(iname,cname(iname),cform(iname),'ambmz',idiag_ambmz)
        call parse_name(iname,cname(iname),cform(iname),'ambmzn',idiag_ambmzn)
        call parse_name(iname,cname(iname),cform(iname),'ambmzs',idiag_ambmzs)
        call parse_name(iname,cname(iname),cform(iname),'jmbmz',idiag_jmbmz)
        call parse_name(iname,cname(iname),cform(iname),'kmz',idiag_kmz)
        call parse_name(iname,cname(iname),cform(iname),'kx_aa',idiag_kx_aa)
        call parse_name(iname,cname(iname),cform(iname),'bxpt',idiag_bxpt)
        call parse_name(iname,cname(iname),cform(iname),'bypt',idiag_bypt)
        call parse_name(iname,cname(iname),cform(iname),'bzpt',idiag_bzpt)
        call parse_name(iname,cname(iname),cform(iname),'Expt',idiag_Expt)
        call parse_name(iname,cname(iname),cform(iname),'Eypt',idiag_Eypt)
        call parse_name(iname,cname(iname),cform(iname),'Ezpt',idiag_Ezpt)
        call parse_name(iname,cname(iname),cform(iname),'uxBrms',idiag_uxBrms)
        call parse_name(iname,cname(iname),cform(iname),'Bresrms',idiag_Bresrms)
        call parse_name(iname,cname(iname),cform(iname),'Rmrms',idiag_Rmrms)
        call parse_name(iname,cname(iname),cform(iname),'jfm',idiag_jfm)
        call parse_name(iname,cname(iname),cform(iname),'bmxy_rms',idiag_bmxy_rms)
        call parse_name(iname,cname(iname),cform(iname),'etasmagm',idiag_etasmagm)
        call parse_name(iname,cname(iname),cform(iname),'etasmagmin',idiag_etasmagmin)
        call parse_name(iname,cname(iname),cform(iname),'etasmagmax',idiag_etasmagmax)
        call parse_name(iname,cname(iname),cform(iname),'etavamax',idiag_etavamax)
        call parse_name(iname,cname(iname),cform(iname),'etajmax',idiag_etajmax)
        call parse_name(iname,cname(iname),cform(iname),'etaj2max',idiag_etaj2max)
        call parse_name(iname,cname(iname),cform(iname),'etajrhomax',idiag_etajrhomax)
        call parse_name(iname,cname(iname),cform(iname),'cosjbm',idiag_cosjbm)
        call parse_name(iname,cname(iname),cform(iname),'jparallelm',idiag_jparallelm)
        call parse_name(iname,cname(iname),cform(iname),'jperpm',idiag_jperpm)
      enddo
!
!  Quantities which are averaged over half (north-south) the box.
!
      iname_half=name_half_max
!
!  Magnetic helicity (north and south) of total field.
!
      if ((idiag_abmn/=0).or.(idiag_abms/=0)) then
        iname_half=iname_half+1
        idiag_abmh=iname_half
      endif
!
!  Current helicity (north and south) of total field.
!
      if ((idiag_jbmn/=0).or.(idiag_jbms/=0)) then
        iname_half=iname_half+1
        idiag_jbmh=iname_half
      endif
!
!  Magnetic energy (north and south) of total field.
!
      if ((idiag_brmsn/=0).or.(idiag_brmss/=0)) then
        iname_half=iname_half+1
        idiag_brmsh=iname_half
      endif
!
!  Magnetic helicity (north and south) of mean field.
!
      if ((idiag_ambmzn/=0).or.(idiag_ambmzs/=0)) then
        iname_half=iname_half+1
        idiag_ambmzh=iname_half
      endif
!
!  Update name_half_max.
!
      name_half_max=iname_half
!
!  Currently need to force zaverage calculation at every lout step for
!  bmx and bmy and bmxy_rms.
!
      if ((idiag_bmx+idiag_bmy+idiag_bmxy_rms)>0) ldiagnos_need_zaverages=.true.
!
!  Check for those quantities for which we want xy-averages.
!
      do inamex=1,nnamex
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'bxmx',idiag_bxmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'bymx',idiag_bymx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex),'bzmx',idiag_bzmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'bx2mx',idiag_bx2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'by2mx',idiag_by2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'bz2mx',idiag_bz2mx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'bxbymx',idiag_bxbymx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'jxbrxmx',idiag_jxbrxmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'jxbrymx',idiag_jxbrymx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'jxbrzmx',idiag_jxbrzmx)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'mflux_x',idiag_mflux_x)
        call parse_name(inamex,cnamex(inamex),cformx(inamex), &
            'etatotalmx',idiag_etatotalmx)
     enddo
!
!  Check for those quantities for which we want xz-averages.
!
      do inamey=1,nnamey
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'bxmy',idiag_bxmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'bymy',idiag_bymy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey),'bzmy',idiag_bzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'bx2my',idiag_bx2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'by2my',idiag_by2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'bz2my',idiag_bz2my)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'bxbymy',idiag_bxbymy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'bxbzmy',idiag_bxbzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'bybzmy',idiag_bybzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'jxbrxmy',idiag_jxbrxmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'jxbrymy',idiag_jxbrymy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'jxbrzmy',idiag_jxbrzmy)
        call parse_name(inamey,cnamey(inamey),cformy(inamey), &
            'mflux_y',idiag_mflux_y)
      enddo
!
!  Check for those quantities for which we want yz-averages.
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'axmz',idiag_axmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'aymz',idiag_aymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'azmz',idiag_azmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'abuxmz',idiag_abuxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'abuymz',idiag_abuymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'abuzmz',idiag_abuzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uabxmz',idiag_uabxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uabymz',idiag_uabymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uabzmz',idiag_uabzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bbxmz',idiag_bbxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bbymz',idiag_bbymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bbzmz',idiag_bbzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bxmz',idiag_bxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bymz',idiag_bymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bzmz',idiag_bzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'jxmz',idiag_jxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'jymz',idiag_jymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'jzmz',idiag_jzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Exmz',idiag_Exmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Eymz',idiag_Eymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'Ezmz',idiag_Ezmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bx2mz',idiag_bx2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'by2mz',idiag_by2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bz2mz',idiag_bz2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bx2rmz',idiag_bx2rmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'by2rmz',idiag_by2rmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bz2rmz',idiag_bz2rmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'bxbymz',idiag_bxbymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'bxbzmz',idiag_bxbzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'bybzmz',idiag_bybzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'b2mz',idiag_b2mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'jxbrxmz',idiag_jxbrxmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'jxbrymz',idiag_jxbrymz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'jxbrzmz',idiag_jxbrzmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'mflux_z',idiag_mflux_z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'jbmz',idiag_jbmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'abmz',idiag_abmz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'uamz',idiag_uamz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'examz1',idiag_examz1)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'examz2',idiag_examz2)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'examz3',idiag_examz3)
        call parse_name(inamez,cnamez(inamez),cformz(inamez), &
            'etatotalmz',idiag_etatotalmz)
      enddo
!
!  Check for those quantities for which we want y-averages.
!
      do ixz=1,nnamexz
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'axmxz',idiag_axmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'aymxz',idiag_aymxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'azmxz',idiag_azmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bxmxz',idiag_bxmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bymxz',idiag_bymxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bzmxz',idiag_bzmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bx2mxz',idiag_bx2mxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'by2mxz',idiag_by2mxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bz2mxz',idiag_bz2mxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bxbymxz',idiag_bxbymxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bxbzmxz',idiag_bxbzmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'bybzmxz',idiag_bybzmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'Exmxz',idiag_Exmxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'Eymxz',idiag_Eymxz)
        call parse_name(ixz,cnamexz(ixz),cformxz(ixz),'Ezmxz',idiag_Ezmxz)
      enddo
!
!  Check for those quantities for which we want z-averages.
!
      do ixy=1,nnamexy
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bxmxy',idiag_bxmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bymxy',idiag_bymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bzmxy',idiag_bzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'jxmxy',idiag_jxmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'jymxy',idiag_jymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'jzmxy',idiag_jzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bx2mxy',idiag_bx2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'by2mxy',idiag_by2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bz2mxy',idiag_bz2mxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bxbymxy',idiag_bxbymxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bxbzmxy',idiag_bxbzmxy)
        call parse_name(ixy,cnamexy(ixy),cformxy(ixy),'bybzmxy',idiag_bybzmxy)
      enddo
!
!  Check for those quantities for which we want phi-averages.
!
      do irz=1,nnamerz
        call parse_name(irz,cnamerz(irz),cformrz(irz),'brmphi'  ,idiag_brmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'brsphmphi',idiag_brsphmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'bthmphi',idiag_bthmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'bpmphi'  ,idiag_bpmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'bzmphi'  ,idiag_bzmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'b2mphi'  ,idiag_b2mphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'jbmphi'  ,idiag_jbmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'uxbrmphi',idiag_uxbrmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'uxbpmphi',idiag_uxbpmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'uxbzmphi',idiag_uxbzmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'jxbrmphi',idiag_jxbrmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'jxbpmphi',idiag_jxbpmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'jxbzmphi',idiag_jxbzmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'armphi'  ,idiag_armphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'apmphi'  ,idiag_apmphi)
        call parse_name(irz,cnamerz(irz),cformrz(irz),'azmphi'  ,idiag_azmphi)
!
      enddo
!
!  Check for those quantities for which we want phiz-averages.
!
      do inamer=1,nnamer
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'brmr',  idiag_brmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'bpmr',  idiag_bpmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'bzmr',  idiag_bzmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'armr',  idiag_armr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'apmr',  idiag_apmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'azmr',  idiag_azmr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'b2mr',  idiag_b2mr)
        call parse_name(inamer,cnamer(inamer),cformr(inamer),'brbpmr',idiag_brbpmr)
      enddo
!
!  Write column, idiag_XYZ, where our variable XYZ is stored.
!
      if (lwr) then
        call farray_index_append('nname',nname)
        call farray_index_append('nnamexy',nnamexy)
        call farray_index_append('nnamexz',nnamexz)
        call farray_index_append('nnamez',nnamez)
        call farray_index_append('iaa',iaa)
        call farray_index_append('iax',iax)
        call farray_index_append('iay',iay)
        call farray_index_append('iaz',iaz)
        call farray_index_append('ihypres',ihypres)
      endif
!
!  call corresponding mean-field routine
!
      call rprint_magnetic_mf(lreset,lwrite)
!
    endsubroutine rprint_magnetic
!***********************************************************************
endmodule Magnetic

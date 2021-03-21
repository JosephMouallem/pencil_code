! $Id$
!
!  Radiation in the fluxlimited-diffusion approximation.
!  Doesn't work convincingly (and maybe never will). Look at the
!  (still experimental) module radiation_ray.f90 for a more
!  sophisticated approach.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lradiation = .true.
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 4
!
!***************************************************************
module Radiation
!
  use Cparam
  use Messages
  use General, only: keep_compiler_quiet
!
  implicit none
!
  include 'radiation.h'
!
  real :: c_gam=100
  real :: opas=1e-8
  real :: mbar=1.  !mbar*m_unit in to not get to big numbers
  real :: k_B_radiation=1.      !k_B*m_unit in to not get to big numbers
  real :: a_SB=1.
  real :: kappa_es_radiation=0
  real :: amplee=0
  real :: ampl_pert=0
  real :: inflow=2
  real, dimension(mx,my,mz) :: DFF_new=0. ! Nils, do we need to initialize here?
                                          ! this makes compilation much slower
!
  character (len=labellen) :: initrad='equil',pertee='none'
  character (len=labellen) :: flim='LP'
!
  namelist /radiation_init_pars/ &
       initrad,c_gam,opas,kappa_es_radiation,mbar,k_B_radiation,a_SB,amplee,pertee,ampl_pert
!
  namelist /radiation_run_pars/ &
       c_gam,opas,kappa_es_radiation,mbar,k_B_radiation,a_SB,flim,inflow
!
! other variables (needs to be consistent with reset list below)
!
  integer :: idiag_frms=0,idiag_fmax=0,idiag_Erad_rms=0,idiag_Erad_max=0
  integer :: idiag_Egas_rms=0,idiag_Egas_max=0
!
  contains
!***********************************************************************
    subroutine register_radiation()
!
!  Initialise variables which should know that we solve for the vector
!  potential: iaa, etc; increase nvar accordingly
!
!  15-jul-02/nils: coded
!
      use Cdata
      use Mpicomm
      use Sub
      use FArrayManager
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_rad called twice')
      first = .false.
!
      lradiation_fld = .true.
!
      call farray_register_pde('Erad',iErad)
      call farray_register_auxiliary('KR_FRad',iKR_Frad,vector=3)
      iKR_Fradx = iKR_Frad
      iKR_Frady = iKR_Frad+1
      iKR_Fradz = iKR_Frad+2
!
      call farray_register_auxiliary('dd',idd)
!
      if ((ip<=8) .and. lroot) then
        print*, 'Register_rad:  nvar = ', nvar
        print*, 'iErad,iKR_Frad,iKR_Fradx,iKR_Frady,iKR_Fradz = ', iErad,iKR_Frad,iKR_Fradx,iKR_Frady,iKR_Fradz
      endif
!
!  Put variable names in array
!
      varname(iErad)  = 'Erad'
      varname(iKR_Fradx) = 'fx'
      varname(iKR_Frady) = 'fy'
      varname(iKR_Fradz) = 'fz'
!
!  Identify version number (generated automatically by SVN).
!
      if (lroot) call svn_id( &
           "$Id$")
!
    endsubroutine register_radiation
!***********************************************************************
    subroutine radtransfer(f)
!
!  Integration radioation transfer equation along rays
!
!  24-mar-03/axel+tobi: coded
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call keep_compiler_quiet(f)
!
   endsubroutine radtransfer
!***********************************************************************
    subroutine initialize_radiation()
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  24-nov-02/tony: coded 
!
!  do nothing
!
    endsubroutine initialize_radiation
!***********************************************************************
    subroutine radiative_cooling(f,df,p)
!
!  dummy routine
!
! 25-mar-03/axel+tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine radiative_cooling
!***********************************************************************
    subroutine radiative_pressure(f,df,p)
! 
!  dummy routine
! 
!  25-mar-03/axel+tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine radiative_pressure
!***********************************************************************
    subroutine init_rad(f)!,xx,yy,zz)
!
!  initialise radiation; called from start.f90
!  We have an init parameter (initrad) to stear radiation i.c. independently.
!
!   15-jul-2002/nils: coded
!
      use Cdata
      use Mpicomm
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mfarray) :: f
      !real, dimension (mx,my,mz)      :: xx,yy,zz
      real :: nr1,nr2
      integer :: l12
!
      select case (initrad)

      case ('zero', '0') 
         f(:,:,:,iKR_Fradx:iKR_Fradz) = 0.
         f(:,:,:,iErad     ) = 1.
      case ('gaussian-noise','1'); call gaunoise(amplee,f,iErad)
      case ('equil','2'); call init_equil(f)
      !case ('cos', '3')
      !   f(:,:,:,ie) = -amplee*(cos(sqrt(3.)*0.5*xx)*(xx-Lx/2)*(xx+Lx/2)-1)
      case ('step', '4')
         l12=(l1+l2)/2
         f(1    :l12,:,:,iErad) = 1.
         f(l12+1: mx,:,:,iErad) = 2.
      case ('substep', '5')
         l12=(l1+l2)/2
         nr1=1.
         nr2=2.
         f(1    :l12-2,:,:,iErad) = nr1
         f(l12-1      ,:,:,iErad) = ((nr1+nr2)/2+nr1)/2
         f(l12+0      ,:,:,iErad) = (nr1+nr2)/2
         f(l12+1      ,:,:,iErad) = ((nr1+nr2)/2+nr2)/2
         f(l12+2: mx  ,:,:,iErad) = nr2
      !case ('lamb', '6')
      !   f(:,:,:,iErad) = 2+(sin(2*pi*xx)*sin(2*pi*zz))
      case default
        !
        !  Catch unknown values
        !
        if (lroot) print*, 'No such value for initrad: ', trim(initrad)
        call stop_it("")
      endselect
!
!  Pertubations
!
      select case (pertee)
         
      case ('none', '0') 
      case ('left','1')
         l12=(l1+l2)/2
         f(l1:l12,m1:m2,n1:n2,iErad) = ampl_pert*f(l1:l12,m1:m2,n1:n2,iErad)
      case ('whole','2')
         f(:,m1:m2,n1:n2,iErad) = ampl_pert*f(:,m1:m2,n1:n2,iErad)
      case ('ent','3') 
         !
         !  For perturbing the entropy after haveing found the 
         !  equilibrium between radiation and entropy.
         !
         f(:,m1:m2,n1:n2,iss) = ampl_pert
         f(:,m1:m2,n1:n2,ilnrho) = ampl_pert
      case default
         !
         !  Catch unknown values
         !
         if (lroot) print*, 'No such value for pertee: ', trim(pertee)
         call stop_it("")
         
      endselect
!
    endsubroutine init_rad
!***********************************************************************
    subroutine pencil_criteria_radiation()
! 
!  All pencils that the Radiation module depends on are specified here.
! 
!  21-11-04/anders: coded
!
      lpenc_requested(i_uu)=.true.
      lpenc_requested(i_divu)=.true.
      lpenc_requested(i_uij)=.true.
      lpenc_requested(i_rho)=.true.
      lpenc_requested(i_rho1)=.true.
      if (lentropy) lpenc_requested(i_TT1)=.true.
!
    endsubroutine pencil_criteria_radiation
!***********************************************************************
    subroutine pencil_interdep_radiation(lpencil_in)
!
!  Interdependency among pencils provided by the Radiation module
!  is specified here.
!
!  21-11-04/anders: coded
! 
      logical, dimension (npencils) :: lpencil_in
! 
      call keep_compiler_quiet(lpencil_in)
! 
    endsubroutine pencil_interdep_radiation
!***********************************************************************
    subroutine calc_pencils_radiation(f,p)
!   
!  Calculate Radiation pencils
!  Most basic pencils should come first, as others may depend on them.
! 
!  21-11-04/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!      
      intent(in) :: f,p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
! 
    endsubroutine calc_pencils_radiation
!********************************************************************
    subroutine de_dt(f,df,p,gamma)
!
!
!  13-Dec-01/nils: coded
!  15-Jul-02/nils: adapted from pencil_mpi
!  30-Jul-02/nils: moved calculation of 1. and 2. moment to other routine
!
      use Sub
      use Cdata
      use Mpicomm
      use Diagnostics
      use Deriv
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension (nx,3) :: gradE
      real, dimension (nx,3,3) :: P_tens
      real, dimension (nx) :: E_rad,source,Edivu,ugradE,divF
      real, dimension (nx) :: graduP,cooling,c_entr
      real, dimension (nx) :: kappa_abs,kappa,E_gas,f2,divF2
      real :: gamma_m1,gamma,taux
      integer :: i
!
      intent(in) :: f,p
      intent(out) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'SOLVE dee_dt'
!
!  some abbreviations and physical quantities
!
!      if (.NOT. ldensity) rho1=1  ! now set in equ.f90
      gamma_m1=gamma-1
      E_rad=f(l1:l2,m,n,iErad)
      if (lentropy) then
         E_gas=1.5*k_B_radiation/(p%rho1*mbar*p%TT1)
         kappa_abs=opas*p%rho**(9./2)*E_gas**(-7./2)
         source=a_SB*p%TT1**(-4)
         kappa=kappa_abs+kappa_es_radiation
         cooling=(source-E_rad)*c_gam*kappa_abs*p%rho
      else
         kappa=kappa_es_radiation
         cooling=0
      endif
!
!  calculating some values needed for momentum equation
!
      Edivu=E_rad*p%divu
      call grad(f,iErad,gradE)
      call dot_mn(p%uu,gradE,ugradE)
      call div(f,iKR_Frad,divF)
!
!  Flux-limited diffusion app.
!
      call flux_limiter(f,df,p%rho1,kappa,gradE,E_rad,P_tens,divF2)
!
!  calculate graduP
!
      call multmm_sc(P_tens,p%uij,graduP)
!
!  calculate dE/dt
!
      df(l1:l2,m,n,iErad)=df(l1:l2,m,n,iErad)-ugradE-Edivu-divF-graduP+cooling
!
!  add (kappa F)/c to momentum equation
!
      if (lhydro) then
         df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)+kappa*f(l1:l2,m,n,iKR_Frady)/c_gam
         df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)+kappa*f(l1:l2,m,n,iKR_Frady)/c_gam
         df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)+kappa*f(l1:l2,m,n,iKR_Fradz)/c_gam
      endif
!
!  add cooling to entropy equation
!
      if (lentropy) then
        df(l1:l2,m,n,iss)=df(l1:l2,m,n,iss)-(source-E_rad)*kappa_abs*c_gam*p%TT1
      endif
!
!  optical depth in x-dir.
!
      if (headtt.or.ldebug) then
         taux=0
         do i=1,nx
            taux=taux+dx*kappa(i)*p%rho(i)
         end do
         print*,'Optical depth in x direction is:',taux
      end if
!
!  Calculate diagnostic values
!
      if (ldiagnos) then
        f2=f(l1:l2,m,n,iKR_Fradx)**2+f(l1:l2,m,n,iKR_Frady)**2+f(l1:l2,m,n,iKR_Fradz)**2
        if (headtt.or.ldebug) print*,'Calculate maxima and rms values...'
        if (idiag_frms/=0) call sum_mn_name(f2,idiag_frms,lsqrt=.true.)
        if (idiag_fmax/=0) call max_mn_name(f2,idiag_fmax,lsqrt=.true.)
        if (idiag_erad_rms/=0) call sum_mn_name(E_rad,idiag_erad_rms)
        if (idiag_erad_max/=0) call max_mn_name(E_rad,idiag_erad_max)
        if (idiag_egas_rms/=0) call sum_mn_name(E_gas,idiag_egas_rms)
        if (idiag_egas_max/=0) call max_mn_name(E_gas,idiag_egas_max)   
      endif
!
!  Calculate UUmax for use in determination of time step 
!
      if (lfirst.and.ldt) then
         !
         !  Speed of sound
         !
         advec_crad2=c_gam
         !
         !  Adding extra time step criterion due to the stiffness in the 
         !  radiative entropy equation
         !
         if (lentropy) then
            c_entr=2*gamma_m1**4*p%rho1**(4*gamma_m1)/(p%TT1*c_gam*kappa_abs*a_SB*4*gamma)
            c_entr=dxmin/c_entr
            advec_crad2=max(advec_crad2,maxval(c_entr))
         endif
      endif
!
    end subroutine de_dt
!***********************************************************************
    subroutine read_radiation_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=radiation_init_pars, IOSTAT=iostat)
!
    endsubroutine read_radiation_init_pars
!***********************************************************************
    subroutine write_radiation_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=radiation_init_pars)
!
    endsubroutine write_radiation_init_pars
!***********************************************************************
    subroutine read_radiation_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=radiation_run_pars, IOSTAT=iostat)
!
    endsubroutine read_radiation_run_pars
!***********************************************************************
    subroutine write_radiation_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=radiation_run_pars)
!
    endsubroutine write_radiation_run_pars
!***********************************************************************
    subroutine rprint_radiation(lreset,lwrite)
!
!  reads and registers print parameters relevant for radiative part
!
!  16-jul-02/nils: adapted from rprint_hydro
!
      use Cdata
      use Diagnostics
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
        idiag_frms=0; idiag_fmax=0; idiag_Erad_rms=0; idiag_Erad_max=0
        idiag_Egas_rms=0; idiag_Egas_max=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if(lroot.and.ip<14) print*,'run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'frms',idiag_frms)
        call parse_name(iname,cname(iname),cform(iname),'fmax',idiag_fmax)
        call parse_name(iname,cname(iname),cform(iname),&
            'Erad_rms',idiag_Erad_rms)
        call parse_name(iname,cname(iname),cform(iname),&
            'Erad_max',idiag_Erad_max)
        call parse_name(iname,cname(iname),cform(iname),&
            'Egas_rms',idiag_Egas_rms)
        call parse_name(iname,cname(iname),cform(iname),&
            'Egas_max',idiag_Egas_max)
      enddo
!
!  write column where which radiative variable is stored
!
      if (lwr) then
        call farray_index_append('i_frms',idiag_frms)
        call farray_index_append('i_fmax',idiag_fmax)
        call farray_index_append('i_Erad_rms',idiag_Erad_rms)
        call farray_index_append('i_Erad_max',idiag_Erad_max)
        call farray_index_append('i_Egas_rms',idiag_Egas_rms)
        call farray_index_append('i_Egas_max',idiag_Egas_max)
        call farray_index_append('nname',nname)
        call farray_index_append('iErad',iErad)
        call farray_index_append('iKR_Fradx',iKR_Fradx)
        call farray_index_append('iKR_Frady',iKR_Frady)
        call farray_index_append('iKR_Fradz',iKR_Fradz)
      endif
!
    endsubroutine rprint_radiation
!***********************************************************************
    subroutine get_slices_radiation(f,slices)
!
!  Write slices for animation of radiation variables.
!
!  26-jun-06/tony: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(slices)
!
    endsubroutine get_slices_radiation
!***********************************************************************
    subroutine flux_limiter(f,df,rho1,kappa,gradE,E_rad,P_tens,divF)
!
!  This subroutine uses the flux limited diffusion approximation
!  and calculates the flux limiter and P_tens
!
!  30-jul-02/nils: coded
!
      use Sub
      use Cdata
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3) :: gradE,n_vec,tmp,gradDFF
      real, dimension (nx,3,3) :: P_tens,f_mat,n_mat
      real, dimension (nx) :: E_rad,rho1,diffus_speed
      real, dimension (nx) :: lgamma,RF,DFF,absgradE,var1
      real, dimension (nx) :: f_sc,kappa,divF,del2E
      integer :: i,j,teller
!
      call dot2_mn(gradE,absgradE)
      lgamma=rho1/kappa
      absgradE=sqrt(absgradE)
      if (flim=='tanhr') then
         RF=lgamma*absgradE/E_rad
         DFF=(1./tanh(RF)-1./RF)/RF
      elseif (flim=='simple') then
         RF=lgamma*absgradE/E_rad
         DFF=(9+RF**2)**(-0.5)
      elseif (flim=='Eddington') then
         DFF=1./3.
      elseif (flim=='LP') then
         RF=lgamma*absgradE/E_rad
         DFF=(2+RF)/(6+3*RF+RF**2)
      elseif (flim=='Minerbo') then
         RF=lgamma*absgradE/E_rad
         do i=1,nx
            if (RF(i)<1.5) then 
               DFF(i)=2/(3+sqrt(9+12*RF(i)**2))
            else 
               DFF(i)=1./(1+RF(i)+sqrt(1+2*RF(i)))
            endif
         enddo
      else
         print*,'There are no such flux-limiter:', flim
      end if
      f_sc=DFF+DFF**2*RF**2
      call multvs(gradE,1./absgradE,n_vec)
      call multvv_mat(n_vec,n_vec,n_mat)
!
!  calculate P_tens
!
      f_mat=0
      do i=1,3
         f_mat(:,i,i)=0.5*(1-f_sc)
      end do
      do i=1,3
         do j=1,3
            f_mat(:,i,j)=f_mat(:,i,j)+0.5*(3*f_sc-1)*n_mat(:,i,j)
         end do
      end do
      do i=1,3
         do j=1,3
            P_tens(:,i,j)=E_rad*f_mat(:,i,j)
         enddo
      enddo
      do teller=1,nx
         if (absgradE(teller)==0) then !Uniform rad. density
            do i=1,3
               do j=1,3
                  P_tens(teller,i,j)=0
                  if (j==i) P_tens(teller,i,i)=E_rad(teller)/3.
               enddo
            enddo
         endif
      enddo
!
!  calculate the flux
!
      call multvs(gradE,-DFF*rho1*c_gam/kappa,tmp)
      f(l1:l2,m,n,iKR_Fradx:iKR_Fradz)=tmp
!
      DFF_new(l1:l2,m,n)=DFF*c_gam*rho1/kappa
      call grad(f,idd,gradDFF) 
      call del2(f,iErad,del2E)
      call dot_mn(gradDFF,gradE,var1)
      divF=-f(l1:l2,m,n,idd)*del2E-var1
!
!  Time step criterion due to diffusion
!
      diffus_speed=4*c_gam*rho1*DFF/(3*kappa*dxmin)
      diffus_chi=max(diffus_chi,maxval(diffus_speed))
!
    end subroutine flux_limiter
!***********************************************************************
    subroutine init_equil(f)
!
!  Routine for calculating equilibrium solution of radiation
!  This routine is now outdated and doen't include cp /= 1.
!
!  18-jul-02/nils: coded
!
      use Cdata
      use EquationOfState, only:cs20,lnrho0,gamma
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx) :: cs2,lnrho,gamma_m1,TT1,source
      integer :: i,j
!
      gamma_m1=gamma-1
      do i=1,my
         do j=1,mz
            lnrho=f(:,i,j,ilnrho)
            cs2=cs20*exp(gamma_m1*(lnrho-lnrho0)+gamma*f(:,i,j,iss))
            TT1=gamma_m1/cs2
            source=a_SB*TT1**(-4)
            f(:,i,j,iErad) = source
         enddo
      enddo
!
    end subroutine init_equil
!***********************************************************************
    subroutine  bc_ee_inflow_x(f,topbot)
!
!  The inflow boundary condition must be improved,
!  it do not work correctly in this simple form
!
!  8-aug-02/nils: coded
!
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i
!
      if (topbot=='bot') then
         !f(1:l1-1,:,:,iErad) = inflow
         do i=1,nghost
            f(l1-i,:,:,iErad) = 2*inflow - f(l1+i,:,:,iErad)
         enddo
      else
         !f(l2+1:mx,:,:,iErad) = inflow
         do i=1,nghost
            f(l2+i,:,:,iErad) = 2*inflow - f(l2-i,:,:,iErad)
         enddo
      endif
!
    end subroutine bc_ee_inflow_x
!***********************************************************************
    subroutine  bc_ee_outflow_x(f,topbot)
!
!  The outflow boundary condition must be improved,
!  it do not work correctly in this simple form
!
!  8-aug-02/nils: coded
!
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i
!
      if (topbot=='bot') then 
         do i=1,nghost
           ! f(i,:,:,iErad) = 1 
            f(l1-i,:,:,iErad) = 2*f(l1,:,:,iErad) - f(l1+i,:,:,iErad)  
         enddo
      else
         do i=1,nghost
            !f(l2+i,:,:,iErad) =  1
            f(l2+i,:,:,iErad) = 2*f(l2,:,:,iErad) - f(l2-i,:,:,iErad) 
         enddo
      endif
!
    end subroutine bc_ee_outflow_x
!***********************************************************************
endmodule Radiation





! $Id$
!
! MODULE_DOC: Runge-Kutta time advance, accurate to order itorder.
! MODULE_DOC: At the moment, itorder can be 1, 2, or 3.
!
module Timestep
!
  use Cparam
  use Cdata
!
  implicit none
!
  private
!
  include 'timestep.h'
!
  contains
!***********************************************************************
    subroutine initialize_timestep
!
!  Coefficients for up to order 3.

      use Messages, only: fatal_error
      use General, only: itoa
!
      if (itorder==1) then
        alpha_ts=(/ 0.0, 0.0, 0.0 /)
        beta_ts =(/ 1.0, 0.0, 0.0 /)
      elseif (itorder==2) then
        alpha_ts=(/   0.0, -1/2.0, 0.0 /)
        beta_ts =(/ 1/2.0,    1.0, 0.0 /)
      elseif (itorder==3) then
        !alpha_ts=(/   0.0, -2/3.0, -1.0   /)
        !beta_ts =(/ 1/3.0,    1.0,  1/2.0 /)
        !  use coefficients of Williamson (1980)
        alpha_ts=(/   0.0, -5/9.0 , -153/128.0 /)
        beta_ts =(/ 1/3.0, 15/16.0,    8/15.0  /)
      else
        call fatal_error('initialize_timestep','Not implemented: itorder= '// &
                         trim(itoa(itorder)))
      endif

    endsubroutine initialize_timestep
!***********************************************************************
    subroutine time_step(f,df,p)
!
!   2-apr-01/axel: coded
!  14-sep-01/axel: moved itorder to cdata
!
      use Boundcond, only: update_ghosts
      use BorderProfiles, only: border_quenching
      use Equ, only: pde, impose_floors_ceilings
      use Mpicomm, only: mpiallreduce_max, MPI_COMM_WORLD
      use Particles_main, only: particles_timestep_first, &
          particles_timestep_second
      use PointMasses, only: pointmasses_timestep_first, &
          pointmasses_timestep_second
      use Solid_Cells, only: solid_cells_timestep_first, &
          solid_cells_timestep_second
      use Shear, only: advance_shear
      use Sub, only: set_dt, shift_dt
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: ds, dtsub
!
!  dt_beta_ts may be needed in other modules (like Dustdensity) for fixed dt.
!
      if (.not. ldt) dt_beta_ts=dt*beta_ts
!
!  Set up df and ds for each time sub.
!
      do itsub=1,itorder

        lfirst=(itsub==1)
        llast=(itsub==itorder)
        if (lfirst) then
          if (.not.lgpu) df=0.0
          ds=0.0
        else
          if (.not.lgpu) df=alpha_ts(itsub)*df !(could be subsumed into pde, but is dangerous!)
          ds=alpha_ts(itsub)*ds
        endif
!
!  Set up particle derivative array.
!
        if (lparticles) call particles_timestep_first(f)
!
!  Set up point masses derivative array
!
        if (lpointmasses) call pointmasses_timestep_first(f)
!
!  Set up solid_cells time advance
!
        if (lsolid_cells) call solid_cells_timestep_first(f)
!
!  Change df according to the chosen physics modules.
!
        call pde(f,df,p,itsub)
        ds=ds+1.0
!
!  If we are in the first time substep we need to calculate timestep dt.
!  Takes minimum over and distributes to all processors.
!  With GPUs this is done on the CUDA side.
!
        if (lfirst.and.ldt.and..not.lgpu) call set_dt(maxval(dt1_max))
!
!  Calculate dt_beta_ts.
!
        if (ldt) dt_beta_ts=dt*beta_ts
        if (ip<=6) print*, 'time_step: iproc, dt=', iproc_world, dt  !(all have same dt?)
        dtsub = ds * dt_beta_ts(itsub)
!
!  Apply border quenching.
!
        if (lborder_profiles) call border_quenching(f,df,dt_beta_ts(itsub))
!
!  Time evolution of grid variables.
!
        if (.not. lgpu) f(l1:l2,m1:m2,n1:n2,1:mvar) =  f(l1:l2,m1:m2,n1:n2,1:mvar) &
                                                     + dt_beta_ts(itsub)*df(l1:l2,m1:m2,n1:n2,1:mvar)
!
!  Time evolution of point masses.
!
        if (lpointmasses) call pointmasses_timestep_second(f)
!
!  Time evolution of particle variables.
!
        if (lparticles) call particles_timestep_second(f)
!
!  Time evolution of solid_cells.
!
        if (lsolid_cells) call solid_cells_timestep_second(f,dt_beta_ts(itsub),ds)
!
!  Advance deltay of the shear (and, optionally, perform shear advection
!  by shifting all variables and their derivatives).
!
        advec: if (lshear) then
          call impose_floors_ceilings(f)
          call update_ghosts(f)  ! Necessary for non-FFT advection but unnecessarily overloading FFT advection
          call advance_shear(f, df, dtsub)
        endif advec
!
        call update_after_timestep(f,df,dtsub,llast)
!
!  Increase time.
!
        t = t + dtsub
!
      enddo
!
!  Integrate operator split terms.
!
      call split_update(f)
!
    endsubroutine time_step
!***********************************************************************
    subroutine split_update(f)
!
!  Integrate operator split terms.
!
!  14-dec-14/ccyang: coded
!
      use Density, only: split_update_density
      use Energy, only: split_update_energy
      use Magnetic, only: split_update_magnetic
      use Viscosity, only: split_update_viscosity
      use Particles_main, only: split_update_particles
!
      real, dimension(mx,my,mz,mfarray), intent(inout) :: f
!
!  Dispatch to respective modules.
!
      if (ldensity) call split_update_density(f)
      if (lenergy) call split_update_energy(f)
      if (lmagnetic) call split_update_magnetic(f)
      if (lviscosity) call split_update_viscosity(f)
!
      if (lparticles) call split_update_particles(f, dt)
!
    endsubroutine split_update
!***********************************************************************
    subroutine update_after_timestep(f,df,dtsub,llast)
!
!   Hooks for modifying f and df after the timestep is performed.
!
!  12-03-17/wlyra: coded
!  28-03-17/MR: removed update_ghosts; checks for already communicated variables enabled.
!
      use Density,  only: density_after_timestep
      use Hydro,    only: hydro_after_timestep
      use Energy,   only: energy_after_timestep
      use Magnetic, only: magnetic_after_timestep
      use Special,  only: special_after_timestep
      use Particles_main, only: particles_special_after_dtsub
!
      logical, intent(in) :: llast
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real :: dtsub
!
!  Enables checks to avoid unnecessary communication
!
      ighosts_updated=0       
!     
!  Dispatch to respective modules. The module which communicates 
!  the biggest number of variables should come first here.
!
      if (lhydro)    call hydro_after_timestep   (f,df,dtsub)
      if (lmagnetic) call magnetic_after_timestep(f,df,dtsub)
      if (lenergy)   call energy_after_timestep  (f,df,dtsub)
      if (ldensity)  call density_after_timestep (f,df,dtsub)
      if (lspecial) then
        call special_after_timestep(f, df, dtsub, llast)
        if (lparticles) call particles_special_after_dtsub(f, dtsub)
      endif
!
!  Disables checks.
!
      ighosts_updated=-1
!
    endsubroutine update_after_timestep
!***********************************************************************
    subroutine pushpars2c(p_par)

    integer, parameter :: n_pars=2
    integer(KIND=ikind8), dimension(n_pars) :: p_par

    call copy_addr_c(alpha_ts,p_par(1))  ! (3)
    call copy_addr_c(beta_ts ,p_par(2))  ! (3)

    endsubroutine pushpars2c
!***********************************************************************      
endmodule Timestep

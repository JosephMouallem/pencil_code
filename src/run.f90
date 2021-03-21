! $Id$
!
!***********************************************************************
!
!  The Pencil Code is a high-order finite-difference code for compressible
!  hydrodynamic flows with magnetic fields and particles. It is highly
!  modular and can easily be adapted to different types of problems.
!
!      MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
!      MMMMMMM7MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
!      MMMMMMMIMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
!      MMMMMMMIIMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
!      MMMMMMM7IMMMMMMMMMMMMMMMMMMM7IMMMMMMMMMMMMMMMMMMMMDMMMMMMM
!      MMMMMMZIIMMMMMMMMMMMMMMMMMMMIIMMMMMMMMMMMMMMMMMMMMIMMMMMMM
!      MMMMMMIIIZMMMMMMMMMMMMMMMMMMIIMMMMMMMMMMMMMMMMMMMMIMMMMMMM
!      MMMMMMIIIIMMMMMMMMMMMMMMMMMNII$MMMMMMMMMMMMMMMMMM$IMMMMMMM
!      MMMMM8IIIIMMMMMMMMMMMMMMMMM$IIIMMMMMMMMMMMMMMMMMMII7MMMMMM
!      MMMMMD7II7MMMMMMMMMMMMMMMMMIIIIMMMMMMMMMMMMMMMMMMIIIMMMMMM
!      MMMMN..:~=ZMMMMMMMMMMMMMMMMIIIIDMMMMMMMMMMMMMMMMDIIIMMMMMM
!      MMMM8.,:~=?MMMMMMMMMMMMMMMMOII7NMMMMMMMMMMMMMMMMZIIIDMMMMM
!      MMMM. ,::=+MMMMMMMMMMMMMMM..,~=?MMMMMMMMMMMMMMMMIIII$MMMMM
!      MMMM..,:~=+MMMMMMMMMMMMMM8 .,~=+DMMMMMMMMMMMMMMM8II78MMMMM
!      MMMM .,:~==?MMMMMMMMMMMMMN .,~=+NMMMMMMMMMMMMMM8 ,~~+MMMMM
!      MMM7  ,:~+=?MMMMMMMMMMMMM  .,~==?MMMMMMMMMMMMMM..,~~+DMMMM
!      MMM.  ,:~==?MMMMMMMMMMMMM  .,~~=?MMMMMMMMMMMMMM. ,~~+?MMMM
!      MMM.  ,:~~=??MMMMMMMMMMMM  ,,~~=?MMMMMMMMMMMMM8 .,~~=?NMMM
!      MMM.  ,:~~=+?MMMMMMMMMMMI  ,,~~=+?MMMMMMMMMMMM. .,~~=?MMMM
!      MM~. .,:~:==?MMMMMMMMMMM   ,,~~==?MMMMMMMMMMMM  .,~~=+?MMM
!      MMN8 .D,D+=M=8MMMMMMMMMM   ,,~~==?MMMMMMMMMMMM. .,~~==?MMM
!      MM==8.   .8===MMMMMMMMMM  .,,~~==?$MMMMMMMMMM=  .,~~==?MMM
!      MM==D.    +===MMMMMMMMMO$ .I?7$=7=NMMMMMMMMMM.  ,,~~==?$MM
!      MM==D.    +===MMMMMMMMM==O?..  ====MMMMMMMMMM.  ,,~~==??MM
!      MM==D.    +===MMMMMMMMM===.    .===MMMMMMMMMM+$.?=,7==?7MM
!      MM==D.    +===MMMMMMMMM===.    .===MMMMMMMMMZ==8    .8==MM
!      MM==D.    +===MMMMMMMMM===.    .===MMMMMMMMMZ==I    .Z==MM
!      MM==D. .  +===MMMMMMMMM===.... .===MMMMMMMMMZ==I    .Z==MM
!      MM==D.    +===MMMMMMMMM===.    .===MMMMMMMMMZ==I    .Z==MM
!      MM==D.    +===MMMMMMMMM===.    .===MMMMMMMMMZ==I    .Z==MM
!      MM==D.    +===MMMMMMMMM===..   .===MMMMMMMMMZ==I    .Z==MM
!      MM==D. .  +===MMMMMMMMM===.... .===MMMMMMMMMZ==I    .Z==MM
!
!  More information can be found in the Pencil Code manual and at the
!  website http://www.nordita.org/software/pencil-code/.
!
!***********************************************************************
program run
!
!  8-mar-13/MR: changed calls to wsnap and rsnap to grant reference to f by
!               address
! 31-oct-13/MR: replaced rparam by read_all_init_pars
! 10-feb-14/MR: initialize_mpicomm now called before read_all_run_pars
! 13-feb-13/MR: call of wsnap_down added
!
  use Boundcond,       only: update_ghosts
  use Cdata
  use Chemistry,       only: chemistry_clean_up, write_net_reaction, lchemistry_diag
  use Density,         only: boussinesq
  use Diagnostics
  use Dustdensity,     only: init_nd
  use Dustvelocity,    only: init_uud
  use Equ,             only: debug_imn_arrays,initialize_pencils
  use EquationOfState, only: ioninit,ioncalc
  use FArrayManager,   only: farray_clean_up
  use Filter
  use Fixed_point,     only: fixed_points_prepare, wfixed_points
  use Forcing,         only: forcing_clean_up,addforce
  use General,         only: random_seed_wrapper, touch_file, itoa
  use Grid,            only: construct_grid, box_vol, grid_bound_data, set_coorsys_dimmask, construct_serial_arrays
  use Gpu,             only: gpu_init, register_gpu
  use HDF5_IO,         only: initialize_hdf5
  use Hydro,           only: hydro_clean_up,kinematic_random_phase
  use ImplicitPhysics, only: calc_heatcond_ADI
  use Interstellar,    only: check_SN,addmassflux
  use IO,              only: rgrid, directory_names, rproc_bounds, output_globals, input_globals, wgrid, wdim
  use Magnetic,        only: rescaling_magnetic
  use Messages
  use Mpicomm
  use NSCBC,           only: NSCBC_clean_up
  use Param_IO
  use Particles_main
  use Pencil_check,    only: pencil_consistency_check
  use PointMasses
  use Register
  use SharedVariables, only: sharedvars_clean_up
  use Signal_handling, only: signal_prepare, emergency_stop
  use Slices
  use Snapshot
  use Solid_Cells,     only: solid_cells_clean_up,time_step_ogrid,wsnap_ogrid
  use Special,         only: initialize_mult_special
  use Streamlines,     only: tracers_prepare, wtracers
  use Sub
  use Syscalls,        only: is_nan
  use Testscalar,      only: rescaling_testscalar
  use Testfield,       only: rescaling_testfield
  use TestPerturb,     only: testperturb_begin, testperturb_finalize
  use Timeavg
  use Timestep,        only: time_step, initialize_timestep
!
  implicit none
!
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension (mx,my,mz,mvar) :: df
  type (pencil_case) :: p
  double precision :: time1, time2
  double precision :: time_last_diagnostic, time_this_diagnostic
  real :: wall_clock_time=0.0, time_per_step=0.0
  integer :: icount, i, mvar_in, isave_shift=0
  integer :: it_last_diagnostic, it_this_diagnostic
  logical :: lstop=.false., lsave=.false., timeover=.false., resubmit=.false.
  logical :: suppress_pencil_check=.false.
  logical :: lreload_file=.false., lreload_always_file=.false.
  logical :: lnoreset_tzero=.false.
  logical :: lonemorestep = .false.
!
  lrun = .true.
!
!  Get processor numbers and define whether we are root.
!
  call mpicomm_init
!
!  Initialize GPU use.
!
  call gpu_init
!
!  Identify version.
!
  if (lroot) call svn_id('$Id$')
!
!  Initialize the message subsystem, eg. color setting etc.
!
  call initialize_messages
!
!  Initialize use of multiple special modules.
!
!  call initialize_mult_special
!
!  Define the lenergy logical
!
  lenergy=lentropy.or.ltemperature.or.lthermal_energy
!
!  Read parameters from start.x (set in start.in/default values; possibly overwritten by 'read_all_run_pars').
!
  call read_all_init_pars
!
!  Read parameters and output parameter list.
!
  call read_all_run_pars
!
!  Initialise MPI communication.
!
  call initialize_mpicomm
!
!  Initialise HDF5 communication.
!
  call initialize_hdf5
!
  if (any(downsampl>1) .or. mvar_down>0 .or. maux_down>0) then
!
!  If downsampling, calculate local start indices and number of data in
!  output for each direction; inner ghost zones are here disregarded
!
    ldownsampl = .true.
    if (dsnap_down<=0.) dsnap_down=dsnap
!
    call get_downpars(1,nx,ipx)
    call get_downpars(2,ny,ipy)
    call get_downpars(3,nz,ipz)
!
    if (any(ndown==0)) &
      call fatal_error('run','zero points in processor ' &
                       //trim(itoa(iproc))//' for downsampling')
  endif
!
!  Set up directory names.
!
  call directory_names
!
!  Read coordinates (if luse_oldgrid=T, otherwise regenerate grid).
!  luse_oldgrid=T can be useful if nghost_read_fewer > 0,
!  i.e. if one is changing the order of spatial derivatives.
!  Also write dim.dat (important when reading smaller meshes, for example)
!  luse_oldgrid=.true. by default, and the values written at the end of
!  each var.dat file are ignored anyway and only used for postprocessing.
!
  call set_coorsys_dimmask
!
  if (luse_oldgrid) then
    if (ip<=6.and.lroot) print*, 'reading grid coordinates'
    call rgrid('grid.dat')
    call construct_serial_arrays
    call grid_bound_data
  else
    if (luse_xyz1) Lxyz = xyz1-xyz0
    call construct_grid(x,y,z,dx,dy,dz)
  endif
!
!  Shorthands (global).
!
  x0 = xyz0(1) ; y0 = xyz0(2) ; z0 = xyz0(3)
  Lx = Lxyz(1) ; Ly = Lxyz(2) ; Lz = Lxyz(3)
!  
!  Size of box at local processor. The if-statement is for
!  backward compatibility.
!
  if (lequidist(1)) then
    Lxyz_loc(1) = Lxyz(1)/nprocx
    xyz0_loc(1) = xyz0(1)+ipx*Lxyz_loc(1)
    xyz1_loc(1) = xyz0_loc(1)+Lxyz_loc(1)
  else
    !
    !  In the equidistant grid, the processor boundaries (xyz[01]_loc) do NOT
    !  coincide with the l[mn]1[2] points. Also, xyz0_loc[ipx+1]=xyz1_loc[ipx], i.e.,
    !  the inner boundary of one is exactly the outer boundary of the other. Reproduce
    !  this behavior also for non-equidistant grids.
    !
    if (ipx==0) then
      xyz0_loc(1) = x(l1)
    else
      xyz0_loc(1) = x(l1) - .5/dx_1(l1)
    endif
    if (ipx==nprocx-1) then
      xyz1_loc(1) = x(l2)
    else
      xyz1_loc(1) = x(l2+1) - .5/dx_1(l2+1)
    endif
    Lxyz_loc(1) = xyz1_loc(1) - xyz0_loc(1)
  endif
!
  if (lequidist(2)) then
    Lxyz_loc(2) = Lxyz(2)/nprocy
    xyz0_loc(2) = xyz0(2)+ipy*Lxyz_loc(2)
    xyz1_loc(2) = xyz0_loc(2)+Lxyz_loc(2)
  else
    if (ipy==0) then
      xyz0_loc(2) = y(m1)
    else
      xyz0_loc(2) = y(m1) - .5/dy_1(m1)
    endif
    if (ipy==nprocy-1) then
      xyz1_loc(2) = y(m2)
    else
      xyz1_loc(2) = y(m2+1) - .5/dy_1(m2+1)
    endif
    Lxyz_loc(2) = xyz1_loc(2) - xyz0_loc(2)
  endif
!
  if (lequidist(3)) then 
    Lxyz_loc(3) = Lxyz(3)/nprocz
    xyz0_loc(3) = xyz0(3)+ipz*Lxyz_loc(3)
    xyz1_loc(3) = xyz0_loc(3)+Lxyz_loc(3)
  else
    if (ipz==0) then
      xyz0_loc(3) = z(n1) 
    else
      xyz0_loc(3) = z(n1) - .5/dz_1(n1)
    endif
    if (ipz==nprocz-1) then
      xyz1_loc(3) = z(n2)
    else
      xyz1_loc(3) = z(n2+1) - .5/dz_1(n2+1)
    endif
    Lxyz_loc(3) = xyz1_loc(3) - xyz0_loc(3)
  endif
!
!  Register physics modules.
!
  call register_modules
  if (lparticles) call particles_register_modules
!
  call register_gpu(f) 
!
!  Only after register it is possible to write the correct dim.dat
!  file with the correct number of variables
!
  if (.not.luse_oldgrid) then
    call wgrid('grid.dat')
    call wdim('dim.dat')
    if (ip<11) print*,'Lz=',Lz
    if (ip<11) print*,'z=',z
  elseif (lwrite_dim_again) then
    call wdim('dim.dat')
    if (ip<11) print*,'Lz=',Lz
    if (ip<11) print*,'z=',z
  endif
!
!  Inform about verbose level.
!
  if (lroot) print*, 'The verbose level is ip=', ip, ' (ldebug=', ldebug, ')'
!
!  Populate wavenumber arrays for fft and calculate Nyquist wavenumber.
!
  if (nxgrid/=1) then
    kx_fft=cshift((/(i-(nxgrid+1)/2,i=0,nxgrid-1)/),+(nxgrid+1)/2)*2*pi/Lx
    kx_fft2=kx_fft**2
    kx_nyq=nxgrid/2 * 2*pi/Lx
  else
    kx_fft=0.0
    kx_nyq=0.0
  endif
!
  if (nygrid/=1) then
    ky_fft=cshift((/(i-(nygrid+1)/2,i=0,nygrid-1)/),+(nygrid+1)/2)*2*pi/Ly
    ky_fft2=ky_fft**2
    ky_nyq=nygrid/2 * 2*pi/Ly
  else
    ky_fft=0.0
    ky_nyq=0.0
  endif
!
  if (nzgrid/=1) then
    kz_fft=cshift((/(i-(nzgrid+1)/2,i=0,nzgrid-1)/),+(nzgrid+1)/2)*2*pi/Lz
    kz_fft2=kz_fft**2
    kz_nyq=nzgrid/2 * 2*pi/Lz
  else
    kz_fft=0.0
    kz_nyq=0.0
  endif
!
!  Position of equator (if any).
!
  if (lequatory) yequator=xyz0(2)+0.5*Lxyz(2)
  if (lequatorz) zequator=xyz0(3)+0.5*Lxyz(3)
!
!  Print resolution and dimension of the simulation.
!
  if (lroot) then
    write(*,'(a,i1,a)') ' This is a ', dimensionality, '-D run'
    print*, 'nxgrid, nygrid, nzgrid=', nxgrid, nygrid, nzgrid
    print*, 'Lx, Ly, Lz=', Lxyz
    call box_vol
    if (lyinyang) then
      print*, '      Vbox(Yin,Yang)=', box_volume
      print*, '      total volume  =', 4./3.*pi*(xyz1(1)**3-xyz0(1)**3)
    else
      print*, '      Vbox=', box_volume
    endif
  endif
!
!  Limits to xaveraging.
!
  if (lav_smallx) call init_xaver
!
!  Inner radius for freezing variables defaults to r_min.
!  Note: currently (July 2005), hydro.f90 uses a different approach:
!  r_int will override rdampint, which doesn't seem to make much sense (if
!  you want rdampint to be overridden, then don't specify it in the first
!  place).
!
  if (rfreeze_int==-impossible .and. r_int>epsi) rfreeze_int=r_int
  if (rfreeze_ext==-impossible) rfreeze_ext=r_ext
!
!  Will we write all slots of f?
!
  if (lwrite_aux) then
    mvar_io=mvar+maux
  else
    mvar_io=mvar
  endif
!
!  set slots to be written in downsampled f if 0 use mvar_io
!
  if (ldownsampl) then
    if (mvar_down<0) mvar_down=mvar
    if (maux_down<0) maux_down=maux
    if (mvar_down+maux_down==0) ldownsampl=.false.
  endif
!
! Shall we read also auxiliary variables or fewer variables (ex: turbulence
! field with 0 species as an input file for a chemistry problem)?
!
  if (lread_aux) then
    mvar_in=mvar+maux
  else if (lread_less) then
    mvar_in=4
  else
    mvar_in=mvar
  endif
!
!  Get state length of random number generator and put the default value.
!  With lreset_seed (which is not the default) we can reset the seed during
!  the run. This is necessary when lreinitialize_uu=T, inituu='gaussian-noise'.
!
  if (lreset_seed) then
    seed(1)=-((seed0-1812+1)*10+iproc_world)
    call random_seed_wrapper(PUT=seed)
  else
    call get_nseed(nseed)
    call random_seed_wrapper (GET=seed)
    seed = seed0
    call random_seed_wrapper (PUT=seed)
  endif
!
!  Write particle block dimensions to file (may have been changed for better
!  load balancing).
!
  if (lroot) then
    if (lparticles) call particles_write_block(trim(datadir)//'/bdim.dat')
  endif
!
!  Read data.
!  Snapshot data are saved in the data subdirectory.
!  This directory must exist, but may be linked to another disk.
!  If we decided to use a new grid, we need to overwrite the data
!  that we just read in from var.dat. (Note that grid information
!  was also used above, so we really need to do it twice then.)
!
  f=0.
  call rsnap('var.dat',f,mvar_in,lread_nogrid)
!
  if (.not.luse_oldgrid) call construct_grid(x,y,z,dx,dy,dz) !MR: already called
!
!  Call rprint_list to initialize diagnostics and write indices to file.
!
  call rprint_list(LRESET=.false.)
  if (lparticles) call particles_rprint_list(.false.)
  call report_undefined_diagnostics
!
  if (lparticles) call read_snapshot_particles(directory_dist)
  if (lpointmasses) call pointmasses_read_snapshot('qvar.dat')
!
  call get_nseed(nseed)
!
!  Set initial time to zero if requested. This is dangerous, however!
!  One may forget removing this entry after having set this once.
!  It is therefore safer to say lini_t_eq_zero_once=.true.,
!  which does the reset once once, unless NORESET_TZERO is removed.
!
  if (lini_t_eq_zero) t=0.0
!
!  Set initial time to zero if requested, but blocks further resets.
!  See detailed comment above.
!
  lnoreset_tzero=control_file_exists('NORESET_TZERO')
  if (lini_t_eq_zero_once.and..not.lnoreset_tzero) then
    call touch_file('NORESET_TZERO')
    t=0.0
  endif
!
!  Set last tsound output time
!
  if (lwrite_sound) then
    if (tsound<0.0) then
      ! if sound output starts new
      tsound=t
      ! output initial values
      lout_sound=.true.
    endif
  endif
!
!  Read processor boundaries.
!
  if (lparticles) then
    if (ip<=6.and.lroot) print*, 'reading processor boundaries'
    call rproc_bounds(trim(directory)//'/proc_bounds.dat')
  endif
!
!  The following is here to avoid division in sub.f90 for diagnostic
!  outputs of integrated values in the non equidistant case.
!  Do this even for uniform meshes, in which case xprim=dx, etc.
!  Remember that dx_1=0 for runs without extent in that direction.
!
  if (nxgrid==1) then; xprim=1.0; else; xprim=1./dx_1; endif
  if (nygrid==1) then; yprim=1.0; else; yprim=1./dy_1; endif
  if (nzgrid==1) then; zprim=1.0; else; zprim=1./dz_1; endif
!
!  Determine slice positions and whether slices are to be written on this
!  processor. This can only be done after the grid has been established.
!
  call setup_slices
!
!  Initialize the list of neighboring processes.
!
  call update_neighbors     !MR: Isn't this only needed for particles?
!
!  Allow modules to do any physics modules do parameter dependent
!  initialization. And final pre-timestepping setup.
!  (must be done before need_XXXX can be used, for example)
!
  call initialize_timestep
  call initialize_modules(f)
!
  if (it1d==impossible_int) then
    it1d=it1
  else
    if (it1d<it1) call stop_it_if_any(lroot,'run: it1d smaller than it1')
  endif
!
!  Read global variables (if any).
!
  if (mglobal/=0) call input_globals('global.dat', &
      f(:,:,:,mvar+maux+1:mvar+maux+mglobal),mglobal)
!
!  Initialize ionization array.
!
  if (leos_ionization) call ioninit(f)
  if (leos_temperature_ionization) call ioncalc(f)
!
!  Prepare particles.
!
  if (lparticles) then
    !!!call particles_rprint_list(.false.) ! already done
    call particles_initialize_modules(f)
  endif
!
!  Write data to file for IDL.
!
  call write_all_run_pars('IDL')
!
!  Write parameters to log file (done after reading var.dat, since we
!  want to output time t.
!
  call write_all_run_pars
!
!  Possible debug output (can only be done after "directory" is set).
!  Check whether mn array is correct.
!
  if (ip<=3) call debug_imn_arrays
!
!  Find out which pencils are needed and write information about required,
!  requested and diagnostic pencils to disc.
!
  call choose_pencils
  call write_pencil_info
!
  if (mglobal/=0) call output_globals('global.dat', &
      f(:,:,:,mvar+maux+1:mvar+maux+mglobal),mglobal)
!
!  Update ghost zones, so rprint works corrected for at the first
!  time step even if we didn't read ghost zones.
!
  call update_ghosts(f)
!
!  Save spectrum snapshot.
!
  if (dspec/=impossible) call powersnap(f)
!
!  Initialize pencils in the pencil_case.
!
  if (lpencil_init) call initialize_pencils(p,0.0)
!
!  Perform pencil_case consistency check if requested.
!
  suppress_pencil_check = control_file_exists("NO-PENCIL-CHECK")
  if ( (lpencil_check .and. .not. suppress_pencil_check) .or. &
       ((.not.lpencil_check).and.lpencil_check_small) ) &
    call pencil_consistency_check(f,df,p)
!
!  Start timing for final timing statistics.
!  Initialize timestep diagnostics during the run (whether used or not,
!  see idiag_timeperstep).
!
  if (lroot) then
    time1=mpiwtime()
    time_last_diagnostic=time1
    icount=0
    it_last_diagnostic=icount
  endif
!
!  Globally catch eventual 'stop_it_if_any' call from single MPI ranks
!
  call stop_it_if_any(.false.,'')
!
!  Prepare signal catching
!
  call signal_prepare
!
!  Trim 1D-averages for times past the current time.
!
  call trim_averages
!
!  Do loop in time.
!
  Time_loop: do while (it<=nt)
!
    lout   = (mod(it-1,it1) == 0) .and. (it > it1start)
    l1davg = (mod(it-1,it1d) == 0)
!
    if (lwrite_sound) then
      if ( .not.lout_sound .and. abs( t-tsound - dsound )<= 1.1*dt ) then
        lout_sound = .true.
        tsound = t
      endif
    endif
!
    if (lout .or. emergency_stop) then
!
!  Exit do loop if file `STOP' exists.
!
      lstop=control_file_exists('STOP',DELETE=.true.)
      if (lstop .or. emergency_stop) then
        if (lroot) then
          print*
          if (emergency_stop) print*, 'Emergency stop requested'
          if (lstop) print*, 'Found STOP file'
        endif
        resubmit=control_file_exists('RESUBMIT',DELETE=.true.)
        if (resubmit) print*, 'Cannot be resubmitted'
        exit Time_loop
      endif
!
!  initialize timer
!
      call timing('run','entered Time_loop',INSTRUCT='initialize')
!
!  Re-read parameters if file `RELOAD' exists; then remove the file
!  (this allows us to change parameters on the fly).
!  Re-read parameters if file `RELOAD_ALWAYS' exists; don't remove file
!  (only useful for debugging RELOAD issues).
!
      lreload_file       =control_file_exists('RELOAD')
      lreload_always_file=control_file_exists('RELOAD_ALWAYS')
      lreloading         =lreload_file .or. lreload_always_file
!
      if (lreloading) then
        if (lroot) write(*,*) 'Found RELOAD file -- reloading parameters'
!  Re-read configuration
        dt=0.0
        call read_all_run_pars(logging=.true.)
!
!  Before reading the rprint_list deallocate the arrays allocated for
!  1-D and 2-D diagnostics.
!
        call diagnostics_clean_up
        if (lforcing)            call forcing_clean_up
        if (lhydro_kinematic)    call hydro_clean_up
        if (lsolid_cells)        call solid_cells_clean_up

        call rprint_list(LRESET=.true.) !(Re-read output list)
        if (lparticles) call particles_rprint_list(.false.) !MR: shouldn't this be called with lreset=.true.?                                    
        call report_undefined_diagnostics

        call initialize_timestep
        call initialize_modules(f)
        if (lparticles) call particles_initialize_modules(f)

        call choose_pencils
        call write_all_run_pars('IDL')       ! data to param2.nml
        call write_all_run_pars              ! diff data to params.log
!
        lreload_file=control_file_exists('RELOAD', DELETE=.true.)
        lreload_file        = .false.
        lreload_always_file = .false.
        lreloading          = .false.
      endif
    endif
!
!  Remove wiggles in lnrho in sporadic time intervals.
!  Necessary on moderate-sized grids. When this happens,
!  this is often an indication of bad boundary conditions!
!  iwig=500 is a typical value. For iwig=0 no action is taken.
!  (The two queries below must come separately on compaq machines.)
!
!  N.B.: We now (July 2003) know that boundary conditions
!  change practically nothing, apart from avoiding stationary
!  stagnation points/surfaces in the first place.
!    rmwig is superseeded by the switches lupw_lnrho, lupw_ss,
!  which should provide a far better solution to the problem.
!
    if (iwig/=0) then
      if (mod(it,iwig)==0) then
        if (lrmwig_xyaverage) call rmwig_xyaverage(f,ilnrho)
        if (lrmwig_full) call rmwig(f,df,ilnrho,ilnrho,awig)
        if (lrmwig_rho) call rmwig(f,df,ilnrho,ilnrho,awig,explog=.true.)
      endif
    endif
!
!  If we want to write out video data, wvid_prepare sets lvideo=.true.
!  This allows pde to prepare some of the data.
!
    if (lwrite_slices) then
      call wvid_prepare
      if (t == 0.0 .and. lwrite_ic) lvideo = .true.
    endif
!
    if (lwrite_2daverages) &
      call write_2daverages_prepare(t == 0.0 .and. lwrite_ic)
!
!  Exit do loop if maximum simulation time is reached; allow one extra
!  step if any diagnostic output needs to be produced.
!
    overtmax: if (t >= tmax) then
      onemorestep: if (lonemorestep .or. &
                       .not. (lout .or. lvideo .or. l2davg)) then
        if (lroot) print *, 'Maximum simulation time exceeded'
        exit Time_loop
      endif onemorestep
      lonemorestep = .true.
    endif overtmax
!
!   Prepare for the writing of the tracers and the fixed points.
!
    if (lwrite_tracers) call tracers_prepare
    if (lwrite_fixed_points) call fixed_points_prepare
!
!  Find out which pencils to calculate at current time-step.
!
    lpencil = lpenc_requested
!  MR: the following should only be done in the first substep, shouldn't it?
    if (lout)   lpencil=lpencil .or. lpenc_diagnos
    if (l2davg) lpencil=lpencil .or. lpenc_diagnos2d
    if (lvideo) lpencil=lpencil .or. lpenc_video
!
!  Save state vector prior to update for the (implicit) ADI scheme.
!
    if (lADI) f(:,:,:,iTTold)=f(:,:,:,iTT)
!
    if (ltestperturb) call testperturb_begin(f,df)
!
!  A random phase for the hydro_kinematic module
!
    if (lhydro_kinematic) call kinematic_random_phase
!
!  Decide here whether or not we will need a power spectrum.
!  At least for the graviational wave spectra, this requires
!  advance warning so the relevant components of the f-array
!  can be filled.
!
    call powersnap_prepare
!
!  Time advance.
!
    call time_step(f,df,p)
!
!  If overlapping grids are used to get body-confined grid around the solids
!  in the flow, call time step on these grids. 
! 
    if (lsolid_cells) call time_step_ogrid(f)
!
!  Print diagnostic averages to screen and file.
!
    if (lout) then
      call prints
      if (lchemistry_diag) call write_net_reaction
    endif
    if (l1davg) call write_1daverages
    if (l2davg) call write_2daverages
!
    if (lout_sound) then
      call write_sound(tsound)
      lout_sound = .false.
    endif
!
!  Ensure better load balancing of particles by giving equal number of
!  particles to each CPU. This only works when block domain decomposition of
!  particles is activated.
!
    if (lparticles) call particles_load_balance(f)
!
!  07-Sep-07/dintrans+gastine: Implicit advance of the radiative diffusion
!  in the temperature equation (using the implicit_physics module).
!
    if (lADI) call calc_heatcond_ADI(f)
!
    if (ltestperturb) call testperturb_finalize(f)
!
    if (lboussinesq) call boussinesq(f)
!
    if (lroot) icount=icount+1  !  reliable loop count even for premature exit
!
!  Update time averages and time integrals.
!
    if (ltavg) call update_timeavgs(f,dt)
!
!  Add forcing and/or do rescaling (if applicable).
!
    if (lforcing) call addforce(f)
    if (lparticles_lyapunov) call particles_stochastic
!    if (lspecial) call special_stochastic
    if (lrescaling_magnetic)  call rescaling_magnetic(f)
    if (lrescaling_testfield) call rescaling_testfield(f)
    if (lrescaling_testscalar) call rescaling_testscalar(f)
!
!  Check for SNe, and update f if necessary (see interstellar.f90).
!
    if (linterstellar) call check_SN(f)
!
!  Check if mass flux replacement required fred test
!
    if (linterstellar) call addmassflux(f)
!
!  Check wall clock time, for diagnostics and for user supplied simulation time
!  limit.
!
    if (lroot.and.(idiag_walltime/=0.or.max_walltime/=0.0)) then
      time2=mpiwtime()
      wall_clock_time=time2-time1
      if (lout) call save_name(wall_clock_time,idiag_walltime)
    endif
!
    if (lout.and.lroot.and.idiag_timeperstep/=0) then
      it_this_diagnostic   = it
      time_this_diagnostic = mpiwtime()
      time_per_step = (time_this_diagnostic - time_last_diagnostic) &
                     /(  it_this_diagnostic -   it_last_diagnostic)
      it_last_diagnostic   =   it_this_diagnostic
      time_last_diagnostic = time_this_diagnostic
      call save_name(time_per_step,idiag_timeperstep)
    endif
!
!  Setting ialive=1 can be useful on flaky machines!
!  The iteration number is written into the file "data/proc*/alive.info".
!  Set ialive=0 to fully switch this off.
!
    if (ialive /= 0) then
      if (mod(it,ialive)==0) call output_form('alive.info',it,.false.)
    endif
    if (lparticles) &
        call write_snapshot_particles(f,ENUM=.true.)
    if (lpointmasses) &
        call pointmasses_write_snapshot('QVAR',ENUM=.true.,FLIST='qvarN.list')
!
    call wsnap('VAR',f,mvar_io,ENUM=.true.,FLIST='varN.list')
    if (ldownsampl) call wsnap_down(f,FLIST='varN_down.list')
    call wsnap_timeavgs('TAVG',ENUM=.true.,FLIST='tavgN.list')
!
!  Write slices (for animation purposes).
!
    if (lvideo .and. lwrite_slices) call wvid(f)
!
!  Write tracers (for animation purposes).
!
    if (ltracers.and.lwrite_tracers) call wtracers(f,trim(directory)//'/tracers_')
!
!  Write fixed points (for animation purposes).
!
    if (lfixed_points.and.lwrite_fixed_points) call wfixed_points(f,trim(directory)//'/fixed_points_')
!
!  Save snapshot every isnap steps in case the run gets interrupted.
!  The time needs also to be written.
!
    lsave = control_file_exists('SAVE', DELETE=.true.)
    if (lsave .or. ((isave /= 0) .and. .not. lnowrite)) then
      if (lsave .or. (mod(it-isave_shift, isave) == 0)) then
        call wsnap('var.dat',f, mvar_io,ENUM=.false.,noghost=noghost_for_isave)
        call wsnap_timeavgs('timeavg.dat',ENUM=.false.)
        if (lparticles) &
            call write_snapshot_particles(f,ENUM=.false.)
        if (lpointmasses) call pointmasses_write_snapshot('qvar.dat',ENUM=.false.)
        if (lsave) isave_shift = mod(it+isave-isave_shift, isave) + isave_shift
        if (lsolid_cells) call wsnap_ogrid('ogvar.dat',ENUM=.false.)
      endif
    endif
!
!  Save spectrum snapshot.
!
    if (dspec/=impossible) call powersnap(f)
!
!  Save global variables.
!
    if (isaveglobal/=0) then
      if ((mod(it,isaveglobal)==0) .and. (mglobal/=0)) then
        call output_globals('global.dat', &
            f(:,:,:,mvar+maux+1:mvar+maux+mglobal),mglobal)
      endif
    endif
!
!  Do exit when timestep has become too short.
!  This may indicate an MPI communication problem, so the data are useless
!  and won't be saved!
!
    if ((it<nt) .and. (dt<dtmin)) then
      if (lroot) &
          write(*,*) ' Time step has become too short: dt = ', dt
      save_lastsnap=.false.
      exit Time_loop
    endif
!
!  Exit do loop if wall_clock_time has exceeded max_walltime.
!
    if (max_walltime>0.0) then
      if (lroot.and.(wall_clock_time>max_walltime)) timeover=.true.
      call mpibcast_logical(timeover,comm=MPI_COMM_WORLD)
      if (timeover) then
        if (lroot) then
          print*
          print*, 'Maximum walltime exceeded'
        endif
        exit Time_loop
      endif
    endif
!
!  Fatal errors sometimes occur only on a specific processor. In that case all
!  processors must be informed about the problem before the code can stop.
!
    call fatal_error_local_collect
    call timing('run','at the end of Time_loop',INSTRUCT='finalize')
!
    it=it+1
    headt=.false.
  enddo Time_loop
!
  if (lroot) then
    print*
    print*, 'Simulation finished after ', icount, ' time-steps'
  endif
!
  if (lroot) time2=mpiwtime()
!
!  Write data at end of run for restart.
!
  if (lroot) then
    print*
    print*, 'Writing final snapshot at time t =', t
  endif
!
  if (.not.lnowrite) then
    if (save_lastsnap) then
      if (lparticles) &
          call write_snapshot_particles(f,ENUM=.false.)
      if (lpointmasses) call pointmasses_write_snapshot('qvar.dat',ENUM=.false.)
      if (lsolid_cells) call wsnap_ogrid('ogvar.dat',ENUM=.false.)
!
      call wsnap('var.dat',f,mvar_io,ENUM=.false.)
      call wsnap_timeavgs('timeavg.dat',ENUM=.false.)
!
!  dvar is written for analysis and debugging purposes only.
!
      if (ip<=11 .or. lwrite_dvar) then
        call wsnap('dvar.dat',df,mvar,ENUM=.false.,noghost=.true.)
        call particles_write_dsnapshot('dpvar.dat',f)
      endif
!
!  Write crash files before exiting if we haven't written var.dat already
!
    else
      call wsnap('crash.dat',f,mvar_io,ENUM=.false.)
      if (ip<=11) call wsnap('dcrash.dat',df,mvar,ENUM=.false.)
    endif
  endif
!
!  Save spectrum snapshot.
!
  if (save_lastsnap) then
    if (dspec/=impossible) call powersnap(f,.true.)
  endif
!
!  Print wall clock time and time per step and processor for diagnostic
!  purposes.
!
  if (lroot) then
    wall_clock_time=time2-time1
    print*
    write(*,'(A,1pG10.3,A,1pG9.2,A)') &
        ' Wall clock time [hours] = ', wall_clock_time/3600.0, &
        ' (+/- ', real(mpiwtick())/3600.0, ')'
    if (it>1) then
      if (lparticles) then
        write(*,'(A,1pG10.3)') &
            ' Wall clock time/timestep/(meshpoint+particle) [microsec] =', &
            wall_clock_time/icount/(nw+npar/ncpus)/ncpus/1.0e-6
      else
        write(*,'(A,1pG10.3)') &
            ' Wall clock time/timestep/meshpoint [microsec] =', &
            wall_clock_time/icount/nw/ncpus/1.0e-6
      endif
    endif
    print*
  endif
!
!  Give all modules the possibility to exit properly.
!
  call finalize_modules(f)
!
!  Write success file, if the requested simulation is complete.
!
  if ((it > nt) .or. (t > tmax)) call touch_file('COMPLETED')
  if (t > tmax) call touch_file('ENDTIME')
!
!  Stop MPI.
!
  call mpifinalize
!
!  Free any allocated memory.
!  MR: Is this needed? the program terminates anyway
!
  call diagnostics_clean_up
  call farray_clean_up
  call sharedvars_clean_up
  call chemistry_clean_up
  call NSCBC_clean_up
  if (lparticles) call particles_cleanup
!
endprogram run
!**************************************************************************

! This tool distributes a global data cube in into the proc-directories.
!
! $Id$
!
program pc_distribute
!
  use Cdata
  use Cparam, only: fnlen
  use Diagnostics
  use Filter
  use Grid, only: initialize_grid,construct_grid,set_coorsys_dimmask
  use IO
  use Messages
  use Param_IO
  use Register
  use Snapshot
  use Sub
!
  implicit none
!
  character (len=fnlen) :: filename
  character (len=*), parameter :: directory_in = 'data/allprocs'
!
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension (:,:,:,:), allocatable :: gf
  real, dimension (mxgrid) :: gx, gdx_1, gdx_tilde
  real, dimension (mygrid) :: gy, gdy_1, gdy_tilde
  real, dimension (mzgrid) :: gz, gdz_1, gdz_tilde
  logical :: ex
  integer :: mvar_in, io_len, pz, pa, alloc_err, lun_global=87
  real :: t_sp   ! t in single precision for backwards compatibility
!
  lstart = .false.
  lmpicomm = .false.
  lroot = .true.
  ipx = 0
  ipy = 0
  ipz = 0
  ylneigh = 0
  zlneigh = 0
  yuneigh = 0
  zuneigh = 0
!
  deltay = 0.0   ! Shearing not available due to missing fseek in Fortran
!
  inquire (IOLENGTH=io_len) 1.0
!
  if (lcollective_IO) call fatal_error ('pc_distribute', &
      "Distributing snapshots currently requires the distributed IO-module.")
!
  write (*,*) 'Please enter the filename to convert (eg. var.dat, VAR1, ...):'
  read (*,*) filename
!
!  Identify version.
!
  if (lroot) call svn_id( &
      '$Id$')
!
!  Initialize the message subsystem, eg. color setting etc.
!
  call initialize_messages
!
!  Read parameters from start.x (default values; overwritten by 'read_all_run_pars').
!
  call read_all_init_pars
  call set_coorsys_dimmask
!
  lstart=.false.
  lrun=.true.
!
!  Read parameters and output parameter list.
!
  call read_all_run_pars
!
!  Derived parameters (that may still be overwritten).
!  [might better be put into another routine, possibly in 'read_all_run_pars']
!
  x0 = xyz0(1)
  y0 = xyz0(2)
  z0 = xyz0(3)
  Lx = Lxyz(1)
  Ly = Lxyz(2)
  Lz = Lxyz(3)
!
!  Register physics modules.
!
  call register_modules
!
!  Define the lenergy logical
!
  lenergy = lentropy .or. ltemperature .or. lthermal_energy
!
  if (lwrite_aux .and. .not. lread_aux) then
    if (lroot) then
      print *, ''
      print *, 'lwrite_aux=T but lread_aux=F'
      print *, 'The code will write the auxiliary variables to allprocs/VARN'
      print *, ' without having read them from proc*/VARN'
      print *, ''
      call fatal_error("pc_distribute","Stop and check")
    endif
  endif
!
!  Will we write all slots of f?
!
  if (lwrite_aux) then
    mvar_io=mvar+maux
  else
    mvar_io=mvar
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
  allocate (gf (mxgrid,mygrid,mz,mvar_io), stat=alloc_err)
  if (alloc_err /= 0) call fatal_error ('pc_distribute', 'Failed to allocate memory for gf.', .true.)
!
!  Print resolution and dimension of the simulation.
!
  if (lroot) write (*,'(a,i1,a)') ' This is a ', dimensionality, '-D run'
  if (lroot) print *, 'nxgrid, nygrid, nzgrid=', nxgrid, nygrid, nzgrid
  if (lroot) print *, 'Lx, Ly, Lz=', Lxyz
  if (lroot) print *, '      Vbox=', Lxyz(1)*Lxyz(2)*Lxyz(3)
!
  inquire (file=trim(directory_in)//'/'//filename, exist=ex)
  if (.not. ex) call fatal_error ('pc_distribute', 'File not found: '//trim(directory_in)//'/'//filename, .true.)
  inquire (file=trim(directory_in)//'/grid.dat', exist=ex)
  if (.not. ex) call fatal_error ('pc_distribute', 'File not found: '//trim(directory_in)//'/grid.dat', .true.)
!
  ! read time:
  open (lun_input, FILE=trim(directory_in)//'/grid.dat', FORM='unformatted', status='old')
  read (lun_input) t_sp, gx, gy, gz, dx, dy, dz
  read (lun_input) dx, dy, dz
  read (lun_input) Lx, Ly, Lz
  read (lun_input) gdx_1, gdy_1, gdz_1
  read (lun_input) gdx_tilde, gdy_tilde, gdz_tilde
  close (lun_input)
  t = t_sp
!
  call directory_names
  open (lun_global, FILE=trim(directory_in)//'/'//filename, access='direct', recl=mxgrid*mygrid*io_len, status='old')
!
!  Allow modules to do any physics modules do parameter dependent
!  initialization. And final pre-timestepping setup.
!  (must be done before need_XXXX can be used, for example)
!
  call construct_grid(x,y,z,dx,dy,dz)
  call initialize_modules (f)
!
! Loop over processors
!
  write (*,*) "IPZ-layer:"
!
  do ipz = 0, nprocz-1
!
    write (*,*) ipz+1, " of ", nprocz
!
    f = huge(1.0)
    gf = huge(1.0)
!
    ! read xy-layer:
    do pa = 1, mvar_io
      do pz = 1, mz
        read (lun_global, rec=pz+ipz*nz+(pa-1)*mzgrid) gf(:,:,pz,pa)
      enddo
    enddo
!
    do ipy = 0, nprocy-1
      do ipx = 0, nprocx-1
!
        iproc_world = ipx + ipy * nprocx + ipz * nprocx*nprocy
        lroot = (iproc_world==root)
!
!  Set up flags for leading processors in each possible direction and plane
!
        lfirst_proc_x = (ipx == 0)
        lfirst_proc_y = (ipy == 0)
        lfirst_proc_z = (ipz == 0)
        lfirst_proc_xy = lfirst_proc_x .and. lfirst_proc_y
        lfirst_proc_yz = lfirst_proc_y .and. lfirst_proc_z
        lfirst_proc_xz = lfirst_proc_x .and. lfirst_proc_z
        lfirst_proc_xyz = lfirst_proc_x .and. lfirst_proc_y .and. lfirst_proc_z
!
!  Set up flags for trailing processors in each possible direction and plane
!
        llast_proc_x = (ipx == nprocx-1)
        llast_proc_y = (ipy == nprocy-1)
        llast_proc_z = (ipz == nprocz-1)
        llast_proc_xy = llast_proc_x .and. llast_proc_y
        llast_proc_yz = llast_proc_y .and. llast_proc_z
        llast_proc_xz = llast_proc_x .and. llast_proc_z
        llast_proc_xyz = llast_proc_x .and. llast_proc_y .and. llast_proc_z
!
!  Set up directory names.
!
        call directory_names
!
! Size of box at local processor. The if-statement is for
! backward compatibility.
!
        if (all(lequidist)) then
          Lxyz_loc(1)=Lxyz(1)/nprocx
          Lxyz_loc(2)=Lxyz(2)/nprocy
          Lxyz_loc(3)=Lxyz(3)/nprocz
          xyz0_loc(1)=xyz0(1)+ipx*Lxyz_loc(1)
          xyz0_loc(2)=xyz0(2)+ipy*Lxyz_loc(2)
          xyz0_loc(3)=xyz0(3)+ipz*Lxyz_loc(3)
          xyz1_loc(1)=xyz0_loc(1)+Lxyz_loc(1)
          xyz1_loc(2)=xyz0_loc(2)+Lxyz_loc(2)
          xyz1_loc(3)=xyz0_loc(3)+Lxyz_loc(3)
        else
          xyz0_loc(1)=x(l1)
          xyz0_loc(2)=y(m1)
          xyz0_loc(3)=z(n1)
          xyz1_loc(1)=x(l2)
          xyz1_loc(2)=y(m2)
          xyz1_loc(3)=z(n2)
          Lxyz_loc(1)=xyz1_loc(1) - xyz0_loc(1)
          Lxyz_loc(2)=xyz1_loc(2) - xyz0_loc(3)
          Lxyz_loc(3)=xyz1_loc(3) - xyz0_loc(3)
        endif
!
!  Need to re-initialize the local grid for each processor.
!
        call construct_grid(x,y,z,dx,dy,dz)
!
        ! distribute gf to f:
        f(:,:,:,1:mvar_io) = gf(1+ipx*nx:mx+ipx*nx,1+ipy*ny:my+ipy*ny,:,:)
        x = gx(1+ipx*nx:mx+ipx*nx)
        y = gy(1+ipy*ny:my+ipy*ny)
        z = gz(1+ipz*nz:mz+ipz*nz)
        dx_1 = gdx_1(1+ipx*nx:mx+ipx*nx)
        dy_1 = gdy_1(1+ipy*ny:my+ipy*ny)
        dz_1 = gdz_1(1+ipz*nz:mz+ipz*nz)
        dx_tilde = gdx_tilde(1+ipx*nx:mx+ipx*nx)
        dy_tilde = gdy_tilde(1+ipy*ny:my+ipy*ny)
        dz_tilde = gdz_tilde(1+ipz*nz:mz+ipz*nz)
!
        ! write data:
        if (mvar_io>0) &
          call wsnap (filename, f, mvar_io, enum=.false., noghost=.true.)
!
        ! write grid:
        call wgrid ('grid.dat')
!
      enddo
    enddo
  enddo
!
  close (lun_global)
  print *, 'Writing snapshot for time t =', t
!
!  Gvie all modules the possibility to exit properly.
!
  call finalize_modules (f)
!
!  Free any allocated memory.
!
  deallocate (gf)
  call fnames_clean_up
  call vnames_clean_up
!
endprogram pc_distribute

! This is a very feature-limited tool to reduce a data cube in the
! horzontal directions (x and y), if these are periodic.
!
! $Id$
!
program pc_reduce
!
  use Cdata
  use Cparam, only: fnlen
  use Diagnostics
  use File_io, only: backskip_to_time, delete_file
  use Filter
  use General, only: numeric_precision
  use Grid, only: initialize_grid, construct_grid, set_coorsys_dimmask
  use IO
  use Messages
  use Param_IO
  use Register
  use Snapshot
  use Sub
  use Syscalls, only: sizeof_real
!
  implicit none
!
  integer, parameter :: reduce=2
  character (len=fnlen) :: filename
  character (len=*), parameter :: directory_out = 'data/reduced'
!
  real, dimension (mx,my,mz,mfarray) :: f
  integer, parameter :: nrx=nxgrid/reduce+2*nghost, nry=nygrid/reduce+2*nghost
  real, dimension (:,:,:,:), allocatable :: rf, gf
  real, dimension (nrx) :: rx, rdx_1, rdx_tilde
  real, dimension (nry) :: ry, rdy_1, rdy_tilde
  real, dimension (mzgrid) :: gz, gdz_1, gdz_tilde
  real, dimension (mxgrid) :: gx, gdx_1, gdx_tilde
  real, dimension (mygrid) :: gy, gdy_1, gdy_tilde
  logical :: ex
  integer :: mvar_in, io_len, px, py, pz, pa, start_pos, end_pos, alloc_err
  integer :: iprocz_slowest = 0
  integer(kind=8) :: rec_len
  real, parameter :: inv_reduce = 1.0 / reduce, inv_reduce_2 = 1.0 / reduce**2
  real :: t_sp, t_test   ! t in single precision for backwards compatibility
!
  lstart = .true.
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
  inquire (IOLENGTH=io_len) t_sp
!
  if (IO_strategy == 'MPI-IO') call fatal_error ('pc_reduce', &
      "Reducing snapshots is not implemented for the 'io_mpi2'-module.")
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
  lstart=.false.; lrun=.true.
!
!  Read parameters and output parameter list.
!
  call read_all_run_pars
!
  if (.not. lperi(1) .and. (reduce /= 1)) call fatal_error ('run', 'reduction impossible in X: not periodic')
  if (.not. lperi(2) .and. (reduce /= 1)) call fatal_error ('run', 'reduction impossible in Y: not periodic')
  if (mod (nx, reduce) /= 0) call fatal_error ('run', 'NX not dividable by reduce factor')
  if (mod (ny, reduce) /= 0) call fatal_error ('run', 'NY not dividable by reduce factor')
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
  allocate (rf (nrx,nry,mz,mvar_io), stat=alloc_err)
  if (alloc_err /= 0) call fatal_error ('pc_reduce', 'Failed to allocate memory for rf.', .true.)
  if (IO_strategy == 'collect') then
    allocate (gf (mxgrid,mygrid,1,1), stat=alloc_err)
    if (alloc_err /= 0) call fatal_error ('pc_reduce', 'Failed to allocate memory for gf.', .true.)
  elseif (IO_strategy == 'collect_xy') then
    allocate (gf (mxgrid,mygrid,mz,mvar_io), stat=alloc_err)
    if (alloc_err /= 0) call fatal_error ('pc_reduce', 'Failed to allocate memory for gf.', .true.)
  endif
!
!  Print resolution and dimension of the simulation.
!
  if (lroot) write (*,'(a,i1,a)') ' This is a ', dimensionality, '-D run'
  if (lroot) print *, 'nxgrid, nygrid, nzgrid=', nxgrid, nygrid, nzgrid
  if (lroot) print *, 'Lx, Ly, Lz=', Lxyz
  if (lroot) print *, '      Vbox=', Lxyz(1)*Lxyz(2)*Lxyz(3)
!
  iproc_world = 0
  call directory_names
  inquire (file=trim(directory_snap)//'/'//filename, exist=ex)
  if (.not. ex) call fatal_error ('pc_reduce', 'File not found: '//trim(directory_snap)//'/'//filename, .true.)
  call delete_file(trim(directory_out)//'/'//filename)
  open (lun_output, FILE=trim(directory_out)//'/'//filename, status='new', access='direct', recl=nrx*nry*io_len)
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
  rx = huge(1.0)
  ry = huge(1.0)
!
  gz = huge(1.0)
!
  do ipz = 0, nprocz-1
!
    write (*,*) ipz+1, " of ", nprocz
!
    rf = huge(1.0)
!
    iproc_world = ipz * nprocx*nprocy
    lroot = (iproc_world==root)
    lfirst_proc_z = (ipz == 0)
    llast_proc_z = (ipz == nprocz-1)
!
    if (IO_strategy == 'collect') then
      ! Take the shortcut, files are well prepared for direct reduction
!
      gf = huge(1.0)
      gx = huge(1.0)
      gy = huge(1.0)
!
      ! Set up directory names 'directory' and 'directory_snap'
      call directory_names
!
      ! Read the data
      rec_len = int (mxgrid, kind=8) * int (mygrid, kind=8) * io_len
      open (lun_input, FILE=trim (directory_snap)//'/'//filename, access='direct', recl=rec_len, status='old')
      do pa = 1, mvar_io
        start_pos = nghost + 1
        end_pos = nghost + nz
        if (lfirst_proc_z) start_pos = 1
        if (llast_proc_z) end_pos = mz
        do pz = start_pos, end_pos
          read (lun_input, rec=pz+ipz*nz+(pa-1)*mzgrid) gf
          do py = 0, nygrid-1, reduce
            do px = 0, nxgrid-1, reduce
              ! reduce f:
              rf(nghost+1+(px+ipx*nxgrid)/reduce,nghost+1+(py+ipy*nygrid)/reduce,pz,pa) = &
                  sum (gf(nghost+1+px:nghost+px+reduce,nghost+1+py:nghost+py+reduce,1,1)) * inv_reduce_2
            enddo
          enddo
        enddo
      enddo
      close (lun_input)
!
      if (lroot) then
!
        ! Read additional information
        open (lun_input, FILE=trim (directory_snap)//'/'//filename, FORM='unformatted', status='old', position='append')
        call backskip_to_time(lun_input)
        read (lun_input) t_sp, gx, gy, gz, dx, dy, dz
        close(lun_input)
        t = t_sp
!
        ! read grid:
        open (lun_input, FILE=trim(directory_collect)//'/grid.dat', FORM='unformatted', status='old')
        read (lun_input) t_sp, gx, gy, gz, dx, dy, dz
        read (lun_input) dx, dy, dz
        read (lun_input) Lx, Ly, Lz
        read (lun_input) gdx_1, gdy_1, gdz_1
        read (lun_input) gdx_tilde, gdy_tilde, gdz_tilde
        close(lun_input)
!
        ! reduce x coordinates:
        do px = 0, nxgrid-1, reduce
          rx(nghost+1+px/reduce) = sum (gx(nghost+1+px:nghost+px+reduce)) * inv_reduce
          rdx_1(nghost+1+px/reduce) = 1.0 / sum (1.0/gdx_1(nghost+1+px:nghost+px+reduce))
          rdx_tilde(nghost+1+px/reduce) = sum (1.0/gdx_1(nghost+1+px:nghost+px+reduce))
        enddo
!
        ! reduce y coordinates:
        do py = 0, nygrid-1, reduce
          ry(nghost+1+py/reduce) = sum (gy(nghost+1+py:nghost+py+reduce)) * inv_reduce
          rdy_1(nghost+1+py/reduce) = 1.0 / sum (1.0/gdy_1(nghost+1+py:nghost+py+reduce))
          rdy_tilde(nghost+1+py/reduce) = sum (1.0/gdy_1(nghost+1+py:nghost+py+reduce))
        enddo
!
      endif
!
    elseif (IO_strategy == 'collect_xy') then
      ! Take the shortcut, files are well prepared for direct reduction
!
      gf = huge(1.0)
      gx = huge(1.0)
      gy = huge(1.0)
!
      ! Set up directory names 'directory' and 'directory_snap'
      call directory_names
!
      ! Read the data
      if (ldirect_access) then
        rec_len = int (mxgrid, kind=8) * int (mygrid, kind=8) * mz
        rec_len = rec_len * mvar_in * io_len
        open (lun_input, FILE=trim (directory_snap)//'/'//filename, access='direct', recl=rec_len, status='old')
        read (lun_input, rec=1) gf
        close(lun_input)
        open (lun_input, FILE=trim (directory_snap)//'/'//filename, FORM='unformatted', status='old',position='append')
        call backskip_to_time(lun_input, lroot)
      else
        open (lun_input, FILE=trim (directory_snap)//'/'//filename, form='unformatted', status='old')
        read (lun_input) gf
      endif
!
      ! Read additional information and check consistency of timestamp
      read (lun_input) t_sp
      if (lroot) then
        t_test = t_sp
        read (lun_input) gx, gy, gz, dx, dy, dz
      else
        if (t_test /= t_sp) then
          write (*,*) 'ERROR: '//trim(directory_snap)//'/'//trim(filename)//' IS INCONSISTENT: t=', t_sp
          stop 1
        endif
      endif
      close (lun_input)
      t = t_sp
!
      ! reduce f:
      do pa = 1, mvar_io
        start_pos = nghost + 1
        end_pos = nghost + nz
        if (lfirst_proc_z) start_pos = 1
        if (llast_proc_z) end_pos = mz
        do pz = start_pos, end_pos
          do py = 0, nygrid-1, reduce
            do px = 0, nxgrid-1, reduce
              rf(nghost+1+(px+ipx*nxgrid)/reduce,nghost+1+(py+ipy*nygrid)/reduce,pz,pa) = &
                  sum (gf(nghost+1+px:nghost+px+reduce,nghost+1+py:nghost+py+reduce,pz,pa)) * inv_reduce_2
            enddo
          enddo
        enddo
      enddo
!
      if (lroot) then
!
        ! read grid:
        open (lun_input, FILE=trim(directory_collect)//'/grid.dat', FORM='unformatted', status='old')
        read (lun_input) t_sp, gx, gy, gz, dx, dy, dz
        read (lun_input) dx, dy, dz
        read (lun_input) Lx, Ly, Lz
        read (lun_input) gdx_1, gdy_1, gdz_1
        read (lun_input) gdx_tilde, gdy_tilde, gdz_tilde
        close(lun_input)
!
        ! reduce x coordinates:
        do px = 0, nxgrid-1, reduce
          rx(nghost+1+px/reduce) = sum (gx(nghost+1+px:nghost+px+reduce)) * inv_reduce
          rdx_1(nghost+1+px/reduce) = 1.0 / sum (1.0/gdx_1(nghost+1+px:nghost+px+reduce))
          rdx_tilde(nghost+1+px/reduce) = sum (1.0/gdx_1(nghost+1+px:nghost+px+reduce))
        enddo
!
        ! reduce y coordinates:
        do py = 0, nygrid-1, reduce
          ry(nghost+1+py/reduce) = sum (gy(nghost+1+py:nghost+py+reduce)) * inv_reduce
          rdy_1(nghost+1+py/reduce) = 1.0 / sum (1.0/gdy_1(nghost+1+py:nghost+py+reduce))
          rdy_tilde(nghost+1+py/reduce) = sum (1.0/gdy_1(nghost+1+py:nghost+py+reduce))
        enddo
!
      endif
!
    else
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
!  Read coordinates.
!
          if (ip<=6.and.lroot) print*, 'reading grid coordinates'
          call rgrid ('grid.dat')
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
!  Read data.
!  Snapshot data are saved in the tmp subdirectory.
!  This directory must exist, but may be linked to another disk.
!
          if (mvar_in>0) call rsnap (filename, f, mvar_in, lread_nogrid)
!
          ! reduce f:
          do pa = 1, mvar_io
            start_pos = nghost + 1
            end_pos = nghost + nz
            if (lfirst_proc_z) start_pos = 1
            if (llast_proc_z) end_pos = mz
            do pz = start_pos, end_pos
              do py = 0, ny-1, reduce
                do px = 0, nx-1, reduce
                  rf(nghost+1+(px+ipx*nx)/reduce,nghost+1+(py+ipy*ny)/reduce,pz,pa) = &
                      sum (f(nghost+1+px:nghost+px+reduce,nghost+1+py:nghost+py+reduce,pz,pa)) * inv_reduce_2
                enddo
              enddo
            enddo
          enddo
!
          if (lfirst_proc_yz) then
            ! reduce x coordinates:
            do px = 0, nx-1, reduce
              rx(nghost+1+(px+ipx*nx)/reduce) = sum (x(nghost+1+px:nghost+px+reduce)) * inv_reduce
              rdx_1(nghost+1+(px+ipx*nx)/reduce) = 1.0 / sum (1.0/dx_1(nghost+1+px:nghost+px+reduce))
              rdx_tilde(nghost+1+(px+ipx*nx)/reduce) = sum (1.0/dx_tilde(nghost+1+px:nghost+px+reduce))
            enddo
          endif
!
          if (lfirst_proc_xz) then
            ! reduce y coordinates:
            do py = 0, ny-1, reduce
              ry(nghost+1+(py+ipy*ny)/reduce) = sum (y(nghost+1+py:nghost+py+reduce)) * inv_reduce
              rdy_1(nghost+1+(py+ipy*ny)/reduce) = 1.0 / sum (1.0/dy_1(nghost+1+py:nghost+py+reduce))
              rdy_tilde(nghost+1+(py+ipy*ny)/reduce) = sum (1.0/dy_tilde(nghost+1+py:nghost+py+reduce))
            enddo
          endif
!
        enddo
      enddo
!
      ! collect z coordinates:
      gz(1+ipz*nz:mz+ipz*nz) = z
      gdz_1(1+ipz*nz:mz+ipz*nz) = dz_1
      gdz_tilde(1+ipz*nz:mz+ipz*nz) = dz_tilde
!
    endif
!
    ! communicate ghost cells along the y direction:
    rf(nghost+1:nrx-nghost,           1:nghost,  :,:) = rf(nghost+1:nrx-nghost,nry-2*nghost+1:nry-nghost,:,:)
    rf(nghost+1:nrx-nghost,nry-nghost+1:nry,     :,:) = rf(nghost+1:nrx-nghost,      nghost+1:2*nghost,  :,:)
!
    ! communicate ghost cells along the x direction:
    rf(           1:nghost,:,:,:) = rf(nrx-2*nghost+1:nrx-nghost,:,:,:)
    rf(nrx-nghost+1:nrx,   :,:,:) = rf(      nghost+1:2*nghost,  :,:,:)
!
    ! write xy-layer:
    do pa = 1, mvar_io
      start_pos = nghost + 1
      end_pos = nghost + nz
      if (lfirst_proc_z) start_pos = 1
      if (llast_proc_z) end_pos = mz
      do pz = start_pos, end_pos
        write (lun_output, rec=pz+ipz*nz+(pa-1)*mzgrid) rf(:,:,pz,pa)
      enddo
    enddo
  enddo
!
  ! communicate ghost cells along the y direction:
  ry(           1:nghost) = ry(nry-2*nghost+1:nry-nghost) - Lxyz(2)
  ry(nry-nghost+1:nry   ) = ry(      nghost+1:2*nghost  ) + Lxyz(2)
  rdy_1(           1:nghost) = rdy_1(nry-2*nghost+1:nry-nghost)
  rdy_1(nry-nghost+1:nry   ) = rdy_1(      nghost+1:2*nghost  )
  rdy_tilde(           1:nghost) = rdy_tilde(nry-2*nghost+1:nry-nghost)
  rdy_tilde(nry-nghost+1:nry   ) = rdy_tilde(      nghost+1:2*nghost  )
!
  ! communicate ghost cells along the x direction:
  rx(           1:nghost) = rx(nrx-2*nghost+1:nrx-nghost) - Lxyz(1)
  rx(nrx-nghost+1:nrx   ) = rx(      nghost+1:2*nghost  ) + Lxyz(1)
  rdx_1(           1:nghost) = rdx_1(nrx-2*nghost+1:nrx-nghost)
  rdx_1(nrx-nghost+1:nrx   ) = rdx_1(      nghost+1:2*nghost  )
  rdx_tilde(           1:nghost) = rdx_tilde(nrx-2*nghost+1:nrx-nghost)
  rdx_tilde(nrx-nghost+1:nrx   ) = rdx_tilde(      nghost+1:2*nghost  )
!
  ! write additional data:
  close(lun_output)
  open (lun_output, FILE=trim(directory_out)//'/'//filename, FORM='unformatted', position='append', status='old')
  t_sp = t
  write (lun_output) t_sp, rx, ry, gz, dx*reduce, dy*reduce, dz
  if (lshear) write (lun_output) deltay
  close(lun_output)
!
  ! write global grid:
  open (lun_output, FILE=trim(directory_out)//'/grid.dat', FORM='unformatted', status='replace')
  write(lun_output) t_sp, rx, ry, gz, dx*reduce, dy*reduce, dz
  write(lun_output) dx*reduce, dy*reduce, dz
  write(lun_output) Lx, Ly, Lz
  write(lun_output) rdx_1, rdy_1, gdz_1
  write(lun_output) rdx_tilde, rdy_tilde, gdz_tilde
  close(lun_output)
!
  ! write global dim:
  open (lun_output, FILE=trim(directory_out)//'/dim.dat', FORM='formatted', status='replace')
  write(lun_output, '(3I7,3I5)') nrx, nry, nzgrid+2*nghost, mvar, maux, mglobal
  write(lun_output, '(A)') numeric_precision()
  write(lun_output, '(3I5)') nghost, nghost, nghost
  if (lprocz_slowest) iprocz_slowest = 1
  write(lun_output, '(4I5)') nprocx, nprocy, nprocz, iprocz_slowest
  close(lun_output)
!
  print*, 'Writing snapshot for time t =', t
!
!  Gvie all modules the possibility to exit properly.
!
  call finalize_modules (f)
!
!  Free any allocated memory.
!
  deallocate (rf)
  if (IO_strategy == 'collect_xy') deallocate (gf)
  call fnames_clean_up
  call vnames_clean_up
!
endprogram pc_reduce

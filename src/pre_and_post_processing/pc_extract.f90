! This is a tool to collect a distributed data cube and process it.
!
! $Id$
!
program pc_extract
!
  use Cdata
  use Cparam, only: fnlen
  use Diagnostics
  use Equ, only: pde
  use File_io, only: backskip_to_time, delete_file
  use Filter
  use Grid, only: initialize_grid,construct_grid,set_coorsys_dimmask
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
  character (len=fnlen) :: filename
  character (len=*), parameter :: directory_out = 'data/allprocs'
!
  real, dimension (mx,my,mz,mfarray) :: f
!!!  real, dimension (mx,my,mz,mvar) :: df
!!!  type (pencil_case) :: p
  real, dimension (:,:,:,:), allocatable :: gf
  real, dimension (mxgrid) :: gx, gdx_1, gdx_tilde
  real, dimension (mygrid) :: gy, gdy_1, gdy_tilde
  real, dimension (mzgrid) :: gz, gdz_1, gdz_tilde
  logical :: ex
  integer :: mvar_in, io_len, pz, pa, start_pos, end_pos, alloc_err
  integer(kind=8) :: rec_len
  real :: t_sp, t_test   ! t in single precision for backwards compatibility
!
  real, dimension (:,:,:,:), allocatable :: global_output
  real, dimension (nx,3) :: tmp
  integer :: pos
  integer, parameter :: num_quantities = 2
  integer :: num_components
  integer, dimension (num_quantities), parameter :: global_start = (/ 1, 4 /)
  integer, dimension (num_quantities), parameter :: global_size = (/ 3, 3 /)
  integer, dimension (num_quantities), parameter :: output_luns = (/ 71, 72 /)
  character (len=labellen), dimension (num_quantities) :: output_names
!
  output_names(1) = "curl_a"
  output_names(2) = "b"
!
  num_components = sum (global_size)
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
  inquire (IOLENGTH=io_len) 1.0
!
  if (IO_strategy == "collect") call fatal_error ('pc_extract', &
      "Snapshots are already collected, when using the 'io_collect' module.")
  if (IO_strategy == "MPI-IO") call fatal_error ('pc_extract', &
      "Snapshots are already collected, when using the MPI-IO module.")
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
  lstart = .false.; lrun=.true.
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
      call fatal_error("pc_extract","Stop and check")
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
  if (alloc_err /= 0) call fatal_error ('pc_extract', 'Failed to allocate memory for gf.', .true.)
  allocate (global_output (nxgrid,nygrid,nz,num_components), stat=alloc_err)
  if (alloc_err /= 0) call fatal_error ('pc_extract', 'Failed to allocate memory for global quantities.', .true.)
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
  inquire (file=trim(directory_dist)//'/'//filename, exist=ex)
  if (.not. ex) call fatal_error ('pc_extract', 'File not found: '//trim(directory_dist)//'/'//filename, .true.)
  call delete_file(trim(directory_out)//'/'//filename)
  open (lun_output, FILE=trim(directory_out)//'/'//filename, status='new', access='direct', recl=mxgrid*mygrid*io_len)
  do pos = 1, num_quantities
    call delete_file(trim(directory_out)//'/'//trim(filename)//'_'//output_names(pos))
    open (output_luns(pos), FILE=trim(directory_out)//'/'//trim(filename)//'_'//output_names(pos), &
          status='new', access='direct', recl=nxgrid*nygrid*io_len)
  enddo
!
!  Allow modules to do any physics modules do parameter dependent
!  initialization. And final pre-timestepping setup.
!  (must be done before need_XXXX can be used, for example)
!
  call construct_grid(x,y,z,dx,dy,dz)
  call initialize_modules(f)
!
! Loop over processors
!
  write (*,*) "IPZ-layer:"
!
  gz = huge(1.0)
  t_test = huge(1.0)
!
  do ipz = 0, nprocz-1
!
    write (*,*) ipz+1, " of ", nprocz
!
    f = huge(1.0)
    gf = huge(1.0)
!
    iproc_world = ipz * nprocx*nprocy
    lroot = (iproc_world==root)
    lfirst_proc_z = (ipz == 0)
    llast_proc_z = (ipz == nprocz-1)
!
    if (IO_strategy == "collect_xy") then
      ! Take the shortcut, files are well prepared for direct combination
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
        close (lun_input)
        open (lun_input, FILE=trim (directory_snap)//'/'//filename, FORM='unformatted', status='old', position='append')
        call backskip_to_time(lun_input,lroot)
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
      ! Write xy-layer
      do pa = 1, mvar_io
        start_pos = nghost + 1
        end_pos = nghost + nz
        if (lfirst_proc_z) start_pos = 1
        if (llast_proc_z) end_pos = mz
        do pz = start_pos, end_pos
          write (lun_output, rec=pz+ipz*nz+(pa-1)*mzgrid) gf(:,:,pz,pa)
        enddo
      enddo
!
      ! That is all we have to do
      cycle
    endif
!
    gx = huge(1.0)
    gy = huge(1.0)
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
        lfirst_proc_xy = lfirst_proc_x .and. lfirst_proc_y
        lfirst_proc_yz = lfirst_proc_y .and. lfirst_proc_z
        lfirst_proc_xz = lfirst_proc_x .and. lfirst_proc_z
        lfirst_proc_xyz = lfirst_proc_x .and. lfirst_proc_y .and. lfirst_proc_z
!
!  Set up flags for trailing processors in each possible direction and plane
!
        llast_proc_x = (ipx == nprocx-1)
        llast_proc_y = (ipy == nprocy-1)
        llast_proc_xy = llast_proc_x .and. llast_proc_y
        llast_proc_yz = llast_proc_y .and. llast_proc_z
        llast_proc_xz = llast_proc_x .and. llast_proc_z
        llast_proc_xyz = llast_proc_x .and. llast_proc_y .and. llast_proc_z
!
!  Set up directory names `directory' and `directory_snap'.
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
        t_sp = t
!
        if (lroot) t_test = t_sp
        if (t_test /= t_sp) then
          write (*,*) 'ERROR: '//trim(directory_snap)//'/'//trim(filename)// &
                      ' IS INCONSISTENT: t=', t_sp
          stop 1
        endif
!
        ! collect f in gf:
        gf(1+ipx*nx:mx+ipx*nx,1+ipy*ny:my+ipy*ny,:,:) = f(:,:,:,1:mvar_io)
!
!!!        ! calculate all needed pencils:
!!!        call pde (f,df,p)
!
        global_output = impossible
        do imn = 1, ny*nz
          n = nn (imn)
          m = mm (imn)
          lfirstpoint = (imn == 1)      ! true for very first m-n loop
          llastpoint = (imn == (ny*nz)) ! true for very last m-n loop
          do pos = 1, num_quantities
            select case (output_names(pos))
              case ("curl_a")
                ! compute curl A manually, this is a vector quantity:
                call curl (f, iax, tmp)
!!!              case ("bb")
!!!                ! get B from the pencils, this is a vector quantity:
!!!                tmp = p%bb
!!!              case ("b2")
!!!                ! get B^2 from the pencils, this is a scalar quantity:
!!!                tmp(:,1) = p%b2
              case default
                ! by default, put some obviously false numbers...
                if (lroot .and. lfirstpoint) write (*,*) "WARNING: Unknown quantity '"//trim (output_names(pos))//"'"
                tmp = impossible
            endselect
            global_output(1+ipx*nx:nx+ipx*nx,m-nghost,n-nghost,global_start(pos):global_start(pos)-1+global_size(pos)) &
                = tmp(:,1:global_size(pos))
          enddo
        enddo
!
        ! collect x coordinates:
        gx(1+ipx*nx:mx+ipx*nx) = x
        gdx_1(1+ipx*nx:mx+ipx*nx) = dx_1
        gdx_tilde(1+ipx*nx:mx+ipx*nx) = dx_tilde
!
        ! collect y coordinates:
        gy(1+ipy*ny:my+ipy*ny) = y
        gdy_1(1+ipy*ny:my+ipy*ny) = dy_1
        gdy_tilde(1+ipy*ny:my+ipy*ny) = dy_tilde
!
      enddo
    enddo
!
    ! collect z coordinates:
    gz(1+ipz*nz:mz+ipz*nz) = z
    gdz_1(1+ipz*nz:mz+ipz*nz) = dz_1
    gdz_tilde(1+ipz*nz:mz+ipz*nz) = dz_tilde
!
    ! write xy-layer:
    start_pos = nghost + 1
    end_pos = nghost + nz
    if (lfirst_proc_z) start_pos = 1
    if (llast_proc_z) end_pos = mz
    do pa = 1, mvar_io
      do pz = start_pos, end_pos
        write (lun_output, rec=pz+ipz*nz+(pa-1)*mzgrid) gf(:,:,pz,pa)
      enddo
    enddo
    do pos = 1, num_quantities
      do pa = 1, global_size(pos)
        do pz = 1, nz
          write (output_luns(pos), rec=pz+ipz*nz+(pa-1)*nzgrid) global_output(:,:,pz,global_start(pos)-1+pa)
        enddo
      enddo
    enddo
  enddo
!
  ! write additional data:
  close (lun_output)
  do pos = 1, num_quantities
    close (output_luns(pos))
  enddo
  open (lun_output, FILE=trim(directory_out)//'/'//filename, FORM='unformatted', position='append', status='old')
  t_sp = t
  write (lun_output) t_sp, gx, gy, gz, dx, dy, dz
  close (lun_output)
  do pos = 1, num_quantities
    open (output_luns(pos), FILE=trim(directory_out)//'/'//trim(filename)//'_'//output_names(pos), &
        FORM='unformatted', position='append', status='old')
    write (output_luns(pos)) t_sp, gx, gy, gz, dx, dy, dz
    close (output_luns(pos))
  enddo
!
  if (IO_strategy == 'dist') then
    ! write global grid:
    open (lun_output, FILE=trim(directory_out)//'/grid.dat', FORM='unformatted', status='replace')
    write (lun_output) t_sp, gx, gy, gz, dx, dy, dz
    write (lun_output) dx, dy, dz
    write (lun_output) Lx, Ly, Lz
    write (lun_output) gdx_1, gdy_1, gdz_1
    write (lun_output) gdx_tilde, gdy_tilde, gdz_tilde
    close (lun_output)
  endif
!
  print *, 'Writing snapshot for time t =', t
!
!  Give all modules the possibility to exit properly.
!
  call finalize_modules (f)
!
!  Free any allocated memory.
!
  deallocate (gf)
  call fnames_clean_up
  call vnames_clean_up
!
endprogram pc_extract

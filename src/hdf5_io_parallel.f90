! $Id$
!
!  This module takes care of massive parallel HDF5 file Input/Output.
!  We use here only F95 and MPI features for HPC-friendly behaviour.
!
module HDF5_IO
!
  use Cdata
  use Cparam, only: mvar, maux, labellen
  use General, only: loptest, itoa, numeric_precision
  use HDF5
  use Messages, only: fatal_error, warning
  use Mpicomm, only: lroot, mpi_precision, mpiscan_int, mpibcast_int
!
  implicit none
!
  interface input_hdf5
    module procedure input_hdf5_int_0D
    module procedure input_hdf5_int_1D
    module procedure input_hdf5_0D
    module procedure input_hdf5_1D
    module procedure input_hdf5_part_2D
    module procedure input_hdf5_profile_1D
    module procedure input_hdf5_3D
    module procedure input_hdf5_4D
  endinterface
!
  interface output_hdf5
    module procedure output_hdf5_string
    module procedure output_hdf5_int_0D
    module procedure output_hdf5_int_1D
    module procedure output_hdf5_0D
    module procedure output_hdf5_1D
    module procedure output_hdf5_part_2D
    module procedure output_hdf5_profile_1D
    module procedure output_local_hdf5_2D
    module procedure output_hdf5_slice_2D
    module procedure output_local_hdf5_3D
    module procedure output_hdf5_3D
    module procedure output_hdf5_4D
  endinterface
!
  include 'hdf5_io.h'
  include 'mpif.h'
!
  private
!
  integer :: h5_err
  integer(HID_T) :: h5_file, h5_dset, h5_plist, h5_fspace, h5_mspace, h5_dspace, h5_ntype, h5_group
  integer, parameter :: n_dims = 3
  integer(kind=8), dimension(n_dims+1) :: local_size, local_subsize, local_start
  integer(kind=8), dimension(n_dims+1) :: global_size, global_start
  logical :: lcollective = .false., lwrite = .false.
  character (len=fnlen) :: current
!
  type element
    character(len=labellen) :: label
    integer :: component
    type (element), pointer :: previous
  endtype element
  type (element), pointer :: last => null(), last_particle => null()
!
  contains
!***********************************************************************
    subroutine initialize_hdf5
!
!  Initialize the HDF IO.
!
!  28-Oct-2016/PABoudin: coded
!
      ! dimensions for local data portion with ghost layers
      local_size(1) = mx
      local_size(2) = my
      local_size(3) = mz
      local_size(4:n_dims+1) = 1
!
      ! dimensions for local data portion without ghost layers
      local_subsize(1) = nx
      local_subsize(2) = ny
      local_subsize(3) = nz
      local_subsize(4:n_dims+1) = 1
!
      ! include the ghost layers only on the outer box boundaries
      if (lfirst_proc_x) local_subsize(1) = local_subsize(1) + nghost
      if (lfirst_proc_y) local_subsize(2) = local_subsize(2) + nghost
      if (lfirst_proc_z) local_subsize(3) = local_subsize(3) + nghost
      if (llast_proc_x)  local_subsize(1) = local_subsize(1) + nghost
      if (llast_proc_y)  local_subsize(2) = local_subsize(2) + nghost
      if (llast_proc_z)  local_subsize(3) = local_subsize(3) + nghost
!
      ! displacements in HDF5 use C-like format, ie. they start from zero
      local_start(1) = l1 - 1
      local_start(2) = m1 - 1
      local_start(3) = n1 - 1
      local_start(4:n_dims+1) = 0

      ! include lower ghost cells on the lower edge
      ! (upper ghost cells are taken care of by the increased 'local_subsize')
      if (lfirst_proc_x) local_start(1) = local_start(1) - nghost
      if (lfirst_proc_y) local_start(2) = local_start(2) - nghost
      if (lfirst_proc_z) local_start(3) = local_start(3) - nghost
!
      ! size of the data in the global file
      global_size(1) = mxgrid
      global_size(2) = mygrid
      global_size(3) = mzgrid
      global_size(4:n_dims+1) = 1
!
      ! starting position of this processor's data portion in the global file
      global_start(1) = nghost + ipx*nx
      global_start(2) = nghost + ipy*ny
      global_start(3) = nghost + ipz*nz
      global_start(4:n_dims+1) = 0
!
      ! include lower ghost layers on the lower edge
      ! (upper ghost cells are taken care of by the increased 'local_subsize')
      if (lfirst_proc_x) global_start(1) = global_start(1) - nghost
      if (lfirst_proc_y) global_start(2) = global_start(2) - nghost
      if (lfirst_proc_z) global_start(3) = global_start(3) - nghost
!
      ! initialize parallel HDF5 Fortran libaray
      call h5open_f (h5_err)
      call check_error (h5_err, 'initialize_hdf5', 'initialize parallel HDF5 library')
      if (mpi_precision == MPI_REAL) then
        h5_ntype = H5T_NATIVE_REAL
      else
        h5_ntype = H5T_NATIVE_DOUBLE
      endif
!
    endsubroutine initialize_hdf5
!***********************************************************************
    subroutine finalize_hdf5
!
      ! close the HDF5 library
      call h5close_f (h5_err)
      call check_error (h5_err, 'finalize_hdf5', 'close parallel HDF5 library')
!
    endsubroutine finalize_hdf5
!***********************************************************************
    subroutine check_error(code, caller, message, dataset)
!
      integer, intent(in) :: code
      character (len=*), intent(in) :: caller, message
      character (len=*), optional, intent(in) :: dataset
!
      ! check for an HDF5 error
      if (code /= 0) then
        if (present (dataset)) then
          call fatal_error (caller, message//' '//"'"//trim (dataset)//"'"//' in "'//trim (current)//'"', .true.)
        else
          call fatal_error (caller, message, .true.)
        endif
      endif
!
    endsubroutine check_error
!***********************************************************************
    subroutine file_open_hdf5(file, truncate, global, read_only, write)
!
      use General, only: loptest
!
      character (len=*), intent(inout) :: file
      logical, optional, intent(in) :: truncate
      logical, optional, intent(in) :: global
      logical, optional, intent(in) :: read_only
      logical, optional, intent(in) :: write
!
      logical :: ltrunc, lread_only
      integer :: h5_read_mode, pos
!
      if (lcollective .or. lwrite) call file_close_hdf5 ()
!
      lread_only = loptest(read_only)
      h5_read_mode = H5F_ACC_RDWR_F
      if (lread_only) h5_read_mode = H5F_ACC_RDONLY_F
!
      ltrunc = loptest(truncate,.true.)
      if (lread_only) ltrunc = .false.
!
      lcollective = loptest(global,.true.)
      lwrite = loptest(write,lroot)
!
      pos = index (file, '.dat.h5')
      if (pos > 1) file = file(1:pos-1)//'.h5'
      current = trim (file)
!
      if (lcollective) then
        ! setup file access property list
        call h5pcreate_f (H5P_FILE_ACCESS_F, h5_plist, h5_err)
        call check_error (h5_err, 'file_open_hdf5', 'create global file access property list')
        call h5pset_fapl_mpio_f (h5_plist, MPI_COMM_WORLD, MPI_INFO_NULL, h5_err)
        call check_error (h5_err, 'file_open_hdf5', 'modify global file access property list')
!
        if (ltrunc) then
          ! create empty (or truncated) HDF5 file
          call h5fcreate_f (trim (file), H5F_ACC_TRUNC_F, h5_file, h5_err, access_prp=h5_plist)
          call check_error (h5_err, 'file_open_hdf5', 'create global file "'//trim (file)//'"')
        else
          ! open existing HDF5 file
          call h5fopen_f (trim (file), h5_read_mode, h5_file, h5_err, access_prp=h5_plist)
          call check_error (h5_err, 'file_open_hdf5', 'open global file "'//trim (file)//'"')
        endif
!
        call h5pclose_f (h5_plist, h5_err)
        call check_error (h5_err, 'file_open_hdf5', 'close global file access property list')
      elseif (lwrite) then
        if (ltrunc) then
          call h5fcreate_f (trim (file), H5F_ACC_TRUNC_F, h5_file, h5_err)
          call check_error (h5_err, 'file_open_hdf5', 'create global file "'//trim (file)//'"')
        else
          call h5fopen_f (trim (file), h5_read_mode, h5_file, h5_err)
          call check_error (h5_err, 'file_open_hdf5', 'open local file "'//trim (file)//'"')
        endif
      endif
!
    endsubroutine file_open_hdf5
!***********************************************************************
    subroutine file_close_hdf5
!
      if (.not. (lcollective .or. lwrite)) return
!
      call h5fclose_f (h5_file, h5_err)
      call check_error (h5_err, 'file_close_hdf5', 'close file "'//trim (current)//'"')
!
      current = repeat (' ', fnlen)
      lcollective = .false.
      lwrite = .false.
!
    endsubroutine file_close_hdf5
!***********************************************************************
    subroutine create_group_hdf5(name)
!
      character (len=*), intent(in) :: name
!
      if (.not. (lcollective .or. lwrite)) return
      if (exists_in_hdf5 (trim (name))) return
!
      call h5gcreate_f (h5_file, trim (name), h5_group, h5_err)
      call check_error (h5_err, 'create_group_hdf5', 'create group', name)
      call h5gclose_f (h5_group, h5_err)
      call check_error (h5_err, 'create_group_hdf5', 'close group', name)
!
    endsubroutine create_group_hdf5
!***********************************************************************
    logical function exists_in_hdf5(name)
!
      character (len=*), intent(in) :: name
!
      exists_in_hdf5 = .false.
      if (.not. (lcollective .or. lwrite)) return
!
      call h5lexists_f(h5_file, trim (name), exists_in_hdf5, h5_err)
      if (h5_err /= 0) exists_in_hdf5 = .false.
!
    endfunction exists_in_hdf5
!***********************************************************************
    subroutine input_hdf5_int_0D(name, data)
!
      character (len=*), intent(in) :: name
      integer, intent(out) :: data
!
      integer, dimension(1) :: read
!
      call input_hdf5_int_1D (name, read, 1)
      data = read(1)
!
    endsubroutine input_hdf5_int_0D
!***********************************************************************
    subroutine input_local_hdf5_int_1D(name, data, nv)
!
!  Read HDF5 dataset as scalar or array.
!
!  05-Jun-2017/Fred: coded based on input_hdf5_1D
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      integer, dimension (nv), intent(out) :: data
!
      integer(HSIZE_T), dimension(1) :: size
!
      if (lcollective) call check_error (1, 'input_local_hdf5_int_1D', 'local input requires local file')
      if (.not. lwrite) return
!
      size = (/ nv /)
!
      ! open dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_local_hdf5_int_1D', 'open dataset', name)
      ! read dataset
      call h5dread_f (h5_dset, H5T_NATIVE_INTEGER, data, size, h5_err)
      call check_error (h5_err, 'input_local_hdf5_int_1D', 'read data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_local_hdf5_int_1D', 'close dataset', name)
!
    endsubroutine input_local_hdf5_int_1D
!***********************************************************************
    subroutine input_hdf5_int_1D(name, data, nv, same_size)
!
!  Read HDF5 dataset as scalar or array.
!
!  24-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      integer, dimension (nv), intent(out) :: data
      logical, optional, intent(in) :: same_size
!
      logical :: lsame_size
      integer :: total, offset, last
      integer(kind=8), dimension (1) :: local_size_1D, local_subsize_1D, local_start_1D
      integer(kind=8), dimension (1) :: global_size_1D, global_start_1D
      integer(kind=8), dimension (1) :: h5_stride, h5_count
!
      if (.not. lcollective) then
        call input_local_hdf5_int_1D(name, data, nv)
        return
      endif
!
      lsame_size = .false.
      if (present (same_size)) lsame_size = same_size
      if (lsame_size) then
        last = nv * (iproc + 1) - 1
        total = nv * ncpus
        offset = nv * iproc
      else
        call mpiscan_int(nv, offset)
        last = offset - 1
        total = offset
        offset = offset - nv
        call mpibcast_int(total, ncpus-1)
      endif
      local_start_1D = 0
      local_size_1D = nv
      local_subsize_1D = nv
      global_size_1D = total
      global_start_1D = offset
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, local_size_1D, h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'create local memory space', name)
!
      ! open the dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'open dataset', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'input_hdf5_int_1D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'input_hdf5_int_1D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'select collective IO', name)
!
      ! collectively read the data
      call h5dread_f (h5_dset, H5T_NATIVE_INTEGER, data, &
          global_size_1D, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'input_hdf5_int_1D', 'read dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_int_1D', 'close parameter list', name)
!
    endsubroutine input_hdf5_int_1D
!***********************************************************************
    subroutine input_hdf5_0D(name, data)
!
      character (len=*), intent(in) :: name
      real, intent(out) :: data
!
      real, dimension(1) :: input
!
      call input_hdf5_1D (name, input, 1)
      data = input(1)
!
    endsubroutine input_hdf5_0D
!***********************************************************************
    subroutine input_local_hdf5_1D(name, data, nv)
!
!  Read HDF5 dataset as scalar or array.
!
!  26-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (nv), intent(out) :: data
!
      integer(HSIZE_T), dimension(1) :: size
!
      if (lcollective) call check_error (1, 'input_local_hdf5_1D', 'local input requires local file')
      if (.not. lwrite) return
!
      size = (/ nv /)
!
      ! open dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_local_hdf5_1D', 'open dataset', name)
      ! read dataset
      call h5dread_f (h5_dset, h5_ntype, data, size, h5_err)
      call check_error (h5_err, 'input_local_hdf5_1D', 'read data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_local_hdf5_1D', 'close dataset', name)
!
    endsubroutine input_local_hdf5_1D
!***********************************************************************
    subroutine input_hdf5_1D(name, data, nv, same_size)
!
!  Read HDF5 dataset as scalar or array.
!
!  24-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (nv), intent(out) :: data
      logical, optional, intent(in) :: same_size
!
      logical :: lsame_size
      integer :: total, offset, last
      integer(kind=8), dimension (1) :: local_size_1D, local_subsize_1D, local_start_1D
      integer(kind=8), dimension (1) :: global_size_1D, global_start_1D
      integer(kind=8), dimension (1) :: h5_stride, h5_count
!
      if (.not. lcollective) then
        call input_local_hdf5_1D(name, data, nv)
        return
      endif
!
      lsame_size = .false.
      if (present (same_size)) lsame_size = same_size
      if (lsame_size) then
        last = nv * (iproc + 1) - 1
        total = nv * ncpus
        offset = nv * iproc
      else
        call mpiscan_int(nv, offset)
        last = offset - 1
        total = offset
        offset = offset - nv
        call mpibcast_int(total, ncpus-1)
      endif
      local_start_1D = 0
      local_size_1D = nv
      local_subsize_1D = nv
      global_size_1D = total
      global_start_1D = offset
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, local_size_1D, h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'create local memory space', name)
!
      ! open the dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'open dataset', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'input_hdf5_1D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'input_hdf5_1D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'select collective IO', name)
!
      ! collectively read the data
      call h5dread_f (h5_dset, h5_ntype, data, &
          global_size_1D, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'input_hdf5_1D', 'read dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_1D', 'close parameter list', name)
!
    endsubroutine input_hdf5_1D
!***********************************************************************
    subroutine input_hdf5_part_2D(name, data, mv, nc, nv)
!
!  Read HDF5 particle dataset into a distributed array.
!
!  24-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: mv, nc
      real, dimension (mv,nc), intent(out) :: data
      integer, intent(out) :: nv
!
      integer :: pos
      character (len=labellen) :: label
!
      if (.not. lcollective) call check_error (1, 'input_hdf5_part_2D', 'particle input requires a global file', name)
!
      ! read components into particle data array
      do pos=1, nc
        if (name == 'fp') then
          label = 'part/'//trim(index_get(pos, particle=.true.))
        else
          label = trim(name)
          if (nc >= 2) label = trim(label)//'_'//trim(itoa(pos))
        endif
        call input_hdf5_1D (label, data(1:nv,pos), nv)
      enddo
!
    endsubroutine input_hdf5_part_2D
!***********************************************************************
    subroutine input_hdf5_profile_1D(name, data, ldim, gdim, np1, np2)
!
!  Write HDF5 dataset from a 1D profile.
!
!  08-Nov-2018/PABourdin: adapted from output_hdf5_slice_2D
!
      character (len=*), intent(in) :: name
      real, dimension (:) :: data
      integer, intent(in) :: ldim, gdim, np1, np2
!
      integer(kind=8), dimension (1) :: h5_stride, h5_count, loc_dim, glob_dim, loc_start, glob_start, loc_subdim
!
      if (.not. lcollective) call check_error (1, 'input_hdf5_profile_1D', '1D profile input requires global file', name)
!
      loc_dim(1) = ldim
      glob_dim(1) = gdim
      loc_start(1) = 0
      glob_start(1) = np1 - 1
      loc_subdim(1) = np2 - np1 + 1
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, loc_dim, h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'create local memory space', name)
!
      ! open dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'open dataset', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, glob_start, h5_count, h5_err, h5_stride, loc_subdim)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, loc_start, h5_count, h5_err, h5_stride, loc_subdim)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'select collective IO', name)
!
      ! collectively read the data
      call h5dread_f (h5_dset, h5_ntype, data, &
          glob_dim, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'read dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_profile_1D', 'close parameter list', name)
!
    endsubroutine input_hdf5_profile_1D
!***********************************************************************
    subroutine input_hdf5_3D(name, data)
!
!  Read HDF5 dataset from a distributed 3D array.
!
!  26-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      real, dimension (mx,my,mz), intent(out) :: data
!
      integer(kind=8), dimension (n_dims) :: h5_stride, h5_count
      integer, parameter :: n = n_dims
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (n, local_size(1:n), h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'create local memory space', name)
!
      ! open the dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'open dataset', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start(1:n), h5_count, h5_err, h5_stride, local_subsize(1:n))
      call check_error (h5_err, 'input_hdf5_3D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start(1:n), h5_count, h5_err, h5_stride, local_subsize(1:n))
      call check_error (h5_err, 'input_hdf5_3D', 'select hyperslab within file', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'select collective IO', name)
!
      ! collectively read the data
      call h5dread_f (h5_dset, h5_ntype, data, &
          global_size, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'input_hdf5_3D', 'read dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_3D', 'close parameter list', name)
!
    endsubroutine input_hdf5_3D
!***********************************************************************
    subroutine input_hdf5_4D(name, data, nv)
!
!  Read HDF5 dataset from a distributed 4D array.
!
!  26-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (mx,my,mz,nv), intent(out) :: data
!
      integer(kind=8), dimension (n_dims+1) :: h5_stride, h5_count
!
      ! read other 4D array
      global_size(n_dims+1) = nv
      local_size(n_dims+1) = nv
      local_subsize(n_dims+1) = nv
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (n_dims+1, local_size, h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'create local memory space', name)
!
      ! open the dataset
      call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'open dataset', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start, h5_count, h5_err, h5_stride, local_subsize)
      call check_error (h5_err, 'input_hdf5_4D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start, h5_count, h5_err, h5_stride, local_subsize)
      call check_error (h5_err, 'input_hdf5_4D', 'select hyperslab within file', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'select collective IO', name)
!
      ! collectively read the data
      call h5dread_f (h5_dset, h5_ntype, data, &
          global_size, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'input_hdf5_4D', 'read dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'input_hdf5_4D', 'close parameter list', name)
!
    endsubroutine input_hdf5_4D
!***********************************************************************
    subroutine output_hdf5_string(name, data)
!
      character (len=*), intent(in) :: name
      character (len=*), intent(in) :: data
!
      integer(HID_T) :: h5_strtype
      integer(HSIZE_T), dimension(2) :: size
      character (len=len(data)), dimension(1) :: str_data
      integer(SIZE_T), dimension(1) :: str_len
!
      if (lcollective) call check_error (1, 'output_hdf5_string', 'string output requires local file', name)
      if (.not. lwrite) return
!
      str_len(1) = len_trim (data)
      size(1) = str_len(1)
      size(2) = 1
      str_data(1) = data
!
      ! create data space
      call H5Tcopy_f (H5T_STRING, h5_strtype, h5_err)
      call check_error (h5_err, 'output_hdf5_string', 'copy string data space type', name)
      call H5Tset_strpad_f (h5_strtype, H5T_STR_NULLPAD_F, h5_err)
      call check_error (h5_err, 'output_hdf5_string', 'modify string data space type', name)
      call h5screate_simple_f (1, size(1), h5_dspace, h5_err)
      call check_error (h5_err, 'output_hdf5_string', 'create string data space', name)
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_string', 'open string dataset', name)
      else
        ! create dataset
        call h5dcreate_f (h5_file, trim (name), h5_strtype, h5_dspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_string', 'create string dataset', name)
      endif
      ! write dataset
      call h5dwrite_vl_f (h5_dset, h5_strtype, str_data, size, str_len, h5_err, h5_dspace)
      call check_error (h5_err, 'output_hdf5_string', 'write string data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_string', 'close string dataset', name)
      call h5sclose_f (h5_dspace, h5_err)
      call check_error (h5_err, 'output_hdf5_string', 'close string data space', name)
!
    endsubroutine output_hdf5_string
!***********************************************************************
    subroutine output_hdf5_int_0D(name, data)
!
!  Write HDF5 dataset as scalar from one or all processor.
!
!  22-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: data
!
      integer, dimension(1) :: output = (/ 1 /)
!
      output = data
      call output_hdf5_int_1D(name, output, 1, .true.)
!
    endsubroutine output_hdf5_int_0D
!***********************************************************************
    subroutine output_local_hdf5_int_1D(name, data, nv)
!
!  Write HDF5 dataset as scalar from one or all processor.
!
!  23-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      integer, dimension(nv), intent(in) :: data
!
      integer(kind=8), dimension(1) :: size
!
      if (lcollective) call check_error (1, 'output_local_hdf5_int_1D', 'local output requires local file')
      if (.not. lwrite) return
!
      size = (/ nv /)
!
      ! create data space
      call h5screate_simple_f (1, size, h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_int_1D', 'create integer data space', name)
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_int_1D', 'open integer dataset', name)
      else
        ! create dataset
        call h5dcreate_f (h5_file, trim (name), H5T_NATIVE_INTEGER, h5_dspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_int_1D', 'create integer dataset', name)
      endif
      ! write dataset
      call h5dwrite_f (h5_dset, H5T_NATIVE_INTEGER, data, size, h5_err)
      call check_error (h5_err, 'output_local_hdf5_int_1D', 'write integer data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_local_hdf5_int_1D', 'close integer dataset', name)
      call h5sclose_f (h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_int_1D', 'close integer data space', name)
!
    endsubroutine output_local_hdf5_int_1D
!***********************************************************************
    subroutine output_hdf5_int_1D(name, data, nv, same_size)
!
!  Write HDF5 dataset as array from one or all processors.
!
!  24-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      integer, dimension (nv), intent(in) :: data
      logical, optional, intent(in) :: same_size
!
      logical :: lsame_size
      integer :: total, offset, last
      integer(kind=8), dimension (1) :: local_size_1D, local_subsize_1D, local_start_1D
      integer(kind=8), dimension (1) :: global_size_1D, global_start_1D
      integer(kind=8), dimension (1) :: h5_stride, h5_count
!
      if (.not. lcollective) then
        call output_local_hdf5_int_1D(name, data, nv)
        return
      endif
!
      lsame_size = .false.
      if (present (same_size)) lsame_size = same_size
      if (lsame_size) then
        last = nv * (iproc + 1) - 1
        total = nv * ncpus
        offset = nv * iproc
      else
        call mpiscan_int(nv, offset)
        last = offset - 1
        total = offset
        offset = offset - nv
        call mpibcast_int(total, ncpus-1)
      endif
      local_start_1D = 0
      local_size_1D = nv
      local_subsize_1D = nv
      global_size_1D = total
      global_start_1D = offset
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (1, global_size_1D, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, local_size_1D, h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_int_1D', 'open integer dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), H5T_NATIVE_INTEGER, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_int_1D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'output_hdf5_int_1D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'output_hdf5_int_1D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'select collective IO', name)
!
      ! collectively write the data
      call h5dwrite_f (h5_dset, H5T_NATIVE_INTEGER, data, &
          global_size_1D, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'output_hdf5_int_1D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_int_1D', 'close parameter list', name)
!
    endsubroutine output_hdf5_int_1D
!***********************************************************************
    subroutine output_hdf5_0D(name, data)
!
      character (len=*), intent(in) :: name
      real, intent(in) :: data
!
      call output_hdf5_1D (name, (/ data /), 1)
!
    endsubroutine output_hdf5_0D
!***********************************************************************
    subroutine output_local_hdf5_1D(name, data, nv)
!
!  Write HDF5 dataset as scalar or array.
!
!  24-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (nv), intent(in) :: data
!
      integer(kind=8), dimension(1) :: size
!
      if (lcollective) call check_error (1, 'output_local_hdf5_1D', 'local output requires local file')
      if (.not. lwrite) return
!
      size = (/ nv /)
!
      ! create data space
      if (nv <= 1) then
        call h5screate_f (H5S_SCALAR_F, h5_dspace, h5_err)
        call check_error (h5_err, 'output_local_hdf5_1D', 'create scalar data space', name)
        call h5sset_extent_simple_f (h5_dspace, 0, size(1), size(1), h5_err)
      else
        call h5screate_f (H5S_SIMPLE_F, h5_dspace, h5_err)
        call check_error (h5_err, 'output_local_hdf5_1D', 'create simple data space', name)
        call h5sset_extent_simple_f (h5_dspace, 1, size, size, h5_err)
      endif
      call check_error (h5_err, 'output_local_hdf5_1D', 'set data space extent', name)
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_1D', 'open dataset', name)
      else
        ! create dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_dspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_1D', 'create dataset', name)
      endif
      ! write dataset
      if (nv <= 1) then
        call h5dwrite_f (h5_dset, h5_ntype, data(1), size, h5_err)
      else
        call h5dwrite_f (h5_dset, h5_ntype, data, size, h5_err)
      endif
      call check_error (h5_err, 'output_local_hdf5_1D', 'write data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_local_hdf5_1D', 'close dataset', name)
      call h5sclose_f (h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_1D', 'close data space', name)
!
    endsubroutine output_local_hdf5_1D
!***********************************************************************
    subroutine output_hdf5_1D(name, data, nv, same_size)
!
!  Write HDF5 dataset as scalar or array.
!
!  24-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (nv), intent(in) :: data
      logical, optional, intent(in) :: same_size
!
      logical :: lsame_size
      integer :: total, offset, last
      integer(kind=8), dimension (1) :: local_size_1D, local_subsize_1D, local_start_1D
      integer(kind=8), dimension (1) :: global_size_1D, global_start_1D
      integer(kind=8), dimension (1) :: h5_stride, h5_count
!
      if (.not. lcollective) then
        call output_local_hdf5_1D(name, data, nv)
        return
      endif
!
      lsame_size = .false.
      if (present (same_size)) lsame_size = same_size
      if (lsame_size) then
        last = nv * (iproc + 1) - 1
        total = nv * ncpus
        offset = nv * iproc
      else
        call mpiscan_int(nv, offset)
        last = offset - 1
        total = offset
        offset = offset - nv
        call mpibcast_int(total, ncpus-1)
      endif
      local_start_1D = 0
      local_size_1D = nv
      local_subsize_1D = nv
      global_size_1D = total
      global_start_1D = offset
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (1, global_size_1D, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, local_size_1D, h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_1D', 'open dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_1D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'output_hdf5_1D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start_1D, h5_count, h5_err, h5_stride, local_subsize_1D)
      call check_error (h5_err, 'output_hdf5_1D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'select collective IO', name)
!
      ! collectively write the data
      call h5dwrite_f (h5_dset, h5_ntype, data, &
          global_size_1D, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'output_hdf5_1D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_1D', 'close parameter list', name)
!
    endsubroutine output_hdf5_1D
!***********************************************************************
    subroutine output_hdf5_part_2D(name, data, mv, nc, nv)
!
!  Write HDF5 dataset from a distributed particle array.
!
!  22-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: mv, nc
      real, dimension (mv,nc), intent(in) :: data
      integer, intent(in) :: nv
!
      integer :: pos
      character (len=labellen) :: label
!
      if (.not. lcollective) call check_error (1, 'output_hdf5_part_2D', 'particle output requires a global file', name)
!
      ! write components of particle data array
      do pos=1, nc
        if (name == 'fp') then
          label = 'part/'//trim(index_get(pos, particle=.true.))
        else
          label = trim(name)
          if (nc >= 2) label = trim(label)//'_'//trim(itoa(pos))
        endif
        call output_hdf5_1D (label, data(1:nv,pos), nv)
      enddo
!
    endsubroutine output_hdf5_part_2D
!***********************************************************************
    subroutine output_hdf5_profile_1D(name, data, ldim, gdim, ip, np1, np2, ng, lhas_data)
!
!  Write HDF5 dataset from a 1D profile.
!
!  08-Nov-2018/PABourdin: adapted from output_hdf5_slice_2D
!
      character (len=*), intent(in) :: name
      real, dimension (:), intent(in) :: data
      integer, intent(in) :: ldim, gdim, ip, np1, np2, ng
      logical, intent(in) :: lhas_data
!
      integer(kind=8), dimension (1) :: h5_stride, h5_count, loc_dim, glob_dim, loc_start, glob_start, loc_subdim
!
      if (.not. lcollective) call check_error (1, 'output_hdf5_profile_1D', '1D profile output requires global file', name)
!
      loc_dim(1) = ldim
      glob_dim(1) = gdim
      loc_start(1) = np1 - 1
      glob_start(1) = ip * (ldim - 2*ng) + loc_start(1)
      loc_subdim(1) = np2 - np1 + 1
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (1, glob_dim, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (1, loc_dim, h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_profile_1D', 'open dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_profile_1D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, glob_start, h5_count, h5_err, h5_stride, loc_subdim)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'select hyperslab within file', name)
      if (.not. lhas_data) then
        call h5sselect_none_f (h5_fspace, h5_err)
        call check_error (h5_err, 'output_hdf5_profile_1D', &
            'set empty hyperslab within file', name)
      endif
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, loc_start, h5_count, h5_err, h5_stride, loc_subdim)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'select hyperslab within memory', name)
      if (.not. lhas_data) then
        call h5sselect_none_f (h5_mspace, h5_err)
        call check_error (h5_err, 'output_hdf5_profile_1D', &
            'set empty hyperslab within memory', name)
      endif
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'select collective IO', name)
!
      ! collectively write the data
      call h5dwrite_f (h5_dset, h5_ntype, data, &
          glob_dim, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_profile_1D', 'close parameter list', name)
!
    endsubroutine output_hdf5_profile_1D
!***********************************************************************
    subroutine output_local_hdf5_2D(name, data, dim1, dim2)
!
!  Write HDF5 dataset from a local 2D array.
!
!  14-Nov-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: dim1, dim2
      real, dimension (dim1,dim2), intent(in) :: data
!
      integer(kind=8), dimension(2) :: size
!
      if (lcollective) call check_error (1, 'output_local_hdf5_2D', 'local 2D output requires local file')
      if (.not. lwrite) return
!
      size = (/ dim1, dim2 /)
!
      ! create data space
      call h5screate_f (H5S_SIMPLE_F, h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_2D', 'create simple data space', name)
      call h5sset_extent_simple_f (h5_dspace, 2, size, size, h5_err)
      call check_error (h5_err, 'output_local_hdf5_2D', 'set data space extent', name)
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_2D', 'open dataset', name)
      else
        ! create dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_dspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_2D', 'create dataset', name)
      endif
      ! write dataset
      call h5dwrite_f (h5_dset, h5_ntype, data, size, h5_err)
      call check_error (h5_err, 'output_local_hdf5_2D', 'write data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_local_hdf5_2D', 'close dataset', name)
      call h5sclose_f (h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_2D', 'close data space', name)
!
    endsubroutine output_local_hdf5_2D
!***********************************************************************
    subroutine output_hdf5_slice_2D(name, data, ldim1, ldim2, gdim1, gdim2, ip1, ip2, lhas_data)
!
!  Write HDF5 dataset from a 2D slice.
!
!  29-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      real, dimension (:,:), pointer :: data
      integer, intent(in) :: ldim1, ldim2, gdim1, gdim2, ip1, ip2
      logical, intent(in) :: lhas_data
!
      integer(kind=8), dimension (2) :: h5_stride, h5_count, loc_dim, glob_dim, loc_start, glob_start
!
      if (.not. lcollective) call check_error (1, 'output_hdf5_slice_2D', '2D slice output requires global file', name)
!
      loc_dim(1) = ldim1
      loc_dim(2) = ldim2
      glob_dim(1) = gdim1
      glob_dim(2) = gdim2
      loc_start(1) = 0
      loc_start(2) = 0
      glob_start(1) = ip1 * ldim1
      glob_start(2) = ip2 * ldim2
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (2, glob_dim, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (2, loc_dim, h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_slice_2D', 'open dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_slice_2D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, glob_start, h5_count, h5_err, h5_stride, loc_dim)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'select hyperslab within file', name)
      if (.not. lhas_data) then
        call h5sselect_none_f (h5_fspace, h5_err)
        call check_error (h5_err, 'output_hdf5_slice_2D', 'set empty hyperslab within file', name)
      endif
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, loc_start, h5_count, h5_err, h5_stride, loc_dim)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'select hyperslab within memory', name)
      if (.not. lhas_data) then
        call h5sselect_none_f (h5_mspace, h5_err)
        call check_error (h5_err, 'output_hdf5_slice_2D', 'set empty hyperslab within memory', name)
      endif
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'select collective IO', name)
!
      ! collectively write the data
      if (lhas_data) then
        call h5dwrite_f (h5_dset, h5_ntype, data, &
            glob_dim, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      else
        call h5dwrite_f (h5_dset, h5_ntype, 0, &
            glob_dim, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      endif
      call check_error (h5_err, 'output_hdf5_slice_2D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_slice_2D', 'close parameter list', name)
!
    endsubroutine output_hdf5_slice_2D
!***********************************************************************
    subroutine output_local_hdf5_3D(name, data, dim1, dim2, dim3)
!
!  Write HDF5 dataset from a local 3D array.
!
!  26-Nov-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: dim1, dim2, dim3
      real, dimension (dim1,dim2,dim3), intent(in) :: data
!
      integer(kind=8), dimension(3) :: size
!
      if (lcollective) call check_error (1, 'output_local_hdf5_3D', 'local 3D output requires local file')
      if (.not. lwrite) return
!
      size = (/ dim1, dim2, dim3 /)
!
      ! create data space
      call h5screate_f (H5S_SIMPLE_F, h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_3D', 'create simple data space', name)
      call h5sset_extent_simple_f (h5_dspace, 3, size, size, h5_err)
      call check_error (h5_err, 'output_local_hdf5_3D', 'set data space extent', name)
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_3D', 'open dataset', name)
      else
        ! create dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_dspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_local_hdf5_3D', 'create dataset', name)
      endif
      ! write dataset
      call h5dwrite_f (h5_dset, h5_ntype, data, size, h5_err)
      call check_error (h5_err, 'output_local_hdf5_3D', 'write data', name)
      ! close dataset and data space
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_local_hdf5_3D', 'close dataset', name)
      call h5sclose_f (h5_dspace, h5_err)
      call check_error (h5_err, 'output_local_hdf5_3D', 'close data space', name)
!
    endsubroutine output_local_hdf5_3D
!***********************************************************************
    subroutine output_hdf5_3D(name, data)
!
!  Write HDF5 dataset from a distributed 3D array.
!
!  17-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: name
      real, dimension (mx,my,mz), intent(in) :: data
!
      integer(kind=8), dimension (n_dims) :: h5_stride, h5_count
      integer, parameter :: n = n_dims
!
      if (.not. lcollective) call check_error (1, 'output_hdf5_3D', '3D array output requires global file', name)
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (n, global_size(1:n), h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (n, local_size(1:n), h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_3D', 'open dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_3D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start(1:n), h5_count, h5_err, h5_stride, local_subsize(1:n))
      call check_error (h5_err, 'output_hdf5_3D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start(1:n), h5_count, h5_err, h5_stride, local_subsize(1:n))
      call check_error (h5_err, 'output_hdf5_3D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'select collective IO', name)
!
      ! collectively write the data
      call h5dwrite_f (h5_dset, h5_ntype, data, &
          global_size, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'output_hdf5_3D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_3D', 'close parameter list', name)
!
    endsubroutine output_hdf5_3D
!***********************************************************************
    subroutine output_hdf5_4D(name, data, nv)
!
!  Write HDF5 dataset from a distributed 4D array.
!
!  26-Oct-2016/PABourdin: coded
!
      character (len=*), intent(in) :: name
      integer, intent(in) :: nv
      real, dimension (mx,my,mz,nv), intent(in) :: data
!
      integer(kind=8), dimension (n_dims+1) :: h5_stride, h5_count
!
      if (.not. lcollective) call check_error (1, 'output_hdf5_4D', '4D array output requires global file', name)
!
      ! write other 4D array
      global_size(n_dims+1) = nv
      local_size(n_dims+1) = nv
      local_subsize(n_dims+1) = nv
!
      ! define 'file-space' to indicate the data portion in the global file
      call h5screate_simple_f (n_dims+1, global_size, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'create global file space', name)
!
      ! define 'memory-space' to indicate the local data portion in memory
      call h5screate_simple_f (n_dims+1, local_size, h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'create local memory space', name)
!
      if (exists_in_hdf5 (name)) then
        ! open dataset
        call h5dopen_f (h5_file, trim (name), h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_4D', 'open dataset', name)
      else
        ! create the dataset
        call h5dcreate_f (h5_file, trim (name), h5_ntype, h5_fspace, h5_dset, h5_err)
        call check_error (h5_err, 'output_hdf5_4D', 'create dataset', name)
      endif
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'close global file space', name)
!
      ! define local 'hyper-slab' in the global file
      h5_stride(:) = 1
      h5_count(:) = 1
      call h5dget_space_f (h5_dset, h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'get dataset for file space', name)
      call h5sselect_hyperslab_f (h5_fspace, H5S_SELECT_SET_F, global_start, h5_count, h5_err, h5_stride, local_subsize)
      call check_error (h5_err, 'output_hdf5_4D', 'select hyperslab within file', name)
!
      ! define local 'hyper-slab' portion in memory
      call h5sselect_hyperslab_f (h5_mspace, H5S_SELECT_SET_F, local_start, h5_count, h5_err, h5_stride, local_subsize)
      call check_error (h5_err, 'output_hdf5_4D', 'select hyperslab within memory', name)
!
      ! prepare data transfer
      call h5pcreate_f (H5P_DATASET_XFER_F, h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'set data transfer properties', name)
      call h5pset_dxpl_mpio_f (h5_plist, H5FD_MPIO_COLLECTIVE_F, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'select collective IO', name)
!
      ! collectively write the data
      call h5dwrite_f (h5_dset, h5_ntype, data, &
          global_size, h5_err, file_space_id=h5_fspace, mem_space_id=h5_mspace, xfer_prp=h5_plist)
      call check_error (h5_err, 'output_hdf5_4D', 'write dataset', name)
!
      ! close data spaces, dataset, and the property list
      call h5sclose_f (h5_fspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'close file space', name)
      call h5sclose_f (h5_mspace, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'close memory space', name)
      call h5dclose_f (h5_dset, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'close dataset', name)
      call h5pclose_f (h5_plist, h5_err)
      call check_error (h5_err, 'output_hdf5_4D', 'close parameter list', name)
!
    endsubroutine output_hdf5_4D
!***********************************************************************
    subroutine output_dim(file, mx_out, my_out, mz_out, mxgrid_out, mygrid_out, mzgrid_out, mvar_out, maux_out, mglobal)
!
!  Write dimension to file.
!
!  02-Nov-2018/PABourdin: coded
!
      character (len=*), intent(in) :: file
      integer, intent(in) :: mx_out, my_out, mz_out, mxgrid_out, mygrid_out, mzgrid_out, mvar_out, maux_out, mglobal
!
      character (len=fnlen) :: filename
!
      filename = trim(datadir)//'/'//trim(file)//'.h5'
      call file_open_hdf5 (filename, global=.false., truncate=.true.)
      call output_hdf5 ('nx', mx_out - 2*nghost)
      call output_hdf5 ('ny', my_out - 2*nghost)
      call output_hdf5 ('nz', mz_out - 2*nghost)
      call output_hdf5 ('mx', mx_out)
      call output_hdf5 ('my', my_out)
      call output_hdf5 ('mz', mz_out)
      call output_hdf5 ('nxgrid', mxgrid_out - 2*nghost)
      call output_hdf5 ('nygrid', mygrid_out - 2*nghost)
      call output_hdf5 ('nzgrid', mzgrid_out - 2*nghost)
      call output_hdf5 ('mxgrid', mxgrid_out)
      call output_hdf5 ('mygrid', mygrid_out)
      call output_hdf5 ('mzgrid', mzgrid_out)
      call output_hdf5 ('mvar', mvar_out)
      call output_hdf5 ('maux', maux_out)
      call output_hdf5 ('mglobal', mglobal)
      call output_hdf5 ('precision', numeric_precision())
      call output_hdf5 ('nghost', nghost)
      if (lprocz_slowest) then
        call output_hdf5 ('procz_slowest', 1)
      else
        call output_hdf5 ('procz_slowest', 0)
      endif
      call output_hdf5 ('nprocx', nprocx)
      call output_hdf5 ('nprocy', nprocy)
      call output_hdf5 ('nprocz', nprocz)
      call output_hdf5 ('ncpus', ncpus)
      call file_close_hdf5
!
    endsubroutine output_dim
!***********************************************************************
    subroutine index_append(varname,ivar,vector,array)
!
! 14-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: varname
      integer, intent(in) :: ivar
      integer, intent(in), optional :: vector
      integer, intent(in), optional :: array
!
      integer :: pos
!
      ! omit all unused variables
      if (ivar <= 0) return
!
      ! ignore vectors because they get expanded in 'farray_index_append'
      if (present (vector) .and. .not. present (array)) return
!
      if (lroot) open(3,file=trim(datadir)//'/'//trim(index_pro), POSITION='append')
      if (present (array)) then
        ! backwards-compatibile expansion: iuud => indgen(vector)
        if (lroot) write(3,*) trim(varname)//'=indgen('//trim(itoa(array))//')*'//trim(itoa(vector))//'+'//trim(itoa(ivar))
        ! expand array: iuud => iuud#=(#-1)*vector+ivar
        do pos=1, array
          if (lroot) write(3,*) trim(varname)//trim(itoa(pos))//'='//trim(itoa((pos-1)*vector+ivar))
          call index_register (trim(varname)//trim(itoa(pos)), (pos-1)*vector+ivar)
        enddo
      else
        if (lroot) write(3,*) trim(varname)//'='//trim(itoa(ivar))
        call index_register (trim(varname), ivar)
      endif
      if (lroot) close(3)
!
    endsubroutine index_append
!***********************************************************************
    subroutine particle_index_append(label,ilabel)
!
! 22-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: label
      integer, intent(in) :: ilabel
!
      integer, parameter :: lun_output = 92
!
      if (lroot) then
        open(lun_output,file=trim(datadir)//'/'//trim(particle_index_pro), POSITION='append')
        write(lun_output,*) trim(label)//'='//trim(itoa(ilabel))
        close(lun_output)
      endif
      call index_register (trim(label), ilabel, particle=.true.)
!
    endsubroutine particle_index_append
!***********************************************************************
    function index_get(ivar,particle)
!
! 17-Oct-2018/PABourdin: coded
!
      character (len=labellen) :: index_get
      integer, intent(in) :: ivar
      logical, optional, intent(in) :: particle
!
      type (element), pointer, save :: current => null()
      integer, save :: max_reported = -1
!
      index_get = ''
      current => last
      if (loptest (particle)) current => last_particle
      do while (associated (current))
        if (current%component == ivar) then
          index_get = current%label(2:len(current%label))
          exit
        endif
        current => current%previous
      enddo
!
      if (lroot .and. (index_get == '') .and. (max_reported < ivar)) then
        call warning ('index_get', 'f-array index #'//trim (itoa (ivar))//' not found!')
        if (max_reported == -1) then
          call warning ('index_get', &
              'This likely indicates a mismatch in the mvar/maux contributions of the modules that are active in this setup.')
          call warning ('index_get', &
              'Alternatively, some variables may not have been initialized correctly. Both is an error and should be fixed!')
        endif
        max_reported = ivar
      endif
!
    endfunction index_get
!***********************************************************************
    subroutine index_register(varname,ivar,particle)
!
! 17-Oct-2018/PABourdin: coded
!
      character (len=*), intent(in) :: varname
      integer, intent(in) :: ivar
      logical, optional, intent(in) :: particle
!
      type (element), pointer, save :: new => null()
!
      if (.not. loptest (particle)) then
        ! ignore variables that are not written
        if ((ivar < 1) .or. (ivar > mfarray)) return
      endif
!
      ! ignore non-index variables
      if ((varname(1:1) /= 'i') .or. (varname(2:2) == '_')) return
!
      ! append this entry to an internal list of written HDF5 variables
      allocate (new)
      nullify (new%previous)
      if (loptest (particle)) then
        if (associated (last_particle)) new%previous => last_particle
      else
        if (associated (last)) new%previous => last
      endif
      new%label = trim(varname)
      new%component = ivar
      if (loptest (particle)) then
        last_particle => new
      else
        last => new
      endif
!
    endsubroutine index_register
!***********************************************************************
    subroutine index_reset()
!
! 14-Oct-2018/PABourdin: coded
!
      type (element), pointer, save :: current => null()
      integer, parameter :: lun_output = 92
!
      if (lroot) then
        open(lun_output,file=trim(datadir)//'/'//trim(index_pro),status='replace')
        close(lun_output)
        open(lun_output,file=trim(datadir)//'/'//trim(particle_index_pro),status='replace')
        close(lun_output)
      endif
!
      do while (associated (last))
        current => last
        last => last%previous
        deallocate (current)
        nullify (current)
      enddo
!
      do while (associated (last_particle))
        current => last_particle
        last_particle => last%previous
        deallocate (current)
        nullify (current)
      enddo
!
    endsubroutine index_reset
!***********************************************************************
endmodule HDF5_IO

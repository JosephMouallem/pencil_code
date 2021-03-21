! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lstreamlines = .true.
!
!***************************************************************
module Streamlines
!
  use Cdata
  use Cparam
  use Messages, only: fatal_error
!
  implicit none
!
  public :: tracers_prepare, wtracers, read_streamlines_init_pars
  public :: write_streamlines_init_pars, read_streamlines_run_pars, write_streamlines_run_pars
!
  include 'mpif.h'
!
! a few constants
  integer :: VV_RQST = 10
  integer :: VV_RCV = 20
  integer :: FINISHED = 99
!
  real, public :: ttracers  ! time of the tracer calculation
  integer, public :: ntracers
! Time value to be written together with the tracers.
  real :: ttrace_write
!
! parameters for the stream line tracing
  integer, public :: trace_sub = 1
  character (len=labellen), public :: trace_field = ''
! the integrated quantity along the field line
  character (len=labellen), public :: int_q = ''
  real, public :: h_max = 0.4, h_min = 1e-4, l_max = 10., tol = 1e-4
! MPI stuff
  integer, dimension (MPI_STATUS_SIZE) :: status
  integer :: grid_pos_b(3), request, receive = 0
!
  namelist /streamlines_init_pars/ &
    trace_field, trace_sub, h_max, h_min, l_max, tol, int_q
  namelist /streamlines_run_pars/ &
    trace_field, trace_sub, h_max, h_min, l_max, tol, int_q
!
  contains
!***********************************************************************
  subroutine tracers_prepare()
!
!  Prepare ltracers for writing tracers into tracers file
!
!  12-mar-12/simon: coded
!
    use Sub, only: update_snaptime, read_snaptime
!
    integer, save :: ifirst=0
!
    character (len=fnlen) :: file
!
!  Output tracer-data in 'ttracers' time intervals
!
    file = trim(datadir)//'/ttracers.dat'
    if (ifirst==0) then
      call read_snaptime(file,ttracers,ntracers,dtracers,t)
      ifirst=1
    endif
!
!  This routine sets ltracers=T whenever its time to write the tracers
!
    call update_snaptime(file,ttracers,ntracers,dtracers,t,ltracers)
!
!  Save current time so that the time that is written out is not
!  from the next time step
!
    if (ltracers) ttrace_write = t
!
  endsubroutine tracers_prepare
!***********************************************************************
  subroutine get_grid_pos(phys_pos, grid_pos, n_int, outside)
!
! Determines the grid cell in this core for the physical location 'phys_pos'.
!
! 13-feb-12/simon: coded
!
    real, dimension(3) :: phys_pos
    integer, dimension(8,3) :: grid_pos
    real :: delta
    integer :: j, n_int, outside
!   number of adjacent points in each direction which lie within the physical domain
    integer :: x_adj, y_adj, z_adj
!
    intent(in) :: phys_pos
    intent(out) :: grid_pos, n_int, outside
!
    outside = 0
    n_int = 0
!
    delta = Lx
    x_adj = 1
    do j=1,nxgrid
      if ((abs(phys_pos(1) - xgrid(j)) <= dx) .and. x_adj <= 2) then
        grid_pos(1:8:x_adj,1) = j
        x_adj = x_adj + 1
      endif
      if (abs(phys_pos(1) - xgrid(j)) < delta) then
        delta = abs(phys_pos(1) - xgrid(j))
      endif
    enddo
    x_adj = x_adj - 1
!   check if the point lies outside the domain
    if (delta > (dx/(2-2.**(-15)))) outside = 1
!
    delta = Ly
    y_adj = 1
    if (outside == 0) then
    do j=1,nygrid
      if ((abs(phys_pos(2) - ygrid(j)) <= dy) .and. y_adj <= 2) then
        grid_pos(1:8:x_adj*y_adj,2) = j
        grid_pos(x_adj:8:x_adj*y_adj,2) = j
        y_adj = y_adj + 1
      endif
      if (abs(phys_pos(2) - ygrid(j)) < delta) then
        delta = abs(phys_pos(2) - ygrid(j))
      endif
    enddo
    y_adj = y_adj - 1
!   check if the point lies outside the domain
    if (delta > (dy/(2-2.**(-15)))) outside = 1
    endif
!
    delta = Lz
    z_adj = 1
    if (outside == 0) then
    do j=1,nzgrid
      if ((abs(phys_pos(3) - zgrid(j)) <= dz) .and. z_adj <= 2) then
        if (z_adj == 1) then
          grid_pos(1:8,3) = j
        else
          grid_pos(1:8:x_adj*y_adj*z_adj,3) = j
          grid_pos(x_adj:8:x_adj*y_adj*z_adj,3) = j
          grid_pos(y_adj:8:x_adj*y_adj*z_adj,3) = j
          grid_pos(x_adj*y_adj:8:x_adj*y_adj*z_adj,3) = j
          grid_pos(x_adj+y_adj-1:8:x_adj*y_adj*z_adj,3) = j
        endif
        z_adj = z_adj + 1
      endif
      if (abs(phys_pos(3) - zgrid(j)) < delta) then
        delta = abs(phys_pos(3) - zgrid(j))
      endif
    enddo
    z_adj = z_adj - 1
!   check if the point lies outside the domain
    if (delta > (dz/(2-2.**(-15)))) outside = 1
    endif
!
    n_int = x_adj * y_adj * z_adj
!
!   consider the processor indices
    grid_pos(:,1) = grid_pos(:,1) - nx*ipx
    grid_pos(:,2) = grid_pos(:,2) - ny*ipy
    grid_pos(:,3) = grid_pos(:,3) - nz*ipz
!
    if ((n_int == 0) .and. (outside == 0)) write(*,*) iproc, &
        "error: n_int == 0: ", phys_pos, delta, dz/(2-2.**(-15))
!
  endsubroutine get_grid_pos
!***********************************************************************
  subroutine interpolate_vv(phys_pos, grid_pos, vv_adj, n_int, vv_int)
!
! Interpolates the vector field by taking the adjacent values.
!
! 27-apr-12/simon: coded
!
    real, dimension(3) :: phys_pos
    integer, dimension(8,3) :: grid_pos
    real, dimension(8,3+mfarray) :: vv_adj
    integer :: n_int, j
    real, dimension(3+mfarray) :: vv_int
    real, dimension(8) :: weight
!
    intent(in) :: phys_pos, grid_pos, vv_adj, n_int
    intent(out) :: vv_int
!
    vv_int(:) = 0
    do j=1,n_int
      weight(j) = (dx-abs(phys_pos(1)-xgrid(grid_pos(j,1)+ipx*nx)))* &
          (dy-abs(phys_pos(2)-ygrid(grid_pos(j,2)+ipy*ny)))* &
          (dz-abs(phys_pos(3)-zgrid(grid_pos(j,3)+ipz*nz)))
      vv_int = vv_int + weight(j)*vv_adj(j,:)
    enddo
    if (sum(weight(1:n_int)) == 0) then
      vv_int = vv_int
    else
      vv_int = vv_int/sum(weight(1:n_int))
    endif
!
  endsubroutine interpolate_vv
!***********************************************************************
  subroutine get_vector(f, grid_pos, vvb, vv)
!
! Gets the vector field value and the f-array at grid_pos from another core.
!
! 20-feb-12/simon: coded
!
    integer :: grid_pos(3), grid_pos_send(3)
    real, dimension (mx,my,mz,mfarray) :: f
    real, dimension(3+mfarray) :: vvb, vvb_send
    real, pointer, dimension (:,:,:,:) :: vv
    integer :: proc_id, x_proc, y_proc, z_proc, ierr
!   variables for the non-blocking mpi communication
    integer, dimension (MPI_STATUS_SIZE) :: status_recv
    integer :: sent, receiving, request_rcv, flag_rcv
!
    intent(out) :: vvb
!
    sent = 0; receiving = 0; flag_rcv = 0
!
!   find the corresponding core
    x_proc = ipx + floor((grid_pos(1)-1)/real(nx))
    y_proc = ipy + floor((grid_pos(2)-1)/real(ny))
    z_proc = ipz + floor((grid_pos(3)-1)/real(nz))
    proc_id = x_proc + nprocx*y_proc + nprocx*nprocy*z_proc
    if (proc_id > ncpus-1) &
        call fatal_error("streamlines", "proc_id > ncpus")
!
!   find the grid position in the other core
    grid_pos_send(1) = grid_pos(1) - (x_proc - ipx)*nx
    grid_pos_send(2) = grid_pos(2) - (y_proc - ipy)*ny
    grid_pos_send(3) = grid_pos(3) - (z_proc - ipz)*nz
!
    if (proc_id == iproc) call fatal_error("streamlines", "sending and receiving core are the same")
!
    do
!     To avoid deadlocks check if there is any request to this core.
      call send_vec(vv, f)
!
!     Now it should be safe to make a blocking send request.
!
!     start non-blocking receive and blocking send
      if (receiving == 0) then
        call MPI_IRECV(vvb,3+mfarray,MPI_REAL,proc_id,VV_RCV,MPI_comm_world,request_rcv,ierr)
        if (ierr /= MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
        receiving = 1
      else
        call MPI_TEST(request_rcv,flag_rcv,status_recv,ierr)
        if (ierr /= MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_TEST failed")
      endif
      if (sent == 0) then
        call MPI_SEND(grid_pos_send,3,MPI_integer,proc_id,VV_RQST,MPI_comm_world,ierr)
        if (ierr /= MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_SEND could not send request")
        sent = 1
      endif
!
      if (flag_rcv == 1) exit
    enddo
!
  endsubroutine get_vector
!***********************************************************************
  subroutine trace_single(tracer,f,vv)
!
!  Trace a single field line until it hits the core boundary.
!
!   20-mar-14/simon: coded
!
    real, dimension(7) :: tracer
    real, dimension (mx,my,mz,mfarray) :: f
    real, pointer, dimension (:,:,:,:) :: vv   ! vector field which is beaing traced
!
    integer :: j
!   the "borrowed" vector from the adjacent core
    real, dimension (3+mfarray) :: vvb
!   the vector from the adjacent grid points
    real, dimension (8,3+mfarray) :: vv_adj
!   the interpolated vector from the adjacent value
    real, dimension (3+mfarray) :: vv_int
!   the "borrowed" f-array at a given point for the field line integration
    real, dimension (mfarray) :: fb
    real :: dh, dist2
!   auxilliary vectors for the tracing
    real, dimension(3) :: x_mid, x_single, x_half, x_double
!   adjacent grid point around this position
    integer :: grid_pos(8,3)
    integer :: loop_count, outside
!   number of adjacent grid points for the field interpolation
    integer :: n_int

!   initial step length dh
    dh = sqrt(h_max*h_min)
    loop_count = 0
    outside = 0
!
    call send_vec(vv, f)
!
    do
!     (a) Single step (midpoint method):
      call get_grid_pos(tracer(3:5),grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
            (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(tracer(3:5),grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_mid = tracer(3:5) + 0.5*dh*vv_int(1:3)
!
      call get_grid_pos(x_mid,grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
          (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(x_mid,grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_single = tracer(3:5) + dh*vv_int(1:3)
!
!     (b) Two steps with half stepsize:
      call get_grid_pos(tracer(3:5),grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
            (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(tracer(3:5),grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_mid = tracer(3:5) + 0.25*dh*vv_int(1:3)
!
      call get_grid_pos(x_mid,grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
            (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(x_mid,grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_half = tracer(3:5) + 0.5*dh*vv_int(1:3)
!
      call get_grid_pos(x_half,grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
            (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(x_half,grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_mid = x_half + 0.25*dh*vv_int(1:3)
!
      call get_grid_pos(x_mid,grid_pos,n_int,outside)
      if (outside == 1) exit
      do j=1,n_int
        if (any(grid_pos(j,:) <= 0) .or. (grid_pos(j,1) > nx) .or. &
            (grid_pos(j,2) > ny) .or. (grid_pos(j,3) > nz)) then
!           write(*,*) iproc, "grid_pos(j,:) = ", grid_pos(j,:), " outside = ", outside
          call get_vector(f, grid_pos(j,:), vvb, vv)
          vv_adj(j,:) = vvb
        else
          vv_adj(j,1:3) = vv(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
          vv_adj(j,4:) = f(grid_pos(j,1),grid_pos(j,2),grid_pos(j,3),:)
        endif
      enddo
      call interpolate_vv(x_mid,grid_pos,vv_adj,n_int,vv_int)
      call send_vec(vv, f)
      x_double = x_half + 0.5*dh*vv_int(1:3)
      fb = vv_int(4:)
!
!     (c) Check error (difference between methods):
      dist2 = dot_product((x_single-x_double),(x_single-x_double))
      if (dist2 > tol**2) then
        dh = 0.5*dh
        if (abs(dh) < h_min) then
          write(*,*) "Error: stepsize underflow"
          exit
        endif
      else
        tracer(6) = tracer(6) + &
            sqrt(dot_product((tracer(3:5)-x_double), (tracer(3:5)-x_double)))
!       integrate the requested quantity along the field line
        if (int_q == 'curlyA') then
          tracer(7) = tracer(7) + &
              dot_product(fb(iax:iaz), (x_double - tracer(3:5)))
        endif
        tracer(3:5) = x_double
        if (abs(dh) < h_min) dh = 2*dh
!
! !       check if the new point lies in another cpu domain
!         call get_grid_pos(x_double, grid_pos, n_int, outside)
!         if (.not. any((grid_pos(:,1) > 0) .and. (grid_pos(:,1) <= nx) .and. &
!                       (grid_pos(:,2) > 0) .and. (grid_pos(:,2) <= ny) .and. &
!                       (grid_pos(:,3) > 0) .and. (grid_pos(:,3) <= nz))) then
!         communicate tracer to corresponding core

!         endif
      endif
!
      if (tracer(6) >= l_max) exit
!
      loop_count = loop_count + 1
    enddo
  endsubroutine trace_single
!***********************************************************************
  subroutine trace_streamlines(f,tracers,n_tracers,vv)
!
!   trace stream lines of the vetor field stored in vv
!
!   13-feb-12/simon: coded
!   20-mar-14/simon: moved the bulk of it into 'trace_single' routine
!
    use Mpicomm, only: mpibarrier
!
    real, dimension (mx,my,mz,mfarray) :: f
    real, pointer, dimension (:,:) :: tracers
    integer :: n_tracers
    real, pointer, dimension (:,:,:,:) :: vv   ! vector field which is beaing traced
!   MPI communication
    integer :: tracer_idx, ierr, proc_idx, flag
!   array with all finished cores
    integer :: finished_tracing(nprocx*nprocy*nprocz)
!   variables for the final non-blocking mpi communication
    integer :: request_finished_send(nprocx*nprocy*nprocz)
    integer :: request_finished_rcv(nprocx*nprocy*nprocz)
!
    real, dimension (3+mfarray) :: vvb
    integer :: grid_pos(3)
!
!     receive = 0
!
    call send_vec(vv, f)
!
    do tracer_idx=1,n_tracers
      tracers(tracer_idx, 6:7) = 0.
      call trace_single(tracers(tracer_idx,:), f, vv)
!
!     check if tracer lies in different core
!       if tracer in different core then
!         communicate tracer to other core
!       endif
    enddo
!
!   Tell every other core that we have finished.
    finished_tracing(:) = 0
    finished_tracing(iproc+1) = 1
    do proc_idx=0,(nprocx*nprocy*nprocz-1)
      if (proc_idx /= iproc) then
        call MPI_ISEND(finished_tracing(iproc+1), 1, MPI_integer, proc_idx, FINISHED, &
            MPI_comm_world, request_finished_send(proc_idx+1), ierr)
        if (ierr /= MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_ISEND could not send")
        call MPI_IRECV(finished_tracing(proc_idx+1), 1, MPI_integer, proc_idx, FINISHED, &
            MPI_comm_world, request_finished_rcv(proc_idx+1), ierr)
        if (ierr /= MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
      endif
    enddo
!
!   make sure that we can receive any request as long as not all cores are finished
    do
      call send_vec(vv, f)
!
!     Check if a core has finished and update finished_tracing array.
      do proc_idx=0,(nprocx*nprocy*nprocz-1)
        if ((proc_idx /= iproc) .and. (finished_tracing(proc_idx+1) == 0)) then
          flag = 0
          call MPI_TEST(request_finished_rcv(proc_idx+1),flag,status,ierr)
          if (ierr /= MPI_SUCCESS) &
              call fatal_error("streamlines", "MPI_TEST failed")
          if (flag == 1) then
            finished_tracing(proc_idx+1) = 1
          endif
        endif
      enddo
!
      if (sum(finished_tracing) == nprocx*nprocy*nprocz) exit
    enddo
!
  endsubroutine trace_streamlines
!***********************************************************************
  subroutine send_vec(vv, f)
!
!  Create a receive request for asynchronous communication of field information
!  and perform such communication if required.
!
!   20-mar-14/simon: coded
!
    real, pointer, dimension (:,:,:,:) :: vv   ! vector field which is beaing traced
    real, dimension (mx,my,mz,mfarray) :: f
!   borrowed position on the grid
    integer :: ierr, flag
!   the "borrowed" vector from the adjacent core
    real, dimension (3+mfarray) :: vvb
!
    do
        if (receive == 0) then
          grid_pos_b(:) = 0
          call MPI_IRECV(grid_pos_b,3,MPI_integer,MPI_ANY_SOURCE,VV_RQST,MPI_comm_world,request,ierr)
          if (ierr /= MPI_SUCCESS) then
              call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
              exit
          endif
          receive = 1
        endif
!
!       check if there is any request for the vector field from another core
        if (receive == 1) then
          flag = 0
          call MPI_TEST(request,flag,status,ierr)
          if (flag == 1) then
!             receive completed, send the vector field
              vvb(1:3) = vv(grid_pos_b(1),grid_pos_b(2),grid_pos_b(3),:)
              vvb(4:) = f(grid_pos_b(1),grid_pos_b(2),grid_pos_b(3),:)
              call MPI_SEND(vvb,3+mfarray,MPI_REAL,status(MPI_SOURCE),VV_RCV,MPI_comm_world,ierr)
              if (ierr /= MPI_SUCCESS) then
                call fatal_error("streamlines", "MPI_SEND could not send")
                exit
              endif
              receive = 0
          endif
        endif
!
        if (receive == 1) exit
    enddo
  endsubroutine send_vec
!***********************************************************************
  subroutine wtracers(f,path)
!
!   Write the tracers values to tracer.dat.
!   This should be called during runtime.
!
!   12-mar-12/simon: coded
!
    use General, only: keep_compiler_quiet
    use Sub, only: curl
!
    real, dimension (mx,my,mz,mfarray) :: f
    character(len=*) :: path
!   the integrated quantity along the field line
    real, pointer, dimension (:,:) :: tracers
!   the traced field
    real, pointer, dimension (:,:,:,:) :: vv
!   filename for the tracer output
    character(len=1024) :: filename, str_tmp
    integer :: j, k
!
    call keep_compiler_quiet(path)
!
!   allocate the memory for the tracers
    allocate(tracers(nx*ny*trace_sub**2,7))
!   allocate memory for the traced field
    allocate(vv(nx,ny,nz,3))
!
!   prepare the traced field
    if (lmagnetic) then
      if (trace_field == 'bb' .and. ipz == 0) then
!       convert the magnetic vector potential into the magnetic field
        do m=m1,m2
          do n=n1,n2
            call curl(f,iaa,vv(:,m-nghost,n-nghost,:))
          enddo
        enddo
      endif
    endif
!   TODO: include other fields as well
!
!   create the initial seeds at z(1+nghost)-ipz*nz*dz+dz
    do j=1,nx*trace_sub
      do k=1,ny*trace_sub
        tracers(j+(k-1)*(nx*trace_sub),1) = x(1+nghost) + (dx/trace_sub)*(j-1)
        tracers(j+(k-1)*(nx*trace_sub),2) = y(1+nghost) + (dy/trace_sub)*(k-1)
        tracers(j+(k-1)*(nx*trace_sub),3) = tracers(j+(k-1)*(nx*trace_sub),1)
        tracers(j+(k-1)*(nx*trace_sub),4) = tracers(j+(k-1)*(nx*trace_sub),2)
        tracers(j+(k-1)*(nx*trace_sub),5) = z(1+nghost)-ipz*nz*dz+dz
        tracers(j+(k-1)*(nx*trace_sub),6) = 0.
        tracers(j+(k-1)*(nx*trace_sub),7) = 0.
      enddo
    enddo
    write(str_tmp, "(I10.1,A)") iproc, '/tracers.dat'
    write(filename, *) 'data/proc', adjustl(trim(str_tmp))
    open(unit = 1, file = adjustl(trim(filename)), form = "unformatted", position = "append")
    call trace_streamlines(f,tracers,nx*ny*trace_sub**2,vv)
    write(1) ttrace_write, tracers(:,:)
    close(1)
!
    deallocate(tracers)
    deallocate(vv)
  end subroutine wtracers
!***********************************************************************
    subroutine read_streamlines_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=streamlines_init_pars, IOSTAT=iostat)
!
    endsubroutine read_streamlines_init_pars
!***********************************************************************
    subroutine write_streamlines_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=streamlines_init_pars)
!
    endsubroutine write_streamlines_init_pars
!***********************************************************************
    subroutine read_streamlines_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=streamlines_run_pars, IOSTAT=iostat)
!
    endsubroutine read_streamlines_run_pars
!***********************************************************************
    subroutine write_streamlines_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=streamlines_run_pars)
!
    endsubroutine write_streamlines_run_pars
!***********************************************************************
endmodule Streamlines

! $Id$
!
!***********************************************************************
program rvid_box
!
!  read and combine slices from individual processor directories data
!  /procN, write them to data/, where they can be used by rvid_box.pro.
!
!  Adapated from read_videofiles.f90 but reads all files without waiting
!  for a user input.
!
!  17-dec-10/bing: coded
!
      use Cparam
      use General
      use File_io
!
      implicit none
!
      real, allocatable, dimension (:,:,:) :: xy_t,xz_t,yz_t
      real, allocatable, dimension (:) :: t_array
!
      real, dimension (nx,ny) :: xy_loc,xy_loc_dummy
      real, dimension (nx,nz) :: xz_loc,xz_loc_dummy
      real, dimension (ny,nz) :: yz_loc,yz_loc_dummy
!
      integer :: ipx,ipy,ipz,iproc,it,istride
      integer :: ipx1 = -1
      integer :: ipy1 = -1, ipy2 = -1
      integer :: ipz1 = -1, ipz2 = -1, ipz3 = -1, ipz4 = -1
      integer :: lun_pos=33, lun_video=34, i
      integer :: lun_read=11,lun_write=22, lun_stride=44
      integer :: iostat=0,stat=0,videostat=0
      integer :: isep1=0,idummy,sindex
      logical :: lread_slice_xy,lread_slice_xy2,lread_slice_xy3
      logical :: lread_slice_xy4,lread_slice_xz,lread_slice_yz
      logical :: lread_slice_xz2
      real :: t,t_dummy
      real :: slice_pos=0.,slice_pos_dummy
      integer :: stride=0
!
      character (len=fnlen) :: file='',fullname='',wfile='',directory=''
      character (len=fnlen) :: datadir='data',path='',cfield=''
      character (len=20) :: field='lnrho',field2=''
!
      logical :: exists,lfirst_slice=.true.
      character, dimension(-1:0) :: trufal=(/'F','T'/)
!
!  Read name of the field from a file containing the field to be read.
!  Use videoread.in as default. If that does not exist, use video.in
!  (that will read all fields). video.in is the default file used to
!  tell the code which fields to write slices. Ideally, we should have
!  a separate file telling read_all_videofiles which slices to read.
!
      inquire(file='videoread.in',exist=exists)
      if (exists) then
        open(lun_video,file='videoread.in')
      else
        inquire(file='video.in',exist=exists)
        if (exists) then
          open(lun_video,file='video.in')
        else
          print*,'ERROR: neither videoread.in nor video.in found'
          STOP 1
        endif
      endif
!
!  Put the stride in a file, stride.in
!
      inquire(file='stride.in',exist=exists)
      if (exists) then
        open(lun_stride,file='stride.in')
        read(lun_stride,'(i3)') stride
        close(lun_stride)
        if (stride==0) then
          print*,'Read stride.in. No skipping.'
        else
          print*,'Read stride.in. Will skip every ',stride,' slices'
        endif
      else
        stride = 0
        print*,'No stride.in hence no skipping.'
      endif
!
! Loop over all processors to find the positions of the slices.
! Therefore read all slice_postions.dat
!
      do ipx=0,nprocx-1
        do ipy=0,nprocy-1
          do ipz=0,nprocz-1
            iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
            call safe_character_assign(directory, trim(datadir)//'/proc'//itoa(iproc))
!
! check for existence first
!
            inquire(FILE=trim(directory)//'/slice_position.dat',EXIST=exists)
            if (.not.exists) then
              print*,'slice_position.dat for iproc=',iproc,'not found!'
              STOP 1
            endif
            open(lun_pos,file=trim(directory)//'/slice_position.dat',STATUS='unknown')
            read(lun_pos,'(l5,i5)') lread_slice_xy,idummy
            read(lun_pos,'(l5,i5)') lread_slice_xy2,idummy
            read(lun_pos,'(l5,i5)') lread_slice_xy3,idummy
            read(lun_pos,'(l5,i5)') lread_slice_xy4,idummy
            read(lun_pos,'(l5,i5)') lread_slice_xz,idummy
            read(lun_pos,'(l5,i5)') lread_slice_xz2,idummy
            read(lun_pos,'(l5,i5)') lread_slice_yz,idummy
            close(lun_pos)
            if (lread_slice_xy) ipz1=ipz
            if (lread_slice_xy2) ipz2=ipz
            if (lread_slice_xy3) ipz3=ipz
            if (lread_slice_xy4) ipz4=ipz
            if (lread_slice_xz) ipy1=ipy
            if (lread_slice_xz2) ipy2=ipy
            if (lread_slice_yz) ipx1=ipx
          enddo
        enddo
      enddo
!
      open (lun_pos,file=trim(datadir)//'/slice_position.dat',form='formatted',STATUS='replace')
      write(lun_pos,*) trufal(min(ipz1,0))
      write(lun_pos,*) trufal(min(ipz2,0))
      write(lun_pos,*) trufal(min(ipz3,0))
      write(lun_pos,*) trufal(min(ipz4,0))
      write(lun_pos,*) trufal(min(ipy1,0))
      write(lun_pos,*) trufal(min(ipy2,0))
      write(lun_pos,*) trufal(min(ipx1,0))
      close(lun_pos)
!
!  Need to reset     MR: Why?
!
      if (ipz1/=-1) lread_slice_xy=.true.
      if (ipz2/=-1) lread_slice_xy2=.true.
      if (ipz3/=-1) lread_slice_xy3=.true.
      if (ipz4/=-1) lread_slice_xy4=.true.
      if (ipy1/=-1) lread_slice_xz=.true.
      if (ipy2/=-1) lread_slice_xz2=.true.
      if (ipx1/=-1) lread_slice_yz=.true.
!
!  Loop over each field.
!
  sindex=0
!
  loop: do
    fieldname: if (sindex==0) then
!
!  Read the name of the next field (must coincide with file extension)
!
      read(lun_video,*,iostat=videostat) cfield
      if (videostat==0) then
        isep1=index(cfield,' ')
        field2=cfield(1:isep1-1)
        field=''
      else
        exit loop
      endif
!
!  Determine if it is a scalar field by checking the file existence
!  (assuming the xy-slice exists)
!
      call get_fullname(nprocx*nprocy*ipz1, field2, '*', fullname)
      if (list_files(fullname,only_number=.true.)>0) then
        field = field2
        sindex = 0
      else
        sindex = 1
        cycle loop
      endif
!
    else fieldname
!
!  Determine if it has multiple components by checking the file existence
!  (assuming the xy-slice exists)
!
      call append_number(field2, field, sindex)
      call get_fullname(nprocx*nprocy*ipz1, field, '*', fullname)
      if (list_files(fullname,only_number=.true.)>0) then
        sindex = sindex + 1
      else
        if (sindex==1) print*, 'The field ', trim(field2), ' does not exist.'
        sindex = 0
        cycle loop
      endif
!
    endif fieldname
    write(*,*) "Reading next: ", field
!
!  Try to find number of timesteps, therefore asume xy-slice is written
!
          if (lfirst_slice) then
            ipz=ipz1
            ipx=0
            ipy=0
            iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
            call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
            call safe_character_assign(file,'/slice_'//trim(field)//'.xy')
            call safe_character_assign(fullname,trim(path)//trim(file))
            !
            inquire(FILE=trim(fullname),EXIST=exists)
            if (.not.exists) then
              print*,"Slice not found: ", fullname
            endif
            !
            it = 0
            iostat=0
            open(lun_read,file=trim(fullname),status='old',form='unformatted')
            do while (iostat==0)
              do istride=1,stride
                read(lun_read,iostat=iostat) xy_loc_dummy,t_dummy,slice_pos_dummy
              enddo
              read(lun_read,iostat=iostat) xy_loc,t,slice_pos
              if (iostat==0) it=it+1
            enddo
            close(lun_read)
            !
            allocate(t_array(it),stat=iostat)
            lfirst_slice=.false.
          endif
!
!  First xy plane
!
      if (lread_slice_xy) then
        allocate(xy_t(nxgrid,nygrid,it),stat=stat)
        if (stat==0) then
          ipz=ipz1
          do ipy=0,nprocy-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xy')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xy_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xy_loc,t,slice_pos
                  xy_t(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny,i)=xy_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xy_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xy_t)) deallocate(xy_t)
      endif
!
!  Second xy plane
!
      if (lread_slice_xy2) then
        allocate(xy_t(nxgrid,nygrid,it),stat=stat)
        if (stat==0) then
          ipz=ipz2
          do ipy=0,nprocy-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xy2')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xy_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xy_loc,t,slice_pos
                  xy_t(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny,i)=xy_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xy_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xy_t)) deallocate(xy_t)
      endif
!
!  Third xy plane
!
      if (lread_slice_xy3) then
        allocate(xy_t(nxgrid,nygrid,it),stat=stat)
        if (stat==0) then
          ipz=ipz3
          do ipy=0,nprocy-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xy3')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xy_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xy_loc,t,slice_pos
                  xy_t(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny,i)=xy_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xy_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xy_t)) deallocate(xy_t)
      endif
!
!  Fourth xy plane
!
      if (lread_slice_xy4) then
        allocate(xy_t(nxgrid,nygrid,it),stat=stat)
        if (stat==0) then
          ipz=ipz4
          do ipy=0,nprocy-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xy4')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xy_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xy_loc,t,slice_pos
                  xy_t(1+ipx*nx:nx+ipx*nx,1+ipy*ny:ny+ipy*ny,i)=xy_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xy_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xy_t)) deallocate(xy_t)
      endif
!
!  First xz plane
!
      if (lread_slice_xz) then
        allocate(xz_t(nxgrid,nzgrid,it),stat=stat)
        if (stat==0) then
          ipy=ipy1
          do ipz=0,nprocz-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xz')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xz_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xz_loc,t,slice_pos
                  xz_t(1+ipx*nx:nx+ipx*nx,1+ipz*nz:nz+ipz*nz,i)=xz_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xz_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xz_t)) deallocate(xz_t)
      endif
!
! Second xz plane
!
      if (lread_slice_xz2) then
        allocate(xz_t(nxgrid,nzgrid,it),stat=stat)
        if (stat==0) then
          ipy=ipy2
          do ipz=0,nprocz-1
            do ipx=0,nprocx-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.xz2')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) xz_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) xz_loc,t,slice_pos
                  xz_t(1+ipx*nx:nx+ipx*nx,1+ipz*nz:nz+ipz*nz,i)=xz_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) xz_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(xz_t)) deallocate(xz_t)
      endif
!
!  First yz plane
!
      if (lread_slice_yz) then
        allocate(yz_t(nygrid,nzgrid,it),stat=stat)
        if (stat==0) then
          ipx=ipx1
          do ipy=0,nprocy-1
            do ipz=0,nprocz-1
              iproc=ipx+nprocx*ipy+nprocx*nprocy*ipz
              call safe_character_assign(path,trim(datadir)//'/proc'//itoa(iproc))
              call safe_character_assign(file,'/slice_'//trim(field)//'.yz')
              call safe_character_assign(fullname,trim(path)//trim(file))
              inquire(FILE=trim(fullname),EXIST=exists)
              if (.not.exists) then
                write (*,*) 'WARNING: FILE ',fullname,' DOES NOT EXIST'
                write (*,*) 'Maybe slice was added to video.in after simulation.'
              else
                open(lun_read,file=trim(fullname),status='old',form='unformatted')
                do i=1,it
                  do istride=1,stride
                    read(lun_read,iostat=iostat) yz_loc_dummy,t_dummy,slice_pos_dummy
                  enddo
                  read(lun_read,iostat=iostat) yz_loc,t,slice_pos
                  yz_t(1+ipy*ny:ny+ipy*ny,1+ipz*nz:nz+ipz*nz,i)=yz_loc
                  t_array(i) = t
                enddo
                close(lun_read)
              endif
            enddo
          enddo
          call safe_character_assign(wfile,trim(datadir)//trim(file))
          open(lun_write,file=trim(wfile),form='unformatted')
          do i=1,it
            write(lun_write,iostat=iostat) yz_t(:,:,i),t_array(i),slice_pos
          enddo
          close(lun_write)
        else
          write(*,*) 'Could not allocate memory to read slices'
          STOP 1
        endif
        if (allocated(yz_t)) deallocate(yz_t)
      endif
!
  enddo loop
!
    if (allocated(t_array)) deallocate(t_array)
    write(*,*) 'Wrote number of timesteps: ', it
!
contains
!***********************************************************************
  subroutine get_fullname(iproc,field,slice,fullname)
!
!  Finds the full name of the slice file including path.
!
!  24-feb-11/ccyang: coded
!
    integer, intent(in) :: iproc                 ! processor index
    character(len=*), intent(in) :: field        ! field name
    character(len=*), intent(in) :: slice        ! slice plane
    character(len=*), intent(out) :: fullname    ! the file name
!
    character(len=fnlen) :: path, filename
!
    call safe_character_assign(path, trim(datadir) // '/proc' // itoa(iproc))
    call safe_character_assign(filename, '/slice_' // trim(field) // '.' // trim(slice))
    call safe_character_assign(fullname, trim(path) // trim(filename))
!
  endsubroutine get_fullname
!***********************************************************************
  subroutine append_number(string1,string2,k)
!
!  Appends the number k to string1 and assigns it to string2.
!
!  24-feb-11/ccyang: coded
!
    character(len=*), intent(in) :: string1
    character(len=*), intent(out) :: string2
    integer, intent(in) :: k
!
    call safe_character_assign(string2, trim(string1) // trim(itoa(k)))
!
  endsubroutine append_number
!***********************************************************************
endprogram rvid_box

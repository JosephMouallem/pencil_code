! F2003 test program
!
! This program contains all F2003 features that Pencil Code currently relies on.
! You may compile this program with gfortran:
! > gfortran -std=f2003 -o test_f2003 test_f2003.f90
! and then try the same test with your favourite compiler, like Intel:
! > ifort -std03 -o test_f2003 test_f2003.f90
!
! Compilers tested successfully:
! * gfortran: 4.8.4 (and newer)
! * ifort: 12.1 (and newer)
!
! Compilers proven to fail:
! * gfortran: 4.6.1 (and lower) - fails on compiling
! * g95: 0.93 (and lower) - fails on compiling
! * PGI: 15.10 - compiles, but fails to determine the correct file size

program test_f2003

    implicit none

    integer, parameter :: namelist_size = 119 ! size of test_namelist.in in bytes
    character (len=80) :: a
    real :: b
    integer :: c
    namelist /example_1/ a, b, c
    namelist /example_2/ a, b, c
    namelist /example_3/ a, b, c

    integer :: num_bytes, unit = 11
    character (len=*), parameter :: in_file = 'test_namelist.in'
    character (len=:), allocatable :: buffer

    ! TODO: protected member within module

    ! allocatable array within type
    type alloc_array_struct
      real :: test_scalar
      real, dimension(:), allocatable :: test_array
    endtype alloc_array_struct
    type (alloc_array_struct) :: test_struct
    allocate (test_struct%test_array(23))

    ! find namelist file size
    inquire (file=in_file, size=num_bytes)
    if (num_bytes /= namelist_size) then
      write (*,'(A,I6,A,I6,A)') 'FILESIZE ERROR! (actual size: ', num_bytes, ', expected: ', namelist_size, ')'
      stop 1
    endif

    ! allocate memory buffer
    allocate (character (len=num_bytes) :: buffer)
    buffer(1:) = char(0)

    ! read namelist file into memory buffer
    open (unit, file=in_file, status='old', form='unformatted', access='stream')
    read (unit) buffer
    close (unit)

    ! read namelist from memory buffer
    read (buffer, nml=example_1)
    if ((a /= 'bcx?0') .or. (b /= -1.234) .or. (c /= 42)) then
      write (*,'(A)') 'NAMELIST 1 READING ERROR!'
      write (*,'(A)') buffer
      write (*,'(A)') '========================='
      stop 1
    endif

    ! read namelists in any order
    read (buffer, nml=example_3)
    if ((a /= 'bcz?0') .or. (b /= -4.321) .or. (c /= 23)) then
      write (*,'(A)') 'NAMELIST 2 READING ERROR!'
      write (*,'(A)') buffer
      write (*,'(A)') '========================='
      stop 1
    endif
    read (buffer, nml=example_2)
    if ((a /= 'bcy?0') .or. (b /= 1.234) .or. (c /= 42)) then
      write (*,'(A)') 'NAMELIST 3 READING ERROR!'
      write (*,'(A)') buffer
      write (*,'(A)') '========================='
      stop 1
    endif

    ! clean up
    deallocate (buffer)

    ! jump to position in file (like fseek)
    allocate (character (len=10) :: buffer)
    buffer(1:) = char(0)
    open (unit, file=in_file, status='old', form='unformatted', access='stream')
    read (unit, pos=12) buffer
    close (unit)
    if (buffer /= char(9)//"a='bcz?0'") then
      write (*,'(A)') 'FILE POSITIONING ERROR!'
      write (*,'(A)') buffer
      write (*,'(A)') '========================='
      stop 1
    endif
    deallocate (buffer)

    ! test F2003 flush
    flush (6)

    ! done
    write (*,'(A)') '> SUCCESS! <'
    write (*,'(A)') 'Your compiler supports all F2003 features needed for Pencil Code.'
end


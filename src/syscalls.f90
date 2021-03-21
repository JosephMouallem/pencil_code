! $Id$
!
!  This module takes care of system calls and provides ANSI-C functionality.
!
module Syscalls
!
  implicit none
!
  external is_nan_c
  external system_c
  external sizeof_real_c
!
  interface is_nan
    module procedure is_nan_0D
    module procedure is_nan_1D
    module procedure is_nan_2D
    module procedure is_nan_3D
    module procedure is_nan_4D
  endinterface
!
  contains
!***********************************************************************
    subroutine system_cmd(command)
!
!  Executes a system command.
!
!  3-nov-11/MR: coded
!
      character(len=*) :: command
!
      call system_c(trim(command)//char(0))
!
    endsubroutine system_cmd
!***********************************************************************
    function sizeof_real()
!
!  Determines the size of a real in bytes.
!
!  Returns:
!  * The number of bytes used for a real.
!
!  16-Feb-2012/Bourdin.KIS: coded
!
      integer :: sizeof_real
!
      call sizeof_real_c(1.0, sizeof_real)
!
    endfunction sizeof_real
!***********************************************************************
    function get_PID()
!
!  Determines the PID of the current process.
!
!  Returns:
!  * Integer containing the PID of the current process
!  * -1 if retrieving of the PID failed
!
!   4-aug-10/Bourdin.KIS: coded
!
      integer :: get_PID
!
      integer, save :: my_PID = -1
!
      if (my_PID == -1) call get_PID_c(my_PID)
      get_PID = my_PID
!
    endfunction get_PID
!***********************************************************************
    subroutine get_env_var(name,value)
!
!  Reads in an environment variable.
!
!  Returns:
!  * String containing the content of a given environment variable name
!  * Empty string, if the variable doesn't exist
!
!   4-aug-10/Bourdin.KIS: coded
!
      character(len=*) :: name
      character(len=*) :: value
!
      value = ' '
      call get_env_var_c(trim(name)//char(0), value)
      value = trim(value)
!
    endsubroutine get_env_var
!***********************************************************************
    function directory_exists(path)
!
!  Checks for existence of a directory.
!
!  Returns:
!  * True, if 'path' points to a directory
!  * False, otherwise
!
!   2-sep-15/PABourdin: coded
!
      logical :: directory_exists
      character(len=*) :: path
!
      integer :: exists
!
      exists = -1
      call directory_exists_c(trim(path)//char(0), exists)
      if (exists == -1) then
        write (*,*) 'WARNING: failure while checking if "'//trim(path)//'" exists!'
        ! This line is temporary code to allow Nils debugging further.
        !exists = 1
      endif
!
      directory_exists = (exists == 1)
!
    endfunction directory_exists
!***********************************************************************
    function is_nan_0D(value)
!
!  Determines if value is not a number (NaN).
!
!  Returns:
!  * true, if value is not a number (NaN)
!  * false, otherwise
!
!  14-jan-2011/Bourdin.KIS: coded
!
      logical :: is_nan_0D
      real, intent(in) :: value
!
      integer :: result
!
      call is_nan_c (value, result)
      if (result == -1) then
        print *, 'is_nan_0D: serious failure in is_nan_c'
        stop
      endif
      is_nan_0D = (result == 1)
!
    endfunction is_nan_0D
!***********************************************************************
    function is_nan_1D(value)
!
!  Determines if value is not a number (NaN).
!
!  Returns:
!  * true, if value is not a number (NaN)
!  * false, otherwise
!
!  15-jan-2011/Bourdin.KIS: coded
!
      real, dimension(:), intent(in) :: value
      logical, dimension(size (value, 1)) :: is_nan_1D
!
      integer, dimension(size (value, 1)) :: result
      integer :: pos
!
      do pos = 1, size (value, 1)
        call is_nan_c (value(pos), result(pos))
      enddo
      if (any (result == -1)) then
        print *, 'is_nan_1D: serious failure in is_nan_c'
        stop
      endif
      is_nan_1D = (result == 1)
!
    endfunction is_nan_1D
!***********************************************************************
    function is_nan_2D(value)
!
!  Determines if value is not a number (NaN).
!
!  Returns:
!  * true, if value is not a number (NaN)
!  * false, otherwise
!
!  15-jan-2011/Bourdin.KIS: coded
!
      real, dimension(:,:), intent(in) :: value
      logical, dimension(size (value, 1),size (value, 2)) :: is_nan_2D
!
      integer, dimension(size (value, 1),size (value, 2)) :: result
      integer :: pos_x, pos_y
!
      do pos_x = 1, size (value, 1)
        do pos_y = 1, size (value, 2)
          call is_nan_c (value(pos_x,pos_y), result(pos_x,pos_y))
        enddo
      enddo
      if (any (result == -1)) then
        print *, 'is_nan_2D: serious failure in is_nan_c'
        stop
      endif
      is_nan_2D = (result == 1)
!
    endfunction is_nan_2D
!***********************************************************************
    function is_nan_3D(value)
!
!  Determines if value is not a number (NaN).
!
!  Returns:
!  * true, if value is not a number (NaN)
!  * false, otherwise
!
!  15-jan-2011/Bourdin.KIS: coded
!
      real, dimension(:,:,:), intent(in) :: value
      logical, dimension(size (value, 1),size (value, 2),size (value, 3)) :: is_nan_3D
!
      integer, dimension(size (value, 1),size (value, 2),size (value, 3)) :: result
      integer :: pos_x, pos_y, pos_z
!
      do pos_x = 1, size (value, 1)
        do pos_y = 1, size (value, 2)
          do pos_z = 1, size (value, 3)
            call is_nan_c (value(pos_x,pos_y,pos_z), result(pos_x,pos_y,pos_z))
          enddo
        enddo
      enddo
      if (any (result == -1)) then
        print *, 'is_nan_3D: serious failure in is_nan_c'
        stop
      endif
      is_nan_3D = (result == 1)
!
    endfunction is_nan_3D
!***********************************************************************
    function is_nan_4D(value)
!
!  Determines if value is not a number (NaN).
!
!  Returns:
!  * true, if value is not a number (NaN)
!  * false, otherwise
!
!  15-jan-2011/Bourdin.KIS: coded
!
      real, dimension(:,:,:,:), intent(in) :: value
      logical, dimension(size (value, 1),size (value, 2),size (value, 3),size (value, 4)) :: is_nan_4D
!
      integer, dimension(size (value, 1),size (value, 2),size (value, 3),size (value, 4)) :: result
      integer :: pos_x, pos_y, pos_z, pos_a
!
      do pos_x = 1, size (value, 1)
        do pos_y = 1, size (value, 2)
          do pos_z = 1, size (value, 3)
            do pos_a = 1, size (value, 4)
              call is_nan_c (value(pos_x,pos_y,pos_z,pos_a), result(pos_x,pos_y,pos_z,pos_a))
            enddo
          enddo
        enddo
      enddo
      if (any (result == -1)) then
        print *, 'is_nan_4D: serious failure in is_nan_c'
        stop
      endif
      is_nan_4D = (result == 1)
!
    endfunction is_nan_4D
!***********************************************************************
endmodule Syscalls

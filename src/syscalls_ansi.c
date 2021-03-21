/*                             syscalls_ansi.c
                              -----------------
*/

/* Date:   19-Mar-2010
   Author: Bourdin.KIS (Bourdin@KIS.Uni-Freiburg.de)
   Description:
 ANSI C and standard library callable function wrappers for use in Fortran.
 Written to compensate for inadequatenesses in the Fortran95/2003 standards.
*/
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>

#include "headers_c.h"

/* ---------------------------------------------------------------------- */

void FTNIZE(file_size_c)
     (char *filename, FINT *bytes)
/* Determines the size of a file.
   Returns:
   * positive integer containing the file size of a given file
   * -2 if the file could not be found or opened
   * -1 if retrieving the file size failed
*/
{
  struct stat fileStat;
  int file = -1;

  *bytes = -2;
  file = open (filename, O_RDONLY);
  if(file == -1) return;

  *bytes = -1;
  if(fstat (file, &fileStat) < 0) { close (file); return; }
  close (file);

  *bytes = fileStat.st_size;
}
/* ---------------------------------------------------------------------- */
void FTNIZE(caller)
     (void (*func)(float* par1, ... ), FINT* npar, ... )
{
  float **arg=(float**)&npar;

  switch(*npar)
  {
  case 1: func(*(arg+1));
  case 2: func(*(arg+1),*(arg+2));
  case 3: func(*(arg+1),*(arg+2),*(arg+3));
  case 4: func(*(arg+1),*(arg+2),*(arg+3),*(arg+4));
  case 5: func(*(arg+1),*(arg+2),*(arg+3),*(arg+4),*(arg+5));
  default: return;
  }
}
/* ---------------------------------------------------------------------- */
void FTNIZE(caller0)
     (void (*func)(void))
{
   func(); 
}
/* ---------------------------------------------------------------------- */
void *FTNIZE(dlopen_c)(const char *filename, FINT *flag)
{
 const int ALLNOW=1;
 void *pointer;
 void *p1;
 char *name;

printf("library = %s\n", filename);

 if (*flag==ALLNOW)
 {
/*   pointer = dlopen(filename, RTLD_LAZY); 
printf("pointer = %d\n", pointer);
   name = "fargo_mp_initialize_special_";
   p1 = dlsym(pointer,name);
printf("handlel = %d\n", p1);
*/
   //return dlopen(filename, RTLD_NOW); 
 }
 else
   //return dlopen(filename, RTLD_LAZY); 
 return NULL;
}
/* ---------------------------------------------------------------------- */
void *FTNIZE(dlsym_c)(void *handle, const char *symbol)
{
//printf("handlel = %d\n", handle);
//printf("symbol = %s\n", symbol);
 return dlsym(handle, symbol); 
}
/* ---------------------------------------------------------------------- */
void FTNIZE(dlclose_c)(void *handle)
{
 dlclose(handle);
}
/* ---------------------------------------------------------------------- */
char* FTNIZE(dlerror_c)(void)
{
 char *error=dlerror();
printf("error = %s\n", dlerror());
 return error;
}       
/* ---------------------------------------------------------------------- */
void FTNIZE(write_binary_file_c)
     (char *filename, FINT *bytes, char *buffer, FINT *result)
/* Writes a given buffer to a binary file.
   Returns:
   * positive integer containing the number of written bytes
   * -2 if the file could not be opened
   * -1 if writing the buffer failed
*/
{
  int file = -1;
  int written = 0;

  *result = -2;
  file = open (filename, O_WRONLY|O_CREAT|O_TRUNC, S_IRUSR|S_IWUSR);

  if(file == -1) return;

  *result = -1;

  written = (int) write (file, buffer, (size_t) *bytes);
  close (file);
  if (written != *bytes) return;
  *result = written;
}

/* ---------------------------------------------------------------------- */

void FTNIZE(get_pid_c)
     (FINT *pid)
/* Determines the PID of the current process.
   Returns:
   * integer containing the PID of the current process
   * -1 if retrieving the PID failed
*/
{
  pid_t result;

  *pid = -1;
  result = getpid ();
  if (result) *pid = (int) result;
}

/* ---------------------------------------------------------------------- */

void FTNIZE(get_env_var_c)
     (char *name, char *value)
/* Gets the content of an environment variable.
   Returns:
   * string containing the content of the environment variable, if available
   * empty string, if retrieving the environment variable failed
*/
{
  char *env_var;

  env_var = getenv (name);
  if (env_var) strncpy (value, env_var, strlen (env_var));
}

/* ---------------------------------------------------------------------- */

void FTNIZE(directory_exists_c)
     (char *path, FINT *exists)
/* Checks for existence of a directory.
   Returns:
   * 1, if 'path' points to a directory
   * -1, on error
   * 0, otherwise
*/
{
  int status;
  struct stat result;

  *exists = 0;
  status = stat (path, &result);
  if (status == -1) *exists = -1;
  if (S_ISDIR (result.st_mode)) *exists = 1;
}

/* ---------------------------------------------------------------------- */

void FTNIZE(is_nan_c)
     (REAL *value, FINT *result)
/* Determine if value is not a number.
   Returns:
   * 1, if value is not a number
   * 0, if value is a number
   * -1 on failure (value is neither float or double)
*/
{
  *result = -1;

  if (sizeof (*value) == sizeof (double)) *result = isnan ((double) *value);
  /*
    isnanf() is sometimes not available
    if (sizeof (*value) == sizeof (float)) *result = isnanf ((float) *value);
  */
  if (sizeof (*value) == sizeof (float)) *result = !(*value == *value);
}

/* ---------------------------------------------------------------------- */

void FTNIZE(system_c) (char *command)
/* Date:   04-Nov-2011
   Author: MR (matthias.rheinhardt@helsinki.fi)
   Description: function wrapper for ANSI C function system.
*/
{
  int res=system(command);
  if (res == -1) return; // some error handling is missing here [Bourdin.KIS]
}

/* ---------------------------------------------------------------------- */

void FTNIZE(sizeof_real_c)
     (REAL *value, FINT *result)
/* Determine the number of bytes used for value.
   Returns:
   * the number of bytes used for value
*/
{
  *result = sizeof (*value);
}
/* ---------------------------------------------------------------------- */
  void FTNIZE(copy_addr_c)(void *src, void **dest)
  {
    *dest=src;
  }
/* ---------------------------------------------------------------------- */


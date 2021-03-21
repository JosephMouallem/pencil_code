# slices.py
#
# Read the slice files.
#
# Author: S. Candelaresi (iomsn1@gmail.com).
"""
Contains the classes and methods to read slice files.
"""


def slices(*args, **kwargs):
    """
    Read Pencil Code slice data.

    call signature:

    read(self. field='uu1', extension='xz', datadir='data', proc=-1,
         old_file=False, precision='f', verbose=False)

    Keyword arguments:

    *field*:
      Name of the field(s) to be read.

    *extension*
      Specifies the slice(s).

    *datadir*:
      Directory where the data is stored.

    *proc*:
      Processor to be read. If -1 read all and assemble to one array.

    *old_file*
      Flag for reading old file format.

    *precision*:
      Precision of the data. Either float 'f' or double 'd'.

    *verbose*:
      Print progress
    """

    slices_tmp = SliceSeries()
    slices_tmp.read(*args, **kwargs)
    return slices_tmp


class SliceSeries(object):
    """
    SliceSeries -- holds Pencil Code slices data and methods.
    """

    def __init__(self):
        """
        Fill members with default values.
        """

        import numpy as np

        self.t = np.array([])


    def read(self, field='', extension='', datadir='data', proc=-1,
             old_file=False, precision='f', verbose=False):
        """
        Read Pencil Code slice data.

        call signature:

        read(self. field='', extension='', datadir='data', proc=-1,
             old_file=False, precision='f', verbose=False)

        Keyword arguments:

        *field*:
          Name of the field(s) to be read.

        *extension*
          Specifies the slice(s).

        *datadir*:
          Directory where the data is stored.

        *proc*:
          Processor to be read. If -1 read all and assemble to one array.

        *old_file*
          Flag for reading old file format.

        *precision*:
          Precision of the data. Either float 'f' or double 'd'.

        *verbose*:
          Print progress
        """

        import os
        import numpy as np
        from scipy.io import FortranFile
        from .. import read

        # Define the directory that contains the slice files.
        if proc < 0:
            slice_dir = datadir
        else:
            slice_dir = os.path.join(datadir, 'proc{0}'.format(proc))

        # Initialize the fields list.
        if field:
            if isinstance(field, list):
                field_list = field
            else:
                field_list = [field]
        else:
            # Find the existing fields.
            field_list = []
            for file_name in os.listdir(slice_dir):
                if file_name[:6] == 'slice_':
                    field_list.append(file_name.split('.')[0][6:])
            # Remove duplicates.
            field_list = list(set(field_list))
            try:
                field_list.remove('position')
            except:
                pass

        # Initialize the extensions list.
        if extension:
            if isinstance(extension, list):
                extension_list = extension
            else:
                extension_list = [extension]
        else:
            # Find the existing extensions.
            extension_list = []
            for file_name in os.listdir(slice_dir):
                if file_name[:6] == 'slice_':
                    extension_list.append(file_name.split('.')[1])
            # Remove duplicates.
            extension_list = list(set(extension_list))
            try:
                extension_list.remove('dat')
            except:
                pass

        class Foo(object):
            pass

        for extension in extension_list:
            if verbose:
                print('Extension: ' + str(extension))
            # This one will store the data.
            ext_object = Foo()

            for field in field_list:
                if verbose:
                    print('  -> Field: ' + str(field))
                # Compose the file name according to field and extension.
                datadir = os.path.expanduser(datadir)
                if proc < 0:
                    file_name = os.path.join(datadir, 'slice_'+field+'.'+extension)
                else:
                    file_name = os.path.join(datadir, 'proc{0}'.format(proc),
                                             'slice_'+field+'.'+extension)

                dim = read.dim(datadir, proc)
                if dim.precision == 'D':
                    precision = 'd'
                else:
                    precision = 'f'

                # Set up slice plane.
                if extension == 'xy' or extension == 'Xy' or  extension == 'xy2':
                    hsize = dim.nx
                    vsize = dim.ny
                if extension == 'xz':
                    hsize = dim.nx
                    vsize = dim.nz
                if extension == 'yz':
                    hsize = dim.ny
                    vsize = dim.nz

                try:
                    infile = FortranFile(file_name)
                except:
                    continue

                islice = 0
                self.t = np.zeros(1, dtype=precision)
                self.t = [0]
                slice_series = [0]

                while True:
                    try:
                        if verbose:
                            print('  -> Reading... ')
                        raw_data = infile.read_record(dtype=precision)
                    except ValueError:
                        break
                    except TypeError:
                        break

                    if old_file:
                        self.t.append(list(raw_data[-1]))
                        slice_series.extend(list(raw_data[:-1]))
                    else:
                        self.t.append(list(raw_data[-2:-1]))
                        slice_series.extend(list(raw_data[:-2]))
                    islice += 1
                    if verbose:
                        print('  -> Done')

                # Reshape and remove first entry.
                if verbose:
                    print('Reshaping array')
                self.t = np.array(self.t[1:], dtype=precision)[:, 0]
                slice_series = np.array(slice_series, dtype=precision)
                slice_series = slice_series[1:].reshape(islice, vsize, hsize)
                setattr(ext_object, field, slice_series)

            setattr(self, extension, ext_object)

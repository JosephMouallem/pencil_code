# averages.py
#
# Read the average files.
#
# Author: S. Candelaresi (iomsn1@gmail.com).
"""
Contains the classes and methods to read average files.
"""


def aver(*args, **kwargs):
    """
    Read Pencil Code average data.

    call signature:

    read(plane_list=['xy', 'xz', 'yz'], datadir='data', proc=-1):

    Keyword arguments:

    *plane_list*:
      A list of the 2d/1d planes over which the averages were taken.
      Takes 'xy', 'xz', 'yz', 'y', 'z'.

    *datadir*:
      Directory where the data is stored.

    *proc*:
      Processor to be read. If -1 read all and assemble to one array.
      Only affects the reading of 'yaverages.dat' and 'zaverages.dat'.
    """

    averages_tmp = Averages()
    averages_tmp.read(*args, **kwargs)
    return averages_tmp


class Averages(object):
    """
    Averages -- holds Pencil Code averages data and methods.
    """

    def __init__(self):
        """
        Fill members with default values.
        """

        import numpy as np

        self.t = np.array([])


    def read(self, plane_list=None, datadir='data', proc=-1):
        """
        Read Pencil Code average data.

        call signature:

        read(plane_list=['xy', 'xz', 'yz'], datadir='data', proc=-1):

        Keyword arguments:

        *plane_list*:
          A list of the 2d/1d planes over which the averages were taken.
          Takes 'xy', 'xz', 'yz', 'y', 'z'.

        *datadir*:
          Directory where the data is stored.

        *proc*:
          Processor to be read. If -1 read all and assemble to one array.
          Only affects the reading of 'yaverages.dat' and 'zaverages.dat'.
        """

        import os

        # Initialize the planes list.
        if plane_list:
            if isinstance(plane_list, list):
                plane_list = plane_list
            else:
                plane_list = [plane_list]
        else:
            plane_list = ['xy', 'xz', 'yz']

        # Determine which average files to read.
        in_file_name_list = []
        aver_file_name_list = []
        if plane_list.count('xy') > 0:
            in_file_name_list.append('xyaver.in')
            aver_file_name_list.append('xyaverages.dat')
        if plane_list.count('xz') > 0:
            in_file_name_list.append('xzaver.in')
            aver_file_name_list.append('xzaverages.dat')
        if plane_list.count('yz') > 0:
            in_file_name_list.append('yzaver.in')
            aver_file_name_list.append('yzaverages.dat')
        if plane_list.count('y') > 0:
            in_file_name_list.append('yaver.in')
            aver_file_name_list.append('yaverages.dat')
        if plane_list.count('z') > 0:
            in_file_name_list.append('zaver.in')
            aver_file_name_list.append('zaverages.dat')
        if not in_file_name_list:
            print("error: invalid plane name")
            return -1

        class Foo(object):
            pass

        for plane, in_file_name, aver_file_name in \
        zip(plane_list, in_file_name_list, aver_file_name_list):
            # This one will store the data.
            ext_object = Foo()

            # Get the averaged quantities.
            file_id = open(os.path.join(os.path.dirname(datadir), in_file_name))
            variables = file_id.readlines()
            file_id.close()
            for i in range(sum(list(map(self.__equal_newline, variables)))):
                variables.remove('\n')
            n_vars = len(variables)

            if plane == 'xy' or plane == 'xz' or plane == 'yz':
                t, raw_data = self.__read_2d_aver(plane, datadir, aver_file_name, n_vars)
            if plane == 'y' or plane == 'z':
                t, raw_data = self.__read_1d_aver(plane, datadir, aver_file_name, n_vars, proc)

            # Add the raw data to self.
            var_idx = 0
            for var in variables:
                setattr(ext_object, var.strip(), raw_data[:, var_idx, ...])
                var_idx += 1

            self.t = t
            setattr(self, plane, ext_object)

        del(raw_data)
        del(ext_object)

        return 0


    def __equal_newline(self, line):
        """
        Determine if string is equal new line.
        """

        return line == '\n'


    def __read_1d_aver(self, plane, datadir, aver_file_name, n_vars, proc):
        """
        Read the yaverages.dat, zaverages.dat.
        Return the raw data and the time array.
        """

        import os
        import numpy as np
        from scipy.io import FortranFile
        from .. import read

        globdim = read.dim(datadir)
        if plane == 'y':
            nu = globdim.nx
            nv = globdim.nz
        if plane == 'z':
            nu = globdim.nx
            nv = globdim.ny

        if proc < 0:
            offset = globdim.nprocx*globdim.nprocy
            if plane == 'z':
            	procs = range(offset)
            if plane == 'y': 
                procs = [] 
                xr = range(globdim.nprocx)
                for iz in range(globdim.nprocz):
                    procs.extend(xr)
                    xr = [x+offset for x in xr]
            allprocs=True
        else:
            procs = [proc]
            allprocs=False

        dim = read.dim(datadir, proc)
        if dim.precision == 'S':
            dtype = np.float32
        if dim.precision == 'D':
            dtype = np.float64

        # Prepare the raw data.
        # This will be reformatted at the end.
        raw_data = []
        for proc in procs:
            proc_dir = 'proc'+str(proc)
            proc_dim = read.dim(datadir, proc)
            # Read the data.
            t = []
            proc_data = []
            try:
                file_id = FortranFile(os.path.join(datadir, proc_dir, aver_file_name))
            except:
                # Not all proc dirs have a [yz]averages.dat.
                print("Averages of processor"+str(proc)+"missing!")
                break
            while True:
                try:
                    t.append(file_id.read_record(dtype=dtype)[0])
                    proc_data.append(file_id.read_record(dtype=dtype))
                except:
                    # Finished reading.
                    break
            file_id.close()
            # Reshape the proc data into [len(t), pnu, pnv].
            if plane == 'y':
                pnu = proc_dim.nx
                pnv = proc_dim.nz
            if plane == 'z':
                pnu = proc_dim.nx
                pnv = proc_dim.ny
            proc_data = np.array(proc_data)
            proc_data = proc_data.reshape([len(t), n_vars, pnv, pnu])

            if not allprocs:
                return np.array(t), proc_data.swapaxes(2,3)

            # Add the proc_data (one proc) to the raw_data (all procs)
            if plane == 'y':
                if allprocs:
                    idx_u = proc_dim.ipx*proc_dim.nx
                    idx_v = proc_dim.ipz*proc_dim.nz
                else:
                    idx_v = 0; idx_u = 0
            if plane == 'z':
                if allprocs:
                    idx_u = proc_dim.ipx*proc_dim.nx
                    idx_v = proc_dim.ipy*proc_dim.ny
                else:
                    idx_v = 0; idx_u = 0

            if not isinstance(raw_data, np.ndarray):
                # Initialize the raw_data array with the right dimensions.
                raw_data = np.zeros([len(t), n_vars, nv, nu])
            raw_data[:, :, idx_v:idx_v+pnv, idx_u:idx_u+pnu] = proc_data.copy()

        t = np.array(t)
        raw_data = np.swapaxes(raw_data, 2, 3)

        return t, raw_data


    def __read_2d_aver(self, plane, datadir, aver_file_name, n_vars):
        """
        Read the xyaverages.dat, xzaverages.dat, yzaverages.dat
        Return the raw data and the time array.
        """

        import os
        import numpy as np
        from pencilnew import read

        # Determine the structure of the xy/xz/yz averages.
        if plane == 'xy':
            nw = getattr(read.dim(), 'nz')
        if plane == 'xz':
            nw = getattr(read.dim(), 'ny')
        if plane == 'yz':
            nw = getattr(read.dim(), 'nx')
        file_id = open(os.path.join(datadir, aver_file_name))
        aver_lines = file_id.readlines()
        file_id.close()
        entry_length = int(np.ceil(nw*n_vars/8.))
        n_times = int(len(aver_lines)/(1. + entry_length))

        # Prepare the data arrays.
        t = np.zeros(n_times, dtype=np.float32)
        raw_data = np.zeros([n_times, n_vars*nw])

        # Read the data
        line_idx = 0
        t_idx = -1
        for current_line in aver_lines:
            if line_idx % (entry_length+1) == 0:
                t_idx += 1
                t[t_idx] = np.float32(current_line)
                raw_idx = 0
            else:
                raw_data[t_idx, raw_idx*8:(raw_idx*8+8)] = \
                    list(map(np.float32, current_line.split()))
                raw_idx += 1
            line_idx += 1

        # Restructure the raw data and add it to the Averages object.
        raw_data = np.reshape(raw_data, [n_times, n_vars, nw])

        return t, raw_data


    def __natural_sort(self, l):
        """
        Sort array in a more natural way, e.g. 9VAR < 10VAR
        """

        import re

        convert = lambda text: int(text) if text.isdigit() else text.lower()
        alphanum_key = lambda key: [convert(c) for c in re.split('([0-9]+)', key)]
        return sorted(l, key=alphanum_key)

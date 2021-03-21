# var.py
#
# Read the var files.
# NB: the f array returned is C-ordered: f[nvar, nz, ny, nx]
#     NOT Fortran as in Pencil (& IDL):  f[nx, ny, nz, nvar]
#
# Authors:
# J. Oishi (joishi@amnh.org)
# T. Gastine (tgastine@ast.obs-mip.fr)
# S. Candelaresi (iomsn1@gmail.com).
"""
Contains the read class for the VAR file reading,
some simulation attributes and the data cube.
"""

def var(*args, **kwargs):
    """
    Read VAR files from Pencil Code. If proc < 0, then load all data
    and assemble, otherwise load VAR file from specified processor.

    The file format written by output() (and used, e.g. in var.dat)
    consists of the followinig Fortran records:
    1. data(mx, my, mz, nvar)
    2. t(1), x(mx), y(my), z(mz), dx(1), dy(1), dz(1), deltay(1)
    Here nvar denotes the number of slots, i.e. 1 for one scalar field, 3
    for one vector field, 8 for var.dat in the case of MHD with entropy.
    but, deltay(1) is only there if lshear is on! need to know parameters.

    call signature:

    var(var_file='', datadir='data', proc=-1, ivar=-1, quiet=True,
        trimall=False, magic=None, sim=None, precision='f')

    Keyword arguments:
        var_file:   Name of the VAR file.
        datadir:    Directory where the data is stored.
        proc:       Processor to be read. If -1 read all and assemble to one array.
        ivar:       Index of the VAR file, if var_file is not specified.
        quiet:      Flag for switching off output.
        trimall:    Trim the data cube to exclude ghost zones.
        magic:      Values to be computed from the data, e.g. B = curl(A).
        sim:        Simulation sim object.
        precision:  Float (f) or double (d).
    """

    from ..sim import __Simulation__

    started = None

    for a in args:
        if isinstance(a, __Simulation__):
            started = a.started()
            break

    if 'sim' in kwargs.keys():
        started = kwargs['sim'].started()
    elif 'datadir' in kwargs.keys():
        from os.path import join, exists
        if exists(join(kwargs['datadir'], 'time_series.dat')):
            started = True
    else:
        from os.path import join, exists
        if exists(join('data', 'time_series.dat')):
            started = True

        #else:
        #    print('!! ERROR: No simulation of path specified..')

    if not started:
        print('ERROR: Simulation has not jet started. There are no var files.')
        return False

    var_tmp = DataCube()
    var_tmp.read(*args, **kwargs)
    return var_tmp


class DataCube(object):
    """
    DataCube -- holds Pencil Code VAR file data.
    """

    def __init__(self):
        """
        Fill members with default values.
        """

        self.t = 0.
        self.dx = 1.
        self.dy = 1.
        self.dz = 1.


    def read(self, var_file='', datadir='data', proc=-1, ivar=-1, quiet=True,
             trimall=False, magic=None, sim=None, precision='f'):
        """
        Read VAR files from Pencil Code. If proc < 0, then load all data
        and assemble, otherwise load VAR file from specified processor.

        The file format written by output() (and used, e.g. in var.dat)
        consists of the followinig Fortran records:
        1. data(mx, my, mz, nvar)
        2. t(1), x(mx), y(my), z(mz), dx(1), dy(1), dz(1), deltay(1)
        Here nvar denotes the number of slots, i.e. 1 for one scalar field, 3
        for one vector field, 8 for var.dat in the case of MHD with entropy.
        but, deltay(1) is only there if lshear is on! need to know parameters.

        call signature:

        var(var_file='', datadir='data', proc=-1, ivar=-1, quiet=True,
            trimall=False, magic=None, sim=None, precision='f')

        Keyword arguments:
            var_file:   Name of the VAR file.
            datadir:    Directory where the data is stored.
            proc:       Processor to be read. If -1 read all and assemble to one array.
            ivar:       Index of the VAR file, if var_file is not specified.
            quiet:      Flag for switching off output.
            trimall:    Trim the data cube to exclude ghost zones.
            magic:      Values to be computed from the data, e.g. B = curl(A).
            sim:        Simulation sim object.
            precision:  Float (f) or double (d).
        """

        import numpy as np
        import os
        from scipy.io import FortranFile
        from ..math.derivatives import curl, curl2
        from .. import read
        from ..sim import __Simulation__

        dim = None
        param = None
        index = None

        if isinstance(sim, __Simulation__):
            datadir = os.path.expanduser(sim.datadir)
            dim = sim.dim
            param = read.param(datadir=sim.datadir, quiet=True)
            index = read.index(datadir=sim.datadir)
        else:
            datadir = os.path.expanduser(datadir)
            if dim is None:
                if var_file[0:2].lower() == 'og':
                    dim = read.ogdim(datadir, proc)
                else:
                    dim = read.dim(datadir, proc)
            if param is None:
                param = read.param(datadir=datadir, quiet=quiet)
            if index is None:
                index = read.index(datadir=datadir)

        run2D = param.lwrite_2d

        if dim.precision == 'D':
            precision = 'd'
        else:
            precision = 'f'

        if param.lwrite_aux:
            total_vars = dim.mvar + dim.maux
        else:
            total_vars = dim.mvar

        if not var_file:
            if ivar < 0:
                var_file = 'var.dat'
            else:
                var_file = 'VAR' + str(ivar)

        if proc < 0:
            proc_dirs = self.__natural_sort(filter(lambda s: s.startswith('proc'),
                                                   os.listdir(datadir)))
        else:
            proc_dirs = ['proc' + str(proc)]

        # Set up the global array.
        if not run2D:
            f = np.zeros((total_vars, dim.mz, dim.my, dim.mx),
                         dtype=precision)
        else:
            if dim.ny == 1:
                f = np.zeros((total_vars, dim.mz, dim.mx), dtype=precision)
            else:
                f = np.zeros((total_vars, dim.my, dim.mx), dtype=precision)

        x = np.zeros(dim.mx, dtype=precision)
        y = np.zeros(dim.my, dtype=precision)
        z = np.zeros(dim.mz, dtype=precision)

        for directory in proc_dirs:
            proc = int(directory[4:])
            if var_file[0:2].lower() == 'og':
                procdim = read.ogdim(datadir, proc)
            else:
                procdim = read.dim(datadir, proc)
            if not quiet:
                print("Reading data from processor {0} of {1} ...".format( \
                      proc, len(proc_dirs)))

            mxloc = procdim.mx
            myloc = procdim.my
            mzloc = procdim.mz

            # Read the data.
            file_name = os.path.join(datadir, directory, var_file)
            infile = FortranFile(file_name)
            if not run2D:
                f_loc = infile.read_record(dtype=precision)
                f_loc = f_loc.reshape((-1, mzloc, myloc, mxloc))
            else:
                if dim.ny == 1:
                    f_loc = infile.read_record(dtype=precision)
                    f_loc = f_loc.reshape((-1, mzloc, mxloc))
                else:
                    f_loc = infile.read_record(dtype=precision)
                    f_loc = f_loc.reshape((-1, myloc, mxloc))
            raw_etc = infile.read_record(precision)
            infile.close()

            t = raw_etc[0]
            x_loc = raw_etc[1:mxloc+1]
            y_loc = raw_etc[mxloc+1:mxloc+myloc+1]
            z_loc = raw_etc[mxloc+myloc+1:mxloc+myloc+mzloc+1]
            if param.lshear:
                shear_offset = 1
                deltay = raw_etc[-1]
            else:
                shear_offset = 0

            dx = raw_etc[-3-shear_offset]
            dy = raw_etc[-2-shear_offset]
            dz = raw_etc[-1-shear_offset]

            if len(proc_dirs) > 1:
                # Calculate where the local processor will go in
                # the global array.
                #
                # Don't overwrite ghost zones of processor to the left (and
                # accordingly in y and z direction -- makes a difference on the
                # diagonals)
                #
                # Recall that in NumPy, slicing is NON-INCLUSIVE on the right end
                # ie, x[0:4] will slice all of a 4-digit array, not produce
                # an error like in idl.

                if procdim.ipx == 0:
                    i0x = 0
                    i1x = i0x + procdim.mx
                    i0xloc = 0
                    i1xloc = procdim.mx
                else:
                    i0x = procdim.ipx*procdim.nx + procdim.nghostx
                    i1x = i0x + procdim.mx - procdim.nghostx
                    i0xloc = procdim.nghostx
                    i1xloc = procdim.mx

                if procdim.ipy == 0:
                    i0y = 0
                    i1y = i0y + procdim.my
                    i0yloc = 0
                    i1yloc = procdim.my
                else:
                    i0y = procdim.ipy*procdim.ny + procdim.nghosty
                    i1y = i0y + procdim.my - procdim.nghosty
                    i0yloc = procdim.nghosty
                    i1yloc = procdim.my

                if procdim.ipz == 0:
                    i0z = 0
                    i1z = i0z+procdim.mz
                    i0zloc = 0
                    i1zloc = procdim.mz
                else:
                    i0z = procdim.ipz*procdim.nz + procdim.nghostz
                    i1z = i0z + procdim.mz - procdim.nghostz
                    i0zloc = procdim.nghostz
                    i1zloc = procdim.mz

                x[i0x:i1x] = x_loc[i0xloc:i1xloc]
                y[i0y:i1y] = y_loc[i0yloc:i1yloc]
                z[i0z:i1z] = z_loc[i0zloc:i1zloc]

                if not run2D:
                    f[:, i0z:i1z, i0y:i1y, i0x:i1x] = \
                        f_loc[:, i0zloc:i1zloc, i0yloc:i1yloc, i0xloc:i1xloc]
                else:
                    if dim.ny == 1:
                        f[:, i0z:i1z, i0x:i1x] = \
                            f_loc[:, i0zloc:i1zloc, i0xloc:i1xloc]
                    else:
                        f[:, i0y:i1y, i0x:i1x] = \
                            f_loc[:, i0yloc:i1yloc, i0xloc:i1xloc]
            else:
                f = f_loc
                x = x_loc
                y = y_loc
                z = z_loc

        if magic is not None:
            if 'bb' in magic:
                # Compute the magnetic field before doing trimall.
                aa = f[index.ax-1:index.az, ...]
                # TODO: Specify coordinate system.
                self.bb = curl(aa, dx, dy, dz, run2D=run2D)
                if trimall:
                    self.bb = self.bb[:, dim.n1:dim.n2+1,
                                      dim.m1:dim.m2+1, dim.l1:dim.l2+1]
            if 'jj' in magic:
                # Compute the electric current field before doing trimall.
                aa = f[index.ax-1:index.az, ...]
                # TODO: Specify coordinate system.
                self.jj = curl2(aa, dx, dy, dz)
                if trimall:
                    self.jj = self.jj[:, dim.n1:dim.n2+1,
                                      dim.m1:dim.m2+1, dim.l1:dim.l2+1]
            if 'vort' in magic:
                # Compute the vorticity field before doing trimall.
                uu = f[index.ux-1:index.uz, ...]
                # TODO: Specify coordinate system.
                # WL: The curl subroutine should take care of it. 
                self.vort = curl(uu, dx, dy, dz, run2D=run2D)
                if trimall:
                    if run2D:
                        if dim.nz == 1:
                            self.vort = self.vort[:, dim.m1:dim.m2+1,
                                                  dim.l1:dim.l2+1]
                        else:
                            self.vort = self.vort[:, dim.n1:dim.n2+1,
                                                  dim.l1:dim.l2+1]
                    else:
                        self.vort = self.vort[:, dim.n1:dim.n2+1,
                                              dim.m1:dim.m2+1,
                                              dim.l1:dim.l2+1]

        # Trim the ghost zones of the global f-array if asked.
        if trimall:
            self.x = x[dim.l1:dim.l2+1]
            self.y = y[dim.m1:dim.m2+1]
            self.z = z[dim.n1:dim.n2+1]
            if not run2D:
                self.f = f[:, dim.n1:dim.n2+1, dim.m1:dim.m2+1, dim.l1:dim.l2+1]
            else:
                if dim.ny == 1:
                    self.f = f[:, dim.n1:dim.n2+1, dim.l1:dim.l2+1]
                else:
                    self.f = f[:, dim.m1:dim.m2+1, dim.l1:dim.l2+1]
        else:
            self.x = x
            self.y = y
            self.z = z
            self.f = f
            self.l1 = dim.l1
            self.l2 = dim.l2 + 1
            self.m1 = dim.m1
            self.m2 = dim.m2 + 1
            self.n1 = dim.n1
            self.n2 = dim.n2 + 1

        # Assign an attribute to self for each variable defined in
        # 'data/index.pro' so that e.g. self.ux is the x-velocity
        for key in index.__dict__.keys():
            if key != 'global_gg' and key != 'keys':
                value = index.__dict__[key]
                setattr(self, key, self.f[value-1, ...])
        # Special treatment for vector quantities.
        if hasattr(index, 'uu'):
            self.uu = self.f[index.ux-1:index.uz, ...]
        if hasattr(index, 'aa'):
            self.aa = self.f[index.ax-1:index.az, ...]

        self.t = t
        self.dx = dx
        self.dy = dy
        self.dz = dz
        if param.lshear:
            self.deltay = deltay

        # Do the rest of magic after the trimall (i.e. no additional curl...).
        self.magic = magic
        if self.magic is not None:
            self.magic_attributes(param)


    def __natural_sort(self, procs_list):
        """
        Sort array in a more natural way, e.g. 9VAR < 10VAR
        """

        import re

        convert = lambda text: int(text) if text.isdigit() else text.lower()
        alphanum_key = lambda key: [convert(c) for c in re.split('([0-9]+)', key)]
        return sorted(procs_list, key=alphanum_key)


    def magic_attributes(self, param):
        """
        Compute some additional 'magic' quantities.
        """

        import numpy as np
        import sys

        for field in self.magic:
            if field == 'rho' and not hasattr(self, 'rho'):
                if hasattr(self, 'lnrho'):
                    setattr(self, 'rho', np.exp(self.lnrho))
                else:
                    sys.exit("pb in magic!")

            if field == 'tt' and not hasattr(self, 'tt'):
                if hasattr(self, 'lnTT'):
                    tt = np.exp(self.lnTT)
                    setattr(self, 'tt', tt)
                else:
                    if hasattr(self, 'ss'):
                        if hasattr(self, 'lnrho'):
                            lnrho = self.lnrho
                        elif hasattr(self, 'rho'):
                            lnrho = np.log(self.rho)
                        else:
                            sys.exit("pb in magic: missing rho or lnrho variable")
                        cp = param.cp
                        gamma = param.gamma
                        cs20 = param.cs0**2
                        lnrho0 = np.log(param.rho0)
                        lnTT0 = np.log(cs20/(cp*(gamma-1.)))
                        lnTT = lnTT0+gamma/cp*self.ss+(gamma-1.)* \
                               (lnrho-lnrho0)
                        setattr(self, 'tt', np.exp(lnTT))
                    else:
                        sys.exit("pb in magic!")

            if field == 'ss' and not hasattr(self, 'ss'):
                cp = param.cp
                gamma = param.gamma
                cs20 = param.cs0**2
                lnrho0 = np.log(param.rho0)
                lnTT0 = np.log(cs20/(cp*(gamma-1.)))
                if hasattr(self, 'lnTT'):
                    setattr(self, 'ss', cp/gamma*(self.lnTT-lnTT0- \
                            (gamma-1.)*(self.lnrho-lnrho0)))
                elif hasattr(self, 'tt'):
                    setattr(self, 'ss', cp/gamma*(np.log(self.tt)- \
                            lnTT0-(gamma-1.)*(self.lnrho-lnrho0)))
                else:
                    sys.exit("pb in magic!")

            if field == 'pp' and not hasattr(self, 'pp'):
                cp = param.cp
                gamma = param.gamma
                cv = cp/gamma
                if hasattr(self, 'lnrho'):
                    lnrho = self.lnrho
                elif hasattr(self, 'rho'):
                    lnrho = np.log(self.rho)
                else:
                    sys.exit("pb in magic: missing rho or lnrho variable")
                if hasattr(self, 'ss'):
                    setattr(self, 'pp', np.exp(gamma*(self.ss+lnrho)))
                elif hasattr(self, 'lntt'):
                    setattr(self, 'pp', (cp-cv)*np.exp(self.lntt+lnrho))
                elif hasattr(self, 'tt'):
                    setattr(self, 'pp', (cp-cv)*self.tt*np.exp(lnrho))
                else:
                    sys.exit("pb in magic!")

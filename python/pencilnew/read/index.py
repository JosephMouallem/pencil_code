# index.py
#
# Read the index.pro file.
#
# Authors:
# T. Gastine (tgastine@ast.obs-mip.fr)
# S. Candelaresi (iomsn1@gmail.com)
"""
Contains the index information.
"""


def index(*args, **kwargs):
    """
    Read Pencil Code index data from index.pro.

    call signature:

    read(datadir='data', param=None, dim=None)

    Keyword arguments:

    *datadir*:
      Directory where the data is stored.

    *param*
      Parameter object.

    *dim*
      Dimension object.
    """

    index_tmp = Index()
    index_tmp.read(*args, **kwargs)
    return index_tmp


class Index(object):
    """
    Index -- holds pencil code index data.
    """

    def __init__(self):
        """
        Fill members with default values.
        """

        self.keys = []


    def read(self, datadir='data', param=None, dim=None):
        """
        Read Pencil Code index data from index.pro.

        call signature:

        read(self, datadir='data', param=None, dim=None)

        Keyword arguments:

        *datadir*:
          Directory where the data is stored.

        *param*
          Parameter object.

        *dim*
          Dimension object.
        """

        import os
        from .. import read

        if param is None:
            param = read.param(datadir=datadir, quiet=True)
        if dim is None:
            dim = read.dim(datadir=datadir)

        if param.lwrite_aux:
            totalvars = dim.mvar + dim.maux
        else:
            totalvars = dim.mvar

        index_file = open(os.path.join(datadir, 'index.pro'))
        for line in index_file.readlines():
            clean = line.strip()
            name = clean.split('=')[0].strip().replace('[', '').replace(']', '')
            if clean.split('=')[1].strip().startswith('intarr(370)'):
                continue
            val = int(clean.split('=')[1].strip())

            if val != 0  and val <= totalvars \
                and not name.startswith('i_') and name.startswith('i'):
                name = name.lstrip('i')
                if name == 'lnTT' and param.ltemperature_nolog:
                    name = 'tt'
                setattr(self, name, val)

def time_slices(field=['uu1'],datadir='data/',proc=-1,extension='xz',format='native',
                tmin=0.,tmax=1.e38,amin=0.,amax=1.,transform='plane[0]',dtstep=1,
                deltat=0,oldfile=False,outfile=""):
    """
    read a list of 1D slice files, combine them, and plot the slice in one dimension, and time in the other one.

    Options:

     field --- list of variables to slice
     datadir --- path to data directory
     proc --- an integer giving the processor to read a slice from
     extension --- which plane of xy,xz,yz,Xz. for 2D this should be overwritten.
     format --- endian. one of little, big, or native (default)
     tmin --- start time
     tmax --- end time
     amin --- minimum value for image scaling
     amax --- maximum value for image scaling
     transform --- insert arbitrary numerical code to combine the slices
     dtstep --- only plot every dt step
     deltat --- if set to nonzero, plot at fixed time interval rather than step
     outfile --- if set, write the slice values in the text file
    """
    
    datadir = os.path.expanduser(datadir)
    if outfile != "":
        outslice=file(outfile,"w")
    filename=[]
    if proc < 0:
        for i in field:
            filename += [datadir+'/slice_'+i+'.'+extension]
    else:
        for i in field:
            filename += [datadir+'/proc'+str(proc)+'/slice_'+i+'.'+extension]

    # global dim
    param = read_param(datadir)

    dim = read_dim(datadir,proc) 
    if dim.precision == 'D':
        precision = 'd'
    else:
        precision = 'f'

    # set up slice plane
    if (extension == 'xy' or extension == 'Xy'):
        hsize = dim.nx
        vsize = dim.ny
    if (extension == 'xz'):
        hsize = dim.nx
        vsize = dim.nz
    if (extension == 'yz'):
        hsize = dim.ny
        vsize = dim.nz
    plane=[]
    infile=[]
    for i in filename:
        plane += [N.zeros((vsize,hsize),dtype=precision)]
        
        infile += [npfile(i,endian=format)]

    ifirst = True
    islice = 0
    plotplane=[]
    dt=0
    nextt=tmin
    while 1:
        try:
            raw_data=[]
            for i in infile:
                raw_data += [i.fort_read(precision)]
        except ValueError:
            break
        except TypeError:
            break

        if oldfile:
            t = raw_data[0][-1]
            for i in range(len(raw_data)):
                plane[i] = raw_data[i][:-1].reshape(vsize,hsize)
        else:
            slice_z2pos = raw_data[0][-1]
            t = raw_data[0][-2]
            for i in range(len(raw_data)):
                plane[i] = raw_data[i][:-2].reshape(vsize,hsize)
        
        exec('tempplane ='+transform)

        if (t > tmin and t < tmax):
            if dt==0:
                plotplane += tempplane.tolist()
            
                if ifirst:
                    print("----islice----------t---------min-------max-------delta")
                print("%10i %10.3e %10.3e %10.3e %10.3e" % (islice,t,tempplane.min(),tempplane.max(),tempplane.max()-tempplane.min()))
                if outfile != "":
                    outslice.write("%10i %10.3e %10.3e %10.3e %10.3e" % (islice,t,tempplane.min(),tempplane.max(),tempplane.max()-tempplane.min()))
                    outslice.write("\n")

                ifirst = False
                islice += 1
                nextt=t+deltat
            if deltat==0:
                dt=(dt+1)%dtstep
            elif t >= nextt:
                dt=0
                nextt=t+deltat
            else:
                dt=1

    ax = P.axes()
    ax.set_xlabel('t')
    ax.set_ylabel('y')
    ax.set_ylim
    image = P.imshow(N.array(plotplane).reshape(islice,vsize).transpose(),vmin=amin,vmax=amax)
    manager = P.get_current_fig_manager()
    manager.show()

    for i in infile:
        i.close()
    if outfile != "":
        outslice.close()

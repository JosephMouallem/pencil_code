; +
; NAME:
;       PC_READ_VAR
;
; PURPOSE:
;       Read var.dat, or other VAR files in any imaginable way!
;
;       Returns one or more fields from a snapshot (var) file generated by a
;       Pencil Code run.  Works for one or all processors. Can select subsets
;       of the data. And pretty much do everything you could dream with a var
;       file.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_var, object=object,                               $
;                    varfile=varfile, datadir=datadir, proc=proc, $
;                    /nostats, /quiet, /help
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;       proc: Specifies processor to get the data from. Default: ALL [integer]
;    varfile: Name of the var file. Default: 'var.dat'.              [string]
;             Also for downsampled snapshots (VARd<n>)
;       ivar: Number of the varfile, to be appended optionally.      [integer]
;   allprocs: Load data from the allprocs directory.                 [integer]
;   /reduced: Load reduced collective varfiles.
;
;     object: Optional structure in which to return the loaded data. [structure]
;  variables: Array of names of variables to read.                   [string(*)]
;exit_status: Suppress fatal errors in favour of reporting the
;             error through exit_status/=0.
;
;/additional: Load all variables stored in the files, PLUS any additional
;             variables specified with the variables=[] option.
;     /magic: Call pc_magic_var to replace special variable names with their
;             functional equivalents.
;    /global: Add global values to snapshot variables.
;
;   /trimxyz: Remove ghost points from the returned x,y,z arrays.
;   /trimall: Remove ghost points from all returned variables and x,y,z arrays.
;             This is equivalent to wrapping each requested variable with
;             > pc_noghost(..., dim=dim)
;             pc_noghost will skip those variables with an initial size
;             unequal to (dim.mx,dim.my,dim.mz).
;   /unshear: Convert coordinates to unsheared frame (needed for FFT).
;     /ghost: Set ghost zones on derived variables (such as bb).
;
;     /quiet: Suppress any information messages and summary statistics.
;   /nostats: Suppress only summary statistics.
;     /stats: Force printing of summary statistics even if /quiet is set.
;      /help: Display this usage information, and exit.
;    /single: enforces single precision of returned data.
;    /sphere: For Yin-Yang grid only: create the triangulation on the unit sphere. (inactive)
;    /toyang: Provides merged data on basis of Yang grid (default: on Yin grid).a
;    /cubint: Interpolation parameter for corners of Yin-Yang grid; 0: linear interp, default: -0.5.
;             Identical with "cubic" keyword parameter of IDL routine "interpolate".
;
; EXAMPLES:
;       pc_read_var, obj=vars            ;; read all vars into vars struct
;       pc_read_var, obj=vars, proc=5    ;; read only from data/proc5
;       pc_read_var, obj=vars, /allprocs ;; read from data/allprocs
;       pc_read_var, obj=vars, /reduced  ;; read from data/reduced
;       pc_read_var, obj=vars, variables=['ss']
;                                        ;; read entropy into vars.ss
;       pc_read_var, obj=vars, variables=['bb'], /magic
;                                        ;; calculate vars.bb from aa
;       pc_read_var, obj=vars, variables=['bb'], /magic, /additional
;                                        ;; get vars.bb, vars.uu, vars.aa, etc.
;       pc_read_var, obj=vars, /bb       ;; shortcut for the above
;       pc_read_var, obj=vars, variables=['bb'], /magic, /trimall
;                                        ;; vars.bb without ghost points
;
; MODIFICATION HISTORY:
;       $Id$
;       Written by: Antony J Mee (A.J.Mee@ncl.ac.uk), 27th November 2002
;
; BUGS:
;       Note that the variable "variables" is being modified upon exiting.
;
;-
pro pc_read_var,                                                  $
    object=object, varfile=varfile_, associate=associate,         $
    variables=variables, tags=tags, magic=magic,                  $
    bbtoo=bbtoo, jjtoo=jjtoo, ootoo=ootoo, TTtoo=TTtoo, pptoo=pptoo, $
    allprocs=allprocs, reduced=reduced,                           $
    trimxyz=trimxyz, trimall=trimall, unshear=unshear,            $
    nameobject=nameobject, validate_variables=validate_variables, $
    dim=dim, grid=grid, param=param, par2=par2, ivar=ivar,        $
    datadir=datadir, proc=proc, additional=additional,            $
    nxrange=nxrange, nyrange=nyrange, nzrange=nzrange,            $
    stats=stats, nostats=nostats, quiet=quiet, help=help,         $
    swap_endian=swap_endian, f77=f77, varcontent=varcontent,      $
    global=global, scalar=scalar, run2D=run2D, noaux=noaux,       $
    ghost=ghost, bcx=bcx, bcy=bcy, bcz=bcz,                       $
    exit_status=exit_status, sphere=sphere,single=single,         $
    toyang=toyang,cubint=cubint,ogrid=ogrid

COMPILE_OPT IDL2,HIDDEN
;
; Use common block belonging to derivative routines etc. so we can
; set them up properly.
;
  common cdat, x, y, z, mx, my, mz, nw, ntmax, date0, time0, nghostx, nghosty, nghostz
  common cdat_limits, l1, l2, m1, m2, n1, n2, nx, ny, nz
  common cdat_grid,dx_1,dy_1,dz_1,dx_tilde,dy_tilde,dz_tilde,lequidist,lperi,ldegenerated
  common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
  common cdat_coords,coord_system
  common corn, llcorn, lucorn, ulcorn, uucorn
;
; Default settings.
;
  default, magic, 0
  default, trimall, 0
  default, unshear, 0
  default, ghost, 0
  default, noaux, 0
  default, bcx, 'none'
  default, bcy, 'none'
  default, bcz, 'none'
  default, validate_variables, 1
  default, single, 0
  default, toyang, 0
  default, cubint, -.5
;
  if (arg_present(exit_status)) then exit_status=0
  default, reduced, 0
  if (keyword_set(reduced)) then allprocs=1
  if not is_defined(allprocs) then begin
;
; derive allprocs from the setting in Makefile.local
;
    spawn, "grep '^ *[^\#].*io_collect' src/Makefile.local", grepres
    if strpos(grepres,'xy') ge 0 then $
      allprocs=2 $
    else if grepres ne '' then $
      allprocs=1 $
    else $
      allprocs=0
  endif
;
; If no meaningful parameters are given show some help!
;
  if (keyword_set(help)) then begin
    doc_library, 'pc_read_var'
    return
  endif
;
; Check if reduced keyword is set.
;
if (keyword_set(reduced) and (n_elements(proc) ne 0)) then $
    message, "pc_read_var: /reduced and 'proc' cannot be set both."
;
; Check if allprocs is set.
;
  if ((allprocs ne 0) and (n_elements (proc) ne 0)) then message, "pc_read_var: 'allprocs' and 'proc' cannot be set both."
;
; Set f77 keyword according to allprocs.
;
  if (keyword_set (allprocs)) then $
    if allprocs eq 1 then default, f77, 0
  default, f77, 1
;
; Default data directory.
;
  datadir = pc_get_datadir(datadir)
;
; Can only unshear coordinate frame if variables have been trimmed.
;
  if (keyword_set(unshear) and (not keyword_set(trimall))) then begin
    message, 'pc_read_var: /unshear only works with /trimall'
  endif
;
; Name and path of varfile to read.
;
  if (keyword_set(ogrid)) then begin
    if (n_elements(ivar) eq 1) then begin
      default, varfile_, 'OGVAR'
      varfile=varfile_+strcompress(string(ivar),/remove_all)
    endif else begin
      default, varfile_, 'ogvar.dat'
      varfile=varfile_
      ivar=-1
    endelse
  endif else begin
    if (n_elements(ivar) eq 1) then begin
      default, varfile_, 'VAR'
      varfile=varfile_+strcompress(string(ivar),/remove_all)
    endif else begin
      default, varfile_, 'var.dat'
      varfile=varfile_
      ivar=-1
    endelse
  endelse
;
; Downsampled snapshot?
;
  ldownsampled=strmid(varfile,0,4) eq 'VARd'
;
; Get necessary dimensions quietly.
;
logrid=0
if (keyword_set(ogrid)) then logrid=1  
  if (n_elements(dim) eq 0) then $
      pc_read_dim, object=dim, datadir=datadir, proc=proc, reduced=reduced, /quiet, down=ldownsampled, ogrid=logrid
  if (n_elements(param) eq 0) then $
      pc_read_param, object=param, dim=dim, datadir=datadir, /quiet
  if (n_elements(par2) eq 0) then begin
    if (file_test(datadir+'/param2.nml')) then begin
      pc_read_param, object=par2, /param2, dim=dim, datadir=datadir, /quiet
    endif else begin
      print, 'Could not find '+datadir+'/param2.nml'
      if (magic) then print, 'This may give problems with magic variables.'
      undefine, par2
    endelse
  endif

  if (n_elements(grid) eq 0) then $
      pc_read_grid, object=grid, dim=dim, param=param, datadir=datadir, $
      proc=proc, allprocs=allprocs, reduced=reduced, $
      swap_endian=swap_endian, /quiet, down=ldownsampled
;
; We know from param whether we have to read 2-D or 3-D data.
;
  default, run2D, 0
  if (param.lwrite_2d) then run2D=1
;
; We know from param whether we have a Yin-Yang grid.
;
  default, yinyang, 0
  if tag_exists(param,'LYINYANG') then begin

    default, cutoff_corners, 0
    default, nycut, 0
    default, nzcut, 0

    if (param.lyinyang) then yinyang=1
    if yinyang then begin
      if (param.lcutoff_corners) then cutoff_corners=1
      nycut=param.nycut & nzcut=param.nzcut
    endif

  endif
;
  if yinyang then begin
    print, 'This is a Yin-Yang grid run. Data are retrieved both in separate and in merged arrays.'
    print, 'Merged data refer to the basis of the '+(toyang ? 'Yang':'Yin')+' grid.'
  endif
;
; Set the coordinate system.
;
  coord_system=param.coord_system
;
; Read dimensions (global)...
;
  if ((n_elements(proc) eq 1) or (allprocs eq 1)) then begin
    procdim=dim
  endif else begin
    pc_read_dim, object=procdim, datadir=datadir, proc=0, /quiet, down=ldownsampled
  endelse
;
; ... and check pc_precision is set for all Pencil Code tools.
;
  pc_set_precision, dim=dim, quiet=quiet
;
; Should ghost zones be returned?
;
  if (trimall) then trimxyz=1
;
; Local shorthand for some parameters.
;
  nx=dim.nx
  ny=dim.ny
  nz=dim.nz
  nw=nx*ny*nz
  mx=dim.mx
  my=dim.my
  mz=dim.mz
  mw=mx*my*mz
  l1=dim.l1
  l2=dim.l2
  m1=dim.m1
  m2=dim.m2
  n1=dim.n1
  n2=dim.n2
  nghostx=dim.nghostx
  nghosty=dim.nghosty
  nghostz=dim.nghostz
  mvar=dim.mvar
  mvar_io=mvar
  if (param.lwrite_aux) then mvar_io+=dim.maux

  precision=dim.precision
  if (precision eq 'D') then bytes=8 else bytes=4
  mxloc=procdim.mx
  myloc=procdim.my
  mzloc=procdim.mz
;
; Number of processors over which to loop.
;
  if ((n_elements(proc) eq 1) or (allprocs eq 1)) then begin
;
; data from a single-processor run or written with IO_STRATEGY=IO_COLLECT
;
    nprocs=1
  endif else if (allprocs eq 2) then begin
;
; data written with IO_STRATEGY=IO_COLLECT_XY
;
    nprocs=dim.nprocz
    procdim.nx=nx
    procdim.ny=ny
    procdim.mx=mx
    procdim.my=my
    procdim.mw=mx*my*procdim.mz
    procdim.ipx=0
    procdim.ipy=0
    mxloc=mx
    myloc=my
  endif else begin
;
; data written with IO_STRATEGY=IO_DIST
;
    nprocs=dim.nprocx*dim.nprocy*dim.nprocz
  endelse
;
; Initialize / set default returns for ALL variables.
;
  t=zero
  x=fltarr(dim.mx)*one
  y=fltarr(dim.my)*one
  z=fltarr(dim.mz)*one
  dx=zero
  dy=zero
  dz=zero
  deltay=zero
;
  if (nprocs gt 1) then begin
    xloc=fltarr(procdim.mx)*one
    yloc=fltarr(procdim.my)*one
    zloc=fltarr(procdim.mz)*one
  endif
;
;  When reading derivative data, do not attempt to read aux variables.
;
  if (varfile eq 'dvar.dat') then noaux=1
;
;  Read meta data and set up variable/tag lists.
;
  if (is_defined(par2)) then begin
    default, varcontent, pc_varcontent(datadir=datadir,dim=dim, $
      param=param,par2=par2,quiet=quiet,scalar=scalar,noaux=noaux,run2D=run2D,down=ldownsampled,single=single)
  endif else begin
    default, varcontent, pc_varcontent(datadir=datadir,dim=dim, $
      param=param,par2=param,quiet=quiet,scalar=scalar,noaux=noaux,run2D=run2D,down=ldownsampled,single=single)
  endelse

  totalvars=(size(varcontent))[1]
;
  if (n_elements(variables) ne 0) then begin
    if (keyword_set(additional)) then begin
      filevars=(varcontent[where((varcontent[*].idlvar ne 'dummy'))].idlvar)
      variables=[filevars,variables]
      if (n_elements(tags) ne 0) then begin
        tags=[filevars,tags]
      endif
    endif
  endif else begin
    default,variables,(varcontent[where((varcontent[*].idlvar ne 'dummy'))].idlvar)
  endelse
;
; Shortcut for getting magnetic field bb.
;
  default, bbtoo, 0
  if (bbtoo and ~any(strmatch(varcontent.idlvar, 'bb'))) then begin
    variables=[variables,'bb']
    magic=1
  endif
;
; Shortcut for getting current density jj.
;
  default, jjtoo, 0
  if (jjtoo and ~any(strmatch(varcontent.idlvar, 'jj'))) then begin
    variables=[variables,'jj']
    magic=1
  endif
;
; Shortcut for getting vorticity oo.
;
  default, ootoo, 0
  if (ootoo) then begin
    variables=[variables,'oo']
    magic=1
  endif
;
; Shortcut for getting temperature.
;
  default, TTtoo, 0
  if (TTtoo) then begin
    variables=[variables,'tt']
    magic=1
  endif
;
; Shortcut for getting pressure.
;
  default, pptoo, 0
  if (pptoo) then begin
    variables=[variables,'pp']
    magic=1
  endif
;
; Default tags are set equal to the variables.
;
  default, tags, variables
;
; Sanity check for variables and tags.
;
  if (n_elements(variables) ne n_elements(tags)) then $
    message, 'ERROR: variables and tags arrays differ in size'
;
; Add global parameters (like external magnetic field) to snapshot.
;
  default, global, 0
  if (global) then begin
    pc_read_global, obj=gg, proc=proc, $
        param=param, dim=dim, datadir=datadir, swap_endian=swap_endian, allprocs=allprocs, /quiet
    global_names=tag_names(gg)
  endif
;
; Apply "magic" variable transformations for derived quantities.
;
  if (keyword_set(magic)) then $
      pc_magic_var, variables, tags, $
      param=param, par2=par2, global_names=global_names, $
      datadir=datadir, quiet=quiet
;
; Get a free unit number.
;
  get_lun, file
;
; Prepare for read (build read command).
;
  res=''
  content=''

  for iv=0L,totalvars-1L do begin
    if (varcontent[iv].variable eq 'UNKNOWN') then continue
    if (nprocs eq 1 and allprocs ne 2 and not run2D) then begin
      res=res+','+varcontent[iv].idlvar
    endif else begin
      res=res+','+varcontent[iv].idlvarloc
    endelse
    content=content+', '+varcontent[iv].variable
;
; Initialise read buffers.
;
    strg=varcontent[iv].idlinit
    if yinyang then begin
      pos=strpos(strg,',type')
      strg=strmid(strg,0,pos)+',2'+strmid(strg,pos)
    endif

    if (execute(varcontent[iv].idlvar+'='+strg,0) ne 1) then $
        message, 'Error initialising ' + varcontent[iv].variable $
        +' - '+ varcontent[iv].idlvar, /info
;
; For vector quantities skip the required number of elements of the f array.
;
    iv=iv+varcontent[iv].skip
  endfor
;
; Display information about the files contents.
;
  content = strmid(content,2)
  if (not keyword_set(quiet)) then begin
    dmx = dim.mx
    dmy = dim.my
    dmz = dim.mz
    if (run2D) then begin
      if (nx eq 1) then dmx = 1
      if (ny eq 1) then dmy = 1
      if (nz eq 1) then dmz = 1
    endif
    print, ''
    print, 'The file '+varfile+' contains: ', content
    print, ''
    print, 'The grid dimension is ', dmx, dmy, dmz
    print, ''
  endif
;
; Loop over grids (two for Yin-Yang).
;
  ia=0 
  for iyy=0,yinyang do begin
;
; Loop over processors.
;
  for i=ia,ia+nprocs-1 do begin
;
; Build the full path and filename.
;
    if (allprocs eq 2) then begin
      filename=datadir+'/proc'+str(i*dim.nprocx*dim.nprocy)+'/'+varfile
      procdim.ipz=i
    endif else if (allprocs eq 1) then begin
      if (keyword_set (reduced)) then procdir = 'reduced' else procdir = 'allprocs'
      filename=datadir+'/'+procdir+'/'+varfile
    endif else begin
      if (n_elements(proc) eq 1) then begin
        filename=datadir+'/proc'+str(proc)+'/'+varfile
      endif else begin
        filename=datadir+'/proc'+str(i)+'/'+varfile
        if (not keyword_set(quiet)) then $
            print, 'Loading chunk ', strtrim(str(i+1)), ' of ', $
            strtrim(str((yinyang+1)*nprocs)), ' (', $
            strtrim(datadir+'/proc'+str(i)+'/'+varfile), ')...'
        pc_read_dim, object=procdim, datadir=datadir, proc=i, /quiet, down=ldownsampled
      endelse
    endelse
;
; Check for existence and read the data.
;
    if (not file_test(filename)) then begin
      if (arg_present(exit_status)) then begin
        exit_status=1
        print, 'ERROR: cannot find file '+ filename
        close, /all
        return
      endif else begin
        message, 'ERROR: cannot find file '+ filename
      endelse
    endif
;
; Setup the coordinates mappings from the processor to the full domain.
;
    if (nprocs gt 1 or run2D or allprocs eq 2) then begin
;
;  Don't overwrite ghost zones of processor to the left (and
;  accordingly in y and z direction makes a difference on the
;  diagonals).
;
      xloc=fltarr(procdim.mx)*one
      yloc=fltarr(procdim.my)*one
      zloc=fltarr(procdim.mz)*one

      if (procdim.ipx eq 0L) then begin
        i0x=0L
        i1x=i0x+procdim.mx-1L
        i0xloc=0L
        i1xloc=procdim.mx-1L
      endif else begin
        i0x=i1x-procdim.nghostx+1L
        i1x=i0x+procdim.mx-1L-procdim.nghostx
        i0xloc=procdim.nghostx
        i1xloc=procdim.mx-1L
      endelse
;
      if (procdim.ipy eq 0L) then begin
        i0y=0L
        i1y=i0y+procdim.my-1L
        i0yloc=0L
        i1yloc=procdim.my-1L
      endif else if procdim.ipy ne ipy_prec then begin
        i0y=i1y-procdim.nghosty+1L
        i1y=i0y+procdim.my-1L-procdim.nghosty
        i0yloc=procdim.nghosty
        i1yloc=procdim.my-1L
      endif
;
      if (procdim.ipz eq 0L) then begin
        i0z=0L
        i1z=i0z+procdim.mz-1L
        i0zloc=0L
        i1zloc=procdim.mz-1L
      endif else if procdim.ipz ne ipz_prec then begin
        i0z=i1z-procdim.nghostz+1L
        i1z=i0z+procdim.mz-1L-procdim.nghostz
        i0zloc=procdim.nghostz
        i1zloc=procdim.mz-1L
      endif
      ipy_prec=procdim.ipy & ipz_prec=procdim.ipz
;
; Skip this processor if it makes no contribution to the requested
; subset of the domain.
;
;       if (n_elements(nxrange)==2) then begin
;         if ((i0x gt nxrange[1]+procdim.nghostx) or (i1x lt nxrange[0]+procdim.nghostx)) then continue
;         ix0=max([ix0-(nxrange[0]+procdim.nghostx),0L]
;         ix1=min([ix1-(nxrange[0]+procdim.nghostx),ix0+(nxrange[1]-nxrange[0])]
;       endif
;       if (n_elements(nyrange)==2) then begin
;         if ((i0y gt nyrange[1]+procdim.nghosty) or (i1y lt nyrange[0]+procdim.nghosty)) then continue
;       endif
;       if (n_elements(nzrange)==2) then begin
;         if ((i0z gt nzrange[1]+procdim.nghostz) or (i1z lt nzrange[0]+procdim.nghostz)) then continue
;       endif

      mxloc=procdim.mx & myloc=procdim.my & mzloc=procdim.mz

      for iv=0L,totalvars-1L do begin
        if (varcontent[iv].variable eq 'UNKNOWN') then continue
        if (execute(varcontent[iv].idlvarloc+'='+varcontent[iv].idlinitloc,0) ne 1) then $
            message, 'Error initialising ' + varcontent[iv].variable $
                      +' - '+ varcontent[iv].idlvarloc, /info
        iv=iv+varcontent[iv].skip
      endfor
    endif
;
; Open a varfile and read some data!
;
    close, file
    openr, file, filename, f77=f77, swap_endian=swap_endian

    if (not keyword_set(associate)) then begin
      if (execute('readu,file'+res) ne 1) then $
          message, 'Error reading: ' + 'readu,' + str(file) + res
    endif else begin
      message, 'Associate behaviour not implemented here yet'
    endelse
;
    if (allprocs eq 1) then begin
      ; collectively written files
      if (f77 eq 0) then begin
        idum=0L & readu, file, idum   ; read Fortran record marker as next record is sequentially written
      endif
      readu, file, t, x, y, z, dx, dy, dz
    endif else if (allprocs ne 2 and nprocs eq 1 and not run2D) then begin
      ; single processor distributed file
      if (param.lshear) then begin
        readu, file, t, x, y, z, dx, dy, dz, deltay
      endif else begin
        readu, file, t, x, y, z, dx, dy, dz
      endelse
    endif else begin
      if (allprocs eq 2) then begin
        ; xy-collectively written files for each ipz-layer
        if (f77 eq 0) then begin
          idum=0L & readu, file, idum   ; read Fortran record marker as next record is sequentially written
        endif
        if (i eq 0) then begin
          readu, file, t
          readu, file, x, y, z, dx, dy, dz
        endif else begin
          t_test = zero
          readu, file, t_test
          if (t ne t_test) then begin
            print, "ERROR: TIMESTAMP IS INCONSISTENT: ", filename
            print, "t /= t_test: ", t, t_test
            print, "Type '.c' to continue..."
            stop
          endif
        endelse
      endif else begin
        ; multiple processor distributed files
        if (param.lshear) then begin
          readu, file, t, xloc, yloc, zloc, dx, dy, dz, deltay
        endif else begin
          readu, file, t, xloc, yloc, zloc, dx, dy, dz
        endelse
        if (i eq 0) then begin
          t_test = t
        endif else begin
          if (t ne t_test) then begin
            print, "ERROR: TIMESTAMP IS INCONSISTENT: ", filename
            print, "t /= t_test: ", t, t_test
            print, "Type '.c' to continue..."
            stop
            t = t_test
          endif
        endelse
;
        x[i0x:i1x] = xloc[i0xloc:i1xloc]
        y[i0y:i1y] = yloc[i0yloc:i1yloc]
        z[i0z:i1z] = zloc[i0zloc:i1zloc]
      endelse
;
; Fill data into global arrays.
;
; Loop over variables.
;
      for iv=0L,totalvars-1L do begin
        if (varcontent[iv].variable eq 'UNKNOWN') then continue
;
; For 2-D run with lwrite_2d=T we only need to read 2-D data.
;
        if (keyword_set(run2D)) then begin
          if (nx eq 1) then begin
; 2-D run in (y,z) plane.
            cmd =   varcontent[iv].idlvar $
                + "[dim.l1,i0y:i1y,i0z:i1z,*,*]=" $
                + varcontent[iv].idlvarloc $
                +"[i0yloc:i1yloc,i0zloc:i1zloc,*,*]"
          endif else if (ny eq 1) then begin
; 2-D run in (x,z) plane.
            cmd =   varcontent[iv].idlvar $
                + "[i0x:i1x,dim.m1,i0z:i1z,*,*]=" $
                + varcontent[iv].idlvarloc $
                +"[i0xloc:i1xloc,i0zloc:i1zloc,*,*]"
          endif else begin
; 2-D run in (x,y) plane.
            cmd =   varcontent[iv].idlvar $
                + "[i0x:i1x,i0y:i1y,dim.n1,*,*]=" $
                + varcontent[iv].idlvarloc $
                +"[i0xloc:i1xloc,i0yloc:i1yloc,*,*]"
          endelse
        endif else begin
;
; Regular 3-D run.
;
          cmd =  varcontent[iv].idlvar $
              + (varcontent[iv].skip eq 0 ? "[i0x:i1x,i0y:i1y,i0z:i1z,iyy]=" : "[i0x:i1x,i0y:i1y,i0z:i1z,*,iyy]=" ) $
              + varcontent[iv].idlvarloc $
              +"[i0xloc:i1xloc,i0yloc:i1yloc,i0zloc:i1zloc,*]"
        endelse

        if (execute(cmd) ne 1) then $
            message, 'Error combining data for ' + varcontent[iv].variable
;
; For vector quantities skip the required number of elements.
;
        iv=iv+varcontent[iv].skip
      endfor
;
    endelse
;
    if (not keyword_set(associate)) then begin
      close,file
      free_lun,file
    endif
  endfor

  if yinyang then ia=nprocs

  endfor
;
; Tidy memory a little.
;
  if (nprocs gt 1) then begin
    undefine,xloc
    undefine,yloc
    undefine,zloc
    for iv=0L,totalvars-1L do begin
      if (varcontent[iv].variable eq 'UNKNOWN') then continue
      dum=execute('undefine,'+varcontent[iv].idlvarloc)
    endfor
  endif
;
; Set ghost zones on derived variables (not default).
;
  if (keyword_set(ghost)) then begin
    for iv=0,n_elements(variables)-1 do begin
; Check that only derived variables get their ghost zones set.
      if (total(variables[iv] eq varcontent.idlvar) eq 0) then begin
        variables[iv] = 'pc_setghost('+variables[iv]+',bcx='''+bcx+''',bcy='''+bcy+''',bcz='''+bcz+''',param=param,t=t)'
      endif
    endfor
  endif
;
; Check variables one at a time and skip the ones that give errors.
; This way the program can still return the other variables, instead
; of dying with an error. One can turn this option off to decrease
; execution time.
;
  if (validate_variables) then begin
    iyy=0
    skipvariable=make_array(n_elements(variables),/INT,value=0)
    for iv=0,n_elements(variables)-1 do begin
      if ( tags[iv] eq variables[iv] ) then begin
        if total(variables[iv] eq varcontent.idlvar) gt 0  then continue
        res=0
      endif else $
        res=execute(tags[iv]+'='+variables[iv])
      if (not res) then begin
        if (not keyword_set(quiet)) then $
            print,"% Skipping: "+tags[iv]+" -> "+variables[iv]
        skipvariable[iv]=1
      endif
    endfor
    if (min(skipvariable) ne 0) then return
    if (max(skipvariable) eq 1) then begin
      variables=variables[where(skipvariable eq 0)]
      tags=tags[where(skipvariable eq 0)]
    endif
  endif
;
; Save changes to the variables array (but don't include the effect of /TRIMALL).
;
  variables_in=variables
;
; Trim x, y and z if requested.
;
  if (keyword_set(trimxyz)) then $
    xyzstring="x[dim.l1:dim.l2],y[dim.m1:dim.m2],z[dim.n1:dim.n2]" $
  else $
    xyzstring="x,y,z"
;
  if yinyang then begin
;
;  Merge Yang and Yin grids; yz[2,*] is merged coordinate array; inds is index vector for Yang points outside Yin into its *1D* coordinate vectors
;
    merge_yin_yang, dim.m1, dim.m2, dim.n1, dim.n2, y, z, dy, dz, yz, inds, yghosts=yghosts, zghosts=zghosts

    if keyword_set(sphere) then begin    ; not operational
      ;lon=reform(yz[1,*]) & lat=reform(yz[0,*]) & fval=indgen((size(lon))[1])
      ;triangulate, lon, lat, triangles, sphere=sphere_data, fval=fval
      triangulate, yz[0,*], yz[1,*], triangles
      sphere_data=0 & fval=0
    endif else $
      triangulate, yz[0,*], yz[1,*], triangles

    for iyy=0,1 do $
      for i=0,n_elements(tags)-1 do begin
;
; Calculate derived variables before interpolating and merging.
;
        if (total(variables[i] eq varcontent.idlvar) eq 0) then begin
          if iyy eq 1 then begin 
            idum=execute( tags[i]+'_tmp = '+tags[i] )
            idum=execute( 'sz=size('+tags[i]+')')
            idum=execute( tags[i]+' = make_array([sz[1:sz[0]],2], /float, /nozero)')
            idum=execute( tags[i]+'['+strjoin(replicate('*,',sz[0]),/single)+'0] ='+tags[i]+'_tmp' )
            idum=execute( tags[i]+'['+strjoin(replicate('*,',sz[0]),/single)+'1] ='+variables[i] )
            idum=execute('undefine,'+tags[i]+'_tmp' )
          endif
        endif
      endfor

    if cutoff_corners then begin
; 
;  Fill the cutaway corners of both grids with interpolated data from other grid.
;
      ncornup_y=procdim.my-nycut+dim.nghosty-1 & ncornup_z=procdim.mz-nzcut+dim.nghostz-1
      ncornlo_y=my-(procdim.my-nycut)-dim.nghosty & ncornlo_z=mz-(procdim.mz-nzcut)-dim.nghostz
      scaly=(my-1)/(y[my-1]-y[0]) & scalz=(mz-1)/(z[mz-1]-z[0])
;
;  Determine first transformed coordinates of the corners.
;
      yin2yang_coors_tri, 0,ncornup_y,0,ncornup_z, y, z, llcorn
      yz_llcorn=llcorn
      yz_llcorn[0,*] = (llcorn[0,*]-y[0])*scaly & yz_llcorn[1,*] = (llcorn[1,*]-z[0])*scalz 

      yin2yang_coors_tri, my-1,ncornlo_y,0,ncornup_z, y, z, ulcorn
      yz_ulcorn=ulcorn
      yz_ulcorn[0,*] = (ulcorn[0,*]-y[0])*scaly & yz_ulcorn[1,*] = (ulcorn[1,*]-z[0])*scalz 

      yin2yang_coors_tri, 0,ncornup_y,mz-1,ncornlo_z, y, z, lucorn
      yz_lucorn=lucorn
      yz_lucorn[0,*] = (lucorn[0,*]-y[0])*scaly & yz_lucorn[1,*] = (lucorn[1,*]-z[0])*scalz 

      yin2yang_coors_tri, my-1,ncornlo_y,mz-1,ncornlo_z, y, z, uucorn
      yz_uucorn=uucorn
      yz_uucorn[0,*] = (uucorn[0,*]-y[0])*scaly & yz_uucorn[1,*] = (uucorn[1,*]-z[0])*scalz 
;
      values=fltarr((size(yz_llcorn))[2])

      for i=0,n_elements(tags)-1 do begin

        idum=execute( 'isvec = not pc_is_scalarfield('+tags[i]+',dim=dim,yinyang=yinyang)')
        inds_other='[*,*,*'+(isvec ? ',icomp' : '')+',1-iyy]' & inds_val=(isvec ? '[*,*,icomp]' : '')
        if isvec then values=fltarr(dim.mx,n_elements(yz_llcorn[0,*]),3)*one 
        ncomp=(isvec ? 2 : 0)
;
;  Interpolate and fill in both grids.
;
        for iyy=0,1 do begin
          for icomp=0,ncomp do $
            idum=execute('values'+inds_val+'=interpolate('+tags[i]+inds_other+',yz_llcorn[0,*],yz_llcorn[1,*],cubic=cubint)')
          idum=execute('set_triangle, 0,ncornup_y,0,ncornup_z, reform(values),'+tags[i]+',iyy, llcorn') 

          for icomp=0,ncomp do $
            idum=execute('values'+inds_val+'=interpolate('+tags[i]+inds_other+',yz_ulcorn[0,*],yz_ulcorn[1,*],cubic=cubint)')
          idum=execute('set_triangle, my-1,ncornlo_y,0,ncornup_z, reform(values),'+tags[i]+',iyy, ulcorn') 

          for icomp=0,ncomp do $
            idum=execute('values'+inds_val+'=interpolate('+tags[i]+inds_other+',yz_lucorn[0,*],yz_lucorn[1,*],cubic=cubint)')
          idum=execute('set_triangle, 0,ncornup_y,mz-1,ncornlo_z, reform(values),'+tags[i]+',iyy, lucorn') 

          for icomp=0,ncomp do $
            idum=execute('values'+inds_val+'=interpolate('+tags[i]+inds_other+',yz_uucorn[0,*],yz_uucorn[1,*],cubic=cubint)')
          idum=execute('set_triangle, my-1,ncornlo_y,mz-1,ncornlo_z, reform(values),'+tags[i]+',iyy, uucorn')

        endfor
      endfor
    endif
;
;  Merge data. Variables have names "*_merge"
;
    for i=0,n_elements(tags)-1 do begin

      if (total(variables[i] eq varcontent.idlvar) eq 0) then variables[i] = tags[i]

      idum=execute( 'isvec = not pc_is_scalarfield('+tags[i]+',dim=dim,yinyang=yinyang)')

      if isvec then begin
;
;  Transformation of theta and phi components in Yang grid.
;  Merged variables are fully trimmmed.
;
        idum=execute( 'trformed=transform_thph_yy(y[m1:m2],z[n1:n2],'+tags[i]+'[l1:l2,m1:m2,n1:n2,*,1-toyang])' )
        idum=execute( tags[i]+'_merge=[[ reform(transpose('+tags[i]+'[l1:l2,m1:m2,n1:n2,*,toyang],[0,2,1,3]),nx,ny*nz,3)],'+ $ 
                                      '[(reform(transpose(trformed,[0,2,1,3]),nx,ny*nz,3))[*,inds,*]]]' ) 
      endif else $
        idum=execute( tags[i]+'_merge=[[ reform(transpose('+tags[i]+'[l1:l2,m1:m2,n1:n2,toyang],[0,2,1]),nx,ny*nz)],'+ $ 
                                      '[(reform(transpose('+tags[i]+'[l1:l2,m1:m2,n1:n2,1-toyang],[0,2,1]),nx,ny*nz))[*,inds]]]' )
    endfor
  endif
;
; Make structure out of the variables.
;
  tagnames="'t','x','y','z','dx','dy','dz'" 
  if (param.lshear) then tagnames += ",'deltay'"
;
;  Merged coordinates and triangulation into object.
;
  if yinyang then begin
    tagnames += ",'yz','triangles'" 
    if is_defined(yghosts) then tagnames += ",'yghosts'"
    if is_defined(zghosts) then tagnames += ",'zghosts'"
    if keyword_set(sphere) then tagnames += ",'sphere_data', 'fval'"
  endif 
  tagnames += arraytostring(tags,QUOTE="'") 
;
;  Merged data into object.
;
  if yinyang then $
    tagnames += arraytostring(tags+'_merge',QUOTE="'")

  makeobject = "object = "+ $
      "CREATE_STRUCT(name=objectname,["+tagnames+"],t,"+xyzstring+",dx,dy,dz"
  if (param.lshear) then makeobject+=",deltay"
  if yinyang then begin
    makeobject += ",yz,triangles"
    if is_defined(yghosts) then makeobject += ",yghosts"
    if is_defined(zghosts) then makeobject += ",zghosts"
    if keyword_set(sphere) then makeobject += ",sphere_data,fval"
    mergevars=arraytostring(variables+'_merge')
  endif
;
; Remove ghost zones if requested.
;
  if (keyword_set(trimall)) then variables = 'pc_noghost('+variables+',dim=dim)'
;
; Transform to unsheared frame if requested.
;
  if (keyword_set(unshear)) then variables = 'pc_unshear('+variables+',param=param,xax=x[dim.l1:dim.l2],t=t)'
;
  makeobject += arraytostring(variables)
  if yinyang then makeobject += mergevars
  makeobject += ")"      
;
; Execute command to make the structure.
;
  if (execute(makeobject) ne 1) then begin
    message, 'ERROR evaluating variables: '+makeobject
    undefine, object
  endif
;
; If requested print a summary (actually the default - unless being quiet).
;
  if (keyword_set(stats) or $
     (not (keyword_set(nostats) or keyword_set(quiet)))) then begin
    if (not keyword_set(quiet)) then begin
      print, ''
      print, '                             Variable summary:'
      print, ''
    endif

    pc_object_stats, object, dim=dim, trim=trimall, quiet=quiet, yinyang=yinyang
    print, ' t = ', t
    print, ''
  endif

end

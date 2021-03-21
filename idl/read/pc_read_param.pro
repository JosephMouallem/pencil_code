;
; $Id$
;
;  Read param.nml
;
;  Author: Tony Mee (A.J.Mee@ncl.ac.uk)
;  $Date: 2008-07-22 07:46:24 $
;  $Revision: 1.14 $
;
;  27-nov-02/tony: coded mostly from Wolgang's start.pro
;  10-Oct-2015/PABourdin: reworked reading of parameter namelist files.
;
;  REQUIRES: external 'nl2idl' perl script (WD)
;  
pro pc_read_param, object=object, dim=dim, datadir=datadir, $
    param2=param2, run_param=run_param, print=print, quiet=quiet, help=help
COMPILE_OPT IDL2,HIDDEN
  common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
;
; If no meaningful parameters are given show some help!
;
  if (keyword_set(help)) THEN BEGIN
    print, "Usage: "
    print, ""
    print, "pc_read_param, object=object,"
    print, "               datadir=datadir, proc=proc,"
    print, "               /print, /quiet, /help,"
    print, "               /run_param"
    print, ""
    print, "Returns the parameters of a Pencil-Code run."
    print, "Returns an empty object on failure."
    print, ""
    print, "   datadir: specify the root data directory. Default is './data'        [string]"
    print, ""
    print, "   object : optional structure in which to return all the above as tags  [struct]"
    print, ""
    print, "   /run_param: for reading param2.nml (synonym: /param2)"
    print, "   /print : instruction to print all variables to standard output"
    print, "   /quiet : instruction not to print any 'helpful' information"
    print, "   /help  : display this usage information, and exit"
    print
    return
  endif
;
; Default parameters.
;
  default, quiet, 0
;
; Default data directory.
;
  datadir = pc_get_datadir(datadir)
  if (n_elements(dim) eq 0) then pc_read_dim, datadir=datadir, object=dim, quiet=quiet
;
; Build the full path and filename and check for existence.
;
  undefine, object
  idl_subdir = datadir+'/idl'
  if (not file_test (idl_subdir, /directory)) then file_mkdir, idl_subdir
  if (keyword_set(param2) or keyword_set(run_param)) then begin
    filename = datadir+'/param2.nml'
    outfile = idl_subdir+'/run_param.pro'
    if (not file_test(filename)) then begin
      if (not keyword_set(quiet)) then $
          print, "WARNING: 'run.csh' not yet executed, 'run_pars' are unavailable."
      return
    end
  endif else begin
    filename = datadir+'/param.nml'
    outfile = idl_subdir+'/start_param.pro'
    if (not file_test(filename)) then $
        message, "ERROR: '"+filename+"' not found - datadir may not be initialized, please execute 'start.csh'."
  endelse
;
; Check if we are prepared for reading anything.
;
  pencil_home = getenv ('PENCIL_HOME')
  if (pencil_home eq "") then $
      message, "ERROR: please 'source sourceme.sh', before using this function."
;
; If double precision, force input to be doubles.
;
  nl2idl_d_opt = ''
  if (data_type eq 'double') then nl2idl_d_opt += ' -d'
;
; Read the parameter namelist file.
;
  if (not keyword_set(quiet)) then print, 'Reading "'+filename+'".'
;
; Parse content of namelist file, if necessary.
;
  spawn, '"$PENCIL_HOME/bin/nl2idl" '+nl2idl_d_opt+' "'+filename+'" -o "'+outfile+'"', result
  result[0] = ''
  result = result[sort (result)]
  num_lines = (size (result, /dimensions))[0]
  object = { param_file:filename }
  for pos = 1, num_lines-1 do begin
    line = result[pos]
    EOL = stregex (line, ',? *\$ *$')
    if (EOL gt 0) then begin
;
;  For long lines which would turn into (too) long command strings:
;  store the data contents in a temporary array tmparr and use its name in the 
;  command string.
;
      ok=0
      if strlen(line) gt 500 then begin
        startind=strpos(line,'[')+1
        if startind gt 0 then begin 
;if startind gt 0 then print, 'line=', line
          ok=1
          stopind=strpos(line,']')-1
          if strpos(line,"'") ge 0 then $
            tmparr=strsplit(strmid(line,startind,stopind-startind+1),',',/EXTRACT) $
          else if strpos(line,"(") ge 0 then begin
;
            tmparr=strsplit(strmid(line,startind,stopind-startind+1),') *, *complex\(',/REGEX,/EXTRACT)
            tmparr=strjoin(tmparr,' ')
            startpos=strpos(tmparr,'(')+1 & stoppos=strpos(tmparr,')')-1
            isdble=strpos(tmparr,'D') ge 0
            if isdble ge 0 then $
              tmparr=double(strsplit(strmid(tmparr,startpos,stoppos-startpos+1),', ', /EXTRACT)) $
            else $
              tmparr=float(strsplit(strmid(tmparr,startpos,stoppos-startpos+1),', ', /EXTRACT))
            ncompl=n_elements(tmparr)/2
            tmparr=reform(tmparr,2,ncompl)
            if isdble then $
              tmparr=reform(dcomplex(tmparr[0,*],tmparr[1,*])) $
            else $
              tmparr=reform(complex(tmparr[0,*],tmparr[1,*]))
          endif else if strpos(line,'L') ge 0 then $
            tmparr=long(strsplit(strmid(line,startind,stopind-startind+1),',',/EXTRACT)) $
          else if strpos(line,'.') ge 0 then begin
            if strpos(line,'D') ge 0 then $
              tmparr=double(strsplit(strmid(line,startind,stopind-startind+1),',',/EXTRACT)) $
            else $
              tmparr=float(strsplit(strmid(line,startind,stopind-startind+1),',',/EXTRACT))
          endif else $
            tmparr=fix(strsplit(strmid(line,startind,stopind-startind+1),',',/EXTRACT))
            
          code = 'struct = {'+strmid (line, 0, startind-1)+' tmparr}'
        endif
      endif 
      if not ok then code = 'struct = {'+strmid (line, 0, EOL)+'}'

      if (not execute (code)) then message, 'ERROR: while converting ('+code+').'
      object = create_struct (object, struct)
    end
  end
;
; If requested print a summary
;
  if (keyword_set(print)) then begin
    print, 'For GLOBAL calculation domain:'
    print, '    NO SUMMARY INFORMATION CONFIGURED - edit pc_read_param.pro'
  endif
;
end

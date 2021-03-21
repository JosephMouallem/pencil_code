;
;  $Id$
;  $Date: 2008-07-31 10:07:55 $
;  $Revision: 1.49 $
;
pro pc_magic_var_dep, variables, tags, var, dep
;
;  Resolve dependencies of magic variables.
;
;  Author: Anders Johansen
;
  iv=where(variables eq var) & iv=min(iv)
;
;  If variable is requested, put dependencies in the variables array.
;
  if (iv ge 0) then begin
    iv1=where(variables eq dep) & iv1=min(iv1)
    if (iv1 eq -1) then begin
      if (iv eq 0) then begin
        variables=[dep,variables]
        tags     =[dep,     tags]
      endif else begin
        variables=[variables[0:iv-1],dep,variables[iv:n_elements(variables)-1]]
        tags     =[     tags[0:iv-1],dep,     tags[iv:n_elements(tags     )-1]]
      endelse
    endif
;
;  Move dependencies so that they are calculated before the variables.
;
    var=variables[iv]
    iv =where(variables eq var) & iv =min(iv)
    iv1=where(variables eq dep) & iv1=min(iv1)
    if (iv1 gt iv) then begin
      index=indgen(n_elements(variables))
      index[iv]=iv1 & index[iv1]=iv
      variables=variables[index] & tags=tags[index]
    endif
  endif
;
end
;
;  Author: Tony Mee (A.J.Mee@ncl.ac.uk)
;
;  25-may-04/tony: coded 
;
; Utility routine to automatically construct expressions for commonly
; requested variable from variables stored in a var file. 
;
; The routine is not really designed to be called directly
; but rather it is intended as a utility function for other
; routines such as pc_read_var.
;
; Having these shortcuts makes using transformation routines
; like pc_eoscalc that have been written in a very high-level
; general purpose way somewhat easier.
;
; See idl/magic/pc_magic_var.pro to view/add useful variables.
; NB the behaviour of pc_read_magic can be dependent upon other parameters etc.
; eg. calculation of pressure is achieved using ss for noionization and lnTT for ionization.
;
;  Examples:
;  A)
;    pc_init
;    pc_read_var,obj=data,variables=['uu','lnrho','bb','tt'],/MAGIC
;
;  Will return (if available) a structure with elements uu, lnrho, bb and
;  tt respectively containing Velocity, Log Density, Magnetic Field and 
;  Temperature fields.
;
;  B)
;    pc_init
;    pc_read_var,obj=mydata,variables=['uu','lnrho','bb','divu','pp'],/MAGIC
;  Is equivalent to:
;    pc_read_var,obj=mydata,variables=['uu','lnrho','curl(aa)','div(uu)', $
;                                       'pc_eoscalc(lnrho,ss,/pp,/lnrho_ss)'], $
;                                 tags=['uu','lnrho','bb','divu','pp']
;
;  NB. pc_init must be called prior to any possible derivative usage 
;      (e.g. here bb = curl(aa) )
;      
;  Current mappings: 
;
;    xx      -> X-Coordinate at every point 
;    yy      -> Y-Coordinate at every point 
;    zz      -> Z-Coordinate at every point 
;    rr      -> R-Coordinate at every point 
;    rho     -> Gas density 
;    bb      -> Magnetic field vector
;    divu    -> Divergence of velocity
;    u2      -> Modulus of velocity
;    cs2     -> Sound speed squared
;    ee      -> Specific energy
;    tt      -> Temperature
;    lntt    -> ln Temperature
;    pp      -> Thermal Pressure
; Dust
;    rhod    -> Dust density
;    fd      -> Dust distribution function dn = f dm
;    ad      -> Dust grain radius
;    epsd    -> Dust-to-gas ratio (sum over all bins)
;    smon    -> Supersaturation level Pmon/Psat
;    unit_md -> Dust mass unit
;    mdave   -> Average grain mass (mean over all bins)
; Interstellar
;    ismcool -> Interstellar cooling (Switched by params cooling_select)
; Gross-Pitaevskii Equation (Bose-Einstein Condensate)
;    psi2    -> mod psi squared (density squared)
;    argpsi  -> atan(imag(psi),real(psi))
;
pro pc_magic_var, variables, tags, $
    param=param, par2=par2, $
    datadir=datadir, global_names=global_names, quiet=quiet
;
;  Default values.
;
  default, quiet, 0
;
  if (not keyword_set(datadir)) then datadir='data'
  if (n_elements(param) eq 0) then $
      pc_read_param, object=param, datadir=datadir, /quiet
;
;  Add global values if requested (e.g. external magnetic field to bb).
;
  default, global, 0
  if (n_elements(global_names) gt 0) then begin
    global=1
    if (not quiet) then print, 'pc_magic_var: WARNING - overloading of global variables on snapshot data comes with no guarantee for consistent implementation'
    global_names=strlowcase(global_names)
  endif else begin
    global=0
  endelse
;
;  Dependencies.
;
  pc_magic_var_dep, variables, tags, 'va2', 'bb'
  pc_magic_var_dep, variables, tags, 'flor', 'bb'
  pc_magic_var_dep, variables, tags, 'flor', 'jj'
  pc_magic_var_dep, variables, tags, 'mten', 'bb'
  pc_magic_var_dep, variables, tags, 'mten', 'bij'
  pc_magic_var_dep, variables, tags, 'mpres', 'bb'
  pc_magic_var_dep, variables, tags, 'mpres', 'bij'
  pc_magic_var_dep, variables, tags, 'alflim', 'bb'
  pc_magic_var_dep, variables, tags, 'comprho', 'divu'
  pc_magic_var_dep, variables, tags, 'advu2', 'uij'
  pc_magic_var_dep, variables, tags, 'advb', 'uu'
  pc_magic_var_dep, variables, tags, 'advb', 'bij'
  pc_magic_var_dep, variables, tags, 'strb', 'bb'
  pc_magic_var_dep, variables, tags, 'strb', 'uij'
  pc_magic_var_dep, variables, tags, 'strbs', 'bb'
  pc_magic_var_dep, variables, tags, 'compb', 'bb'
  pc_magic_var_dep, variables, tags, 'compb', 'divu'
  pc_magic_var_dep, variables, tags, 'divadvu', 'uu'
  pc_magic_var_dep, variables, tags, 'divadvu', 'uij'
  pc_magic_var_dep, variables, tags, 'fvisc', 'uij'
  pc_magic_var_dep, variables, tags, 'fresi', 'bb'
;
;  Modules.
;
  lshear = safe_get_tag(param,'lshear',default=safe_get_tag(param,'lshear',default=0)) 
  lionization = safe_get_tag(param,'lionization',default=safe_get_tag(param,'leos_ionization',default=0)) 
  lionization_fixed = safe_get_tag(param,'lionization_fixed',default=safe_get_tag(param,'leos_ionizationi_fixed',default=0)) 
  lentropy = safe_get_tag(param,'lentropy',default=safe_get_tag(param,'lentropy',default=0)) 
;
;  Check for param.ldensity_nolog, but only if param.ldensity=T
;
   density_var='lnrho' 
   if (param.ldensity) then begin
     if (where(strmatch(tag_names(param), 'LDENSITY_NOLOG')) lt 0) then density_var='rho' $
     else if (param.ldensity_nolog) then density_var='rho'
   endif
;
  for iv=0,n_elements(variables)-1 do begin
    tags[iv]=variables[iv]
; x Coordinate
    if (variables[iv] eq 'xx') then begin
      variables[iv]='spread(spread(x,1,n_elements(y)),2,n_elements(z))'
; y Coordinate
    endif else if (variables[iv] eq 'yy') then begin
      variables[iv]='spread(spread(y,0,n_elements(x)),2,n_elements(z))'
; z Coordinate
    endif else if (variables[iv] eq 'zz') then begin
      variables[iv]='spread(spread(z,0,n_elements(x)),1,n_elements(y))'
; r Coordinate
    endif else if (variables[iv] eq 'rr') then begin
      variables[iv]='sqrt(spread(spread(x^2,1,n_elements(y)),2,n_elements(z))+spread(spread(y^2,0,n_elements(x)),2,n_elements(z))+spread(spread(z^2,0,n_elements(x)),1,n_elements(y)))'
; Magnetic field vector
    endif else if (variables[iv] eq 'bb') then begin
      variables[iv]='curl(aa[*,*,*,*,iyy])'
      if (global) then begin
        if (max(where(global_names eq 'bx_ext')) ne -1) then begin
          vari1='gg.bx_ext'
        endif else begin
          vari1='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        if (max(where(global_names eq 'by_ext')) ne -1) then begin
          vari2='gg.by_ext'
        endif else begin
          vari2='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        if (max(where(global_names eq 'bz_ext')) ne -1) then begin
          vari3='gg.bz_ext'
        endif else begin
          vari3='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        variables[iv]=variables[iv]+'+reform([[['+vari1+']],[['+vari2+']],[['+vari3+']]],dim.mx,dim.my,dim.mz,3)'
      endif
; Current density [jj=curl(bb)=curl(curl(aa))=grad(div(aa))-del2(aa)]
    endif else if (variables[iv] eq 'jj') then begin
      ;variables[iv]='graddiv(aa)-del2(aa)'
      variables[iv]='curlcurl(aa[*,*,*,*,iyy])'
      if (global) then begin
        if (max(where(global_names eq 'jx_ext')) ne -1) then begin
          vari1='gg.jx_ext'
        endif else begin
          vari1='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        if (max(where(global_names eq 'jy_ext')) ne -1) then begin
          vari2='gg.jy_ext'
        endif else begin
          vari2='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        if (max(where(global_names eq 'jz_ext')) ne -1) then begin
          vari3='gg.jz_ext'
        endif else begin
          vari3='fltarr(dim.mx,dim.my,dim.mz)'
        endelse
        variables[iv]=variables[iv]+'+reform([[['+vari1+']],[['+vari2+']],[['+vari3+']]],dim.mx,dim.my,dim.mz,3)'
      endif
; Derivative vector of magnetic vector potential
    endif else if (variables[iv] eq 'd2A') then begin
      variables[iv]='derij(aa[*,*,*,*,iyy])'
; Derivative vector of magnetic field
    endif else if (variables[iv] eq 'bij') then begin
      variables[iv]='gijcurl(aa[*,*,*,*,iyy])'
; Lorentz force
    endif else if (variables[iv] eq 'flor') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='spread(1./rho[*,*,*,iyy],3,3)*cross(jj[*,*,*,*,iyy],bb[*,*,*,*,iyy])'
      endif else begin
        variables[iv]='spread(exp(-lnrho[*,*,*,iyy]),3,3)*cross(jj[*,*,*,*,iyy],bb[*,*,*,*,iyy])'
      endelse
; Alfven speed squared
    endif else if (variables[iv] eq 'va2') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='total(bb[*,*,*,*,iyy]^2,4)/rho[*,*,*,iyy]'
      endif else begin
        variables[iv]='total(bb[*,*,*,*,iyy]^2,4)*exp(-lnrho[*,*,*,iyy])'
      endelse
; Magnetic pressure
    endif else if (variables[iv] eq 'mpres') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='-spread(1./rho[*,*,*,iyy],3,3)*reform([[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,0,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,1,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,2,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
      endif else begin
        variables[iv]='-spread(exp(-lnrho[*,*,*,iyy]),3,3)*reform([[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,0,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,1,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,*,2,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
      endelse
; Magnetic tension
    endif else if (variables[iv] eq 'mten') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='spread(1./rho[*,*,*,iyy],3,3)*reform([[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,0,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,1,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,2,*,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
      endif else begin
        variables[iv]='spread(exp(-lnrho[*,*,*,iyy]),3,3)*reform([[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,0,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,1,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(bij[*,*,*,2,*,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
      endelse
; Alfven speed limiter [ (numerical flor) = alflim * (actual flor) ].
    endif else if (variables[iv] eq 'alflim') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='(1+((total(bb[*,*,*,*,iyy]^2,4)/(param.mu0*rho[*,*,*,iyy]))/par2.va2max_jxb)^par2.va2power_jxb)^(-1./par2.va2power_jxb)'
      endif else begin
        variables[iv]='(1+((total(bb[*,*,*,*,iyy]^2,4)/(param.mu0*exp(lnrho[*,*,*,iyy])))/par2.va2max_jxb)^par2.va2power_jxb)^(-1./par2.va2power_jxb)'
      endelse
; EMF
    endif else if (variables[iv] eq 'emf') then begin
      variables[iv]='cross(uu([*,*,*,*,iyy],bb[*,*,*,*,iyy])'
; Magnetic field advection
    endif else if (variables[iv] eq 'advb') then begin
      variables[iv]='-reform([[[total(uu[*,*,*,*,iyy]*reform(bij[*,*,*,0,*,iyy]),4)]],[[total(uu[*,*,*,*,iyy]*reform(bij[*,*,*,1,*,iyy]),4)]],[[total(uu[*,*,*,*,iyy]*reform(bij[*,*,*,2,*,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
; Magnetic field advection by background shear
    endif else if (variables[iv] eq 'sadvb') then begin
      if (lshear) then begin
        variables[iv]='param.qshear*param.omega*spread(x,[1,2,3],[my,mz,3])*yder(bb[*,*,*,*,iyy])'
      endif else begin
        variables[iv]='fltarr(mx,my,mz,3)*one'
      endelse
; Magnetic stretching
    endif else if (variables[iv] eq 'strb') then begin
      variables[iv]='reform([[[total(bb[*,*,*,*,iyy]*reform(uij[*,*,*,0,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(uij[*,*,*,1,*,iyy]),4)]],[[total(bb[*,*,*,*,iyy]*reform(uij[*,*,*,2,*,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
; Magnetic stretching by background shear
    endif else if (variables[iv] eq 'strbs') then begin
      if (lshear) then begin
        variables[iv]='-param.qshear*param.omega*bb[*,*,*,0,iyy]'
      endif else begin
        variables[iv]='fltarr(mx,my,mz)*one'
      endelse
; Magnetic compression
    endif else if (variables[iv] eq 'compb') then begin
      variables[iv]='-bb[*,*,*,*,iyy]*spread(divu[*,*,*,iyy],3,3)'
; Vorticity
    endif else if (variables[iv] eq 'oo') then begin
      variables[iv]='curl(uu[*,*,*,*,iyy])'
; Divergence of velocity
    endif else if (variables[iv] eq 'divu') then begin
      variables[iv]='div(uu[*,*,*,*,iyy])'
; Derivative vector of velocity field
    endif else if (variables[iv] eq 'uij') then begin
      variables[iv]='gij(uu[*,*,*,*,iyy])'
; Gas Density 
    endif else if (density_var eq 'lnrho' and variables[iv] eq 'rho') then begin
      variables[iv]='exp(lnrho[*,*,*,iyy])'
; Logarithmic gas Density 
    endif else if (density_var eq 'rho' and variables[iv] eq 'lnrho') then begin
      variables[iv]='alog(rho[*,*,*,iyy])'
; Velocity advection
    endif else if (variables[iv] eq 'advu') then begin
      variables[iv]='-0.5*grad(dot2(uu[*,*,*,*,iyy]))+cross(uu[*,*,*,*,iyy],curl(uu[*,*,*,*,iyy]))'
    endif else if (variables[iv] eq 'advu2') then begin
      variables[iv]='-reform([[[total(uu[*,*,*,*,iyy]*reform(uij[*,*,*,0,*,iyy]),4)]],[[total(uu[*,*,*,*,iyy]*reform(uij[*,*,*,1,*,iyy]),4)]],[[total(uu[*,*,*,*,iyy]*reform(uij[*,*,*,2,*,iyy]),4)]]],dim.mx,dim.my,dim.mz,3)'
; Velocity advection by background shear
    endif else if (variables[iv] eq 'sadvu') then begin
      if (lshear) then begin
        variables[iv]='param.qshear*param.omega*spread(x,[1,2,3],[my,mz,3])*yder(uu[*,*,*,*,iyy])'
      endif else begin
        variables[iv]='fltarr(mx,my,mz,3)*one'
      endelse
; Density advection
    endif else if (variables[iv] eq 'advlnrho') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='-dot(uu[*,*,*,*,iyy],grad(alog(rho[*,*,*,iyy])))'
      endif else begin  
        variables[iv]='-dot(uu[*,*,*,*,iyy],grad(lnrho[*,*,*,iyy]))'
      endelse
; Density advection (non-logarithmic density)
    endif else if (variables[iv] eq 'advrho') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='-dot(uu[*,*,*,*,iyy],grad(rho[*,*,*,iyy]))'
      endif else begin  
        variables[iv]='-dot(uu[*,*,*,*,iyy],grad(exp(lnrho[*,*,*,iyy])))'
      endelse
; Density advection by background shear
    endif else if (variables[iv] eq 'sadvrho') then begin
      if (lshear) then begin
        if (param.ldensity_nolog) then begin
          variables[iv]='param.qshear*param.omega*spread(x,[1,2],[my,mz])*yder(rho[*,*,*,iyy])'
        endif else begin
          variables[iv]='param.qshear*param.omega*spread(x,[1,2],[my,mz])*yder(exp(lnrho[*,*,*,iyy]))'
        endelse
      endif else begin
        variables[iv]='fltarr(mx,my,mz)*one'
      endelse
; Density advection by background shear (logarithmic density)
    endif else if (variables[iv] eq 'sadvlnrho') then begin
      if (lshear) then begin
        if (param.ldensity_nolog) then begin
          variables[iv]='param.qshear*param.omega*spread(x,[1,2],[my,mz])*yder(alog(rho[*,*,*,iyy]))'
        endif else begin
          variables[iv]='param.qshear*param.omega*spread(x,[1,2],[my,mz])*yder(lnrho[*,*,*,iyy])'
        endelse
      endif else begin
        variables[iv]='fltarr(mx,my,mz)*one'
      endelse
; Density compression
    endif else if (variables[iv] eq 'comprho') then begin
      if (param.ldensity_nolog) then begin
        variables[iv]='-rho[*,*,*,iyy]*divu[*,*,*,iyy]'
      endif else begin  
        variables[iv]='-exp(lnrho[*,*,*,iyy])*divu[*,*,*,iyy]'
      endelse
; Modulus of velocity
    endif else if (variables[iv] eq 'u2') then begin
      variables[iv]='dot2(uu[*,*,*,*,iyy])'
; Divergence of advection ter,
    endif else if (variables[iv] eq 'divadvu') then begin
      variables[iv]='-dot(uu[*,*,*,*,iyy],graddiv(uu[*,*,*,*,iyy]))-total(total(uij[*,*,*,*,*,iyy]*transpose(uij[*,*,*,*,*,iyy],[2,1,0,3,4]),5),4)'
; Sound speed squared
    endif else if (variables[iv] eq 'cs2') then begin
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],lnTT[*,*,*,iyy],/cs2,/'+density_var+'_lnTT,dim=dim,param=param,datadir=datadir)'
      endif else begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/cs2,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir)'
      endelse
; Pressure gradient
    endif else if (variables[iv] eq 'fpres' or variables[iv] eq 'apres') then begin
      if lentropy then begin

        if (variables[iv] eq 'fpres') then $
          variables[iv]='-grad(pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/pp,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir))' $
        else if (param.ldensity_nolog) then $
          variables[iv]='spread(-1./rho[*,*,*,iyy],3,3)*grad(pc_eoscalc(rho[*,*,*,iyy],ss[*,*,*,iyy],/pp,/rho_ss,dim=dim,param=param,datadir=datadir))' $
        else $
          variables[iv]='spread(-exp(-lnrho[*,*,*,iyy]),3,3)*grad(pc_eoscalc(lnrho[*,*,*,iyy],ss[*,*,*,iyy],/pp,/lnrho_ss,dim=dim,param=param,datadir=datadir))'
      endif else begin
; The following only correct for isothermal gas.
        if (variables[iv] eq 'fpres') then begin
          if (param.ldensity_nolog) then $
            variables[iv]='-grad(rho[*,*,*,iyy])' $
          else $
            variables[iv]='-grad(exp(lnrho[*,*,*,iyy]))'
        endif else $
          if (param.ldensity_nolog) then $
            variables[iv]='spread(-1./rho[*,*,*,iyy],3,3)*grad(rho[*,*,*,iyy])' $
          else $
            variables[iv]='-grad(lnrho[*,*,*,iyy])'
        variables[iv]+='*param.cs02'
      endelse
; Specific energy
    endif else if (variables[iv] eq 'ee') then begin
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],lnTT[*,*,*,iyy],/ee,/'+density_var+'_lnTT,dim=dim,param=param,datadir=datadir)'
      endif else begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/ee,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir)'
      endelse
; Temperature
    endif else if (variables[iv] eq 'tt') then begin
      if (lionization and not lionization_fixed) then begin
        variables[iv]='exp(lnTT[*,*,*,iyy])'
      endif else begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/tt,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir)'
      endelse
; Logarithm of temperature
    endif else if (variables[iv] eq 'lntt') then begin
      if not (lionization and not lionization_fixed) then $
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/lntt,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir)'
; Entropy ss
    endif else if (variables[iv] eq 'ss') then begin
      if (lionization and not lionization_fixed) then begin
        message,"Thermodynamic combination not implemented yet: /ss from lnrho and lnTT with lionization"
      endif else begin
        if (lentropy ne -1) then variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],lnTT[*,*,*,iyy],/ss,/'+density_var+'_lnTT,dim=dim,param=param,datadir=datadir)'
      endelse
; Pressure
    endif else if (variables[iv] eq 'pp') then begin
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],lnTT[*,*,*,iyy],/pp,/'+density_var+'_lnTT,dim=dim,param=param,datadir=datadir)'
      endif else begin
        variables[iv]='pc_eoscalc('+density_var+'[*,*,*,iyy],ss[*,*,*,iyy],/pp,/'+density_var+'_ss,dim=dim,param=param,datadir=datadir)'
      endelse
; Divergence of dust velocity
    endif else if (variables[iv] eq 'divud') then begin
      variables[iv]='(size(uud))[0] eq 5 ? div(uud[*,*,*,*,iyy]) : div(uud[*,*,*,*,*,iyy])'
; Dust density
    endif else if (variables[iv] eq 'rhod') then begin
      variables[iv]="pc_dust_aux(nd=(size(nd))[0] eq 4 ? nd[*,*,*,iyy] : nd[*,*,*,*,iyy], md=(size(md))[0] eq 4 ? md[*,*,*,iyy] : md[*,*,*,*,iyy],param=param,var='rhod')"
; Dust distribution function dn = f dm
    endif else if (variables[iv] eq 'fd') then begin
      variables[iv]="pc_dust_aux(nd=(size(nd))[0] eq 4 ? nd[*,*,*,iyy] : nd[*,*,*,*,iyy],param=param,var='fd')"
; Dust grain radius
    endif else if (variables[iv] eq 'ad') then begin
      variables[iv]="pc_dust_aux(md=(size(md))[0] eq 4 ? md[*,*,*,iyy] : md[*,*,*,*,iyy],param=param,var='ad')"
; Dust-to-gas ratio (sum over all bins)
    endif else if (variables[iv] eq 'epsd') then begin
      variables[iv]="pc_dust_aux(lnrho=lnrho[*,*,*,iyy],nd=nd,md=md,par=param,var='epsd')"
; Supersaturation level Pmon/Psat
    endif else if (variables[iv] eq 'smon') then begin
      variables[iv]="pc_dust_aux(lnrho=lnrho[*,*,*,iyy],ss=ss[*,*,*,iyy],nd=nd,md=md," + $
          "param=param,datadir=datadir,var='smon')"
; Dust mass unit
    endif else if (variables[iv] eq 'unit_md') then begin
      variables[iv]="pc_dust_aux(param=param,var='unit_md')"
; Average grain mass (mean over all bins)
    endif else if (variables[iv] eq 'mdave') then begin
      variables[iv]="pc_dust_aux(nd=(size(nd))[0] eq 4 ? nd[*,*,*,iyy] : nd[*,*,*,*,iyy],md=(size(md))[0] eq 4 ? md[*,*,*,iyy] : md[*,*,*,*,iyy],param=param,var='mdave')"
; Interstellar cooling term (as switched by the cooling_select param.)
    endif else if (variables[iv] eq 'ismcool') then begin
      variables[iv]="pc_interstellar_cool(lnrho=lnrho[*,*,*,iyy],ss=ss[*,*,*,iyy],param=param)"
; Particle velocity
    endif else if (variables[iv] eq 'vvp') then begin
      variables[iv]="pc_particles_aux(np=np,vvpsum=vvpsum,dim=dim,var='vvp')"
; Absolute value of the wavefunction squared
    endif else if (variables[iv] eq 'psi2') then begin
      variables[iv]="psi_real[*,*,*,iyy]^2+psi_imag[*,*,*,iyy]^2"
; Argument of the complex wavefunction
    endif else if (variables[iv] eq 'argpsi') then begin
      variables[iv]="atan(psi_imag[*,*,*,iyy],psi_real[*,*,*,iyy])"
; Viscosity.
    endif else if (variables[iv] eq 'fvisc' or variables[iv] eq 'avisc') then begin

      if (param.ldensity_nolog) then begin
        rhospread ='*spread(rho[*,*,*,iyy],3,3)'
        rho1spread='/spread(rho[*,*,*,iyy],3,3)'
      endif else begin
        rhospread ='*spread(exp( lnrho[*,*,*,iyy]),3,3)'
        rho1spread='*spread(exp(-lnrho[*,*,*,iyy]),3,3)'
      endelse

      if (par2.ivisc[0] eq 'simplified') then begin
        variables[iv]='par2.nu*del2(uu[*,*,*,*,iyy])'
        if (variables[iv] eq 'fvisc') then variables[iv]+=rhospread
      endif else if (par2.ivisc[0] eq 'rho_nu-const') then begin
        variables[iv]='par2.nu*(del2(uu[*,*,*,*,iyy])+1/3.*graddiv(uu[*,*,*,*,iyy]))'
        if (variables[iv] eq 'avisc') then variables[iv]+=rho1spread
      endif else if (par2.ivisc[0] eq 'nu-const') then begin
        if (param.ldensity_nolog) then begin
          variables[iv]='par2.nu*(2*total((uij[*,*,*,*,*,iyy]+transpose(uij[*,*,*,*,*,iyy],[0,1,2,4,3]))*spread(grad(alog(rho[*,*,*,iyy])),4,3),5) + del2(uu[*,*,*,*,iyy])+1/3.*graddiv(uu[*,*,*,*,iyy]) )'
        endif else  begin
          variables[iv]='par2.nu*(2*total((uij[*,*,*,*,*,iyy]+transpose(uij[*,*,*,*,*,iyy],[0,1,2,4,3]))*spread(grad(lnrho[*,*,*,iyy]),4,3),5) + del2(uu[*,*,*,*,iyy])+1/3.*graddiv(uu[*,*,*,*,iyy]) )'
        endelse
        if (variables[iv] eq 'fvisc') then variables[iv]+=rhospread
      endif else if (par2.ivisc[0] eq 'hyper3_simplified') then begin
        variables[iv]='par2.nu_hyper3*del6(uu[*,*,*,*,iyy])'
        if (variables[iv] eq 'fvisc') then variables[iv]+=rhospread
      endif else if (par2.ivisc[0] eq 'hyper3_rho_nu-const') then begin
        variables[iv]='par2.nu_hyper3*del6(uu[*,*,*,*,iyy])'
        if (variables[iv] eq 'avisc') then variables[iv]+=rho1spread
      endif else begin
        print, 'pc_magic_var: unknown viscosity type ivisc=', par2.ivisc[0]
        variables[iv]='fltarr(mx,my,mz,3)'
      endelse
; Resistivity.
    endif else if (variables[iv] eq 'fresi') then begin
      if (par2.iresistivity[0] eq 'eta-const') then begin
        variables[iv]='par2.eta*del2(bb[*,*,*,*,iyy])'
      endif else if (par2.iresistivity[0] eq 'hyper3') then begin
        variables[iv]='par2.eta_hyper3*del6(bb[*,*,*,*,iyy])'
      endif else begin
        print, 'pc_magic_var: unknown resistivity type ivisc=', par2.iresistivity[0]
        variables[iv]='fltarr(mx,my,mz,3)'
      endelse
; Mass diffusion.
    endif else if (variables[iv] eq 'fdiff') then begin
      if (par2.idiff[0] eq 'shock') then begin
        if (param.ldensity_nolog) then begin
          variables[iv]='par2.nu_shock*shock*del2(rho[*,*,*,iyy])'
        endif else begin
          variables[iv]='par2.nu_shock*shock*exp(-lnrho[*,*,*,iyy])*del2(exp(lnrho[*,*,*,iyy]))'
        endelse
      endif else begin
        print, 'pc_magic_var: unknown diffusion type ivisc=', par2.iresistivity[0]
        variables[iv]='fltarr(mx,my,mz)'
      endelse
    endif
  endfor
;
end

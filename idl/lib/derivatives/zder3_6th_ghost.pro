;;
;;  $Id$
;;
;;  Third derivative d^3 / dz^3
;;  - 6th-order (9-point stencil) for inner grid cells
;;  - 4th-order (7-point stencil) for non-periodic boundary grid cells
;
; 12-Oct-2014/Bourdin.KIS: coded
;
function zder3,f,ghost=ghost,bcx=bcx,bcy=bcy,bcz=bcz,param=param,t=t
  COMPILE_OPT IDL2,HIDDEN
;
  common cdat, x, y, z, mx, my, mz, nw, ntmax, date0, time0, nghostx, nghosty, nghostz
  common cdat_grid,dx_1,dy_1,dz_1,dx_tilde,dy_tilde,dz_tilde,lequidist,lperi,ldegenerated
  common cdat_coords, coord_system
  common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
;
;  Default values.
;
  default, one, 1.d0
  default, ghost, 0
;
;  Calculate fmx, fmy, and fmz, based on the input array size.
;
  s = size(f)
  if ((s[0] lt 3) or (s[0] gt 4)) then $
      message, 'zder3_6th_ghost: not implemented for '+strtrim(s[0],2)+'-D arrays'
  d = make_array(size=s)
  fmx = s[1] & fmy = s[2] & fmz = s[3]
  l1 = nghostx & l2 = fmx-nghostx-1
  m1 = nghosty & m2 = fmy-nghosty-1
  n1 = nghostz & n2 = fmz-nghostz-1
;
;  Check for degenerate case (no x-derivative)
;
  if (ldegenerated[0] or (fmx eq 1)) then return, d
;
  if (lequidist[1]) then begin
    fdz = dz_1[l1]^3/240.
  endif else begin
    if (fmx ne mx) then $
        message, "zder3_6th_ghost: not implemented for subvolumes on a non-equidistant grid in x."
    fdz = one/240.
  endelse
;
  if (lperi[1]) then begin
    d[l1:l2,m1:m2,n1:n2,*] = $
          (488.*fdz)*(f[l1-1:l2-1,m1:m2,n1:n2,*]-f[l1+1:l2+1,m1:m2,n1:n2,*]) $
        - (338.*fdz)*(f[l1-2:l2-2,m1:m2,n1:n2,*]-f[l1+2:l2+2,m1:m2,n1:n2,*]) $
        +  (72.*fdz)*(f[l1-3:l2-3,m1:m2,n1:n2,*]-f[l1+3:l2+3,m1:m2,n1:n2,*]) $
        -   (7.*fdz)*(shift (f[l1:l2,m1:m2,n1:n2,*], 0, 0, -4, 0)-shift (f[l1:l2,m1:m2,n1:n2,*], 0, 0, +4, 0))
  end else begin
    ; inner grid points (6th order)
    d[l1+1:l2-1,m1:m2,n1:n2,*] = $
          (488.*fdz)*(f[l1-0:l2-2,m1:m2,n1:n2,*]-f[l1+2:l2+0,m1:m2,n1:n2,*]) $
        - (338.*fdz)*(f[l1-1:l2-3,m1:m2,n1:n2,*]-f[l1+3:l2+1,m1:m2,n1:n2,*]) $
        +  (72.*fdz)*(f[l1-2:l2-4,m1:m2,n1:n2,*]-f[l1+4:l2+2,m1:m2,n1:n2,*]) $
        -   (7.*fdz)*(f[l1-3:l2-5,m1:m2,n1:n2,*]-f[l1+5:l2+3,m1:m2,n1:n2,*])
    ; boundary grid points (4th order)
;    ???49/8 	29 	???461/8 	62 	???307/8 	13 	???15/8
    d[l1,m1:m2,n1:n2,*] = $
         (14880.*fdz)*f[l1,m1:m2,n1:n2,*] $
        -(13830.*fdz)*f[l1-1,m1:m2,n1:n2,*]-(9210.*fdz)*f[l1+1,m1:m2,n1:n2,*] $
        + (6960.*fdz)*f[l1-2,m1:m2,n1:n2,*]+(3120.*fdz)*f[l1+2,m1:m2,n1:n2,*] $
        - (1470.*fdz)*f[l1-3,m1:m2,n1:n2,*]- (450.*fdz)*f[l1+3,m1:m2,n1:n2,*]
    d[l2,m1:m2,n1:n2,*] = $
         (14880.*fdz)*f[l2,m1:m2,n1:n2,*] $
        -(13830.*fdz)*f[l1-1,m1:m2,n1:n2,*]-(9210.*fdz)*f[l1+1,m1:m2,n1:n2,*] $
        + (6960.*fdz)*f[l1-2,m1:m2,n1:n2,*]+(3120.*fdz)*f[l1+2,m1:m2,n1:n2,*] $
        - (1470.*fdz)*f[l1-3,m1:m2,n1:n2,*]- (450.*fdz)*f[l1+3,m1:m2,n1:n2,*]
  end
;
  if (not lequidist[0]) then begin
    ; Nonuniform mesh correction:
    ; d3f(xi)/dz3 = f'''*xi'^3 + 3*f"*xi'*xi" + f'*xi'''
    ; will also work on subvolumes like zder3(ss[*,10:16,20:26])
    df_dz = zder(f)
    d2f_dz2 = zder2(f)
    d[l1:l2,m1:m2,n1:n2,*] *= dz_1[l1:l2]^3
    message, "zder3: 'd2xi_dz2' is not yet implemented, needs more than 'dz_tilde'..."
    df_dz[l1:l2,m1:m2,n1:n2,*] *= d2xi_dz2[l1:l2]
    d2f_dz2[l1:l2,m1:m2,n1:n2,*] *= dz_tilde[l1:l2]
    d += df_dz
  endif
;
;  Set ghost zones.
;
  if (ghost) then d=pc_setghost(d,bcx=bcx,bcy=bcy,bcz=bcz,param=param,t=t)
;
  return, d
;
end

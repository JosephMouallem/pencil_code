#!/bin/csh
#
#$Id$
#
idl << EOF
;pc_read_ts,obj=ts
;print,ts.t(0:4)
;
pc_read_var,obj=var,/trimall
print,var.aa(5,5,0:4,1)
;
openw,1,'output.dat'
printf,1,reform(var.aa(5,5,0:4,1))
close,1
;
EOF
#
diff output.dat reference_idl_var.out
#

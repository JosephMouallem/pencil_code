;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;   pc_gui_companion.pro     ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   Framework for precalculation and comparision of output in pencil units.
;;;   Companion procedures needed by 'pc_gui.pro'.
;;;
;;;  To do:
;;;   Add more comments


; Prepares the varset
pro pc_gui_prepare_varset, num, units, coords, varset, overset, dir, start_params, run_params, idlvar_list

	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, datadir, sources, start_param, run_param, var_list

	datadir = dir

	unit = units
	coord = coords
	start_param = start_params
	run_param = run_params
	var_list = idlvar_list

	varfiles = { title:"-", time:0.0d0, loaded:0, number:-1, precalc_done:0 }
	varfiles = replicate (varfiles, num)

	if (num le 1) then begin
		varsets = varset
		oversets = overset
	end else begin
		varsets = replicate (varset, num)
		oversets = replicate (overset, num)
	end
end


; Precalculates a data set and loads data, if necessary
pro pc_gui_precalc, i, number=number, varfile=varfile, datadir=dir, dim=dim, start_param=start_par, run_param=run_par, varcontent=varcontent, allprocs=allprocs, reduced=reduced, show_aver=show_aver, time=time, xs=xs, xe=xe, ys=ys, ye=ye, zs=zs, ze=ze

	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, datadir, sources, start_param, run_param, var_list

	; Default settings
	default, show_aver, 0
	default, xs, 0
	default, ys, 0
	default, zs, 0
	default, xe, coord.orig_nx
	default, ye, coord.orig_ny
	default, ze, coord.orig_nz
	default, number, i
	dir=pc_get_datadir(dir)
	default, datadir, dir
	default, time, 0.0d0
	if (keyword_set (par)) then start_param = start_par
	if (keyword_set (run_par)) then run_param = run_par

	if (varfiles[i].number le 0) then varfiles[i].number = number

	if (varfiles[i].loaded eq 0) then begin
		default, varfile, "var.dat"
		if (n_elements (vars) eq 0) then begin
			print, 'Reading: ', varfile, ' ... please wait!'
			if ((xe-xs lt coord.orig_nx-1) or (ye-ys lt coord.orig_ny-1) or (ze-zs lt coord.orig_nz-1)) then begin
				pc_read_subvol_raw, varfile=varfile, var_list=var_list, object=vars, tags=tags, datadir=datadir, sub_dim=dim, start_param=start_param, run_param=run_param, varcontent=varcontent, allprocs=allprocs, reduced=reduced, time=time, quiet=(i ne 0), xs=xs, xe=xe, ys=ys, ye=ye, zs=zs, ze=ze, /addghosts
			end else begin
				pc_read_var_raw, varfile=varfile, var_list=var_list, object=vars, tags=tags, datadir=datadir, dim=dim, start_param=start_param, run_param=run_param, varcontent=varcontent, allprocs=allprocs, reduced=reduced, time=time, quiet=(i ne 0)
			end
			sources = varcontent.idlvar
			sources = sources[where (varcontent.idlvar ne 'dummy')]
			pc_gui_precalc_data, number, vars, tags, dim, grid
		end
		varfiles[i].title = varfile
		varfiles[i].loaded = 1
		varfiles[i].precalc_done = 1
		varfiles[i].time = time * unit.time / unit.default_time
		vars = 0
	end

	if (show_aver) then draw_averages, number
	if (keyword_set (start_par)) then start_par = start_param
	if (keyword_set (run_par)) then run_par = run_param
end


; Precalculates a data set
pro pc_gui_precalc_data, i, vars, index, dim, gird

	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, datadir, sources, start_param, run_param, var_list

	; Compute all desired quantities from available source data
	tags = tag_names (varsets[i])
	num = n_elements (tags)
	for pos = 0, num-1 do begin
		tag = tags[pos]
		last = (pos eq num-1)
		varsets[i].(pos) = pc_get_quantity (tag, vars, index, unit=unit, dim=dim, grid=grid, start_param=start_param, run_param=run_param, datadir=datadir, /cache, clean=last)

		; Divide by default units, where applicable.
		if (any (strcmp (tag, ['u_abs', 'u_x', 'u_y', 'u_z'], /fold_case)) and (unit.default_velocity ne 1)) then $
			varsets[i].(pos) /= unit.default_velocity
		if (any (strcmp (tag, ['Temp'], /fold_case)) and (unit.default_temperature ne 1)) then $
			varsets[i].(pos) /= unit.default_temperature
		if (any (strcmp (tag, ['rho'], /fold_case)) and (unit.default_density ne 1)) then $
			varsets[i].(pos) /= unit.default_density
		if (any (strcmp (tag, ['ln_rho'], /fold_case)) and (unit.default_density ne 1)) then $
			varsets[i].(pos) -= alog (unit.default_density)
		if (any (strcmp (tag, ['log_rho'], /fold_case)) and (unit.default_density ne 1)) then $
			varsets[i].(pos) -= alog10 (unit.default_density)
		if (any (strcmp (tag, ['B_abs', 'B_x', 'B_y', 'B_z'], /fold_case)) and (unit.default_magnetic_field ne 1)) then $
			varsets[i].(pos) /= unit.default_magnetic_field
		if (any (strcmp (tag, ['j_abs'], /fold_case)) and (unit.default_current_density ne 1)) then $
			varsets[i].(pos) /= unit.default_current_density
	end

	; Compute all desired overplot quantities from available source data
	tags = tag_names (oversets[i])
	num = n_elements (tags)
	for pos = 0, num-1 do begin
		tag = tags[pos]
		if (strcmp (tag, "none", /fold_case)) then continue
		last = (pos eq num-1)
		oversets[i].(pos) = pc_get_quantity (tag, vars, index, unit=unit, dim=dim, grid=grid, start_param=start_param, run_param=run_param, datadir=datadir, /cache, clean=last)
		; Divide by default units, where applicable.
		if (any (strcmp (tag, ['u'], /fold_case))) then $
			oversets[i].(pos) /= unit.default_velocity
		if (any (strcmp (tag, ['b'], /fold_case))) then $
			oversets[i].(pos) /= unit.default_magnetic_field
	end
end


; Dummy routine
pro pc_gui_companion

	pc_gui_companion_loaded = 1
end


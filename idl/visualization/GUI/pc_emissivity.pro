;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;   pc_emissivity.pro   ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   Fast and simple to use tool to view and compare emissivities of different ions.
;;;   This tool expects, that '.r pc_gui' has already been executed.
;;;
;;;  To do:
;;;   Add more comments


; Event handling of emissivity visualisation window
pro pc_emissivity_event, event

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common emissive_event, button_pressed
	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, val_min, val_max, val_range, dimensionality, frozen

	WIDGET_CONTROL, WIDGET_INFO(event.top, /CHILD)

	quit = -1
	DRAW_IMAGES = 0

	WIDGET_CONTROL, event.id, GET_UVALUE = eventval


	SWITCH eventval of
	'CUT_Z':  begin
		WIDGET_CONTROL, event.id, GET_VALUE = cut_z
		pc_emissivity_cut_z, cut_z, dragging=event.drag
		DRAW_IMAGES = 1
		break
	end
	'HORIZ':  begin
		sub_horiz = event.select
		WIDGET_CONTROL, em_sel, SENSITIVE = 0
		WIDGET_CONTROL, image, SENSITIVE = 0
		pc_emissivity_precalc
		WIDGET_CONTROL, em_sel, SENSITIVE = 1
		WIDGET_CONTROL, image, SENSITIVE = 1
		DRAW_IMAGES = 1
		break
	end
	'VAL_B': begin
		WIDGET_CONTROL, val_b, GET_VALUE = sl_min
		if (sl_min gt sl_max) then begin
			sl_min = sl_max
			WIDGET_CONTROL, val_b, SET_VALUE = sl_min
		end
		emin = 10^sl_min
		DRAW_IMAGES = 1
		break
	end
	'VAL_T': begin
		WIDGET_CONTROL, val_t, GET_VALUE = sl_max
		if (sl_max lt sl_min) then begin
			sl_max = sl_min
			WIDGET_CONTROL, val_t, SET_VALUE = sl_max
		end
		emax = 10^sl_max
		DRAW_IMAGES = 1
		break
	end
	'EMIS': begin
		last = selected_emissivity
		selected_emissivity = event.index
		if (last ne selected_emissivity) then begin
			WIDGET_CONTROL, em_sel, SENSITIVE = 0
			WIDGET_CONTROL, image, SENSITIVE = 0
			pc_emissivity_precalc
			WIDGET_CONTROL, em_sel, SENSITIVE = 1
			WIDGET_CONTROL, image, SENSITIVE = 1
		end
		DRAW_IMAGES = 1
		break
	end
	'IMAGE': begin
		WIDGET_CONTROL, em_sel, SENSITIVE = 0
		WIDGET_CONTROL, image, SENSITIVE = 0
		pc_emissivity_save, "PNG"
		WIDGET_CONTROL, em_sel, SENSITIVE = 1
		WIDGET_CONTROL, image, SENSITIVE = 1
		break
	end
	'EM_X':
	'EM_Y': begin
		if (event.press) then button_pressed = 1
		if (button_pressed) then begin
			pos_z = event.y / bin_z > 0 < (num_z-1)
			pc_emissivity_cut_z, pos_z, dragging=(event.release ne 1)
		end
		if (event.release) then button_pressed = 0
		DRAW_IMAGES = 1
		break
	end
	'QUIT': begin
		quit = event.top
		break
	end
	endswitch

	if (DRAW_IMAGES) then pc_emissivity_plot

	WIDGET_CONTROL, WIDGET_INFO (event.top, /CHILD)

	IF quit GE 0 THEN  WIDGET_CONTROL, quit, /DESTROY

	return
end


; Cuts a defined part of the lower layer for Z-integration
pro pc_emissivity_cut_z, pos_z, dragging=dragging

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, val_min, val_max, val_range, dimensionality, frozen

	if (n_elements (dragging) eq 0) then dragging = 0

	if (pos_z ne cut_z) then begin
		WIDGET_CONTROL, sl_cut, SET_VALUE = cut_z
		cut_z = pos_z
	end

	WIDGET_CONTROL, em_sel, SENSITIVE = 0
	WIDGET_CONTROL, image, SENSITIVE = 0
	if (dragging le 0) then begin
		em_z = total (em[*,*,cut_z:*], 3)
		if ((bin_x ne 1) or (bin_y ne 1)) then em_z = congrid (em_z, fix (num_x*bin_x), fix (num_y*bin_y), cubic=0)
	end
	WIDGET_CONTROL, em_sel, SENSITIVE = 1
	WIDGET_CONTROL, image, SENSITIVE = 1
end


; Calculates emissivities
pro pc_emissivity_precalc

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, datadir, sources, param, run_param
	common settings_common, px, py, pz, cut, abs_scale, show_cross, show_cuts, sub_aver, selected_cube, selected_overplot, selected_snapshot, af_x, af_y, af_z
	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, val_min, val_max, val_range, dimensionality, frozen

	T_0 = parameter[selected_emissivity].T_ex
	dT = parameter[selected_emissivity].delta_T

	; Cosine contribution function:
;	em = (1 - cos (((1 - ((alog10 (varsets[selected_snapshot].temp[cut]) - T_0) / dT)^2) > 0) * !PI)) * 10^((varsets[selected_snapshot].log_rho[cut]) * 2)
	; Quadratic-cutoff contribution function:
;	em = ((1 - ((alog10 (varsets[selected_snapshot].temp[cut]) - T_0) / dT)^2) > 0) * 10^((varsets[selected_snapshot].log_rho[cut]) * 2)
	; Gaussian contribution function:
	em = exp (-((alog10 (varsets[selected_snapshot].temp[cut]) - T_0) / dT)^2) * 10^((varsets[selected_snapshot].log_rho[cut]) * 2)

	em_x = total (em, 1)
	em_y = total (em, 2)
	em_z = total (em[*,*,cut_z:*], 3)

	; normalise to averages of maximum emissivities in horizontal layers
	if (sub_horiz) then begin
		m = 0
		std = 10^mean ([sl_min, sl_max])
		for z=cut_z, num_z-1 do begin
			zs = min ([num_z/2, num_z-aver_z-1])
			if (z lt zs) then begin
				m = 0
				for iz=zs, zs+aver_z do m += max (em_x[*,iz]) + max (em_y[*,iz])
				m /= aver_z * 2
			end
			if (m gt 0) then begin
				em_x[*,z] *= std / m
				em_y[*,z] *= std / m
			end
		end
	end

	if (bin_x ne 1 or bin_z ne 1) then em_x = congrid (em_x, fix (num_y*bin_y), fix (num_z*bin_z), cubic = 0)
	if (bin_y ne 1 or bin_z ne 1) then em_y = congrid (em_y, fix (num_x*bin_x), fix (num_z*bin_z), cubic = 0)
	if (bin_x ne 1 or bin_y ne 1) then em_z = congrid (em_z, fix (num_x*bin_x), fix (num_y*bin_y), cubic = 0)
end


; Plots integrated emissivities in x-, y- and z-direction
pro pc_emissivity_plot

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, val_min, val_max, val_range, dimensionality, frozen

	plot_em_x = em_x
	plot_em_y = em_y

	if (cut_z ge 1) then begin
		plot_em_x[*,0:(cut_z-1)*bin_z] = 0.5 * (emin + emax)
		plot_em_y[*,0:(cut_z-1)*bin_z] = 0.5 * (emin + emax)
	endif

	wset, wem_x
	tvscl, alog10 ((plot_em_x > emin) < emax)

	wset, wem_y
	tvscl, alog10 ((plot_em_y > emin) < emax)

	wset, wem_z
	tvscl, alog10 ((em_z > emin) < emax)
end


; Saves the data with the given format
pro pc_emissivity_save, img_type

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, datadir, sources
	common settings_common, px, py, pz, cut, abs_scale, show_cross, show_cuts, sub_aver, selected_cube, selected_overplot, selected_snapshot, af_x, af_y, af_z

	prefix = parameter[selected_emissivity].title
	suffix = "." + strlowcase (img_type)

	wset, wem_x
	save_image, prefix+"_x"+suffix
	wset, wem_y
	save_image, prefix+"_y"+suffix
	wset, wem_z
	save_image, prefix+"_z"+suffix

	x = coord.x * unit.default_length
	y = coord.y * unit.default_length
	z = coord.z * unit.default_length
	dx = coord.dx
	dy = coord.dy
	dz = coord.dz
	time = varfiles[selected_snapshot].time * unit.time
	parameters = parameter[selected_emissivity]
	emissivity = prefix

	save, filename=prefix+"_cuts.xdr", time, emissivity, parameters, em_x, em_y, em_z, x, y, z, dx, dy, dz
end


; Emissivity plotting GUI
pro pc_emissivity, sets, limits, scaling=scaling

	common emissive_common, parameter, selected_emissivity, em, em_x, em_y, em_z, cut_z, sub_horiz, aver_z, emin, emax
	common emigui_common, wem_x, wem_y, wem_z, val_t, val_b, sl_min, sl_max, sl_cut, em_sel, image
	common emissive_event, button_pressed
	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, val_min, val_max, val_range, dimensionality, frozen

	; Emissivities for different ions (values with only one decimal digit are UNVERIFIED)
	; Temperatures are logarithmic to the base of 10
	parameter = [ $
		{ title:'Si II',   lambda:1533, T_ion:4.60, T_ex:4.36, T_DEM:4.08, T_MHD:4.25, delta_T:0.3  }, $
		{ title:'Si IV',   lambda:1394, T_ion:4.81, T_ex:4.85, T_DEM:4.82, T_MHD:4.90, delta_T:0.29 }, $
		{ title:'C II',    lambda:1335, T_ion:4.67, T_ex:4.57, T_DEM:4.23, T_MHD:4.64, delta_T:0.22 }, $
		{ title:'C III',   lambda:977,  T_ion:4.78, T_ex:4.8,  T_DEM:4.71, T_MHD:4.84, delta_T:0.29 }, $
		{ title:'C IV',    lambda:1548, T_ion:5.00, T_ex:5.00, T_DEM:5.02, T_MHD:5.11, delta_T:0.25 }, $
		{ title:'O IV',    lambda:1401, T_ion:5.27, T_ex:5.14, T_DEM:5.15, T_MHD:5.18, delta_T:0.32 }, $
		{ title:'O V',     lambda:630,  T_ion:5.38, T_ex:5.35, T_DEM:5.40, T_MHD:5.44, delta_T:0.28 }, $
		{ title:'O VI',    lambda:1032, T_ion:5.45, T_ex:5.44, T_DEM:5.50, T_MHD:5.60, delta_T:0.23 }, $
		{ title:'Ne VIII', lambda:770,  T_ion:5.81, T_ex:5.76, T_DEM:5.82, T_MHD:5.89, delta_T:0.16 }, $
		{ title:'Mg X',    lambda:625,  T_ion:6.04, T_ex:6.01, T_DEM:6.01, T_MHD:6.06, delta_T:0.17 }, $
		{ title:'Fe IX',   lambda:173,  T_ion:0.0,  T_ex:5.8,  T_DEM:0.0,  T_MHD:0.0,  delta_T:0.5 }, $  ; needs verifivation
		{ title:'Fe XII',  lambda:195,  T_ion:0.0,  T_ex:6.0,  T_DEM:0.0,  T_MHD:0.0,  delta_T:0.3 }, $  ; needs verifivation
		{ title:'Fe XV',   lambda:284,  T_ion:0.0,  T_ex:6.35, T_DEM:0.0,  T_MHD:0.0,  delta_T:0.25 } $  ; needs verifivation
	      ]
	n_emissivities = n_elements (parameter)

	; SETTINGS/DEFAULTS:
	selected_emissivity = 0
	cut_z = 0
	emin = -30.0
	emax =  10.0
	sl_min = -24.0
	sl_max = -18.0
	sub_horiz = 0
	aver_z = 10

	em = dblarr (num_x,num_y,num_z)
	em_x = dblarr (num_y,num_z)
	em_y = dblarr (num_x,num_z)
	em_z = dblarr (num_x,num_y)

	MOTHER	= WIDGET_BASE (title='emissivitiy')
	BASE	= WIDGET_BASE (MOTHER, /col)
	TOP	= WIDGET_BASE (base, /row)
	col	= WIDGET_BASE (top, /col)
	tmp	= WIDGET_LABEL (col, value='Plot starts at z-layer:', frame=0)
	col	= WIDGET_BASE (top, /col)
	sl_cut	= WIDGET_SLIDER (col, uvalue='CUT_Z', value=cut_z, min=0, max=num_z-1, xsize=num_z*bin_z, /drag)
	col	= WIDGET_BASE (top, /col)
	em_sel	= WIDGET_DROPLIST (col, value=(parameter[*].title), uvalue='EMIS', EVENT_PRO=pc_emissivity_event, title='Ion:', SENSITIVE = 0)
	col	= WIDGET_BASE (top, /col)
	b_sub	= CW_BGROUP (col, 'normalise averages', /nonexcl, uvalue='HORIZ', set_value=sub_horiz)
	col	= WIDGET_BASE (top, /col)
	image	= WIDGET_BUTTON (col, value='SAVE IMAGE', UVALUE='IMAGE', xsize=100)
	col	= WIDGET_BASE (top, /col)
	tmp	= WIDGET_BUTTON (col, value='QUIT', UVALUE='QUIT', xsize=100)
	drow	= WIDGET_BASE (BASE, /row)
	dem_x	= WIDGET_DRAW (drow, UVALUE='EM_X', xsize=num_y*bin_y, ysize=num_z*bin_z, retain=2, /button_events, /motion_events)
	dem_y	= WIDGET_DRAW (drow, UVALUE='EM_Y', xsize=num_x*bin_x, ysize=num_z*bin_z, retain=2, /button_events, /motion_events)
	dem_z	= WIDGET_DRAW (drow, UVALUE='EM_Z', xsize=num_x*bin_x, ysize=num_y*bin_y, retain=2)
	bcot	= WIDGET_BASE (base, /row)

	sl_size = ((2*num_x*bin_x+num_y*bin_y)/2.5 > (400+max([num_x*bin_x,num_y*bin_y,num_z*bin_z]))/2) < 500
	val_b	= CW_FSLIDER (bcot, title='lower value (black level)', uvalue='VAL_B', /edit, min=emin, max=emax, drag=1, value=sl_min, xsize=sl_size)
	val_t	= CW_FSLIDER (bcot, title='upper value (white level)', uvalue='VAL_T', /edit, min=emin, max=emax, drag=1, value=sl_max, xsize=sl_size)

	WIDGET_CONTROL, MOTHER, /REALIZE
	WIDGET_CONTROL, dem_x, GET_VALUE = wem_x
	WIDGET_CONTROL, dem_y, GET_VALUE = wem_y
	WIDGET_CONTROL, dem_z, GET_VALUE = wem_z

	WIDGET_CONTROL, BASE

	XMANAGER, "pc_emissivity", MOTHER, /no_block

	emin = 10^sl_min
	emax = 10^sl_max

	button_pressed = 0
	pc_emissivity_precalc
	pc_emissivity_plot
	WIDGET_CONTROL, em_sel, SENSITIVE = 1

	return
end


;;; Settings:

; Quantities to be used for emissivity (calculated in 'pc_emissivity_precalc'):
emissivity_quantities = { Temp:'temperature', log_rho:'log density' }


pc_emissivity, emissivity_quantities, lmn12, scaling=scaling

window, 0, xsize=8, ysize=8, retain=2
!P.MULTI = [0, 1, 1]
wdelete

end


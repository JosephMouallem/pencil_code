;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;   pc_show_ts.pro     ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   GUI for investigation and analysis of the timeseries.
;;;
;;;  To do:
;;;   Add more comments


; Event handling of visualisation window
pro pc_show_ts_event, event

	common timeseries_common, time_start, time_end, ts, units, run_par, start_par, orig_dim, lvx_min, lvx_max, lvy_min, lvy_max, rvx_min, rvx_max, rvy_min, rvy_max, l_plot, r_plot, l_sx, l_sy, r_sx, r_sy, plot_style
	common timeseries_gui_common, l_x, l_y, r_x, r_y, lx_min, lx_max, ly_min, ly_max, rx_min, rx_max, ry_min, ry_max, lx_fr, rx_fr, l_coupled, r_coupled, lx_range, ly_range, rx_range, ry_range, s_line

	WIDGET_CONTROL, WIDGET_INFO (event.top, /CHILD)
	WIDGET_CONTROL, event.id, GET_UVALUE = eventval

	quit = -1
	L_DRAW_TS = 0
	R_DRAW_TS = 0

	SWITCH eventval of
	'ANALYZE': begin
		pc_show_ts_analyze
		break
	end
	'LX_MIN': begin
		WIDGET_CONTROL, lx_min, GET_VALUE = val_min
		if (l_coupled lt 0) then begin
			val_max = lvx_max
			if (val_min gt val_max) then begin
				val_min = val_max
				WIDGET_CONTROL, lx_min, SET_VALUE = val_min
			end
		end else begin
			val_max = lx_range[1]
			if (val_min gt val_max-l_coupled) then begin
				val_min = val_max-l_coupled
				WIDGET_CONTROL, lx_min, SET_VALUE = val_min
			end
			val_max = val_min+l_coupled
			WIDGET_CONTROL, lx_max, SET_VALUE = val_max
			lvx_max = val_max
		end
		lvx_min = val_min
		L_DRAW_TS = 1
		break
	end
	'LX_MAX': begin
		WIDGET_CONTROL, lx_max, GET_VALUE = val_max
		if (l_coupled lt 0) then begin
			val_min = lvx_min
			if (val_max lt val_min) then begin
				val_max = val_min
				WIDGET_CONTROL, lx_max, SET_VALUE = val_max
			end
		end else begin
			val_min = lx_range[0]
			if (val_max lt val_min+l_coupled) then begin
				val_max = val_min+l_coupled
				WIDGET_CONTROL, lx_max, SET_VALUE = val_max
			end
			val_min = val_max-l_coupled
			WIDGET_CONTROL, lx_min, SET_VALUE = val_min
			lvx_min = val_min
		end
		lvx_max = val_max
		L_DRAW_TS = 1
		break
	end
	'LY_MIN': begin
		WIDGET_CONTROL, ly_min, GET_VALUE = lvy_min
		if (lvy_min gt ly_range[1]) then begin
			lvy_min = ly_range[1]
			WIDGET_CONTROL, ly_min, SET_VALUE = lvy_min
		end
		L_DRAW_TS = 1
		break
	end
	'LY_MAX': begin
		WIDGET_CONTROL, ly_max, GET_VALUE = lvy_max
		if (lvy_max lt ly_range[0]) then begin
			lvy_max = ly_range[0]
			WIDGET_CONTROL, ly_max, SET_VALUE = lvy_max
		end
		L_DRAW_TS = 1
		break
	end
	'RX_MIN': begin
		WIDGET_CONTROL, rx_min, GET_VALUE = val_min
		if (r_coupled lt 0) then begin
			val_max = rvx_max
			if (val_min gt val_max) then begin
				val_min = val_max
				WIDGET_CONTROL, rx_min, SET_VALUE = val_min
			end
		end else begin
			val_max = rx_range[1]
			if (val_min gt val_max-r_coupled) then begin
				val_min = val_max-r_coupled
				WIDGET_CONTROL, rx_min, SET_VALUE = val_min
			end
			val_max = val_min+r_coupled
			WIDGET_CONTROL, rx_max, SET_VALUE = val_max
			rvx_max = val_max
		end
		rvx_min = val_min
		R_DRAW_TS = 1
		break
	end
	'RX_MAX': begin
		WIDGET_CONTROL, rx_max, GET_VALUE = val_max
		if (r_coupled lt 0) then begin
			val_min = rvx_min
			if (val_max lt val_min) then begin
				val_max = val_min
				WIDGET_CONTROL, rx_max, SET_VALUE = val_max
			end
		end else begin
			val_min = rx_range[0]
			if (val_max lt val_min+r_coupled) then begin
				val_max = val_min+r_coupled
				WIDGET_CONTROL, rx_max, SET_VALUE = val_max
			end
			val_min = val_max-r_coupled
			WIDGET_CONTROL, rx_min, SET_VALUE = val_min
			rvx_min = val_min
		end
		rvx_max = val_max
		R_DRAW_TS = 1
		break
	end
	'RY_MIN': begin
		WIDGET_CONTROL, ry_min, GET_VALUE = rvy_min
		if (rvy_min gt rvy_max) then begin
			rvy_min = rvy_max
			WIDGET_CONTROL, ry_min, SET_VALUE = rvy_min
		end
		R_DRAW_TS = 1
		break
	end
	'RY_MAX': begin
		WIDGET_CONTROL, ry_max, GET_VALUE = rvy_max
		if (rvy_max lt rvy_min) then begin
			rvy_max = rvy_min
			WIDGET_CONTROL, ry_max, SET_VALUE = rvy_max
		end
		R_DRAW_TS = 1
		break
	end
	'L_X': begin
		if (l_sx ne event.index) then begin
			l_sx = event.index
			lx_range = minmax (ts.(l_sx))
			lvx_min = lx_range[0]
			lvx_max = lx_range[1]
			WIDGET_CONTROL, lx_min, SET_VALUE = [lvx_min, get_val_range (lx_range)]
			WIDGET_CONTROL, lx_max, SET_VALUE = [lvx_max, get_val_range (lx_range)]
			WIDGET_CONTROL, lx_fr, SENSITIVE = 0
			L_DRAW_TS = 1
		end
		break
	end
	'L_Y': begin
		if (l_sy ne event.index) then begin
			l_sy = event.index
			ly_range = minmax (ts.(l_sy))
			lvy_min = ly_range[0]
			lvy_max = ly_range[1]
			WIDGET_CONTROL, ly_min, SET_VALUE = [lvy_min, get_val_range (ly_range)]
			WIDGET_CONTROL, ly_max, SET_VALUE = [lvy_max, get_val_range (ly_range)]
			L_DRAW_TS = 1
		end
		break
	end
	'R_X': begin
		if (r_sx ne event.index) then begin
			r_sx = event.index
			rx_range = minmax (ts.(r_sx))
			rvx_min = rx_range[0]
			rvx_max = rx_range[1]
			WIDGET_CONTROL, rx_min, SET_VALUE = [rvx_min, get_val_range (rx_range)]
			WIDGET_CONTROL, rx_max, SET_VALUE = [rvx_max, get_val_range (rx_range)]
			WIDGET_CONTROL, rx_fr, SENSITIVE = 0
			R_DRAW_TS = 1
		end
		break
	end
	'R_Y': begin
		if (r_sy ne event.index) then begin
			r_sy = event.index
			ry_range = minmax (ts.(r_sy))
			rvy_min = ry_range[0]
			rvy_max = ry_range[1]
			WIDGET_CONTROL, ry_min, SET_VALUE = [rvy_min, get_val_range (ry_range)]
			WIDGET_CONTROL, ry_max, SET_VALUE = [rvy_max, get_val_range (ry_range)]
			R_DRAW_TS = 1
		end
		break
	end
	'STYLE': begin
		if (plot_style ne event.index) then begin
			plot_style = event.index
			L_DRAW_TS = 1
			R_DRAW_TS = 1
		end
		break
	end
	'RESET': begin
		; reset_ts_GUI
		break
	end
	'REFRESH': begin
		pc_read_ts, obj=ts, datadir=datadir, /quiet
		lx_range = minmax (ts.(l_sx))
		ly_range = minmax (ts.(l_sy))
		rx_range = minmax (ts.(r_sx))
		ry_range = minmax (ts.(r_sy))
		WIDGET_CONTROL, lx_min, SET_VALUE = [lvx_min, get_val_range (lx_range)]
		WIDGET_CONTROL, lx_max, SET_VALUE = [lvx_max, get_val_range (lx_range)]
		WIDGET_CONTROL, ly_min, SET_VALUE = [lvy_min, get_val_range (ly_range)]
		WIDGET_CONTROL, ly_max, SET_VALUE = [lvy_max, get_val_range (ly_range)]
		WIDGET_CONTROL, rx_min, SET_VALUE = [rvx_min, get_val_range (rx_range)]
		WIDGET_CONTROL, rx_max, SET_VALUE = [rvx_max, get_val_range (rx_range)]
		WIDGET_CONTROL, ry_min, SET_VALUE = [rvy_min, get_val_range (ry_range)]
		WIDGET_CONTROL, ry_max, SET_VALUE = [rvy_max, get_val_range (ry_range)]
		pc_show_ts_draw, 1, 1
		break
	end
	'L_COUPLE': begin
		WIDGET_CONTROL, lx_fr, set_value='<= RELEASE =>', set_uvalue='L_RELEASE'
		l_coupled = lvx_max - lvx_min
		break
	end
	'L_RELEASE': begin
		WIDGET_CONTROL, lx_fr, set_value='<= COUPLE =>', set_uvalue='L_COUPLE'
		l_coupled = -1
		break
	end
	'L_MINMAX': begin
		indices = where ((ts.(l_sx) ge lvx_min) and (ts.(l_sx) le lvx_max))
		if (indices[0] ge 0) then range = minmax ((ts.(l_sy))[indices]) else range = ly_range
		lvy_min = range[0]
		lvy_max = range[1]
		WIDGET_CONTROL, ly_min, SET_VALUE = [lvy_min, get_val_range (ly_range)]
		WIDGET_CONTROL, ly_max, SET_VALUE = [lvy_max, get_val_range (ly_range)]
		L_DRAW_TS = 1
		break
	end
	'R_COUPLE': begin
		WIDGET_CONTROL, rx_fr, set_value='<= RELEASE =>', set_uvalue='R_RELEASE'
		r_coupled = rvx_max - rvx_min
		break
	end
	'R_RELEASE': begin
		WIDGET_CONTROL, rx_fr, set_value='<= COUPLE =>', set_uvalue='R_COUPLE'
		r_coupled = -1
		break
	end
	'R_MINMAX': begin
		indices = where ((ts.(r_sx) ge rvx_min) and (ts.(r_sx) le rvx_max))
		if (indices[0] ge 0) then range = minmax ((ts.(r_sy))[indices]) else range = ry_range
		rvy_min = range[0]
		rvy_max = range[1]
		WIDGET_CONTROL, ry_min, SET_VALUE = [rvy_min,  get_val_range (ry_range)]
		WIDGET_CONTROL, ry_max, SET_VALUE = [rvy_max,  get_val_range (ry_range)]
		R_DRAW_TS = 1
		break
	end
	'QUIT': begin
		quit = event.top
		break
	end
	endswitch

	pc_show_ts_draw, L_DRAW_TS, R_DRAW_TS

	WIDGET_CONTROL, lx_fr, SENSITIVE = ((lvx_min gt lx_range[0]) or (lvx_max lt lx_range[1]))
	WIDGET_CONTROL, rx_fr, SENSITIVE = ((rvx_min gt rx_range[0]) or (rvx_max lt rx_range[1]))

	WIDGET_CONTROL, WIDGET_INFO (event.top, /CHILD)

	if (quit ge 0) then WIDGET_CONTROL, quit, /DESTROY

	return
end


; Draw the timeseries plots
pro pc_show_ts_draw, l_draw, r_draw

	common timeseries_common, time_start, time_end, ts, units, run_par, start_par, orig_dim, lvx_min, lvx_max, lvy_min, lvy_max, rvx_min, rvx_max, rvy_min, rvy_max, l_plot, r_plot, l_sx, l_sy, r_sx, r_sy, plot_style

	if (l_draw ne 0) then begin
		wset, l_plot
		xr = get_val_range ([lvx_min, lvx_max])
		yr = get_val_range ([lvy_min, lvy_max])
		if (plot_style le 2) then plot, ts.(l_sx), ts.(l_sy), xr=xr, yr=yr, /xs, ys=3
		if (plot_style eq 1) then oplot, ts.(l_sx), ts.(l_sy), psym=3, color=200
		if (plot_style eq 2) then oplot, ts.(l_sx), ts.(l_sy), psym=2, color=200
		if (plot_style eq 3) then plot, ts.(l_sx), ts.(l_sy), xr=xr, yr=yr, /xs, ys=3, psym=3
		if (plot_style eq 4) then plot, ts.(l_sx), ts.(l_sy), xr=xr, yr=yr, /xs, ys=3, psym=2
	end

	if (r_draw ne 0) then begin
		wset, r_plot
		xr = get_val_range ([rvx_min, rvx_max])
		yr = get_val_range ([rvy_min, rvy_max])
		if (plot_style le 2) then plot, ts.(r_sx), ts.(r_sy), xr=xr, yr=yr, /xs, ys=3
		if (plot_style eq 1) then oplot, ts.(r_sx), ts.(r_sy), psym=3, color=200
		if (plot_style eq 2) then oplot, ts.(r_sx), ts.(r_sy), psym=2, color=200
		if (plot_style eq 3) then plot, ts.(r_sx), ts.(r_sy), xr=xr, yr=yr, /xs, ys=3, psym=3
		if (plot_style eq 4) then plot, ts.(r_sx), ts.(r_sy), xr=xr, yr=yr, /xs, ys=3, psym=2
	end
end


; Analyze the timeseries plots
pro pc_show_ts_analyze

	common timeseries_common, time_start, time_end, ts, units, run_par, start_par, orig_dim, lvx_min, lvx_max, lvy_min, lvy_max, rvx_min, rvx_max, rvy_min, rvy_max, l_plot, r_plot, l_sx, l_sy, r_sx, r_sy, plot_style

	charsize = 1.25
	old_multi = !P.MULTI
	old_x_margin = !X.margin
	!X.margin[0] += 3
	x_margin_both = (!X.margin > max (old_x_margin))

	window, 11, xsize=1000, ysize=400, title='timestep analysis', retain=2
	!P.MULTI = [0, 2, 1]

	print, "starting values:"
	print, "dt    :", ts.dt[0]
	plot, ts.dt, title = 'dt', xc=charsize, yc=charsize, /yl

	if (has_tag (ts, 't')) then begin
		time = ts.t
	endif else begin
		time = ts.it
	endelse
	x_minmax = minmax (time > time_start)
	if (time_end gt 0) then x_minmax = minmax (x_minmax < time_end)
	y_minmax = minmax (ts.dt)
	if (has_tag (ts, 'dtu'))       then y_minmax = minmax ([y_minmax, ts.dtu])
	if (has_tag (ts, 'dtv'))       then y_minmax = minmax ([y_minmax, ts.dtv])
	if (has_tag (ts, 'dtnu'))      then y_minmax = minmax ([y_minmax, ts.dtnu])
	if (has_tag (ts, 'dtb'))       then y_minmax = minmax ([y_minmax, ts.dtb])
	if (has_tag (ts, 'dteta'))     then y_minmax = minmax ([y_minmax, ts.dteta])
	if (has_tag (ts, 'dtc'))       then y_minmax = minmax ([y_minmax, ts.dtc])
	if (has_tag (ts, 'dtchi'))     then y_minmax = minmax ([y_minmax, ts.dtchi])
	if (has_tag (ts, 'dtchi2'))    then y_minmax = minmax ([y_minmax, ts.dtchi2])
	if (has_tag (ts, 'dtspitzer')) then y_minmax = minmax ([y_minmax, ts.dtspitzer])
	if (has_tag (ts, 'dtd'))       then y_minmax = minmax ([y_minmax, ts.dtd])

	time *= units.time
	ts.dt *= units.time
	x_minmax *= units.time
	y_minmax *= units.time

	plot, time, ts.dt, title = 'dt(t) u{-t} v{-p} nu{.v} b{.r} eta{-g} c{.y} chi{-.b} chi2{-.o} d{-l} [s]', xrange=x_minmax, /xs, xc=charsize, yc=charsize, yrange=y_minmax, /yl
	if (has_tag (ts, 'dtu')) then begin
		oplot, time, ts.dtu*units.time, linestyle=2, color=11061000
		print, "dtu      :", ts.dtu[0]
	end
	if (has_tag (ts, 'dtv')) then begin
		oplot, time, ts.dtv*units.time, linestyle=2, color=128255200
		print, "dtv      :", ts.dtv[0]
	end
	if (has_tag (ts, 'dtnu')) then begin
		oplot, time, ts.dtnu*units.time, linestyle=1, color=128000128
		print, "dtnu     :", ts.dtnu[0]
	end
	if (has_tag (ts, 'dtb')) then begin
		oplot, time, ts.dtb*units.time, linestyle=1, color=200
		print, "dtb      :", ts.dtb[0]
	end
	if (has_tag (ts, 'dteta')) then begin
		oplot, time, ts.dteta*units.time, linestyle=2, color=220200200
		print, "dteta    :", ts.dteta[0]
	end
	if (has_tag (ts, 'dtc')) then begin
		oplot, time, ts.dtc*units.time, linestyle=1, color=61695
		print, "dtc      :", ts.dtc[0]
	end
	if (has_tag (ts, 'dtchi')) then begin
		oplot, time, ts.dtchi*units.time, linestyle=3, color=115100200
		print, "dtchi    :", ts.dtchi[0]
	end
	if (has_tag (ts, 'dtchi2')) then begin
		oplot, time, ts.dtchi2*units.time, linestyle=3, color=41215
		print, "dtchi2   :", ts.dtchi2[0]
	end
	if (has_tag (ts, 'dtspitzer')) then begin
		oplot, time, ts.dtspitzer*units.time, linestyle=3, color=41215000
		print, "dtspitzer:", ts.dtspitzer[0]
	end
	if (has_tag (ts, 'dtd')) then begin
		oplot, time, ts.dtd*units.time, linestyle=2, color=16737000
		print, "dtc      :", ts.dtd[0]
	end

	window, 12, xsize=1000, ysize=800, title='time series analysis', retain=2
	multi_x = 2
	multi_y = 2
	!P.MULTI = [0, multi_x, multi_y, 0, 0]

	max_subplots = 4
	num_subplots = 0

	N_grid = orig_dim.nx * orig_dim.ny * orig_dim.nz
	volume = start_par.Lxyz[0] * start_par.Lxyz[1] * start_par.Lxyz[2]

	if (has_tag (ts, 'eem') and has_tag (ts, 'ekintot') and has_tag (ts, 'ethm') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		energy_int = (ts.eem*N_grid + ts.ekintot) * units.mass * units.velocity^2
		energy_therm = (ts.ethm + ts.ekintot/volume) * units.mass * units.velocity^2 / units.length^3
		plot, time, energy_int, title = 'Total energy {w} and E/V {r} conservation', xrange=x_minmax, /xs, xmar=x_margin_both, xc=charsize, yc=charsize, ytitle='E_total [J]', ys=10, /noerase
		plot, time, energy_therm, color=200, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, ys=6, /noerase
		axis, xc=charsize, yc=charsize, yaxis=1, yrange=!Y.CRANGE, /ys, ytitle='<E/V> [J/m^3]'
		plot, time, energy_int, linestyle=2, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, ys=6, /noerase
		!P.MULTI = [max_subplots-num_subplots, multi_x, multi_y, 0, 0]
	end else if (has_tag (ts, 'eem') and has_tag (ts, 'ekintot') and has_tag (ts, 'totmass') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		mass = ts.totmass * units.mass / units.default_mass
		energy = (ts.eem*N_grid + ts.ekintot) / ts.totmass * units.velocity^2
		plot, time, energy, title = 'Energy {w} and mass {r} conservation', xrange=x_minmax, /xs, xmar=x_margin_both, xc=charsize, yc=charsize, ytitle='<E/M> [J/kg]', ys=10, /noerase
		plot, time, mass, color=200, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, ys=6, /noerase
		axis, xc=charsize, yc=charsize, yaxis=1, yrange=!Y.CRANGE, /ys, ytitle='total mass ['+units.default_mass_str+']'
		plot, time, energy, linestyle=2, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, ys=6, /noerase
		!P.MULTI = [max_subplots-num_subplots, multi_x, multi_y, 0, 0]
	end else if (has_tag (ts, 'eem') and has_tag (ts, 'ekintot') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		energy = (ts.eem*N + ts.ekintot) * units.mass * units.velocity^2
		plot, time, energy, title = 'Energy conservation', xrange=x_minmax, /xs, xc=charsize, yc=charsize, ytitle='<E> [J]'
	end else if (has_tag (ts, 'ethm') and has_tag (ts, 'ekintot') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		energy = (ts.ethm + ts.ekintot/volume) * units.mass * units.velocity^2 / units.length^3
		plot, time, energy, title = 'Energy conservation', xrange=x_minmax, /xs, xc=charsize, yc=charsize, ytitle='<E/V> [J/m^3]'
	end
	if (has_tag (ts, 'TTmax') and has_tag (ts, 'rhomin') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		Temp_max = ts.TTmax * units.temperature
		rho_min = ts.rhomin * units.density / units.default_density
		plot, time, Temp_max, title = 'Maximum temperature {w} and minimum density {.r}', xrange=x_minmax, /xs, xmar=x_margin_both, xc=charsize, yc=charsize, ytitle='maximum temperature [K]', /yl, ys=10, /noerase
		plot, time, rho_min, color=200, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		axis, xc=charsize, yc=charsize, yaxis=1, yrange=10.^(!Y.CRANGE), /ys, /yl, ytitle='minimum density ['+units.default_density_str+']'
		plot, time, Temp_max, linestyle=2, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		!P.MULTI = [max_subplots-num_subplots, multi_x, multi_y, 0, 0]
	end else if (has_tag (ts, 'TTm') and has_tag (ts, 'rhomin') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		Temp_mean = ts.TTm * units.temperature
		rho_min = ts.rhomin * units.density / units.default_density
		plot, time, Temp_mean, title = 'Mean temperature {w} and minimum density {.r}', xrange=x_minmax, /xs, xmar=x_margin_both, xc=charsize, yc=charsize, ytitle='<T> [K]', /yl, ys=10, /noerase
		plot, time, rho_min, color=200, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		axis, xc=charsize, yc=charsize, yaxis=1, yrange=10.^(!Y.CRANGE), /ys, /yl, ytitle='minimum density ['+units.default_density_str+']'
		plot, time, Temp_mean, linestyle=2, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		!P.MULTI = [max_subplots-num_subplots, multi_x, multi_y, 0, 0]
	end else if (has_tag (ts, 'TTm') and has_tag (ts, 'TTmax') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		Temp_max = ts.TTmax * units.temperature
		Temp_mean = ts.TTm * units.temperature
		yrange = [ min (Temp_mean), max (Temp_max) ]
		plot, time, Temp_max, title = 'Maximum temperature {w} and mean temperature {.r}', xrange=x_minmax, /xs, xc=charsize, yc=charsize, ytitle='maximum and mean temperature [K]', yrange=yrange, /yl
		oplot, time, Temp_mean, color=200
		oplot, time, Temp_max, linestyle=2
	end else if (has_tag (ts, 'TTmax') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		Temp_max = ts.TTmax * units.temperature
		plot, time, Temp_max, title = 'Maximum temperature [K]', xrange=x_minmax, /xs, xc=charsize, yc=charsize, /yl
	end else if (has_tag (ts, 'TTm') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		Temp_mean = ts.TTm * units.temperature
		plot, time, Temp_mean, title = 'Mean temperature [K]', xrange=x_minmax, /xs, xc=charsize, yc=charsize, /yl
	end else if (has_tag (ts, 'rhomin') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		rho_min = ts.rhomin * units.density / units.default_density
		plot, time, rho_min, title = 'rho_min(t) ['+units.default_density_str+']', xrange=x_minmax, /xs, xc=charsize, yc=charsize, /yl
	end
	if (has_tag (ts, 'j2m') and has_tag (ts, 'visc_heatm') and has_tag (run_par, "eta") and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		HR_ohm = run_par.eta * start_par.mu0 * ts.j2m * units.density * units.velocity^3 / units.length
		visc_heat_mean = ts.visc_heatm * units.density * units.velocity^3 / units.length
		yrange = [ min ([HR_ohm, visc_heat_mean]), max ([HR_ohm, visc_heat_mean]) ]
		plot, time, HR_ohm, title = 'Mean Ohmic heating rate {w} and viscous heating rate {.r}', xrange=x_minmax, /xs, xc=charsize, yc=charsize, ytitle='heating rates [W/m^3]', yrange=yrange, /yl
		oplot, time, visc_heat_mean, color=200
		oplot, time, HR_ohm, linestyle=2
	end else if (has_tag (ts, 'j2m') and has_tag (run_par, "eta") and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		mu0_SI = 4.0 * !Pi * 1.e-7
		HR_ohm = run_par.eta * start_par.mu0 * ts.j2m * units.density * units.velocity^3 / units.length
		j_abs = sqrt (ts.j2m) * units.velocity * sqrt (start_par.mu0 / mu0_SI * units.density) / units.length
		plot, time, HR_ohm, title = 'Mean Ohmic heating rate {w} and mean current density {.r}', xrange=x_minmax, /xs, xmar=x_margin_both, xc=charsize, yc=charsize, ytitle='HR = <eta*mu0*j^2> [W/m^3]', /yl, ys=10, /noerase
		plot, time, j_abs, color=200, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		axis, xc=charsize, yc=charsize, yaxis=1, yrange=10.^(!Y.CRANGE), /ys, /yl, ytitle='sqrt(<j^2>) [A/m^2]'
		plot, time, HR_ohm, linestyle=2, xrange=x_minmax, xs=5, xmar=x_margin_both, xc=charsize, yc=charsize, /yl, ys=6, /noerase
		!P.MULTI = [max_subplots-num_subplots, multi_x, multi_y, 0, 0]
	end else if (has_tag (ts, 'visc_heatm') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		visc_heat_mean = ts.visc_heatm * units.density * units.velocity^3 / units.length
		plot, time, visc_heat_mean, title = 'Mean viscous heating rate', xrange=x_minmax, /xs, xc=charsize, yc=charsize, ytitle='heating rate [W/m^3]', /yl
	end
	if (has_tag (ts, 'umax') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		u_max = ts.umax * units.velocity / units.default_velocity
		u_title = 'u_max(t){w}'
		if (has_tag (ts, 'urms')) then begin
			u_title += ' u_rms{.r}'
		end else if (has_tag (ts, 'u2m')) then begin
			u_title += ' sqrt(<u^2>){.-b}'
		end
		plot, time, u_max, title = u_title+' ['+units.default_velocity_str+']', xrange=x_minmax, /xs, xc=charsize, yc=charsize
		if (has_tag (ts, 'urms')) then begin
			urms = ts.urms * units.velocity / units.default_velocity
			oplot, time, urms, linestyle=1, color=200
		end else if (has_tag (ts, 'u2m')) then begin
			u2m = sqrt (ts.u2m) * units.velocity / units.default_velocity
			oplot, time, u2m, linestyle=3, color=115100200
		end
	end
	if (has_tag (ts, 'totmass') and (num_subplots lt max_subplots)) then begin
		num_subplots += 1
		mass = ts.totmass * units.mass / units.default_mass
		plot, time, mass, title = 'Mass conservation', xrange=x_minmax, /xs, xc=charsize, yc=charsize
	end

	skip_ts = 2
	tags = tag_names (ts)
	num_tags = n_elements (tags)
	while ((num_subplots lt max_subplots) and (skip_ts+1 lt num_tags)) do begin
		num_subplots += 1
		skip_ts += 1
		plot, time, ts.(skip_ts), title = tags[skip_ts], xrange=x_minmax, /xs, xc=charsize, yc=charsize
	end

	!X.margin = old_x_margin
	!P.MULTI = old_multi
end


; Show timeseries analysis window
pro pc_show_ts, object=time_series, unit=unit, start_param=start_param, run_param=run_param, start_time=start_time, end_time=end_time, datadir=datadir

	common timeseries_common, time_start, time_end, ts, units, run_par, start_par, orig_dim, lvx_min, lvx_max, lvy_min, lvy_max, rvx_min, rvx_max, rvy_min, rvy_max, l_plot, r_plot, l_sx, l_sy, r_sx, r_sy, plot_style
	common timeseries_gui_common, l_x, l_y, r_x, r_y, lx_min, lx_max, ly_min, ly_max, rx_min, rx_max, ry_min, ry_max, lx_fr, rx_fr, l_coupled, r_coupled, lx_range, ly_range, rx_range, ry_range, s_line

	; GUI settings
	@pc_gui_settings
	col_width = 220
	plot_width = 2 * col_width
	plot_height = plot_width
	sl_width = col_width - 52

	datadir = pc_get_datadir(datadir)
	pc_read_dim, obj=orig_dim, datadir=datadir, /quiet
	if (not keyword_set (unit)) then pc_units, obj=unit, datadir=datadir, param=start_param, dim=orig_dim, /quiet
	if (not has_tag (unit, "default_length")) then unit = create_struct (unit, display_units)
	units = unit

	if (keyword_set (time_series)) then ts = time_series
	if (n_elements (ts) le 0) then pc_read_ts, obj=ts, datadir=datadir, /quiet
	time_series = ts

	if (not keyword_set (start_param)) then pc_read_param, obj=start_param, datadir=datadir, /quiet
	if (not keyword_set (run_param)) then pc_read_param, obj=run_param, datadir=datadir, /param2, /quiet
	if (not keyword_set (start_time)) then start_time = min (ts.t) * unit.time
	if (not keyword_set (end_time)) then end_time = max (ts.t) * unit.time

	time_start = start_time
	time_end = end_time
	run_par = run_param
	start_par = start_param

	plots = tag_names (ts)
	num_plots = n_elements (plots)

	; Usually, the first column (0) is 'it', the second (1) is 't', and additional quantities follow (2, ...):
	l_sx = 1
	l_sy = 2 < (num_plots-1)
	r_sx = 1 < (num_plots-1)
	r_sy = 3 < (num_plots-1)
	lx_range = float (minmax (ts.(l_sx)))
	ly_range = float (minmax (ts.(l_sy)))
	rx_range = float (minmax (ts.(r_sx)))
	ry_range = float (minmax (ts.(r_sy)))
	lvx_min = lx_range[0]
	lvx_max = lx_range[1]
	lvy_min = ly_range[0]
	lvy_max = ly_range[1]
	rvx_min = rx_range[0]
	rvx_max = rx_range[1]
	rvy_min = ry_range[0]
	rvy_max = ry_range[1]
	l_coupled = -1
	r_coupled = -1
	plot_style = 0

	MOTHER	= WIDGET_BASE (title='PC timeseries analysis')
	APP	= WIDGET_BASE (MOTHER, /col)

	BASE	= WIDGET_BASE (APP, /row)

	tmp	= WIDGET_BASE (BASE, /row)
	BUT	= WIDGET_BASE (tmp, /col)
	L_X	= WIDGET_DROPLIST (BUT, xsize=plot_width-60, value=plots, uvalue='L_X', title='LEFT plot:')
	L_Y	= WIDGET_LIST (BUT, value=plots, uvalue='L_Y', ysize=(num_plots<12)>4); , /multiple
	WIDGET_CONTROL, L_X, SET_DROPLIST_SELECT = l_sx
	WIDGET_CONTROL, L_Y, SET_LIST_SELECT = l_sy

	CTRL	= WIDGET_BASE (BASE, /col)
	BUT	= WIDGET_BASE (CTRL, /col, frame=1, /align_center)
	tmp	= WIDGET_BUTTON (BUT, xsize=100, value='RESET', uvalue='RESET', sensitive=0)
	tmp	= WIDGET_BUTTON (BUT, xsize=100, value='REFRESH', uvalue='REFRESH')
	tmp	= WIDGET_BUTTON (BUT, xsize=100, value='ANALYZE', uvalue='ANALYZE')
	tmp	= WIDGET_BUTTON (BUT, xsize=100, value='QUIT', uvalue='QUIT')
	BUT	= WIDGET_BASE (CTRL, /col, /align_center)
	tmp	= WIDGET_LABEL (CTRL, value='plotting style:', frame=0)
	tmp	= WIDGET_DROPLIST (CTRL, value=['line', 'line+dots', 'line+stars', 'dots', 'stars'], uvalue='STYLE')
	WIDGET_CONTROL, tmp, SET_DROPLIST_SELECT = plot_style

	tmp	= WIDGET_BASE (BASE, /row)
	BUT	= WIDGET_BASE (tmp, /col)
	R_X	= WIDGET_DROPLIST (BUT, xsize=plot_width-60, value=plots, uvalue='R_X', title='RIGHT plot:')
	R_Y	= WIDGET_LIST (BUT, value=plots, uvalue='R_Y', ysize=(num_plots<12)>4) ; , /multiple
	WIDGET_CONTROL, R_X, SET_DROPLIST_SELECT = r_sx
	WIDGET_CONTROL, R_Y, SET_LIST_SELECT = r_sy

	BASE	= WIDGET_BASE (APP, /row)

	PLOTS	= WIDGET_BASE (BASE, /col)
	tmp	= WIDGET_BASE (PLOTS, /row)
	dplot_l	= WIDGET_DRAW (tmp, xsize=plot_width, ysize=plot_height, retain=2)

	range = get_val_range (lx_range)
	BUT	= WIDGET_BASE (PLOTS, /row)
	lx_min	= CW_FSLIDER (BUT, xsize=sl_width, title='minimum value', uvalue='LX_MIN', /double, /edit, min=range[0], max=range[1], drag=1, value=lvx_min)
	CTRL	= WIDGET_BASE (BUT, /col, frame=0)
	tmp	= WIDGET_LABEL (CTRL, value='X-axis:')
	lx_fr	= WIDGET_BUTTON (CTRL, value='<= COUPLE =>', uvalue='L_COUPLE', sensitive=0)
	lx_max	= CW_FSLIDER (BUT, xsize=sl_width, title='maximum value', uvalue='LX_MAX', /double, /edit, min=range[0], max=range[1], drag=1, value=lvx_max)

	range = get_val_range (ly_range)
	BUT	= WIDGET_BASE (PLOTS, /row)
	ly_min	= CW_FSLIDER (BUT, xsize=sl_width, uvalue='LY_MIN', /double, /edit, min=range[0], max=range[1], drag=1, value=lvy_min)
	CTRL	= WIDGET_BASE (BUT, /col, frame=0)
	tmp	= WIDGET_LABEL (CTRL, value='Y-axis:')
	tmp	= WIDGET_BUTTON (CTRL, value='<= MINMAX =>', uvalue='L_MINMAX')
	ly_max	= CW_FSLIDER (BUT, xsize=sl_width, uvalue='LY_MAX', /double, /edit, min=range[0], max=range[1], drag=1, value=lvy_max)

	PLOTS	= WIDGET_BASE (BASE, /col)
	tmp	= WIDGET_BASE (PLOTS, /row)
	dplot_r	= WIDGET_DRAW (tmp, xsize=plot_width, ysize=plot_height, retain=2)

	range = get_val_range (rx_range)
	BUT	= WIDGET_BASE (PLOTS, /row)
	rx_min	= CW_FSLIDER (BUT, xsize=sl_width, title='minimum value', uvalue='RX_MIN', /double, /edit, min=range[0], max=range[1], drag=1, value=rvx_min)
	CTRL	= WIDGET_BASE (BUT, /col)
	tmp	= WIDGET_LABEL (CTRL, value='X-axis:')
	rx_fr	= WIDGET_BUTTON (CTRL, value='<= COUPLE =>', uvalue='R_COUPLE', sensitive=0)
	rx_max	= CW_FSLIDER (BUT, xsize=sl_width, title='maximum value', uvalue='RX_MAX', /double, /edit, min=range[0], max=range[1], drag=1, value=rvx_max)

	range = get_val_range (ry_range)
	BUT	= WIDGET_BASE (PLOTS, /row)
	ry_min	= CW_FSLIDER (BUT, xsize=sl_width, uvalue='RY_MIN', /double, /edit, min=range[0], max=range[1], drag=1, value=rvy_min)
	CTRL	= WIDGET_BASE (BUT, /col)
	tmp	= WIDGET_LABEL (CTRL, value='Y-axis:')
	tmp	= WIDGET_BUTTON (CTRL, value='<= MINMAX =>', uvalue='R_MINMAX')
	ry_max	= CW_FSLIDER (BUT, xsize=sl_width, uvalue='RY_MAX', /double, /edit, min=range[0], max=range[1], drag=1, value=rvy_max)

	BASE	= WIDGET_BASE (APP, /row)


	WIDGET_CONTROL, MOTHER, /REALIZE
	WIDGET_CONTROL, dplot_l, GET_VALUE = l_plot
	WIDGET_CONTROL, dplot_r, GET_VALUE = r_plot

	WIDGET_CONTROL, BASE

	XMANAGER, "pc_show_ts", MOTHER, /no_block

	pc_show_ts_draw, 1, 1

end


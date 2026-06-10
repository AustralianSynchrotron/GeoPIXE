pro get_mca, p, file

;	Read a NSLS MCA soectrum file

ErrorNo = 0
common c_errors_1, catch_errors_on
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'Get_mca',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!Error_state.msg,'',c], /error
		MESSAGE, /RESET
		goto, finish
	endif
endif
common c_null_spec_1, max_history, max_cal,  max_fit
max_history = 32
max_cal = 8
max_fit = 6

	obj = obj_new('NSLS_MCA_DEVICE')
	if obj_valid(obj) eq 0 then goto, finish

	p = ptr_new()

	if n_elements(med) lt 1 then med = obj_new('MED',16)			;9)
	if obj_valid(med) eq 0 then med = obj_new('MED',16)				;9)

	med->read_file, file

;	The variable data is the counts in each mca channel, so an array
;	2048 x number of detector elements. In our case [2048,9].
	data = med->get_data()

;	the variable energy is the energy of each mca channel in keV, again an array 2048 x number of detector elements.
    energy = med->get_energy()

;	Environment variables are stored in the header of each spectrum file.
	environment = med->get_environment()

;	I0, x_value, and y_value pull out the ion chamber counts,
;	position of the x stage motor (in mm's),
;	and y stage motor from the saved environment variables.

	I0 = environment[0].value
	x_value = 0.0
	y_value = 0.0
	z_value = 0.0

if n_elements(environment) ge 5 then begin
;	ring_current = environment[1].value
	x_value = environment[2].value
	y_value = environment[3].value
	z_value = environment[4].value
;	mono_theta = environment[5].value
;	mono_E = environment[6].value
endif

	sz = n_elements(data[*,0])
	n = n_elements(data[0,*])
	cal = {order:1, units:'keV', poly:fltarr(max_cal)}
	found = 0

	for i=0L,n-1 do begin
		spec = define(/spectrum)
		spec.file = file
		spec.DevObj = clone_device_object(obj)
		spec.x = float(x_value)
		spec.y = float(y_value)
		spec.z = float(z_value)
		spec.charge = float(I0)
		spec.source = file
		spec.label = file
		spec.size = sz
		spec.data = ptr_new(data[*,i])
		spec.station = i+1
		spec.log = 1

		cb = energy[0,i]
		ca = energy[1,i] - cb
		cal.poly[0:1] = [cb,ca]
		spec.cal = cal

		if found eq 0 then begin
			p = ptr_new( spec, /no_copy)
		endif else begin
			p = [ p, ptr_new(spec, /no_copy)]
		endelse
		found = 1
	endfor

finish:
	if n_elements(med) gt 1 then if obj_valid(med) then obj_destroy, med
	return

end

function BauerSNIP_back_plugin, pspec, elow, ehigh, passes=passesi, filters=filters, detector=detectori, $
		boost=boost, curve=curve, yields=yields, title=title

;	Combined max of SNIP & Bauer backgrounds:
;	
;	Bauer background used in AES
;	(H.E. Bauer, "A fast and simple method for background removal in Auger electron spectroscopy",
;	 Fresenius J Anal Chem 353 (1995) 450-455)
;	
;	SNIP background algorithm used in PIXE, SXRF
;	(C.G. Ryan et al., "SNIP, a Statistics Sensitive Background Treatment for the Quantitative 
;	 Analysis of PIXE Spectra in Geoscience Applications" Nucl. Instr. and Meth. B34 (1988) 396-402)
;
;	pspec				pointer to spectrum structure (see DEFINE.pro)
;	elow				low energy marker
;	ehigh				high energy
;	passes				number of passes (in this case used to scale the sampling width parameter Delta)
;	filters				filters to use with Boost
;	yields				structure contains sample composition for self-absorption correction
;	detector			detector struct, use with Boost
;	title				just return title text
;	boost				=1 switches on Boost mode
;	curve				optional curvature parameter (not used in Bauer, only in SNIP)

COMPILE_OPT STRICTARR

if arg_present(title) then begin
	title = 'Bauer & SNIP'								; return the menu title for this plugin
	return, 0L
endif

	if n_elements(detectori) lt 1 then detectori=0
	detector = detectori[0]
	if size(detector,/tname) eq 'POINTER' then begin
		if ptr_valid(detector) then detector = (*detector)[0]
	endif
	if size(detector,/tname) eq 'STRUCT' then begin
		if n_elements(w1) lt 1 then w1 = detector.w1
		if n_elements(w0) lt 1 then w0 = detector.w0
	endif else begin
		if n_elements(w1) lt 1 then w1 = 0.003
		if n_elements(w0) lt 1 then w0 = (0.16)*(0.16) - w1*5.895
		detector = 0
	endelse
	if n_elements(filters) lt 1 then filters=0
	if n_elements(yields) lt 1 then yields=0
	if n_elements(passesi) lt 1 then passesi = 8
	if n_elements(def_passes) lt 1 then def_passes = 2*passesi
	if n_elements(curve) lt 1 then curve = 1.0003
	if n_elements(hybrid) lt 1 then hybrid=1
	if n_elements(boost) lt 1 then boost=0

	elow = elow > 0.15							; 0.15 keV minimum (also in pixe_fit)
	passes = passesi
	if boost then passes = passes/2

	sample_width_scaling = 2.0					; Clip FWHM scaling width
	n_wiggles_trim = 4							; Reduce wiggles as last pass

	if ptr_valid(pspec) eq 0 then goto, bad_ptr
	cal_a = (*pspec).cal.poly[1]
	cal_b = (*pspec).cal.poly[0]
	ehigh = ehigh > (elow+2.0)
	
	;	Use passes to scale the FWHM sampling width.
	;	Normally passes=8, so w is 24*FWHM @ mid energy
	
	wm = sqrt( w0 + w1*(4*elow+ehigh)/5)/cal_a				; middle FWHM
	w = passes * wm / 20.
	
	spec = *(*pspec).data
	n = n_elements(spec)
	t = reform(float(spec))
	low = (elow-cal_b)/cal_a > 1
	high = (ehigh-cal_b)/cal_a < n-2
	if (n lt 50) or (high lt low+50) then goto, bad_exit
	
	n_trans = (e_inflection(filters) - cal_b)/cal_a
	if hybrid then begin
		n_trans_low = fix(0.8 * n_trans) > low
		n_trans_high = fix(1.2 * n_trans) < high
	endif
	n_curve = n_trans

;	Veto ends, if there are only zero channels

	veto_ends, t, low, high, error=error		; move low, high if zero channels
	if error then goto, spec_gone				; low, high MUST remain fixed from here ...
	
;	Apply 'low stats' filter first ...

	AF = (w1 * cal_a) / (cal_a*cal_a)			; FWHM**2 (channels)
	BF = (w0 + w1 * cal_b) / (cal_a*cal_a)
;	t1 = median(t, wm/4 > 2)
	t1 = t
	err = low_stats_filter( t1,t, n_elements(t), low,high, AF,BF)

;	t = median(t, wm/4 > 2)						; clip any remaining single spikes
	t0 = t

;	Extend the ends to a constant at high, and a ramp at low energy

	extend_ends, t, low, high, error=error, boost=boost
	if error then goto, spec_gone

;	BOOST out (if /boost, remove effects of filters, matrix optional, detector always)

	t = boost_back( t, low, high, cal_a, cal_b, detector, filters, yields, $
						/out, boost=boost, factor=trans)

	x = low + indgen(high-low+1)
	back = t

;----------------------------------------------------------------------------------------
;	Do your custom background algorithm here ...
;	t --> back
;
;	Bauer first ...

	s = t[x]
	e = cal_a * x + cal_b
	n = n_elements(x)
	s0 = s
	
;	Bauer end treatment first ...

	s = s - min(s)
	q = where( s le 0.5, nq)									; low side
	if (q[0] eq 1) then begin
		s[0] = 0.0
	endif else if (q[0] ge 2) then begin
		k = q[0]
		alpha = max( alog(s[1:k-1]/s[0]) / alog((e[k]-e[1:k-1])/(e[k]-e[0])) ) > 0.0
		s[0:k-1] = s[0:k-1] - s[0] * ((e[k]-e[0:k-1])/(e[k]-e[0]))^alpha
	endif

	q = reverse(q)												; high side
	if (q[0] eq n-2) then begin
		s[n-1] = 0.0
	endif else if (q[0] le n-3) then begin
		k = q[0]
		alpha = max( alog(s[k+1:n-2]/s[n-1]) / alog((e[k+1:n-2]-e[k])/(e[n-1]-e[k])) ) > 0.0
		s[k+1:n-1] = s[k+1:n-1] - s[n-1] * ((e[k+1:n-1]-e[k])/(e[n-1]-e[k]))^alpha
	endif
	
;	Bauer quadratic maximum 'under envelope' ...
;	The result is just the peaks, with the background stripped off iteratively.

	repeat begin
		jump = 0
		q = where( s le 0.5, nq)								; spectrum zeroes between peaks
		l = 0
		repeat begin
			m = l+1
			if e[q[m]] - e[q[l]] gt w then begin
				jump = 1
				A = min( s[q[l]+1:q[m]-1]/((e[q[l]+1:q[m]-1]-e[q[l]])*(e[q[m]]-e[q[l]+1:q[m]-1])) )
				s[q[l]+1:q[m]-1] = s[q[l]+1:q[m]-1] - A * (e[q[l]+1:q[m]-1] - e[q[l]]) * (e[q[m]]-e[q[l]+1:q[m]-1])  
			endif
			l = m
		endrep until l ge nq-1
	endrep until jump eq 0
	
	back[x] = s0 - s											; form back from this bare peaks spectrum
 
 ;	BOOST in (restore absorption of filters, matrix, detector)

	back[x] = back[x] * trans[x]
	
;.....................................................................................
 
 ;	Next SNIP ...
;	t --> back
 
 	t = alog( (alog((t>0.0D0) + 1.0D0) > 0.0D0) + 1.0D0)

;	Do the main strips ...

	if hybrid then begin
		if n_trans_high gt low+50 then begin
			simple_strip, t, low, n_trans_high, cal_a, cal_b, w0, w1, curve, $
					sample_width_scaling, passes, n_curve
		endif
		if high gt n_trans_low+50 then begin
			simple_strip, t, n_trans_low, high, cal_a, cal_b, w0, w1, curve, $
					sample_width_scaling, def_passes, n_curve
		endif
	endif else begin
		simple_strip, t, low, high, cal_a, cal_b, w0, w1, curve, $
				sample_width_scaling, passes, n_curve
	endelse

;	More strips with decreasing widths to reduce wiggles

	nm = 4
	if n_wiggles_trim lt 1 then nm=2
	wiggle_passes = (n_wiggles_trim+1)/4 > 1

	r = 1.0
	for i=0,nm-1 do begin
		simple_strip, t, low, high, cal_a, cal_b, w0, w1, 1.0, $
				r*sample_width_scaling, wiggle_passes, 0
		r = 0.7*r
	endfor

skip:

;	Transform back from log-log space

	back2 = float( exp( exp(t) -1.0D0) - 1.0D0 ) > 0.1
 
;	BOOST in (filters optional, matrix later, detector always)

	back2 = back2 * trans

;.......................................................................................
;	Do 2nd pass in boost mode as a ratio to first iteration

;	warning,'strip_back','boost ...'		; debug
	if boost then begin
		back2 = un_back( t0, back2, low, high, /out, factor=uback)

		simple_strip, back2, low, high, cal_a, cal_b, w0, w1, curve, $
				sample_width_scaling, passes, n_curve

		nm = 4
		if n_wiggles_trim lt 1 then nm=2
		wiggle_passes = (n_wiggles_trim+1)/4 > 1

		r = 1.0
		for i=0L,nm-1 do begin
			simple_strip, back2, low, high, cal_a, cal_b, w0, w1, 1.0, $
					r*sample_width_scaling, wiggle_passes, 0
			r = 0.7*r
		endfor

		back2[x] = back2[x] * uback
	endif
 
 	back = back > back2						; take max envelope of Bauer and SNIP
 	
;------------------------------------------------------------------------------------------
	
	back[0:low-1] = back[low]
	back[high+1:*] = back[high]
	q = where( finite(back) eq 0)
	if q[0] ne -1 then back[q]=0.0
	back = median(back, wm > 2)
	back[0:low-2] = 0.0
	back[high+2:*] = 0.0

;.....................................................................................
;	Put it in a fit overlay ...
;	This assumes that 'back' and 'spec' have the same energy calibration.

	fit = define(/spectrum)
	fit.source = (*pspec).source
	fit.label = 'BauerSNIP Back'
	fit.cal.poly[0] = cal_b
	fit.cal.poly[1] = cal_a
	fit.cal.units = (*pspec).cal.units
	fit.cal.order = 1
	fit.comment = 'BauerSNIP Back - background algorithm'

	fit.size = n_elements(back)
	fit.data = ptr_new( back, /no_copy)

	return, ptr_new( fit, /no_copy)

bad_ptr:
	warning, 'BauerSNIP_back_plugin', 'bad spectrum pointer'
	goto, bad_exit
spec_gone:
	warning, 'BauerSNIP_back_plugin', ['Null spectrum, or','bad or missing energy calibration.']
	goto, bad_exit

bad_exit:
	return, ptr_new()
	end

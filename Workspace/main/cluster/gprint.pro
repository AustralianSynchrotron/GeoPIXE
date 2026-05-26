pro gprintf, lun, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19,m20, $
			_extra=extra

	gprint, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19,m20, $
			output=lun, _extra=extra
	return
end

;-------------------------------------------------------------------------------------------

pro gprint, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19,m20, $
			output=out, active=active, level=level, _extra=extra

; Print or printf to 'out'
; 'out'		is unit to use. If out=0, then try common block default unit
;			'default_gprint_unit'. If it's zero, then fall back to print.
; 'active'	enable or disable gprint using this flag.
;			set to active=2 normally, =1 for the most detailed diagnostics, =0 disable
; 'level'	level of diagnostic detail. Ignore/skip is 'level' lt current 'active'. 

COMPILE_OPT STRICTARR
ErrorNo = 0
common c_errors_1, catch_errors_on
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
;		help, calls = s
;		n = n_elements(s)
;		c = 'Call stack: '
;		if n gt 2 then c = [c, s[1:n-2]]
;		warning,'gprint',['IDL run-time error caught.', '', $
;				'Error:  '+strtrim(!error_state.name,2), $
;				!Error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

common c_debug_print1, default_gprint_unit, gprint_active
if n_elements(default_gprint_unit) lt 1 then default_gprint_unit=-1	; stdout
if n_elements(gprint_active) lt 1 then gprint_active=2
if n_elements(active) eq 1 then begin
	gprint_active = active
	return
endif
if gprint_active eq 0 then return
if n_elements(level) lt 1 then level=2
if level lt gprint_active then return

narg = 0
if n_elements(m1) ge 1 then narg++
if n_elements(m2) ge 1 then narg++
if n_elements(m3) ge 1 then narg++
if n_elements(m4) ge 1 then narg++
if n_elements(m5) ge 1 then narg++
if n_elements(m6) ge 1 then narg++
if n_elements(m7) ge 1 then narg++
if n_elements(m8) ge 1 then narg++
if n_elements(m9) ge 1 then narg++
if n_elements(m10) ge 1 then narg++
if n_elements(m11) ge 1 then narg++
if n_elements(m12) ge 1 then narg++
if n_elements(m13) ge 1 then narg++
if n_elements(m14) ge 1 then narg++
if n_elements(m15) ge 1 then narg++
if n_elements(m16) ge 1 then narg++
if n_elements(m17) ge 1 then narg++
if n_elements(m18) ge 1 then narg++
if n_elements(m19) ge 1 then narg++
if n_elements(m20) ge 1 then narg++

if n_elements(out) lt 1 then out = default_gprint_unit
if out le 0 then goto, do_print
default_gprint_unit = out

;		1: printf, out,  _extra=extra, '$> ', m1	; add this prefix to be able to see lines in log file from here.

	case narg of
		0: printf, out,  _extra=extra
		1: printf, out,  _extra=extra, m1
		2: printf, out,  _extra=extra, m1,m2
		3: printf, out,  _extra=extra, m1,m2,m3
		4: printf, out,  _extra=extra, m1,m2,m3,m4
		5: printf, out,  _extra=extra, m1,m2,m3,m4,m5
		6: printf, out,  _extra=extra, m1,m2,m3,m4,m5,m6
		7: printf, out,  _extra=extra, m1,m2,m3,m4,m5,m6,m7
		8: printf, out,  _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8
		9: printf, out,  _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9
		10: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10
		11: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11
		12: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12
		13: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13
		14: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14
		15: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15
		16: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16
		17: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17
		18: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18
		19: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19
		20: printf, out, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19,m20
		else: 
	endcase
	flush, out
	return

;		1: print,  _extra=extra, '#> ', m1	; add this prefix to be able to see lines in log file from here.
	
do_print:
	case narg of
		0: print,  _extra=extra
		1: print,  _extra=extra, m1
		2: print,  _extra=extra, m1,m2
		3: print,  _extra=extra, m1,m2,m3
		4: print,  _extra=extra, m1,m2,m3,m4
		5: print,  _extra=extra, m1,m2,m3,m4,m5
		6: print,  _extra=extra, m1,m2,m3,m4,m5,m6
		7: print,  _extra=extra, m1,m2,m3,m4,m5,m6,m7
		8: print,  _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8
		9: print,  _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9
		10: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10
		11: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11
		12: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12
		13: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13
		14: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14
		15: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15
		16: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16
		17: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17
		18: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18
		19: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19
		20: print, _extra=extra, m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18,m19,m20
		else: 
	endcase
	return
end

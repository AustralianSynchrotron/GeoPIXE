;
;  conc_stats_test Image plugin routine
;  -----------------------------
;
;  All Image conc_offset routines MUST be named with "_image__plugin.pro"
;  at the end of the file name. For a new "Fred" plugin, copy and rename this file
;  to "Fred_image_plugin.pro" and edit the first line to:
;  "pro fred_image_plugin, p, i, title=title, history=history"
;
;  Plugins should be compiled in IDLDE and saved as a SAV file.
;  Only compile routines for ONE plugin and save using the command:
;
;  "SAVE, /routines, filename='fred_image_plugin.sav'"
;
;  for a "fred_image_plugin" plugin.
;
;  To ensure that only one routine exists in a file, exit IDLDE and start it again to compile
;  and save a plugin.
;
;  NOTE: It is important to ensure that ONLY routines for ONE plugin is in each SAV file.
;  Otherwise, unexpected results may result when the SAV files are restored at run-time.
;
;
;  The plugin SAV files will then be loaded automatically when GeoPIXE.sav runs,
;  if the plugin SAV files are located in the same directory as GeoPIXE.sav.
;
;  Plugin arguments:
;	p		pointer to the GeoPIXE image structure for the present loaded images
;	i		the number of the presently displayed element.
;
;  keywords:
;	history		return a history string along with the image result.
;	title		just return the title string (to go in the menu).
;
;  On return to GeoPIXE, it is assumed that only the contents of the selected element image have
;  been changed, and the sizes of images, their total number and element names all remain unchanged.
;  Avoid tinkering with image structure parameters, as strange things may happen.
;
;----------------------------------------------------------------------------------------------

pro conc_stats_test_image_plugin, p, i, title=title, history=history

COMPILE_OPT STRICTARR

if arg_present(title) then begin
	title = 'Conc Stats Test Image Plugin'			; return the menu title for this plugin
	return
endif

image_save_undo, p, i						; this will save image in undo buffer
											; this routine is part of GeoPIXE

;text = ['Offset value (ppm)']
;initial_text = '0.0'
;help_text = ['Enter a value to offset each pixel by, in ppm.']
;;Help_default = 'Selecge.'
;r = options_popup( title='Offset all pixels', text=text, initial_text=initial_text, help_text=help_text, $
;			error=error)			; min_xsize=300, help_default=help_default
;if error then return
;
;offset = r.text[0]

;...............................................................................................
;
; Now comes your code here. Use the image data "(*pimg)[ix,iy,iel]" as source,
; and form a new image called "img". The example below will just do a simple smooth:
; Make use of these parameters from the image structure.

pimg = (*p).image							; pointer to the image arrays for all elements
var = (*p).error							; pointer to 'var' (different size!)
sx = (*p).xsize								; X size of image in pixels
sy = (*p).ysize								; Y size of image in pixels
n_el = (*p).n_el							; number of elements/images
el_name = (*(*p).el)[i]						; name of this image
ca = (*p).cal.poly[1]						; energy calibration energy per channel
cb = (*p).cal.poly[0]						; energy calibration offset
cunits = (*p).cal.units						; energy calibration units string
charge = (*p).charge						; integrated charge for images (uC)

old_img = (*pimg)[*,*,i]					; image data for this element
old_var = congrid( (*var)[*,*,i], sx,sy)

(*pimg)[*,*,i] = old_img / sqrt(old_var > 0.001)	; write back the modified image data

; A simple history record for this plugin.
; No need to add the plugin name here; this is done by GeoPIXE.

history = 'Conc / sqrt(Var)'

; Still half baked test, Should:
;	not be puit off by low Var values
;	Then form ratio of conc/sqrt(var) in correct ppm units.
;	use conc of region and error estimate as a guide ...

	window,0, xsize=500, ysize=400, retain=retain
;	binsiz = 3000
;	h = histogram( count_rate, min=50000., max=max(count_rate), omin=omin,omax=omax, binsize=binsiz, locations=x)
;	x = x+binsiz/2.
	h = histogram( (*pimg)[*,*,i], omin=omin,omax=omax, locations=x)
	
	!p.color = spec_colour('black')
	!p.background = spec_colour('white')
	!p.title = 'Count rate distribution'
	!x.title = 'c/s'
	!y.title = 'Frequency'
	!p.charsize = 1.2
	!p.charthick = 1.0
	!p.thick = 1.0
	erase
;	plot, x,h, xrange=[(omin-binsiz)>0,omax+200000], /nodata, /ylog, yrange=[0.5,1.03*max(h)], xstyle=1,ystyle=1
	plot, x,h, xrange=[(omin)>0,omax], /nodata, /ylog, xstyle=1,ystyle=1
	oplot, x,h, color=spec_colour('green'), thick=2.

;...............................................................................................

return
end


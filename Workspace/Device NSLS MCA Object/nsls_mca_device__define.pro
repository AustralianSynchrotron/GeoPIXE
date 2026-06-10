;
; GeoPIXE Device Object for NSLS MCA pixel spectra data
; 
; This makes use of the "mca" and "med" objects and sample code written by Mark Rivers.
; 
; Initialization:
; When all device classes are detected and loaded into GeoPIXE (all files of the
; form "xxx_device__define.sav" or "xxx_device__define.pro" in the "interface"
; sub-directory of the GeoPIXE main directory, excluding 'BASE_DEVICE"), an 
; Object reference is created for each using the IDL call "Obj_New('xxx_device')".
; This executes the "Init" method in the class.
; 
; init()			initialize the class definition and also defines the main 
; 					object parameter struct in the "xxx_device__define" routine.
; 					DO NOT RUN THIS METHOD (it is done by IDL).
; cleanup			this is run when an object is destroyed (DO NOT RUN THIS METHOD)
; 
; Reading list-mode data to produce images and spectra:
; All device object classes need to implement these methods, with a full parameter
; list (even if some parameters are not used).
;
; read_setup()		will be called after each data file that is opened to setup
;					internal device parameters needed for reading data buffers,
;					such as buffer size and device-specific buffer organization.
; read_buffer()		called repeatedly to read buffers from the data file, process
;					these to extract X,Y,E triplet data, tagged by detector channel,
;					compress X,Y,E if needed, and optionally detect other
;					information (e.g. flux/charge, energy tokens). 
; get_header_info()	interrogate the data files (usually prior to starting processing)
; 					for various details, such as scan size (physical size and/or
; 					pixel count), title, energy cal for detectors, etc.
;
; The above 3 methods (plus the init and cleanup methods) are the minimum set needed 
; to be written for a new device class.
;
; flux_scan()		scan the raw data-files for details of available ion chamber 
; 					specifications (e.g. EPICS PVs) to provide for user selection, and 
; 					select one to use, and the pre-amp sensitivity value and units.
; trim_evt_files()	trim the list of files to only include files needed for the Y range
; 					seen in the region mask arrays (used with EVT button on Image Regions window).
;
; Import of various device-specific spectra formats:
; The "Spectrum Display" window "File->Import" menu can provide access to various routines
; for reading local device-specific spectrum data formats. It also provides access for
; scanning the list-mode data to extract all spectrum information (this is handled internally
; in GeoPIXE. The two routines providing this access are:
; 
; get_import_list()	returns a vector of structs specifiying various properties of the
; 					spectrum import (or list-mode spectrum extract) routines.
; 					(look at these routines below for details of these structs and various
; 					examples).
; import_spec()		calls the selected external import routine to read local spectral data.
; 
; Base-device methods available:
; Some general purpose methods are provided by the BASE_DEVICE master-class, so you don't
; need to write these for each device class (call from your class code using e.g.
; "self->big_endian()"). These are:
;
; name()				return name of device (e.g. "NSLS_MCA_DEVICE").
; title()				return title string for this device (used in Sort EVT droplist)
; extension()			return raw data file extension (if fixed, else '')
; multi_files()			1=data organized in multiple files, else=0
; multi_char()			character used to separate run name/number from numeric data-file series
; big_endian()			1=flags data stored in raw data in Big Endian byte order, else=0
; vax_float()			1=flags VAX D-floating variables as part of data header
; start_adc()			# of the first detector ADC.
; pileup()				1=flags the use of a pileup rejection file for this device
; throttle()			1=f;ags the use of a Throttle mechanism for this device
; linear()				1=flags a linearization correction table used for this device
; ylut()				1=flags that this device can use and generate a lookup table of 
;						first Y for each member of a multi-file data series to speed up
;						certain operations (e.g. spectra extract using EVT button on Image Regions window).
; use_bounds()			1=flags that this device may have a border of pixels that contain
;						no data and no beam charge/flux that should be excluded from pixel count.
;
; The values for these setting are set-up in the device Init method, in a call to
; the BASE_DEVICE super-class Init method. 
; 
; Other options that can be flagged are the use of pileup, throttle, linearization, and the
; use of a Y lookup table, which can be flagged this way:
;
;	self.pileup.use = 1
;	self.throttle.use = 1
;	self.linear.use = 1
;	self.header.scan.use_ylut = 1
;
; Device specific parameters:
; If the device has some device specific parameters that need to be set-up for
; processing and read/written along with image and region data, etc. then use this
; facility to define widgets to gather info about parameter options and manage them.
; If you don't need them, do not define these methods. Then a default (no action)
; method will be used in the "BASE_DEVICE" master-class. See the code in the Maia_device
; as an example.
; 
; These options are set-up in widgets that appear in the Sort EVT options box on the
; Sort tab. The parameters live in the class 'self' struct and are handled by GeoPIXE
; using these methods:
;
; render_options	Draws widgets needed in supplied parent base (on Sort tab).
; read_options		Called when images and regions are read from disk to read
;					the device specific options into the object self struct.
; write_options		Called when images and regions are written to disk to write
;					the device specific options from the object self struct.
; options_legend()	Returns a formatted string array to be added to the
;					image history list in the Image History window.
;
; To use these widgets and methods, enable the options by setting the following in
; your class 'init' method:
; 
; 	self.options.scan.on = 1			; enable options wdigets
; 	self.options.scan.ysize = 100		; Y size of sort options box, when open
; 	
; If you need to set or get your options parameters from your class, you can define these
; methods (see examples in Maia_device). They are not essential and are NOT called
; from GeoPIXE:
; 
; set_options		Explicitly pass these options parameters into the object.
;					This is only used to transfer old version file data in
;					and should be avoided normally.
; get_options()		Explicitly get options parameters from object.
;					Avoid using this.		
;
; The following two are used with Options widgets, but are handled by the Base super-class:
; 
; show_sort_options()  Flags that this device has sort options to display.
; get_sort_ysize()	   Returns number of Y pixels needed for device options fields.
;
; The code in the render_options for creating options widgets for the Maia device,
; which also calls some OnRealize routines and an event handler, can be used as a model
; for new device options fields.
;
;----------------------------------------------------------------------------------------------------

pro NSLS_MCA_DEVICE::cleanup

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::cleanup',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

	self->BASE_DEVICE::cleanup
    return
end

;-------------------------------------------------------------------

; The "options" are widgets and parameters associated with the Sort tab
; of the Sort EVT window. These are rendered in this class, using the method
; "render_options" and the parameters read/written FROM DISK using the "read_options",
; "write_options" methods.
;
;	options		return current option values

pro NSLS_MCA_DEVICE::read_options, unit, options=options, error=error

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::read_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

; Get current defaults in this device

	options = self->get_options()
	assume_rate_pv = options.assume_rate_pv
	version = 0L
	
; Read options parameters from the file

	on_ioerror, bad_io
	if self.use_version then readu, unit, version
	
	if self.use_version then begin
		if version le -1 then begin
			readu, unit, assume_rate_pv

			assume_rate_pv = clip(assume_rate_pv,0,1)
		endif
	endif
	
; Write back these options arameters to the device ...

	options.assume_rate_pv = assume_rate_pv
	
	self->set_options, options
	error = 0
	return
	
bad_io:
	error = 1
	return
end

;-------------------------------------------------------------------------------

; The "options" are widgets and parameters associated with the Sort tab
; of the Sort EVT window. These are rendered in this class, using the method
; "render_options" and the parameters read/written FROM DISK using the "read_options",
; "write_options" methods.
;
; write_options writes device parameters to disk. It is assumes that they have been used
; (e.g. in sort) and are being saved in an image file. Hence, the widgets are not read
; again here first. If 'options' passed use these instead.

pro NSLS_MCA_DEVICE::write_options, unit, options=p, error=error

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::write_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

	if n_elements(p) eq 0 then options = self.sort_options
	if ptr_valid(p) then begin
		if size(*p,/tname) eq 'STRUCT' then begin
			options = *p
		endif else begin
			options = self.sort_options
		endelse
	endif else begin
		if size(p,/tname) eq 'STRUCT' then begin
			options = p
		endif else begin
			options = self.sort_options
		endelse
	endelse
	
	version = -1L
	
	on_ioerror, bad_io
	writeu, unit, version
	
	writeu, unit, options.assume_rate_pv
	error = 0
	return
	
bad_io:
	error = 1
	return
end

;-------------------------------------------------------------------------------

; Return a string to display (e.g. in Image History window) to show the
; state of this device's options. If 'p' present, then show this parameter set.

function NSLS_MCA_DEVICE::options_legend, p

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::read_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, ''
	endif
endif

	if n_elements(p) ge 1 then begin
		if size(p, /tname) eq 'STRUCT' then options = p
		if ptr_good(p, /struct) then options = *p
	endif
	if n_elements(options) eq 0 then options = self.sort_options

	on_off = ['Off','On']

	list = ['NSLS_MCA:' ] 
	list = [list, '   Epics PV as rate: ' + on_off[options.assume_rate_pv] ]

	return, list
end

;-------------------------------------------------------------------------------
; These routines are associated with the rendering of Sort Options widgets
; in the Sort EVT window Sort tab options box.
;-------------------------------------------------------------------------------

function NSLS_MCA_DEVICE_sort_option_event, event

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE_sort_option_event',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0L
	endif
endif

	if widget_info( event.handler, /valid) eq 0L then begin
;		print,'NSLS_MCA_DEVICE_sort_option_event: event.handler not valid.'
		return, 0
	endif
	uname = widget_info( event.handler, /uname)
	if uname ne 'obj-ref-here' then begin
		print,'NSLS_MCA_DEVICE_sort_option_event: Object base not found.'
		return, 0
	endif
	widget_control, event.handler, get_uvalue=obj
	if obj_valid(obj) eq 0L then begin
		print,'NSLS_MCA_DEVICE_sort_option_event: Device Object ref not found.'
		return, 0
	endif

case tag_names( event,/structure) of
	'WIDGET_TRACKING': begin
		return, event						; pass context help up the line ...
		end
	else: begin
		
		uname = widget_info( event.id, /uname)
		case uname of
			'nsls-options': begin
				case event.value of
					0: begin
						obj->set_options, assume_rate_pv = event.select
						end
				endcase
				end
		endcase		
		end
endcase
return, 0L
end

;------------------------------------------------------------------------------------------

; Render options widgets in Sort Options box in Sort EVT window.
; Parent is the framed container box. Its child must be a base that
; all options widgets are attached to. This child is target of destroy
; when switching devices.

pro NSLS_MCA_DEVICE::render_options, parent

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::render_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

case !version.os_family of
	'MacOS': begin
		deadtime_xsize = 107
		end
	'unix': begin
		deadtime_xsize = 107
		end
	else: begin
		deadtime_xsize = 107
		end
endcase

; Call super-class to cleanup old display and set Y size of box first ...

self->BASE_DEVICE::render_options, parent

; The following will appear in the Options box on the Sort tab of the Sort EVT window ...

nslsmode_base = widget_base( parent, /column,  space=1, xpad=0, ypad=0, /base_align_center, $
		event_func='NSLS_MCA_DEVICE_sort_option_event', uvalue=self, uname='obj-ref-here')
lab = widget_label( nslsmode_base, value='NSLS MCA Option Parameters')

; Check-boxes for optional Epics PV rate. 
; The uvalue contains a help string to be displayed to explain this widget.

nsls_epics_pv = cw_bgroup2( nslsmode_base, ['Epics PV is a rate'], /row, set_value=[self.sort_options.assume_rate_pv], sensitive=1, $
					/return_index, uname='nsls-options',/ nonexclusive, /tracking, ypad=0, $
					uvalue=['Optionally specify that the Epics PVs in the data are rates (c/s), rather than a count accumulated during the pixel dwell.'])

error = 0
add_widget_vector, self.sort_id.assume_rate_pv, nsls_epics_pv, error=err & error=error or err
if error then begin
	warning,'NSLS_MCA_DEVICE::render_options','Error adding device object widget ID vectors.'
endif
return
end

;------------------------------------------------------------------------------

; The "options" are widgets and parameters associated with the Sort tab
; of the Sort EVT window. These are rendered in this class, using the method
; "render_options" and the parameters read/written from/to DISK using the "read_options",
; "write_options" methods. Keep a local copy of device parameters and set them using
; "set_options". 

pro NSLS_MCA_DEVICE::set_options, p, assume_rate_pv=assume_rate_pv

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::set_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

	if n_elements(p) eq 1 then begin
		if size(p, /tname) eq 'STRUCT' then begin
			nsls = p
		endif else if ptr_good(p,/struct) then begin
			nsls = *p
		endif else return
	endif

	if n_elements(nsls) eq 1 then begin
		if tag_present('ASSUME_RATE_PV',nsls) then self.sort_options.assume_rate_pv = nsls.assume_rate_pv
	endif else begin
		if n_elements(assume_rate_pv) eq 1 then self.sort_options.assume_rate_pv = assume_rate_pv
	endelse
	
	; Set value of widgets. There may be multiple sort option panels attached to this object, so
	; we use 'widget_control_vector' to set all of them.
	
	widget_control_vector, self.sort_id.assume_rate_pv, set_value = [self.sort_options.assume_rate_pv]
	return
end

;-------------------------------------------------------------------

function NSLS_MCA_DEVICE::get_options, error=error

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::get_options',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0
	endif
endif

	error = 0
	
	return, self.sort_options
end

;-------------------------------------------------------------------
;-------------------------------------------------------------------

; This method is called when list-mode files are accessed (e.g. when a 
; file is selected in the Sort EVT window) to read details of the data
; and/or experiment/scan set-up. It fills in as many header details as can be
; found in the data. See the Base_device super-class definition for the 
; contents of the header. Of particular importance are the scan sizes in pixels.

function NSLS_MCA_DEVICE::get_header_info, file, output=output, silent=silent, error=error

; file		a raw data file to look for associated header, metadata
; output	if present, this is a file on the output path, if some metadata is
;			located in that path. 
; /silent	suppress any pop-ups.

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::get_header_info',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0
	endif
endif
common c_geopixe_adcs, geopixe_max_adcs

	if n_elements(silent) lt 1 then silent=0
	error = 1

         s = ''
         set_separators, ' ,  '

         on_ioerror, cont10
		 close, 2
         openr, 2, strip_file_ext(file)+'.dat'

         while( ~ EOF(2)) do begin
          readf,2, s
          l = locate(':',s)
          token = extract(s,0,l-1)
          val = extract(s,l+1,lenchr(s)-1)
          case token of
              'Image title': begin
                 self.header.title = strtrim(val,2)
                 end
              'Number of columns': begin
                 self.header.scan.x_pixels = fix(val)
                 self.header.scan.on = 1
                 end
              'Number of rows': begin
                 self.header.scan.y_pixels = fix(val)
                 self.header.scan.on = 1
                 end
              'Starting and Stopping Positions (cols)': begin
                 chop_string, val, str, n_str
                 if n_str ge 2 then begin
                   self.header.scan.x_mm = abs(float(str[1])-float(str[0]))*float(self.header.scan.x_pixels+1)/float(self.header.scan.x_pixels)
                 endif
                 end
              'Starting and Stopping Positions (rows)': begin
                 chop_string, val, str, n_str
                 if n_str ge 2 then begin
                   self.header.scan.y_mm = abs(float(str[1])-float(str[0]))*float(self.header.scan.y_pixels+1)/float(self.header.scan.y_pixels)
                 endif
                 end
              else:
          endcase
         endwhile

cont10:     close, 2
         on_ioerror, bad_io
         med = obj_new('MED',16)
         med->read_file, file

    ;   The variable energy is the energy of each mca channel in keV, again an array 2048 x number of detector elements.
           energy = med->get_energy()

	;	Time information
			time = med->get_elapsed()

    ;   Environment variables are stored in the header of each spectrum file.

           environment = med->get_environment()

    ;   I0, x_value, and y_value pull out the ion chamber counts,
    ;   position of the x stage motor (in mm's),
    ;   and y stage motor from the saved environment variables.

         n = min([geopixe_max_adcs,n_elements(energy[0,*]),16])

         cb = reform(energy[0,0:n-1])
         ca = reform(energy[1,0:n-1]) - cb
         self.header.cal[0:n-1].on = 1
         self.header.cal[0:n-1].a = ca
         self.header.cal[0:n-1].b = cb
         self.header.cal[0:n-1].units = 'keV'

         self.header.detector[0:n-1] = 7          ; SXRF
         self.header.scan.dwell = mean(time.real_time)
         error = 0

		 med->free_environment
         obj_destroy, med
	
	self.header.error = 0
	return, self.header

bad_io:
	error = 1
	return, 0L
end

;-------------------------------------------------------------------

; Scan raw data files for device specific flux IC PV information
 
pro NSLS_MCA_DEVICE::flux_scan, unit, evt_file, PV_list, IC_name, IC_val, IC_vunit, dwell=dwell, $
			image_mode=image_mode, group=group, suppress=suppress, $
			no_pv=no_pv, use_dwell=use_dwell, error=error

; Scan raw data files for flux IC PV information
; 
; Input:
; 	unit		I/O unit open
; 	evt_file	file-name of opened file
; 	group		group-leader parent window to pass to any pop-up windows
;
;	/Image_mode	scan data for PVs for an image, with dwell
;	/Suppress	suppress pop-ups

; Return:
; 	PV_list		string list of all PV's found that may be used to measure flux/IC count
; 	IC_name		PV selected by user from list
; 	IC_val		pre-amp sensitivity value
; 	IC_vunit	pre-amp sensitivity unit multipler
; 	dwell		dwell-time in a pixel (ms), if needed
; 	no_pv		flags absence of any PVs
;	use_dwell	flags need to use dwell in flux count measure

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::flux_scan',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif
common c_geopixe_adcs, geopixe_max_adcs
common c_nsls_1, nsls_x_range, nsls_y_range, nsls_x, nsls_y
common c_nsls_2, nsls_e, nsls_ste, nsls_chans, nsls_dets, nsls_x1, nsls_y1
common c_nsls_3, med, nsls_data
common c_nsls_4, nsls_IC
common c_nsls_5, nsls_IC_value_index, nsls_flux_scale
common c_nsls_6, max_det
common c_nsls_7, nsls_dead
common c_nsls_8, mca_id, sdsSPECTRA, nsls_read_line, mca_spectra
common c_nsls_9, nsls_debug

	if n_elements(first) lt 1 then first = 1
	if n_elements(suppress) lt 1 then suppress = 0
	if n_elements(image_mode) lt 1 then image_mode = 1
	if n_elements(nsls_debug) lt 1 then nsls_debug = 0
	
	PV_list = 'none'
	IC_name = ''
	IC_val = 1.
	IC_vunit = 0.
	dwell = 0.
	no_pv = 1
	use_dwell = 0
	error = 1
	
	on_ioerror, bad_io

		stat = fstat(unit)
 		close, unit
		if first then begin
			if n_elements(med) lt 1 then med = obj_new('MED', 16)
			if obj_valid(med) eq 0 then med = obj_new('MED', 16)

			med->read_file, stat.name
		    energy = med->get_energy()
			max_det = min([geopixe_max_adcs,n_elements(energy[0,*]),16])
			print,'max_det=', max_det

	    	med->free_environment
			obj_destroy, med
		endif

		if n_elements(med) lt 1 then med = obj_new('MED', max_det)
		if obj_valid(med) eq 0 then med = obj_new('MED', max_det)

		med->read_file, stat.name

;		Time data includes time[i].live_time and time[i].real_time (secs).

		time = med->get_elapsed()

;		Environment variables are stored in the header of each spectrum file.

    	environment = med->get_environment()

		if first and (suppress eq 0) then begin
			a1_val = 0.0
			a1_unit = 1.0
			vals = [1., 2., 5., 10., 20., 50., 100., 200., 500.]
			units = ['pA/V', 'nA/V', 'uA/V', 'mA/V']
			vunit = [0.001,1.0,1000.0,1000000.0]

;			Ion chamber PV selection options, or ring current, etc.
;			Search for PV token fragments in 'environment.name' and 'description'

			qa = where_tokens( [':scaler',':userCalc'], environment.name)
			q = where_tokens( ['Ion','IC','I0','Ring'], environment.description, nq, q=qa)

;			Ion chamber preamp sensitivity value

			q2a = where_tokens( ['sens_num.VAL'], environment.name)
			q2 = where_tokens( ['sensitivity value'], environment.description, nq2, q=q2a)

;			Ion chamber preamp sensitivity units

			q3a = where_tokens( ['sens_unit.VAL'], environment.name)
			q3 = where_tokens( ['sensitivity unit'], environment.description, nq3, q=q3a)

;			Deadtime correction PV not used. Real-time/live-time used in read_setup() to
;			calculate deadtime fraction for each pixel. Dead=0 used in call below to suppress
;			widget selector.

			times = ['-- not used --']		

			if (nq ne 0) then begin
				if (nq2[0] ne 0) and (nq3[0] ne 0) then begin
					select = generic_flux_select( group, environment[q].name, environment[q2].name, environment[q3].name, times, dead=0, error=dud)
				endif else begin
					select = generic_flux_select( group, environment[q].name, string(vals), units, times, dead=0, error=dud)
				endelse
				PV_list = environment[q].name
				no_pv = 0
			endif else dud=1

			if dud then begin
				nsls_IC_value_index = 0
				nsls_flux_scale = 1.
			endif else begin
				nsls_IC_value_index = q[select.flux]
				if (nq2 ne 0) and (nq3 ne 0) then begin
					a1_val = float(environment[q2[select.sense_num]].value)
					u = environment[q3[select.sense_unit]].value
					q2b = where( strlowcase(u) eq strlowcase(units))
					a1_unit = 1.
					if q2b[0] ne -1 then a1_unit = vunit[q2b]
				endif else begin
					a1_val = vals[ select.sense_num ]
					a1_unit = vunit[ select.sense_unit ]
				endelse
				IC_val = a1_val
				IC_vunit = a1_unit
				nsls_flux_scale = a1_val * a1_unit								; scaling of counts for nA/V units
			endelse
			IC_name = environment[nsls_IC_value_index].name
		endif

    	med->free_environment
		obj_destroy, med
		openr, unit, stat.name
	error = 0
	return

bad_io:
	warning,'NSLS_MCA_DEVICE::flux_scan','MCA file I/O error.'
	error = 1
	return
end

;-------------------------------------------------------------------

function NSLS_MCA_DEVICE::get_dwell, error=error

; Return the internal dwell (ms) image array

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::get_dwell',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		error = 1
		return, 0L
	endif
endif
common c_nsls_10, nsls_dwell, nsls_fixed_dwell, nsls_pixel_dwell

	error = 0
	return, 1000. * nsls_dwell
end

;-------------------------------------------------------------------

; read_setup()		will be called after each data file that is opened to setup
;					internal device parameters needed for reading data buffers,
;					such as buffer size and device-specific buffer organization.

function NSLS_MCA_DEVICE::read_setup, unit, xrange,yrange, first=first, $
			n_guide,progress_file, charge=charge, ecompress=ecompress, $
			flux=flux, dead_fraction=dead_fraction, $
			suppress=suppress, ic=flux_ic, x_coords=x_coords, $
			y_coords=y_coords, x_coord_units=x_coord_units, y_coord_units=y_coord_units, $
			beam_energy=beam_energy

;   Device specific list-mode (event-by-event) data file read set-up routine.
;   Remember, channel starts at 0 (-1 means any channel/ADC).
;
; input:
;   unit		read unit number
;   xrange		X size of scan (pixels)
;   yrange		Y size of scan (pixels)
;   ecompress	desired E axis compression (needs to match DA energy calibration)
;   ic			struct containing ion chamber settings for flux measurement. Has the form:
;   			{mode:0, pv:'', val:0.0, unit:0.0, conversion:1., use_dwell:0, dwell:1.0}
;   			where	mode	0=no flux IC (no IC data), 1=use IC PV, 2=use conversion only (no PV)
;   					pv		user selected EPICS PV string to be used for flux IC
;   					val		pre-amp sensitivity value
;   					unit	pre-amp sensitivity unit (scale)
;   				conversion	conversion from flux count to charge (uC)
;   				use_dwell	use the dwell time with flux count-rate to build flux count per pixel
;   				dwell		dwell time in a pixel (ms)
;
;	/first		for first file in multi-file data-set
;   /suppress	suppress any pop-up windows
;
; return:
; 	n_guide		an event number to guide reporting in the progress bar
;   progress_file provide progress by (1) file advance/ (2) spectra # rather than (0) records/events
;   charge		charge for whole scan (uC), if available from file
;   beam_energy	beam energy, if it's available (MeV=ionbeam, keV=synchrotron)
;
;	x_coords	vector of physical coordinates for X pixels (if available from data files)
;	x_coord_units units string for X coords
;	y_coords	vector of physical coordinates for y pixels
;	y_coord_units units string for Y coords
;	
;   flux		flux array (matches image dimensions for scan), accumulated here or in read_buffer
;   			'flux' is scalar for spectrum mode.
;   dead_fraction DT loss-fraction array (matches image dimensions for scan, matches n_detectors in spectrum mode),
;   			accumulated here or in read_buffer
;
;   error		read_setup() returns=1 to flag an error to abort data processing

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::read_setup',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 1
	endif
endif
common c_geopixe_adcs, geopixe_max_adcs
common c_nsls_1, nsls_x_range, nsls_y_range, nsls_x, nsls_y
common c_nsls_2, nsls_e, nsls_ste, nsls_chans, nsls_dets, nsls_x1, nsls_y1
common c_nsls_3, med, nsls_data
common c_nsls_4, nsls_IC
common c_nsls_5, nsls_IC_value_index, nsls_flux_scale
common c_nsls_6, max_det
common c_nsls_7, nsls_dead
common c_nsls_8, mca_id, sdsSPECTRA, nsls_read_line, mca_spectra
common c_nsls_9, nsls_debug
common c_nsls_10, nsls_dwell, nsls_fixed_dwell, nsls_pixel_dwell
common c_nsls_11, nsls_assume_rate_pv, nsls_assume_live_time

	n_guide = 50000L				; i.e. Will update each ~2nd pixel

; Often the Epics ion chamber PV is a "rate" variable, rather than the flux "count" in
; the dwell time. In this case we need to scale the rate by dwell to get a count 
; proportional to flux for the pixel.

;	nsls_assume_rate_pv = 1			; Epics PV is a "rate" (=1), or a "count" (=0) in dwell

	nsls_assume_rate_pv = self.sort_options.assume_rate_pv		; get it from "Device" tab

; If we have acquired to a live time per pixel, corrected for dead-time losses, then
; we can set the dwell to the "live" time and set dead-time zero (to suppress any further
; correction for dead-time in GeoPIXE). However, DT will not be visible in GeoPIXE.

;	nsls_assume_live_time = 1		; Pixel acquired for a live time, already DT corrected
	
; If we have acquired to a nominal time per pixel, not corrected for dead-time losses, then
; we can set the dwell to the "real" time and set dead-time based on "real"-"live"
; (correction for dead-time will then be done in GeoPIXE). The results should be the
; same as for the live option, but the DT values will be visible as a map in GeoPIXE.

	nsls_assume_live_time = 0		; Pixel acquired for a set time, correct for DT elsewhere
	
	stat = fstat(unit)
	close, unit
	if first then begin
		if n_elements(med) lt 1 then med = obj_new('MED', 16)
		if obj_valid(med) eq 0 then med = obj_new('MED', 16)

		med->read_file, stat.name
		energy = med->get_energy()
		max_det = min([geopixe_max_adcs,n_elements(energy[0,*]),16])
		print,'max_det=', max_det

		self.spectrum_mode = 1
		if (n_elements(flux) ge 2) then self.spectrum_mode=0
			
		med->free_environment
		obj_destroy, med
	endif

	if n_elements(med) lt 1 then med = obj_new('MED', max_det)
	if obj_valid(med) eq 0 then med = obj_new('MED', max_det)

	med->read_file, stat.name

;	The variable data is the counts in each mca channel, so an array
;	2048 x number of detector elements. In our case [2048,9].

	nsls_data = med->get_data()

;	Time data includes time[i].live_time and time[i].real_time (secs).

	time = med->get_elapsed()

;	Environment variables are stored in the header of each spectrum file.

	environment = med->get_environment()

;	I0, x_value, and y_value pull out the ion chamber counts,
;	position of the x stage motor (in mm's),
;	and y stage motor from the saved environment variables.

	case flux_ic.mode of
		0: begin
			I0 = 0.													; will not build a flux map/value
			nsls_flux_scale = 1.
			end
		1: begin
			nsls_flux_scale = flux_ic.val * flux_ic.unit
			q = where( flux_ic.pv eq environment.name, nq)
			if nq eq 0 then begin
				warning,'NSLS_MCA_DEVICE::read_setup','Need to specify a valid flux PV in Sort EVT/ Import set-up.'
				goto, bad_io
			endif else begin
				nsls_IC_value_index = q[0]
			endelse
			I0 = float(environment[nsls_IC_value_index].value)		; ion chamber "count" or "rate"
			end
		2: begin
			warning,'NSLS_MCA_DEVICE::read_setup',['Not a valid Flux option for this device.', $
							'Use an Epics flux PV, or the direct charge option.']
			goto, bad_io		
			end
	endcase
	
;	x_value = environment[2].value
;	y_value = environment[3].value

	nsls_x_range = long(xrange)
	nsls_y_range = long(yrange)
	nsls_dets = n_elements(nsls_data[0,*])
	nsls_chans = n_elements(nsls_data[*,0])

	if nsls_assume_live_time then begin						; live time dwell, so device
		nsls_pixel_dwell = mean(time.live_time)				; will return no dead-time
	endif else begin
		nsls_pixel_dwell = mean(time.real_time)
	endelse
	nsls_IC = I0 * nsls_flux_scale							; "count" (norm to 1 nA/V scale)
	if nsls_assume_rate_pv then begin						; if it is a "rate",
		nsls_IC = nsls_IC * nsls_pixel_dwell				; scale by time to get "count"
	endif
		
	if first then begin
		nsls_x = 0
		nsls_y = 0
		nsls_fixed_dwell = nsls_pixel_dwell					; if an approx. uniform dwell
		if self.spectrum_mode then begin					; is needed anywhere
			nsls_dwell = flux[0]
		endif else begin
			nsls_dwell = flux[*,*]							; to replicate size and type as flux
		endelse												; should dwell be zeroed here, or elsewhere?
		nsls_dwell[*] = 0.0									; zero only for 'first'
		self.dwell_total = 0.0
	endif

	if nsls_assume_live_time then begin						; live time dwell, so device
		nsls_dead = time.live_time							; will return no dead-time
		nsls_dead[*] = 0.0
	endif else begin
		nsls_dead = (time.real_time - time.live_time)
	endelse
	if self.spectrum_mode then begin
		self.dwell_total = self.dwell_total + nsls_pixel_dwell
	endif else begin
		nsls_dead = nsls_dead/time.real_time
	endelse
	q = where(finite(nsls_dead) eq 0)
	if q[0] ne -1 then nsls_dead[q]=0.0
	
	ramp = indgen(nsls_chans)
	nsls_e = uintarr( nsls_chans, nsls_dets)
	nsls_ste = nsls_e
	for i=0L,nsls_dets-1 do begin
		nsls_e[*,i] = ramp
		nsls_ste[ramp,i] = i
	endfor

	nsls_e = reform( nsls_e, nsls_chans*nsls_dets)
	nsls_ste = reform( nsls_ste, nsls_chans*nsls_dets)
	nsls_x1 = uintarr( nsls_chans*nsls_dets)
	nsls_y1 = uintarr( nsls_chans*nsls_dets)

	med->free_environment
	obj_destroy, med
	openr, unit, stat.name
	return, 0
	
bad_io:
	return, 1
end

;-------------------------------------------------------------------

; read_buffer()		called repeatedly to read buffers from the data file, process
;					these to extract X,Y,E triplet data, tagged by detector channel, ste,
;					compress X,Y,E if needed, and optionally detect other
;					information (e.g. flux/charge, energy tokens). 

function NSLS_MCA_DEVICE::read_buffer, unit, x1,y1,e, channel_on,n, xcompress,ycompress, $
       ecompress=ecompress, total_bad_xy=bad_xy, total_processed=processed, $
       station_e=ste, title=title, multiple=multiple, $
       processed=count1, valid=good, raw_xy=raw_xy, time=tot, $
       flux=flux, dead_fraction=dead_fraction, file=file, $
       xoffset=xoffset, yoffset=yoffset, error=error, beam_energy=beam_energy

;   Device specific list-mode (event-by-event) data file reading routine.
;   Remember, channel starts at 0 (-1 means any channel/ADC).
;
; input:
;   unit		read unit number
;   file		filename passed for multi-file XY checking
;   channel_on	desired ADC channel(s) (these start at zero, after an optional offset)
;   xcompress	desired X axis compression
;   ycompress	desired Y axis compression
;   ecompress	desired E axis compression (needs to match DA energy calibration)
;   xoffset		offset X by this (i.e. subtract this)
;   yoffset		offset Y by this
;   /raw_xy		suppresses X,Y compression and offset
;   flux		for some flux is an array that comes in to be updated with pixel flux
;   dead_fraction for some this is an array that comes in to be updated with pixel dead_fraction
;				If flux is already DT corrected, "live" flux, then set dead-fraction zero.
;				
; return:
;   e			energy vector (uintarr) returned
;   x1			X vector (uintarr) return
;   y1			Y vector (uintarr) return
;   ste			ADC number vector (uintarr) for each returned event (less offset, starting at 0)
;	n			number of (x,y,e) triplets returned
;   beam_energy	beam energy, if it's available (MeV=ionbeam, keV=synchrotron)
;   valid		number of good events (same as 'n'), or zero
;   count1		number of events processes in this buffer
;   bad_xy		increment passed in value of total event with bad X,Y codes
;   processed	increment total number of events processed.
;   title		run title
;   error		error=1 flags an error to abort
;
; Optional (not used here):
;   t			(optional) Time-over-threshold vector (uintarr), for some DAQs (e.g. Maia)
;	veto		(optional) vector (uintarr) indicates a vetoed event (use this as events are rejected)
;   multiple	(optional) if this has same dimensions as e, then it indicates multiple
;          		events with the same x1,y1,e.

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::read_buffer',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 1
	endif
endif
common c_geopixe_adcs, geopixe_max_adcs
common c_nsls_1, nsls_x_range, nsls_y_range, nsls_x, nsls_y
common c_nsls_2, nsls_e, nsls_ste, nsls_chans, nsls_dets, nsls_x1, nsls_y1
common c_nsls_3, med, nsls_data
common c_nsls_4, nsls_IC
common c_nsls_5, nsls_IC_value_index, nsls_flux_scale
common c_nsls_6, max_det
common c_nsls_7, nsls_dead
common c_nsls_8, mca_id, sdsSPECTRA, nsls_read_line, mca_spectra
common c_nsls_9, nsls_debug
common c_nsls_10, nsls_dwell, nsls_fixed_dwell, nsls_pixel_dwell
common c_nsls_11, nsls_assume_rate_pv, nsls_assume_live_time

	on_ioerror, bad_io
	nc = n_elements(channel_on)

	multiple = long( reform(nsls_data, nsls_chans*nsls_dets))
	e = nsls_e
	ste = nsls_ste
	x1 = nsls_x1
	y1 = nsls_y1
	x1[*] = uint(nsls_x)
	y1[*] = uint(nsls_y)

	; in spectrum mode, the 'dead_fraction' array will accumulate dead-time across detectors, and
	; the variable 'self.total_dwell' will accumulate total time (in read_setup). In GeoPIXE, the
	; 'dead_fraction' will be nornmalized to total dwell time.  In image mode, 
	; 'dead_fraction' returns the fraction of time lost to dead-time in each pixel.
	
	if self.spectrum_mode then begin
		dead_fraction[0:nsls_dets-1] = dead_fraction[0:nsls_dets-1] + nsls_dead[0:nsls_dets-1] 
	endif else begin
		dt = mean(nsls_dead)
		if (nsls_x ge 0) and (nsls_y ge 0) and $
					(nsls_x lt nsls_x_range) and (nsls_y lt nsls_y_range) then begin
			dead_fraction[nsls_x/xcompress,nsls_y/ycompress] = dt
		endif
		nsls_dwell[nsls_x/xcompress,nsls_y/ycompress] = nsls_pixel_dwell
	endelse
	
	if self.spectrum_mode then begin
		if ((nsls_x_range*nsls_y_range gt 0) and (nsls_x ge 0) and (nsls_y ge 0) and $
					(nsls_x lt nsls_x_range) and (nsls_y lt nsls_y_range)) or $
					(nsls_x_range*nsls_y_range eq 0) then begin
			flux = flux + float(nsls_IC)
		endif
	endif else begin
		if (nsls_x ge 0) and (nsls_y ge 0) and (nsls_x lt nsls_x_range) and $
					(nsls_y lt nsls_y_range) then begin
			flux[nsls_x/xcompress,nsls_y/ycompress] = flux[nsls_x/xcompress,nsls_y/ycompress] + float(nsls_IC)
		endif
	endelse
;	print,'nsls: x,y, dwell, flux, dead, data = ', nsls_x, nsls_y, nsls_pixel_dwell, nsls_IC, dt, total(nsls_data)

	nsls_x = nsls_x+1
	if nsls_x ge nsls_x_range then begin
		nsls_x = 0
		nsls_y = nsls_y+1
	endif

	q = where((multiple gt 0) and channel_on[ste], good)
	if good gt 0 then begin
		e = e[q]
		ste = ste[q]
		x1 = x1[q]
		y1 = y1[q]
		multiple = multiple[q]
	endif
	n = good

	if good gt 0 then begin
		if raw_xy eq 0 then begin
			if xcompress ne 1 then x1 = x1 / uint(xcompress)
			if ycompress ne 1 then y1 = y1 / uint(ycompress)
			if ecompress ne 1 then e = e / uint(ecompress)
		endif
	endif else begin
		x1 = 0US
		y1 = 0US
		e = 0US
		ste = 0US
		multiple = -1L
	endelse

	processed = processed + good
	close, unit

	return, 0
	
bad_io:
	return, 1
end

;-------------------------------------------------------------------

function NSLS_MCA_DEVICE::import_spec, name, file, group=group

; Import spectra of various local types. This does not include extraction of
; spectra from list-mode data, which is handled elsewhere.

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::get_import_list',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0
	endif
endif
common c_geopixe_adcs, geopixe_max_adcs

	case name of
		'nsls_mca_mca': begin						; 27
			get_mca, p, file
			end
		'nsls_mca_evt': begin						; 26
			warning,'NSLS_MCA_DEVICE::import_spec',['"nsls_mca_evt" spectrum import.','This import should use "spec_evt" elsewhere.']
			end
	endcase
	return, p
end

;-------------------------------------------------------------------

function NSLS_MCA_DEVICE::get_import_list, error=error

; Return a vector of import specification structs that can be used in the
; Import window ("File->Import" menu of Spectrum Display window).

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::get_import_list',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0
	endif
endif

; Details of spectrum import struct ... (the first 4 items are essential):
;opt = { name:			'', $			; unique name for import
;		title:			'', $			; description for import list
;		in_ext:			'', $			; input file extension
;		request:		'', $			; title for file requester
;		
;		preview:		0, $			; allow spectrum preview
;		raw:			0, $			; flags use of separate Raw data path '(*pstate).dpath'
;		spec_evt:		0, $			; uses a call to spec_evt to extract from EVT data
;		device_name:	'', $			; associated device object name
;		multifile:		0, $			; denotes data in a series of more than one file
;		separate:		'.', $			; char between file and run #
;		use_linear:		0, $			; request linearization file
;		use_pileup:		0, $			; request pileup file
;		use_throttle:	0, $			; request throttle file
;		use_IC:			0, $			; pop-up the flux_select PV selection panel
;		use_tot:		0, $			; collect ToT data too
;		xr:				200, $			; default X range
;		yr:				200 $			; default Y range

	error = 1
	
	opt_27 = define(/import)			; NSLS MCA
		opt_27.name =		'nsls_mca_mca'		; unique name of import
		opt_27.title =		'NSLS MCA spectrum files'
		opt_27.in_ext =		''			; file extension
		opt_27.request =	'Select NSLS MCA spectrum to load'
	
	opt_26 = define(/import)			; NSLS MCA image spectra
		opt_26.name =		'nsls_mca_evt'		; unique name of import
		opt_26.title =		'Extract from NSLS image pixel MCA spectra'
		opt_26.in_ext =		''			; input file extension
		opt_26.request =	'NSLS MCA files to scan for all spectra [Enter FIRST file]'
		opt_26.raw =		1			; flags use of separate Raw data path '(*pstate).dpath'
		opt_26.spec_evt =	1			; uses a call to spec_evt to extract from EVT data
		opt_26.multifile =	1			; denotes data in a series of more than one file
		opt_26.separate =	'.'			; char between file and run #
		opt_26.use_IC =		1			; pop-up the flux_select PV selection panel
		opt_26.xr =			100			; default X range
		opt_26.yr =			100			; default Y range

	opt = [opt_27, opt_26]
	for i=0L,n_elements(opt)-1 do opt[i].device_name = self.name

	self.import_list = ptr_new(opt)
	error = 0
	return, opt
end

;-------------------------------------------------------------------

function NSLS_MCA_DEVICE::init

COMPILE_OPT STRICTARR
common c_errors_1, catch_errors_on
if n_elements(catch_errors_on) lt 1 then catch_errors_on=1
if catch_errors_on then begin
	Catch, ErrorNo
	if (ErrorNo ne 0) then begin
		Catch, /cancel
		on_error, 1
		help, calls = s
		n = n_elements(s)
		c = 'Call stack: '
		if n gt 2 then c = [c, s[1:n-2]]
		warning,'NSLS_MCA_DEVICE::init',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0
	endif
endif

; Sort Option items appear as Scan setup options in the Sort EVT "Scan" tab

	self.options.scan.on = 1				; scan sort options available for this class
											; these must be set-up in the render_options method
	self.options.scan.ysize = 90			; Y size of sort options box, when open

; Set default Sort Options local parameters ...

	self.sort_options.assume_rate_pv = 0	; Epics PV is asumed to be a count, not a rate

; Initial heap allocation for sort_id widget vector pointers ...

	self.sort_id.assume_rate_pv = ptr_new(/allocate_heap)			; Clear X,Y border check-box ID array pointer

;	Pass core device parameters to BASE DEVICE superclass
;	Note that 'name' must match the object's file-name:
;	"NSLS_MCA_DEVICE" --> NSLS_MCA_DEVICE_define.sav
;	and 'name' must contain the string "_DEVICE".
	 
	i = self->BASE_DEVICE::init(  $
		name = 'NSLS_MCA_DEVICE', $	; unique name for this device object
		title = 'NSLS MCA - VME data acquisition', $
		ext = '', $				; no fixed file extension for raw data
		multi_files = 1, $		; multiple segment files per run
		multi_char = '.', $		; separates run from segment number in file name
		big_endian = 1, $		; list-mode data written with Unix byte order
		vax_float = 0, $		; not VAX floating point
		start_adc = 1, $		; start detector ADC #'s at 0
		use_bounds = 0, $		; not confine charge/flux within bounded area
		array_default = 1, $	; a detect array by default
		synchrotron = 1, $		; synchrotron data
		ionbeam = 0)			; ion-beam data
	return, i
end

;-------------------------------------------------------------------

pro NSLS_MCA_DEVICE__define

; Define Maia device object internal data structure.
; Only called using obj = obj_new('NSLS_MCA_DEVICE')

COMPILE_OPT STRICTARR

maia = {NSLS_MCA_DEVICE,  $

		INHERITS BASE_DEVICE, $			; mandatory base device parameters
										; see the base_device super-class for details.

		sort_options : {sort_options_nsls_mca, $			; Sort EVT window Sort options panel
				assume_rate_pv:				0}, $			; Epics PV is a rate (1), or a count (0)

		sort_id: {sort_id_nsls_mca, $						; pointers to vector of sort widget IDs
				assume_rate_pv:				ptr_new()} $	; Epics PV as rate check-box ID array pointer
		}								
	return
end

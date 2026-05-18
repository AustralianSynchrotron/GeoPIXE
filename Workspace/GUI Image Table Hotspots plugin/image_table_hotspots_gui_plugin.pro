
;	Plugin to add a Hotspot tab to the Image Table GUI

function image_table_hotspots_gui_plugin_event, Event

COMPILE_OPT STRICTARR
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
		warning,'image_table_hotspots_gui_plugin_event',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return, 0L
	endif
endif

	child = widget_info( event.handler, /child)
	widget_control, child, get_uvalue=pstate
	pstate_parent = (*pstate).pstate_parent

	if ptr_good(pstate_parent, /struct) eq 0 then goto, bad_state
	if ptr_good(pstate, /struct) eq 0 then goto, bad_state

	p = (*pstate_parent).p
	no_regions = 0
	if ptr_valid(p) eq 0 then goto, bad_ptr
	if size(*p,/tname) ne 'POINTER' then begin
		no_regions = 1
	endif else begin
		if ptr_valid( (*p)[0] ) eq 0 then no_regions=1
		if no_regions eq 0 then if size(*(*p)[0],/tname) ne 'STRUCT' then no_regions=1
	endelse
	if no_regions eq 0 then obj = (*(*p)[0]).DevObj

	case tag_names( event,/structure) of
		'WIDGET_TRACKING': begin
			return, { WIDGET_TRACKING, ID:event.id, TOP:event.top, HANDLER:0L, ENTER:event.enter }
			end
		else:
	endcase

	uname = widget_info( event.id, /uname)

	case uname of
		'Hotspots_Button': begin
			widget_control, (*pstate).hotspot_element, get_value=s
			OnButton_Image_Table_HotSpots, Event, stub=s[0]
			end
	
		'Neighbourhoods_Button': begin
			widget_control, (*pstate).hotspot_element, get_value=s
			OnButton_Image_Table_HotSpot_Neighbourhood, Event, stub=s[0]
			end
	
		'Export_Centroids_Button': begin
			widget_control, (*pstate).hotspot_element, get_value=s
			OnButton_Image_Table_Export, Event, /hotspots, hs_el=s[0]
			end
	
		else: return, event
	endcase

finish:
	return, 0L

bad_state:
	warning,'image_table_hotspots_gui_plugin_event',['STATE variable has become ill-defined.','Abort Image Table.'],/error
	goto, finish
bad_ptr:
	warning,'image_table_hotspots_gui_plugin_event',['Parameter structure variable has become ill-defined.','Abort Image Table.'],/error
	goto, finish
end

;-----------------------------------------------------------------

pro OnButton_Image_Table_HotSpots, Event, stub=stub

COMPILE_OPT STRICTARR
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
		warning,'OnButton_Image_Table_HotSpots',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif

;	This was written for parent originally, so pstate is that of Image_Table parent

	child = widget_info( event.handler, /child)
	widget_control, child, get_uvalue=pstate_local
	pstate = (*pstate_local).pstate_parent
		
	i = (*pstate).sel.top
	if image_table_invalid(pstate) then goto, done
	(*pstate).n = n_elements( *(*pstate).p)
	if (i lt 0) or (i ge (*pstate).n) then goto, done
	p = (*(*pstate).p)[i]
	if (*p).mode ne 1 then begin
		warning,'OnButton_Image_Table_HotSpots','No "highlighted" pixels found in region.'
		goto, done
	endif
	p1 = (*(*pstate).p)[0:i]
	if i lt ((*pstate).n-1) then begin
		p3 = (*(*pstate).p)[i+1:(*pstate).n-1]
	endif else p3 = 0L

	progress, tlb=progress_tlb, title='Hot-spot particle separation'

	a = bytarr( (*p).nx, (*p).ny)
	a[*(*p).q] = 1B									; hot pixels

;	Invert the map
	b = 1B - a

;	Use watershed function to find distinct index for each watershed
	c = watershed( b)

;	Number of distinct 'watersheds' or particles
	n = max(c)

	progress, /update, progress_tlb, {unit:0, value:0, current:1, size:n}, cancel=cancel
	if cancel then goto, done

	warning,'OnButton_Image_Table_HotSpots',['Found '+str_tidy(n)+' distinct particles or "watersheds".', $
			'Select "Cancel" to cancel, or "OK" to continue.'], cancel=cancel
	if cancel then goto, done

	for j=1,n do begin
		progress, /update, progress_tlb, {unit:0, value:0, current:j, size:n}, cancel=cancel
		if cancel then goto, done

		qi = where( (c eq j) and (a eq 1), ni)		; pixels for watershed index 'j'
		if ni ge 1 then begin
			copy_pointer_data, p, pi, /init			; clone region pointer data
			*(*pi).q = qi							; set the selected pixels for this index
			if j eq 1 then begin
				p2 = pi
			endif else begin
				p2 = [p2,pi]
			endelse
		endif
	endfor

	p = [p1,p2]										; insert p2 list between p1 and p3
	if ptr_valid(p3[0]) then p=[p,p3]
	*(*pstate).p = p
	(*pstate).n = n_elements( *(*pstate).p)

	for i=0, (*pstate).n-1 do begin
		(*p[i]).index = i							; reset index values
	endfor
	
;	new_table_pselect, pstate, 0
	notify, 'image-region-clear', from=event.top
	notify, 'image-region-update', from=event.top	; get Image window to update concs to use new pixel selections
	(*pstate).file_valid = 0
	*(*pstate).pregions = 0L						; regions do not match spectra anymore
	notify, 'image-regions', (*pstate).pregions, from=event.top

	file = (*pstate).file
	if file[0] eq '' then file=strip_file_ext((*(*(*pstate).p)[0]).file) + '.region'

	file = strip_file_ext(file) + '.region'
	remove = ['-hotspots','-neighbourhood','-q1']
	add = '-hotspots'
	if strlen(stub) ne 0 then begin
		remove = [remove, '-'+stub]
		add = add + '-'+stub
	endif
	add = add + '-q1'
	(*pstate).file = strip_file_keys( file, remove=remove, element=1, add=add)

done:
	progress, /complete, progress_tlb, 'Update ...'
	progress, /ending, progress_tlb
	return
end

;-----------------------------------------------------------------

pro OnButton_Image_Table_HotSpot_Neighbourhood, Event, stub=stub, w=w

COMPILE_OPT STRICTARR
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
		warning,'OnButton_Image_Table_HotSpot_Neighbourhood',['IDL run-time error caught.', '', $
				'Error:  '+strtrim(!error_state.name,2), $
				!error_state.msg,'',c], /error
		MESSAGE, /RESET
		return
	endif
endif
if n_elements(w) eq 0 then w=3

;	This was written for parent originally, so pstate is that of Image_Table parent

	child = widget_info( event.handler, /child)
	widget_control, child, get_uvalue=pstate_local
	pstate = (*pstate_local).pstate_parent
		
	i = (*pstate).sel.top
	if image_table_invalid(pstate) then goto, done
	(*pstate).n = n_elements( *(*pstate).p)
	if (i lt 0) or (i ge (*pstate).n) then goto, done
	p = (*(*pstate).p)[i]
	if (*p).mode ne 1 then begin
		warning,'OnButton_Image_Table_HotSpot_Neighbourhood','No "highlighted" pixels found in region.'
		goto, done
	endif
	p1 = (*(*pstate).p)[0:i]
	if i lt ((*pstate).n-1) then begin
		p3 = (*(*pstate).p)[i+1:(*pstate).n-1]
	endif else p3 = 0L

	progress, tlb=progress_tlb, title='Hot-spot neighbourhood analysis'

	a = bytarr( (*p).nx, (*p).ny)
	a[*(*p).q] = 1B									; hot pixels

	a2 = a
	s = round_kernel(w)								; kernel for dilate
	s2 = round_kernel(2*w)							; kernel for neighbourhood expand
	a0 = dilate(a2,s2)								; expand hot pixels so we don't include transition pixels
	q0 = where(a0 eq 1, n0)							; indices into hot exclusion zone

	b = 1B - a										; Invert the map

;	Use watershed function to find distinct index for each watershed
	c = watershed( b)

;	Number of distinct 'watersheds' or particles
	n = max(c)

	progress, /update, progress_tlb, {unit:0, value:0, current:1, size:n}, cancel=cancel
	if cancel then goto, done

	warning,'OnButton_Image_Table_HotSpot_Neighbourhood',['Found '+str_tidy(n)+' distinct particles or "watersheds".', $
			'Select "Cancel" to cancel, or "OK" to continue.'], cancel=cancel
	if cancel then goto, done

	for j=1,n do begin
		progress, /update, progress_tlb, {unit:0, value:0, current:j, size:n}, cancel=cancel
		if cancel then goto, done

		qi = where( (c eq j) and (a eq 1), ni)		; pixels for watershed index 'j'
		if ni ge 1 then begin
			copy_pointer_data, p, pi, /init			; clone region pointer data

			a2[*] = 0
			a2[qi] = 1B								; hot pixels for hotspot 'j'
			a2 = dilate(a2,s2)						; expand hot pixels so we don't include transition pixels
			b = dilate(a2,s2)						; expand some more out into neighbourhood pixels
			b2 = b - a2								; just neighbourhood pixels
			b2[q0] = 0								; exclude all hot-pixel exclusion zone

			qj = where(b2 eq 1, nj)
			*(*pi).q = qj							; set the neighbourhood pixels for this index
			if j eq 1 then begin
				p2 = pi
			endif else begin
				p2 = [p2,pi]
			endelse
		endif
	endfor

	p = p1	
	if ptr_valid(p3[0]) then p=[p,p3]
	p = [p,p2]										; append p2 list at end after p3
	*(*pstate).p = p
	(*pstate).n = n_elements( *(*pstate).p)

	for i=0, (*pstate).n-1 do begin
		(*p[i]).index = i							; reset index values
	endfor

;	new_table_pselect, pstate, 0
	notify, 'image-region-clear', from=event.top
	notify, 'image-region-update', from=event.top
	(*pstate).file_valid = 0
	*(*pstate).pregions = 0L						; regions do not match spectra anymore
	notify, 'image-regions', (*pstate).pregions, from=event.top

	file = (*pstate).file
	if file[0] eq '' then file=strip_file_ext((*(*(*pstate).p)[0]).file) + '.region'

	file = strip_file_ext(file) + '.region'
	remove = ['-hotspots','-neighbourhood','-q1']
	add = '-hotspots-neighbourhood'
	if strlen(stub) ne 0 then begin
		remove = [remove, '-'+stub]
		add = add + '-'+stub
	endif
	add = add + '-q1'
	(*pstate).file = strip_file_keys( file, remove=remove, element=1, add=add)
done:
	progress, /complete, progress_tlb, 'Update ...'
	progress, /ending, progress_tlb
	return
end

;---------------------------------------------------------------------

function image_table_hotspots_gui_plugin, tab_panel, pstate_parent

;	Plugin to add a Hotspot tab to the Image Table GUI
;
;	Will set the 'minimal_centroid_element' widget ID in pstate_parent to the local hotspot_element ID.


; ---------------- Hotspots  -------------------------------------------------------------------

	geo = widget_info( tab_panel, /geometry)

	hot_base = widget_base( tab_panel, title=' Hotspots ', /column, xpad=0, ypad=1, space=3, $
								/align_center, /base_align_center, scr_xsize=geo.scr_xsize)

	h0base = widget_base( hot_base, /row, /base_align_center, ypad=0, xpad=0, space=10)

	hot_Base2 = Widget_Base( h0base, UNAME='Image_Table_HButton_Base' ,/ALIGN_CENTER ,/BASE_ALIGN_CENTER, SPACE=1 ,XPAD=0 ,YPAD=0 , /ROW, uvalue='')

	label = Widget_label(hot_Base2, value='Element:')

	hotspot_element = Widget_text(hot_Base2, /edit, scr_xsize=60, /tracking, uname='Hotspots_Text', uvalue='Enter the element name (e.g. "Au") to be used to calculate XY position centroids, which will be added to the construction of an output file-name along with function dependent key-words (e.g. "-hotspots").')

	hotspot_Button = Widget_Button(h0base, /tracking,  $
		UNAME='Hotspots_Button' ,/ALIGN_CENTER ,VALUE='Hotspot separation', uvalue='Separate highlighted pixels in selected region into separate hotspot regions and append them to the table. ' + $
		'Select the row with ALL hot-spots as Association highlights. Remember to enter the element name that selects the XY centroids to use.')

	Neighbourhoods_Button = Widget_Button(h0base, /tracking,  $
		UNAME='Neighbourhoods_Button' ,/ALIGN_CENTER ,VALUE='Neighbourhoods', uvalue='Separate hotspots and determine their immediate neighbourhood pixels as new regions and append them to the table. ' + $
		'Select the row with ALL hot-spots as Association highlights. Remember to enter the element name that selects the XY centroids to use.')

	Save_Button2 = Widget_Button(h0base, /tracking,  $
		UNAME='Save_Button' ,/ALIGN_CENTER ,VALUE='Save', uvalue='Save regions to a REGION file. Must save before using "Extract spectra".')

	Export_centroids_Button = Widget_Button(h0base, /tracking,  $
		UNAME='Export_Centroids_Button' ,/ALIGN_CENTER ,VALUE='Export (w/ centroids)', uvalue='Export regions (w/ centroids based on "Element") for selected element columns to a CSV file. You will be prompted for element columns to include.')

  
	WIDGET_CONTROL, hot_base, EVENT_FUNC = 'image_table_hotspots_gui_plugin_event'
  
	state = {	pstate_parent:	pstate_parent, $	; pstate in image_table parent	

			group:		tab_panel, $		; Hotspot tab parent TLB
			tlb:		hot_base, $			; TLB ID
			hotspot_element: hotspot_element} ; hotspot element text ID
  
	child = widget_info( hot_base, /child)
	pstate = ptr_new(state, /no_copy)
	widget_control, child, set_uvalue=pstate

	(*pstate_parent).minimal_centroid_element = hotspot_element
	return, hot_base
end

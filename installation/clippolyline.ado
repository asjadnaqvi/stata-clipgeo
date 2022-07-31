*! clippolyline v1.1 Asjad Naqvi 31Jul2022
* Clip polyline vectors based on a custom bounding box


cap program drop clipline


***********************
// 	  clippolyline   //
***********************

program define clippolyline, eclass
	version 15
	
	syntax namelist(max=1), Box(numlist min=4 max=4)
	
	*** checks

	// check gtools
	capture findfile gtools.ado
	if _rc != 0 {
		display as error "gtools package is missing. Click here to install: {stata ssc install clipline, replace}"
		exit
	}		
	
	
	
	capture confirm file "`namelist'.dta"
	if _rc {
	   di as err "{p}File {bf:`namelist'} not found{p_end}"
	   exit 601
	}	
		

	// push the bounds to locals	
	tokenize `box'		
		local xmin = `1'	
		local xmax = `2'
		local ymin = `3'
		local ymax = `4'
	
		if `xmax' < `xmin' {
			di as error "xmax < xmin. Please make sure the coordinates are specified in the correct order."
			exit
		}
		
		if `ymax' < `ymin' {
			di as error "ymax < ymin. Please make sure the coordinates are specified in the correct order."
			exit
		}
				
		
		

// main routine	
	
qui {
	preserve	
		
		use "`namelist'.dta", clear
		
		count if shape_order > 3
		
		if r(N) > 0 {
			noisily di in red "`namelist' is not a valid polyline file. It contains polygons. Try {bf:clipolygon} instead."
			exit
		}
	
	
	
		// check if the box is valid (v1.1)
		
		cap drop box
		gen  box = 1 if inrange(_X, `xmin', `xmax') & inrange(_Y, `ymin', `ymax')


		bysort group: egen double boxcheck = mean(box)
		drop if boxcheck==.
		drop boxcheck	
		drop box
		sort _ID shape_order		
		
		count 
		
		if `r(N)' == 0 {
			di as error "No shapes are contained within the box. Please check the box bounds."
			exit
		}	
	
	
	
		keep _ID _X _Y shape_order		
		drop if shape_order==1

		// convert to line coordinates
		greshape wide _X _Y, i(_ID) j(shape_order)


		// call clipline program
		local box2: subinstr local box " " ", ", all
		clipline _X2 _Y2 _X3 _Y3, box(`box2')


		cap drop clip*

		gen clip_X2 = .
		gen clip_Y2 = .

		gen clip_X3 = .
		gen clip_Y3 = .

		mata: clipdata = .
		mata: st_view(clipdata, .,"clip_X2 clip_Y2 clip_X3 clip_Y3")
		mata: cliplist2 = ((1::rows(cliplist)), cliplist)
		mata: clipdata[cliplist2[.,1], .] = cliplist2[.,2::5]

		drop if clip_X2 ==.
		drop _X2 _Y2 _X3 _Y3

		gen clip_X1 = .
		gen clip_Y1 = .


		greshape long clip_X clip_Y, i(_ID) j(shape_order)

		ren clip* *
		order _ID _X _Y shape_order

		sort _ID shape_order

		compress
		save "`namelist'_clipped.dta", replace

	restore
}	

	di in green "Done! File exported as `namelist'_clipped.dta"

	
end	
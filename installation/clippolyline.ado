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


		bysort _ID: egen double boxcheck = mean(box)
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





cap program drop clipline

*********************
// 	   clipline    //
*********************

program define clipline, sortpreserve
	version 15
	syntax varlist(min=4 max=4 numeric), 	///
		[Box(numlist min=4 max=4)] 			///	  // manually define the bounding box 	
		[OFFset(real 0)] 					///   // manually define the offset of the box
		[lines] 							///   // export lines inside the box
		[addbox]								  // export bounding box coordinates	
	
	di in green "clipline: Initializing"
	
	// get the variables
	tokenize "`varlist'"
	local x1 `1'
	local y1 `2'
	local x2 `3'
	local y2 `4'
	
	
	mata: points = st_data(.,("`x1'", "`y1'", "`x2'", "`y2'"))

	
	mata: xmin = .
	mata: xmax = .
	mata: ymin = .
	mata: ymax = .	
	
	
	// bounding box
	//di in green "clipline: Bounding box"
	
	if "`box'" != "" {
        local box2: subinstr local box " " ", ", all
		mata: getmanbounds(points,`box2',xmin,xmax,ymin,ymax,`offset')	
	}
	else {
		mata: getautobounds(points,xmin,xmax,ymin,ymax,`offset') 
	}
	
	
	//mata: xmin,xmax,ymin,ymax

	
	mata: cliplist = clipline_core(points, xmin, xmax, ymin, ymax)
	di in green "clipline: Finished"
		
	//cliplist	
	
	if "`lines'" != "" {
		mata: st_local("newobs", strofreal(rows(cliplist)))

		if `newobs' > _N {
			set obs `newobs'
		}
		
		cap drop clip*	
		mata: st_matrix("clip",cliplist)
		mat colnames clip = "clip_x1" "clip_y1" "clip_x2" "clip_y2"

		svmat clip, n(col)
		
		di in green "clipline: Clipped lines exported back to Stata"
	}
	
	if "`addbox'" != "" {
		cap drop box*

		qui {
			gen box_x = .
			gen box_y = .
			
			replace box_x = xmin in 1
			replace box_y = ymin in 1

			replace box_x = xmin in 2
			replace box_y = ymax in 2
			
			replace box_x = xmax in 3
			replace box_y = ymax in 3
			
			replace box_x = xmax in 4
			replace box_y = ymin in 4
			
			replace box_x = xmin in 5
			replace box_y = ymin in 5		
		}

		di in green "clipline: Box exported back to Stata"
	}
	
	
end


************************
// 	  clipline_core	  //		
************************


cap mata: mata drop clipline_core()

mata // clipline_core
function clipline_core(points, xmin, xmax, ymin, ymax)
{
	cliplist = J(rows(points),4,.)
	
	for (i=1; i <= rows(points); i++) {			
		cliplist[i,.] = cliproutine(points[i,1], points[i,2], points[i,3], points[i,4], xmin, xmax, ymin, ymax)	
		}
			
	return(cliplist)
}
end


********************
//  getmanbounds  //		
********************

cap mata: mata drop getmanbounds()

mata // getmanbounds
void getmanbounds(points, xlo, xhi, ylo, yhi, xmin, xmax, ymin, ymax, real scalar value)
{
	
	
	
	displacex = abs((xhi - xlo) * value)
	displacey = abs((yhi - ylo) * value)

	xmin 	  = xlo + displacex
	xmax 	  = xhi - displacex

	ymin 	  = ylo + displacey
	ymax 	  = yhi - displacey

	
	// pass them to stata scalars for drawing later
	st_numscalar("xmin", xmin)
	st_numscalar("xmax", xmax)

	st_numscalar("ymin", ymin)
	st_numscalar("ymax", ymax)

}

end



************************
//  getautobounds	  //		
************************

cap mata: mata drop getautobounds()

mata // getautobounds
void getautobounds(points,xmin,xmax,ymin,ymax,real scalar value)
{
	real matrix mymat
	mymat = colshape(points,2)
	
	displacex = abs((max(mymat[.,1]) - min(mymat[.,1])) * value)
	displacey = abs((max(mymat[.,2]) - min(mymat[.,2])) * value)

	xmin 	  = min(mymat[.,1]) + displacex
	xmax 	  = max(mymat[.,1]) - displacex

	ymin 	  = min(mymat[.,2]) + displacey
	ymax 	  = max(mymat[.,2]) - displacey

	
	// pass them to stata scalars for drawing later
	st_numscalar("xmin", xmin)
	st_numscalar("xmax", xmax)

	st_numscalar("ymin", ymin)
	st_numscalar("ymax", ymax)
}
end

********************
//  cliproutine	  //		
********************

cap mata: mata drop cliproutine()
mata:  // cliproutine
	function cliproutine(x1, y1, x2, y2, minX, maxX, minY, maxY)  
	{
		real scalar code1, code2, accept, x, y

		// Defining region codes 
		LEFT   = 1  // 0001 
		RIGHT  = 2  // 0010 
		BOTTOM = 4  // 0100 
		TOP    = 8  // 1000 
		
		
		code1 = computeCode(x1, y1, minX, maxX, minY, maxY)
		code2 = computeCode(x2, y2, minX, maxX, minY, maxY)
		
		accept = 0
		t = 0 // counter
		
		zz = 0
		while (zz == 0)  {
		
			// If both endpoints lie within rectangle 
			if (code1 == 0 & code2 == 0) {
				accept = 1
				break
			}
			// If both endpoints are outside rectangle 
			else if (code1==code2 & code1!=0 & code2!=0) {
				accept = 0
				
				x1 = .
				y1 = .
				x2 = .
				y2 = .	
				break
			}
			
			// Some segment lies within the rectangle 			
			else {	
				x = 1
				y = 1
				
				if (code1 != 0) {
					codeout = code1
				}
				else {
					codeout = code2
				}
				
				// point is above the clip rectangle 
				if      (codeout >= TOP) {   		
					x = x1 + ((x2 - x1) * (maxY - y1) / (y2 - y1))
					y = maxY
				}
				
				// point is below the clip rectangle
				else if (codeout >= BOTTOM) {
					x = x1 + ((x2 - x1) * (minY - y1) / (y2 - y1))
					y = minY
				}
				
				// point is to the right of the clip rectangle 
				else if (codeout >= RIGHT) {
					y = y1 + ((y2 - y1) * (maxX - x1) / (x2 - x1))
					x = maxX
				}
				
				// point is to the left of the clip rectangle 
				else if (codeout >= LEFT) {
					y = y1 + ((y2 - y1) * (minX - x1) / (x2 - x1))
					x = minX
				}	
				
			if (codeout == code1) { 
                x1 = x 
                y1 = y 
                code1 = computeCode(x1, y1, minX, maxX, minY, maxY) 
			}
			else {
                x2 = x 
                y2 = y 
                code2 = computeCode(x2, y2, minX, maxX, minY, maxY) 
			}
		
		t = t + 1
		if (t > 100) {
		//	printf("bad egg\n")
				x1 = .
				y1 = .
				x2 = .
				y2 = .
			break
			}
		
		}

	}
			
	return(x1,y1,x2,y2)
}
end




*********************
// 	 computeCode   //
*********************

cap mata: mata drop computeCode()
mata // computeCode
	function computeCode(xx, yy, minX, maxX, minY, maxY)  
	{
		real scalar code
		code = 0   // 1 = left, 2 = right, 4 = bottom, 8 = top (binary)
			if (xx < minX) code = code + 1
			if (xx > maxX) code = code + 2		
			if (yy < minY) code = code + 4
			if (yy > maxY) code = code + 8	
		return(code)
	}
end



**** END OF CLIPLINE ****








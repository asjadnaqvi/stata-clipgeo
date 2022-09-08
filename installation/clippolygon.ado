*! clippolygon v1.3 Asjad Naqvi 08Aug2022

* v1.0: first release. Consolidation of different packages
* Sutherland-Hodgman polygon clipping algorithm
* Asjad Naqvi (asjadnaqvi@gmail.com)



cap program drop clippolygon


********************
// 	clippolygon   //
********************

program define clippolygon, // sortpreserve eclass
	version 15
	
	syntax namelist(max=1), ///
		Method(string) 	///  				// method is box or circle
		[ Box(numlist min=4 max=4) ] /// 	// box options
		[ XMid(real 0) YMid(real 0) Radius(real 5) Points(real 60) Angle(real 0)  ]  // circle options
	
	*** checks

	// check gtools
	capture findfile gtools.ado
	if _rc != 0 {
		di as err "gtools package is missing. Click here to install: {stata ssc install gtools, replace}"
		exit
	}	
	
	// carryforward
	capture findfile carryforward.ado
	if _rc != 0 {
		di as err "carryforward package is missing. Click here to install: {stata ssc install carryforward, replace}"
		exit
	}	
	
	
	capture confirm file "`namelist'.dta"
	if _rc {
	   di as err "{p}File {bf:`namelist'} not found{p_end}"
	   exit 601
	}	

	
	capture confirm file "`namelist'.dta"
	if _rc {
	   di as err "{p}File {bf:`namelist'} not found{p_end}"
	   exit 601
	}	
	
	if ("`method'" != "box" & "`method'" !="circle") {
		di as error "Valid method options are {it:box} or {it:circle}."
	}	
	
		
	// push the bounds to locals	
	
	if ("`method'" == "box")  {
	
	
		if "`box'" == "" {
			di as error "The option {it:box()} must be specified."
			exit 601
		}	
	
	
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
		
		mata: box = `xmin', `ymin' \ `xmin', `ymax' \ `xmax', `ymax' \ `xmax', `ymin' \ `xmin', `ymin'	
	
	}
	
	
	if ("`method'" == "circle") {
			
			mata: box = returnbounds(`xmid', `ymid', `radius', `angle', `points') 
			
			mata: st_local("xmin", strofreal(min(box[.,1])))
			mata: st_local("xmax", strofreal(max(box[.,1])))

			mata: st_local("ymin", strofreal(min(box[.,2])))
			mata: st_local("ymax", strofreal(max(box[.,2])))
			
	}	
	
	
	
// main routine	

qui {
	preserve	
		use "`namelist'.dta", clear

		
		// separate out the islands

		cap drop markme 
		cap drop group

		sort _ID shape_order
		bysort _ID: gen markme = _n if _X==.

		sort _ID markme
		gen group = _n if markme!=.

		drop markme	
		sort _ID shape_order	
		carryforward group, replace	
		
		cap drop box
		gen  box = 1 if inrange(_X, `xmin', `xmax') & inrange(_Y, `ymin', `ymax')

		// mark empty _IDs and throw them out

		cap drop temp
		by _ID: egen temp = mean(_X)	
		drop if temp==.
		drop temp
		
		// throw out the shapes that are completely outside the box

		bysort group: egen double boxcheck = mean(box)
		drop if boxcheck==.
		drop boxcheck	
		drop box
		sort _ID shape_order		
		
		count 
		
		if `r(N)' == 0 {
			di as error "No shapes are contained within the clipping boundary. Please check the bounds."
			exit
		}
		
		
		// mark shapes that are completely inside the box and leave them as they are

		cap drop markme
		gen markme = . 

	
			tempvar minx maxx miny maxy
		
			bysort group: egen double `minx' = min(_X)
			bysort group: egen double `maxx' = max(_X)
			
			bysort group: egen double `miny' = min(_Y)
			bysort group: egen double `maxy' = max(_Y)
			
			
				if ("`method'" == "box") {
					qui replace markme = 1 if (`minx' >= `xmin') & (`maxx' <= `xmax') &  (`miny' >= `ymin') & (`maxy' <= `ymax') 			
				}

		
				if ("`method'" == "circle") {
				
					
					local inradius = `radius' * cos(_pi / `points')
					
					tempvar mark
					gen `mark' = 0
					
					replace `mark' = `mark' + 1 if (sqrt((`maxx' - `xmid')^2 + (`maxy' - `ymid')^2) < `inradius')  
					replace `mark' = `mark' + 1 if (sqrt((`minx' - `xmid')^2 + (`maxy' - `ymid')^2) < `inradius')  
					replace `mark' = `mark' + 1 if (sqrt((`maxx' - `xmid')^2 + (`miny' - `ymid')^2) < `inradius')  
					replace `mark' = `mark' + 1 if (sqrt((`minx' - `xmid')^2 + (`miny' - `ymid')^2) < `inradius')  
					
					qui replace markme = 1 if `mark'==4 
					
				}
			
	
		
		// save here as a tempfile since we cannot preserve twice
		
		drop `minx' `maxx' `miny' `maxy' 
		cap drop `mark'
		
		sort _ID shape_order group
		tempfile _polysample
		save "`_polysample'", replace
		
				
		// store the shapes that are fully inside in a separate file. This speeds up teh calculations
		keep if markme==1	
		drop markme
		tempfile _polyinside
		save "`_polyinside'", replace		
		
		
		// continue with the shapes that intersect with the box
		use "`_polysample'", clear
		
		
		di "Values to be dropped"
		count if markme==1
		
		
		drop if markme==1
		drop markme
		
		
		di "Values left"
		count


		// start the procedure here. Each island needs to be processed separately.
		
		cap gen double clip_x = .
		cap gen double clip_y = .
		cap gen double id = .
		cap gen double group = .
		
		
		mata: points   = st_data(., ("_X", "_Y", "_ID", "group"))
		mata: myindex  = uniqrows(points[.,4])
		mata: myindex  = select(myindex, (myindex[.,1] :< .)) 
		mata: clipbox  = returnclip(points, myindex, box)
		mata: st_local("newobs", strofreal(rows(clipbox)))
		
			
		// expand observations (automate this for the custom data range)
			if `newobs' > _N {
				set obs `newobs'
			}

			if `newobs' > 1 {
				getmata (clip_x clip_y id group shape_order) = clipbox, force double replace
			}


		keep clip_x clip_y id group shape_order

		drop if id==.
		ren id _ID
		ren clip_x _X
		ren clip_y _Y
		gen clipped = 1		
		
		append using "`_polyinside'" // add back the inside polygons
		

		
		order _ID _X _Y group shape_order
		sort _ID group shape_order 

		compress		
		save "`namelist'_clipped.dta", replace	
	restore
 }	

	di in green "Done! File exported as `namelist'_clipped.dta"


end	


**************************
//   Mata subroutines   //
**************************


******************
//  returnclip  //		
*****************
		
cap mata: mata drop returnclip()

mata:
function returnclip(data, index, box) 
{	
	mycoords = J(1,5,.)

	for (i=1; i <= rows(index); i++) {
		
		
		mysubset = select(data, data[.,4] :== index[i] )
		mysubset = select(mysubset, (mysubset[.,1] :< .)) 
		
		myclips = clipme(mysubset, box)
	
		if (rows(myclips) > 1) {
			
			myclips[1,3] = myclips[2,3]
			myclips[1,4] = myclips[2,4]
			myclips =  myclips   \ ., .,  myclips[2,3], myclips[2,4] //   ., .,  myclips[2,3], myclips[2,4] 
			
			myclips = myclips, (1::rows(myclips))   
			mycoords = mycoords \ myclips 
			
		}
	
	}

	return (mycoords)
}
end


**********************
//  returnbounds	//		
**********************

cap mata: mata drop returnbounds()
mata:  // returnbounds
	function returnbounds(x, y, r, a, o)  // xmid, ymin, radius, angle, obs
	{
		theta  = J(o,1,.)
		
		for (i=1; i <= o; i++) {	
			theta[i] = i * -2 * pi() / o
		}
		
		coords = cos(theta) :* r, sin(theta) :* r
		ro = -1 * a * pi() / 180
		rotation = (cos(ro), -sin(ro) \ sin(ro), cos(ro))
		coords = (coords * rotation') :+ (x, y)
		coords = coords \ coords[1,.]
		
		return (coords)
		
	}
end

********************
//  is_inside	  //		
********************

cap mata: mata drop is_inside()
mata:  // is_inside
	function is_inside(p1,p2,q)  // clip point start, clip point end, point to be evaluated
	{
		scalar R
		R = (p2[.,1] - p1[.,1]) * (q[.,2] - p1[.,2]) - (p2[.,2] - p1[.,2]) * (q[.,1] - p1[.,1])
		return (R <= 0)
	}
	
end


****************************
//  compute_intersection  //		
****************************

cap mata: mata drop compute_intersection()
mata:  // compute_intersection

	function compute_intersection(p1,p2,p3,p4)  // 
	{
		
		scalar x, m2, b2, y, m1, b1
		vector intersection
		
        // if first line is vertical
		if (p2[.,1] - p1[.,1] == 0) {        
			
			x = p1[.,1]
			m2 = (p4[.,2] - p3[.,2]) / (p4[.,1] - p3[.,1])
			b2 = p3[.,2] - m2 * p3[.,1]
			y = m2 * x + b2
        }
		
        // if second line is vertical
		else if (p4[.,1] - p3[.,1] == 0) {
            
			x = p3[.,1]
			m1 = (p2[.,2] - p1[.,2]) / (p2[.,1] - p1[.,1])
			b1 = p1[.,2] - m1 * p1[.,1]
			y = m1 * x + b1
        }
		
        // if neither line is vertical
        else {
           
			m1 = (p2[.,2] - p1[.,2]) / (p2[.,1] - p1[.,1])
			b1 = p1[.,2] - m1 * p1[.,1]
			
			m2 = (p4[.,2] - p3[.,2]) / (p4[.,1] - p3[.,1])
			b2 = p3[.,2] - m2 * p3[.,1]
        
			x = (b2 - b1) / (m1 - m2)    
			y = m1 * x + b1
		}
        
		intersection = (x, y, p1[.,3], p1[.,4]) 
        return (intersection)
	}
end
		

		
**************
//  clipme  //		
**************
		
cap mata: mata drop clipme()
mata:  // clipme

	function clipme(subpoly,clippoly) 
	{		
		
	scalar i, j, cedge1, cedge2, sedge1, sedge2
	matrix finalpoly, nextpoly, intersection
	
	finalpoly = subpoly	
	
	
		for (i=1; i <= rows(clippoly) - 1; i++) {			
		
			if (finalpoly[.,1]!=.) {
				finalpoly   = select(finalpoly, (finalpoly[.,1] :< .))
			}
		
			finalpoly   = finalpoly \ finalpoly[1.,]
			nextpoly = finalpoly
			finalpoly = J(1, 4, .)  
	
			cedge1 = clippoly[i    , .]
			cedge2 = clippoly[i + 1, .]		
		
			for (j=1; j <= rows(nextpoly) - 1; j++) {			
			
				sedge1 = nextpoly[j    , .]
				sedge2 = nextpoly[j + 1, .]		
						
				if (is_inside(cedge1,cedge2,sedge2) == 1) {
					if (is_inside(cedge1,cedge2,sedge1) == 0) {
						intersection = compute_intersection(sedge1, sedge2, cedge1, cedge2)						
						finalpoly = finalpoly \ intersection
					}
					finalpoly = finalpoly \ sedge2
				}
				else if (is_inside(cedge1,cedge2,sedge1) == 1) {					
					intersection = compute_intersection(sedge1, sedge2, cedge1, cedge2)
					finalpoly = finalpoly \ intersection
				}						
			}
		}
		
		// if have a line, clean it up
		if (rows(finalpoly) == 4) {
			if (finalpoly[2,1]!=finalpoly[3,1] & finalpoly[2,2]!=finalpoly[3,2]) {
				return (finalpoly[1::rows(finalpoly) - 1, .])
			}
		}
		else {
			return (finalpoly)
		}
	}
end	

****************************
***     END OF FILE      ***
****************************


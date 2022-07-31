*! clippolygon v1.2 Asjad Naqvi 31May2022

* v1.0: first release. Consolidation of different packages
* Sutherland-Hodgman polygon clipping algorithm
* Asjad Naqvi (asjadnaqvi@gmail.com)



cap program drop clippolygon


********************
// 	clippolygon   //
********************

program define clippolygon, sortpreserve eclass
	version 15
	
	syntax namelist(max=1), Box(numlist min=4 max=4)
	
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
		

		
		// add the box in Mata
		mata: box = `xmin', `ymin' \ `xmin', `ymax' \ `xmax', `ymax' \ `xmax', `ymin' \ `xmin', `ymin'	
	
	
	
	// noi di "Here 1"
	
	
// main routine	

qui {
	preserve	
		use "`namelist'.dta", clear

		
		// check if box bounds are legitmate or not		
		// they should contain at least one shape
		
		// noi di "Here 1"
		
		summ _X, meanonly
		local _shpxmin = r(min)
		local _shpxmax = r(max)
		
		summ _Y, meanonly
		local _shpymin = r(min)
		local _shpymax = r(max)
		

		
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
			di as error "No shapes are contained within the box. Please check the box bounds."
			exit
		}
		
		
		
		// mark shapes that are completely inside the box and leave them as they are

		cap drop markme
		gen markme = . 

		qui levelsof group, local(lvls)

		foreach x of local lvls {
			
			qui summ _X if _X!=. & group==`x'
			local minx = r(min)
			local maxx = r(max)

			qui summ _Y if _Y!=. & group==`x'
			local miny = r(min)
			local maxy = r(max)
				
			qui replace markme = 1 if (`minx' >= `xmin') & (`maxx' <= `xmax') &  (`miny' >= `ymin') & (`maxy' <= `ymax') & group==`x'
		}		
	
		
		// save here as a tempfile since we cannot preserve twice
		tempfile _polysample
		save "`_polysample'", replace
		
				
		// store the shapes that are fully inside in a separate file. This speeds up teh calculations
		keep if markme==1
		
		
		drop markme
		tempfile _polyinside
		save "`_polyinside'", replace		
		
		
		
		// continue with the shapes that intersect with the box
		use "`_polysample'", clear
		drop if markme==1
		drop markme
		


		// start the procedure here. Each island needs to be processed separately.

		levelsof group, local(lvls)

		foreach x of local lvls {		

			cap drop touse
			gen touse = group==`x'		
			cap gen double clip_x`x' = .
			cap gen double clip_y`x' = .
			cap gen double id`x' = .
			cap gen double group`x' = .

			mata: points   = st_data(., ("_X", "_Y", "_ID", "group"), "touse")
			mata: points   = select(points, (points[.,2] :< .)) 
			mata: clipbox  = clipme(points, box)
			mata: st_local("newobs", strofreal(rows(clipbox)))

		// expand observations (automate this for the custom data range)
			if `newobs' > _N {
				set obs `newobs'
			}

			if `newobs' > 1 {
				getmata (clip_x`x' clip_y`x' id`x' group`x') = clipbox, force double replace
			}
		}

		keep clip* id* group*
		drop group
		gen shape_order = _n
		order shape_order

		foreach x of varlist clip* id* group* {
			sum `x'
			if `r(N)' ==0 {
				drop `x'
			}
		}

		foreach x of varlist id* group* {
			replace `x' = `x'[_n+1] if `x'==.
			replace `x' = `x'[_n+1] if `x'==.
			replace `x' = `x'[_n+1] if `x'==.
		}

		greshape long clip_x clip_y id group, i(shape_order) j(temp)
		drop temp

		ren id _ID
		ren clip_x _X
		ren clip_y _Y
		
		append using "`_polyinside'" // add back the inside polygons
		

		order _ID _X _Y group shape_order
		sort _ID group shape_order

		drop if _ID==.
		
		compress		
		save "`namelist'_clipped.dta", replace	
	restore
}	

	di in green "Done! File exported as `namelist'_clipped.dta"


end	




**************************
//   Mata subroutines   //
**************************


********************
//  is_inside	  //		
********************

cap mata: mata drop is_inside()
mata:  // is_inside
	function is_inside(p1,p2,q)  // clip point start, clip point end, point to be evaluated
	{
		scalar R
		R = (p2[.,1] - p1[.,1]) * (q[.,2] - p1[.,2]) - (p2[.,2] - p1[.,2]) * (q[.,1] - p1[.,1])
		return(R <= 0)
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
        return(intersection)
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
		
			finalpoly   = select(finalpoly, (finalpoly[.,1] :< .)) 
			finalpoly   = finalpoly \ finalpoly[1.,]
		
			nextpoly = finalpoly
			finalpoly = J(1, 4, .)  
	
			cedge1 = clippoly[i    , .]
			cedge2 = clippoly[i + 1, .]		
		
			for (j=1; j <= rows(nextpoly) - 1; j++) {			
			
				sedge1 = nextpoly[j     , .]
				sedge2 = nextpoly[j + 1 , .]		
						
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
		return(finalpoly)
	}
end		
		

****************************
***     END OF FILE      ***
****************************


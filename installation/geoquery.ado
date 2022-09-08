*! geoquery v1.0 Asjad Naqvi 08Sep2022
* query shapefiles for summary statistics



cap program drop geoquery


********************
// 	geoquery   //
********************

program define geoquery, eclass sortpreserve
	version 15
	
	syntax namelist(max=1) [if] [in]  [, OFFset(numlist >=0 ) ]
	
	
	capture confirm file "`namelist'.dta"
	if _rc {
	   di as err "{p}File {bf:`namelist'} not found{p_end}"
	   exit 601
	}		
	

qui { 
 preserve		
	
	marksample touse, strok
	keep if `touse'	
	merge 1:m _ID using "`namelist'.dta"
	drop if _m != 3
	
	
	if "`offset'" == "" local offset 0
	
	summ _X, meanonly

	local xdiff = abs((r(max) - r(min)) * `offset')
	local xmin  = r(min) - `xdiff'
	local xmax  = r(max) + `xdiff'
	local xmid = r(mean)
	

	
	ereturn local xmin  = `xmin' 
	ereturn local xmax  = `xmax' 
	ereturn local xmid  = `xmid'	

	summ _Y, meanonly
	
	local ydiff = abs((r(max) - r(min)) * `offset')
	local ymin = r(min) - `ydiff'
	local ymax = r(max) + `ydiff'
	local ymid = r(mean)
	

	ereturn local ymin  = `ymin' 
	ereturn local ymax  = `ymax' 
	ereturn local ymid  = `ymid'		

	
	// noi di "Here 3"
	local radius = sqrt((`xmax' - `xmid')^2 + (`ymax' - `ymid')^2)
	ereturn local radius = `radius'
	
	// noi di "Here 4"
	local bounds = "`xmin', `xmax', `ymin', `ymax'"
	ereturn local bounds `bounds'
 restore	
}	
	
end
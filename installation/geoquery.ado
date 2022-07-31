*! geoquery v1.0 Asjad Naqvi 31July2022

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

	local _Xdiff = abs((r(max) - r(min)) * `offset')
	local _Xmin  = r(min) - `_Xdiff'
	local _Xmax  = r(max) + `_Xdiff'
	local _Xmean = r(mean)
	

	
	ereturn local _Xmin  = `_Xmin' 
	ereturn local _Xmax  = `_Xmax' 
	ereturn local _Xmean = `_Xmean'	

	summ _Y, meanonly
	
	local _Ydiff = abs((r(max) - r(min)) * `offset')
	local _Ymin = r(min) - `_Ydiff'
	local _Ymax = r(max) + `_Ydiff'
	local _Ymean = r(mean)
	

	ereturn local _Ymin  = `_Ymin' 
	ereturn local _Ymax  = `_Ymax' 
	ereturn local _Ymean = `_Ymean'		

	
	// noi di "Here 3"
	local radius = sqrt((`_Xmax' - `_Xmean')^2 + (`_Ymax' - `_Ymean')^2)
	ereturn local radius = `radius'
	
	// noi di "Here 4"
	local bounds = "`_Xmin', `_Xmax', `_Ymin', `_Ymax'"
	ereturn local bounds `bounds'
 restore	
}	
	
end
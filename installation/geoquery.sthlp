{smcl}
{* 31July2022}{...}
{hi:help geoquery}{...}
{right:{browse "https://github.com/asjadnaqvi/Stata-clipgeo":clipgeo (GitHub)}}

{hline}

{title:GEOQUERY (beta)}

{p 4 4 2}
{cmd:geoquery} calculates the summary statistics of the shapefile and returns bounds that can be directly used in clippolygon and clippolyline.

{p 4 4 2}
The program is intended to be an intermediate program, to support other programs for spatial analysis. 



{marker syntax}{title:Syntax}
{p 8 15 2}
{cmd:geoquery} {it:shapefile} [if] [in], [{cmdab:off:set}({it:num})]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}

{p2coldent : {opt geoquery filename}}The filename must be a valid, mergeable shapefile, otherwise the program will break.{p_end}

{p2coldent : {opt off:set(value)}}Offset defines the how much the box needs to shrink or expand in size. The default value is set at 0 (no change in box size). If we set {it:offset(0.1)} then it implies that bounds on the axes change by 
{it:delta = (max - min) * 0.1}. The new bounds are, {it:xmin = xmin + xdelta, xmax = xmax - xdelta} for the x-axis. Simiarly {it:yxmin = ymin + ydelta, ymax = ymax - ydelta} for the y-axis. {p_end}
{synoptline}
{p2colreset}{...}

{p 4 4 2}
After the command, relevant values are stored in eclass locals. Type {cmd:{it:return list}} to view the estimates.



{title:Psuedo code}

{it:Load the main file}
. use myfile.dta, clear

{it:Query the corresponding shapefile, using conditions and offset}
. geoquery myfile_shp if id==X, offset(0.3)

{it:Display the bounds (optional)}
. return list
. di "`e(bounds)'"

{it:Pass the bounds to the clipolygon or clipolyline command}
. clippolygon myfile_shp, box("`e(bounds)'")

{it:Test the mapped values}
. spmap _ID using myfile_shp_clipped, id(_ID)


See {browse "https://github.com/asjadnaqvi/Stata-clipgeo":GitHub} for actual examples.

{hline}


Keywords: Stata, graphs, maps, query, shapefile
Version: {bf:geoquery} version 1.0
This  release: 31 Jul 2022
First release: 31 Jul 2022
License: {browse "https://opensource.org/licenses/MIT":MIT}

Author: {browse "https://github.com/asjadnaqvi":Asjad Naqvi}
E-mail: asjadnaqvi@gmail.com
Twitter: {browse "https://twitter.com/AsjadNaqvi":@AsjadNaqvi}


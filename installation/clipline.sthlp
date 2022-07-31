{smcl}
{* 02April2022}{...}
{hi:help clipline}{...}
{right:{browse "https://github.com/asjadnaqvi/Stata-clipgeo":clipgeo v1.1 (GitHub)}}

{hline}

{title:CLIPLINE}

{p 4 4 2}
{cmd:clipline} implements the Cohen-Sutherland algorithm in Stata. It takes a set of lines, 
defined by {it:x1 y1 x2 y2} coordinates and clips its on a bounding box. The 
bounding box can be manually defined or automatically generated.

{p 4 4 2}
The program is intended to be an intermediate program, to support other programs that require clipping. 
For example, it is used in the clipping of infinite rays in Voronoi diagrams, or reducing the extent of spatial data. 


{marker syntax}{title:Syntax}
{p 8 15 2}
{cmd:clipline} {it:x1 y1 x2 y2}, [{cmdab:b:ox}({it:x_min x_max y_min y_max})] [{cmdab:off:set}(number)] [lines] [box]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}

{p2coldent : {opt clipline x1 y1 x2 y2}}The lines are defined as coordinate pairs {it:(x1,y1)} and {it:(x2,y2)}. These are represented by four numeric variables. Please make the order sequence of the variables is correct.{p_end}

{p2coldent : {opt b:ox(x_min x_max y_min y_max)}}Manually define the bounding box in the order specified. If no box is set, the minimum and maximum values of the lines are used.{p_end}

{p2coldent : {opt off:set(value)}}Offset defines the how much the box needs to shrink or expand in size. The default value is set at 0 (no change in box size). If we set offset(-0.1) then it implies that bounds on the axes are reduced by {it:delta = (max - min) * 0.1}, and the new bounds are, {it:xmin = xmin + xdelta, xmax = xmax - xdelta} for the x-axis. Simiarly {it:yxmin = ymin + ydelta, ymax = ymax - ydelta} for the y-axis. {p_end}

{p2coldent : {opt lines}}Export the lines back to Stata as new variables {it:clip_x1, clip_y1, clip_x2, clip_y2}. These can be plotted using {it:twoway pcspike}.{p_end}

{p2coldent : {opt box}}Export the coordinates of the box back to Stata as new variables {it:box_x, box_y}. The first coordinate is repeated to allow us to draw a complete line. These can be plotted using the {it:twoway line box_y box_x} option.

{synoptline}
{p2colreset}{...}

{p 4 4 2}
If no options are specified, then nothing is returned. The evaluated clipped lines and box coordinates are stored as Mata matrices that can be recovered later. Type {it:mata mata describe} to view them. 



{title:Test the code}

You can copy the following code in a dofile to run the example:

{space 8}{hline 27} {it:example do-file content} {hline 27}
{cmd}{...}
{* example_start}{...}
	clear
 	set obs 100
	
	gen id = _n
	gen x1 = runiform(1,50)
	gen y1 = runiform(1,50)
	gen x2 = runiform(1,50)
	gen y2 = runiform(1,50)
	
	
	clipline x1 y1 x2 y2, offset(-0.2) lines addbox 

	twoway ///
		(pcspike y1 x1 y2 x2, lw(thin) lc(gs12)) ///
		(pcspike clip_y1 clip_x1 clip_y2 clip_x2, lw(thin)) ///
		(line box_y box_x, lc(black) lw(0.4)) ///
			, legend(off) 

	
	clipline x1 y1 x2 y2, box(5 35 10 40) lines addbox

	twoway ///
		(pcspike y1 x1 y2 x2, lw(thin) lc(gs12)) ///
		(pcspike clip_y1 clip_x1 clip_y2 clip_x2, lw(thin)) ///
		(line box_y box_x, lc(black) lw(0.4)) ///
			, legend(off) 
	
{* example_end}{...}
{txt}{...}

{hline}


Keywords: Stata, graphs, line clipping, Cohen-Sutherland
Version: {bf:clipline} version 1.1
This  release: 02 Apr 2022
First release: 05 Dec 2021
License: {browse "https://opensource.org/licenses/MIT":MIT}

Author: {browse "https://github.com/asjadnaqvi":Asjad Naqvi} (WU Wien and IIASA, Austria)
E-mail: asjadnaqvi@gmail.com
Twitter: {browse "https://twitter.com/AsjadNaqvi":@AsjadNaqvi}


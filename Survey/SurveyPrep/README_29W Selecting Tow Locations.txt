Load Stations for SFA 29 West:

1. In ArcMAP, load all polygons for SFA29W (eg. Y:\INSHORE SCALLOP\Databases\Scallsur\SFA29BottomTypes\survey2014\sdm_29A_low.shp)
2. Use package 'Create Random Points' (Data Management Toolbox) to generate 
	- Choose number of points per polygon (based on station allocation)
	- 1km between tows)
3. Once stations are created for all Subareas and Habitats
	- Move to appropriate bottom (Use previous years OLEX tows and German Bank Raster (Y:\INSHORE SCALLOP\Databases\Scallsur\SFA29BottomTypes\GermanBnk.tif)
		Save*** (must use proper editor tool etc to save... check attribute table to make sure it is updating positional information
		To Update coordinates::: Open attribute table/ right click on column headings and "Calculate geometry" > this will update the coordinates
			Merge all stations into a single layer and export as SFA2024_olex.csv
4. Use 'Convert to olex format_SFA29 Survey.R' to load all into R convert to OLEX formatting
	- Open .gps file with Notepad++ and add information above column headings (use example file from last year)
	- NOTE: ID must be written as "ID----" with appropriate spacing (see previous years file) or conversion won't work properly
5. Use GPS Utility - GPSU Olex File Converter to convert file to OLEX format	
	- freeware version of the software only allows conversion of 20 waypoints
	- registration:
		Licenced to: Amy Glass
		Registration Key: B953E17BD5C0B841	
	GPSU to OLEX	
		Select file > convert
	- choose .gps source file
	- save to .txt target file

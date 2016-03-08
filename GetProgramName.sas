/*
          Name:  GetProgramName

   Description:  Returns the full path and 
                 name of the program currently being used.

          Type:  Documentation

     Arguments:  <none>

  Other Inputs:  <none>

        Output:  A string giving the full path and name of the program.

   Usage Notes:  Will return "Program not found" if running in interactive
                 mode and the program has not yet been saved with a name.

  Calls macros:  <none>

   History:   Date        Init  Comments
              10/2/2008   MAS   Creation   
              10/24/2008  MAS   Corrected so that program names with "-"
                                do not cause failure. 
*/

%Macro GetProgramName;

/*If Running in batch mode, can use sysin*/

%if %quote(%sysfunc(getoption(sysin))) ne %then %sysfunc(getoption(sysin));

/*If running in interactive mode, use sas_execfilepath system variable*/

%else %if %quote(%sysfunc(sysget(sas_execfilepath))) ne 
	%then %quote(%sysfunc(sysget(sas_execfilepath)));

/*If all else fails, just say "Program Name not Found"*/

%else Program Name Not Found;

%mend GetProgramName;



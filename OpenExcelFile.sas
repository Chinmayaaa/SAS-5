/*
          Name:  OpenExcelFile

   Description:  Opens a specified ExcelFile.

          Type:  Excel Interface

     Arguments:  1. Path = the full name of the folder that contains
                    the spreadsheet you want to open.  End with a "\".
                 2. File = the full name of the excel file you want to
                    open.  Include file extension.

  Other Inputs: <none>

        Output: <none>

   Usage Notes:  Can be used to open txt and csv files with Excel.

  Calls macros:  1. OpenExcel

   History:   Date        Init  Comments
              10/8/2008   MAS   Creation
              04/02/2009  MAS   Updated to check to see if file exists
                                before trying to open it.
*/

%Macro OpenExcelFile(Path,File);
%if %sysfunc(fileexist(&path.)) = 0 %then %do;
	%put ERROR: specified path &path. does not exist.  Aborting.;
	%goto quit;
	%end;

%if %sysfunc(fileexist(&path.&file.)) = 0 %then %do;
	%put ERROR: specified file &file. not found in &path.. Aborting.;
	%goto quit;
	%end;

%OpenExcel
data _null_;
	file control;
	put "[open(%bquote("&path.\&file."))]";
run;

%quit:
%mend OpenExcelFile;


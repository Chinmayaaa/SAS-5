/*
          Name:  CloseActiveExcelFile

   Description:  Closes the active open excel file.

          Type:  Excel Interface

     Arguments:  <none>

  Other Inputs:  <none>

        Output:  <none>

   Usage Notes:  1. Will NOT save changes in the spreadsheet being closed.
                 2. Will overwrite any filename "control" that you have
                    assigned.

  Calls macros:  <none>

   History:   Date        Init  Comments
              10/8/2008   MAS   Creation
*/

%Macro CloseActiveExcelFile;

filename control dde "Excel|system";

data _null_;
	file control;
	put "[Error(false)]";
	put "[close]";
run;

%mend CloseActiveExcelFile;




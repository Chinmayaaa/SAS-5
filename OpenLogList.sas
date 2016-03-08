/*
          Name:  OpenLogList
   Description:  This macro will open the log list files 
     Arguments:  If 1 is passed then the log list files are created, if not then the logic is skipped.
  Other Inputs: <none>
        Output: Log and list files are opened in separate SAS tabs.  
   Usage Notes:  
  Calls macros:  None
   History:   Date        Init  Comments
              1/25/2011   ACB   Creation
*/


%macro openLogList(finalFlag);
	%if &finalFlag = 1 %then %do;
		PROC PRINTTO PRINT=PRINT LOG=LOG;
		run;	
		dm "fslist outlog;";
		dm "fslist outlst;";
	%end;
%mend;


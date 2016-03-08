/*
          Name:  SaveLogList

   Description:  This macro will save the log list files 

          Type:  Analysis Dataset Creation

     Arguments:  If 1 is passed then the log list files are created, if not then the logic is skipped.

  Other Inputs: <none>

        Output: Log and list are printed to output directory specified by using outlog and 
				outlst libnames in calling program

   Usage Notes:  

  Calls macros:  None

   History:   Date        Init  Comments
              10/27/2010  ACB   Creation
*/


%macro saveLogList(finalFlag);
	%if &finalFlag = 1 %then %do;
		proc printto print=outlst
					log=outlog
					new;
	 	run;
	%end;
	%else %do;
		PROC PRINTTO PRINT=PRINT LOG=LOG;
		run;
	%end;
%mend;

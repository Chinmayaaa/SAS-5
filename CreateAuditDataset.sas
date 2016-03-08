/*
          Name:  CreateAuditDataset

   Description:  Creates a dataset containing useful 
                 documentation information that can be exported to
                 a spreadsheet.

          Type:  Documentation

     Arguments:  1. AuditDataset = the name you would like the 
                    dataset to have.  Will have ProgramName, 
                    CreatedTime, User, and Computer Variables.

  Other Inputs:  <none>

        Output:  1. The specified "AuditDataset"

   Usage Notes:  <none>

  Calls macros:  1. GetProgramName

   History:   Date        Init  Comments
              11/11/2008  MAS   Creation
              04/08/2009  MAS   Added Computer variable.
*/


%Macro CreateAuditDataset(AuditDataset);
	Data &AuditDataset.;
		format ProgramName $500. CreatedTime datetime20.
			User Computer $100.;
		ProgramName = "%GetProgramName";
		CreatedTime = datetime();
		user = "%sysget(username)";
		Computer = "%sysget(computername)";
	run;
%mend;




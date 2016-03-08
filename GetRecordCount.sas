/*
          Name:  GetRecordCount

   Description:  Returns the number of observations from a SAS dataset.

          Type:  

     Arguments:  1. Dataset = Required argument giving the name of the
                    dataset to be examined.

  Other Inputs:  <none>

        Output:  Returns a number.

   Usage Notes:  Returns a zero if the dataset does not exist.  Also
                 returns a zero if the dataset exists, but has no 
                 records.  Could have "%if %GetRecordCount(patients)
                 >0 %then %do;" in a macro definition.

  Calls macros:  <none>

   History:   Date        Init  Comments
              10/3/2008   MAS   Creation
             
*/

%macro GetRecordCount(Dataset);

%local z1 z2 z3;

/*Check to make sure the dataset exists*/
%if %sysfunc(exist(&Dataset.)) %then %do;
	%let z1 = %sysfunc(open(&Dataset.));
	%let z2 = %sysfunc(attrn(&z1,nobs));
	%let z3 = %sysfunc(close(&z1));
	&z2
	%end;
/*If it does not, return a zero*/
%else 0 

%mend GetRecordCount;


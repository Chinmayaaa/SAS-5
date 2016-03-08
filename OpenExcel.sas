/*
          Name:  OpenExcel

   Description:  Opens a new Excel Session if an existing session
                 is not already open.

          Type:  Excel Interface

     Arguments:  <none>

  Other Inputs:  <none>

        Output:  <none>

   Usage Notes:  <none>

  Calls macros:  <none>

   History:   Date        Init  Comments
              10/8/2008   MAS   Creation
*/


%macro OpenExcel; 
/*Opens a new excel session if an existing session is not
	already open*/
options noxwait noxsync;
filename control dde "Excel|system";

data _null_;
length fid rc start stop time 8;
/*test to see if excel is already open*/
fid=fopen("control",'s');
/*If it's not, open excel*/
if (fid le 0) then do;
rc=system('start excel'); 
/*Stop waiting once excel opens and give it only
	10 second so no infinite loops result*/
start=datetime();
stop=start+10;
do while (fid le 0); 
fid=fopen("control",'s');
time=datetime();
if (time ge stop) then fid=1;
end;
end;
rc=fclose(fid);
run;
%mend OpenExcel;

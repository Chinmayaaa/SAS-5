/*
          Name:  FlagOutliers

   Description:  Reports on observations that fall more than the
                 specified number of standard deviations from the 
                 mean.

          Type:  Data Cleaning

     Arguments:  1. Dataset = the name of the dataset you want to
                    check.
                 2. Var = the variable you want to examine.  Must be
                    numeric.
                 3. IDVars = space delimited list of variables that
                    you want included in the output aside from the
                    variable you want to examine and the variable(s)
                    you want to group the summary statistics by.
                 4. GroupVars = optional argument that if specified is
                    a space delimited list of variables that you would
                    like to group the summary statistics (mean and
                    standard deviation) by.  For example, you may want
                    to group by race or study site.
                 5. StdDev = the number of standard deviations you want
                    to use when determining which records are outliers.
                 6. OutDataset = optional argument that if specified
                    gives the name of the Dataset that will list the oulier
                    records.  Will have the variables listed by the
                    "IDVars" argument, a "DatasetName" variable, any
                    variables specified by the "GroupVars" argument, and
                    2 variables that give the mean and standard
                    deviation of the variable specified.  These summary
                    statistic variables will be named mean_"Var" and
                    std_"Var".  If this argument is not specified, the 
                    results will be routed to the output window.


  Other Inputs:  <none>

        Output:  <none>

   Usage Notes:  1. The dataset being analyzed is assumed to not have
                    any variables with the name mean_"Var" or
                    std_"Var" where "Var" is the variable being analyzed.
                 2. Missing values for the grouping variables or zero
                    variation in the variable being checked will cause
                    strange results.
                 3. This routine will set any title1 and title2 to blanks
                    after being executed.
                 4. The IDVars and the GroupVars must not have any 
                    variables in common.  Both will be reported in the
                    output dataset.

  Calls macros:  <none>

   History:   Date        Init  Comments
              07/27/2009  MAS   Creation
*/


%Macro FlagOutliers(Dataset,Var,IDVars,GroupVars,StdDev,OutDataset);
/*Check to make sure the dataset exists*/
%if %sysfunc(exist(&Dataset.)) = 0 %then %do;
	%put ERROR: Dataset &dataset. does not exist.  Aborting.;
	%goto quit;
	%end;

%local i j k lvarcount gvarcount;
%let i = 0;
%let j = 0;
%let k = 0;
%let l = 0;

%let varcount = 0;
%let varcount = %eval(%sysfunc(countc(&IDVars.,%str( )))+1);

%let gvarcount = 0;
%let gvarcount = %eval(%sysfunc(countc(&GroupVars.,%str( )))+1);

	title1 "Records from Dataset &Dataset. with &Var. outside &StdDev. standard deviation(s) from the mean";

%if &GroupVars ne %str( ) %then %do;
	title2 "(Grouped by &GroupVars.)";
	%end;

proc sql;
	%if &OutDataset. ne %str( ) %then %do;
		create table &OutDataset. as %end;
	select distinct %do i = 1 %to &Varcount.;
		%scan(&IDVars.,&i.,%str( )), %end; &var., 
		%if &GroupVars. ne %str( ) %then %do;
			%do l = 1 %to &gvarcount.; %scan(&GroupVars.,&l.,%str( )) , %end;
			%end;
		"&Dataset" as DatasetName format = $32.,
		mean(&var.) as mean_&var., std(&var.) as std_&var.
	from &Dataset.
		%if &GroupVars. ne %str( ) %then %do;
		group by %do j = 1 %to &GVarcount.;
			%scan(&GroupVars.,&j.,%str( )) %if &j.<&GVarcount. %then %do; , %end; %end;	
			%end;
		having &var. < (calculated mean_&var. - &StdDev.*calculated std_&var.) or
				&var. > (calculated mean_&var. + &StdDev.*calculated std_&var.)
		order by %do k = 1 %to &Varcount.;
			%scan(&IDVars.,&k.,%str( )) %if &k.<&Varcount. %then %do; , %end; %end;	
	;
quit;

title1 "";
title2 "";

%quit:
%mend;




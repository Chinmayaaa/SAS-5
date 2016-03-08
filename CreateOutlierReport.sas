/*
          Name:  CreateOutlierReport

   Description:  Creates a report on outliers based on an input
                 spreadsheet.

          Type:  Data Cleaning

     Arguments:  1. XLPath = the full path of the folder that contains
                    the excel file.  End in a "\".
                 2. XLFile = the full name of the excel
                    template that contains the requisite information.
                 3. OutputType = Argument in which you specify "HTML" or 
                    "Excel".  If you specify HTML it will create one
                    HTML report.  If you specify "Excel", it will
                    create an Excel spreadsheet with a tab for each
                    dataset.
                 4. OutputFile = The full path and name of the file
                    to be created.  Include the file extension.


  Other Inputs:  <none>

        Output:  <none>

   Usage Notes:  1. Use the I:\Code_Sharing_and_General_Documentation\Code_Sharing_and_Presentations\SAS\SwetzMacros\Code\OutlierReportTemplate.xls
                    template.
                 2. Any dataset on the work library called:
                    tempranges, tempdatasets, _I, _Ivars, where I represents
                    an integer, or Audit may be deleted
                 3. Any filename called xltmp will be deleted.
                 4. Any custom format on the work library with a
                    name like _Itmp where I represents an integer
                    may be deleted.
                 5. Assumes the dataset in question does not have
                    a variable called "VarOutofRange".
                 6. If you're exporting the report to Excel, you may need to 
                    change your default printer.  You'll also need to make sure
                    your dataset(s) do not have more variables than Excel 2003 has
                    columns.

  Calls macros:  1. OpenExcelFile
                 2. CloseActiveExcelFile
                 3. GetProgramName
                 4. CreateAuditDataset
                 5. GetRecordCount

   History:   Date        Init  Comments
              05/06/2009  MAS   Creation 
              05/07/2009  MAS   Added note to log if no record found
                                out of range.
              05/08/2009  MAS   Added error message if there are character
                                variables trying to be range checked.
*/


%macro CreateOutlierReport(xlpath,xlfile,OutputType,OutputFile);
%local Rowcount;
%local DsetCount;
%local a b c d e f g;
%local Varcount;
%local missvars;
%local charvars;

%let Rowcount = 0;
%let DsetCount = 0;

/*Check for the existence of the excel file*/
/*If not found, abort*/
%if %sysfunc(FileExist(&xlpath.&xlfile.)) = 0 %then %do;
	%put ERROR: Specified file &xlfile. does not exist. Aborting.;
	%goto quit;
	%end;

/*Check to see if they correctly specified the OutputType*/
/*%if %upcase(&outputtype.) ne HTML and %upcase(&outputtype.) ne EXCEL %then %do;
	%put ERROR: Invalid argument for OutputType Variable.  Only Excel and html are valid choices.  Aborting.;
	%goto quit;
	%end;
*/

/*Clear conflicting datasets*/

proc datasets lib=work nolist;
	delete tempranges tempdatasets audit;
quit;


/*Read in the Excel File*/
%OpenExcelFile(&xlpath.,&xlfile)

filename xltmp dde "Excel|RowCount!r1c1" notab;

data _null_;
	infile xltmp dlm = '09'x dsd truncover lrecl=100000 firstobs=1;
	input xlrows :best12.;
	call symputx("Rowcount",xlrows);
run;

/*If there are no rows in the spreadsheet, print an error and abort*/
%if &Rowcount = 0 %then %do;
	%put ERROR: No ranges found in specified workbook.  Aborting;
	%CloseActiveExcelFile
	%Goto quit;
	%end;

filename xltmp dde "Excel|Ranges!r1c1:r&Rowcount.c4" notab;

data tempranges;
	infile xltmp dlm ='09'x dsd truncover lrecl=100000 firstobs=2;
		input Dset :$100.
			Variable :$100.
			Range :$100.
			CheckForNulls $5.
			;
run;

proc sort data = tempranges;
	by Dset Variable;
run;

%CloseActiveExcelFile

/*Get a distinct list of the datasets specified*/
proc sql;
	create table tempdatasets as select distinct Dset from
		tempranges
	order by dset;
quit;

data _null_;
	set tempdatasets;
	call symputx("Dset"||Trim(Left(_N_)),dset);
	call symputx("DsetCount",Trim(left(_N_)));
run;

/*For each dataset, test for the existence of the 
	specified dataset.  */
%do a = 1 %to &DsetCount.;
	/*If not found, print an error and go to the next.*/
	%if %sysfunc(exist(&&Dset&a)) = 0 %then %do;
		%put ERROR: Dataset &&Dset&a.. not found.;
		%end;
	
	%else %do;
		%let VarCount = 0;
		%let MissVars = ;
		%let CharVars = ;
		/*If found, get the list of variables and ranges to check.*/

		data _null_;
			set tempranges(where =(upcase(dset) = "%Upcase(&&Dset&a)"));
			call symputx("Var"||trim(left(_N_)),Variable);
			call symputx("Range"||trim(Left(_N_)),Range);
			call symputx("ChkNulls"||trim(left(_N_)),CheckForNulls);
			call symputx("VarCount",trim(left(_N_)));
		run;
		
		/*Create a temporary custom format to check the validity
			of a given variable*/
		proc format;
			%do b = 1 %to &Varcount.;
				value _&b.tmp
					%do c = 1 %to %eval(%sysfunc(countc(%quote(&&Range&b),%str(,)))+1);
						%scan(%quote(&&Range&b),&c.,%str(,)) = "Valid"
						%end;
					%if %upcase(&&ChkNulls&b) ne YES %then %do;
						. = "Valid" %end;

						other = "Invalid"
						;
				%end;
		run;

		/*Check for the possibility that a spreadsheet does not have
		 the correct variables and produce an error message*/

		proc contents data = &&Dset&a out = _&a.vars(keep = name type) noprint;
		run;

		proc sql;
			select distinct variable into :missvars separated by ", "
				from tempranges where 
				upcase(dset) = "%Upcase(&&Dset&a)" and
				upcase(variable) not in (select upcase(name) from
					_&a.vars);
		quit;

		%if &missvars. ne %str( ) %then %do;
			%Put ERROR: Variable(s) &missvars. not found in Dataset &&Dset&a...;
			%end;
				
		/*Print an error if there is a character variable and skip to next
			dataset since if a variable is character, it will not give the
			correct results since it prematurely terminates the datastep.*/

		proc sql;
			select distinct variable into :charvars separated by ", "
				from tempranges where
				upcase(dset) = "%Upcase(&&Dset&a)" and
				upcase(variable) in (select upcase(name) from _&a.vars where
					type = 2);
		quit;

		%if &charvars. ne %str( ) %then %do;
			%put ERROR: Variable(s) &charvars. in Dataset &&Dset&a. is(are) not numeric.  Skipping dataset &&Dset&a...;
			%Goto NextDset;
			%end;

		/*Read through the dataset, outputting any records out of range
		on a given variable*/
			
		data _&a.;
			format VarOutOfRange $50.;
			set &&Dset&a;
			%do d = 1 %to &Varcount.;
				if put(&&Var&d,_&d.tmp.) = "Invalid" then do;
					VarOutOfRange = "&&Var&d";
					output;
					end;
				%end;
		run;

		proc sort data = _&a.;
			by VarOutOfRange;
		run;
		
		/*Print a note if no variables found out of range*/

		%if %GetRecordCount(_&a.) = 0 %then %do;
			%Put WARNING: No records found out of range in dataset &&Dset&a...;
			%end;

		%NextDset:
		/*Delete the temporary formats*/
		proc catalog cat = work.formats;
			%do e = 1 %to &Varcount.;
				delete _&e.tmp.format;
				%end;
		quit;
					
		%end;
	%end;

/*When looped through all the datasets, either create the
	specified report, or spreadsheet*/

%if %upcase(&outputtype.) = HTML %then %do;
	ods html body = "&outputfile";
	footnote f=arial h=10pt "Created by %GetProgramName at %sysfunc(putn(%sysfunc(datetime()),datetime20.)).";
	title "Ranges Used To Flag Invalid Records";

	proc print data = tempranges noobs;
	run;

	%do f = 1 %to &DsetCount.;
		%if %sysfunc(exist(_&f.)) %then %do;
			title "Invalid records from Dataset &&Dset&f";
			proc print data = _&f.;
			run;
			%end;
		%end;
	%end;

%if %upcase(&outputType.) = EXCEL %then %do;
	%CreateAuditDataset(Audit)

	proc export data = Audit outfile = "&OutputFile." replace;
		sheet = "Audit";
	run;

	proc export data = tempranges outfile = "&Outputfile." replace;
		Sheet = "Ranges";
	run;

	%do g = 1 %to &DsetCount.;
		%if %sysfunc(exist(_&g.)) %then %do;
			proc export data = _&g. outfile = "&Outputfile." replace;
				sheet = "&&Dset&g";
			run;
			%end;
		%end;
	%end;

/*Delete intermediate datasets*/
/*
proc datasets lib=work nolist;
	delete tempranges tempdatasets audit %do h = 1 %to &DsetCount.;
		_&h. _&h.vars %end;
		;
quit;
*/


%quit:
%mend;

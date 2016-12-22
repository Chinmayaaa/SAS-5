/*********************************************
*		OnCoreMacros.sas  
*
*		Description: Contains the macros that can be used for OnCore downloaded files.  
*			This file has 4 macros that can referenced:
*			1. TrimTextVars - Trims the length of text variables in work datasets with _FMT extension in the name
*			2. CreateOnCoreFormatFile - Combines all the proc format codes in the .sas file into a single format 
*					file and removes duplicate format names														
*			3. CopySASorTextFiles - Copies the .sas or .txt files extracted from OnCore to a specified location
*			4. RunBatchSASFiles - Runs multiple sas files as %include statements
*			5. InsertID - For Cancer Center studies only.  This creates the USUBJID and SUBJID for all forms and 
*					drops specific variables											
*			6. GetFilenamesFromDir - Referenced in Macros 2 to 4 and returns the filenames in a directory
*			7. InsertStudyID - Creates the STUDYID variable for all data sets (forms)
*			8. TrimTextVariables - Trims the text variables in a single, specified dataset
*			9. CopyOnCoreFilesByExtension - Copies the .sas or .txt files extracted from OnCore to a specified 
*					location (NO PROMPT)
*			10. CopyOnCoreSASFiles - Copies just the .sas files extracted from OnCore to a specified 
*					location (NO PROMPT)
*			11. CopyOnCoreTextFiles - Copies just the .txt files extracted from OnCore to a specified 
*					location (NO PROMPT)
*			12. RemoveLabelColons - Removes ending ':' from all labels in a dataset
*			13. ArchiveSASDatasets - Moves all SAS datasets in one folder to another folder, grouped into a subfolder with
*				the name YYYY-MM-DD, which represents the "creation date" of the datasets
*			14. FixTimeImport - Temporary macro to fix the OnCore bug that imports integers as blank time values
*		
*		NOTE: When passing parameters, make sure there is a "\" at the end of the directory path.
* 		7/22/2014 MGE:  This is an update to OnCoreMacros.sas and should be used when processing the data exports 
				from OnCore version 13.5
*********************************************/


/*Example lines that need to be placed in analysis dataset generation program;
**START**;

%include 'I:\Projects\Cancer\IUSCC\_SAS Macro\OnCoreMacros135.sas' ; 

**AT FIRST EXPORT OF DATA FROM ONCORE:
* 1. Copy the .sas file (enter 1 at prompt);
*			%CopySASorTextFiles(I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\Downloads\,I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\RawData\);
* 2. Create the format file;
*			%CreateOncoreFormatFile(I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\RawData\,I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\Programs\,oncore_formats.sas);

**AT SUCCEEDING EXPORTS OF DATA:
* 1. Copy the .txt file (enter 2 at prompt);
*			%CopySASorTextFiles(I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\Downloads\,I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\RawData\);

**THE FOLLOWING NEED TO BE RUN EVERYTIME THE ANALYSIS DATASETS ARE GENERATED;

*run .sas files exported from OnCore to create the files in work directory;
%RunBatchSASFiles(I:\Projects\Cancer\IUSCC\IUCRO-0000\DataMgt\RawData\);

*trim text variables to the maximum length for each variable based on entered data;
%TrimTextVars();

*add USUBJID and SUBJID to each dataset and exclude specific variables;
%InsertID('0414');

*insert the STUDYID variable on each dataset from the Batch Run ;
%InsertStudyID('0414');

**END**;
*/



	
/*********************************************
MACRO #1:	TrimTextVars
		Description:  
				Trims the length of text variables in work datasets. Should be run only after RunBatchSASFiles
				as this references all files with "_FMT" extension in work directory.
		Parameters: 
				None (references all the datasets with suffix of "_FMT" in the current SAS work directory)
 		Example:
				%TrimTextVars();

		Author:  Anna Kispert
		Date created:  March 2015
**********************************************/
%macro TrimTextVars();
	
	*populate work_contents with the names of the data sets in work;
	proc datasets memtype=data lib=work noprint; 
		contents data=_ALL_ out=work_contents(keep=memname) noprint; 
	run; 

	*remove duplicates;
	proc sort data=work_contents nodupkey; by memname; run; 

	*narrows the list of datasets to datasets with "_FMT" at the end, creates a macro call
	to TrimTextVariables for each dataset;
	data work_contentsb; 
		set work_contents; 
		length macrocall $300.; 

		if substr(memname,length(memname)-3) ne '_FMT' then delete;
		macrocall='%TrimTextVariables(' || trim(memname) || ')';
	run;

	*create a text string of each of the macro calls to each of the datasets;
	proc sql noprint;
		select trim(macrocall) into: allmacrocalls separated by '; '
		from work_contentsb;
	quit;

	*when dereferenced, this will be a text-block containing the macro calls for each dataset;
	&allmacrocalls.;

	*delete the datasets created by this macro;
	proc datasets memtype=data lib=work nolist;
		delete work_contents work_contentsb;
	quit;
	run;

%mend;
***************END OF MACRO #1;




/*********************************************
MACRO #2:	CreateOnCoreFormatFile
		Description:  
				Creates a PROC FORMAT file from all the downloaded .sas programs
				Should be run after the .sas files have been moved from the downloads subfolder
				Runs the newly created file, which creates a format catalog
		Parameters: 
				RawSASFileDirectory = directory where the updated .sas files in macro 1 are stored
				MainSASProgramDirectory = directory where you want the oncore_format.sas file to be stored
				formatfilename = name of the SAS format file that will be created
 		Example:
				%CreateOnCoreFormatFile(I:\Projects\PsychBeta\DataMgt\RawData\,
						I:\Projects\PsychBeta\DataMgt\SASFiles\,oncore_formats);
		Author:
				Andy Borst
		Updates:
				2/10/2014 MGE
				3/12/2015 Anna Kispert:  Added the file header, which creates a format catalog.  Also added
										a step to delete all of the working datasets created by this macro.
				6/12/2015 Anna Kispert:  Undid the previous modification. Added steps to combine numeric + character
										formats with the same name.
*********************************************/
%macro CreateOnCoreFormatFile(RawSASFileDirectory,MainSASProgramDirectory,formatfilename);

	* This string variable will be used to delete all newly created datasets at the end of the macro;
	%let deletestring = raw_files_dir merged_formats merged_formats2 new_formats temp_value_names temp_var_name val_counts val_status_counts ;

	* Get the list of files and folders in the RAW files directory;
	%GetFilenamesFromDir(&RawSASFileDirectory,raw_files_dir);

	* Trim the list of RAW files to just the .SAS files;
	data raw_files_dir; 
		set raw_files_dir(where = (find(FILENAME,'.sas')));

		* Add variable containing file path of '.sas' file names;
		FILESAS = (trim(DIRECTORY) || trim(FILENAME));

		* Create a counter variable and use it to create the corresponding dataset name;
		COUNTER = _n_;
		if COUNTER < 10 then DSNAME = "formats_0" || strip(COUNTER);
		else DSNAME = "formats_" || strip(COUNTER);
	run;

	%macro ReadSASFile(FileLocation, NewDatasetName);
		* Read in the full SAS file;
		data &NewDatasetName.; 
			length FORMATLINE $1000.;
			infile "&FileLocation.";
			input;
			FORMATLINE = _infile_;
		run; 

		* Some format labels and variable labels are more than 195 characters, so trim to 190 and add 
		quotation mark at the end (seems SAS only reads up to 198??? characters);
		data &NewDatasetName.; 
			set &NewDatasetName.; 

			length FORMATLINE2 $1000.;
			FORMATLINE2 = strip(FORMATLINE); *Spaces will be removed anyway on the output files;

			if length(trim(FORMATLINE2))>197 then FORMATLINE=trim(substr(trim(FORMATLINE2),1,197) || '"'); 
			else FORMATLINE=FORMATLINE2;

			drop FORMATLINE2;
			format FORMATLINE $198.;

			FORMATLINE = tranwrd(FORMATLINE,'&',' and '); *Removes '&' symbols from format lines;
		run;

		* Assign different group numbers to each different format and the main 'data work' section;
		data &NewDatasetName.;
			set &NewDatasetName.;

			if index(upcase(FORMATLINE), 'PROC FORMAT')>0 then SECTION_INDICATOR = 1;
			if index(upcase(FORMATLINE),'DATA WORK')>0 then SECTION_INDICATOR = 2;

			retain GROUP_NUM; *Assign a group number to each format block and to the 'data work' section;
			if first.SECTION_INDICATOR then GROUP_NUM = 1;
			if SECTION_INDICATOR = 1 then GROUP_NUM + 1;
			if SECTION_INDICATOR = 2 then GROUP_NUM = 999;
		run;

		* For each new group_num, assign a name (= the value statement line);
		data temp_value_names;
			format VALUE_NAME $500.;
			set &NewDatasetName. (keep = FORMATLINE GROUP_NUM); *Keep GROUP_NUM for the merge below;
			VALUE_NAME = FORMATLINE;
			drop FORMATLINE;
			if index(upcase(VALUE_NAME),'VALUE')>0 and GROUP_NUM ne 999 and
				index(VALUE_NAME,'=')=0 then output temp_value_names;
			else if index(upcase(FORMATLINE),'DATA WORK')>0 then do;
				VALUE_NAME = '[data section]';
				output temp_value_names;
			end;
		run;
		data &NewDatasetName.;
			merge &NewDatasetName. (in = a) temp_value_names;
			by GROUP_NUM;
			if a;
		run;

		%macro ConvertNumFormatsToText(DatasetWithFormats);
			* Formats listed below should be changed to text formats if they are numeric, so they can be merged;
			%let format1 = 'PROCEDURE_LABS';  *%let format2 = 'EXAMPLE_FMT';
			%let fmt_count = 1; *This should be equal to the number of format variables defined just above.

			* Loops through all of the format[#] variables above;
			%do i = 1 %to &fmt_count.;
				* Changes value statement that matches the current format name to be a text version of itself;
				data &DatasetWithFormats.;
					set &DatasetWithFormats.;
					* If the VALUE_NAME variable matches the format and it is not a text format;
					if index(upcase(VALUE_NAME), &&format&i.)>0
					   and index(upcase(VALUE_NAME), '$')=0 then do;
						* First update the VALUE_NAME line to match the new character format;
						VALUE_NAME = 'VALUE $' || &&format&i. ;
						* Change the value statement corresponding to the format contain the dollar sign;
						if index(upcase(FORMATLINE), 'VALUE')>0 then do;
							FORMATLINE = 'VALUE $' || &&format&i. ;
						end;
						* Change the '=' statements corresponding to the format to use quotes around the left-hand values;
						else if index(FORMATLINE, '=')>0 then do;
							LENGTH_OF_FORMAT = index(upcase(strip(FORMATLINE)), ' ')-1;
							LENGTH_OF_LEFTOVER_TEXT = length(FORMATLINE)-LENGTH_OF_FORMAT-2;  *Note: TWO leading spaces;
							FORMATLINE =  '  "' || substr(FORMATLINE,3,LENGTH_OF_FORMAT) 
										  || '"' || substr(FORMATLINE,LENGTH_OF_FORMAT+3,LENGTH_OF_LEFTOVER_TEXT);
						end;
					end;
					* Change the line where the format is applied to a variable to contain the dollar sign;
					if index(upcase(FORMATLINE), &&format&i.)>0 AND
					   index(upcase(FORMATLINE), 'FORMAT')>0 AND
					   index(FORMATLINE, '$')=0 then do;
					   		POS_OF_FMT_NAME = index(upcase(FORMATLINE), &&format&i.);
							FORMATLINE = substr(FORMATLINE,1,POS_OF_FMT_NAME-1) || '$' || &&format&i. || '.;';
							POS_OF_FORMAT = index(upcase(FORMATLINE), 'FORMAT');
							* Record the name of the variable with the modified format;
							CHANGED_VAR = substr(FORMATLINE,POS_OF_FORMAT+7,POS_OF_FMT_NAME-POS_OF_FORMAT-7);
					end;
					MERGE_VAR = 1; *Will be used below to merge temp_var_name back in with this dataset;
				run;
				
				* Change the input line of the variable using the given format to read it in as character;
				data temp_var_name;
					set &DatasetWithFormats.;
					if CHANGED_VAR ne '' then output;
					keep CHANGED_VAR MERGE_VAR;
				run;

				* Now the name of the variable with the corresponding modified format will run all along the 
				CHANGED_VAR column;
				data &DatasetWithFormats.;
					merge &DatasetWithFormats. (in = a drop = CHANGED_VAR) temp_var_name;
					by MERGE_VAR;
					if a;
				run;

				* Change any format or informat statements for reading in the data to read the value in as text (so
				* that when the variable is assigned the text format later, an error will not be thrown);
				data &DatasetWithFormats.;
					set &DatasetWithFormats.;
			
					if index(upcase(FORMATLINE), 'FORMAT')>0 AND
					   index(upcase(FORMATLINE), upcase(strip(CHANGED_VAR)))>0 AND
					   POS_OF_FORMAT = . then do;
							FORMATLINE = 'format ' || strip(CHANGED_VAR) || ' $500.;';
					end;
				run;

				data &DatasetWithFormats.;
					* Drop all variables created by this submacro;
					set &DatasetWithFormats. (drop = LENGTH_OF_FORMAT LENGTH_OF_LEFTOVER_TEXT POS_OF_FORMAT 
													 POS_OF_FMT_NAME CHANGED_VAR MERGE_VAR);	
				run;
			%end;

		%mend ConvertNumFormatsToText;

		%ConvertNumFormatsToText(&NewDatasetName.);
		
	%mend ReadSASFile; 

	* This data step reads in all of the .SAS files in the RAW directory and creates a "formats_#" dataset for each;
	data _null_;
		set raw_files_dir;
		call execute ('%ReadSASFile(' || trim(FILESAS) || ',' || trim(DSNAME) || ');'); 
	run;

	* Concatinate the list of "format_#" dataset names into a text string;
	proc sql noprint;
		select trim(DSNAME) into: dslist separated by ' ' from raw_files_dir;
	quit; run;
	* Add the list of newly created datasets to the list of datasets to delete;
	%let deletestring = &deletestring. &dslist.;

	* Merge all of the "format_#" datasets;
	data merged_formats; 
		set &dslist.;

		* Delete everything but the assignment statements from the value sections;
		if upcase(trim(FORMATLINE)) = 'RUN;' or index(FORMATLINE, upcase('PROC FORMAT'))
		   or trim(FORMATLINE) = '' or index(FORMATLINE, upcase('VALUE'))
		   or trim(VALUE_NAME) = '[data section]' or trim(FORMATLINE) = ';'
				then delete;
		OBS_NUM = _N_;
	run;

	* Sort the formats and drop duplicate format lines, by value name;
	proc sort data = merged_formats nodupkey; by VALUE_NAME FORMATLINE; run;
	* Put the formats back in the order they were taken;
	proc sort data = merged_formats; by VALUE_NAME OBS_NUM;

	* Surround each value with the title (value) statement and semicolon + new line;
	data merged_formats2;
		set merged_formats;
		format TEMP_FORMATLINE $198.;

		by VALUE_NAME;
		if first.VALUE_NAME and last.VALUE_NAME then do; *Is the line the beginning AND end of the value group?;
			TEMP_FORMATLINE = trim(FORMATLINE);
			FORMATLINE = trim(VALUE_NAME); output;
			FORMATLINE = trim(TEMP_FORMATLINE); output;
			FORMATLINE = ';'; output;
			FORMATLINE = ''; output;
		end;
		else if first.VALUE_NAME then do; *Is the line the first of the value group?;
			TEMP_FORMATLINE = trim(FORMATLINE);
			FORMATLINE = trim(VALUE_NAME); output;
			FORMATLINE = trim(TEMP_FORMATLINE); output;
		end;
		else if last.VALUE_NAME then do; *Is the line the last of the value group?;
			output;
			FORMATLINE = ';'; output;
			FORMATLINE = ''; output;
		end;
		else output;

		drop TEMP_FORMATLINE;
	run;

	* Create the formats.SAS file with the final formats list;
	data _null_ ; * No SAS data set is created;
		set merged_formats2 end=FINAL_OBS;

		* Output SAS format fileFile;
		file "&MainSASProgramDirectory.&formatfilename";     

		ROW_NUM=_N_;
		if ROW_NUM = 1 then do; *Precede the VALUE statements with a PROC FORMAT statement;
			put 'proc format;';
			put FORMATLINE;
		end;
		else if FINAL_OBS then do; *Succeed the VALUE statements with a RUN statement;
			put FORMATLINE;
			put 'run;';
		end;
		else put FORMATLINE;
	run;

	*This macro alters the downloaded SAS files to contain the new merged formats;
	%macro WriteSASFile(FileLocation, WorkingDataSet, NewFormats);

		* Add PROC FORMAT statments to the new formats;
		data new_formats;
			format TEMP_VALUE $500.;
			set &NewFormats.;

			STATUS = 'NEW'; *Indicates that the format comes from the new merged formats file;

			by VALUE_NAME;
			if first.VALUE_NAME then do;
				TEMP_VALUE = FORMATLINE;
				FORMATLINE = 'PROC FORMAT;';
				output;
				FORMATLINE = TEMP_VALUE;
				output;
			end;
			else output;

			drop TEMP_VALUE;
		run;

		* Merge the new formats with the old;
		data &WorkingDataSet.;
			set new_formats &WorkingDataSet.;
			if STATUS = '' then STATUS = 'OLD';
			NUMBERING = _N_;
		run;

		* Count the total number of instances of each format, by name;
		proc freq data = &WorkingDataSet. noprint; tables VALUE_NAME / out = val_counts; run;
		data val_counts;
			set val_counts (drop = PERCENT);
			rename COUNT = TOTALCOUNT;
		run;
		proc sort data = &WorkingDataSet.; by VALUE_NAME STATUS; run;
		data &WorkingDataSet.;
			merge &WorkingDataSet. (in = a) val_counts;
			by VALUE_NAME;
			if a;
		run;

		* Count the total number of instances of each new and old format, by name;
		proc freq data = &WorkingDataSet. noprint; tables VALUE_NAME*STATUS / out = val_status_counts; run;
		data val_status_counts;
			set val_status_counts (drop = PERCENT);
		run;
		data &WorkingDataSet.;
			merge &WorkingDataSet. (in = a) val_status_counts;
			by VALUE_NAME STATUS;
			if a;
		run;
		proc sort data = &WorkingDataSet.; by NUMBERING; run;

		* Replace the old formats with the new ones;
		data &WorkingDataSet.;
			set &WorkingDataSet.;
			if TOTALCOUNT ne COUNT and STATUS = 'NEW' then output; *Take only the new versions of each format;
			else if TOTALCOUNT = COUNT and STATUS = 'OLD' then output; *TOTALCOUNT only = COUNT for the data section;
		run;

		* Create the formats.SAS file with the edited formats;
		data _null_ ; * No SAS data set is created;
			set &WorkingDataSet.;

			* Output SAS format fileFile;
			file "&FileLocation.";     
			put FORMATLINE;
		run;

	%mend;

	* Call the WriteSASFile macro for each SAS file in the RAW data folder;
	data _null_;
		set raw_files_dir;
		call execute ('%WriteSASFile(' || trim(FILESAS) || ',' || trim(DSNAME) || ', merged_formats2);'); 
	run;

	%put &deletestring.; * For debugging purposes;

	* Delete all temp datasets created above;
	proc datasets memtype=data lib=work nolist;
		delete &deletestring. ;
	quit; run;

%mend;
***************END OF MACRO #2;




/********************************************
MACRO #3: CopySASorTextFiles
		Description:  
				Automatically copies .sas or .txt (prompt window will appear) from the individual exported 
				OnCore folders into the RawData folder
		Parameters: 
				SourceFolder = the folder containing the files to copy
				DestinationFolder = the folder to receive the new copies
 		Example:
				%CopySASorTextFiles(I:\Projects\PsychBeta\DataMgt\Downloads\,
					I:\Projects\PsychBeta\DataMgt\RawData\);

		Author:  Jon Mathews
		Date created:  June 2013
		Updates:
				7/15/2014 MGE (copies SAS or text files downloaded)
				6/18/2015 Anna Kispert:  Modified to use the new CopyOnCoreSASFiles and CopyOnCoreTextFiles macros
**********************************************/
%macro CopySASorTextFiles(SourceFolder, DestinationFolder);

	* Set window prompt message for user ;
	%window prompt_extractFiles
	  #5 @5 "Unpack (1).sas files only (2).txt files only or (0)none ?"
	  #6 @5 '(1=.sas 2=.txt 0=None): ' YNinput 8 attr=underline;
	%display prompt_extractFiles;
	%if &YNinput eq 0 %then %goto finish;
	%if &YNinput eq 1 %then %goto sas_only;
	%if &YNinput eq 2 %then %goto txt_only;

	/*(1)*/
	%sas_only:		
		%CopyOnCoreFilesByExtension(&SourceFolder., &DestinationFolder., 'sas');
	%goto finish;

	/*(2)*/
	%txt_only:		
		%CopyOnCoreFilesByExtension(&SourceFolder., &DestinationFolder., 'txt');
	%goto finish;

	%finish:  

	%if &YNinput eq 0 %then %put 'No files copied'; 
	%if &YNinput eq 1 %then %put '.sas files were copied';
	%if &YNinput eq 2 %then %put '.txt data files were copied';
	
	run;

%mend;
***************END OF MACRO #3;




/********************************************
MACRO #4: RunBatchSASFiles
		Description:  
				Run to create SAS work files when running main SAS Analysis Generation Program
		Parameters: 
				OnCoreSASFileDir = directory where all the updated .sas files are stored
 		Example:
				%RunBatchSASFiles(I:\Projects\PsychBeta\DataMgt\RawData\);

		Author:  MGE
		Date created:  February 2014
		Updates:
			June 2015 - Modified to fix the FU and DM SAS files, which have been exporting from OnCore with incorrect
					    formatting	ANK
**********************************************/
%macro RunBatchSASFiles(OnCoreSASFileDir);

	* Temporary sub-macro to fix the follow-up SAS file, which has been exporting from OnCore with incorrect formatting;
	%macro RepairFU(RawSASFileDirectory); 
	
		* Read in the Followup.SAS file, storing each line in the SAS file as an observation for the var "formatline";
		data corrected_fu;
			length FORMATLINE $1000.;
			infile "&RawSASFileDirectory.Followup.sas";
			input;
			FORMATLINE = _infile_;
		run;

		data corrected_fu;
			set corrected_fu;

			* Correct / remove the offending formats, storing the corrections in the new var NEWFORMATLINE;
			FORMATLINE = tranwrd(FORMATLINE, 'OFF_TREATMENT_REASON_EXPLAIN 12.', 'OFF_TREATMENT_REASON_EXPLAIN $200.');
			FORMATLINE = tranwrd(FORMATLINE, 'OFF_STUDY_REASON_EXPLAIN 12.', 'OFF_STUDY_REASON_EXPLAIN $200.');
			if upcase(strip(FORMATLINE)) = 'FORMAT OFF_TREATMENT_REASON_EXPLAIN OFF_TREATMENT_REASON_EXPLAIN.;' then delete;
			if upcase(strip(FORMATLINE)) = 'FORMAT OFF_STUDY_REASON_EXPLAIN OFF_STUDY_REASON_EXPLAIN.;' then delete;
		run;

		* Overwrite the incorrect Followup.SAS program with the corrected text from the corrected_fu dataset;
		data _null_;
		    set corrected_fu; 
		    file "&RawSASFileDirectory.Followup.sas" ; 
		    put FORMATLINE; 
		run;

		* Delete the newly created corrected_fu dataset;
		proc datasets memtype=data lib=work nolist;
			delete corrected_fu;  
		quit; run;

	%mend RepairFU;

	* Temporary sub-macro to fix the demographics SAS file, which has been exporting from OnCore with incorrect formatting;
	%macro RepairDemog(RawSASFileDirectory);

		* Read in the Demographics.SAS file, storing each line in the SAS file as an observation for the var "formatline";
		data corrected_demog;
			length FORMATLINE $1000.;
			infile "&RawSASFileDirectory.Demographics.sas";
			input;
			FORMATLINE = _infile_;
		run; 

		* Add a line to set the RACE variable format to be $RACE;
		data corrected_demog;
			set corrected_demog;

			if upcase(strip(FORMATLINE)) = 'SET DEMOGRAPHICS;' then do;
				output;
				FORMATLINE = 'format RACE $RACE.;';
				output;
			end;
			else output;
		run;

		* Overwrite the incorrect Demographics.SAS program with the corrected text from the corrected_demog dataset;
		data _null_;
		    set corrected_demog; 
		    file "&RawSASFileDirectory.Demographics.sas" ; 
		    put FORMATLINE; 
		run;

		* Delete the newly created corrected_demog dataset;
		proc datasets memtype=data lib=work nolist;
			delete corrected_demog;
		quit; run;

	%mend RepairDemog;

	%RepairFU(&OnCoreSASFileDir);
	%RepairDemog(&OnCoreSASFileDir);

	%GetFilenamesFromDir(&OnCoreSASFileDir,sasfiledir);

	data sasfiledir2; 
		set sasfiledir(where=(find(lowcase(FILENAME),'.sas')));

		* Add variable containing file path of '.sas' file names;
		FILESAS=(trim(DIRECTORY) || trim(FILENAME) );
		call symput('num_files',_n_);
		call symput ('filein', trim(FILESAS));
	run;

	%do a = 1 %to &num_files.;
		data _null_;
			set sasfiledir2;
			if _n_=&a;
			call symput ('filein', trim(FILESAS));
		run;
		x "cd &OnCoreSASFileDir"; * Change the default directory so the infile statement will work;
		%include "&filein";
	%end;
	run;

	* Delete the temporarily created datasets;
	proc datasets memtype=data lib=work nolist;
		delete sasfiledir sasfiledir2;  
	quit; run;

%mend;
***************END OF MACRO #4;




/********************************************
MACRO #5: InsertID
		Description:  
				Creates SUBJID and USUBJID and drops specific variables from the dataset
				Run this one after TrimTextVars in main SAS analysis program
		Parameters: 
				studynum = IU Cancer Center Study Number
 		Example:
				%InsertID('0414');

		Author:  MGE
		Date created:  July 2014
		Updates:
			July 2015 - Modified code to catch case where SEQUENCE_NO_ does not contain a hyphen - ANK
			July 2016 - Added the case where SEQUENCE_NO_ contains 2 hyphens (site ID included in sequence) - ANK
**********************************************/
%macro InsertID(StudyNum); 

	%macro InsertIDPerDataset(DatasetToAlter, HasFormDescVar);	
	 	data &DatasetToAlter.; 
			retain USUBJID SUBJID; *Place the new variables in the front;
			set &DatasetToAlter.;

			* Create USUBJID and SUBJID variables and set the length;
			format SUBJID 8. USUBJID $12.;
			
			* Case 1: SEQUENCE_NO_ contains a single hyphen in it (most cases), should be in the form [STUDYID]-[SUBJID];
			* In this case, SUBJID = [SUBJID] and USUBJID = [STUDYID]-[SUBJID];
			if count(SEQUENCE_NO_,'-') = 1 then do; 
				SUBJID = substr(SEQUENCE_NO_,find(SEQUENCE_NO_,'-')+1,length(SEQUENCE_NO_)-find(SEQUENCE_NO_,'-'));
				if &StudyNum. = '0498' then do;
					*0498 has a mix of 3-digit and 4-digit IDs in SEQUENCE_NO_;
					if SUBJID < 10 then USUBJID = &StudyNum. || '-00' || strip(put(SUBJID, 3.));
					else if SUBJID < 100 then USUBJID = &StudyNum. || '-0' || strip(put(SUBJID, 3.));
					else USUBJID = &StudyNum. || '-' || strip(put(SUBJID, 3.));
				end;
				else do;
					USUBJID = &StudyNum. || '-' || substr(SEQUENCE_NO_,find(SEQUENCE_NO_,'-')+1,length(SEQUENCE_NO_)-find(SEQUENCE_NO_,'-')+1);
				end;
			end;
			* Case 2: SEQUENCE_NO_ does not contain a hyphen in it, should be in the form [SUBJID].
			* In this case, SUBJID = [SUBJID] and USUBJID = [STUDYID]-[SUBJID];
			else if count(SEQUENCE_NO_,'-') = 0 then do; 
				SUBJID = SEQUENCE_NO_;
				USUBJID = &StudyNum. || '-' || strip(SEQUENCE_NO_);
			end;
			* Case 3: SEQUENCE_NO_ contains TWO hyphens in it -- typically in the form [SITEID]-[STUDYID]-[SUBJID];
			* In this case, SUBJID = [SITEID][SUBJID] and USUBJID = [STUDYID]-[SITEID]-[SUBJID];
			else if count(SEQUENCE_NO_,'-') = 2 then do; 
				SUBJID = substr(SEQUENCE_NO_,1,2) || substr(SEQUENCE_NO_,find(SEQUENCE_NO_,'-',-1*length(SEQUENCE_NO_))+1);
				*USUBJID will be [STUDYID]-[SITEID]-[SUBJID];
				USUBJID = &StudyNum. || '-' || substr(SEQUENCE_NO_,1,2) || '-' || substr(SEQUENCE_NO_,find(SEQUENCE_NO_,'-',-1*length(SEQUENCE_NO_))+1);
			end;


			* Drop some unnecessary variables here;
			drop SEQUENCE_NO_ INITIALS; 
			if &HasFormDescVar. = 1 then do; drop FORM_DESC_; end;

			label SUBJID = 'Subject ID Numeric'
				  USUBJID = 'Subject ID Character';
		run;

	%mend InsertIDPerDataset; 
	 
	* Populate workcontents with the names of the data sets in the WORK library;
	proc datasets memtype=data lib=work nolist; 
		contents data = _ALL_ out = workcontents (keep=MEMNAME) noprint; *MEMNAME will be name of input dataset;
	run; 
	proc sort data = workcontents nodupkey; by MEMNAME; run; *Remove duplicate entries;
 
	* Execute the InsertIDPerDataset macro on each data set in the WORK library; 
	data workcontents; 
		set workcontents; 
		if substr(MEMNAME,length(MEMNAME)-3,4) = '_FMT'; *Only alter datasets that end with _FMT;

		length MACROCALL $300.; 
		if MEMNAME in('DEMOGRAPHICS_FMT','FOLLOWUP_FMT') then
			MACROCALL = '%InsertIDPerDataset(' || trim(MEMNAME) || ',1);'; *For demographics and followup only;
		else 				
			MACROCALL = '%InsertIDPerDataset(' || trim(MEMNAME) || ',0);'; *For the rest of datasets;
		call execute(MACROCALL); 
	run; 

	* Delete the temporarily created dataset;
	proc datasets memtype=data lib=work nolist;
		delete workcontents;  
	quit; run;

%mend;
***************END OF MACRO #5;




/********************************************
MACRO #6: GetFilenamesFromDir
		Description:  
				Returns a list of filenames from a specified directory
				NOTE: This macro was created by Mike Swetz and can also be found in:
				"I:\Code_Sharing_and_General_Documentation\Code_Sharing_and_Presentations\SAS\SwetzMacros\Code\General Routines\GetFilenamesFromDir.sas"		
		Parameters: 
				Directory = directory to be examined
                Output = dataset to be created.  Will have DIRECTORY and FILENAME variables (both w/ $300. formats)
                KeepStrings = Optional space-delimited list of strings to scan the filenames for inclusion in 
						the output dataset
                ExcludeStrings = Optional space-delimited list of strings to scan the filenames for exclusion
                Subs = Optional argument that if set equal to yes, checks the subfolders of the specified folder
 		Examples:
				%GetFilenamesFromDir(I:\Projects\PsychBeta\DataMgt\Downloads\,sasfiledir);
				%GetFilenamesFromDir(I:\Projects\PsychBeta\DataMgt\Downloads\,sasfiledir, 'hello goodbye',
						'yes no maybe', yes);

		Author:  Mike Swetz
		Date created:  October 2008
		Updates:
				3/10/2009 Mike Swetz:  Added the subs argument so that subfolders could be checked as well
**********************************************/
%macro GetFilenamesFromDir(Directory,Output,KeepStrings,ExcludeStrings,Subs);

	%local kstringcount exstringcount i j;

	%let kstringcount = 0;
	%let exstringcount = 0;

	/*Count number of strings to keep and to exclude*/
	%let kstringcount = %eval(%sysfunc(countc(&keepstrings.," "))+1);
	%let exstringcount = %eval(%sysfunc(countc(&excludestrings.," "))+1);

	/*Pipe the dos directory statement*/
	%if %upcase(&subs.) = YES %then %do;
		filename temp pipe "dir %bquote("&Directory.") /s /b";
	%end;
	%else %do;
		filename temp pipe "dir %bquote("&Directory.") /b";
	%end;

	/*Read in the results of the directory statement parsing the
		list of strings to keep and exclude*/

	data &Output;
		format directory filename $1000.;
		infile temp truncover lrecl=1000;
		directory = "&Directory.";
		input filename $1000.;

		/*If subs argument specified, parse out the directory argument from the filename
			so the downstream routines will still work.*/
		%if %upcase(&Subs.) = YES %then %do;
			filename = tranwrd(filename,"&directory.","");
		%end;

		%if &ExcludeStrings ne %then %do;
			if
			%do j = 1 %to &exstringcount.;
				index(upcase(filename),"%upcase(%scan(&ExcludeStrings.,&j.,%str( )))") > 0
						%if &j < &exstringcount %then or;
			%end;
			then delete;
		%end;

		%if &KeepStrings. ne %then %do;
			if
			%do i = 1 %to &kstringcount.;
				index(upcase(filename),"%upcase(%scan(&Keepstrings.,&i.,%str( )))") = 0
					%if &i < &kstringcount %then and;
			%end;
			then delete;
		%end;

	run;	
		
%mend;
***************END OF MACRO #6;




/********************************************
MACRO #7: InsertStudyID 
		Description:  
				Adds the STUDYID variable to all _FMT datasets in the WORK directory
				This macro call should follow the "InsertID" macro call in your study's main SAS program
		Parameters: 
				studynum = IU Cancer Center Study Number
 		Example:
				%InsertStudyID('0123');

		Author:  Anna Kispert
		Date created:  January 2015
**********************************************/
%macro InsertStudyID(StudyNum); 
	%macro add_sid(DatasetToAlter);
		data &DatasetToAlter.; 
			retain STUDYID;
			set &DatasetToAlter.;

			format STUDYNUM_NUMERIC 8.;
			STUDYNUM_NUMERIC = &StudyNum.;
			if STUDYNUM_NUMERIC < 525 then STUDYID = 'IUCRO-' || &StudyNum.;
			else STUDYID = 'IUSCC-' || &StudyNum.;
			label STUDYID = 'Study Protocol Number';
			drop STUDYNUM_NUMERIC;
		run;
	%mend; 

	* Populate workcontents with the names of the data sets in the WORK library;
	proc datasets memtype=data lib=work nolist; 
		contents data = _all_ out = workcontents (keep=MEMNAME) noprint; 
	run; 
	proc sort data=workcontents nodupkey; by MEMNAME; run; *Remove duplicate dataset names;

	data workcontents; 
		set workcontents; 
		if substr(MEMNAME,length(MEMNAME)-3,4)='_FMT';  *Only add the STUDYID var to the _FMT datasets;

		call execute ('%add_sid(' || trim(MEMNAME) || ');'); 
	run;

	* Delete the temporarily created dataset;
	proc datasets memtype=data lib=work nolist;
		delete workcontents;  
	quit; run;

%mend;
***************END OF MACRO #7;




/********************************************
MACRO #8: TrimTextVariables
		Description:  
				Trims the text variable lengths of just one dataset
		Parameters: 
				inp = the dataset to trim
 		Example:
				%TrimTextVariables(Demographics);

		Author:  Anna Kispert
		Date created:  3/2/2015
**********************************************/
%macro TrimTextVariables (inp);
	
	*create a dataset CharVar that has the names, lengths, and formats of all of the character-type variables;
	proc contents data = &inp noprint
		out = CharVar (where = (type=2) keep = name type length format);
	run;

	*create a dataset that contains expressions that will be used below to find (1) the individual lengths of
	each observation of each character variable and (2) the maximum length for each variable, given #1;
	data CharVar2;
		length length_var length_expression max_expression $100;
		attrib format informat=$32.;
 		set CharVar;

  		varcount = _N_; *varcount is just the value of the observation number;

		length_var = compress('text_var_' || trim(varcount) || '_length');
 		length_expression = trim(length_var) || '=length(' || trim(name)||')';
 		max_expression = 'max(' || trim(length_var) || ') as ' || trim(name);

		if format in ('$', ' .', '') then format = '';
		else format = trim(format) || '.';
	run;

	*concatinate the expressions into macro variables that will be inserted below as text;
	proc sql noprint;
		select trim(length_expression) into: newvar separated by '; '
		from CharVar2;
		select trim(max_expression) into: maxvar separated by ', '
		from CharVar2;
	quit;

	*create a dataset that contains the original data and the lengths of each of the character variables;
	data VarLen ;
		set &inp;
		&newvar.;
	run;

	*select the maximum lengths from each of the length columns;
	proc sql noprint;
		create table maxx as
		select &maxvar.
		from VarLen ;
	quit;

	*transpose the data from MAXX so that one column contains the variable names and another contains the max
	length of each variable;
	proc transpose data=maxx
        out=maxx_t;
	run;

	*rename variables for the MERGE in MAXX_T3;
	data maxx_t2;
		set maxx_t;
		rename _name_ = name
			   col1 = max_length;
	run;

	*create a dataset with expressions for setting variable lengths and variable formats, based on the maximum
	length information we found above;
	data maxx_t3;
		length name $100 length_expression $100 format_expression $100;
 		merge maxx_t2 CharVar2 (keep = name format);
		by name;

 		if max_length < 1 then max_length = 1;

 		length_expression = trim(name) || ' $' || strip(put(max_length, best.));

		if format = '' then format = '$' || strip(put(max_length, best.)) || '.';

		format_expression = trim(name) || ' ' || trim(format);
	run;

	*concatinate the expressions into macro variables that will be inserted below as text;
	proc sql noprint ;
 		select strip(length_expression) into: newlen separated by ' '
 		from maxx_t3 ;

		select strip(format_expression) into: newformat separated by ' '
 		from maxx_t3 ;
	quit;

	*the AllVar dataset will be used to generate a list (as text) of the variables in the original dataset
	in the original order;
	proc contents data = &inp noprint short
		out = AllVar (keep = libname memname name varnum);
	run;

	proc sort data = AllVar; by varnum; run;

	*get the text list of variable names in order, then get the name of the original dataset for the proc
	datasets step below;
	proc sql noprint;
		select trim(name) into: varorder separated by ' '
		from AllVar;

		select memname into: dsname
		from AllVar;

		select libname into: dslib
		from AllVar;
	quit;

	*this dataset will have the same information as the original dataset, but with the new lengths and formats;
	options varlenchk=nowarn;  *since we will be shortening var lengths, turn off SAS warning;
	data new_formatted_inp;
		retain &varorder. ;
		length &newlen. ;
		format &newformat. ;
		set &dslib..&dsname.;			
	run;
	options varlenchk=warn;;  *turn var length warnings back on;

	*update the original dataset using the newly created dataset;
	data &dslib..&dsname.;
		set new_formatted_inp;
	run;

	*delete all temp datasets created above;
	proc datasets memtype=data lib=work nolist;
		delete CharVar CharVar2 VarLen maxx maxx_t maxx_t2 maxx_t3 AllVar new_formatted_inp;
	quit;
	run;

%mend;
***************END OF MACRO #8;




/********************************************
MACRO #9: CopyOnCoreFilesByExtension
		Description:  
				Moves the unziped OnCore files that match the specified extension into the specified destination
				folder
		Parameters: 
				SourceFolder = the folder containing the files to copy
				DestinationFolder = the folder to receive the new copies
				Extension = text string containing the extension of the files to copy
 		Example:
				%CopyOnCoreFilesByExtension(I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\Downloads\,
				I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\,'sas');

		Author:  Anna Kispert
		Date created:  June 2015
		Updates:  10/27/15 - Edited to extract nested folders
**********************************************/
%macro CopyOnCoreFilesByExtension(SourceFolder, DestinationFolder, Extension);

	%GetFilenamesFromDir(&SourceFolder.,source_folder_contents,,,yes);

	data source_folder_contents2;
		set source_folder_contents;
		if find(FILENAME,'.') = 0; *Gets folder names only;

		* Gets the position of the last backslash;
		LASTSLASHPOS = findc(FILENAME,'\',-length(FILENAME));
		* Determine the file path of the file to move;
		format FILEPATH $500.;
		if LASTSLASHPOS = 0 then 
			FILEPATH = strip(DIRECTORY) || strip(FILENAME) || '\' || strip(FILENAME) || '.' || &Extension.;
		else
			FILEPATH = strip(DIRECTORY) || strip(FILENAME) || '\' || 
					   strip(substr(FILENAME,LASTSLASHPOS+1,length(FILENAME)-LASTSLASHPOS)) || '.' || &Extension.;

		* This will equal 0 if the file does not exist, 1 if it does;
		CHECKEXIST = fileexist(strip(FILEPATH));

		* Create the code that will move the file;
		MOVECODE = catt('%sysExec xcopy "',strip(FILEPATH),'" "&DestinationFolder." /E /Y;');
	run;

	data _null_;
		set source_folder_contents2;
		if CHECKEXIST = 1 then call execute(MOVECODE);
	run;

	* Delete all temp datasets created above;
	proc datasets memtype=data lib=work nolist;
		delete source_folder_contents source_folder_contents2;
	quit;
	run;

%mend;
***************END OF MACRO #9;




/********************************************
MACRO #10: CopyOnCoreSASFiles
		Description:  
				Moves the unziped OnCore .SAS files into the specified destination folder (NO PROMPT)
		Parameters: 
				SourceFolder = the folder containing the files to copy
				DestinationFolder = the folder to receive the new copies
 		Example:
				%CopyOnCoreSASFiles(I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\Downloads\,
				I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\);

		Author:  Anna Kispert
		Date created:  June 2015
**********************************************/
%macro CopyOnCoreSASFiles(SourceFolder, DestinationFolder);
	%CopyOnCoreFilesByExtension(&SourceFolder., &DestinationFolder., 'sas');
%mend;
***************END OF MACRO #10;




/********************************************
MACRO #11: CopyOnCoreTextFiles
		Description:  
				Moves the unziped OnCore .TXT files into the specified destination folder (NO PROMPT)
		Parameters: 
				SourceFolder = the folder containing the files to copy
				DestinationFolder = the folder to receive the new copies
 		Example:
				%CopyOnCoreTextFiles(I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\Downloads\,
				I:\Projects\Cancer\IUSCC\IUCRO-0498\DataMgt\RawData\);

		Author:  Anna Kispert
		Date created:  June 2015
**********************************************/
%macro CopyOnCoreTextFiles(SourceFolder, DestinationFolder);
	%CopyOnCoreFilesByExtension(&SourceFolder., &DestinationFolder., 'txt');
%mend;
***************END OF MACRO #11;




/********************************************
MACRO #12: RemoveLabelColons
		Description:  
				Removes all ending colons (:) from the end of the labels on a dataset
		Parameters: 
				DatasetName = the dataset whose labels to modify
 		Example:
				%RemoveLabelColons(EXIV);

		Author:  Anna Kispert
		Date created:  September 2015
**********************************************/
%macro RemoveLabelColons (DatasetName);

	* Get the list of all variables and their labels in the dataset;
	proc contents data = &DatasetName. noprint
		out = DataSetVariables (keep = NAME LABEL);
	run;

	* If a label ends in a :, create a new label without it, then create an equality statement
	  to reset the label below;
	data DataSetVariables2;
		set DataSetVariables;

		if LABEL ne '' then do;
			if substr(LABEL,length(LABEL),1) = ':' then do;
				NEWLABEL = substr(LABEL,1,length(LABEL)-1);
				EQUALITYSTMT = strip(NAME) || ' = "' || strip(NEWLABEL) || '"';
			end;
		end;
	run;

	* Gather all equality statements into a macro text variable;
	proc sql number noprint;
		select trim(EQUALITYSTMT) into :RelabelingStmts separated by ' '
		from DataSetVariables2;
	quit;

	* Apply the renaming statements;
	data &DatasetName.;
		set &DatasetName.;
		label &RelabelingStmts.;
	run;

	* Delete all temp datasets created above;
	proc datasets memtype=data lib=work nolist;
		delete DataSetVariables DataSetVariables2;
	quit; run;

%mend;
***************END OF MACRO #12;




/********************************************
MACRO #13: ArchiveSASDatasets
		Description:  
				Moves all SAS datasets in one folder to another folder, grouped into a subfolder with
				the name YYYY-MM-DD, which represents the "creation date" of the dataset
		Parameters: 
				FolderWithDatasets = the folder containing the datasets to move
				ArchiveFolder = the folder in which to create the YYYY-MM-DD folder containing the moved
					datasets
 		Example:
				%ArchiveSASDatasets(I:\Projects\Cancer\IUSCC\IUCRO-0473\Stat\,
					I:\Projects\Cancer\IUSCC\IUCRO-0473\Stat\Archive\);
				(Would the SAS dataset files in the STAT folder into a new folder named 2016-06-19, which
				can be found in the STAT/ARCHIVE folder)

		Author:  Anna Kispert
		Date created:  June 2016
**********************************************/
%macro ArchiveSASDatasets(FolderWithDatasets,ArchiveFolder);

	* Get the list of files and folders that are in the FolderWithDatasets;	
	%GetFilenamesFromDir(&FolderWithDatasets.,directory_content);

	* Reduce the list of files and folders to only include SAS dataset files;
	data directory_content2;
		set directory_content;

		* Keep only the SAS dataset files;		
		if find(filename,'.') then fileextension = strip(lowcase(substr(filename,find(filename,'.'))));
		if fileextension = '.sas7bdat';

		fullfilepath = strip(directory) || '\' || strip(filename); 
	run;

	*Only if there is at least one SAS dataset in the FolderWithDatasets should the archive be performed;
	proc sql noprint; select count(*) into : NumDatasets from directory_content2; quit;
	%if &NumDatasets > 0 %then %do;

		* Get the full file path of the first dataset file and place it into a macro variable;
		data first_dataset; set directory_content2; if _N_ = 1; run;	
		proc sql noprint; select fullfilepath into : FirstDatasetFilename from first_dataset; quit;

		* This dataset uses the INFILE command to "open" the first dataset and extract its metadata;
		filename fileref "&FirstDatasetFilename.";
		data dataset_information;
			infile fileref truncover;
			fid = fopen('fileref'); *This will return 1 if the file can be successfully accessed;                                                               
			creation_datetime_txt = finfo(fid,'Create Time');
			input var1 $1.; *Dummy variable for reading in datalines;
		run;

		* Set the archived folder name (i.e. the folder that will hold/group all of the datasets together to the string 
		  'YYYY-MM-DD', using the creation date of the first file. Put this folder name into a new macro variable;
		data dataset_information2 (keep = archived_folder_name);
			set dataset_information (keep = creation_datetime_txt);

			creation_date_txt = substr(creation_datetime_txt,1,find(creation_datetime_txt,':')-1);
			creation_date = input(strip(creation_date_txt),date9.);
			format creation_date yymmddd10.;
			archived_folder_name = vvalue(creation_date);
		run;
		proc sql noprint; select archived_folder_name into : NewArchiveSubfolder from dataset_information2; quit;
		
		libname dsdir "&FolderWithDatasets."; *Library to move files from;

		options dlcreatedir; *Turning on this option will force SAS to create a folder for a library if one does not exist;
		libname archdir "&ArchiveFolder.&NewArchiveSubfolder."; *Create the new archive folder to move files to;
		options nodlcreatedir; *Turn the dlcreatedir option off;

		* Move the dataset files from one directory to another;
		proc copy in = dsdir out = archdir move; run; 

		* Clear the librefs now that they are no longer needed;
		libname dsdir clear; libname archdir clear;
		
		* Delete all temp datasets created above (within the IF);
		proc datasets memtype = data lib = work nolist;
			delete first_dataset dataset_information dataset_information2;
		quit;

	%end;

	* Delete all temp datasets created above (outside the IF);
	proc datasets memtype = data lib = work nolist;
		delete directory_content directory_content2;
	quit;

%mend;




/********************************************
MACRO #14: FixTimeImport
		Description:  
				Fix any input statement that informats time values as TIME5 (will not read integers as times)
		Parameters: 
				OnCoreSASFileDirectory = Directory where all the OnCore .sas files are stored
 		Example:
				%FixTimeImport(I:\Projects\PsychBeta\DataMgt\RawData\);

		Author:  ANK
		Date created:  December 2016
		Updates:
**********************************************/
%macro FixTimeImport(OnCoreSASFileDirectory);

	* Temporary sub-macro to fix the follow-up SAS file, which has been exporting from OnCore with incorrect formatting;
	%macro CheckForTimeInformat(FileName); 

		%macro FixTimeImportOneFile(NameOfFile);
			* Modify any informatting lines with the "time5" informat;
			data SASFileCode2;
				set SASFileCode;

				if find(codeline,"informat","i") and find(codeline,"time5.;") then do;
					codeline = tranwrd(codeline,"time5.;","hhmmss5.;");
				end;
			run;

			* Overwrite the SAS program with the corrected text from the SASFileCode2 dataset;
			data _null_;
			    set SASFileCode2; 
			    file "&OnCoreSASFileDirectory.&NameOfFile."; 
			    put codeline; 
			run;

			* Delete the temporarily created SASFileCode2 dataset;
			proc datasets memtype = data lib = work nolist; delete SASFileCode2; quit; run;

		%mend FixTimeImportOneFile;
	
		* Read in the SAS file, storing each line in the file as an observation for the variable "formatline";
		data SASFileCode;
			length codeline $1000.;
			infile "&OnCoreSASFileDirectory.&FileName.";
			input;
			codeline = _infile_;
		run;

		* Check to see if the file contains any lines containing "informat" and "time5.";
		data _null_;
			set SASFileCode;

			nameoffile = "&FileName.";
			retain indicator;
			if _N_ = 1 then indicator = 0;

			if indicator = 0 and find(codeline,"informat","i") and find(codeline,"time5.;") then do;
				indicator = 1;
				call execute ('%FixTimeImportOneFile(' || trim(nameoffile) || ');');
			end;
		run;

		* Delete the temporarily created dataset;
		proc datasets memtype = data lib = work nolist; delete SASFileCode; quit; run;

	%mend CheckForTimeInformat;

	%GetFilenamesFromDir(&OnCoreSASFileDirectory,SASFileDirectory);
	data _null_;
		set SASFileDirectory (where = (find(lowcase(filename),'.sas')));
		call execute ('%CheckForTimeInformat(' || trim(filename) || ');');
	run;

	* Delete the temporarily created dataset;
	proc datasets memtype = data lib = work nolist; delete SASFileDirectory; quit; run;

%mend;

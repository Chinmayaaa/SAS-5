*********************************************************************************************
TREAT Macro for importing dating into SAS from OnCore. 
Because of the nature of Treat 001 and the problems encountered from Oncore,
a macro was created in order to standardize all of the datasets. 
This helps reduce code in the many ad hoc or other ancilary studies that TREAT 001 garners. 
In addtion it also allows for Data Managers to quickly qc certain data points for reports and 
other data safety reports.

Author: Ryan Cook
Date : 5/20/2015

********************************************************************************************;


********************
This macro formats the race for the demographics form of OnCore;

%macro DemoRace();

proc sort data= demographics_fmt;
	by SEQUENCE_NO_;
run;


data demog (rename= nih_race=race);
	set demographics_fmt (drop = age);

	age=round((on_study_date-birth_date)/365.25, .1);


	if eligibility_status IN ("Eligible", "Eligible(O)"); 

	nih_race = race;
	* when race is Other then NIH reporting should have it has "Unknown";
	if race = '9' then nih_race = '6';
	* when race has multiple values then NIH reporting should have it has "More than one race";
	if index (race, ';') > 0 then nih_race = '8';

	format 	nih_race $race.;

	drop race; 

	studyid = input(sequence_no_, 5.);
	drop sequence_no_;

	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";

	label age="Age at Enrollment"; 
	label site = "Site";
	label arms="Arms";
	lable nih_race="Race";

run; 

%mend;
************************End of Macro;


****This macro will merge the old TLFB form with the current one since OnCore created a bug that
did not carry infomration over from a certain date. ;

/*%macro TLFBmerge();*/
/**/
/*PROC IMPORT OUT= WORK.tlfb_old*/
/*            DATAFILE= "I:\Projects\TREAT\DSMB\Jan2015\OnCore_data\QS-TLFB Summary  V1.xlsx" */
/*            DBMS=EXCEL REPLACE;*/
/*     RANGE="QS-TLFB Summary  V1$"; */
/*     GETNAMES=YES;*/
/*     MIXED=NO;*/
/*     SCANTEXT=YES;*/
/*     USEDATE=YES;*/
/*     SCANTIME=YES;*/
/*RUN;*/
/**/
/***NOTE-02.18.2014---->TLFB DOES NOT EXPORT TLFB_TOTALDRINKS SINCE THE CRF was changed*/
/*                       waiting on the bug to be fixed, TLFB_TOTALDRINKS2 is the new name for the same*/
/*                       field, however data are not combined at export, needs to be combined in SAS into one and only*/
/*                       TLFB_TOTALDRINKS field;*/
/*data t2; */
/*      set tlfb_old;*/
/*      seq=put(sequence_no_, $5.);*/
/*run;*/
/**/
/**/
/*proc sql;*/
/*      create table tlfb_combo as*/
/*      select tlfb2.sequence_no_, tlfb2.segment, tlfb2.visit_date, max(tlfb_totaldrinks, tlfb_totaldrinks2 ) as tlfb_total_drinks,*/
/*      tlfb2.TLFB_TOTALDRINKINGDAYS, tlfb2.tlfb_complete30, tlfb2.tlfb_totaldrinks2 */
/*      from qs_tlfb_summary_v3_fmt as tlfb2 left join t2 on tlfb2.sequence_no_ = t2.seq and tlfb2.segment = t2.segment;*/
/*quit;*/

/*data tlfbout;*/
/*      set tlfb_combo;*/
/**/
/*      IF TLFB_TOTALDRINKINGDAYS >0 THEN */
/*            TLFB_AVG_drinksDD=round(tlfb_total_drinks/TLFB_TOTALDRINKINGDAYS, .1);*/
/*      ELSE TLFB_AVG_drinksDD=.;*/
/**/
/*     * AVG_drinksD=round(tlfb_total_drinks/30, .1);*/
/*      *AVG_alcoholDD_gr=round(AVG_drinksDD*14, .1);*/
/*      *AVG_alcoholD_gr=round(AVG_drinksD*14, .1);*/
/*   		tlfb_new_mop = 0; */
/*      if visit_date > '28MAY2014'd then tlfb_new_mop = 1; */
/**/
/*			label tlfb_avg_drinksDD= "TLFB Average Drinks Per Drinking Day"; */
/*			label tlfb_new_mop="TLFB Indicator for MOP change on 28MAY2014";*/
/*			label tlfb_totaldrinkingdays="TLFB Total Drinking Days";*/
/*			label tlfb_total_drinks="TLFB Total Drinks";*/
/*run;*/
/**/
/**/
/**/
/*%mend;*/
/**/
********End of Macro;


*****this macro changes the sequence number to numeric then creates the site variable, 
 also, sets 0 to missing for numeric fields that were required;

%macro datafix();


data followup; 
	retain StudyID;
	set followup_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Hematology; 
	retain StudyID;
	set CL_Hematology_V1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Bloodchem; 
	retain StudyID;
	set cl_bloodchem_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Coagulation; 
	retain StudyID;
	set cl_coagulation_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Lipids; 
	retain StudyID;
	set cl_lipids_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Otherlabs1; 
	retain StudyID;
	set cl_otherlabs_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Otherlabs2; 
	retain StudyID;
	set cl_otherlabs_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data ConMeds; 
	retain StudyID;
	set cm_001_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Death; 
	retain StudyID;
	set death_form_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data NIAAA; 
	retain StudyID;
	set QS_NIAAA_6Q_V1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data LiverHist; 
	retain StudyID;
	set DG_liver_histology_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Hospital; 
	retain StudyID;
	set hospitalization_form__v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Audit; 
	retain StudyID;
	set qs_audit_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data PTSD; 
	retain StudyID;
	set qs_pc_ptsd_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data SF36; 
	retain StudyID;
	set qs_sf_36v2__v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data SleepQS; 
	retain StudyID;
	set Qs_sleep_eb_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data TobaccoQS; 
	retain StudyID;
	set qs_tobacco_marijuana_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data BloodUrine; 
	retain StudyID;
	set sp_blood_urine_proc_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data PBMC; 
	retain StudyID;
	set sp_pbmc_proc_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Shipping; 
	retain StudyID;
	set sp_shipping_log_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Stool; 
	retain StudyID;
	set sp_stool_processing__v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Termination; 
	retain StudyID;
	set termination_v3_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data EligCases; 
	retain StudyID;
	set tr_0_elig_cases_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data EligControls; 
	retain StudyID;
	set tr_0_elig_controls_v3_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data SubjChar; 
	retain StudyID;
	set TR_1_subj_char_v3_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data CoffeeTea; 
	retain StudyID;
	set tr_2_coffee_tea_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data FamHist; 
	retain StudyID;
	set tr_3_fam_hist_alcohol_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data Complications; 
	retain StudyID;
	set tr_4_complicLD_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data LiverBiop; 
	retain StudyID;
	set tr_5_liverbiopsy_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;
data AnthroMeas; 
	retain StudyID;
	set tr_6_anthroms_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
	if WAIST_UMBILICUS = 0 then WAIST_UMBILICUS = . ;
	if WAIST_DIAMETER = 0 then WAIST_DIAMETER = . ;
	if HIP = 0 then HIP = . ;
	if WRIST = 0 then WRIST = .;
	if FOREARM = 0 then FOREARM = . ;
	if  MIDUPPER_ARM = 0 then  MIDUPPER_ARM = . ;
run;

data SpMeds1; 
	retain StudyID;
	set tr_7_specific_meds_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data SpMeds2; 
	retain StudyID;
	set tr_7_specific_meds_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;

data PhysExam; 
	retain StudyID;
	set tr_8_physexam_v2_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
run;


data VitalSigns; 
	retain StudyID;
	set tr_9_vital_signs_v1_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";
	if WEIGHTKG = 0 then WEIGHTKG = .;
	if bmi = 0 then bmi = .;
	if TEMPC = 0 then TEMPC = .;
	if BP_SYST = 0 then BP_SYST = .;
	if BP_DIAST = 0 then BP_DIAST = .;
	if PULSE_BPM = 0 then PULSE_BPM = .; 
	if RESPIRATION = 0 then RESPIRATION = .;
run;

data tlfb;
	Retain StudyID;
	set QS_TLFB_summary_V3_fmt;
	StudyID=input (sequence_no_,5.);
	drop sequence_no_;
	if StudyID >20000 and StudyID < 30000  then Site = "Mayo Clinic";
	if StudyID < 20000 then Site = "IU";
	if studyid >30000 then Site = "VCU";

  IF TLFB_TOTALDRINKINGDAYS >0 THEN 
  	TLFB_AVG_drinksDD=round(tlfb_totaldrinks2/TLFB_TOTALDRINKINGDAYS, .1);
	ELSE TLFB_AVG_drinksDD=.;

	tlfb_new_mop = 0; 
  if visit_date > '28MAY2014'd then tlfb_new_mop = 1; 

	label tlfb_avg_drinksDD= "TLFB Average Drinks Per Drinking Day"; 
	label tlfb_new_mop="TLFB Indicator for MOP change on 28MAY2014";

run;

%mend; 

***End of Macro;

%macro CreateDataDictionary(adsfolder, ddlocation, domdeclocation, optionsyn);

/* PART 1: Get the list of domains and each of their variables in the ADS folder location */

	libname templib "&adsfolder.";

	* Creates a dataset with ALL the variables in ALL the datasets of the templib library;
	proc datasets lib = templib noprint;
		contents data = _all_ out = work.tcont1;
	quit; run;

	* Drop non-essential variables and convert the TYPE variable to be text;
	data tcont2;
		set tcont1 (keep = MEMNAME NAME TYPE LENGTH FORMAT INFORMAT LABEL);

		rename MEMNAME = DOMAIN
			   NAME = VARIABLE;

		format TYPE2 $20.;
		if TYPE = 1 then TYPE2 = 'Numeric';
		else if TYPE = 2 then TYPE2 = 'Character';
		drop TYPE;
		rename TYPE2 = TYPE;
	run;

	* Create the datadictionary dataset, which will be output as an excel file below;
	data datadictionary;
		retain DOMAIN VARIABLE TYPE LENGTH FORMAT INFORMAT LABEL;
		set tcont2;

		* Create the NOTES variable (will be left blank -- to be filled out by DM);
		NOTES = '';

		label DOMAIN = 'Dataset / Domain'
			  VARIABLE = 'Variable'
			  TYPE = 'Type'
			  LENGTH = 'Length'
			  FORMAT = 'Format'
			  INFORMAT = 'Informat'
			  LABEL = 'Label'
			  NOTES = 'Notes';
	run;

	* Sort the datadictionary by domain / dataset name;
	proc sort data = datadictionary; by DOMAIN; run;


/* PART 2: Get the names of the forms that went into each domain, if applicable (OPTIONAL) */

	%if "&domdeclocation." ne "" %then %do;

		* Get the extension of the file that will be created;
		data _null_;
			FILEPATH = "&domdeclocation.";
			EXTPOS = length(FILEPATH) - length(scan(FILEPATH,-1,'.'));
			EXT = substr(FILEPATH,EXTPOS+1,length(FILEPATH)-EXTPOS);
			call symput('domdeclocextension', EXT);
		run;

		* Import the list of domains and their corresponding forms;
		proc import out = dd1 
			datafile = "&domdeclocation."
			dbms = &domdeclocextension. REPLACE;
			getnames = yes;
		run;

		* Only keep rows where a form has a designated domain / dataset name (and vice versa);
		data dd2;
			set dd1 (keep = FORM DOMAIN);
			if FORM = '' or DOMAIN = '' then delete;
			DOMAIN = upcase(DOMAIN); *Need these to be all upper case for the merge;
		run;

		proc sort data = dd2; by DOMAIN; run;

		* If multiple forms are assigned to one domain, this will merge those form names into one variable.
		  For example, if forms TX-001 and TX-002 were combined to create the TOXICITY dataset, then the
		  FORMS variable will contain the string 'TX-001, TX-002';
		data dd3;
			set dd2;
			by DOMAIN;

			format FORMS $200.;
			retain FORMS;
			if first.DOMAIN then FORMS = FORM;
			else FORMS = trim(FORMS) || "; " || trim(FORM);
		run;

		* Drop all but the last occurence of a domain name to get the one-to-one list of domains and
		  their corresponding form(s);
		data dd4;
			set dd3;

			by DOMAIN;
			if last.DOMAIN then output;

			drop FORM;
		run;

		* Merge the FORMS information into the datadictionary dataset;
		data datadictionary;
			retain DOMAIN FORMS VARIABLE TYPE LENGTH FORMAT INFORMAT LABEL;
			format DOMAIN $32.; *Format set so dataset names do not get cut off in the merge;
			merge datadictionary (in = a) dd4;
			by DOMAIN;
			if a;

			label FORMS = 'Form(s)';
		run;

	%end;


/* PART 3: Get the list of format options (OPTIONAL) */

	%if &optionsyn. = YES %then %do;

		* Capture the currently loaded formats as a dataset;
		proc format cntlout = fmtopts1; run;

		data fmtopts2;
			set fmtopts1 (keep = FMTNAME START LABEL TYPE);
			if TYPE = 'C' then do;
				FMTNAME = '$' || strip(FMTNAME);
				START = "'" || strip(START) || "'";
			end;
		run;

		proc sort data = fmtopts2; by FMTNAME START; run;

		data fmtopts3;
			set fmtopts2;
			by FMTNAME;

			format FMTOPTIONS $10000.;
			retain FMTOPTIONS;
			if first.FMTNAME then FMTOPTIONS = strip(START) || ', ' || strip(LABEL);
			else FMTOPTIONS = trim(FMTOPTIONS) || ' | ' || strip(START) || ', ' || strip(LABEL);
		run;

		data fmtopts4;
			set fmtopts3;

			by FMTNAME;
			if last.FMTNAME then output;

			drop START LABEL TYPE;

			rename FMTNAME = FORMAT;
		run;

		* Merge the format options in with the datadictionary dataset;
		proc sort data = datadictionary; by FORMAT; run;
		proc sort data = fmtopts4; by FORMAT; run;

		data datadictionary;
			retain DOMAIN FORMS VARIABLE TYPE LENGTH FORMAT FMTOPTIONS INFORMAT LABEL;
			merge datadictionary (in = a) fmtopts4;
			by FORMAT;
			if a;

			label FMTOPTIONS = 'Choices';
		run;

		* Restore original sorting order;
		proc sort data = datadictionary; by DOMAIN; run;

	%end;

	%if &optionsyn. = YES:TABBED %then %do;

		* Capture the currently loaded formats as a dataset;
		proc format cntlout = formats1; run;

		proc sort data = formats1; by FMTNAME; run;

		data formats;
			set formats1 (keep = FMTNAME START LABEL TYPE);
			if TYPE = 'C' then do;
				FMTNAME = '$' || strip(FMTNAME);
				START = "'" || strip(START) || "'";
			end;
			else do;
				START = strip(START);
			end;

			drop TYPE;

			label FMTNAME = 'Format name'
				  START = 'Value'
				  LABEL = 'Value label';
		run;

	%end;


/* PART 4: Export */

	* Create a new dataset with the name "Variables" so that the spreadsheet tab will have this name;
	data variables; set datadictionary; run;

	* Get the extension of the file that will be created;
	data _null_;
		FILEPATH = "&ddlocation.";
		EXTPOS = length(FILEPATH) - length(scan(FILEPATH,-1,'.'));
		EXT = substr(FILEPATH,EXTPOS+1,length(FILEPATH)-EXTPOS);
		call symput('ddlocextension', EXT);
	run;
	%put &ddlocextension.;

	* Export the data dictionary as a new file;
	%if &optionsyn. = YES:TABBED %then %do;	
		proc export data = variables outfile = "&ddlocation." dbms = excel replace label; sheet='Variables';
		proc export data = formats outfile = "&ddlocation." dbms = excel replace label; sheet='Formats';
		run;
	%end;
	%else %do;
		proc export data = variables outfile = "&ddlocation." dbms = &ddlocextension. replace label;
		run;
	%end;

	* Delete all of the temporary datasets used within this macro - keep datadictionary in case
	  further manipulation is desired;
	proc datasets nolist;
		delete dd1 dd2 dd3 dd4 fmtopts1 fmtopts2 fmtopts3 fmtopts4 formats formats1 tcont1 tcont2 variables;
	quit; run;

%mend;









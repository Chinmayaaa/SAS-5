/************************
TREAT 001 Import program

This program will import the data from OnCore SAS files into a folder with the current date and QC folder. 


CHANGE ALL THE PATHs to YOUR STUDY FOLDER FILE PATHS!!

*/

* delete all sas and txt files from rawdata folder that were created in the previous run of this code;
/*Updates:
4/11/2016 Abhidnya Kawli:  Merged SpMeds1 and SpMeds2 into SpMeds. Also merged Otherlabs1 and Otherlabs2 into Otherlabs. 
						   These datasets need to be merged for creating the analysis datasets as well as for QC.
****************************************************************************************************************/


%let path=I:\Projects\TREAT\Data Management\OnCore Data\Rawdata;
filename filrf "&path.";
data _null_;
  did = dopen('filrf');
  memcount = dnum(did);
  do while (memcount>0);
    fname = dread(did,memcount);
    if scan(lowcase(fname),2,'.')='sas' or scan(lowcase(fname),2,'.')='txt' then do;
        rcref = filename('fref',catx('\',"&path.",fname));
        rcdel = fdelete('fref');
    end;
    memcount+-1;
  end;
  stop;
run;

%include 'I:\Projects\TREAT\Data Management\sas\SASMacros\OnCoreMacros.sas';

*Copy the .sas files from the download folder TO the Raw Data Folder;
%CopyOnCoreSASFiles(I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\Downloads\,
				I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\)

		
*Call the macro that creates the Formats.sas program;
%CreateOncoreFormatFile(I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\,
			I:\Projects\TREAT\Data Management\OnCore Data\,formats.sas);


*Call the macro that copies the data .txt files to the Raw Data folder;
%CopyOnCoreTextFiles(I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\Downloads\,
				I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\);


*Call the macro that runs the moved SAS programs;
%RunBatchSASFiles(I:\Projects\TREAT\Data Management\OnCore Data\Rawdata\);


%include 'I:\Projects\TREAT\Data Management\sas\SASMacros\ImportMacro.sas';


%DemoRace();


%datafix();


options dlcreatedir;
* these are the datasets to use for analysis since they are in static folders;
libname Datasets "I:\Projects\TREAT\Data Management\OnCore Data\Datasets\&sysdate";
* these are the datasets to use for QC and to generate regular reports since you will not have to 
	change the directory location in the code using this library;
libname QCdata "I:\Projects\TREAT\Data Management\OnCore Data\Datasets\QC";


title 'Copy datasets';
proc datasets  library = work;
	copy out = Datasets;
	select  
		AnthroMeas
		Audit	
		Bloodchem
		BloodUrine
		Coagulation
 		CoffeeTea
		Complications
		ConMeds
		Death
		demog
		EligCases
	 	EligControls
		FamHist
		followup
		Hematology
		Hospital
		Lipids
		LiverBiop
		LiverHist
		Otherlabs1
		Otherlabs2
	 	NIAAA
		PBMC
		PhysExam
		PTSD
	 	SF36
		Shipping
	 	SleepQS	
		SpMeds1
		SpMeds2
		Stool
	 	SubjChar
		Termination
		tlfb
	 	TobaccoQS
		VitalSigns;
run;

/*Merged SpMeds1 and SpMeds2 into SpMeds. Also merged Otherlabs1 and Otherlabs2 into Otherlabs. 
  These datasets need to be merged for creating the analysis datasets as well as for QC. */

proc sort data=Datasets.SpMeds1;
by studyid segment;
run;

proc sort data=Datasets.SpMeds2;
by studyid segment;
run;

proc sort data=Datasets.Otherlabs1;
by studyid segment;
run;

proc sort data=Datasets.Otherlabs2;
by studyid segment;
run;

data Datasets.SpMeds;
merge Datasets.SpMeds1 Datasets.SpMeds2;
by studyid segment;
run;

data Datasets.Otherlabs;
merge Datasets.Otherlabs1 Datasets.Otherlabs2;
by studyid segment;
run;

proc datasets library = Datasets;
	copy out = QCdata;
run;

%CreateDataDictionary(I:\Projects\TREAT\Data Management\OnCore Data\Datasets\&SYSDATE, 
										I:\Projects\TREAT\Data Management\OnCore Data\Codebook.xlsx,,YES);


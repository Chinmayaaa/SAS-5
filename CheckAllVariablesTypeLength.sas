/*******************************************************/
/*** TIP 00403
This checks the attributes of all variables in selected
sas library (directory) for consistency in its data type
and lengths.  If any are different, it will list out all
of the entries for your review and you decide if they are OK.

It is possible the same name of a SAS variable is used
for a different purpose or data field in another Dataset and
may not be a problem.

Be sure the SAS libname ref has been issued before running
the macro chkattrs.

***/


%macro chkattrs( saslib=sasuser, sasvar=* );
/***
1st Parameter saslib = name of SAS Library
2nd Parameter sasvar = name of SAS variable in question, "*"
    for all variables to be checked.
***/

  %let saslib = %upcase( &saslib );
  %let sasvar = %upcase( &sasvar );

  /*** get list of all sas datasets and selected sasvar if chosen ***/
  PROC SQL;
  create table CHKATTRS as
  select *
  from SASHELP.VCOLUMN
    where
      upcase(libname) = "&saslib"
      and upcase(memtype) = "DATA"
    %if "&sasvar" ne "*" %then %do;
      and upcase(name   ) = "&sasvar"
    %end;
  ORDER BY libname, name, memtype, memname;
  quit;

  /*** now check to see if attributes are identical across all
       sas datasets in library ***/
  data inconsistent (drop=flag tmptype tmplength tmpname);
   set chkattrs;
   by libname name memtype memname;
   retain tmptype tmplength tmpname;
   if first.name then do;
              flag = 0;
              tmptype = type;
            tmplength = length;
            tmpname   = name;
   end;
     if name eq tmpname then do;
        if type   ne tmptype   then flag + 1;
        if length ne tmplength then flag + 1;
        if flag gt 0 then output;
     end;
  run;

  /*** select only 1 record per sasvar (name) ***/
  proc sort data=inconsistent out=inconsistent nodupkey; by libname name; run;

  data _null_;
   if 0 then set inconsistent nobs=numobs;
   CALL SYMPUT('NUMOBS' ,PUT(NUMOBS , BEST.));
   stop;
  run;

  %if &numobs ne 0 %then %do;
    /*** also need to get the full path name of SAS library ref
         to document where to go if inconsistencies exist ***/
    proc sql;
     create table mixattrs as
     select *
     from chkattrs a,
          inconsistent b,
          SASHELP.VMEMBER c
     where b.name    = a.name
       and b.libname = c.libname
       and b.memname = c.memname
     ;
    quit;

    options ls=132 pagesize=59;
    Title1 "These variables are INCONSISTENT with respect to ATTRIBUTES";
    PROC PRINT DATA=mixattrs LABEL SPLIT=' '; run;
  %end;
  %else %do;
   Title "All Variables are Consistent and Well Behaved in the &saslib Directory";
   data _null_;
   file print notitles;
   put "All variables are Consistent and Well Behaved in &saslib directory";
   run;
  %end;

   /***
   proc sql; drop table chkattrs inconsistent mixattrs; quit;
   ***/

%mend chkattrs;
/*** sample call to macro ***/
***%chkattrs( saslib=mylib, sasvar=effdate  );
***%chkattrs( saslib=mylib, sasvar=*        );
/*** end of tip00403 ***/

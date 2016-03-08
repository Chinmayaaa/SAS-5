/*
          Name:  ShrinkCharVars

   Description:  This macro will find the maximum length of each character variable in the 
			data file then write a DATA Step that issues new LENGTH and FORMAT statements for each 
			character variable, and then read the data. The goal is to make the data file as small 
			as possible without using compression. 

          Type:  Data Cleaning

     Arguments:  Dataset name containing character variables to shrink

  Other Inputs: <none>

        Output: Same dataset as input 

   Usage Notes:  Can output to a different dataset by changing the last proc data output.

  Calls macros:  None

   History:   Date        Init  Comments
              10/27/2010  ACB   Creation
*/


%macro ShrinkCharVars(dsn);                                         
                                                            
data _null_;                                                
  set &dsn;                                                 
  array qqq(*) _character_;                                 
  call symput('siz',put(dim(qqq),5.-L));                    
  stop;                                                     
run;                                                        
                                                            
data _null_;                                                
  set &dsn end=done;                                        
  array qqq(&siz) _character_;                              
  array www(&siz.);                                         
  if _n_=1 then do i= 1 to dim(www);                        
    www(i)=0;                                               
  end;                                                      
  do i = 1 to &siz.;                                        
    www(i)=max(www(i),length(qqq(i)));                      
  end;                                                      
  retain _all_;                                             
  if done then do;                                          
    do i = 1 to &siz.;                                      
      length vvv $50;                                       
      vvv=catx(' ','length',vname(qqq(i)),'$',www(i),';');  
      fff=catx(' ','format ',vname(qqq(i))||' '||           
          compress('$'||put(www(i),3.)||'.;'),' ');         
      call symput('lll'||put(i,3.-L),vvv) ;                 
      call symput('fff'||put(i,3.-L),fff) ;                 
    end;                                                    
  end;                                                      
run;                                                        
                                                            
data &dsn._;                                                
  %do i = 1 %to &siz.;                                      
    &&lll&i                                                 
    &&fff&i                                                 
  %end;                                                     
  set &dsn;                                                 
run;                                                        
                                                            
%mend;               

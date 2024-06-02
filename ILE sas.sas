libname ile 'C:\Users\Bobie\Desktop\ILE';

data ilestart;
set ile.nhanes2016;
run;

proc contents data=ile.nhanes2016;
run;
*used Friedewald formula to calculate LDL;
data ilestart_filtered;
set ilestart;
LBDLDL = round(LBXTC-(LBDHDD+LBXSTR/5));
run;


proc contents data=ilestart_filtered;
run;

data ilestart_raw;
set ilestart_filtered;
where LBDLDL is not missing;
run;

data ilestart_grp1;
set ilestart_filtered;
keep SEQN RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 LBDLDL DIQ010 DIQ160;
run;


proc contents data=ilestart_grp1;
run;

proc print data=ilestart_grp1;
run;

data ilestart_grp2;
set DBQ_I;
keep SEQN DBD900;
run;

proc sort data=ilestart_grp1; 
by SEQN; 
run;

proc sort data=ilestart_grp2; 
by SEQN; 
run;

data merged_ILEdataset;
merge ilestart_grp1(in=a) ilestart_grp2(in=b);
by SEQN;
run;

proc print data=merged_ILEdataset;
run;

data merged_ILEfinal;
set merged_ILEdataset;
if DBD900=. then DBD900final=.;
else if DBD900=0 then DBD900final=0;
else if DBD900 =>1 then DBD900final=1;
run; 

proc print data=merged_ILEfinal;
run;

proc format;
value RIAGENDRf 1="Male" 2="Female" . =' ';
value RIDRETH1f 1='Mexican American' 2='Other Hispanic' 3='Non-Hispanic White' 4='Non-Hispanic Black' 5='Other Race - Including Multi-Racial' . =' ';
value DMDHREDUf 1='Less Than 9th Grade' 2='9-11th Grade' 3='High School Grad/GED or Equivalent' 4='Some College or AA degree' 5='College Graduate or above' 9='Do not know' . =' ';
value INDHHIN2f 1,2,3,4,5,12,13='$ 0 to $ 24,999'  6,7,8='$25,000 to $54,999' 9,10,14='$55,000 to $99,999' 15='$100,000 and Over' 77='Refused' 99='Do not know'. =' ';
value DBD900finalf 0='No' 1='Yes'. =' ';
value DIQ010f 1='Yes' 2='No' 3='Borderline' 7='Refused' 9='Do not know'. =' ';
value DIQ160f 1='Yes' 2='No' 3='Borderline' 7='Refused' 9='Do not know' . =' ';
run;


data ILEfinal22;
set merged_ILEfinal;
format RIAGENDR RIAGENDRf. RIDRETH1 RIDRETH1f. DMDHREDU DMDHREDUf. INDHHIN2 INDHHIN2f. DBD900final DBD900finalf. DIQ010 DIQ010f. DIQ160 DIQ160f. ;
run;

data ILEfinal;
set ILEfinal22;
where LBDLDL is not missing;
run;

proc sort data=ILEfinal;
by DBD900final;
run;

proc print data=ILEfinal;
run;

proc freq data=ILEfinal;
tables RIDAGEYR;
run;

proc freq data=ILEfinal;
tables DBD900final;
run;


proc means data=ILEfinal mean std maxdec=2;
var RIDAGEYR BMXBMI LBDLDL LBDHDD;
by DBD900final;
run;

proc freq data=ILEfinal;
tables RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 DIQ010 DIQ160;
by DBD900final;
run;

*Model testing=unadjusted;
proc glm data=ILEfinal;
class DBD900final(ref='No');
model LBDLDL=DBD900final/solution clparm;
lsmeans DBD900final /tdiff adjust=tukey cl;
run;

*Model 1;
proc glm data=ILEfinal;
class DBD900final(ref='No')RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White');
model LBDLDL=DBD900final RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 /solution clparm;
run;

*Model 2;
proc glm data=ILEfinal;
class DBD900final(ref='No')RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') ;
model LBDLDL=DBD900final RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU  /solution clparm;
run;

*Model 3;
proc glm data=ILEfinal;
class DBD900final(ref='No')RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') INDHHIN2(ref='$25,000 to $54,999') ;
model LBDLDL=DBD900final RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 /solution clparm;
run;

*Removing Borderline,Refused and Do not know using ;
data ILEfinaldata;
set ILEfinal;
if DIQ010=3 then delete;
else if DIQ010=7 then delete;
else if DIQ010=9 then delete;
if DIQ160=3 then delete;
else if DIQ160=7 then delete;
else if DIQ160=9 then delete;
run;

proc print data=ILEfinaldata;
run;

proc freq data=ILEfinaldata;
tables DIQ010;
run;

*Effect modication 1 Doctor told you have diabetes;
proc glm data=ILEfinaldata;
class DBD900final(ref='No') DIQ010 (ref='No') RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') INDHHIN2(ref='$25,000 to $54,999');
model LBDLDL=DBD900final*DIQ010 DBD900final DIQ010 RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 /solution clparm;
run;


*stratification based on diabetes;
data Diabetes_set ;
set ILEfinaldata;
if DIQ010 =1 then output Diabetes_set;
run;

data NonDiabetes_set;
set ILEfinaldata;
if DIQ010=2 then output NonDiabetes_set;
run;

proc print data=NonDiabetes_set;
run;

*Effect modication by stratification based on diabetes;
*Diabetes;
proc glm data=Diabetes_set;
class DBD900final(ref='No') RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') INDHHIN2(ref='$25,000 to $54,999');
model LBDLDL=DBD900final*DIQ010 DBD900final DIQ010 RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 /solution clparm;
run;

*NonDiabetes;
proc glm data=NonDiabetes_set;
class DBD900final(ref='No') RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') INDHHIN2(ref='$25,000 to $54,999');
model LBDLDL=DBD900final*DIQ010 DBD900final DIQ010 RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 /solution clparm;
run;


*test other models;
*Effect modification 2 Ever told you have prediabetes;
proc glm data=ILEfinaldata;
class DBD900final(ref='No') DIQ160 (ref='No') RIAGENDR(ref='Female') RIDRETH1(ref='Non-Hispanic White') DMDHREDU(ref='High School Grad/GED or Equivalent') INDHHIN2(ref='$25,000 to $54,999');
model LBDLDL=DBD900final*DIQ160 DBD900final DIQ160 RIDAGEYR LBDHDD BMXBMI RIAGENDR RIDRETH1 DMDHREDU INDHHIN2 /solution clparm;
run;



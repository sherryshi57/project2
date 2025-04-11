

%let pg2dataset=E:\github\project 2\1-dataset; /* Set the file path folder to your own file path */
%let pg2output=E:\github\project 2\3-output;  /* Set the file path folder to your own file path */

* Set a libref for the dataset;
libname pg2 "&pg2dataset";

* Define the libref for the XPT file;
libname xptlib1 xport "&pg2dataset\LLCP2021.XPT_";
libname xptlib2 xport "&pg2dataset\LLCP2022.XPT_";

* Use PROC COPY to transfer datasets;
proc copy in=xptlib1 out=pg2;
run;
proc copy in=xptlib2 out=pg2;
run;

data pg2.LLCP2021data;
    set pg2.LLCP2021;
run;
data pg2.LLCP2022data;
    set pg2.LLCP2022;
run;

proc contents data=pg2.LLCP2021data noprint out=varlist2021(keep=Name);
run;

proc print data=varlist2021;
run;


*******************************************************************;
********************    second table    ***************************;
*******************************************************************;



data pg2.LLCP2021_filter_2;
	retain  _STATE _LLCPWT _STSTR _PSU CAREGIV1 _AGE_G SEXVAR _RACE PHYSHLTH MENTHLTH POORHLTH EXERANY2 _RFDRHV7 _RFBING5 _RFSMOK3 GENHLTH;
	set pg2.LLCP2021data;
	keep  _STATE  _LLCPWT _STSTR _PSU CAREGIV1 _AGE_G SEXVAR _RACE PHYSHLTH MENTHLTH POORHLTH EXERANY2 _RFDRHV7 _RFBING5 _RFSMOK3 GENHLTH;
run;
data pg2.LLCP2022_filter_2;	
	retain _STATE _LLCPWT _STSTR _PSU CAREGIV1 _AGE_G SEXVAR _RACE1 PHYSHLTH MENTHLTH POORHLTH EXERANY2 _RFDRHV8 _RFBING6 _RFSMOK3 GENHLTH;
	set pg2.LLCP2022data;
	rename _RFDRHV8=_RFDRHV7 _RFBING6=_RFBING5 _RACE1=_RACE;
	keep  _STATE _LLCPWT _STSTR _PSU CAREGIV1 _AGE_G SEXVAR _RACE1 PHYSHLTH MENTHLTH POORHLTH EXERANY2 _RFDRHV8 _RFBING6 _RFSMOK3 GENHLTH;
run;


/* Merge two datasets */
proc sql;
   create table pg2.filter_2021_2022_2 as
   select *, 2021 as year from pg2.LLCP2021_filter_2
   union all
   select *, 2022 as year from pg2.LLCP2022_filter_2;
quit;




data filter_2021_2022_2;
	set pg2.filter_2021_2022_2;
	*_STATE expansion state ys non-expansion state; 
	*if _STATE in(2, 4, 5, 6, 8, 9, 10, 11, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36, 38, 39, 40, 41, 42, 44, 49, 50, 51, 53, 54)
 	then expansion_state = 1;
	*else if _STATE in(1,12,13,20,28,37,45,46,47,48,55,56,66,72,78)then expansion_state = 0;

	*CAREGIV1 caregiver;
    if CAREGIV1 in (1) then caregive = 1;
	else if CAREGIV1 in (2) then caregive = 0;
    else caregive = .;
	*_AGE_G age group;
	if _AGE_G in (1, 2, 3) then age='18-44';
	else if _AGE_G in (4, 5) then age='45-64';
	else if _AGE_G in (6) then age='65+';
	*SEXVAR ;
	if SEXVAR = 2 then gender ='Female';
	else if SEXVAR = 1 then gender = 'Male';
	else gender = '';
	*_RACE ;
	if _RACE = 8 then race = 'Hispanic';
    else if _RACE = 1 then race = 'White';
    else if _RACE = 2 then race = 'Black';
    else if _RACE = 4 then race = 'Asian';
    else if _RACE = 6 then race = 'Other';
	*PHYSHLTH>=14 14+ days in past month of poor physical health;
	if PHYSHLTH>=14 then physical_flag = 1;
	else physical_flag = 0;
	*MENTHLTH>=14 14+ days in past month of poor mental health;
	if MENTHLTH>=14 then mental_flag = 1;
	else mental_flag = 0;
	*POORHLTH>=14 14+ days per month of poor health prohibiting normal activities; 
	if POORHLTH>=14 then proh_n_flag = 1;
	else proh_n_flag = 0;
	*EXERANY2=1 Able to exercise in past month;
	if EXERANY2=1 then exercise_flag = 1;
	else exercise_flag = 0;	 
	*_RFDRHV7=2 Heavy drinking; 
	if _RFDRHV7=2 then heavy_dr_flag = 1;
	else heavy_dr_flag = 0;
	*_RFBING5=2 Binge drinking; 
	if _RFBING5=2 then binge_dr_flag = 1;
	else binge_dr_flag = 0;
	*_RFSMOK3=2 smoking;
	if _RFSMOK3=2 then smoke_flag = 1;
	else smoke_flag = 0;
	*GENHLTH=5 Poor general health;
	if GENHLTH=5 then p_gen_flag = 1;
	else p_gen_flag = 0;
	*GENHLTH=4 or 5 Poor and fair health;
	if GENHLTH in (4 5) then p_f_flag = 1;
	else p_f_flag = 0;

run;


%macro crosstabsfreq_2(var);

    /* Generate a shortened variable name to use in dataset names */
	%let var_short = %substr(&var, 1, %sysfunc(min(%length(&var), 25)));

    /* Run survey frequency procedure to create crosstab data */
    ods exclude all;
    proc surveyfreq data=filter_2021_2022_2;
        ods output CrossTabs=ctOut_&var_short ChiSq=chi_2_&var_short; /* Use shortened variable name */
        weight _LLCPWT;
        strata _STSTR;
        cluster _PSU;
        table caregive*&var / row cl chisq;
    run;
    ods exclude none;

    /* Process crosstab output and split by caregive values */
	data cg_0_&var_short (drop=caregive rename=(Weighted=weighted_non RowPercent=non_rowpercent RowLowerCL=non_rowlowerci RowUpperCL=non_rowupperci))
	     cg_1_&var_short (drop=caregive rename=(Weighted=weighted_family RowPercent=family_rowpercent RowLowerCL=family_rowlowerci RowUpperCL=family_rowupperci))
	     cg_t_&var_short (drop=caregive Weighted RowPercent RowLowerCL RowUpperCL);
		/* Ensure consistent length for Demographic_Group */
	    length Demographic_Group $50;
		set ctOut_&var_short(rename=(F_&var=Demographic_Group));
		
		/* Generate the Weighted string with confidence intervals */
		Weighted = ifc(caregive ne ., 
		               compress(put(RowPercent, 6.1)) || "%" || 
		               " (" || compress(put(RowLowerCL, 6.1)) || "%, " || compress(put(RowUpperCL, 6.1)) || "%)", 
		               "");
		
		/* Assign Unweighted_N only for caregive missing values */
		if caregive = . then Unweighted_N = Frequency;
		format Unweighted_N comma10.;

		/* Output data to appropriate dataset based on caregive value */
		if caregive = 0 then output cg_0_&var_short;
		else if caregive = 1 then output cg_1_&var_short;
		else if caregive = . then output cg_t_&var_short;
	run;

    /* Merge the datasets and calculate Marginal Difference */
	data final_2_&var_short;
	    length Demographic_Group $50; /* Ensure consistent length */
	    merge cg_0_&var_short (in=a) cg_1_&var_short (in=b) cg_t_&var_short (in=c);
	    by Demographic_Group;

		/* Extract substring after '*' */
		Table = scan(Table, 2, '*');
        Table = strip(Table); /* Remove leading/trailing spaces */
        
	    /* Calculate Marginal Difference and Confidence Intervals */
	    if a and b then do;
	        Marginal_Difference = family_rowpercent - non_rowpercent;
	        Marginal_Lower_CI = family_rowlowerci - non_rowlowerci;
	        Marginal_Upper_CI = family_rowupperci - non_rowupperci;

	        /* Create formatted Marginal Difference string with CI */
	        Marginal_Diff_CI = catx(" ", put(Marginal_Difference, 5.1), 
	                                "(", put(Marginal_Lower_CI, 5.1), "%, ", 
	                                put(Marginal_Upper_CI, 5.1), "%)");
	    end;

	    /* Keep only necessary columns */
	    keep Table Demographic_Group Unweighted_N weighted_family weighted_non Marginal_Diff_CI;
	run;

%mend crosstabsfreq_2;

/* Run the macro for each variable */
%crosstabsfreq_2(physical_flag);
%crosstabsfreq_2(mental_flag);
%crosstabsfreq_2(proh_n_flag);
%crosstabsfreq_2(exercise_flag);
%crosstabsfreq_2(heavy_dr_flag);
%crosstabsfreq_2(binge_dr_flag);
%crosstabsfreq_2(smoke_flag);
%crosstabsfreq_2(p_gen_flag);
%crosstabsfreq_2(p_f_flag);


data final_crosstable_2;
	*length Table $50 Demographic_Group $50;
	retain Table unweighted_n weighted_family weighted_non marginal_diff_ci;
	set 
		final_2_physical_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_mental_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_proh_n_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_exercise_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_heavy_dr_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_binge_dr_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_smoke_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_p_gen_flag (where=(index(Demographic_Group, '1') > 0))
		final_2_p_f_flag (where=(index(Demographic_Group, '1') > 0));
	keep Table unweighted_n weighted_family weighted_non marginal_diff_ci;

run;


proc export data=final_crosstable_2
    outfile="&pg2output\final_crosstable_2.xlsx"
    dbms=xlsx
    replace;
run;

data final_chisq_2;
	length Table $256 Name1 $20 cValue1 $50;
    retain Table Name1 cValue1;
	
   	set 
		chi_2_physical_flag (where=(Name1 = "P_RSCHI"))
		chi_2_mental_flag (where=(Name1 = "P_RSCHI"))
		chi_2_proh_n_flag (where=(Name1 = "P_RSCHI"))
		chi_2_exercise_flag (where=(Name1 = "P_RSCHI"))
		chi_2_heavy_dr_flag (where=(Name1 = "P_RSCHI"))
		chi_2_binge_dr_flag (where=(Name1 = "P_RSCHI"))
		chi_2_smoke_flag (where=(Name1 = "P_RSCHI"))
		chi_2_p_gen_flag (where=(Name1 = "P_RSCHI"))
		chi_2_p_f_flag (where=(Name1 = "P_RSCHI"));

	/* Extract substring after '*' */
	Table = scan(Table, 2, '*');
    Table = strip(Table); /* Remove leading/trailing spaces */

    keep Table Name1 cValue1;

run;


proc export data=final_chisq_2
    outfile="&pg2output\final_chisq_2.xlsx"
    dbms=xlsx
    replace;
run;



%macro RiskE_2(var);
    ods exclude all;
    /* Survey frequency procedure for unadjusted risk differences */
    proc surveyfreq data=filter_2021_2022_2;
        ods output Risk1=RiskE_&var;
        weight _LLCPWT;
        strata _STSTR;
        cluster _PSU;
        table caregive*&var / row cl chisq riskdiff;
    run;
    /* Survey regression procedure for adjusted risk differences */
    proc surveyreg data=filter_2021_2022_2;
        class &var(ref='0') age gender race;
        model caregive = &var age gender race;
        weight _LLCPWT;
        strata _STSTR;
        cluster _PSU;
        lsmeans &var / diff cl;
        ods output Diffs=Adju_&var;
    run;
    ods exclude none;

    /* Process unadjusted risk differences */
    data RiskE_&var._total;
        set RiskE_&var;
        if _N_ = 4; /* Assuming the desired row is always the fourth one */

		/* Extract substring after '*' */
		Table = scan(Table, 2, '*');
        Table = strip(Table); /* Remove leading/trailing spaces */
        
        Unadjusted_Risk_Diff = catx(" ", put(Risk, 8.4), "(", put(LowerCL, 8.4), ",", put(UpperCL, 8.4), ")");
        
        keep Table Unadjusted_Risk_Diff;
    run;

    /* Process adjusted risk differences */
    data Adju_&var._total;
        set Adju_&var;
        Adjusted_Risk_Diff = cats(put(Estimate, 8.4), " (", put(Lower, 8.4), ", ", put(Upper, 8.4), ")");
        keep Effect Adjusted_Risk_Diff;
    run;

    /* Merge unadjusted and adjusted datasets */
    data Merged_&var;
        merge RiskE_&var._total 
              Adju_&var._total(rename=(Effect=Table));
        by Table; 
    run;

%mend RiskE_2;


%RiskE_2(physical_flag);
%RiskE_2(mental_flag);
%RiskE_2(proh_n_flag);
%RiskE_2(exercise_flag);
%RiskE_2(heavy_dr_flag);
%RiskE_2(binge_dr_flag);
%RiskE_2(smoke_flag);
%RiskE_2(p_gen_flag);
%RiskE_2(p_f_flag);



data final_riske_2;
	retain Table Unadjusted_Risk_Diff Adjusted_Risk_Diff;
	set 
		merged_physical_flag 
		merged_mental_flag 
		merged_proh_n_flag 
		merged_exercise_flag 
		merged_heavy_dr_flag 
		merged_binge_dr_flag 
		merged_smoke_flag 
		merged_p_gen_flag
		merged_p_f_flag;
    keep Table Unadjusted_Risk_Diff Adjusted_Risk_Diff;

run;


proc export data=final_riske_2
    outfile="&pg2output\final_riske_2.xlsx"
    dbms=xlsx
    replace;
run;

proc sql;
    create table table2 as
    select 
        a.Table,
        a.unweighted_n,
        a.weighted_family,
        a.weighted_non,
        b.Unadjusted_Risk_Diff,
        b.Adjusted_Risk_Diff,
        c.cValue1 as p_value,
        a.marginal_diff_ci
    from final_crosstable_2 as a
    left join final_riske_2 as b
        on a.Table = b.Table
    left join final_chisq_2 as c
        on a.Table = c.Table
    order by 
        case 
            when a.Table = 'physical_flag' then 1
            when a.Table = 'mental_flag' then 2
            when a.Table = 'proh_n_flag' then 3
            when a.Table = 'exercise_flag' then 4
            when a.Table = 'heavy_dr_flag' then 5
            when a.Table = 'binge_dr_flag' then 6
            when a.Table = 'smoke_flag' then 7
            when a.Table = 'p_gen_flag' then 8
            when a.Table = 'p_f_flag' then 9
            else 10
        end;
quit;



proc export data=table2
    outfile="&pg2output\table2.xlsx"
    dbms=xlsx
    replace;
run;
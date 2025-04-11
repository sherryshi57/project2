
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



data pg2.LLCP2021_filter_1;
	retain IYEAR _STATE CHILDREN HHADULT NUMADULT _LLCPWT _STSTR _PSU CAREGIV1 CRGVEXPT _AGE_G SEXVAR _RACE INCOME3 _BMI5CAT DIABETE4 BPHIGH6 TOLDHI3 CVDINFR4 CVDCRHD4 CVDSTRK3 ASTHNOW CHCOCNCR CHCCOPD3 ADDEPEV3 CHCKDNY2;
	set pg2.LLCP2021data;
	keep IYEAR _STATE CHILDREN HHADULT NUMADULT _LLCPWT _STSTR _PSU CAREGIV1 CRGVEXPT _AGE_G SEXVAR _RACE INCOME3 _BMI5CAT DIABETE4 BPHIGH6 TOLDHI3 CVDINFR4 CVDCRHD4 CVDSTRK3 ASTHNOW CHCOCNCR CHCCOPD3 ADDEPEV3 CHCKDNY2;
run;
data pg2.LLCP2022_filter_1;	
	retain IYEAR _STATE CHILDREN HHADULT NUMADULT _LLCPWT _STSTR _PSU CAREGIV1 CRGVEXPT _AGE_G SEXVAR _RACE1 INCOME3 _BMI5CAT DIABETE4 BPHIGH6 TOLDHI3 CVDINFR4 CVDCRHD4 CVDSTRK3 ASTHNOW CHCSCNC1 CHCCOPD3 ADDEPEV3 CHCKDNY2;
	set pg2.LLCP2022data;
	rename _RACE1=_RACE CHCSCNC1=CHCOCNCR;
	BPHIGH6=.;
	TOLDHI3=.;
	keep IYEAR _STATE CHILDREN HHADULT NUMADULT _LLCPWT _STSTR _PSU CAREGIV1 CRGVEXPT _AGE_G SEXVAR _RACE1 INCOME3 _BMI5CAT DIABETE4 BPHIGH6 TOLDHI3 CVDINFR4 CVDCRHD4 CVDSTRK3 ASTHNOW CHCSCNC1 CHCCOPD3 ADDEPEV3 CHCKDNY2;
run;


/* Merge two datasets */
proc sql;
   create table pg2.filter_2021_2022 as
   select *, 2021 as year from pg2.LLCP2021_filter_1
   union all
   select *, 2022 as year from pg2.LLCP2022_filter_1;
quit;




data filter_2021_2022_1;
	set pg2.filter_2021_2022;
	*_STATE expansion state ys non-expansion state; 
	*if _STATE in(2, 4, 5, 6, 8, 9, 10, 11, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36, 38, 39, 40, 41, 42, 44, 49, 50, 51, 53, 54)
 	then expansion_state = 1;
	*else if _STATE in(1,12,13,20,28,37,45,46,47,48,55,56,66,72,78)then expansion_state = 0;
	*CHILDREN children group;
	children_clean = ifn(1 <= CHILDREN <= 87, CHILDREN, 0);
	children_flag = ifn(1 <= CHILDREN <= 87, 1, 0);
	*HHADULT hhadult-only on the cell phone survey;
    hhadult_clean = ifn(1 <= HHADULT <= 76, HHADULT, 0);
  	*NUMADULT adult numbere-only on the land line survey;
    * total family size, exclude missing value;
    hh_size = SUM(NUMADULT, hhadult_clean, children_clean);
    if (NUMADULT eq . and hhadult_clean eq 0 ) or hh_size eq 0 then hh_size = .;

	*_LLCPWT weight _STSTR stratification _PSU sequence number;
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
	*INCOME3 income_num;
    select (INCOME3);
        when (1) income_num = 10000;
        when (2) income_num = 15000;
        when (3) income_num = 20000;
        when (4) income_num = 25000;
        when (5) income_num = 35000;
        when (6) income_num = 50000;
        when (7) income_num = 75000;
        when (8) income_num = 100000;
        when (9) income_num = 150000;
        when (10) income_num = 200000;
        when (11) income_num = 210000;* >200000;
        otherwise income_num = .; 
    end;
 	*Household Income %FPL;
	/* Alaska, Hawaii, and Other States FPG Calculation for 2021 & 2022 */
	if hh_size >= 1 then do;
	    select (_state);
	        when (2) do; /* Alaska */
	            if year = 2021 then fpg = 100 * (income_num / (16090 + (hh_size - 1) * 5680));
	            else if year = 2022 then fpg = 100 * (income_num / (16990 + (hh_size - 1) * 5900));
	        end;
	        when (15) do; /* Hawaii */
	            if year = 2021 then fpg = 100 * (income_num / (14820 + (hh_size - 1) * 5220));
	            else if year = 2022 then fpg = 100 * (income_num / (15630 + (hh_size - 1) * 5430));
	        end;
	        otherwise do; /* Other States */
	            if year = 2021 then fpg = 100 * (income_num / (12880 + (hh_size - 1) * 4540));
	            else if year = 2022 then fpg = 100 * (income_num / (13590 + (hh_size - 1) * 4720));
	        end;
	    end;
	end;
	length hh_income $ 15;
	if 0 <= fpg < 138 then hh_income = '<138%FPL';
	else if 138 <= fpg < 200 then hh_income = '139-200%FPL';
	else if 200 <= fpg < 400 then hh_income = '201-400%FPL';
	else if fpg >= 400 then hh_income = '>400%FPL';

	/* Medical Conditions */

	* Obesity (_BMI5CAT=4);
	if _BMI5CAT = 4 then obesity_flag = 1;
	else obesity_flag = 0;
	* Diabetes (DIABETE4=1);
	if DIABETE4 = 1 then diabetes_flag = 1;
	else diabetes_flag = 0;
	* Hypertension (BPHIGH6=1) - Only for 2021;
	if BPHIGH6 = 1 then hypertension_flag = 1;
	else hypertension_flag = 0;
	* Hyperlipidemia (TOLDHI3=1)- Only for 2021;
	if TOLDHI3 = 1 then hyperlipidemia_flag = 1;
	else hyperlipidemia_flag = 0;
	* Myocardial infarction (CVDINFR4=1);
	if CVDINFR4 = 1 then myocardial_infarction_flag = 1;
	else myocardial_infarction_flag = 0;
	* Coronary artery disease (CVDCRHD4=1);
	if CVDCRHD4 = 1 then coronary_artery_disease_flag = 1;
	else coronary_artery_disease_flag = 0;
	* Stroke (CVDSTRK3=1);
	if CVDSTRK3 = 1 then stroke_flag = 1;
	else stroke_flag = 0;
	* Asthma (ASTHNOW=1);
	if ASTHNOW = 1 then asthma_flag = 1;
	else asthma_flag = 0;
	* Non-skin cancer (CHCOCNCR=1);
	if CHCOCNCR = 1 then non_skin_cancer_flag = 1;
	else non_skin_cancer_flag = 0;
	* COPD (CHCCOPD3=1);
	if CHCCOPD3 = 1 then copd_flag = 1;
	else copd_flag = 0;
	* Depression (ADDEPEV3=1);
	if ADDEPEV3 = 1 then depression_flag = 1;
	else depression_flag = 0;
	* Chronic kidney disease (CHCKDNY2=1);
	if CHCKDNY2 = 1 then chronic_kidney_disease_flag = 1;
	else chronic_kidney_disease_flag = 0;

run;


/* Suppress output for surveymeans procedures */
ods exclude all;
proc surveyfreq data=filter_2021_2022_1;
	ods output oneway=caregiveOutput_total; 
    weight _LLCPWT;
    cluster _PSU;
    strata _STSTR;
    tables caregive /cl;
run;
/* Re-enable output */
ods exclude none;

/* Create a formatted table for caregivers and non-caregivers */
data formatted_output_total;
    set caregiveOutput_total;
    length Group $20 Status $30 Weighted $50;

    /* Define Group and Status based on the Caregiver variable */
    if caregive = 1 then do;
        Group = "Family Caregivers";
        Status = "Unweighted N=" || trim(left(put(Frequency, comma10.)));
        Weighted = "Weighted " || trim(left(put(Percent, 5.1))) || "% (" ||
                   trim(left(put(LowerCL, 5.1))) || "%, " ||
                   trim(left(put(UpperCL, 5.1))) || "%)";
    end;
    else if caregive = 0 then do;
        Group = "Non-Caregivers";
        Status = "Unweighted N=" || trim(left(put(Frequency, comma10.)));
        Weighted = "Weighted " || trim(left(put(Percent, 5.1))) || "% (" ||
                   trim(left(put(LowerCL, 5.1))) || "%, " ||
                   trim(left(put(UpperCL, 5.1))) || "%)";
    end;
run;

data formatted_output_head;
    retain Group Status Weighted;
    set formatted_output_total;

    /* Define Group, Status, and Weighted labels if needed */
    label Group = "Category"
          Status = "Unweighted N"
          Weighted = "Weighted Percentage (Confidence Interval)";
	keep Group Status Weighted;

run;

/* Display the final formatted table */
ods exclude all;
proc print data=formatted_output_total noobs label;
    var Group Status Weighted;
    label Group="Category"
          Status="Unweighted N"
          Weighted="Weighted Percentage (Confidence Interval)";
run;
ods exclude none;



******************************************;
*      calculate crosstable value        *;
******************************************;

%macro crosstabsfreq(var);

    /* Generate a shortened variable name to use in dataset names */
	%let var_short = %substr(&var, 1, %sysfunc(min(%length(&var), 25)));

    /* Run survey frequency procedure to create crosstab data */
    ods exclude all;
    proc surveyfreq data=filter_2021_2022_1;
        ods output CrossTabs=ctOut_&var_short ChiSq=chi_&var_short; 
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
	data final_&var_short;
	    length Demographic_Group $50; /* Ensure consistent length */
	    merge cg_0_&var_short (in=a) cg_1_&var_short (in=b) cg_t_&var_short (in=c);
	    by Demographic_Group;

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

%mend crosstabsfreq;


/* Run the macro for each variable */
%crosstabsfreq(age);
%crosstabsfreq(gender);
%crosstabsfreq(race);
%crosstabsfreq(hh_income);

%crosstabsfreq(obesity_flag);
%crosstabsfreq(diabetes_flag);
%crosstabsfreq(hypertension_flag);
%crosstabsfreq(hyperlipidemia_flag);
%crosstabsfreq(myocardial_infarction_flag);
%crosstabsfreq(coronary_artery_disease_flag);
%crosstabsfreq(stroke_flag);
%crosstabsfreq(asthma_flag);
%crosstabsfreq(non_skin_cancer_flag);
%crosstabsfreq(copd_flag);
%crosstabsfreq(depression_flag);
%crosstabsfreq(chronic_kidney_disease_flag);


data final_crosstable;
	length Demographic_Group $50;
	retain Table Demographic_Group unweighted_n weighted_family weighted_non marginal_diff_ci;
	set 
		final_age
		final_gender
		final_race
		final_hh_income

		final_obesity_flag (where=(index(Demographic_Group, '1') > 0))
		final_diabetes_flag (where=(index(Demographic_Group, '1') > 0))
		final_hypertension_flag (where=(index(Demographic_Group, '1') > 0))
		final_hyperlipidemia_flag (where=(index(Demographic_Group, '1') > 0))
		final_myocardial_infarction_fla (where=(index(Demographic_Group, '1') > 0))
		final_coronary_artery_disease_f (where=(index(Demographic_Group, '1') > 0))
		final_stroke_flag (where=(index(Demographic_Group, '1') > 0))
		final_asthma_flag (where=(index(Demographic_Group, '1') > 0))
		final_non_skin_cancer_flag (where=(index(Demographic_Group, '1') > 0))
		final_copd_flag (where=(index(Demographic_Group, '1') > 0))
		final_depression_flag (where=(index(Demographic_Group, '1') > 0))
		final_chronic_kidney_disease_fl (where=(index(Demographic_Group, '1') > 0));
	keep Table Demographic_Group unweighted_n weighted_family weighted_non marginal_diff_ci;

run;




ods excel file="&pg2output\formatted_output_head.xlsx" options(sheet_name="Results");
proc print data=formatted_output_head noobs label;
    var Group Status Weighted;
    label Group="Category"
          Status="Unweighted N"
          Weighted="Weighted Percentage (Confidence Interval)";
run;
ods excel close;


proc export data=final_crosstable
    outfile="&pg2output\final_crosstable.xlsx"
    dbms=xlsx
    replace;
run;


data final_chisq;
    length Demographic_Group $50;
    retain Table Name1 cValue1;
    set 
        chi_age(where=(Name1 = "P_RSCHI"))
        chi_gender(where=(Name1 = "P_RSCHI"))
        chi_race(where=(Name1 = "P_RSCHI"))
        chi_hh_income(where=(Name1 = "P_RSCHI"))
        
        chi_obesity_flag(where=(Name1 = "P_RSCHI"))
        chi_diabetes_flag(where=(Name1 = "P_RSCHI"))
        chi_hypertension_flag(where=(Name1 = "P_RSCHI"))
        chi_hyperlipidemia_flag(where=(Name1 = "P_RSCHI"))
        chi_myocardial_infarction_fla(where=(Name1 = "P_RSCHI"))
        chi_coronary_artery_disease_f(where=(Name1 = "P_RSCHI"))
        chi_stroke_flag(where=(Name1 = "P_RSCHI"))
        chi_asthma_flag(where=(Name1 = "P_RSCHI"))
        chi_non_skin_cancer_flag(where=(Name1 = "P_RSCHI"))
        chi_copd_flag(where=(Name1 = "P_RSCHI"))
        chi_depression_flag(where=(Name1 = "P_RSCHI"))
        chi_chronic_kidney_disease_fl(where=(Name1 = "P_RSCHI"));
    keep Table Name1 cValue1;
run;


proc export data=final_chisq
    outfile="&pg2output\final_chisq.xlsx"
    dbms=xlsx
    replace;
run;

/* Add a row number to final_crosstable to preserve its order */
data order_list;
    set final_crosstable;
    Order_ID = _N_; /* Assign a unique row number */
run;

/* Merge the two datasets based on the Table variable */
proc sql;
    create table table1 as
    select a.*, b.cValue1 as p_value
    from final_crosstable as a
    left join final_chisq as b
    on a.Table = b.Table;
quit;

/* Merge with order_list to apply correct ordering */
proc sql;
    create table table1_ordered as
    select t1.*, o.Order_ID
    from table1 as t1
    left join order_list as o
    on t1.Table = o.Table and t1.Demographic_Group = o.Demographic_Group
    order by o.Order_ID;
quit;

/* Remove Order_ID column to clean the table */
data table1_final;
    set table1_ordered;
    drop Order_ID;
run;

/* View the final ordered table */
proc print data=table1_final (obs=10); /* View first 10 rows */
run;

proc export data=table1_final
    outfile="&pg2output\table1_final.xlsx"
    dbms=xlsx
    replace;
run;
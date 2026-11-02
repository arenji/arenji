/*==============================================================================
8_assemble_table1.do -- Table 1 (summary statistics) wrapper combining the
panels written by steps 4-7:
  Panel A  bank-household-year      (5_tables_relationship_level.do)
  Panel B  bank-municipality-year   (4_tables_pricing.do)
  Panels C1-C3  loan-growth samples (6_tables_loangrowth.do)
  Panel D  bank level               (7_figures.do)
Output: $tables/t1_sumstats.tex  (= \input{tables/t1_sumstats.tex} in manuscript.tex)
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

foreach p in t1_panelA t1_panelB t1_panelC1 t1_panelC2 t1_panelC3 t1_panelD {
    capture confirm file "$tables/`p'.tex"
    if _rc di as error "Missing panel file $tables/`p'.tex"
}

file open f1 using "$tables/t1_sumstats.tex", write replace
file write f1 "\begin{table}[p]\centering" _n
file write f1 "\caption{Summary Statistics}\label{tab:sumstats}" _n
file write f1 "\tablelegend{Panel A: bank-household-year observations with an existing deposit relationship. Panel B: bank-municipality-year cells of the baseline estimation sample (Table 3, column 2). Panels C1-C3: the NFC loan growth samples at the bank-municipality, bank-NACE3 and bank-NACE5 level. Panel D: bank-level aggregates; the deposit spread beta is estimated per bank from annual deposit-spread changes on policy-rate changes (at least three usable years; winsorized at 5/95 across banks). Rates in percent, spreads in percentage points, volumes in NOK.}" _n
file write f1 "\footnotesize" _n
file write f1 "\begin{tabular}{l*{8}{r}}" _n
file write f1 "\toprule" _n
foreach p in t1_panelA t1_panelB t1_panelC1 t1_panelC2 t1_panelC3 t1_panelD {
    file write f1 "\input{tables/`p'.tex}" _n
}
file write f1 "\bottomrule" _n
file write f1 "\end{tabular}" _n
file write f1 "\end{table}" _n
file close f1

di as result "Step 8 done: $tables/t1_sumstats.tex assembled"

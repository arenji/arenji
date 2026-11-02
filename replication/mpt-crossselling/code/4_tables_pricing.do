/*==============================================================================
4_tables_pricing.do -- deposit-pricing and deposit-growth tables on the
bank x municipality x year panel

Input : $work/bmy_analysis.dta
Output ($tables):
  t1_panelB.tex   Table 1, Panel B   summary statistics, bank-municipality-year
  t3_core.tex     Table 3            core pricing results
  t4_intensive.tex Table 4           intensive-margin measures
  t5_depgrowth.tex Table 6           deposit growth
  t9_lowrates.tex Table 10           low-rate years and bank strength
  a2_leads.tex    Table A2           leads and lags of the policy-rate change
  a4_ao.tex       Table A1           Altonji-Oster and residualized PrB
  a4_ao_variance_decomposition.txt   numbers quoted in the Table A1 discussion
  a5_other.tex    Table 5            own-bank vs. other-banks PrB
  a7_loanhhi.tex  Table A3           loan-market HHI
  a11_levels.tex  Table A6           levels instead of changes
  a12_weighted.tex Table A7          deposit-volume weighted
  a13_mps.tex     Table A8           monetary policy surprises
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

use "$work/bmy_analysis.dta", clear
label_bmy_vars

local note_fe "Bank-year fixed effects as indicated. Standard errors clustered by bank-year in parentheses. *, **, *** denote significance at the 10, 5 and 1 percent level. Effects of one standard deviation are the coefficient on the interaction with \$\Delta\$PR multiplied by the standard deviation of the respective variable in the estimation sample."

*------------------------------------------------------------------------------
* Table 1, Panel B: bank-municipality-year summary statistics (baseline sample)
*------------------------------------------------------------------------------
write_sumstats_panel prate dpr depspread_w0100_tr595 d_depspread_w0100_tr595 ///
    depositvol pr_borrower_conv_ds hhi_deposit mshare_dep numberclients if sample_conv, ///
    name(t1_panelB) panel(B) title(Bank-municipality-year level)

*------------------------------------------------------------------------------
* Table 3: core pricing results
*------------------------------------------------------------------------------
eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, ///
    noa cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "No"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_deposit##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    qui sum hhi_deposit if e(sample)
    estadd scalar sdeff_hhi = r(sd) * _b[c.hhi_deposit#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.mshare_dep##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    qui sum mshare_dep if e(sample)
    estadd scalar sdeff_ms = r(sd) * _b[c.mshare_dep#c.dpr]
    estadd local BYFE "Yes"

write_table, name(t3_core) texlabel(tab:core) ///
    title(Cross-Selling Potential and the Pass-Through of Policy Rate Changes to Deposit Spreads) ///
    note(Dependent variable: year-on-year change in the deposit spread (policy rate minus effective deposit rate), bank-municipality-year level. PrB is the estimated probability that a depositor later borrows from the same bank. `note_fe') ///
    stats(N r2 sdeff_prb sdeff_hhi sdeff_ms BYFE, fmt(%12.0fc %9.3f %9.4f %9.4f %9.4f) ///
          labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Effect of 1 SD of HHI" "Effect of 1 SD of MS" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table 4: intensive-margin measures (expected loan volume; expected loan income)
*------------------------------------------------------------------------------
capture gen c3_conv  = pr_borrower_conv_ds * pr_lnmeandebt_conv
capture gen c3a_conv = c3_conv * pr_loanspread_conv
label_bmy_vars

eststo clear
foreach con of varlist c3_conv c3a_conv {
    eststo: reghdfe d_depspread_w0100_tr595 c.`con'##c.dpr, noa cluster(bankid##year)
        qui sum `con' if e(sample)
        estadd scalar sdeff = r(sd) * _b[c.`con'#c.dpr]
        estadd local BYFE "No"
    eststo: reghdfe d_depspread_w0100_tr595 c.`con'##c.dpr, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum `con' if e(sample)
        estadd scalar sdeff = r(sd) * _b[c.`con'#c.dpr]
        estadd local BYFE "Yes"
    eststo: reghdfe d_depspread_w0100_tr595 c.`con'##c.dpr c.hhi_deposit##c.dpr, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum `con' if e(sample)
        estadd scalar sdeff = r(sd) * _b[c.`con'#c.dpr]
        qui sum hhi_deposit if e(sample)
        estadd scalar sdeff_hhi = r(sd) * _b[c.hhi_deposit#c.dpr]
        estadd local BYFE "Yes"
    eststo: reghdfe d_depspread_w0100_tr595 c.`con'##c.dpr c.mshare_dep##c.dpr, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum `con' if e(sample)
        estadd scalar sdeff = r(sd) * _b[c.`con'#c.dpr]
        qui sum mshare_dep if e(sample)
        estadd scalar sdeff_ms = r(sd) * _b[c.mshare_dep#c.dpr]
        estadd local BYFE "Yes"
}
write_table, name(t4_intensive) texlabel(tab:intensive) ///
    title(Intensive-Margin Measures of Cross-Selling Potential) ///
    note(Columns 1-4 replace PrB by PrB times expected log loan volume; columns 5-8 additionally multiply by the expected loan spread (expected loan income). Both expectations are predicted from household observables on the deposit-conditional sample. `note_fe') ///
    stats(N r2 sdeff sdeff_hhi sdeff_ms BYFE, fmt(%12.0fc %9.3f %9.4f %9.4f %9.4f) ///
          labels("Observations" "R\$^2\$" "Effect of 1 SD of CS measure" "Effect of 1 SD of HHI" "Effect of 1 SD of MS" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table 6: deposit growth (log difference; winsorized at 10/90)
*------------------------------------------------------------------------------
qui reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, noa cluster(bankid##year)
gen sample1_dg = e(sample)
qui reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, absorb(i.bankid##i.year) cluster(bankid##year)
gen sample2_dg = e(sample)
qui reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_deposit##c.dpr, absorb(i.bankid##i.year) cluster(bankid##year)
gen sample3_dg = e(sample)
qui reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.mshare_dep##c.dpr, absorb(i.bankid##i.year) cluster(bankid##year)
gen sample4_dg = e(sample)

eststo clear
foreach dg of varlist depgrowth_ld depgrowth_ld_w1090 {
    eststo: reghdfe `dg' c.pr_borrower_conv_ds##c.dpr if sample1_dg, noa cluster(bankid##year)
        qui sum pr_borrower_conv_ds if e(sample)
        estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
        estadd local BYFE "No"
    eststo: reghdfe `dg' c.pr_borrower_conv_ds##c.dpr if sample2_dg, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum pr_borrower_conv_ds if e(sample)
        estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
        estadd local BYFE "Yes"
    eststo: reghdfe `dg' c.pr_borrower_conv_ds##c.dpr c.hhi_deposit##c.dpr if sample3_dg, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum pr_borrower_conv_ds if e(sample)
        estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
        qui sum hhi_deposit if e(sample)
        estadd scalar sdeff_hhi = r(sd) * _b[c.hhi_deposit#c.dpr]
        estadd local BYFE "Yes"
    eststo: reghdfe `dg' c.pr_borrower_conv_ds##c.dpr c.mshare_dep##c.dpr if sample4_dg, ///
        absorb(i.bankid##i.year) cluster(bankid##year)
        qui sum pr_borrower_conv_ds if e(sample)
        estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
        qui sum mshare_dep if e(sample)
        estadd scalar sdeff_ms = r(sd) * _b[c.mshare_dep#c.dpr]
        estadd local BYFE "Yes"
}
write_table, name(t5_depgrowth) texlabel(tab:depgrowth) ///
    title(Cross-Selling Potential and the Deposit Growth Response to Policy Rate Changes) ///
    note(Dependent variable: deposit growth (log difference, in percent) at the bank-municipality-year level; columns 5-8 winsorize growth at the 10th and 90th percentiles. Samples are those of the corresponding columns of Table 3. `note_fe') ///
    stats(N r2 sdeff_prb sdeff_hhi sdeff_ms BYFE, fmt(%12.0fc %9.3f %9.3f %9.3f %9.3f) ///
          labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Effect of 1 SD of HHI" "Effect of 1 SD of MS" "Bank-year FE"))
drop sample?_dg

*------------------------------------------------------------------------------
* Table 10: low-rate years (2015-2018) and bank financial strength
*   col 1: full sample, triple interaction PrB x dPR x LowRate
*   cols 2-5: subsamples below/above the yearly median of profits/TA and log TA,
*             with a cross-sample difference test from the stacked regression
*------------------------------------------------------------------------------
eststo clear
eststo pooled: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr##i.lowrates, ///
    absorb(i.bankid##i.year) cluster(bankid year)

local splitvars overp50_profits_ta overp50_ln_ta
local k = 0
foreach var of local splitvars {
    local ++k
    eststo s`k'l: reghdfe d_depspread_w0100_tr595 ///
        c.pr_borrower_conv_ds##c.dpr##i.lowrates if `var' == 0, ///
        absorb(i.bankid##i.year) cluster(bankid year)
    eststo s`k'h: reghdfe d_depspread_w0100_tr595 ///
        c.pr_borrower_conv_ds##c.dpr##i.lowrates if `var' == 1, ///
        absorb(i.bankid##i.year) cluster(bankid year)
    * cross-sample test: four-way interaction in a stacked regression
    qui reghdfe d_depspread_w0100_tr595 ///
        c.pr_borrower_conv_ds##c.dpr##i.lowrates##i.`var', ///
        absorb(i.bankid##i.year) cluster(bankid year)
    qui lincom c.pr_borrower_conv_ds#c.dpr#1.lowrates#1.`var'
    local t_`k' = r(estimate) / r(se)
    local p_`k' = 2 * ttail(r(df), abs(`t_`k''))
    foreach m in s`k'l s`k'h {
        estadd local tstat = string(`t_`k'', "%6.3f"): `m'
        estadd local pval  = string(`p_`k'', "%6.3f"): `m'
    }
}
write_table pooled s1l s1h s2l s2h, name(t9_lowrates) texlabel(tab:lowrates) ///
    title(Cross-Selling and Pass-Through in Low-Rate Years, by Bank Financial Strength) ///
    note(LowRate equals one in 2015-2018, when the policy rate was below 1.5 pp. Column 1 uses the full sample; columns 2-5 split banks at the yearly median of pre-tax profits over total assets and of log total assets. All columns include bank-year fixed effects; standard errors are two-way clustered by bank and year. The t-statistic and p-value test whether the triple interaction differs between the two subsamples, from a stacked regression with all terms interacted with the split indicator.) ///
    mtitles("Full sample" "Low profits/TA" "High profits/TA" "Small" "Large") ///
    stats(N r2 tstat pval, fmt(%12.0fc %9.3f %s %s) labels("Observations" "R\$^2\$" "t-stat, difference" "p-value, difference"))

*------------------------------------------------------------------------------
* Table A2: leads and lags of the policy-rate change
*------------------------------------------------------------------------------
sort bankmuniid year
xtset bankmuniid year
gen dpr_lead = F.dpr
gen dpr_lag  = L.dpr
label_bmy_vars

eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr ///
    c.pr_borrower_conv_ds##c.dpr_lead c.pr_borrower_conv_ds##c.dpr_lag, noa cluster(bankid##year)
    estadd local BYFE "No"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr ///
    c.pr_borrower_conv_ds##c.dpr_lead c.pr_borrower_conv_ds##c.dpr_lag, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr ///
    c.pr_borrower_conv_ds##c.dpr_lead c.pr_borrower_conv_ds##c.dpr_lag c.hhi_deposit##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr ///
    c.pr_borrower_conv_ds##c.dpr_lead c.pr_borrower_conv_ds##c.dpr_lag c.mshare_dep##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
write_table, name(a2_leads) texlabel(tab:a_leads) ///
    title(Timing: Leads and Lags of the Policy-Rate Change) ///
    note(Baseline specification augmented with the lead and the lag of the policy-rate change, each interacted with PrB. `note_fe') ///
    stats(N r2 BYFE, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table A1: Altonji-Oster (short vs. long) and residualized PrB
*------------------------------------------------------------------------------
* Residualize PrB within bank-year against expanding control sets
qui reghdfe pr_borrower_conv_ds, absorb(i.bankid##i.year) residuals(prb_resid_fe)
qui reghdfe pr_borrower_conv_ds AgedSub30 age30to40 age40to50 age50to60 ageover60, ///
    absorb(i.bankid##i.year) residuals(prb_resid_age)
qui reghdfe pr_borrower_conv_ds AgedSub30 age30to40 age40to50 age50to60 ageover60 ///
    ln_inc ln_wealth, absorb(i.bankid##i.year) residuals(prb_resid_inc)
qui reghdfe pr_borrower_conv_ds AgedSub30 age30to40 age40to50 age50to60 ageover60 ///
    ln_inc ln_wealth educ move extensive_stock stock_bond_share, ///
    absorb(i.bankid##i.year) residuals(prb_resid_full)
label_bmy_vars

* Variance decomposition of PrB (numbers quoted in Section 5.3), common sample
qui sum pr_borrower_conv_ds if prb_resid_full != .
local V = r(Var)
foreach v in fe age inc full {
    qui sum prb_resid_`v' if prb_resid_full != .
    local v_`v' = r(Var)
}
local sh_fe   = 1 - `v_fe'/`V'
local sh_ctrl = (`v_fe' - `v_full')/`V'
local sh_tot  = 1 - `v_full'/`V'
local pr2_dem  = 1 - `v_inc'/`v_fe'
local pr2_soph = 1 - `v_full'/`v_inc'
file open fv using "$tables/a4_ao_variance_decomposition.txt", write replace
file write fv "Variance decomposition of PrB (common estimation sample)" _n
file write fv "Share absorbed by bank-year FE:                " %6.3f (`sh_fe') _n
file write fv "Share absorbed by controls given FE:           " %6.3f (`sh_ctrl') _n
file write fv "Total share absorbed (FE + controls):          " %6.3f (`sh_tot') _n
file write fv "Within-bank-year partial R2, demographics:     " %6.3f (`pr2_dem') _n
file write fv "Within-bank-year partial R2, sophistication:   " %6.3f (`pr2_soph') _n
file close fv

eststo clear
eststo short_ao: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local controls "None"
eststo long_ao: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr ///
    c.educ##c.dpr c.move##c.dpr c.extensive_stock##c.dpr c.stock_bond_share##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local controls "Sophistication"
eststo r_inc: reghdfe d_depspread_w0100_tr595 c.prb_resid_inc##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local controls "Resid.: age, inc., wealth"
eststo r_full: reghdfe d_depspread_w0100_tr595 c.prb_resid_full##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local controls "Resid.: full"
estimates restore short_ao
local b_short = _b[c.pr_borrower_conv_ds#c.dpr]
estimates restore long_ao
local b_long = _b[c.pr_borrower_conv_ds#c.dpr]
file open fv using "$tables/a4_ao_variance_decomposition.txt", write append
file write fv _n "Altonji-Oster: PrB x dPR short = " %7.4f (`b_short') ", long = " %7.4f (`b_long') _n
file close fv

write_table short_ao long_ao r_inc r_full, name(a4_ao) texlabel(tab:a_ao) ///
    title(Selection on Observables and Unobservables: Altonji-Oster Comparison and Residualized PrB) ///
    note(Column 1 is the baseline (bank-year fixed effects only); column 2 adds interactions of the policy-rate change with four depositor-sophistication proxies (education, residential mobility, stock-market participation, stock and bond share). Columns 3-4 use as regressor the residual of PrB from a within-bank-year regression on age shares, log income and log wealth (column 3) and additionally on the four sophistication proxies (column 4). `note_fe') ///
    mtitles("Short" "Long" "Resid. (age, inc., wealth)" "Resid. (full)") ///
    stats(N r2 controls, fmt(%12.0fc %9.4f) labels("Observations" "R\$^2\$" "Controls"))

*------------------------------------------------------------------------------
* Table 5: own-bank vs. other-banks PrB
*------------------------------------------------------------------------------
bysort muniid year: egen total_prb_my = total(pr_borrower_conv_ds)
bysort muniid year: egen count_my = count(pr_borrower_conv_ds)
gen prb_others = (total_prb_my - pr_borrower_conv_ds) / (count_my - 1)
bysort muniid year: egen total_prbw_my = total(pr_borrower_conv_ds * depositvol)
bysort muniid year: egen total_dep_my = total(depositvol)
gen prb_others_w = (total_prbw_my - pr_borrower_conv_ds * depositvol) / (total_dep_my - depositvol)
label_bmy_vars

eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
eststo: reghdfe d_depspread_w0100_tr595 c.prb_others##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.prb_others##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.prb_others_w##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.prb_others##c.dpr c.hhi_deposit##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
write_table, name(a5_other) texlabel(tab:a_other) ///
    title(Bank-Specific Cross-Selling Potential versus Local Market Conditions) ///
    note(Other-banks PrB is the leave-one-out average PrB of all other banks in the same municipality-year (unweighted; deposit-weighted in column 4). All columns include bank-year fixed effects; standard errors clustered by bank-year.) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$"))

*------------------------------------------------------------------------------
* Table A3: loan-market HHI
*------------------------------------------------------------------------------
eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_loan##c.dpr, ///
    noa cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "No"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_loan##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_loan##c.dpr c.hhi_deposit##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_loan##c.dpr c.mshare_dep##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "Yes"
write_table, name(a7_loanhhi) texlabel(tab:a_loanhhi) ///
    title(Loan-Market Concentration and Pass-Through) ///
    note(Baseline specification with the municipality loan-market HHI interacted with the policy-rate change. `note_fe') ///
    stats(N r2 sdeff_prb BYFE, fmt(%12.0fc %9.3f %9.4f) labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table A6: levels on levels
*------------------------------------------------------------------------------
eststo clear
eststo: reghdfe depspread_w0100_tr595 c.pr_borrower_conv_ds##c.prate, noa cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prate = r(sd) * _b[c.pr_borrower_conv_ds#c.prate]
    estadd local BYFE "No"
eststo: reghdfe depspread_w0100_tr595 c.pr_borrower_conv_ds##c.prate, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prate = r(sd) * _b[c.pr_borrower_conv_ds#c.prate]
    estadd local BYFE "Yes"
eststo: reghdfe depspread_w0100_tr595 c.pr_borrower_conv_ds##c.prate c.hhi_deposit##c.prate, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prate = r(sd) * _b[c.pr_borrower_conv_ds#c.prate]
    qui sum hhi_deposit if e(sample)
    estadd scalar sdeff_hhi = r(sd) * _b[c.hhi_deposit#c.prate]
    estadd local BYFE "Yes"
eststo: reghdfe depspread_w0100_tr595 c.pr_borrower_conv_ds##c.prate c.mshare_dep##c.prate, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prate = r(sd) * _b[c.pr_borrower_conv_ds#c.prate]
    qui sum mshare_dep if e(sample)
    estadd scalar sdeff_ms = r(sd) * _b[c.mshare_dep#c.prate]
    estadd local BYFE "Yes"
write_table, name(a11_levels) texlabel(tab:a_levels) ///
    title(Levels of Deposit Spreads and Policy Rates) ///
    note(Dependent variable: level of the deposit spread; the policy rate enters in levels. `note_fe') ///
    stats(N r2 sdeff_prate sdeff_hhi sdeff_ms BYFE, fmt(%12.0fc %9.3f %9.4f %9.4f %9.4f) ///
          labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Effect of 1 SD of HHI" "Effect of 1 SD of MS" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table A7: deposit-volume weighted
*------------------------------------------------------------------------------
eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr [aw=depositvol], noa cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "No"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr [aw=depositvol], ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.hhi_deposit##c.dpr [aw=depositvol], ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    qui sum hhi_deposit if e(sample)
    estadd scalar sdeff_hhi = r(sd) * _b[c.hhi_deposit#c.dpr]
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr c.mshare_dep##c.dpr [aw=depositvol], ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    qui sum pr_borrower_conv_ds if e(sample)
    estadd scalar sdeff_prb = r(sd) * _b[c.pr_borrower_conv_ds#c.dpr]
    qui sum mshare_dep if e(sample)
    estadd scalar sdeff_ms = r(sd) * _b[c.mshare_dep#c.dpr]
    estadd local BYFE "Yes"
write_table, name(a12_weighted) texlabel(tab:a_weighted) ///
    title(Deposit-Volume Weighted Estimates) ///
    note(Baseline specification with observations weighted by the deposit volume of the bank-municipality cell. `note_fe') ///
    stats(N r2 sdeff_prb sdeff_hhi sdeff_ms BYFE, fmt(%12.0fc %9.3f %9.4f %9.4f %9.4f) ///
          labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Effect of 1 SD of HHI" "Effect of 1 SD of MS" "Bank-year FE"))

*------------------------------------------------------------------------------
* Table A8: monetary policy surprises instead of observed rate changes
*------------------------------------------------------------------------------
eststo clear
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.mpshock, noa cluster(bankid##year)
    estadd local BYFE "No"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.mpshock, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.mpshock c.hhi_deposit##c.mpshock, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
eststo: reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.mpshock c.mshare_dep##c.mpshock, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
    estadd local BYFE "Yes"
write_table, name(a13_mps) texlabel(tab:a_mps) ///
    title(Monetary Policy Surprises) ///
    note(The year-on-year policy-rate change is replaced by the annual narrative monetary policy surprise of Holm, Paul and Tischbirek (2021). `note_fe') ///
    stats(N r2 BYFE, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$" "Bank-year FE"))

di as result "Step 4 done: pricing tables written to $tables"

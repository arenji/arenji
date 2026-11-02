/*==============================================================================
2_construct_prb_and_bmy.do -- cross-selling potential and the analysis panels

Input : $f_relid  (relationship x year panel), $f_bankstr (bank x year)
Output: $work/relid_withconv.dta                 relationship panel + predicted measures
        $work/BMY_unweighted_withconv.dta        bank x municipality x year panel (baseline unit)
        $work/treatments_banklevel_weighted_conv.dta  bank-level PrB and HHI (loan-growth tables)
        $work/overp50s.dta                       bank x year above-median dummies (Table 10)
        $tables/t2_lpm.tex is NOT written here (Table 2 is produced in
        5_tables_relationship_level.do on the same specification).

Baseline measure of cross-selling potential, PrB = pr_borrower_conv_ds:
  linear probability model of `converted' (depositor later borrows from the
  same bank) on household observables, estimated on relationship-years with
  an existing deposit (existing_dep == 1), as described in Section 3.2.
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

use "$f_relid", clear
xtset relid year

* Indicators that the construction step provides; re-create if absent
capture confirm variable existing_dep
if _rc gen existing_dep = (L.deposits > 0 & L.deposits != .)
capture confirm variable converted
if _rc gen converted = futureborrower & existing_dep

local rhs parent retired ln_inc ln_wealth ln_deposits AgedSub30 number_banks_hhid hhi_deposit

*---- Extensive margin ----------------------------------------------------------
* pr_borrower1: LPM of futureborrower, full sample (auxiliary measure; carried
* in the bank-level file but not used in any reported exhibit)
capture drop pr_borrower1
qui reghdfe futureborrower `rhs', noa cluster(relid)
predict pr_borrower1, xb

* pr_borrower_conv_ds: BASELINE PrB
capture drop pr_borrower_conv_ds
qui reghdfe converted `rhs' if existing_dep == 1, noa cluster(relid)
predict pr_borrower_conv_ds, xb
label var pr_borrower_conv_ds "PrB (prob. that a depositor later borrows from the same bank)"

*---- Intensive margin (deposit-conditional sample) -----------------------------
capture drop pr_meandebt_conv pr_lnmeandebt_conv pr_loanspread_conv pr_loanspreadon_conv
qui reghdfe meandebt `rhs' if existing_dep == 1, noa cluster(relid)
predict pr_meandebt_conv, xb
qui reghdfe lnmeandebt `rhs' if existing_dep == 1, noa cluster(relid)
predict pr_lnmeandebt_conv, xb
qui reghdfe loanspread `rhs' if existing_dep == 1, noa cluster(relid)
predict pr_loanspread_conv, xb
qui reghdfe loanspread_on `rhs' if existing_dep == 1, noa cluster(relid)
predict pr_loanspreadon_conv, xb
label var pr_lnmeandebt_conv "E[Ln(mean loan volume)]"
label var pr_loanspread_conv "E[Loan spread]"

sort relid year
compress
save "$work/relid_withconv.dta", replace

*---- Bank x municipality x year panel (unweighted means, summed volumes) -------
use prate deprate depspread* hhi_deposit hhi_loan age AgedSub30 parent ///
    futureborrower converted existing_dep pr_borrower1 pr_borrower_conv_ds ///
    pr_meandebt_conv pr_lnmeandebt_conv pr_loanspread_conv pr_loanspreadon_conv ///
    loanvol depositvol bankid muniid year maxdebt maxloanvol ///
    using "$work/relid_withconv.dta", clear

gen age30to40 = age >= 30 & age < 40
gen age40to50 = age >= 40 & age < 50
gen age50to60 = age >= 50 & age < 60
gen ageover60 = age >= 60
bysort bankid muniid year: gen numberclients = _N

collapse (mean) prate deprate depspread* hhi_deposit hhi_loan ///
    AgedSub30 age30to40 age40to50 age50to60 ageover60 parent ///
    futureborrower converted existing_dep pr_borrower1 pr_borrower_conv_ds numberclients ///
    pr_meandebt_conv pr_lnmeandebt_conv pr_loanspread_conv pr_loanspreadon_conv ///
    maxdebt maxloanvol ///
    (sum) loanvol depositvol, by(bankid muniid year)
label var pr_borrower_conv_ds "PrB"
label var numberclients "Number of clients"
sort bankid muniid year
save "$work/BMY_unweighted_withconv.dta", replace

*---- Bank-level treatments for the loan-growth tables (deposit-weighted means) --
use bankid depositvol pr_borrower_conv_ds pr_borrower1 hhi_deposit ///
    using "$work/relid_withconv.dta", clear
collapse (mean) pr_borrower_conv_ds hhi_deposit pr_borrower1 [iw = depositvol], by(bankid)
ren pr_borrower_conv_ds prb_conv_banklevel
ren hhi_deposit hhi_banklevel
ren pr_borrower1 prb_banklevel
label var prb_conv_banklevel "PrB (bank level)"
label var hhi_banklevel "HHI (bank level)"
sort bankid
save "$work/treatments_banklevel_weighted_conv.dta", replace

*---- Above-median bank-strength dummies, by year (Table 10 sample splits) -------
use "$f_bankstr", clear
keep bankid year profits_ta ln_ta
foreach var in profits_ta ln_ta {
    gen overp50_`var' = .
    forvalues y = $y_first/$y_last {
        qui sum `var' if year == `y', detail
        replace overp50_`var' = (`var' >= r(p50)) if year == `y' & `var' != .
    }
}
keep bankid year overp50_*
sort bankid year
save "$work/overp50s.dta", replace

di as result "Step 2 done: relid_withconv, BMY_unweighted_withconv, treatments_banklevel_weighted_conv, overp50s"

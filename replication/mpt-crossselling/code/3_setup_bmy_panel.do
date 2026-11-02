/*==============================================================================
3_setup_bmy_panel.do -- common setup of the bank x municipality x year
analysis panel

Input : $work/BMY_unweighted_withconv.dta, $f_mshares, $f_munichar,
        $f_mpshock, $work/overp50s.dta
Output: $work/bmy_analysis.dta  (one row per bank-municipality-year)
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

use "$work/BMY_unweighted_withconv.dta", clear

egen bankmuniid = group(bankid muniid)
sort bankmuniid year
xtset bankmuniid year

* Year-on-year changes (Eq. 4): policy rate and deposit spread
gen dpr = D.prate
gen d_depspread_w0100_tr595 = D.depspread_w0100_tr595

* Deposit growth (Table 6)
gen ln_depositvol = ln(depositvol)
gen depgrowth_ld = 100 * D.ln_depositvol
winsor2 depgrowth_ld, cuts(10 90) suffix(_w1090)

* Bank's own deposit market share in the municipality
sort bankid muniid year
merge 1:1 bankid muniid year using "$f_mshares", nogen keep(1 3) keepusing(mshare_dep)

* Income, wealth and the four sophistication proxies (Sections 4.1, 5.3)
preserve
    use "$f_munichar", clear
    keep muniid bankid year total_income gross_wealth gross_fin_assets total_deposits educ move
    tempfile incwlth
    save `incwlth'
restore
foreach v in educ move {
    capture drop `v'
}
merge 1:1 muniid bankid year using `incwlth', nogen keep(1 3)
gen ln_inc    = ln(total_income)
gen ln_wealth = ln(gross_wealth)
gen stock_bonds      = gross_fin_assets - total_deposits
gen stock_bond_share = stock_bonds / gross_wealth
gen extensive_stock  = (stock_bonds / gross_wealth) > 0

* Monetary policy surprises (Table A8)
merge m:1 year using "$f_mpshock", nogen keep(1 3)

* Above-median bank strength (Table 10)
merge m:1 bankid year using "$work/overp50s.dta", nogen keep(1 3)

* Low-rate period: policy rate below 1.5 pp (2015-2018)
gen lowrates = (year >= $y_lowrate)

* Baseline estimation sample (Table 3, column 2)
qui reghdfe d_depspread_w0100_tr595 c.pr_borrower_conv_ds##c.dpr, ///
    absorb(i.bankid##i.year) cluster(bankid##year)
gen sample_conv = e(sample)
label var sample_conv "In baseline estimation sample (Table 3, col. 2)"

label_bmy_vars
sort bankmuniid year
compress
save "$work/bmy_analysis.dta", replace

qui count if sample_conv
di as result "Step 3 done: bmy_analysis.dta, " r(N) " bank-municipality-years in the baseline sample"

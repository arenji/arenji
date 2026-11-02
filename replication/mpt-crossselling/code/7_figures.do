/*==============================================================================
7_figures.do -- figures on the bank x municipality x year panel and Table 1,
Panel D (bank level)

Input : $work/bmy_analysis.dta, $f_bench
Output ($figures): figure1_spreads_v2.png, figure2_benchmarks_v2.png,
                   figure3_hist_conv.png, figure4_panelA_conv_v2.png,
                   figure4_panelB_conv_v2.png, figureA1_hhi_loan_vs_deposit.png
       ($tables):  t1_panelD.tex, figure1_annual_series.csv, lowrate_descriptives.txt
       ($work):    bank_depbetas_conv.dta, bank_depbetas_pre2015_conv.dta
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

*------------------------------------------------------------------------------
* Figures 1 and 2: annual volume-weighted series of the deposit spread,
* deposit rate and policy rate. The averages run over all
* bank-municipality-year rows of the panel, weighted by deposit volume; the
* series is also written to figure1_annual_series.csv.
*------------------------------------------------------------------------------
preserve
    collapse (mean) spread_pr = depspread_w0100_tr595 (mean) prate = prate ///
        [aw = depositvol], by(year)
    gen deprate = prate - spread_pr
    order year prate deprate spread_pr
    export delimited using "$tables/figure1_annual_series.csv", replace
    merge 1:1 year using "$f_bench", nogen keep(1 3)

    * Figure 1
    label var prate "Policy rate (%)"
    label var deprate "Deposit rate (%)"
    label var spread_pr "Deposit spread (pp)"
    twoway (line prate year, lcolor(navy) lpattern(solid)) ///
           (line deprate year, lcolor(maroon) lpattern(dash)) ///
           (line spread_pr year, lcolor(forest_green) lpattern(solid) lwidth(medthick)), ///
        yline(0, lcolor(gs10)) xlabel($y_first(2)$y_last) ///
        ytitle("Percent / percentage points") xtitle("") ///
        legend(order(1 "Policy rate" 2 "Deposit rate" 3 "Deposit spread") rows(1) position(6))
    graph export "$figures/figure1_spreads_v2.png", replace width(1600)

    * Figure 2: one marker per year against three benchmark rates, OLS fits
    local i = 0
    foreach r in prate nibor3m y10y {
        local ++i
        local ttl : word `i' of "A. Policy rate" "B. 3-month money-market rate" "C. 10-year government bond yield"
        twoway (scatter spread_pr `r', mcolor(navy)) ///
               (lfit spread_pr `r', lcolor(maroon)), ///
            title("`ttl'", size(medium)) xtitle("Benchmark rate (%)") ytitle("Deposit spread (pp)") ///
            legend(off) name(f2_`i', replace)
    }
    graph combine f2_1 f2_2 f2_3, rows(1) ycommon xsize(12) ysize(4)
    graph export "$figures/figure2_benchmarks_v2.png", replace width(2400)
restore

*------------------------------------------------------------------------------
* Low-rate descriptives quoted in Section 5.7: bank-level volume-weighted spreads, the
* share of banks with a negative spread in a low-rate year, and the mean
* low-rate-year spread against alternative benchmark yields.
*------------------------------------------------------------------------------
file open fl using "$tables/lowrate_descriptives.txt", write replace
file write fl "Low-rate descriptives (Section 5.7); low-rate years = $y_lowrate-$y_last" _n
merge m:1 year using "$f_bench", nogen keep(1 3)
gen double deprate_bmy = prate - depspread_w0100_tr595
foreach bmk in policy y12m y3y y5y y10y {
    if "`bmk'" == "policy" gen double _alt = depspread_w0100_tr595
    else gen double _alt = `bmk' - deprate_bmy
    * bank-year volume-weighted spread
    preserve
        collapse (mean) s_by = _alt (max) inT3 = sample_conv [aw = depositvol], by(bankid year)
        gen lr  = (year >= $y_lowrate)
        gen neg = (s_by < 0) if !missing(s_by)
        qui sum s_by if lr
        local m_low = r(mean)
        qui sum neg if lr
        local by_share = r(mean)
        gen neg_low = neg if lr
        collapse (max) evneg_low = neg_low (max) inT3, by(bankid)
        qui sum evneg_low if inT3 == 1
        local bank_share = r(mean)
    restore
    file write fl "  benchmark `bmk': mean bank-level spread in low-rate years = " %7.3f (`m_low') ///
        "; share of baseline-sample banks negative in >=1 low-rate year = " %5.1f (100*`bank_share') ///
        "%; share of low-rate bank-years negative = " %5.1f (100*`by_share') "%" _n
    drop _alt
}
drop nibor3m y12m y3y y5y y10y deprate_bmy
file close fl
di as text "  wrote $tables/lowrate_descriptives.txt"

*------------------------------------------------------------------------------
* Bank-level deposit spread betas: one regression per bank of the annual change
* in the deposit spread on the policy-rate change; >= 3 usable years;
* winsorized at 5/95 across banks. Saved once and used for Figure 3, Figure 4
* and Table 1 Panel D so that figure and table agree by construction.
*------------------------------------------------------------------------------
gen _use = (d_depspread_w0100_tr595 < . & dpr < .)
bysort bankid: egen beta_nobs = total(_use)
gen depbeta_raw = .
levelsof bankid if beta_nobs >= 3, local(banks)
foreach b of local banks {
    qui reg d_depspread_w0100_tr595 dpr if bankid == `b'
    qui replace depbeta_raw = _b[dpr] if bankid == `b'
}
preserve
    keep if depbeta_raw < .
    collapse (first) depbeta_raw beta_nobs, by(bankid)
    winsor2 depbeta_raw, cuts(5 95) suffix(_w)
    ren depbeta_raw_w depbeta
    label var depbeta "Deposit spread beta"
    save "$work/bank_depbetas_conv.dta", replace
restore

* Pre-2015 betas (Figure 4, Panel B)
replace _use = (d_depspread_w0100_tr595 < . & dpr < . & year < $y_lowrate)
bysort bankid: egen beta_nobs_pre = total(_use)
gen depbeta_pre_raw = .
levelsof bankid if beta_nobs_pre >= 3, local(banks)
foreach b of local banks {
    qui reg d_depspread_w0100_tr595 dpr if bankid == `b' & year < $y_lowrate
    qui replace depbeta_pre_raw = _b[dpr] if bankid == `b'
}
preserve
    keep if depbeta_pre_raw < .
    collapse (first) depbeta_pre_raw beta_nobs_pre, by(bankid)
    winsor2 depbeta_pre_raw, cuts(5 95) suffix(_w)
    ren depbeta_pre_raw_w depbeta_pre
    save "$work/bank_depbetas_pre2015_conv.dta", replace
restore
drop _use

merge m:1 bankid using "$work/bank_depbetas_conv.dta", nogen keep(1 3) keepusing(depbeta)
merge m:1 bankid using "$work/bank_depbetas_pre2015_conv.dta", nogen keep(1 3) keepusing(depbeta_pre)

*------------------------------------------------------------------------------
* Figure 3: distribution of pass-through across banks
*------------------------------------------------------------------------------
preserve
    use "$work/bank_depbetas_conv.dta", clear
    qui sum depbeta, detail
    di "Figure 3: N = " r(N) "  mean = " %6.3f r(mean) "  median = " %6.3f r(p50)
    histogram depbeta, width(0.025) fcolor(navy%60) lcolor(navy) fraction ///
        xtitle("Deposit spread beta") ytitle("Fraction of banks")
    graph export "$figures/figure3_hist_conv.png", replace width(1600)
restore

*------------------------------------------------------------------------------
* Figure 4: bank-level deposit spread betas against PrB (binned scatter)
*------------------------------------------------------------------------------
binscatter depbeta pr_borrower_conv_ds, nquantiles(20) ///
    xtitle("Cross-selling potential (PrB)") ytitle("Deposit spread beta")
graph export "$figures/figure4_panelA_conv_v2.png", replace width(1600)
binscatter depbeta_pre pr_borrower_conv_ds if year < $y_lowrate, nquantiles(20) ///
    xtitle("Cross-selling potential (PrB)") ytitle("Deposit spread beta (2004-2014)")
graph export "$figures/figure4_panelB_conv_v2.png", replace width(1600)

* Bank-level slope quoted in Section 5.1 (one row per bank)
preserve
    collapse (mean) prb_bank = pr_borrower_conv_ds (first) depbeta, by(bankid)
    reg depbeta prb_bank
    di "Section 5.1 slope of bank-level beta on bank-mean PrB: b = " %7.3f _b[prb_bank] "  se = " %6.3f _se[prb_bank]
restore

*------------------------------------------------------------------------------
* Figure A1: loan-market vs. deposit-market HHI (municipality level)
*------------------------------------------------------------------------------
preserve
    collapse (mean) hhi_deposit hhi_loan, by(muniid)
    corr hhi_deposit hhi_loan
    local rho = r(rho)
    binscatter hhi_loan hhi_deposit, nquantiles(50) ///
        xtitle("HHI, deposit market") ytitle("HHI, loan market") ///
        note("Correlation: `: di %5.3f `rho''")
    graph export "$figures/figureA1_hhi_loan_vs_deposit.png", replace width(1600)
restore

*------------------------------------------------------------------------------
* Table 1, Panel D: bank level
*------------------------------------------------------------------------------
preserve
    collapse (mean) depositvol (first) depbeta (mean) prb_bank = pr_borrower_conv_ds ///
        (count) nmuni = muniid, by(bankid year)
    collapse (mean) depositvol prb_bank nmuni (first) depbeta, by(bankid)
    label var depositvol "Household deposits (mean per municipality, NOK)"
    label var prb_bank "PrB (bank mean)"
    label var nmuni "Number of municipalities served"
    label var depbeta "Deposit spread beta"
    write_sumstats_panel depbeta prb_bank nmuni depositvol, ///
        name(t1_panelD) panel(D) title(Bank level)
restore

di as result "Step 7 done: figures written to $figures"

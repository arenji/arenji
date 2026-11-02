/*==============================================================================
5_tables_relationship_level.do -- exhibits estimated on the bank-household
relationship panel

Input : $work/relid_withconv.dta, $f_prate
Output ($tables): t1_panelA.tex, t2_lpm.tex, t8_flow.tex, a9_npl.tex
       ($figures): figure5a_loanspread_sameyear.png, figure5b_loanspread_onboarding.png
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

*------------------------------------------------------------------------------
* Table 2: linear probability model for the cross-selling measures
*  (deposit-conditional sample, existing_dep == 1)
*------------------------------------------------------------------------------
use bankid muniid year relid existing_dep futureborrower converted ///
    parent retired AgedSub30 ln_inc ln_wealth ln_deposits number_banks_hhid hhi_deposit ///
    debt loanspread_on loanvol depositvol prate depspread_w0100_tr595 ///
    using "$work/relid_withconv.dta", clear

keep if year >= $y_first & year <= $y_last

* Table 1, Panel A: relationship-year level (depositor sample)
preserve
    keep if existing_dep == 1
    label var prate "Policy rate"
    label var depspread_w0100_tr595 "Deposit spread"
    label var depositvol "Deposit volume"
    label var converted "I(later borrows from same bank)"
    label var hhi_deposit "HHI"
    write_sumstats_panel prate depspread_w0100_tr595 depositvol converted hhi_deposit ///
        AgedSub30 parent retired ln_inc ln_wealth number_banks_hhid, ///
        name(t1_panelA) panel(A) title(Bank-household-year level)
restore

keep if existing_dep == 1
gen I_borrow = converted
bysort relid: egen meandebt_rel = mean(debt) if debt > 0
gen ln_meandebt = ln(meandebt_rel)
label var I_borrow "I(borrow)"
label var ln_meandebt "Ln(Mean debt)"
label var loanspread_on "Loan spread"
label var parent "I(Parental support)"
label var retired "I(Retired)"
label var AgedSub30 "Aged below 30"
label var ln_inc "Log(Income)"
label var ln_wealth "Log(Wealth)"
label var ln_deposits "Log(Deposits)"
label var number_banks_hhid "Number of bank relationships"
label var hhi_deposit "HHI"

local rhs parent retired AgedSub30 ln_inc ln_wealth ln_deposits number_banks_hhid hhi_deposit
eststo clear
eststo: reg I_borrow `rhs', robust
eststo: reg ln_meandebt `rhs', robust
eststo: reg loanspread_on `rhs', robust
write_table, name(t2_lpm) texlabel(tab:lpm) ///
    title(Predicting Cross-Selling: Borrowing Propensity, Loan Volume and Loan Spread) ///
    note(Linear probability model (column 1) and OLS (columns 2-3) on bank-household-year observations with an existing deposit relationship. I(borrow) equals one if the depositor later takes a loan from the same bank. Robust standard errors in parentheses. *, **, *** denote significance at the 10, 5 and 1 percent level.) ///
    mtitles("I(borrow)" "Ln(Mean debt)" "Loan spread") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$"))

*------------------------------------------------------------------------------
* Table 9 and Table A5: flow-profit sub-channels and NPL risk premium
*------------------------------------------------------------------------------
use bankid muniid year relid depositvol existing_dep futureborrower converted ///
    prate loanspread_on loanvol debt interest_debt ///
    using "$work/relid_withconv.dta", clear
xtset relid year

* Policy-rate change (year-level file; the panel carries only the level)
sort year
merge m:1 year using "$f_prate", nogen keep(1 3)
drop prate
ren prate2 prate
ren d_prate2 dpr
keep if year >= $y_first & year <= $y_last
label var dpr "\$\Delta\$PR"

* Loan volume measures
bysort relid: egen meanloanvol = mean(loanvol)
gen ln_meanloanvol = ln(meanloanvol)
bysort relid: egen maxloanvol = max(loanvol)
gen ln_maxloanvol = ln(maxloanvol)

* Non-performing-loan proxies: a loan with no interest paid
gen default = 0
replace default = 1 if interest_debt == 0 & loanvol > 0 & loanvol != .
bysort relid: egen ever_default = max(default)
gen default2 = 0
qui sum loanvol, detail
replace default2 = 1 if interest_debt == 0 & loanvol >= r(p75) & loanvol != .
bysort relid: egen ever_default2 = max(default2)
label var ever_default  "I(Ever NPL)"
label var ever_default2 "I(Ever NPL, large loans)"
label var loanspread_on "Loan spread"

* Table A5: do the NPL proxies carry a risk premium? (relationship-year panel)
eststo clear
eststo: reghdfe loanspread_on ever_default,  noa
    estadd local BFE "No"
eststo: reghdfe loanspread_on ever_default2, noa
    estadd local BFE "No"
eststo: reghdfe loanspread_on ever_default,  absorb(bankid)
    estadd local BFE "Yes"
eststo: reghdfe loanspread_on ever_default2, absorb(bankid)
    estadd local BFE "Yes"
write_table, name(a9_npl) texlabel(tab:a_npl) ///
    title(Loan Spreads and Non-Performing-Loan Proxies) ///
    note(Dependent variable: loan spread over the policy rate, bank-household-year level. The NPL proxies equal one if the relationship ever shows a positive loan balance with zero interest paid (column 2 and 4: loan balance above the 75th percentile). Standard errors in parentheses. *, **, *** denote significance at the 10, 5 and 1 percent level.) ///
    stats(N r2 BFE, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$" "Bank FE"))

* Figure 5: loan spread against the same-year and the onboarding-year policy rate
bysort relid (year): gen prate_onboard = prate[1]
label var prate "Policy rate in the loan year (%)"
label var prate_onboard "Policy rate in the onboarding year (%)"
label var loanspread_on "Loan spread (pp)"
binscatter loanspread_on prate if loanvol > 0, nquantiles(20) ///
    xtitle("Policy rate in the same year (%)") ytitle("Loan spread (pp)")
graph export "$figures/figure5a_loanspread_sameyear.png", replace width(1600)
binscatter loanspread_on prate_onboard if loanvol > 0, nquantiles(20) ///
    xtitle("Policy rate in the onboarding year (%)") ytitle("Loan spread (pp)")
graph export "$figures/figure5b_loanspread_onboarding.png", replace width(1600)

* Collapse to one row per relationship (first year), depositor relationships
gen has_deposits = (depositvol > 0 & depositvol != .)
bysort relid: egen ever_had_deposits = max(has_deposits)
bysort relid: egen mean_depositvol = mean(depositvol)
bysort relid (year): keep if _n == 1
gen converted_outcome = (maxloanvol > 0 & maxloanvol != .) & (ever_had_deposits == 1)
keep if ever_had_deposits == 1
label var converted_outcome "I(later loan)"
label var ln_maxloanvol "Ln(Loan vol)"

* Table 9, Panel A: unweighted
eststo clear
eststo a_b1: reghdfe converted_outcome dpr, noa cluster(relid)
eststo a_b2: reghdfe ln_maxloanvol dpr, noa cluster(relid)
eststo a_b3: reghdfe loanspread_on dpr, noa cluster(relid)
eststo a_b4: reghdfe converted_outcome dpr, absorb(bankid) cluster(relid)
eststo a_b5: reghdfe ln_maxloanvol dpr, absorb(bankid) cluster(relid)
eststo a_b6: reghdfe loanspread_on dpr, absorb(bankid) cluster(relid)
eststo a_b7: reghdfe converted_outcome dpr ever_default2, noa cluster(relid)
eststo a_b8: reghdfe ln_maxloanvol dpr ever_default2, noa cluster(relid)
eststo a_b9: reghdfe loanspread_on dpr ever_default2, noa cluster(relid)
foreach m in a_b1 a_b2 a_b3 a_b7 a_b8 a_b9 {
    estadd local BFE "No": `m'
}
foreach m in a_b4 a_b5 a_b6 {
    estadd local BFE "Yes": `m'
}
esttab a_b1 a_b2 a_b3 a_b4 a_b5 a_b6 a_b7 a_b8 a_b9 using "$tables/t8_flow_panelA.tex", ///
    replace booktabs fragment b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps label nonotes ///
    mtitles("I(later loan)" "Ln(Loan vol)" "Loan spread" "I(later loan)" "Ln(Loan vol)" "Loan spread" "I(later loan)" "Ln(Loan vol)" "Loan spread") ///
    stats(N r2 BFE, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$" "Bank FE")) ///
    prehead("\multicolumn{10}{l}{\textit{Panel A: Unweighted}}\tabularnewline \midrule") ///
    postfoot("\midrule")

* Table 9, Panel B: deposit-volume weighted
eststo clear
eststo b_b1: reghdfe converted_outcome dpr [aw=mean_depositvol], noa cluster(relid)
eststo b_b2: reghdfe ln_maxloanvol dpr [aw=mean_depositvol], noa cluster(relid)
eststo b_b3: reghdfe loanspread_on dpr [aw=mean_depositvol], noa cluster(relid)
eststo b_b4: reghdfe converted_outcome dpr [aw=mean_depositvol], absorb(bankid) cluster(relid)
eststo b_b5: reghdfe ln_maxloanvol dpr [aw=mean_depositvol], absorb(bankid) cluster(relid)
eststo b_b6: reghdfe loanspread_on dpr [aw=mean_depositvol], absorb(bankid) cluster(relid)
eststo b_b7: reghdfe converted_outcome dpr ever_default2 [aw=mean_depositvol], noa cluster(relid)
eststo b_b8: reghdfe ln_maxloanvol dpr ever_default2 [aw=mean_depositvol], noa cluster(relid)
eststo b_b9: reghdfe loanspread_on dpr ever_default2 [aw=mean_depositvol], noa cluster(relid)
foreach m in b_b1 b_b2 b_b3 b_b7 b_b8 b_b9 {
    estadd local BFE "No": `m'
}
foreach m in b_b4 b_b5 b_b6 {
    estadd local BFE "Yes": `m'
}
esttab b_b1 b_b2 b_b3 b_b4 b_b5 b_b6 b_b7 b_b8 b_b9 using "$tables/t8_flow_panelB.tex", ///
    replace booktabs fragment b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps label nonotes ///
    nomtitles nonumbers ///
    stats(N r2 BFE, fmt(%12.0fc %9.3f) labels("Observations" "R\$^2\$" "Bank FE")) ///
    prehead("\multicolumn{10}{l}{\textit{Panel B: Deposit-volume weighted}}\tabularnewline \midrule")

* Wrapper combining the two panels into tables/t8_flow.tex
file open f8 using "$tables/t8_flow.tex", write replace
file write f8 "\begin{table}[p]\centering" _n
file write f8 "\caption{Policy Rates and the Flow Profits from Cross-Selling}\label{tab:flow}" _n
file write f8 "\tablelegend{One observation per bank-household relationship that ever held deposits (first year of the relationship). Columns 1-3: no fixed effects; columns 4-6: bank fixed effects; columns 7-9: control for the NPL proxy. Panel B weights by the relationship's mean deposit volume. Standard errors clustered by relationship. *, **, *** denote significance at the 10, 5 and 1 percent level.}" _n
file write f8 "\footnotesize" _n
file write f8 "\begin{tabular}{l*{9}{c}}" _n
file write f8 "\toprule" _n
file write f8 "\input{tables/t8_flow_panelA.tex}" _n
file write f8 "\input{tables/t8_flow_panelB.tex}" _n
file write f8 "\bottomrule" _n
file write f8 "\end{tabular}" _n
file write f8 "\end{table}" _n
file close f8

di as result "Step 5 done: Tables 1A, 2, 9, A5 and Figure 5 written"

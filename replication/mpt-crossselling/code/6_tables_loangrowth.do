/*==============================================================================
6_tables_loangrowth.do -- NFC loan growth across banks within municipality-year
and within sector-year

Input : $f_firm_bmy, $f_firm_n3, $f_firm_n5, $f_prate,
        $work/treatments_banklevel_weighted_conv.dta
Output ($tables): t6_lg_bmy.tex, t7_lg_nace3.tex, a8_lg_nace5.tex,
                  t1_panelC1.tex, t1_panelC2.tex, t1_panelC3.tex
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

* One program runs the nine-column table for a given unit of observation
capture program drop loangrowth_table
program define loangrowth_table
    syntax , UNIT(varname) FE(string) NAME(string) TEXLABEL(string) TITLE(string) ///
             NOTE(string) LNVAR(varname) PANELNAME(string) PANELLETTER(string) PANELTITLE(string)

    * Growth variables (log difference arrives as a fraction; symmetric growth; new lending)
    egen uid = group(bankid `unit')
    drop if uid == .
    sort uid year
    xtset uid year
    gen firmloans = exp(`lnvar')
    gen firmloangrowth_arc = 100 * D.firmloans / (0.5*firmloans + 0.5*L.firmloans)
    winsor2 firmloangrowth_arc, cuts(1 99) suffix(_w199)
    replace firmloangrowthld_w199 = firmloangrowthld_w199 * 100
    qui sum firmloangrowthld_w199, detail
    if abs(r(p50)) > 50 | r(sd) > 500 {
        di as error "SCALING ERROR: firmloangrowthld_w199 implausibly large after *100 (source already in percent?)"
        error 9999
    }
    gen newloanvol = firmloans if (firmloans > 0 & firmloans != .) & (L.firmloans == 0 | L.firmloans == .)
    gen ln_newloanvol = ln(newloanvol)
    label var firmloangrowthld_w199 "LG (log diff., \%)"
    label var firmloangrowth_arc_w199 "LG (symmetric, \%)"
    label var ln_newloanvol "Ln(new loans)"
    label var dpr "\$\Delta\$PR"
    label var prb_conv_banklevel "PrB"
    label var hhi_banklevel "HHI"

    * Table 1, Panel C: summary statistics of this sample
    write_sumstats_panel firmloangrowthld_w199 firmloangrowth_arc_w199 ln_newloanvol dpr ///
        prb_conv_banklevel hhi_banklevel, name(`panelname') panel(`panelletter') title(`paneltitle')

    egen feid = group(`fe')
    eststo clear
    foreach var of varlist firmloangrowthld_w199 firmloangrowth_arc_w199 ln_newloanvol {
        eststo: reghdfe `var' c.dpr##c.prb_conv_banklevel, absorb(feid##year) cluster(feid##year)
            qui sum prb_conv_banklevel if e(sample)
            estadd scalar sdeff_prb = r(sd) * _b[c.dpr#c.prb_conv_banklevel]
        eststo: reghdfe `var' c.dpr##c.hhi_banklevel, absorb(feid##year) cluster(feid##year)
            qui sum hhi_banklevel if e(sample)
            estadd scalar sdeff_hhi = r(sd) * _b[c.dpr#c.hhi_banklevel]
        eststo: reghdfe `var' c.dpr##c.prb_conv_banklevel c.dpr##c.hhi_banklevel, ///
            absorb(feid##year) cluster(feid##year)
            qui sum prb_conv_banklevel if e(sample)
            estadd scalar sdeff_prb = r(sd) * _b[c.dpr#c.prb_conv_banklevel]
            qui sum hhi_banklevel if e(sample)
            estadd scalar sdeff_hhi = r(sd) * _b[c.dpr#c.hhi_banklevel]
    }
    write_table, name(`name') texlabel(`texlabel') title(`title') note(`note') ///
        order(c.dpr#c.prb_conv_banklevel prb_conv_banklevel c.dpr#c.hhi_banklevel hhi_banklevel _cons) ///
        mtitles("LG (LD)" "LG (LD)" "LG (LD)" "LG (Sym)" "LG (Sym)" "LG (Sym)" "Ln(new)" "Ln(new)" "Ln(new)") ///
        stats(N r2 sdeff_prb sdeff_hhi, fmt(%12.0fc %9.3f %9.3f %9.3f) ///
              labels("Observations" "R\$^2\$" "Effect of 1 SD of PrB" "Effect of 1 SD of HHI"))
end

* Common preparation: policy-rate change and bank-level treatments
capture program drop loangrowth_prep
program define loangrowth_prep
    syntax , BANKVAR(varname)
    sort year
    merge m:1 year using "$f_prate", nogen keep(1 3) keepusing(d_prate2)
    ren d_prate2 dpr
    * bank identifier is a string in the loan files: numeric id in positions 4-10
    ren `bankvar' bankid_str
    gen bankid = substr(bankid_str, 4, 7)
    replace bankid = "" if bankid == "L"
    destring bankid, replace
    sort bankid
    merge m:1 bankid using "$work/treatments_banklevel_weighted_conv.dta", nogen keep(1 3)
end

local note_lg "Dependent variables: NFC loan growth (log difference, columns 1-3; symmetric growth, columns 4-6) and the log volume of new loans (columns 7-9), winsorized at 1/99. PrB and HHI are deposit-weighted bank-level averages. Standard errors clustered at the fixed-effect level in parentheses. *, **, *** denote significance at the 10, 5 and 1 percent level."

*---- Table 7: bank x municipality, municipality-year FE ---------------------
use "$f_firm_bmy", clear
loangrowth_prep, bankvar(bankid)
loangrowth_table, unit(muniid) fe(muniid) lnvar(ln_firmloans_bmy) ///
    name(t6_lg_bmy) texlabel(tab:lg_bmy) ///
    title(Cross-Selling Potential and the Loan Growth Response to Policy Rate Changes: Bank-Municipality Level) ///
    note(Bank-municipality-year observations with municipality-year fixed effects. `note_lg') ///
    panelname(t1_panelC1) panelletter(C1) paneltitle(Loan growth sample, bank-municipality-year level)

*---- Table 8: bank x NACE3, sector-year FE ----------------------------------
use "$f_firm_n3", clear
loangrowth_prep, bankvar(bank_id)
loangrowth_table, unit(nace3digits) fe(nace3digits) lnvar(ln_firmloans_bsy) ///
    name(t7_lg_nace3) texlabel(tab:lg_nace3) ///
    title(Cross-Selling Potential and the Loan Growth Response to Policy Rate Changes: Bank-Sector (NACE 3-digit) Level) ///
    note(Bank-sector-year observations (NACE 3-digit) with sector-year fixed effects. `note_lg') ///
    panelname(t1_panelC2) panelletter(C2) paneltitle(Loan growth sample, bank-NACE3-year level)

*---- Table A4: bank x NACE5, sector-year FE ---------------------------------
use "$f_firm_n5", clear
loangrowth_prep, bankvar(bank_id)
loangrowth_table, unit(F_nace) fe(F_nace) lnvar(ln_firmloans_bsy) ///
    name(a8_lg_nace5) texlabel(tab:a_nace5) ///
    title(Loan Growth Response to Policy Rate Changes: Bank-Sector (NACE 5-digit) Level) ///
    note(Bank-sector-year observations (NACE 5-digit) with sector-year fixed effects. `note_lg') ///
    panelname(t1_panelC3) panelletter(C3) paneltitle(Loan growth sample, bank-NACE5-year level)

di as result "Step 6 done: loan-growth tables written"

/*==============================================================================
config.do -- paths, input-file names, required packages, helper programs.
Called by 0_master.do; can also be run on its own before running a single
script interactively (set $root first).
==============================================================================*/

* ---- Data source switch ------------------------------------------------------
* 1 = simulated pseudo data (shipped, created by 1_simulate_data.do)
* 0 = confidential administrative data placed in data/raw/ under the file
*     names listed below (no other change is needed)
global simulated 1

* ---- Folders -----------------------------------------------------------------
if $simulated == 1  global data_in "$root/data/simulated"
else                global data_in "$root/data/raw"
global work    "$root/data/work"
global tables  "$root/output/tables"
global figures "$root/output/figures"
foreach d in "$work" "$tables" "$figures" "$root/logs" "$data_in" {
    capture mkdir "`d'"
}

* ---- Input files (same names and layout as the confidential inputs) ----------
* Relationship (bank x household) x year panel = output of the data-construction
* step, i.e. data_analysis_final_full.dta.
global f_relid    "$data_in/data_analysis_final_full.dta"
* Year-level series
global f_prate    "$data_in/policy_rate.dta"          // year prate2 d_prate2 (2003-2018)
global f_mpshock  "$data_in/mpshocks_annual.dta"      // year mpshock (Holm, Paul & Tischbirek 2021)
global f_bench    "$data_in/benchmark_rates.dta"      // year nibor3m y12m y3y y5y y10y (Figure 2; Sec. 5.7 benchmarks)
* Bank x municipality x year
global f_mshares  "$data_in/mshares_and_pshares.dta"  // bankid muniid year mshare_dep
global f_munichar "$data_in/muni_characteristics.dta" // bankid muniid year total_income gross_wealth gross_fin_assets total_deposits educ move
* Bank x year (ORBOF balance sheet)
global f_bankstr  "$data_in/bankstrength.dta"         // bankid year ta ln_ta profits_ta
* NFC loan panels
global f_firm_bmy "$data_in/firmloans_bankmuni.dta"          // bankid(string) muniid year ln_firmloans_bmy firmloangrowthld_w199
global f_firm_n3  "$data_in/firmloans_banksector_nace3.dta"  // bank_id(string) nace3digits year ln_firmloans_bsy firmloangrowthld_w199
global f_firm_n5  "$data_in/firmloans_banksector_nace5.dta"  // bank_id(string) F_nace year ln_firmloans_bsy firmloangrowthld_w199

* ---- Sample window -----------------------------------------------------------
global y_first 2004
global y_last  2018
global y_lowrate 2015     // first low-rate year (policy rate < 1.5 pp)

* ---- Required community-contributed packages ---------------------------------
foreach pkg in reghdfe ftools estout winsor2 binscatter {
    capture which `pkg'
    if _rc {
        di as error "Package `pkg' is missing: ssc install `pkg', replace"
        exit 111
    }
}

* ---- Helper 1: write an esttab regression table as a self-contained .tex ----
* Usage: write_table [model list], name(file stem) title(...) [note(...)] [texlabel(...)] [esttab options]
* Produces $tables/<name>.tex with \begin{table} ... \end{table}, matching the
* \input{tables/<name>.tex} lines in manuscript.tex (which defines \tablelegend).
capture program drop write_table
program define write_table
    syntax [anything(name=models)] , NAME(string) TITLE(string) ///
        [NOTE(string) TEXLABEL(string) *]
    if "`texlabel'" == "" local texlabel "tab:`name'"
    if "`models'"   == "" local models "_all"
    esttab `models' using "$tables/`name'.tex", replace booktabs ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps label ///
        interaction(" \$\times\$ ") nonotes noomitted nobaselevels ///
        prehead("\begin{table}[p]\centering" ///
                "\caption{`title'}\label{`texlabel'}" ///
                "\tablelegend{`note'}" ///
                "\footnotesize" ///
                "\begin{tabular}{l*{@M}{c}}" "\toprule") ///
        postfoot("\bottomrule" "\end{tabular}" "\end{table}") ///
        `options'
    di as text "  wrote $tables/`name'.tex"
end

* ---- Helper 2: write one summary-statistics panel (estpost tabstat) ---------
* Usage: write_sumstats_panel varlist [if], name(file stem) panel(letter) title(...)
capture program drop write_sumstats_panel
program define write_sumstats_panel
    syntax varlist [if] , NAME(string) PANEL(string) TITLE(string)
    estpost tabstat `varlist' `if', ///
        statistics(count mean sd min p5 p50 p95 max) columns(statistics)
    esttab . using "$tables/`name'.tex", replace booktabs fragment ///
        cells("count(fmt(%12.0fc)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) p5(fmt(%9.3f)) p50(fmt(%9.3f)) p95(fmt(%9.3f)) max(fmt(%9.3f))") ///
        noobs nonumber nomtitle collabels(none) label nolines ///
        prehead("\multicolumn{9}{l}{\textit{Panel `panel': `title'}}\tabularnewline \midrule" ///
                " & N & Mean & SD & Min & p5 & p50 & p95 & Max \tabularnewline \midrule") ///
        postfoot("\midrule")
    di as text "  wrote $tables/`name'.tex"
end

* ---- Common variable labels (used by esttab label option) -------------------
capture program drop label_bmy_vars
program define label_bmy_vars
    capture label var pr_borrower_conv_ds "PrB"
    capture label var dpr          "\$\Delta\$PR"
    capture label var prate        "PR"
    capture label var mpshock      "MP surprise"
    capture label var hhi_deposit  "HHI"
    capture label var hhi_loan     "Loan HHI"
    capture label var mshare_dep   "MS"
    capture label var depspread_w0100_tr595   "Deposit spread"
    capture label var d_depspread_w0100_tr595 "\$\Delta\$ Deposit spread"
    capture label var depositvol   "Deposit volume"
    capture label var numberclients "Number of clients"
    capture label var lowrates     "LowRate"
    capture label var c3_conv      "PrB \$\times\$ E[Ln(Loan vol)]"
    capture label var c3a_conv     "PrB \$\times\$ E[Ln(Loan vol)] \$\times\$ E[Loan spread]"
    capture label var prb_others   "Other-banks PrB"
    capture label var prb_others_w "Other-banks PrB (weighted)"
    capture label var prb_resid_inc  "PrB, resid. (age, income, wealth)"
    capture label var prb_resid_full "PrB, resid. (full)"
    capture label var dpr_lead     "\$\Delta\$PR\$_{t+1}\$"
    capture label var dpr_lag      "\$\Delta\$PR\$_{t-1}\$"
    capture label var educ "Education"
    capture label var move "Moved"
    capture label var extensive_stock "Stock-market participation"
    capture label var stock_bond_share "Stock and bond share"
    capture label var depgrowth_ld "Deposit growth (log diff., \%)"
    capture label var depgrowth_ld_w1090 "Deposit growth (log diff., wins. 10/90, \%)"
end

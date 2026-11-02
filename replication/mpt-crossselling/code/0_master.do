/*==============================================================================
0_master.do -- Replication package for
  Basten & Juelsrud, "Monetary Policy Transmission through Cross-Selling Banks",
  Journal of Financial Economics (accepted version FINEC-D-26-00588R1).

Runs the complete pipeline from the relationship-level analysis panel to every
table and figure in the paper (except Figure 6, which uses ECB survey data).

HOW TO RUN
  1. Set $root below to the folder that contains code/, data/ and output/.
  2. Choose the data source in code/config.do:
       global simulated 1   -> run on the simulated pseudo data shipped here
       global simulated 0   -> run on the confidential data placed in data/raw/
  3. do "code/0_master.do"

See README.docx (or README.pdf) for the exhibit-to-script map and the list of input files.
==============================================================================*/

clear all
set more off
set varabbrev off
version 16

* ---- 1. Root folder: edit if you do not run this file from the package root --
global root "`c(pwd)'"
capture confirm file "$root/code/config.do"
if _rc {
    di as error "Set global root to the replication-package folder (the one containing code/)."
    exit 601
}

* ---- 2. Configuration: paths, file names, helper programs ------------------
do "$root/code/config.do"

capture log close main
log using "$root/logs/replication_run.log", name(main) replace text
di "Replication run started $S_DATE $S_TIME  (simulated data = $simulated)"

* ---- 2b. Record the computational environment (logs/environment.txt) --------
file open fe using "$root/logs/environment.txt", write replace
file write fe "Run date:        $S_DATE $S_TIME" _n
file write fe "Stata:           `c(stata_version)' `c(edition_real)' (`c(born_date)'), version control set to `c(version)'" _n
file write fe "OS:              `c(os)' `c(osdtl)' `c(machine_type)' `c(bit)'-bit" _n
file write fe "Simulated data:  $simulated" _n
file write fe "Community-contributed packages (first line of each ado-file):" _n
foreach pkg in reghdfe ftools esttab estout estpost winsor2 binscatter {
    capture findfile `pkg'.ado
    if _rc file write fe "  `pkg': NOT FOUND" _n
    else {
        tempname fh
        file open `fh' using "`r(fn)'", read text
        file read `fh' line
        file close `fh'
        file write fe `"  `pkg': `line'"' _n
    }
}
file close fe
type "$root/logs/environment.txt"

* ---- 3. Pipeline -------------------------------------------------------------
if $simulated == 1 {
    do "$root/code/1_simulate_data.do"          // pseudo data with the real panel structure
}
do "$root/code/2_construct_prb_and_bmy.do"      // PrB estimation, intensive-margin predictions, BMY collapse
do "$root/code/3_setup_bmy_panel.do"            // common analysis panel (dpr, spreads, merges, sophistication)
do "$root/code/4_tables_pricing.do"             // Tables 3, 4, 5, 6, 10 and A1, A2, A3, A6, A7, A8; Table 1 Panel B
do "$root/code/5_tables_relationship_level.do"  // Tables 2, 9, A5; Figure 5; Table 1 Panel A
do "$root/code/6_tables_loangrowth.do"          // Tables 7, 8, A4; Table 1 Panels C1-C3
do "$root/code/7_figures.do"                    // Figures 1, 2, 3, 4, A1; Table 1 Panel D
do "$root/code/8_assemble_table1.do"            // Table 1 wrapper (Panels A-D)
do "$root/code/9_text_numbers.do"               // numbers quoted only in the text (Sections 3.3, 4.1, 4.3)

di "Replication run finished $S_DATE $S_TIME"
di "Tables  -> $tables"
di "Figures -> $figures"
log close main

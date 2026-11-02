/*==============================================================================
1_simulate_data.do -- pseudo data with the panel structure of the confidential
administrative inputs. Nothing here is real data; the data-generating process
only reproduces the STRUCTURE (identifiers, variables, panel dimensions,
sign patterns) so that every script downstream runs unchanged on real data.

Writes to $data_in (= data/simulated/):
  data_analysis_final_full.dta    relationship (household x bank) x year panel,
                                  with the variables that the data-construction
                                  step creates
  policy_rate.dta                 year prate2 d_prate2, 2003-2018
  mpshocks_annual.dta             year mpshock
  benchmark_rates.dta             year nibor3m y12m y3y y5y y10y
  mshares_and_pshares.dta         bankid muniid year mshare_dep
  muni_characteristics.dta        bankid muniid year means of household observables
  bankstrength.dta                bankid year ta ln_ta profits_ta
  firmloans_bankmuni.dta          bankid(string) muniid year ln_firmloans_bmy firmloangrowthld_w199
  firmloans_banksector_nace3.dta  bank_id(string) nace3digits year ln_firmloans_bsy firmloangrowthld_w199
  firmloans_banksector_nace5.dta  bank_id(string) F_nace year ln_firmloans_bsy firmloangrowthld_w199

Scale: 50 banks, 120 municipalities, 30,000 households, 2004-2018.
(The real data: ~180 banks, ~430 municipalities, ~45 million relationship-years.)
Runtime: about a minute.
==============================================================================*/

* Helper programs and globals come from config.do; reload it if they are missing
* (e.g. after -clear all- when running this script on its own).
capture quietly program list write_table
if _rc {
    if "$root" == "" global root "`c(pwd)'"
    do "$root/code/config.do"
}

clear
set seed 20261021

local NB = 50          // banks
local NM = 120         // municipalities
local NH = 30000       // households
local Y0 = $y_first
local Y1 = $y_last
local NY = `Y1' - `Y0' + 1

*==============================================================================
* A. Year-level series
*==============================================================================

* Policy rate: approximate annual averages of the Norges Bank key policy rate.
clear
input year prate2
2003 4.10
2004 1.80
2005 2.00
2006 2.90
2007 4.50
2008 5.30
2009 1.80
2010 1.90
2011 2.10
2012 1.60
2013 1.50
2014 1.50
2015 1.00
2016 0.55
2017 0.50
2018 0.60
end
sort year
gen d_prate2 = prate2 - prate2[_n-1]
label var prate2   "Policy rate, annual average (%)"
label var d_prate2 "Year-on-year change in the policy rate (pp)"
save "$data_in/policy_rate.dta", replace

* Narrative monetary policy surprises (Holm, Paul and Tischbirek 2021), annual
gen mpshock = 0.5*d_prate2 + rnormal(0, 0.25)
keep if year >= `Y0'
keep year mpshock
label var mpshock "Monetary policy surprise (pp)"
save "$data_in/mpshocks_annual.dta", replace

* Benchmark rates: 3-month money-market rate (Figure 2, panel B) and generic
* government yields at 12 months, 3, 5 and 10 years (Figure 2, panel C and the
* benchmark robustness of Section 5.7). Real data: Norges Bank / OECD MEI.
use "$f_prate", clear
keep if year >= `Y0'
gen nibor3m = prate2 + 0.35 + rnormal(0, 0.15)
gen y12m    = prate2 + 0.15 + rnormal(0, 0.10)
gen y3y     = 0.8*prate2 + 0.9 + rnormal(0, 0.15)
gen y5y     = 0.7*prate2 + 1.4 + rnormal(0, 0.20)
gen y10y    = 0.55*prate2 + 2.0 + rnormal(0, 0.25)
keep year nibor3m y12m y3y y5y y10y
label var nibor3m "3-month money-market rate (%)"
label var y12m "12-month Treasury bill yield (%)"
label var y3y  "3-year government bond yield (%)"
label var y5y  "5-year government bond yield (%)"
label var y10y "10-year government bond yield (%)"
save "$data_in/benchmark_rates.dta", replace


*==============================================================================
* B. Municipalities and banks
*==============================================================================

clear
set obs `NM'
gen muniid      = 100 + _n
gen m_size      = exp(rnormal(0, 0.8))             // relative population
gen hhi_deposit = 0.15 + 0.5*runiform()^2          // deposit-market HHI
gen hhi_loan    = 0.05 + 0.9*hhi_deposit + rnormal(0, 0.03)   // corr ~0.9 with deposit HHI
gen m_inc       = rnormal(0, 0.15)                 // local income shifter
gen m_fe_dep    = rnormal(0, 0.015)                // local deposit-pricing shifter
tempfile munis
save `munis'

clear
set obs `NB'
gen bankid    = _n
gen b_pt      = rnormal(0, 0.015)                  // bank pass-through shifter
gen b_scope   = 0.25 + 0.60*runiform()             // share of municipalities served
gen b_lnta0   = rnormal(9.5, 1.4)
gen b_prof0   = 0.009 + rnormal(0, 0.004)
gen b_lspread = rnormal(0, 0.15)                   // bank loan-pricing shifter
tempfile banks
save `banks'

* Bank x year balance-sheet panel (ORBOF in the real data)
expand `NY'
bysort bankid: gen year = `Y0' + _n - 1
gen ln_ta      = b_lnta0 + 0.04*(year - `Y0') + rnormal(0, 0.05)
gen ta         = exp(ln_ta)
gen profits_ta = b_prof0 + rnormal(0, 0.0015) - 0.001*(year >= $y_lowrate)
keep bankid year ta ln_ta profits_ta
label var ta         "Total assets"
label var ln_ta      "Log total assets"
label var profits_ta "Pre-tax profits / total assets"
sort bankid year
save "$data_in/bankstrength.dta", replace

* Bank presence across municipalities (banks 1-3 are nationwide)
use `banks', clear
keep bankid b_scope
cross using `munis'
keep if runiform() < b_scope | bankid <= 3
keep bankid muniid
tempfile presence
save `presence'

*==============================================================================
* C. Households, relationships, and the relationship-year panel
*==============================================================================

clear
set obs `NH'
gen hhid = _n

* Municipality drawn with probability proportional to size
preserve
    use `munis', clear
    sort muniid
    egen tot = total(m_size)
    gen w  = m_size/tot
    gen cw = sum(w)
    forvalues i = 1/`NM' {
        local cw`i'  = cw[`i']
        local mid`i' = muniid[`i']
    }
restore
gen u = runiform()
gen muniid = .
forvalues i = `NM'(-1)1 {
    replace muniid = `mid`i'' if u <= `cw`i''
}
replace muniid = `mid`NM'' if muniid == .
drop u
merge m:1 muniid using `munis', nogen keep(1 3) ///
    keepusing(hhi_deposit hhi_loan m_inc m_fe_dep)

* Time-invariant household characteristics
gen age04      = floor(18 + 65*runiform()^0.9)
gen birthyear  = `Y0' - age04
gen parent0    = runiform() < 0.30
gen ln_inc0    = 12.6 + m_inc + rnormal(0, 0.45)
gen ln_wealth0 = ln_inc0 + 0.6 + rnormal(0, 1.1)
gen educ       = runiform() < (0.30 + 0.25*(ln_inc0 - 12.6))
gen move       = runiform() < 0.08
gen stockholder = runiform() < 0.35
gen nbanks     = 1 + (runiform() < 0.40) + (runiform() < 0.15)
gen hh_dep_fe  = rnormal(0, 0.9)
gen hh_u1 = runiform()
gen hh_u2 = runiform()
label var educ "Higher education"
label var move "Moved municipality"

* Relationships: each household picks nbanks distinct banks present in its municipality
joinby muniid using `presence'
gen r = runiform()
bysort hhid (r): keep if _n <= nbanks
drop r
sort hhid bankid
gen relid = _n
bysort hhid: gen number_banks_hhid = _N
merge m:1 bankid using `banks', nogen keep(1 3) keepusing(b_pt b_lspread)

* Latent conversion propensity (depends on what the bank observes)
gen xb = -1.2 + 1.4*(age04 < 30) - 0.40*parent0 - 1.1*(age04 >= 62) ///
       + 0.50*(ln_inc0 - 12.6) + 0.15*(ln_wealth0 - 13.2) - 0.60*(nbanks - 1) ///
       + 0.40*(hhi_deposit - 0.35) + rnormal(0, 0.3)
gen prb_true = invlogit(xb)

* Active years of the household (all of its relationships share them)
gen start_y = `Y0'
replace start_y = `Y0' + 1 + floor(10*(hh_u1 - 0.65)/0.35) if hh_u1 >= 0.65
gen end_y = `Y1'
replace end_y = start_y + floor((`Y1' - start_y)*(hh_u2 - 0.85)/0.15) if hh_u2 >= 0.85

* Policy-rate change in the household's first year (conversion is more likely
* after rate cuts: flow-profit channel, Table 9)
gen dpr_start = .
preserve
    use "$f_prate", clear
    forvalues y = `Y0'/`Y1' {
        qui sum d_prate2 if year == `y'
        local dpr`y' = r(mean)
    }
restore
forvalues y = `Y0'/`Y1' {
    replace dpr_start = `dpr`y'' if start_y == `y'
}

* Deposit vs loan-only relationships; loan origination year. A share of the
* depositor relationships already carry a loan in their first observed year
* (left-censoring at 2004 in the real data).
gen depositor = runiform() < 0.92
gen u_loan    = runiform()
gen u_first   = runiform()
gen loan_y    = .
replace loan_y = start_y + 1 + floor(runiform()*(`Y1' - start_y)) ///
    if depositor == 1 & u_loan < 1.6*prb_true*(1 - 0.15*dpr_start) & start_y < `Y1'
replace loan_y = start_y if depositor == 1 & loan_y != . & u_first < 0.25
replace loan_y = start_y + floor(runiform()*(`Y1' - start_y + 1)) ///
    if depositor == 0 & u_loan < 0.60
replace loan_y = . if loan_y > end_y
gen u_loansize = rnormal(0, 0.6)
gen risky      = runiform() < 0.08
gen rel_spread_fe = rnormal(0, 0.8)   // persistent relationship-level deposit-pricing effect (product sorting)
gen npl_y      = loan_y + 1 + floor(runiform()*5) if loan_y != . & risky == 1

* Expand to the relationship-year panel
gen ny = end_y - start_y + 1
expand ny
bysort relid: gen year = start_y + _n - 1
merge m:1 year using "$f_prate", nogen keep(1 3) keepusing(prate2)
ren prate2 prate
sort relid year
xtset relid year

* Time-varying household observables
gen age       = year - birthyear
gen AgedSub30 = age < 30
gen retired   = age >= 62
gen parent    = parent0 & inrange(age, 25, 50)
gen ln_inc    = ln_inc0 + 0.025*(year - `Y0') - 0.35*retired + rnormal(0, 0.10)
gen ln_wealth = ln_wealth0 + 0.03*(year - `Y0') + rnormal(0, 0.10)
gen total_income = exp(ln_inc)
gen gross_wealth = exp(ln_wealth)

* Bank strength (for the low-rate attenuation in the DGP)
merge m:1 bankid year using "$data_in/bankstrength.dta", nogen keep(1 3) keepusing(profits_ta ln_ta)
sort relid year
xtset relid year
gen lowrates = year >= $y_lowrate

*---- Deposit pricing: the deposit spread beta (d spread / d PR) is higher
* where PrB and HHI are higher; the PrB part fades in the low-rate years, more
* so for less profitable and smaller banks. The spread is generated from its
* year-on-year changes so that the pass-through heterogeneity is exactly what
* the first-differenced regressions estimate.
gen dpr_sim = D.prate
replace dpr_sim = 0 if dpr_sim == .
gen att = 0.60 - 25*(profits_ta - 0.009) - 0.08*(ln_ta - 9.5)
replace att = max(min(att, 0.9), 0.1)
gen dsb = 0.15 - b_pt - m_fe_dep + 0.30*(prb_true - 0.17)*(1 - lowrates*(1.2 + 2.5*att)) ///
        + 0.15*(hhi_deposit - 0.35)
gen spread_sim = prate*dsb + rel_spread_fe + rnormal(0, 0.15) if year == start_y
forvalues y = `=`Y0'+1'/`Y1' {
    replace spread_sim = L.spread_sim + dpr_sim*dsb + rnormal(0, 0.07) if year == `y' & spread_sim == .
}
gen deprate_sim = max(prate - spread_sim, 0.02)      // banks do not pay negative deposit rates

*---- Deposit balances: growth responds to relative deposit attractiveness ---
gen g_dep = 0.03 - 0.02*dpr_sim - 0.20*dpr_sim*(prb_true - 0.17) ///
          - 0.10*dpr_sim*(hhi_deposit - 0.35) + rnormal(0, 0.30)
gen ln_dep = 11.0 + 0.45*(ln_inc - 12.6) + 0.30*(ln_wealth - 13.2) + 0.5*retired ///
           + hh_dep_fe + rnormal(0, 0.5) if year == start_y
forvalues y = `=`Y0'+1'/`Y1' {
    replace ln_dep = L.ln_dep + g_dep if year == `y' & ln_dep == .
}
gen deposits = round(exp(ln_dep)) if depositor == 1
replace deposits = 0 if depositor == 0
gen ave_dep = 0.5*(L.deposits + deposits)
replace ave_dep = deposits if L.deposits == .
gen interest_deposit = deprate_sim/100 * ave_dep

*---- Loans: volume falls and spread compresses when the policy rate is higher
gen prate_orig_tmp = prate if year == loan_y
egen prate_orig = max(prate_orig_tmp), by(relid)
gen ln_loan0 = 13.6 + 0.7*(age04 < 30) + 0.5*parent0 + 0.6*(ln_inc0 - 12.6) ///
             + 0.15*(ln_wealth0 - 13.2) - 0.10*prate_orig - 0.08*dpr_start + u_loansize
gen loanvol = round(exp(ln_loan0)*(1 - 0.06*(year - loan_y))) if loan_y != . & year >= loan_y
replace loanvol = 0 if loanvol == . | loanvol < 0
gen loanrate_sim = prate + 2.3 - 0.25*prate - 0.25*dpr_sim + 0.35*risky + b_lspread + rnormal(0, 0.35) if loanvol > 0
gen ave_debt = 0.5*(L.loanvol + loanvol)
replace ave_debt = loanvol if L.loanvol == .
gen interest_debt = loanrate_sim/100 * ave_debt if loanvol > 0
replace interest_debt = 0 if loanvol == 0
replace interest_debt = 0 if year == npl_y & loanvol > 0      // non-performing year

*==============================================================================
* D. Variables as created by the data-construction step
*    (same names and definitions as in the confidential analysis panel)
*==============================================================================

sort relid year
xtset relid year

* Loan events and cross-selling indicators
gen new_loan = loanvol > 0 & L.loanvol == 0 & loanvol != .
gen existing_dep = (L.deposits > 0 & L.deposits != .)
gen futureborrower = new_loan
forvalues k = 1/13 {
    replace futureborrower = 1 if F`k'.new_loan == 1
}
gen converted = futureborrower & existing_dep

* Effective interest rates (interest flow / average balance), deposit spreads
gen interest_rate_deposit = 100*interest_deposit/ave_dep
replace interest_rate_deposit = . if interest_rate_deposit <= 0
gen interest_rate_debt = 100*interest_debt/ave_debt
replace interest_rate_debt = . if interest_rate_debt <= 1
gen deprate = interest_rate_deposit
gen depspread = prate - deprate
gen depspread_w0100 = depspread                       // deposit rate as is (no winsorizing)
winsor2 depspread_w0100, cuts(5 95) trim suffix(_tr595)   // spread trimmed at 5/95 (baseline)
winsor2 depspread_w0100, cuts(5 95) suffix(_w595)         // spread winsorized at 5/95

* Loan rates and spreads
gen loanrate = interest_rate_debt
winsor2 loanrate, cuts(1 99) replace
gen loanspread_on = loanrate - prate
winsor2 loanspread_on, cuts(1 99) replace
* In the real data loanspread is benchmarked to a maturity-matched government
* yield; the pseudo data have no maturity information, so the two coincide.
gen loanspread = loanspread_on

* Balances
gen depositvol = deposits
gen ln_deposits = ln(depositvol)
replace ln_deposits = ln(0.000001) if depositvol == 0
gen debt = loanvol
winsor2 debt, cuts(0 99) replace
gen debt_old = debt
replace debt = 0.01 if debt == 0

* Household-level loan size measures used for the intensive-margin predictions
gen posdebt = debt if debt > 0 & debt != .
bysort hhid: egen meandebt = mean(posdebt)
bysort hhid: egen maxdebt  = max(posdebt)
gen lnmeandebt = ln(meandebt)
gen lnmaxdebt  = ln(maxdebt)
bysort relid: egen maxloanvol = max(loanvol)

* Keep the variables of the analysis file
keep hhid relid bankid muniid year prate ///
     deposits depositvol ln_deposits interest_deposit deprate ///
     depspread depspread_w0100 depspread_w0100_tr595 depspread_w0100_w595 ///
     loanvol debt debt_old interest_debt loanrate loanspread loanspread_on ///
     age AgedSub30 birthyear parent retired educ move stockholder ///
     ln_inc ln_wealth total_income gross_wealth number_banks_hhid ///
     hhi_deposit hhi_loan ///
     new_loan existing_dep futureborrower converted ///
     meandebt maxdebt lnmeandebt lnmaxdebt maxloanvol

label var relid  "Bank-household relationship id"
label var hhid   "Household id"
label var bankid "Bank id"
label var muniid "Municipality id"
label var prate  "Policy rate (%)"
label var depositvol "Deposit volume (NOK)"
label var loanvol    "Loan volume (NOK)"
label var deprate    "Effective deposit rate (%)"
label var depspread_w0100_tr595 "Deposit spread, trimmed 5/95 (pp)"
label var loanspread_on "Loan spread over policy rate (pp)"
label var AgedSub30 "Aged below 30"
label var parent  "I(Parental support)"
label var retired "I(Retired)"
label var ln_inc  "Log(Income)"
label var ln_wealth "Log(Wealth)"
label var ln_deposits "Log(Deposits)"
label var number_banks_hhid "Number of bank relationships"
label var hhi_deposit "Deposit-market HHI"
label var hhi_loan "Loan-market HHI"
label var futureborrower "Takes a loan from this bank within the sample"
label var existing_dep "Had deposits with this bank last year"
label var converted "Depositor who later borrows from the same bank"

sort relid year
compress
save "$data_in/data_analysis_final_full.dta", replace

*==============================================================================
* E. Auxiliary bank x municipality x year files derived from the panel
*==============================================================================

* Deposit market shares (mshares_and_pshares.dta in the real data)
use bankid muniid year depositvol using "$data_in/data_analysis_final_full.dta", clear
collapse (sum) depositvol, by(bankid muniid year)
bysort muniid year: egen tot = total(depositvol)
gen mshare_dep = depositvol/tot
label var mshare_dep "Bank's deposit market share in the municipality"
keep bankid muniid year mshare_dep
sort bankid muniid year
save "$data_in/mshares_and_pshares.dta", replace

* Municipality characteristics (muni_characteristics.dta in the real data):
* bank x municipality x year means of household observables
use hhid bankid muniid year depositvol total_income gross_wealth educ move stockholder ///
    using "$data_in/data_analysis_final_full.dta", clear
bysort hhid year: egen total_deposits = total(depositvol)
gen gross_fin_assets = total_deposits + stockholder*0.30*gross_wealth*runiform()
collapse (mean) total_income gross_wealth gross_fin_assets total_deposits educ move, ///
    by(muniid bankid year)
sort bankid muniid year
save "$data_in/muni_characteristics.dta", replace

*==============================================================================
* F. NFC loan panels (bank x municipality x year, bank x NACE3 x year,
*    bank x NACE5 x year). Loan growth responds to dPR x bank-level PrB.
*==============================================================================

* Bank-level cross-selling potential implied by the pseudo data
use bankid depositvol hhi_deposit converted using "$data_in/data_analysis_final_full.dta", clear
collapse (mean) prb_bank = converted hhi_bank = hhi_deposit [iw = depositvol], by(bankid)
tempfile bankprb
save `bankprb'

* Muni-year and sector-year demand shocks
clear
set obs `NM'
gen muniid = 100 + _n
expand `NY'
bysort muniid: gen year = `Y0' + _n - 1
gen my_shock = rnormal(0, 0.06)
tempfile myshock
save `myshock'

capture program drop simulate_firmloans
program define simulate_firmloans
    * args: unit variable name, level of ln loans, output name
    syntax , UNIT(string) LNLEVEL(real) SHOCKFILE(string) SHOCKVAR(string) ///
             OUT(string) IDNAME(string) LNNAME(string)
    merge m:1 bankid using `shockfile', nogen keep(1 3)
    merge m:1 year using "$f_prate", nogen keep(1 3) keepusing(d_prate2)
    gen g = 0.01 + `shockvar' - 0.05*d_prate2 - 0.55*d_prate2*(prb_bank - 0.17) ///
            - 0.20*d_prate2*(hhi_bank - 0.35) + rnormal(0, 0.35)
    egen uid = group(bankid `unit')
    sort uid year
    gen lnL = `lnlevel' + b_lnta0 - 9.5 + rnormal(0, 0.8) if year == entry_y
    forvalues y = `=$y_first+1'/$y_last {
        replace lnL = lnL[_n-1] + g if year == `y' & lnL == . & uid == uid[_n-1]
    }
    gen `lnname' = lnL
    gen firmloangrowthld = `lnname' - `lnname'[_n-1] if uid == uid[_n-1]
    winsor2 firmloangrowthld, cuts(1 99) suffix(_w199)
    * string bank identifier as in the real loan files (numeric id in positions 4-10);
    * the output variable may itself be called bankid, so build it under a temporary name
    gen _bankid_str = "NB_" + string(bankid, "%07.0f")
    drop bankid
    rename _bankid_str `idname'
    keep `idname' `unit' year `lnname' firmloangrowthld_w199
    label var firmloangrowthld_w199 "Log-difference loan growth (fraction), winsorized 1/99"
    sort `idname' `unit' year
    save "`out'", replace
end

* F1. Bank x municipality (firmloans_bankmuni.dta)
use `presence', clear
merge m:1 bankid using `banks', nogen keep(1 3) keepusing(b_lnta0)
merge m:1 bankid using `bankprb', nogen keep(1 3)
gen entry_y = cond(runiform() < 0.85, `Y0', `Y0' + 1 + floor(runiform()*8))
expand `NY'
bysort bankid muniid: gen year = `Y0' + _n - 1
drop if year < entry_y
merge m:1 muniid year using `myshock', nogen keep(1 3)
tempfile bm
save `bm'
* shock file for the program: bank-level ingredients are already on the file
keep bankid b_lnta0 prb_bank hhi_bank
duplicates drop
tempfile bankinfo
save `bankinfo'
use `bm', clear
drop b_lnta0 prb_bank hhi_bank
simulate_firmloans, unit(muniid) lnlevel(16) shockfile(`bankinfo') shockvar(my_shock) ///
    out("$data_in/firmloans_bankmuni.dta") idname(bankid) lnname(ln_firmloans_bmy)

* F2. Bank x NACE 3-digit sector (firmloans_banksector_nace3.dta)
clear
set obs 40
gen nace3digits = 100 + 5*_n
expand `NY'
bysort nace3digits: gen year = `Y0' + _n - 1
gen sy_shock = rnormal(0, 0.06)
tempfile n3shock
save `n3shock'
use `banks', clear
keep bankid b_lnta0
cross using `n3shock'
drop year sy_shock
duplicates drop
keep if runiform() < 0.6 | bankid <= 3
gen entry_y = cond(runiform() < 0.85, `Y0', `Y0' + 1 + floor(runiform()*8))
expand `NY'
bysort bankid nace3digits: gen year = `Y0' + _n - 1
drop if year < entry_y
merge m:1 nace3digits year using `n3shock', nogen keep(1 3)
drop b_lnta0
simulate_firmloans, unit(nace3digits) lnlevel(17) shockfile(`bankinfo') shockvar(sy_shock) ///
    out("$data_in/firmloans_banksector_nace3.dta") idname(bank_id) lnname(ln_firmloans_bsy)

* F3. Bank x NACE 5-digit sector (firmloans_banksector_nace5.dta)
clear
set obs 120
gen F_nace = 10000 + 37*_n
expand `NY'
bysort F_nace: gen year = `Y0' + _n - 1
gen sy_shock = rnormal(0, 0.08)
tempfile n5shock
save `n5shock'
use `banks', clear
keep bankid b_lnta0
cross using `n5shock'
drop year sy_shock
duplicates drop
keep if runiform() < 0.35 | bankid <= 3
gen entry_y = cond(runiform() < 0.85, `Y0', `Y0' + 1 + floor(runiform()*8))
expand `NY'
bysort bankid F_nace: gen year = `Y0' + _n - 1
drop if year < entry_y
merge m:1 F_nace year using `n5shock', nogen keep(1 3)
drop b_lnta0
simulate_firmloans, unit(F_nace) lnlevel(16) shockfile(`bankinfo') shockvar(sy_shock) ///
    out("$data_in/firmloans_banksector_nace5.dta") idname(bank_id) lnname(ln_firmloans_bsy)

di as result "Simulated data written to $data_in"

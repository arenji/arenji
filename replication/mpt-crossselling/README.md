# Replication package — Basten & Juelsrud, "Monetary Policy Transmission through Cross-Selling Banks" (Journal of Financial Economics, forthcoming)

Full documentation: **[README.pdf](README.pdf)** (also `README.docx`).

Quick start (Stata 16 or later, with `reghdfe`, `ftools`, `estout`, `winsor2` and `binscatter` installed from SSC):

```stata
cd "<this folder>"
do "code/0_master.do"
```

This runs the whole pipeline on the simulated pseudo data set included in `data/simulated/`, which has the structure of the confidential administrative data and can be rebuilt with `code/1_simulate_data.do` (`global regenerate 1` in `code/config.do`), and writes every table and figure of the paper to `output/`. To run on the confidential data, place the input files listed in the README in `data/raw/` and set `global simulated 0` in `code/config.do`.

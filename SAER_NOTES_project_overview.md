# NCVS (Crimea analyses) — Project map + methods outline (draft)

## What Danny said the project is doing (from voice note)
- Data: National Crime Victimization Survey (NCVS), Bureau of Justice Statistics (BJS), years **2014–2022**.
- Core question: whether the **ratio of “social crimes” to total crimes** is **statistically elevated for teens** relative to other age brackets.
- Run three analysis scopes:
  1) all crimes
  2) theft crimes only
  3) violent crimes only

## Conceptual variables / coding (high-level)
- Age is categorical (NCVS bracket codes), not continuous.
- NCVS “crime type” is stored as codes, with an index mapping to categories (violent/theft/etc.).
- Sociality coding:
  - **solo crime** vs **group crime**
  - within group crimes: distinguish **social** vs **group-but-not-social** where others are present but *not helpful to victim* (per variables like others_present/help/harm)
- For group crimes with multiple offenders, crimes can be attributed to:
  - youngest offender present
  - oldest offender present
  - (and possibly both; Danny said you can find where we attributed the crime to both)

## Current file structure (as pulled from Battle Station)
Top-level (selected):
- `ncvs-merged-data-2014-2022.csv` — merged dataset (all crimes)
- `theft-ncvs-merged-data-2014-2022.csv` — theft subset
- `violent-ncvs-merged-data-2014-2022.csv` — violent subset
- `NCVS-Analyses-weighted.docx` / `NCVS-Analyses-unweighted.docx` — writeups/tables assembled in Word
- `ReadMe_Template.txt` — rough intended readme

Raw → coded pipeline:
- `originaldata-pull/raw-ncvs-data/` — per-year raw CSVs (`2014.csv` … `2022.csv`)
- `originaldata-pull/ncvs-data-coding.Rmd` — **raw conversion + recoding** script
- `originaldata-pull/coded_data/` — intermediate coded outputs
  - `ncvs_2014_2022_incident_full.csv`
  - `ncvs_2014_2022_incident_age_brr.csv`
  - `rawdata--ncvs-2014-2022.csv`
  - `ncvs-merged-data-2014-2022.csv` (duplicate of top-level)

Analysis notebooks (main entrypoints):
- `total/unweighted/ncvs_coofensecombined_scoring.Rmd`
- `total/weighted/weighted-ncvs_coofensecombined_scoring.Rmd`
- `total/weighted/theft-weighted-ncvs_coofensecombined_scoring.Rmd`
- `total/weighted/violent-weighted-ncvs_coofensecombined_scoring.Rmd`
- `cooffending/total/coffend-ncvs_coofensecombined_scoring.Rmd`

Outputs:
- Multiple `*_R_Tables/` directories with `.docx` tables and CSVs (e.g., chi-squared tables, regression tables, percentage tables)

## Methods outline (draft — fill as we read the code)
1) **Acquire raw NCVS per-year CSVs (2014–2022)** from BJS.
2) **Standardize variable availability across years** using helper `get_var()`; missing vars become NA.
3) Extract key incident/offender variables (seen in code):
   - offender count indicator (`V4234`)
   - offender gender (`V4236`)
   - solo offender age (`V4237`)
   - youngest multiple (`V4251`), oldest multiple (`V4252`)
   - others present/help/harm (`V4184`, `V4185`, `V4194`)
   - crime type (`V4529`)
   - incident weight (`V4527`, fallback `SERIES_IWEIGHT`)
4) **Replicate weights (BRR)**: detect prefix (e.g., `VICREPWGT`, `SERIESVICREPWGT`, etc.), standardize to `VICREPWGT1` … `VICREPWGT160`.
5) **Recoding**: map numeric codes → labeled categories (gender, age brackets, etc.).
6) Create derived indicators:
   - solo vs group
   - social vs non-social group crimes using presence/help/harm logic
   - teen age brackets vs others
   - violent/theft/all crime subsets using crime-type index codes
7) **Modeling/estimation** (to verify by reading the scoring Rmds):
   - compute social/total ratios by age group
   - compare teens vs other groups
   - use weights + replicate weights for variance/SEs where applicable
   - logistic regression tables and chi-squared tables appear in outputs

## Immediate next actions Saer will do
- [ ] Read the main scoring notebooks (`total/unweighted/...` and `total/weighted/...`) and summarize:
  - what datasets they read
  - what derived variables they compute
  - what exact models/tests they run
  - which outputs correspond to which manuscript tables
- [ ] Build a clean `README.md` explaining the pipeline + how to reproduce.
- [ ] Find and add the **BJS PDF/codebook** that maps column codes → meaning (requested).

## Repro notes / blockers
- I don’t currently have R available on Saer Mac (`Rscript` not found), so I can’t execute the Rmds yet.
  - Option A: install R + needed packages on Saer.
  - Option B: run the code on Battle Station (which likely already has R configured) and sync outputs back.

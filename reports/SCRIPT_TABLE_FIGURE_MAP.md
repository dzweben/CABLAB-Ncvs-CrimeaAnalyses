# Script → table/figure/output map

This is a pragmatic map of the scripts/Rmds in the repo to the key outputs they are intended to create.

> Conventions:
> - Paths are relative to the repo root.
> - Several legacy Rmds contain hard-coded absolute output paths; those runs may write outside the repo unless edited.

## Data build / coding

| Script | Purpose | Key inputs | Key outputs |
|---|---|---|---|
| `originaldata-pull/ncvs-data-coding.Rmd` | Parse yearly raw NCVS extracts; recode and build merged analysis files (total/theft/violent). | `originaldata-pull/raw-ncvs-data/{2014..2022}.csv` | `ncvs-merged-data-2014-2022.csv`, `theft-ncvs-merged-data-2014-2022.csv`, `violent-ncvs-merged-data-2014-2022.csv`, plus `originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv` |

## Main analyses (Rmds)

| Script | Scope | Key inputs | Intended outputs |
|---|---|---|---|
| `total/weighted/weighted-ncvs_coofensecombined_scoring.Rmd` | Total (weighted) | `ncvs-merged-data-2014-2022.csv` | Word tables in `total/weighted/R_Tables/` (e.g., chi-square, descriptives, logistic regression) |
| `total/weighted/theft-weighted-ncvs_coofensecombined_scoring.Rmd` | Theft (weighted) | `theft-ncvs-merged-data-2014-2022.csv` | Word tables in `total/weighted/Theft_R_Tables/` |
| `total/weighted/violent-weighted-ncvs_coofensecombined_scoring.Rmd` | Violent (weighted) | `violent-ncvs-merged-data-2014-2022.csv` | Word tables in `total/weighted/Violent_R_Tables/` |
| `total/weighted/weighted-ncvs_cooffendingonly_scoring.Rmd` | Total (weighted; alternative social definition / co-offending only) | `ncvs-merged-data-2014-2022.csv` | Word tables in `total/weighted/R_Tables/` (alt-definition variants) |
| `total/unweighted/ncvs_coofensecombined_scoring.Rmd` | Total (unweighted; legacy exploratory + tables/figures) | `ncvs-merged-data-2014-2022.csv` | Intended: `total/R_Tables/*` including a co-offense pairing matrix `.csv` and multiple `.docx` tables; **contains hard-coded absolute paths** |

## Co-offending scoring (Rmd)

| Script | Purpose | Key inputs | Key outputs |
|---|---|---|---|
| `cooffending/total/coffend-ncvs_coofensecombined_scoring.Rmd` | Co-offending scoring workflow (total) | Merged NCVS CSV(s) (see script) | Outputs depend on knitting config; review Rmd for output paths |

## Supplemental analyses

| Script | Purpose | Key inputs | Outputs |
|---|---|---|---|
| `supplemental/unweighted_run_all.R` | Runs 4 unweighted supplemental analysis scopes and exports `.csv` + bundled `.docx` tables. | `ncvs-merged-data-2014-2022.csv`, `theft-ncvs-merged-data-2014-2022.csv`, `violent-ncvs-merged-data-2014-2022.csv` | `supplemental/unweighted_outputs/{total_main,theft_main,violent_main,total_backup_cooffending_only}/*` |
| `supplemental/extract_docx_tables.py` | Utility: extract tables from `.docx` | A `.docx` file | Extracted tables (see script for output conventions) |
| `supplemental/age_gap_check_youngest_oldest.py` | Utility: checks age-gap patterns between youngest/oldest co-offenders | A merged NCVS CSV | Summary output (see script for output conventions) |

## Manuscript utilities

| Script | Purpose | Inputs | Outputs |
|---|---|---|---|
| `manuscript/make_reference_doc.py` | Generate an APA-ish formatted references `.docx` shell. | None (or CLI arg for output path) | `.docx` written to provided path (default `apa7_reference.docx`) |

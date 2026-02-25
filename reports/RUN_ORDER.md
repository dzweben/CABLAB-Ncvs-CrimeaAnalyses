# NCVS Crimea Analyses — Run order

This repo contains (a) raw-year NCVS extracts, (b) a coding/merge step that produces analysis-ready CSVs, and (c) analysis scripts/Rmds that generate tables (mostly `.docx`) and some `.csv` outputs.

## 0) Working directory
All commands below assume you run them **from the repository root**.

## 1) Raw inputs (required)
- `originaldata-pull/raw-ncvs-data/2014.csv` … `2022.csv`

If any year file is missing, the coding step will skip it.

## 2) Build analysis-ready merged datasets (required)
Source:
- `originaldata-pull/ncvs-data-coding.Rmd`

Primary outputs (written to repo root):
- `ncvs-merged-data-2014-2022.csv`
- `theft-ncvs-merged-data-2014-2022.csv`
- `violent-ncvs-merged-data-2014-2022.csv`

Additional output:
- `originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv`

Example command:
```bash
Rscript -e "rmarkdown::render('originaldata-pull/ncvs-data-coding.Rmd', knit_root_dir=getwd())"
```

## 3) Main analyses (tables)
### 3a) Total (weighted)
- Script: `total/weighted/weighted-ncvs_coofensecombined_scoring.Rmd`
- Outputs: `total/weighted/R_Tables/*` (Word tables)

### 3b) Theft (weighted)
- Script: `total/weighted/theft-weighted-ncvs_coofensecombined_scoring.Rmd`
- Outputs: `total/weighted/Theft_R_Tables/*` (Word tables)

### 3c) Violent (weighted)
- Script: `total/weighted/violent-weighted-ncvs_coofensecombined_scoring.Rmd`
- Outputs: `total/weighted/Violent_R_Tables/*` (Word tables)

### 3d) Total (unweighted; legacy)
- Script: `total/unweighted/ncvs_coofensecombined_scoring.Rmd`
- Outputs (intended): `total/R_Tables/*`
- Note: this Rmd currently contains **hard-coded absolute paths** (e.g., `/Users/dannyzweben/...`). It may require path edits or running in an environment that matches those paths.

Example render pattern:
```bash
Rscript -e "rmarkdown::render('total/weighted/weighted-ncvs_coofensecombined_scoring.Rmd', knit_root_dir=getwd())"
```

## 4) Supplemental analyses (unweighted)
Driver script:
- `supplemental/unweighted_run_all.R`

Inputs (must exist in repo root):
- `ncvs-merged-data-2014-2022.csv`
- `theft-ncvs-merged-data-2014-2022.csv`
- `violent-ncvs-merged-data-2014-2022.csv`

Outputs:
- `supplemental/unweighted_outputs/<scope>/*`

Run:
```bash
Rscript supplemental/unweighted_run_all.R
```

## 5) Manuscript utilities (optional)
- `manuscript/make_reference_doc.py` → creates an APA-ish formatted `.docx` shell.

Example:
```bash
python manuscript/make_reference_doc.py manuscript/apa7_reference.docx
```

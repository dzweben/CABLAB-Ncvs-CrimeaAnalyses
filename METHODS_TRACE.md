# NCVS (Crimea analyses) — Methods trace + reproducibility map

This document is the “audit trail” for the manuscript: every methodological claim is tied to (1) **what** we did, (2) **where** it lives in code (file + exact variables/column codes), (3) **what** it outputs, and (4) how it fits into the pipeline.

> Status: Draft v0 (skeleton). I will fill in each section by reading and (where possible) executing the analysis notebooks.

---

## 0) Project goal (conceptual)
**Research question:** Is the **ratio of “social crimes” to total crimes** statistically elevated among **teens** relative to other age groups?

**Scopes analyzed:**
1) all crimes
2) theft/property crimes subset
3) violent/nonfatal personal crimes subset

**Primary dataset:** National Crime Victimization Survey (NCVS), Bureau of Justice Statistics (BJS), 2014–2022.

---

## 1) Data provenance + documentation
### 1.1 Source
- **Raw data location in repo:** `originaldata-pull/raw-ncvs-data/2014.csv` … `2022.csv`
- **Years:** 2014–2022 (inclusive)

### 1.2 Codebooks / PDFs used for decoding
Stored in `docs/bjs/`:
- `docs/bjs/gvf_users_guide.pdf`
- `docs/bjs/ncvs_variance_user_guide_11.06.14.pdf`
- `docs/bjs/NCVS_Select_person_level_codebook.pdf`

**TODO:** Identify which PDF explicitly defines each variable code used (e.g., `V4529`, `V4234`, etc.).

---

## 2) Raw → coded conversion (harmonization across years)
### 2.1 Notebook responsible
- **Code:** `originaldata-pull/ncvs-data-coding.Rmd`
- **Rendered output (for inspection):** `originaldata-pull/ncvs-data-coding.html`

### 2.2 Variables pulled from raw per-year files (exact NCVS column header codes)
In `originaldata-pull/ncvs-data-coding.Rmd`:

**Offender/incident structure:**
- `V4234` → one_or_more_offenders (used to classify solo vs group)
- `V4236` → gender
- `V4237` → age_solo
- `V4251` → youngest_multiple
- `V4252` → oldest_multiple

**Others present / sociality proxies:**
- `V4184` → others_present
- `V4185` → others_help
- `V4194` → others_harm

**Crime type:**
- `V4529` → crimetype (mapped to a detailed crime label, then collapsed)

**Weights:**
- `V4527` → incident_weight (preferred)
- fallback: `SERIES_IWEIGHT`

**Replicate weights (BRR; 160 columns):**
- Prefix detected among: `VICREPWGT`, `SERIESVICREPWGT`, `SERIESINCREPWGT`, `SRWGT`
- Standardized output columns: `VICREPWGT1` … `VICREPWGT160`

### 2.3 Harmonization strategy across years
- Helper `get_var(df, varname)` returns the column if present, else an all-NA vector of length `nrow(df)`.
- **Important nuance:** `bind_rows(all_data)` can drop columns that are *all NA* across all years. In this repo we treat that as acceptable in some contexts, but it can break downstream code. (We have a portability fix in the recode section; see below.)

### 2.4 Output artifacts created by this step
- `originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv`
- `originaldata-pull/coded_data/ncvs-merged-data-2014-2022.csv`
- Convenience copies at repo root:
  - `ncvs-merged-data-2014-2022.csv`
  - `theft-ncvs-merged-data-2014-2022.csv`
  - `violent-ncvs-merged-data-2014-2022.csv`

---

## 3) Methodological construct definitions (and where they are implemented)
This is the heart of the APA Methods mapping.

### 3.1 Solo vs group crime
**What (definition):**
- Solo vs group based on `V4234`.

**Code:** `originaldata-pull/ncvs-data-coding.Rmd`
- Derived: `solo_group_crime = case_when(V4234==1 ~ 'solo', V4234==2 ~ 'group', else NA)`

**Outputs:** lives in the coded dataset.

### 3.2 Social vs alone vs observed ("people present but not helping")
**What (definition):**
- A crime is categorized based on:
  - group offender status
  - presence of others
  - whether others help the victim

**Code:** `originaldata-pull/ncvs-data-coding.Rmd`
- Creates `social_crime` with levels:
  - `group`
  - `observed`
  - `alone`
- Then collapses into `Social2`:
  - `social` vs `alone`

**NCVS columns involved:** `V4234`, `V4184`, `V4185` (and potentially `V4194`).

**TODO:** Confirm exact logical conditions (and whether `others_harm` is used anywhere downstream).

### 3.3 Age-group assignment rules (solo vs multiple offenders; youngest/oldest)
**What (definition):**
- Age is categorical (brackets). For group crimes, both youngest and oldest offender categories are used.
- Nuance noted by Danny: if only one of youngest/oldest is present, copy it into the other for consistency.

**Code:** `originaldata-pull/ncvs-data-coding.Rmd`
- Recode mapping for:
  - `age_solo` (from `V4237`)
  - `youngest_multiple` (from `V4251`)
  - `oldest_multiple` (from `V4252`)
- “Fill missing youngest/oldest” logic block.

**TODO:** Document exactly how incidents are attributed “to both” youngest+oldest for co-offending scoring in the downstream scoring notebooks (likely `ncvs_coofensecombined_scoring.Rmd`).

### 3.4 Crime-type classification (all vs theft vs violent)
**What (definition):**
- `V4529` is mapped to a detailed label (`crimetypespecific`), then collapsed into:
  - `Property Crime` (used as theft/property subset)
  - `Nonfatal Personal Crimes` (used as violent subset)

**Code:** `originaldata-pull/ncvs-data-coding.Rmd`
- `crime_map` lookup table
- `property_crimes` and `nonfatal_personal_crimes` label lists

**TODO:** Tie these definitions to the BJS documentation PDFs.

---

## 4) Weighting + variance estimation
**TODO:** Locate the exact code where survey design objects are built (likely in the weighted scoring notebooks) and document:
- weight variable used
- replicate weights usage
- BRR variance estimator settings

---

## 5) Analysis pipeline entrypoints (where the actual manuscript results are generated)

### 5.1 Main scoring notebooks (weighted; manuscript-facing)
Weighted TOTAL / THEFT / VIOLENT (parallel methods; different crime-type filters):
- `total/weighted/weighted-ncvs_coofensecombined_scoring.Rmd`
- `total/weighted/theft-weighted-ncvs_coofensecombined_scoring.Rmd`
- `total/weighted/violent-weighted-ncvs_coofensecombined_scoring.Rmd`

**What they do (high-level):**
- Weighted descriptives by age group
- Rao–Scott chi-square omnibus + pairwise (Bonferroni)
- Weighted logistic regression (Fay’s BRR design; centered at 15–17 and 18–20)

**Key output directories (docx/csv):**
- TOTAL: `total/weighted/R_Tables/`
- THEFT: `total/weighted/Theft_R_Tables/`
- VIOLENT: `total/weighted/Violent_R_Tables/`

### 5.2 Backup analysis notebook (weighted; “co-offending only = social”)
TOTAL-only backup pipeline matching prior literature’s “co-offending only” framing:
- `total/weighted/weighted-ncvs_cooffendingonly_scoring.Rmd`

**Outputs:** `total/weighted/R_Tables_backup/`

### 5.3 Supplemental robustness check (unweighted; no weights anywhere)
To show the same general patterns hold without weighting, we run an unweighted version of the full analysis suite for 4 scopes:
- total_main (alone/group/observed)
- theft_main
- violent_main
- total_backup_cooffending_only

**Runner script (single entrypoint):**
- `supplemental/unweighted_run_all.R`

**Outputs:** `supplemental/unweighted_outputs/<scope>/`
- `*_SUPPLEMENT_unweighted.docx` (one bundled docx per scope)
- CSV exports for descriptives, chi-square, and logit tables

### 5.4 Unweighted notebooks (legacy / reference)
- `total/unweighted/ncvs_coofensecombined_scoring.Rmd`
- `total/unweighted/theft-violence-oldversions/theft-ncvs_coofensecombined_scoring.Rmd`
- `total/unweighted/theft-violence-oldversions/violent-ncvs_coofensecombined_scoring.Rmd`

**TODO (next pass):** For each analysis entrypoint above, add:
- Inputs read (exact filenames)
- Derived variables created
- Statistical model/tests used
- Outputs written (docx/csv) and where they are consumed in the Word writeups

---

## 6) Output artifacts → manuscript tables
### 6.1 Where “final tables” live
- Word docs: `NCVS-Analyses-weighted.docx`, `NCVS-Analyses-unweighted.docx`
- Intermediate R outputs: `*_R_Tables/` directories (docx + csv)

**TODO:** For each manuscript table/figure:
- Which R output file it comes from
- Which code chunk generated it

---

## 7) File-structure map (pipeline)
### 7.1 Raw → coded
`originaldata-pull/raw-ncvs-data/YYYY.csv`
→ `originaldata-pull/ncvs-data-coding.Rmd`
→ `originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv`
→ `originaldata-pull/coded_data/ncvs-merged-data-2014-2022.csv`
→ (copies) `ncvs-merged-data-2014-2022.csv`, `theft-...`, `violent-...`

### 7.2 Coded → analysis → tables
**TODO:** Fill after auditing scoring notebooks.

---

## 8) Reproducibility notes (Saer)
- R installed on Saer (`R 4.5.2`) and required packages installed.
- Pandoc installed for rmarkdown.

**Portability fixes applied to `originaldata-pull/ncvs-data-coding.Rmd`:**
- Correct path assembly for yearly raw CSVs (use `file.path(input_dir, paste0(yr, '.csv'))`).
- Replace hard-coded `~/Desktop/...` output paths with project-relative paths.
- Guard recode operations against columns being absent.

**TODO:** Commit these fixes on a dedicated branch and open a PR (so Battle Station and others can reproduce cleanly).

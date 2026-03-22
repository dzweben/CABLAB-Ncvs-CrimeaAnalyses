# Age-Graded Patterns in Social Offending: Evidence from the NCVS, 1993-2024

This repository contains the complete analysis pipeline for examining age-graded patterns in social (peer-involved) offending using 31 years of the National Crime Victimization Survey (1993-2024, excluding 2006).

## Overview

The project examines two questions:

1. **Analysis 1 — Social Offending:** How does the rate of peer-involved crime vary across age groups? We compute survey-weighted descriptive statistics, Rao-Scott chi-square tests, and logistic regression models across total, violent, theft, and co-offending specifications.

2. **Analysis 2 — Risk-Taking Moderation:** Does social context (peers vs. alone) amplify risk-taking differently for adolescents vs. adults? We test this via survey-weighted OLS with age x social context interaction terms on a composite risk score derived from six behavioral indicators.

## Data Access

All analyses use the **NCVS Concatenated File, Legacy Version, 1992-2024** (ICPSR Study 39273). See [`data/README.md`](data/README.md) for instructions on obtaining and placing the data.

## Requirements

**Python 3.9+**
- pandas, numpy, matplotlib

**R 4.x**
- survey, dplyr, broom, flextable, officer

## Pipeline

Run the full pipeline with:

```bash
./run_all.sh
```

Or run scripts individually in order. All scripts assume the working directory is the repository root.

### Phase 1: Data Preparation

| Script | Description |
|--------|-------------|
| `scripts/01_build_merged_data.py` | Reads the ICPSR concatenated incident file. Applies exclusion criteria (1992 redesign overlap, 2006 anomalous year, series victimizations). Harmonizes offender age brackets, social context classifications, and survey design elements (pseudostratum, half-sample codes, year groups for TSL). Produces three analysis-ready CSVs: total, violent-only, and theft-only. |
| `scripts/02_build_risk_data.py` | Same source data. Extracts routing-aware risk indicators for violent contact crimes: weapon presence, attack, injury, public location, outdoors, and substance use. Handles NCVS skip-logic (e.g., injury is only asked when attack occurred). Computes composite RISK_SCORE as the mean of six binary indicators (0-1 scale). |

### Phase 2: Statistical Analysis

| Script | Description |
|--------|-------------|
| `scripts/03_weighted_analysis.R` | Core Analysis 1. Applies Taylor Series Linearization (TSL) with the NCVS pseudostratum and half-sample code as design elements. For each of four crime scopes (total, violent, theft, co-offending), computes: survey-weighted proportions by age group, Rao-Scott F-adjusted chi-square omnibus tests, and logistic regression predicting solo offending (reference = ages 15-17). Outputs intermediate .docx tables to `outputs/tables/`. |
| `scripts/04_pairwise_comparisons.R` | Extracts all 15 Bonferroni-corrected pairwise age-group comparisons (odds ratios with 95% CIs) for supplement tables. |
| `scripts/05_temporal_stability.R` | Tests whether the age-graded social offending pattern is stable across the 31-year study period by estimating age x centered-year interactions. Reports per-year interaction ORs and a joint Wald test. |
| `scripts/06_risk_moderation.R` | Analysis 2. Regresses composite risk score on age group, social context, and their interaction using survey-weighted OLS. Reports: F-change test for moderation, interaction coefficients (each age's social boost relative to ages 15-17), and simple effects of age among solo offenders. Also tests era stability (age x social x era three-way interaction). |
| `scripts/07_risk_unweighted.R` | Replicates Analysis 2 without survey weights (unweighted OLS) as a robustness check for the supplement. |
| `scripts/08_unweighted_robustness.R` | Replicates the full Analysis 1 pipeline without survey weights (simple chi-square and unweighted logistic regression) for the supplement. |

### Phase 3: Figures

| Script | Description |
|--------|-------------|
| `scripts/09_figure1_stacked_bars.py` | **Figure 1.** 2x2 panel of stacked bar charts showing social vs. solo offending proportions by age group across total, violent, theft, and co-offending. |
| `scripts/10_figure2_forest_plot.py` | **Figure 2.** 2x2 panel of forest plots showing logistic regression ORs for solo offending (reference = ages 15-17) with 95% CIs. |
| `scripts/11_figure3_pairwise_heatmaps.py` | **Figure 3.** 2x2 panel of lower-triangular heatmaps showing Bonferroni-adjusted pairwise ORs across all age-group pairs. |
| `scripts/12_figure4_era_stability.py` | **Figure 4.** Three-panel bar chart showing social offending rates by age group across three study eras (1993-2003, 2004-2014, 2015-2024). |
| `scripts/13_figure5_risk_moderation.py` | **Figure 5.** Two-line simple slopes plot showing mean composite risk scores for social vs. solo offending across age groups, with the social risk boost annotated at each age. |

### Note on Figure Data

The figure scripts (09-12) contain statistics hardcoded from verified R output (scripts 03-08). The R scripts serve as the reproducibility audit trail. If data or methods change, rerun the R scripts first, then update the hardcoded values in the figure scripts to match.

## Outputs

| Path | Contents |
|------|----------|
| `outputs/figures/` | Figures 1-5 in PDF, PNG, and TIFF |
| `outputs/tables/` | Intermediate R analysis tables (.docx) from script 03 |
| `outputs/supplement/` | Unweighted robustness tables from script 08 |

## Repository Structure

```
ncvs/
├── README.md                  This file
├── run_all.sh                 Master pipeline script
├── scripts/                   13 numbered analysis and figure scripts
├── data/
│   ├── raw/                   ICPSR source data (gitignored)
│   └── derived/               Analysis-ready CSVs (gitignored)
├── outputs/
│   ├── figures/               Figures 1-5 (PDF, PNG, TIFF)
│   ├── tables/                Intermediate R analysis tables
│   └── supplement/            Unweighted robustness tables
├── docs/                      Variable specifications and BJS reference documents
└── archive/                   Legacy scripts and earlier analysis versions (gitignored)
```

## License

CC-BY-4.0

#!/usr/bin/env bash
# ===========================================================================
# run_all.sh — Reproduce all analyses and outputs from scratch
#
# Prerequisites:
#   - ICPSR 39273 DS0003 TSV at data/raw/ICPSR_39273/DS0003/39273-0003-Data.tsv
#   - Python 3.9+ with: pandas, python-docx, matplotlib, numpy
#   - R 4.x with: survey, dplyr, broom, flextable, officer
#
# Run from the repository root directory.
# ===========================================================================
set -euo pipefail

echo "============================================"
echo "NCVS Social Offending Analysis Pipeline"
echo "============================================"
echo ""

echo "=== Phase 1: Data Preparation ==="
echo "[01] Building merged analysis dataset..."
python3 scripts/01_build_merged_data.py

echo "[02] Building risk analysis dataset..."
python3 scripts/02_build_risk_data.py

echo ""
echo "=== Phase 2: Statistical Analysis ==="
echo "[03] Weighted analysis (Total, Violent, Theft, Co-offending)..."
Rscript scripts/03_weighted_analysis.R

echo "[04] Pairwise age-group comparisons..."
Rscript scripts/04_pairwise_comparisons.R

echo "[05] Temporal stability test..."
Rscript scripts/05_temporal_stability.R

echo "[06] Risk moderation (Analysis 2, weighted)..."
Rscript scripts/06_risk_moderation.R

echo "[07] Risk moderation (unweighted sensitivity)..."
Rscript scripts/07_risk_unweighted.R

echo "[08] Unweighted robustness checks (supplement)..."
Rscript scripts/08_unweighted_robustness.R

echo ""
echo "=== Phase 3: Figures ==="
echo "[09] Figure 1: Social offending rates..."
python3 scripts/09_figure1_stacked_bars.py

echo "[10] Figure 2: Odds ratio forest plot..."
python3 scripts/10_figure2_forest_plot.py

echo "[11] Figure 3: Pairwise comparison heatmaps..."
python3 scripts/11_figure3_pairwise_heatmaps.py

echo "[12] Figure 4: Era stability..."
python3 scripts/12_figure4_era_stability.py

echo "[13] Figure 5: Risk-taking moderation..."
python3 scripts/13_figure5_risk_moderation.py

echo ""
echo "============================================"
echo "Pipeline complete."
echo "Figures: outputs/figures/"
echo "============================================"

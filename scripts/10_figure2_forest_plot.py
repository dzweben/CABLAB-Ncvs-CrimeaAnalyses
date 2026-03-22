#!/usr/bin/env python3
# ===========================================================================
# 10 — Figure 2: Logistic Regression Odds Ratios (Forest Plot)
#
# Generates a 2x2 panel of forest plots showing odds ratios for solo
# offending by age group (reference = ages 15-17).
#
# Input:  Hardcoded data (verified against script 03 output)
# Output: outputs/figures/Figure2.{png,pdf,tiff}
#
# Supports: Results — Logistic Regression (all scopes)
# ===========================================================================
"""
Generate Figure 2: Forest plots of survey-weighted logistic regression ORs.
Updated for 1993-2024 TSL analysis.

2x2 layout:
  A. Total Offenses          B. Violent Offenses
  C. Theft Offenses          D. Co-offending - Total

Reference category = ages 15-17 in all panels.
All panels: 5 age groups (Under 12, 12-14, 18-20, 21-29, 30+).
Significance stars placed to the right of CI upper endpoints.
Single shared x-axis label at the bottom of the figure.

Output: Figure2.png, Figure2.pdf, Figure2.tiff
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import os

# -- Data (ref = 15-17, verified from R output, 1993-2024 TSL) ------------
AGE_5 = ["Under 12", "12\u201314", "18\u201320", "21\u201329", "30+"]

# p-values from logistic regression (unadjusted, from R output)
# Stars:  * p < .05   ** p < .01   *** p < .001
DATA_5 = {
    "A. Total Offenses": {
        "OR": [1.54, 1.09, 1.22, 2.15, 3.07],
        "lo": [1.35, 1.01, 1.15, 2.04, 2.88],
        "hi": [1.75, 1.18, 1.31, 2.28, 3.27],
        "p":  [0.0001, 0.034, 0.0001, 0.0000, 0.0000],
        "color": "#333333",
    },
    "B. Violent Offenses": {
        "OR": [1.56, 1.11, 1.22, 2.36, 3.33],
        "lo": [1.29, 1.01, 1.13, 2.21, 3.11],
        "hi": [1.90, 1.21, 1.32, 2.53, 3.56],
        "p":  [0.0001, 0.028, 0.0001, 0.0000, 0.0000],
        "color": "#B03030",
    },
    "C. Theft Offenses": {
        "OR": [1.38, 1.05, 1.24, 1.60, 2.31],
        "lo": [1.15, 0.91, 1.08, 1.43, 2.03],
        "hi": [1.66, 1.21, 1.42, 1.78, 2.63],
        "p":  [0.001, 0.508, 0.003, 0.0000, 0.0000],
        "color": "#2C6E91",
    },
}

DATA_COOFF = {
    "OR": [1.22, 1.43, 0.92, 2.07, 4.67],
    "lo": [1.06, 1.33, 0.86, 1.94, 4.34],
    "hi": [1.40, 1.55, 0.99, 2.20, 5.03],
    "p":  [0.006, 0.0001, 0.026, 0.0000, 0.0000],
    "color": "#6B3FA0",
}


def _stars(p):
    """Return significance stars from a p-value."""
    if p < .001:
        return "***"
    if p < .01:
        return "**"
    if p < .05:
        return "*"
    return ""


# -- Build figure ----------------------------------------------------------
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

# -- Panels A-C (5 age groups) ---------------------------------------------
panel_positions = [(0, 0), (0, 1), (1, 0)]

for (r, c), (title, d) in zip(panel_positions, DATA_5.items()):
    ax = axes[r, c]
    y = np.arange(len(AGE_5))
    ors, lo, hi, pvals, color = d["OR"], d["lo"], d["hi"], d["p"], d["color"]

    xerr_lo = [o - l for o, l in zip(ors, lo)]
    xerr_hi = [h - o for o, h in zip(ors, hi)]

    ax.errorbar(ors, y, xerr=[xerr_lo, xerr_hi], fmt="D",
                color=color, markersize=8, capsize=5, capthick=1.5,
                elinewidth=1.5, markeredgecolor="white",
                markeredgewidth=0.6)
    ax.axvline(x=1, color="gray", linestyle="--", linewidth=0.8, alpha=0.6)

    # Significance stars
    for i, (h_val, p_val) in enumerate(zip(hi, pvals)):
        s = _stars(p_val)
        if s:
            ax.text(h_val + 0.06, i, s, va="center", ha="left",
                    fontsize=9, fontfamily="serif", fontweight="bold",
                    color=color)

    ax.set_yticks(y)
    ax.set_yticklabels(AGE_5, fontsize=11, fontfamily="serif")
    ax.set_title(title, fontsize=13, fontweight="bold",
                 fontfamily="serif", loc="left", pad=10)
    ax.tick_params(axis="x", labelsize=10)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.invert_yaxis()

    # Generous x limits (extra space for stars)
    ax.set_xlim(0.4, max(hi) + 0.7)

# -- Panel D (5 age groups, co-offending) -----------------------------------
ax_d = axes[1, 1]
y_d = np.arange(len(AGE_5))
ors_d, lo_d, hi_d = DATA_COOFF["OR"], DATA_COOFF["lo"], DATA_COOFF["hi"]
pvals_d = DATA_COOFF["p"]
color_d = DATA_COOFF["color"]

xerr_lo_d = [o - l for o, l in zip(ors_d, lo_d)]
xerr_hi_d = [h - o for o, h in zip(ors_d, hi_d)]

ax_d.errorbar(ors_d, y_d, xerr=[xerr_lo_d, xerr_hi_d], fmt="D",
              color=color_d, markersize=8, capsize=5, capthick=1.5,
              elinewidth=1.5, markeredgecolor="white",
              markeredgewidth=0.6)
ax_d.axvline(x=1, color="gray", linestyle="--", linewidth=0.8, alpha=0.6)

# Significance stars
for i, (h_val, p_val) in enumerate(zip(hi_d, pvals_d)):
    s = _stars(p_val)
    if s:
        ax_d.text(h_val + 0.06, i, s, va="center", ha="left",
                  fontsize=9, fontfamily="serif", fontweight="bold",
                  color=color_d)

ax_d.set_yticks(y_d)
ax_d.set_yticklabels(AGE_5, fontsize=11, fontfamily="serif")
ax_d.set_title("D. Co-offending \u2013 Total", fontsize=13,
               fontweight="bold", fontfamily="serif", loc="left", pad=10)
ax_d.tick_params(axis="x", labelsize=10)
ax_d.spines["top"].set_visible(False)
ax_d.spines["right"].set_visible(False)
ax_d.invert_yaxis()
ax_d.set_xlim(0.4, max(hi_d) + 1.0)

# -- Shared x-axis label ---------------------------------------------------
fig.text(0.5, 0.02,
         "Odds Ratio (Reference: Ages 15\u201317)\n"
         "* p < .05   ** p < .01   *** p < .001",
         ha="center", va="bottom", fontsize=11, fontfamily="serif",
         style="italic")

plt.tight_layout(rect=[0, 0.07, 1, 1], h_pad=3.5, w_pad=3.0)

# -- Save ------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
out_dir = os.path.join(PROJECT_ROOT, "outputs", "figures")
os.makedirs(out_dir, exist_ok=True)
for fmt in ("png", "pdf", "tiff"):
    path = os.path.join(out_dir, f"Figure2.{fmt}")
    fig.savefig(path, dpi=600, bbox_inches="tight", facecolor="white")
    print(f"Saved: {path}")

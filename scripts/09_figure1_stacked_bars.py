#!/usr/bin/env python3
# ===========================================================================
# 09 — Figure 1: Social Offending Rates by Age Group
#
# Generates a 2x2 panel of stacked bar charts showing the proportion of
# social vs. solo offending across age groups for Total, Violent, Theft,
# and Co-offending.
#
# Input:  Hardcoded data (verified against script 03 output)
# Output: outputs/figures/Figure1.{png,pdf,tiff}
#
# Supports: Results — Descriptive Statistics (all scopes)
# ===========================================================================
"""
Generate Figure 1: Stacked bar charts of offending context by age group.
Updated for 1993-2024 TSL analysis.

2x2 layout:
  A. Total Offenses          B. Violent Offenses
  C. Theft Offenses          D. Co-offending - Total

Panels A-C: 3-category stack (co-offense, observed, solo).
Panel D: 2-category stack (co-offense vs. not co-offense).

Social categories are stacked on the BOTTOM so that the coloured-area
height equals the social-offending (or co-offending) percentage.
Overlaid trend line with dots at the social % boundary.

Output: Figure1.png, Figure1.pdf, Figure1.tiff
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import os

# -- Data (verified against R output, 1993-2024 TSL) ----------------------

AGE = ["Under 12", "12\u201314", "15\u201317", "18\u201320", "21\u201329", "30+"]

TOTAL = {
    "cooff": [34.0, 30.5, 38.6, 40.5, 23.3, 11.8],
    "obs":   [23.6, 35.3, 29.1, 22.6, 26.0, 28.7],
    "solo":  [42.4, 34.3, 32.4, 36.9, 50.8, 59.5],
}
VIOLENT = {
    "cooff": [34.1, 31.1, 40.1, 42.7, 23.2, 10.6],
    "obs":   [24.6, 35.6, 28.9, 21.8, 25.2, 29.4],
    "solo":  [41.3, 33.3, 31.0, 35.4, 51.5, 60.0],
}
THEFT = {
    "cooff": [33.8, 28.2, 33.5, 33.2, 23.5, 17.1],
    "obs":   [21.8, 33.9, 29.8, 25.0, 28.5, 25.6],
    "solo":  [44.4, 37.8, 36.7, 41.8, 48.1, 57.2],
}
# Co-offending: co-offense vs. everything else (solo + observed)
COOFF_TOTAL = {
    "cooff":    [34.0, 30.5, 38.6, 40.5, 23.3, 11.8],
    "not_cooff": [66.0, 69.5, 61.4, 59.5, 76.7, 88.2],
}

# -- Colours ---------------------------------------------------------------
C_COOFF = "#2C6E91"   # Dark teal-blue  (co-offense)
C_OBS   = "#6DAECC"   # Light blue      (observed)
C_SOLO  = "#C8C8C8"   # Light grey      (solo)
C_NOT   = "#D5D5D5"   # Slightly diff grey (not co-offense)

# -- Build figure ----------------------------------------------------------
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

x = np.arange(len(AGE))
W = 0.60

# -- Panels A-C (3-category) -----------------------------------------------
panels_3cat = [
    (axes[0, 0], "A. Total Offenses",   TOTAL),
    (axes[0, 1], "B. Violent Offenses",  VIOLENT),
    (axes[1, 0], "C. Theft Offenses",    THEFT),
]

for ax, title, d in panels_3cat:
    cooff = np.array(d["cooff"])
    obs   = np.array(d["obs"])
    solo  = np.array(d["solo"])
    bottom_obs  = cooff
    bottom_solo = cooff + obs

    ax.bar(x, cooff, W, color=C_COOFF, edgecolor="white", linewidth=0.5,
           label="Co-offense")
    ax.bar(x, obs, W, bottom=bottom_obs, color=C_OBS, edgecolor="white",
           linewidth=0.5, label="Observed")
    ax.bar(x, solo, W, bottom=bottom_solo, color=C_SOLO, edgecolor="white",
           linewidth=0.5, label="Solo")

    # Trend line: social offending % = co-offense + observed
    social_pct = cooff + obs
    ax.plot(x, social_pct, marker="o", color="#1a1a1a", linewidth=1.8,
            markersize=7, markerfacecolor="#1a1a1a", markeredgecolor="white",
            markeredgewidth=1.2, zorder=5)

    ax.set_title(title, fontsize=14, fontweight="bold",
                 fontfamily="serif", pad=10)
    ax.set_xticks(x)
    ax.set_xticklabels(AGE, fontsize=10, fontfamily="serif",
                       rotation=30, ha="right")
    ax.set_ylim(0, 105)
    ax.set_yticks([0, 20, 40, 60, 80, 100])
    ax.yaxis.set_major_formatter(
        plt.FuncFormatter(lambda v, _: f"{v:.0f}%"))
    ax.tick_params(axis="y", labelsize=10)
    ax.set_ylabel("Percentage of Incidents", fontsize=11, fontfamily="serif")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.yaxis.grid(True, linestyle=":", linewidth=0.5, alpha=0.5, color="#999999")
    ax.set_axisbelow(True)

# -- Panel D (2-category: co-offense vs. not) ------------------------------
ax_d = axes[1, 1]
cooff_d = np.array(COOFF_TOTAL["cooff"])
not_d   = np.array(COOFF_TOTAL["not_cooff"])

ax_d.bar(x, cooff_d, W, color=C_COOFF, edgecolor="white", linewidth=0.5,
         label="Co-offense")
ax_d.bar(x, not_d, W, bottom=cooff_d, color=C_NOT, edgecolor="white",
         linewidth=0.5, label="Not co-offense")

# Trend line: co-offending %
ax_d.plot(x, cooff_d, marker="o", color="#1a1a1a", linewidth=1.8,
          markersize=7, markerfacecolor="#1a1a1a", markeredgecolor="white",
          markeredgewidth=1.2, zorder=5)

ax_d.set_title("D. Co-offending \u2013 Total Offenses", fontsize=14,
               fontweight="bold", fontfamily="serif", pad=10)
ax_d.set_xticks(x)
ax_d.set_xticklabels(AGE, fontsize=10, fontfamily="serif",
                     rotation=30, ha="right")
ax_d.set_ylim(0, 105)
ax_d.set_yticks([0, 20, 40, 60, 80, 100])
ax_d.yaxis.set_major_formatter(
    plt.FuncFormatter(lambda v, _: f"{v:.0f}%"))
ax_d.tick_params(axis="y", labelsize=10)
ax_d.set_ylabel("Percentage of Incidents", fontsize=11, fontfamily="serif")
ax_d.spines["top"].set_visible(False)
ax_d.spines["right"].set_visible(False)
ax_d.yaxis.grid(True, linestyle=":", linewidth=0.5, alpha=0.5, color="#999999")
ax_d.set_axisbelow(True)

# -- Legend ----------------------------------------------------------------
from matplotlib.patches import Patch
from matplotlib.lines import Line2D
legend_handles = [
    Patch(facecolor=C_COOFF, edgecolor="white", label="Co-offense"),
    Patch(facecolor=C_OBS,   edgecolor="white", label="Observed"),
    Patch(facecolor=C_SOLO,  edgecolor="white", label="Solo"),
    Patch(facecolor=C_NOT,   edgecolor="white", label="Not co-offense (Panel D)"),
    Line2D([0], [0], color="#1a1a1a", marker="o", markersize=7,
           markerfacecolor="#1a1a1a", markeredgecolor="white",
           markeredgewidth=1.2, linewidth=1.8,
           label="Social / Co-offending %"),
]
fig.legend(
    handles=legend_handles,
    loc="lower center",
    ncol=5,
    fontsize=11,
    frameon=True,
    edgecolor="black",
    fancybox=False,
    borderpad=0.6,
    handlelength=2.0,
    handletextpad=0.6,
    columnspacing=2.0,
    bbox_to_anchor=(0.5, -0.005),
    prop={"family": "serif", "size": 12},
)

plt.tight_layout(rect=[0, 0.06, 1, 1], h_pad=3.0, w_pad=2.0)

# -- Save -----------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
out_dir = os.path.join(PROJECT_ROOT, "outputs", "figures")
os.makedirs(out_dir, exist_ok=True)
for fmt in ("png", "pdf", "tiff"):
    path = os.path.join(out_dir, f"Figure1.{fmt}")
    fig.savefig(path, dpi=600, bbox_inches="tight", facecolor="white")
    print(f"Saved: {path}")

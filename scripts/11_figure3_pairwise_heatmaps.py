#!/usr/bin/env python3
# ===========================================================================
# 11 — Figure 3: Pairwise Comparison Heatmaps
#
# Generates a 2x2 panel of lower-triangular heatmaps showing
# Bonferroni-adjusted pairwise odds ratios across age groups.
#
# Input:  Hardcoded data (verified against script 04 output)
# Output: outputs/figures/Figure3.{png,pdf,tiff}
#
# Supports: Results — Omnibus and Pairwise Comparisons
# ===========================================================================
"""
Generate Figure 3: Bonferroni-adjusted pairwise comparison heatmaps.
Updated for 1993-2024 TSL analysis.

2x2 layout:
  A. Total Offenses          B. Violent Offenses
  C. Theft Offenses          D. Co-offending - Total

Lower-triangular dissimilarity matrix showing odds ratios from pairwise
survey-weighted logistic regression across six age groups.

Colour scale (diverging, centred at OR = 1):
  Blue  <-  OR < 1 (row group is MORE social / more co-offending)
  White    OR = 1 (no difference)
  Red   ->  OR > 1 (row group is MORE solo / less co-offending)

Cell text: OR with significance stars
  *** Bonferroni-adjusted p < .001
  **  Bonferroni-adjusted p < .01
  *   Bonferroni-adjusted p < .05

Output: Figure3.png, Figure3.pdf, Figure3.tiff
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np
import os

# -- Age groups ------------------------------------------------------------
AGE = ["Under 12", "12\u201314", "15\u201317", "18\u201320", "21\u201329", "30+"]
N = len(AGE)

# -- Pairwise data: (OR, adjusted_p_str) ----------------------------------
# 15 pairs per scope, order: (0,1) (0,2) ... (0,5) (1,2) ... (4,5)

DATA = {
    "A. Total Offenses": [
        (0.71, "< .001"), (0.65, "< .001"), (0.80, ".012"),
        (1.40, "< .001"), (1.99, "< .001"),
        (0.92, ".509"),   (1.12, ".073"),   (1.98, "< .001"),
        (2.81, "< .001"),
        (1.22, "< .001"), (2.15, "< .001"), (3.07, "< .001"),
        (1.76, "< .001"), (2.50, "< .001"),
        (1.42, "< .001"),
    ],
    "B. Violent Offenses": [
        (0.71, ".011"),   (0.64, "< .001"), (0.78, ".157"),
        (1.51, "< .001"), (2.13, "< .001"),
        (0.90, ".423"),   (1.10, ".678"),   (2.13, "< .001"),
        (3.01, "< .001"),
        (1.22, "< .001"), (2.36, "< .001"), (3.33, "< .001"),
        (1.94, "< .001"), (2.73, "< .001"),
        (1.41, "< .001"),
    ],
    "C. Theft Offenses": [
        (0.76, ".054"),   (0.73, ".010"),   (0.90, "1.000"),
        (1.16, "1.000"),  (1.68, "< .001"),
        (0.95, "1.000"),  (1.18, ".168"),   (1.52, "< .001"),
        (2.20, "< .001"),
        (1.24, ".044"),   (1.60, "< .001"), (2.31, "< .001"),
        (1.29, "< .001"), (1.87, "< .001"),
        (1.45, "< .001"),
    ],
    "D. Co-offending \u2013 Total": [
        (1.18, ".535"),   (0.82, ".093"),   (0.76, ".002"),
        (1.70, "< .001"), (3.84, "< .001"),
        (0.70, "< .001"), (0.64, "< .001"), (1.44, "< .001"),
        (3.26, "< .001"),
        (0.92, ".395"),   (2.07, "< .001"), (4.67, "< .001"),
        (2.24, "< .001"), (5.06, "< .001"),
        (2.26, "< .001"),
    ],
}

# -- Helpers ---------------------------------------------------------------

def _sig(p_str):
    """Return significance stars from a Bonferroni-adjusted p string."""
    s = p_str.strip()
    if s == "< .001":
        return "***"
    try:
        p = float(s)
    except ValueError:
        return ""
    if p < .001:
        return "***"
    if p < .01:
        return "**"
    if p < .05:
        return "*"
    return ""


def _build_matrices(pairs):
    """Return (or_matrix, sig_matrix) from a list of 15 (OR, p_str) tuples."""
    or_m = np.full((N, N), np.nan)
    sig_m = np.empty((N, N), dtype=object)
    sig_m[:] = ""
    idx = 0
    for i in range(N):
        for j in range(i + 1, N):
            or_val, p_str = pairs[idx]
            or_m[j, i] = or_val
            sig_m[j, i] = _sig(p_str)
            idx += 1
    return or_m, sig_m


# -- Colour mapping (log scale, centred at OR = 1) -------------------------
LOG_MIN, LOG_CTR, LOG_MAX = -0.45, 0.0, 1.65
_norm = mcolors.TwoSlopeNorm(vmin=LOG_MIN, vcenter=LOG_CTR, vmax=LOG_MAX)
_cmap = plt.cm.RdBu_r

# -- Build figure ----------------------------------------------------------
fig, axes = plt.subplots(2, 2, figsize=(15, 13))

panel_pos = [(0, 0), (0, 1), (1, 0), (1, 1)]

for (r, c), (title, pairs) in zip(panel_pos, DATA.items()):
    ax = axes[r, c]
    or_m, sig_m = _build_matrices(pairs)

    ax.set_xlim(-0.5, N - 0.5)
    ax.set_ylim(N - 0.5, -0.5)
    ax.set_aspect("equal")
    ax.tick_params(length=0)

    for i in range(N):
        for j in range(N):
            if i > j:
                # Lower triangle: coloured OR cell
                v = or_m[i, j]
                lv = np.log(v)
                rgba = _cmap(_norm(lv))
                ax.add_patch(plt.Rectangle(
                    (j - 0.5, i - 0.5), 1, 1,
                    facecolor=rgba, edgecolor="white", linewidth=1.4))
                txt = f"{v:.2f}{sig_m[i, j]}"
                # Luminance-based text colour (WCAG contrast)
                r_c, g, b, _ = rgba
                lum = 0.299 * r_c + 0.587 * g + 0.114 * b
                tc = "white" if lum < 0.55 else "black"
                ax.text(j, i, txt, ha="center", va="center",
                        fontsize=9, fontfamily="serif",
                        fontweight="bold", color=tc)
            elif i == j:
                # Diagonal
                ax.add_patch(plt.Rectangle(
                    (j - 0.5, i - 0.5), 1, 1,
                    facecolor="#F0F0F0", edgecolor="white", linewidth=1.4))
                ax.text(j, i, "\u2014", ha="center", va="center",
                        fontsize=11, fontfamily="serif", color="#999999")
            else:
                # Upper triangle: blank
                ax.add_patch(plt.Rectangle(
                    (j - 0.5, i - 0.5), 1, 1,
                    facecolor="white", edgecolor="white", linewidth=1.4))

    ax.set_xticks(range(N))
    ax.set_xticklabels(AGE, fontsize=9.5, fontfamily="serif",
                       rotation=45, ha="right")
    ax.set_yticks(range(N))
    ax.set_yticklabels(AGE, fontsize=9.5, fontfamily="serif")
    ax.set_title(title, fontsize=13, fontweight="bold",
                 fontfamily="serif", pad=12)
    for spine in ax.spines.values():
        spine.set_visible(False)

# -- Layout first, then colour bar ----------------------------------------
fig.subplots_adjust(left=0.08, right=0.88, top=0.95, bottom=0.10,
                    hspace=0.50, wspace=0.30)

# Shared colour bar in the rightmost strip
sm = plt.cm.ScalarMappable(cmap=_cmap, norm=_norm)
sm.set_array([])
cax = fig.add_axes([0.91, 0.25, 0.02, 0.50])          # [left, bottom, w, h]
cbar = fig.colorbar(sm, cax=cax)
tick_ors = [0.70, 0.85, 1.00, 1.50, 2.00, 3.00, 4.00, 5.00]
cbar.set_ticks([np.log(v) for v in tick_ors])
cbar.set_ticklabels([f"{v:.2f}" for v in tick_ors])
cbar.set_label("Odds Ratio", fontsize=12, fontfamily="serif")
cbar.ax.tick_params(labelsize=10)

# -- Significance note -----------------------------------------------------
fig.text(
    0.47, 0.02,
    "* p < .05   ** p < .01   *** p < .001  "
    "(Bonferroni-adjusted across 15 comparisons per panel)",
    ha="center", va="bottom", fontsize=10, fontfamily="serif",
    style="italic",
)

# -- Save ------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
out_dir = os.path.join(PROJECT_ROOT, "outputs", "figures")
os.makedirs(out_dir, exist_ok=True)
for fmt in ("png", "pdf", "tiff"):
    path = os.path.join(out_dir, f"Figure3.{fmt}")
    fig.savefig(path, dpi=600, bbox_inches="tight", facecolor="white")
    print(f"Saved: {path}")

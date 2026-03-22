#!/usr/bin/env python3
# ===========================================================================
# 13 — Figure 5: Risk-Taking Moderation (Two-Line Simple Slopes)
#
# Generates a two-line plot showing mean composite risk scores for social
# vs. solo offending across age groups, with the social risk boost
# annotated at each age. Illustrates the age-graded moderation of peer
# influence on risk-taking in violent crime.
#
# Input:  Hardcoded data (verified against script 06 output)
# Output: outputs/figures/Figure5_Risk_TwoLine.{png,pdf,tiff}
#
# Supports: Results — Analysis 2: Risk-Taking in Violent Crime
# ===========================================================================

import os
import numpy as np
import matplotlib.pyplot as plt

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

# ---------------------------------------------------------------------------
# Hardcoded data (verified against 06_risk_moderation.R output)
# ---------------------------------------------------------------------------

# Weighted means (M, SE, n) by age group and social context
RISK_DESC = {
    "Under 12": {"alone": (.4810, .0094, 425),  "social": (.5263, .0094, 509)},
    "12-14":    {"alone": (.5173, .0054, 1303), "social": (.5668, .0049, 2537)},
    "15-17":    {"alone": (.5174, .0048, 1551), "social": (.5805, .0047, 3387)},
    "18-20":    {"alone": (.5177, .0055, 1757), "social": (.5771, .0052, 2626)},
    "21-29":    {"alone": (.5183, .0033, 5727), "social": (.5532, .0037, 4648)},
    "30+":      {"alone": (.4992, .0027, 9975), "social": (.5057, .0036, 5365)},
}

RISK_GAPS = {
    "Under 12": .0453, "12-14": .0495, "15-17": .0631,
    "18-20": .0594, "21-29": .0348, "30+": .0065
}

RISK_AGE_KEYS = ["Under 12", "12-14", "15-17", "18-20", "21-29", "30+"]
RISK_AGE_LABELS = ["<12", "12\u201314", "15\u201317", "18\u201320", "21\u201329", "30+"]


def main():
    x = np.arange(len(RISK_AGE_LABELS))
    alone_m = [RISK_DESC[k]["alone"][0] for k in RISK_AGE_KEYS]
    alone_se = [RISK_DESC[k]["alone"][1] for k in RISK_AGE_KEYS]
    social_m = [RISK_DESC[k]["social"][0] for k in RISK_AGE_KEYS]
    social_se = [RISK_DESC[k]["social"][1] for k in RISK_AGE_KEYS]

    fig, ax = plt.subplots(figsize=(10, 6))

    ax.errorbar(x, social_m, yerr=[1.96 * s for s in social_se],
                fmt="o-", color="#2C6E91", linewidth=2.5, markersize=9,
                capsize=5, capthick=1.5, markeredgecolor="white",
                markeredgewidth=0.8, label="Social offending", zorder=5)

    ax.errorbar(x, alone_m, yerr=[1.96 * s for s in alone_se],
                fmt="s--", color="#888888", linewidth=2.5, markersize=8,
                capsize=5, capthick=1.5, markeredgecolor="white",
                markeredgewidth=0.8, label="Solo offending", zorder=5)

    ax.fill_between(x, alone_m, social_m, alpha=0.12, color="#2C6E91")

    for i, k in enumerate(RISK_AGE_KEYS):
        gap = RISK_GAPS[k]
        y_top = social_m[i] + 1.96 * social_se[i] + 0.004
        ax.annotate(f"+{gap * 100:.1f}pp",
                    xy=(x[i], y_top), fontsize=9, color="#2C6E91",
                    fontweight="bold", fontfamily="serif",
                    ha="center", va="bottom")

    ax.set_xticks(x)
    ax.set_xticklabels(RISK_AGE_LABELS, fontsize=11, fontfamily="serif")
    ax.set_ylabel("Mean Composite Risk Score", fontsize=12, fontfamily="serif")
    ax.set_xlabel("Offender Age Group", fontsize=12, fontfamily="serif")
    ax.set_ylim(0.44, 0.60)
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.2f}"))
    ax.tick_params(axis="y", labelsize=10)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.yaxis.grid(True, linestyle=":", linewidth=0.5, alpha=0.5, color="#999999")
    ax.set_axisbelow(True)

    ax.legend(loc="upper right", fontsize=11, frameon=True, fancybox=False,
              edgecolor="black", prop={"family": "serif", "size": 11})

    plt.tight_layout()
    fig_dir = os.path.join(PROJECT_ROOT, "outputs", "figures")
    os.makedirs(fig_dir, exist_ok=True)
    for fmt in ("png", "pdf", "tiff"):
        path = os.path.join(fig_dir, f"Figure5_Risk_TwoLine.{fmt}")
        fig.savefig(path, dpi=600, bbox_inches="tight", facecolor="white")
        print(f"Saved: {path}")
    plt.close()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# ===========================================================================
# 12 — Figure 4: Era Stability of Social Offending
#
# Generates a three-panel bar chart showing social offending rates by age
# group across three study eras (1993-2003, 2004-2014, 2015-2024).
#
# Input:  data/derived/ncvs-merged-data-1993-2024.csv
# Output: outputs/figures/Figure4.{png,pdf,tiff}
#
# Supports: Results — Stability Across Survey Years
# ===========================================================================
"""
Generate Figure 4: Stability of the Age-Graded Social Offending Pattern.

Three-panel bar chart showing the survey-weighted social offending rate
for each of six age groups across three study eras (1993-2003, 2004-2014,
2015-2024).  The repeating inverted-U shape demonstrates that the
age-graded pattern is invariant over the study period.

Output: Figure4.png, Figure4.pdf, Figure4.tiff
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd
import os

# ---------------------------------------------------------------------------
# Compute era-by-era weighted social offending rates
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
CSV = os.path.join(PROJECT_ROOT, "data", "derived", "ncvs-merged-data-1993-2024.csv")

df = pd.read_csv(CSV, low_memory=False)

# --- Normalize age labels ---
def normalize_age(s):
    if pd.isna(s) or s == "":
        return None
    s = str(s).strip()
    if "Under" in s or "under" in s:
        return "under_12"
    if s.startswith("12"):
        return "12-14"
    if s.startswith("15"):
        return "15-17"
    if s.startswith("18"):
        return "18-20"
    if s.startswith("21"):
        return "21-29"
    if s.startswith("30"):
        return "30+"
    return s

df["age_solo"] = df["age_solo"].apply(normalize_age)
df["youngest_multiple"] = df["youngest_multiple"].apply(normalize_age)
df["oldest_multiple"] = df["oldest_multiple"].apply(normalize_age)

age_levels = ["under_12", "12-14", "15-17", "18-20", "21-29", "30+"]

# Fix youngest/oldest consistency
mask_only_oldest = df["youngest_multiple"].isna() & df["oldest_multiple"].isin(age_levels)
mask_only_youngest = df["oldest_multiple"].isna() & df["youngest_multiple"].isin(age_levels)
df.loc[mask_only_oldest, "youngest_multiple"] = df.loc[mask_only_oldest, "oldest_multiple"]
df.loc[mask_only_youngest, "oldest_multiple"] = df.loc[mask_only_youngest, "youngest_multiple"]

# --- Expand co-offense rows ---
solo = df[df["age_solo"].isin(age_levels)].copy()
solo["age"] = solo["age_solo"]

same_age = df[
    (~df["age_solo"].isin(age_levels)) &
    (df["youngest_multiple"] == df["oldest_multiple"]) &
    df["youngest_multiple"].isin(age_levels)
].copy()
same_age["age"] = same_age["youngest_multiple"]

diff_age = df[
    (~df["age_solo"].isin(age_levels)) &
    (df["youngest_multiple"] != df["oldest_multiple"]) &
    df["youngest_multiple"].isin(age_levels) &
    df["oldest_multiple"].isin(age_levels)
].copy()
young_rows = diff_age.copy()
young_rows["age"] = young_rows["youngest_multiple"]
old_rows = diff_age.copy()
old_rows["age"] = old_rows["oldest_multiple"]

expanded = pd.concat([solo, same_age, young_rows, old_rows], ignore_index=True)
expanded = expanded[expanded["age"].isin(age_levels)]
expanded = expanded[expanded["social_crime"].isin(["alone", "observed", "group"])]

print(f"Expanded rows: {len(expanded):,}")

# --- Assign eras ---
def assign_era(yr):
    if yr <= 2003:
        return "1993\u20132003"
    elif yr <= 2014:
        return "2004\u20132014"
    else:
        return "2015\u20132024"

expanded["era"] = expanded["year"].apply(assign_era)

# --- Compute weighted percentages by era x age ---
expanded["is_social"] = (expanded["social_crime"] != "alone").astype(float)
expanded["w"] = expanded["incident_weight"]
expanded["w_social"] = expanded["is_social"] * expanded["w"]

eras = ["1993\u20132003", "2004\u20132014", "2015\u20132024"]
era_data = {}

for era in eras:
    sub = expanded[expanded["era"] == era]
    pcts = []
    ns = []
    for age in age_levels:
        a = sub[sub["age"] == age]
        w_total = a["w"].sum()
        w_social = a["w_social"].sum()
        pct = w_social / w_total * 100 if w_total > 0 else 0
        pcts.append(pct)
        ns.append(len(a))
    era_data[era] = {"pct": pcts, "n": ns}
    yrs_in_era = sorted(sub["year"].unique())
    print(f"\n{era} ({len(yrs_in_era)} years: {yrs_in_era[0]}-{yrs_in_era[-1]}):")
    for i, age in enumerate(age_levels):
        print(f"  {age:12s}: social={pcts[i]:5.1f}%  (n={ns[i]:,})")

# ---------------------------------------------------------------------------
# Build figure: 1 x 3 panel bar chart
# ---------------------------------------------------------------------------

AGE_DISPLAY = ["Under 12", "12\u201314", "15\u201317", "18\u201320", "21\u201329", "30+"]

# Colour palette (matched to Figure 1)
C_BAR = "#2C6E91"       # Teal (matches Figure 1 co-offense colour)

fig, axes = plt.subplots(1, 3, figsize=(15, 6.5), sharey=True)

x = np.arange(len(age_levels))
W = 0.60  # Match Figure 1 bar width

for idx, (era, ax) in enumerate(zip(eras, axes)):
    pcts = era_data[era]["pct"]

    # Bars (matched to Figure 1 style)
    ax.bar(x, pcts, W, color=C_BAR, edgecolor="white", linewidth=0.5,
           zorder=3)

    # Trend line connecting bar tops (matched to Figure 1)
    ax.plot(x, pcts, marker="o", color="#1a1a1a", linewidth=1.8,
            markersize=7, markerfacecolor="#1a1a1a", markeredgecolor="white",
            markeredgewidth=1.2, zorder=5)

    # Percentage labels above each bar
    for i, p in enumerate(pcts):
        ax.text(i, p + 3.5, f"{p:.0f}%", ha="center", va="bottom",
                fontsize=9, fontfamily="serif", fontweight="bold",
                color="#333333", zorder=10)

    # Panel title (matched to Figure 1)
    ax.set_title(era, fontsize=14, fontweight="bold",
                 fontfamily="serif", pad=10)

    # X-axis (matched to Figure 1)
    ax.set_xticks(x)
    ax.set_xticklabels(AGE_DISPLAY, fontsize=10, fontfamily="serif",
                       rotation=30, ha="right")

    # Y-axis (matched to Figure 1)
    ax.set_ylim(0, 85)
    ax.set_yticks([0, 20, 40, 60, 80])
    ax.yaxis.set_major_formatter(
        plt.FuncFormatter(lambda v, _: f"{v:.0f}%"))
    if idx == 0:
        ax.set_ylabel("Social Offending (%)", fontsize=11, fontfamily="serif")
    ax.tick_params(axis="y", labelsize=10)

    # Grid (matched to Figure 1)
    ax.yaxis.grid(True, linestyle=":", linewidth=0.5, alpha=0.5,
                  color="#999999")
    ax.set_axisbelow(True)

    # Spines (matched to Figure 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

plt.tight_layout(w_pad=2.5)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
out_dir = os.path.join(PROJECT_ROOT, "outputs", "figures")
os.makedirs(out_dir, exist_ok=True)
for fmt in ("png", "pdf", "tiff"):
    path = os.path.join(out_dir, f"Figure4.{fmt}")
    fig.savefig(path, dpi=600, bbox_inches="tight", facecolor="white")
    print(f"\nSaved: {path}")

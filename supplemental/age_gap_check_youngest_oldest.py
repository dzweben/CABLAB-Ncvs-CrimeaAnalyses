#!/usr/bin/env python3
"""NCVS co-offending age-gap check (youngest vs oldest offender age group).

Purpose
-------
Quantify how often, in co-offending incidents, the youngest and oldest offender
age-group categories are:
  - the same (gap = 0)
  - adjacent (gap = 1)
  - separated by 2+ brackets (gap >= 2)

This supports the Methods statement about potential unobserved intermediate age
brackets when attributing co-offending incidents using youngest/oldest age-group
fields.

Data source
-----------
Reads the *coded* incident-level file produced by `originaldata-pull/ncvs-data-coding.Rmd`:
  originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv

Outputs
-------
Writes two CSV files to supplemental/derived_tables/:
  - cooffending_age_gap_summary.csv
  - cooffending_age_gap_by_pair.csv

Notes
-----
- Uses incident_weight when available for survey-weighted percentages.
- Treats valid NCVS age-group codes as: 1..6 (Under 12, 12–14, 15–17, 18–20, 21–29, 30+).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

AGE_CODE_TO_LABEL = {
    1: "Under 12",
    2: "12–14",
    3: "15–17",
    4: "18–20",
    5: "21–29",
    6: "30+",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--infile",
        type=Path,
        default=Path("originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv"),
        help="Path to coded incident-level CSV",
    )
    ap.add_argument(
        "--outdir",
        type=Path,
        default=Path("supplemental/derived_tables"),
        help="Directory to write outputs",
    )
    args = ap.parse_args()

    infile: Path = args.infile
    outdir: Path = args.outdir
    outdir.mkdir(parents=True, exist_ok=True)

    usecols = ["solo_group_crime", "youngest_multiple", "oldest_multiple", "incident_weight"]
    df = pd.read_csv(infile, usecols=lambda c: c in usecols)

    # Co-offending incidents only
    sub = df[(df["solo_group_crime"] == "group")].copy()

    # Valid codes 1..6 only
    valid_codes = set(AGE_CODE_TO_LABEL.keys())
    sub = sub[
        sub["youngest_multiple"].isin(valid_codes)
        & sub["oldest_multiple"].isin(valid_codes)
    ].copy()

    # Compute absolute gap in bracket codes
    sub["gap"] = (sub["oldest_multiple"].astype(int) - sub["youngest_multiple"].astype(int)).abs()

    # Summary (unweighted)
    total_n = len(sub)
    gap_counts = sub["gap"].value_counts().sort_index()

    def pct(x: float) -> float:
        return 0.0 if total_n == 0 else float(x) / float(total_n)

    summary_rows = []
    for g, c in gap_counts.items():
        summary_rows.append(
            {
                "gap": int(g),
                "count": int(c),
                "pct_unweighted": pct(c),
            }
        )

    # Add combined rows
    summary_rows.append(
        {
            "gap": "<=1",
            "count": int((sub["gap"] <= 1).sum()),
            "pct_unweighted": float((sub["gap"] <= 1).mean()) if total_n else 0.0,
        }
    )
    summary_rows.append(
        {
            "gap": ">=2",
            "count": int((sub["gap"] >= 2).sum()),
            "pct_unweighted": float((sub["gap"] >= 2).mean()) if total_n else 0.0,
        }
    )

    # Weighted percentages (incident_weight)
    if "incident_weight" in sub.columns and sub["incident_weight"].notna().any():
        w = sub["incident_weight"].astype(float)
        w_sum = float(w.sum())
        if w_sum > 0:
            for r in summary_rows:
                if isinstance(r["gap"], int):
                    g = r["gap"]
                    r["pct_weighted"] = float(w[sub["gap"] == g].sum() / w_sum)
                elif r["gap"] == "<=1":
                    r["pct_weighted"] = float(w[sub["gap"] <= 1].sum() / w_sum)
                elif r["gap"] == ">=2":
                    r["pct_weighted"] = float(w[sub["gap"] >= 2].sum() / w_sum)
        else:
            for r in summary_rows:
                r["pct_weighted"] = None
    else:
        for r in summary_rows:
            r["pct_weighted"] = None

    summary_df = pd.DataFrame(summary_rows)
    summary_path = outdir / "cooffending_age_gap_summary.csv"
    summary_df.to_csv(summary_path, index=False)

    # Pair table (youngest x oldest)
    pair = (
        sub.groupby(["youngest_multiple", "oldest_multiple"])  # type: ignore[arg-type]
        .size()
        .reset_index(name="n")
    )
    pair["youngest_label"] = pair["youngest_multiple"].map(AGE_CODE_TO_LABEL)
    pair["oldest_label"] = pair["oldest_multiple"].map(AGE_CODE_TO_LABEL)
    pair["gap"] = (pair["oldest_multiple"].astype(int) - pair["youngest_multiple"].astype(int)).abs()

    pair_path = outdir / "cooffending_age_gap_by_pair.csv"
    pair.sort_values(["gap", "n"], ascending=[True, False]).to_csv(pair_path, index=False)

    print(f"Read: {infile}")
    print(f"Co-offending incidents with valid youngest/oldest codes: N={total_n}")
    print(f"Wrote: {summary_path}")
    print(f"Wrote: {pair_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# ===========================================================================
# 01 — Build Merged Analysis Dataset
#
# Reads the ICPSR 39273 concatenated incident file (1993-2024) and produces
# analysis-ready CSVs with harmonized variables, survey design elements,
# and social offending classifications.
#
# Input:  data/raw/ICPSR_39273/DS0003/39273-0003-Data.tsv
# Output: data/derived/ncvs-merged-data-1993-2024.csv
#         data/derived/violent-ncvs-merged-data-1993-2024.csv
#         data/derived/theft-ncvs-merged-data-1993-2024.csv
#
# Supports: All analyses (scripts 03-08)
# ===========================================================================
"""
Build merged NCVS analysis dataset from concatenated incident file, 1993-2024.

Reads the ICPSR 39273 concatenated incident TSV (DS0003), extracts and recodes
variables, derives social_crime and Social2, adds TSL design variables
(V2117, V2118, YR_GRP), and writes merged CSVs to project root.

Key differences from build_merged_2014_2024.py:
  - Input: single concatenated TSV instead of per-year CSVs
  - Adds V2117 (pseudostratum) and V2118 (half-sample code) for TSL
  - Adds YR_GRP (year group for pooled TSL variance estimation)
  - Removes replicate weights (VICREPWGT1-160) — not needed for TSL
  - Covers 1993-2024 (excludes 1992 redesign overlap and 2006 anomalous)

Variable mapping (identical codes 1992-2024):
  V4234 -> solo_group_crime  (1=solo, 2=group; 3=don't know->NA)
  V4236 -> gender            (1=male, 2=female)
  V4237 -> age_solo          (1-6 bracket codes)
  V4251 -> youngest_multiple (1-6 bracket codes)
  V4252 -> oldest_multiple   (1-6 bracket codes)
  V4184 -> others_present    (1=yes, 2=no)
  V4185 -> others_help       (1=yes, 2=no)
  V4194 -> others_harm       (1=yes, 2=no)
  V4529 -> crimetype         (1-59 crime codes)
  V4527 -> incident_weight   (fallback: SERIES_IWEIGHT)
  V4017 -> series crime      (1=no, 2=yes; V4017=2 excluded)
  V2117 -> pseudostratum     (TSL strata variable)
  V2118 -> half_sample_code  (TSL cluster/PSU variable)

Series victimizations (V4017=2) are excluded: bundled multi-incident
records do not represent discrete crime events.

Weight handling by era:
  1993-2011: V4527 only (SERIES_IWEIGHT not applicable)
  2012-2015: V4527, fallback to SERIES_IWEIGHT if V4527 invalid
  2016:      V4527 mostly -2, SERIES_IWEIGHT used for ~79% of cases
  2017-2018: V4527 all -2, SERIES_IWEIGHT used for all
  2019-2024: V4527, fallback to SERIES_IWEIGHT if invalid

YR_GRP construction (per BJS variance estimation guide):
  1 = 1993-1996 (original sample design)
  2 = 1997-2005 (post-1996 PSU boundary change)
  3 = 2007-2024 (post-2006 PSU boundary change; 2006 excluded)
"""

import csv
import os
import sys
from collections import defaultdict

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
TSV_PATH = os.path.join(PROJECT_ROOT, "data", "raw", "ICPSR_39273",
                        "DS0003", "39273-0003-Data.tsv")
OUT_DIR = os.path.join(PROJECT_ROOT, "data", "derived")

# Years to EXCLUDE
EXCLUDE_YEARS = {"1992", "2006"}

# ---------------------------------------------------------------------------
# Recode maps (matching ncvs-data-coding.Rmd exactly — codes consistent 1992-2024)
# ---------------------------------------------------------------------------
AGE_MAP = {"1": "Under 12", "2": "12\u201314", "3": "15\u201317",
           "4": "18\u201320", "5": "21\u201329", "6": "30+",
           "8": None, "9": None}

GENDER_MAP = {"1": "male", "2": "female", "3": None, "8": None, "9": None}

YESNO_MAP = {"1": "yes", "2": "no", "3": None, "8": None, "9": None}

CRIME_MAP = {
    "1": "Completed rape", "2": "Attempted rape",
    "3": "Sexual attack with serious assault", "4": "Sexual attack with minor assault",
    "5": "Completed robbery with injury from serious assault",
    "6": "Completed robbery with injury from minor assault",
    "7": "Completed robbery without injury from minor assault",
    "8": "Attempted robbery with injury from serious assault",
    "9": "Attempted robbery with injury from minor assault",
    "10": "Attempted robbery without injury",
    "11": "Completed aggravated assault with injury",
    "12": "Attempted aggravated assault with weapon",
    "13": "Threatened assault with weapon",
    "14": "Simple assault completed with injury",
    "15": "Sexual assault without injury",
    "16": "Unwanted sexual contact without force",
    "17": "Assault without weapon without injury",
    "18": "Verbal threat of rape", "19": "Verbal threat of sexual assault",
    "20": "Verbal threat of assault",
    "21": "Completed purse snatching", "22": "Attempted purse snatching",
    "23": "Pocket picking (completed only)",
    "24": "Completed personal larceny without contact less than $10",
    "25": "Completed personal larceny without contact $10 to $49",
    "26": "Completed personal larceny without contact $50 to $249",
    "27": "Completed personal larceny without contact $250 or greater",
    "28": "Completed personal larceny without contact value NA",
    "29": "Attempted personal larceny without contact",
    "31": "Completed burglary, forcible entry",
    "32": "Completed burglary, unlawful entry without force",
    "33": "Attempted forcible entry",
    "34": "Completed household larceny less than $10",
    "35": "Completed household larceny $10 to $49",
    "36": "Completed household larceny $50 to $249",
    "37": "Completed household larceny $250 or greater",
    "38": "Completed household larceny value NA",
    "39": "Attempted household larceny",
    "40": "Completed motor vehicle theft", "41": "Attempted motor vehicle theft",
    "54": "Completed theft less than $10",
    "55": "Completed theft $10 to $49",
    "56": "Completed theft $50 to $249",
    "57": "Completed theft $250 or greater",
    "58": "Completed theft value NA",
    "59": "Attempted Theft",
}

PROPERTY_CRIMES = {
    "Completed burglary, forcible entry",
    "Completed burglary, unlawful entry without force",
    "Attempted forcible entry",
    "Completed motor vehicle theft", "Attempted motor vehicle theft",
    "Completed theft less than $10", "Completed theft $10 to $49",
    "Completed theft $50 to $249", "Completed theft $250 or greater",
    "Completed theft value NA", "Attempted Theft",
    "Completed household larceny less than $10",
    "Completed household larceny $10 to $49",
    "Completed household larceny $50 to $249",
    "Completed household larceny $250 or greater",
    "Completed household larceny value NA",
    "Completed personal larceny without contact less than $10",
    "Completed personal larceny without contact $10 to $49",
    "Completed personal larceny without contact $50 to $249",
    "Completed personal larceny without contact $250 or greater",
    "Completed personal larceny without contact value NA",
    "Attempted personal larceny without contact",
    "Attempted household larceny",
    "Pocket picking (completed only)",
}

VIOLENT_CRIMES = {
    "Completed rape", "Attempted rape",
    "Sexual attack with serious assault", "Sexual attack with minor assault",
    "Completed robbery with injury from serious assault",
    "Completed robbery with injury from minor assault",
    "Completed robbery without injury from minor assault",
    "Attempted robbery with injury from serious assault",
    "Attempted robbery with injury from minor assault",
    "Attempted robbery without injury",
    "Completed aggravated assault with injury",
    "Attempted aggravated assault with weapon",
    "Threatened assault with weapon",
    "Simple assault completed with injury",
    "Sexual assault without injury",
    "Unwanted sexual contact without force",
    "Assault without weapon without injury",
    "Verbal threat of rape", "Verbal threat of sexual assault",
    "Verbal threat of assault",
    "Completed purse snatching", "Attempted purse snatching",
}


def safe_int(val):
    """Convert to integer string, stripping decimals (e.g., '1.0' -> '1')."""
    if val is None or val.strip() == "":
        return ""
    try:
        return str(int(float(val)))
    except (ValueError, TypeError):
        return ""


def get_year_group(year_int):
    """Assign YR_GRP per BJS variance estimation guide for pooled TSL.
    PSU boundaries changed in 1996 and 2006.
      1 = 1993-1996 (original post-redesign sample)
      2 = 1997-2005 (post-1996 boundary change)
      3 = 2007-2024 (post-2006 boundary change; 2006 excluded)
    """
    if year_int <= 1996:
        return "1"
    elif year_int <= 2005:
        return "2"
    else:
        return "3"


def process_concatenated_file():
    """Read concatenated TSV, extract and recode variables for all years."""
    print(f"\nReading: {TSV_PATH}")
    print(f"File size: {os.path.getsize(TSV_PATH) / 1e6:.1f} MB")

    # Column names we need to extract
    needed_cols = [
        "YEARQ", "IDHH", "IDPER",
        "V2117", "V2118",
        "V4017",                    # Series crime indicator (1=no, 2=yes)
        "V4234", "V4236", "V4237", "V4251", "V4252",
        "V4184", "V4185", "V4194",
        "V4529", "V4527", "SERIES_IWEIGHT",
    ]

    rows_out = []
    year_counts = defaultdict(int)
    weight_source_counts = defaultdict(lambda: defaultdict(int))
    skipped_years = defaultdict(int)

    with open(TSV_PATH, "r", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")

        # Verify all needed columns exist
        missing = [c for c in needed_cols if c not in reader.fieldnames]
        if missing:
            print(f"  ❌ MISSING COLUMNS: {missing}")
            sys.exit(1)
        print(f"  ✅ All {len(needed_cols)} needed columns found in {len(reader.fieldnames)}-column file")

        for row in reader:
            yearq = row["YEARQ"].strip()
            year_str = yearq[:4]

            # Skip excluded years
            if year_str in EXCLUDE_YEARS:
                skipped_years[year_str] += 1
                continue

            year_int = int(year_str)

            # --- Exclude series victimizations (V4017=2) ---
            # Series crimes bundle 6+ similar incidents into one record;
            # event characteristics are ambiguous for bundled events.
            # Our unit of analysis is the discrete crime event.
            # Consistent with pre-2012 BJS practice.
            v4017 = safe_int(row.get("V4017", ""))
            if v4017 == "2":
                continue

            # --- Design variables for TSL ---
            v2117 = row["V2117"].strip()
            v2118 = row["V2118"].strip()
            yr_grp = get_year_group(year_int)

            # --- Incident weight (V4527 preferred, fallback SERIES_IWEIGHT) ---
            wt = row.get("V4527", "").strip()
            wt_source = "V4527"
            try:
                wt_invalid = (not wt or float(wt) <= 0)
            except ValueError:
                wt_invalid = True
            if wt_invalid:
                series_wt = row.get("SERIES_IWEIGHT", "").strip()
                if series_wt:
                    try:
                        if float(series_wt) > 0:
                            wt = series_wt
                            wt_source = "SERIES_IWEIGHT"
                    except ValueError:
                        pass
            weight_source_counts[year_str][wt_source] += 1

            # --- Substantive variables ---
            v4234 = safe_int(row.get("V4234", ""))
            if v4234 == "1":
                solo_group = "solo"
            elif v4234 == "2":
                solo_group = "group"
            else:
                solo_group = ""

            gender_raw = safe_int(row.get("V4236", ""))
            gender = GENDER_MAP.get(gender_raw, "")
            if gender is None:
                gender = ""

            age_solo_raw = safe_int(row.get("V4237", ""))
            age_solo = AGE_MAP.get(age_solo_raw, "")
            if age_solo is None:
                age_solo = ""

            youngest_raw = safe_int(row.get("V4251", ""))
            youngest = AGE_MAP.get(youngest_raw, "")
            if youngest is None:
                youngest = ""

            oldest_raw = safe_int(row.get("V4252", ""))
            oldest = AGE_MAP.get(oldest_raw, "")
            if oldest is None:
                oldest = ""

            others_present_raw = safe_int(row.get("V4184", ""))
            others_present = YESNO_MAP.get(others_present_raw, "")
            if others_present is None:
                others_present = ""

            others_help_raw = safe_int(row.get("V4185", ""))
            others_help = YESNO_MAP.get(others_help_raw, "")
            if others_help is None:
                others_help = ""

            others_harm_raw = safe_int(row.get("V4194", ""))
            others_harm = YESNO_MAP.get(others_harm_raw, "")
            if others_harm is None:
                others_harm = ""

            crime_code_raw = safe_int(row.get("V4529", ""))
            crimetypespecific = CRIME_MAP.get(crime_code_raw, "")

            # --- Build output row ---
            out = {
                "year": year_str,
                "V2117": v2117,
                "V2118": v2118,
                "YR_GRP": yr_grp,
                "solo_group_crime": solo_group,
                "gender": gender,
                "age_solo": age_solo,
                "youngest_multiple": youngest,
                "oldest_multiple": oldest,
                "others_present": others_present,
                "others_help": others_help,
                "others_harm": others_harm,
                "crimetype": crime_code_raw,
                "incident_weight": wt,
                "crimetypespecific": crimetypespecific,
            }
            rows_out.append(out)
            year_counts[year_str] += 1

    # Print summary
    print(f"\n  Skipped years: {dict(skipped_years)}")
    print(f"  Total incidents extracted: {len(rows_out)}")
    print(f"\n  Incidents per year:")
    for yr in sorted(year_counts.keys()):
        wsc = weight_source_counts[yr]
        v4527_n = wsc.get("V4527", 0)
        series_n = wsc.get("SERIES_IWEIGHT", 0)
        wt_note = ""
        if series_n > 0:
            wt_note = f"  (V4527:{v4527_n}, SERIES:{series_n})"
        print(f"    {yr}: {year_counts[yr]:>6}{wt_note}")

    return rows_out


def apply_derived_variables(rows):
    """Apply social_crime, Social2, crimetype collapse, and age consistency fixes."""
    for r in rows:
        # --- social_crime (trichotomous) ---
        sgc = r["solo_group_crime"]
        op = r["others_present"]
        oh = r["others_help"]
        if sgc == "":
            social = ""
        elif sgc == "group":
            social = "group"
        elif sgc == "solo" and op == "yes" and oh != "yes":
            social = "observed"
        elif sgc == "solo":
            social = "alone"
        else:
            social = ""
        r["social_crime"] = social

        # --- Social2 (binary) ---
        if social in ("group", "observed"):
            r["Social2"] = "social"
        elif social == "alone":
            r["Social2"] = "alone"
        else:
            r["Social2"] = ""

        # --- crimetype collapse ---
        cs = r["crimetypespecific"]
        if cs in PROPERTY_CRIMES:
            r["crimetype"] = "Property Crime"
        elif cs in VIOLENT_CRIMES:
            r["crimetype"] = "Nonfatal Personal Crimes"
        else:
            r["crimetype"] = ""

        # --- Fix youngest/oldest age consistency ---
        age_levels = {"Under 12", "12\u201314", "15\u201317", "18\u201320", "21\u201329", "30+"}
        ym = r["youngest_multiple"]
        om = r["oldest_multiple"]
        if ym == "" and om in age_levels:
            r["youngest_multiple"] = om
        if om == "" and ym in age_levels:
            r["oldest_multiple"] = ym

    return rows


def write_csv_output(rows, filepath):
    """Write rows to CSV."""
    if not rows:
        print(f"  ⚠️  No rows to write for {filepath}")
        return
    fieldnames = list(rows[0].keys())
    with open(filepath, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  \U0001f4c4 {os.path.basename(filepath)}: {len(rows)} rows, {len(fieldnames)} columns")


def main():
    print("=" * 70)
    print("NCVS Data Merge Pipeline: 1993-2024 (TSL Design)")
    print("Source: ICPSR 39273 Concatenated Incident File (Legacy)")
    print("Excludes: 1992 (redesign overlap), 2006 (BJS anomalous)")
    print("=" * 70)

    if not os.path.exists(TSV_PATH):
        print(f"\n  ❌ TSV file not found: {TSV_PATH}")
        print("  Download DS0003 (Delimited) from https://www.icpsr.umich.edu/web/NACJD/studies/39273")
        sys.exit(1)

    # --- Step 1: Extract and recode ---
    all_rows = process_concatenated_file()

    # --- Step 2: Apply derived variables ---
    print("\nApplying derived variables (social_crime, Social2, crimetype)...")
    all_rows = apply_derived_variables(all_rows)

    # --- Step 3: Summary stats ---
    years_present = sorted(set(r["year"] for r in all_rows))
    print(f"\n  Years included: {years_present[0]}-{years_present[-1]} ({len(years_present)} years)")
    print(f"  Years excluded: 1992, 2006")

    # --- Step 4: Write outputs ---
    print("\nWriting output files...")
    total_path = os.path.join(OUT_DIR, "ncvs-merged-data-1993-2024.csv")
    write_csv_output(all_rows, total_path)

    theft_rows = [r for r in all_rows if r["crimetype"] == "Property Crime"]
    theft_path = os.path.join(OUT_DIR, "theft-ncvs-merged-data-1993-2024.csv")
    write_csv_output(theft_rows, theft_path)

    violent_rows = [r for r in all_rows if r["crimetype"] == "Nonfatal Personal Crimes"]
    violent_path = os.path.join(OUT_DIR, "violent-ncvs-merged-data-1993-2024.csv")
    write_csv_output(violent_rows, violent_path)

    # --- Step 5: Validation ---
    print("\n" + "=" * 70)
    print("VALIDATION")
    print("=" * 70)

    # Check that all crimetype categories are accounted for
    missing_crime = sum(1 for r in all_rows if r["crimetype"] == "" and r["crimetypespecific"] != "")
    print(f"  Unmapped crime types: {missing_crime}")
    if missing_crime > 0:
        unmapped = set(r["crimetypespecific"] for r in all_rows if r["crimetype"] == "" and r["crimetypespecific"] != "")
        print(f"    {unmapped}")

    # Check social_crime distribution
    sc_dist = defaultdict(int)
    for r in all_rows:
        sc = r["social_crime"] if r["social_crime"] else "NA"
        sc_dist[sc] += 1
    print(f"  social_crime distribution: {dict(sc_dist)}")

    # Check age_solo distribution
    age_dist = defaultdict(int)
    for r in all_rows:
        a = r["age_solo"] if r["age_solo"] else "NA"
        age_dist[a] += 1
    print(f"  age_solo distribution: {dict(age_dist)}")

    # Check V2117/V2118 validity
    v2117_missing = sum(1 for r in all_rows if r["V2117"] == "")
    v2118_missing = sum(1 for r in all_rows if r["V2118"] == "")
    print(f"  V2117 missing: {v2117_missing}")
    print(f"  V2118 missing: {v2118_missing}")

    # Check weight validity
    wt_missing = sum(1 for r in all_rows if r["incident_weight"] == "" or r["incident_weight"] == "0")
    try:
        wt_invalid = sum(1 for r in all_rows if float(r["incident_weight"]) <= 0)
    except ValueError:
        wt_invalid = -1
    print(f"  incident_weight missing/zero: {wt_missing}")
    print(f"  incident_weight invalid (<=0): {wt_invalid}")

    # YR_GRP distribution
    yrgrp_dist = defaultdict(int)
    for r in all_rows:
        yrgrp_dist[r["YR_GRP"]] += 1
    print(f"  YR_GRP distribution: {dict(yrgrp_dist)}")

    # Cross-check with 2014-2024 per-year data
    print("\n  Cross-check with existing 2014-2024 merged data:")
    old_path = os.path.join(PROJECT_ROOT, "data", "derived", "ncvs-merged-data-2014-2024.csv")
    if os.path.exists(old_path):
        old_year_counts = defaultdict(int)
        with open(old_path, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                old_year_counts[row["year"]] += 1

        # The concatenated file may have different counts for some years
        # (e.g., 2016 legacy-only vs full), so report comparison
        for yr in sorted(old_year_counts.keys()):
            old_n = old_year_counts[yr]
            new_n = sum(1 for r in all_rows if r["year"] == yr)
            match = "\u2705" if old_n == new_n else f"\u26a0\ufe0f  (diff={new_n - old_n})"
            print(f"    {yr}: old={old_n}, new={new_n} {match}")
    else:
        print("    (no existing 2014-2024 file found for comparison)")

    print("\n\u2705 Done!")


if __name__ == "__main__":
    main()

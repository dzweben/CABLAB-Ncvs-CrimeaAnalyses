#!/usr/bin/env python3
# ===========================================================================
# 02 — Build Risk-Taking Analysis Dataset
#
# Reads the ICPSR 39273 concatenated incident file and extracts routing-aware
# risk indicators (weapon, attack, injury, location, substance use) for
# violent contact crimes. Computes composite RISK_SCORE (mean of 6 binary
# indicators, 0-1 scale).
#
# Input:  data/raw/ICPSR_39273/DS0003/39273-0003-Data.tsv
# Output: data/derived/ncvs-risk-merged-1993-2024.csv
#
# Supports: Analysis 2 — Risk-Taking Moderation (scripts 06-07)
# ===========================================================================
"""
Phase 0: Build risk analysis dataset from NCVS concatenated incident file.

Reads ICPSR 39273 DS0003 (concatenated TSV), extracts ALL existing variables
from build_merged_1993_2024.py PLUS risk V-codes, derives routing-aware
risk indicators, computes composite RISK_SCORE.

Key routing-aware design decisions:
  - V4110 (injury): Gated by V4060=1. Blank when V4060≠1 → code as 0, NOT NA.
    This is the biggest fix — previous scripts treated routing skips as missing,
    which destroyed the sample via listwise deletion.
  - V4239/V4254 (substance): Routed by V4234 (solo→V4239, group→V4254).
  - V4238/V4253 (gang): Routed by V4234 (solo→V4238, group→V4253).
  - V4236 (gender): Solo-offender only. Group → "unknown" (not dropped).
  - V4060→V4062→V4064: Sequential cascade. Blank on V4062 means V4060=1.

Composite RISK_SCORE:
  Mean of 6 indicators: WEAPON, ATTACK, INJURY, LOCATION_PUBLIC, OUTDOORS,
  SUBSTANCE. Scale 0-1. Require ≥4 of 6 non-NA.
  Excluded from composite: GANG (inherently age-correlated confound),
  DAYTIME (post-1998 only), STRANGER (solo-only routing).

Series victimizations (V4017=2) are excluded: bundled multi-incident
records do not represent discrete crime events.

Output: ncvs-risk-merged-1993-2024.csv (ALL crime types — R filters to TOC 1-17)
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
OUT_PATH = os.path.join(PROJECT_ROOT, "data", "derived", "ncvs-risk-merged-1993-2024.csv")

EXCLUDE_YEARS = {"1992", "2006"}

# ---------------------------------------------------------------------------
# Recode maps
# ---------------------------------------------------------------------------

# Age bracket codes → labels
AGE_MAP = {"1": "Under 12", "2": "12-14", "3": "15-17",
           "4": "18-20", "5": "21-29", "6": "30+"}

# Age code → AGE_GROUP_3
AGE3 = {"1": "Child",
        "2": "Adolescent", "3": "Adolescent",
        "4": "Emerging_Adult",
        "5": "Adult", "6": "Adult"}

# Age code → AGE_GROUP_4
AGE4 = {"1": "Child",
        "2": "Early_Adolescent", "3": "Mid_Adolescent",
        "4": "Emerging_Adult",
        "5": "Adult", "6": "Adult"}

# TOC → CRIME_CATEGORY (violent contact crimes TOC 1-17)
CRIME_CAT = {}
for c in ["1", "2", "3", "4", "15", "16"]:
    CRIME_CAT[c] = "rape_SA"
for c in ["5", "6", "7", "8", "9", "10"]:
    CRIME_CAT[c] = "robbery"
for c in ["11", "12", "13"]:
    CRIME_CAT[c] = "agg_assault"
for c in ["14", "17"]:
    CRIME_CAT[c] = "simple_assault"

# TOC → Completed/Attempted (within TOC 1-17)
COMPLETED_TOCS = {"1", "3", "4", "5", "6", "7", "11", "14", "15", "16", "17"}
ATTEMPTED_TOCS = {"2", "8", "9", "10", "12"}
# TOC 13 (threatened assault with weapon) = neither → NA

# Location codes: 17-23 = public/exposed
PUBLIC_LOCS = set(str(i) for i in range(17, 24))
VALID_LOCS = set(str(i) for i in range(1, 28))   # 1-27 = known specific locations

# Full crime type labels
CRIME_MAP = {
    "1": "Completed rape", "2": "Attempted rape",
    "3": "Sexual attack with serious assault",
    "4": "Sexual attack with minor assault",
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
    "18": "Verbal threat of rape",
    "19": "Verbal threat of sexual assault",
    "20": "Verbal threat of assault",
    "21": "Completed purse snatching",
    "22": "Attempted purse snatching",
    "23": "Pocket picking (completed only)",
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
      1 = 1993-1996 (original post-redesign)
      2 = 1997-2005 (post-1996 boundary change)
      3 = 2007-2024 (post-2006 boundary change)
    """
    if year_int <= 1996:
        return "1"
    elif year_int <= 2005:
        return "2"
    else:
        return "3"


def main():
    print("=" * 70)
    print("NCVS Risk Analysis — Phase 0: Data Extraction")
    print("Routing-aware risk indicator derivation")
    print("7-indicator composite: WEAPON + ATTACK + INJURY +")
    print("  LOCATION_PUBLIC + OUTDOORS + SUBSTANCE")
    print("=" * 70)

    if not os.path.exists(TSV_PATH):
        print(f"\nTSV not found: {TSV_PATH}")
        sys.exit(1)

    print(f"\nReading: {TSV_PATH}")
    print(f"File size: {os.path.getsize(TSV_PATH) / 1e6:.0f} MB")

    # All columns we need from the TSV
    needed = [
        "YEARQ", "V2117", "V2118",
        "V4017",                    # Series crime indicator (1=no, 2=yes)
        # Offender + social context (existing)
        "V4234", "V4236", "V4237", "V4251", "V4252",
        "V4184", "V4185", "V4194",
        "V4529", "V4527", "SERIES_IWEIGHT",
        # Risk V-codes (new)
        "V4049",                    # Weapon present
        "V4024", "V4042",           # Location, indoors/outdoors
        "V4021B",                   # Time of day (post-1998 only)
        "V4060", "V4062", "V4064", # Violence cascade
        "V4110",                    # Injury (gated by V4060=1)
        "V4239", "V4254",          # Substance (solo/group)
        "V4238", "V4253",          # Gang (solo/group)
        "V4241",                    # Stranger (all personal crimes)
    ]

    rows = []
    yr_counts = defaultdict(int)
    wt_source_counts = defaultdict(lambda: defaultdict(int))

    with open(TSV_PATH, "r", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")

        # Verify columns
        missing = [c for c in needed if c not in reader.fieldnames]
        if missing:
            print(f"MISSING COLUMNS: {missing}")
            sys.exit(1)
        print(f"All {len(needed)} columns found in {len(reader.fieldnames)}-col file\n")

        row_num = 0
        for row in reader:
            row_num += 1
            if row_num % 500000 == 0:
                print(f"  ...processed {row_num:,} rows")

            yearq = row["YEARQ"].strip()
            year_str = yearq[:4]
            if year_str in EXCLUDE_YEARS:
                continue
            year_int = int(year_str)

            # ── Exclude series victimizations (V4017=2) ──
            # Series crimes bundle 6+ similar incidents into one record;
            # event characteristics (weapon, injury, etc.) are ambiguous
            # for bundled events.  Our unit of analysis is the discrete
            # crime event.  Consistent with pre-2012 BJS practice.
            v4017 = safe_int(row.get("V4017", ""))
            if v4017 == "2":
                continue

            # ── Design variables ──
            v2117 = row["V2117"].strip()
            v2118 = row["V2118"].strip()
            yr_grp = get_year_group(year_int)

            # ── Weight (V4527 preferred, fallback SERIES_IWEIGHT) ──
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
            wt_source_counts[year_str][wt_source] += 1

            # ── Solo/Group (master gate for offender variables) ──
            v4234 = safe_int(row.get("V4234", ""))
            if v4234 == "1":
                sgc = "solo"
            elif v4234 == "2":
                sgc = "group"
            else:
                sgc = ""   # DK (3) or property with no offender (9)

            # ── Gender — ROUTING-AWARE ──
            # V4236 is solo-offender only. Blank for group → "unknown", NOT dropped.
            if sgc == "solo":
                gender_raw = safe_int(row.get("V4236", ""))
                if gender_raw == "1":
                    gender = "male"
                elif gender_raw == "2":
                    gender = "female"
                else:
                    gender = "unknown"
            else:
                gender = "unknown"

            # ── Age (solo → V4237; group → V4251 youngest) ──
            age_solo_raw = safe_int(row.get("V4237", ""))
            youngest_raw = safe_int(row.get("V4251", ""))
            oldest_raw = safe_int(row.get("V4252", ""))

            if sgc == "solo":
                age_raw = age_solo_raw
            elif sgc == "group":
                age_raw = youngest_raw
            else:
                age_raw = ""

            age_solo_label = AGE_MAP.get(age_solo_raw, "")
            youngest_label = AGE_MAP.get(youngest_raw, "")
            oldest_label = AGE_MAP.get(oldest_raw, "")

            ag3 = AGE3.get(age_raw, "")
            ag4 = AGE4.get(age_raw, "")

            # ── Social context ──
            op = safe_int(row.get("V4184", ""))
            oh = safe_int(row.get("V4185", ""))

            if sgc == "":
                social = ""
            elif sgc == "group":
                social = "group"
            elif sgc == "solo" and op == "1" and oh != "1":
                social = "observed"
            elif sgc == "solo":
                social = "alone"
            else:
                social = ""

            s2 = "social" if social in ("group", "observed") else (
                "alone" if social == "alone" else "")

            # ── Crime type ──
            toc = safe_int(row.get("V4529", ""))
            crimetypespecific = CRIME_MAP.get(toc, "")
            crime_cat = CRIME_CAT.get(toc, "")

            # ── ERA ──
            if year_int <= 2005:
                era = "1993-2005"
            elif year_int <= 2015:
                era = "2007-2015"
            else:
                era = "2016-2024"

            # ================================================================
            # RISK INDICATORS (routing-aware)
            # ================================================================

            # 1. WEAPON_PRESENT (V4049): 1=yes, 2=no, 3=DK
            wp = safe_int(row.get("V4049", ""))
            weapon = "1" if wp == "1" else ("0" if wp == "2" else "")

            # 2+3. ATTACK_BINARY + VICTIM_INJURED
            # V4060: 1=attacked, 2=not attacked
            # V4110: 1=injured, 2=not injured — ONLY ASKED IF V4060=1
            # >>> ROUTING-AWARE: V4060=2 → injury=0 (NOT missing!) <<<
            atk = safe_int(row.get("V4060", ""))
            inj_raw = safe_int(row.get("V4110", ""))

            if atk == "1":
                attack = "1"
                if inj_raw == "1":
                    injury = "1"
                elif inj_raw == "2":
                    injury = "0"
                else:
                    injury = ""   # DK on injury (rare)
            elif atk == "2":
                attack = "0"
                injury = "0"     # Not attacked → not injured (ROUTING-AWARE!)
            else:
                attack = ""
                injury = ""

            # 4. LOCATION_PUBLIC (V4024): 17-23 = public/exposed
            loc = safe_int(row.get("V4024", ""))
            if loc in PUBLIC_LOCS:
                location = "1"
            elif loc in VALID_LOCS:
                location = "0"
            else:
                location = ""    # DK (98), refused (99), or blank

            # 5. OUTDOORS (V4042): 1=indoors, 2=outdoors, 3=both
            outd = safe_int(row.get("V4042", ""))
            if outd in ("2", "3"):
                outdoors = "1"
            elif outd == "1":
                outdoors = "0"
            else:
                outdoors = ""

            # 6. SUBSTANCE_USE — ROUTING-AWARE by solo/group
            # Solo → V4239; Group → V4254. 1=yes, 2=no, 3=DK
            if sgc == "solo":
                su = safe_int(row.get("V4239", ""))
            elif sgc == "group":
                su = safe_int(row.get("V4254", ""))
            else:
                su = ""
            substance = "1" if su == "1" else ("0" if su == "2" else "")

            # 7. GANG_INVOLVED — ROUTING-AWARE by solo/group
            # Solo → V4238; Group → V4253. 1=yes, 2=no, 3=DK
            if sgc == "solo":
                ga = safe_int(row.get("V4238", ""))
            elif sgc == "group":
                ga = safe_int(row.get("V4253", ""))
            else:
                ga = ""
            gang = "1" if ga == "1" else ("0" if ga == "2" else "")

            # ── Standalone indicators (not in composite) ──

            # DAYTIME (V4021B): 1-4=day, 5-8=night, 9=DK
            # NOTE: V4021B only exists post-1998. Pre-1999 → blank → ""
            td = safe_int(row.get("V4021B", ""))
            if td in ("1", "2", "3", "4"):
                daytime = "1"
            elif td in ("5", "6", "7", "8"):
                daytime = "0"
            else:
                daytime = ""

            # STRANGER_CRIME (V4241): 2=stranger, 1=known, 3=DK
            st = safe_int(row.get("V4241", ""))
            if st == "2":
                stranger = "1"
            elif st == "1":
                stranger = "0"
            else:
                stranger = ""

            # CRIME_COMPLETED: from TOC code
            if toc in COMPLETED_TOCS:
                completed = "1"
            elif toc in ATTEMPTED_TOCS:
                completed = "0"
            else:
                completed = ""   # TOC 13 (threat) or non-violent crimes

            # ================================================================
            # COMPOSITE RISK_SCORE
            # Mean of 6 indicators: WEAPON, ATTACK, INJURY,
            #   LOCATION_PUBLIC, OUTDOORS, SUBSTANCE
            # GANG excluded: inherently age-correlated (confound).
            # Require ≥4 of 6 non-NA.
            # ================================================================
            indicators = [weapon, attack, injury, location,
                          outdoors, substance]
            valid_vals = [float(x) for x in indicators if x in ("0", "1")]
            if len(valid_vals) >= 4:
                risk_score = str(round(sum(valid_vals) / len(valid_vals), 6))
            else:
                risk_score = ""

            # ── Output row ──
            rows.append({
                "year": year_str,
                "V2117": v2117,
                "V2118": v2118,
                "YR_GRP": yr_grp,
                "incident_weight": wt,
                "solo_group_crime": sgc,
                "gender": gender,
                "age_solo": age_solo_label,
                "youngest_multiple": youngest_label,
                "oldest_multiple": oldest_label,
                "social_crime": social,
                "SOCIAL2": s2,
                "crimetype_raw": toc,
                "crimetypespecific": crimetypespecific,
                "AGE_GROUP_3": ag3,
                "AGE_GROUP_4": ag4,
                "CRIME_CATEGORY": crime_cat,
                "ERA": era,
                "WEAPON_PRESENT": weapon,
                "ATTACK_BINARY": attack,
                "VICTIM_INJURED": injury,
                "LOCATION_PUBLIC": location,
                "OUTDOORS": outdoors,
                "DAYTIME": daytime,
                "SUBSTANCE_USE": substance,
                "STRANGER_CRIME": stranger,
                "GANG_INVOLVED": gang,
                "CRIME_COMPLETED": completed,
                "RISK_SCORE": risk_score,
            })
            yr_counts[year_str] += 1

    # ==================================================================
    # SUMMARY + VALIDATION
    # ==================================================================
    print(f"\nExtracted {len(rows):,} total incidents")
    print(f"Years: {sorted(yr_counts.keys())[0]}-{sorted(yr_counts.keys())[-1]}")

    # Year distribution
    print(f"\nYear distribution:")
    for yr in sorted(yr_counts.keys()):
        wsc = wt_source_counts[yr]
        v4527_n = wsc.get("V4527", 0)
        series_n = wsc.get("SERIES_IWEIGHT", 0)
        wt_note = f"  (V4527:{v4527_n}, SERIES:{series_n})" if series_n > 0 else ""
        print(f"  {yr}: {yr_counts[yr]:>7,}{wt_note}")

    # Filter to violent contact (TOC 1-17) for validation
    violent_tocs = set(str(i) for i in range(1, 18))
    violent = [r for r in rows if r["crimetype_raw"] in violent_tocs]
    print(f"\n{'='*70}")
    print(f"VALIDATION — Violent contact crimes (TOC 1-17): {len(violent):,}")
    print(f"{'='*70}")

    # AGE_GROUP_3 distribution
    ag3_dist = defaultdict(int)
    for r in violent:
        ag3_dist[r["AGE_GROUP_3"] or "NA"] += 1
    print(f"\nAGE_GROUP_3: {dict(ag3_dist)}")

    # SOCIAL2 distribution
    s2_dist = defaultdict(int)
    for r in violent:
        s2_dist[r["SOCIAL2"] or "NA"] += 1
    print(f"SOCIAL2: {dict(s2_dist)}")

    # Analysis sample: violent, known age + social
    analysis = [r for r in violent
                if r["AGE_GROUP_3"] in ("Adolescent", "Emerging_Adult", "Adult")
                and r["SOCIAL2"] in ("alone", "social")]
    print(f"\nAnalysis sample (known age + social): {len(analysis):,}")

    # AGE × SOCIAL cross-tab
    print(f"\nAGE_GROUP_3 x SOCIAL2 cross-tab (unweighted):")
    for ag in ["Adolescent", "Emerging_Adult", "Adult"]:
        for s in ["alone", "social"]:
            n = sum(1 for r in analysis
                    if r["AGE_GROUP_3"] == ag and r["SOCIAL2"] == s)
            print(f"  {ag:20s} x {s:8s}: {n:>6,}")

    # Social offending rate by age
    print(f"\nSocial offending rate by AGE_GROUP_3 (unweighted):")
    for ag in ["Adolescent", "Emerging_Adult", "Adult"]:
        n_soc = sum(1 for r in analysis
                    if r["AGE_GROUP_3"] == ag and r["SOCIAL2"] == "social")
        n_tot = sum(1 for r in analysis if r["AGE_GROUP_3"] == ag)
        pct = n_soc / n_tot * 100 if n_tot > 0 else 0
        print(f"  {ag:20s}: {n_soc:>5,}/{n_tot:>5,} = {pct:.1f}%")

    # Risk indicator coverage
    print(f"\nRisk indicator coverage (analysis sample):")
    for rv in ["WEAPON_PRESENT", "ATTACK_BINARY", "VICTIM_INJURED",
               "LOCATION_PUBLIC", "OUTDOORS", "DAYTIME",
               "SUBSTANCE_USE", "STRANGER_CRIME", "GANG_INVOLVED",
               "CRIME_COMPLETED"]:
        valid = sum(1 for r in analysis if r[rv] in ("0", "1"))
        pos = sum(1 for r in analysis if r[rv] == "1")
        pct_v = valid / len(analysis) * 100 if analysis else 0
        pct_p = pos / valid * 100 if valid > 0 else 0
        print(f"  {rv:20s}: {valid:>6,}/{len(analysis):,} "
              f"({pct_v:5.1f}% valid), {pct_p:5.1f}% = 1")

    # Composite coverage
    rs_valid = sum(1 for r in analysis if r["RISK_SCORE"] != "")
    rs_vals = [float(r["RISK_SCORE"]) for r in analysis if r["RISK_SCORE"] != ""]
    rs_mean = sum(rs_vals) / len(rs_vals) if rs_vals else 0
    print(f"\n  RISK_SCORE (composite): {rs_valid:>6,}/{len(analysis):,} "
          f"({rs_valid/len(analysis)*100:.1f}% valid), mean={rs_mean:.4f}")

    # CRIME_CATEGORY distribution
    cc_dist = defaultdict(int)
    for r in analysis:
        cc_dist[r["CRIME_CATEGORY"]] += 1
    print(f"\nCRIME_CATEGORY: {dict(cc_dist)}")

    # Gender distribution (verify "unknown" coding)
    gen_dist = defaultdict(int)
    for r in analysis:
        gen_dist[r["gender"]] += 1
    print(f"Gender: {dict(gen_dist)}")

    # ERA distribution
    era_dist = defaultdict(int)
    for r in analysis:
        era_dist[r["ERA"]] += 1
    print(f"ERA: {dict(era_dist)}")

    # ==================================================================
    # WRITE OUTPUT
    # ==================================================================
    print(f"\n{'='*70}")
    print(f"Writing output...")
    with open(OUT_PATH, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote: {OUT_PATH}")
    print(f"  {len(rows):,} rows x {len(rows[0])} columns")
    print(f"\nDone.")


if __name__ == "__main__":
    main()

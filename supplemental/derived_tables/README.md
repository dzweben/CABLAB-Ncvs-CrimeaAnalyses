# Derived tables (local)

This folder is for locally-generated derived outputs (CSV tables, interim summaries).
It may be `.gitignore`'d.

## Reproduce co-offending youngest/oldest age-gap check

From the repo root:

```bash
python3 supplemental/age_gap_check_youngest_oldest.py \
  --infile originaldata-pull/coded_data/ncvs_2014_2022_incident_full.csv \
  --outdir supplemental/derived_tables
```

Outputs:
- `cooffending_age_gap_summary.csv`
- `cooffending_age_gap_by_pair.csv`

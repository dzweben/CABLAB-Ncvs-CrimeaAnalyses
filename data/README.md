# Data

This directory holds the raw and derived data files used in the analysis.

## Obtaining the Data

The analyses use the **National Crime Victimization Survey (NCVS) Concatenated File, Legacy Version, 1992-2024** from the Inter-university Consortium for Political and Social Research (ICPSR).

**ICPSR Study 39273**
https://doi.org/10.3886/ICPSR39273.v1

### Steps:
1. Create an ICPSR account at https://www.icpsr.umich.edu/
2. Navigate to Study 39273 and download **DS0003** (Incident-Level File)
3. Extract the TSV file and place it at:
   ```
   data/raw/ICPSR_39273/DS0003/39273-0003-Data.tsv
   ```

## Directory Structure

```
data/
├── raw/          # Place ICPSR TSV here (gitignored)
│   └── ICPSR_39273/DS0003/39273-0003-Data.tsv
└── derived/      # Produced by scripts 01-02 (gitignored)
    ├── ncvs-merged-data-1993-2024.csv
    ├── violent-ncvs-merged-data-1993-2024.csv
    ├── theft-ncvs-merged-data-1993-2024.csv
    └── ncvs-risk-merged-1993-2024.csv
```

The derived CSVs are produced by running `scripts/01_build_merged_data.py` and `scripts/02_build_risk_data.py`. They are not included in the repository due to size and data use agreements.

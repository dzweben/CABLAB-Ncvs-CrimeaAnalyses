import sys
from pathlib import Path

import pandas as pd
from docx import Document


def extract_tables(docx_path: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    doc = Document(str(docx_path))

    for ti, table in enumerate(doc.tables, start=1):
        rows = []
        for row in table.rows:
            rows.append([cell.text.strip() for cell in row.cells])
        if not rows:
            continue
        # Drop completely empty trailing columns
        max_len = max(len(r) for r in rows)
        rows = [r + [""] * (max_len - len(r)) for r in rows]

        df = pd.DataFrame(rows)
        # If first row looks like header, keep as header
        # We'll just write raw table with row0 as header for convenience.
        header = df.iloc[0].tolist()
        body = df.iloc[1:].copy()
        body.columns = header
        body.to_csv(out_dir / f"table_{ti:02d}.csv", index=False)


def main():
    if len(sys.argv) < 3:
        print("Usage: extract_docx_tables.py <docx_path> <out_dir>")
        raise SystemExit(2)
    docx_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    extract_tables(docx_path, out_dir)


if __name__ == "__main__":
    main()

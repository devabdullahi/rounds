#!/usr/bin/env python3
"""Writes SQL that loads knowledge-base/licensed/synthetic_backgrounds.jsonl into private.patient_backgrounds.

The backgrounds are synthetic (Synthea), but their condition, allergy and social wording is SNOMED CT,
which is licensed (UMLS Affiliate License): it may live in our database but not in git. So the SQL goes
to the path given, which must be outside the repo. The script refuses any path inside it
(knowledge-base/licensed/ included), so the SQL can't be committed or land in seed files.

    python3 backgrounds.py .cache/population/csv           # refresh the JSONL from a Synthea export
    python3 load_backgrounds.py ~/rounds-backgrounds.sql    # then run that SQL against the database

Rows are upserted by id, so running the SQL again refreshes them in place.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "knowledge-base" / "licensed" / "synthetic_backgrounds.jsonl"
TAG = "$rounds_bg$"
COLUMNS = ("id", "age", "sex", "marital", "conditions", "medications", "allergies", "smoking", "social")
JSON_COLUMNS = {"conditions", "medications", "allergies", "social"}


def outside_repo(value: str) -> Path:
    """argparse type: the resolved path, refused when it falls anywhere inside the repo."""
    path = Path(value).expanduser().resolve()
    if path == ROOT or ROOT in path.parents:
        raise argparse.ArgumentTypeError(f"{path} is inside the repo; licensed SNOMED CT content must stay out of it")
    return path


def literal(row: dict, column: str) -> str:
    """One value as SQL: dollar-quoted text or jsonb, a bare integer for age, null when missing."""
    value = row.get(column)
    if column == "age":
        return str(int(value))
    if column in JSON_COLUMNS:
        text = json.dumps(value or [], ensure_ascii=False)
        suffix = "::jsonb"
    elif value is None:
        return "null"
    else:
        text, suffix = str(value), ""
    if TAG in text:
        raise ValueError(f"{row.get('id')}: {column} contains the quote tag")
    return f"{TAG}{text}{TAG}{suffix}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("output", type=outside_repo, help="where to write the SQL (outside the repo)")
    args = parser.parse_args()

    rows = [json.loads(line) for line in SOURCE.open() if line.strip()]
    updates = ", ".join(f"{c} = excluded.{c}" for c in COLUMNS if c != "id")
    with args.output.open("w") as out:
        out.write("begin;\n")
        for r in rows:
            if r.get("sex") not in ("F", "M"):
                raise ValueError(f"{r.get('id')}: sex must be F or M")
            values = ", ".join(literal(r, c) for c in COLUMNS)
            out.write(f"insert into private.patient_backgrounds ({', '.join(COLUMNS)}) values ({values})"
                      f" on conflict (id) do update set {updates};\n")
        out.write("commit;\n")
    print(f"wrote {len(rows)} upserts to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()

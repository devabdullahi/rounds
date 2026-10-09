#!/usr/bin/env python3
"""Writes SQL that loads knowledge-base/licensed/snomed.jsonl into private.conditions.terms.

SNOMED CT content is licensed (UMLS Affiliate License): it may live in our database but not in git,
so the SQL goes to the path given, which must be outside the repo. The script refuses any path
inside it (knowledge-base/licensed/ included), so the SQL can't be committed or land in seed files.

    python3 snomed.py                         # refresh knowledge-base/licensed/snomed.jsonl from UMLS
    python3 load_terms.py ~/rounds-terms.sql  # then run that SQL against the database
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from common import KB, ROOT

TAG = "$rounds_terms$"


def outside_repo(value: str) -> Path:
    """argparse type: the resolved path, refused when it falls anywhere inside the repo."""
    path = Path(value).expanduser().resolve()
    if path == ROOT or ROOT in path.parents:
        raise argparse.ArgumentTypeError(f"{path} is inside the repo; licensed SNOMED CT content must stay out of it")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("output", type=outside_repo, help="where to write the SQL (outside the repo)")
    args = parser.parse_args()

    rows = [json.loads(line) for line in (KB / "licensed" / "snomed.jsonl").open()]
    with args.output.open("w") as out:
        for r in rows:
            terms = json.dumps({"snomed": {k: r["snomed"][k] for k in ("code", "preferred", "synonyms")},
                                "icd10cm": r["icd10cm"]}, ensure_ascii=False)
            if TAG in terms:
                raise ValueError(f"{r['slug']}: terms contain the quote tag")
            out.write(f"update private.conditions set terms = {TAG}{terms}{TAG}::jsonb where slug = {TAG}{r['slug']}{TAG};\n")
    print(f"wrote {len(rows)} updates to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()

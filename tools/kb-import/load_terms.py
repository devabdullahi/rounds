#!/usr/bin/env python3
"""Writes SQL that loads knowledge-base/licensed/snomed.jsonl into private.conditions.terms.

SNOMED CT content is licensed (UMLS Affiliate License): it may live in our database but not in git,
so the SQL goes to the path given (outside the repo), never to supabase/seed files.

    python3 snomed.py                         # refresh knowledge-base/licensed/snomed.jsonl from UMLS
    python3 load_terms.py /tmp/terms.sql      # then run that SQL against the database
"""

from __future__ import annotations

import json
import sys

from common import KB

TAG = "$rounds_terms$"


def main() -> None:
    rows = [json.loads(line) for line in (KB / "licensed" / "snomed.jsonl").open()]
    with open(sys.argv[1], "w") as out:
        for r in rows:
            terms = json.dumps({"snomed": {k: r["snomed"][k] for k in ("code", "preferred", "synonyms")},
                                "icd10cm": r["icd10cm"]}, ensure_ascii=False)
            if TAG in terms:
                raise ValueError(f"{r['slug']}: terms contain the quote tag")
            out.write(f"update private.conditions set terms = {TAG}{terms}{TAG}::jsonb where slug = {TAG}{r['slug']}{TAG};\n")
    print(f"wrote {len(rows)} updates to {sys.argv[1]}", file=sys.stderr)


if __name__ == "__main__":
    main()

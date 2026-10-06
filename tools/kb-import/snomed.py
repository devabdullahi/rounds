#!/usr/bin/env python3
"""Maps conditions to SNOMED CT US Edition and ICD-10-CM through the UMLS REST API.

Output: knowledge-base/licensed/snomed.jsonl, one row per case-suitable condition: the SNOMED
concept (code, fully specified name, preferred term, synonyms) and its ICD-10-CM codes.

SNOMED CT content is licensed (UMLS Affiliate License, free in the US): it may be used in Rounds
but not redistributed, so the output folder is git-ignored and loaded only into our own database.

Needs UMLS_API_KEY in tools/kb-import/.env (see .env.example). Responses are cached without the key.

    python3 snomed.py              # all case-suitable conditions (knowledge-base/triage.jsonl)
    python3 snomed.py --limit 10   # quick trial
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse

from common import KB, ROOT, cached_json, slug, write_jsonl

API = "https://uts-ws.nlm.nih.gov/rest"
DELAY = 0.07           # UMLS allows 20 requests a second per IP
CANDIDATES = 3         # search hits checked for a disorder/finding concept
# Semantic tags (the bracket at the end of a SNOMED fully specified name) that can be a case's diagnosis.
WANTED_TAGS = ("(disorder)", "(finding)")


def key() -> str:
    value = os.environ.get("UMLS_API_KEY")
    if not value:
        raise SystemExit("Set UMLS_API_KEY in tools/kb-import/.env (uts.nlm.nih.gov → My Profile).")
    return value


def get(cache_key: str, path: str, params: dict, missing: object = None) -> object:
    query = urllib.parse.urlencode(params | {"apiKey": key()})
    return cached_json(f"umls-{cache_key}", f"{API}{path}?{query}", DELAY, missing=missing)


def search(name: str) -> tuple[list[dict], str]:
    """SNOMED concepts for a name, trying exact, then normalized, then word matches."""
    for search_type in ("exact", "normalizedString", "words"):
        data = get(f"search-{search_type}-{slug(name)}", "/search/current",
                   {"string": name, "sabs": "SNOMEDCT_US", "returnIdType": "code",
                    "searchType": search_type, "pageSize": 5})
        hits = [r for r in data["result"]["results"] if r.get("ui") and r["ui"] != "NONE"]
        if hits:
            return hits, search_type
    return [], "none"


def atoms(code: str) -> list[dict]:
    data = get(f"atoms-{code}", f"/content/current/source/SNOMEDCT_US/{code}/atoms",
               {"language": "ENG", "pageSize": 100}, missing={"result": []})
    return data["result"]


def icd10cm(code: str) -> list[dict]:
    data = get(f"crosswalk-{code}", f"/crosswalk/current/source/SNOMEDCT_US/{code}",
               {"targetSource": "ICD10CM"}, missing={"result": []})
    seen, out = set(), []
    for r in data["result"]:
        if r["ui"] not in seen:
            seen.add(r["ui"])
            out.append({"code": r["ui"], "name": r["name"]})
    return out


def concept(name: str) -> dict | None:
    hits, match = search(name)
    for hit in hits[:CANDIDATES]:
        terms = atoms(hit["ui"])
        fsn = next((a["name"] for a in terms if a.get("termType") == "FN"), "")
        if fsn.endswith(WANTED_TAGS):
            names = {a["name"] for a in terms if a.get("termType") in ("PT", "SY")}
            return {
                "code": hit["ui"],
                "fsn": fsn,
                "preferred": next((a["name"] for a in terms if a.get("termType") == "PT"), hit["name"]),
                "synonyms": sorted(names - {fsn}),
                "match": match,
            }
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    key()

    triage = [json.loads(line) for line in (KB / "triage.jsonl").open()]
    suitable = [t for t in triage if t.get("triage") and t["triage"].get("case_suitable")][: args.limit]
    rows, unmatched = [], []
    for n, t in enumerate(suitable, 1):
        name = t["triage"]["name"]
        c = concept(name)
        print(f"  [{n}/{len(suitable)}] {name}: {c['preferred'] + ' ' + c['code'] if c else 'no SNOMED disorder found'}", file=sys.stderr)
        if not c:
            unmatched.append(name)
            continue
        rows.append({"slug": t["slug"], "condition_id": t["condition_id"], "name": name,
                     "snomed": c, "icd10cm": icd10cm(c["code"])})

    out = KB / "licensed" / "snomed.jsonl"
    write_jsonl(out, rows)
    with_icd = sum(bool(r["icd10cm"]) for r in rows)
    print(f"wrote {len(rows)}/{len(suitable)} conditions ({with_icd} with ICD-10-CM) to {out.relative_to(ROOT)}", file=sys.stderr)
    if unmatched:
        print(f"no SNOMED disorder for: {', '.join(unmatched[:20])}{' …' if len(unmatched) > 20 else ''}", file=sys.stderr)


if __name__ == "__main__":
    main()

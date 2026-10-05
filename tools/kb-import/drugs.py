#!/usr/bin/env python3
"""Builds knowledge-base/drugs.jsonl from openFDA prescription drug labels (public domain, CC0).

One record per common single-ingredient generic: indications, dosing, contraindications, boxed
warning, adverse reactions, interactions and mechanism, trimmed for case authoring. Labels are
manufacturer text published by the FDA; use them to check facts and write our own wording.

openFDA allows 1,000 requests a day without a key. Set OPENFDA_API_KEY to lift that; responses are
cached, so a run that hits the limit resumes the next day.

    python3 tools/kb-import/drugs.py              # top 600 generics
    python3 tools/kb-import/drugs.py --limit 20   # quick trial
"""

from __future__ import annotations

import argparse
import os
import sys
import urllib.parse

from common import KB, ROOT, cached_json, slug, truncate, write_jsonl

LABELS = "https://api.fda.gov/drug/label.json"
RX = 'openfda.product_type:"HUMAN PRESCRIPTION DRUG"'
DELAY = 0.3  # stays under openFDA's 240 requests a minute

# Label sections worth keeping, in reading order, with a per-section character budget.
SECTIONS = {
    "boxed_warning": 1500,
    "indications_and_usage": 2000,
    "dosage_and_administration": 2500,
    "dosage_forms_and_strengths": 800,
    "contraindications": 1200,
    "warnings_and_cautions": 3000,
    "warnings": 3000,               # older, pre-2006 label format
    "adverse_reactions": 2000,
    "drug_interactions": 1500,
    "use_in_specific_populations": 1500,
    "mechanism_of_action": 1000,
}

# Not useful as case medications: gases, diluents, contrast and allergen extracts.
SKIP_WORDS = ("OXYGEN", "NITROGEN", "WATER", "SODIUM CHLORIDE", "DEXTROSE", "ALLERGENIC", "POLLEN", "EXTRACT")


def query(params: dict) -> str:
    key = os.environ.get("OPENFDA_API_KEY")
    if key:
        params = params | {"api_key": key}
    return f"{LABELS}?{urllib.parse.urlencode(params)}"


def common_generics(count: int) -> list[str]:
    data = cached_json("fda-rx-generic-counts",
                       query({"search": RX, "count": "openfda.generic_name.exact", "limit": 1000}), DELAY)
    names = []
    for row in data["results"]:
        name = row["term"]
        if "," in name or " AND " in name or any(w in name for w in SKIP_WORDS):
            continue
        names.append(name)
    return names[:count]


def newest_label(generic: str) -> dict | None:
    data = cached_json(
        f"fda-label-{slug(generic)}",
        query({"search": f'{RX} AND openfda.generic_name.exact:"{generic}"', "sort": "effective_time:desc", "limit": 1}),
        DELAY, missing={"results": []})
    return data["results"][0] if data["results"] else None


def record(generic: str, label: dict) -> dict:
    fda = label.get("openfda", {})
    sections = {}
    for name, budget in SECTIONS.items():
        if name == "warnings" and "warnings_and_cautions" in sections:
            continue
        if label.get(name):
            sections[name] = truncate("\n".join(label[name]).strip(), budget)
    return {
        "generic_name": generic.title(),
        "brand_names": sorted(set(fda.get("brand_name", [])))[:8],
        "rxcui": fda.get("rxcui", [])[:5],
        "route": fda.get("route", []),
        "pharm_class": fda.get("pharm_class_epc", []) + fda.get("pharm_class_moa", []),  # often empty
        "label": sections,
        "source": {
            "set_id": label.get("set_id"),
            "effective_time": label.get("effective_time"),
            "url": f"https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid={label.get('set_id')}",
            "license": "openFDA: public domain (CC0). Label text is FDA-published; reword for cases.",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, default=600)
    args = parser.parse_args()

    generics = common_generics(args.limit)
    records = []
    for n, generic in enumerate(generics, 1):
        print(f"  [{n}/{len(generics)}] {generic}", file=sys.stderr)
        label = newest_label(generic)
        if label:
            records.append(record(generic, label))

    out = KB / "drugs.jsonl"
    write_jsonl(out, records)
    print(f"wrote {len(records)} drugs to {out.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()

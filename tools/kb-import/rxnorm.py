#!/usr/bin/env python3
"""Normalizes knowledge-base/drugs.jsonl to RxNorm and adds what each drug treats.

Output: knowledge-base/rxnorm.jsonl, one row per drug: ingredient RXCUI(s), brand names, FDA drug
classes (EPC/MOA) and MED-RT relations (may_treat, may_prevent, contraindicated with). Grading can
then check a student's plan in code: a drug the student names, normalized by RxNorm, either may
treat the case's condition or not.

RxNav needs no key; NLM asks for at most 20 requests a second and caching, which cached_json does.
Sources used are US government (RxNorm names, FDA SPL classes, VA MED-RT). WHO ATC classes are
deliberately not pulled: ATC needs WHO permission for commercial use.

    python3 rxnorm.py              # all drugs in drugs.jsonl
    python3 rxnorm.py --limit 10   # quick trial
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse

from common import KB, ROOT, cached_json, slug, write_jsonl

API = "https://rxnav.nlm.nih.gov/REST"
DELAY = 0.06
MEDRT_RELAS = ("may_treat", "may_prevent", "ci_with")


def get(cache_key: str, path: str, params: dict | None = None) -> dict:
    query = "?" + urllib.parse.urlencode(params) if params else ""
    return cached_json(f"rx-{cache_key}", f"{API}{path}{query}", DELAY, missing={})


def rxcui_for(name: str) -> str | None:
    """RxNorm concept for a drug name: exact match first, then normalized."""
    data = get(f"name-{slug(name)}", "/rxcui.json", {"name": name, "search": 2})
    ids = data.get("idGroup", {}).get("rxnormId", [])
    if ids:
        return ids[0]
    approx = get(f"approx-{slug(name)}", "/approximateTerm.json", {"term": name, "maxEntries": 1})
    candidates = approx.get("approximateGroup", {}).get("candidate", [])
    return candidates[0]["rxcui"] if candidates else None


def related(rxcui: str) -> dict[str, list[dict]]:
    """Ingredients (IN, MIN) and brands (BN) for a concept."""
    data = get(f"related-{rxcui}", f"/rxcui/{rxcui}/related.json", {"tty": "IN MIN BN"})
    groups = data.get("relatedGroup", {}).get("conceptGroup", [])
    return {g["tty"]: [{"rxcui": c["rxcui"], "name": c["name"]} for c in g.get("conceptProperties", [])] for g in groups}


def classes(rxcui: str, source: str, relas: str | None = None) -> list[dict]:
    params = {"rxcui": rxcui, "relaSource": source} | ({"relas": relas} if relas else {})
    data = get(f"class-{source}-{relas or 'all'}-{rxcui}", "/rxclass/class/byRxcui.json", params)
    seen, out = set(), []
    for info in data.get("rxclassDrugInfoList", {}).get("rxclassDrugInfo", []):
        item = info["rxclassMinConceptItem"]
        entry = (info.get("rela", ""), item["className"])
        if entry not in seen:
            seen.add(entry)
            out.append({"relation": info.get("rela", ""), "class": item["className"],
                        "class_id": item["classId"], "type": item.get("classType", "")})
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()

    drugs = [json.loads(line) for line in (KB / "drugs.jsonl").open()][: args.limit]
    rows, missing = [], []
    for n, drug in enumerate(drugs, 1):
        name = drug["generic_name"]
        rxcui = rxcui_for(name)
        if not rxcui:
            missing.append(name)
            print(f"  [{n}/{len(drugs)}] {name}: not found", file=sys.stderr)
            continue
        rel = related(rxcui)
        ingredients = rel.get("IN", []) or rel.get("MIN", [])
        # Classes and indications attach to the ingredient, not the salt or product.
        targets = [i["rxcui"] for i in ingredients] or [rxcui]
        fda = [c for t in targets for c in classes(t, "FDASPL")]
        medrt = [c for t in targets for c in classes(t, "MEDRT", " ".join(MEDRT_RELAS))]
        rows.append({
            "generic_name": name,
            "rxcui": rxcui,
            "ingredients": ingredients,
            "brands": sorted({b["name"] for b in rel.get("BN", [])})[:20],
            "fda_classes": [c for c in fda if c["type"] in ("EPC", "MOA", "PE")],
            "may_treat": sorted({c["class"] for c in medrt if c["relation"] == "may_treat"}),
            "may_prevent": sorted({c["class"] for c in medrt if c["relation"] == "may_prevent"}),
            "contraindicated_with": sorted({c["class"] for c in medrt if c["relation"] == "ci_with"}),
            "source": "RxNorm and RxClass (NLM RxNav): RxNorm, FDA SPL and VA MED-RT. Public US government data.",
        })
        print(f"  [{n}/{len(drugs)}] {name}: {len(rows[-1]['may_treat'])} indication(s)", file=sys.stderr)

    out = KB / "rxnorm.jsonl"
    write_jsonl(out, rows)
    print(f"wrote {len(rows)}/{len(drugs)} drugs to {out.relative_to(ROOT)}"
          f" ({sum(bool(r['may_treat']) for r in rows)} with indications)", file=sys.stderr)
    if missing:
        print(f"not found in RxNorm: {', '.join(missing[:20])}", file=sys.stderr)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Adds the core conditions MedlinePlus doesn't cover, using the NLM Clinical Tables conditions list.

conditions.jsonl comes from MedlinePlus health topics, which lump or skip many hospital diagnoses
(DKA, preeclampsia, intussusception). For each core condition (core_conditions.json) not already in
it, this finds the condition in the Clinical Tables conditions dataset (Regenstrief, ~2,400
conditions with ICD-10-CM codes and synonyms), confirms it as a SNOMED CT disorder through UMLS,
attaches its MeSH descriptor (definition, organ system, look-alikes) and, when Clinical Tables links
one, the broader MedlinePlus topic's summary. Records match conditions.jsonl's shape so the profile
generator reads both files.

Sources:
  - Clinical Tables conditions download (bulk JSON, no key): names, synonyms, ICD-10-CM.
  - UMLS (UMLS_API_KEY): verification only; no SNOMED wording is written.
  - MeSH descriptors: public domain.

Outputs:
  - knowledge-base/conditions_core.jsonl: the added conditions.
  - knowledge-base/licensed/clinical_tables_conditions.jsonl: the full condition list, for lookups.
    Kept out of git until Regenstrief's terms for redistribution are confirmed.

    python3 tools/kb-import/clinical_tables.py
"""

from __future__ import annotations

import json
import re
import sys
import zipfile

from build_kb import condition_kind, is_condition, load_mesh, organ_systems, parent_tree
from common import CACHE, KB, ROOT, cached_download, slug
from coverage_gaps import CORE, norm
from snomed import concept, icd10cm, key

DOWNLOAD = "https://clinicaltables.nlm.nih.gov/ctss-downloads/cond_proc_download-{date}.json.zip"
DOWNLOAD_DATE = "2026-10-01"
OUT = KB / "conditions_core.jsonl"
FULL_LIST = KB / "licensed" / "clinical_tables_conditions.jsonl"


def load_clinical_tables() -> list[dict]:
    """Conditions only (the download also holds procedures)."""
    path = cached_download(DOWNLOAD.format(date=DOWNLOAD_DATE), f"ct_conditions_{DOWNLOAD_DATE}.zip")
    with zipfile.ZipFile(path) as z:
        rows = json.loads(z.read(z.namelist()[0]))
    return [r for r in rows if not r["is_procedure"]]


def names_of(row: dict) -> list[str]:
    return [row["primary_name"], row["consumer_name"], *(row.get("synonyms") or [])]


def mesh_index(mesh: dict[str, dict]) -> dict[str, str]:
    """Normalized descriptor name or entry term → descriptor UI, disease descriptors only."""
    index: dict[str, str] = {}
    for ui, d in mesh.items():
        if is_condition(d["trees"]):
            for name in [d["name"], *d["entry_terms"]]:
                index.setdefault(norm(name), ui)
    return index


def uninvert(name: str) -> str:
    """'Hemorrhage - postpartum' → 'postpartum Hemorrhage' (Clinical Tables writes some names inverted)."""
    head, sep, tail = name.partition(" - ")
    return f"{tail} {head}" if sep else name


def linked_topics(row: dict | None) -> list[str]:
    """MedlinePlus pages Clinical Tables links to a condition, as conditions.jsonl spells their URLs."""
    links = (row or {}).get("info_link_data") or []
    return [url.rstrip("/").replace("http://www.nlm.nih.gov/medlineplus", "https://medlineplus.gov") for url, _ in links]


def umbrella_condition_ids() -> set[str]:
    """Condition ids of topics tagged as umbrellas, mapped through triage's slugs."""
    umbrellas = KB / "umbrellas.jsonl"
    if not umbrellas.exists():
        return set()
    slugs = {r["slug"] for r in map(json.loads, umbrellas.read_text().splitlines()) if r.get("umbrella")}
    return {t["condition_id"] for t in map(json.loads, (KB / "triage.jsonl").read_text().splitlines())
            if t.get("slug") in slugs and t.get("condition_id")}


def main() -> None:
    key()
    rows = load_clinical_tables()
    FULL_LIST.parent.mkdir(parents=True, exist_ok=True)
    FULL_LIST.write_text("".join(json.dumps({
        "key_id": r["key_id"], "name": r["primary_name"], "consumer_name": r["consumer_name"],
        "synonyms": r.get("synonyms") or [], "icd10cm": r.get("icd10cm") or [],
    }, ensure_ascii=False) + "\n" for r in rows))

    by_name: dict[str, dict] = {}
    for r in rows:
        for n in names_of(r):
            by_name.setdefault(norm(n), r)
            by_name.setdefault(norm(uninvert(n)), r)

    existing = [json.loads(line) for line in (KB / "conditions.jsonl").open()]
    # A condition is already covered when a topic is that condition: its name or alias, or its only
    # MeSH heading. A broad topic listing it among several headings ("Eating Disorders" with Bulimia
    # Nervosa) doesn't count, or umbrellas swallow the specific conditions students should practise.
    # Umbrella topics (tools/kb-generate/tag_umbrellas.py) list their subtypes as aliases ("Eating
    # Disorders": "Anorexia nervosa", "Bulimia"); only an umbrella's own name counts as covered.
    umbrella_ids = umbrella_condition_ids()
    umbrella_names = {norm(c["name"]) for c in existing if c["id"] in umbrella_ids}
    known = {norm(n) for c in existing
             for n in ([c["name"]] if c["id"] in umbrella_ids
                       else [c["name"], *c["also_called"], *(m["name"] for m in c["mesh"] if len(c["mesh"]) == 1)])}
    by_medlineplus = {c["source"]["medlineplus_url"].rstrip("/"): c for c in existing}

    print("MeSH descriptors…", file=sys.stderr)
    mesh = load_mesh(2026)
    mesh_by_name = mesh_index(mesh)
    # Conditions under the same MeSH parent are look-alikes, as in build_kb/assemble.py.
    by_parent: dict[str, set[str]] = {}
    for c in existing:
        for m in c["mesh"]:
            for tree in m["trees"]:
                by_parent.setdefault(parent_tree(tree), set()).add(c["name"])

    records, unmatched = [], []
    added: set[str] = set()
    for clerkship, items in json.loads(CORE.read_text())["clerkships"].items():
        for names in items:
            name = names[0]
            # A condition can sit under two specialties (iron deficiency anemia: internal medicine and
            # nutrition); it is imported once.
            # An alias can be the broad topic the condition sits under ("Generalized anxiety disorder",
            # alias "anxiety"): aliases that name an umbrella don't count as covered.
            if any(norm(n) in known and norm(n) not in umbrella_names for n in names) or norm(name) in added:
                continue
            ct = next((by_name[norm(n)] for n in names if norm(n) in by_name), None)
            snomed = next((c for n in names if (c := concept(n))), None)
            if not ct and not snomed:
                unmatched.append(name)
                continue
            synonyms = list(dict.fromkeys(s for s in [*names[1:], *(names_of(ct) if ct else [])]
                                          if norm(s) != norm(name)))
            descriptor_ui = next((mesh_by_name[norm(n)] for n in [name, *synonyms] if norm(n) in mesh_by_name), None)
            descriptors = [mesh[descriptor_ui] | {"ui": descriptor_ui}] if descriptor_ui else []
            trees = [t for d in descriptors for t in d["trees"]]
            codes = (ct.get("icd10cm") or []) if ct else []
            if not codes and snomed:
                codes = icd10cm(snomed["code"])
            broader = [by_medlineplus[u] for u in linked_topics(ct) if u in by_medlineplus]
            siblings = sorted({s for tree in trees for s in by_parent.get(parent_tree(tree), ())})
            summary = " ".join(f"(Broader MedlinePlus topic: {b['name']}) {b['summary']}" for b in broader[:1])
            added.add(norm(name))
            records.append({
                "id": f"ct-{ct['key_id']}" if ct else f"core-{slug(name)}",
                "name": name,
                "kind": condition_kind(trees) if trees else "disease",
                "also_called": synonyms[:8],
                "organ_systems": organ_systems(trees),
                "mesh": [{"ui": d["ui"], "name": d["name"], "trees": d["trees"],
                          "scope_note": d["scope_note"], "entry_terms": d["entry_terms"]} for d in descriptors],
                "icd10cm_candidates": [{"code": c["code"], "name": c.get("name", "")} for c in codes][:5],
                "summary": summary,
                "related_topics": [b["name"] for b in broader],
                "differential_seeds": siblings[:15],
                "references": {"reviews": [], "case_reports": []},
                "clerkship": clerkship,
                "source": {
                    "clinical_tables_key_id": ct["key_id"] if ct else None,
                    "snomed_verified": bool(snomed),
                    "license": "Names and synonyms: NLM Clinical Tables (Regenstrief). MeSH and MedlinePlus: public domain (NLM). "
                               "SNOMED CT used for verification only.",
                },
            })
            print(f"  {name}: {'Clinical Tables' if ct else 'UMLS only'}"
                  f"{', MeSH ' + descriptors[0]['name'] if descriptors else ''}", file=sys.stderr)

    OUT.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in records))
    print(f"wrote {len(records)} conditions to {OUT.relative_to(ROOT)}; "
          f"{len(rows)} to {FULL_LIST.relative_to(ROOT)}", file=sys.stderr)
    if unmatched:
        print(f"not found anywhere: {', '.join(unmatched)}", file=sys.stderr)


if __name__ == "__main__":
    main()

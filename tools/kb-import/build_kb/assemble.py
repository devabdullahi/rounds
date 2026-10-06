"""Joins the sources into condition records and writes knowledge-base/conditions.jsonl.

This is the only module that decides record shape and writes output; the sources only fetch and
parse, and mapping.py holds the classification rules.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from common import CACHE, KB, ROOT

from .mapping import condition_kind, is_condition, organ_systems, parent_tree
from .sources.icd10 import icd10_candidates
from .sources.medlineplus import load_topics
from .sources.mesh import load_mesh
from .sources.pubmed import pubmed_ids, pubmed_summaries

OUT = KB / "conditions.jsonl"

LICENSE = "MedlinePlus summary and MeSH: public domain (NLM). PubMed: citation metadata only."


def select_conditions(topics: list[dict], mesh: dict[str, dict]) -> list[tuple[dict, list[dict], list[str]]]:
    """Keeps topics whose MeSH descriptors are diseases or mental disorders, as
    (topic, descriptors, tree numbers) in MedlinePlus order."""
    conditions = []
    for topic in topics:
        descriptors = [mesh[i] | {"ui": i} for i in topic["mesh_ids"] if i in mesh]
        trees = [t for d in descriptors for t in d["trees"]]
        if descriptors and is_condition(trees):
            conditions.append((topic, descriptors, trees))
    return conditions


def titles_by_parent(conditions: list[tuple[dict, list[dict], list[str]]]) -> dict[str, set[str]]:
    """Conditions under the same MeSH parent are natural differentials for one another."""
    by_parent: dict[str, set[str]] = {}
    for topic, _, trees in conditions:
        for tree in trees:
            by_parent.setdefault(parent_tree(tree), set()).add(topic["title"])
    return by_parent


def condition_record(r: dict, by_parent: dict[str, set[str]], summaries: dict[str, dict]) -> dict:
    """Shapes one fetched condition into its conditions.jsonl line. Key order is the file format."""
    t = r["topic"]
    siblings = sorted({s for tree in r["trees"] for s in by_parent.get(parent_tree(tree), ())} - {t["title"]})
    return {
        "id": f"mplus-{t['id']}",
        "name": t["title"],
        "kind": condition_kind(r["trees"]),
        "also_called": t["also_called"],
        "organ_systems": organ_systems(r["trees"]),
        "mesh": [{"ui": d["ui"], "name": d["name"], "trees": d["trees"],
                  "scope_note": d["scope_note"], "entry_terms": d["entry_terms"]}
                 for d in r["descriptors"]],
        "icd10cm_candidates": r["icd10cm_candidates"],
        "summary": t["summary"],
        "related_topics": t["related"],
        "differential_seeds": siblings[:15],
        "references": {
            "reviews": [summaries[p] for p in r["reviews"] if p in summaries],
            "case_reports": [summaries[p] for p in r["case_reports"] if p in summaries],
        },
        "source": {
            "medlineplus_url": t["url"],
            "medlineplus_date": t["source_date"],
            "institute": t["institute"],
            "license": LICENSE,
        },
    }


def build(limit: int | None, mesh_year: int, out: Path = OUT) -> None:
    """Fetches every source (cached), then writes one JSON line per condition to `out`."""
    CACHE.mkdir(parents=True, exist_ok=True)
    print("MedlinePlus topics…", file=sys.stderr)
    topics = load_topics()
    print("MeSH descriptors…", file=sys.stderr)
    mesh = load_mesh(mesh_year)

    conditions = select_conditions(topics, mesh)
    if limit:
        conditions = conditions[:limit]
    print(f"{len(conditions)} conditions of {len(topics)} English topics", file=sys.stderr)

    # Differentials come from the selected set only, so a --limit trial has fewer of them.
    by_parent = titles_by_parent(conditions)

    records = []
    for n, (topic, descriptors, trees) in enumerate(conditions, 1):
        primary = descriptors[0]
        print(f"  [{n}/{len(conditions)}] {topic['title']}", file=sys.stderr)
        reviews = pubmed_ids(primary["name"], "review", 5)
        case_reports = pubmed_ids(primary["name"], "case reports", 5)
        records.append({
            "topic": topic, "descriptors": descriptors, "trees": trees,
            "reviews": reviews, "case_reports": case_reports,
            "icd10cm_candidates": icd10_candidates(topic["title"], primary["name"]),
        })

    summaries = pubmed_summaries(sorted({p for r in records for p in r["reviews"] + r["case_reports"]}))

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w") as f:
        for r in records:
            f.write(json.dumps(condition_record(r, by_parent, summaries), ensure_ascii=False) + "\n")
    shown = out.relative_to(ROOT) if out.is_relative_to(ROOT) else out
    print(f"wrote {len(records)} conditions to {shown}", file=sys.stderr)

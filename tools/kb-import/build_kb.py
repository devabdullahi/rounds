#!/usr/bin/env python3
"""Builds the Rounds case-authoring knowledge base from public-domain NLM sources.

Output: knowledge-base/conditions.jsonl, one condition per line, for drafting fictional cases.
Authoring only: this file must never be given to the patient LLM (it would leak the diagnosis).

Sources, all official bulk files or APIs (no page scraping):
  - MedlinePlus health topics XML: NLM-written summaries, public domain.
  - MeSH descriptors XML: tree numbers (organ system) and scope notes, public domain.
  - NLM Clinical Tables ICD-10-CM API: candidate codes, matched by name, so review before use.
  - PubMed E-utilities: PMIDs and titles of free-full-text reviews and case reports. Metadata only;
    abstracts and article text belong to publishers and are not stored.

Standard library only. Downloads are cached in tools/kb-import/.cache (git-ignored), so re-runs only
redo the API lookups that are missing from the cache.

    python3 tools/kb-import/build_kb.py            # full build
    python3 tools/kb-import/build_kb.py --limit 20 # quick trial
"""

from __future__ import annotations

import argparse
import gzip
import html
import json
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET

from common import CACHE, KB, ROOT, cached_download, cached_json, fetch, slug, strip_html

OUT = KB / "conditions.jsonl"

MEDLINEPLUS_INDEX = "https://medlineplus.gov/xml.html"
MESH_DESCRIPTORS = "https://nlmpubs.nlm.nih.gov/projects/mesh/MESH_FILES/xmlmesh/desc{year}.gz"
ICD10CM_SEARCH = "https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search"
EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# NCBI asks callers to identify their tool and stay under 3 requests a second without an API key.
NCBI_TOOL = "rounds-kb"
NCBI_DELAY = 0.4

# MeSH tree prefixes mapped to the app's OrganSystem raw values (Model/StudyFocus.swift).
# Longest prefix wins, so the pregnancy and kidney branches beat their broader parents.
ORGAN_SYSTEM_BY_TREE = {
    "C14": "cardiovascular",
    "C08": "respiratory",
    "C06": "gastrointestinal",
    "C12": "renal",
    "C12.200": "renal",          # urologic and male genital
    "C12.100": "reproductive",   # female urogenital
    "C12.800": "reproductive",   # male genital
    "C13": "reproductive",       # female urogenital and pregnancy complications
    "C10": "nervous",
    "C19": "endocrine",
    "C18": "endocrine",          # nutritional and metabolic
    "C15": "blood",
    "C20": "blood",              # immune
    "C05": "musculoskeletal",
    "C17": "musculoskeletal",    # skin and connective tissue
    "F03": "behavioral",
}

# Only disease and mental-disorder descriptors make a case; wellness and procedure topics don't.
CONDITION_TREE_ROOTS = ("C", "F03")


# MARK: - Pure helpers

def organ_systems(tree_numbers: list[str]) -> list[str]:
    """Maps MeSH tree numbers to OrganSystem raw values, keeping first-seen order."""
    found: list[str] = []
    for tree in tree_numbers:
        best = max((p for p in ORGAN_SYSTEM_BY_TREE if tree == p or tree.startswith(p + ".")),
                   key=len, default=None)
        if best and ORGAN_SYSTEM_BY_TREE[best] not in found:
            found.append(ORGAN_SYSTEM_BY_TREE[best])
    return found


def is_condition(tree_numbers: list[str]) -> bool:
    return any(t.startswith(CONDITION_TREE_ROOTS) for t in tree_numbers)


def condition_kind(tree_numbers: list[str]) -> str:
    """'symptom' when every disease tree sits under C23 (signs and symptoms), so a generator can use
    it as a presenting complaint rather than a hidden diagnosis."""
    disease_trees = [t for t in tree_numbers if t.startswith(CONDITION_TREE_ROOTS)]
    return "symptom" if all(t.startswith("C23.888") for t in disease_trees) else "disease"


def icd_search_terms(title: str, mesh_name: str) -> list[str]:
    """'Alcohol Use Disorder (AUD)' → 'Alcohol Use Disorder'; 'Diabetes Mellitus, Type 2' → 'Type 2 Diabetes Mellitus'."""
    plain = re.sub(r"\s*\([^)]*\)", "", title).strip()
    head, _, tail = mesh_name.partition(", ")
    uninverted = f"{tail} {head}" if tail else mesh_name
    return list(dict.fromkeys([plain, uninverted, mesh_name]))


def parent_tree(tree: str) -> str:
    return tree.rsplit(".", 1)[0] if "." in tree else tree


# MARK: - Sources

def latest_topics_url() -> str:
    page = fetch(MEDLINEPLUS_INDEX).decode()
    match = re.search(r'href="(https://medlineplus\.gov/xml/mplus_topics_\d{4}-\d{2}-\d{2}\.xml)"', page)
    if not match:
        raise RuntimeError("MedlinePlus XML index changed; no topics file found")
    return match.group(1)


def load_topics() -> list[dict]:
    url = latest_topics_url()
    root = ET.parse(cached_download(url, url.rsplit("/", 1)[1])).getroot()
    topics = []
    for t in root.iter("health-topic"):
        if t.get("language") != "English":
            continue
        topics.append({
            "id": t.get("id"),
            "title": t.get("title"),
            "url": t.get("url"),
            "summary": strip_html(t.findtext("full-summary") or ""),
            "also_called": [a.text for a in t.findall("also-called") if a.text],
            "groups": [g.text for g in t.findall("group") if g.text],
            "mesh_ids": [d.get("id") for d in t.findall("mesh-heading/descriptor")],
            "related": [r.text for r in t.findall("related-topic") if r.text],
            "institute": t.findtext("primary-institute"),
            "source_date": root.get("date-generated"),
        })
    return topics


def load_mesh(year: int) -> dict[str, dict]:
    path = cached_download(MESH_DESCRIPTORS.format(year=year), f"desc{year}.gz")
    mesh: dict[str, dict] = {}
    with gzip.open(path) as f:
        for _, el in ET.iterparse(f):
            if el.tag != "DescriptorRecord":
                continue
            ui = el.findtext("DescriptorUI")
            mesh[ui] = {
                "name": el.findtext("DescriptorName/String"),
                "trees": [t.text for t in el.findall("TreeNumberList/TreeNumber")],
                "scope_note": re.sub(r"\s+", " ", el.findtext("ConceptList/Concept/ScopeNote") or "").strip(),
                "entry_terms": [t.text for t in el.findall("ConceptList/Concept/TermList/Term/String")][1:12],
            }
            el.clear()
    return mesh


def icd10_candidates(title: str, mesh_name: str) -> list[dict]:
    """Tries the plain title first; the API ranks inverted MeSH names ("Diabetes Mellitus, Type 2")
    badly or finds nothing, so those come after, uninverted and then as-is."""
    for name in icd_search_terms(title, mesh_name):
        query = urllib.parse.urlencode({"sf": "code,name", "terms": name, "maxList": 5})
        data = cached_json(f"icd-{slug(name)}", f"{ICD10CM_SEARCH}?{query}", delay=0.1)
        if data[3]:
            return [{"code": c, "name": n} for c, n in data[3]]
    return []


def pubmed_ids(mesh_name: str, publication_type: str, count: int) -> list[str]:
    term = f'"{mesh_name}"[majr] AND {publication_type}[pt] AND free full text[sb] AND english[la]'
    query = urllib.parse.urlencode({
        "db": "pubmed", "term": term, "retmax": count, "sort": "relevance",
        "retmode": "json", "tool": NCBI_TOOL,
    })
    data = cached_json(f"pm-{publication_type.replace(' ', '')}-{slug(mesh_name)}",
                       f"{EUTILS}/esearch.fcgi?{query}", delay=NCBI_DELAY)
    return data["esearchresult"]["idlist"]


def pubmed_summaries(pmids: list[str]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for start in range(0, len(pmids), 200):
        batch = pmids[start:start + 200]
        query = urllib.parse.urlencode({"db": "pubmed", "id": ",".join(batch), "retmode": "json", "tool": NCBI_TOOL})
        data = cached_json(f"pmsum-{batch[0]}-{len(batch)}", f"{EUTILS}/esummary.fcgi?{query}", delay=NCBI_DELAY)
        for pmid in batch:
            doc = data["result"].get(pmid)
            if doc:
                out[pmid] = {
                    "pmid": pmid,
                    "title": html.unescape(doc.get("title", "")),
                    "journal": doc.get("source"),
                    "year": (doc.get("pubdate") or "")[:4],
                    "url": f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/",
                }
    return out


# MARK: - Build

def build(limit: int | None, mesh_year: int) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    print("MedlinePlus topics…", file=sys.stderr)
    topics = load_topics()
    print("MeSH descriptors…", file=sys.stderr)
    mesh = load_mesh(mesh_year)

    conditions = []
    for topic in topics:
        descriptors = [mesh[i] | {"ui": i} for i in topic["mesh_ids"] if i in mesh]
        trees = [t for d in descriptors for t in d["trees"]]
        if descriptors and is_condition(trees):
            conditions.append((topic, descriptors, trees))
    if limit:
        conditions = conditions[:limit]
    print(f"{len(conditions)} conditions of {len(topics)} English topics", file=sys.stderr)

    # Conditions under the same MeSH parent are natural differentials for one another.
    by_parent: dict[str, set[str]] = {}
    for topic, _, trees in conditions:
        for tree in trees:
            by_parent.setdefault(parent_tree(tree), set()).add(topic["title"])

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

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w") as f:
        for r in records:
            t = r["topic"]
            siblings = sorted({s for tree in r["trees"] for s in by_parent.get(parent_tree(tree), ())} - {t["title"]})
            f.write(json.dumps({
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
                    "license": "MedlinePlus summary and MeSH: public domain (NLM). PubMed: citation metadata only.",
                },
            }, ensure_ascii=False) + "\n")
    print(f"wrote {len(records)} conditions to {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, help="only build the first N conditions (for trials)")
    parser.add_argument("--mesh-year", type=int, default=2026)
    args = parser.parse_args()
    build(args.limit, args.mesh_year)

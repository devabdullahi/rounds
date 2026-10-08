#!/usr/bin/env python3
"""Maps every symptom, sign and exam finding in the condition profiles to a SNOMED CT concept.

Step one of replacing free-text symptoms with SNOMED: it measures how many of today's profile
phrases are real SNOMED findings, and records the concept (code, fully specified name, synonyms)
for each one that is. Nothing in the profiles changes yet.

Output (git-ignored, SNOMED content isn't redistributable):
  knowledge-base/licensed/finding_snomed.jsonl   one row per distinct phrase
  printed summary                                coverage by match quality

    python3 snomed_findings.py              # all profiles
    python3 snomed_findings.py --limit 3    # first 3 profiles, for a trial
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter

from common import KB, ROOT, slug, write_jsonl
from snomed import atoms, get, key

# Semantic tags that can describe something a patient has or a clinician finds.
FINDING_TAGS = ("(finding)", "(disorder)", "(observable entity)")
CANDIDATES = 3
# Word-overlap needed to accept a loose ("words") match; exact and normalized matches always count.
MIN_OVERLAP = 0.6
STOPWORDS = {"a", "an", "the", "of", "or", "and", "with", "in", "on", "to", "at", "for", "from", "that", "is", "be"}


def phrases(profile: dict) -> list[tuple[str, str]]:
    """(kind, phrase) for every finding-like text in a profile."""
    out: list[tuple[str, str]] = []
    p = profile.get("presentation", {})
    hpi = p.get("hpi", {})
    out += [("symptom", s["text"]) for s in hpi.get("associated_symptoms", [])]
    out += [("negative", t) for t in hpi.get("pertinent_negatives", [])]
    for ros in p.get("ros", []):
        out += [("symptom", s["text"]) for s in ros.get("positives", [])]
        out += [("negative", t) for t in ros.get("negatives", [])]
    out += [("exam", f["finding"]) for f in profile.get("exam", {}).get("findings", [])]
    return out


def words(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9]+", text.lower()) if w not in STOPWORDS}


def overlap(a: str, b: str) -> float:
    wa, wb = words(a), words(b)
    return len(wa & wb) / len(wa | wb) if wa and wb else 0.0


# Context the profiles add after the finding itself ("…on the face", "…after drinking").
TRAILING = re.compile(r"\s+(?:on|in|at|after|before|when|while|during|with|without|that|which|from|over|around|where)\s.*$", re.I)


def variants(phrase: str) -> list[str]:
    """The phrase, then its parts: split on 'or'/commas/dashes/parentheses, trailing context dropped."""
    base = re.sub(r"\([^)]*\)", "", phrase).split("—")[0].split(";")[0]
    parts = [p.strip(" .") for p in re.split(r",|\bor\b|\band\b|/", base) if p.strip(" .")]
    out = [phrase, base.strip()]
    for part in parts:
        out += [part, TRAILING.sub("", part).strip()]
    seen, unique = set(), []
    for v in out:
        key_ = v.lower()
        if len(words(v)) and key_ not in seen:
            seen.add(key_)
            unique.append(v)
    return unique


def lookup(phrase: str) -> dict | None:
    """The best SNOMED finding/disorder concept for a phrase or one of its parts, with how it matched."""
    for variant in variants(phrase):
        hit = lookup_one(variant)
        if hit:
            return hit | ({"matched_part": variant} if variant != phrase else {})
    return None


def lookup_one(phrase: str) -> dict | None:
    for search_type in ("exact", "normalizedString", "normalizedWords", "words"):
        data = get(f"search-{search_type}-{slug(phrase)}", "/search/current",
                   {"string": phrase, "sabs": "SNOMEDCT_US", "returnIdType": "code",
                    "searchType": search_type, "pageSize": 5})
        hits = [r for r in data["result"]["results"] if r.get("ui") and r["ui"] != "NONE"]
        for hit in hits[:CANDIDATES]:
            score = 1.0 if search_type in ("exact", "normalizedString") else overlap(phrase, hit["name"])
            if score < MIN_OVERLAP:
                continue
            terms = atoms(hit["ui"])
            fsn = next((a["name"] for a in terms if a.get("termType") == "FN"), "")
            if fsn.endswith(FINDING_TAGS):
                return {
                    "code": hit["ui"], "fsn": fsn, "preferred": hit["name"],
                    "synonyms": sorted({a["name"] for a in terms if a.get("termType") in ("PT", "SY")} - {fsn})[:12],
                    "match": search_type, "score": round(score, 2),
                }
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    key()

    profiles = [json.loads(p.read_text()) for p in sorted((KB / "profiles").glob("*.json"))]
    profiles = [p for p in profiles if p["generation"]["validation"]["status"] == "passed"][: args.limit]

    used_in: dict[str, dict] = {}
    for p in profiles:
        for kind, text in phrases(p):
            entry = used_in.setdefault(text.strip(), {"kinds": set(), "slugs": set()})
            entry["kinds"].add(kind)
            entry["slugs"].add(p["slug"])
    print(f"{len(used_in)} distinct phrases from {len(profiles)} profiles", file=sys.stderr)

    rows, quality = [], Counter()
    for n, (text, entry) in enumerate(sorted(used_in.items()), 1):
        concept = lookup(text)
        quality[concept["match"] if concept else "none"] += 1
        if concept and "matched_part" in concept:
            quality["via a part"] += 1
        rows.append({"phrase": text, "kinds": sorted(entry["kinds"]), "profiles": sorted(entry["slugs"]),
                     "snomed": concept})
        if n % 100 == 0:
            print(f"  {n}/{len(used_in)}", file=sys.stderr)

    out = KB / "licensed" / "finding_snomed.jsonl"
    write_jsonl(out, rows)
    total = len(rows)
    print(f"wrote {out.relative_to(ROOT)}", file=sys.stderr)
    for q in ("exact", "normalizedString", "normalizedWords", "words", "none"):
        print(f"  {q:16s} {quality[q]:5d}  ({quality[q] / total:.0%})", file=sys.stderr)
    print(f"  (of the matches, {quality['via a part']} came from a part of the phrase)", file=sys.stderr)


if __name__ == "__main__":
    main()

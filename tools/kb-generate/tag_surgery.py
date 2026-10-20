#!/usr/bin/env python3
"""Decides which case-suitable conditions belong to the Surgery rotation.

Triage gave each condition its rotations in one pass, and Surgery came out as a grab-bag: medical
conditions (GERD, fever, constipation) sat beside appendicitis, and urology and orthopedic problems
were filed there too. This asks one narrow question per condition: is it a core case on a US general
surgery clerkship? Output goes to knowledge-base/surgery.jsonl; load_conditions.py adds or removes
"surgery" from each condition's rotations to match, and moves a condition's primary rotation off
Surgery when it no longer belongs.

    python3 tag_surgery.py            # tag conditions not yet tagged
    python3 tag_surgery.py --retag    # tag every condition again and rewrite the file
    python3 tag_surgery.py --counts   # how the tags change Surgery (in, out, added)

A mock run (LLM_PROVIDER=mock) writes to KB_OUT or a temp folder, like generate.py.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import llm
import tagfile
from generate import OUT as OUT_DIR, SCHEMA, load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]

TAGS = ROOT / "knowledge-base" / "surgery.jsonl"  # what load_conditions.py reads
OUT = OUT_DIR / "surgery.jsonl"                   # where a run writes: TAGS, or scratch on a mock run
FIELD = "surgery"                                  # ["surgery"] when it belongs, [] when not
BATCH = 25
PROMPT_VERSION = "1"

SYSTEM = "You are a US general surgery clerkship director deciding which conditions students should practice on their surgery rotation. Reply with JSON only."

TEMPLATE = """For each condition below, decide whether it is a core case for a US third-year general surgery clerkship: a surgeon is the one who diagnoses it or decides whether to operate, and the surgery shelf exam expects students to work it up. That covers the acute abdomen, hepatobiliary and pancreatic disease, bowel and colorectal disease, hernias, breast and endocrine surgery, surgical oncology, trauma and burns, vascular emergencies and vascular disease, soft tissue surgical infections, and pediatric surgical problems.

Say no when the condition is managed mainly with medicines or lifestyle (for example GERD, constipation, fever, cirrhosis, acute kidney injury), or belongs to urology, orthopedics, ENT or neurosurgery rather than general surgery.

For a condition that is not a surgery case, also give the rotation that should own it instead, from: {rotations}.

Conditions:
{conditions}

Reply with JSON: {{"results": [{{"id": "<condition id>", "surgery": true or false, "owner": "<rotation id, only when surgery is false>"}}]}} with one entry per condition."""


# Reviewed corrections to the model's answers, applied over the tag file.
OVERRIDES: dict[str, bool] = {
    "collapsed-lung": True,   # chest tubes and traumatic pneumothorax are core surgery shelf material
    "lymphoma": False,        # an oncology diagnosis; surgery only does the biopsy
}


def rotations(triage: dict) -> list[str]:
    return [triage["primary_clerkship"], *triage.get("secondary_clerkships", [])]


def load_tags(path: Path = TAGS) -> dict[str, dict]:
    return tagfile.read_rows(path, FIELD)


def suitable() -> dict[str, dict]:
    return {s: t["triage"] for s, t in load_triage().items() if t.get("triage", {}).get("case_suitable") and not t.get("errors")}


def run(retag: bool = False) -> None:
    """Tags what's missing, appending as it goes. With `retag`, tags everything into a temp file
    that replaces the old one only when the run finishes, so a failed run loses nothing."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if not retag:
        tagfile.compact(OUT, FIELD)
    conditions, triage, done = load_conditions(), suitable(), ({} if retag else load_tags(OUT))
    todo = [s for s in triage if s not in done]
    target = OUT.with_name(OUT.name + ".tmp") if retag else OUT
    if retag:
        target.write_text("")
    choices = [r for r in SCHEMA["$defs"]["clerkship"]["enum"] if r != "surgery"]
    provider, model = llm.current()
    print(f"surgery: {len(todo)} to tag, {len(done)} done, model {provider}/{model}, writing {OUT}", file=sys.stderr)
    missed: list[str] = []
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        # Conditions added from UMLS aren't in the MedlinePlus list; triage's name stands in for them.
        rows = [{"id": s, "name": conditions[s]["name"] if s in conditions else triage[s]["name"],
                 "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:240] if s in conditions else ""}
                for s in batch]
        reply = llm.complete_json(SYSTEM, TEMPLATE.format(rotations=", ".join(choices), conditions=json.dumps(rows, ensure_ascii=False)))
        results = {r.get("id"): r for r in reply.get("results", []) if isinstance(r, dict)}
        with target.open("a") as f:
            for s in batch:
                r = results.get(s)
                if not r or not isinstance(r.get("surgery"), bool):  # left out of the reply: no row, so the next run retries it
                    missed.append(s)
                    continue
                row = {"slug": s, FIELD: ["surgery"] if r["surgery"] else []}
                if not r["surgery"] and r.get("owner") in choices:
                    row["owner"] = r["owner"]
                row["generation"] = {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)
    if retag:
        target.replace(OUT)
    if missed:
        print(f"{len(missed)} condition(s) missing from the replies, run again to retry: {', '.join(missed)}", file=sys.stderr)


def apply(slug: str, triage: dict, tags: dict[str, dict]) -> tuple[str, list[str]]:
    """The condition's primary rotation and rotation list with its Surgery tag applied. Untagged
    conditions keep triage's rotations."""
    primary, rest = triage["primary_clerkship"], list(triage.get("secondary_clerkships", []))
    row = tags.get(slug)
    if slug in OVERRIDES:
        row = {**(row or {}), FIELD: ["surgery"] if OVERRIDES[slug] else []}
    if row is None:
        return primary, rest
    if row[FIELD]:
        return primary, rest if primary == "surgery" or "surgery" in rest else [*rest, "surgery"]
    rest = [r for r in rest if r != "surgery"]
    if primary == "surgery":
        primary = row.get("owner") or (rest[0] if rest else "internalMedicine")
        rest = [r for r in rest if r != primary]
    return primary, rest


def retagged(slug: str, triage: dict, tags: dict[str, dict] | None = None) -> dict:
    """A copy of `triage` with its rotations corrected for Surgery. The loaders store this copy, so
    prepare-profile (which merges triage's rotations into a profile's) can't put Surgery back."""
    primary, rest = apply(slug, triage, load_tags() if tags is None else tags)
    return {**triage, "primary_clerkship": primary, "secondary_clerkships": rest}


def counts() -> None:
    tags, triage = load_tags(), suitable()
    before = {s for s, t in triage.items() if "surgery" in rotations(t)}
    after = {s for s, t in triage.items() if "surgery" in [apply(s, t, tags)[0], *apply(s, t, tags)[1]]}
    print(f"Surgery: {len(before)} before, {len(after)} after ({len(after - before)} added, {len(before - after)} removed)")
    for label, slugs in (("added", after - before), ("removed", before - after)):
        print(f"\n{label}:")
        for s in sorted(slugs):
            print(f"  {s}" + (f" → {tags[s].get('owner')}" if label == "removed" and tags[s].get("owner") else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--counts", action="store_true")
    parser.add_argument("--retag", action="store_true", help="tag every condition again and rewrite the file")
    args = parser.parse_args()
    counts() if args.counts else run(args.retag)

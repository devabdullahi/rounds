#!/usr/bin/env python3
"""Files each case-suitable condition under the organ systems students browse by.

Triage chose from ten systems, where skin shared "MSK & skin" and immune shared "Blood & immune",
so skin, eye, ENT and allergy conditions were squeezed into the nearest fit. This re-files every
case-suitable condition against the full list. MeSH (tools/kb-import/build_kb/mapping.py) is a hint
to the model and a floor: a new system MeSH implies is always kept. Output goes to
knowledge-base/systems.jsonl; load_conditions.py uses it in place of triage's organ_systems.

    python3 tag_systems.py                 # file conditions not yet filed (drops null rows first)
    python3 tag_systems.py --retag         # file every condition again and rewrite the file
    python3 tag_systems.py --counts        # case-suitable conditions per system
    python3 tag_systems.py --check-swift   # compare system ids with the app's OrganSystem enum

A mock run (LLM_PROVIDER=mock) writes to KB_OUT or a temp folder, like generate.py.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import llm
import swift_enums
import tagfile
from generate import OUT as OUT_DIR, load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "kb-import"))
from build_kb.mapping import organ_systems as mesh_systems  # noqa: E402

TAGS = ROOT / "knowledge-base" / "systems.jsonl"  # what load_conditions.py reads
OUT = OUT_DIR / "systems.jsonl"                   # where a run writes: TAGS, or scratch on a mock run
FIELD = "organ_systems"
MAX_SYSTEMS = 3  # matches the prompt's "at most three"; MeSH additions count toward it
BATCH = 25
PROMPT_VERSION = "1"

SYSTEMS: dict[str, str] = {
    "cardiovascular": "heart and blood vessels",
    "respiratory": "lungs and airways below the larynx",
    "gastrointestinal": "digestive tract, liver, gallbladder, pancreas",
    "renal": "kidneys and urinary tract",
    "nervous": "brain, spinal cord, nerves",
    "endocrine": "hormones, metabolism and nutrition",
    "blood": "blood cells, bleeding and clotting, blood cancers, and infections that are mainly systemic",
    "immune": "allergy, immunodeficiency, and autoimmune disease without one main organ",
    "musculoskeletal": "bones, joints, muscles, tendons and connective tissue",
    "skin": "skin, hair and nails",
    "eye": "eyes and vision",
    "ent": "ear, nose, sinuses, throat, mouth and voice",
    "reproductive": "reproductive organs, pregnancy and breast",
    "behavioral": "psychiatric conditions and substance use",
}
NEW = {"skin", "eye", "ent", "immune"}

SYSTEM_PROMPT = "You are a US physician filing medical conditions by the body system they mainly affect. Reply with JSON only."

TEMPLATE = """For each condition, list the body systems it mainly affects: usually one, at most three. Use the organ where the disease is, not the specialty that treats it (an infection goes under the organ it infects; a skin cancer under skin).

Systems (id: what belongs):
{systems}

Conditions (mesh_hint is the MeSH category's system, when there is one):
{conditions}

Reply with JSON: {{"results": [{{"id": "<condition id>", "systems": ["<system id>", ...]}}]}} with one entry per condition."""


def load_systems(path: Path = TAGS) -> dict[str, list[str]]:
    # Every condition has a body system, so an empty list is a failed reply, not an answer.
    return {slug: row[FIELD] for slug, row in tagfile.read_rows(path, FIELD, allow_empty=False).items()}


def suitable() -> list[str]:
    return [s for s, t in load_triage().items() if t.get("triage", {}).get("case_suitable") and not t.get("errors")]


def run(retag: bool = False) -> None:
    """Files what's missing, appending as it goes. With `retag`, files everything into a temp file
    that replaces the old one only when the run finishes, so a failed run loses nothing."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if not retag:
        tagfile.compact(OUT, FIELD, allow_empty=False)
    conditions, done = load_conditions(), ({} if retag else load_systems(OUT))
    todo = [s for s in suitable() if s not in done]
    target = OUT.with_name(OUT.name + ".tmp") if retag else OUT
    if retag:
        target.write_text("")
    provider, model = llm.current()
    print(f"systems: {len(todo)} to file, {len(done)} done, model {provider}/{model}, writing {OUT}", file=sys.stderr)
    missed: list[str] = []
    listing = "\n".join(f"{k}: {v}" for k, v in SYSTEMS.items())
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        hints = {s: mesh_systems([t for m in conditions[s]["mesh"] for t in m["trees"]]) for s in batch}
        rows = [{"id": s, "name": conditions[s]["name"], "mesh_hint": hints[s],
                 "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:200]}
                for s in batch]
        reply = llm.complete_json(SYSTEM_PROMPT, TEMPLATE.format(systems=listing, conditions=json.dumps(rows, ensure_ascii=False)))
        results = {r.get("id"): r.get("systems") for r in reply.get("results", [])}
        with target.open("a") as f:
            for s in batch:
                picked = [x for x in (results.get(s) or []) if x in SYSTEMS]
                if not picked:  # left out of the reply or no valid id: no row, so the next run retries it
                    missed.append(s)
                    continue
                # MeSH is the floor for the new systems: a skin disease is always filed under skin,
                # so the cap trims the model's extra picks, never the floor.
                floor = [x for x in hints[s] if x in NEW and x not in picked][:MAX_SYSTEMS]
                picked = picked[:MAX_SYSTEMS - len(floor)] + floor
                f.write(json.dumps({"slug": s, FIELD: picked,
                                    "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}},
                                   ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)
    if retag:
        target.replace(OUT)
    if missed:
        print(f"{len(missed)} condition(s) missing from the replies, run again to retry: {', '.join(missed)}", file=sys.stderr)
    check_swift()


def check_swift() -> int:
    return swift_enums.report("systems", set(SYSTEMS), set(SYSTEMS), swift_enums.ORGAN_SYSTEM)


def counts() -> None:
    filed = load_systems()
    tally = Counter(x for s in suitable() for x in filed.get(s, []))
    for k in SYSTEMS:
        print(f"{tally[k]:4}  {k}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--counts", action="store_true")
    parser.add_argument("--retag", action="store_true", help="file every condition again and rewrite the file")
    parser.add_argument("--check-swift", action="store_true", help="compare ids with OrganSystem.swift and exit")
    args = parser.parse_args()
    if args.check_swift:
        sys.exit(1 if check_swift() else 0)
    counts() if args.counts else run(args.retag)

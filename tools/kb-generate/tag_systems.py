#!/usr/bin/env python3
"""Files each case-suitable condition under the organ systems students browse by.

Triage chose from ten systems, where skin shared "MSK & skin" and immune shared "Blood & immune",
so skin, eye, ENT and allergy conditions were squeezed into the nearest fit. This re-files every
case-suitable condition against the full list. MeSH (tools/kb-import/build_kb/mapping.py) is a hint
to the model and a floor: a new system MeSH implies is always kept. Output goes to
knowledge-base/systems.jsonl; load_conditions.py uses it in place of triage's organ_systems.

    python3 tag_systems.py            # file conditions not yet filed
    python3 tag_systems.py --counts   # case-suitable conditions per system
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import llm
from generate import load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "kb-import"))
from build_kb.mapping import organ_systems as mesh_systems  # noqa: E402

OUT = ROOT / "knowledge-base" / "systems.jsonl"
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


def load_systems() -> dict[str, list[str]]:
    if not OUT.exists():
        return {}
    return {r["slug"]: r["organ_systems"] for r in map(json.loads, OUT.read_text().splitlines()) if r.get("organ_systems")}


def suitable() -> list[str]:
    return [s for s, t in load_triage().items() if t.get("triage", {}).get("case_suitable") and not t.get("errors")]


def run() -> None:
    conditions, done = load_conditions(), load_systems()
    todo = [s for s in suitable() if s not in done]
    provider, model = llm.current()
    print(f"systems: {len(todo)} to file, {len(done)} done, model {provider}/{model}", file=sys.stderr)
    listing = "\n".join(f"{k}: {v}" for k, v in SYSTEMS.items())
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        hints = {s: mesh_systems([t for m in conditions[s]["mesh"] for t in m["trees"]]) for s in batch}
        rows = [{"id": s, "name": conditions[s]["name"], "mesh_hint": hints[s],
                 "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:200]}
                for s in batch]
        reply = llm.complete_json(SYSTEM_PROMPT, TEMPLATE.format(systems=listing, conditions=json.dumps(rows, ensure_ascii=False)))
        results = {r.get("id"): r.get("systems") for r in reply.get("results", [])}
        with OUT.open("a") as f:
            for s in batch:
                picked = [x for x in (results.get(s) or []) if x in SYSTEMS]
                # MeSH is the floor for the new systems: a skin disease is always filed under skin.
                picked += [x for x in hints[s] if x in NEW and x not in picked]
                f.write(json.dumps({"slug": s, "organ_systems": picked[:4] or None,
                                    "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}},
                                   ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)


def counts() -> None:
    filed = load_systems()
    tally = Counter(x for s in suitable() for x in filed.get(s, []))
    for k in SYSTEMS:
        print(f"{tally[k]:4}  {k}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--counts", action="store_true")
    args = parser.parse_args()
    counts() if args.counts else run()

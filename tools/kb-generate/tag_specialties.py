#!/usr/bin/env python3
"""Tags each case-suitable condition with the specialties that manage it.

Specialties are study topics alongside the core rotations (triage's clerkships): a student who
picks Cardiology practices on conditions tagged here. Output goes to knowledge-base/specialties.jsonl,
one line per condition; load_conditions.py merges the tags into each condition's topic list.

    python3 tag_specialties.py                 # tag conditions not yet tagged (drops null rows first)
    python3 tag_specialties.py --retag         # tag every condition again and rewrite the file
    python3 tag_specialties.py --counts        # how many case-suitable conditions each specialty has
    python3 tag_specialties.py --check-swift   # compare specialty ids with the app's Clerkship enum

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
from generate import OUT as OUT_DIR, SCHEMA, load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]

TAGS = ROOT / "knowledge-base" / "specialties.jsonl"  # what load_conditions.py reads
OUT = OUT_DIR / "specialties.jsonl"                   # where a run writes: TAGS, or scratch on a mock run
FIELD = "specialties"
BATCH = 25
PROMPT_VERSION = "1"

# id: (name, what belongs). Ids are the stored topic values, like the clerkship ids.
SPECIALTIES: dict[str, tuple[str, str]] = {
    "cardiology": ("Cardiology & vascular", "heart disease, arrhythmias, heart failure, valve disease, hypertension emergencies, aortic and peripheral vascular disease, venous thromboembolism"),
    "allergyImmunology": ("Allergy & immunology", "allergic disease (anaphylaxis, food and drug allergy, allergic rhinitis, urticaria, allergic asthma) and primary immunodeficiencies"),
    "endocrinology": ("Endocrinology", "diabetes, thyroid, adrenal, pituitary, parathyroid and calcium disorders, endocrine tumors, metabolic bone disease"),
    "geriatrics": ("Geriatrics", "conditions mainly of older adults: dementia, delirium, falls, frailty, osteoporosis, Parkinson disease, incontinence, polypharmacy harms"),
    "hematologyOncology": ("Hematology/oncology", "anemias, bleeding and clotting disorders, blood cancers, and solid-tumor cancers managed medically"),
    "infectiousDisease": ("Infectious disease", "infections whose diagnosis or treatment is the core of the case: bacterial, viral, fungal, parasitic, sexually transmitted, tropical and travel infections"),
    "nephrology": ("Nephrology", "kidney disease: acute kidney injury, chronic kidney disease, glomerular disease, electrolyte and acid-base disorders"),
    "rheumatology": ("Rheumatology", "autoimmune and inflammatory joint and connective tissue disease, gout, vasculitis"),
    "ophthalmology": ("Ophthalmology", "eye and vision disorders"),
    "orthopedicSurgery": ("Orthopedic surgery", "fractures, dislocations, sports and joint injuries, spine and bone disorders"),
    "otolaryngology": ("Otolaryngology", "ear, nose, sinus, throat, voice and head and neck disorders"),
    "radiationOncology": ("Radiation oncology", "cancers where radiation is a main treatment"),
    "urology": ("Urology", "kidney stones, urinary tract and bladder disorders, prostate, testicular and male reproductive disorders, urologic cancers"),
    "neonatology": ("Neonatal/perinatal", "conditions of newborns and the perinatal period: prematurity, neonatal jaundice and infections, birth injuries, congenital anomalies found at birth"),
    "nutrition": ("Health nutrition", "nutritional deficiencies and excesses: malnutrition, vitamin and mineral deficiencies, obesity, eating-related metabolic problems"),
    "rehabilitation": ("Physical medicine & rehabilitation", "conditions whose care centers on recovering function: stroke and brain injury recovery, spinal cord injury, amputation, chronic musculoskeletal pain and disability"),
}

# Specialties students can pick today: enough case-suitable conditions to practice on (15 or more)
# and a fit for diagnosis practice. Held back: Radiation oncology (its cases would be the same
# cancers, and the app trains diagnosis, not radiation planning). Neonatal/perinatal and Health
# nutrition went live once UMLS-verified conditions were added (tools/kb-import/clinical_tables.py).
# load_conditions.py adds only these to each condition's topics.
LIVE = ["cardiology", "allergyImmunology", "endocrinology", "geriatrics", "hematologyOncology", "infectiousDisease",
        "nephrology", "rheumatology", "ophthalmology", "orthopedicSurgery", "otolaryngology", "urology", "rehabilitation",
        "neonatology", "nutrition"]

SYSTEM = "You are a US attending physician assigning medical conditions to the specialties that manage them. Reply with JSON only."

TEMPLATE = """For each condition below, list the specialties from this list whose physicians manage it as a core part of their practice. A condition may have none, one or several. Don't include a specialty that only sees it occasionally or only consults on it.

Specialties (id: name, what belongs):
{specialties}

Conditions:
{conditions}

Reply with JSON: {{"results": [{{"id": "<condition id>", "specialties": ["<specialty id>", ...]}}]}} with one entry per condition."""


def load_tags(path: Path = TAGS) -> dict[str, list[str]]:
    return {slug: row[FIELD] for slug, row in tagfile.read_rows(path, FIELD).items()}


def suitable() -> list[str]:
    return [s for s, t in load_triage().items() if t.get("triage", {}).get("case_suitable") and not t.get("errors")]


def run(retag: bool = False) -> None:
    """Tags what's missing, appending as it goes. With `retag`, tags everything into a temp file
    that replaces the old one only when the run finishes, so a failed run loses nothing."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if not retag:
        tagfile.compact(OUT, FIELD)
    conditions, done = load_conditions(), ({} if retag else load_tags(OUT))
    todo = [s for s in suitable() if s not in done]
    target = OUT.with_name(OUT.name + ".tmp") if retag else OUT
    if retag:
        target.write_text("")
    provider, model = llm.current()
    print(f"specialties: {len(todo)} to tag, {len(done)} done, model {provider}/{model}, writing {OUT}", file=sys.stderr)
    missed: list[str] = []
    listing = "\n".join(f"{k}: {name}, {scope}" for k, (name, scope) in SPECIALTIES.items())
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        rows = [{"id": s, "name": conditions[s]["name"],
                 "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:240]}
                for s in batch]
        reply = llm.complete_json(SYSTEM, TEMPLATE.format(specialties=listing, conditions=json.dumps(rows, ensure_ascii=False)))
        results = {r.get("id"): r.get("specialties") for r in reply.get("results", [])}
        with target.open("a") as f:
            for s in batch:
                tags = results.get(s)
                if not isinstance(tags, list):  # left out of the reply: no row, so the next run retries it
                    missed.append(s)
                    continue
                clean = sorted({t for t in tags if t in SPECIALTIES})
                f.write(json.dumps({"slug": s, FIELD: clean,
                                    "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}},
                                   ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)
    if retag:
        target.replace(OUT)
    if missed:
        print(f"{len(missed)} condition(s) missing from the replies, run again to retry: {', '.join(missed)}", file=sys.stderr)
    check_swift()


def check_swift() -> int:
    """Live specialties and triage rotations are what the app decodes into `Clerkship`."""
    rotations = set(SCHEMA["$defs"]["clerkship"]["enum"])
    return swift_enums.report("specialties", set(LIVE) | rotations, set(SPECIALTIES) | rotations, swift_enums.CLERKSHIP)


def counts() -> None:
    tags = load_tags()
    tally = Counter(t for s in suitable() for t in tags.get(s, []))
    for k, (name, _) in SPECIALTIES.items():
        print(f"{tally[k]:4}  {name} ({k})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--counts", action="store_true")
    parser.add_argument("--retag", action="store_true", help="tag every condition again and rewrite the file")
    parser.add_argument("--check-swift", action="store_true", help="compare ids with Clerkship.swift and exit")
    args = parser.parse_args()
    if args.check_swift:
        sys.exit(1 if check_swift() else 0)
    counts() if args.counts else run(args.retag)

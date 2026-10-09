#!/usr/bin/env python3
"""Tags each case-suitable condition with the specialties that manage it.

Specialties are study topics alongside the core rotations (triage's clerkships): a student who
picks Cardiology practices on conditions tagged here. Output goes to knowledge-base/specialties.jsonl,
one line per condition; load_conditions.py merges the tags into each condition's topic list.

    python3 tag_specialties.py            # tag conditions not yet tagged
    python3 tag_specialties.py --counts   # how many case-suitable conditions each specialty has
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter

import llm
from pathlib import Path

from generate import load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]

OUT = ROOT / "knowledge-base" / "specialties.jsonl"
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


def load_tags() -> dict[str, list[str]]:
    if not OUT.exists():
        return {}
    return {r["slug"]: r["specialties"] for r in map(json.loads, OUT.read_text().splitlines()) if r.get("specialties") is not None}


def suitable() -> list[str]:
    return [s for s, t in load_triage().items() if t.get("triage", {}).get("case_suitable") and not t.get("errors")]


def run() -> None:
    conditions, done = load_conditions(), load_tags()
    todo = [s for s in suitable() if s not in done]
    provider, model = llm.current()
    print(f"specialties: {len(todo)} to tag, {len(done)} done, model {provider}/{model}", file=sys.stderr)
    listing = "\n".join(f"{k}: {name}, {scope}" for k, (name, scope) in SPECIALTIES.items())
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        rows = [{"id": s, "name": conditions[s]["name"],
                 "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:240]}
                for s in batch]
        reply = llm.complete_json(SYSTEM, TEMPLATE.format(specialties=listing, conditions=json.dumps(rows, ensure_ascii=False)))
        results = {r.get("id"): r.get("specialties") for r in reply.get("results", [])}
        with OUT.open("a") as f:
            for s in batch:
                tags = results.get(s)
                clean = sorted({t for t in tags if t in SPECIALTIES}) if isinstance(tags, list) else None
                f.write(json.dumps({"slug": s, "specialties": clean,
                                    "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}},
                                   ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)


def counts() -> None:
    tags = load_tags()
    tally = Counter(t for s in suitable() for t in tags.get(s, []))
    for k, (name, _) in SPECIALTIES.items():
        print(f"{tally[k]:4}  {name} ({k})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--counts", action="store_true")
    args = parser.parse_args()
    counts() if args.counts else run()

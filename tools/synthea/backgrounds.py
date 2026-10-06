#!/usr/bin/env python3
"""Turns a Synthea population (CSV export) into compact patient backgrounds for generated cases.

A background is who the patient is before today's illness: age, sex, chronic conditions,
current medications (RxNorm), allergies, smoking status and social circumstances. The case
planner picks one that fits the condition; the writer voices it; the grader can check a plan
against the real med list. Everything is synthetic (Synthea), so no real patient data.

    java -jar .cache/synthea.jar -s 42 -p 1000 --exporter.baseDirectory=.cache/population \
        --exporter.fhir.export=false --exporter.hospital.fhir.export=false \
        --exporter.practitioner.fhir.export=false --exporter.csv.export=true \
        --exporter.years_of_history=10
    python3 backgrounds.py .cache/population/csv

Output: knowledge-base/licensed/synthetic_backgrounds.jsonl (one line per living patient; git-ignored).
"""

from __future__ import annotations

import csv
import json
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Synthea condition names are SNOMED CT wording, so the output stays in the git-ignored licensed folder.
OUT = ROOT / "knowledge-base" / "licensed" / "synthetic_backgrounds.jsonl"
REFERENCE_DATE = date.today()

SMOKING_LOINC = "72166-2"
# Synthea records social circumstances as findings; these become the patient's social history.
SOCIAL = re.compile(r"employment|education|educated|housing|stress|social isolation|limited social contact|"
                    r"unemployed|lack of access|transport|risk activity", re.I)
# Sensitive circumstances left out by default: dropped into an unrelated case they read as gratuitous.
SENSITIVE = re.compile(r"victim|abuse|violence|criminal|refugee|incarcerat", re.I)
# Bookkeeping and screening entries that aren't part of a patient's story.
SKIP = re.compile(r"medication review|review due|screening|(\(procedure\)|\(situation\))$", re.I)
TAG = re.compile(r"\s*\((disorder|finding|situation|procedure|morphologic abnormality)\)$", re.I)


def clean(description: str) -> str:
    """'Hypertension (disorder)' → 'Hypertension'."""
    return TAG.sub("", description).strip()


def age_on(birth: str, day: date) -> int:
    b = date.fromisoformat(birth)
    return day.year - b.year - ((day.month, day.day) < (b.month, b.day))


def rows(folder: Path, name: str) -> list[dict]:
    with (folder / name).open(newline="") as f:
        return list(csv.DictReader(f))


def main() -> None:
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / ".cache" / "population" / "csv"
    patients = [p for p in rows(folder, "patients.csv")
                if not p["DEATHDATE"] and age_on(p["BIRTHDATE"], REFERENCE_DATE) >= 0]

    conditions: dict[str, list[str]] = defaultdict(list)
    social: dict[str, list[str]] = defaultdict(list)
    for r in rows(folder, "conditions.csv"):
        if r["STOP"] or SKIP.search(r["DESCRIPTION"]) or SENSITIVE.search(r["DESCRIPTION"]):
            continue
        name = clean(r["DESCRIPTION"])
        target = social if SOCIAL.search(r["DESCRIPTION"]) else conditions
        if name not in target[r["PATIENT"]]:
            target[r["PATIENT"]].append(name)

    meds: dict[str, list[dict]] = defaultdict(list)
    for r in rows(folder, "medications.csv"):
        if not r["STOP"] and all(m["rxcui"] != r["CODE"] for m in meds[r["PATIENT"]]):
            meds[r["PATIENT"]].append({"rxcui": r["CODE"], "name": r["DESCRIPTION"]})

    allergies: dict[str, list[str]] = defaultdict(list)
    for r in rows(folder, "allergies.csv"):
        if not r["STOP"]:
            allergies[r["PATIENT"]].append(clean(r["DESCRIPTION"]))

    smoking: dict[str, tuple[str, str]] = {}
    for r in rows(folder, "observations.csv"):
        if r["CODE"] == SMOKING_LOINC and (r["PATIENT"] not in smoking or r["DATE"] > smoking[r["PATIENT"]][0]):
            smoking[r["PATIENT"]] = (r["DATE"], clean(r["VALUE"]))

    out = []
    for p in patients:
        pid = p["Id"]
        out.append({
            "id": pid[:8],
            "age": age_on(p["BIRTHDATE"], REFERENCE_DATE),
            "sex": p["GENDER"],
            "marital": p["MARITAL"] or None,
            "conditions": conditions[pid],
            "medications": meds[pid],
            "allergies": allergies[pid],
            "smoking": smoking.get(pid, (None, None))[1],
            "social": social[pid],
        })
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in out) + "\n")
    print(f"wrote {len(out)} backgrounds to {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()

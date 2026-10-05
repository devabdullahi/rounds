#!/usr/bin/env python3
"""Generates condition profiles (knowledge-base/schema) with the configured LLM.

    python3 generate.py triage [--limit N]        # stage 0 over conditions.jsonl, resumable
    python3 generate.py profile SLUG [SLUG ...]   # stages 1–5 for specific conditions
    python3 generate.py profile --top N           # stages 1–5 for the N most common suitable ones
    python3 generate.py check [SLUG ...]          # re-run validation on saved profiles

Model and keys come from .env (see .env.example). Every stage is validated against the schema and
the rule checks; a failing stage is retried once with the errors, then saved as failed for review.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import llm
from checks import PANELS, SCHEMA, TESTS, rule_errors, rule_warnings, schema_errors, section_errors

HERE = Path(__file__).resolve().parent
KB = HERE.parents[1] / "knowledge-base"
PROMPTS = HERE / "prompts"
PROFILES = KB / "profiles"
TRIAGE = KB / "triage.jsonl"
EXAMPLE = json.loads((KB / "schema" / "examples" / "acute-appendicitis.json").read_text())

# Bump when a prompt changes so regenerated profiles can be told apart.
PROMPT_VERSION = "1"
TRIAGE_BATCH = 20
BACKGROUND_LIMIT = 4000

# Stage name → sections it fills, in order. Later stages see earlier output.
STAGES = {
    "patient_presentation": ["patient", "presentation"],
    "exam_vitals": ["exam", "vitals"],
    "diagnostics": ["labs", "ecg", "imaging", "workup"],
    "differential_course": ["differential", "course", "cancer"],
    "teaching": ["teaching"],
}
OPTIONAL_SECTIONS = {"ecg", "cancer"}
COMMONNESS_ORDER = ["very_common", "common", "uncommon", "rare"]


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def prompt(name: str) -> str:
    return (PROMPTS / f"{name}.md").read_text()


def fill(template: str, **values: str) -> str:
    """str.format would trip over the JSON braces in the templates, so replace named slots only."""
    for key, value in values.items():
        template = template.replace("{" + key + "}", value)
    return template


def load_conditions() -> dict[str, dict]:
    rows = [json.loads(line) for line in (KB / "conditions.jsonl").open()]
    return {slugify(r["name"]): r for r in rows}


def load_triage() -> dict[str, dict]:
    if not TRIAGE.exists():
        return {}
    return {r["slug"]: r for r in map(json.loads, TRIAGE.open())}


# MARK: - Stage 0: triage

def run_triage(limit: int | None) -> None:
    conditions = load_conditions()
    done = load_triage()
    todo = [s for s in conditions if s not in done][:limit]
    provider, model = llm.current()
    print(f"triage: {len(todo)} to do, {len(done)} done, model {provider}/{model}", file=sys.stderr)

    for start in range(0, len(todo), TRIAGE_BATCH):
        batch = todo[start:start + TRIAGE_BATCH]
        listing = [{
            "id": s,
            "name": conditions[s]["name"],
            "also_called": conditions[s]["also_called"][:4],
            "definition": next((m["scope_note"] for m in conditions[s]["mesh"] if m["scope_note"]), "")[:300],
        } for s in batch]
        user = fill(prompt("triage"),
                    schema=json.dumps(SCHEMA["properties"]["triage"]),
                    example=json.dumps(EXAMPLE["triage"]),
                    conditions=json.dumps(listing, indent=1, ensure_ascii=False))
        reply = llm.complete_json(prompt("system"), user)
        results = {r.get("id"): r.get("triage") for r in reply.get("results", [])}
        with TRIAGE.open("a") as f:
            for s in batch:
                triage = results.get(s)
                errors = ["missing from reply"] if triage is None else section_errors("triage", triage)
                f.write(json.dumps({
                    "slug": s, "condition_id": conditions[s]["id"], "triage": triage, "errors": errors,
                    "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()},
                }, ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)


# MARK: - Stages 1–5: profile

def background(condition: dict) -> str:
    parts = [condition["summary"]]
    parts += [f"MeSH definition ({m['name']}): {m['scope_note']}" for m in condition["mesh"] if m["scope_note"]]
    if condition["also_called"]:
        parts.append("Also called: " + ", ".join(condition["also_called"]))
    if condition["differential_seeds"]:
        parts.append("Related conditions (candidate look-alikes): " + ", ".join(condition["differential_seeds"]))
    return "\n".join(parts)[:BACKGROUND_LIMIT]


def reference_table() -> str:
    """Compact test list for the diagnostics stage: id, name, unit, normal range, derived flag."""
    lines = ["Reference tests (id | name | unit | normal | notes):"]
    for panel in json.loads((KB / "reference_ranges.json").read_text())["panels"]:
        lines.append(f"[panel {panel['id']}] {panel['name']}")
        for t in panel["tests"]:
            if "normal" in t:
                normal = f"{t['normal']}; abnormal values: {', '.join(t['abnormal'])}"
            elif "female" in t:
                normal = f"F {t['female']}, M {t['male']}"
            else:
                normal = f"{t.get('low')}–{t.get('high')}"
            note = " | derived, never list" if t.get("derived") else ""
            lines.append(f"{t['id']} | {t['name']} | {t.get('unit', '')} | {normal}{note}")
    return "\n".join(lines) + "\n"


def stage_schema(sections: list[str]) -> str:
    return json.dumps({"properties": {s: SCHEMA["properties"][s] for s in sections}, "$defs": SCHEMA["$defs"]})


def run_stage(stage: str, name: str, condition: dict, profile: dict) -> tuple[dict, list[str]]:
    sections = STAGES[stage]
    previous = {k: v for k, v in profile.items() if k not in ("generation", "schema_version", "slug")}
    user = fill(prompt("stage"),
                name=name,
                instructions=prompt(f"stage_{stage}"),
                keys=", ".join(sections),
                schema=stage_schema(sections),
                example=json.dumps({s: EXAMPLE.get(s, {}) for s in sections}, ensure_ascii=False),
                background=background(condition),
                extra=reference_table() if stage == "diagnostics" else "",
                previous=json.dumps(previous, ensure_ascii=False))

    errors: list[str] = []
    for attempt in range(2):
        reply = llm.complete_json(prompt("system"), user)
        output = {s: reply[s] for s in sections if s in reply}
        errors = [f"missing section {s}" for s in sections if s not in output and s not in OPTIONAL_SECTIONS]
        for s, value in output.items():
            errors += section_errors(s, value)
        if not errors:
            errors = rule_errors(profile | output)
        if not errors:
            return output, []
        print(f"    {stage}: {len(errors)} error(s){', retrying' if attempt == 0 else ''}", file=sys.stderr)
        user += "\n\nYour previous reply had these problems. Fix them and reply with the full JSON again:\n- " + "\n- ".join(errors[:30])
    return output, errors


def run_profile(slug: str, conditions: dict[str, dict], triage: dict[str, dict]) -> None:
    condition, row = conditions.get(slug), triage.get(slug)
    if not condition or not row or not row.get("triage"):
        print(f"{slug}: needs a triage result first", file=sys.stderr)
        return
    if not row["triage"].get("case_suitable"):
        print(f"{slug}: triaged as not case-suitable, skipping", file=sys.stderr)
        return

    provider, model = llm.current()
    profile = {
        "schema_version": "0.1",
        "slug": slug,
        "triage": row["triage"],
        "generation": {
            "stages": [{"stage": "triage", "model": row["generation"]["model"],
                        "prompt_version": row["generation"]["prompt_version"],
                        "generated_at": row["generation"]["generated_at"]}],
            "validation": {"status": "pending"},
            "review": {"status": "pending"},
        },
    }
    all_errors: list[str] = []
    print(f"{slug}:", file=sys.stderr)
    for stage in STAGES:
        output, errors = run_stage(stage, row["triage"]["name"], condition, profile)
        profile.update(output)
        all_errors += errors
        profile["generation"]["stages"].append(
            {"stage": stage, "model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()})
        print(f"    {stage}: {'ok' if not errors else 'FAILED'}", file=sys.stderr)

    for section in OPTIONAL_SECTIONS:
        if profile.get(section) in ({}, {"findings": []}):
            profile.pop(section)
    save(profile, all_errors)


def validate(profile: dict) -> list[str]:
    return schema_errors(profile, SCHEMA) + rule_errors(profile)


def save(profile: dict, stage_errors: list[str]) -> None:
    errors = sorted(set(stage_errors + validate(profile)))
    known = {p.stem for p in PROFILES.glob("*.json")} | {profile["slug"]}
    profile["generation"]["validation"] = {
        "status": "failed" if errors else "passed",
        "rule_errors": errors,
        "review_issues": rule_warnings(profile, known),
    }
    PROFILES.mkdir(parents=True, exist_ok=True)
    path = PROFILES / f"{profile['slug']}.json"
    path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n")
    print(f"  saved {path.relative_to(KB.parent)} ({profile['generation']['validation']['status']})", file=sys.stderr)


def top_suitable(triage: dict[str, dict], count: int) -> list[str]:
    suitable = [s for s, r in triage.items() if r.get("triage") and r["triage"].get("case_suitable") and not r["errors"]]
    suitable.sort(key=lambda s: COMMONNESS_ORDER.index(triage[s]["triage"].get("commonness", "rare")))
    return suitable[:count]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    t = sub.add_parser("triage")
    t.add_argument("--limit", type=int)
    p = sub.add_parser("profile")
    p.add_argument("slugs", nargs="*")
    p.add_argument("--top", type=int)
    c = sub.add_parser("check")
    c.add_argument("slugs", nargs="*")
    args = parser.parse_args()

    if args.command == "triage":
        run_triage(args.limit)
    elif args.command == "profile":
        triage = load_triage()
        slugs = args.slugs or top_suitable(triage, args.top or 10)
        conditions = load_conditions()
        for slug in slugs:
            run_profile(slug, conditions, triage)
    else:
        paths = [PROFILES / f"{s}.json" for s in args.slugs] or sorted(PROFILES.glob("*.json"))
        for path in paths:
            profile = json.loads(path.read_text())
            save(profile, [])


if __name__ == "__main__":
    main()

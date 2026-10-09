#!/usr/bin/env python3
"""Exports what on-demand profile generation needs from this folder to the backend.

  - supabase/seed_conditions.sql: every triaged condition (catalog, triage, source background),
    loaded into private.conditions by `supabase db reset`.
  - supabase/functions/_shared/profilegen_assets.json: prompts, stage list, schema, example and
    the lab reference table, so the prepare-profile edge function writes profiles exactly as
    generate.py does. These files stay the source of truth; rerun this after changing them.
  - supabase/functions/_shared/reference_ranges.json: a copy of knowledge-base/reference_ranges.json,
    which labs.ts and profilegen.ts import (a deploy bundles only supabase/functions/; labs_test.ts
    fails when the copy drifts).

    python3 load_conditions.py           # regenerate the files
    python3 load_conditions.py --apply   # also upsert the catalog into the running local database
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from generate import (EXAMPLE, OPTIONAL_SECTIONS, PROMPT_VERSION, REQUIRED_SECTIONS, SCHEMA, STAGES, background,
                      load_conditions, load_triage, prompt, reference_table, stage_schema)
from load_profiles import LOCAL_DB_CONTAINER, array, literal
from tag_specialties import LIVE, load_tags
from tag_systems import load_systems
from terminology import MAX_UNVERIFIED

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "supabase" / "seed_conditions.sql"
ASSETS = ROOT / "supabase" / "functions" / "_shared" / "profilegen_assets.json"
RANGES = ROOT / "knowledge-base" / "reference_ranges.json"
RANGES_COPY = ROOT / "supabase" / "functions" / "_shared" / "reference_ranges.json"


def upsert(slug: str, condition: dict, triage: dict, specialties: list[str] | None = None,
           systems: list[str] | None = None) -> str:
    # Study topics: the triage rotations, then any live specialties the condition is tagged with.
    clerkships = list(dict.fromkeys([triage["primary_clerkship"], *triage.get("secondary_clerkships", []),
                                     *[s for s in (specialties or []) if s in LIVE]]))
    return (
        "insert into private.conditions (slug, condition_id, name, case_suitable, commonness, primary_clerkship, "
        "clerkships, organ_systems, triage, background) values ("
        f"{literal(slug)}, {literal(condition['id'])}, {literal(triage['name'])}, {str(bool(triage['case_suitable'])).lower()}, "
        f"{literal(triage.get('commonness', 'rare'))}, {literal(triage['primary_clerkship'])}, {array(clerkships)}, "
        # Body systems: the re-filing (tag_systems.py) when there is one, else triage's.
        f"{array(systems or triage.get('organ_systems', []))}, {literal(json.dumps(triage, ensure_ascii=False))}::jsonb, "
        f"{literal(background(condition))})\n"
        "on conflict (slug) do update set condition_id = excluded.condition_id, name = excluded.name, "
        "case_suitable = excluded.case_suitable, commonness = excluded.commonness, primary_clerkship = excluded.primary_clerkship, "
        "clerkships = excluded.clerkships, organ_systems = excluded.organ_systems, triage = excluded.triage, "
        "background = excluded.background, updated_at = now();\n"
    )


def assets() -> dict:
    return {
        "prompt_version": PROMPT_VERSION,
        "system": prompt("system"),
        "stage_template": prompt("stage"),
        "stages": [{
            "name": stage,
            "sections": sections,
            "instructions": prompt(f"stage_{stage}"),
            "schema": stage_schema(sections),
            "example": json.dumps({s: EXAMPLE.get(s, {}) for s in sections}, ensure_ascii=False),
        } for stage, sections in STAGES.items()],
        "optional_sections": sorted(OPTIONAL_SECTIONS),
        "required_sections": REQUIRED_SECTIONS,
        "reference_table": reference_table(),
        "max_unverified": MAX_UNVERIFIED,
        "schema": SCHEMA,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    conditions, triage, tags, systems = load_conditions(), load_triage(), load_tags(), load_systems()
    rows = [(slug, conditions[slug], t["triage"]) for slug, t in triage.items()
            if slug in conditions and t.get("triage") and not t.get("errors")]
    # Rows left out of the catalog: say which, so a failed triage batch isn't lost without a trace.
    failed = sorted(s for s, t in triage.items() if not t.get("triage") or t.get("errors"))
    unknown = sorted(s for s, t in triage.items() if s not in conditions and s not in failed)
    if failed:
        print(f"skipped {len(failed)} triage row(s) with errors or no result (rerun triage): {', '.join(failed)}",
              file=sys.stderr)
    if unknown:
        print(f"skipped {len(unknown)} triage row(s) whose condition is gone from the catalog: {', '.join(unknown)}",
              file=sys.stderr)
    sql = "-- Generated by tools/kb-generate/load_conditions.py from knowledge-base. Don't edit.\n\n"
    sql += "\n".join(upsert(*row, tags.get(row[0]), systems.get(row[0])) for row in rows)
    SEED.write_text(sql)
    ASSETS.write_text(json.dumps(assets(), ensure_ascii=False, indent=1) + "\n")
    shutil.copyfile(RANGES, RANGES_COPY)
    suitable = sum(1 for _, _, t in rows if t["case_suitable"])
    print(f"wrote {len(rows)} conditions ({suitable} case-suitable) to {SEED.relative_to(ROOT)}; "
          f"assets to {ASSETS.relative_to(ROOT)}; ranges to {RANGES_COPY.relative_to(ROOT)}", file=sys.stderr)
    untriaged = sorted(set(conditions) - set(triage))
    if untriaged:
        print(f"{len(untriaged)} conditions have no triage yet (run generate.py triage)", file=sys.stderr)

    if args.apply:
        result = subprocess.run(["docker", "exec", "-i", LOCAL_DB_CONTAINER, "psql", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-q"],
                                input=sql, capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(result.stderr)
        print("applied to local database", file=sys.stderr)


if __name__ == "__main__":
    main()

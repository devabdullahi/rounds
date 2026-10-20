#!/usr/bin/env python3
"""Finds case-suitable conditions that are umbrellas rather than one diagnosis.

MedlinePlus topics like "Drug use and addiction", "Headache" or "Hernia" cover several distinct
diagnoses. A case built on one has nothing specific to work from: the patient can't say which drug,
and its facts contradict each other. This asks, per condition, whether it is one specific diagnosis
or an umbrella, and for an umbrella which catalog conditions are its specific versions. Output goes
to knowledge-base/umbrellas.jsonl; load_conditions.py takes an umbrella out of cases when the
catalog has specific versions to cover it, and leaves one with none as it is.

    python3 tag_umbrellas.py            # tag conditions not yet tagged
    python3 tag_umbrellas.py --retag    # tag every condition again and rewrite the file
    python3 tag_umbrellas.py --counts   # how many umbrellas, and how many leave cases

A mock run (LLM_PROVIDER=mock) writes to KB_OUT or a temp folder, like generate.py.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import llm
import tagfile
from generate import OUT as OUT_DIR, load_conditions, load_triage, now

ROOT = Path(__file__).resolve().parents[2]
TAGS = ROOT / "knowledge-base" / "umbrellas.jsonl"  # what load_conditions.py reads
OUT = OUT_DIR / "umbrellas.jsonl"                   # where a run writes: TAGS, or scratch on a mock run
FIELD = "covered_by"                                 # specific catalog conditions an umbrella covers; [] when specific
BATCH = 25
PROMPT_VERSION = "1"

SYSTEM = "You are a US medical school clerkship director deciding which conditions make good single practice cases. Reply with JSON only."

TEMPLATE = """A practice case is one fictional patient with one specific diagnosis that a student must reach by taking a history, examining and ordering tests.

For each condition below, decide whether it is:
- specific: one diagnosis a single patient case can be built around (for example "Acute appendicitis", "Asthma", "Alcohol use disorder", "Migraine"), or
- umbrella: a category that covers several distinct diagnoses with different presentations and workups (for example "Drug use and addiction", "Headache", "Hernia", "Heart valve diseases", "Eating disorders").

A condition with subtypes that share one presentation and workup is still specific (asthma, eczema). A symptom that is itself the diagnosis students learn (for example "Back pain" in primary care) is umbrella only if its workup depends entirely on an underlying cause.

For an umbrella, list the ids of the catalog conditions below the line that are its specific versions (only ids from that list; none if the catalog has none).

Conditions to decide:
{conditions}

Catalog (id: name), for the specific versions:
{catalog}

Reply with JSON: {{"results": [{{"id": "<condition id>", "umbrella": true or false, "covered_by": ["<catalog id>", ...]}}]}} with one entry per condition to decide."""


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
    name = lambda s: conditions[s]["name"] if s in conditions else triage[s]["name"]  # noqa: E731
    catalog = "\n".join(f"{s}: {name(s)}" for s in triage)
    provider, model = llm.current()
    print(f"umbrellas: {len(todo)} to tag, {len(done)} done, model {provider}/{model}, writing {OUT}", file=sys.stderr)
    missed: list[str] = []
    for start in range(0, len(todo), BATCH):
        batch = todo[start:start + BATCH]
        rows = [{"id": s, "name": name(s)} for s in batch]
        reply = llm.complete_json(SYSTEM, TEMPLATE.format(conditions=json.dumps(rows, ensure_ascii=False), catalog=catalog))
        results = {r.get("id"): r for r in reply.get("results", []) if isinstance(r, dict)}
        with target.open("a") as f:
            for s in batch:
                r = results.get(s)
                if not r or not isinstance(r.get("umbrella"), bool):  # left out of the reply: no row, so the next run retries it
                    missed.append(s)
                    continue
                covered = [c for c in (r.get("covered_by") or []) if c in triage and c != s] if r["umbrella"] else []
                row = {"slug": s, "umbrella": r["umbrella"], FIELD: covered,
                       "generation": {"model": f"{provider}/{model}", "prompt_version": PROMPT_VERSION, "generated_at": now()}}
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"  {start + len(batch)}/{len(todo)}", file=sys.stderr)
    if retag:
        target.replace(OUT)
    if missed:
        print(f"{len(missed)} condition(s) missing from the replies, run again to retry: {', '.join(missed)}", file=sys.stderr)


def retired(slug: str, tags: dict[str, dict]) -> bool:
    """An umbrella the catalog covers with specific conditions: kept in the catalog, not used for cases.
    An umbrella with no specific versions stays usable, since it's the only way to practice that area."""
    row = tags.get(slug)
    return bool(row and row.get("umbrella") and row.get(FIELD))


def narrowed(slug: str, triage: dict, tags: dict[str, dict] | None = None) -> dict:
    """A copy of `triage` with case_suitable off for a retired umbrella, saying why."""
    tags = load_tags() if tags is None else tags
    if not retired(slug, tags):
        return triage
    return {**triage, "case_suitable": False,
            "reason": f"An umbrella over several diagnoses; its specific versions are cases instead: {', '.join(tags[slug][FIELD])}."}


def counts() -> None:
    tags, triage = load_tags(), suitable()
    umbrellas = [s for s in triage if tags.get(s, {}).get("umbrella")]
    out = [s for s in umbrellas if retired(s, tags)]
    print(f"{len(umbrellas)} umbrellas among {len(triage)} case-suitable conditions; {len(out)} leave cases, "
          f"{len(umbrellas) - len(out)} stay (no specific versions in the catalog)")
    for s in umbrellas:
        print(f"  {'OUT ' if s in out else 'KEEP'} {s}: {', '.join(tags[s][FIELD]) or '-'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--retag", action="store_true", help="tag every condition again")
    parser.add_argument("--counts", action="store_true", help="report the effect of the saved tags")
    args = parser.parse_args()
    if args.counts:
        counts()
    else:
        run(retag=args.retag)


if __name__ == "__main__":
    main()

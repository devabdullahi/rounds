# Condition profile generator

Fills `knowledge-base/profiles/<slug>.json` (schema: `knowledge-base/schema/`) with the configured LLM. Standard library only.

## Setup

Put your keys in `tools/kb-generate/.env` (git-ignored; template in `.env.example`):

```
LLM_PROVIDER=deepseek          # deepseek | anthropic | openai | mock
# LLM_MODEL=deepseek-v4-pro    # optional override (deepseek-flash is cheaper)
# LLM_EFFORT=high              # off | low | high | max; DeepSeek reasoning effort
DEEPSEEK_API_KEY=sk-...
UMLS_API_KEY=...               # SNOMED CT checks (terminology.py)
```

Switching models later only means changing `LLM_PROVIDER` / `LLM_MODEL`. Each profile records which model and prompt version produced each stage.

## Run

```bash
cd tools/kb-generate
python3 generate.py triage                 # stage 0 for all conditions → knowledge-base/triage.jsonl (resumable)
python3 generate.py profile --top 10       # stages 1–5 for the 10 most common case-suitable conditions
python3 generate.py profile acute-appendicitis kidney-stones
python3 generate.py check                  # re-validate saved profiles after editing them
LLM_PROVIDER=mock python3 generate.py …    # offline dry run, no key or cost; writes to a temp folder
KB_OUT=/tmp/kb-dry LLM_PROVIDER=mock python3 generate.py triage --limit 5   # dry run into a folder you choose
```

A mock run never writes to `knowledge-base/`: the mock replays the appendicitis example for every condition, so its output goes to `KB_OUT` when set, else a new temp folder (printed at the start). Profile runs read triage from that folder when it has one, else read the real `triage.jsonl` without changing it. `KB_OUT` also redirects a real run.

## Pipeline order

Run these in order after the condition list changes (`tools/kb-import`). Each step is resumable and only does what's missing:

```bash
python3 generate.py triage        # 1. stage 0 → knowledge-base/triage.jsonl
python3 tag_specialties.py        # 2. specialties → knowledge-base/specialties.jsonl
python3 tag_systems.py            # 3. organ systems → knowledge-base/systems.jsonl
python3 load_conditions.py        # 4. catalog, prompts, schema, ranges → supabase/
python3 generate.py profile --top 10   # 5. profiles → knowledge-base/profiles/ (optional: the app writes them on demand)
python3 load_profiles.py          # 6. passing profiles → supabase/seed_profiles.sql
```

`tag_specialties.py` and `tag_systems.py` take `--retag` to redo every condition (the file is replaced only when the run finishes), `--counts` for conditions per topic, and `--check-swift` to compare their ids with the app's `Clerkship` and `OrganSystem` enums (also run at the end of each tagging run). A normal run first drops null rows left by replies that skipped a condition, then retries those conditions.

Each stage is checked against the schema and the rule checks (`checks.py`). A failing stage is retried once with its errors. If it still fails, it's saved with `validation.status: failed` and its errors listed. `review.status` stays `pending` until a clinician approves the profile.

## On demand in the app

In the app, profiles aren't batch-generated: they're written when students need them. The edge function `prepare-profile` (`supabase/functions/`) runs the same stages, prompts and checks in TypeScript (`_shared/profilegen.ts`, `_shared/terms.ts`). When a student starts or finishes a case in a topic, one condition in that topic without a profile is queued (`_shared/prefetch.ts`). A topic with no profile yet makes the app wait while its first one is written.

This folder stays the source of truth. After changing prompts, the schema, the example or triage, export them:

```bash
python3 load_conditions.py --apply   # catalog → supabase/seed_conditions.sql (+ local DB); prompts/schema → profilegen_assets.json; reference_ranges.json → _shared/
```

The edge function needs `UMLS_API_KEY` alongside the LLM keys (`supabase/functions/.env` locally, `supabase secrets set` when deployed).

## Files

| File | Job |
|---|---|
| `generate.py` | Stages, prompts, retries, saving |
| `llm.py` | Provider switch (DeepSeek, Anthropic, OpenAI, mock) and `.env` loading |
| `checks.py` | Schema checker + rule checks against `reference_ranges.json` |
| `prompts/` | Prompt templates. Bump `PROMPT_VERSION` in `generate.py` when you change one |
| `terminology.py` | SNOMED CT (UMLS) and RxNorm checks on findings and medications |
| `load_conditions.py` | Exports the triaged catalog, the prompts/schema and a copy of `reference_ranges.json` for on-demand generation. Lists triage rows it skips |
| `tag_specialties.py` | Tags case-suitable conditions with the specialties that manage them → `specialties.jsonl`. `LIVE` lists the ones students can pick |
| `tag_systems.py` | Files case-suitable conditions under up to three organ systems → `systems.jsonl` (used in place of triage's `organ_systems`) |
| `tagfile.py` | Reads and cleans the tag files (latest usable row per condition) |
| `swift_enums.py` | Reads the app's `Clerkship` / `OrganSystem` cases (read-only) so the taggers can report id mismatches |
| `load_profiles.py` | Writes passing profiles to `supabase/seed_profiles.sql` (`--apply` also loads the local DB) |

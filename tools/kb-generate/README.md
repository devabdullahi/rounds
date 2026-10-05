# Condition profile generator

Fills `knowledge-base/profiles/<slug>.json` (schema: `knowledge-base/schema/`) with the configured LLM. Standard library only.

## Setup

Put your keys in `tools/kb-generate/.env` (git-ignored; template in `.env.example`):

```
LLM_PROVIDER=deepseek          # deepseek | anthropic | openai | mock
# LLM_MODEL=deepseek-chat      # optional override
DEEPSEEK_API_KEY=sk-...
```

Switching models later only means changing `LLM_PROVIDER` / `LLM_MODEL`. Each profile records which model and prompt version produced each stage.

## Run

```bash
cd tools/kb-generate
python3 generate.py triage                 # stage 0 for all conditions → knowledge-base/triage.jsonl (resumable)
python3 generate.py profile --top 10       # stages 1–5 for the 10 most common case-suitable conditions
python3 generate.py profile acute-appendicitis kidney-stones
python3 generate.py check                  # re-validate saved profiles after editing them
LLM_PROVIDER=mock python3 generate.py …    # offline dry run, no key or cost
```

Each stage is checked against the schema and the rule checks (`checks.py`). A failing stage is retried once with its errors. If it still fails, it's saved with `validation.status: failed` and its errors listed. `review.status` stays `pending` until a clinician approves the profile.

## Files

| File | Job |
|---|---|
| `generate.py` | Stages, prompts, retries, saving |
| `llm.py` | Provider switch (DeepSeek, Anthropic, OpenAI, mock) and `.env` loading |
| `checks.py` | Schema checker + rule checks against `reference_ranges.json` |
| `prompts/` | Prompt templates. Bump `PROMPT_VERSION` in `generate.py` when you change one |

# Knowledge-base importers

Pull public reference data into `knowledge-base/` for case authoring and profile generation. Standard library only; downloads go through `curl` and are cached in `.cache/` (git-ignored), so reruns resume. What each output file holds is in [`knowledge-base/README.md`](../../knowledge-base/README.md).

## Setup

Keys go in `tools/kb-import/.env` (git-ignored; template in `.env.example`). Only the UMLS scripts need one:

```
UMLS_API_KEY=...   # uts.nlm.nih.gov → My Profile → API Key; also unlocks VSAC
```

## Licensed data stays out of git

SNOMED CT (UMLS Affiliate License), VSAC value sets and the Clinical Tables full list may be used in Rounds but not redistributed. Rules:

- Licensed output goes only to `knowledge-base/licensed/`, which `.gitignore` excludes. Never copy it elsewhere in the repo, into `supabase/seed*.sql`, or into a commit.
- It reaches our database only through SQL written outside the repo (`load_terms.py`, which refuses paths inside it).
- Committed files may use SNOMED to *verify* a condition, but show our own names and public-domain codes (ICD-10-CM), never SNOMED wording.

## Run order

```bash
cd tools/kb-import
python3 -m build_kb            # MedlinePlus + MeSH + ICD-10-CM + PubMed → conditions.jsonl (--limit 20 to try)
python3 clinical_tables.py     # core conditions MedlinePlus lacks → conditions_core.jsonl
python3 drugs.py               # openFDA labels → drugs.jsonl
python3 rxnorm.py              # RxNorm + MED-RT → rxnorm.jsonl
python3 cdc.py                 # CDC pages → cdc_pages.jsonl
# then triage and tag in tools/kb-generate (see its README), then:
python3 snomed.py              # SNOMED CT + ICD-10-CM per case-suitable condition → licensed/snomed.jsonl
python3 load_terms.py ~/rounds-terms.sql   # SQL to load those terms into private.conditions
python3 coverage_gaps.py       # core-condition coverage report → coverage-gaps.md
```

## Scripts

### `snomed.py`

Maps each case-suitable condition (from `knowledge-base/triage.jsonl`) to a SNOMED CT US Edition disorder or finding and its ICD-10-CM codes through the UMLS REST API. Output: `knowledge-base/licensed/snomed.jsonl` (licensed, git-ignored). Its lookup helpers (`concept`, `icd10cm`, `atoms`) are reused by `clinical_tables.py`, `coverage_gaps.py`, `snomed_findings.py` and the profile generator's `terminology.py`. Needs `UMLS_API_KEY`; responses are cached without the key. `--limit N` for a trial.

### `clinical_tables.py`

Adds the core conditions (`core_conditions.json`) that MedlinePlus lumps or skips (DKA, preeclampsia, intussusception). Finds each in the NLM Clinical Tables conditions download, confirms it as a SNOMED CT disorder through UMLS (verification only, no SNOMED wording kept), and attaches its MeSH descriptor. Outputs:

- `knowledge-base/conditions_core.jsonl`: committed, same shape as `conditions.jsonl`.
- `knowledge-base/licensed/clinical_tables_conditions.jsonl`: the full list, git-ignored until Regenstrief's redistribution terms are confirmed.

### `load_terms.py`

Writes SQL that sets `private.conditions.terms` (SNOMED code, preferred term, synonyms and ICD-10-CM) from `licensed/snomed.jsonl`. The output path is required and must be outside the repo; run the SQL against the database yourself.

```bash
python3 load_terms.py ~/rounds-terms.sql
```

### Others

| File | Job |
|---|---|
| `build_kb/` | MedlinePlus topics + MeSH + ICD-10-CM candidates + PubMed refs → `conditions.jsonl`. `mapping.py` maps MeSH trees to organ systems |
| `drugs.py` | openFDA drug labels → `drugs.jsonl` (`OPENFDA_API_KEY` optional, lifts the daily limit) |
| `rxnorm.py` | RxNorm ingredients, FDA classes, MED-RT treats/contraindications → `rxnorm.jsonl` |
| `cdc.py` | CDC syndication pages by condition → `cdc_pages.jsonl` |
| `coverage_gaps.py` | Which core conditions have a catalog entry, a passing profile and a SNOMED match → `coverage-gaps.md` |
| `snomed_findings.py` | Maps profile findings to SNOMED CT → `licensed/finding_snomed.jsonl` (measurement only; profiles unchanged) |
| `vsac.py` | VSAC value sets for the measures in `vsac_measures.json` → `licensed/vsac.jsonl` (CPT codes dropped) |
| `common.py` | `.env` loading, cached downloads, JSONL helpers |

# Knowledge base (case authoring)

Reference material for **drafting fictional cases**. Each file has one JSON record per line.

| File | What | Built by |
|---|---|---|
| `conditions.jsonl` | Diseases and symptoms: summary, MeSH, ICD-10-CM candidates, differentials, PubMed refs | `build_kb/` (`python3 -m build_kb`) |
| `drugs.jsonl` | Common prescription generics: indications, dosing, contraindications, boxed warning, interactions | `drugs.py` |
| `reference_ranges.json` | Adult normal ranges in US units for 108 tests and vitals: sex-specific ranges, critical values, report decimals, formulas for derived values | Written by hand (teaching values, not clinical) |
| `cdc_pages.jsonl` | CDC overview pages linked by `condition_id` (mostly infectious and chronic disease) | `cdc.py` (run after `build_kb`) |
| `conditions_core.jsonl` | Core hospital diagnoses MedlinePlus lacks (DKA, preeclampsia…), same shape as `conditions.jsonl`; wins on a slug collision | `clinical_tables.py` |
| `rxnorm.jsonl` | Drugs normalized to RxNorm: ingredient RXCUIs, brands, FDA classes, MED-RT may-treat / contraindications | `rxnorm.py` |
| `triage.jsonl` | Stage 0 per condition: case-suitable, kind, clerkships, commonness, settings | `tools/kb-generate/generate.py triage` |
| `specialties.jsonl` | Specialties that manage each case-suitable condition (study topics beside the rotations) | `tools/kb-generate/tag_specialties.py` |
| `systems.jsonl` | Organ systems (up to three) per case-suitable condition, from the full 14-system list | `tools/kb-generate/tag_systems.py` |
| `profiles/` | One generated condition profile per slug (schema in `schema/`) | `tools/kb-generate/generate.py profile` (the app also writes them on demand) |
| `schema/` | Condition profile JSON Schema and a worked example | Written by hand |
| `coverage-gaps.md` | Which core conditions have a catalog entry, a passing profile and a SNOMED match | `coverage_gaps.py` |
| `licensed/` | **Git-ignored.** SNOMED CT maps (`snomed.jsonl`, `finding_snomed.jsonl`), VSAC value sets, the Clinical Tables full list, Synthea backgrounds. Usable in Rounds, not redistributable | `snomed.py`, `snomed_findings.py`, `vsac.py`, `clinical_tables.py`, `tools/synthea/backgrounds.py` |

```bash
cd tools/kb-import
python3 -m build_kb  # --limit 20 for a quick trial
python3 drugs.py      # openFDA: 1,000 requests/day without OPENFDA_API_KEY; cached, so reruns resume
python3 cdc.py
```

The full run order is in [`tools/kb-import/README.md`](../tools/kb-import/README.md) and [`tools/kb-generate/README.md`](../tools/kb-generate/README.md). Builders without a path live in `tools/kb-import/`.

Downloads and API responses are cached in `tools/kb-import/.cache/`, which is git-ignored.

## Rules

- **Authoring only.** The patient LLM must never see these files. They name diagnoses, so giving it to the patient would leak the answer. The patient gets only its own case's revealable facts.
- **Facts, not wording.** Write case text in our own words. The summaries are written for patients, not clinicians. Use them as background, not as content shown to students.
- **ICD-10-CM codes are candidates.** They're matched by name through the NLM Clinical Tables API. Pick the right code by hand when a case is written.
- **References are pointers.** PubMed entries are title, journal, year and link only. Read the article to check facts. Don't paste its text.

## Fields

| Field | From | Use |
|---|---|---|
| `name`, `also_called` | MedlinePlus | Diagnosis label and synonyms for answer matching |
| `kind` | MeSH tree | `symptom`: use as a presenting complaint. `disease`: can be the hidden diagnosis |
| `organ_systems` | MeSH tree → `OrganSystem` raw values | A hint only. The organ systems the app browses by come from `systems.jsonl` (`tag_systems.py`, with MeSH as a floor), falling back to triage's when a condition has no row there |
| `mesh[].scope_note`, `entry_terms` | MeSH | Definition and alternate names |
| `icd10cm_candidates` | NLM Clinical Tables | Candidate codes to review |
| `summary` | MedlinePlus | Plain-language background: symptoms, causes, who gets it |
| `differential_seeds` | Conditions under the same MeSH parent | Starting list of differentials and distractors |
| `related_topics` | MedlinePlus | More neighbors for differentials |
| `references` | PubMed (free full text) | Reviews and case reports for checking facts |

`drugs.jsonl` has `generic_name`, `brand_names`, `rxcui` (joins to `DrugMatch.rxcui`), `route`, `pharm_class` (often empty in openFDA) and `label` sections trimmed to fixed lengths, plus a DailyMed link.

## Sources and licenses

| Source | Access | License |
|---|---|---|
| MedlinePlus health topics | Official daily XML ([medlineplus.gov/xml.html](https://medlineplus.gov/xml.html)) | NLM-written summaries are public domain. The licensed A.D.A.M. encyclopedia and drug monographs are not used. |
| MeSH | Official descriptor XML from nlmpubs.nlm.nih.gov | Public domain (NLM) |
| ICD-10-CM | NLM Clinical Tables API | Public domain (CMS/NCHS) |
| openFDA drug labels | Official API (api.fda.gov) | Public domain (CC0). The text is manufacturer label wording, so reword it for cases. |
| CDC | Content syndication API (tools.cdc.gov) | US government work, public domain. CDC asks that syndicated pages not be republished in modified form, so use them as background only. |
| PubMed | NCBI E-utilities (official API, under 3 requests/s) | Citation metadata only. Abstracts and full text are not stored. |

Not included on purpose:
- **NCBI Bookshelf.** Its terms forbid bulk downloading, and most books are copyrighted. StatPearls is CC BY-NC-ND (no commercial use).
- **USMLE content outlines.** These are owned by NBME/FSMB, and we don't use exam branding. Our topic taxonomy is the app's own `Clerkship` and `OrganSystem`.
- **Common Crawl.** Crawled pages keep their original copyright, and the medical slice mixes in question-bank leaks, textbook copies and real patient posts. Government sources come from their official APIs instead.

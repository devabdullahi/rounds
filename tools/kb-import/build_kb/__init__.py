"""Builds the Rounds case-authoring knowledge base from public-domain NLM sources.

Output: knowledge-base/conditions.jsonl, one condition per line, for drafting fictional cases.
Authoring only: this file must never be given to the patient LLM (it would leak the diagnosis).

Sources, all official bulk files or APIs (no page scraping):
  - MedlinePlus health topics XML: NLM-written summaries, public domain.
  - MeSH descriptors XML: tree numbers (organ system) and scope notes, public domain.
  - NLM Clinical Tables ICD-10-CM API: candidate codes, matched by name, so review before use.
  - PubMed E-utilities: PMIDs and titles of free-full-text reviews and case reports. Metadata only;
    abstracts and article text belong to publishers and are not stored.

Layout: mapping.py (pure MeSH rules), sources/ (one module per source, fetch and parse only),
assemble.py (joins them and writes the file), __main__.py (CLI).

Standard library only. Downloads are cached in tools/kb-import/.cache (git-ignored), so re-runs only
redo the API lookups that are missing from the cache.

    cd tools/kb-import
    python3 -m build_kb            # full build
    python3 -m build_kb --limit 20 # quick trial
"""

# Re-exported so other import scripts (clinical_tables.py) keep `from build_kb import …`.
from .assemble import OUT, build
from .mapping import (
    CONDITION_TREE_ROOTS,
    ORGAN_SYSTEM_BY_TREE,
    condition_kind,
    icd_search_terms,
    is_condition,
    organ_systems,
    parent_tree,
)
from .sources.icd10 import icd10_candidates
from .sources.medlineplus import latest_topics_url, load_topics
from .sources.mesh import load_mesh
from .sources.pubmed import pubmed_ids, pubmed_summaries

__all__ = [
    "CONDITION_TREE_ROOTS", "ORGAN_SYSTEM_BY_TREE", "OUT",
    "build", "condition_kind", "icd10_candidates", "icd_search_terms", "is_condition",
    "latest_topics_url", "load_mesh", "load_topics", "organ_systems", "parent_tree",
    "pubmed_ids", "pubmed_summaries",
]

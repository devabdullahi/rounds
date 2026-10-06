"""NLM Clinical Tables ICD-10-CM API: candidate codes, matched by name, so review before use."""

from __future__ import annotations

import urllib.parse

from common import cached_json, slug

from ..mapping import icd_search_terms

ICD10CM_SEARCH = "https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search"


def icd10_candidates(title: str, mesh_name: str) -> list[dict]:
    """Tries the plain title first; the API ranks inverted MeSH names ("Diabetes Mellitus, Type 2")
    badly or finds nothing, so those come after, uninverted and then as-is."""
    for name in icd_search_terms(title, mesh_name):
        query = urllib.parse.urlencode({"sf": "code,name", "terms": name, "maxList": 5})
        data = cached_json(f"icd-{slug(name)}", f"{ICD10CM_SEARCH}?{query}", delay=0.1)
        if data[3]:
            return [{"code": c, "name": n} for c, n in data[3]]
    return []

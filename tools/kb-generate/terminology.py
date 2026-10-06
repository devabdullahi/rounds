"""Terminology checks for generated profiles: findings must be SNOMED CT concepts (via the UMLS API)
and medications must be RxNorm drugs (via RxNav).

Reuses the importers' cached HTTP helpers, so each term is looked up once across all runs. SNOMED
content isn't copied into profiles: a finding only gets `snomed_verified: true`.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "kb-import"))

from common import slug  # noqa: E402
from snomed import atoms, get  # noqa: E402
import rxnorm  # noqa: E402

FINDING_TAGS = ("(finding)", "(disorder)", "(observable entity)", "(morphologic abnormality)")


# "Crackles absent", "No rebound", "Tactile fremitus normal": the finding is the part to look up.
NEGATION = re.compile(r"^(?:no|absent|absence of|without)\s+|\s+(?:absent|normal|not present)$", re.I)


def is_snomed_finding(term: str) -> bool:
    """True when SNOMED CT has a finding/disorder concept named exactly (or normalized) as `term`,
    or as the finding inside a negated term."""
    base = NEGATION.sub("", term).strip()
    return _lookup(term) or (base != term and _lookup(base))


def _lookup(term: str) -> bool:
    for search_type in ("exact", "normalizedString"):
        data = get(f"search-{search_type}-{slug(term)}", "/search/current",
                   {"string": term, "sabs": "SNOMEDCT_US", "returnIdType": "code",
                    "searchType": search_type, "pageSize": 5})
        for hit in [r for r in data["result"]["results"] if r.get("ui") and r["ui"] != "NONE"][:3]:
            fsn = next((a["name"] for a in atoms(hit["ui"]) if a.get("termType") == "FN"), "")
            if fsn.endswith(FINDING_TAGS):
                return True
    return False


def is_rxnorm_drug(name: str) -> bool:
    return rxnorm.rxcui_for(name) is not None


def suggestions(term: str, limit: int = 4) -> list[str]:
    """SNOMED's own names for the concept(s) UMLS matches to `term`, offered to the writer on a retry.
    UMLS searches all its vocabularies, so "Pharyngeal erythema" finds the concept SNOMED calls
    "Redness of throat"."""
    base = NEGATION.sub("", term).strip() or term
    data = get(f"concept-words-{slug(base)}", "/search/current", {"string": base, "searchType": "words", "pageSize": 3})
    out: list[str] = []
    for hit in [r for r in data["result"]["results"] if r.get("ui") and r["ui"] != "NONE"]:
        names = get(f"cui-snomed-pt-{hit['ui']}", f"/content/current/CUI/{hit['ui']}/atoms",
                    {"sabs": "SNOMEDCT_US", "ttys": "PT", "pageSize": 3}, missing={"result": []})  # 404: no SNOMED name
        for atom in (names.get("result") or []) if isinstance(names, dict) else []:
            if atom["name"] not in out:
                out.append(atom["name"])
    return out[:limit]


def finding_items(section: str, output: dict) -> list[dict]:
    """The term-bearing items in a stage's output."""
    if section == "presentation":
        p = output.get("presentation", {})
        items = list(p.get("chief_complaints", [])) + list(p.get("hpi", {}).get("associated_symptoms", []))
        for ros in p.get("ros", []):
            items += ros.get("positives", [])
        return items
    if section == "exam":
        return list(output.get("exam", {}).get("findings", []))
    return []


def check_terms(output: dict) -> list[str]:
    """Marks verified terms on the items in place; returns errors for missing or unknown ones."""
    errors: list[str] = []
    for section in ("presentation", "exam"):
        for item in finding_items(section, output):
            term = (item.get("term") or "").strip()
            label = item.get("text") or item.get("finding") or "?"
            if not term:
                errors.append(f"{section}: {label!r} has no term; add its standard clinical name")
                continue
            item["snomed_verified"] = is_snomed_finding(term)
            if not item["snomed_verified"]:
                close = suggestions(term)
                hint = f"; SNOMED names close to it: {', '.join(repr(c) for c in close)}" if close else "; use its standard clinical name"
                errors.append(f"{section}: term {term!r} isn't a SNOMED CT finding{hint}")
    for drug in output.get("patient", {}).get("risk_medications", []) or []:
        if not is_rxnorm_drug(drug):
            errors.append(f"patient.risk_medications: {drug!r} isn't an RxNorm drug; use the generic name")
    return errors


# Share of a section's findings allowed to miss SNOMED CT before the profile fails. A few near-miss
# names ("Cardiac murmur" vs SNOMED's "Heart murmur") are flagged for review instead.
MAX_UNVERIFIED = 0.25


def term_summary(profile: dict) -> tuple[list[str], list[str]]:
    """(errors, review notes) from the verified flags already set on a saved profile."""
    errors, notes = [], []
    for section in ("presentation", "exam"):
        items = finding_items(section, profile)
        if not items:
            continue
        if not any("term" in i for i in items):
            notes.append(f"{section}: older format without SNOMED terms")
            continue
        unverified = [i.get("term") or "(none)" for i in items if not i.get("snomed_verified")]
        if len(unverified) / len(items) > MAX_UNVERIFIED:
            errors.append(f"{section}: {len(unverified)} of {len(items)} terms aren't SNOMED CT findings")
        notes += [f"{section}: term {t!r} not found in SNOMED CT" for t in unverified]
    return errors, notes

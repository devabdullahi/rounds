"""Pure MeSH mapping rules: which descriptors are conditions, their organ systems and kind.

No I/O here, so the rules can be checked on plain lists of tree numbers, and other import
scripts (clinical_tables.py) classify conditions exactly the way the builder does.
"""

from __future__ import annotations

import re

# MeSH tree prefixes mapped to the app's OrganSystem raw values (Model/StudyFocus.swift).
# Longest prefix wins, so the pregnancy and kidney branches beat their broader parents.
ORGAN_SYSTEM_BY_TREE = {
    "C14": "cardiovascular",
    "C08": "respiratory",
    "C06": "gastrointestinal",
    "C12": "renal",
    "C12.200": "renal",          # urologic and male genital
    "C12.100": "reproductive",   # female urogenital
    "C12.800": "reproductive",   # male genital
    "C13": "reproductive",       # female urogenital and pregnancy complications
    "C10": "nervous",
    "C19": "endocrine",
    "C18": "endocrine",          # nutritional and metabolic
    "C15": "blood",
    "C20": "blood",              # immune
    "C05": "musculoskeletal",
    "C17": "musculoskeletal",    # skin and connective tissue
    "F03": "behavioral",
}

# Only disease and mental-disorder descriptors make a case; wellness and procedure topics don't.
CONDITION_TREE_ROOTS = ("C", "F03")


def organ_systems(tree_numbers: list[str]) -> list[str]:
    """Maps MeSH tree numbers to OrganSystem raw values, keeping first-seen order."""
    found: list[str] = []
    for tree in tree_numbers:
        best = max((p for p in ORGAN_SYSTEM_BY_TREE if tree == p or tree.startswith(p + ".")),
                   key=len, default=None)
        if best and ORGAN_SYSTEM_BY_TREE[best] not in found:
            found.append(ORGAN_SYSTEM_BY_TREE[best])
    return found


def is_condition(tree_numbers: list[str]) -> bool:
    return any(t.startswith(CONDITION_TREE_ROOTS) for t in tree_numbers)


def condition_kind(tree_numbers: list[str]) -> str:
    """'symptom' when every disease tree sits under C23 (signs and symptoms), so a generator can use
    it as a presenting complaint rather than a hidden diagnosis."""
    disease_trees = [t for t in tree_numbers if t.startswith(CONDITION_TREE_ROOTS)]
    return "symptom" if all(t.startswith("C23.888") for t in disease_trees) else "disease"


def icd_search_terms(title: str, mesh_name: str) -> list[str]:
    """'Alcohol Use Disorder (AUD)' → 'Alcohol Use Disorder'; 'Diabetes Mellitus, Type 2' → 'Type 2 Diabetes Mellitus'."""
    plain = re.sub(r"\s*\([^)]*\)", "", title).strip()
    head, _, tail = mesh_name.partition(", ")
    uninverted = f"{tail} {head}" if tail else mesh_name
    return list(dict.fromkeys([plain, uninverted, mesh_name]))


def parent_tree(tree: str) -> str:
    """Conditions sharing a parent tree number are look-alikes, used as differential seeds."""
    return tree.rsplit(".", 1)[0] if "." in tree else tree

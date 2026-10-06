#!/usr/bin/env python3
"""Pulls value sets from VSAC (SVS API v2) for the CMS quality measures in vsac_measures.json.

Output: knowledge-base/licensed/vsac.jsonl, one row per value set: its OID, name, code systems and
codes (SNOMED CT, ICD-10-CM, LOINC, RxNorm…). Useful for grading plans in code, e.g. "did the
student start a medication from the antidepressant value set".

Value sets carry SNOMED CT (licensed) and sometimes CPT (AMA-licensed) codes, so the output folder
is git-ignored. CPT codes are dropped here. NLM asks for this attribution wherever the data is used:
"This product uses publicly available data from the U.S. National Library of Medicine (NLM)."

Needs UMLS_API_KEY in tools/kb-import/.env (the same key as snomed.py).

    python3 vsac.py
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

from common import CACHE, KB, ROOT, fetch, write_jsonl

SVS = "https://vsac.nlm.nih.gov/vsac/svs/RetrieveMultipleValueSets"
NS = {"ns0": "urn:ihe:iti:svs:2008"}
DELAY = 0.07                       # VSAC allows 20 requests a second per IP
DROPPED_SYSTEMS = {"CPT"}          # AMA-licensed; not ours to use
MEASURES = Path(__file__).resolve().parent / "vsac_measures.json"


def key() -> str:
    value = os.environ.get("UMLS_API_KEY")
    if not value:
        raise SystemExit("Set UMLS_API_KEY in tools/kb-import/.env (the UMLS key also unlocks VSAC).")
    return value


# VSAC tags measures by versioned id (CMS122v15), and the tag-value list isn't served, so each
# measure's newest published version is found by trying versions from NEWEST_VERSION down.
NEWEST_VERSION = 18
OLDEST_VERSION = 6


def tagged_xml(tag: str) -> bytes | None:
    """All value sets for one versioned eCQM id, cached on disk (NLM asks for 12–24 h caching at least)."""
    path = CACHE / "vsac" / f"{tag}.xml"
    if path.exists():
        return path.read_bytes()
    time.sleep(DELAY)
    query = urllib.parse.urlencode({"tagName": "CMS eMeasure ID", "tagValue": tag})
    try:
        data = fetch(f"{SVS}?{query}", user=f"apikey:{key()}")
    except RuntimeError as error:
        print(f"  {tag}: {error}", file=sys.stderr)
        return None
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def measure_xml(measure: str) -> tuple[str, bytes] | None:
    """The newest version of a measure that has value sets, as (versioned id, xml)."""
    for version in range(NEWEST_VERSION, OLDEST_VERSION - 1, -1):
        tag = f"{measure}v{version}"
        xml = tagged_xml(tag)
        if xml and b"DescribedValueSet " in xml:
            return tag, xml
    return None


def value_sets(xml: bytes, measure: str) -> list[dict]:
    root = ET.fromstring(xml)
    out = []
    for vs in root.iter(f"{{{NS['ns0']}}}DescribedValueSet"):
        concepts = []
        for c in vs.iter(f"{{{NS['ns0']}}}Concept"):
            system = c.get("codeSystemName", "")
            if system in DROPPED_SYSTEMS:
                continue
            concepts.append({"code": c.get("code"), "system": system, "display": c.get("displayName")})
        if not concepts:
            continue
        out.append({
            "oid": vs.get("ID"),
            "name": vs.get("displayName"),
            "version": vs.get("version"),
            "measures": [measure],
            "systems": sorted({c["system"] for c in concepts}),
            "concepts": concepts,
            "attribution": "This product uses publicly available data from the U.S. National Library of Medicine (NLM).",
        })
    return out


def main() -> None:
    key()
    measures = json.loads(MEASURES.read_text())["measures"]
    by_oid: dict[str, dict] = {}
    for n, measure in enumerate(measures, 1):
        found = measure_xml(measure)
        tag, xml = found if found else (measure, None)
        sets = value_sets(xml, tag) if xml else []
        print(f"  [{n}/{len(measures)}] {tag}: {len(sets)} value set(s)", file=sys.stderr)
        for vs in sets:
            if vs["oid"] in by_oid:
                by_oid[vs["oid"]]["measures"].append(measure)   # shared across measures
            else:
                by_oid[vs["oid"]] = vs

    rows = sorted(by_oid.values(), key=lambda v: v["name"] or "")
    out = KB / "licensed" / "vsac.jsonl"
    write_jsonl(out, rows)
    meds = sum("RXNORM" in v["systems"] for v in rows)
    print(f"wrote {len(rows)} value sets ({meds} with RxNorm medications) to {out.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()

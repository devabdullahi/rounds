"""MeSH descriptors XML: tree numbers (organ system) and scope notes, public domain."""

from __future__ import annotations

import gzip
import re
import xml.etree.ElementTree as ET

from common import cached_download

MESH_DESCRIPTORS = "https://nlmpubs.nlm.nih.gov/projects/mesh/MESH_FILES/xmlmesh/desc{year}.gz"


def load_mesh(year: int) -> dict[str, dict]:
    """Descriptors keyed by UI. Streams the file and clears each record, since the full tree
    would not fit comfortably in memory."""
    path = cached_download(MESH_DESCRIPTORS.format(year=year), f"desc{year}.gz")
    mesh: dict[str, dict] = {}
    with gzip.open(path) as f:
        for _, el in ET.iterparse(f):
            if el.tag != "DescriptorRecord":
                continue
            ui = el.findtext("DescriptorUI")
            mesh[ui] = {
                "name": el.findtext("DescriptorName/String"),
                "trees": [t.text for t in el.findall("TreeNumberList/TreeNumber")],
                "scope_note": re.sub(r"\s+", " ", el.findtext("ConceptList/Concept/ScopeNote") or "").strip(),
                "entry_terms": [t.text for t in el.findall("ConceptList/Concept/TermList/Term/String")][1:12],
            }
            el.clear()
    return mesh

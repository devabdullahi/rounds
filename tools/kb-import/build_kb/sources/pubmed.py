"""PubMed E-utilities: PMIDs and titles of free-full-text reviews and case reports.

Metadata only; abstracts and article text belong to publishers and are not stored.
"""

from __future__ import annotations

import html
import urllib.parse

from common import cached_json, slug

EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# NCBI asks callers to identify their tool and stay under 3 requests a second without an API key.
NCBI_TOOL = "rounds-kb"
NCBI_DELAY = 0.4


def pubmed_ids(mesh_name: str, publication_type: str, count: int) -> list[str]:
    """Most relevant free-full-text English PMIDs where the descriptor is a major topic."""
    term = f'"{mesh_name}"[majr] AND {publication_type}[pt] AND free full text[sb] AND english[la]'
    query = urllib.parse.urlencode({
        "db": "pubmed", "term": term, "retmax": count, "sort": "relevance",
        "retmode": "json", "tool": NCBI_TOOL,
    })
    data = cached_json(f"pm-{publication_type.replace(' ', '')}-{slug(mesh_name)}",
                       f"{EUTILS}/esearch.fcgi?{query}", delay=NCBI_DELAY)
    return data["esearchresult"]["idlist"]


def pubmed_summaries(pmids: list[str]) -> dict[str, dict]:
    """Citation metadata keyed by PMID, fetched in batches of 200 to keep request counts low."""
    out: dict[str, dict] = {}
    for start in range(0, len(pmids), 200):
        batch = pmids[start:start + 200]
        query = urllib.parse.urlencode({"db": "pubmed", "id": ",".join(batch), "retmode": "json", "tool": NCBI_TOOL})
        data = cached_json(f"pmsum-{batch[0]}-{len(batch)}", f"{EUTILS}/esummary.fcgi?{query}", delay=NCBI_DELAY)
        for pmid in batch:
            doc = data["result"].get(pmid)
            if doc:
                out[pmid] = {
                    "pmid": pmid,
                    "title": html.unescape(doc.get("title", "")),
                    "journal": doc.get("source"),
                    "year": (doc.get("pubdate") or "")[:4],
                    "url": f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/",
                }
    return out

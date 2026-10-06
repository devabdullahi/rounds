"""MedlinePlus health topics XML: NLM-written summaries, public domain."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET

from common import cached_download, fetch, strip_html

MEDLINEPLUS_INDEX = "https://medlineplus.gov/xml.html"


def latest_topics_url() -> str:
    """The topics file is renamed daily, so its URL is read from the index page each run."""
    page = fetch(MEDLINEPLUS_INDEX).decode()
    match = re.search(r'href="(https://medlineplus\.gov/xml/mplus_topics_\d{4}-\d{2}-\d{2}\.xml)"', page)
    if not match:
        raise RuntimeError("MedlinePlus XML index changed; no topics file found")
    return match.group(1)


def load_topics() -> list[dict]:
    """English health topics with the fields a condition record needs, in file order."""
    url = latest_topics_url()
    root = ET.parse(cached_download(url, url.rsplit("/", 1)[1])).getroot()
    topics = []
    for t in root.iter("health-topic"):
        if t.get("language") != "English":
            continue
        topics.append({
            "id": t.get("id"),
            "title": t.get("title"),
            "url": t.get("url"),
            "summary": strip_html(t.findtext("full-summary") or ""),
            "also_called": [a.text for a in t.findall("also-called") if a.text],
            "groups": [g.text for g in t.findall("group") if g.text],
            "mesh_ids": [d.get("id") for d in t.findall("mesh-heading/descriptor")],
            "related": [r.text for r in t.findall("related-topic") if r.text],
            "institute": t.findtext("primary-institute"),
            "source_date": root.get("date-generated"),
        })
    return topics

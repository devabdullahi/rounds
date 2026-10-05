#!/usr/bin/env python3
"""Adds CDC pages to the knowledge base: knowledge-base/cdc_pages.jsonl, keyed by condition id.

Uses CDC's official content syndication API (tools.cdc.gov). CDC-authored content is a US
government work (public domain); CDC asks that syndicated pages not be republished in modified
form, so this text is background for authoring only and is never shown to students.

Coverage is mostly infectious and chronic disease; most surgical and many specialty conditions
have no CDC page. Run after build_kb.py, since it reads conditions.jsonl.

    python3 tools/kb-import/cdc.py
"""

from __future__ import annotations

import json
import sys
import urllib.parse

from common import KB, ROOT, cached_json, slug, strip_html, truncate, write_jsonl

MEDIA = "https://tools.cdc.gov/api/v2/resources/media"
DELAY = 0.3
PAGES_PER_CONDITION = 2
PAGE_BUDGET = 6000

# Surveillance protocols and journal reports don't describe how a disease presents.
SKIP_PATHS = ("/mmwr/", "/nhsn/", "/nchs/", "/eid/", "/pcd/")


def search(name: str) -> list[dict]:
    query = urllib.parse.urlencode({"q": name, "mediatype": "html", "language": "english", "max": 20})
    data = cached_json(f"cdc-search-{slug(name)}", f"{MEDIA}?{query}", DELAY)
    return data.get("results", [])


def relevant(results: list[dict], names: list[str]) -> list[dict]:
    """CDC pages whose title names the condition, "About …" overviews first, one per source URL."""
    wanted = [n.lower() for n in names]
    seen: set[str] = set()
    picks = []
    for r in results:
        url = r.get("sourceUrl") or ""
        title = strip_html(r.get("name") or "").lower()
        if not url.startswith("https://www.cdc.gov/") or any(p in url for p in SKIP_PATHS):
            continue
        if url in seen or not any(w in title for w in wanted):
            continue
        seen.add(url)
        picks.append(r)
    picks.sort(key=lambda r: not strip_html(r["name"]).lower().startswith("about"))
    return picks[:PAGES_PER_CONDITION]


def page_text(media_id: int) -> str:
    data = cached_json(f"cdc-page-{media_id}", f"{MEDIA}/{media_id}/syndicate.json", DELAY)
    return truncate(strip_html(data["results"]["content"]), PAGE_BUDGET)


def main() -> None:
    conditions = [json.loads(line) for line in (KB / "conditions.jsonl").open()]
    diseases = [c for c in conditions if c["kind"] == "disease"]
    records = []
    for n, c in enumerate(diseases, 1):
        names = [c["name"]] + [m["name"] for m in c["mesh"]] + c["also_called"]
        pages = relevant(search(c["name"]), names)
        print(f"  [{n}/{len(diseases)}] {c['name']}: {len(pages)} page(s)", file=sys.stderr)
        for p in pages:
            records.append({
                "condition_id": c["id"],
                "condition": c["name"],
                "title": strip_html(p["name"]),
                "url": p["sourceUrl"],
                "date_published": p.get("datePublished"),
                "text": page_text(p["id"]),
                "license": "CDC: US government work, public domain. Authoring background only; don't republish modified.",
            })

    out = KB / "cdc_pages.jsonl"
    write_jsonl(out, records)
    covered = len({r["condition_id"] for r in records})
    print(f"wrote {len(records)} pages for {covered}/{len(diseases)} diseases to {out.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()

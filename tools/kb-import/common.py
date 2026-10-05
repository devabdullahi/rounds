"""Shared download, cache and text helpers for the knowledge-base import scripts."""

from __future__ import annotations

import html
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / ".cache"
KB = ROOT / "knowledge-base"


def fetch(url: str) -> bytes:
    """GETs a URL with curl, which uses the system trust store and proxy settings."""
    result = subprocess.run(
        ["curl", "-sSfL", "--retry", "3", "--max-time", "120", url],
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"GET {url} failed: {result.stderr.decode().strip()}")
    return result.stdout


def cached_download(url: str, name: str) -> Path:
    path = CACHE / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(fetch(url))
    return path


def cached_json(key: str, url: str, delay: float, missing: object = None) -> object:
    """API responses are cached per query so an interrupted run resumes where it stopped.
    `missing` is returned (and cached) when the API answers 404, which openFDA uses for "no match"."""
    path = CACHE / "api" / f"{key}.json"
    if path.exists():
        return json.loads(path.read_text())
    time.sleep(delay)
    try:
        data = json.loads(fetch(url))
    except RuntimeError as error:
        if missing is None or "404" not in str(error):
            raise
        data = missing
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data))
    return data


def strip_html(fragment: str) -> str:
    """Turns an HTML fragment into plain text, keeping list items as '- ' lines."""
    text = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", fragment, flags=re.S | re.I)
    text = re.sub(r"<li[^>]*>\s*", "\n- ", text)
    text = re.sub(r"</p>|<br\s*/?>|</ul>|</ol>|</h\d>|</div>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    lines = [re.sub(r"\s+", " ", line).strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line and line != "-")


def truncate(text: str, limit: int) -> str:
    """Cuts at the last sentence end before `limit` so excerpts don't stop mid-word."""
    if len(text) <= limit:
        return text
    cut = text[:limit]
    end = max(cut.rfind(". "), cut.rfind(".\n"))
    return (cut[:end + 1] if end > limit // 2 else cut).rstrip() + " …"


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:80]


def write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")

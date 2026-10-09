"""Reads and rewrites the one-line-per-condition tag files (specialties.jsonl, systems.jsonl).

Tagging appends as it goes so a long run can resume. That leaves two kinds of junk behind: rows
whose tags came back empty (the model skipped the condition) and older rows for a condition that
was tagged again. `compact` drops both, keeping each condition's latest usable row.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def usable(row: dict, field: str, allow_empty: bool) -> bool:
    """A list of tags; an empty list counts only where "none apply" is a real answer (specialties)."""
    value = row.get(field)
    return isinstance(value, list) and (allow_empty or bool(value))


def read_rows(path: Path, field: str, allow_empty: bool = True) -> dict[str, dict]:
    """Latest usable row per slug; empty when the file doesn't exist yet."""
    if not path.exists():
        return {}
    rows: dict[str, dict] = {}
    for row in map(json.loads, path.read_text().splitlines()):
        if usable(row, field, allow_empty):
            rows[row["slug"]] = row
    return rows


def compact(path: Path, field: str, allow_empty: bool = True) -> None:
    """Rewrites `path` without null rows or superseded duplicates, when it has any."""
    if not path.exists():
        return
    lines = path.read_text().splitlines()
    rows = read_rows(path, field, allow_empty)
    if len(rows) == len(lines):
        return
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows.values()))
    print(f"cleaned {path.name}: dropped {len(lines) - len(rows)} null or superseded row(s)", file=sys.stderr)

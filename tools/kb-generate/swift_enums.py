"""Reads the app's topic enums so the tagging scripts can tell when their ids drift from the app.

The app decodes stored topics with `Clerkship(rawValue:)` and `OrganSystem(rawValue:)`; an id the
enum lacks is dropped without a sound in the app, so the check lives here, where ids are written.
The Swift files are only read, never changed.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDY = ROOT / "Rounds - IOS" / "Rounds" / "Model" / "Study"
CLERKSHIP = STUDY / "Clerkship.swift"
ORGAN_SYSTEM = STUDY / "OrganSystem.swift"

# Declaration lines like `case cardiology, endocrinology`; switch arms (`case .x:`) don't match.
CASE_LINE = re.compile(r"^\s*case\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*$")


def swift_cases(path: Path) -> set[str]:
    """Case names of the first enum in `path`, which are also its raw values (no explicit raw values)."""
    cases: set[str] = set()
    for line in path.read_text().splitlines():
        match = CASE_LINE.match(line)
        if match:
            cases.update(name.strip() for name in match.group(1).split(","))
    return cases


def report(label: str, written: set[str], known: set[str], path: Path) -> int:
    """Prints ids written here that the app lacks, and app cases nothing here can produce."""
    swift = swift_cases(path)
    missing = sorted(written - swift)
    unused = sorted(swift - known)
    if missing:
        print(f"{label}: not in {path.name}, the app will drop them: {', '.join(missing)}", file=sys.stderr)
    if unused:
        print(f"{label}: in {path.name} but never written by the tools: {', '.join(unused)}", file=sys.stderr)
    if not missing and not unused:
        print(f"{label}: ids match {path.name}", file=sys.stderr)
    return len(missing) + len(unused)

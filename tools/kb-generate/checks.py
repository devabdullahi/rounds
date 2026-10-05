"""Validation for generated profiles: a small JSON Schema checker plus rule checks the schema can't express.

The schema checker covers the subset condition_profile.schema.json uses (type, enum, const, required,
properties, additionalProperties, items, minItems, pattern, maxLength, minimum, maximum, $ref), so the
tool needs no third-party packages.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

KB = Path(__file__).resolve().parents[2] / "knowledge-base"
SCHEMA = json.loads((KB / "schema" / "condition_profile.schema.json").read_text())
RANGES = json.loads((KB / "reference_ranges.json").read_text())
TESTS = {t["id"]: t for panel in RANGES["panels"] for t in panel["tests"]}
PANELS = {panel["id"] for panel in RANGES["panels"]}

_TYPES = {
    "object": dict, "array": list, "string": str, "boolean": bool,
    "integer": int, "number": (int, float),
}


# MARK: - Schema

def schema_errors(value: object, schema: dict, path: str = "$") -> list[str]:
    if "$ref" in schema:
        schema = SCHEMA["$defs"][schema["$ref"].rsplit("/", 1)[1]]
    errors: list[str] = []
    expected = schema.get("type")
    if expected:
        kind = _TYPES[expected]
        is_bool = isinstance(value, bool)
        if not isinstance(value, kind) or (is_bool and expected in ("integer", "number")):
            return [f"{path}: expected {expected}"]
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: must be {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not in {schema['enum']}")
    if isinstance(value, str):
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} doesn't match {schema['pattern']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{path}: longer than {schema['maxLength']}")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: below {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: above {schema['maximum']}")
    if isinstance(value, dict):
        props = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}: missing {key}")
        for key, item in value.items():
            if key in props:
                errors += schema_errors(item, props[key], f"{path}.{key}")
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}: unexpected key {key}")
            elif isinstance(schema.get("additionalProperties"), dict):
                errors += schema_errors(item, schema["additionalProperties"], f"{path}.{key}")
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(f"{path}: needs at least {schema['minItems']} items")
        if "items" in schema:
            for i, item in enumerate(value):
                errors += schema_errors(item, schema["items"], f"{path}[{i}]")
    return errors


def section_errors(section: str, value: object) -> list[str]:
    return schema_errors(value, SCHEMA["properties"][section], f"$.{section}")


# MARK: - Rules

def _normal_interval(test: dict) -> tuple[float | None, float | None]:
    """Widest normal interval across sexes, so direction checks don't depend on the patient."""
    lows, highs = [test.get("low")], [test.get("high")]
    for sex in ("female", "male"):
        if sex in test:
            lows.append(test[sex][0])
            highs.append(test[sex][1])
    lows = [v for v in lows if v is not None]
    highs = [v for v in highs if v is not None]
    return (min(lows) if lows else None, max(highs) if highs else None)


def rule_errors(profile: dict) -> list[str]:
    """Checks that need reference data. Every error here blocks the profile."""
    errors: list[str] = []

    for i, lab in enumerate(profile.get("labs", [])):
        where = f"labs[{i}] {lab.get('test_id')}"
        test = TESTS.get(lab.get("test_id"))
        if not test:
            errors.append(f"{where}: unknown test id")
            continue
        if test.get("derived"):
            errors.append(f"{where}: derived test; code computes it, don't list it")
        if lab.get("qualitative"):
            allowed = test.get("abnormal", [])
            for severity, result in lab["qualitative"].items():
                if result not in allowed:
                    errors.append(f"{where}.{severity}: {result!r} not in {allowed}")
        for severity, r in (lab.get("ranges") or {}).items():
            if r["min"] > r["max"]:
                errors.append(f"{where}.{severity}: min above max")
            if test.get("critical_low") is not None and r["max"] < test["critical_low"] * 0.5:
                errors.append(f"{where}.{severity}: implausibly low")
            if test.get("critical_high") is not None and r["min"] > test["critical_high"] * 3:
                errors.append(f"{where}.{severity}: implausibly high")

    temp = (profile.get("vitals") or {}).get("temp") or {}
    for severity, r in temp.items():
        if not (90 <= r["min"] <= 110 and 90 <= r["max"] <= 110):
            errors.append(f"vitals.temp.{severity}: must be °F")
    for vital, ranges in (profile.get("vitals") or {}).items():
        for severity, r in ranges.items():
            if r["min"] > r["max"]:
                errors.append(f"vitals.{vital}.{severity}: min above max")

    for group, refs in (profile.get("workup") or {}).items():
        if group in ("initial", "confirmatory", "supporting", "not_indicated"):
            for ref in refs:
                name = ref["test"]
                looks_like_id = re.fullmatch(r"[a-z0-9_]+", name) is not None
                if looks_like_id and name not in TESTS and name not in PANELS:
                    errors.append(f"workup.{group}: unknown test id {name!r}; use a listed id or the test's plain name")
                if name == "vitals":
                    errors.append(f"workup.{group}: vital signs aren't an orderable test")

    # A test sits in one group, except "not routine, but order it if X": not_indicated plus one
    # conditional entry (only_if) elsewhere.
    groups: dict[str, list[tuple[str, bool]]] = {}
    for group in ("initial", "confirmatory", "supporting", "not_indicated"):
        for ref in (profile.get("workup") or {}).get(group, []):
            groups.setdefault(ref["test"].lower(), []).append((group, bool(ref.get("only_if"))))
    for name, found in groups.items():
        if len(found) == 1:
            continue
        others = [f for f in found if f[0] != "not_indicated"]
        conditional_pair = len(found) == 2 and len(others) == 1 and others[0][1]
        if not conditional_pair:
            errors.append(f"workup: {name!r} appears in {[g for g, _ in found]}; use one group, or not_indicated plus one entry with only_if")

    if profile.get("labs") and profile.get("teaching"):
        if not any(d.get("must_not_miss") for d in profile.get("differential", [])):
            errors.append("differential: no must-not-miss alternative; every case should have one to rule out")
    return errors


def rule_warnings(profile: dict, known_slugs: set[str]) -> list[str]:
    """Worth a reviewer's look but don't block."""
    warnings: list[str] = []
    for lab in profile.get("labs", []):
        test = TESTS.get(lab.get("test_id"))
        if not test or not lab.get("ranges"):
            continue
        low, high = _normal_interval(test)
        directions = set()
        for r in lab["ranges"].values():
            if high is not None and r["min"] > high:
                directions.add("high")
            if low is not None and r["max"] < low:
                directions.add("low")
        if len(directions) > 1:
            warnings.append(f"labs {lab['test_id']}: both high and low across severities")
    for d in profile.get("differential", []):
        if d.get("slug") and d["slug"] not in known_slugs:
            warnings.append(f"differential {d['slug']}: no profile yet")
    return warnings

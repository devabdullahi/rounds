"""Validation for generated profiles: a small JSON Schema checker plus rule checks the schema can't express.

The schema checker covers the subset condition_profile.schema.json uses (type, enum, const, required,
properties, additionalProperties, items, minItems, pattern, maxLength, minimum, maximum, $ref), so the
tool needs no third-party packages.
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

KB = Path(__file__).resolve().parents[2] / "knowledge-base"
SCHEMA = json.loads((KB / "schema" / "condition_profile.schema.json").read_text())
RANGES = json.loads((KB / "reference_ranges.json").read_text())
TESTS = {t["id"]: t for panel in RANGES["panels"] for t in panel["tests"]}
PANELS = {panel["id"] for panel in RANGES["panels"]}
# Hand-written condition slug → {test id: expected direction} for high-yield pairs (see its "about").
DIRECTIONS = json.loads((KB / "lab_directions.json").read_text())["conditions"]

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


# MARK: - Repair

WORKUP_GROUPS = ("initial", "confirmatory", "supporting", "not_indicated")


def _match_test(token: str) -> str | None:
    """Our test id for a model-made id like 'troponin', when exactly one test name contains its words."""
    words = token.replace("_", " ").replace("-", " ").split()
    hits = [tid for tid, t in TESTS.items()
            if not t.get("derived") and all(w in t["name"].lower() for w in words)]
    return hits[0] if len(hits) == 1 else None


def _plain_name(token: str) -> str:
    """'fungal_culture' → 'Fungal culture'; short tokens read as abbreviations ('ecg' → 'ECG')."""
    text = token.replace("_", " ")
    return text.upper() if len(text) <= 4 else text[0].upper() + text[1:]


def repair(profile: dict) -> list[str]:
    """Fixes mechanical slips in place and returns notes for the reviewer.

    Model-made test ids become our id or a plain name, labs with unknown ids are dropped, and a
    test listed in several workup groups is kept once (see _keep_one). Medical content is never
    invented here. Notes come back without repeats.
    """
    notes: list[str] = []
    workup = profile.get("workup") or {}
    for group in WORKUP_GROUPS:
        for ref in workup.get(group, []):
            name = ref["test"]
            if re.fullmatch(r"[a-z0-9_]+", name) and name not in TESTS and name not in PANELS:
                ref["test"] = _match_test(name) or _plain_name(name)
                notes.append(f"workup: renamed '{name}' to '{ref['test']}'")

    kept_labs = []
    for lab in profile.get("labs", []):
        tid = lab.get("test_id")
        if tid not in TESTS:
            match = _match_test(tid or "")
            if match:
                notes.append(f"labs: mapped '{tid}' to '{match}'")
                lab["test_id"] = match
            else:
                notes.append(f"labs: dropped '{tid}' (not in the reference table)")
                continue
        if TESTS[lab["test_id"]].get("derived"):
            notes.append(f"labs: dropped derived '{lab['test_id']}'")
            continue
        kept_labs.append(lab)
    if "labs" in profile:
        profile["labs"] = kept_labs

    ecg = profile.get("ecg")
    if isinstance(ecg, dict) and isinstance(ecg.get("findings"), list):
        extra = [k for k in ecg if k != "findings"]
        for k in extra:
            del ecg[k]
        if extra:
            notes.append(f"ecg: dropped extra keys {', '.join(extra)} (findings carry their own leads)")

    seen: dict[str, list[tuple[str, dict]]] = {}
    for group in WORKUP_GROUPS:
        for ref in workup.get(group, []):
            seen.setdefault(workup_key(ref["test"]), []).append((group, ref))
    for entries in seen.values():
        if len(entries) > 1:
            notes.append(_keep_one(workup, entries))
    return list(dict.fromkeys(notes))


def workup_key(name: str) -> str:
    """'Chest X-ray', 'chest x ray' and 'CHEST X-RAY' are one test: lowercase, punctuation as spaces."""
    return " ".join(re.sub(r"[^a-z0-9]+", " ", name.lower()).split())


def _keep_one(workup: dict, entries: list[tuple[str, dict]]) -> str:
    """Keeps a test listed in several workup groups once and says what happened.

    An order beats not_indicated: "not indicated" plus an order is either a conditional order (one
    of them has only_if, which the kept entry carries) or the model contradicting itself, which a
    reviewer should look at. Among orders the earliest group wins (initial, confirmatory, supporting).
    """
    ordered = [(g, r) for g, r in entries if g != "not_indicated"]
    skipped = [r for g, r in entries if g == "not_indicated"]
    group, kept = (ordered or entries)[0]
    for g, r in entries:
        if r is not kept:  # identity: duplicates are often equal dicts
            workup[g] = [x for x in workup[g] if x is not r]
    note = f"workup: '{kept['test']}' was in {', '.join(g for g, _ in entries)}; kept {group}"
    if not ordered or not skipped:
        return note
    condition = next((r["only_if"] for r in skipped if r.get("only_if")), None)
    if condition and not kept.get("only_if"):
        kept["only_if"] = condition
    if kept.get("only_if"):
        return note + f" as a conditional order (only if {kept['only_if']})"
    return note + "; also listed as not indicated, so the model contradicted itself: check whether to order it"


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
                    errors.append(f"{where}.{severity}: '{result}' not in {', '.join(allowed)}")
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
                    errors.append(f"workup.{group}: unknown test id '{name}'; use a listed id or the test's plain name")
                if name == "vitals":
                    errors.append(f"workup.{group}: vital signs aren't an orderable test")

    # A test sits in one group; a conditional order is one entry with only_if, never also not_indicated.
    groups: dict[str, list[str]] = {}
    for group in WORKUP_GROUPS:
        for ref in (profile.get("workup") or {}).get(group, []):
            groups.setdefault(workup_key(ref["test"]), []).append(group)
    for name, found in groups.items():
        if len(found) > 1:
            errors.append(f"workup: '{name}' appears in {', '.join(found)}; list it once (use only_if for a conditional order)")

    if profile.get("labs") and profile.get("teaching"):
        if not any(d.get("must_not_miss") for d in profile.get("differential", [])):
            errors.append("differential: no must-not-miss alternative; every case should have one to rule out")

    errors += age_errors(profile)
    errors += duplicate_errors(profile)
    errors += empty_string_errors(profile)
    errors += snomed_id_errors(profile)
    errors += direction_errors(profile)
    errors += vital_errors(profile)
    return errors


# Outer limits a planned vital may reach, by age (same as supabase/functions/_shared/vitalcheck.ts):
# past them the value is a wrong number, not a sick patient. Low blood pressures aren't bounded.
VITAL_BOUNDS = [
    (1, {"hr": (50, 230), "rr": (10, 100), "sbp": (0, 130), "dbp": (0, 90)}),
    (18, {"hr": (25, 240), "rr": (8, 80), "sbp": (0, 230), "dbp": (0, 140)}),
    (float("inf"), {"hr": (25, 250), "rr": (4, 60), "sbp": (0, 260), "dbp": (0, 160)}),
]


def _vital_for_age(vital: str, value: float, age: float) -> int:
    """A profile's adult vital as generate-case plans it for a male patient of this age (casegen.ts forPatient)."""
    value = _js_round(value)
    test = TESTS.get(vital)
    if age >= 18 or not test:
        return value
    band = next((b for b in test.get("pediatric", []) if age < b["max_age"]), None)
    if not band:
        return value
    adult = test.get("male") or (test.get("low"), test.get("high"))
    mid = lambda lo, hi: ((lo or 0) + (hi or 0)) / 2
    return _js_round(value + mid(band["low"], band["high"]) - mid(*adult))


def _js_round(x: float) -> int:
    """Halves round up, as JavaScript's Math.round does (Python's round goes to even)."""
    return math.floor(x + 0.5)


def vital_errors(profile: dict) -> list[str]:
    """Vital ranges that plan an impossible value at either end of the typical age range (a newborn's
    own numbers, shifted for their age a second time), and diastolic ranges that reach the systolic."""
    vitals = profile.get("vitals") or {}
    age = (profile.get("patient") or {}).get("age") or {}
    ages = list(dict.fromkeys(a for a in (age.get("typical_min"), age.get("typical_max")) if isinstance(a, (int, float))))
    errors: list[str] = []
    for vital, ranges in vitals.items():
        for severity, r in (ranges or {}).items():
            for a in ages:
                limits = next(b for top, b in VITAL_BOUNDS if a < top).get(vital)
                if not limits:
                    continue
                lo, hi = _vital_for_age(vital, r["min"], a), _vital_for_age(vital, r["max"], a)
                if lo < limits[0] or hi > limits[1]:
                    errors.append(f"vitals.{vital}.{severity}: {r['min']}–{r['max']} plans {lo}–{hi} at age {a:g}, outside "
                                  f"{limits[0]}–{limits[1]}; write vital ranges for an adult (code adjusts them for a child's age)")
                    break
    for severity, s in (vitals.get("sbp") or {}).items():
        d = (vitals.get("dbp") or {}).get(severity)
        if d and (d["min"] >= s["min"] or d["max"] >= s["max"]):
            errors.append(f"vitals.dbp.{severity}: reaches the systolic range")
    return errors


MAX_AGE = 120
# Newborn and infant conditions: an age over 2 means the model wrote days, weeks or months.
INFANT = re.compile(r"neonat|newborn|infant")
MAX_INFANT_AGE = 2


def age_errors(profile: dict) -> list[str]:
    """Ages are whole years; days or months written as years show up as impossible numbers."""
    age = (profile.get("patient") or {}).get("age") or {}
    errors = [f"patient.age.{k}: over {MAX_AGE}; ages are in years"
              for k, v in age.items() if isinstance(v, (int, float)) and not isinstance(v, bool) and v > MAX_AGE]
    name = f"{profile.get('slug', '')} {(profile.get('triage') or {}).get('name', '')}".lower()
    oldest = age.get("possible_max", age.get("typical_max"))
    if INFANT.search(name) and isinstance(oldest, (int, float)) and MAX_AGE >= oldest > MAX_INFANT_AGE:
        key = "possible_max" if "possible_max" in age else "typical_max"
        errors.append(f"patient.age.{key}: over {MAX_INFANT_AGE} for a newborn or infant condition; ages are in years")
    return errors


# A list item's identity: two labs with one test_id, or two findings with one id, are the same item.
ITEM_KEYS = ("test_id", "id", "slug", "text")


def _content(profile: dict):
    """(path, value) for the generated content: everything but the pipeline's own bookkeeping."""
    for key, value in profile.items():
        if key != "generation":
            yield f"$.{key}", value


def _walk(path: str, value: object):
    """Every (path, value) inside value, depth first, in document order."""
    yield path, value
    if isinstance(value, dict):
        for k, v in value.items():
            yield from _walk(f"{path}.{k}", v)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from _walk(f"{path}[{i}]", v)


def duplicate_errors(profile: dict) -> list[str]:
    """The same string twice in a list, or two list items with the same id, test_id, slug or text."""
    errors: list[str] = []
    for top, section in _content(profile):
        for path, value in _walk(top, section):
            if not isinstance(value, list):
                continue
            seen: set[tuple[str, str]] = set()
            for item in value:
                if isinstance(item, str):
                    field, text = "", item
                elif isinstance(item, dict):
                    field = next((k for k in ITEM_KEYS if isinstance(item.get(k), str)), None)
                    if field is None:
                        continue
                    text = item[field]
                else:
                    continue
                marker = (field, text.strip().lower())
                if marker in seen:
                    errors.append(f"{path}: duplicate {field + ' ' if field else ''}'{text}'")
                seen.add(marker)
    return errors


def empty_string_errors(profile: dict) -> list[str]:
    return [f"{path}: empty string"
            for top, section in _content(profile) for path, value in _walk(top, section)
            if isinstance(value, str) and not value.strip()]


def snomed_id_errors(profile: dict) -> list[str]:
    """SNOMED CT content is licensed: profiles carry snomed_verified flags, never concept ids."""
    errors: list[str] = []
    for path, value in _walk("$", profile):
        if isinstance(value, dict) and "snomed_id" in value:
            errors.append(f"{path}.snomed_id: SNOMED CT ids are licensed content; keep only snomed_verified")
    return errors


SEVERITIES = ("mild", "moderate", "severe", "critical")


def direction_errors(profile: dict) -> list[str]:
    """Labs that move the wrong way with severity, for the hand-written pairs in lab_directions.json."""
    errors: list[str] = []
    expected = DIRECTIONS.get(profile.get("slug"), {})
    for lab in profile.get("labs") or []:
        direction = expected.get(lab.get("test_id"))
        test = TESTS.get(lab.get("test_id"))
        if not direction or not test or not lab.get("ranges"):
            continue
        low, high = _normal_interval(test)
        where = f"labs {lab['test_id']}"
        ranges = [(s, lab["ranges"][s]) for s in SEVERITIES if s in lab["ranges"]]
        if direction in ("up", "down"):
            rising = direction == "up"
            mids = [(s, (r["min"] + r["max"]) / 2) for s, r in ranges]
            for (before, a), (after, b) in zip(mids, mids[1:]):
                if (b < a) if rising else (b > a):
                    errors.append(f"{where}: should {'rise' if rising else 'fall'} with severity, but {after} is {'lower' if rising else 'higher'} than {before}")
            top, mid = mids[-1]
            bound = high if rising else low
            if bound is not None and ((mid <= bound) if rising else (mid >= bound)):
                errors.append(f"{where}.{top}: should be {'above' if rising else 'below'} normal at the worst listed severity")
        for s, r in ranges:
            if direction == "normal_or_up" and low is not None and r["max"] < low:
                errors.append(f"{where}.{s}: should be normal or high, not low")
            if direction == "normal_or_down" and high is not None and r["min"] > high:
                errors.append(f"{where}.{s}: should be normal or low, not high")
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


def main() -> None:
    """Prints {slug: {rules, repairs, after_repair}} for the given profiles as JSON, so the edge
    function's port (profilegen_test.ts) can be checked against this file on the real corpus."""
    import copy
    import sys
    paths = [Path(a) for a in sys.argv[1:]] or sorted((KB / "profiles").glob("*.json"))
    out = {}
    for path in paths:
        profile = json.loads(path.read_text())
        repaired = copy.deepcopy(profile)
        notes = repair(repaired)
        out[path.stem] = {"rules": rule_errors(profile), "repairs": notes, "after_repair": rule_errors(repaired)}
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()

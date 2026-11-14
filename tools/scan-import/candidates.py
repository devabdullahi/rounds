"""Turns expert-labelled NIH ChestX-ray14 subsets into candidate assets.

Only two label sources qualify an image: NIH's radiologist bounding boxes (BBox_List_2017.csv) and
Google's adjudicated label sets. NIH's NLP labels never do, and "normal" never comes from NIH's
"No Finding". A candidate is a dict with the `private.scan_assets` columns that the labels decide
(finding, side, zone, view, age, sex, label_source, source_image); the image, report and gate are
added later.
"""

from __future__ import annotations

import csv
from pathlib import Path

# Google's adjudicated sets are optional: flip this off to build the library from NIH boxes alone.
USE_GOOGLE_LABELS = True

# NIH box label -> our finding. Anything else (Fibrosis, ...) has no wording and is skipped.
NIH_BOX_FINDINGS = {
    "Atelectasis": "atelectasis",
    "Effusion": "effusion",
    "Infiltrate": "opacity",
    "Pneumonia": "opacity",
    "Mass": "nodule_mass",
    "Nodule": "nodule_mass",
    "Pneumothorax": "pneumothorax",
    "Cardiomegaly": "cardiomegaly",
}
# Boxes on these findings carry no side or zone: they are central or bilateral.
NIH_DIFFUSE = {"cardiomegaly"}

# Google's all-findings test_labels.csv. Their documentation describes the file (image ID, a
# normal/abnormal column, one column per NIH finding and "Other") but does not list the headers or
# the cell values. CONFIRM THESE AGAINST THE DOWNLOADED FILE before the first run.
GOOGLE_IMAGE_COLUMN = "Image ID"
GOOGLE_NORMAL_COLUMN = "Normal"
GOOGLE_FINDING_COLUMNS = {"edema": "Edema", "emphysema": "Emphysema", "cardiomegaly": "Cardiomegaly"}
# Every other finding column in that file; any positive among them disqualifies an image, so an
# "edema" image is never also read as something else.
GOOGLE_OTHER_COLUMNS = ("Atelectasis", "Consolidation", "Effusion", "Fibrosis", "Hernia", "Infiltration",
                        "Mass", "Nodule", "Pleural_Thickening", "Pneumonia", "Pneumothorax", "Other")
GOOGLE_POSITIVE = {"YES", "TRUE", "1", "1.0"}

# NIH's age field has typos in the hundreds (e.g. 412); a student would notice a 412-year-old.
MAX_AGE = 110
# A box that reaches this far past the image midline on its minor side has no honest left or right.
MIDLINE_TOLERANCE = 0.10


def side_zone(x: float, y: float, w: float, h: float, width: int = 1024, height: int = 1024) -> tuple[str | None, str | None]:
    """(side, zone) for a box in image pixels. Side is the patient's, by radiographic convention:
    the patient's right sits on the viewer's left. A box straddling the midline gives (None, None)."""
    midline = width / 2
    left_extent = midline - x
    right_extent = x + w - midline
    if left_extent > 0 and right_extent > 0 and min(left_extent, right_extent) > MIDLINE_TOLERANCE * width:
        return None, None
    side = "right" if x + w / 2 < midline else "left"
    centre_y = y + h / 2
    zone = "upper" if centre_y < height / 3 else "middle" if centre_y < 2 * height / 3 else "lower"
    return side, zone


def _entries(entry_csv: Path) -> dict[str, dict]:
    """Patient metadata per image from Data_Entry_2017.csv, skipping rows we cannot use."""
    entries: dict[str, dict] = {}
    with open(entry_csv, newline="") as f:
        for row in csv.DictReader(f):
            try:
                age = int(row["Patient Age"])
                width = int(row["OriginalImage[Width"])
                height = int(row["Height]"])
            except (KeyError, ValueError):
                continue
            sex = {"M": "male", "F": "female"}.get(row.get("Patient Gender", ""))
            view = row.get("View Position", "")
            if sex is None or view not in ("PA", "AP") or not 0 <= age <= MAX_AGE:
                continue
            entries[row["Image Index"]] = {"age": age, "sex": sex, "view": view, "width": width, "height": height}
    return entries


def nih_box_candidates(bbox_csv: Path, entry_csv: Path) -> list[dict]:
    """Candidates from NIH's radiologist boxes. An image whose boxes disagree (different findings, sides
    or zones) is dropped rather than guessed at."""
    entries = _entries(Path(entry_csv))
    labels: dict[str, set[tuple]] = {}
    with open(bbox_csv, newline="") as f:
        reader = csv.reader(f)
        next(reader, None)
        # Positional: the header splits "Bbox [x,y,w,h]" across columns.
        for row in reader:
            if len(row) < 6 or row[0] not in entries or row[1] not in NIH_BOX_FINDINGS:
                continue
            finding = NIH_BOX_FINDINGS[row[1]]
            if finding in NIH_DIFFUSE:
                label = (finding, None, None)
            else:
                meta = entries[row[0]]
                side, zone = side_zone(*(float(v) for v in row[2:6]), width=meta["width"], height=meta["height"])
                if side is None:
                    label = None
                else:
                    label = (finding, side, zone)
            # A rejected (midline) box still counts as a label, so it can conflict with a clean one.
            labels.setdefault(row[0], set()).add(label)

    result = []
    for image, found in labels.items():
        if None in found:
            continue
        # Different sides, or different zones on one side, mean the label is not one place: drop it.
        if len(found) != 1:
            continue
        finding, side, zone = next(iter(found))
        meta = entries[image]
        result.append({"source_image": image, "finding": finding, "side": side, "zone": zone,
                       "view": meta["view"], "age": meta["age"], "sex": meta["sex"], "label_source": "nih_bbox"})
    return sorted(result, key=lambda c: c["source_image"])


def google_candidates(all_findings_csv: Path, entry_csv: Path) -> list[dict]:
    """Adjudicated normals and single diffuse findings from Google's all-findings set. Lateral
    findings from Google's sets are skipped: they carry no side, and the report needs one."""
    if not USE_GOOGLE_LABELS:
        return []
    entries = _entries(Path(entry_csv))
    by_column = {column: finding for finding, column in GOOGLE_FINDING_COLUMNS.items()}
    result = []
    with open(all_findings_csv, newline="") as f:
        for row in csv.DictReader(f):
            image = row.get(GOOGLE_IMAGE_COLUMN, "")
            meta = entries.get(image)
            if meta is None:
                continue
            positive = {c for c in [*by_column, *GOOGLE_OTHER_COLUMNS]
                        if row.get(c, "").strip().upper() in GOOGLE_POSITIVE}
            if row.get(GOOGLE_NORMAL_COLUMN, "").strip().upper() in GOOGLE_POSITIVE:
                finding = "normal" if not positive else None
            else:
                finding = by_column[next(iter(positive))] if len(positive) == 1 and positive <= set(by_column) else None
            if finding is None:
                continue
            result.append({"source_image": image, "finding": finding, "side": None, "zone": None,
                           "view": meta["view"], "age": meta["age"], "sex": meta["sex"], "label_source": "google_all"})
    return result

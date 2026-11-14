"""Builds the real chest X-ray library from NIH ChestX-ray14.

    python3 run.py --dry-run     (default) pick, fetch, re-encode and gate candidates; write
                                 knowledge-base/licensed/scans/out/ (JPEGs + assets.json) to spot-check
    python3 run.py --upload      send what the dry run wrote to Storage and private.scan_assets

Raw label files and downloaded PNGs stay in knowledge-base/licensed/scans/ (git-ignored). See README.md.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import urllib.request
import uuid
from collections import Counter
from pathlib import Path

import candidates
import reports
from encode import RejectedImage, reencode
from gate import agrees, gate
from upload import upload_all

ROOT = Path(__file__).resolve().parents[2] / "knowledge-base" / "licensed" / "scans"
IMAGE_URL = "https://storage.googleapis.com/gcs-public-data--healthcare-nih-chest-xray/png/"
# Library size: enough variety per finding and side that a case rarely repeats an image.
MAX_PER_BUCKET = 30
MIN_NORMALS = 60


def log(message: str) -> None:
    sys.stderr.write(message + "\n")


def fetch_png(name: str, raw_dir: Path) -> bytes:
    """Downloads one image (cached in raw/), one at a time."""
    cached = raw_dir / name
    if cached.exists():
        return cached.read_bytes()
    request = urllib.request.Request(IMAGE_URL + name, headers={"User-Agent": "scan-import"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    raw_dir.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(data)
    return data


def collect(root: Path) -> list[dict]:
    pool = candidates.nih_box_candidates(root / "BBox_List_2017.csv", root / "Data_Entry_2017.csv")
    google = root / "google_all_findings_test_labels.csv"
    if candidates.USE_GOOGLE_LABELS and google.exists():
        pool += candidates.google_candidates(google, root / "Data_Entry_2017.csv")
    return pool


def write_manifest(manifest: Path, rows: list[dict]) -> None:
    manifest.write_text(json.dumps(rows, indent=2))


def build(root: Path, limit: int | None) -> list[dict]:
    """Walks shuffled candidates, filling each (finding, side) bucket. Stops at `limit` candidates
    tried (for small spot-check runs), or when every bucket is full."""
    out_dir = root / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = out_dir / "assets.json"
    pool = collect(root)
    random.Random(7).shuffle(pool)
    kept: Counter = Counter()
    rows: list[dict] = []
    tried = 0
    for c in pool:
        bucket = (c["finding"], c["side"])
        if kept[bucket] >= (MIN_NORMALS if c["finding"] == "normal" else MAX_PER_BUCKET):
            continue
        if limit is not None and tried >= limit:
            break
        tried += 1
        try:
            jpeg = reencode(fetch_png(c["source_image"], root / "raw"))
            result = gate(jpeg)
        except (RejectedImage, OSError, RuntimeError) as error:
            log(f"skip {c['source_image']}: {error}")
            continue
        if not agrees(result, c["finding"], c["side"]):
            log(f"gate rejected {c['source_image']} ({c['finding']} {c['side']}): {result['answers']}")
            continue
        asset_id = str(uuid.uuid4())
        object_name = f"{asset_id}.jpg"
        (out_dir / object_name).write_bytes(jpeg)
        rows.append({"id": asset_id, "object_name": object_name, **c,
                     "report": reports.report(c["finding"], c["side"], c["zone"]), "gate": result})
        kept[bucket] += 1
        # Written per asset so a crash never leaves JPEGs in out/ that the manifest does not list.
        write_manifest(manifest, rows)
    log(f"kept {len(rows)} of {tried} tried: " + ", ".join(f"{f}/{s or '-'}={n}" for (f, s), n in sorted(kept.items(), key=str)))
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="write out/ locally (default)")
    mode.add_argument("--upload", action="store_true", help="upload out/ to Storage and the database")
    parser.add_argument("--limit", type=int, help="try at most this many candidates (e.g. 50 for a spot-check)")
    parser.add_argument("--root", type=Path, default=ROOT, help="folder holding the label files (default: knowledge-base/licensed/scans)")
    args = parser.parse_args()

    out_dir = args.root / "out"
    manifest = out_dir / "assets.json"
    if args.upload:
        if not manifest.exists():
            raise SystemExit("No out/assets.json: run the dry run and spot-check it first")
        upload_all(out_dir, json.loads(manifest.read_text()))
        log("uploaded")
        return
    rows = build(args.root, args.limit)
    write_manifest(manifest, rows)
    log(f"wrote {manifest}")


if __name__ == "__main__":
    main()

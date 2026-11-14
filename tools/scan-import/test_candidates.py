"""Tests for candidates.py. Run: python3 -m unittest"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import candidates
from candidates import google_candidates, nih_box_candidates, side_zone

ENTRY_HEADER = ('"Image Index","Finding Labels","Follow-up #","Patient ID","Patient Age","Patient Gender",'
                '"View Position","OriginalImage[Width","Height]","OriginalImagePixelSpacing[x","y]"\n')
BBOX_HEADER = 'Image Index,Finding Label,Bbox [x,y,w,h],,,\n'


COLUMNS = [*candidates.GOOGLE_FINDING_COLUMNS.values(), *candidates.GOOGLE_OTHER_COLUMNS]


def write(directory: str, name: str, text: str) -> Path:
    path = Path(directory) / name
    path.write_text(text)
    return path


class SideZoneTests(unittest.TestCase):
    def test_box_left_of_midline_is_the_patients_right(self):
        self.assertEqual(side_zone(100, 100, 80, 80), ("right", "upper"))

    def test_box_right_of_midline_is_the_patients_left(self):
        self.assertEqual(side_zone(800, 700, 80, 80), ("left", "lower"))

    def test_box_crossing_the_midline_has_no_side(self):
        self.assertEqual(side_zone(400, 400, 300, 100), (None, None))

    def test_small_overlap_with_the_midline_keeps_its_side(self):
        self.assertEqual(side_zone(450, 400, 100, 100), ("right", "middle"))

    def test_uses_the_real_image_size(self):
        self.assertEqual(side_zone(100, 100, 100, 100, width=2048, height=2048), ("right", "upper"))
        self.assertEqual(side_zone(1500, 1900, 100, 100, width=2048, height=2048), ("left", "lower"))


class NihBoxTests(unittest.TestCase):
    def build(self, bbox_rows: str, entry_rows: str) -> list[dict]:
        with tempfile.TemporaryDirectory() as d:
            return nih_box_candidates(write(d, "bbox.csv", BBOX_HEADER + bbox_rows),
                                      write(d, "entry.csv", ENTRY_HEADER + entry_rows))

    def test_maps_label_side_zone_and_patient_fields(self):
        rows = self.build("a.png,Pneumonia,100,100,80,80,,,\n",
                          "a.png,Pneumonia,0,1,058,M,PA,1024,1024,0.14,0.14\n")
        self.assertEqual(rows, [{
            "source_image": "a.png", "finding": "opacity", "side": "right", "zone": "upper",
            "view": "PA", "age": 58, "sex": "male", "label_source": "nih_bbox"}])

    def test_cardiomegaly_has_no_side_or_zone(self):
        rows = self.build("c.png,Cardiomegaly,300,500,400,300,,,\n", "c.png,Cardiomegaly,0,2,40,F,AP,1024,1024,0.14,0.14\n")
        self.assertEqual((rows[0]["finding"], rows[0]["side"], rows[0]["zone"], rows[0]["sex"]),
                         ("cardiomegaly", None, None, "female"))

    def test_drops_midline_boxes_unmapped_labels_and_implausible_ages(self):
        rows = self.build("m.png,Mass,400,400,300,100,,,\n"
                          "x.png,Fibrosis,100,100,80,80,,,\n"
                          "o.png,Nodule,100,100,80,80,,,\n",
                          "m.png,Mass,0,3,50,M,PA,1024,1024,0.1,0.1\n"
                          "x.png,Fibrosis,0,4,50,M,PA,1024,1024,0.1,0.1\n"
                          "o.png,Nodule,0,5,412,M,PA,1024,1024,0.1,0.1\n")
        self.assertEqual(rows, [])

    def test_images_with_conflicting_boxes_are_dropped(self):
        rows = self.build("k.png,Effusion,100,500,80,80,,,\nk.png,Effusion,800,500,80,80,,,\n",
                          "k.png,Effusion,0,6,50,M,PA,1024,1024,0.1,0.1\n")
        self.assertEqual(rows, [])

    def test_same_side_boxes_in_different_zones_are_dropped(self):
        rows = self.build("z.png,Mass,100,100,80,80,,,\nz.png,Mass,100,800,80,80,,,\n",
                          "z.png,Mass,0,6,50,M,PA,1024,1024,0.1,0.1\n")
        self.assertEqual(rows, [])

    def test_repeated_identical_boxes_collapse_to_one_candidate(self):
        rows = self.build("k.png,Effusion,100,500,80,80,,,\nk.png,Effusion,110,505,80,80,,,\n",
                          "k.png,Effusion,0,6,50,M,PA,1024,1024,0.1,0.1\n")
        self.assertEqual(len(rows), 1)


class GoogleTests(unittest.TestCase):
    def labels(self, rows: str) -> list[dict]:
        header = ",".join([candidates.GOOGLE_IMAGE_COLUMN, candidates.GOOGLE_NORMAL_COLUMN, *COLUMNS])
        with tempfile.TemporaryDirectory() as d:
            return google_candidates(write(d, "g.csv", header + "\n" + rows),
                                     write(d, "entry.csv", ENTRY_HEADER + "n.png,No Finding,0,7,30,F,PA,1024,1024,0.1,0.1\n"
                                           "e.png,Edema,0,8,60,M,AP,1024,1024,0.1,0.1\n"
                                           "l.png,Pneumothorax,0,9,60,M,AP,1024,1024,0.1,0.1\n"))

    def row(self, image: str, normal: str, **flags: str) -> str:
        return ",".join([image, normal, *(flags.get(name, "NO") for name in COLUMNS)])

    def test_keeps_adjudicated_normal_and_a_single_diffuse_finding(self):
        rows = self.labels("\n".join([
            self.row("n.png", "YES"),
            self.row("e.png", "NO", **{candidates.GOOGLE_FINDING_COLUMNS["edema"]: "YES"}),
            self.row("l.png", "NO", **{"Pneumothorax": "YES"}),
        ]))
        self.assertEqual([(r["source_image"], r["finding"], r["side"]) for r in rows],
                         [("n.png", "normal", None), ("e.png", "edema", None)])
        self.assertTrue(all(r["label_source"] == "google_all" for r in rows))

    def test_normal_with_a_positive_finding_is_dropped(self):
        rows = self.labels(self.row("n.png", "YES", **{candidates.GOOGLE_FINDING_COLUMNS["edema"]: "YES"}))
        self.assertEqual(rows, [])

    def test_switch_off_returns_nothing(self):
        original = candidates.USE_GOOGLE_LABELS
        candidates.USE_GOOGLE_LABELS = False
        try:
            self.assertEqual(self.labels(self.row("n.png", "YES")), [])
        finally:
            candidates.USE_GOOGLE_LABELS = original


if __name__ == "__main__":
    unittest.main()

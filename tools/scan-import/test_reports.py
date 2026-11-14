"""Tests for reports.py. Run: python3 -m unittest"""

from __future__ import annotations

import re
import unittest

from reports import DIFFUSE, LATERAL, report

DIAGNOSIS_WORDS = {"pneumonia", "pneumothorax", "effusion", "edema", "emphysema", "cardiomegaly",
                   "atelectasis", "nodule", "mass", "fracture"}


def words(text: str) -> set[str]:
    return set(re.findall(r"[a-z]+", text.lower()))


class ReportTests(unittest.TestCase):
    def test_lateral_reports_name_a_side_and_no_diagnosis(self):
        for finding in sorted(LATERAL):
            for side in ("left", "right"):
                with self.subTest(finding=finding, side=side):
                    text = report(finding, side, "upper")
                    self.assertEqual(words(text) & DIAGNOSIS_WORDS, set())
                    self.assertIn(side, words(text))

    def test_diffuse_reports_never_name_a_side(self):
        for finding in sorted(DIFFUSE):
            with self.subTest(finding=finding):
                text = report(finding, None, None)
                self.assertFalse(words(text) & {"left", "right"})
                if finding != "normal":
                    self.assertEqual(words(text) & DIAGNOSIS_WORDS, set())

    def test_normal_only_negates_diagnoses(self):
        self.assertEqual(report("normal", None, None),
                         "Lungs are clear. Heart size within normal limits. No pleural effusion or pneumothorax.")

    def test_zone_appears_where_the_wording_uses_one(self):
        self.assertEqual(report("opacity", "right", "lower"),
                         "Airspace opacity in the right lower zone. Heart size within normal limits.")

    def test_incomplete_labels_are_refused(self):
        for finding, side, zone in [("opacity", None, "upper"), ("opacity", "left", None), ("fracture", "left", "upper")]:
            with self.subTest(finding=finding, side=side, zone=zone):
                with self.assertRaises(ValueError):
                    report(finding, side, zone)


if __name__ == "__main__":
    unittest.main()

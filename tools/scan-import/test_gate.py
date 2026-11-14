"""Tests for the pure part of gate.py (no network). Run: python3 -m unittest"""

from __future__ import annotations

import unittest

from gate import agrees


def result(*answers: tuple[str, str]) -> dict:
    return {"model": "m", "answers": [{"finding": f, "side": s} for f, s in answers]}


class AgreesTests(unittest.TestCase):
    def test_all_passes_must_match_finding_and_side(self):
        self.assertTrue(agrees(result(*[("opacity", "right")] * 3), "opacity", "right"))
        self.assertFalse(agrees(result(("opacity", "right"), ("opacity", "right"), ("opacity", "left")), "opacity", "right"))
        self.assertFalse(agrees(result(("opacity", "right"), ("opacity", "right"), ("effusion", "right")), "opacity", "right"))

    def test_diffuse_findings_ignore_side(self):
        self.assertTrue(agrees(result(("edema", "none"), ("edema", "left"), ("edema", "none")), "edema", None))

    def test_too_few_answers_fail(self):
        self.assertFalse(agrees(result(("normal", "none")), "normal", None))


if __name__ == "__main__":
    unittest.main()

"""Tests for the profile repairs and rule checks in checks.py. Run: python3 -m unittest test_checks"""

from __future__ import annotations

import unittest

from checks import (age_errors, direction_errors, duplicate_errors, empty_string_errors, repair, rule_errors,
                    snomed_id_errors, workup_key)


def ranges(*mids: tuple[str, float, float]) -> dict:
    return {s: {"min": lo, "max": hi} for s, lo, hi in mids}


class WorkupRepairTests(unittest.TestCase):
    def test_conditional_not_indicated_moves_its_condition_to_the_order(self):
        profile = {"workup": {
            "initial": [{"test": "Chest X-ray"}],
            "not_indicated": [{"test": "chest x ray", "only_if": "crackles on exam"}],
        }}
        notes = repair(profile)
        self.assertEqual(profile["workup"]["initial"], [{"test": "Chest X-ray", "only_if": "crackles on exam"}])
        self.assertEqual(profile["workup"]["not_indicated"], [])
        self.assertEqual(len(notes), 1)
        self.assertIn("conditional order", notes[0])
        self.assertEqual(rule_errors(profile), [])

    def test_unconditional_contradiction_keeps_the_order_and_flags_it(self):
        profile = {"workup": {"initial": [{"test": "tsh"}], "not_indicated": [{"test": "tsh", "why": "not needed"}]}}
        notes = repair(profile)
        self.assertEqual(profile["workup"], {"initial": [{"test": "tsh"}], "not_indicated": []})
        self.assertEqual(notes, ["workup: 'tsh' was in initial, not_indicated; kept initial; also listed as not "
                                 "indicated, so the model contradicted itself: check whether to order it"])

    def test_a_second_repair_finds_nothing(self):
        profile = {"workup": {"initial": [{"test": "hcg"}], "confirmatory": [{"test": "HCG"}],
                              "not_indicated": [{"test": "hcg"}]}}
        self.assertEqual(len(repair(profile)), 1)
        self.assertEqual(profile["workup"], {"initial": [{"test": "hcg"}], "confirmatory": [], "not_indicated": []})
        self.assertEqual(repair(profile), [])

    def test_equal_duplicates_in_one_group_keep_one(self):
        profile = {"workup": {"initial": [{"test": "cbc"}, {"test": "cbc"}]}}
        self.assertEqual(repair(profile), ["workup: 'cbc' was in initial, initial; kept initial"])
        self.assertEqual(profile["workup"]["initial"], [{"test": "cbc"}])

    def test_rules_reject_any_test_in_two_groups(self):
        profile = {"workup": {"initial": [{"test": "CT abdomen", "only_if": "x"}], "not_indicated": [{"test": "ct abdomen"}]}}
        self.assertEqual(rule_errors(profile), [
            "workup: 'ct abdomen' appears in initial, not_indicated; list it once (use only_if for a conditional order)"])

    def test_workup_key_ignores_case_and_punctuation(self):
        for name in ("Chest X-ray", "chest x ray", "CHEST  X-RAY "):
            self.assertEqual(workup_key(name), "chest x ray")


class AgeTests(unittest.TestCase):
    CASES = [
        # slug, age, expected error count
        ("appendicitis", {"typical_min": 10, "typical_max": 30, "possible_max": 90}, 0),
        ("appendicitis", {"typical_min": 10, "typical_max": 30, "possible_max": 150}, 1),
        ("neonatal-sepsis", {"typical_min": 0, "typical_max": 90, "possible_max": 90}, 1),
        ("neonatal-sepsis", {"typical_min": 0, "typical_max": 0, "possible_max": 1}, 0),
        ("reflux-in-infants", {"typical_min": 0, "typical_max": 12}, 1),
        ("transient-tachypnea-of-the-newborn", {"typical_min": 0, "typical_max": 0, "possible_max": 400}, 1),
    ]

    def test_age_table(self):
        for slug, age, count in self.CASES:
            with self.subTest(slug=slug, age=age):
                self.assertEqual(len(age_errors({"slug": slug, "patient": {"age": age}})), count)

    def test_infant_in_the_triage_name_counts(self):
        profile = {"slug": "x", "triage": {"name": "Infant botulism"}, "patient": {"age": {"typical_max": 1, "possible_max": 5}}}
        self.assertEqual(age_errors(profile), [
            "patient.age.possible_max: over 2 for a newborn or infant condition; ages are in years"])


class ContentTests(unittest.TestCase):
    def test_duplicates(self):
        profile = {
            "patient": {"comorbidities": ["Obesity", "obesity "], "risk_factors": [
                {"text": "Smoking", "strength": "strong"}, {"text": "smoking", "strength": "weak"}]},
            "labs": [{"test_id": "wbc"}, {"test_id": "wbc"}],
            "exam": {"findings": [{"id": "rebound"}, {"id": "guarding"}, {"id": "rebound"}]},
            "generation": {"validation": {"review_issues": ["same", "same"]}},
        }
        self.assertEqual(duplicate_errors(profile), [
            "$.patient.comorbidities: duplicate 'obesity '",
            "$.patient.risk_factors: duplicate text 'smoking'",
            "$.labs: duplicate test_id 'wbc'",
            "$.exam.findings: duplicate id 'rebound'",
        ])

    def test_empty_strings_report_their_path(self):
        profile = {"presentation": {"chief_complaints": [{"text": " "}]}, "teaching": {"pearls": ["ok", ""]},
                   "generation": {"note": ""}}
        self.assertEqual(empty_string_errors(profile), [
            "$.presentation.chief_complaints[0].text: empty string", "$.teaching.pearls[1]: empty string"])

    def test_snomed_ids_anywhere(self):
        profile = {"exam": {"findings": [{"id": "a", "snomed_id": "123", "snomed_verified": True}]},
                   "generation": {"snomed_id": "1"}}
        self.assertEqual(len(snomed_id_errors(profile)), 2)
        self.assertEqual(snomed_id_errors({"exam": {"findings": [{"snomed_verified": True}]}}), [])


class DirectionTests(unittest.TestCase):
    CASES = [
        # slug, test, ranges, expected errors
        ("pancreatitis", "lipase", ranges(("mild", 180, 420), ("critical", 1500, 4000)), []),
        ("pancreatitis", "lipase", ranges(("mild", 800, 1200), ("severe", 300, 500)),
         ["labs lipase: should rise with severity, but severe is lower than mild"]),
        ("pancreatitis", "ca", ranges(("moderate", 10.3, 11.0), ("severe", 7.0, 8.0)),
         ["labs ca.moderate: should be normal or low, not high"]),
        ("pancreatitis", "ca", ranges(("severe", 7.0, 8.0)), []),
        ("heart-attack", "hs_tnt", ranges(("mild", 5, 10), ("critical", 10, 20)),
         ["labs hs_tnt.critical: should be above normal at the worst listed severity"]),
        ("diabetes-type-1", "k", ranges(("mild", 3.3, 3.5), ("critical", 1.5, 2.0)),
         ["labs k.critical: should be normal or high, not low"]),
        ("diabetes-type-1", "hco3", ranges(("mild", 20, 22), ("critical", 4, 8)), []),
        ("diabetes-type-1", "hco3", ranges(("mild", 20, 22), ("critical", 24, 26)),
         ["labs hco3: should fall with severity, but critical is higher than mild",
          "labs hco3.critical: should be below normal at the worst listed severity"]),
        ("appendicitis", "ca", ranges(("mild", 12, 13)), []),  # no expectation listed
    ]

    def test_direction_table(self):
        for slug, test, r, expected in self.CASES:
            with self.subTest(slug=slug, test=test):
                profile = {"slug": slug, "labs": [{"test_id": test, "ranges": r}]}
                self.assertEqual(direction_errors(profile), expected)


if __name__ == "__main__":
    unittest.main()

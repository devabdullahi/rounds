"""Tests for run.build with the network and OpenAI replaced. Run: python3 -m unittest"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import gate as gate_module
import run


def cand(name: str) -> dict:
    return {"source_image": name, "finding": "edema", "side": None, "zone": None,
            "view": "PA", "age": 50, "sex": "male", "label_source": "google_all"}


GOOD = {"choices": [{"message": {"content": '{"finding": "edema", "side": "none"}'}}]}


class MalformedReplyTests(unittest.TestCase):
    def test_gate_raises_gate_error_for_every_malformed_shape(self):
        for reply in [{"choices": [{"message": {"content": ""}}]}, {"choices": [{"message": {"content": "no json"}}]},
                      {"choices": []}, {}, {"choices": [{"message": {"content": "[1]"}}]}]:
            with self.subTest(reply=reply), mock.patch.dict("os.environ", {"OPENAI_API_KEY": "k"}):
                with self.assertRaises(gate_module.GateError):
                    gate_module.gate(b"x", post=lambda *a: reply)

    def test_gate_returns_answers_for_good_replies(self):
        with mock.patch.dict("os.environ", {"OPENAI_API_KEY": "k"}):
            result = gate_module.gate(b"x", post=lambda *a: GOOD)
        self.assertTrue(gate_module.agrees(result, "edema", None))

    def test_build_skips_a_malformed_candidate_and_keeps_the_manifest(self):
        replies = {"bad.png": {"choices": []}, "ok.png": GOOD}
        current = []

        def fake_gate(jpeg: bytes) -> dict:
            return gate_module.gate(jpeg, post=lambda *a: replies[current[-1]])

        def fake_reencode(png: bytes) -> bytes:
            return png

        def fake_fetch(name: str, raw: Path) -> bytes:
            current.append(name)
            return b"jpeg-" + name.encode()

        with tempfile.TemporaryDirectory() as d, mock.patch.dict("os.environ", {"OPENAI_API_KEY": "k"}), \
                mock.patch.object(run, "collect", return_value=[cand("bad.png"), cand("ok.png")]), \
                mock.patch.object(run, "fetch_png", fake_fetch), mock.patch.object(run, "reencode", fake_reencode), \
                mock.patch.object(run, "gate", fake_gate), mock.patch.object(run, "log"):
            rows = run.build(Path(d), None)
            manifest = json.loads((Path(d) / "out" / "assets.json").read_text())
        self.assertEqual([r["source_image"] for r in rows], ["ok.png"])
        self.assertEqual([r["source_image"] for r in manifest], ["ok.png"])


if __name__ == "__main__":
    unittest.main()

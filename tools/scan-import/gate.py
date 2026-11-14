"""Vision gate: a second opinion on each candidate image, asked without the label.

Three independent passes each name the main finding and its side. An asset is kept only if all three
agree with the expert label, which filters out images where the box or label does not match what a
student would actually see. The three answers are stored in the asset's `gate` column.
"""

from __future__ import annotations

import base64
import os
import sys
from pathlib import Path

# Reuse the kb-generate OpenAI call (curl with the key off the command line, reasoning fields).
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "kb-generate"))
import llm  # noqa: E402

GATE_MODEL = "gpt-6.1-sol"
PASSES = 3
# The ScanFinding list the server and app use; "fracture" is askable even though the library has none yet.
FINDINGS = ["normal", "pneumothorax", "opacity", "nodule_mass", "fracture",
            "effusion", "atelectasis", "cardiomegaly", "edema", "emphysema"]
LATERAL_FINDINGS = {"pneumothorax", "opacity", "nodule_mass", "fracture", "effusion", "atelectasis"}

PROMPT = (
    "You are shown one frontal chest X-ray. Name its single main finding, choosing exactly one of: "
    + ", ".join(FINDINGS) + ". Use 'normal' only if nothing abnormal is visible. "
    "If the finding is on one side, give the side as the PATIENT's side (the patient's right appears on the "
    "left of the image): 'left' or 'right'; otherwise 'none'. "
    'Reply with JSON only: {"finding": "<one of the list>", "side": "left|right|none"}.'
)


def gate(image_bytes: bytes) -> dict:
    """Runs the passes and returns {"model", "answers": [{"finding", "side"}, ...]}. Judging against
    the label is `agrees`, so the stored record can be re-checked later."""
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise SystemExit("Set OPENAI_API_KEY (e.g. `! export OPENAI_API_KEY=...`)")
    url = "data:image/jpeg;base64," + base64.b64encode(image_bytes).decode()
    body = {
        "model": GATE_MODEL,
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": PROMPT},
            {"type": "image_url", "image_url": {"url": url}},
        ]}],
        "response_format": {"type": "json_object"},
        **llm.thinking_fields("openai", 200, os.environ.get("LLM_EFFORT", "medium")),
    }
    answers = []
    for _ in range(PASSES):
        reply = llm._post(llm.PROVIDERS["openai"].url, [f"Authorization: Bearer {key}"], body)
        parsed = llm._parse_json(reply["choices"][0]["message"]["content"])
        answers.append({"finding": str(parsed.get("finding", "")).lower(), "side": str(parsed.get("side", "none")).lower()})
    return {"model": GATE_MODEL, "answers": answers}


def agrees(result: dict, finding: str, side: str | None) -> bool:
    """True when every pass gave the labelled finding, and, for lateral findings, the labelled side."""
    answers = result["answers"]
    if len(answers) < PASSES:
        return False
    return all(a["finding"] == finding and (finding not in LATERAL_FINDINGS or a["side"] == side) for a in answers)

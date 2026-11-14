"""Result text for the X-ray an asset stands in for.

The server shows an asset's `report` verbatim as the study result and rejects a report that contains
the case's diagnosis words, so every report here describes signs and never names a diagnosis. Diffuse
findings never mention a side, and lateral findings always do.
"""

from __future__ import annotations

# Findings whose report needs a side from a radiologist box.
LATERAL = {"pneumothorax", "opacity", "nodule_mass", "effusion", "atelectasis"}
# Findings that are bilateral or central, so a side would be wrong.
DIFFUSE = {"normal", "cardiomegaly", "edema", "emphysema"}

# Findings with a zone in the wording; the others are described by side only.
_ZONED = {"opacity", "nodule_mass", "atelectasis"}

_TEMPLATES = {
    "opacity": "Airspace opacity in the {side} {zone} zone. Heart size within normal limits.",
    "pneumothorax": "Visible visceral pleural line with absent lung markings peripherally on the {side}.",
    "effusion": "Blunting of the {side} costophrenic angle with a meniscus.",
    "nodule_mass": "Rounded opacity in the {side} {zone} zone.",
    "atelectasis": "Linear opacity with volume loss in the {side} {zone} zone.",
    "cardiomegaly": "Cardiothoracic ratio greater than 0.5.",
    "edema": "Bilateral perihilar haziness with vascular congestion.",
    "emphysema": "Hyperinflated lungs with flattened hemidiaphragms.",
    "normal": "Lungs are clear. Heart size within normal limits. No pleural effusion or pneumothorax.",
}


def report(finding: str, side: str | None, zone: str | None) -> str:
    """The result text for a finding. Raises for findings with no wording (fracture) and for a
    lateral finding missing its side or zone, so an incomplete label never reaches the library."""
    template = _TEMPLATES.get(finding)
    if template is None:
        raise ValueError(f"no report wording for finding '{finding}'")
    if finding in LATERAL and side not in ("left", "right"):
        raise ValueError(f"'{finding}' needs a side")
    if finding in _ZONED and zone not in ("upper", "middle", "lower"):
        raise ValueError(f"'{finding}' needs a zone")
    return template.format(side=side, zone=zone)

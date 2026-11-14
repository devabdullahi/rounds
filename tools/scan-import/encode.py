"""Re-encodes a source PNG into the JPEG the app is served.

Re-encoding through Pillow strips everything the source carried (EXIF, ICC profile, PNG text
chunks), which is the point: the library holds pixels only.
"""

from __future__ import annotations

import io

from PIL import Image, ImageStat

LONG_EDGE = 1024
JPEG_QUALITY = 88
# A real chest film at 1024 px compresses well above this; less means a blank or failed image.
MIN_BYTES = 40 * 1024
# Flat or near-uniform images carry no anatomy worth showing.
MIN_STD_DEV = 20


class RejectedImage(ValueError):
    """The image decoded but is not good enough to teach from."""


def reencode(png_bytes: bytes) -> bytes:
    """Grayscale JPEG, long edge 1024, no metadata. Raises RejectedImage when the result is too
    small or too flat, judged after the resize."""
    with Image.open(io.BytesIO(png_bytes)) as source:
        gray = source.convert("L")
    scale = LONG_EDGE / max(gray.size)
    resized = gray.resize((max(1, round(gray.width * scale)), max(1, round(gray.height * scale))), Image.LANCZOS)
    if ImageStat.Stat(resized).stddev[0] < MIN_STD_DEV:
        raise RejectedImage("image is too flat")
    out = io.BytesIO()
    resized.save(out, format="JPEG", quality=JPEG_QUALITY)
    data = out.getvalue()
    if len(data) < MIN_BYTES:
        raise RejectedImage(f"encoded image is only {len(data)} bytes")
    return data

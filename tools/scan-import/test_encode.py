"""Tests for encode.py. Run: python3 -m unittest"""

from __future__ import annotations

import io
import random
import unittest

from PIL import Image

from encode import RejectedImage, reencode


def png(image: Image.Image, **save) -> bytes:
    out = io.BytesIO()
    image.save(out, format="PNG", **save)
    return out.getvalue()


def noisy(size: tuple[int, int]) -> Image.Image:
    rng = random.Random(1)
    image = Image.new("L", size)
    image.putdata([rng.randrange(256) for _ in range(size[0] * size[1])])
    return image


class ReencodeTests(unittest.TestCase):
    def test_long_edge_is_1024_and_grayscale_jpeg(self):
        data = reencode(png(noisy((2000, 1500))))
        image = Image.open(io.BytesIO(data))
        self.assertEqual((image.format, image.mode, image.size), ("JPEG", "L", (1024, 768)))

    def test_metadata_is_stripped(self):
        from PIL import PngImagePlugin
        info = PngImagePlugin.PngInfo()
        info.add_text("Patient", "Jane Doe")
        source = noisy((1024, 1024))
        data = reencode(png(source, pnginfo=info))
        image = Image.open(io.BytesIO(data))
        self.assertEqual(len(image.getexif()), 0)
        self.assertNotIn("icc_profile", image.info)
        self.assertNotIn(b"Jane", data)

    def test_flat_image_is_rejected(self):
        with self.assertRaises(RejectedImage):
            reencode(png(Image.new("L", (1024, 1024), 128)))

    def test_small_output_is_rejected(self):
        # Varied enough to pass the contrast check but smooth, so it compresses below the size floor.
        image = Image.new("L", (1024, 1024))
        image.putdata([0 if (x // 512) % 2 else 255 for y in range(1024) for x in range(1024)])
        with self.assertRaises(RejectedImage):
            reencode(png(image))


if __name__ == "__main__":
    unittest.main()

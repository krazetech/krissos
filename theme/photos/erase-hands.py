# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
# Paint the photo's own clock hands out of the tower's two centre discs, so the shell can
# draw live ones (DynamicWallpaper.qml, which has the same dials). Run once per photo, on
# the photos as shot:
#   python3 erase-hands.py sungai-petani-day.jpg sungai-petani-night.jpg
# The hand pixels are filled from the disc around them (a blur that skips the hands), so the
# disc keeps its shading, then the photo's own grain is put back on top.
import sys

import numpy as np
from PIL import Image

# (cx, cy, rx, ry) of each centre disc in the 3840x2160 photo. The left one is foreshortened.
DISCS = ((1049, 1459, 22, 48), (1427, 1437, 40, 48))


def blur(a, sigma):
    """Separable Gaussian blur over the first two axes."""
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    for axis in (0, 1):
        a = np.apply_along_axis(lambda v: np.convolve(np.pad(v, r, mode="edge"), k, "valid"), axis, a)
    return a


for path in sys.argv[1:]:
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    rng = np.random.default_rng(0)
    for cx, cy, rx, ry in DISCS:
        ys, xs = slice(cy - ry - 4, cy + ry + 5), slice(cx - rx - 4, cx + rx + 5)
        patch = a[ys, xs]
        gy, gx = np.mgrid[ys, xs]
        r = np.sqrt(((gx - cx) / rx) ** 2 + ((gy - cy) / ry) ** 2)
        lum = patch.mean(2)
        inside = r <= 0.9
        face = np.percentile(lum[inside], 70)
        dark = np.percentile(lum[inside], 3)
        # How much each pixel is hand: darker than the face, inside the disc, grown a little.
        hand = np.clip((face - lum) / (face - dark) * 3, 0, 1) * np.clip((0.93 - r) / 0.12, 0, 1)
        hand = np.clip(blur(hand, 1.0) * 2, 0, 1)
        keep = (1 - hand) * (r <= 0.85) * (lum > (face + dark) / 2)  # bright disc only
        fill = blur(patch * keep[..., None], 5) / np.maximum(blur(keep, 5), 1e-3)[..., None]
        # The photo's grain is soft, so the added grain is too.
        grain = blur(rng.normal(0, 3.0, lum.shape), 0.8)[..., None]
        a[ys, xs] = patch * (1 - hand[..., None]) + (fill + grain) * hand[..., None]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(path, quality=92)

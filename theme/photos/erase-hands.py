# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
# Paint the photo's own clock hands out of the tower's two centre discs, so the shell can
# draw live ones (DynamicWallpaper.qml, which has the same DISCS). Run once per photo:
#   python3 erase-hands.py sungai-petani-day.jpg sungai-petani-night.jpg
# Dark pixels inside a disc fade to the disc's face colour by how dark they are, so its
# edge and texture stay as shot.
import sys

import numpy as np
from PIL import Image

# (cx, cy, rx, ry) of each centre disc in the 3840x2160 photo. The left one is foreshortened.
DISCS = ((1049, 1459, 22, 48), (1427, 1437, 40, 48))

for path in sys.argv[1:]:
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    for cx, cy, rx, ry in DISCS:
        ys, xs = slice(cy - ry - 2, cy + ry + 3), slice(cx - rx - 2, cx + rx + 3)
        patch = a[ys, xs]
        gy, gx = np.mgrid[ys, xs]
        r = np.sqrt(((gx - cx) / rx) ** 2 + ((gy - cy) / ry) ** 2)
        lum = patch.mean(2)
        inside = r <= 0.9
        face = np.median(patch[inside & (lum >= np.percentile(lum[inside], 60))], 0)
        dark = np.percentile(lum[inside], 3)
        w = np.clip((face.mean() - lum) / (face.mean() - dark) * 4, 0, 1) * np.clip((0.95 - r) / 0.15, 0, 1)
        a[ys, xs] = patch * (1 - w[..., None]) + face * w[..., None]
    Image.fromarray(a.astype(np.uint8)).save(path, quality=92)

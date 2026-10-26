"""Turn a generated albedo into tiled albedo, normal, and roughness JPEGs.

Desktop maps are 1024. Web maps are 512. The normal is a sobel of the
luminance, and the roughness is the inverse of local contrast so worn
floors stay matte.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps


def _maps(src, stem, out_dir):
    im = Image.open(src).convert("RGB")
    # Offset a copy and blend the seam so a non-tileable generate still repeats.
    w, h = im.size
    tile = im.copy()
    tile.paste(im.crop((w // 2, 0, w, h)), (0, 0))
    tile.paste(im.crop((0, 0, w // 2, h)), (w // 2, 0))
    im = Image.blend(im, tile, 0.35)
    for px, tier in ((1024, "lod0"), (512, "lod2")):
        albedo = im.resize((px, px), Image.Resampling.LANCZOS)
        albedo.save(os.path.join(out_dir, "%s_albedo_%s.jpg" % (stem, tier)), quality=82, optimize=True)
        lum = np.asarray(ImageOps.grayscale(albedo).filter(ImageFilter.GaussianBlur(radius=max(1, px // 256))), dtype=np.float32) / 255.0
        dx = (np.roll(lum, -1, axis=1) - np.roll(lum, 1, axis=1)) * 2.4
        dy = (np.roll(lum, -1, axis=0) - np.roll(lum, 1, axis=0)) * 2.4
        normal = np.dstack([
            np.clip(128 - dx * 127, 0, 255),
            np.clip(128 + dy * 127, 0, 255),
            np.full_like(lum, 220),
        ]).astype(np.uint8)
        rough = np.clip(255 - lum * 40, 0, 255).astype(np.uint8)
        Image.fromarray(normal, "RGB").save(os.path.join(out_dir, "%s_normal_%s.jpg" % (stem, tier)), quality=80, optimize=True)
        Image.fromarray(rough, "L").save(os.path.join(out_dir, "%s_rough_%s.jpg" % (stem, tier)), quality=80, optimize=True)
        print("MAP", stem, tier, px)


if __name__ == "__main__":
    # src stem out, repeated
    args = sys.argv[1:]
    out = args[-1]
    os.makedirs(out, exist_ok=True)
    i = 0
    while i + 1 < len(args) - 1:
        _maps(args[i], args[i + 1], out)
        i += 2

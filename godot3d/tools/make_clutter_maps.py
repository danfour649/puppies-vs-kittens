"""Local kraft, rug, and floor-decal maps. No network calls.

Writes house/textures/kraft_* and rug_* at lod0 (1024) and lod2 (512),
plus small dust, stain, and paper decals.
"""
import os

import numpy as np
from PIL import Image


ROOT = os.path.join(os.path.dirname(__file__), "..", "house", "textures")


def _save_jpg(path, rgb):
    Image.fromarray(rgb, "RGB").save(path, quality=82, optimize=True)


def _save_png(path, rgba):
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)


def _noise(rng, h, w, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    total = 0.0
    for i in range(octaves):
        sh = max(2, h // (2 ** (i + 2)))
        sw = max(2, w // (2 ** (i + 2)))
        small = rng.random((sh, sw)).astype(np.float32)
        up = np.array(Image.fromarray(small, "F").resize((w, h), Image.BILINEAR), np.float32)
        out += up * amp
        total += amp
        amp *= 0.5
    return out / total


def kraft(size):
    rng = np.random.default_rng(25501)
    n = _noise(rng, size, size, 5)
    fiber = _noise(rng, size, size, 3)
    y = np.linspace(0, 18, size, dtype=np.float32)[:, None]
    flute = 0.5 + 0.5 * np.sin(y * 3.1 + fiber * 2.0)
    base = np.array([148, 124, 92], np.float32)
    img = base + (n - 0.5)[:, :, None] * 28.0 + (flute - 0.5)[:, :, None] * 16.0
    stain = _noise(rng, size, size, 2)
    img -= (stain > 0.72).astype(np.float32)[:, :, None] * np.array([18, 14, 8], np.float32)
    return np.clip(img, 0, 255).astype(np.uint8)


def kraft_rough(size, albedo):
    rng = np.random.default_rng(25502)
    n = _noise(rng, size, size, 4)
    lum = albedo.astype(np.float32).mean(axis=2) / 255.0
    rough = 210 + (1.0 - lum) * 30 + (n - 0.5) * 18
    return np.clip(rough, 0, 255).astype(np.uint8)


def rug(size):
    rng = np.random.default_rng(25503)
    n = _noise(rng, size, size, 5)
    yy = np.linspace(-1, 1, size, dtype=np.float32)[:, None]
    xx = np.linspace(-1, 1, size, dtype=np.float32)[None, :]
    border = (np.abs(yy) > 0.82) | (np.abs(xx) > 0.82)
    field = np.array([92, 58, 48], np.float32)
    edge = np.array([62, 44, 36], np.float32)
    img = np.where(border[:, :, None], edge, field)
    img = img + (n - 0.5)[:, :, None] * 22.0
    wear = _noise(rng, size, size, 2)
    img += (wear > 0.78).astype(np.float32)[:, :, None] * np.array([16, 12, 8], np.float32)
    return np.clip(img, 0, 255).astype(np.uint8)


def rug_rough(size):
    rng = np.random.default_rng(25504)
    n = _noise(rng, size, size, 3)
    rough = 200 + n * 40
    return np.clip(rough, 0, 255).astype(np.uint8)


def _alpha_blob(size, seed, color, thresh):
    rng = np.random.default_rng(seed)
    n = _noise(rng, size, size, 5)
    a = np.clip((n - thresh) / (1.0 - thresh), 0, 1)
    a = a ** 1.4
    rgb = np.array(color, np.float32) + (n - 0.5)[:, :, None] * 18.0
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = (a * 255).astype(np.uint8)
    return rgba


def paper(size):
    rng = np.random.default_rng(25507)
    n = _noise(rng, size, size, 3)
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[:, :, 0] = np.clip(214 + (n - 0.5) * 16, 0, 255).astype(np.uint8)
    rgba[:, :, 1] = np.clip(206 + (n - 0.5) * 14, 0, 255).astype(np.uint8)
    rgba[:, :, 2] = np.clip(186 + (n - 0.5) * 12, 0, 255).astype(np.uint8)
    margin = int(size * 0.08)
    rgba[margin:-margin, margin:-margin, 3] = 230
    for row in range(6):
        y = margin + 18 + row * (size // 8)
        if y >= size - margin:
            break
        x0 = margin + 10
        x1 = size - margin - int(rng.integers(8, 40))
        rgba[y : y + 2, x0:x1, 0] = 90
        rgba[y : y + 2, x0:x1, 1] = 88
        rgba[y : y + 2, x0:x1, 2] = 82
    return rgba


def beam(size):
    """Rough timber. Grain runs with the image's vertical axis so a
    triplanar side face reads as vertical grain, not floorboards."""
    rng = np.random.default_rng(25511)
    x = np.linspace(0.0, 10.0 * np.pi, size, endpoint=False, dtype=np.float32)
    y = np.linspace(0.0, 2.0 * np.pi, size, endpoint=False, dtype=np.float32)
    rings = 0.5 + 0.5 * np.sin(x[None, :] * 1.7 + np.sin(y[:, None] * 0.4) * 0.15)
    fiber = _noise(rng, size, size, 3)
    # Squash across X so the noise becomes long vertical fibers.
    streak = np.array(
        Image.fromarray(fiber).resize((max(8, size // 40), size), Image.BILINEAR).resize((size, size), Image.BILINEAR),
        np.float32,
    )
    base = np.array([102, 74, 48], np.float32)
    img = base + (rings - 0.5)[:, :, None] * np.array([64, 40, 22], np.float32)
    img += (streak - 0.5)[:, :, None] * 10.0
    knot = _noise(rng, size, size, 2)
    img -= (knot > 0.82).astype(np.float32)[:, :, None] * np.array([22, 14, 8], np.float32)
    return np.clip(img, 0, 255).astype(np.uint8)


def beam_rough(size):
    rng = np.random.default_rng(25512)
    n = _noise(rng, size, size, 3)
    rough = 188 + n * 48
    return np.clip(rough, 0, 255).astype(np.uint8)


def plaster(size):
    rng = np.random.default_rng(25513)
    n = _noise(rng, size, size, 5)
    fine = _noise(rng, size, size, 2)
    base = np.array([176, 168, 154], np.float32)
    img = base + (n - 0.5)[:, :, None] * 22.0 + (fine - 0.5)[:, :, None] * 8.0
    scuff = _noise(rng, size, size, 2)
    img -= (scuff > 0.8).astype(np.float32)[:, :, None] * np.array([20, 16, 12], np.float32)
    return np.clip(img, 0, 255).astype(np.uint8)


def plaster_rough(size):
    rng = np.random.default_rng(25514)
    n = _noise(rng, size, size, 3)
    rough = 214 + n * 28
    return np.clip(rough, 0, 255).astype(np.uint8)


def _write_pair(name, albedo, rough, lod2):
    _save_jpg(os.path.join(ROOT, "%s_albedo_lod0.jpg" % name), albedo)
    _save_jpg(os.path.join(ROOT, "%s_rough_lod0.jpg" % name), np.repeat(rough[:, :, None], 3, axis=2))
    small = np.array(Image.fromarray(albedo).resize((lod2, lod2), Image.LANCZOS))
    small_r = np.array(Image.fromarray(rough).resize((lod2, lod2), Image.LANCZOS))
    _save_jpg(os.path.join(ROOT, "%s_albedo_lod2.jpg" % name), small)
    _save_jpg(os.path.join(ROOT, "%s_rough_lod2.jpg" % name), np.repeat(small_r[:, :, None], 3, axis=2))


def main():
    os.makedirs(ROOT, exist_ok=True)
    # Beam and plaster only. Kraft and rug lod2 stay at 256 from the
    # pack trim; regenerating them here would push the web pack back up.
    b = beam(1024)
    p = plaster(1024)
    _write_pair("beam", b, beam_rough(1024), 256)
    _write_pair("plaster", p, plaster_rough(1024), 256)
    print("beam and plaster maps written")


if __name__ == "__main__":
    main()

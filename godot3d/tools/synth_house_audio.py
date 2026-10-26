#!/usr/bin/env python3
"""Self-generated house and creature voices for Willie and Aggie.

No third-party samples. Every clip is synthesised here and encoded
with ffmpeg's Vorbis encoder: 24 kbit/s mono for the web pack, 64
kbit/s mono for desktop. Loops are crossfaded so a fridge, a purr,
wind, scurry, scrabble and wingbeats can repeat.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parents[1] / "audio"
LOOP_KINDS = {"purr", "scrabble", "scurry", "wingbeat", "fridge", "wind"}


def _fade(x: np.ndarray, edge: float = 0.012) -> np.ndarray:
    n = int(SR * edge)
    if n * 2 >= x.size:
        return x
    w = np.linspace(0.0, 1.0, n, dtype=np.float32)
    y = x.copy()
    y[:n] *= w
    y[-n:] *= w[::-1]
    return y


def _norm(x: np.ndarray, peak: float = 0.88) -> np.ndarray:
    m = float(np.max(np.abs(x))) if x.size else 1.0
    if m < 1e-6:
        return x
    return (x * (peak / m)).astype(np.float32)


def _seamless(x: np.ndarray, fade: float = 0.04) -> np.ndarray:
    n = int(SR * fade)
    if n * 2 >= x.size:
        return x.astype(np.float32)
    w = np.linspace(0.0, 1.0, n, dtype=np.float32)
    head = x[:n] * w + x[-n:] * (1.0 - w)
    return np.concatenate([head, x[n:-n]]).astype(np.float32)


def _resonate(x: np.ndarray, freq: float, bw: float) -> np.ndarray:
    r = float(np.exp(-np.pi * bw / SR))
    w = 2.0 * np.pi * freq / SR
    a1 = -2.0 * r * np.cos(w)
    a2 = r * r
    y = np.zeros_like(x, dtype=np.float64)
    for i in range(x.size):
        prev = y[i - 1] if i > 0 else 0.0
        prev2 = y[i - 2] if i > 1 else 0.0
        y[i] = x[i] - a1 * prev - a2 * prev2
    return y.astype(np.float32)


def _tone(dur: float, f0, f1=None, vib: float = 0.0, partials=(1.0, 0.35, 0.12)) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n, dtype=np.float64) / SR
    if f1 is None:
        freq = np.full(n, float(f0))
    else:
        freq = np.linspace(float(f0), float(f1), n)
    if vib:
        freq *= 1.0 + vib * np.sin(2.0 * np.pi * 8.0 * t)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    y = np.zeros(n, dtype=np.float64)
    for h, amp in enumerate(partials, start=1):
        y += amp * np.sin(phase * h)
    return y.astype(np.float32)


def _noise(dur: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.uniform(-1.0, 1.0, int(SR * dur)).astype(np.float32)


def meow() -> np.ndarray:
    dur = 0.48
    n = int(SR * dur)
    t = np.arange(n) / SR
    k = t / dur
    f0 = np.interp(k, [0.0, 0.28, 1.0], [620.0, 860.0, 390.0])
    f0 *= 1.0 + 0.025 * np.sin(2.0 * np.pi * 11.0 * t) * np.clip(k * 1.4, 0.0, 1.0)
    phase = 2.0 * np.pi * np.cumsum(f0) / SR
    pulses = np.zeros(n, dtype=np.float32)
    ip = np.floor(np.cumsum(f0) / SR)
    pulses[1:] = (ip[1:] != ip[:-1]).astype(np.float32)
    y = np.zeros(n, dtype=np.float32)
    step = 256
    acc = pulses
    for i in range(0, n, step):
        sl = slice(i, min(n, i + step))
        kk = float(k[i])
        f1 = float(np.interp(kk, [0.0, 0.3, 1.0], [780.0, 1150.0, 480.0]))
        f2 = float(np.interp(kk, [0.0, 0.3, 1.0], [1500.0, 1950.0, 1050.0]))
        chunk = acc[sl]
        y[sl] = _resonate(chunk, f1, 80.0)[: chunk.size] + 0.55 * _resonate(chunk, f2, 140.0)[: chunk.size]
    env = np.sin(np.pi * np.clip(k, 0.001, 0.999)) ** 0.55
    breath = _noise(dur, 3) * 0.04 * env
    return _fade(_norm(y * env + breath))


def chirp() -> np.ndarray:
    y = _tone(0.18, 1080.0, 1320.0, vib=0.01, partials=(1.0, 0.25, 0.08))
    env = np.sin(np.linspace(0.0, np.pi, y.size)) ** 0.7
    return _fade(_norm(y * env), 0.008)


def chatter() -> np.ndarray:
    dur = 0.72
    y = np.zeros(int(SR * dur), dtype=np.float32)
    rng = np.random.default_rng(11)
    for i in range(10):
        start = int((0.03 + i * 0.068) * SR)
        freq = 1250.0 + float(rng.integers(-90, 90))
        click = _tone(0.038, freq, freq * 0.82, partials=(0.4, 0.2, 0.05))
        click += _noise(0.038, 20 + i) * 0.35
        env = np.sin(np.linspace(0.0, np.pi, click.size)) ** 0.4
        click = click * env
        end = min(y.size, start + click.size)
        y[start:end] += click[: end - start]
    return _fade(_norm(y))


def trill() -> np.ndarray:
    dur = 0.55
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = np.linspace(500.0, 780.0, n)
    phase = 2.0 * np.pi * np.cumsum(f) / SR
    am = 0.25 + 0.75 * (0.5 + 0.5 * np.sin(2.0 * np.pi * 32.0 * t)) ** 1.5
    y = (np.sin(phase) + 0.28 * np.sin(2.0 * phase)) * am
    env = np.sin(np.pi * np.clip(t / dur, 0.001, 0.999)) ** 0.5
    return _fade(_norm((y * env).astype(np.float32)))


def purr() -> np.ndarray:
    dur = 2.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    pulse = (0.5 + 0.5 * np.sin(2.0 * np.pi * 21.0 * t - np.pi * 0.5)) ** 1.6
    carrier = (
        np.sin(2.0 * np.pi * 55.0 * t) * 0.55
        + np.sin(2.0 * np.pi * 110.0 * t) * 0.28
        + np.sin(2.0 * np.pi * 165.0 * t) * 0.10
    )
    y = carrier * (0.30 + 0.70 * pulse)
    return _seamless(_norm(y.astype(np.float32), 0.8))


def hiss() -> np.ndarray:
    dur = 0.8
    n = int(SR * dur)
    t = np.arange(n) / SR
    k = t / dur
    white = _noise(dur, 1313)
    y = np.zeros(n, dtype=np.float32)
    step = 256
    for i in range(0, n, step):
        sl = slice(i, min(n, i + step))
        cutoff = float(np.interp(k[i], [0.0, 1.0], [2400.0, 700.0]))
        y[sl] = _resonate(white[sl], cutoff, cutoff * 0.85)[: sl.stop - sl.start]
    env = np.clip(t / 0.03, 0.0, 1.0) * (1.0 - k) ** 2
    env = env + 0.35 * np.clip((t - 0.45) / 0.03, 0.0, 1.0) * np.clip(1.0 - (t - 0.45) / 0.35, 0.0, 1.0)
    return _fade(_norm(y * env.astype(np.float32)))


def scrabble() -> np.ndarray:
    dur = 0.64
    y = np.zeros(int(SR * dur), dtype=np.float32)
    rng = np.random.default_rng(19)
    for i in range(9):
        start = int(rng.uniform(0.0, dur - 0.05) * SR)
        burst = _noise(0.045, 40 + i)
        burst = _resonate(burst, 180.0 + float(i * 30), 120.0)
        env = np.sin(np.linspace(0.0, np.pi, burst.size)) ** 0.5
        end = min(y.size, start + burst.size)
        y[start:end] += (burst * env)[: end - start] * float(rng.uniform(0.4, 1.0))
    return _seamless(_norm(y))


def squeak() -> np.ndarray:
    y = _tone(0.09, 6400.0, 5100.0, partials=(1.0, 0.15))
    env = np.sin(np.linspace(0.0, np.pi, y.size)) ** 0.45
    return _fade(_norm(y * env), 0.004)


def scurry() -> np.ndarray:
    dur = 0.48
    y = np.zeros(int(SR * dur), dtype=np.float32)
    for i in range(8):
        start = int(i * dur / 8.0 * SR)
        tick = _noise(0.018, 70 + i)
        tick = _resonate(tick, 2200.0, 900.0)
        env = np.linspace(1.0, 0.0, tick.size) ** 1.4
        end = min(y.size, start + tick.size)
        y[start:end] += (tick * env)[: end - start] * (0.5 if i % 2 else 1.0)
    return _seamless(_norm(y, 0.7), 0.02)


def alarm() -> np.ndarray:
    a = _tone(0.16, 3400.0, 3900.0, partials=(1.0, 0.08))
    b = _tone(0.18, 3600.0, 4100.0, partials=(1.0, 0.08))
    gap = np.zeros(int(SR * 0.06), dtype=np.float32)
    y = np.concatenate([a * np.sin(np.linspace(0, np.pi, a.size)), gap, b * np.sin(np.linspace(0, np.pi, b.size))])
    return _fade(_norm(y.astype(np.float32)))


def wingbeat() -> np.ndarray:
    dur = 0.36
    y = np.zeros(int(SR * dur), dtype=np.float32)
    for i in range(4):
        start = int(i * dur / 4.0 * SR)
        flap = _noise(0.04, 90 + i)
        flap = _resonate(flap, 140.0, 80.0)
        env = np.sin(np.linspace(0.0, np.pi, flap.size))
        end = min(y.size, start + flap.size)
        y[start:end] += (flap * env)[: end - start]
    return _seamless(_norm(y, 0.75), 0.02)


def creak() -> np.ndarray:
    dur = 0.7
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 180.0 + 40.0 * np.sin(2.0 * np.pi * 3.0 * t)
    phase = 2.0 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * 0.5 + np.sin(phase * 2.07) * 0.25 + np.sin(phase * 3.4) * 0.1
    grit = _noise(dur, 5) * 0.15
    env = np.sin(np.pi * np.clip(t / dur, 0.001, 0.999)) ** 1.4
    return _fade(_norm(((body + grit) * env).astype(np.float32)))


def fridge() -> np.ndarray:
    dur = 2.0
    t = np.arange(int(SR * dur)) / SR
    y = (
        np.sin(2.0 * np.pi * 60.0 * t) * 0.45
        + np.sin(2.0 * np.pi * 120.0 * t) * 0.22
        + np.sin(2.0 * np.pi * 180.0 * t) * 0.06
    )
    y += _resonate(_noise(dur, 8), 90.0, 30.0) * 0.08
    return _seamless(_norm(y.astype(np.float32), 0.7))


def wind() -> np.ndarray:
    dur = 2.0
    white = _noise(dur, 17)
    y = _resonate(white, 240.0, 180.0)
    t = np.arange(y.size) / SR
    gust = 0.55 + 0.45 * np.sin(2.0 * np.pi * 0.5 * t)
    return _seamless(_norm((y * gust).astype(np.float32), 0.75))


def drip() -> np.ndarray:
    dur = 0.28
    n = int(SR * dur)
    t = np.arange(n) / SR
    y = np.sin(2.0 * np.pi * 980.0 * t) * np.exp(-t * 18.0)
    y += np.sin(2.0 * np.pi * 2100.0 * t) * np.exp(-t * 28.0) * 0.25
    return _fade(_norm(y.astype(np.float32)), 0.004)


CLIPS = {
    "meow": meow,
    "chirp": chirp,
    "chatter": chatter,
    "trill": trill,
    "purr": purr,
    "hiss": hiss,
    "scrabble": scrabble,
    "squeak": squeak,
    "scurry": scurry,
    "alarm": alarm,
    "wingbeat": wingbeat,
    "creak": creak,
    "fridge": fridge,
    "wind": wind,
    "drip": drip,
}


def _encode(samples: np.ndarray, path: Path, bitrate: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "pipe:0",
            "-c:a", "libvorbis", "-b:a", bitrate, "-ar", str(SR),
            str(path),
        ],
        input=samples.astype(np.float32).tobytes(),
        check=True,
    )
    del proc


def main() -> None:
    for name, fn in CLIPS.items():
        samples = fn()
        _encode(samples, ROOT / "web" / f"{name}.ogg", "24k")
        _encode(samples, ROOT / "desktop" / f"{name}.ogg", "64k")
        web = (ROOT / "web" / f"{name}.ogg").stat().st_size
        desk = (ROOT / "desktop" / f"{name}.ogg").stat().st_size
        print(f"{name:10} {samples.size / SR:.2f}s  web {web:6}  desktop {desk:6}")


if __name__ == "__main__":
    main()

"""Synthesis primitives for the sound-effect pack.

Moved out of generate_sfx_pack.py unchanged; generate_sfx_pack.py imports these names back."""
from __future__ import annotations
import math
import zlib
import numpy as np


SR = 44100


def n_of(dur: float) -> int:
    return int(round(dur * SR))


def t_axis(dur: float) -> np.ndarray:
    return np.arange(n_of(dur)) / SR


def silence(dur: float) -> np.ndarray:
    return np.zeros(n_of(dur))


def sine(freq, dur: float, amp: float = 1.0, phase: float = 0.0) -> np.ndarray:
    n = n_of(dur)
    if np.isscalar(freq):
        ph = 2.0 * math.pi * float(freq) * np.arange(n) / SR + phase
    else:
        freq = np.asarray(freq, dtype=float)
        if len(freq) != n:
            freq = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(freq)), freq)
        ph = 2.0 * math.pi * np.cumsum(freq) / SR + phase
    return amp * np.sin(ph)


def expdecay(dur: float, tau: float, start: float = 1.0) -> np.ndarray:
    return start * np.exp(-t_axis(dur) / max(tau, 1e-4))


def linramp(dur: float, a: float, b: float) -> np.ndarray:
    return np.linspace(a, b, n_of(dur))


def noise(dur: float, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n_of(dur))


def svf(x: np.ndarray, freq, q: float = 1.2):
    """State-variable filter; returns (low, band, high). freq scalar or array."""
    n = len(x)
    if np.isscalar(freq):
        fs = np.full(n, float(freq))
    else:
        fs = np.asarray(freq, dtype=float)
        if len(fs) != n:
            fs = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fs)), fs)
    f_coef = 2.0 * np.sin(np.pi * np.minimum(fs, SR * 0.45) / SR)
    qinv = 1.0 / max(q, 0.2)
    low = np.empty(n)
    band = np.empty(n)
    high = np.empty(n)
    lo = bd = 0.0
    for i in range(n):
        f = f_coef[i]
        lo += f * bd
        hi = x[i] - lo - qinv * bd
        bd += f * hi
        low[i] = lo
        band[i] = bd
        high[i] = hi
    return low, band, high


def lowpass(x: np.ndarray, freq, q: float = 0.8) -> np.ndarray:
    return svf(x, freq, q)[0]


def bandpass(x: np.ndarray, freq, q: float = 1.6) -> np.ndarray:
    return svf(x, freq, q)[1]


def highpass(x: np.ndarray, freq, q: float = 0.8) -> np.ndarray:
    return svf(x, freq, q)[2]


BELL_PARTIALS = (
    (1.00, 1.00, 1.00),
    (2.00, 0.55, 0.52),
    (2.98, 0.36, 0.34),
    (4.16, 0.22, 0.22),
    (5.43, 0.12, 0.14),
)


def bell(f0: float, dur: float, bright: float = 1.0, damp: float = 1.0,
         strike: float = 0.5, rng: np.random.Generator | None = None,
         partials=BELL_PARTIALS) -> np.ndarray:
    """Bronze-family bell: inharmonic partial stack with exponential tails."""
    out = silence(dur)
    for idx, (ratio, amp, dfrac) in enumerate(partials):
        f = f0 * ratio * (1.0 + 0.0015 * idx)
        if f > SR * 0.45:
            continue
        tau = max(0.02, dur * dfrac / max(damp, 0.05))
        out += sine(f, dur, amp * (bright if idx else 1.0)) * expdecay(dur, tau)
    if strike > 0 and rng is not None:
        hit = bandpass(noise(0.008, rng), min(f0 * 4.0, 9000.0), 1.0) * strike
        out[: len(hit)] += hit * np.linspace(1, 0, len(hit))
    return out


def pluck(f0: float, dur: float, tau: float = 0.12, amp: float = 1.0,
          rng: np.random.Generator | None = None) -> np.ndarray:
    """Thread-family pluck: fast-decay tone + tiny pick transient + 2nd harm."""
    drop = f0 * np.concatenate([linramp(min(0.02, dur), 1.02, 1.0),
                                np.ones(n_of(dur) - n_of(min(0.02, dur)))])
    x = sine(drop, dur) * expdecay(dur, tau)
    x += sine(f0 * 2.0, dur, 0.35) * expdecay(dur, tau * 0.6)
    if rng is not None:
        pick = highpass(noise(0.004, rng), 2500.0) * 0.5
        x[: len(pick)] += pick
    return amp * x


def place(canvas: np.ndarray, part: np.ndarray, at_s: float, gain: float = 1.0) -> None:
    i0 = n_of(at_s)
    i1 = min(len(canvas), i0 + len(part))
    if i1 > i0:
        canvas[i0:i1] += part[: i1 - i0] * gain


def edge_fade(x: np.ndarray, fade_s: float = 0.005) -> np.ndarray:
    n = min(n_of(fade_s), len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0.0, 1.0, n)
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def normalize(x: np.ndarray, peak: float = 0.7) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    return x * (peak / m) if m > 1e-9 else x


def make_loop(x: np.ndarray, xfade_s: float = 0.12) -> np.ndarray:
    """Equal-power crossfade of tail into head so end->start is seamless."""
    n = min(n_of(xfade_s), len(x) // 3)
    out = x[: len(x) - n].copy()
    up = np.sin(np.linspace(0.0, math.pi / 2.0, n)) ** 2
    out[:n] = out[:n] * up + x[len(x) - n:] * (1.0 - up)
    return out


def hishelf(x: np.ndarray, f0: float = 8000.0, gain_db: float = -6.0) -> np.ndarray:
    """FFT high-shelf: tame harsh full-level highs above f0 (review fix 3d)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    g = 10.0 ** (gain_db / 20.0)
    w = 1.0 / (1.0 + np.exp(-(freqs - f0) / (f0 * 0.08)))
    spec *= 1.0 + (g - 1.0) * w
    return np.fft.irfft(spec, len(x))


def active_rms_db(x: np.ndarray, frame_s: float = 0.05, gate_db: float = -40.0) -> float:
    """RMS (dBFS) over 50 ms frames louder than the -40 dBFS gate."""
    n = max(1, min(n_of(frame_s), len(x)))
    nf = max(1, len(x) // n)
    frames = x[: nf * n].reshape(nf, n)
    fr = np.sqrt(np.mean(frames ** 2, axis=1))
    act = frames[20.0 * np.log10(np.maximum(fr, 1e-9)) > gate_db]
    if len(act) == 0:
        act = frames
    return 20.0 * math.log10(max(math.sqrt(float(np.mean(act ** 2))), 1e-9))


def rms_target(x: np.ndarray, rms_db: float, ceiling: float,
               drive: float = 1.6, max_iter: int = 8) -> np.ndarray:
    """Scale to an active-RMS target; soft-tanh the crest when the peak
    ceiling would otherwise block the required gain."""
    for _ in range(max_iter):
        cur = active_rms_db(x)
        if abs(cur - rms_db) <= 0.5:
            return x
        x = x * 10.0 ** ((rms_db - cur) / 20.0)
        m = float(np.max(np.abs(x)))
        if m > ceiling:
            x = np.tanh((x / m) * drive) * (ceiling / math.tanh(drive))
    return x


def rng_for(name: str) -> np.random.Generator:
    # zlib.crc32 is stable across processes (str hash() is salted per run).
    return np.random.default_rng(zlib.crc32(("crimson_sfx:" + name).encode("utf-8")))

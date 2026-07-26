"""Generate the project-owned ambience + combat-completion pack for 绯线巡礼.

Companion to tools/generate_sfx_pack.py, same engineering rules (deterministic
per-file seeded RNG, 16-bit 44.1 kHz mono, idempotent reruns) covering the
remaining future_free_candidate audio in godot/data/audio_visual_manifest.json:

A. chapter ambience (OGG, godot/assets/audio/ambience/)
   * amb_ch01_bed .. amb_ch06_bed - 30-45 s seamless bed loops built from
     circular FFT-shaped noise + integer-cycle LFOs (loop-safe by construction)
     following spec 20260726160400000 section 4.6 recipes:
     ch1 cave-court wind/drips/far bell chamber, ch2 double rain + far thunder,
     ch3 still archive air + sparse salt-crystal ticks, ch4 muffled greenhouse
     wind + insects, ch5 plateau night wind + far war drums, ch6 organized
     silence (pressure hiss + tinnitus tone).
     Loudness: active RMS -28 dBFS (peak ceiling 0.5).
   * amb_ch02_anvil_far one-shot + amb_chXX_os_1..8 one-shots per chapter
     (1-3 s) after the section 4.6 imagery tables.
     Loudness: active RMS -25 dBFS (peak ceiling 0.7).
B. chapter beat sounds (OGG, godot/assets/audio/sfx/generated/) - the 15
   chapter_audio_visual future_free_candidate beat keys, recipes taken from
   each manifest beat description.
C. combat completion (OGG) - player_attack_01/02/03 swing family,
   player_land_soft/hard, enemy hit material trio, six boss kits
   (roar/phase_shift/atk_light/atk_heavy) voiced per chapter material.
D. UI jingles (OGG) - ability unlock, key-item pickup, testimony complete,
   all on the D-A-B(b) crimson-thread motif system.
E. footstep completion (OGG, godot/assets/audio/sfx/generated_footsteps/) -
   glass + wet surfaces, 5 variants each (~0.1-0.5 s, peak 0.7 per the
   project-wide SFX peak convention).

All output is OGG Vorbis (ffmpeg -q:a 4), 44.1 kHz mono.  Active RMS =
RMS over 50 ms frames gated at -40 dBFS; targets are applied after peak
normalization with a soft tanh limiter against the class peak ceiling.

Inventory: output/audio_preview/ambience_pack_inventory.json
License of all output: project-generated (CC0).
"""
from __future__ import annotations

import json
import math
import subprocess
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[1]
AMB_DIR = ROOT / "godot" / "assets" / "audio" / "ambience"
SFX_DIR = ROOT / "godot" / "assets" / "audio" / "sfx" / "generated"
FOOT_DIR = ROOT / "godot" / "assets" / "audio" / "sfx" / "generated_footsteps"
INVENTORY = ROOT / "output" / "audio_preview" / "ambience_pack_inventory.json"
FFMPEG = "C:/Users/Administrator/Desktop/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe"

D2, D3, D4, D5, D6 = 73.42, 146.83, 293.66, 587.33, 1174.66
A3, A4, A5 = 220.0, 440.0, 880.0
B4, B5 = 493.88, 987.77
BB4, BB5 = 466.16, 932.33
E5 = 659.26
FS4 = 369.99
G3 = 196.0


# ---------------------------------------------------------------- primitives

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


def place_wrap(canvas: np.ndarray, part: np.ndarray, at_s: float, gain: float = 1.0) -> None:
    """place() that wraps tails around the loop end - keeps beds seamless."""
    n = len(canvas)
    idx = (n_of(at_s) + np.arange(len(part))) % n
    np.add.at(canvas, idx, part * gain)


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
    return np.random.default_rng(zlib.crc32(("crimson_amb:" + name).encode("utf-8")))


# --------------------------------------------------- loop-safe bed primitives

def gband(freqs: np.ndarray, center: float, width: float) -> np.ndarray:
    return np.exp(-0.5 * ((freqs - center) / max(width, 1.0)) ** 2)


def fft_noise(dur: float, rng: np.random.Generator, shape) -> np.ndarray:
    """Spectrally shaped noise via circular FFT - inherently seamless loop."""
    n = n_of(dur)
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    spec *= shape(freqs)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    m = float(np.max(np.abs(x)))
    return x / m if m > 1e-9 else x


def loop_lfo(dur: float, cycles: int, lo: float, hi: float, phase: float = 0.0) -> np.ndarray:
    """Sine LFO with an integer cycle count over the loop - seam-free."""
    w = np.sin(2.0 * math.pi * cycles * t_axis(dur) / dur + phase)
    return lo + (hi - lo) * (0.5 + 0.5 * w)


def cconv(x: np.ndarray, kernel: np.ndarray) -> np.ndarray:
    """Circular convolution (loop-safe smearing of impulse trains)."""
    n = len(x)
    k = np.zeros(n)
    k[: min(len(kernel), n)] = kernel[: min(len(kernel), n)]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(k), n)


def sparse_env(dur: float, rng: np.random.Generator, density_hz: float,
               tau: float, sharp: float = 1.5) -> np.ndarray:
    """Random sparse impulses smeared by an exponential decay, circularly."""
    n = n_of(dur)
    imp = (rng.random(n) < density_hz / SR).astype(float) * rng.random(n) ** sharp
    kern = np.exp(-np.arange(n_of(min(tau * 6.0, 0.5))) / (tau * SR))
    return cconv(imp, kern)


def chirp(f1: float, f0: float, dur: float, tau: float, amp: float = 1.0) -> np.ndarray:
    return sine(linramp(dur, f1, f0), dur, amp) * expdecay(dur, tau)


def drip(rng: np.random.Generator, f_top: float = 1900.0, echo: float = 0.3) -> np.ndarray:
    """Single water drip: down-chirp blip + optional wet echo."""
    x = silence(0.5)
    place(x, chirp(f_top, f_top * 0.45, 0.045, 0.018), 0.0)
    place(x, highpass(noise(0.006, rng), 3000.0) * 0.3, 0.0)
    if echo > 0.0:
        place(x, chirp(f_top * 0.9, f_top * 0.4, 0.05, 0.02), 0.16, echo)
        place(x, chirp(f_top * 0.8, f_top * 0.38, 0.05, 0.02), 0.31, echo * 0.5)
    return x


def growl(dur: float, f0: float, rng: np.random.Generator, vib: float = 4.6) -> np.ndarray:
    fr = f0 * (1.0 + 0.06 * np.sin(2 * math.pi * vib * t_axis(dur)))
    x = sine(fr, dur) + sine(fr * 2.02, dur, 0.6) + sine(fr * 3.05, dur, 0.32)
    x += bandpass(noise(dur, rng), 300.0, 0.8) * 1.2
    return x * np.sin(np.linspace(0.0, math.pi, n_of(dur))) ** 0.8


def whoosh(dur: float, rng: np.random.Generator, f_lo: float, f_hi: float,
           q: float = 1.5) -> np.ndarray:
    body = bandpass(noise(dur, rng), linramp(dur, f_lo, f_hi), q)
    return body * np.sin(np.linspace(0.0, math.pi, n_of(dur))) ** 1.2


# ------------------------------------------------------------------ A. beds

def bed_ch01() -> np.ndarray:
    """苔钟庭：地底庭院低风 + 极远钟腔共鸣 + 苔间滴水。"""
    rng = rng_for("bed_ch01")
    dur = 38.0
    wind = fft_noise(dur, rng, lambda f: gband(f, 220.0, 160.0) + 0.4 * gband(f, 620.0, 420.0))
    wind *= loop_lfo(dur, 3, 0.45, 1.0) * loop_lfo(dur, 7, 0.7, 1.0, 1.3)
    x = wind * 1.0
    # far bell-chamber resonance: slow-beating D partial drone
    drone = sine(D3, dur, 0.10) + sine(D3 * 1.005, dur, 0.08) + sine(A3, dur, 0.05)
    x += drone * loop_lfo(dur, 2, 0.4, 1.0, 0.7)
    for _ in range(11):  # sparse moss drips
        place_wrap(x, drip(rng, 1400.0 + 900.0 * rng.random(), 0.35), dur * rng.random(), 0.42)
    hiss = fft_noise(dur, rng, lambda f: gband(f, 3400.0, 1500.0))
    x += hiss * loop_lfo(dur, 5, 0.0, 0.16, 2.2)  # wind through the bell mouth
    return x


def bed_ch02() -> np.ndarray:
    """铸雨渠：双层雨（近层颗粒 + 远层墙）+ 远雷，室内切远层的近/远混合床。"""
    rng = rng_for("bed_ch02")
    dur = 36.0
    rain_far = fft_noise(dur, rng, lambda f: gband(f, 900.0, 700.0) + 0.5 * gband(f, 2200.0, 1600.0))
    rain_far *= loop_lfo(dur, 4, 0.75, 1.0)
    grain = sparse_env(dur, rng, 260.0, 0.004, 2.2)  # individual droplet grains
    rain_near = fft_noise(dur, rng, lambda f: gband(f, 4200.0, 2600.0)) * (0.28 + 2.4 * grain)
    x = rain_far * 0.9 + rain_near * 0.75
    for at in (7.0, 21.5, 31.0):  # distant thunder rolls
        rumble = lowpass(noise(3.4, rng), linramp(3.4, 140.0, 60.0), 0.6)
        rumble *= np.sin(np.linspace(0.0, math.pi, n_of(3.4))) ** 1.6
        place_wrap(x, rumble, at + rng.random(), 1.35)
    gutter = sparse_env(dur, rng, 6.0, 0.02) * fft_noise(dur, rng, lambda f: gband(f, 1500.0, 700.0))
    return x + gutter * 0.5


def bed_ch03() -> np.ndarray:
    """盐白书库：静止馆藏空气（低频为主）+ 稀疏盐晶结晶点缀 + 极轻纸页静电。

    v2（评审返工）：旧配方以 4kHz+ 纯 hiss 为主体（质心 4180 Hz）过于刺耳；
    现以低频空气感承载响度，高频只留稀疏点缀。"""
    rng = rng_for("bed_ch03_v2")
    dur = 34.0
    air = fft_noise(dur, rng, lambda f: gband(f, 130.0, 100.0) + 0.6 * gband(f, 280.0, 190.0))
    x = air * loop_lfo(dur, 3, 0.55, 1.0)  # still archive air, slow breathing
    x += sine(D3, dur, 0.05) * loop_lfo(dur, 2, 0.4, 1.0)  # shelf-hall standing air
    static = fft_noise(dur, rng, lambda f: gband(f, 5200.0, 2200.0))
    x += static * (0.02 + 0.4 * sparse_env(dur, rng, 30.0, 0.003, 2.6))  # faint paper static
    for _ in range(11):  # sparse crystal-growth ticks
        f = 3800.0 + 3600.0 * rng.random()
        tick = sine(f, 0.08, 0.5) * expdecay(0.08, 0.02)
        place_wrap(x, tick, dur * rng.random(), 0.32)
    for _ in range(3):  # far page swishes stay, quieter
        sw = whoosh(0.8, rng, 700.0, 1900.0, 1.1)
        place_wrap(x, sw, dur * rng.random(), 0.1)
    return x


def bed_ch04() -> np.ndarray:
    """断弦温室：玻璃暖房闷风 + 叶面摩挲 + 湿气虫鸣。"""
    rng = rng_for("bed_ch04")
    dur = 40.0
    wind = fft_noise(dur, rng, lambda f: gband(f, 180.0, 140.0) + 0.3 * gband(f, 480.0, 300.0))
    x = wind * loop_lfo(dur, 4, 0.5, 1.0) * 1.05
    leaves = fft_noise(dur, rng, lambda f: gband(f, 2600.0, 1500.0))
    x += leaves * loop_lfo(dur, 9, 0.05, 0.4, 0.6) * loop_lfo(dur, 2, 0.5, 1.0)
    for _ in range(14):  # humid insect chirps
        f = 3300.0 + 1600.0 * rng.random()
        tr = sine(f * (1.0 + 0.04 * np.sin(2 * math.pi * 38.0 * t_axis(0.22))), 0.22, 0.4)
        place_wrap(x, tr * np.sin(np.linspace(0, math.pi, n_of(0.22))) ** 2, dur * rng.random(), 0.22)
    for _ in range(6):  # condensation drips off the glass
        place_wrap(x, drip(rng, 2300.0 + 700.0 * rng.random(), 0.2), dur * rng.random(), 0.28)
    return x


def bed_ch05() -> np.ndarray:
    """黑曜巡礼道：高原夜风 + 火把群噼啪 + 远处行军鼓。"""
    rng = rng_for("bed_ch05")
    dur = 42.0
    wind = fft_noise(dur, rng, lambda f: gband(f, 300.0, 240.0) + 0.5 * gband(f, 900.0, 600.0))
    x = wind * loop_lfo(dur, 5, 0.35, 1.0) * loop_lfo(dur, 11, 0.7, 1.0, 2.0) * 1.1
    torch = fft_noise(dur, rng, lambda f: gband(f, 1900.0, 1300.0))
    x += torch * (2.6 * sparse_env(dur, rng, 14.0, 0.003, 2.2)) * 0.5
    x += sine(D2, dur, 0.07) * loop_lfo(dur, 2, 0.5, 1.0)  # mountain body hum
    beat = 0
    while beat * 3.5 < dur - 0.5:  # far war drums, slow march pulse
        at = beat * 3.5 + 0.12 * rng.random()
        thump = sine(57.0, 0.22, 1.0) * np.sin(np.linspace(0, math.pi, n_of(0.22))) ** 2
        place_wrap(x, lowpass(thump, 220.0), at, 0.5)
        if beat % 3 == 2:
            place_wrap(x, lowpass(thump, 200.0), at + 0.42, 0.3)
        beat += 1
    return x


def bed_ch06() -> np.ndarray:
    """无声王冠：有组织的静默——气压 hiss + 极微耳鸣单音 + 真空低鸣。"""
    rng = rng_for("bed_ch06")
    dur = 44.0
    hiss = fft_noise(dur, rng, lambda f: gband(f, 4600.0, 2400.0))
    x = hiss * loop_lfo(dur, 3, 0.5, 1.0) * 0.30  # air-pressure hiss
    x += sine(6400.0, dur, 0.05) * loop_lfo(dur, 5, 0.35, 1.0, 1.1)  # faint tinnitus
    x += (sine(D2, dur, 0.5) + sine(D2 * 1.004, dur, 0.4)) * loop_lfo(dur, 2, 0.55, 1.0)
    x += sine(D3, dur, 0.12) * loop_lfo(dur, 4, 0.2, 0.8, 2.4)  # vacuum bell-throat hum
    swell = fft_noise(dur, rng, lambda f: gband(f, 140.0, 110.0))
    x += swell * loop_lfo(dur, 6, 0.0, 0.5, 0.4) * 0.6  # pressure "earplug" waves
    return x


# ---------------------------------------------------- A. ambience one-shots

def a_ch01_1() -> np.ndarray:  # 苔间滴水
    return drip(rng_for("a01_1"), 1650.0, 0.45)[: n_of(0.5)].copy()


def a_ch01_2() -> np.ndarray:  # 远处齿轮咬合
    rng = rng_for("a01_2")
    dur = 1.6
    teeth = 1.0 + 0.8 * np.sign(np.sin(2 * math.pi * 9.0 * t_axis(dur)))
    body = bandpass(noise(dur, rng), 620.0, 1.8) * teeth
    x = lowpass(body, 900.0) * expdecay(dur, 0.8) * linramp(dur, 0.4, 1.0)
    place(x, sine(180.0, 0.5, 0.4) * expdecay(0.5, 0.2), 0.9)
    return x


def a_ch01_3() -> np.ndarray:  # 铜蛾翅颤掠过
    rng = rng_for("a01_3")
    dur = 1.2
    flut = bandpass(noise(dur, rng), 3400.0, 2.2)
    flut *= 0.5 + 0.5 * np.sign(np.sin(2 * math.pi * 46.0 * t_axis(dur)))
    env = np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.6  # passes by
    return flut * env + sine(2200.0, dur, 0.08) * env


def a_ch01_4() -> np.ndarray:  # 青铜构件热胀吱呀
    rng = rng_for("a01_4")
    dur = 1.5
    creak = bandpass(noise(dur, rng), linramp(dur, 380.0, 720.0), 3.2)
    creak *= 1.0 + 0.7 * np.sin(2 * math.pi * 13.0 * t_axis(dur))
    x = creak * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.8
    place(x, sine(950.0, 0.4, 0.2) * expdecay(0.4, 0.12), 0.9)
    return x


def a_ch01_5() -> np.ndarray:  # 孢子囊轻爆
    rng = rng_for("a01_5")
    x = silence(1.0)
    place(x, lowpass(noise(0.09, rng), 800.0) * expdecay(0.09, 0.03), 0.0, 1.2)
    for k in range(6):
        place(x, chirp(900.0 + 500.0 * rng.random(), 400.0, 0.05, 0.02, 0.5), 0.06 + 0.07 * k)
    return x


def a_ch01_6() -> np.ndarray:  # 苔藓蠕动蜂窝音
    rng = rng_for("a01_6")
    dur = 2.2
    body = lowpass(noise(dur, rng), 500.0, 0.7)
    pores = 1.0 + 2.0 * sparse_env(dur, rng, 22.0, 0.008, 2.0)
    return body * pores * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.2


def a_ch01_7() -> np.ndarray:  # 风穿钟口的哨音
    rng = rng_for("a01_7")
    dur = 2.4
    f = 1250.0 * (1.0 + 0.12 * np.sin(2 * math.pi * 0.9 * t_axis(dur)))
    tone = sine(f, dur, 0.7) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.5
    breath = bandpass(noise(dur, rng), f, 2.6) * 0.6
    return tone + breath * np.sin(np.linspace(0, math.pi, n_of(dur)))


def a_ch01_8() -> np.ndarray:  # 远方一记哑钟
    rng = rng_for("a01_8")
    x = bell(D4, 2.6, bright=0.5, damp=1.4, strike=0.2, rng=rng)
    return lowpass(x, 900.0)


def a_ch02_anvil() -> np.ndarray:  # amb_ch02_anvil_far 远砧一击
    rng = rng_for("a02_anvil")
    x = silence(1.7)
    hit = sine(880.0, 0.5, 0.8) * expdecay(0.5, 0.07)
    place(hit, sine(1320.0, 0.4, 0.5) * expdecay(0.4, 0.05), 0.0)
    place(hit, bandpass(noise(0.03, rng), 2600.0, 1.2), 0.0)
    place(x, lowpass(hit, 1600.0), 0.0)
    for delay, gain in ((0.24, 0.4), (0.55, 0.22), (0.95, 0.11)):
        place(x, lowpass(hit, 1100.0), delay, gain)  # canal echoes
    return x


def a_ch02_1() -> np.ndarray:  # 雨点打铁皮
    rng = rng_for("a02_1")
    dur = 2.2
    tin = bandpass(noise(dur, rng), 3100.0, 1.4)
    hits = sparse_env(dur, rng, 26.0, 0.005, 2.4)
    x = tin * hits * 3.0
    x += sine(520.0, dur, 0.1) * hits  # sheet-metal body ring
    return x * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.6


def a_ch02_2() -> np.ndarray:  # 水轮转动
    rng = rng_for("a02_2")
    dur = 2.6
    churn = lowpass(noise(dur, rng), 420.0, 0.7)
    paddles = 1.0 + 0.8 * np.sin(2 * math.pi * 1.6 * t_axis(dur))
    x = churn * paddles
    drops = sparse_env(dur, rng, 12.0, 0.01) * bandpass(noise(dur, rng), 2200.0, 1.4)
    return (x + drops * 1.6) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.8


def a_ch02_3() -> np.ndarray:  # 管道滴漏
    rng = rng_for("a02_3")
    x = silence(2.0)
    for i, at in enumerate((0.0, 0.55, 1.25)):
        place(x, drip(rng, 2100.0 - 260.0 * i, 0.5), at, 1.0 - 0.2 * i)
    place(x, sine(240.0, 1.6, 0.08) * expdecay(1.6, 0.7), 0.1)  # pipe body hum
    return x


def a_ch02_4() -> np.ndarray:  # 蒸汽泄压
    rng = rng_for("a02_4")
    dur = 1.8
    steam = highpass(noise(dur, rng), 2400.0)
    env = np.concatenate([linramp(0.06, 0.0, 1.0), expdecay(dur - 0.06, 0.55)])
    x = steam * env
    place(x, chirp(600.0, 300.0, 0.1, 0.05, 0.4), 0.0)  # valve pop
    return x


def a_ch02_5() -> np.ndarray:  # 锁链晃动
    rng = rng_for("a02_5")
    x = silence(2.2)
    for k in range(9):
        at = 0.12 * k + 0.9 * (k / 9.0) ** 2 + 0.02 * rng.random()
        f = 2500.0 + 1800.0 * rng.random()
        link = sine(f, 0.1, 0.5) * expdecay(0.1, 0.02)
        place(link, bandpass(noise(0.02, rng), f, 2.0), 0.0, 0.5)
        place(x, link, at, 1.0 - 0.07 * k)
    place(x, sine(140.0, 1.0, 0.15) * expdecay(1.0, 0.4), 0.0)
    return x


def a_ch02_6() -> np.ndarray:  # 远雷
    rng = rng_for("a02_6")
    dur = 3.0
    r = lowpass(noise(dur, rng), linramp(dur, 150.0, 55.0), 0.6)
    env = np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.4
    env *= 1.0 + 0.5 * np.sin(2 * math.pi * 1.1 * t_axis(dur) + 0.6)
    return r * env


def a_ch02_7() -> np.ndarray:  # 水下闷涌（泵井）
    rng = rng_for("a02_7")
    dur = 2.4
    surge = lowpass(noise(dur, rng), 260.0, 0.6)
    surge *= 1.0 + 0.7 * np.sin(2 * math.pi * 0.8 * t_axis(dur))
    bub = sparse_env(dur, rng, 7.0, 0.015) * bandpass(noise(dur, rng), 700.0, 2.0)
    return (surge + bub * 1.4) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.9


def a_ch02_8() -> np.ndarray:  # 雨槽溢流冲刷
    rng = rng_for("a02_8")
    dur = 2.0
    wash = bandpass(noise(dur, rng), linramp(dur, 1300.0, 800.0), 0.9)
    x = wash * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.7
    for at in (0.5, 0.9, 1.4):
        place(x, drip(rng, 1900.0, 0.0), at, 0.5)
    return x


def a_ch03_1() -> np.ndarray:  # 远处翻页
    rng = rng_for("a03_1")
    x = silence(1.4)
    place(x, whoosh(0.5, rng, 1200.0, 3200.0, 1.0), 0.0, 1.0)
    place(x, whoosh(0.4, rng, 2600.0, 1000.0, 1.0), 0.55, 0.7)
    place(x, lowpass(noise(0.05, rng), 900.0) * expdecay(0.05, 0.02), 0.95, 0.6)
    return x


def a_ch03_2() -> np.ndarray:  # 笔尖誊写
    rng = rng_for("a03_2")
    dur = 2.2
    scr = bandpass(noise(dur, rng), 4300.0, 2.4)
    strokes = np.clip(4.0 * sparse_env(dur, rng, 5.0, 0.06, 1.0), 0.0, 1.0)
    return scr * strokes


def a_ch03_3() -> np.ndarray:  # 盐晶脆裂
    rng = rng_for("a03_3")
    x = silence(1.1)
    for k in range(7):
        f = 4200.0 + 4200.0 * rng.random()
        place(x, sine(f, 0.07, 0.6) * expdecay(0.07, 0.015), 0.05 * k + 0.03 * rng.random())
    place(x, highpass(noise(0.4, rng), 6000.0) * expdecay(0.4, 0.1), 0.0, 0.6)
    return x


def a_ch03_4() -> np.ndarray:  # 书架承重呻吟
    rng = rng_for("a03_4")
    dur = 2.0
    creak = bandpass(noise(dur, rng), linramp(dur, 240.0, 420.0), 3.0)
    creak *= 1.0 + 0.6 * np.sin(2 * math.pi * 7.0 * t_axis(dur))
    x = creak * np.sin(np.linspace(0, math.pi, n_of(dur)))
    x += sine(110.0, dur, 0.2) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 2
    return x


def a_ch03_5() -> np.ndarray:  # 迟影掠过的反相 whoosh
    rng = rng_for("a03_5")
    dur = 1.3
    sw = whoosh(dur, rng, 2800.0, 700.0, 1.2)
    return sw[::-1].copy() - 0.4 * sw  # reversed layer against itself: phasey


def a_ch03_6() -> np.ndarray:  # 封蜡滴落
    rng = rng_for("a03_6")
    x = silence(1.2)
    place(x, chirp(700.0, 260.0, 0.09, 0.04), 0.0, 0.9)  # soft hot-wax blob
    place(x, lowpass(noise(0.12, rng), 600.0) * expdecay(0.12, 0.04), 0.02, 0.7)
    place(x, chirp(520.0, 240.0, 0.06, 0.03, 0.4), 0.34)
    return x


def a_ch03_7() -> np.ndarray:  # 索引卡片弹跳
    rng = rng_for("a03_7")
    x = silence(1.1)
    for k in range(5):
        snap = highpass(noise(0.02, rng), 3200.0) * expdecay(0.02, 0.006)
        place(x, snap, 0.12 * k * (1.0 - 0.06 * k), 1.0 - 0.12 * k)
    place(x, whoosh(0.4, rng, 1800.0, 3600.0, 1.2), 0.45, 0.5)
    return x


def a_ch03_8() -> np.ndarray:  # 极远女声读词（听不清）
    rng = rng_for("a03_8")
    dur = 2.6
    f0 = 210.0 * (1.0 + 0.05 * np.sin(2 * math.pi * 4.7 * t_axis(dur)))
    voice = sine(f0, dur, 0.6) + sine(f0 * 2.0, dur, 0.35) + sine(f0 * 3.0, dur, 0.18)
    syl = np.clip(3.0 * sparse_env(dur, rng, 3.2, 0.09, 0.8), 0.0, 1.0)
    x = lowpass(voice * syl, 900.0)
    return x + lowpass(x, 600.0)[::-1] * 0.2  # unintelligible, hall-washed


def a_ch04_1() -> np.ndarray:  # 玻璃风铃
    rng = rng_for("a04_1")
    x = silence(2.6)
    for k, f in enumerate((2093.0, 2637.0, 3136.0, 2349.0)):
        strike = sine(f, 0.9, 0.7) * expdecay(0.9, 0.22)
        place(strike, sine(f * 2.76, 0.5, 0.2) * expdecay(0.5, 0.1), 0.0)
        place(x, strike, 0.3 * k + 0.15 * rng.random(), 0.9 - 0.12 * k)
    return x


def a_ch04_2() -> np.ndarray:  # 藤蔓伸长吱嘎
    rng = rng_for("a04_2")
    dur = 1.8
    creak = bandpass(noise(dur, rng), linramp(dur, 300.0, 640.0), 3.4)
    creak *= 1.0 + 0.75 * np.sin(2 * math.pi * 18.0 * t_axis(dur) * linramp(dur, 0.7, 1.3))
    x = creak * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.7
    place(x, pluck(G3, 0.3, 0.08, 0.4, rng=rng), 1.3)  # fiber settles
    return x


def a_ch04_3() -> np.ndarray:  # 花粉风袭
    rng = rng_for("a04_3")
    dur = 2.4
    gust = bandpass(noise(dur, rng), linramp(dur, 500.0, 1500.0), 0.9)
    dust = highpass(noise(dur, rng), 5200.0) * 0.35
    env = np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.1
    return (gust + dust) * env


def a_ch04_4() -> np.ndarray:  # 蜂群远近
    rng = rng_for("a04_4")
    dur = 2.8
    f = 190.0 * (1.0 + 0.08 * np.sin(2 * math.pi * 1.3 * t_axis(dur)) + 0.02 * lowpass(noise(dur, rng), 6.0, 0.6))
    swarm = sine(f, dur, 0.6) + sine(f * 2.01, dur, 0.35) + sine(f * 2.99, dur, 0.2)
    swarm += bandpass(noise(dur, rng), 260.0, 2.0) * 0.5
    env = np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.8  # approaches, recedes
    return swarm * env


def a_ch04_5() -> np.ndarray:  # 玻璃裂纹蔓延
    rng = rng_for("a04_5")
    x = silence(1.5)
    place(x, highpass(noise(0.03, rng), 3800.0), 0.0, 0.9)
    for k in range(9):
        at = 0.06 + 1.1 * (k / 9.0) ** 1.5 + 0.02 * rng.random()
        f = 5200.0 + 3400.0 * rng.random()
        place(x, sine(f, 0.05, 0.5) * expdecay(0.05, 0.012), at, 1.0 - 0.08 * k)
    return x


def a_ch04_6() -> np.ndarray:  # 断弦远响（单根提琴弦崩）
    rng = rng_for("a04_6")
    x = silence(1.9)
    snap = pluck(G3 * 2.0, 1.2, 0.3, 1.0, rng=rng)
    place(x, snap, 0.0)
    place(x, lowpass(snap, 1200.0), 0.35, 0.4)  # greenhouse glass echo
    place(x, highpass(noise(0.015, rng), 2800.0), 0.0, 0.8)
    return x


def a_ch04_7() -> np.ndarray:  # 果实落地
    rng = rng_for("a04_7")
    x = silence(1.2)
    place(x, sine(linramp(0.09, 180.0, 70.0), 0.09, 1.0) * expdecay(0.09, 0.04), 0.0)
    place(x, lowpass(noise(0.08, rng), 700.0) * expdecay(0.08, 0.025), 0.0, 0.8)
    place(x, sine(linramp(0.05, 150.0, 80.0), 0.05, 0.4) * expdecay(0.05, 0.02), 0.28)  # small bounce
    place(x, bandpass(noise(0.3, rng), 1900.0, 1.4) * expdecay(0.3, 0.1), 0.05, 0.25)  # leaf scatter
    return x


def a_ch04_8() -> np.ndarray:  # 藤蔓爆珠
    rng = rng_for("a04_8")
    x = silence(1.3)
    for k in range(5):
        at = 0.14 * k + 0.05 * rng.random()
        place(x, chirp(1500.0 - 130.0 * k, 500.0, 0.05, 0.018, 0.8), at)
        place(x, lowpass(noise(0.05, rng), 900.0) * expdecay(0.05, 0.015), at, 0.7)
    place(x, whoosh(0.5, rng, 800.0, 2000.0, 1.4), 0.6, 0.35)  # juice mist
    return x


def a_ch05_1() -> np.ndarray:  # 旗帜猎猎
    rng = rng_for("a05_1")
    dur = 2.2
    cloth = bandpass(noise(dur, rng), 1500.0, 0.9)
    flap = np.clip(1.0 + 5.0 * sparse_env(dur, rng, 9.0, 0.02, 1.2), 0.2, 3.2)
    return cloth * flap * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.7


def a_ch05_2() -> np.ndarray:  # 旗杆震动
    rng = rng_for("a05_2")
    dur = 2.0
    f = 132.0
    x = sine(f * (1.0 + 0.01 * np.sin(2 * math.pi * 5.4 * t_axis(dur))), dur, 0.8) * expdecay(dur, 0.6)
    x += sine(f * 4.1, dur, 0.25) * expdecay(dur, 0.3)
    x[: n_of(0.01)] += bandpass(noise(0.01, rng), 900.0, 1.2)[: n_of(0.01)]
    return x


def a_ch05_3() -> np.ndarray:  # 远处行军鼓
    rng = rng_for("a05_3")
    x = silence(2.6)
    for k, (at, g) in enumerate(((0.0, 1.0), (0.5, 0.8), (1.0, 1.0), (1.32, 0.55), (1.5, 0.9), (2.0, 0.7))):
        thump = sine(64.0, 0.2, 1.0) * np.sin(np.linspace(0, math.pi, n_of(0.2))) ** 2
        place(x, lowpass(thump, 240.0), at, g * 0.9)
        place(x, bandpass(noise(0.05, rng), 800.0, 1.0) * expdecay(0.05, 0.02), at, 0.2 * g)
    return x


def a_ch05_4() -> np.ndarray:  # 灰烬簌落
    rng = rng_for("a05_4")
    dur = 2.2
    fall = highpass(noise(dur, rng), 4600.0)
    grains = sparse_env(dur, rng, 40.0, 0.004, 2.0)
    return fall * (0.12 + 2.2 * grains) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.3


def a_ch05_5() -> np.ndarray:  # 灯芯吸气
    rng = rng_for("a05_5")
    x = silence(1.4)
    swell = lowpass(noise(0.5, rng), 600.0) * np.linspace(0.0, 1.0, n_of(0.5)) ** 2
    place(x, swell[::-1], 0.0, 1.0)  # reversed intake
    place(x, sine(linramp(0.35, 90.0, 46.0), 0.35, 0.8) * expdecay(0.35, 0.12), 0.45)
    place(x, highpass(noise(0.2, rng), 3600.0) * expdecay(0.2, 0.05), 0.5, 0.4)
    return x


def a_ch05_6() -> np.ndarray:  # 黑曜石冷缩脆响
    rng = rng_for("a05_6")
    x = silence(1.0)
    place(x, sine(150.0, 0.06, 0.9) * expdecay(0.06, 0.02), 0.0)
    for k in range(4):
        f = 3000.0 + 2600.0 * rng.random()
        place(x, sine(f, 0.05, 0.5) * expdecay(0.05, 0.01), 0.02 + 0.11 * k, 0.8 - 0.15 * k)
    return x


def a_ch05_7() -> np.ndarray:  # 盔甲队列远过
    rng = rng_for("a05_7")
    dur = 2.8
    x = silence(dur)
    for k in range(6):
        at = 0.42 * k + 0.02 * rng.random()
        step = lowpass(noise(0.1, rng), 300.0) * expdecay(0.1, 0.03)
        place(x, step, at, 0.9)
        jangle = bandpass(noise(0.08, rng), 2600.0, 1.6) * expdecay(0.08, 0.025)
        place(x, jangle, at + 0.02, 0.35)
    return x * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.9


def a_ch05_8() -> np.ndarray:  # 山体低鸣
    rng = rng_for("a05_8")
    dur = 3.0
    x = sine(D2 * (1.0 + 0.006 * np.sin(2 * math.pi * 0.7 * t_axis(dur))), dur, 1.0)
    x += lowpass(noise(dur, rng), 90.0, 0.6) * 0.8
    return x * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.4


def a_ch06_1() -> np.ndarray:  # 羽状白尘飘落
    rng = rng_for("a06_1")
    dur = 2.6
    dust = highpass(noise(dur, rng), 6800.0)
    drift = np.clip(2.0 * sparse_env(dur, rng, 16.0, 0.02, 1.6), 0.0, 1.0)
    return dust * drift * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.5


def a_ch06_2() -> np.ndarray:  # 金属谐振被激发又止
    rng = rng_for("a06_2")
    x = sine(1720.0, 1.5, 0.9) * expdecay(1.5, 0.5)
    place(x, sine(1720.0 * 2.4, 1.0, 0.3) * expdecay(1.0, 0.2), 0.0)
    x[: n_of(0.008)] += bandpass(noise(0.008, rng), 4200.0, 1.2)[: n_of(0.008)]
    cut = n_of(0.62)  # resonance is stopped mid-ring
    x[cut:] *= np.exp(-np.arange(len(x) - cut) / (0.012 * SR))
    return x


def a_ch06_3() -> np.ndarray:  # 远童声半句
    rng = rng_for("a06_3")
    dur = 2.0
    f0 = 340.0 * (1.0 + 0.04 * np.sin(2 * math.pi * 5.2 * t_axis(dur)))
    v = sine(f0, dur, 0.7) + sine(f0 * 2.0, dur, 0.3) + sine(f0 * 2.99, dur, 0.12)
    syl = np.clip(3.0 * sparse_env(dur, rng, 2.6, 0.11, 0.7), 0.0, 1.0)
    x = lowpass(v * syl, 1100.0)
    x[n_of(1.35):] *= np.linspace(1.0, 0.0, len(x) - n_of(1.35)) ** 2  # half a phrase
    return x + np.roll(x, n_of(0.22)) * 0.3


def a_ch06_4() -> np.ndarray:  # 心跳（自己的）
    rng = rng_for("a06_4")
    x = silence(1.6)
    for at in (0.0, 0.94):
        place(x, sine(54.0, 0.12, 1.0) * np.sin(np.linspace(0, math.pi, n_of(0.12))) ** 2, at)
        place(x, sine(42.0, 0.1, 0.7) * np.sin(np.linspace(0, math.pi, n_of(0.1))) ** 2, at + 0.19)
    place(x, lowpass(noise(0.1, rng), 200.0) * expdecay(0.1, 0.03), 0.0, 0.1)
    return x


def a_ch06_5() -> np.ndarray:  # 真空吸引门风
    rng = rng_for("a06_5")
    dur = 2.2
    windf = bandpass(noise(dur, rng), linramp(dur, 300.0, 1400.0), 0.8)
    env = np.linspace(0.0, 1.0, n_of(dur)) ** 2.2
    x = windf * env
    x[n_of(dur - 0.12):] *= np.linspace(1.0, 0.0, len(x) - n_of(dur - 0.12)) ** 0.5  # door seals
    return x


def a_ch06_6() -> np.ndarray:  # 王冠丝线微颤
    rng = rng_for("a06_6")
    x = silence(1.8)
    for i, f in enumerate((D5, A4, BB4)):
        tr = sine(f * (1.0 + 0.006 * np.sin(2 * math.pi * 11.0 * t_axis(1.0))), 1.0, 0.5)
        place(x, tr * expdecay(1.0, 0.35), 0.22 * i, 0.8 - 0.15 * i)
    place(x, pluck(D5, 0.4, 0.1, 0.25, rng=rng), 0.0)  # a single thread-tick sets them off
    return highpass(x, 300.0)


def a_ch06_7() -> np.ndarray:  # 静默压强"耳塞感"起伏
    rng = rng_for("a06_7")
    dur = 2.8
    p = lowpass(noise(dur, rng), 130.0, 0.6)
    x = p * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.1
    x += sine(6400.0, dur, 0.04) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 3  # ear whine peaks
    return x


def a_ch06_8() -> np.ndarray:  # 一次远得不可能的回声钟
    rng = rng_for("a06_8")
    x = silence(3.0)
    strike = lowpass(bell(D4, 2.2, bright=0.4, damp=0.7, strike=0.1, rng=rng), 700.0)
    place(x, strike, 0.0, 0.8)
    place(x, strike, 0.5, 0.3)
    place(x, strike, 1.1, 0.12)
    return x


# ------------------------------------------------------------ B. beat sfx

def beat_ch02_01() -> np.ndarray:
    """wall_grip：低频吸附声加轻微水滴尾音。"""
    rng = rng_for("b0201")
    x = silence(0.85)
    place(x, sine(linramp(0.14, 200.0, 62.0), 0.14, 1.0) * expdecay(0.14, 0.06), 0.0)
    place(x, lowpass(noise(0.14, rng), 380.0) * expdecay(0.14, 0.05), 0.0, 0.9)
    place(x, drip(rng, 1700.0, 0.3), 0.3, 0.5)  # the wet-wall drip tail
    return x


def beat_ch02_02() -> np.ndarray:
    """echo_hook：钩环金属声后接一拍水声回响。"""
    rng = rng_for("b0202")
    x = silence(1.2)
    place(x, bell(E5, 0.4, bright=1.2, damp=1.8, strike=0.6, rng=rng), 0.0)
    wat = lowpass(noise(0.55, rng), linramp(0.55, 900.0, 300.0), 0.7)
    wat *= 1.0 + 0.6 * np.sin(2 * math.pi * 9.0 * t_axis(0.55))
    place(x, wat * np.sin(np.linspace(0, math.pi, n_of(0.55))) ** 1.2, 0.42, 0.9)
    place(x, chirp(1400.0, 700.0, 0.06, 0.025, 0.4), 0.55)
    return x


def beat_ch02_03() -> np.ndarray:
    """boss_water_hammer：重击叠水浪（heavy_hit 本地 OGG 的水浪叠加层）。"""
    rng = rng_for("b0203")
    x = silence(1.3)
    place(x, bandpass(noise(0.1, rng), 1500.0, 0.9) * expdecay(0.1, 0.03), 0.0, 1.1)
    place(x, sine(72.0, 0.3, 1.0) * expdecay(0.3, 0.09), 0.0)
    wave_ = lowpass(noise(0.8, rng), linramp(0.8, 700.0, 250.0), 0.6)
    place(x, wave_ * np.sin(np.linspace(0, math.pi, n_of(0.8))) ** 0.9, 0.06, 1.2)
    spray = sparse_env(0.7, rng, 20.0, 0.008) * bandpass(noise(0.7, rng), 2600.0, 1.4)
    place(x, spray, 0.1, 1.2)
    return x


def beat_ch03_01() -> np.ndarray:
    """delayed_shadow：玻璃摩擦声和低音翻页声。"""
    rng = rng_for("b0301")
    x = silence(1.1)
    squeal = bandpass(noise(0.6, rng), linramp(0.6, 2400.0, 3300.0), 4.0)
    squeal *= 1.0 + 0.5 * np.sin(2 * math.pi * 16.0 * t_axis(0.6))
    place(x, squeal * np.sin(np.linspace(0, math.pi, n_of(0.6))) ** 0.8, 0.0, 0.9)
    page = lowpass(noise(0.5, rng), 500.0, 0.7) * np.sin(np.linspace(0, math.pi, n_of(0.5))) ** 1.2
    place(x, page, 0.35, 1.0)
    return x


def beat_ch03_02() -> np.ndarray:
    """bell_guard：短促钟壳响和能量回流声。"""
    rng = rng_for("b0302")
    x = silence(0.95)
    place(x, bell(A4, 0.5, bright=1.1, damp=2.2, strike=0.6, rng=rng), 0.0)
    backflow = sine(A5, 0.35, 0.5) * np.linspace(0.0, 1.0, n_of(0.35)) ** 2
    place(x, backflow[::-1], 0.3)  # reversed swell = energy sucked back
    place(x, highpass(noise(0.25, rng), 3000.0) * np.linspace(0.0, 1.0, n_of(0.25)) ** 2, 0.35, 0.3)
    return x


def beat_ch03_03() -> np.ndarray:
    """contract_break：纸页撕裂声与低频钟声。"""
    rng = rng_for("b0303")
    x = silence(1.5)
    tear = bandpass(noise(0.5, rng), linramp(0.5, 900.0, 3200.0), 1.2)
    tear *= 1.0 + 0.7 * np.sign(np.sin(2 * math.pi * 74.0 * t_axis(0.5)))
    place(x, tear * expdecay(0.5, 0.2), 0.0, 1.0)
    place(x, bell(D3, 1.2, bright=0.7, damp=0.9, strike=0.3, rng=rng), 0.18, 0.95)
    return x


def beat_ch04_01() -> np.ndarray:
    """thorn_downstrike：短促木裂声（下劈重击叠加层）。"""
    rng = rng_for("b0401")
    x = silence(0.7)
    place(x, highpass(noise(0.04, rng), 1600.0) * expdecay(0.04, 0.012), 0.0, 1.2)
    for at in (0.015, 0.04, 0.07):
        place(x, bandpass(noise(0.025, rng), 1900.0 + 1100.0 * rng.random(), 1.8), at, 0.8)
    place(x, sine(linramp(0.16, 220.0, 90.0), 0.16, 0.9) * expdecay(0.16, 0.05), 0.0)
    place(x, bandpass(noise(0.25, rng), 3200.0, 1.4) * expdecay(0.25, 0.07), 0.05, 0.4)  # leaf burst
    return x


def beat_ch04_02() -> np.ndarray:
    """pollen_wind：轻风声和蜂蜡颤音。"""
    rng = rng_for("b0402")
    dur = 1.6
    gust = bandpass(noise(dur, rng), linramp(dur, 600.0, 1600.0), 0.9)
    x = gust * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.1
    waxf = 235.0 * (1.0 + 0.05 * np.sin(2 * math.pi * 27.0 * t_axis(dur)))
    x += sine(waxf, dur, 0.28) * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.6
    x += highpass(noise(dur, rng), 5600.0) * 0.12 * np.sin(np.linspace(0, math.pi, n_of(dur)))
    return x


def beat_ch04_03() -> np.ndarray:
    """string_bridge_break：断弦拨片声和轻微石屑落地声。"""
    rng = rng_for("b0403")
    x = silence(1.1)
    snap = pluck(G3, 0.7, 0.22, 1.0, rng=rng)
    snap *= np.concatenate([np.ones(n_of(0.05)), np.linspace(1.0, 0.6, len(snap) - n_of(0.05))])
    place(x, snap, 0.0)
    place(x, pluck(G3 * 1.5, 0.4, 0.1, 0.5, rng=rng), 0.03)  # the two loose ends whip back
    for k in range(6):
        at = 0.3 + 0.5 * rng.random()
        place(x, bandpass(noise(0.03, rng), 2200.0 + 1600.0 * rng.random(), 2.0) * expdecay(0.03, 0.008), at, 0.35)
    return x


def beat_ch05_01() -> np.ndarray:
    """lantern_phase：低频灯芯吸入声和短促相位噪音。"""
    rng = rng_for("b0501")
    x = silence(1.0)
    swell = lowpass(noise(0.4, rng), 650.0) * np.linspace(0.0, 1.0, n_of(0.4)) ** 2
    place(x, swell[::-1], 0.0, 1.0)  # wick intake
    ph = bandpass(noise(0.35, rng), 1100.0, 1.1) * sine(760.0, 0.35)  # ring-mod phase fizz
    place(x, ph * expdecay(0.35, 0.1), 0.36, 0.9)
    place(x, sine(linramp(0.3, 110.0, 44.0), 0.3, 0.9) * expdecay(0.3, 0.1), 0.4)
    return x


def beat_ch05_02() -> np.ndarray:
    """silent_order：无声前摇后接一次低频压缩声。"""
    rng = rng_for("b0502")
    x = silence(1.1)
    # 0.3 s of engineered near-silence: only a hair of air
    place(x, highpass(noise(0.28, rng), 7000.0) * 0.02, 0.0)
    comp = np.tanh(sine(linramp(0.4, 66.0, 38.0), 0.4, 1.6)) * expdecay(0.4, 0.16)
    place(x, comp, 0.3)
    place(x, lowpass(noise(0.25, rng), 240.0) * expdecay(0.25, 0.07), 0.3, 0.8)
    place(x, highpass(noise(0.01, rng), 2600.0), 0.3, 0.5)  # command tick at the onset
    return x


def beat_ch05_03() -> np.ndarray:
    """parade_charge：低频步伐循环和旗杆震动声（loop）。"""
    rng = rng_for("b0503")
    dur = 2.0
    x = silence(dur)
    for k in range(4):  # 2 Hz war-march stomps
        at = 0.5 * k
        stomp = sine(60.0, 0.18, 1.0) * np.sin(np.linspace(0, math.pi, n_of(0.18))) ** 2
        place(x, lowpass(stomp, 200.0), at, 1.0)
        place(x, lowpass(noise(0.07, rng), 320.0) * expdecay(0.07, 0.02), at, 0.5)
    pole = sine(132.0, dur, 0.22) * (1.0 + 0.4 * np.sin(2 * math.pi * 6.0 * t_axis(dur)))
    x += pole + bandpass(noise(dur, rng), 1700.0, 1.2) * 0.08
    return make_loop(x, 0.15)


def beat_ch06_01() -> np.ndarray:
    """echo_room_open：低频钟声与章节主题音色短句。"""
    rng = rng_for("b0601")
    x = silence(2.0)
    place(x, bell(D3, 1.6, bright=0.8, damp=0.8, strike=0.4, rng=rng), 0.0, 1.0)
    # five chapter-seal voices answer in turn (moss/copper/salt/fiber/obsidian)
    place(x, lowpass(bell(D5, 0.4, damp=1.6, strike=0.2, rng=rng), 3200.0), 0.35, 0.5)
    place(x, bell(A4, 0.4, bright=1.4, damp=2.0, strike=0.3, rng=rng), 0.62, 0.45)
    place(x, highpass(bell(D6, 0.35, damp=2.4, strike=0.2, rng=rng), 800.0), 0.89, 0.4)
    place(x, pluck(BB4, 0.4, 0.12, 0.55, rng=rng), 1.16)
    place(x, lowpass(bell(D4, 0.5, bright=0.6, damp=1.6, strike=0.2, rng=rng), 1100.0), 1.43, 0.5)
    return x


def beat_ch06_02() -> np.ndarray:
    """crown_resonance：低频脉冲、线弦拨动声和短暂停顿。"""
    rng = rng_for("b0602")
    x = silence(1.9)
    place(x, np.tanh(sine(52.0, 0.25, 1.5)) * expdecay(0.25, 0.09), 0.0)
    for i, f in enumerate((D5, A4, BB4)):  # the motif on three re-tied threads
        place(x, pluck(f, 0.45, 0.14, 0.9, rng=rng), 0.14 + 0.2 * i)
    # one deliberate beat of silence, then the crown answers
    place(x, sine(D6, 0.45, 0.28) * expdecay(0.45, 0.16), 1.45)
    place(x, np.tanh(sine(52.0, 0.2, 1.2)) * expdecay(0.2, 0.07), 1.42, 0.7)
    return x


def beat_ch06_03() -> np.ndarray:
    """ending_doors：重鸣为钟声，断冠为断弦，真结局为绯线和声。"""
    rng = rng_for("b0603")
    x = silence(2.4)
    place(x, bell(D4, 0.8, bright=1.2, damp=1.1, strike=0.5, rng=rng), 0.0, 0.9)  # gold door: full toll
    snap = pluck(G3, 0.5, 0.1, 1.0, rng=rng)  # black door: string severed
    place(x, snap, 0.8)
    place(x, highpass(noise(0.012, rng), 2600.0), 0.8, 0.7)
    for f, g in ((D4, 0.6), (A4, 0.55), (D5, 0.5), (FS4, 0.35)):  # crimson door: thread chord
        swellt = sine(f, 0.9, g) * np.sin(np.linspace(0, math.pi, n_of(0.9))) ** 1.3
        place(x, swellt, 1.45)
    return x


# ---------------------------------------------------------- C. combat fill

def c_attack(idx: int) -> np.ndarray:
    """普攻三连：兵刃破风三采样（中/低/高起手音高微差 §4.2）。"""
    rng = rng_for(f"attack_{idx}")
    lo, hi, dur = ((900.0, 2500.0, 0.22), (620.0, 1700.0, 0.26), (1250.0, 3300.0, 0.19))[idx - 1]
    x = silence(dur + 0.08)
    body = bandpass(noise(dur, rng), linramp(dur, lo, hi), 1.3)
    place(x, body * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.4, 0.0, 1.1)
    thread = sine(linramp(0.08, lo * 2.2, hi * 1.4), 0.08, 0.16) * expdecay(0.08, 0.03)
    place(x, thread, 0.02)  # the crimson-thread edge sings faintly
    place(x, highpass(noise(0.02, rng), 4200.0) * expdecay(0.02, 0.006), 0.0, 0.5)
    return x


def c_land_soft() -> np.ndarray:
    rng = rng_for("land_soft")
    x = silence(0.4)
    place(x, sine(linramp(0.1, 150.0, 82.0), 0.1, 1.0) * expdecay(0.1, 0.035), 0.0)
    place(x, lowpass(noise(0.09, rng), 520.0) * expdecay(0.09, 0.03), 0.0, 0.7)
    place(x, bandpass(noise(0.12, rng), 1400.0, 0.9) * expdecay(0.12, 0.04), 0.005, 0.35)  # cloth
    return x


def c_land_hard() -> np.ndarray:
    rng = rng_for("land_hard")
    x = silence(0.65)
    place(x, np.tanh(sine(linramp(0.16, 120.0, 52.0), 0.16, 1.6)) * expdecay(0.16, 0.06), 0.0)
    place(x, lowpass(noise(0.2, rng), 400.0) * expdecay(0.2, 0.06), 0.0, 1.0)
    for k in range(5):  # dust and grit kicked out (matches LandDustVfx)
        at = 0.04 + 0.3 * rng.random()
        place(x, bandpass(noise(0.03, rng), 1600.0 + 1800.0 * rng.random(), 1.8) * expdecay(0.03, 0.01), at, 0.4)
    return x


def c_hit_soft() -> np.ndarray:
    """受击·软体：湿质切入+汁液。"""
    rng = rng_for("hit_soft")
    x = silence(0.3)
    place(x, lowpass(noise(0.09, rng), 620.0) * expdecay(0.09, 0.03), 0.0, 1.2)
    place(x, sine(linramp(0.1, 260.0, 110.0), 0.1, 0.9) * expdecay(0.1, 0.035), 0.0)
    place(x, chirp(900.0, 350.0, 0.06, 0.02, 0.4), 0.07)  # juice squirt
    return x


def c_hit_shell() -> np.ndarray:
    """受击·甲壳：脆裂+短金属。"""
    rng = rng_for("hit_shell")
    x = silence(0.3)
    place(x, highpass(noise(0.03, rng), 2600.0) * expdecay(0.03, 0.009), 0.0, 1.2)
    for at in (0.008, 0.022):
        place(x, bandpass(noise(0.02, rng), 3400.0 + 900.0 * rng.random(), 2.2), at, 0.7)
    place(x, sine(1750.0, 0.12, 0.4) * expdecay(0.12, 0.03), 0.004)
    place(x, sine(210.0, 0.08, 0.6) * expdecay(0.08, 0.025), 0.0)
    return x


def c_hit_armor() -> np.ndarray:
    """受击·重甲：火花铛+低频 thud——提示需重击/格挡。"""
    rng = rng_for("hit_armor")
    x = silence(0.42)
    for i, f in enumerate((820.0, 1360.0, 2210.0)):
        place(x, sine(f, 0.22, 0.8 - 0.2 * i) * expdecay(0.22, 0.05), 0.0)
    place(x, sine(96.0, 0.16, 1.0) * expdecay(0.16, 0.05), 0.0)
    place(x, highpass(noise(0.14, rng), 5200.0) * expdecay(0.14, 0.04), 0.006, 0.6)  # sparks
    return x


# ------------------------------------------------------------- C. boss kits

def m_gear(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch1 锈冠齿轮：棘轮咬合 + 锈钟暗示。"""
    teeth = 1.0 + 0.85 * np.sign(np.sin(2 * math.pi * 15.0 * t_axis(dur)))
    x = bandpass(noise(dur, rng), 760.0, 2.0) * teeth
    x += bandpass(noise(dur, rng), linramp(dur, 340.0, 620.0), 3.0) * 0.6  # rust squeal
    return x


def m_water(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch2 雨锻水锤：水涌 + 飞沫。"""
    x = lowpass(noise(dur, rng), linramp(dur, 650.0, 280.0), 0.6) * 1.2
    x += sparse_env(dur, rng, 18.0, 0.008) * bandpass(noise(dur, rng), 2400.0, 1.4) * 1.4
    return x


def m_crystal(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch3 盐像结晶：高频晶片 + 盐尘。"""
    x = silence(dur)
    for _ in range(max(3, int(dur * 9))):
        f = 3800.0 + 4600.0 * rng.random()
        place(x, sine(f, 0.06, 0.55) * expdecay(0.06, 0.014), (dur - 0.08) * rng.random())
    x += highpass(noise(dur, rng), 5600.0) * 0.4
    return x


def m_vine(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch4 温室藤蔓：木质吱嘎 + 纤维崩弹。"""
    creak = bandpass(noise(dur, rng), linramp(dur, 300.0, 560.0), 3.0)
    creak *= 1.0 + 0.7 * np.sin(2 * math.pi * 24.0 * t_axis(dur))
    x = creak
    for _ in range(max(2, int(dur * 4))):
        place(x, pluck(G3 * (1.0 + rng.random()), 0.2, 0.06, 0.6, rng=rng), (dur - 0.22) * rng.random())
    return x


def m_order(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch5 黑曜军令：黑铜鼓点 + 命令字符干裂点击。"""
    x = sine(D2, dur, 0.8) * linramp(dur, 0.6, 1.0)
    n_ticks = max(2, int(dur * 6))
    for k in range(n_ticks):
        place(x, highpass(noise(0.012, rng), 3000.0) * expdecay(0.012, 0.004), dur * k / n_ticks, 0.8)
    x += lowpass(noise(dur, rng), 180.0, 0.6) * 0.7
    return x


def m_crown(dur: float, rng: np.random.Generator) -> np.ndarray:
    """ch6 王冠寂静：捂住的钟腔气压——素材本身已被低通(§4.4 P1 无声之战)。"""
    x = lowpass(noise(dur, rng), 420.0, 0.7)
    x += sine(D3, dur, 0.5) * (1.0 + 0.3 * np.sin(2 * math.pi * 2.0 * t_axis(dur)))
    return x


BOSS_MATS = {1: m_gear, 2: m_water, 3: m_crystal, 4: m_vine, 5: m_order, 6: m_crown}
BOSS_F0 = {1: 66.0, 2: 80.0, 3: 92.0, 4: 56.0, 5: 72.0, 6: 60.0}


def _muffle(ch: int, x: np.ndarray) -> np.ndarray:
    if ch != 6:
        return x
    y = lowpass(x, 500.0)  # 终 Boss P1：全部被"捂住"
    cut = int(len(y) * 0.82)
    y[cut:] *= np.linspace(1.0, 0.0, len(y) - cut) ** 2  # ...and cut early
    return y


def boss_roar(ch: int) -> np.ndarray:
    rng = rng_for(f"boss{ch}_roar")
    dur = 1.7
    x = growl(dur, BOSS_F0[ch], rng)
    x += BOSS_MATS[ch](dur, rng) * 0.55
    return _muffle(ch, x)


def boss_phase(ch: int) -> np.ndarray:
    rng = rng_for(f"boss{ch}_phase")
    x = silence(1.9)
    riser = bandpass(noise(1.0, rng), linramp(1.0, 260.0, 2100.0), 1.4)
    place(x, riser * np.linspace(0.15, 1.0, n_of(1.0)) ** 1.5, 0.0, 1.0)
    place(x, sine(linramp(1.0, BOSS_F0[ch], BOSS_F0[ch] * 2.4), 1.0, 0.5), 0.0)
    burst = BOSS_MATS[ch](0.8, rng) * expdecay(0.8, 0.3)
    place(x, burst, 1.0, 1.2)
    place(x, np.tanh(sine(linramp(0.4, 90.0, 40.0), 0.4, 1.4)) * expdecay(0.4, 0.14), 1.0)
    return _muffle(ch, x)


def boss_atk_light(ch: int) -> np.ndarray:
    rng = rng_for(f"boss{ch}_atk_light")
    x = silence(0.5)
    place(x, whoosh(0.3, rng, 500.0, 1900.0, 1.2), 0.0, 1.0)
    place(x, BOSS_MATS[ch](0.28, rng) * expdecay(0.28, 0.09), 0.08, 0.5)
    if ch == 3:  # review 3d: salt crystal shards were piercing at full level
        x = hishelf(x)
    return _muffle(ch, x)


def boss_atk_heavy(ch: int) -> np.ndarray:
    rng = rng_for(f"boss{ch}_atk_heavy")
    x = silence(1.0)
    place(x, whoosh(0.32, rng, 350.0, 900.0, 1.0), 0.0, 0.8)  # slow heavy windup arc
    place(x, np.tanh(sine(linramp(0.22, 110.0, 44.0), 0.22, 1.8)) * expdecay(0.22, 0.08), 0.3)
    place(x, lowpass(noise(0.16, rng), 360.0) * expdecay(0.16, 0.05), 0.3, 1.0)
    place(x, BOSS_MATS[ch](0.55, rng) * expdecay(0.55, 0.16), 0.32, 0.8)
    return _muffle(ch, x)


# ------------------------------------------------------------- D. UI jingle

def ui_ability_unlock() -> np.ndarray:
    """8 能力获得 jingle：D-A-B 上行三音 + 线族光尾。"""
    rng = rng_for("ui_unlock")
    x = silence(2.8)
    for i, (f, g) in enumerate(((D5, 0.95), (A5, 0.85), (B5, 0.9))):
        place(x, bell(f, 1.2 - 0.1 * i, bright=1.15, damp=1.0, strike=0.35, rng=rng), 0.3 * i, g)
    shimmer = highpass(noise(1.2, rng), 4800.0) * np.sin(np.linspace(0, math.pi, n_of(1.2))) ** 2
    place(x, shimmer, 0.8, 0.16)  # thread-light tail
    place(x, sine(D6, 1.0, 0.2) * expdecay(1.0, 0.4), 0.95)
    return x


def ui_pickup_key_item() -> np.ndarray:
    """关键拾取：动机三音变体 D-A-B♭（钟族短句 §4.5）。"""
    rng = rng_for("ui_key_item")
    x = silence(1.6)
    for i, f in enumerate((D5, A4, BB4)):
        place(x, bell(f, 0.7 - 0.06 * i, bright=1.1, damp=1.6, strike=0.3, rng=rng), 0.22 * i, 0.9)
    place(x, sine(D6, 0.5, 0.16) * expdecay(0.5, 0.2), 0.66)
    return x


def ui_testimony_complete() -> np.ndarray:
    """六证词集齐：六件区域乐器各奏一音连成动机 + 解决预示。"""
    rng = rng_for("ui_testimony")
    x = silence(3.0)
    place(x, lowpass(bell(D5, 0.5, damp=1.4, strike=0.25, rng=rng), 3200.0), 0.0, 0.85)   # ch1 moss bell
    place(x, bell(A4, 0.5, bright=1.4, damp=1.8, strike=0.35, rng=rng), 0.3, 0.8)          # ch2 copper
    place(x, highpass(bell(D6, 0.45, damp=2.2, strike=0.25, rng=rng), 800.0), 0.6, 0.7)    # ch3 salt glass
    place(x, pluck(B4, 0.55, 0.16, 0.85, rng=rng), 0.9)                                     # ch4 fiber string
    place(x, lowpass(bell(A3, 0.6, bright=0.7, damp=1.2, strike=0.2, rng=rng), 1200.0), 1.2, 0.85)  # ch5 horn-bell
    place(x, sine(BB4, 0.7, 0.55) * expdecay(0.7, 0.3), 1.5)                                # ch6 pure far sine
    for f, g in ((D4, 0.6), (FS4, 0.4), (A4, 0.5), (D5, 0.45)):  # resolution foreshadowed
        place(x, bell(f, 1.0, bright=0.9, damp=0.9, strike=0.12, rng=rng), 2.0, g)
    return x


# ------------------------------------------------------------ E. footsteps

def foot_glass(idx: int) -> np.ndarray:
    """玻璃/釉面脚步：硬质高频哒音 + 微弱杯缘泛音（§4.2 player_step_glass）。"""
    rng = rng_for(f"foot_glass_{idx}")
    dur = 0.16 + 0.03 * rng.random()
    x = silence(dur)
    place(x, highpass(noise(0.012, rng), 2800.0) * expdecay(0.012, 0.004), 0.0, 1.2)
    place(x, sine(linramp(0.03, 900.0, 620.0), 0.03, 0.7) * expdecay(0.03, 0.01), 0.0)
    for f, g in ((3150.0 * (1.0 + 0.08 * rng.random()), 0.30),
                 (5240.0 * (1.0 + 0.06 * rng.random()), 0.18)):
        place(x, sine(f, 0.07, g) * expdecay(0.07, 0.018), 0.002)  # rim overtones
    return x


def foot_wet(idx: int) -> np.ndarray:
    """积水浅滩脚步：踏水噗嗤 + 滴落（§4.2 player_step_wet）。"""
    rng = rng_for(f"foot_wet_{idx}")
    dur = 0.26 + 0.06 * rng.random()
    x = silence(dur)
    place(x, lowpass(noise(0.06, rng), 750.0) * expdecay(0.06, 0.02), 0.0, 1.2)  # splat
    place(x, sine(linramp(0.05, 240.0, 120.0), 0.05, 0.8) * expdecay(0.05, 0.02), 0.0)
    squish = bandpass(noise(0.1, rng), linramp(0.1, 1500.0, 800.0), 1.2) * expdecay(0.1, 0.035)
    place(x, squish, 0.015, 0.8)
    place(x, chirp(2100.0 + 500.0 * rng.random(), 900.0, 0.035, 0.012, 0.4), 0.09 + 0.06 * rng.random())
    return x


# --------------------------------------------------------------------- pack

AMB_ONESHOT_DESCS = {
    "amb_ch01_os_1": "苔间滴水", "amb_ch01_os_2": "远处齿轮咬合", "amb_ch01_os_3": "铜蛾翅颤掠过",
    "amb_ch01_os_4": "青铜构件热胀吱呀", "amb_ch01_os_5": "孢子囊轻爆", "amb_ch01_os_6": "苔藓蠕动蜂窝音",
    "amb_ch01_os_7": "风穿钟口的哨音", "amb_ch01_os_8": "远方一记哑钟",
    "amb_ch02_os_1": "雨点打铁皮", "amb_ch02_os_2": "水轮转动", "amb_ch02_os_3": "管道滴漏",
    "amb_ch02_os_4": "蒸汽泄压", "amb_ch02_os_5": "锁链晃动", "amb_ch02_os_6": "远雷",
    "amb_ch02_os_7": "水下闷涌（泵井）", "amb_ch02_os_8": "雨槽溢流冲刷",
    "amb_ch03_os_1": "远处翻页", "amb_ch03_os_2": "笔尖誊写", "amb_ch03_os_3": "盐晶脆裂",
    "amb_ch03_os_4": "书架承重呻吟", "amb_ch03_os_5": "迟影掠过的反相 whoosh", "amb_ch03_os_6": "封蜡滴落",
    "amb_ch03_os_7": "索引卡片弹跳", "amb_ch03_os_8": "极远女声读词（听不清）",
    "amb_ch04_os_1": "玻璃风铃", "amb_ch04_os_2": "藤蔓伸长吱嘎", "amb_ch04_os_3": "花粉风袭",
    "amb_ch04_os_4": "蜂群远近", "amb_ch04_os_5": "玻璃裂纹蔓延", "amb_ch04_os_6": "断弦远响",
    "amb_ch04_os_7": "果实落地", "amb_ch04_os_8": "藤蔓爆珠",
    "amb_ch05_os_1": "旗帜猎猎", "amb_ch05_os_2": "旗杆震动", "amb_ch05_os_3": "远处行军鼓",
    "amb_ch05_os_4": "灰烬簌落", "amb_ch05_os_5": "灯芯吸气", "amb_ch05_os_6": "黑曜石冷缩脆响",
    "amb_ch05_os_7": "盔甲队列远过", "amb_ch05_os_8": "山体低鸣",
    "amb_ch06_os_1": "羽状白尘飘落", "amb_ch06_os_2": "金属谐振被激发又止", "amb_ch06_os_3": "远童声半句",
    "amb_ch06_os_4": "心跳（自己的）", "amb_ch06_os_5": "真空吸引门风", "amb_ch06_os_6": "王冠丝线微颤",
    "amb_ch06_os_7": "静默压强耳塞感起伏", "amb_ch06_os_8": "一次远得不可能的回声钟",
}

BED_DESCS = {
    "amb_ch01_bed": "地底庭院低风+极远钟腔共鸣+苔间滴水",
    "amb_ch02_bed": "双层雨（近颗粒/远墙混合）+远雷；室内切远层时可整体低通",
    "amb_ch03_bed": "纸页静电+盐晶生长微裂+静止馆藏空气",
    "amb_ch04_bed": "玻璃暖房闷风+叶面摩挲+湿气虫鸣",
    "amb_ch05_bed": "高原夜风+火把群噼啪+远处行军鼓",
    "amb_ch06_bed": "有组织的静默：气压hiss+极微耳鸣单音+真空低鸣",
}

BEAT_DESCS = {
    "ch02_rain_foundry_canal_beat_01_audio": "wall_grip 低频吸附声加轻微水滴尾音",
    "ch02_rain_foundry_canal_beat_02_audio": "echo_hook 钩环金属声后接一拍水声回响",
    "ch02_rain_foundry_canal_beat_03_audio": "boss_water_hammer 重击水浪叠加层",
    "ch03_saltwhite_archive_beat_01_audio": "delayed_shadow 玻璃摩擦声和低音翻页声",
    "ch03_saltwhite_archive_beat_02_audio": "bell_guard 短促钟壳响和能量回流声",
    "ch03_saltwhite_archive_beat_03_audio": "contract_break 纸页撕裂声与低频钟声",
    "ch04_broken_string_greenhouse_beat_01_audio": "thorn_downstrike 短促木裂声下劈叠加层",
    "ch04_broken_string_greenhouse_beat_02_audio": "pollen_wind 轻风声和蜂蜡颤音",
    "ch04_broken_string_greenhouse_beat_03_audio": "string_bridge_break 断弦拨片声和石屑落地",
    "ch05_obsidian_pilgrim_road_beat_01_audio": "lantern_phase 低频灯芯吸入声和短促相位噪音",
    "ch05_obsidian_pilgrim_road_beat_02_audio": "silent_order 无声前摇后接低频压缩声",
    "ch05_obsidian_pilgrim_road_beat_03_audio": "parade_charge 低频步伐循环和旗杆震动（loop）",
    "ch06_silent_crown_core_beat_01_audio": "echo_room_open 低频钟声与章节主题音色短句",
    "ch06_silent_crown_core_beat_02_audio": "crown_resonance 低频脉冲、线弦拨动声和短暂停顿",
    "ch06_silent_crown_core_beat_03_audio": "ending_doors 重鸣钟声/断冠断弦/真结局绯线和声",
}


def build_pack():
    """Return list of (key, out_path, kind, loop, peak, builder)."""
    pack = []
    beds = {1: bed_ch01, 2: bed_ch02, 3: bed_ch03, 4: bed_ch04, 5: bed_ch05, 6: bed_ch06}
    for ch, fn in beds.items():
        key = f"amb_ch{ch:02d}_bed"
        pack.append((key, AMB_DIR / f"{key}.ogg", "ambience_bed", True, 0.3, fn))
    pack.append(("amb_ch02_anvil_far", AMB_DIR / "amb_ch02_anvil_far.ogg",
                 "ambience_oneshot", False, 0.4, a_ch02_anvil))
    os_builders = {
        1: (a_ch01_1, a_ch01_2, a_ch01_3, a_ch01_4, a_ch01_5, a_ch01_6, a_ch01_7, a_ch01_8),
        2: (a_ch02_1, a_ch02_2, a_ch02_3, a_ch02_4, a_ch02_5, a_ch02_6, a_ch02_7, a_ch02_8),
        3: (a_ch03_1, a_ch03_2, a_ch03_3, a_ch03_4, a_ch03_5, a_ch03_6, a_ch03_7, a_ch03_8),
        4: (a_ch04_1, a_ch04_2, a_ch04_3, a_ch04_4, a_ch04_5, a_ch04_6, a_ch04_7, a_ch04_8),
        5: (a_ch05_1, a_ch05_2, a_ch05_3, a_ch05_4, a_ch05_5, a_ch05_6, a_ch05_7, a_ch05_8),
        6: (a_ch06_1, a_ch06_2, a_ch06_3, a_ch06_4, a_ch06_5, a_ch06_6, a_ch06_7, a_ch06_8),
    }
    for ch, fns in os_builders.items():
        for i, fn in enumerate(fns, start=1):
            key = f"amb_ch{ch:02d}_os_{i}"
            pack.append((key, AMB_DIR / f"{key}.ogg", "ambience_oneshot", False, 0.4, fn))

    beat_builders = [
        ("ch02_rain_foundry_canal_beat_01_audio", beat_ch02_01, False),
        ("ch02_rain_foundry_canal_beat_02_audio", beat_ch02_02, False),
        ("ch02_rain_foundry_canal_beat_03_audio", beat_ch02_03, False),
        ("ch03_saltwhite_archive_beat_01_audio", beat_ch03_01, False),
        ("ch03_saltwhite_archive_beat_02_audio", beat_ch03_02, False),
        ("ch03_saltwhite_archive_beat_03_audio", beat_ch03_03, False),
        ("ch04_broken_string_greenhouse_beat_01_audio", beat_ch04_01, False),
        ("ch04_broken_string_greenhouse_beat_02_audio", beat_ch04_02, False),
        ("ch04_broken_string_greenhouse_beat_03_audio", beat_ch04_03, False),
        ("ch05_obsidian_pilgrim_road_beat_01_audio", beat_ch05_01, False),
        ("ch05_obsidian_pilgrim_road_beat_02_audio", beat_ch05_02, False),
        ("ch05_obsidian_pilgrim_road_beat_03_audio", beat_ch05_03, True),
        ("ch06_silent_crown_core_beat_01_audio", beat_ch06_01, False),
        ("ch06_silent_crown_core_beat_02_audio", beat_ch06_02, False),
        ("ch06_silent_crown_core_beat_03_audio", beat_ch06_03, False),
    ]
    for key, fn, is_loop in beat_builders:
        pack.append((key, SFX_DIR / f"{key}.ogg", "chapter_beat", is_loop, 0.7 if not is_loop else 0.6, fn))

    for i in (1, 2, 3):
        pack.append((f"player_attack_{i:02d}", SFX_DIR / f"player_attack_{i:02d}.ogg",
                     "combat_sfx", False, 0.7, (lambda k=i: c_attack(k))))
    pack.append(("player_land_soft", SFX_DIR / "player_land_soft.ogg", "combat_sfx", False, 0.66, c_land_soft))
    pack.append(("player_land_hard", SFX_DIR / "player_land_hard.ogg", "combat_sfx", False, 0.7, c_land_hard))
    pack.append(("enemy_hit_soft", SFX_DIR / "enemy_hit_soft.ogg", "combat_sfx", False, 0.7, c_hit_soft))
    pack.append(("enemy_hit_shell", SFX_DIR / "enemy_hit_shell.ogg", "combat_sfx", False, 0.7, c_hit_shell))
    pack.append(("enemy_hit_armor", SFX_DIR / "enemy_hit_armor.ogg", "combat_sfx", False, 0.7, c_hit_armor))

    for ch in range(1, 7):
        peak = 0.5 if ch == 6 else 0.7  # 终 Boss P1 整体更"被捂住"
        pack.append((f"boss_ch{ch:02d}_roar", SFX_DIR / f"boss_ch{ch:02d}_roar.ogg",
                     "boss_sfx", False, peak, (lambda c=ch: boss_roar(c))))
        pack.append((f"boss_ch{ch:02d}_phase_shift", SFX_DIR / f"boss_ch{ch:02d}_phase_shift.ogg",
                     "boss_sfx", False, peak, (lambda c=ch: boss_phase(c))))
        pack.append((f"boss_ch{ch:02d}_atk_light", SFX_DIR / f"boss_ch{ch:02d}_atk_light.ogg",
                     "boss_sfx", False, peak, (lambda c=ch: boss_atk_light(c))))
        pack.append((f"boss_ch{ch:02d}_atk_heavy", SFX_DIR / f"boss_ch{ch:02d}_atk_heavy.ogg",
                     "boss_sfx", False, peak, (lambda c=ch: boss_atk_heavy(c))))

    pack.append(("ui_ability_unlock", SFX_DIR / "ui_ability_unlock.ogg", "ui_jingle", False, 0.68, ui_ability_unlock))
    pack.append(("ui_pickup_key_item", SFX_DIR / "ui_pickup_key_item.ogg", "ui_jingle", False, 0.68, ui_pickup_key_item))
    pack.append(("ui_testimony_complete", SFX_DIR / "ui_testimony_complete.ogg", "ui_jingle", False, 0.66, ui_testimony_complete))

    for surface, fn in (("glass", foot_glass), ("wet", foot_wet)):
        for i in range(5):
            key = f"footstep_{surface}_{i:03d}"
            pack.append((key, FOOT_DIR / f"{key}.ogg", "footstep", False, 0.7, (lambda k=i, f=fn: f(k))))
    return pack


def write_wav(path: Path, samples: np.ndarray) -> int:
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm.tobytes())
    return path.stat().st_size


def to_ogg(wav_path: Path, ogg_path: Path) -> int:
    subprocess.run(
        [FFMPEG, "-y", "-loglevel", "error", "-i", str(wav_path),
         "-ar", str(SR), "-ac", "1", "-q:a", "4",
         # bitexact muxing: fixed ogg serial + no encoder tag -> idempotent rerun
         "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg_path)],
        check=True,
    )
    return ogg_path.stat().st_size


def decode_ogg(path: Path) -> np.ndarray:
    p = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le",
         "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).astype(float)


def write_ogg_verified(path: Path, x: np.ndarray, peak: float,
                       rms_db: float | None) -> int:
    """Encode, then compensate Vorbis level drift: -q:a 4 shaves the peak off
    very short transients (and a little active RMS off sparse textures), so
    re-measure the decoded file and nudge the master gain until it meets its
    target again."""
    tmp = path.with_suffix(".tmp.wav")
    write_wav(tmp, x)
    size = to_ogg(tmp, path)
    tmp.unlink()
    for _ in range(3):
        y = decode_ogg(path)
        if rms_db is not None:
            err = rms_db - active_rms_db(y)
        else:
            err = 20.0 * math.log10(peak) - 20.0 * math.log10(
                max(float(np.max(np.abs(y))), 1e-9))
        if abs(err) <= 0.35:
            break
        x = np.clip(x * 10.0 ** (err / 20.0), -1.0, 1.0)
        write_wav(tmp, x)
        size = to_ogg(tmp, path)
        tmp.unlink()
    return size


# class-wide active-RMS targets (review fix 4) and per-key exceptions (3f/3g)
RMS_TARGET_BY_KIND = {"ambience_bed": -28.0, "ambience_oneshot": -25.0}
RMS_CEILING_BY_KIND = {"ambience_bed": 0.5, "ambience_oneshot": 0.7}
RMS_TARGET_BY_KEY = {
    "ch06_silent_crown_core_beat_01_audio": -19.0,  # was -13.3: too loud
    "boss_ch05_atk_heavy": -20.0,                   # was ~-24: too quiet
}


def main() -> None:
    for d in (AMB_DIR, SFX_DIR, FOOT_DIR, INVENTORY.parent):
        d.mkdir(parents=True, exist_ok=True)
    inventory = []
    total_bytes = 0
    for key, out_path, kind, is_loop, peak, builder in build_pack():
        x = np.asarray(builder(), dtype=float)
        if not is_loop:
            x = edge_fade(x, 0.003 if kind == "footstep" else 0.005)
        x = normalize(x, peak)
        rms_db = RMS_TARGET_BY_KEY.get(key, RMS_TARGET_BY_KIND.get(kind))
        if rms_db is not None:
            x = rms_target(x, rms_db, ceiling=RMS_CEILING_BY_KIND.get(kind, peak))
        dur = len(x) / SR
        if kind == "ambience_bed":
            assert 30.0 <= dur <= 45.0, f"{key} bed length {dur:.1f}s out of 30-45s"
        elif kind == "ambience_oneshot":
            assert 0.4 <= dur <= 3.2, f"{key} one-shot length {dur:.2f}s out of range"
        elif kind == "footstep":
            assert 0.08 <= dur <= 0.8, f"{key} footstep length {dur:.2f}s out of range"
        else:
            assert is_loop or dur <= 3.2, f"{key} exceeds 3.2 s ({dur:.2f}s)"
        if out_path.suffix == ".ogg":
            size = write_ogg_verified(out_path, x, peak, rms_db)
        else:
            size = write_wav(out_path, x)
        total_bytes += size
        desc = (BED_DESCS.get(key) or AMB_ONESHOT_DESCS.get(key)
                or BEAT_DESCS.get(key) or "")
        res_path = "res://" + out_path.relative_to(ROOT / "godot").as_posix()
        inventory.append({
            "key": key,
            "file": out_path.name,
            "res_path": res_path,
            "kind": kind,
            "loop": is_loop,
            "seconds": round(dur, 3),
            "peak": round(float(np.max(np.abs(x))), 3),
            "active_rms_db": round(active_rms_db(x), 1),
            "bytes": size,
            "description": desc,
        })
        print(f"{key:<44} {kind:<17} {dur:>6.2f}s loop={str(is_loop):<5} "
              f"aRMS {active_rms_db(x):>6.1f} {size:>8} B")

    doc = {
        "title": "绯线巡礼 ambience + combat completion pack",
        "generator": "tools/generate_ambience_pack.py",
        "spec": "docs/spec/20260726160400000_音效与音乐设计规格.md sections 4.2/4.3/4.4/4.6",
        "manifest": "godot/data/audio_visual_manifest.json (v2 future_free_candidate coverage)",
        "license": "CC0 (project-generated)",
        "sample_rate": SR,
        "channels": 1,
        "ogg_quality": "ffmpeg -q:a 4",
        "deterministic": True,
        "counts": {
            "total": len(inventory),
            "ambience_bed": sum(1 for r in inventory if r["kind"] == "ambience_bed"),
            "ambience_oneshot": sum(1 for r in inventory if r["kind"] == "ambience_oneshot"),
            "chapter_beat": sum(1 for r in inventory if r["kind"] == "chapter_beat"),
            "combat_sfx": sum(1 for r in inventory if r["kind"] == "combat_sfx"),
            "boss_sfx": sum(1 for r in inventory if r["kind"] == "boss_sfx"),
            "ui_jingle": sum(1 for r in inventory if r["kind"] == "ui_jingle"),
            "footstep": sum(1 for r in inventory if r["kind"] == "footstep"),
        },
        "total_bytes": total_bytes,
        "files": inventory,
    }
    INVENTORY.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n{len(inventory)} files, {total_bytes / 1024:.1f} KiB total")
    print(f"inventory -> {INVENTORY}")


if __name__ == "__main__":
    main()

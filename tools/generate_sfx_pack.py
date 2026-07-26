"""Generate the project-owned SFX pack for 绯线巡礼 (Crimson Thread Pilgrimage).

Synthesizes every sfx_catalog event that was marked future_free_candidate in
godot/data/audio_visual_manifest.json v2, plus the placeholder rewires
(pogo bell, attack-hit trio, shrine rest six-region variants), following the
sound-family recipes in docs/spec/20260726160400000_音效与音乐设计规格.md §4:

* bell family  - decayed sine/FM partial stacks on the D pitch system
                 (pogo = D5 587.33 Hz small bronze bell, guard block = muted
                 bell, perfect guard = pure A4/A5 fifth overtone strike,
                 shrine rest = same lullaby motif D-A-B with six regional
                 timbre filters)
* thread family - filtered noise + fast envelopes (wall attach = wet suction,
                 slide loop = seamless friction loop, hook latch = E5 ring +
                 reel swish)
* tide/material - shaped noise for the six enemy death materials
                 (moss spore pop / copper gear shatter / salt crystal /
                 fiber tear / obsidian wick-out hiss / silent near-nothing)

Also synthesizes the 11 core gameplay sounds that live directly under
godot/assets/audio/sfx/ (player_jump/player_dash/player_heal/player_hurt/
player_hook/player_attack/enemy_hit/heavy_hit/pickup/interact/lever), same
thread-family vocabulary, overwriting the old silent placeholders in place.

Output: OGG Vorbis (ffmpeg -q:a 4) 44.1 kHz mono under
godot/assets/audio/sfx/generated/ (and the 11 core files at the sfx root),
peak-normalized to 0.7 (unless noted), 5 ms edge fades on one-shots and
zero-crossing crossfaded seams on loops.  Entries may carry an active-RMS
target (50 ms frames gated at -40 dBFS) that is applied after peak
normalization with a soft tanh limiter against the peak ceiling.
Deterministic (per-file seeded RNG) and idempotent - rerunning rewrites
identical content.

Also renders output/audio_preview/sfx_sampler.wav: a short audition reel of
eight representative sounds for human ears.

License of all output: project-generated (CC0).
"""
from __future__ import annotations

import math
import subprocess
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[1]
SFX_ROOT = ROOT / "godot" / "assets" / "audio" / "sfx"
OUT_DIR = SFX_ROOT / "generated"
PREVIEW = ROOT / "output" / "audio_preview" / "sfx_sampler.wav"
FFMPEG = "C:/Users/Administrator/Desktop/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe"

D3, D4, D5, D6 = 146.83, 293.66, 587.33, 1174.66
A3, A4, A5 = 220.0, 440.0, 880.0
B3, B4, B5 = 246.94, 493.88, 987.77
BB4, BB5 = 466.16, 932.33
E5 = 659.26
FS4 = 369.99


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


# ------------------------------------------------------------------ recipes


def rng_for(name: str) -> np.random.Generator:
    # zlib.crc32 is stable across processes (str hash() is salted per run).
    return np.random.default_rng(zlib.crc32(("crimson_sfx:" + name).encode("utf-8")))


def r_pogo_bounce() -> np.ndarray:
    rng = rng_for("pogo")
    x = bell(D5, 0.62, bright=1.15, damp=1.2, strike=0.7, rng=rng)
    # springy thread rebound: fast up-chirp, very quiet
    x[: n_of(0.07)] += sine(linramp(0.07, 320.0, 940.0), 0.07, 0.16) * expdecay(0.07, 0.03)
    return x


def r_hit_light() -> np.ndarray:
    rng = rng_for("hit_light")
    x = silence(0.16)
    place(x, bandpass(noise(0.07, rng), 2400.0, 1.1) * expdecay(0.07, 0.02), 0.0, 1.0)
    place(x, sine(185.0, 0.09, 0.8) * expdecay(0.09, 0.03), 0.0)
    return x


def r_hit_heavy() -> np.ndarray:
    rng = rng_for("hit_heavy")
    x = silence(0.30)
    place(x, bandpass(noise(0.10, rng), 1700.0, 0.9) * expdecay(0.10, 0.028), 0.0, 1.2)
    place(x, sine(95.0, 0.20, 1.0) * expdecay(0.20, 0.06), 0.0)
    place(x, sine(1480.0, 0.16, 0.28) * expdecay(0.16, 0.05), 0.004)
    return x


def r_hit_kill() -> np.ndarray:
    rng = rng_for("hit_kill")
    x = silence(0.5)
    place(x, r_hit_heavy(), 0.0, 0.9)
    place(x, sine(58.0, 0.22, 1.0) * expdecay(0.22, 0.07), 0.0, 0.8)
    place(x, bell(A5, 0.36, bright=1.3, damp=1.6, strike=0.4, rng=rng), 0.012, 0.5)
    return x


def r_hook_latch() -> np.ndarray:
    rng = rng_for("hook_latch")
    x = silence(0.6)
    place(x, bell(E5, 0.42, bright=1.2, damp=1.5, strike=0.6, rng=rng), 0.0)
    tension = sine(linramp(0.16, 220.0, 640.0), 0.16, 0.3) * expdecay(0.16, 0.07)
    place(x, tension, 0.02)
    place(x, bandpass(noise(0.12, rng), linramp(0.12, 900.0, 2600.0), 1.4) * expdecay(0.12, 0.05), 0.03, 0.5)
    return x


def r_hook_reel() -> np.ndarray:
    rng = rng_for("hook_reel")
    dur = 0.48
    body = bandpass(noise(dur, rng), linramp(dur, 420.0, 2600.0), 1.8)
    clicks = 1.0 + 0.45 * np.sign(np.sin(2 * math.pi * 26.0 * t_axis(dur)))
    return body * clicks * (linramp(dur, 0.5, 1.0) * expdecay(dur, 0.4))


def r_double_jump_wings() -> np.ndarray:
    rng = rng_for("double_jump")
    x = silence(0.5)
    place(x, pluck(D5, 0.3, 0.08, rng=rng), 0.0)
    place(x, pluck(A5, 0.34, 0.09, rng=rng), 0.06)
    place(x, highpass(noise(0.2, rng), 3200.0) * expdecay(0.2, 0.06), 0.0, 0.25)
    return x


def r_wall_grip_attach() -> np.ndarray:
    rng = rng_for("wall_grip")
    x = silence(0.42)
    body = sine(linramp(0.14, 210.0, 68.0), 0.14, 1.0) * expdecay(0.14, 0.06)
    place(x, body, 0.0)
    place(x, lowpass(noise(0.12, rng), 420.0) * expdecay(0.12, 0.04), 0.0, 0.8)
    drop = sine(linramp(0.05, 1250.0, 620.0), 0.05, 0.2) * expdecay(0.05, 0.02)
    place(x, drop, 0.26)
    return x


def r_wall_slide_loop() -> np.ndarray:
    rng = rng_for("wall_slide")
    dur = 1.35
    body = bandpass(noise(dur, rng), 1050.0, 0.9)
    wobble = 1.0 + 0.55 * lowpass(noise(dur, rng), 9.0, 0.6) / 0.12
    wobble = np.clip(wobble, 0.25, 1.9)
    grain = 1.0 + 0.2 * np.sin(2 * math.pi * 63.0 * t_axis(dur))
    return make_loop(body * wobble * grain, 0.18)


def r_guard_block() -> np.ndarray:
    rng = rng_for("guard_block")
    x = bell(D4, 0.42, bright=0.6, damp=3.2, strike=0.8, rng=rng)
    x = lowpass(x, 1500.0)
    x[: n_of(0.012)] += bandpass(noise(0.012, rng), 3200.0, 1.0) * 0.5
    return x


def r_guard_perfect() -> np.ndarray:
    rng = rng_for("guard_perfect")
    x = silence(1.1)
    place(x, bell(A4, 1.0, bright=1.25, damp=0.9, strike=0.5, rng=rng), 0.0)
    place(x, sine(A5, 0.9, 0.4) * expdecay(0.9, 0.3), 0.0)
    backflow = sine(A5 * 2.0, 0.4, 0.14) * np.linspace(0.0, 1.0, n_of(0.4)) ** 2
    place(x, backflow[::-1], 0.05)
    return x


def r_downstrike_crack() -> np.ndarray:
    rng = rng_for("down_crack")
    x = silence(0.34)
    place(x, highpass(noise(0.05, rng), 1400.0) * expdecay(0.05, 0.015), 0.0, 1.2)
    for at in (0.012, 0.03, 0.055):
        place(x, bandpass(noise(0.02, rng), 2600.0 + 900 * rng.random(), 1.5), at, 0.7)
    place(x, sine(250.0, 0.12, 0.8) * expdecay(0.12, 0.035), 0.0)
    return x


def r_downstrike_break() -> np.ndarray:
    rng = rng_for("down_break")
    x = silence(0.72)
    place(x, r_downstrike_crack(), 0.0, 1.0)
    place(x, lowpass(noise(0.5, rng), 160.0) * expdecay(0.5, 0.14), 0.02, 1.4)
    for k in range(7):
        at = 0.1 + 0.42 * rng.random()
        place(x, bandpass(noise(0.03, rng), 1200.0 + 2400.0 * rng.random(), 2.0) * expdecay(0.03, 0.01), at, 0.4)
    return x


def r_bind_channel() -> np.ndarray:
    rng = rng_for("bind_channel")
    dur = 1.6
    wheel = bandpass(noise(dur, rng), 760.0, 1.2)
    spokes = 1.0 + 0.5 * np.sin(2 * math.pi * 6.2 * t_axis(dur))
    hum = sine(220.0, dur, 0.28) * (1.0 + 0.12 * np.sin(2 * math.pi * 3.1 * t_axis(dur)))
    return make_loop(wheel * spokes * 0.8 + hum, 0.2)


def r_bind_tighten() -> np.ndarray:
    rng = rng_for("bind_tighten")
    x = silence(0.55)
    for i, f in enumerate((420.0, 560.0, 760.0)):
        place(x, pluck(f, 0.22, 0.07, rng=rng), 0.09 * i)
    creak = bandpass(noise(0.3, rng), linramp(0.3, 300.0, 900.0), 2.4)
    creak *= 1.0 + 0.6 * np.sin(2 * math.pi * 34.0 * t_axis(0.3))
    place(x, creak * expdecay(0.3, 0.2), 0.1, 0.35)
    return x


def r_bind_interrupt() -> np.ndarray:
    rng = rng_for("bind_interrupt")
    x = silence(0.3)
    place(x, highpass(noise(0.012, rng), 2400.0), 0.0, 1.1)
    place(x, sine(linramp(0.08, 820.0, 190.0), 0.08, 0.9) * expdecay(0.08, 0.03), 0.004)
    place(x, sine(120.0, 0.12, 0.5) * expdecay(0.12, 0.04), 0.02)
    return x


def r_death_cocoon() -> np.ndarray:
    rng = rng_for("death_cocoon")
    x = silence(1.8)
    for i, f in enumerate((D5, A4, 349.23, D4)):
        place(x, pluck(f, 0.5, 0.16, 0.7 - 0.1 * i, rng=rng), 0.16 * i)
    exhale = lowpass(noise(1.3, rng), 900.0, 0.6)
    env = np.sin(np.linspace(0.0, math.pi, n_of(1.3))) ** 1.5
    place(x, exhale * env, 0.4, 0.55)
    return x


def r_respawn_weave() -> np.ndarray:
    rng = rng_for("respawn")
    x = silence(1.5)
    for i, f in enumerate((D5, A5, BB5)):
        place(x, bell(f, 0.8, bright=1.1, damp=1.4, strike=0.35, rng=rng), 0.2 * i, 0.8)
    inhale = highpass(noise(0.5, rng), 1600.0) * np.linspace(0.0, 1.0, n_of(0.5)) ** 2
    place(x, inhale, 0.0, 0.2)
    return x


def r_low_hp_heartbeat() -> np.ndarray:
    rng = rng_for("heartbeat")
    dur = 60.0 / 57.0  # one cycle at 57 BPM
    x = silence(dur)
    lub = sine(56.0, 0.12, 1.0) * np.sin(np.linspace(0, math.pi, n_of(0.12))) ** 2
    dub = sine(44.0, 0.10, 0.72) * np.sin(np.linspace(0, math.pi, n_of(0.10))) ** 2
    place(x, lub, 0.0)
    place(x, dub, 0.19)
    place(x, lowpass(noise(0.1, rng), 220.0) * expdecay(0.1, 0.03), 0.0, 0.12)
    return x  # naturally seamless: silence at both ends


def r_death_moss() -> np.ndarray:
    rng = rng_for("death_moss")
    x = silence(0.45)
    place(x, lowpass(noise(0.16, rng), 640.0) * expdecay(0.16, 0.05), 0.0, 1.2)
    place(x, sine(linramp(0.14, 300.0, 88.0), 0.14, 0.8) * expdecay(0.14, 0.06), 0.01)
    for at in (0.14, 0.2, 0.27):
        f = 500.0 + 700.0 * rng.random()
        place(x, sine(linramp(0.04, f, f * 0.6), 0.04, 0.3) * expdecay(0.04, 0.015), at)
    return x


def r_death_copper() -> np.ndarray:
    rng = rng_for("death_copper")
    x = silence(0.5)
    for i, f in enumerate((1320.0, 2140.0, 3390.0)):
        place(x, sine(f, 0.2, 0.7 - 0.15 * i) * expdecay(0.2, 0.04), 0.004 * i)
    rattle = bandpass(noise(0.4, rng), 3100.0, 1.4)
    gate = (rng.random(n_of(0.4)) < 0.12).astype(float)
    place(x, rattle * lowpass(gate, 900.0, 0.6) * expdecay(0.4, 0.12), 0.03, 2.2)
    place(x, sine(160.0, 0.12, 0.5) * expdecay(0.12, 0.04), 0.0)
    return x


def r_death_salt() -> np.ndarray:
    rng = rng_for("death_salt")
    x = silence(0.48)
    for k in range(9):
        f = 3600.0 + 4800.0 * rng.random()
        at = 0.02 * k + 0.01 * rng.random()
        place(x, sine(f, 0.09, 0.5) * expdecay(0.09, 0.02), at)
    place(x, highpass(noise(0.3, rng), 5200.0) * expdecay(0.3, 0.08), 0.0, 0.8)
    place(x, sine(D6, 0.2, 0.3) * expdecay(0.2, 0.06), 0.02)
    return hishelf(x)  # crystal sparkle kept, harsh >8k shelved -6 dB


def r_death_fiber() -> np.ndarray:
    rng = rng_for("death_fiber")
    dur = 0.46
    tear = bandpass(noise(dur, rng), linramp(dur, 820.0, 2600.0), 1.2)
    rough = 1.0 + 0.7 * np.sign(np.sin(2 * math.pi * 82.0 * t_axis(dur)))
    x = tear * rough * expdecay(dur, 0.16)
    place(x, pluck(196.0, 0.2, 0.06, 0.7, rng=rng), 0.3)
    return x


def r_death_obsidian() -> np.ndarray:
    rng = rng_for("death_obsidian")
    x = silence(0.4)
    place(x, sine(118.0, 0.07, 1.0) * expdecay(0.07, 0.02), 0.0)
    place(x, bandpass(noise(0.04, rng), 2100.0, 1.1) * expdecay(0.04, 0.012), 0.0, 1.1)
    hiss = highpass(noise(0.3, rng), 3800.0) * expdecay(0.3, 0.07)
    place(x, hiss, 0.05, 0.6)  # wick-out breath, almost no tail
    return hishelf(x)  # keep the hiss but shelve the piercing >8k -6 dB


def r_death_silent() -> np.ndarray:
    rng = rng_for("death_silent")
    dur = 0.5
    air = lowpass(noise(dur, rng), 500.0, 0.6)
    env = np.sin(np.linspace(0.0, math.pi, n_of(dur))) ** 3
    x = air * env * 0.08  # hushed exhale body stays far below the peak
    # one soft "thread goes slack" tap gives the file a real (peak -6 dB) attack
    tap = sine(linramp(0.015, 280.0, 85.0), 0.015, 1.0) * expdecay(0.015, 0.002)
    place(x, tap, 0.015)
    return x


def r_elite_ritual_start() -> np.ndarray:
    rng = rng_for("elite_ritual")
    x = silence(1.5)
    tvib = t_axis(0.9)
    fr = 84.0 * (1.0 + 0.05 * np.sin(2 * math.pi * 5.0 * tvib))
    roar = sine(fr, 0.9) + sine(fr * 2.02, 0.9, 0.6) + sine(fr * 3.1, 0.9, 0.3)
    roar += bandpass(noise(0.9, rng), 300.0, 0.8) * 1.4
    place(x, roar * np.sin(np.linspace(0, math.pi, n_of(0.9))) ** 0.8, 0.0, 0.8)
    place(x, bell(D4, 1.0, bright=1.1, damp=1.0, strike=0.6, rng=rng), 0.32, 0.9)
    return x


def r_boss_windup_light() -> np.ndarray:
    rng = rng_for("boss_windup_light")
    dur = 0.5
    creak = bandpass(noise(dur, rng), linramp(dur, 320.0, 880.0), 2.6)
    creak *= 1.0 + 0.6 * np.sin(2 * math.pi * 21.0 * t_axis(dur))
    breath = highpass(noise(dur, rng), 2400.0) * np.linspace(0.0, 1.0, n_of(dur)) ** 2
    return creak * linramp(dur, 0.5, 1.0) + breath * 0.5


def r_boss_windup_lethal() -> np.ndarray:
    rng = rng_for("boss_windup_lethal")
    dur = 0.8
    drop = sine(linramp(dur, 92.0, 34.0), dur)
    drop = np.tanh(drop * 2.2)
    dark = lowpass(noise(dur, rng), 260.0) * linramp(dur, 0.2, 1.0)
    return (drop * linramp(dur, 0.4, 1.0) + dark * 0.6) * expdecay(dur, dur)


def r_boss_death_slowmo() -> np.ndarray:
    rng = rng_for("boss_death")
    x = silence(2.0)
    strike = bell(D4, 1.9, bright=0.9, damp=0.55, strike=0.7, rng=rng)
    place(x, strike, 0.0)
    for delay, gain in ((0.09, 0.4), (0.21, 0.24), (0.36, 0.14)):
        place(x, strike, delay, gain)  # cheap wet chamber tail
    return x * np.concatenate([np.ones(n_of(1.2)), np.linspace(1.0, 0.0, n_of(0.8))])


def r_shrine_wrap() -> np.ndarray:
    rng = rng_for("shrine_wrap")
    dur = 0.8
    rustle = bandpass(noise(dur, rng), 1900.0, 0.8)
    flutter = np.clip(1.0 + 4.0 * lowpass(noise(dur, rng), 13.0, 0.6), 0.1, 2.2)
    x = rustle * flutter * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 0.8
    place(x, pluck(D5, 0.18, 0.06, 0.5, rng=rng), 0.6)
    return x


def _shrine_rest_base(rng: np.random.Generator, f_scale: float = 1.0,
                      damp: float = 1.0, bright: float = 1.0) -> np.ndarray:
    """Lullaby motif 龛中眠: D-A-B(natural) — the near-resolved major variant."""
    x = silence(1.8)
    for i, f in enumerate((D5, A4, B4)):
        place(x, bell(f * f_scale, 1.3 - 0.15 * i, bright=bright, damp=damp,
                      strike=0.3, rng=rng), 0.34 * i, 0.9 - 0.12 * i)
    return x


def r_shrine_rest_ch01() -> np.ndarray:  # moss: warm, absorbed highs
    return lowpass(_shrine_rest_base(rng_for("rest01"), damp=1.1), 3400.0)


def r_shrine_rest_ch02() -> np.ndarray:  # copper: rusty music-box, metallic
    rng = rng_for("rest02")
    x = _shrine_rest_base(rng, bright=1.3, damp=1.5)
    x += bandpass(noise(1.8, rng), 4200.0, 2.2) * expdecay(1.8, 0.4) * 0.06
    return x


def r_shrine_rest_ch03() -> np.ndarray:  # salt: glassy celesta, bright/short
    x = _shrine_rest_base(rng_for("rest03"), f_scale=2.0, damp=2.2, bright=1.2)
    return highpass(x, 700.0)


def r_shrine_rest_ch04() -> np.ndarray:  # fiber: plucked-string lullaby
    rng = rng_for("rest04")
    x = silence(1.8)
    for i, f in enumerate((D5, A4, B4)):
        place(x, pluck(f, 0.9, 0.28, 0.85 - 0.1 * i, rng=rng), 0.34 * i)
    return x


def r_shrine_rest_ch05() -> np.ndarray:  # obsidian: muted low horn-bell
    x = _shrine_rest_base(rng_for("rest05"), f_scale=0.5, damp=0.9, bright=0.7)
    return lowpass(x, 1250.0)


def r_shrine_rest_ch06() -> np.ndarray:  # silent: pure far sines with echoes
    rng = rng_for("rest06")
    x = silence(1.8)
    for i, f in enumerate((D5, A4, B4)):
        tone = sine(f, 1.0, 0.8) * expdecay(1.0, 0.4)
        place(x, tone, 0.34 * i, 0.7)
        place(x, tone, 0.34 * i + 0.12, 0.24)
        place(x, tone, 0.34 * i + 0.27, 0.1)
    return lowpass(x, 5200.0)


def r_gate_dash() -> np.ndarray:
    rng = rng_for("gate_dash")
    x = silence(1.0)
    hissb = bandpass(noise(0.26, rng), linramp(0.26, 1000.0, 4200.0), 1.6) * expdecay(0.26, 0.12)
    place(x, hissb, 0.0, 1.1)
    slide = lowpass(noise(0.7, rng), 320.0) * np.sin(np.linspace(0, math.pi, n_of(0.7))) ** 0.7
    place(x, slide, 0.12, 1.2)
    place(x, sine(88.0, 0.16, 0.9) * expdecay(0.16, 0.05), 0.72)
    return x


def r_gate_wallshaft() -> np.ndarray:
    rng = rng_for("gate_wallshaft")
    x = silence(0.95)
    place(x, sine(linramp(0.3, 170.0, 55.0), 0.3, 1.0) * expdecay(0.3, 0.14), 0.0)
    place(x, lowpass(noise(0.4, rng), 500.0) * expdecay(0.4, 0.14), 0.0, 0.9)
    for i, at in enumerate((0.4, 0.55, 0.74)):
        f = 1400.0 - 260.0 * i
        place(x, sine(linramp(0.06, f, f * 0.55), 0.06, 0.3) * expdecay(0.06, 0.025), at)
    return x


def r_gate_hookring() -> np.ndarray:
    rng = rng_for("gate_hookring")
    x = silence(1.1)
    place(x, bell(E5, 0.8, bright=1.2, damp=1.1, strike=0.5, rng=rng), 0.0)
    for k in range(8):
        at = 0.3 + 0.5 * (k / 8.0) + 0.03 * rng.random()
        f = 2400.0 + 3200.0 * rng.random()
        place(x, sine(f, 0.05, 0.4) * expdecay(0.05, 0.012), at)
    place(x, lowpass(noise(0.5, rng), 240.0) * expdecay(0.5, 0.16), 0.3, 0.8)
    return x


def r_gate_doublejump() -> np.ndarray:
    rng = rng_for("gate_doublejump")
    x = silence(0.9)
    for rep in (0.0, 0.24):
        place(x, pluck(D5, 0.26, 0.08, rng=rng), rep)
        place(x, pluck(A5, 0.26, 0.08, 0.8, rng=rng), rep + 0.04)
    for k in range(5):
        place(x, bandpass(noise(0.025, rng), 1500.0 + 400.0 * k, 2.4) * expdecay(0.025, 0.01), 0.5 + 0.06 * k, 0.6)
    return x


def r_gate_guardbreak() -> np.ndarray:
    rng = rng_for("gate_guardbreak")
    x = silence(1.0)
    cracked = bell(D4, 0.5, bright=0.8, damp=2.4, strike=0.8, rng=rng)
    cut = n_of(0.34)
    cracked[cut:] *= np.linspace(1.0, 0.0, len(cracked) - cut) ** 2  # ring choked off
    place(x, cracked, 0.0)
    place(x, highpass(noise(0.06, rng), 1800.0) * expdecay(0.06, 0.02), 0.3, 1.0)
    place(x, bandpass(noise(0.2, rng), 900.0, 1.1) * expdecay(0.2, 0.07), 0.36, 0.8)
    return x


def r_gate_shadow() -> np.ndarray:
    rng = rng_for("gate_shadow")
    x = silence(1.0)
    swell = lowpass(noise(0.4, rng), 700.0) * np.linspace(0.0, 1.0, n_of(0.4)) ** 2
    place(x, swell[::-1] * -1.0, 0.0, 0.9)  # reversed wick intake
    flip = bandpass(noise(0.3, rng), 900.0, 1.0) * sine(880.0, 0.3)
    place(x, flip * expdecay(0.3, 0.09), 0.4, 0.9)
    place(x, sine(linramp(0.25, 120.0, 48.0), 0.25, 0.9) * expdecay(0.25, 0.1), 0.42)
    return x


def r_gate_crown() -> np.ndarray:
    rng = rng_for("gate_crown")
    x = silence(1.6)
    for i, f in enumerate((D5, A4, BB4)):  # the silent-toll motif itself
        place(x, pluck(f, 0.5, 0.18, rng=rng), 0.28 * i)
    place(x, sine(D3, 0.3, 0.6) * expdecay(0.3, 0.1), 0.84)
    # one beat of engineered silence, then a tiny far bell answers
    place(x, bell(D6, 0.28, bright=0.8, damp=2.0, strike=0.2, rng=rng), 1.3, 0.35)
    return x


def r_chapter_transition() -> np.ndarray:
    rng = rng_for("chapter_transition")
    x = silence(1.8)
    reel = bandpass(noise(1.2, rng), linramp(1.2, 320.0, 3100.0), 1.7)
    place(x, reel * np.linspace(0.25, 1.0, n_of(1.2)) ** 1.5, 0.0, 1.1)
    gliss = sine(linramp(1.1, D4, D5), 1.1, 0.5) * np.sin(np.linspace(0, math.pi, n_of(1.1)))
    place(x, gliss, 0.05)
    place(x, bell(D5, 0.6, bright=1.0, damp=1.4, strike=0.3, rng=rng), 1.15, 0.8)
    return x


def r_ending_a() -> np.ndarray:
    rng = rng_for("ending_a")
    x = silence(2.0)
    for i, f in enumerate((BB4, A4, D5)):  # Bb -> A -> D: the motif resolves
        place(x, bell(f, 1.4 - 0.2 * i, bright=1.1, damp=0.8, strike=0.5, rng=rng), 0.3 * i, 0.9)
        place(x, bell(f * 0.5, 1.4, bright=0.8, damp=0.7, strike=0.2, rng=rng), 0.3 * i, 0.5)
    return x


def r_ending_b() -> np.ndarray:
    rng = rng_for("ending_b")
    x = silence(2.0)
    place(x, highpass(noise(0.015, rng), 2200.0), 0.08, 0.7)
    place(x, sine(linramp(0.1, 900.0, 160.0), 0.1, 0.8) * expdecay(0.1, 0.04), 0.09)
    surge = lowpass(noise(1.6, rng), linramp(1.6, 180.0, 700.0), 0.7)
    surge *= 1.0 + 0.5 * np.sin(2 * math.pi * 1.7 * t_axis(1.6))
    # surge carries the loudness (review 3e: was 10 dB under endings a/c)
    place(x, surge * np.sin(np.linspace(0, math.pi, n_of(1.6))) ** 0.6, 0.25, 4.2)
    return x


def r_ending_c() -> np.ndarray:
    rng = rng_for("ending_c")
    x = silence(2.0)
    for i, f in enumerate((D5, A4, BB4)):
        place(x, pluck(f, 0.6, 0.22, rng=rng), 0.24 * i, 0.8)
    # Picardy close: soft D major bloom (D + F# + A)
    for f, g in ((D4, 0.8), (FS4, 0.55), (A4, 0.6), (D5, 0.4)):
        place(x, bell(f, 1.1, bright=0.9, damp=0.8, strike=0.15, rng=rng), 0.85, g)
    return x


# ----------------------------------------------------- core gameplay sounds
# The 11 root-level files main_level/player_controller (and web src/main.js)
# already reference. Same crimson-thread family vocabulary as the rest.


def r_core_jump() -> np.ndarray:
    """起跳：线弹跳 pluck + 微钟 tick。"""
    rng = rng_for("core_jump")
    x = silence(0.34)
    place(x, pluck(D5, 0.24, 0.05, 1.0, rng=rng), 0.0)
    spring = sine(linramp(0.07, 460.0, 980.0), 0.07, 0.28) * expdecay(0.07, 0.028)
    place(x, spring, 0.0)  # thread rebounds upward
    place(x, bell(D6, 0.18, bright=1.05, damp=2.6, strike=0.2, rng=rng), 0.02, 0.22)
    return x


def r_core_dash() -> np.ndarray:
    """冲刺：气流嗖——上扫带通噪声 + 微弱线鸣。"""
    rng = rng_for("core_dash")
    x = silence(0.3)
    sw = bandpass(noise(0.24, rng), linramp(0.24, 700.0, 3400.0), 1.3)
    place(x, sw * np.sin(np.linspace(0, math.pi, n_of(0.24))) ** 1.9, 0.0, 1.0)
    place(x, sine(linramp(0.12, 1200.0, 2600.0), 0.12, 0.1) * expdecay(0.12, 0.05), 0.02)
    # thread-launch snap carries the peak so the swoosh body can sit lower
    place(x, highpass(noise(0.012, rng), 3600.0) * expdecay(0.012, 0.004), 0.0, 2.4)
    return x


def r_core_hurt() -> np.ndarray:
    """受伤：闷线崩 + 身体钝击。"""
    rng = rng_for("core_hurt")
    x = silence(0.4)
    place(x, pluck(A3, 0.16, 0.05, 1.0, rng=rng), 0.0)  # muted thread snap
    thud = np.tanh(sine(linramp(0.14, 150.0, 62.0), 0.14, 1.5)) * expdecay(0.14, 0.038)
    place(x, thud, 0.005, 0.8)
    place(x, lowpass(noise(0.12, rng), 480.0) * expdecay(0.12, 0.03), 0.005, 0.65)
    return x


def r_core_heal() -> np.ndarray:
    """治疗：温暖织线微光——柔和低亮钟对 + 上行线光。"""
    rng = rng_for("core_heal")
    x = silence(0.95)
    place(x, pluck(D6, 0.12, 0.03, 1.0, rng=rng), 0.0)  # bright knot-tie transient
    place(x, bell(D5, 0.7, bright=0.9, damp=1.2, strike=0.1, rng=rng), 0.0, 0.42)
    place(x, bell(A5, 0.6, bright=0.85, damp=1.4, strike=0.1, rng=rng), 0.18, 0.28)
    weave = sine(linramp(0.5, D4, D5), 0.5, 0.1) * np.sin(np.linspace(0, math.pi, n_of(0.5)))
    place(x, weave, 0.05)
    shimmer = bandpass(noise(0.7, rng), 5200.0, 1.2)
    place(x, shimmer * np.sin(np.linspace(0, math.pi, n_of(0.7))) ** 2, 0.1, 0.06)
    return x


def r_core_hook() -> np.ndarray:
    """勾索：甩线鞭 whoosh + 金属 tick。"""
    rng = rng_for("core_hook")
    x = silence(0.46)
    lash = bandpass(noise(0.18, rng), linramp(0.18, 600.0, 3000.0), 1.4)
    place(x, lash * np.sin(np.linspace(0, math.pi, n_of(0.18))) ** 1.1, 0.0, 1.1)
    place(x, bell(E5, 0.28, bright=1.2, damp=2.0, strike=0.5, rng=rng), 0.14, 0.7)
    return x


def r_core_attack() -> np.ndarray:
    """普攻：丝斩破风（player_attack_01 同配方语汇，中音起手）。"""
    rng = rng_for("core_attack")
    lo, hi, dur = 900.0, 2500.0, 0.22
    x = silence(dur + 0.08)
    body = bandpass(noise(dur, rng), linramp(dur, lo, hi), 1.3)
    place(x, body * np.sin(np.linspace(0, math.pi, n_of(dur))) ** 1.4, 0.0, 1.1)
    thread = sine(linramp(0.08, lo * 2.2, hi * 1.4), 0.08, 0.16) * expdecay(0.08, 0.03)
    place(x, thread, 0.02)  # the crimson-thread edge sings faintly
    place(x, highpass(noise(0.02, rng), 4200.0) * expdecay(0.02, 0.006), 0.0, 0.5)
    return x


def r_core_enemy_hit() -> np.ndarray:
    """敌人受击：钝击。"""
    rng = rng_for("core_enemy_hit")
    x = silence(0.2)
    place(x, bandpass(noise(0.07, rng), 2100.0, 1.0) * expdecay(0.07, 0.016), 0.0, 1.1)
    place(x, sine(170.0, 0.1, 0.9) * expdecay(0.1, 0.024), 0.0)
    return x


def r_core_heavy_hit() -> np.ndarray:
    """重钝击：低频 thud + 宽噪声冲击。"""
    rng = rng_for("core_heavy_hit")
    x = silence(0.36)
    place(x, bandpass(noise(0.1, rng), 1500.0, 0.9) * expdecay(0.1, 0.024), 0.0, 1.3)
    thud = np.tanh(sine(linramp(0.2, 105.0, 48.0), 0.2, 1.6)) * expdecay(0.2, 0.05)
    place(x, thud, 0.0, 0.85)
    place(x, sine(1350.0, 0.14, 0.2) * expdecay(0.14, 0.04), 0.004)
    return x


def r_core_pickup() -> np.ndarray:
    """拾取：柔和风铃三音（D 系下行）。"""
    rng = rng_for("core_pickup")
    x = silence(0.72)
    for i, (f, gn) in enumerate(((D6, 0.7), (B5, 0.5), (A5, 0.35))):
        tone = sine(f, 0.4, gn) * expdecay(0.4, 0.07)
        place(tone, sine(f * 2.76, 0.25, gn * 0.25) * expdecay(0.25, 0.032), 0.0)
        place(x, tone, 0.07 * i)
        place(x, highpass(noise(0.006, rng), 3000.0) * 0.35 * gn, 0.07 * i)
    return x


def r_core_interact() -> np.ndarray:
    """交互：布/纸触碰摩挲。"""
    rng = rng_for("core_interact")
    x = silence(0.26)
    brush = bandpass(noise(0.13, rng), 1700.0, 0.8)
    place(x, brush * np.sin(np.linspace(0, math.pi, n_of(0.13))) ** 1.5, 0.0, 1.0)
    place(x, lowpass(noise(0.05, rng), 700.0) * expdecay(0.05, 0.015), 0.0, 0.6)
    place(x, bandpass(noise(0.07, rng), 1300.0, 1.0) * expdecay(0.07, 0.02), 0.15, 0.3)
    return x


def r_core_lever() -> np.ndarray:
    """拉杆：机构咔嗒两段 + 低频到位 thunk。"""
    rng = rng_for("core_lever")
    x = silence(0.42)
    place(x, highpass(noise(0.012, rng), 2200.0) * expdecay(0.012, 0.004), 0.0, 1.1)
    place(x, sine(linramp(0.05, 420.0, 210.0), 0.05, 0.8) * expdecay(0.05, 0.02), 0.005)
    place(x, highpass(noise(0.015, rng), 1800.0) * expdecay(0.015, 0.005), 0.12, 0.9)
    place(x, sine(150.0, 0.12, 0.7) * expdecay(0.12, 0.04), 0.12)
    place(x, bandpass(noise(0.08, rng), 900.0, 1.4) * expdecay(0.08, 0.03), 0.13, 0.5)
    return x


# --------------------------------------------------------------------- pack

# (event_key, file_name, builder, is_loop, peak, active_rms_db_target|None)
PACK = [
    ("player_pogo_bounce", "player_pogo_bounce.ogg", r_pogo_bounce, False, 0.7, None),
    ("player_attack_hit_light", "player_attack_hit_light.ogg", r_hit_light, False, 0.7, None),
    ("player_attack_hit_heavy", "player_attack_hit_heavy.ogg", r_hit_heavy, False, 0.7, None),
    ("player_attack_kill", "player_attack_kill.ogg", r_hit_kill, False, 0.7, None),
    ("player_hook_latch", "player_hook_latch.ogg", r_hook_latch, False, 0.7, None),
    ("player_hook_reel", "player_hook_reel.ogg", r_hook_reel, False, 0.62, None),
    ("player_double_jump_wings", "player_double_jump_wings.ogg", r_double_jump_wings, False, 0.66, None),
    ("player_wall_grip_attach", "player_wall_grip_attach.ogg", r_wall_grip_attach, False, 0.7, None),
    ("player_wall_slide_loop", "player_wall_slide_loop.ogg", r_wall_slide_loop, True, 0.5, None),
    ("player_guard_block", "player_guard_block.ogg", r_guard_block, False, 0.7, None),
    ("player_guard_perfect", "player_guard_perfect.ogg", r_guard_perfect, False, 0.7, None),
    ("player_downstrike_crack", "player_downstrike_crack.ogg", r_downstrike_crack, False, 0.7, None),
    ("player_downstrike_break", "player_downstrike_break.ogg", r_downstrike_break, False, 0.7, None),
    ("player_bind_channel", "player_bind_channel.ogg", r_bind_channel, True, 0.55, None),
    ("player_bind_tighten", "player_bind_tighten.ogg", r_bind_tighten, False, 0.64, None),
    ("player_bind_interrupt", "player_bind_interrupt.ogg", r_bind_interrupt, False, 0.7, None),
    ("player_death_cocoon", "player_death_cocoon.ogg", r_death_cocoon, False, 0.62, None),
    ("player_respawn_weave", "player_respawn_weave.ogg", r_respawn_weave, False, 0.66, None),
    ("player_low_hp_heartbeat", "player_low_hp_heartbeat.ogg", r_low_hp_heartbeat, True, 0.6, None),
    ("enemy_death_moss", "enemy_death_moss.ogg", r_death_moss, False, 0.66, None),
    ("enemy_death_copper", "enemy_death_copper.ogg", r_death_copper, False, 0.7, None),
    ("enemy_death_salt", "enemy_death_salt.ogg", r_death_salt, False, 0.64, None),
    ("enemy_death_fiber", "enemy_death_fiber.ogg", r_death_fiber, False, 0.66, None),
    ("enemy_death_obsidian", "enemy_death_obsidian.ogg", r_death_obsidian, False, 0.7, None),
    # review 3b: was a 0.12-peak near-silent file - now a real, still-hushed cue
    # (peak -6 dB; tap crest keeps active RMS around -23, close to the -24 aim)
    ("enemy_death_silent", "enemy_death_silent.ogg", r_death_silent, False, 0.5, None),
    ("elite_ritual_start", "elite_ritual_start.ogg", r_elite_ritual_start, False, 0.68, None),
    ("boss_windup_light", "boss_windup_light.ogg", r_boss_windup_light, False, 0.6, None),
    # review 3a: -6.3 dB active RMS was the loudest file in the library -> -12
    ("boss_windup_lethal", "boss_windup_lethal.ogg", r_boss_windup_lethal, False, 0.7, -12.0),
    ("boss_death_slowmo", "boss_death_slowmo.ogg", r_boss_death_slowmo, False, 0.7, None),
    ("env_shrine_wrap", "env_shrine_wrap.ogg", r_shrine_wrap, False, 0.55, None),
    ("env_shrine_rest", "env_shrine_rest_ch01.ogg", r_shrine_rest_ch01, False, 0.66, None),
    ("env_shrine_rest", "env_shrine_rest_ch02.ogg", r_shrine_rest_ch02, False, 0.66, None),
    ("env_shrine_rest", "env_shrine_rest_ch03.ogg", r_shrine_rest_ch03, False, 0.62, None),
    ("env_shrine_rest", "env_shrine_rest_ch04.ogg", r_shrine_rest_ch04, False, 0.66, None),
    ("env_shrine_rest", "env_shrine_rest_ch05.ogg", r_shrine_rest_ch05, False, 0.66, None),
    ("env_shrine_rest", "env_shrine_rest_ch06.ogg", r_shrine_rest_ch06, False, 0.45, None),
    ("env_gate_dash", "env_gate_dash.ogg", r_gate_dash, False, 0.68, None),
    ("env_gate_wallshaft", "env_gate_wallshaft.ogg", r_gate_wallshaft, False, 0.68, None),
    ("env_gate_hookring", "env_gate_hookring.ogg", r_gate_hookring, False, 0.68, None),
    ("env_gate_doublejump", "env_gate_doublejump.ogg", r_gate_doublejump, False, 0.66, None),
    ("env_gate_guardbreak", "env_gate_guardbreak.ogg", r_gate_guardbreak, False, 0.68, None),
    ("env_gate_shadow", "env_gate_shadow.ogg", r_gate_shadow, False, 0.66, None),
    ("env_gate_crown", "env_gate_crown.ogg", r_gate_crown, False, 0.68, None),
    ("env_chapter_transition", "env_chapter_transition.ogg", r_chapter_transition, False, 0.66, None),
    ("story_ending_a_rebell", "story_ending_a_rebell.ogg", r_ending_a, False, 0.7, None),
    # review 3e: align the severance ending with endings a/c
    ("story_ending_b_severance", "story_ending_b_severance.ogg", r_ending_b, False, 0.7, -18.0),
    ("story_ending_c_reweave", "story_ending_c_reweave.ogg", r_ending_c, False, 0.7, None),
]

# core gameplay files at the sfx root (overwrite the old silent placeholders;
# web build src/main.js points at the same paths). Combat-SFX loudness
# convention: peak 0.7, active RMS -18..-24 dBFS.
CORE_PACK = [
    ("player_jump", "player_jump.ogg", r_core_jump, False, 0.7, None),
    ("player_dash", "player_dash.ogg", r_core_dash, False, 0.7, None),
    ("player_heal", "player_heal.ogg", r_core_heal, False, 0.7, None),
    ("player_hurt", "player_hurt.ogg", r_core_hurt, False, 0.7, None),
    ("player_hook", "player_hook.ogg", r_core_hook, False, 0.7, None),
    ("player_attack", "player_attack.ogg", r_core_attack, False, 0.7, None),
    ("enemy_hit", "enemy_hit.ogg", r_core_enemy_hit, False, 0.7, None),
    ("heavy_hit", "heavy_hit.ogg", r_core_heavy_hit, False, 0.7, None),
    ("pickup", "pickup.ogg", r_core_pickup, False, 0.7, None),
    ("interact", "interact.ogg", r_core_interact, False, 0.7, None),
    ("lever", "lever.ogg", r_core_lever, False, 0.7, None),
]

SAMPLER_FILES = [
    "player_pogo_bounce.ogg",
    "player_guard_perfect.ogg",
    "player_wall_grip_attach.ogg",
    "enemy_death_copper.ogg",
    "enemy_death_salt.ogg",
    "env_shrine_rest_ch01.ogg",
    "env_gate_crown.ogg",
    "env_chapter_transition.ogg",
]


def write_wav(path: Path, samples: np.ndarray) -> int:
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm.tobytes())
    return path.stat().st_size


def _encode_ogg(path: Path, samples: np.ndarray) -> int:
    tmp = path.with_suffix(".tmp.wav")
    write_wav(tmp, samples)
    subprocess.run(
        [FFMPEG, "-y", "-loglevel", "error", "-i", str(tmp),
         "-ar", str(SR), "-ac", "1", "-q:a", "4",
         # bitexact muxing: fixed ogg serial + no encoder tag -> idempotent rerun
         "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)],
        check=True,
    )
    tmp.unlink()
    return path.stat().st_size


def decode_ogg(path: Path) -> np.ndarray:
    p = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le",
         "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).astype(float)


def write_ogg(path: Path, samples: np.ndarray, peak: float,
              rms_db: float | None) -> int:
    """Encode, then compensate Vorbis level drift: -q:a 4 shaves the peak off
    very short transients (and a little active RMS off sparse textures), so
    re-measure the decoded file and nudge the master gain until it meets its
    target again."""
    size = _encode_ogg(path, samples)
    for _ in range(3):
        y = decode_ogg(path)
        if rms_db is not None:
            err = rms_db - active_rms_db(y)
        else:
            err = 20.0 * math.log10(peak) - 20.0 * math.log10(
                max(float(np.max(np.abs(y))), 1e-9))
        if abs(err) <= 0.35:
            break
        samples = np.clip(samples * 10.0 ** (err / 20.0), -1.0, 1.0)
        size = _encode_ogg(path, samples)
    return size


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    rendered: dict[str, np.ndarray] = {}
    total_bytes = 0
    jobs = [(OUT_DIR, entry) for entry in PACK] + [(SFX_ROOT, entry) for entry in CORE_PACK]
    for out_dir, (event_key, file_name, builder, is_loop, peak, rms_db) in jobs:
        x = np.asarray(builder(), dtype=float)
        if not is_loop:
            x = edge_fade(x, 0.005)
        x = normalize(x, peak)
        if rms_db is not None:
            x = rms_target(x, rms_db, ceiling=peak)
        dur = len(x) / SR
        assert is_loop or dur <= 2.0 + 1e-6, f"{file_name} exceeds 2 s ({dur:.2f}s)"
        size = write_ogg(out_dir / file_name, x, peak, rms_db)
        total_bytes += size
        rendered[file_name] = x
        rows.append((event_key, file_name, dur, float(np.max(np.abs(x))),
                     active_rms_db(x), is_loop, size))

    gap = silence(0.3)
    sampler = np.concatenate(
        [np.concatenate([rendered[name], gap]) for name in SAMPLER_FILES]
    )
    sampler_size = write_wav(PREVIEW, edge_fade(sampler.copy(), 0.005))

    print(f"generated {len(rows)} ogg files -> {OUT_DIR} (+{len(CORE_PACK)} core at {SFX_ROOT})")
    print(f"{'event':<26} {'file':<32} {'dur_s':>6} {'peak':>5} {'aRMS':>6} {'loop':>5} {'bytes':>8}")
    for event_key, file_name, dur, peak, arms, is_loop, size in rows:
        print(f"{event_key:<26} {file_name:<32} {dur:>6.2f} {peak:>5.2f} {arms:>6.1f} {str(is_loop):>5} {size:>8}")
    print(f"total_bytes={total_bytes} ({total_bytes / 1024:.1f} KiB)")
    print(f"sampler -> {PREVIEW} ({sampler_size / 1024:.1f} KiB, {len(sampler) / SR:.1f}s)")


if __name__ == "__main__":
    main()

"""Generate the project-owned music pack for 绯线巡礼 (Crimson Thread Pilgrimage).

Synthesizes every missing music asset from godot/data/audio_visual_manifest.json
(chapter_audio_visual music keys still marked future_free_candidate) plus the
new keys mandated by docs/spec/20260726160400000_音效与音乐设计规格.md §2/§3:

* ch02-ch06 explore loops     - §2.3-2.7 chapter moods (25-40 s seamless loops)
* ch01-ch06 combat layer stems- same tempo as the chapter explore loop so the
                                game can stack them (§2.1 dual-layer structure)
* ch02-ch06 boss loops        - §3.2-3.6 (hemiola scissors / retrograde canon /
                                passacaglia ground bass / mirrored waltz /
                                quodlibet roll-call)
* boss_final_silent_crown_mvt1/2/3 - §3.8 three movements (~30 s loops)
* chXX_shrine_lullaby x6      - §2.1 "龛中眠": the D-A-B(natural) major-variant
                                of the Silent Toll motif, per-chapter timbre
* ending_a_rebell / ending_b_severance / ending_c_reweave - §3.8 cadences,
                                45-60 s one-shots (keys follow the existing
                                story_ending_* stinger naming minus prefix)
* bellway_transit_loop + depart/arrive jingles - §2.9 (3/8 allegro variation)
* hidden_black_tide_drone     - §2.8 low generative drone loop
* ch01 real tracks            - overwrite the two legacy bgm-root files
                                ch01_cave_loop.ogg (§2.2 moss bell court
                                explore) and boss_rust_crown_loop.ogg (rust
                                crown guardian boss), keeping the legacy
                                filenames so every existing reference,
                                validation assertion and web path stays valid

Musical DNA (§1): everything derives from the Silent Toll motif D -> A -> Bb
(falling 4th, rising minor 2nd, no resolution). Lullabies flip Bb to B natural
(the only near-resolved form); ending A finally resolves Bb -> A -> D; the
crimson-thread theme (D leap up to Bb4 then stepwise descent) answers in boss
material and ending C. Chapter color: ch1 D dorian bronze bells, ch2 G minor
anvils, ch3 A minor celesta counterpoint (no drums), ch4 E minor broken
pizzicato + glass harmonics + wordless voice, ch5 D phrygian horns + muted
snare, ch6 near-silence with child voice on D and Bb only.

Output: 44.1 kHz mono synthesis -> ffmpeg -q:a 5 OGG under
godot/assets/audio/bgm/generated/<key>.ogg (the two ch01 legacy keys go to the
bgm root instead). Loops are rendered on integer-bar grids with wrap-around
tails plus equal-power crossfaded seams, then seam-polished (the residual
end->start amplitude step is spread over the last ~90 ms) so looping is
click-free. Loudness is target-driven per category using gated "voiced" RMS
(50 ms windows, -60 dBFS absolute + -20 dB relative gate): explore -22,
combat -20, boss/final -18, lullaby -26 (>=3 dB under the chapter explore by
construction), ending -17, bellway loop -24, jingles -20, drone -30 dBFS;
after the gain ride a tanh soft limiter (ceiling 0.92, leaving headroom for
Vorbis codec overshoot) guards peaks.
Deterministic (per-file seeded RNG) and idempotent - rerunning rewrites
identical WAV content.

Inventory: output/audio_preview/music_pack_inventory.json.
License of all output: project-generated (CC0).
"""
from __future__ import annotations

import json
import math
import re
import shutil
import subprocess
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[1]
BGM_ROOT = ROOT / "godot" / "assets" / "audio" / "bgm"
OGG_DIR = BGM_ROOT / "generated"
# ch01 keys keep their historical filenames in the bgm root (13 existing
# references: audio_director/main_level fallbacks, validation, web preview).
LEGACY_BGM_KEYS = {"ch01_cave_loop", "boss_rust_crown_loop"}
WAV_DIR = ROOT / "output" / "audio_preview" / "music_wav_build"
INVENTORY = ROOT / "output" / "audio_preview" / "music_pack_inventory.json"
FFMPEG = Path("C:/Users/Administrator/Desktop/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe")

_NOTE_SEMIS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name: str) -> float:
    """Note name ("D4", "Bb3", "F#5") -> equal-tempered frequency, A4=440."""
    m = re.fullmatch(r"([A-G])([b#]?)(-?\d)", name)
    if not m:
        raise ValueError(f"bad note {name!r}")
    semi = _NOTE_SEMIS[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    midi = (int(m.group(3)) + 1) * 12 + semi
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


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


def harmonic_phase(freq, dur: float) -> np.ndarray:
    """Phase track usable for coherent harmonic stacks sin(k*ph)."""
    n = n_of(dur)
    if np.isscalar(freq):
        return 2.0 * math.pi * float(freq) * np.arange(n) / SR
    freq = np.asarray(freq, dtype=float)
    if len(freq) != n:
        freq = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(freq)), freq)
    return 2.0 * math.pi * np.cumsum(freq) / SR


def expdecay(dur: float, tau: float, start: float = 1.0) -> np.ndarray:
    return start * np.exp(-t_axis(dur) / max(tau, 1e-4))


def linramp(dur: float, a: float, b: float) -> np.ndarray:
    return np.linspace(a, b, n_of(dur))


def noise(dur: float, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n_of(dur))


def fftfilt(x: np.ndarray, lp: float | None = None, hp: float | None = None,
            order: int = 4) -> np.ndarray:
    """Zero-phase Butterworth-magnitude filter via the frequency domain.
    Vectorized replacement for per-sample SVF loops (music-length arrays)."""
    if len(x) == 0:
        return x
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = np.ones_like(f)
    if lp is not None:
        H *= 1.0 / np.sqrt(1.0 + (f / max(lp, 1.0)) ** (2 * order))
    if hp is not None:
        with np.errstate(divide="ignore"):
            ratio = np.where(f > 0, max(hp, 1.0) / np.maximum(f, 1e-9), np.inf)
        H *= 1.0 / np.sqrt(1.0 + ratio ** (2 * order))
    return np.fft.irfft(X * H, n=len(x))


def bandfilt(x: np.ndarray, lo: float, high: float, order: int = 4) -> np.ndarray:
    return fftfilt(x, lp=high, hp=lo, order=order)


def place(canvas: np.ndarray, part: np.ndarray, at_s: float, gain: float = 1.0) -> None:
    i0 = n_of(at_s)
    i1 = min(len(canvas), i0 + len(part))
    if i1 > i0:
        canvas[i0:i1] += part[: i1 - i0] * gain


def edge_fade(x: np.ndarray, fade_s: float = 0.01) -> np.ndarray:
    n = min(n_of(fade_s), len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0.0, 1.0, n)
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def tail_fade(x: np.ndarray, fade_s: float = 0.015) -> np.ndarray:
    n = min(n_of(fade_s), len(x))
    if n > 0:
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    return x * (peak / m) if m > 1e-9 else x


# ------------------------------------------------------- loudness targeting

# Per-category active("voiced")-RMS targets in dBFS. Lullaby sits 4 dB under
# explore by construction, satisfying the ">=3 dB quieter than the chapter
# explore loop" rule for every chapter.
RMS_TARGETS = {
    "explore": -22.0,
    "combat": -20.0,
    "boss": -18.0,
    "boss_final": -18.0,
    "lullaby": -26.0,
    "ending": -17.0,
    "bellway": -24.0,   # transit loop
    "drone": -30.0,
}
# Key-level overrides (the two bellway jingles are UI-adjacent one-shots).
KEY_RMS_TARGETS = {
    "bellway_depart_jingle": -20.0,
    "bellway_arrive_jingle": -20.0,
}
# 0.92 leaves ~0.7 dB of headroom: lossy Vorbis reconstruction overshoots the
# encoded waveform by a few percent on dense material, and the decoded file
# must still stay clip-free.
LIMIT_CEILING = 0.92


def active_rms_db(x: np.ndarray, win_s: float = 0.05) -> float:
    """Gated 'voiced' RMS in dBFS: 50 ms windows, -60 dBFS absolute gate plus
    a -20 dB relative gate below the ungated mean (BS.1770-flavoured), so
    breathing room in sparse tracks does not drag the measurement down."""
    w = max(1, n_of(win_s))
    n = len(x) // w
    if n == 0:
        return 10.0 * math.log10(float(np.mean(x ** 2)) + 1e-12)
    ms = np.mean(x[: n * w].reshape(n, w) ** 2, axis=1)
    db = 10.0 * np.log10(ms + 1e-12)
    keep = db > -60.0
    if keep.any():
        rel = 10.0 * np.log10(float(np.mean(ms[keep])) + 1e-12) - 20.0
        keep2 = db > max(rel, -60.0)
        if keep2.any():
            keep = keep2
    else:
        keep = np.ones(n, dtype=bool)
    return 10.0 * np.log10(float(np.mean(ms[keep])) + 1e-12)


def soft_limit(x: np.ndarray, ceiling: float = LIMIT_CEILING,
               knee: float = 0.72) -> np.ndarray:
    """Memoryless tanh peak guard: transparent below knee*ceiling, squeezes
    everything above smoothly under the ceiling (never hard-clips)."""
    t = ceiling * knee
    a = np.abs(x)
    over = a > t
    if not over.any():
        return x
    y = x.copy()
    y[over] = np.sign(x[over]) * (t + (ceiling - t)
                                  * np.tanh((a[over] - t) / (ceiling - t)))
    return y


def loudness_normalize(x: np.ndarray, target_db: float) -> np.ndarray:
    """Measure gated RMS -> whole-file gain toward target -> soft limiter;
    iterate a few times since limiting can shave a little RMS back off."""
    y = x
    for _ in range(4):
        cur = active_rms_db(y)
        if abs(cur - target_db) < 0.15:
            break
        y = soft_limit(y * 10.0 ** ((target_db - cur) / 20.0))
    return y


def seam_polish(x: np.ndarray, w_s: float = 0.093) -> np.ndarray:
    """C0 continuity at the loop seam: whatever residual amplitude step is
    left between the last and first sample (free-running partials, codec-side
    energy) is spread as a ramp over the last ~90 ms, so end->start lands
    exactly on the head value - kills the audible click without touching
    musical time (loop length unchanged)."""
    w = min(n_of(w_s), len(x) // 4)
    if w < 8:
        return x
    step = float(x[0] - x[-1])
    if abs(step) < 1e-9:
        return x
    y = x.copy()
    y[-w:] = y[-w:] + np.linspace(0.0, 1.0, w) * step
    return y


def loop_canvas(loop_s: float, tail_s: float = 4.0) -> tuple[np.ndarray, int]:
    """Event canvas with extra tail room; wrap() folds the tail onto the head."""
    return np.zeros(n_of(loop_s) + n_of(tail_s)), n_of(loop_s)


def wrap(canvas: np.ndarray, loop_n: int) -> np.ndarray:
    """Fold decaying tails past the loop point back onto the loop head."""
    out = canvas[:loop_n].copy()
    tail = canvas[loop_n:]
    m = min(len(tail), loop_n)
    out[:m] += tail[:m]
    return out


def seamless(x: np.ndarray, loop_n: int, xfade_s: float = 0.5) -> np.ndarray:
    """Equal-power crossfade of the post-loop excess into the head; use for
    continuous textures (noise beds, free-running sines)."""
    n = min(n_of(xfade_s), loop_n // 3, max(len(x) - loop_n, 0))
    out = x[:loop_n].copy()
    if n > 0:
        up = np.sin(np.linspace(0.0, math.pi / 2.0, n)) ** 2
        out[:n] = out[:n] * up + x[loop_n: loop_n + n] * (1.0 - up)
    return out


def cyc(freq: float, loop_s: float) -> float:
    """Snap an LFO frequency to an integer cycle count over the loop."""
    return max(1.0, round(freq * loop_s)) / loop_s


def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(("crimson_music:" + name).encode("utf-8")))


# --------------------------------------------------------------- instruments

BELL_PARTIALS = (
    (1.00, 1.00, 1.00),
    (2.00, 0.55, 0.52),
    (2.98, 0.36, 0.34),
    (4.16, 0.22, 0.22),
    (5.43, 0.12, 0.14),
)

CELESTA_PARTIALS = (
    (1.00, 1.00, 0.9),
    (3.92, 0.38, 0.42),
    (9.15, 0.12, 0.2),
)


def bell(f0: float, dur: float, bright: float = 1.0, damp: float = 1.0,
         strike: float = 0.4, rng: np.random.Generator | None = None,
         partials=BELL_PARTIALS) -> np.ndarray:
    out = silence(dur)
    for idx, (ratio, amp, dfrac) in enumerate(partials):
        f = f0 * ratio * (1.0 + 0.0015 * idx)
        if f > SR * 0.45:
            continue
        tau = max(0.02, dur * dfrac / max(damp, 0.05))
        out += sine(f, dur, amp * (bright if idx else 1.0)) * expdecay(dur, tau)
    if strike > 0 and rng is not None:
        hit = bandfilt(noise(0.008, rng), min(f0 * 2.0, 2000.0), min(f0 * 6.0, 9000.0)) * strike
        out[: len(hit)] += hit * np.linspace(1, 0, len(hit))
    return out


def celesta(f0: float, dur: float, rng: np.random.Generator | None = None) -> np.ndarray:
    return bell(f0, dur, bright=1.1, damp=1.6, strike=0.25, rng=rng,
                partials=CELESTA_PARTIALS)


def pluck(f0: float, dur: float, tau: float = 0.3, amp: float = 1.0,
          bright: float = 0.72) -> np.ndarray:
    """Thread-family pluck: decaying harmonic stack, slight inharmonicity."""
    out = silence(dur)
    for k in range(1, 7):
        f = f0 * k * (1.0 + 0.0008 * k * k)
        if f > SR * 0.45:
            continue
        out += sine(f, dur, (bright ** (k - 1)) / k) * expdecay(dur, tau / (0.6 + 0.4 * k))
    out[: n_of(0.004)] *= np.linspace(0.3, 1.0, n_of(0.004))
    return amp * out


def snap_pizz(f0: float, dur: float, rng: np.random.Generator) -> np.ndarray:
    """Bartok snap: hard slap transient into a short dark pluck."""
    x = pluck(f0, dur, tau=0.09, bright=0.6)
    slap = bandfilt(noise(0.012, rng), 700.0, 3200.0) * 0.9
    x[: len(slap)] += slap * np.linspace(1.0, 0.0, len(slap))
    return x


def musicbox(f0: float, dur: float, detune: float = 0.015,
             rng: np.random.Generator | None = None) -> np.ndarray:
    """Rusty music box: bright short pluck pair slightly out of tune, thin."""
    x = pluck(f0, dur, tau=0.5, bright=0.85)
    x += pluck(f0 * (1.0 + detune), dur, tau=0.4, bright=0.8) * 0.35
    return fftfilt(x, hp=700.0)


def pad(f0: float, dur: float, amp: float = 1.0, attack: float = 0.6,
        release: float = 0.8, lpf: float = 1800.0, detune: float = 0.004,
        octave: float = 0.35) -> np.ndarray:
    x = silence(dur)
    for d in (-detune, 0.0, detune):
        x += sine(f0 * (1.0 + d), dur, 1.0 / 3.0)
        if octave > 0:
            x += sine(f0 * 2.0 * (1.0 + d), dur, octave / 3.0)
    a = min(attack, dur * 0.45)
    r = min(release, dur * 0.45)
    env = np.ones(n_of(dur))
    env[: n_of(a)] = np.linspace(0.0, 1.0, n_of(a)) ** 1.5
    env[-n_of(r):] *= np.linspace(1.0, 0.0, n_of(r)) ** 1.2
    return fftfilt(x * env, lp=lpf) * amp


def glass_harmonic(f0: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Bowed glass rim: near-pure tone with slow arch and shimmer beat."""
    x = sine(f0, dur) + sine(f0 * 2.003, dur, 0.18) + sine(f0 * 1.002, dur, 0.4)
    env = np.sin(np.linspace(0.0, math.pi, n_of(dur))) ** 1.6
    return x * env * amp


def organ(f0: float, dur: float, amp: float = 1.0, lpf: float = 3200.0) -> np.ndarray:
    ph = harmonic_phase(f0, dur)
    x = (np.sin(ph) + 0.7 * np.sin(2 * ph) + 0.45 * np.sin(3 * ph)
         + 0.4 * np.sin(4 * ph) + 0.25 * np.sin(6 * ph) + 0.15 * np.sin(8 * ph))
    x += sine(f0 * 1.003, dur, 0.4)
    env = np.ones(n_of(dur))
    a = n_of(min(0.05, dur * 0.2))
    r = n_of(min(0.12, dur * 0.3))
    env[:a] = np.linspace(0.0, 1.0, a)
    env[-r:] *= np.linspace(1.0, 0.0, r)
    return fftfilt(x * env, lp=lpf) * amp * 0.4


def horn(f0: float, dur: float, amp: float = 1.0, lpf: float = 1400.0,
         attack: float = 0.07) -> np.ndarray:
    vib = f0 * (1.0 + 0.006 * np.sin(2 * math.pi * 4.6 * t_axis(dur))
                * np.minimum(t_axis(dur) / 0.35, 1.0))
    ph = harmonic_phase(vib, dur)
    x = sum((1.0 / k ** 1.25) * np.sin(k * ph) for k in range(1, 10))
    env = np.ones(n_of(dur))
    a = n_of(min(attack, dur * 0.3))
    r = n_of(min(0.15, dur * 0.35))
    env[:a] = np.linspace(0.0, 1.0, a) ** 1.4
    env[-r:] *= np.linspace(1.0, 0.0, r)
    return fftfilt(x * env, lp=lpf) * amp * 0.45


def voice(f0: float, dur: float, amp: float = 1.0, vib: float = 4.8,
          vdepth: float = 0.012, lpf: float = 3000.0,
          rng: np.random.Generator | None = None) -> np.ndarray:
    """Wordless hum: coherent low harmonics + vibrato + a wisp of breath."""
    t = t_axis(dur)
    freq = f0 * (1.0 + vdepth * np.sin(2 * math.pi * vib * t) * np.minimum(t / 0.5, 1.0))
    ph = harmonic_phase(freq, dur)
    x = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph) + 0.04 * np.sin(4 * ph)
    if rng is not None:
        x += bandfilt(noise(dur, rng), f0 * 1.5, f0 * 4.0) * 0.03
    env = np.sin(np.linspace(0.0, math.pi, n_of(dur))) ** 0.8
    return fftfilt(x * env, lp=lpf) * amp


def kick(dur: float = 0.28, f_hi: float = 120.0, f_lo: float = 42.0) -> np.ndarray:
    x = sine(f_hi * np.exp(-t_axis(dur) / 0.05) + f_lo, dur)
    return x * expdecay(dur, 0.09)


def taiko(dur: float = 0.5, rng: np.random.Generator | None = None) -> np.ndarray:
    x = sine(66.0 * np.exp(-t_axis(dur) / 0.09) + 52.0, dur) * expdecay(dur, 0.16)
    if rng is not None:
        th = fftfilt(noise(min(0.06, dur), rng), lp=320.0)
        x[: len(th)] += th * np.linspace(1.0, 0.0, len(th)) * 0.7
    return x


def snare(dur: float = 0.2, muffle: float = 2200.0,
          rng: np.random.Generator | None = None) -> np.ndarray:
    assert rng is not None
    x = bandfilt(noise(dur, rng), 400.0, muffle) * expdecay(dur, 0.045)
    x += sine(196.0, dur, 0.4) * expdecay(dur, 0.03)
    return x


def tick(dur: float = 0.04, lo: float = 3200.0, hi: float = 9000.0,
         rng: np.random.Generator | None = None) -> np.ndarray:
    assert rng is not None
    return bandfilt(noise(dur, rng), lo, hi) * expdecay(dur, 0.008)


def anvil(f0: float, dur: float = 0.5, rng: np.random.Generator | None = None,
          amp: float = 1.0) -> np.ndarray:
    """Pitched foundry strike: inharmonic metal partials + strike noise."""
    out = silence(dur)
    for ratio, a in ((1.0, 1.0), (1.51, 0.68), (2.42, 0.5), (3.28, 0.34), (4.73, 0.2)):
        f = f0 * ratio
        if f > SR * 0.45:
            continue
        out += sine(f, dur, a) * expdecay(dur, 0.16 / ratio ** 0.6)
    if rng is not None:
        hit = bandfilt(noise(0.01, rng), 1800.0, 8000.0)
        out[: len(hit)] += hit * np.linspace(1.2, 0.0, len(hit))
    return out * amp


def timpani(f0: float = 73.42, dur: float = 1.2,
            rng: np.random.Generator | None = None) -> np.ndarray:
    x = sine(f0 * (1.0 + 0.02 * np.exp(-t_axis(dur) / 0.06)), dur) * expdecay(dur, 0.35)
    x += sine(f0 * 1.5, dur, 0.3) * expdecay(dur, 0.2)
    if rng is not None:
        th = fftfilt(noise(0.05, rng), lp=260.0)
        x[: len(th)] += th * np.linspace(1.0, 0.0, len(th)) * 0.8
    return x


def triangle_ping(dur: float = 1.0, f: float = 5274.0) -> np.ndarray:
    x = sine(f, dur, 1.0) + sine(f * 1.505, dur, 0.4) + sine(f * 2.02, dur, 0.2)
    return x * expdecay(dur, 0.4)


def sustain_tone(freq_gains, dur: float, lpf: float = 2000.0,
                 detune: float = 0.003) -> np.ndarray:
    """Free-running sustained cluster for beds (loop via seamless())."""
    x = silence(dur)
    for f, g in freq_gains:
        x += sine(f * (1.0 - detune), dur, g * 0.5)
        x += sine(f * (1.0 + detune), dur, g * 0.5)
    return fftfilt(x, lp=lpf)


def echoes(part: np.ndarray, canvas: np.ndarray, at_s: float, gain: float,
           delays=((0.19, 0.42), (0.41, 0.2), (0.66, 0.09))) -> None:
    """Dry hit + cheap wet chamber repeats."""
    place(canvas, part, at_s, gain)
    for d, g in delays:
        place(canvas, part, at_s + d, gain * g)


def events(canvas: np.ndarray, spb: float, notes, instr, t0: float = 0.0,
           gain: float = 1.0) -> None:
    """notes: iterable of (beat, note_name_or_freq, dur_beats, velocity)."""
    for beat, note, durb, vel in notes:
        f = hz(note) if isinstance(note, str) else float(note)
        x = instr(f, max(durb * spb, 0.03))
        tail_fade(x, 0.015)
        place(canvas, x, t0 + beat * spb, gain * vel)


# ---------------------------------------------------------- motif materials

def toll_notes(beat0: float, unit: float, vel: float = 1.0, octave: int = 4):
    """Silent Toll motif D->A->Bb: falling 4th, trapped minor 2nd, no cadence."""
    d, a, bb = f"D{octave}", f"A{octave - 1}", f"Bb{octave - 1}"
    return [(beat0, d, 1.5 * unit, vel),
            (beat0 + 1.5 * unit, a, 0.5 * unit, vel * 0.85),
            (beat0 + 2.0 * unit, bb, 2.5 * unit, vel * 0.95)]


def thread_notes(beat0: float, unit: float, vel: float = 1.0):
    """Crimson-thread theme: leap D4->Bb4 then stepwise descent (the stitch)."""
    seq = [("D4", 0.5), ("Bb4", 1.0), ("A4", 0.5), ("G4", 0.5), ("F4", 0.5), ("E4", 1.5)]
    out, t = [], beat0
    for name, durb in seq:
        out.append((t, name, durb * unit, vel))
        t += durb * unit
    return out


def lull_phrase(canvas: np.ndarray, t0: float, unit: float, instr,
                gain: float = 1.0, octave: int = 5, b_dur: float = 3.5) -> None:
    """龛中眠 lullaby: D-A-B natural (minor 2nd widened to major 2nd)."""
    d, a, b = f"D{octave}", f"A{octave - 1}", f"B{octave - 1}"
    for at, name, durb, vel in ((0.0, d, 2.0, 1.0), (2.2, a, 1.8, 0.82),
                                (4.2, b, b_dur, 0.92)):
        x = instr(hz(name), durb * unit)
        tail_fade(x, 0.02)
        place(canvas, x, t0 + at * unit, gain * vel)


# ------------------------------------------------------------------- recipes
# Each returns (samples, loop_bool). Loop recipes are integer-bar grids with
# wrapped tails + crossfaded beds.

def r_ch01_explore() -> tuple[np.ndarray, bool]:
    # §2.2 苔钟庭 (legacy filename ch01_cave_loop): 72 BPM D dorian 6/8
    # pendulum sway - the same 30.0 s / 18-bar grid as the ch01 combat layer
    # so AudioStreamSynchronized can stack them. Tube/hand bells state the
    # motif, harp plucks answer, wood-flute phrase once, D-A open-fifth drone
    # breathing at the pendulum period under wet moss drips; >=40% air.
    rng = rng_for("ch01_explore")
    dq = 60.0 / 72.0            # dotted-quarter pulse
    bar = 2 * dq
    bars = 18
    loop_s = bars * bar         # 30.0 s
    e8 = dq / 3.0
    ev, loop_n = loop_canvas(loop_s)
    hb = lambda f, d: bell(f, max(d, 1.6), bright=0.95, damp=0.7, strike=0.3, rng=rng)
    # pendulum tick-tock: soft alternating D3/A2 plucks on the two beats
    for b in range(bars):
        base = b * bar
        place(ev, pluck(hz("D3"), 0.5, tau=0.18, bright=0.45), base, 0.3)
        place(ev, pluck(hz("A2"), 0.5, tau=0.18, bright=0.4), base + dq, 0.24)
    # motif statements: bar 2 in bronze, bar 11 an octave up and hushed
    events(ev, dq, toll_notes(2 * 2.0, 1.0, 1.0, octave=4), hb, gain=0.55)
    events(ev, dq, toll_notes(11 * 2.0, 1.0, 0.7, octave=5), hb, gain=0.32)
    # harp broken-chord answers between statements
    for b0, names in ((5, ("D3", "A3", "D4", "E4")),
                      (8, ("A2", "E3", "A3", "C4", "E4")),
                      (14, ("D3", "F3", "A3", "D4"))):
        for i, n in enumerate(names):
            place(ev, pluck(hz(n), 1.2, tau=0.6, bright=0.7),
                  b0 * bar + i * 2 * e8, 0.3)
    # wood-flute short answer after the first statement (bar 4)
    fl = lambda n, d: voice(hz(n), d, 1.0, vib=4.4, vdepth=0.007,
                            lpf=2600.0, rng=rng)
    for at, n, d in ((0.0, "F4", 1.2), (1.4, "E4", 1.0), (2.5, "D4", 1.8)):
        place(ev, fl(n, d * dq), 4 * bar + at * dq, 0.2)
    # moss drips - quiet wet ticks scattered through the court
    for _ in range(12):
        place(ev, tick(0.03, 1500.0, 5200.0, rng),
              float(rng.random()) * loop_s, 0.05)
    # one far second bell voice (the vertical court shaft, all reverb)
    far = fftfilt(bell(hz("D3"), 5.0, bright=0.8, damp=0.5, strike=0.0), lp=900.0)
    place(ev, far, 16 * bar, 0.2)
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.6), (hz("D3"), 0.3)),
                           loop_s + 1.0, lpf=700.0)
    lfo = 0.8 + 0.2 * np.sin(2 * math.pi * cyc(1.0 / bar, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.8) * lfo
    return wrap(ev, loop_n) + bed * 0.3, True


def r_ch01_boss() -> tuple[np.ndarray, bool]:
    # 锈冠守卫 (legacy filename boss_rust_crown_loop): 84 BPM 6/8 over the
    # same D material gone rusty - a gear-train ratchet ostinato with a
    # skipping tooth, rust-detuned twin bells that shear the motif off at A
    # (a grind eats the Bb) until bar 14 finally tolls it whole, anvil D/A
    # answers, D|Eb minor-second rub bed, and the crimson thread answering
    # late as the P2 signature hint. 21 bars = 30.0 s loop.
    rng = rng_for("ch01_boss")
    dq = 60.0 / 84.0
    bar = 2 * dq
    bars = 21
    loop_s = bars * bar         # 30.0 s
    e8 = dq / 3.0
    ev, loop_n = loop_canvas(loop_s)
    # gear ratchet: every eighth, 6/8 accents, a slipping tooth every 4 bars
    for b in range(bars):
        base = b * bar
        for e in range(6):
            g = 0.22 if e in (0, 3) else 0.1
            place(ev, tick(0.03, 900.0, 2600.0, rng), base + e * e8, g)
        if b % 4 == 3:
            place(ev, tick(0.05, 700.0, 1900.0, rng), base + 4 * e8 + 0.03, 0.26)
    # drive train: taiko downbeat, kick pickup, rusted anvil on D/A
    for b in range(bars):
        base = b * bar
        place(ev, taiko(0.45, rng), base, 0.75)
        place(ev, kick(0.2), base + dq, 0.45)
        if b % 2 == 1:
            place(ev, anvil(hz("D3") if b % 4 == 1 else hz("A2"), 0.5, rng),
                  base + dq, 0.4)
    # rust-detuned twin bells: motif sheared at A twice, whole at bar 14
    rb = lambda f, d: (bell(f, max(d, 1.2), 1.05, 1.2, 0.45, rng)
                       + bell(f * 1.017, max(d, 1.2), 0.9, 1.4, 0.0) * 0.4)
    grind = bandfilt(noise(0.7, rng), 500.0, 2400.0) * expdecay(0.7, 0.2)
    for b0, g in ((4, 0.4), (9, 0.35)):
        events(ev, dq, [(b0 * 2.0, "D4", 2.0, 1.0),
                        (b0 * 2.0 + 2.0, "A3", 1.5, 0.9)], rb, gain=0.5)
        place(ev, grind, (b0 * 2.0 + 3.4) * dq, g)
    events(ev, dq, toll_notes(14 * 2.0, 1.0, 1.0, octave=4), rb, gain=0.55)
    # rust tension: low string glide D->Eb (the crown tightening)
    for b0 in (6, 13, 20):
        gl = np.concatenate([np.full(n_of(1.2 * dq), hz("D3")),
                             np.linspace(hz("D3"), hz("Eb3"), n_of(0.8 * dq))])
        s = fftfilt(sine(gl, len(gl) / SR), lp=1000.0)
        env = np.ones(len(s))
        env[: n_of(0.15)] = np.linspace(0.0, 1.0, n_of(0.15))
        env[-n_of(0.25):] *= np.linspace(1.0, 0.0, n_of(0.25))
        place(ev, s * env, b0 * bar, 0.3)
    for b0 in (8, 16):  # crown glints
        place(ev, triangle_ping(0.9, hz("A6")), b0 * bar, 0.07)
    # crimson thread answers over the last stretch
    events(ev, dq, thread_notes(17 * 2.0, 0.5, 0.9),
           lambda f, d: pluck(f, d, tau=0.35, bright=0.8), gain=0.5)
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.5), (hz("Eb3"), 0.3)),
                           loop_s + 1.0, lpf=620.0)
    bed = seamless(bed_raw, loop_n, 0.6)
    rust_air = seamless(bandfilt(noise(loop_s + 1.0, rng), 320.0, 1500.0),
                        loop_n, 0.8)
    glfo = 0.5 + 0.5 * np.sin(2 * math.pi * cyc(0.11, loop_s)
                              * t_axis(loop_s) + 0.8) ** 2
    return wrap(ev, loop_n) + bed * 0.22 + rust_air * 0.05 * glfo, True


def r_ch02_explore() -> tuple[np.ndarray, bool]:
    # §2.3 铸雨渠: 92 BPM G minor, anvils hammer the motif pitches D-A,
    # cello surfaces once with Bb arriving by slide (rain glissando).
    rng = rng_for("ch02_explore")
    bpm, bars = 92.0, 12
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    # forge bass: 2+3+3 eighth grouping, low pluck
    for bar in range(bars):
        base = bar * 4 * spb
        root = "G2" if bar % 4 != 3 else "D3"
        for e in (0, 2, 5):
            x = pluck(hz(root), 0.5, tau=0.16, bright=0.5)
            place(ev, x, base + e * spb * 0.5, 0.85 if e == 0 else 0.55)
    # pitched anvils on the motif pitches, sparse
    for bar in range(bars):
        if bar % 2 == 0:
            f = hz("D4") if (bar // 2) % 2 == 0 else hz("A3")
            place(ev, anvil(f, 0.6, rng), bar * 4 * spb + 2 * spb, 0.34)
    # cello statement at bar 8: D..A then Bb by upward slide
    t0 = 8 * 4 * spb
    place(ev, horn(hz("D4"), 2.0 * spb, lpf=1000.0, attack=0.15), t0, 0.5)
    glide = np.concatenate([np.full(n_of(0.5 * spb), hz("A3")),
                            np.linspace(hz("A3"), hz("Bb3"), n_of(0.5 * spb)),
                            np.full(n_of(2.4 * spb), hz("Bb3"))])
    sl = fftfilt(sine(glide, len(glide) / SR), lp=1100.0)
    env = np.ones(len(sl))
    env[: n_of(0.2)] = np.linspace(0, 1, n_of(0.2))
    env[-n_of(0.6):] *= np.linspace(1, 0, n_of(0.6))
    place(ev, sl * env, t0 + 2.0 * spb, 0.42)
    # rain-tap ticks (music-side hint only; the real rain is the ambience bed)
    for _ in range(26):
        at = float(rng.random()) * loop_s
        place(ev, tick(0.03, 2600.0, 6800.0, rng), at, 0.05 + 0.05 * rng.random())
    # dark G minor bed
    bed_raw = sustain_tone(((hz("G2"), 1.0), (hz("D3"), 0.7), (hz("Bb3"), 0.28)),
                           loop_s + 1.0, lpf=750.0)
    lfo = 0.75 + 0.25 * np.sin(2 * math.pi * cyc(0.09, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.8) * lfo
    return wrap(ev, loop_n) + bed * 0.4, True


def r_ch03_explore() -> tuple[np.ndarray, bool]:
    # §2.4 盐白档案馆: 66 BPM, celesta states the motif, left hand answers in
    # retrograde two beats late (the copying archive), no percussion.
    rng = rng_for("ch03_explore")
    bpm, bars = 66.0, 8
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    cel = lambda f, d: celesta(f, max(d, 0.8), rng)
    for start, vel in ((1 * 4, 1.0), (5 * 4, 0.8)):
        events(ev, spb, toll_notes(start, 1.0, vel, octave=5), cel, gain=0.5)
        # retrograde imitation: Bb-A-D, two beats late, one octave down
        retro = [(start + 2.0, "Bb3", 1.5, 0.6), (start + 3.5, "A3", 0.5, 0.5),
                 (start + 4.0, "D4", 2.0, 0.55)]
        events(ev, spb, retro, lambda f, d: pluck(f, d, tau=0.6, bright=0.6), gain=0.5)
    # quill-scribe harpsichord murmur (bars 3-4, 7-8)
    for start in (2 * 4, 6 * 4):
        for i, name in enumerate(("A3", "C4", "E4", "B3", "C4", "E4", "A4", "E4")):
            events(ev, spb, [(start + i * 0.5, name, 0.45, 0.28)],
                   lambda f, d: pluck(f, d, tau=0.12, bright=0.9))
    # one lydian sparkle (D#5) - the bright lie in the salt
    events(ev, spb, [(6 * 4 + 2, "D#5", 1.5, 0.3)], cel)
    bed_raw = sustain_tone(((hz("A3"), 0.8), (hz("E4"), 0.5)), loop_s + 1.0,
                           lpf=2600.0, detune=0.002)
    lfo = 0.7 + 0.3 * np.sin(2 * math.pi * cyc(0.07, loop_s) * t_axis(loop_s) + 1.0)
    bed = seamless(bed_raw, loop_n, 0.8) * lfo
    return wrap(ev, loop_n) + bed * 0.16, True


def r_ch04_explore() -> tuple[np.ndarray, bool]:
    # §2.5 断弦温室: 58 BPM rubato, 5/4+6/4 pairs; the motif is cut apart by
    # rests, Bb caught by glass harmonics; a distant wordless voice surfaces.
    rng = rng_for("ch04_explore")
    spb = 60.0 / 58.0
    beats = 33  # three 5/4+6/4 pairs
    loop_s = beats * spb
    ev, loop_n = loop_canvas(loop_s)
    pz = lambda f, d: pluck(f, max(d, 0.5), tau=0.4, bright=0.65)
    # fragmented motif: D ... (break) A ... (break) Bb as glass
    for t0, vel in ((0.0, 1.0), (16.0, 0.75)):
        events(ev, spb, [(t0 + 0.5, "D4", 1.2, vel)], pz, gain=0.6)
        events(ev, spb, [(t0 + 5.5, "A3", 1.0, vel * 0.9)], pz, gain=0.6)
        place(ev, glass_harmonic(hz("Bb4"), 3.2 * spb, 0.5), (t0 + 8.5) * spb, vel)
    # glass swells on the open-string harmonic pool (E-A-D-G)
    for at, name, durb in ((2.0, "E4", 4.0), (13.0, "G4", 4.0), (24.0, "B4", 5.0)):
        place(ev, glass_harmonic(hz(name), durb * spb, 0.4), at * spb, 0.8)
    # snap pizzicato splinters + col legno ticks
    scale = ("E3", "G3", "A3", "B3", "D4", "E4")
    for _ in range(7):
        at = float(rng.random()) * (beats - 2)
        name = scale[int(rng.integers(len(scale)))]
        place(ev, snap_pizz(hz(name), 0.5, rng), at * spb, 0.16 + 0.1 * rng.random())
    for _ in range(10):
        place(ev, tick(0.03, 1400.0, 4200.0, rng), float(rng.random()) * loop_s, 0.06)
    # the broken-string singer, far off in the wet glass air
    t0 = 26.0 * spb
    for at, name, durb in ((0.0, "E4", 2.0), (2.1, "G4", 2.0), (4.2, "F#4", 2.6)):
        v = voice(hz(name), durb * spb, 0.8, rng=rng)
        echoes(ev, v, t0 + at * spb, 0.22, delays=((0.24, 0.5), (0.51, 0.26), (0.83, 0.12)))
    bed_raw = sustain_tone(((hz("E3"), 0.9), (hz("B3"), 0.4)), loop_s + 1.0, lpf=900.0)
    lfo = 0.65 + 0.35 * np.sin(2 * math.pi * cyc(0.06, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.8) * lfo
    return wrap(ev, loop_n) + bed * 0.2, True


def r_ch05_explore() -> tuple[np.ndarray, bool]:
    # §2.6 黑曜巡礼路: 100 BPM march, D phrygian; the motif augmented into a
    # low horn ostinato (D-A-Eb), ghost snare only on weak beats.
    rng = rng_for("ch05_explore")
    bpm, bars = 100.0, 14
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    hn = lambda f, d: horn(f, d, lpf=1100.0, attack=0.1)
    for pair in range(bars // 2):
        b0 = pair * 8.0
        events(ev, spb, [(b0, "D3", 2.0, 0.9), (b0 + 2.0, "A2", 2.0, 0.8),
                         (b0 + 4.0, "Eb3", 3.0, 0.85)], hn, gain=0.5)
    # ghost snare weak-beat brushes, muffled field drum
    for bar in range(bars):
        for off, vel in ((1.5, 0.1), (2.5, 0.08), (3.5, 0.13)):
            place(ev, snare(0.16, 1500.0, rng), (bar * 4 + off) * spb, vel)
        if bar % 4 == 0:
            place(ev, snare(0.22, 1700.0, rng), bar * 4 * spb, 0.2)
    # timpani mile-posts + one distant male-choir swell
    for bar in (0, 8):
        place(ev, timpani(hz("D2"), 1.4, rng), bar * 4 * spb, 0.5)
    sw = voice(hz("D3"), 6 * spb, 0.9, vdepth=0.006, lpf=900.0, rng=rng)
    place(ev, sw, 10 * 4 * spb, 0.2)
    place(ev, voice(hz("A2"), 6 * spb, 0.9, vdepth=0.006, lpf=800.0, rng=rng),
          10 * 4 * spb, 0.16)
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.6)), loop_s + 1.0, lpf=500.0)
    lfo = 0.8 + 0.2 * np.sin(2 * math.pi * cyc(0.08, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.8) * lfo
    return wrap(ev, loop_n) + bed * 0.32, True


def r_ch06_explore() -> tuple[np.ndarray, bool]:
    # §2.7 寂冠核心: organized silence. Child voice sings only D and Bb
    # (the fourth is gone - the pendulum stopped); one impossible far bell.
    rng = rng_for("ch06_explore")
    loop_s = 32.0
    ev, loop_n = loop_canvas(loop_s)
    ch = lambda name, dur, vd: voice(hz(name), dur, 1.0, vib=5.4, vdepth=vd,
                                     lpf=4200.0, rng=rng)
    place(ev, ch("D5", 3.6, 0.008), 3.0, 0.5)
    place(ev, ch("Bb4", 4.2, 0.01), 11.0, 0.45)
    place(ev, ch("D5", 3.0, 0.006), 21.5, 0.3)
    # the far wet D2 bell (once per loop, all reverb, almost no attack)
    far = fftfilt(bell(hz("D2"), 6.0, bright=0.7, damp=0.5, strike=0.0), lp=620.0)
    echoes(ev, far, 16.5, 0.4, delays=((0.9, 0.55), (2.1, 0.3), (3.6, 0.14)))
    # air-pressure bed + faint single-tone tinnitus
    air = seamless(fftfilt(noise(loop_s + 1.0, rng), lp=260.0), loop_n, 0.8)
    hiss = seamless(bandfilt(noise(loop_s + 1.0, rng), 7500.0, 11000.0), loop_n, 0.8)
    tin = sine(hz("E6"), loop_s, 1.0)
    tlfo = 0.5 + 0.5 * np.sin(2 * math.pi * cyc(0.05, loop_s) * t_axis(loop_s))
    # the organized silence stays *analog*: the bed sits just above -50 dBFS
    # in the final mix so no window ever reads as a dropout
    return wrap(ev, loop_n) + air * 0.12 + hiss * 0.012 + tin * 0.02 * tlfo, True


# combat layer stems: percussion + tension sustains at the chapter tempo

def r_ch01_combat() -> tuple[np.ndarray, bool]:
    # 72 BPM 6/8 hand drums + low-string staccato under the bronze court.
    rng = rng_for("ch01_combat")
    dq = 60.0 / 72.0            # dotted-quarter pulse
    bar = 2 * dq
    bars = 18
    loop_s = bars * bar         # 30.0 s
    ev, loop_n = loop_canvas(loop_s)
    e8 = dq / 3.0
    for b in range(bars):
        base = b * bar
        place(ev, taiko(0.4, rng), base, 0.8)
        place(ev, snare(0.14, 1900.0, rng), base + 3 * e8, 0.3)
        place(ev, tick(0.03, 3000.0, 8000.0, rng), base + 2 * e8, 0.12)
        place(ev, tick(0.03, 3000.0, 8000.0, rng), base + 5 * e8, 0.14)
        root = hz("D3") if b % 2 == 0 else hz("A2")
        place(ev, pluck(root, 0.3, tau=0.08, bright=0.5), base + dq, 0.5)
        if b % 6 == 5:  # fill
            for k in range(3):
                place(ev, snare(0.1, 2100.0, rng), base + (3 + k) * e8, 0.22)
    bed_raw = sustain_tone(((hz("D3"), 1.0), (hz("A3"), 0.5)), loop_s + 1.0, lpf=900.0)
    trem = 0.7 + 0.3 * np.sin(2 * math.pi * cyc(6.0, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.6) * trem
    return wrap(ev, loop_n) + bed * 0.2, True


def r_ch02_combat() -> tuple[np.ndarray, bool]:
    # double-density foundry percussion + bowed minor-second rub (G|Ab).
    rng = rng_for("ch02_combat")
    bpm, bars = 92.0, 12
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    for b in range(bars):
        base = b * 4 * spb
        for beat in range(4):
            place(ev, kick(0.24), base + beat * spb, 0.75 if beat in (0, 2) else 0.5)
        for e in (0, 2, 5):  # forge accents kept from the explore layer
            f = (hz("D4"), hz("A3"), hz("G3"))[e % 3]
            place(ev, anvil(f, 0.4, rng), base + e * spb * 0.5, 0.3)
        place(ev, snare(0.18, 2600.0, rng), base + 1 * spb, 0.42)
        place(ev, snare(0.18, 2600.0, rng), base + 3 * spb, 0.5)
        for s in range(8):
            if rng.random() < 0.35:
                place(ev, tick(0.03, 4000.0, 9000.0, rng), base + s * spb * 0.5, 0.1)
    bed_raw = sustain_tone(((hz("G2"), 1.0), (hz("Ab2"), 0.55)), loop_s + 1.0, lpf=600.0)
    bed = seamless(bed_raw, loop_n, 0.6)
    return wrap(ev, loop_n) + bed * 0.22, True


def r_ch03_combat() -> tuple[np.ndarray, bool]:
    # §2.4: still no drums - tension comes from density: racing sixteenth
    # harpsichord cells + high glass tremors over an anxious pad.
    rng = rng_for("ch03_combat")
    bpm, bars = 66.0, 8
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    cell = ("A3", "C4", "E4", "D#4", "E4", "C4", "B3", "C4")
    for b in range(bars):
        base = b * 4 * spb
        for s in range(16):
            name = cell[s % len(cell)]
            vel = 0.32 if s % 4 == 0 else 0.18
            oct_up = 2.0 if b % 4 == 3 and s >= 8 else 1.0
            place(ev, pluck(hz(name) * oct_up, 0.2, tau=0.07, bright=0.95),
                  base + s * spb * 0.25, vel)
        if b % 2 == 1:  # glass tremor burst
            for k in range(10):
                f = hz("E6") if k % 2 == 0 else hz("D#6")
                place(ev, celesta(f, 0.3, rng), base + 2 * spb + k * 0.045, 0.1)
    bed_raw = sustain_tone(((hz("A2"), 1.0), (hz("E3"), 0.6), (hz("D#4"), 0.2)),
                           loop_s + 1.0, lpf=1600.0)
    lfo = 0.7 + 0.3 * np.sin(2 * math.pi * cyc(0.14, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.6) * lfo
    return wrap(ev, loop_n) + bed * 0.2, True


def r_ch04_combat() -> tuple[np.ndarray, bool]:
    # Bartok snaps + muted woodblock in the limping 5/4|6/4 pairs.
    rng = rng_for("ch04_combat")
    spb = 60.0 / 58.0
    beats = 33
    loop_s = beats * spb
    ev, loop_n = loop_canvas(loop_s)
    accents = []
    b = 0.0
    for pair in range(3):
        accents += [(b + x) for x in (0.0, 3.0)]          # 5/4 bar
        accents += [(b + 5.0 + x) for x in (0.0, 2.0, 4.0)]  # 6/4 bar
        b += 11.0
    scale = ("E2", "E3", "G3", "A3", "B3", "D4")
    for i, at in enumerate(accents):
        name = scale[i % len(scale)]
        place(ev, snap_pizz(hz(name), 0.45, rng), at * spb, 0.6)
    for s in range(int(beats * 2)):
        if rng.random() < 0.6:
            place(ev, tick(0.035, 1200.0, 3400.0, rng), s * spb * 0.5, 0.14)
    for _ in range(5):  # glass shards
        f = hz("B5") * (1.0 + 0.3 * rng.random())
        place(ev, celesta(f, 0.5, rng), float(rng.random()) * loop_s, 0.12)
    bed_raw = sustain_tone(((hz("E2"), 1.0), (hz("B2"), 0.5)), loop_s + 1.0, lpf=520.0)
    swell = 0.6 + 0.4 * np.sin(2 * math.pi * cyc(0.09, loop_s) * t_axis(loop_s))
    bed = seamless(bed_raw, loop_n, 0.6) * swell
    return wrap(ev, loop_n) + bed * 0.26, True


def r_ch05_combat() -> tuple[np.ndarray, bool]:
    # full field-snare march + horn stabs + low male drone (the mustered dead).
    rng = rng_for("ch05_combat")
    bpm, bars = 100.0, 14
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    for b in range(bars):
        base = b * 4 * spb
        for s in range(16):
            vel = 0.42 if s % 4 == 0 else (0.26 if s % 2 == 0 else 0.13)
            place(ev, snare(0.13, 2400.0, rng), base + s * spb * 0.25, vel)
        place(ev, taiko(0.5, rng), base, 0.7)
        place(ev, taiko(0.4, rng), base + 2 * spb, 0.5)
        if b % 2 == 0:
            st = horn(hz("D3"), 1.0 * spb, lpf=1500.0, attack=0.03)
            st2 = horn(hz("Eb3"), 1.0 * spb, lpf=1500.0, attack=0.03)
            place(ev, st, base, 0.4)
            place(ev, st2, base, 0.26)
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.55)), loop_s + 1.0, lpf=420.0)
    bed = seamless(bed_raw, loop_n, 0.6)
    return wrap(ev, loop_n) + bed * 0.3, True


def r_ch06_combat() -> tuple[np.ndarray, bool]:
    # §2.7: the silent city fights without music - this stem is a near-empty
    # dread bed (sub pulses + air) so stacking it barely "adds" anything.
    rng = rng_for("ch06_combat")
    loop_s = 32.0
    ev, loop_n = loop_canvas(loop_s)
    for k in range(16):
        # long-tailed sub pulses: the decay bridges the 2 s spacing so the
        # bed never collapses to near-silence (loop-seam energy floor)
        x = sine(46.0, 1.6) * expdecay(1.6, 0.45)
        place(ev, x, k * 2.0, 0.9 if k % 4 == 0 else 0.6)
    for _ in range(4):
        sh = bandfilt(noise(0.8, rng), 5200.0, 9000.0) * expdecay(0.8, 0.2)
        place(ev, sh, float(rng.random()) * loop_s, 0.05)
    air = seamless(fftfilt(noise(loop_s + 1.0, rng), lp=200.0), loop_n, 0.8)
    tin = sine(hz("D6"), loop_s, 1.0) * (0.4 + 0.6 * np.sin(
        2 * math.pi * cyc(0.06, loop_s) * t_axis(loop_s)) ** 2)
    deep = seamless(sustain_tone(((hz("D1"), 1.0),), loop_s + 1.0, lpf=80.0),
                    loop_n, 0.8)
    return wrap(ev, loop_n) + air * 0.08 + tin * 0.01 + deep * 0.12, True


# boss loops

def r_ch02_boss() -> tuple[np.ndarray, bool]:
    # §3.3 双剪断誓: 138 BPM G minor; 2-vs-3 hemiola (cut vs stitch), the
    # cello motif always sheared off at A, thread theme answers late (P2 hint).
    rng = rng_for("ch02_boss")
    bpm, bars = 138.0, 18
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    ost = ("G3", "Bb3", "D4", "Bb3")
    for b in range(bars):
        base = b * 4 * spb
        shift = 2.0 ** (1.0 / 12.0) if b >= 12 else 1.0  # last third pushed to Ab
        for beat in range(4):
            place(ev, kick(0.2), base + beat * spb, 0.8 if beat == 0 else 0.5)
            place(ev, pluck(hz(ost[beat]) * shift, 0.3, tau=0.09, bright=0.8),
                  base + beat * spb, 0.5)
            place(ev, pluck(hz(ost[beat]) * shift, 0.24, tau=0.07, bright=0.8),
                  base + (beat + 0.5) * spb, 0.3)
        place(ev, anvil(hz("D4") * shift if b % 2 == 0 else hz("A3") * shift,
                        0.4, rng), base, 0.4)
        if 8 <= b < 12:  # hemiola: accents every 3 eighths against the 2s
            for e in range(0, 8, 3):
                place(ev, anvil(hz("G4"), 0.25, rng), base + e * spb * 0.5, 0.3)
                place(ev, tick(0.03, 5000.0, 10000.0, rng), base + e * spb * 0.5, 0.2)
    # the motif sheared at A: D...A then a scissor snip, twice
    for b in (5, 14):
        t0 = b * 4 * spb
        place(ev, horn(hz("D4"), 1.6 * spb, lpf=1200.0, attack=0.08), t0, 0.5)
        place(ev, horn(hz("A3"), 0.7 * spb, lpf=1200.0, attack=0.04), t0 + 1.6 * spb, 0.46)
        snip = bandfilt(noise(0.05, rng), 2600.0, 9500.0) * expdecay(0.05, 0.012)
        place(ev, snip, t0 + 2.35 * spb, 0.55)
    # thread theme over the shifted final third
    events(ev, spb, thread_notes(12 * 4 + 0.0, 1.0, 0.5),
           lambda f, d: pluck(f, d, tau=0.35, bright=0.75), gain=0.6)
    bed_raw = sustain_tone(((hz("G2"), 1.0), (hz("D3"), 0.5)), loop_s + 1.0, lpf=700.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.18, True


def r_ch03_boss() -> tuple[np.ndarray, bool]:
    # §3.4 复写的军役: 120 BPM; a harpsichord cell self-copies into a stacking
    # canon (max 4 voices), then the whole music plays in retrograde.
    rng = rng_for("ch03_boss")
    bpm, bars = 120.0, 16
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    cell = [(0.0, "A3", 0.5, 1.0), (0.5, "C4", 0.5, 0.7), (1.0, "E4", 0.5, 0.85),
            (1.5, "D#4", 0.5, 0.7), (2.0, "E4", 0.5, 0.8), (2.5, "C4", 0.5, 0.65),
            (3.0, "B3", 1.0, 0.8), (4.0, "A3", 0.5, 0.9), (4.5, "E4", 0.5, 0.7),
            (5.0, "C5", 1.0, 0.8), (6.0, "B4", 1.0, 0.75), (7.0, "A4", 1.0, 0.8)]
    hp_i = lambda f, d: pluck(f, d, tau=0.14, bright=0.95)
    # first half: canon builds - each copy 4 beats later, an octave apart
    for voice_i in range(4):
        t0 = voice_i * 4.0
        mul = (1.0, 2.0, 0.5, 2.0)[voice_i]
        g = (0.5, 0.34, 0.4, 0.24)[voice_i]
        for rep in range(2):
            events(ev, spb, [(t0 + rep * 12.0 + b_, n, d_, v) for b_, n, d_, v in cell],
                   lambda f, d: hp_i(f * mul, d), gain=g)
    # second half: retrograde restatement (the archive plays you backwards)
    retro = sorted(((8.0 - b_ - d_, n, d_, v) for b_, n, d_, v in cell))
    for voice_i in range(3):
        t0 = 32.0 + voice_i * 4.0
        mul = (1.0, 2.0, 0.5)[voice_i]
        g = (0.5, 0.3, 0.38)[voice_i]
        for rep in range(2):
            events(ev, spb, [(t0 + rep * 12.0 + b_, n, d_, v) for b_, n, d_, v in retro],
                   lambda f, d: hp_i(f * mul, d), gain=g)
    # glass scythe line + one legion choir hit at the flip point
    for b in range(0, bars, 4):
        for k, name in enumerate(("E6", "C6", "B5", "A5")):
            place(ev, celesta(hz(name), 0.5, rng), (b * 4 + k) * spb, 0.16)
    ch_hit = voice(hz("A2"), 2.0, 1.0, vdepth=0.004, lpf=800.0, rng=rng)
    place(ev, ch_hit, 32.0 * spb, 0.5)
    bed_raw = sustain_tone(((hz("A2"), 1.0), (hz("E3"), 0.5)), loop_s + 1.0, lpf=1200.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.16, True


def r_ch04_boss() -> tuple[np.ndarray, bool]:
    # §3.5 根上帕萨卡利亚: 69 BPM passacaglia - an 8-bar organ ground bass that
    # never stops, with stacked variations above (pizz / glass / col legno).
    rng = rng_for("ch04_boss")
    bpm, bars = 69.0, 8
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    ground = (("E2", 0), ("C2", 8), ("D2", 16), ("B1", 24))
    for name, beat in ground:
        x = organ(hz(name), 8.2 * spb, lpf=1900.0)
        place(ev, x, beat * spb, 0.62)
        place(ev, organ(hz(name) * 2.0, 8.2 * spb, lpf=2400.0), beat * spb, 0.2)
    # variation 1: snap pizz answering on offbeats (bars 1-4)
    for i, (beat, name) in enumerate(((1.5, "E3"), (3.5, "G3"), (5.5, "B3"),
                                      (7.5, "E4"), (9.5, "G3"), (11.5, "C4"),
                                      (13.5, "B3"), (15.5, "E3"))):
        place(ev, snap_pizz(hz(name), 0.5, rng), beat * spb, 0.4)
    # variation 2: glass harmonic halo (bars 5-8)
    for beat, name, durb in ((16.0, "B4", 6.0), (22.0, "G4", 5.0), (27.0, "E4", 4.5)):
        place(ev, glass_harmonic(hz(name), durb * spb, 0.4), beat * spb, 0.7)
    # variation 3: col legno ticks all through, denser toward the wall-push
    for s in range(64):
        if rng.random() < 0.28 + 0.3 * (s / 64.0):
            place(ev, tick(0.035, 1100.0, 3000.0, rng), s * spb * 0.5, 0.12)
    # the singer resists in the highest voice near the loop's end (P2 seed)
    place(ev, voice(hz("E5"), 5.0 * spb, 0.9, rng=rng), 26.5 * spb, 0.2)
    bed_raw = sustain_tone(((hz("E2"), 0.8), (hz("B2"), 0.4)), loop_s + 1.0, lpf=460.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.2, True


def r_ch05_boss() -> tuple[np.ndarray, bool]:
    # §3.6 破镜圆舞曲: 3/4 at 60 bars/min; detuned wedding music box, string
    # waltz, mirrored (inverted) answer in the second half, ghost snare grows.
    rng = rng_for("ch05_boss")
    bar = 1.0
    bars = 32
    loop_s = bars * bar
    spb = bar / 3.0
    ev, loop_n = loop_canvas(loop_s)
    # oom-pah-pah
    for b in range(bars):
        base = b * bar
        place(ev, taiko(0.4, rng), base, 0.5)
        for beat in (1, 2):
            for name in ("D3", "F3", "A3"):
                place(ev, pluck(hz(name), 0.28, tau=0.08, bright=0.6),
                      base + beat * spb, 0.2)
        if b % 2 == 0:
            place(ev, triangle_ping(0.8), base, 0.08)
    # detuned music-box wedding cell (bars 0-3, again at 16-17 in tune-lite)
    mb = [(0.0, "D5", 1.0, 0.9), (1.0, "Eb5", 1.0, 0.7), (2.0, "D5", 1.0, 0.8),
          (3.0, "A4", 2.0, 0.75), (5.0, "Bb4", 1.0, 0.6), (6.0, "A4", 3.0, 0.7)]
    events(ev, spb, mb, lambda f, d: musicbox(f, d, 0.02, rng), t0=0.0, gain=0.5)
    # waltz melody (D phrygian) bars 8-15, mirrored inversion bars 20-27
    mel = [(24.0, "D4", 2.0, 0.9), (26.0, "Eb4", 1.0, 0.7), (27.0, "F4", 2.0, 0.85),
           (29.0, "D4", 1.0, 0.7), (30.0, "C4", 2.0, 0.8), (32.0, "A3", 3.0, 0.85),
           (36.0, "F4", 2.0, 0.8), (38.0, "G4", 1.0, 0.7), (39.0, "A4", 3.0, 0.9),
           (42.0, "G4", 1.0, 0.7), (43.0, "F4", 2.0, 0.75), (45.0, "D4", 3.0, 0.85)]
    hn = lambda f, d: horn(f, d, lpf=1600.0, attack=0.06)
    events(ev, spb, mel, hn, gain=0.36)
    d4 = hz("D4")
    inv = [(b_ + 36.0, d4 * d4 / (hz(n) if isinstance(n, str) else n), d_, v)
           for b_, n, d_, v in mel]  # mirror around D4
    events(ev, spb, inv, hn, gain=0.3)
    # ghost snare grows in the second half (she is still the commander)
    for b in range(16, bars):
        for beat, vel in ((1.5, 0.1), (2.5, 0.16)):
            place(ev, snare(0.14, 1600.0, rng), b * bar + beat * spb,
                  vel * (0.5 + (b - 16) / 32.0))
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.5)), loop_s + 1.0, lpf=480.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.2, True


def r_ch06_boss() -> tuple[np.ndarray, bool]:
    # §3.7 六城点名 quodlibet: 116 BPM roll-call of the five chapter sounds,
    # key-rain celesta, then the motif forced into a tutti unison.
    rng = rng_for("ch06_boss")
    bpm, bars = 116.0, 16
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    # bars 0-1 ch1: bronze bells state the motif
    events(ev, spb, toll_notes(0.0, 1.0, 1.0, octave=5),
           lambda f, d: bell(f, max(d, 1.2), 1.05, 1.1, 0.4, rng), gain=0.5)
    # bars 2-3 ch2: anvil forge rhythm
    for e, f in ((8.0, "D4"), (9.0, "A3"), (10.5, "D4"), (11.5, "G3"),
                 (12.5, "A3"), (14.0, "D4"), (15.0, "A3")):
        place(ev, anvil(hz(f), 0.4, rng), e * spb, 0.4)
    # bars 4-5 ch3: celesta copying run
    for i, n in enumerate(("A4", "C5", "E5", "D#5", "E5", "C5", "B4", "A4")):
        place(ev, celesta(hz(n), 0.6, rng), (16 + i) * spb, 0.3)
        place(ev, celesta(hz(n) * 2, 0.5, rng), (17 + i) * spb, 0.14)
    # bars 6-7 ch4: broken snaps
    for beat, n in ((24.0, "E3"), (25.5, "G3"), (27.0, "B3"), (29.5, "E4"), (30.5, "B3")):
        place(ev, snap_pizz(hz(n), 0.5, rng), beat * spb, 0.5)
    # bars 8-9 ch5: horn + snare march
    place(ev, horn(hz("D3"), 3 * spb, lpf=1300.0), 32 * spb, 0.5)
    place(ev, horn(hz("Eb3"), 3 * spb, lpf=1300.0), 36 * spb, 0.4)
    for s in range(16):
        place(ev, snare(0.13, 2200.0, rng), (32 + s * 0.5) * spb,
              0.3 if s % 4 == 0 else 0.14)
    # bars 10-11: key-rain (celesta + small bells falling)
    for _ in range(22):
        at = (40.0 + 8.0 * rng.random()) * spb
        f = hz("D6") * 2.0 ** float(rng.integers(-5, 4) / 12.0)
        place(ev, celesta(f, 0.4, rng), at, 0.14 + 0.1 * rng.random())
    # bars 12-15: the crown commands - tutti unison motif, augmented
    tutti = toll_notes(48.0, 2.0, 1.0, octave=4)
    events(ev, spb, tutti, lambda f, d: bell(f, max(d, 1.5), 1.1, 0.9, 0.5, rng), gain=0.5)
    events(ev, spb, tutti, lambda f, d: horn(f, d, lpf=1500.0), gain=0.4)
    events(ev, spb, tutti, lambda f, d: organ(f, d, lpf=2200.0), gain=0.4)
    events(ev, spb, tutti,
           lambda f, d: voice(f * 2.0, d, 1.0, vdepth=0.006, lpf=2400.0, rng=rng), gain=0.3)
    for s in range(32):  # snare roll under the command
        place(ev, snare(0.1, 2400.0, rng), (48 + s * 0.5) * spb, 0.1 + 0.12 * (s / 32.0))
    for beat in range(0, 64, 2):  # heartbeat kicks throughout
        place(ev, kick(0.22), beat * spb, 0.5)
    bed_raw = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.5)), loop_s + 1.0, lpf=520.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.18, True


# final boss movements

def r_final_mvt1() -> tuple[np.ndarray, bool]:
    # §3.8-I 无声: heartbeat + breath + a muted giant bell every ~15 s
    # (struck but not allowed to ring).
    rng = rng_for("final_mvt1")
    loop_s = 30.0
    ev, loop_n = loop_canvas(loop_s)
    for k in range(30):  # 60 BPM heartbeat
        lub = sine(56.0, 0.11) * np.sin(np.linspace(0, math.pi, n_of(0.11))) ** 2
        dub = sine(44.0, 0.09) * np.sin(np.linspace(0, math.pi, n_of(0.09))) ** 2
        place(ev, lub, k * 1.0, 0.5)
        place(ev, dub, k * 1.0 + 0.19, 0.36)
    for at in (1.0, 16.0):  # the muffled toll: choked low bell
        b = fftfilt(bell(hz("D2"), 3.0, bright=0.6, damp=0.8, strike=0.9, rng=rng),
                    lp=340.0)
        choke = np.ones(len(b))
        c0 = n_of(1.1)
        choke[c0:] *= np.linspace(1.0, 0.0, len(b) - c0) ** 2
        place(ev, b * choke, at, 0.9)
    for k in range(5):  # slow breathing; the extra cycle carries the loop seam
        br = fftfilt(noise(2.4, rng), lp=800.0) * np.sin(
            np.linspace(0, math.pi, n_of(2.4))) ** 2
        place(ev, br, 2.2 + k * 6.6, 0.05)
    air = seamless(fftfilt(noise(loop_s + 1.0, rng), lp=180.0), loop_n, 0.8)
    # continuous D1 pressure floor: keeps the "silence" analog, not digital,
    # and holds the last pre-seam second within 9 dB of the active RMS
    sub = seamless(sustain_tone(((hz("D1"), 1.0),), loop_s + 1.0, lpf=90.0),
                   loop_n, 0.8)
    return wrap(ev, loop_n) + air * 0.07 + sub * 0.16, True


def r_final_mvt2() -> tuple[np.ndarray, bool]:
    # §3.8-II 万声: 148 BPM, every chapter instrument at once; the motif
    # stacked at three speeds while the black tide pushes up from below.
    rng = rng_for("final_mvt2")
    bpm, bars = 148.0, 18
    spb = 60.0 / bpm
    loop_s = bars * 4 * spb
    ev, loop_n = loop_canvas(loop_s)
    for b in range(bars):
        base = b * 4 * spb
        for beat in range(4):
            place(ev, kick(0.2), base + beat * spb, 0.7 if beat % 2 == 0 else 0.45)
        place(ev, snare(0.14, 2600.0, rng), base + 1 * spb, 0.4)
        place(ev, snare(0.14, 2600.0, rng), base + 3 * spb, 0.48)
        place(ev, anvil(hz("D4") if b % 2 else hz("A3"), 0.35, rng), base, 0.3)
    # motif at three speeds: bells (original), horns (augmented), celesta (diminished)
    for start in (0.0, 24.0, 48.0):
        events(ev, spb, toll_notes(start, 1.0, 1.0, octave=5),
               lambda f, d: bell(f, max(d, 1.0), 1.1, 1.1, 0.4, rng), gain=0.42)
    events(ev, spb, toll_notes(0.0, 4.0, 1.0, octave=3),
           lambda f, d: horn(f, d, lpf=1200.0, attack=0.12), gain=0.4)
    for start in range(0, 72, 12):
        events(ev, spb, toll_notes(float(start), 0.5, 0.8, octave=6),
               lambda f, d: celesta(f, max(d, 0.5), rng), gain=0.26)
    # snaps + thread theme stitching through the top
    for beat in (6.0, 14.0, 22.0, 38.0, 54.0):
        place(ev, snap_pizz(hz("E3"), 0.4, rng), beat * spb, 0.4)
    events(ev, spb, thread_notes(32.0, 2.0, 0.9),
           lambda f, d: pluck(f * 2.0, d, tau=0.4, bright=0.8), gain=0.5)
    # child voice holds D over everything
    place(ev, voice(hz("D5"), 10 * spb, 1.0, vdepth=0.008, lpf=3600.0, rng=rng),
          40 * spb, 0.3)
    # black-tide whole-tone cluster rising from below
    clus_raw = sustain_tone(((hz("C3"), 0.9), (hz("D3"), 0.8), (hz("E3"), 0.7),
                             (hz("F#3"), 0.6)), loop_s + 1.0, lpf=700.0)
    rise = 0.35 + 0.65 * np.sin(2 * math.pi * cyc(0.06, loop_s) * t_axis(loop_s) - 1.2) ** 2
    clus = seamless(clus_raw, loop_n, 0.5) * rise
    bed_raw = sustain_tone(((hz("D2"), 1.0),), loop_s + 1.0, lpf=300.0)
    bed = seamless(bed_raw, loop_n, 0.5)
    return wrap(ev, loop_n) + clus * 0.14 + bed * 0.24, True


def r_final_mvt3() -> tuple[np.ndarray, bool]:
    # §3.8-III 抉择: the music hangs on an unresolved dominant (A7) long tone,
    # handed to the three doors - loops holding its breath.
    rng = rng_for("final_mvt3")
    loop_s = 30.0
    ev, loop_n = loop_canvas(loop_s)
    chord = ((hz("A2"), 1.0), (hz("E3"), 0.6), (hz("G3"), 0.45), (hz("C#4"), 0.4))
    ped_raw = sustain_tone(chord, loop_s + 1.0, lpf=1500.0, detune=0.0035)
    swell = 0.55 + 0.45 * np.sin(2 * math.pi * cyc(0.066, loop_s) * t_axis(loop_s) - 0.7) ** 2
    ped = seamless(ped_raw, loop_n, 0.8) * swell
    # organ breath an octave below + shimmer pings above, never resolving
    org_raw = sustain_tone(((hz("A1"), 1.0),), loop_s + 1.0, lpf=380.0)
    org = seamless(org_raw, loop_n, 0.8)
    for at, name in ((4.0, "A5"), (11.0, "E6"), (19.0, "C#6"), (26.0, "A5")):
        place(ev, celesta(hz(name), 2.2, rng), at, 0.14)
    # soft timpani pressure that rises and wraps
    roll = fftfilt(noise(loop_s + 1.0, rng), lp=120.0)
    roll *= 0.4 + 0.6 * np.sin(2 * math.pi * cyc(0.033, loop_s) *
                               np.arange(len(roll)) / SR - 1.5) ** 2
    roll = seamless(roll, loop_n, 0.8)
    return wrap(ev, loop_n) + ped * 0.5 + org * 0.3 + roll * 0.18, True


# shrine lullabies (龛中眠: D-A-B natural, per-chapter timbre)

def r_ch01_lullaby() -> tuple[np.ndarray, bool]:
    rng = rng_for("lullaby01")
    unit, loop_s = 0.62, 21.0
    ev, loop_n = loop_canvas(loop_s)
    hb = lambda f, d: fftfilt(bell(f, max(d * 1.6, 2.0), 0.95, 0.8, 0.25, rng), lp=3400.0)
    lull_phrase(ev, 0.5, unit, hb, 0.9)
    lull_phrase(ev, 11.0, unit, hb, 0.6)
    # harp answer between phrases
    for i, n in enumerate(("D3", "A3", "D4", "F#4")):
        place(ev, pluck(hz(n), 1.4, tau=0.7, bright=0.7), 6.2 + i * 0.5, 0.3)
    bed = seamless(sustain_tone(((hz("D3"), 1.0), (hz("A3"), 0.5)),
                                loop_s + 1.0, lpf=800.0), loop_n, 0.8)
    return wrap(ev, loop_n) + bed * 0.12, True


def r_ch02_lullaby() -> tuple[np.ndarray, bool]:
    rng = rng_for("lullaby02")
    unit, loop_s = 0.55, 20.0
    ev, loop_n = loop_canvas(loop_s)
    mb = lambda f, d: musicbox(f, max(d * 1.4, 1.6), 0.018, rng)
    lull_phrase(ev, 0.4, unit, mb, 0.85)
    lull_phrase(ev, 10.4, unit, mb, 0.55)
    for k in range(18):  # tired clockwork behind the comb
        place(ev, tick(0.025, 1800.0, 4000.0, rng), 0.2 + k * 1.1, 0.05)
    # rain pushed outside the window + a faint warm hum keep the floor alive
    bed = seamless(fftfilt(noise(loop_s + 1.0, rng), lp=500.0), loop_n, 0.8)
    hum = seamless(sustain_tone(((hz("D3"), 0.7), (hz("A3"), 0.35)),
                                loop_s + 1.0, lpf=700.0), loop_n, 0.8)
    return wrap(ev, loop_n) + bed * 0.08 + hum * 0.05, True


def r_ch03_lullaby() -> tuple[np.ndarray, bool]:
    rng = rng_for("lullaby03")
    unit, loop_s = 0.6, 22.0
    ev, loop_n = loop_canvas(loop_s)
    cel = lambda f, d: celesta(f, max(d * 1.5, 1.6), rng)
    lull_phrase(ev, 0.5, unit, cel, 0.85)
    lull_phrase(ev, 11.5, unit, cel, 0.6)
    # the honest room: the left hand follows FORWARD (no retrograde here)
    low = lambda f, d: pluck(f * 0.5, max(d * 1.5, 1.6), tau=0.7, bright=0.6)
    lull_phrase(ev, 0.5 + 1.2, unit, low, 0.4)
    lull_phrase(ev, 11.5 + 1.2, unit, low, 0.3)
    bed = seamless(sustain_tone(((hz("A3"), 0.7), (hz("E4"), 0.35)),
                                loop_s + 1.0, lpf=2200.0), loop_n, 0.8)
    return wrap(ev, loop_n) + bed * 0.07, True


def r_ch04_lullaby() -> tuple[np.ndarray, bool]:
    # the only sung lullaby - the broken-string singer keeps watch (§2.5)
    rng = rng_for("lullaby04")
    unit, loop_s = 0.75, 24.0
    ev, loop_n = loop_canvas(loop_s)
    vo = lambda f, d: voice(f * 0.5, max(d * 1.1, 1.5), 1.0, vib=4.2,
                            vdepth=0.014, lpf=2800.0, rng=rng)
    lull_phrase(ev, 0.6, unit, vo, 0.9)
    lull_phrase(ev, 12.6, unit, vo, 0.62, b_dur=4.2)
    for i, n in enumerate(("E3", "B3", "G3")):  # sparse guitar-like cradle
        place(ev, pluck(hz(n), 1.8, tau=0.8, bright=0.6), 6.4 + i * 0.9, 0.24)
        place(ev, pluck(hz(n), 1.8, tau=0.8, bright=0.6), 18.4 + i * 0.9, 0.18)
    bed = seamless(sustain_tone(((hz("E3"), 0.8), (hz("B3"), 0.4)),
                                loop_s + 1.0, lpf=900.0), loop_n, 0.8)
    return wrap(ev, loop_n) + bed * 0.1, True


def r_ch05_lullaby() -> tuple[np.ndarray, bool]:
    # lights-out call: a single muted horn (§2.6)
    rng = rng_for("lullaby05")
    unit, loop_s = 0.7, 20.0
    ev, loop_n = loop_canvas(loop_s)
    hn = lambda f, d: horn(f * 0.5, max(d * 1.1, 1.4), lpf=820.0, attack=0.14)
    lull_phrase(ev, 0.5, unit, hn, 0.9)
    lull_phrase(ev, 10.5, unit, hn, 0.5)
    place(ev, timpani(hz("D2"), 1.6, rng), 8.4, 0.14)
    bed = seamless(sustain_tone(((hz("D2"), 1.0),), loop_s + 1.0, lpf=320.0),
                   loop_n, 0.8)
    return wrap(ev, loop_n) + bed * 0.14, True


def r_ch06_lullaby() -> tuple[np.ndarray, bool]:
    # the child hums it and finally reaches B natural - nearest to resolution
    rng = rng_for("lullaby06")
    unit, loop_s = 0.68, 21.0
    ev, loop_n = loop_canvas(loop_s)
    ch = lambda f, d: voice(f, max(d * 1.2, 1.6), 1.0, vib=5.2, vdepth=0.009,
                            lpf=4400.0, rng=rng)
    lull_phrase(ev, 0.6, unit, ch, 0.8, b_dur=4.5)
    # far echo of the same phrase, hushed
    lull_phrase(ev, 11.6, unit, lambda f, d: fftfilt(ch(f, d), lp=1800.0), 0.4, b_dur=4.5)
    air = seamless(fftfilt(noise(loop_s + 1.0, rng), lp=240.0), loop_n, 0.8)
    # the child's held breath: a faint D pedal keeps the hush analog between
    # phrases (no >500 ms dropout windows)
    hum = seamless(sustain_tone(((hz("D4"), 0.6), (hz("A3"), 0.3)),
                                loop_s + 1.0, lpf=1500.0), loop_n, 0.8)
    return wrap(ev, loop_n) + air * 0.2 + hum * 0.06, True


# endings (one-shots)

def r_ending_a() -> tuple[np.ndarray, bool]:
    # §3.8 A 重鸣: authentic cadence - the motif finally resolves Bb->A->D,
    # real bells peal in D major; the child still hangs on Bb at the end.
    rng = rng_for("ending_a")
    dur = 50.0
    x = silence(dur)
    big = lambda n, d: bell(hz(n), d, 1.05, 0.65, 0.5, rng)
    # solo statement, resolving for the first time
    for at, n, d, g in ((0.5, "Bb4", 3.0, 0.8), (3.2, "A4", 2.6, 0.75),
                        (5.6, "D5", 5.0, 0.95)):
        echoes(x, big(n, d), at, g)
    # organ + choir ground blooms in
    for at, n, g in ((8.0, "D3", 0.5), (8.0, "A3", 0.35), (8.0, "F#3", 0.3),
                     (24.0, "D3", 0.55), (24.0, "A3", 0.4), (24.0, "F#4", 0.28)):
        place(x, organ(hz(n), 12.0, lpf=2100.0), at, g)
    place(x, voice(hz("D4"), 9.0, 1.0, vdepth=0.007, lpf=2400.0, rng=rng), 20.0, 0.3)
    place(x, voice(hz("F#4"), 8.0, 1.0, vdepth=0.007, lpf=2600.0, rng=rng), 21.0, 0.24)
    # peal cascade
    peal = ("D5", "F#5", "A5", "D6", "A5", "F#5")
    for k in range(18):
        at = 10.0 + k * 1.35
        if at > 36.0:
            break
        n = peal[k % len(peal)]
        place(x, big(n, 3.5), at, 0.4 - 0.008 * k)
    for at in (12.0, 26.0):
        place(x, timpani(hz("D2"), 2.0, rng), at, 0.5)
    # two more resolved statements, tutti
    for t0 in (14.0, 28.0):
        for at, n, d, g in ((0.0, "Bb4", 2.2, 0.6), (2.0, "A4", 2.0, 0.56),
                            (3.8, "D5", 4.5, 0.7)):
            place(x, big(n, d), t0 + at, g)
            place(x, horn(hz(n), d * 0.8, lpf=1400.0), t0 + at, 0.3)
    # the thorn: the child keeps Bb, alone, as everything fades
    place(x, voice(hz("Bb4"), 6.0, 1.0, vib=5.0, vdepth=0.008, lpf=3800.0, rng=rng),
          43.0, 0.3)
    # warm ground under the farewell so the tail never dips to a dropout
    place(x, organ(hz("D2"), 11.0, lpf=900.0), 36.5, 0.22)
    place(x, organ(hz("A2"), 10.0, lpf=900.0), 37.0, 0.12)
    fade = np.ones(n_of(dur))
    fade[n_of(38.0):] = np.linspace(1.0, 0.0, n_of(dur) - n_of(38.0)) ** 1.3
    return x * fade, False


def r_ending_b() -> tuple[np.ndarray, bool]:
    # §3.8 B 断冠: deceptive cadence, then the string snaps and the black tide
    # floods - a thousand small voices speaking at once for the first time.
    rng = rng_for("ending_b")
    dur = 48.0
    x = silence(dur)
    # the motif tries to climb (D-A-Bb, then again on Eb - the dark step)
    events(x, 0.9, toll_notes(0.0, 1.0, 0.9, octave=4),
           lambda f, d: pluck(f, d, tau=0.5, bright=0.7), t0=0.5, gain=0.6)
    events(x, 0.9, [(0.0, "Eb4", 1.4, 0.9), (1.5, "Bb3", 0.5, 0.8),
                    (2.0, "B3", 2.0, 0.85)],
           lambda f, d: pluck(f, d, tau=0.5, bright=0.7), t0=5.5, gain=0.6)
    drone0 = sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.4)), 10.5, lpf=420.0)
    env0 = np.linspace(0.3, 1.0, n_of(10.5))
    place(x, drone0 * env0, 0.0, 0.3)
    # THE SNAP (10.6 s): crack + string whip-down + one second of nothing
    crack = bandfilt(noise(0.02, rng), 2000.0, 11000.0)
    place(x, crack, 10.6, 1.2)
    place(x, sine(np.linspace(820.0, 140.0, n_of(0.12)), 0.12) * expdecay(0.12, 0.05),
          10.62, 0.9)
    # a faint D2 after-ring carries the "one second of nothing" analog silence
    place(x, sine(hz("D2"), 1.7) * expdecay(1.7, 0.8), 10.68, 0.12)
    # black tide: whole-tone cluster + reversed bells + whisper flood
    clus = sustain_tone(((hz("C2"), 1.0), (hz("D2"), 0.9), (hz("E2"), 0.75),
                         (hz("F#2"), 0.6)), 30.0, lpf=520.0)
    surge = np.sin(np.linspace(0.0, math.pi, n_of(30.0))) ** 0.8
    surge *= 1.0 + 0.35 * np.sin(2 * math.pi * 0.11 * t_axis(30.0) + 1.0)
    place(x, clus * surge, 12.0, 0.5)
    for at, g in ((13.5, 0.5), (18.7, 0.42), (26.9, 0.5), (33.4, 0.34)):
        rb = fftfilt(bell(hz("D3"), 3.2, 0.9, 0.7, 0.0), lp=900.0)[::-1]
        place(x, rb, at, g)
    for k in range(9):  # many small voices, none intelligible
        at = 14.0 + 26.0 * float(rng.random())
        band = 700.0 + 2200.0 * float(rng.random())
        w = bandfilt(noise(2.6, rng), band, band * 2.2)
        w *= np.abs(fftfilt(noise(2.6, rng), lp=7.0)) * 6.0
        place(x, np.clip(w, -1.5, 1.5), at, 0.1)
    place(x, sine(hz("D1"), 20.0) * np.sin(np.linspace(0, math.pi, n_of(20.0))) ** 1.4,
          16.0, 0.55)
    # recede to a single deep pulse
    fade = np.ones(n_of(dur))
    fade[n_of(38.0):] = np.linspace(1.0, 0.0, n_of(dur) - n_of(38.0)) ** 1.6
    x *= fade
    # unfaded deep floor bridging the recede into the last pulse (no dropout)
    place(x, sine(hz("D1"), 7.0) * np.sin(np.linspace(0.0, math.pi, n_of(7.0))) ** 0.7,
          38.5, 0.12)
    place(x, sine(hz("D1"), 1.6) * expdecay(1.6, 0.5), 45.0, 0.4)
    return x, False


def r_ending_c() -> tuple[np.ndarray, bool]:
    # §3.8 C 绯线真结局: the Silent Toll and the crimson-thread theme sound
    # together at last; six chapter voices join one by one; Picardy D major.
    rng = rng_for("ending_c")
    dur = 58.0
    x = silence(dur)
    unit = 0.85
    bl = lambda f, d: bell(f, max(d * 1.4, 1.6), 1.0, 0.9, 0.35, rng)
    th = lambda f, d: pluck(f, max(d, 0.5), tau=0.45, bright=0.8)
    # duet statements every 8 s; a new chapter instrument joins each round
    joins = (
        None,
        lambda f, d: celesta(f * 2.0, max(d, 0.8), rng),          # ch3
        lambda f, d: musicbox(f * 2.0, max(d, 0.9), 0.012, rng),  # ch2
        lambda f, d: horn(f * 0.5, d, lpf=1100.0),                # ch5
        lambda f, d: voice(f, max(d, 1.2), 0.9, rng=rng),         # ch4/ch6
        lambda f, d: glass_harmonic(f, max(d, 1.4), 0.6),         # ch4 glass
    )
    for round_i in range(6):
        t0 = 1.0 + round_i * 8.0
        g = 0.42 + 0.05 * round_i
        events(x, unit, toll_notes(0.0, 1.0, 1.0, octave=4), bl, t0=t0, gain=g)
        events(x, unit, thread_notes(1.0, 0.8, 0.9), th, t0=t0, gain=g * 0.9)
        extra = joins[round_i]
        if extra is not None:
            events(x, unit, toll_notes(0.0, 1.0, 0.8, octave=5), extra,
                   t0=t0, gain=0.3)
    drone_env = 0.25 + 0.75 * np.sin(np.linspace(0.0, math.pi, n_of(51.0))) ** 0.6
    place(x, sustain_tone(((hz("D2"), 1.0), (hz("A2"), 0.5)), 51.0, lpf=500.0)
          * drone_env, 0.5, 0.3)
    # Picardy bloom: D major, both themes' last notes agree at last
    t0 = 49.0
    for n, g in (("D3", 0.6), ("F#3", 0.4), ("A3", 0.5), ("D4", 0.5),
                 ("F#4", 0.34), ("A4", 0.3), ("D5", 0.3)):
        place(x, bl(hz(n), 5.0), t0, g)
    place(x, organ(hz("D2"), 7.5, lpf=1600.0), t0, 0.4)
    place(x, voice(hz("F#4"), 6.0, 1.0, vdepth=0.008, lpf=3200.0, rng=rng), t0 + 0.4, 0.26)
    fade = np.ones(n_of(dur))
    fade[n_of(52.0):] = np.linspace(1.0, 0.0, n_of(dur) - n_of(52.0)) ** 1.2
    return x * fade, False


# bellway (§2.9)

def r_bellway_transit() -> tuple[np.ndarray, bool]:
    # 3/8 allegro: small handbells + plucks skip through a light-footed
    # variation of the motif (the one cheerful theme in the whole game).
    rng = rng_for("bellway_transit")
    bar = 0.6
    bars = 48
    loop_s = bars * bar
    e8 = bar / 3.0
    ev, loop_n = loop_canvas(loop_s)
    hb = lambda n, d: bell(hz(n), d, 1.15, 1.5, 0.35, rng)
    tune = ("D5", "A4", "B4", "D5", "E5", "D5", "B4", "A4",
            "D5", "F#5", "E5", "D5", "B4", "D5", "A4", "B4")
    for b in range(bars):
        base = b * bar
        n = tune[b % len(tune)]
        place(ev, hb(n, 0.7), base, 0.5)
        if b % 2 == 1:
            place(ev, hb("A5" if b % 8 == 7 else "F#5", 0.5), base + e8, 0.2)
        place(ev, pluck(hz("D3") if b % 4 < 2 else hz("A2"), 0.35, tau=0.12,
                        bright=0.6), base, 0.5)
        place(ev, tick(0.025, 4500.0, 9000.0, rng), base + 2 * e8, 0.12)
    for b in range(0, bars, 8):  # winch clicks - the ladder is working
        place(ev, tick(0.05, 900.0, 2400.0, rng), b * bar + e8, 0.2)
    bed = seamless(sustain_tone(((hz("D3"), 0.8), (hz("A3"), 0.5)),
                                loop_s + 1.0, lpf=1100.0), loop_n, 0.5)
    return wrap(ev, loop_n) + bed * 0.12, True


def r_bellway_depart() -> tuple[np.ndarray, bool]:
    rng = rng_for("bellway_depart")
    x = silence(2.8)
    for at, n in ((0.0, "D5"), (0.22, "A5"), (0.44, "B5")):
        place(x, bell(hz(n), 1.4, 1.15, 1.4, 0.4, rng), at, 0.7)
    # winch spin-up
    wn = bandfilt(noise(1.2, rng), 300.0, 1800.0)
    ramp = np.linspace(0.2, 1.0, n_of(1.2)) ** 1.5
    place(x, wn * ramp, 0.3, 0.25)
    place(x, pluck(hz("D4"), 1.2, tau=0.3, bright=0.7), 0.66, 0.5)
    place(x, bell(hz("A5"), 1.6, 1.1, 1.2, 0.3, rng), 1.1, 0.5)
    return x, False


def r_bellway_arrive() -> tuple[np.ndarray, bool]:
    rng = rng_for("bellway_arrive")
    x = silence(2.8)
    for at, n in ((0.0, "B5"), (0.22, "A5"), (0.44, "D5")):
        place(x, bell(hz(n), 1.4, 1.1, 1.4, 0.35, rng), at, 0.65)
    brake = bandfilt(noise(1.0, rng), 250.0, 1500.0)
    place(x, brake * np.linspace(1.0, 0.1, n_of(1.0)) ** 1.4, 0.25, 0.22)
    place(x, bell(hz("D6"), 1.5, 1.05, 1.1, 0.4, rng), 1.15, 0.55)
    place(x, pluck(hz("D3"), 1.0, tau=0.3, bright=0.6), 1.15, 0.4)
    return x, False


def r_black_tide_drone() -> tuple[np.ndarray, bool]:
    # §2.8: anti-music. D1 underwater drone, reversed bells, whisper clusters,
    # the motif surfacing only in retrograde. Fibonacci-ish surge spacing.
    rng = rng_for("black_tide")
    loop_s = 39.0
    ev, loop_n = loop_canvas(loop_s, 5.0)
    # reversed bell surges at 8 / 21 / 34 s (8-13-13 spacing wraps to 5)
    for at, g in ((8.0, 0.55), (21.0, 0.45), (34.0, 0.5)):
        rb = fftfilt(bell(hz("D2"), 4.5, 0.85, 0.6, 0.0), lp=760.0)[::-1]
        place(ev, rb, at, g)
        place(ev, fftfilt(bell(hz("A2"), 3.0, 0.8, 0.8, 0.0), lp=600.0)[::-1],
              at + 0.6, g * 0.4)
    # retrograde motif, drowned: Bb -> A -> D, far below
    events(ev, 1.4, [(0.0, "Bb2", 2.0, 0.8), (2.2, "A2", 1.4, 0.7),
                     (3.6, "D3", 3.0, 0.75)],
           lambda f, d: fftfilt(pluck(f, d * 1.5, tau=1.2, bright=0.5), lp=480.0),
           t0=13.0, gain=0.3)
    # beds: D1 drone with slow interference, drowned water noise, whispers
    t = t_axis(loop_s)
    d1 = hz("D1")
    drone = (sine(d1, loop_s, 1.0) + sine(d1 * 2.0, loop_s, 0.45)
             + sine(hz("A1"), loop_s, 0.28) + sine(d1 * 1.007, loop_s, 0.5))
    drone *= 0.65 + 0.35 * np.sin(2 * math.pi * cyc(0.077, loop_s) * t + 0.4)
    water = seamless(fftfilt(noise(loop_s + 1.2, rng), lp=170.0), loop_n, 1.0)
    water *= 0.6 + 0.4 * np.sin(2 * math.pi * cyc(0.128, loop_s) * t + 2.0)
    whisp_raw = bandfilt(noise(loop_s + 1.2, rng), 900.0, 2500.0)
    gate = np.abs(fftfilt(noise(loop_s + 1.2, rng), lp=1.3)) * 9.0
    whisp = seamless(whisp_raw * np.clip(gate, 0.0, 1.6), loop_n, 1.0)
    clus = sustain_tone(((hz("C2"), 0.8), (hz("D2"), 0.7), (hz("E2"), 0.55),
                         (hz("F#2"), 0.4)), loop_s + 1.0, lpf=300.0)
    clus = seamless(clus, loop_n, 1.0)
    mix = (wrap(ev, loop_n) + drone * 0.5 + water * 0.35 + whisp * 0.06
           + clus * 0.12)
    return fftfilt(mix, lp=1500.0), True


# --------------------------------------------------------------------- pack

# (key, builder, peak, bpm_or_None, category, recipe summary for inventory)
PACK = [
    ("ch01_cave_loop", r_ch01_explore, 0.45, 72,
     "explore", "§2.2苔钟庭真曲（沿用legacy文件名）：72BPM D多利亚6/8钟摆律动；管钟第2/11小节陈述动机，竖琴分解应答+木笛短句一次，D-A空五度drone按钟摆周期呼吸+苔间滴水，留白≥40%；30s与ch1战斗层同网格可叠加"),
    ("boss_rust_crown_loop", r_ch01_boss, 0.55, 84,
     "boss", "锈冠守卫（沿用legacy文件名）：84BPM 6/8齿轮棘轮八分ostinato+每4小节跳齿；锈蚀失谐双钟两次只唱到A即被研磨声吃掉B♭、第14小节才鸣全动机；铁砧D/A应答+D→E♭低弦上紧滑奏+D|E♭小二度摩擦垫，绯线主题末段迟到应答；30s"),
    ("ch02_rain_foundry_canal_explore_loop", r_ch02_explore, 0.45, 92,
     "explore", "92BPM G小调；2+3+3锻打低音+D/A音高化铁砧，大提琴质感浮出动机、B♭滑音进入，暗垫G-D-B♭"),
    ("ch03_saltwhite_archive_explore_loop", r_ch03_explore, 0.45, 66,
     "explore", "66BPM A小调利底亚色；钢片琴右手动机+左手迟两拍逆行，羽管键琴誊写背景，无打击"),
    ("ch04_broken_string_greenhouse_explore_loop", r_ch04_explore, 0.45, 58,
     "explore", "58BPM 5/4+6/4；动机被休止切碎，B♭由玻璃泛音接住，snap pizz碎片+远处无词女声"),
    ("ch05_obsidian_pilgrim_road_explore_loop", r_ch05_explore, 0.45, 100,
     "explore", "100BPM D弗里几亚行军；动机增值成号角ostinato D-A-E♭，军鼓只打弱拍幽灵音+男声齐唱远影"),
    ("ch06_silent_crown_core_explore_loop", r_ch06_explore, 0.45, None,
     "explore", "无节拍；童声只唱D与B♭（纯四度缺席），每循环一次极远湿D2钟，空气声床+微耳鸣单音"),
    ("ch01_moss_bell_court_combat_layer", r_ch01_combat, 0.5, 72,
     "combat", "72BPM 6/8手鼓+低音弦断奏stem，D-A张力持续音颤音垫，可叠加ch1探索层"),
    ("ch02_rain_foundry_canal_combat_layer", r_ch02_combat, 0.5, 92,
     "combat", "92BPM双倍密度金属打击+底鼓，G|A♭小二度弓奏摩擦垫"),
    ("ch03_saltwhite_archive_combat_layer", r_ch03_combat, 0.5, 66,
     "combat", "66BPM仍无鼓——羽管键琴急速十六分+玻璃高音颤，紧张感来自密度"),
    ("ch04_broken_string_greenhouse_combat_layer", r_ch04_combat, 0.5, 58,
     "combat", "58BPM Bartók拨弦重音+闷木鱼按5/4|6/4跛行分组，低E弦鸣涨落"),
    ("ch05_obsidian_pilgrim_road_combat_layer", r_ch05_combat, 0.5, 100,
     "combat", "100BPM军鼓全奏+号角小二度戳刺+男低音drone，行军战斗stem"),
    ("ch06_silent_crown_core_combat_layer", r_ch06_combat, 0.5, None,
     "combat", "无声之城遇敌近于无乐：46Hz次声脉冲+空气床+微金属呼吸（规格§2.7音乐消失的最小张力替身）"),
    ("ch02_rain_foundry_canal_boss_loop", r_ch02_boss, 0.55, 138,
     "boss", "138BPM G小调急板；2拍剪vs3拍缝hemiola，动机两次只唱到A即被剪停，末段半音上推+绯线主题对题"),
    ("ch03_saltwhite_archive_boss_loop", r_ch03_boss, 0.55, 120,
     "boss", "120BPM复写卡农：羽管键琴乐句每4拍自我叠加至4声部，后半整体逆行重奏+玻璃镰刃线"),
    ("ch04_broken_string_greenhouse_boss_loop", r_ch04_boss, 0.55, 69,
     "boss", "69BPM帕萨卡利亚：管风琴8小节固定低音永不停，其上snap pizz/玻璃泛音/col legno逐层变奏"),
    ("ch05_obsidian_pilgrim_road_boss_loop", r_ch05_boss, 0.55, 180,
     "boss", "3/4每分钟60小节圆舞曲：走音八音盒婚礼句，弦乐oom-pah-pah，后半旋律绕D4镜像反演+军鼓潜入"),
    ("ch06_silent_crown_core_boss_loop", r_ch06_boss, 0.55, 116,
     "boss", "116BPM六城点名集腋曲：钟/铁砧/钢片琴/snap/号角军鼓逐段引用+钥匙雨，尾段动机全奏tutti强制齐鸣"),
    ("boss_final_silent_crown_mvt1", r_final_mvt1, 0.55, None,
     "boss_final", "乐章I无声：60BPM心跳+呼吸+每15秒一记被捂住的哑钟（敲了但不响）"),
    ("boss_final_silent_crown_mvt2", r_final_mvt2, 0.55, 148,
     "boss_final", "乐章II万声：148BPM tutti，动机原速(钟)/增值(号角)/减值(钢片琴)叠置+黑潮全音簇上顶+童声长音"),
    ("boss_final_silent_crown_mvt3", r_final_mvt3, 0.55, None,
     "boss_final", "乐章III抉择：A属和弦长音悬停不解决，管风琴低八度+高音闪烁+定音鼓压强起伏"),
    ("ch01_moss_bell_court_shrine_lullaby", r_ch01_lullaby, 0.45, None,
     "lullaby", "龛中眠D-A-B♮：单支手钟低通暖音色+竖琴分解应答（苔藓吸音）"),
    ("ch02_rain_foundry_canal_shrine_lullaby", r_ch02_lullaby, 0.45, None,
     "lullaby", "龛中眠：生锈八音盒（高通薄音+失谐副音）+疲惫发条嘀嗒"),
    ("ch03_saltwhite_archive_shrine_lullaby", r_ch03_lullaby, 0.45, None,
     "lullaby", "龛中眠：钢片琴独奏，左手顺行跟随——唯一不复写的诚实房间"),
    ("ch04_broken_string_greenhouse_shrine_lullaby", r_ch04_lullaby, 0.45, None,
     "lullaby", "龛中眠：全作唯一人声摇篮曲——断弦歌者近景哼唱+稀疏拨弦守夜"),
    ("ch05_obsidian_pilgrim_road_shrine_lullaby", r_ch05_lullaby, 0.45, None,
     "lullaby", "龛中眠：独支弱音器号角（军营熄灯号质感）+一记极轻定音鼓"),
    ("ch06_silent_crown_core_shrine_lullaby", r_ch06_lullaby, 0.45, None,
     "lullaby", "龛中眠：童声哼唱首次唱到B♮——离解决最近的一次，远回声应答"),
    ("ending_a_rebell", r_ending_a, 0.55, None,
     "ending", "结局A重鸣：正格终止，动机首次完整解决B♭→A→D，D大调钟群齐鸣+管风琴+合唱；尾声童声仍悬B♭"),
    ("ending_b_severance", r_ending_b, 0.55, None,
     "ending", "结局B断冠：动机爬升被一声断弦剪停→黑潮全音簇涌成全频+倒放钟+无数细小人声各说各话，退成深脉冲"),
    ("ending_c_reweave", r_ending_c, 0.55, None,
     "ending", "结局C绯线：缄钟动机与绯线主题首次同时完整对位，六区乐器逐件加入，皮卡迪大三度D大调收束"),
    ("bellway_transit_loop", r_bellway_transit, 0.45, 300,
     "bellway", "3/8快板：小手铃+拨弦轻快变奏动机（全作唯一欢快主题）+绞盘咔哒"),
    ("bellway_depart_jingle", r_bellway_depart, 0.45, None,
     "bellway", "乘梯出发jingle：D5-A5-B5上行铃+绞盘起动升噪"),
    ("bellway_arrive_jingle", r_bellway_arrive, 0.45, None,
     "bellway", "到站jingle：B5-A5-D5下行铃+制动降噪+到站D6一击"),
    ("hidden_black_tide_drone", r_black_tide_drone, 0.35, None,
     "drone", "深井黑潮：D1水下drone三层干涉+倒放钟涌(8/21/34s)+耳语簇+动机整体逆行沉底，全局低通"),
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


def ffmpeg_bin() -> str:
    if FFMPEG.exists():
        return str(FFMPEG)
    found = shutil.which("ffmpeg")
    if found:
        return found
    raise FileNotFoundError(f"ffmpeg not found at {FFMPEG} and not on PATH")


def encode_ogg(wav_path: Path, ogg_path: Path) -> int:
    # bitexact keeps the Ogg stream serial/CRCs deterministic so reruns are
    # byte-identical (true idempotence, not just identical WAV upstream)
    subprocess.run(
        [ffmpeg_bin(), "-y", "-loglevel", "error", "-i", str(wav_path),
         "-c:a", "libvorbis", "-q:a", "5",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg_path)],
        check=True)
    return ogg_path.stat().st_size


def main() -> None:
    OGG_DIR.mkdir(parents=True, exist_ok=True)
    WAV_DIR.mkdir(parents=True, exist_ok=True)
    INVENTORY.parent.mkdir(parents=True, exist_ok=True)
    inventory: dict[str, dict] = {}
    total_ogg = 0
    print(f"{'key':<46} {'dur_s':>7} {'loop':>5} {'rms_db':>7} {'peak':>5} {'ogg_kb':>7}")
    for key, builder, peak, bpm, category, recipe in PACK:
        x, is_loop = builder()
        x = np.asarray(x, dtype=float)
        if not is_loop:
            x = edge_fade(x.copy(), 0.01)
        x = normalize(x, peak)
        if is_loop:
            x = seam_polish(x)
        target_rms = KEY_RMS_TARGETS.get(key, RMS_TARGETS[category])
        x = loudness_normalize(x, target_rms)
        rms_db = active_rms_db(x)
        peak_final = float(np.max(np.abs(x)))
        dur = len(x) / SR
        legacy = key in LEGACY_BGM_KEYS
        wav_path = WAV_DIR / f"{key}.wav"
        ogg_path = (BGM_ROOT if legacy else OGG_DIR) / f"{key}.ogg"
        write_wav(wav_path, x)
        size = encode_ogg(wav_path, ogg_path)
        total_ogg += size
        inventory[key] = {
            "path": ("res://assets/audio/bgm/" + ("" if legacy else "generated/")
                     + f"{key}.ogg"),
            "loop": is_loop,
            "seconds": round(dur, 3),
            "bpm": bpm,
            "rms_dbfs": round(rms_db, 2),
            "rms_target_dbfs": target_rms,
            "peak": round(peak_final, 3),
            "category": category,
            "recipe": recipe,
        }
        print(f"{key:<46} {dur:>7.2f} {str(is_loop):>5} {rms_db:>7.2f} "
              f"{peak_final:>5.2f} {size / 1024:>7.1f}")
    doc = {
        "generator": "tools/generate_music_pack.py",
        "license": "project-generated (CC0)",
        "format": "OGG Vorbis -q:a 5, mono 44.1 kHz, synthesized 16-bit WAV upstream",
        "loop_policy": ("integer-bar grids, wrapped decaying tails + equal-power "
                        "crossfaded seams + seam polish (end->start step spread "
                        "over the last ~90 ms)"),
        "loudness_policy": {
            "metric": "active(gated) RMS dBFS, 50ms windows, -60dBFS abs + -20dB rel gate",
            "explore": -22.0, "combat_layer": -20.0, "boss": -18.0,
            "boss_final": -18.0, "lullaby": -26.0,
            "lullaby_rule": "同章摇篮曲恒比探索曲低4dB(>=3dB要求)",
            "ending": -17.0, "bellway_loop": -24.0, "bellway_jingle": -20.0,
            "drone": -30.0,
            "peak_protection": f"tanh soft limiter, ceiling {LIMIT_CEILING}",
        },
        "spec": "docs/spec/20260726160400000_音效与音乐设计规格.md §2/§3",
        "tracks": inventory,
    }
    INVENTORY.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
                         encoding="utf-8")
    print(f"tracks={len(inventory)} total_ogg={total_ogg / 1024:.1f} KiB")
    print(f"inventory -> {INVENTORY}")


if __name__ == "__main__":
    main()

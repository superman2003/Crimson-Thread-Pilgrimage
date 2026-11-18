"""Synthesis primitives for the music pack: oscillators, envelopes, filters, loudness, seams and the instrument voices.

Moved out of generate_music_pack.py unchanged; generate_music_pack.py imports these names back."""
from __future__ import annotations
import math
import re
import zlib
import numpy as np


SR = 44100


_NOTE_SEMIS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name: str) -> float:
    """Note name ("D4", "Bb3", "F#5") -> equal-tempered frequency, A4=440."""
    m = re.fullmatch(r"([A-G])([b#]?)(-?\d)", name)
    if not m:
        raise ValueError(f"bad note {name!r}")
    semi = _NOTE_SEMIS[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    midi = (int(m.group(3)) + 1) * 12 + semi
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


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

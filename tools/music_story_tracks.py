"""Boss, finale, ending, bellway and drone tracks.

Moved out of generate_music_pack.py unchanged; generate_music_pack.py imports these names back."""
from __future__ import annotations
import math
import numpy as np
from music_dsp import (BELL_PARTIALS, CELESTA_PARTIALS, LIMIT_CEILING, SR, _NOTE_SEMIS,
    active_rms_db, anvil, bandfilt, bell, celesta, cyc, echoes, edge_fade, events, expdecay,
    fftfilt, glass_harmonic, harmonic_phase, horn, hz, kick, linramp, loop_canvas,
    loudness_normalize, lull_phrase, musicbox, n_of, noise, normalize, organ, pad, place, pluck,
    rng_for, seam_polish, seamless, silence, sine, snap_pizz, snare, soft_limit, sustain_tone,
    t_axis, taiko, tail_fade, thread_notes, tick, timpani, toll_notes, triangle_ping, voice, wrap)


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

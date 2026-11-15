"""Exploration, combat and lullaby tracks for each region.

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

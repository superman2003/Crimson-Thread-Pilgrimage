"""Story beats, combat, material, boss, UI and footstep cues.

Moved out of generate_ambience_pack.py unchanged; generate_ambience_pack.py imports these names back."""
from __future__ import annotations
import math
import numpy as np
from ambience_dsp import (BELL_PARTIALS, SR, active_rms_db, bandpass, bell, cconv, chirp, drip,
    edge_fade, expdecay, fft_noise, gband, growl, highpass, hishelf, linramp, loop_lfo, lowpass,
    make_loop, n_of, noise, normalize, place, place_wrap, pluck, rms_target, rng_for, silence,
    sine, sparse_env, svf, t_axis, whoosh)
from ambience_beds import (A3, A4, A5, BB4, BB5, D2, D3, D4, D5, D6, G3, a_ch01_1, a_ch01_2,
    a_ch01_3, a_ch01_4, a_ch01_5, a_ch01_6, a_ch01_7, a_ch01_8, a_ch02_1, a_ch02_2, a_ch02_3,
    a_ch02_4, a_ch02_5, a_ch02_6, a_ch02_7, a_ch02_8, a_ch02_anvil, a_ch03_1, a_ch03_2, a_ch03_3,
    a_ch03_4, a_ch03_5, a_ch03_6, a_ch03_7, a_ch03_8, a_ch04_1, a_ch04_2, a_ch04_3, a_ch04_4,
    a_ch04_5, a_ch04_6, a_ch04_7, a_ch04_8, a_ch05_1, a_ch05_2, a_ch05_3, a_ch05_4, a_ch05_5,
    a_ch05_6, a_ch05_7, a_ch05_8, a_ch06_1, a_ch06_2, a_ch06_3, a_ch06_4, a_ch06_5, a_ch06_6,
    a_ch06_7, a_ch06_8, bed_ch01, bed_ch02, bed_ch03, bed_ch04, bed_ch05, bed_ch06)


B4, B5 = 493.88, 987.77


E5 = 659.26


FS4 = 369.99


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

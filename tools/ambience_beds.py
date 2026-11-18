"""Region ambience beds and their one-shots.

Moved out of generate_ambience_pack.py unchanged; generate_ambience_pack.py imports these names back."""
from __future__ import annotations
import math
import numpy as np
from ambience_dsp import (BELL_PARTIALS, SR, active_rms_db, bandpass, bell, cconv, chirp, drip,
    edge_fade, expdecay, fft_noise, gband, growl, highpass, hishelf, linramp, loop_lfo, lowpass,
    make_loop, n_of, noise, normalize, place, place_wrap, pluck, rms_target, rng_for, silence,
    sine, sparse_env, svf, t_axis, whoosh)


D2, D3, D4, D5, D6 = 73.42, 146.83, 293.66, 587.33, 1174.66


A3, A4, A5 = 220.0, 440.0, 880.0


BB4, BB5 = 466.16, 932.33


G3 = 196.0


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

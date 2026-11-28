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
import os
import shutil
import subprocess
import wave
import zlib
from pathlib import Path

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
from ambience_cues import (B4, B5, BOSS_F0, BOSS_MATS, E5, FS4, _muffle, beat_ch02_01,
    beat_ch02_02, beat_ch02_03, beat_ch03_01, beat_ch03_02, beat_ch03_03, beat_ch04_01,
    beat_ch04_02, beat_ch04_03, beat_ch05_01, beat_ch05_02, beat_ch05_03, beat_ch06_01,
    beat_ch06_02, beat_ch06_03, boss_atk_heavy, boss_atk_light, boss_phase, boss_roar, c_attack,
    c_hit_armor, c_hit_shell, c_hit_soft, c_land_hard, c_land_soft, foot_glass, foot_wet, m_crown,
    m_crystal, m_gear, m_order, m_vine, m_water, ui_ability_unlock, ui_pickup_key_item,
    ui_testimony_complete)

ROOT = Path(__file__).resolve().parents[1]
AMB_DIR = ROOT / "godot" / "assets" / "audio" / "ambience"
SFX_DIR = ROOT / "godot" / "assets" / "audio" / "sfx" / "generated"
FOOT_DIR = ROOT / "godot" / "assets" / "audio" / "sfx" / "generated_footsteps"
INVENTORY = ROOT / "output" / "audio_preview" / "ambience_pack_inventory.json"


def ffmpeg_bin() -> str:
    env_bin = os.environ.get("CTP_FFMPEG", "").strip()
    if env_bin:
        candidate = Path(env_bin)
        if candidate.is_file():
            return str(candidate)
        found_env = shutil.which(env_bin)
        if found_env:
            return found_env
        raise FileNotFoundError(f"CTP_FFMPEG points to missing executable: {env_bin}")
    found = shutil.which("ffmpeg")
    if found:
        return found
    raise FileNotFoundError("ffmpeg not found on PATH; install ffmpeg or set CTP_FFMPEG")


# ---------------------------------------------------------------- primitives


# --------------------------------------------------- loop-safe bed primitives


# ------------------------------------------------------------------ A. beds


# ---------------------------------------------------- A. ambience one-shots


# ------------------------------------------------------------ B. beat sfx


# ---------------------------------------------------------- C. combat fill


# ------------------------------------------------------------- C. boss kits


# ------------------------------------------------------------- D. UI jingle


# ------------------------------------------------------------ E. footsteps


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
        [ffmpeg_bin(), "-y", "-loglevel", "error", "-i", str(wav_path),
         "-ar", str(SR), "-ac", "1", "-q:a", "4",
         # bitexact muxing: fixed ogg serial + no encoder tag -> idempotent rerun
         "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg_path)],
        check=True,
    )
    return ogg_path.stat().st_size


def decode_ogg(path: Path) -> np.ndarray:
    p = subprocess.run(
        [ffmpeg_bin(), "-v", "error", "-i", str(path), "-f", "f32le",
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

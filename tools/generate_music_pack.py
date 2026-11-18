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
from music_dsp import (BELL_PARTIALS, CELESTA_PARTIALS, LIMIT_CEILING, SR, _NOTE_SEMIS,
    active_rms_db, anvil, bandfilt, bell, celesta, cyc, echoes, edge_fade, events, expdecay,
    fftfilt, glass_harmonic, harmonic_phase, horn, hz, kick, linramp, loop_canvas,
    loudness_normalize, lull_phrase, musicbox, n_of, noise, normalize, organ, pad, place, pluck,
    rng_for, seam_polish, seamless, silence, sine, snap_pizz, snare, soft_limit, sustain_tone,
    t_axis, taiko, tail_fade, thread_notes, tick, timpani, toll_notes, triangle_ping, voice, wrap)
from music_region_tracks import (r_ch01_combat, r_ch01_explore, r_ch01_lullaby, r_ch02_combat,
    r_ch02_explore, r_ch02_lullaby, r_ch03_combat, r_ch03_explore, r_ch03_lullaby, r_ch04_combat,
    r_ch04_explore, r_ch04_lullaby, r_ch05_combat, r_ch05_explore, r_ch05_lullaby, r_ch06_combat,
    r_ch06_explore, r_ch06_lullaby)
from music_story_tracks import (r_bellway_arrive, r_bellway_depart, r_bellway_transit,
    r_black_tide_drone, r_ch01_boss, r_ch02_boss, r_ch03_boss, r_ch04_boss, r_ch05_boss,
    r_ch06_boss, r_ending_a, r_ending_b, r_ending_c, r_final_mvt1, r_final_mvt2, r_final_mvt3)

ROOT = Path(__file__).resolve().parents[1]
BGM_ROOT = ROOT / "godot" / "assets" / "audio" / "bgm"
OGG_DIR = BGM_ROOT / "generated"
# ch01 keys keep their historical filenames in the bgm root (13 existing
# references: audio_director/main_level fallbacks, validation, web preview).
LEGACY_BGM_KEYS = {"ch01_cave_loop", "boss_rust_crown_loop"}
WAV_DIR = ROOT / "output" / "audio_preview" / "music_wav_build"
INVENTORY = ROOT / "output" / "audio_preview" / "music_pack_inventory.json"
FFMPEG = Path("C:/Users/Administrator/Desktop/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe")


# ---------------------------------------------------------------- primitives


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


# --------------------------------------------------------------- instruments


# ---------------------------------------------------------- motif materials


# ------------------------------------------------------------------- recipes
# Each returns (samples, loop_bool). Loop recipes are integer-bar grids with
# wrapped tails + crossfaded beds.


# combat layer stems: percussion + tension sustains at the chapter tempo


# boss loops


# final boss movements


# shrine lullabies (龛中眠: D-A-B natural, per-chapter timbre)


# endings (one-shots)


# bellway (§2.9)


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

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

import argparse
import math
import os
import shutil
import subprocess
import wave
import zlib
from pathlib import Path

import numpy as np
from sfx_dsp import (BELL_PARTIALS, SR, active_rms_db, bandpass, bell, edge_fade, expdecay,
    highpass, hishelf, linramp, lowpass, make_loop, n_of, noise, normalize, place, pluck,
    rms_target, rng_for, silence, sine, svf, t_axis)
from sfx_recipes import (A3, A4, A5, B3, B4, B5, BB4, BB5, D3, D4, D5, D6, E5, FS4,
    _shrine_rest_base, r_bind_channel, r_bind_interrupt, r_bind_tighten, r_boss_death_slowmo,
    r_boss_windup_lethal, r_boss_windup_light, r_chapter_transition, r_core_attack, r_core_dash,
    r_core_enemy_hit, r_core_heal, r_core_heavy_hit, r_core_hook, r_core_hurt, r_core_interact,
    r_core_jump, r_core_lever, r_core_pickup, r_death_cocoon, r_death_copper, r_death_fiber,
    r_death_moss, r_death_obsidian, r_death_salt, r_death_silent, r_double_jump_wings,
    r_downstrike_break, r_downstrike_crack, r_elite_ritual_start, r_ending_a, r_ending_b,
    r_ending_c, r_enemy_alarm_call, r_enemy_ambush_reveal, r_enemy_support_mend, r_gate_crown,
    r_gate_dash, r_gate_doublejump, r_gate_guardbreak, r_gate_hookring, r_gate_shadow,
    r_gate_wallshaft, r_guard_block, r_guard_perfect, r_hit_heavy, r_hit_kill, r_hit_light,
    r_hook_latch, r_hook_reel, r_low_hp_heartbeat, r_pogo_bounce, r_respawn_weave,
    r_shrine_rest_ch01, r_shrine_rest_ch02, r_shrine_rest_ch03, r_shrine_rest_ch04,
    r_shrine_rest_ch05, r_shrine_rest_ch06, r_shrine_wrap, r_wall_grip_attach, r_wall_slide_loop)

ROOT = Path(__file__).resolve().parents[1]
SFX_ROOT = ROOT / "godot" / "assets" / "audio" / "sfx"
OUT_DIR = SFX_ROOT / "generated"
PREVIEW = ROOT / "output" / "audio_preview" / "sfx_sampler.wav"
FFMPEG = os.environ.get("CTP_FFMPEG") or shutil.which("ffmpeg") or "C:/Users/Administrator/Desktop/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe"


# ---------------------------------------------------------------- primitives


# ------------------------------------------------------------------ recipes


# ----------------------------------------------------- core gameplay sounds
# Eleven root-level sounds are shared by main_level and player_controller.
# Same crimson-thread family vocabulary as the rest.


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
    # B01 role cues: ambush reveal, alarm call and support channel (enemy_actor._role_cue)
    ("enemy_ambush_reveal", "enemy_ambush_reveal.ogg", r_enemy_ambush_reveal, False, 0.62, None),
    ("enemy_alarm_call", "enemy_alarm_call.ogg", r_enemy_alarm_call, False, 0.66, None),
    ("enemy_support_mend", "enemy_support_mend.ogg", r_enemy_support_mend, False, 0.55, None),
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

# Core gameplay files replace the old silent placeholders at the sfx root.
# Combat-SFX loudness convention: peak 0.7, active RMS -18..-24 dBFS.
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
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="+", metavar="FILE",
                        help="render only these output files (e.g. enemy_alarm_call.ogg); skips the sampler")
    only = set(parser.parse_args().only or [])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    rendered: dict[str, np.ndarray] = {}
    total_bytes = 0
    jobs = [(OUT_DIR, entry) for entry in PACK] + [(SFX_ROOT, entry) for entry in CORE_PACK]
    for out_dir, (event_key, file_name, builder, is_loop, peak, rms_db) in jobs:
        if only and file_name not in only:
            continue
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

    missing = only - set(rendered)
    assert not missing, f"unknown --only files: {sorted(missing)}"
    if only:
        print(f"generated {len(rows)} ogg files (--only; sampler skipped)")
        for event_key, file_name, dur, peak, arms, is_loop, size in rows:
            print(f"{event_key:<26} {file_name:<32} {dur:>6.2f} {peak:>5.2f} {arms:>6.1f} {str(is_loop):>5} {size:>8}")
        return
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

from __future__ import annotations

import json
import math
import random
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

sys.path.append(str(Path(__file__).resolve().parent))
from build_enemy_runtime_keyframes import build_frames, cell_size, res_path, start_index  # noqa: E402
from small_enemy_frames import (ATTACK_POSES, ATTACK_STAGES, CHROMA_KEY_SOURCES,
    CONNECTED_COMPONENT_SOURCES, DETACHED_THIN_ARTIFACT_SOURCES, FOOTLESS_RESHAPE_PLANS,
    FRAME_COUNT, FRAME_SIZE, PREVIEW_GAP, SOURCE_SEQUENCE_OVERRIDES, add_edge_light, alpha_area,
    amplified_attack_pose, apply_attack_pose, apply_locomotion_attack_bias, apply_walk_pose,
    build_connected_component_frame_bank, build_frame_bank, build_frames_from_bank,
    color_distance_sq, connected_components_for_image, contain_alpha, dominant_region_color,
    draw_continuous_amphibian_base, draw_continuous_armor_base, draw_continuous_hide_base,
    draw_continuous_imp_base, draw_continuous_root_base, draw_floating_body_attack,
    draw_hover_shadow, draw_integrated_base_texture, draw_motion_dust,
    draw_native_attack_readability, draw_root_shambler_attack, draw_shape_aware_walk_motion,
    draw_slither_marks, draw_slug_trail, draw_snail_slide_attack, draw_source_biped_attack,
    draw_source_locked_fallback_attack, draw_tendril_sway, draw_winged_hover_attack,
    draw_worm_slither_attack, expand_frames, filter_actor_tiles, footless_band_width,
    is_likely_flat_sheet_background, looks_like_label_tile, make_attack_frame, make_death_frame,
    make_hurt_frame, make_idle_frame, make_walk_frame, max_dimensions, normalize_frame,
    offset_frame, remove_detached_thin_source_artifacts, remove_flat_source_background,
    reshape_footless_frame, save_animation_frames, save_strip, select_source_frames, sharpen_alpha,
    tint_image, tone_down_native_attack_pose, trim_alpha, walk_pose_values,
    weighted_alpha_center_x)
from small_enemy_reviews import (ARTIFACT_ROOT, CONTACT_DIR, FOOTLESS_AUDIT_KINDS, GODOT, ROOT,
    WALK_STAGES, from_res_path, render_attack_showcase, render_enemy_preview,
    render_floating_body_runtime_review, render_frogman_runtime_review,
    render_hunched_shambler_runtime_review, render_no_added_feet_walk_zoom, render_overview,
    render_snail_slide_runtime_review, render_source_biped_runtime_review, render_walk_showcase,
    render_winged_hover_runtime_review, render_worm_slither_runtime_review)


DATA_DIR = GODOT / "data"
OUT_ROOT = GODOT / "assets" / "third_party" / "dark_fantasy_bestiary" / "runtime_keyframes"

QUALITY_PROFILE = "shape_aware_walk_attack_v19_no_line_attack_fx"


SOURCE_ROOT = "res://assets/third_party/dark_fantasy_bestiary"

SOURCE_REGIONS: dict[str, list[int]] = {
    "ansimuz-shambler-pal2-alpha_0.png": [0, 0, 32, 40],
    "ansimuz-shambler-short-pal2-alpha_0.png": [0, 0, 32, 32],
    "balmer-andromalius-57x88-alpha.png": [0, 0, 57, 88],
    "balmer-minion-45x66-alpha.png": [0, 0, 45, 66],
    "calciumtrice-emceeflesher-worm-alpha.png": [0, 0, 32, 48],
    "redshrike-blatty-alpha-pal2.png": [0, 0, 64, 64],
    "redshrike-blatty-alpha.png": [0, 0, 64, 64],
    "redshrike-bonio-alpha.png": [0, 0, 32, 32],
    "redshrike-emceeflesher-eyewasp-alpha.png": [0, 0, 36, 36],
    "redshrike-emceeflesher-skullwasp-alpha.png": [0, 0, 36, 36],
    "redshrike-emceeflesher-wasp.png": [0, 0, 38, 36],
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png": [0, 0, 60, 40],
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png": [0, 0, 60, 40],
    "redshrike-thompson-golem-pal2-alpha.png": [0, 0, 64, 72],
    "redshrike-wartaur-alpha.png": [0, 0, 80, 80],
    "sparky-surt-emceeflesher-alpha.png": [0, 0, 32, 32],
    "surt-emceeflesher-spitsnail-alpha_0.png": [0, 0, 32, 32],
}

CHAPTER_FILES = {
    1: "demo_ch01_moss_bell_court.json",
    2: "demo_ch02_rain_foundry_canal.json",
    3: "demo_ch03_saltwhite_archive.json",
    4: "demo_ch04_broken_string_greenhouse.json",
    5: "demo_ch05_obsidian_pilgrim_road.json",
    6: "demo_ch06_silent_crown_core.json",
}

ROSTER: dict[int, list[dict[str, Any]]] = {
    1: [
        {"kind": "moss_larva", "source": "ansimuz-shambler-short-pal2-alpha_0.png", "style": "crawler", "tint": "9fd96a", "scale": 0.82},
        {"kind": "bronze_moth", "source": "redshrike-emceeflesher-skullwasp-alpha.png", "style": "flyer", "tint": "d7a246", "scale": 0.92},
        {"kind": "spore_bellmaker", "source": "balmer-minion-45x66-alpha.png", "style": "shooter", "tint": "e6b35b", "scale": 0.84},
        {"kind": "gear_sentinel", "source": "redshrike-thompson-golem-pal2-alpha.png", "style": "charger", "tint": "c38b42", "scale": 0.76},
        {"kind": "corridor_heavy", "source": "redshrike-wartaur-alpha.png", "style": "heavy", "tint": "ba8f4f", "scale": 0.78},
        {"kind": "bellroot_acolyte", "source": "balmer-andromalius-57x88-alpha.png", "style": "caster", "tint": "b7cf67", "scale": 0.76},
    ],
    2: [
        {"kind": "drain_leech", "source": "calciumtrice-emceeflesher-worm-alpha.png", "style": "crawler", "tint": "74d7db", "scale": 0.82},
        {"kind": "pipe_thrower", "source": "redshrike-evert-pufalotti-frogman-pal2-alpha.png", "style": "shooter", "tint": "8fcad7", "scale": 0.84},
        {"kind": "rust_diver", "source": "surt-emceeflesher-spitsnail-alpha_0.png", "style": "flyer", "tint": "b68b5a", "scale": 0.92},
        {"kind": "bell_mote", "source": "redshrike-emceeflesher-eyewasp-alpha.png", "style": "flyer", "tint": "d7eeb0", "scale": 0.88},
        {"kind": "waterwheel_knight", "source": "redshrike-wartaur-alpha.png", "style": "heavy", "tint": "a9d2d9", "scale": 0.78},
        {"kind": "valve_crawler", "source": "ansimuz-shambler-pal2-alpha_0.png", "style": "crawler", "tint": "7cc8b6", "scale": 0.84},
        {"kind": "rain_censer_mote", "source": "redshrike-emceeflesher-wasp.png", "style": "flyer", "tint": "b2e8ff", "scale": 0.90},
    ],
    3: [
        {"kind": "salt_bookmite", "source": "sparky-surt-emceeflesher-alpha.png", "style": "crawler", "tint": "f3d7ad", "scale": 0.84},
        {"kind": "page_duelist", "source": "redshrike-blatty-alpha-pal2.png", "style": "duelist", "tint": "f1b06a", "scale": 0.86},
        {"kind": "index_scribe", "source": "balmer-andromalius-57x88-alpha.png", "style": "caster", "tint": "e6ccb2", "scale": 0.76},
        {"kind": "summoned_page", "source": "redshrike-emceeflesher-eyewasp-alpha.png", "style": "flyer", "tint": "ffe8ba", "scale": 0.88},
        {"kind": "wax_lancer", "source": "balmer-minion-45x66-alpha.png", "style": "charger", "tint": "f0b35d", "scale": 0.84},
        {"kind": "erasure_bailiff", "source": "redshrike-wartaur-alpha.png", "style": "heavy", "tint": "c2785b", "scale": 0.78},
    ],
    4: [
        {"kind": "vine_crawler", "source": "surt-emceeflesher-spitsnail-alpha_0.png", "style": "crawler", "tint": "8bd279", "scale": 0.84},
        {"kind": "wax_bee", "source": "redshrike-emceeflesher-wasp.png", "style": "flyer", "tint": "f2d875", "scale": 0.90},
        {"kind": "root_cage_hunter", "source": "ansimuz-shambler-pal2-alpha_0.png", "style": "charger", "tint": "a8b95a", "scale": 0.84},
        {"kind": "pollen_lutist", "source": "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png", "style": "shooter", "tint": "e8d789", "scale": 0.84},
        {"kind": "thorn_sentinel", "source": "redshrike-wartaur-alpha.png", "style": "heavy", "tint": "a7c96a", "scale": 0.78},
        {"kind": "thorn_bloom_mote", "source": "redshrike-emceeflesher-eyewasp-alpha.png", "style": "flyer", "tint": "f0a8d4", "scale": 0.88},
    ],
    5: [
        {"kind": "obsidian_spearman", "source": "redshrike-bonio-alpha.png", "style": "duelist", "tint": "78d9bf", "scale": 0.92},
        {"kind": "phase_censor", "source": "redshrike-blatty-alpha-pal2.png", "style": "caster", "tint": "88dfd7", "scale": 0.86},
        {"kind": "silent_bugbler", "source": "ansimuz-shambler-pal2-alpha_0.png", "style": "crawler", "tint": "cad9b6", "scale": 0.84},
        {"kind": "kneeling_crossbowman", "source": "redshrike-evert-pufalotti-frogman-pal2-alpha.png", "style": "shooter", "tint": "d8dfc5", "scale": 0.84},
        {"kind": "pilgrim_chariot", "source": "surt-emceeflesher-spitsnail-alpha_0.png", "style": "charger", "tint": "b5d3a3", "scale": 0.92},
        {"kind": "ash_banner_imp", "source": "balmer-minion-45x66-alpha.png", "style": "duelist", "tint": "c6c99f", "scale": 0.84},
        {"kind": "obsidian_bellwheel", "source": "redshrike-thompson-golem-pal2-alpha.png", "style": "heavy", "tint": "84cbbf", "scale": 0.76},
    ],
    6: [
        {"kind": "echo_moss_larva", "source": "sparky-surt-emceeflesher-alpha.png", "style": "crawler", "tint": "78f4ed", "scale": 0.84},
        {"kind": "falling_clapper", "source": "redshrike-bonio-alpha.png", "style": "heavy", "tint": "d6bb75", "scale": 0.92},
        {"kind": "echo_waterwheel_knight", "source": "redshrike-thompson-golem-pal2-alpha.png", "style": "heavy", "tint": "76dfe8", "scale": 0.76},
        {"kind": "echo_contract_scribe", "source": "balmer-andromalius-57x88-alpha.png", "style": "caster", "tint": "d3e7ff", "scale": 0.76},
        {"kind": "delayed_shadow", "source": "redshrike-blatty-alpha.png", "style": "duelist", "tint": "8e8ee8", "scale": 0.86},
        {"kind": "echo_thorn_sentinel", "source": "calciumtrice-emceeflesher-worm-alpha.png", "style": "crawler", "tint": "9fe6de", "scale": 0.82},
        {"kind": "echo_pilgrim_commander_minor", "source": "redshrike-emceeflesher-skullwasp-alpha.png", "style": "flyer", "tint": "c7eaff", "scale": 0.88},
        {"kind": "isotope_lumen", "source": "redshrike-emceeflesher-eyewasp-alpha.png", "style": "caster", "tint": "b9ffe9", "scale": 0.88},
    ],
}

STYLE_ATTACKS: dict[str, dict[str, Any]] = {
    "crawler": {"id": "bite_lunge", "type": "lunge", "range": 92, "damage": 1, "windup": 0.26, "active": 0.18, "recover": 0.46, "cooldown": 1.18, "lunge_speed": 250, "hit_width": 82, "hit_height": 54, "offset": 44, "telegraph": "bf6c3f", "priority": 1.0},
    "flyer": {"id": "sickle_swoop", "type": "lunge", "range": 112, "damage": 1, "windup": 0.22, "active": 0.20, "recover": 0.44, "cooldown": 1.16, "lunge_speed": 285, "hit_width": 92, "hit_height": 58, "offset": 52, "telegraph": "d9b25f", "priority": 1.0},
    "shooter": {"id": "body_cast", "type": "melee", "range": 96, "damage": 1, "windup": 0.34, "active": 0.18, "recover": 0.55, "cooldown": 1.34, "hit_width": 88, "hit_height": 64, "offset": 48, "telegraph": "c99a50", "priority": 1.0},
    "caster": {"id": "sigil_burst", "type": "aoe", "range": 86, "damage": 1, "windup": 0.38, "active": 0.16, "recover": 0.58, "cooldown": 1.42, "hit_width": 126, "hit_height": 76, "offset": 0, "telegraph": "9bd7f0", "priority": 1.0},
    "charger": {"id": "shield_rush", "type": "lunge", "range": 118, "damage": 1, "windup": 0.30, "active": 0.22, "recover": 0.54, "cooldown": 1.36, "lunge_speed": 310, "hit_width": 100, "hit_height": 68, "offset": 56, "telegraph": "d38c45", "priority": 1.0},
    "duelist": {"id": "quick_cut", "type": "melee", "range": 88, "damage": 1, "windup": 0.20, "active": 0.16, "recover": 0.42, "cooldown": 1.08, "hit_width": 82, "hit_height": 72, "offset": 42, "telegraph": "e1b879", "priority": 1.0},
    "heavy": {"id": "heavy_body_check", "type": "melee", "range": 84, "damage": 2, "windup": 0.40, "active": 0.20, "recover": 0.66, "cooldown": 1.55, "hit_width": 104, "hit_height": 74, "offset": 48, "telegraph": "c9764a", "priority": 1.0},
}

SOURCE_LOCOMOTION_PLANS: dict[str, str] = {
    "ansimuz-shambler-pal2-alpha_0.png": "hunched_shambler",
    "ansimuz-shambler-short-pal2-alpha_0.png": "hunched_shambler",
    "balmer-andromalius-57x88-alpha.png": "tendril_float",
    "balmer-minion-45x66-alpha.png": "tendril_float",
    "calciumtrice-emceeflesher-worm-alpha.png": "worm_slither",
    "redshrike-blatty-alpha-pal2.png": "winged_hover",
    "redshrike-blatty-alpha.png": "winged_hover",
    "redshrike-bonio-alpha.png": "biped_imp",
    "redshrike-emceeflesher-eyewasp-alpha.png": "winged_hover",
    "redshrike-emceeflesher-skullwasp-alpha.png": "winged_hover",
    "redshrike-emceeflesher-wasp.png": "winged_hover",
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png": "amphibian_hop",
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png": "amphibian_hop",
    "redshrike-thompson-golem-pal2-alpha.png": "armored_biped",
    "redshrike-wartaur-alpha.png": "beast_biped",
    "sparky-surt-emceeflesher-alpha.png": "flame_wisp",
    "surt-emceeflesher-spitsnail-alpha_0.png": "snail_slide",
}


SOURCE_NATIVE_ATTACK_PLANS = {
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png",
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png",
}

NO_ADDED_WALK_LIMB_PLANS = {
    "snail_slide",
    "worm_slither",
    "winged_hover",
    "tendril_float",
    "flame_wisp",
    "hunched_shambler",
    "amphibian_hop",
    "armored_biped",
    "beast_biped",
    "biped_imp",
}


def main() -> None:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    CONTACT_DIR.mkdir(parents=True, exist_ok=True)

    generated: list[dict[str, Any]] = []
    for chapter, file_name in CHAPTER_FILES.items():
        config_path = DATA_DIR / file_name
        data = load_json(config_path)
        specs = ROSTER[chapter]
        assets_by_kind: dict[str, dict[str, Any]] = {}
        for spec in specs:
            entry = build_enemy_asset(chapter, spec)
            assets_by_kind[spec["kind"]] = entry
            generated.append(entry)
        update_config(data, specs, assets_by_kind)
        config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    update_campaign()
    render_overview(generated)
    render_walk_showcase(generated)
    render_attack_showcase(generated)
    render_no_added_feet_walk_zoom(generated)
    render_frogman_runtime_review(generated)
    render_hunched_shambler_runtime_review(generated)
    render_worm_slither_runtime_review(generated)
    render_snail_slide_runtime_review(generated)
    render_winged_hover_runtime_review(generated)
    render_floating_body_runtime_review(generated)
    render_source_biped_runtime_review(generated)
    print(
        "BUILD_SMALL_ENEMY_RUNTIME_ASSETS_PASS "
        f"unique_enemies={len(generated)} chapters={len(CHAPTER_FILES)} "
        f"walk_frames={FRAME_COUNT * 2 * len(generated)} attack_frames={FRAME_COUNT * 2 * len(generated)} "
        f"overview={CONTACT_DIR / 'small_enemy_40_overview.png'}"
    )


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def update_campaign() -> None:
    campaign_path = DATA_DIR / "campaign_chapters.json"
    if not campaign_path.exists():
        return
    campaign = load_json(campaign_path)
    chapters = campaign.get("chapters", [])
    if not isinstance(chapters, list):
        return
    for chapter in chapters:
        if not isinstance(chapter, dict):
            continue
        index = int(chapter.get("index", 0))
        if index not in ROSTER:
            continue
        enemies = chapter.setdefault("enemies", [])
        if not isinstance(enemies, list):
            enemies = []
            chapter["enemies"] = enemies
        existing = {enemy if isinstance(enemy, str) else str(enemy.get("kind", enemy.get("name", ""))) for enemy in enemies}
        for spec in ROSTER[index]:
            if spec["kind"] not in existing:
                enemies.append(spec["kind"])
                existing.add(spec["kind"])
    campaign_path.write_text(json.dumps(campaign, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_config(data: dict[str, Any], specs: list[dict[str, Any]], assets_by_kind: dict[str, dict[str, Any]]) -> None:
    desired_kinds = [str(spec["kind"]) for spec in specs]
    profile_table = data.setdefault("ai_profiles", {})
    for spec in specs:
        kind = str(spec["kind"])
        previous = profile_table.get(kind, {}) if isinstance(profile_table.get(kind, {}), dict) else {}
        profile_table[kind] = make_ai_profile(spec, previous)

    spawns = data.get("enemy_spawns", [])
    if not isinstance(spawns, list):
        return
    ensure_spawn_kinds(spawns, desired_kinds)
    for spawn in spawns:
        if not isinstance(spawn, dict):
            continue
        kind = str(spawn.get("kind", ""))
        if kind not in assets_by_kind:
            continue
        apply_asset_to_spawn(spawn, assets_by_kind[kind])


def ensure_spawn_kinds(spawns: list[Any], desired_kinds: list[str]) -> None:
    current = [str(spawn.get("kind", "")) for spawn in spawns if isinstance(spawn, dict)]
    missing = [kind for kind in desired_kinds if kind not in current]
    for missing_kind in missing:
        counts: dict[str, int] = {}
        for kind in current:
            counts[kind] = counts.get(kind, 0) + 1
        replace_index = -1
        for index in range(len(spawns) - 1, -1, -1):
            spawn = spawns[index]
            if not isinstance(spawn, dict):
                continue
            kind = str(spawn.get("kind", ""))
            if counts.get(kind, 0) > 1:
                replace_index = index
                counts[kind] -= 1
                current[index] = missing_kind
                break
        if replace_index < 0:
            template = deepcopy(next((spawn for spawn in spawns if isinstance(spawn, dict)), {}))
            template["id"] = f"AUTO_{len(spawns) + 1:02d}"
            spawns.append(template)
            current.append(missing_kind)
            replace_index = len(spawns) - 1
        spawns[replace_index]["kind"] = missing_kind


def make_ai_profile(spec: dict[str, Any], previous: dict[str, Any]) -> dict[str, Any]:
    style = str(spec.get("style", "crawler"))
    attack = deepcopy(STYLE_ATTACKS[style])
    attack["animation"] = "attack"
    profile = deepcopy(previous)
    profile["move_speed"] = int(profile.get("move_speed", move_speed_for_style(style)))
    profile["aggro_range"] = float(profile.get("aggro_range", 235 if style in {"flyer", "shooter", "caster"} else 220))
    profile["preferred_range"] = float(profile.get("preferred_range", 86 if style in {"shooter", "caster", "flyer"} else 58))
    profile["attack_desire_threshold"] = float(profile.get("attack_desire_threshold", 0.62))
    profile["attack_desire_gain"] = float(profile.get("attack_desire_gain", 1.05))
    profile["attack_desire_decay"] = float(profile.get("attack_desire_decay", 0.82))
    profile["attacks"] = [attack]
    return profile


def move_speed_for_style(style: str) -> int:
    return {
        "crawler": 50,
        "flyer": 66,
        "shooter": 36,
        "caster": 34,
        "charger": 46,
        "duelist": 58,
        "heavy": 42,
    }.get(style, 48)


def apply_asset_to_spawn(spawn: dict[str, Any], asset: dict[str, Any]) -> None:
    frame_region = [0, 0, FRAME_SIZE, FRAME_SIZE]
    spawn["sprite"] = asset["manifest_res"]
    spawn["sprite_region"] = frame_region
    spawn["source_sprite"] = asset["source_res"]
    spawn["source_sprite_region"] = asset["source_region"]
    spawn["visual_scale"] = asset["visual_scale"]
    spawn["visual_offset"] = [0, -8]
    spawn["visual_modulate"] = "ffffff"
    spawn["visual_source"] = "OpenGameArt Dark Fantasy Platformer Bestiary CC-BY 4.0; normalized directional keyframes"
    spawn["visual_role"] = "dark_fantasy_enemy"
    spawn["sprite_faces_left"] = False
    spawn["sprite_regions"] = {
        "idle": frame_region,
        "walk": frame_region,
        "walk_left": frame_region,
        "walk_right": frame_region,
        "attack": frame_region,
        "attack_left": frame_region,
        "attack_right": frame_region,
        "hurt": frame_region,
        "death": frame_region,
    }
    spawn["spawn_half_width"] = int(asset["spawn_half_width"])
    spawn["spawn_visual_height"] = int(asset["spawn_visual_height"])


def build_enemy_asset(chapter: int, spec: dict[str, Any]) -> dict[str, Any]:
    kind = str(spec["kind"])
    source_name = str(spec["source"])
    source_res = f"{SOURCE_ROOT}/{source_name}"
    source_path = res_path(source_res)
    source_region = SOURCE_REGIONS.get(source_name, [0, 0, source_path.stat().st_size, source_path.stat().st_size])
    image = Image.open(source_path).convert("RGBA")
    cell_w, cell_h = cell_size(source_path, source_region)
    frame_bank = build_frame_bank(source_name, image, cell_w, cell_h)
    frames = select_source_frames(source_name, frame_bank, "walk", start_index(source_region, cell_w, cell_h, image.width), FRAME_COUNT)
    if not frames:
        raise RuntimeError(f"No frames extracted for {kind}: {source_path}")

    out_dir = OUT_ROOT / kind
    frames_dir = out_dir / "frames"
    sheets_dir = out_dir / "sheets"
    frames_dir.mkdir(parents=True, exist_ok=True)
    sheets_dir.mkdir(parents=True, exist_ok=True)

    rng = random.Random(f"{chapter}:{kind}")
    tint = hex_to_rgb(str(spec["tint"]))
    style = str(spec.get("style", "crawler"))
    locomotion_plan = str(spec.get("locomotion_plan", SOURCE_LOCOMOTION_PLANS.get(source_name, "biped_imp")))
    walk_base_frames = [normalize_frame(frame, tint, style, index, rng) for index, frame in enumerate(expand_frames(frames, FRAME_COUNT))]
    attack_source_frames = select_source_frames(source_name, frame_bank, "attack", start_index(source_region, cell_w, cell_h, image.width), FRAME_COUNT)
    attack_base_frames = [normalize_frame(frame, tint, style, index, rng) for index, frame in enumerate(expand_frames(attack_source_frames, FRAME_COUNT))]
    walk_right = [make_walk_frame(frame, index, "right", style, tint, locomotion_plan) for index, frame in enumerate(walk_base_frames)]
    walk_left = [ImageOps.mirror(frame) for frame in walk_right]
    use_native_attack = source_name in SOURCE_NATIVE_ATTACK_PLANS
    attack_right = [
        make_attack_frame(attack_base_frames[index % len(attack_base_frames)], index, "right", style, tint, locomotion_plan, use_native_attack)
        for index in range(FRAME_COUNT)
    ]
    attack_left = [ImageOps.mirror(frame) for frame in attack_right]
    idle = [make_idle_frame(walk_base_frames[index % len(walk_base_frames)], index, tint) for index in range(4)]
    hurt = [make_hurt_frame(walk_base_frames[0], tint)]
    death = [make_death_frame(walk_base_frames[index % len(walk_base_frames)], index, tint) for index in range(4)]

    animation_frames = {
        "idle": idle,
        "walk": walk_right,
        "walk_right": walk_right,
        "walk_left": walk_left,
        "attack": attack_right,
        "attack_right": attack_right,
        "attack_left": attack_left,
        "hurt": hurt,
        "death": death,
    }
    frame_paths: dict[str, list[Path]] = {}
    for animation_name, images in animation_frames.items():
        frame_paths[animation_name] = save_animation_frames(frames_dir, animation_name, images)
        if animation_name in {"walk_left", "walk_right", "attack_left", "attack_right"}:
            save_strip(sheets_dir / f"{animation_name}_strip.png", images)

    preview_path = out_dir / "preview_contact_sheet.png"
    render_enemy_preview(preview_path, kind, animation_frames)

    manifest = {
        "source": source_res,
        "source_region": source_region,
        "note": "Small enemy runtime keyframes normalized from open dark fantasy source sprites. Each enemy has high-readability staged walk and one staged attack, 8-frame walk left/right, and 8-frame attack left/right.",
        "quality_profile": QUALITY_PROFILE,
        "kind": kind,
        "chapter": chapter,
        "cell_size": [FRAME_SIZE, FRAME_SIZE],
        "frame_spacing_px": PREVIEW_GAP,
        "anchor": "bottom_center",
        "locomotion_plan": locomotion_plan,
        "shape_constraints": {
            "no_added_walk_limbs": True,
            "no_generated_extra_feet_or_legs": True,
            "no_detached_attack_effects": True,
            "source_silhouette_driven": True,
        },
        "walk_stages": WALK_STAGES,
        "attack_count": 1,
        "attack_stages": ATTACK_STAGES,
        "quality_gates": {
            "walk_body_pose_changes": True,
            "walk_source_silhouette_motion": True,
            "walk_center_travel_px_min": 5,
            "walk_alpha_area_delta_min": 80,
            "attack_body_pose_changes": True,
            "attack_has_anticipation_impact_recovery": True,
            "attack_motion_extent_px_min": 20,
            "attack_center_travel_px_min": 20,
            "attack_alpha_area_delta_min": 180,
            "strip_spacing_px_min": 24,
            "no_added_feet_visual_audit": True,
        },
        "attacks": [
            {
                "id": STYLE_ATTACKS[style]["id"],
                "style": style,
                "readability": "anticipation -> release -> impact -> recovery",
                "animations": {
                    "left": "attack_left",
                    "right": "attack_right",
                },
                "frames_per_direction": FRAME_COUNT,
            }
        ],
        "animations": [
            {
                "name": animation_name,
                "fps": 7.0 if animation_name.startswith("walk") or animation_name == "idle" else 12.0,
                "loop": animation_name.startswith("walk") or animation_name == "idle",
                "frames": [to_res_path(path) for path in paths],
            }
            for animation_name, paths in frame_paths.items()
        ],
        "preview": to_res_path(preview_path) if preview_path.is_relative_to(GODOT) else preview_path.as_posix(),
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {
        "kind": kind,
        "chapter": chapter,
        "source_res": source_res,
        "source_region": source_region,
        "manifest": manifest_path,
        "manifest_res": to_res_path(manifest_path),
        "preview": preview_path,
        "style": style,
        "visual_scale": float(spec.get("scale", 0.84)),
        "spawn_half_width": 42 if style in {"heavy", "charger"} else 36,
        "spawn_visual_height": 72 if style in {"heavy", "charger", "caster"} else 58,
    }


def footless_base_color(image: Image.Image, region: tuple[int, int, int, int], tint: tuple[int, int, int]) -> tuple[int, int, int]:
    sampled = dominant_region_color(image, region, tint)
    mixed = tuple(int(sampled[channel] * 0.68 + tint[channel] * 0.32) for channel in range(3))
    if sum(mixed) < 100:
        mixed = tuple(int(tint[channel] * 0.58 + 34) for channel in range(3))
    return mixed


def draw_amphibian_feet(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], bright: tuple[int, int, int], dark: tuple[int, int, int], sign: int, phase: float) -> None:
    foot_y = min(116, bbox[3] - 2)
    cx = (bbox[0] + bbox[2]) // 2
    crouch = abs(math.cos(phase * 2))
    front_x = cx + sign * int(12 + math.sin(phase) * 8)
    back_x = cx - sign * int(12 - math.sin(phase) * 8)
    draw.line((cx - sign * 4, foot_y - 16, front_x, foot_y - 6, front_x + sign * 9, foot_y), fill=(*bright, 135), width=3)
    draw.line((cx + sign * 4, foot_y - 14, back_x, foot_y - 4, back_x - sign * 8, foot_y), fill=(*dark, 125), width=3)
    if crouch > 0.8:
        draw.ellipse((front_x + sign * 4 - 3, foot_y - 2, front_x + sign * 14, foot_y + 2), fill=(*tint, 95))


def draw_biped_stride(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], bright: tuple[int, int, int], dark: tuple[int, int, int], sign: int, phase: float, locomotion_plan: str) -> None:
    foot_y = min(116, bbox[3] - 2)
    cx = (bbox[0] + bbox[2]) // 2
    front = math.sin(phase)
    back = -front
    front_x = cx + sign * int(12 + front * 10)
    back_x = cx - sign * int(12 + back * 10)
    heavy = locomotion_plan in {"armored_biped", "beast_biped"}
    knee_y = foot_y - (10 if heavy else 12)
    hip_y = foot_y - (24 if heavy else 26)
    width = 5 if heavy else 4
    draw.line((cx - sign * 6, hip_y, front_x, knee_y, front_x + sign * 8, foot_y), fill=(*bright, 155), width=width)
    draw.line((cx + sign * 6, hip_y + 1, back_x, knee_y + 2, back_x - sign * 8, foot_y), fill=(*dark, 145), width=width)
    shoulder_y = bbox[1] + 30
    arm_swing = int(math.cos(phase) * 10)
    draw.line((cx, shoulder_y, cx - sign * (16 + arm_swing), shoulder_y + 18), fill=(*dark, 110), width=max(2, width - 1))
    draw.line((cx + sign * 5, shoulder_y + 2, cx + sign * (18 + arm_swing), shoulder_y + 14), fill=(*bright, 108), width=max(2, width - 1))


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def to_res_path(path: Path) -> str:
    return "res://" + path.relative_to(GODOT).as_posix()


if __name__ == "__main__":
    main()

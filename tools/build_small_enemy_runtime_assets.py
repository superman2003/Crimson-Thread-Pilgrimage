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


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
DATA_DIR = GODOT / "data"
OUT_ROOT = GODOT / "assets" / "third_party" / "dark_fantasy_bestiary" / "runtime_keyframes"
ARTIFACT_ROOT = ROOT / "artifacts" / "small_enemy_keyframes"
CONTACT_DIR = ARTIFACT_ROOT / "contact_sheets"

FRAME_SIZE = 128
FRAME_COUNT = 8
PREVIEW_GAP = 40
QUALITY_PROFILE = "shape_aware_walk_attack_v19_no_line_attack_fx"

WALK_STAGES = [
    "contact_a",
    "down_a",
    "passing_a",
    "up_a",
    "contact_b",
    "down_b",
    "passing_b",
    "up_b",
]

ATTACK_STAGES = [
    "ready",
    "anticipation",
    "coil",
    "release",
    "impact",
    "follow_through",
    "recover",
    "settle",
]

ATTACK_POSES: dict[str, list[dict[str, float]]] = {
    "crawler": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -6, "dy": 1, "sx": 0.92, "sy": 1.08, "rot": -5},
        {"dx": -10, "dy": 2, "sx": 0.86, "sy": 1.14, "rot": -8},
        {"dx": 7, "dy": -2, "sx": 1.16, "sy": 0.92, "rot": 5},
        {"dx": 19, "dy": -4, "sx": 1.30, "sy": 0.84, "rot": 9},
        {"dx": 14, "dy": -2, "sx": 1.18, "sy": 0.90, "rot": 7},
        {"dx": 5, "dy": 0, "sx": 1.02, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "flyer": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -5, "dy": -5, "sx": 0.96, "sy": 1.06, "rot": -10},
        {"dx": -8, "dy": -9, "sx": 0.92, "sy": 1.12, "rot": -18},
        {"dx": 7, "dy": -5, "sx": 1.14, "sy": 0.92, "rot": 18},
        {"dx": 20, "dy": 3, "sx": 1.26, "sy": 0.86, "rot": 28},
        {"dx": 14, "dy": 6, "sx": 1.12, "sy": 0.94, "rot": 20},
        {"dx": 4, "dy": 2, "sx": 1.02, "sy": 0.98, "rot": 8},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "shooter": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -4, "dy": 0, "sx": 0.96, "sy": 1.05, "rot": -3},
        {"dx": -7, "dy": 1, "sx": 0.90, "sy": 1.12, "rot": -5},
        {"dx": 1, "dy": -2, "sx": 1.05, "sy": 0.98, "rot": 2},
        {"dx": 8, "dy": -2, "sx": 1.12, "sy": 0.93, "rot": 4},
        {"dx": 3, "dy": 0, "sx": 1.02, "sy": 1.00, "rot": -3},
        {"dx": -2, "dy": 1, "sx": 0.98, "sy": 1.02, "rot": -2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "caster": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -2, "dy": -1, "sx": 0.98, "sy": 1.05, "rot": -2},
        {"dx": -4, "dy": -4, "sx": 0.94, "sy": 1.12, "rot": -4},
        {"dx": 0, "dy": -7, "sx": 1.03, "sy": 1.08, "rot": 1},
        {"dx": 7, "dy": -8, "sx": 1.10, "sy": 1.00, "rot": 5},
        {"dx": 5, "dy": -4, "sx": 1.05, "sy": 1.02, "rot": 3},
        {"dx": 1, "dy": -1, "sx": 1.01, "sy": 1.00, "rot": 1},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "charger": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -7, "dy": 1, "sx": 0.94, "sy": 1.08, "rot": -5},
        {"dx": -12, "dy": 2, "sx": 0.88, "sy": 1.14, "rot": -9},
        {"dx": 9, "dy": -1, "sx": 1.18, "sy": 0.92, "rot": 6},
        {"dx": 23, "dy": -2, "sx": 1.34, "sy": 0.86, "rot": 10},
        {"dx": 17, "dy": 0, "sx": 1.20, "sy": 0.92, "rot": 7},
        {"dx": 6, "dy": 1, "sx": 1.03, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "duelist": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -5, "dy": 0, "sx": 0.94, "sy": 1.07, "rot": -7},
        {"dx": -9, "dy": 1, "sx": 0.88, "sy": 1.14, "rot": -12},
        {"dx": 4, "dy": -2, "sx": 1.10, "sy": 0.96, "rot": 8},
        {"dx": 16, "dy": -3, "sx": 1.24, "sy": 0.88, "rot": 16},
        {"dx": 11, "dy": -1, "sx": 1.14, "sy": 0.92, "rot": 18},
        {"dx": 3, "dy": 0, "sx": 1.02, "sy": 0.99, "rot": 6},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
    "heavy": [
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
        {"dx": -4, "dy": -1, "sx": 0.98, "sy": 1.06, "rot": -4},
        {"dx": -8, "dy": -6, "sx": 0.94, "sy": 1.16, "rot": -10},
        {"dx": 1, "dy": -8, "sx": 1.06, "sy": 1.10, "rot": 7},
        {"dx": 13, "dy": -1, "sx": 1.20, "sy": 0.88, "rot": 13},
        {"dx": 10, "dy": 3, "sx": 1.14, "sy": 0.86, "rot": 9},
        {"dx": 3, "dy": 1, "sx": 1.02, "sy": 0.98, "rot": 2},
        {"dx": 0, "dy": 0, "sx": 1.00, "sy": 1.00, "rot": 0},
    ],
}

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

SOURCE_SEQUENCE_OVERRIDES: dict[str, dict[str, list[int]]] = {
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png": {
        "walk": [5, 3, 1, 0, 5, 3, 1, 0],
        "attack": [5, 6, 8, 9, 7, 8, 6, 5],
    },
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png": {
        "walk": [5, 3, 1, 0, 5, 3, 1, 0],
        "attack": [5, 6, 8, 9, 7, 8, 6, 5],
    },
    "surt-emceeflesher-spitsnail-alpha_0.png": {
        "walk": [0, 1, 2, 3, 0, 1, 2, 3],
        "attack": [10, 11, 12, 13, 14, 15, 16, 17],
    },
}

CONNECTED_COMPONENT_SOURCES = {
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png",
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png",
}

CHROMA_KEY_SOURCES = {
    "redshrike-emceeflesher-eyewasp-alpha.png",
    "redshrike-emceeflesher-skullwasp-alpha.png",
    "redshrike-emceeflesher-wasp.png",
}

DETACHED_THIN_ARTIFACT_SOURCES = {
    "calciumtrice-emceeflesher-worm-alpha.png",
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

FOOTLESS_RESHAPE_PLANS = {
    "hunched_shambler",
    "amphibian_hop",
    "armored_biped",
    "beast_biped",
    "biped_imp",
}

FOOTLESS_AUDIT_KINDS = [
    "root_cage_hunter",
    "silent_bugbler",
    "moss_larva",
    "echo_moss_larva",
    "thorn_sentinel",
    "corridor_heavy",
    "erasure_bailiff",
    "falling_clapper",
    "obsidian_bellwheel",
    "echo_waterwheel_knight",
    "gear_sentinel",
    "waterwheel_knight",
    "wax_lancer",
    "obsidian_spearman",
]


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


def expand_frames(frames: list[Image.Image], count: int) -> list[Image.Image]:
    result: list[Image.Image] = []
    for index in range(count):
        source = frames[index % len(frames)]
        result.append(source.copy())
    return result


def build_frame_bank(source_name: str, image: Image.Image, cell_w: int, cell_h: int) -> list[Image.Image]:
    if source_name in CONNECTED_COMPONENT_SOURCES:
        return build_connected_component_frame_bank(image)
    frames: list[Image.Image] = []
    for y in range(0, image.height, cell_h):
        for x in range(0, image.width, cell_w):
            if x + cell_w > image.width or y + cell_h > image.height:
                continue
            frame = image.crop((x, y, x + cell_w, y + cell_h))
            if source_name in CHROMA_KEY_SOURCES:
                frame = remove_flat_source_background(frame)
            if source_name in DETACHED_THIN_ARTIFACT_SOURCES:
                frame = remove_detached_thin_source_artifacts(frame)
            if frame.getchannel("A").getbbox() is not None:
                frames.append(frame)
            else:
                frames.append(Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0)))
    return frames


def remove_flat_source_background(image: Image.Image) -> Image.Image:
    frame = image.convert("RGBA")
    pixels = frame.load()
    candidates: dict[tuple[int, int, int], int] = {}
    for x in range(frame.width):
        for y in (0, frame.height - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_likely_flat_sheet_background(red, green, blue):
                candidates[(red, green, blue)] = candidates.get((red, green, blue), 0) + 1
    for y in range(frame.height):
        for x in (0, frame.width - 1):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_likely_flat_sheet_background(red, green, blue):
                candidates[(red, green, blue)] = candidates.get((red, green, blue), 0) + 1
    if not candidates:
        return frame
    key = max(candidates.items(), key=lambda item: item[1])[0]
    for y in range(frame.height):
        for x in range(frame.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and color_distance_sq((red, green, blue), key) <= 28 * 28:
                pixels[x, y] = (red, green, blue, 0)
    return frame


def remove_detached_thin_source_artifacts(image: Image.Image) -> Image.Image:
    frame = image.convert("RGBA")
    pixels = frame.load()
    for area, bbox, points in connected_components_for_image(frame):
        x0, y0, x1, y1 = bbox
        width = x1 - x0
        height = y1 - y0
        aspect = width / max(1, height)
        if area <= 80 and width >= 18 and height <= 3 and aspect >= 6 and y0 < frame.height * 0.72:
            for x, y in points:
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return frame


def is_likely_flat_sheet_background(red: int, green: int, blue: int) -> bool:
    strong_blue = blue > 170 and red < 80 and green < 110
    purple = blue > 85 and red > 45 and red < 135 and green < 60
    return strong_blue or purple


def color_distance_sq(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def build_connected_component_frame_bank(image: Image.Image) -> list[Image.Image]:
    components = connected_components_for_image(image)
    frames: list[Image.Image] = []
    for _area, bbox, points in components:
        x0, y0, x1, y1 = bbox
        pad = 4
        crop_box = (max(0, x0 - pad), max(0, y0 - pad), min(image.width, x1 + pad), min(image.height, y1 + pad))
        crop = Image.new("RGBA", (crop_box[2] - crop_box[0], crop_box[3] - crop_box[1]), (0, 0, 0, 0))
        source = image.load()
        target = crop.load()
        for x, y in points:
            if crop_box[0] <= x < crop_box[2] and crop_box[1] <= y < crop_box[3]:
                target[x - crop_box[0], y - crop_box[1]] = source[x, y]
        frames.append(crop)
    return frames


def connected_components_for_image(image: Image.Image) -> list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]]:
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    result: list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or pixels[x, y][3] <= 0:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            points: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                points.append((px, py))
                for nx in (px - 1, px, px + 1):
                    for ny in (py - 1, py, py + 1):
                        if nx < 0 or ny < 0 or nx >= width or ny >= height:
                            continue
                        if (nx, ny) in seen or pixels[nx, ny][3] <= 0:
                            continue
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(points) < 20:
                continue
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
            result.append((len(points), bbox, points))
    return sorted(result, key=lambda item: (item[1][1], item[1][0]))


def select_source_frames(source_name: str, frame_bank: list[Image.Image], track: str, preferred_index: int, count: int) -> list[Image.Image]:
    override = SOURCE_SEQUENCE_OVERRIDES.get(source_name, {}).get(track)
    if override:
        selected = [
            frame_bank[index].copy()
            for index in override
            if 0 <= index < len(frame_bank) and frame_bank[index].getchannel("A").getbbox() is not None
        ]
        if selected:
            return expand_frames(selected, count)
    fallback = build_frames_from_bank(frame_bank, preferred_index)
    return expand_frames(fallback, count)


def build_frames_from_bank(frame_bank: list[Image.Image], preferred_index: int) -> list[Image.Image]:
    tiles: list[tuple[int, Image.Image, int, tuple[int, int, int, int]]] = []
    for index, frame in enumerate(frame_bank):
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            continue
        if looks_like_label_tile(frame):
            continue
        tiles.append((index, frame, alpha_area(frame), bbox))
    if not tiles:
        return []
    tiles = filter_actor_tiles(tiles)
    after = [frame for index, frame, _area, _bbox in tiles if index >= preferred_index]
    before = [frame for index, frame, _area, _bbox in tiles if index < preferred_index]
    ordered = after + before
    while len(ordered) < 6:
        ordered.extend(ordered)
    return [frame.copy() for frame in ordered[:8]]


def filter_actor_tiles(tiles: list[tuple[int, Image.Image, int, tuple[int, int, int, int]]]) -> list[tuple[int, Image.Image, int, tuple[int, int, int, int]]]:
    max_area = max(area for _index, _frame, area, _bbox in tiles)
    max_width = max(bbox[2] - bbox[0] for _index, _frame, _area, bbox in tiles)
    max_height = max(bbox[3] - bbox[1] for _index, _frame, _area, bbox in tiles)
    min_area = max(18, int(max_area * 0.24))
    min_width = max(4, int(max_width * 0.25))
    min_height = max(4, int(max_height * 0.25))
    filtered = [
        tile for tile in tiles
        if tile[2] >= min_area
        and tile[3][2] - tile[3][0] >= min_width
        and tile[3][3] - tile[3][1] >= min_height
    ]
    return filtered or tiles


def looks_like_label_tile(frame: Image.Image) -> bool:
    tile = frame.convert("RGBA")
    pixels = tile.load()
    opaque_count = 0
    white = 0
    pale = 0
    colored = 0
    for y in range(tile.height):
        for x in range(tile.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= 0:
                continue
            opaque_count += 1
            if red > 215 and green > 215 and blue > 215:
                white += 1
            if red > 175 and green > 175 and blue > 175:
                pale += 1
            if max(red, green, blue) - min(red, green, blue) > 45:
                colored += 1
    if opaque_count == 0:
        return False
    white_ratio = white / opaque_count
    pale_ratio = pale / opaque_count
    colored_ratio = colored / opaque_count
    return white_ratio > 0.34 and pale_ratio > 0.48 and colored_ratio < 0.34


def alpha_area(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    if hasattr(alpha, "get_flattened_data"):
        return sum(1 for value in alpha.get_flattened_data() if value > 0)
    return sum(1 for value in alpha.getdata() if value > 0)


def normalize_frame(source: Image.Image, tint: tuple[int, int, int], style: str, index: int, rng: random.Random) -> Image.Image:
    crop = trim_alpha(source)
    crop = ImageEnhance.Contrast(crop).enhance(1.08)
    crop = ImageEnhance.Color(crop).enhance(1.10)
    crop = tint_image(crop, tint, 0.16 + (index % 3) * 0.025)
    bbox = crop.getbbox()
    if bbox is None:
        return Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    max_w, max_h = max_dimensions(style)
    scale = min(max_w / max(1, crop.width), max_h / max(1, crop.height))
    scale *= 0.96 + rng.random() * 0.04
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return add_edge_light(canvas, tint)


def max_dimensions(style: str) -> tuple[int, int]:
    if style == "heavy":
        return (76, 84)
    if style in {"caster", "charger"}:
        return (70, 82)
    if style == "flyer":
        return (72, 64)
    if style == "crawler":
        return (72, 56)
    return (68, 74)


def trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    pad = 3
    return image.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(image.width, bbox[2] + pad), min(image.height, bbox[3] + pad)))


def tint_image(image: Image.Image, tint: tuple[int, int, int], strength: float) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            pixels[x, y] = (
                int(r * (1 - strength) + tint[0] * strength),
                int(g * (1 - strength) + tint[1] * strength),
                int(b * (1 - strength) + tint[2] * strength),
                a,
            )
    return rgba


def add_edge_light(image: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    alpha = image.getchannel("A")
    glow = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    edge = Image.new("RGBA", image.size, (*tint, 0))
    edge.putalpha(glow.point(lambda value: min(90, value // 3)))
    result = Image.alpha_composite(edge, image)
    return result


def reshape_footless_frame(image: Image.Image, locomotion_plan: str, tint: tuple[int, int, int], style: str, index: int) -> Image.Image:
    if locomotion_plan not in FOOTLESS_RESHAPE_PLANS:
        return image
    frame = image.copy()
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return frame

    body_cx = weighted_alpha_center_x(frame, bbox)
    ratio = {
        "hunched_shambler": 0.72,
        "amphibian_hop": 0.58,
        "armored_biped": 0.62,
        "beast_biped": 0.58,
        "biped_imp": 0.60,
    }.get(locomotion_plan, 0.64)
    max_erase = {
        "hunched_shambler": 18,
        "amphibian_hop": 24,
        "armored_biped": 27,
        "beast_biped": 30,
        "biped_imp": 28,
    }.get(locomotion_plan, 24)
    height = bbox[3] - bbox[1]
    cut_y = max(bbox[1] + int(height * ratio), bbox[3] - max_erase)
    cut_y = min(cut_y, bbox[3] - 8)
    bottom_y = min(FRAME_SIZE - 4, bbox[3] + 1)
    band_w = footless_band_width(bbox, locomotion_plan)
    x0 = max(2, body_cx - band_w // 2)
    x1 = min(FRAME_SIZE - 3, body_cx + band_w // 2)

    alpha = frame.getchannel("A")
    alpha_draw = ImageDraw.Draw(alpha)
    alpha_draw.rectangle((x0, cut_y - 2, x1, min(FRAME_SIZE - 1, bottom_y + 4)), fill=0)
    frame.putalpha(alpha)

    draw = ImageDraw.Draw(frame, "RGBA")
    base = dominant_region_color(image, (max(0, x0 - 4), max(0, cut_y - 18), min(FRAME_SIZE, x1 + 4), max(cut_y, bottom_y)), tint)
    bright = tuple(min(255, channel + 34) for channel in base)
    dark = tuple(max(0, channel - 58) for channel in base)
    accent = tuple(min(255, channel + 18) for channel in tint)
    sway = int(math.sin(index / FRAME_COUNT * math.tau) * 3)

    if locomotion_plan == "hunched_shambler":
        draw_continuous_root_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark, accent)
    elif locomotion_plan == "armored_biped":
        draw_continuous_armor_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "beast_biped":
        draw_continuous_hide_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "biped_imp":
        draw_continuous_imp_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    elif locomotion_plan == "amphibian_hop":
        draw_continuous_amphibian_base(draw, x0, x1, cut_y, bottom_y, body_cx + sway, base, bright, dark)
    return frame


def weighted_alpha_center_x(image: Image.Image, bbox: tuple[int, int, int, int]) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    top = bbox[1]
    bottom = bbox[1] + int((bbox[3] - bbox[1]) * 0.72)
    total = 0
    weighted = 0
    for y in range(top, max(top + 1, bottom)):
        for x in range(bbox[0], bbox[2]):
            value = pixels[x, y]
            if value <= 24:
                continue
            total += value
            weighted += x * value
    if total == 0:
        return (bbox[0] + bbox[2]) // 2
    return int(weighted / total)


def footless_band_width(bbox: tuple[int, int, int, int], locomotion_plan: str) -> int:
    width = bbox[2] - bbox[0]
    factor = {
        "hunched_shambler": 0.84,
        "amphibian_hop": 0.76,
        "armored_biped": 0.88,
        "beast_biped": 0.86,
        "biped_imp": 0.82,
    }.get(locomotion_plan, 0.72)
    return max(30, min(62, int(width * factor)))


def footless_base_color(image: Image.Image, region: tuple[int, int, int, int], tint: tuple[int, int, int]) -> tuple[int, int, int]:
    sampled = dominant_region_color(image, region, tint)
    mixed = tuple(int(sampled[channel] * 0.68 + tint[channel] * 0.32) for channel in range(3))
    if sum(mixed) < 100:
        mixed = tuple(int(tint[channel] * 0.58 + 34) for channel in range(3))
    return mixed


def dominant_region_color(image: Image.Image, region: tuple[int, int, int, int], fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    pixels = image.load()
    counts: dict[tuple[int, int, int], int] = {}
    x0, y0, x1, y1 = region
    for y in range(max(0, y0), min(image.height, y1)):
        for x in range(max(0, x0), min(image.width, x1)):
            r, g, b, a = pixels[x, y]
            if a <= 32:
                continue
            key = (r // 24 * 24, g // 24 * 24, b // 24 * 24)
            counts[key] = counts.get(key, 0) + int(a)
    if not counts:
        return fallback
    return max(counts.items(), key=lambda item: item[1])[0]


def draw_integrated_base_texture(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
    phase_seed: int,
) -> None:
    width = max(1, x1 - x0)
    for band in range(3):
        y = cut_y + 5 + band * max(3, (bottom_y - cut_y) // 4)
        inset = 4 + band * 2
        alpha = 82 - band * 12
        draw.line((x0 + inset, y, x1 - inset, y), fill=(*bright, alpha), width=1)
    for mark in range(9):
        x = x0 + 5 + (mark * 7 + phase_seed * 3) % max(8, width - 10)
        y = cut_y + 4 + (mark * 5 + phase_seed) % max(6, bottom_y - cut_y - 4)
        color = bright if mark % 3 == 0 else dark
        draw.rectangle((x, y, x + 2, y + 1), fill=(*color, 78))


def draw_continuous_root_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
    accent: tuple[int, int, int],
) -> None:
    top_w = max(20, int((x1 - x0) * 0.58))
    points = [
        (cx - top_w // 2, cut_y - 3),
        (cx + top_w // 2, cut_y - 3),
        (x1 - 2, bottom_y - 6),
        (x1 - 8, bottom_y),
        (x0 + 7, bottom_y),
        (x0 + 1, bottom_y - 6),
    ]
    draw.polygon(points, fill=(*base, 238))
    draw.line((x0 + 8, bottom_y - 1, x1 - 8, bottom_y - 1), fill=(*dark, 220), width=3)
    draw.line((x0 + 10, cut_y + 5, x1 - 10, cut_y + 5), fill=(*bright, 96), width=2)
    draw.line((x0 + 12, bottom_y - 7, x1 - 12, bottom_y - 7), fill=(*dark, 126), width=2)
    draw.arc((x0 + 5, bottom_y - 9, x1 - 5, bottom_y + 5), 190, 350, fill=(*accent, 94), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_armor_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(24, int((x1 - x0) * 0.62))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 2),
            (cx + top_w // 2, cut_y - 2),
            (x1 - 4, bottom_y - 4),
            (x1 - 10, bottom_y),
            (x0 + 10, bottom_y),
            (x0 + 4, bottom_y - 4),
        ],
        fill=(*base, 242),
    )
    draw.rectangle((x0 + 9, bottom_y - 5, x1 - 9, bottom_y - 2), fill=(*dark, 210))
    draw.line((x0 + 12, cut_y + 8, x1 - 12, cut_y + 8), fill=(*bright, 118), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_hide_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(24, int((x1 - x0) * 0.56))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 3),
            (cx + top_w // 2, cut_y - 3),
            (x1 - 4, bottom_y - 7),
            (x1 - 15, bottom_y),
            (cx + 3, bottom_y - 3),
            (x0 + 13, bottom_y),
            (x0 + 3, bottom_y - 7),
        ],
        fill=(*base, 236),
    )
    draw.line((x0 + 9, bottom_y - 2, x1 - 11, bottom_y - 2), fill=(*dark, 198), width=3)
    draw.line((x0 + 11, cut_y + 6, x1 - 11, cut_y + 6), fill=(*bright, 104), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_imp_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    top_w = max(18, int((x1 - x0) * 0.48))
    draw.polygon(
        [
            (cx - top_w // 2, cut_y - 3),
            (cx + top_w // 2, cut_y - 3),
            (x1 - 5, bottom_y - 6),
            (x1 - 14, bottom_y),
            (x0 + 13, bottom_y),
            (x0 + 5, bottom_y - 6),
        ],
        fill=(*base, 238),
    )
    draw.rectangle((x0 + 11, bottom_y - 5, x1 - 11, bottom_y - 2), fill=(*dark, 190))
    draw.line((x0 + 10, cut_y + 5, x1 - 10, cut_y + 5), fill=(*bright, 108), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def draw_continuous_amphibian_base(
    draw: ImageDraw.ImageDraw,
    x0: int,
    x1: int,
    cut_y: int,
    bottom_y: int,
    cx: int,
    base: tuple[int, int, int],
    bright: tuple[int, int, int],
    dark: tuple[int, int, int],
) -> None:
    draw.ellipse((x0 + 2, cut_y - 5, x1 - 2, bottom_y + 2), fill=(*base, 230))
    draw.arc((x0 + 6, cut_y - 2, x1 - 6, bottom_y + 2), 200, 340, fill=(*dark, 180), width=3)
    draw.line((cx - 9, cut_y + 1, cx + 10, cut_y + 4), fill=(*bright, 125), width=2)
    draw_integrated_base_texture(draw, x0, x1, cut_y, bottom_y, bright, dark, cx)


def make_idle_frame(base: Image.Image, index: int, tint: tuple[int, int, int]) -> Image.Image:
    y = int(math.sin(index / 4 * math.tau) * 2)
    return offset_frame(base, 0, y, tint, 0.10)


def make_walk_frame(base: Image.Image, index: int, direction: str, style: str, tint: tuple[int, int, int], locomotion_plan: str) -> Image.Image:
    phase = index / FRAME_COUNT * math.tau
    stride = math.sin(phase)
    sign = 1 if direction == "right" else -1
    lift, bob, squash, stretch, lean, walk_stride = walk_pose_values(style, locomotion_plan, stride, phase)
    body = apply_walk_pose(base, stretch, squash, lean * sign)
    x = int(stride * walk_stride) * sign
    frame = offset_frame(body, x, int(lift + bob), tint, 0.14)
    draw_shape_aware_walk_motion(frame, index, style, tint, sign, locomotion_plan)
    draw_motion_dust(frame, index, tint, style, locomotion_plan)
    return contain_alpha(sharpen_alpha(frame), 3)


def walk_pose_values(style: str, locomotion_plan: str, stride: float, phase: float) -> tuple[float, int, float, float, float, int]:
    if locomotion_plan == "snail_slide":
        return 0, int(math.cos(phase * 2) * 1), 0.96 - 0.025 * abs(stride), 1.04 + 0.035 * abs(stride), stride * 1.2, 8
    if locomotion_plan == "worm_slither":
        return -abs(stride) * 2, int(math.cos(phase * 2) * 2), 0.92 - 0.030 * abs(stride), 1.10 + 0.060 * abs(stride), stride * 4.5, 10
    if locomotion_plan == "winged_hover":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 3), 0.98, 1.02 + 0.030 * abs(stride), stride * 8.0, 8
    if locomotion_plan == "tendril_float":
        return -abs(stride) * 2, int(math.cos(phase * 2) * 3), 0.97 - 0.020 * abs(stride), 1.04 + 0.035 * abs(stride), stride * 3.5, 7
    if locomotion_plan == "flame_wisp":
        return -abs(stride) * 3, int(math.cos(phase * 2) * 4), 0.95 - 0.035 * abs(stride), 1.08 + 0.050 * abs(stride), stride * 5.5, 8
    if locomotion_plan == "amphibian_hop":
        return -abs(stride) * 7, int(math.cos(phase * 2) * 2), 0.93 - 0.045 * abs(math.cos(phase * 2)), 1.08 + 0.060 * abs(stride), stride * 5.0, 10
    if locomotion_plan == "armored_biped":
        return -abs(stride) * 3, int(math.cos(phase * 2) * 1), 0.98 - 0.025 * abs(math.cos(phase * 2)), 1.03 + 0.030 * abs(stride), stride * 4.0, 7
    if locomotion_plan == "beast_biped":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 2), 0.96 - 0.035 * abs(math.cos(phase * 2)), 1.06 + 0.045 * abs(stride), stride * 5.5, 9
    if locomotion_plan == "hunched_shambler":
        return -abs(stride) * 4, int(math.cos(phase * 2) * 2), 0.94 - 0.040 * abs(math.cos(phase * 2)), 1.07 + 0.050 * abs(stride), stride * 4.5, 8
    return -abs(stride) * (5 if style != "heavy" else 3), int(math.cos(phase * 2) * 2), 0.96, 1.05, stride * 5.0, 8


def apply_walk_pose(base: Image.Image, sx: float, sy: float, rotation: float) -> Image.Image:
    crop = trim_alpha(base)
    crop = crop.resize((max(1, round(crop.width * sx)), max(1, round(crop.height * sy))), Image.Resampling.NEAREST)
    if abs(rotation) > 0.1:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return canvas


def draw_shape_aware_walk_motion(frame: Image.Image, index: int, style: str, tint: tuple[int, int, int], sign: int, locomotion_plan: str) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (44, 48, 84, 108)
    foot_y = min(116, bbox[3] - 2)
    cx = (bbox[0] + bbox[2]) // 2
    phase = index / FRAME_COUNT * math.tau
    bright = tuple(min(255, channel + 28) for channel in tint)
    dark = tuple(max(0, channel - 48) for channel in tint)

    if locomotion_plan == "snail_slide":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    if locomotion_plan == "worm_slither":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        draw_slither_marks(draw, bbox, tint, phase)
        return

    if locomotion_plan == "winged_hover":
        draw_hover_shadow(draw, bbox, tint)
        return

    if locomotion_plan in {"tendril_float", "flame_wisp", "hunched_shambler"}:
        draw_tendril_sway(draw, bbox, tint, bright, dark, phase)
        if locomotion_plan == "hunched_shambler":
            draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    if locomotion_plan == "amphibian_hop":
        draw_slug_trail(draw, bbox, tint, sign, phase)
        return

    draw_slug_trail(draw, bbox, tint, sign, phase)


def draw_slug_trail(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], sign: int, phase: float) -> None:
    y = min(116, bbox[3] - 2)
    for mark in range(4):
        x = bbox[0] - sign * (mark * 8 + int(math.sin(phase + mark) * 2))
        draw.ellipse((x, y + mark % 2, x + 10, y + 3 + mark % 2), fill=(*tint, 28))


def draw_slither_marks(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], phase: float) -> None:
    base_y = min(116, bbox[3] - 3)
    for mark in range(3):
        x = bbox[0] + 8 + mark * max(6, (bbox[2] - bbox[0]) // 4)
        y = base_y - int(abs(math.sin(phase + mark)) * 5)
        draw.arc((x - 7, y - 4, x + 8, y + 7), 180, 350, fill=(*tint, 88), width=2)


def draw_hover_shadow(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int]) -> None:
    draw.ellipse((bbox[0] + 14, bbox[3] + 5, bbox[2] - 12, bbox[3] + 8), fill=(*tint, 18))


def draw_tendril_sway(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], tint: tuple[int, int, int], bright: tuple[int, int, int], dark: tuple[int, int, int], phase: float) -> None:
    cx = (bbox[0] + bbox[2]) // 2
    foot_y = min(116, bbox[3] - 2)
    hem_y = bbox[3] - 8
    for tendril in range(3):
        sway = int(math.sin(phase + tendril * 1.2) * 7)
        x0 = cx - 12 + tendril * 12
        color = bright if tendril % 2 == 0 else dark
        draw.ellipse((x0 + sway - 3, hem_y - 2, x0 + sway + 4, foot_y), fill=(*color, 62))


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


def make_attack_frame(base: Image.Image, index: int, direction: str, style: str, tint: tuple[int, int, int], locomotion_plan: str, native_attack: bool = False) -> Image.Image:
    pose = apply_locomotion_attack_bias(amplified_attack_pose(style, index), locomotion_plan, index)
    if native_attack:
        pose = tone_down_native_attack_pose(pose, index)
    sign = 1 if direction == "right" else -1
    body = apply_attack_pose(base, pose, sign)
    frame = offset_frame(body, int(pose["dx"]) * sign, int(pose["dy"]), tint, 0.22)
    if native_attack:
        draw_native_attack_readability(frame, index, tint, sign)
    elif locomotion_plan == "hunched_shambler":
        draw_root_shambler_attack(frame, index, tint, sign)
    elif locomotion_plan == "worm_slither":
        draw_worm_slither_attack(frame, index, tint, sign)
    elif locomotion_plan == "snail_slide":
        draw_snail_slide_attack(frame, index, tint, sign)
    elif locomotion_plan == "winged_hover":
        draw_winged_hover_attack(frame, index, tint, sign)
    elif locomotion_plan in {"tendril_float", "flame_wisp"}:
        draw_floating_body_attack(frame, index, tint, sign, locomotion_plan)
    elif locomotion_plan in {"armored_biped", "beast_biped", "biped_imp"}:
        draw_source_biped_attack(frame, index, tint, sign, locomotion_plan, style)
    else:
        draw_source_locked_fallback_attack(frame, index, tint, sign, locomotion_plan, style)
    return contain_alpha(sharpen_alpha(frame), 2)


def tone_down_native_attack_pose(pose: dict[str, float], index: int) -> dict[str, float]:
    stage = ATTACK_STAGES[index]
    tuned = dict(pose)
    tuned["dx"] = {"ready": 0, "anticipation": -4, "coil": -7, "release": 7, "impact": 13, "follow_through": 8, "recover": 3, "settle": 0}[stage]
    tuned["dy"] = {"ready": 0, "anticipation": 1, "coil": 2, "release": -1, "impact": -2, "follow_through": -1, "recover": 0, "settle": 0}[stage]
    tuned["rot"] = float(tuned["rot"]) * 0.22
    tuned["sx"] = 1.0 + (float(tuned["sx"]) - 1.0) * 0.22
    tuned["sy"] = 1.0 + (float(tuned["sy"]) - 1.0) * 0.22
    return tuned


def draw_native_attack_readability(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 48, 86, 108)
    height = bbox[3] - bbox[1]
    mouth_y = bbox[1] + int(height * 0.42)
    ground_y = min(116, bbox[3] - 2)
    front_x = bbox[2] if sign > 0 else bbox[0]
    if stage in {"release", "impact", "follow_through"}:
        bright = tuple(min(255, channel + 42) for channel in tint)
        dark = tuple(max(0, channel - 62) for channel in tint)
        alpha = 122 if stage == "impact" else 78
        mark_x = front_x - sign * 6
        draw.ellipse((mark_x - 3, mouth_y - 4, mark_x + 3, mouth_y + 2), fill=(*bright, alpha))
        draw.ellipse((mark_x - 5, mouth_y + 1, mark_x + 2, mouth_y + 5), fill=(*dark, int(alpha * 0.54)))
        draw.ellipse((bbox[0] + 5, ground_y + 1, bbox[2] - 5, ground_y + 4), fill=(*tint, 26 if stage != "impact" else 42))


def draw_root_shambler_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (44, 42, 84, 112)
    root_y = min(116, bbox[3] - 3)
    front_x = bbox[2] if sign > 0 else bbox[0]
    back_x = bbox[0] if sign > 0 else bbox[2]
    width = bbox[2] - bbox[0]
    base = dominant_region_color(frame, (bbox[0], max(0, bbox[3] - 24), bbox[2], bbox[3]), tint)
    bright = tuple(min(255, channel + 38) for channel in base)
    dark = tuple(max(0, channel - 54) for channel in base)
    reach = {
        "ready": 4,
        "anticipation": -5,
        "coil": -9,
        "release": 11,
        "impact": 19,
        "follow_through": 15,
        "recover": 7,
        "settle": 3,
    }[stage]
    phase = index / FRAME_COUNT * math.tau
    draw.ellipse((bbox[0] + 4, root_y + 1, bbox[2] - 3, root_y + 5), fill=(*dark, 72))
    if stage in {"anticipation", "coil"}:
        for mark in range(3):
            x0 = back_x - sign * (4 + mark * 7)
            y0 = root_y - 2 - mark
            draw.ellipse((x0 - 4, y0 - 2, x0 + 4, y0 + 3), fill=(*dark, 54))
    for strand in range(3):
        start_x = front_x - sign * (4 + strand * max(3, width // 9))
        start_y = root_y - 5 - strand
        end_x = front_x + sign * (max(-3, min(9, reach)) + strand * 3)
        end_y = root_y - 3 + int(math.sin(phase + strand) * 2)
        if stage in {"ready", "settle"}:
            end_x = front_x + sign * (3 + strand * 3)
        color = bright if strand == 1 else base
        alpha = 138 if stage == "impact" else 104
        draw.polygon(
            [
                (start_x, start_y - 2),
                (end_x, end_y - 3),
                (end_x + sign * 3, end_y + 2),
                (start_x - sign * 2, start_y + 3),
            ],
            fill=(*color, alpha),
        )
        if stage == "impact" and strand == 1:
            draw.ellipse((end_x - 3, end_y - 4, end_x + 4, end_y + 3), fill=(*bright, 116))


def draw_worm_slither_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 54, 86, 112)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    ground_y = min(116, bbox[3] - 2)
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 42) for channel in base)
    dark = tuple(max(0, channel - 60) for channel in base)
    reach = {
        "ready": 2,
        "anticipation": -4,
        "coil": -7,
        "release": 7,
        "impact": 13,
        "follow_through": 9,
        "recover": 4,
        "settle": 1,
    }[stage]
    trail_alpha = 52 if stage in {"release", "impact", "follow_through"} else 34
    for mark in range(3):
        x0 = bbox[0] - sign * (mark * 10 + index)
        draw.ellipse((x0, ground_y + mark % 2, x0 + 13, ground_y + 3 + mark % 2), fill=(*dark, trail_alpha))
    if stage in {"release", "impact", "follow_through"}:
        jaw_x = front_x + sign * reach
        upper_y = mid_y - 6
        lower_y = mid_y + 4
        alpha = 132 if stage == "impact" else 92
        draw.polygon(
            [
                (front_x - sign * 5, upper_y - 2),
                (jaw_x, mid_y - 2),
                (front_x - sign * 5, lower_y + 3),
                (front_x - sign * 9, mid_y + 1),
            ],
            fill=(*bright, alpha),
        )
        draw.ellipse((min(front_x, jaw_x) - 3, mid_y - 3, max(front_x, jaw_x) + 2, mid_y + 4), fill=(*dark, int(alpha * 0.44)))


def draw_snail_slide_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (40, 58, 90, 112)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    foot_y = min(116, bbox[3] - 2)
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 36) for channel in base)
    dark = tuple(max(0, channel - 58) for channel in base)
    phase = index / FRAME_COUNT * math.tau
    draw_slug_trail(draw, bbox, tint, sign, phase)
    if stage in {"anticipation", "coil"}:
        draw.ellipse((bbox[0] + 4, foot_y + 1, bbox[2] - 4, foot_y + 5), fill=(*dark, 54))
    if stage in {"release", "impact", "follow_through"}:
        reach = {"release": 6, "impact": 12, "follow_through": 8}[stage]
        sip_x = front_x + sign * reach
        alpha = 118 if stage == "impact" else 82
        draw.ellipse((min(front_x - sign * 2, sip_x) - 3, mid_y - 6, max(front_x - sign * 2, sip_x) + 3, mid_y + 1), fill=(*bright, alpha))
        draw.ellipse((min(front_x - sign * 2, sip_x - sign * 2) - 2, mid_y + 1, max(front_x - sign * 2, sip_x - sign * 2) + 2, mid_y + 7), fill=(*dark, int(alpha * 0.56)))
        for droplet in range(2):
            x = front_x + sign * (4 + droplet * 5)
            y = mid_y + 7 + droplet
            draw.ellipse((x - 1, y - 1, x + 2, y + 1), fill=(*tint, 88))


def draw_winged_hover_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (38, 40, 90, 98)
    cy = (bbox[1] + bbox[3]) // 2
    front_x = bbox[2] if sign > 0 else bbox[0]
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 42) for channel in base)
    if stage in {"release", "impact", "follow_through"}:
        reach = {"release": 7, "impact": 13, "follow_through": 9}[stage]
        tip_x = front_x + sign * min(8, reach)
        tip_y = cy + (2 if stage == "impact" else 0)
        draw.ellipse((min(front_x - sign * 2, tip_x) - 2, tip_y - 3, max(front_x - sign * 2, tip_x) + 2, tip_y + 3), fill=(*bright, 44 if stage == "impact" else 28))
    draw_hover_shadow(draw, bbox, tint)


def draw_floating_body_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 38, 86, 110)
    front_x = bbox[2] if sign > 0 else bbox[0]
    mid_y = (bbox[1] + bbox[3]) // 2
    base = dominant_region_color(frame, bbox, tint)
    bright = tuple(min(255, channel + 46) for channel in base)
    dark = tuple(max(0, channel - 56) for channel in base)
    phase = index / FRAME_COUNT * math.tau
    reach = {
        "ready": 3,
        "anticipation": -5,
        "coil": -8,
        "release": 10,
        "impact": 17,
        "follow_through": 12,
        "recover": 5,
        "settle": 2,
    }[stage]
    if locomotion_plan == "flame_wisp":
        for lick in range(3):
            start_x = front_x - sign * (8 + lick * 4)
            start_y = mid_y - 10 + lick * 8
            end_x = front_x + sign * (max(2, min(8, reach)) + lick * 2)
            end_y = start_y + int(math.sin(phase + lick) * 4)
            alpha = 130 if stage == "impact" else 88
            draw.ellipse((min(start_x, end_x) - 3, min(start_y, end_y) - 3, max(start_x, end_x) + 3, max(start_y, end_y) + 4), fill=(*bright, int(alpha * 0.62)))
            draw.ellipse((min(start_x - sign * 2, end_x - sign * 3) - 2, min(start_y + 2, end_y + 3) - 2, max(start_x - sign * 2, end_x - sign * 3) + 2, max(start_y + 2, end_y + 3) + 2), fill=(*dark, int(alpha * 0.36)))
    else:
        for tendril in range(4):
            start_x = front_x - sign * (4 + tendril * 3)
            start_y = bbox[1] + 16 + tendril * max(6, (bbox[3] - bbox[1]) // 7)
            local_reach = max(-3, min(8, reach))
            bend_x = start_x + sign * (local_reach // 2 + tendril)
            bend_y = start_y + int(math.sin(phase + tendril) * 5)
            end_x = front_x + sign * (max(2, local_reach) + tendril * 2)
            end_y = start_y + int(math.cos(phase + tendril) * 4)
            alpha = 124 if stage == "impact" else 86
            color = bright if tendril % 2 == 0 else dark
            draw.polygon(
                [
                    (start_x, start_y - 3),
                    (bend_x, bend_y - 4),
                    (end_x + sign * 2, end_y),
                    (bend_x, bend_y + 4),
                    (start_x - sign * 2, start_y + 3),
                ],
                fill=(*color, int(alpha * 0.74)),
            )
    draw.ellipse((bbox[0] + 8, bbox[3] + 2, bbox[2] - 8, bbox[3] + 6), fill=(*tint, 22))


def draw_source_biped_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str, style: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 34, 88, 116)
    front_x = bbox[2] if sign > 0 else bbox[0]
    hip_y = bbox[1] + int((bbox[3] - bbox[1]) * 0.66)
    base = dominant_region_color(frame, bbox, tint)
    dark = tuple(max(0, channel - 60) for channel in base)
    if stage in {"anticipation", "coil"}:
        draw.ellipse((front_x - sign * 13, hip_y - 4, front_x - sign * 5, hip_y + 2), fill=(*dark, 58))
    if stage in {"release", "impact", "follow_through"}:
        alpha = 74 if stage == "impact" else 46
        draw.ellipse((front_x - sign * 10, hip_y - 5, front_x + sign * 3, hip_y + 4), fill=(*base, alpha))
    draw.ellipse((bbox[0] + 8, min(116, bbox[3] - 1), bbox[2] - 8, min(120, bbox[3] + 3)), fill=(*tint, 20))


def draw_source_locked_fallback_attack(frame: Image.Image, index: int, tint: tuple[int, int, int], sign: int, locomotion_plan: str, style: str) -> None:
    stage = ATTACK_STAGES[index]
    draw = ImageDraw.Draw(frame, "RGBA")
    bbox = frame.getbbox() or (42, 34, 88, 116)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    front_x = bbox[2] if sign > 0 else bbox[0]
    focus_y = bbox[1] + int(height * (0.50 if style in {"flyer", "caster"} else 0.62))
    base = dominant_region_color(frame, bbox, tint)
    dark = tuple(max(0, channel - 54) for channel in base)
    bright = tuple(min(255, channel + 34) for channel in base)
    if stage in {"anticipation", "coil"}:
        pull = 10 if stage == "coil" else 6
        draw.ellipse((front_x - sign * pull - 5, focus_y - 5, front_x - sign * pull + 5, focus_y + 5), fill=(*dark, 42))
    elif stage in {"release", "impact", "follow_through"}:
        push = {"release": 5, "impact": 9, "follow_through": 6}[stage]
        alpha = 66 if stage == "impact" else 42
        draw.ellipse((front_x - sign * 8, focus_y - 6, front_x + sign * push, focus_y + 6), fill=(*bright, alpha))
    shadow_pad = max(6, width // 7)
    shadow_y = min(117, bbox[3])
    draw.ellipse((bbox[0] + shadow_pad, shadow_y - 1, bbox[2] - shadow_pad, shadow_y + 4), fill=(*tint, 18))


def amplified_attack_pose(style: str, index: int) -> dict[str, float]:
    pose = dict(ATTACK_POSES.get(style, ATTACK_POSES["crawler"])[index])
    stage = ATTACK_STAGES[index]
    dx_factor = {
        "crawler": 1.42,
        "flyer": 1.38,
        "shooter": 1.62,
        "caster": 2.22,
        "charger": 1.34,
        "duelist": 1.46,
        "heavy": 1.52,
    }.get(style, 1.42)
    if stage in {"anticipation", "coil", "release", "impact", "follow_through"}:
        pose["dx"] = float(pose["dx"]) * dx_factor
        pose["rot"] = float(pose["rot"]) * 1.18
        pose["sx"] = 1.0 + (float(pose["sx"]) - 1.0) * 1.22
        pose["sy"] = 1.0 + (float(pose["sy"]) - 1.0) * 1.16
    if style == "flyer":
        pose["rot"] = float(pose["rot"]) * 0.62
        pose["sx"] = 1.0 + (float(pose["sx"]) - 1.0) * 0.58
        pose["sy"] = 1.0 + (float(pose["sy"]) - 1.0) * 0.58
    return pose


def apply_locomotion_attack_bias(pose: dict[str, float], locomotion_plan: str, index: int) -> dict[str, float]:
    stage = ATTACK_STAGES[index]
    biased = dict(pose)
    if locomotion_plan == "winged_hover" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 5, "impact": 9, "follow_through": 6}[stage]
        biased["rot"] = float(biased["rot"]) + {"release": 2, "impact": 4, "follow_through": 2}[stage]
    elif locomotion_plan in {"tendril_float", "flame_wisp"} and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 6, "impact": 12, "follow_through": 8}[stage]
        biased["sy"] = 1.0 + (float(biased["sy"]) - 1.0) * 1.2
    elif locomotion_plan == "snail_slide" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 8, "impact": 14, "follow_through": 10}[stage]
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 1.35
    elif locomotion_plan == "worm_slither" and stage in {"release", "impact", "follow_through"}:
        biased["dx"] = float(biased["dx"]) + {"release": 7, "impact": 15, "follow_through": 9}[stage]
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 1.3
    elif locomotion_plan == "hunched_shambler":
        biased["dx"] = float(biased["dx"]) + {
            "ready": 0,
            "anticipation": -4,
            "coil": -7,
            "release": 4,
            "impact": 9,
            "follow_through": 6,
            "recover": 2,
            "settle": 0,
        }[stage]
        biased["rot"] = float(biased["rot"]) * 0.55
        biased["sx"] = 1.0 + (float(biased["sx"]) - 1.0) * 0.86
        biased["sy"] = 1.0 + (float(biased["sy"]) - 1.0) * 0.92
    return biased


def apply_attack_pose(base: Image.Image, pose: dict[str, float], sign: int) -> Image.Image:
    crop = trim_alpha(base)
    sx = max(0.70, float(pose["sx"]))
    sy = max(0.70, float(pose["sy"]))
    width = max(1, round(crop.width * sx))
    height = max(1, round(crop.height * sy))
    crop = crop.resize((width, height), Image.Resampling.NEAREST)
    rotation = float(pose["rot"]) * sign
    if abs(rotation) > 0.1:
        crop = crop.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - crop.width) // 2
    y = FRAME_SIZE - 16 - crop.height
    canvas.alpha_composite(crop, (x, y))
    return canvas


def sharpen_alpha(frame: Image.Image) -> Image.Image:
    alpha = frame.getchannel("A")
    frame.putalpha(alpha.point(lambda value: 0 if value < 8 else value))
    return frame


def contain_alpha(frame: Image.Image, margin: int) -> Image.Image:
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return frame
    content = frame.crop(bbox)
    max_w = FRAME_SIZE - margin * 2
    max_h = FRAME_SIZE - margin * 2
    if content.width > max_w or content.height > max_h:
        scale = min(max_w / content.width, max_h / content.height)
        content = content.resize((max(1, int(content.width * scale)), max(1, int(content.height * scale))), Image.Resampling.NEAREST)
        bbox = (bbox[0], bbox[1], bbox[0] + content.width, bbox[1] + content.height)
    x = min(max(margin, bbox[0]), FRAME_SIZE - margin - content.width)
    y = min(max(margin, bbox[1]), FRAME_SIZE - margin - content.height)
    result = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    result.alpha_composite(content, (x, y))
    return result


def make_hurt_frame(base: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    frame = offset_frame(tint_image(base, (255, 90, 80), 0.28), -4, -2, tint, 0.0)
    draw = ImageDraw.Draw(frame, "RGBA")
    draw.line((36, 34, 50, 48), fill=(255, 80, 60, 190), width=3)
    draw.line((48, 34, 34, 48), fill=(255, 80, 60, 190), width=3)
    return frame


def make_death_frame(base: Image.Image, index: int, tint: tuple[int, int, int]) -> Image.Image:
    frame = tint_image(base, (70, 70, 76), 0.18 + index * 0.11)
    frame = offset_frame(frame, index * 2, index * 3, tint, 0.0)
    alpha = frame.getchannel("A").point(lambda value: int(value * max(0.18, 1.0 - index * 0.2)))
    frame.putalpha(alpha)
    return frame


def offset_frame(base: Image.Image, dx: int, dy: int, tint: tuple[int, int, int], shadow_alpha: float) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    if shadow_alpha > 0:
        shadow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow, "RGBA")
        shadow_draw.ellipse((42 + dx // 2, 106, 86 + dx // 2, 118), fill=(*tint, int(80 * shadow_alpha)))
        canvas.alpha_composite(shadow)
    canvas.alpha_composite(base, (dx, dy))
    return canvas


def draw_motion_dust(frame: Image.Image, index: int, tint: tuple[int, int, int], style: str, locomotion_plan: str) -> None:
    if locomotion_plan in {"winged_hover", "tendril_float", "flame_wisp"}:
        return
    draw = ImageDraw.Draw(frame, "RGBA")
    phase = index % 4
    alpha = 34 if locomotion_plan in {"snail_slide", "worm_slither"} else 55
    for dot in range(3):
        x = 38 + dot * 12 - phase * 2
        y = 112 + (dot % 2) * 2
        draw.ellipse((x, y, x + 4, y + 2), fill=(*tint, alpha))


def save_animation_frames(frames_dir: Path, animation_name: str, frames: list[Image.Image]) -> list[Path]:
    out_dir = frames_dir / animation_name
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for index, frame in enumerate(frames):
        path = out_dir / f"{animation_name}_{index:02d}.png"
        frame.save(path)
        paths.append(path)
    return paths


def save_strip(path: Path, frames: list[Image.Image]) -> None:
    strip = Image.new("RGBA", (FRAME_COUNT * FRAME_SIZE + (FRAME_COUNT - 1) * PREVIEW_GAP, FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * (FRAME_SIZE + PREVIEW_GAP), 0))
    strip.save(path)


def render_enemy_preview(path: Path, kind: str, animations: dict[str, list[Image.Image]]) -> None:
    rows = ["walk_right", "walk_left", "attack_right", "attack_left"]
    label_w = 160
    width = label_w + FRAME_COUNT * 84
    height = 34 + len(rows) * 104
    preview = Image.new("RGBA", (width, height), (12, 13, 16, 255))
    draw = ImageDraw.Draw(preview, "RGBA")
    draw.text((12, 10), kind, fill=(230, 224, 206, 255))
    for row, animation_name in enumerate(rows):
        y = 34 + row * 104
        draw.text((12, y + 38), animation_name, fill=(170, 168, 156, 255))
        for index, frame in enumerate(animations[animation_name]):
            thumb = frame.resize((76, 76), Image.Resampling.NEAREST)
            x = label_w + index * 84
            draw.rectangle((x, y, x + 76, y + 76), outline=(54, 54, 62, 255))
            preview.alpha_composite(thumb, (x, y))
            draw.text((x + 2, y + 80), f"{index:02d}", fill=(118, 118, 128, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(path)


def render_overview(entries: list[dict[str, Any]]) -> None:
    row_h = 104
    label_w = 210
    cols_per_anim = 4
    sample_anims = ["walk_right", "attack_right"]
    width = label_w + len(sample_anims) * cols_per_anim * 86 + 20
    height = 42 + len(entries) * row_h
    overview = Image.new("RGBA", (width, height), (10, 10, 14, 255))
    draw = ImageDraw.Draw(overview, "RGBA")
    draw.text((12, 10), "Small Enemy 40 Runtime Overview | high-fidelity staged walk + one attack", fill=(235, 230, 210, 255))
    for row, entry in enumerate(entries):
        y = 38 + row * row_h
        draw.line((0, y - 4, width, y - 4), fill=(31, 31, 38, 255))
        draw.text((12, y + 12), f"ch{entry['chapter']:02d} {entry['kind']}", fill=(218, 216, 200, 255))
        draw.text((12, y + 34), str(entry["style"]), fill=(138, 144, 154, 255))
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        x = label_w
        for animation_name in sample_anims:
            for frame_index in (0, 2, 4, 7):
                frame_path = from_res_path(animations[animation_name][frame_index])
                frame = Image.open(frame_path).convert("RGBA").resize((76, 76), Image.Resampling.NEAREST)
                draw.rectangle((x, y, x + 76, y + 76), outline=(48, 48, 58, 255))
                overview.alpha_composite(frame, (x, y))
                draw.text((x + 2, y + 78), f"{animation_name[:3]} {frame_index:02d}", fill=(112, 116, 124, 255))
                x += 86
    overview.save(CONTACT_DIR / "small_enemy_40_overview.png")


def render_attack_showcase(entries: list[dict[str, Any]]) -> None:
    thumb = 96
    gap = 12
    label_h = 34
    block_w = FRAME_COUNT * (thumb + gap) + 18
    label_w = 230
    cols = 2
    rows = math.ceil(len(entries) / cols)
    width = cols * (label_w + block_w) + 20
    height = 48 + rows * (label_h + thumb + 26)
    sheet = Image.new("RGBA", (width, height), (9, 10, 14, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((14, 12), "Small Enemy 40 | high-fidelity attack keyframes | ready -> anticipation -> impact -> recovery", fill=(236, 231, 212, 255))
    for idx, entry in enumerate(entries):
        col = idx % cols
        row = idx // cols
        x0 = 14 + col * (label_w + block_w)
        y0 = 46 + row * (label_h + thumb + 26)
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        draw.text((x0, y0), f"ch{entry['chapter']:02d} {entry['kind']}", fill=(220, 217, 202, 255))
        draw.text((x0, y0 + 16), f"{entry['style']} | one attack | 8 frames", fill=(134, 142, 154, 255))
        x = x0 + label_w
        for frame_index, frame_res in enumerate(animations["attack_right"]):
            frame = Image.open(from_res_path(frame_res)).convert("RGBA").resize((thumb, thumb), Image.Resampling.NEAREST)
            draw.rectangle((x - 1, y0 + label_h - 1, x + thumb, y0 + label_h + thumb), outline=(52, 54, 64, 255))
            sheet.alpha_composite(frame, (x, y0 + label_h))
            draw.text((x + 4, y0 + label_h + thumb + 4), ATTACK_STAGES[frame_index][:4], fill=(118, 122, 132, 255))
            x += thumb + gap
    sheet.save(CONTACT_DIR / "small_enemy_40_attack_showcase.png")


def render_walk_showcase(entries: list[dict[str, Any]]) -> None:
    thumb = 96
    gap = 12
    label_h = 34
    block_w = FRAME_COUNT * (thumb + gap) + 18
    label_w = 230
    cols = 2
    rows = math.ceil(len(entries) / cols)
    width = cols * (label_w + block_w) + 20
    height = 48 + rows * (label_h + thumb + 26)
    sheet = Image.new("RGBA", (width, height), (9, 10, 14, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((14, 12), "Small Enemy 40 | high-fidelity walk keyframes | contact -> down -> passing -> up", fill=(236, 231, 212, 255))
    for idx, entry in enumerate(entries):
        col = idx % cols
        row = idx // cols
        x0 = 14 + col * (label_w + block_w)
        y0 = 46 + row * (label_h + thumb + 26)
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        draw.text((x0, y0), f"ch{entry['chapter']:02d} {entry['kind']}", fill=(220, 217, 202, 255))
        draw.text((x0, y0 + 16), f"{entry['style']} | 8-frame gait", fill=(134, 142, 154, 255))
        x = x0 + label_w
        for frame_index, frame_res in enumerate(animations["walk_right"]):
            frame = Image.open(from_res_path(frame_res)).convert("RGBA").resize((thumb, thumb), Image.Resampling.NEAREST)
            draw.rectangle((x - 1, y0 + label_h - 1, x + thumb, y0 + label_h + thumb), outline=(52, 54, 64, 255))
            sheet.alpha_composite(frame, (x, y0 + label_h))
            draw.text((x + 4, y0 + label_h + thumb + 4), WALK_STAGES[frame_index][:4], fill=(118, 122, 132, 255))
            x += thumb + gap
    sheet.save(CONTACT_DIR / "small_enemy_40_walk_showcase.png")


def render_no_added_feet_walk_zoom(entries: list[dict[str, Any]]) -> None:
    audit_entries = [entry for entry in entries if str(entry["kind"]) in FOOTLESS_AUDIT_KINDS]
    if not audit_entries:
        return
    thumb = 128
    gap = 18
    label_w = 220
    row_h = thumb + 52
    width = label_w + FRAME_COUNT * (thumb + gap) + 28
    height = 34 + len(audit_entries) * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 10), "No generated extra feet/legs audit | source anatomy preserved, wider strip spacing", fill=(236, 231, 212, 255))
    for row, entry in enumerate(audit_entries):
        y = 34 + row * row_h
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        draw.text((10, y + 20), str(entry["kind"]), fill=(220, 217, 202, 255))
        draw.text((10, y + 40), f"{entry['style']} | {manifest.get('locomotion_plan')}", fill=(138, 146, 156, 255))
        draw.text((10, y + 60), "no generated extra limbs; source anatomy", fill=(122, 172, 142, 255))
        x = label_w
        for frame_index, frame_res in enumerate(animations["walk_right"]):
            frame = Image.open(from_res_path(frame_res)).convert("RGBA")
            draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
            sheet.alpha_composite(frame, (x, y + 3))
            draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
            x += thumb + gap
    sheet.save(CONTACT_DIR / "no_added_feet_walk_zoom.png")


def render_frogman_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {"pipe_thrower", "pollen_lutist", "kneeling_crossbowman"}
    ]
    if not review_entries:
        return
    thumb = 144
    gap = 18
    label_w = 210
    row_h = thumb + 52
    rows_per_entry = 2
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * rows_per_entry * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Frogman runtime review | source-locked walk + native body attack, no added weapon/ball", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source silhouette only", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "frogman_runtime_review.png")


def render_hunched_shambler_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {"root_cage_hunter", "valve_crawler", "silent_bugbler", "moss_larva"}
    ]
    if not review_entries:
        return
    thumb = 150
    gap = 18
    label_w = 220
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Hunched shambler review | root-body walk + root-tendril attack, no feet/weapon/sigil", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source root silhouette", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "hunched_shambler_runtime_review.png")


def render_worm_slither_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {"drain_leech", "echo_thorn_sentinel"}
    ]
    if not review_entries:
        return
    thumb = 150
    gap = 18
    label_w = 220
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Worm slither review | body stretch + bite attack, no feet/weapon/arc", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source worm silhouette", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "worm_slither_runtime_review.png")


def render_snail_slide_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {"rust_diver", "vine_crawler", "pilgrim_chariot"}
    ]
    if not review_entries:
        return
    thumb = 150
    gap = 18
    label_w = 220
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Snail slide review | normal slide walk + native spit/lunge attack, no feet/weapon/arc", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source snail silhouette", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "snail_slide_runtime_review.png")


def render_winged_hover_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {
            "bronze_moth",
            "bell_mote",
            "rain_censer_mote",
            "wax_bee",
            "summoned_page",
            "thorn_bloom_mote",
            "echo_pilgrim_commander_minor",
        }
    ]
    if not review_entries:
        return
    thumb = 142
    gap = 16
    label_w = 225
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Winged hover review | wingbeat walk + body dive attack, no slash arc/beam", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source winged silhouette", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "winged_hover_runtime_review.png")


def render_floating_body_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {
            "spore_bellmaker",
            "bellroot_acolyte",
            "index_scribe",
            "echo_contract_scribe",
            "salt_bookmite",
            "echo_moss_larva",
        }
    ]
    if not review_entries:
        return
    thumb = 142
    gap = 16
    label_w = 225
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Floating body review | tendril/flame body attack, no detached orb/sigil", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), "source floating silhouette", fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "floating_body_runtime_review.png")


def render_source_biped_runtime_review(entries: list[dict[str, Any]]) -> None:
    review_entries = [
        entry
        for entry in entries
        if str(entry["kind"]) in {
            "gear_sentinel",
            "obsidian_bellwheel",
            "echo_waterwheel_knight",
            "corridor_heavy",
            "waterwheel_knight",
            "thorn_sentinel",
            "obsidian_spearman",
            "falling_clapper",
        }
    ]
    if not review_entries:
        return
    thumb = 142
    gap = 16
    label_w = 225
    row_h = thumb + 54
    width = label_w + FRAME_COUNT * (thumb + gap) + 30
    height = 40 + len(review_entries) * 2 * row_h
    sheet = Image.new("RGBA", (width, height), (8, 9, 12, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.text((12, 12), "Source biped review | source legs preserved + body/weapon attack, no added limbs/arc projectile", fill=(236, 231, 212, 255))
    row = 0
    for entry in review_entries:
        manifest = json.loads(Path(entry["manifest"]).read_text(encoding="utf-8"))
        animations = {anim["name"]: anim["frames"] for anim in manifest["animations"]}
        for animation_name in ("walk_right", "attack_right"):
            y = 40 + row * row_h
            draw.text((10, y + 26), str(entry["kind"]), fill=(220, 217, 202, 255))
            draw.text((10, y + 48), animation_name, fill=(138, 146, 156, 255))
            draw.text((10, y + 70), str(manifest.get("locomotion_plan", "source biped")), fill=(122, 172, 142, 255))
            x = label_w
            for frame_index, frame_res in enumerate(animations[animation_name]):
                frame = Image.open(from_res_path(frame_res)).convert("RGBA")
                draw.rectangle((x - 1, y + 3, x + thumb, y + thumb + 4), outline=(60, 62, 72, 255))
                sheet.alpha_composite(frame.resize((thumb, thumb), Image.Resampling.NEAREST), (x, y + 3))
                draw.text((x + 4, y + thumb + 8), str(frame_index), fill=(118, 122, 132, 255))
                x += thumb + gap
            row += 1
    sheet.save(CONTACT_DIR / "source_biped_runtime_review.png")


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def to_res_path(path: Path) -> str:
    return "res://" + path.relative_to(GODOT).as_posix()


def from_res_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT / path.removeprefix("res://")
    return ROOT / path


if __name__ == "__main__":
    main()

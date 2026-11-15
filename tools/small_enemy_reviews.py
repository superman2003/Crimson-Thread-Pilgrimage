"""Preview, overview, showcase and runtime review sheets for the small enemy assets.

Moved out of build_small_enemy_runtime_assets.py unchanged; build_small_enemy_runtime_assets.py imports these names back."""
from __future__ import annotations
import json
import math
from pathlib import Path
from typing import Any
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps
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


ROOT = Path(__file__).resolve().parents[1]


GODOT = ROOT / "godot"


ARTIFACT_ROOT = ROOT / "artifacts" / "small_enemy_keyframes"


CONTACT_DIR = ARTIFACT_ROOT / "contact_sheets"


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


def from_res_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT / path.removeprefix("res://")
    return ROOT / path

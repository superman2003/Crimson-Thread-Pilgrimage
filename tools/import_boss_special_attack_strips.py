from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from import_generated_boss_attack_strips import (
    ARTIFACT_FRAME_SIZE,
    ARTIFACT_ROOT,
    CONCEPT_INDEX,
    FRAME_COUNT,
    GODOT_BOSS_ROOT,
    GODOT_FRAME_SIZE,
    GODOT_ROOT,
    ROOT,
    clean_alpha_source,
    first_existing,
    has_transparent_background,
    load_font,
    normalize_frame,
    normalize_rel,
    remove_chroma,
    render_strip,
    split_source_frames,
    stored_source_path,
    to_res_path,
)


DEFAULT_TIMING = ["ready", "anticipation", "windup", "active_hit", "follow_through", "recovery"]


def main() -> None:
    parser = argparse.ArgumentParser(description="Import one generated boss special-attack strip and rebuild special indexes.")
    parser.add_argument("--boss-id", required=True, help="Boss id, for example boss_01.")
    parser.add_argument("--attack-id", required=True, help="Unique attack id, for example bell_wave.")
    parser.add_argument("--source", required=True, help="Generated chroma or alpha 6-frame source strip.")
    parser.add_argument("--name-zh", required=True, help="Chinese display name for this attack.")
    parser.add_argument("--name-en", required=True, help="English display name for this attack.")
    parser.add_argument("--vfx-key", required=True, help="Unique VFX key for this attack.")
    parser.add_argument("--vfx-color", default="#9fdc8f", help="Primary VFX color.")
    parser.add_argument("--vfx-name-zh", default="", help="Chinese VFX display name.")
    parser.add_argument("--vfx-name-en", default="", help="English VFX display name.")
    parser.add_argument("--trigger-frame", type=int, default=3, help="Frame index where hit/VFX fires.")
    parser.add_argument("--layout", choices=["auto", "strip-6", "grid-3x2"], default="auto")
    args = parser.parse_args()

    entries = read_concepts()
    selected = next((entry for entry in entries if entry["id"] == args.boss_id), None)
    if selected is None:
        raise SystemExit(f"Unknown boss id: {args.boss_id}")
    if args.attack_id == "attack":
        raise SystemExit("Use the existing import_generated_boss_attack_strips.py for the default attack id.")
    if not 0 <= args.trigger_frame < FRAME_COUNT:
        raise SystemExit(f"--trigger-frame must be between 0 and {FRAME_COUNT - 1}")

    imported = import_special_attack(
        selected,
        attack_id=args.attack_id,
        source=Path(args.source),
        layout=args.layout,
        name_zh=args.name_zh,
        name_en=args.name_en,
        vfx_key=args.vfx_key,
        vfx_color=args.vfx_color,
        vfx_name_zh=args.vfx_name_zh or args.name_zh,
        vfx_name_en=args.vfx_name_en or args.name_en,
        trigger_frame=args.trigger_frame,
    )
    indexes = rebuild_special_indexes(entries)
    print(
        "IMPORT_BOSS_SPECIAL_ATTACK_STRIPS_PASS "
        f"boss={args.boss_id} attack={args.attack_id} "
        f"special_attacks={indexes['special_attack_count']} completed_bosses={indexes['completed_boss_count']} "
        f"strip={imported['strip']}"
    )


def import_special_attack(
    entry: dict[str, Any],
    *,
    attack_id: str,
    source: Path,
    layout: str,
    name_zh: str,
    name_en: str,
    vfx_key: str,
    vfx_color: str,
    vfx_name_zh: str,
    vfx_name_en: str,
    trigger_frame: int,
) -> dict[str, Any]:
    source = source.resolve()
    if not source.exists():
        raise FileNotFoundError(source)

    boss_id = str(entry["id"])
    slug = Path(entry["file"]).stem
    artifact_frames_dir = ARTIFACT_ROOT / slug / "actions" / attack_id
    artifact_sheets_dir = ARTIFACT_ROOT / slug / "sheets"
    godot_frames_dir = GODOT_BOSS_ROOT / slug / "frames" / attack_id
    source_dir = ARTIFACT_ROOT / slug / "source" / attack_id
    for path in [artifact_frames_dir, artifact_sheets_dir, godot_frames_dir, source_dir]:
        path.mkdir(parents=True, exist_ok=True)

    stored_source = stored_source_path(source, source_dir)
    if source != stored_source.resolve():
        shutil.copy2(source, stored_source)

    strip = Image.open(stored_source).convert("RGBA")
    slots = split_source_frames(strip, FRAME_COUNT, layout)
    artifact_frames: list[Path] = []
    godot_frames: list[Path] = []
    normalized_frames: list[Image.Image] = []

    for index, slot in enumerate(slots):
        cutout = clean_alpha_source(slot) if has_transparent_background(slot) else remove_chroma(slot)

        artifact_frame = normalize_frame(cutout, ARTIFACT_FRAME_SIZE)
        artifact_path = artifact_frames_dir / f"attack_{index:02d}.png"
        artifact_frame.save(artifact_path)
        artifact_frames.append(artifact_path)
        normalized_frames.append(artifact_frame)

        godot_frame = normalize_frame(cutout, GODOT_FRAME_SIZE)
        godot_path = godot_frames_dir / f"attack_{index:02d}.png"
        godot_frame.save(godot_path)
        godot_frames.append(godot_path)

    strip_path = artifact_sheets_dir / f"{boss_id}_{attack_id}_strip.png"
    render_strip(normalized_frames, strip_path)

    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    manifest = read_json(manifest_path) if manifest_path.exists() else base_manifest(entry)
    godot_paths = [to_res_path(path) for path in godot_frames]
    attack_record = {
        "id": attack_id,
        "name": attack_id,
        "name_zh": name_zh,
        "name_en": name_en,
        "fps": 12.0,
        "loop": False,
        "frames": godot_paths,
        "hit_frame_index": trigger_frame,
        "hitbox": {"shape": "rect", "size": [156, 96], "offset": [76, -44]},
        "vfx": [
            {
                "key": vfx_key,
                "name_zh": vfx_name_zh,
                "name_en": vfx_name_en,
                "trigger_frame": trigger_frame,
                "color": vfx_color,
            }
        ],
        "source_generated_strip": normalize_rel(stored_source),
    }

    manifest["source_concept"] = normalize_rel(ROOT / entry["file"])
    manifest["frame_size"] = [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE]
    manifest["anchor"] = "bottom-center"
    manifest["runtime_2d"] = {
        "view": "locked side or three-quarter side view",
        "anchor": "bottom-center",
        "timing": DEFAULT_TIMING,
        "hit_frame_index": trigger_frame,
        "horizontal_motion_only": True,
        "keep_collision_box_stable": True,
    }
    manifest["attacks"] = upsert_by_id(manifest.get("attacks", []), attack_record)
    manifest["animations"] = upsert_animation(manifest.get("animations", []), attack_id, godot_paths)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    return build_attack_set(entry, attack_id, attack_record)


def rebuild_special_indexes(entries: list[dict[str, Any]]) -> dict[str, int]:
    old_artifact_index = read_json(ARTIFACT_ROOT / "boss_attack_keyframes_index.json")
    old_godot_index = read_json(GODOT_BOSS_ROOT / "boss_attack_keyframes_index.json")

    artifact_entries: list[dict[str, Any]] = []
    godot_entries: list[dict[str, Any]] = []
    special_entries: list[dict[str, Any]] = []
    special_attack_count = 0
    completed_boss_count = 0

    old_artifact_by_id = {entry["id"]: entry for entry in old_artifact_index.get("entries", [])}
    old_godot_by_id = {entry["id"]: entry for entry in old_godot_index.get("entries", [])}

    for entry in entries:
        boss_id = str(entry["id"])
        slug = Path(entry["file"]).stem
        attack_sets = collect_attack_sets(entry)
        special_sets = [attack for attack in attack_sets if attack["id"] != "attack"]
        if len(special_sets) >= 2:
            completed_boss_count += 1
        special_attack_count += len(special_sets)

        artifact_entry = dict(old_artifact_by_id.get(boss_id, {}))
        artifact_entry.update(
            {
                "id": boss_id,
                "slug": slug,
                "name_zh": entry.get("name_zh", ""),
                "name_en": entry.get("name_en", ""),
                "source": normalize_rel(ROOT / entry["file"]),
                "attack_sets": attack_sets,
                "special_attacks": special_sets,
            }
        )
        artifact_entries.append(artifact_entry)

        godot_entry = dict(old_godot_by_id.get(boss_id, {}))
        godot_entry.update(
            {
                "id": boss_id,
                "slug": slug,
                "name_zh": entry.get("name_zh", ""),
                "name_en": entry.get("name_en", ""),
                "manifest": to_res_path(GODOT_BOSS_ROOT / slug / "manifest.json"),
                "attacks": {attack["id"]: attack["godot_frames"] for attack in attack_sets},
                "special_attacks": {attack["id"]: attack["godot_frames"] for attack in special_sets},
            }
        )
        godot_entries.append(godot_entry)

        if special_sets:
            special_entries.append(
                {
                    "id": boss_id,
                    "slug": slug,
                    "name_zh": entry.get("name_zh", ""),
                    "name_en": entry.get("name_en", ""),
                    "source": normalize_rel(ROOT / entry["file"]),
                    "attacks": special_sets,
                    "godot_manifest": to_res_path(GODOT_BOSS_ROOT / slug / "manifest.json"),
                }
            )

    old_artifact_index["entries"] = artifact_entries
    old_artifact_index["special_attack_count"] = special_attack_count
    old_artifact_index["completed_special_boss_count"] = completed_boss_count
    old_artifact_index["note"] = "Generated boss keyframes. Default attack is preserved; special_attacks contains unique boss attack sets and VFX."
    (ARTIFACT_ROOT / "boss_attack_keyframes_index.json").write_text(
        json.dumps(old_artifact_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    old_godot_index["entries"] = godot_entries
    old_godot_index["special_attack_count"] = special_attack_count
    old_godot_index["completed_special_boss_count"] = completed_boss_count
    old_godot_index["note"] = "Godot-ready boss keyframes. attack is preserved; attacks/special_attacks expose multi-attack sets."
    (GODOT_BOSS_ROOT / "boss_attack_keyframes_index.json").write_text(
        json.dumps(old_godot_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    special_index = {
        "count": len(special_entries),
        "completed_boss_count": completed_boss_count,
        "special_attack_count": special_attack_count,
        "required_attacks_per_boss": [2, 3],
        "frames_per_attack": FRAME_COUNT,
        "frame_size": [ARTIFACT_FRAME_SIZE, ARTIFACT_FRAME_SIZE],
        "godot_frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "note": "Progress index for unique 2-3 boss attacks with VFX. Goal is 20 completed bosses.",
        "entries": special_entries,
    }
    (ARTIFACT_ROOT / "boss_special_attack_keyframes_index.json").write_text(
        json.dumps(special_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    godot_special_index = {
        "count": len(special_entries),
        "completed_boss_count": completed_boss_count,
        "special_attack_count": special_attack_count,
        "frames_per_attack": FRAME_COUNT,
        "frame_size": [GODOT_FRAME_SIZE, GODOT_FRAME_SIZE],
        "entries": [
            {
                "id": entry["id"],
                "slug": entry["slug"],
                "name_zh": entry["name_zh"],
                "name_en": entry["name_en"],
                "manifest": entry["godot_manifest"],
                "attacks": {attack["id"]: attack["godot_frames"] for attack in entry["attacks"]},
            }
            for entry in special_entries
        ],
    }
    (GODOT_BOSS_ROOT / "boss_special_attack_keyframes_index.json").write_text(
        json.dumps(godot_special_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    render_special_contact_sheet(special_entries, ARTIFACT_ROOT / "contact_sheets" / "boss_special_attack_keyframes_contact_sheet.png")
    render_special_preview_html(special_entries, ARTIFACT_ROOT / "special_attacks_preview.html")
    return {"special_attack_count": special_attack_count, "completed_boss_count": completed_boss_count}


def collect_attack_sets(entry: dict[str, Any]) -> list[dict[str, Any]]:
    slug = Path(entry["file"]).stem
    actions_root = ARTIFACT_ROOT / slug / "actions"
    manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
    manifest = read_json(manifest_path) if manifest_path.exists() else {}
    manifest_attacks = {attack["id"]: attack for attack in manifest.get("attacks", []) if "id" in attack}
    if not actions_root.exists():
        return []
    attack_sets: list[dict[str, Any]] = []
    for action_dir in sorted(path for path in actions_root.iterdir() if path.is_dir()):
        attack_id = action_dir.name
        attack_set = build_attack_set(entry, attack_id, manifest_attacks.get(attack_id, {}))
        if attack_set:
            attack_sets.append(attack_set)
    return attack_sets


def build_attack_set(entry: dict[str, Any], attack_id: str, manifest_attack: dict[str, Any]) -> dict[str, Any]:
    boss_id = str(entry["id"])
    slug = Path(entry["file"]).stem
    artifact_frames = [ARTIFACT_ROOT / slug / "actions" / attack_id / f"attack_{index:02d}.png" for index in range(FRAME_COUNT)]
    godot_frames = [GODOT_BOSS_ROOT / slug / "frames" / attack_id / f"attack_{index:02d}.png" for index in range(FRAME_COUNT)]
    strip_name = f"{boss_id}_attack_strip.png" if attack_id == "attack" else f"{boss_id}_{attack_id}_strip.png"
    strip_path = ARTIFACT_ROOT / slug / "sheets" / strip_name
    source_dir = ARTIFACT_ROOT / slug / "source" if attack_id == "attack" else ARTIFACT_ROOT / slug / "source" / attack_id
    raw_path = first_existing(
        [
            source_dir / "generated_attack_strip_alpha.png",
            source_dir / "generated_attack_strip_chroma.png",
            source_dir / "generated_attack_strip_source.png",
        ]
    )
    if not all(path.exists() for path in artifact_frames + godot_frames) or not strip_path.exists():
        return {}
    return {
        "id": attack_id,
        "name_zh": manifest_attack.get("name_zh", "基础攻击" if attack_id == "attack" else attack_id),
        "name_en": manifest_attack.get("name_en", "Default Attack" if attack_id == "attack" else attack_id),
        "source_generated_strip": normalize_rel(raw_path) if raw_path and raw_path.exists() else "",
        "frames": [normalize_rel(path) for path in artifact_frames],
        "strip": normalize_rel(strip_path),
        "godot_frames": [to_res_path(path) for path in godot_frames],
        "fps": manifest_attack.get("fps", 12.0),
        "loop": manifest_attack.get("loop", False),
        "hit_frame_index": manifest_attack.get("hit_frame_index", 3),
        "hitbox": manifest_attack.get("hitbox", {}),
        "vfx": manifest_attack.get("vfx", []),
    }


def upsert_by_id(items: list[dict[str, Any]], item: dict[str, Any]) -> list[dict[str, Any]]:
    out = [existing for existing in items if existing.get("id") != item["id"]]
    out.append(item)
    return out


def upsert_animation(animations: list[dict[str, Any]], attack_id: str, frames: list[str]) -> list[dict[str, Any]]:
    out = [animation for animation in animations if animation.get("name") != attack_id]
    out.append({"name": attack_id, "fps": 12.0, "loop": False, "frames": frames})
    return out


def base_manifest(entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": entry["id"],
        "name_zh": entry.get("name_zh", ""),
        "name_en": entry.get("name_en", ""),
        "source_concept": normalize_rel(ROOT / entry["file"]),
        "style": "high quality dark fantasy non-pixel hand-painted generated attack keyframes",
        "animations": [],
    }


def render_special_contact_sheet(entries: list[dict[str, Any]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows = [(entry, attack) for entry in entries for attack in entry["attacks"]]
    thumb = 132
    label_w = 330
    row_h = 162
    margin = 18
    width = label_w + FRAME_COUNT * thumb + margin * 2
    height = max(margin * 2 + row_h * len(rows), 220)
    sheet = Image.new("RGB", (width, height), (10, 11, 16))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(20)
    small_font = load_font(14)
    for row_index, (entry, attack) in enumerate(rows):
        y = margin + row_index * row_h
        draw.rectangle((margin // 2, y - 6, width - margin // 2, y + row_h - 8), outline=(43, 47, 58), width=1)
        draw.text((margin, y + 12), f"{entry['id']} {entry['name_zh']}", fill=(235, 225, 188), font=title_font)
        draw.text((margin, y + 40), f"{attack['id']} / {attack['name_en']}", fill=(165, 178, 194), font=small_font)
        vfx = attack.get("vfx", [])
        if vfx:
            draw.text((margin, y + 62), f"VFX: {vfx[0].get('key', '')}", fill=(118, 202, 180), font=small_font)
        for frame_index, rel in enumerate(attack["frames"]):
            frame = Image.open(ROOT / rel).convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS)
            bg = Image.new("RGBA", (thumb, thumb), (18, 19, 25, 255))
            bg.alpha_composite(frame)
            x = label_w + frame_index * thumb
            sheet.paste(bg.convert("RGB"), (x, y + 8))
            draw.text((x + 8, y + thumb + 9), f"{frame_index:02d}", fill=(132, 143, 158), font=small_font)
    sheet.save(out_path)


def render_special_preview_html(entries: list[dict[str, Any]], out_path: Path) -> None:
    lines = [
        "<!doctype html>",
        "<meta charset=\"utf-8\">",
        "<title>Boss Special Attack Keyframes</title>",
        "<style>",
        "body{margin:0;background:#0b0c10;color:#e8dfc5;font-family:Arial,'Microsoft YaHei',sans-serif}",
        "main{max-width:1180px;margin:0 auto;padding:24px}",
        "section{border-bottom:1px solid #303441;padding:18px 0}",
        "h1{font-size:26px;margin:0 0 12px}",
        "h2{font-size:18px;margin:0 0 10px;color:#e8dfc5}",
        "h3{font-size:16px;margin:12px 0 8px;color:#bfe8d8}",
        "img{max-width:100%;height:auto;background:#11131a}",
        ".meta{color:#aeb9c8;font-size:13px;margin-bottom:8px}",
        "</style>",
        "<main>",
        "<h1>Boss Special Attack Keyframes</h1>",
    ]
    for entry in entries:
        lines.extend(["<section>", f"<h2>{entry['id']} {entry['name_zh']} / {entry['name_en']}</h2>"])
        for attack in entry["attacks"]:
            strip_path = ROOT / attack["strip"]
            src = strip_path.relative_to(out_path.parent).as_posix() if strip_path.is_relative_to(out_path.parent) else attack["strip"]
            vfx_key = attack["vfx"][0]["key"] if attack.get("vfx") else ""
            lines.extend(
                [
                    f"<h3>{attack['id']} / {attack['name_zh']} / {attack['name_en']}</h3>",
                    f"<div class=\"meta\">VFX: {vfx_key} | {attack['strip']}</div>",
                    f"<img src=\"{src}?v={strip_path.stat().st_mtime_ns}\" alt=\"{entry['id']} {attack['id']} strip\">",
                ]
            )
        lines.append("</section>")
    lines.extend(["</main>", ""])
    out_path.write_text("\n".join(lines), encoding="utf-8")


def read_concepts() -> list[dict[str, Any]]:
    return read_json(CONCEPT_INDEX)["entries"]


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()

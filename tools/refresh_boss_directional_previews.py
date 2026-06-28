from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
GODOT_BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
ARTIFACT_ROOT = ROOT / "artifacts" / "boss_keyframes"
SPECIAL_INDEX = ARTIFACT_ROOT / "boss_special_attack_keyframes_index.json"

CELL = 128
PREVIEW_GAP = 34
LABEL_W = 280
ROW_H = 178
MARGIN = 28


def main() -> None:
    parser = argparse.ArgumentParser(description="Refresh directional boss contact sheets with larger frame gaps.")
    parser.add_argument("--start", type=int, default=2)
    parser.add_argument("--end", type=int, default=20)
    args = parser.parse_args()

    special_entries = read_json(SPECIAL_INDEX)["entries"]
    refreshed: list[str] = []
    for entry in special_entries:
        boss_id = str(entry["id"])
        number = int(boss_id.split("_", 1)[1])
        if number < args.start or number > args.end:
            continue
        slug = str(entry["slug"])
        manifest_path = GODOT_BOSS_ROOT / slug / "manifest.json"
        if not manifest_path.exists():
            continue
        manifest = read_json(manifest_path)
        pack = manifest.get("directional_asset_pack")
        if not isinstance(pack, dict):
            continue
        rows = collect_directional_rows(manifest)
        if not rows:
            continue
        preview_path = ARTIFACT_ROOT / slug / f"{boss_id}_directional_contact.png"
        render_contact_sheet(rows, preview_path, boss_id, str(entry["name_zh"]), str(entry["name_en"]))
        pack["preview_gap_px"] = PREVIEW_GAP
        pack["contact_sheet"] = preview_path.relative_to(ROOT).as_posix()
        manifest["directional_asset_pack"] = pack
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        refreshed.append(boss_id)

    print(f"REFRESH_BOSS_DIRECTIONAL_PREVIEWS_PASS refreshed={len(refreshed)} preview_gap={PREVIEW_GAP} ids={','.join(refreshed)}")


def collect_directional_rows(manifest: dict[str, Any]) -> list[tuple[str, list[Image.Image]]]:
    rows: list[tuple[str, list[Image.Image]]] = []
    for animation in manifest.get("animations", []):
        if not isinstance(animation, dict):
            continue
        name = str(animation.get("name", ""))
        if not name.endswith("_left") and not name.endswith("_right"):
            continue
        frames: list[Image.Image] = []
        for frame_path in animation.get("frames", []):
            frames.append(Image.open(res_to_path(str(frame_path))).convert("RGBA"))
        rows.append((name, frames))
    rows.sort(key=lambda row: (row[0].rsplit("_", 1)[0], row[0].rsplit("_", 1)[-1]))
    return rows


def render_contact_sheet(
    rows: list[tuple[str, list[Image.Image]]],
    out_path: Path,
    boss_id: str,
    name_zh: str,
    name_en: str,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    max_frames = max(len(frames) for _, frames in rows)
    width = LABEL_W + max_frames * CELL + max(0, max_frames - 1) * PREVIEW_GAP + MARGIN * 2
    height = MARGIN * 2 + 42 + len(rows) * ROW_H
    sheet = Image.new("RGB", (width, height), (13, 12, 15))
    draw = ImageDraw.Draw(sheet)
    draw.text((MARGIN, MARGIN), f"{boss_id} {name_zh} / {name_en}", fill=(238, 226, 204))
    draw.text((MARGIN, MARGIN + 20), f"preview_gap={PREVIEW_GAP}px, walk=16f, attacks=8f per direction", fill=(160, 150, 144))
    y_offset = MARGIN + 42
    for row_index, (name, frames) in enumerate(rows):
        y = y_offset + row_index * ROW_H
        draw.text((MARGIN, y + 14), name, fill=(232, 228, 205))
        draw.text((MARGIN, y + 40), f"{len(frames)} frames", fill=(151, 145, 128))
        for frame_index, frame in enumerate(frames):
            thumb = Image.new("RGBA", (CELL, CELL), (22, 21, 24, 255))
            thumb.alpha_composite(frame.resize((CELL, CELL), Image.Resampling.LANCZOS), (0, 0))
            x = LABEL_W + frame_index * (CELL + PREVIEW_GAP)
            sheet.paste(thumb.convert("RGB"), (x, y))
            draw.rectangle((x, y, x + CELL - 1, y + CELL - 1), outline=(68, 64, 70))
            draw.text((x + 5, y + CELL + 7), f"{frame_index:02d}", fill=(148, 144, 150))
    sheet.save(out_path)


def res_to_path(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(path)
    return GODOT_ROOT / path.removeprefix("res://")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()

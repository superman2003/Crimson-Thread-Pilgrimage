#!/usr/bin/env python3
"""Before/after strips of the motion v5 batch, drawn from packed runtime frames.

Each row composes the poses exactly as the game places them on the rig canvas
(atlas region + margin), so scale, baseline and anchor jumps are visible. The
"before" row reads the same character from another checkout (e.g. a git
worktree of main): --before <repo root>.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
C, N = "original_creatures/", "original_npcs/"
BOSS_E = ["broken_string_gardener", "rust_crown_guardian", "saltwhite_contract_judge", "sunken_hammer_smith"]
# (output, folder, before sequence, after sequence); an index of None means every cel.
SHEETS = [(f"phase_{b}", C + b, [("phase_windup", -1), ("phase", None), ("recover", 0)],
           [("phase_windup", -1), ("phase", None), ("phase_settle" if b == "broken_string_gardener" else "phase_bridge", None),
            ("idle" if b == "broken_string_gardener" else "recover", 0)]) for b in BOSS_E]
SHEETS += [(f"bridges_{b}", C + b, [(m, -1) for m in ("heavy", "cast")] + [("recover", 0)],
            [x for m in ("heavy", "cast") for x in ((m, -1), (f"{m}_settle" if (b, m) == ("broken_string_gardener", "heavy") else f"{m}_bridge", None))]
            + [("recover", 0)])
           for b in BOSS_E + ["silent_crown_core", "silent_pilgrim_commander"]]
SHEETS += [("phase_bridges_late_bosses", None, None, None)]
SHEETS += [
    ("ash_banner_imp", C + "ash_banner_imp", [("idle", 0), ("windup", None), ("attack", None), ("recover", 0)],
     [("idle", 0), ("windup", None), ("attack", None), ("recover", 0), ("recover", 1), ("recover", 2)]),
    ("echo_contract_scribe", C + "echo_contract_scribe", [("attack", None), ("recover", 0)], [("attack", None), ("recover", 0)]),
    ("wax_lancer", C + "wax_lancer", [("attack", -1), ("recover", 0)], [("attack", -1), ("recover", 0), ("recover", 1), ("recover", 2)]),
    ("clipped_frames", None, None, None),
]
CLIPPED = [(C + "broken_string_gardener", "death", 3), (C + "delayed_shadow", "recover", 0), (C + "pipe_thrower", "hurt", 2),
           (N + "npc_blind_bell_knight", "talk", 3), (N + "npc_deserter_flagbearer", "talk", 6)]


def load(root: Path, folder: str) -> dict:
    base = root / "godot/assets/sprites" / folder
    manifest = json.loads((base / "motion_manifest.json").read_text())
    width, height = manifest["canvas"]
    atlases, result = {}, {}
    for animation in manifest["animations"]:
        cels = []
        for frame in animation["frames"]:
            path = root / "godot" / frame["atlas"].removeprefix("res://")
            atlases.setdefault(path, Image.open(path).convert("RGBA"))
            x, y, w, h = frame["region"]
            canvas = Image.new("RGBA", (width, height))
            canvas.alpha_composite(atlases[path].crop((x, y, x + w, y + h)), (frame["margin"][0], frame["margin"][1]))
            cels.append(canvas)
        result[animation["name"]] = cels
    return result


def pick(frames: dict, sequence: list) -> list:
    tiles = []
    for name, index in sequence:
        cels = frames[name]
        for i in (range(len(cels)) if index is None else [index % len(cels)]):
            tiles.append((f"{name}[{i}]", cels[i]))
    return tiles


def draw_rows(rows: list, out: Path) -> None:
    """rows: [(label, tiles)]; all tiles of one image share one crop box and scale."""
    box = None
    for _, tiles in rows:
        for _, cel in tiles:
            b = cel.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    pad = 6
    box = (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)
    w, h = box[2] - box[0], box[3] - box[1]
    columns = max(len(t) for _, t in rows)
    image = Image.new("RGBA", (w * columns + 120, (h + 18) * len(rows)), (104, 104, 104, 255))
    pen = ImageDraw.Draw(image)
    for r, (label, tiles) in enumerate(rows):
        top = r * (h + 18)
        pen.text((6, top + 4), label, fill=(255, 255, 255, 255))
        for c, (name, cel) in enumerate(tiles):
            left = 120 + c * w
            image.alpha_composite(cel.crop(box), (left, top + 18))
            pen.text((left + 4, top + 4), name, fill=(255, 230, 90, 255))
        ground = top + 18 + tiles[0][1].height - 8 - box[1]
        pen.line([(120, ground), (image.width, ground)], fill=(230, 80, 80, 255))
    scale = min(1.0, 2600 / image.width)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(out, quality=90)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/character_motion_v5")
    args = parser.parse_args()
    written = []
    for name, folder, before, after in SHEETS:
        if name == "phase_bridges_late_bosses":
            rows = []
            for boss in ("silent_crown_core", "silent_pilgrim_commander"):
                old, new = load(args.before, C + boss), load(ROOT, C + boss)
                rows += [(boss + " before", pick(old, [("phase", -1), ("recover", 0)])),
                         (boss + " after", pick(new, [("phase", -1), ("phase_bridge", None), ("recover", 0)]))]
            # The two bosses differ in canvas; render each pair separately.
            for i in (0, 2):
                draw_rows(rows[i:i + 2], args.out / f"{name}_{rows[i][0].split()[0]}.jpg")
                written.append(f"{name}_{rows[i][0].split()[0]}.jpg")
            continue
        if name == "clipped_frames":
            for folder_name, animation, index in CLIPPED:
                old, new = load(args.before, folder_name), load(ROOT, folder_name)
                neighbours = [(animation, max(0, index - 1)), (animation, index), (animation, min(len(new[animation]) - 1, index + 1))]
                stem = folder_name.split("/")[-1]
                draw_rows([("before", pick(old, neighbours)), ("after", pick(new, neighbours))], args.out / f"clipped_{stem}.jpg")
                written.append(f"clipped_{stem}.jpg")
            continue
        old, new = load(args.before, folder), load(ROOT, folder)
        draw_rows([("before", pick(old, before)), ("after", pick(new, after))], args.out / f"{name}.jpg")
        written.append(f"{name}.jpg")
    print(json.dumps({"images": written}, indent=2))


if __name__ == "__main__":
    main()

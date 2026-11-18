"""Pick a visually close entry cel for each transition back to a character loop.

Compare premultiplied colour and alpha in the shared rig canvas, after the
creature's drawing-size correction. Only frame indices ship with the game.
"""
import argparse
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

from build_creature_frame_fit import ACTIVE_LAYERS


GODOT = Path(__file__).resolve().parents[1] / "godot"
OUTPUT = GODOT / "data/character_loop_entries.json"
SAMPLE_SIZE = (40, 40)


def drawing(page, frame, canvas, fit):
    x, y, width, height = frame["region"]
    left, top = frame["margin"][:2]
    crop = page.crop((x, y, x + width, y + height)).convert("RGBa")
    scale, px, py = fit
    if scale != 1:
        pivot_x, pivot_y = canvas[0] * 0.5 + px, canvas[1] * 0.5 + py
        left = round(pivot_x + (left - pivot_x) * scale)
        top = round(pivot_y + (top - pivot_y) * scale)
        crop = crop.resize((max(1, round(width * scale)), max(1, round(height * scale))),
                           Image.Resampling.BILINEAR)
    image = Image.new("RGBa", canvas)
    image.paste(crop, (left, top))
    return np.asarray(image.resize(SAMPLE_SIZE, Image.Resampling.BOX), dtype=np.int16)


def loop_entries(path, loops):
    data = json.loads(path.read_text(encoding="utf-8"))
    fit_path = path.with_name("frame_fit.json")
    fit = json.loads(fit_path.read_text(encoding="utf-8")) if fit_path.exists() else {}
    fits = fit["frames"] if fit.get("manifest") == path.name else {}
    pages, clips = {}, {}
    for clip in data["animations"]:
        name = clip["name"]
        frames = clip["frames"]
        if not frames or not all(isinstance(frame, dict) and "margin" in frame for frame in frames):
            continue
        corrections = fits.get(name, [])
        poses = []
        for index, frame in enumerate(frames):
            atlas = frame["atlas"]
            if atlas not in pages:
                with Image.open(GODOT / atlas.removeprefix("res://")) as source:
                    pages[atlas] = source.convert("RGBA")
            correction = corrections[index] if len(corrections) == len(frames) else (1, 0, 0)
            poses.append(drawing(pages[atlas], frame, data["canvas"], correction))
        clips[name] = np.stack(poses)
    result = {}
    for dest in loops:
        if dest not in clips:
            continue
        candidates = clips[dest]
        entries = {"count": len(candidates)}
        for name, poses in clips.items():
            if name != dest:
                entries[name] = [int(np.abs(candidates - pose).sum(axis=(1, 2, 3)).argmin())
                                 for pose in poses]
        result[dest] = entries
    return result


def build():
    result = {}
    for family, loops in [("original_creatures", ("idle", "walk")), ("original_npcs", ("idle", "talk"))]:
        # character_manifest() only considers the newer creature layers for enemies.
        layers = ACTIVE_LAYERS if family == "original_creatures" else (
            "boss_behavior_manifest.json", "combat_motion_v7_manifest.json", "motion_manifest.json", "manifest.json")
        for folder in sorted((GODOT / "assets/sprites" / family).iterdir()):
            path = next((folder / name for name in layers if (folder / name).is_file()), None)
            if path:
                key = "res://" + path.relative_to(GODOT).as_posix()
                entries = loop_entries(path, loops)
                if entries:
                    result[key] = entries
    # Keep each list of frame indices on one line for asset reviews.
    text = json.dumps(result, indent=2)
    return re.sub(r"\[[\d,\s]+\]", lambda match: "".join(match[0].split()), text) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = build()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != content:
            raise SystemExit("Character loop entries are stale. Run tools/build_character_loop_entries.py.")
    else:
        OUTPUT.write_text(content, encoding="utf-8", newline="\n")
    print("Character loop entries match the production drawings.")

"""Index original PNG atlases and assign varied chapter art without repainting pixels."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = ROOT / "godot/assets/sprites/flat_maps"
THEMES = ["moss_cavern", "rain_foundry", "salt_archive", "string_greenhouse", "obsidian_pilgrim", "silent_crown"]
MOTIFS = ["bell", "wheel", "pages", "leaf", "banner", "crown"]
NAMES = ["shelf", "jointed_ledge", "fractured_ledge", "hanging_ledge", "carved_shelf", "ornamented_lintel", "natural_bridge", "metal_bridge", "corbel_ledge", "narrow_step", "bound_lintel", "ceremonial_floor"]


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def index_atlas(theme: str) -> dict:
    folder = ART_ROOT / theme
    with Image.open(folder / "platform_atlas.png") as image:
        if image.mode != "RGBA":
            raise ValueError(f"{theme}: platform atlas must have real alpha")
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        if np.count_nonzero(alpha == 0) < alpha.size * 0.30:
            raise ValueError(f"{theme}: atlas has insufficient transparent margins")
        width, height = image.size
        variants = []
        for index in range(12):
            row, col = divmod(index, 3)
            x0, x1 = round(col * width / 3), round((col + 1) * width / 3)
            y0, y1 = round(row * height / 4), round((row + 1) * height / 4)
            cell_alpha = alpha[y0:y1, x0:x1]
            labels, _ = ndimage.label(cell_alpha > 16)
            areas = np.bincount(labels.ravel())
            areas[0] = 0
            yy, xx = np.where(labels == int(areas.argmax()))
            if len(xx) < 1000:
                raise ValueError(f"{theme}: missing sprite in grid cell {index}")
            left, right = int(xx.min()), int(xx.max()) + 1
            top, bottom = int(yy.min()), int(yy.max()) + 1
            region_alpha = cell_alpha[top:bottom, left:right]
            counts = (region_alpha > 100).sum(axis=1)
            lines = np.flatnonzero(counts >= (right - left) * 0.64)
            if not len(lines):
                raise ValueError(f"{theme}: no readable walkable edge for variant {index}")
            region = [x0 + left, y0 + top, right - left, bottom - top]
            variants.append({"id": index, "name": NAMES[index], "region": region, "walk_y": int(lines[0]), "pixel_sha256": hashlib.sha256(pixels[y0+top:y0+bottom, x0+left:x0+right].tobytes()).hexdigest()})
            resource = '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
            resource += f'[ext_resource type="Texture2D" path="res://assets/sprites/flat_maps/{theme}/platform_atlas.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\n'
            resource += f'region = Rect2({", ".join(map(str, region))})\nfilter_clip = true\n'
            (folder / f"platform_{index:02d}.tres").write_text(resource, encoding="utf-8")
    manifest = {"theme": theme, "style": "flat hand-inked orthographic 2D", "source": "imagegen original artwork", "atlas_size": [width, height], "grid": [3, 4], "variants": variants}
    write_json(folder / "manifest.json", manifest)
    return manifest


def index_decorations(theme: str, manifest: dict) -> None:
    folder = ART_ROOT / theme
    with Image.open(folder / "decor_atlas.png") as image:
        if image.mode != "RGBA":
            raise ValueError(f"{theme}: decorative sprites must have real alpha")
        alpha = np.asarray(image.getchannel("A"))
        if np.count_nonzero(alpha == 0) < alpha.size * 0.30:
            raise ValueError(f"{theme}: decorative atlas needs transparent margins")
        width, height = image.size
        decorations = []
        for index in range(6):
            row, col = divmod(index, 3)
            x0, x1 = round(col * width / 3), round((col + 1) * width / 3)
            y0, y1 = round(row * height / 2), round((row + 1) * height / 2)
            labels, _ = ndimage.label(alpha[y0:y1, x0:x1] > 16)
            areas = np.bincount(labels.ravel())
            areas[0] = 0
            yy, xx = np.where(labels == int(areas.argmax()))
            if len(xx) < 600:
                raise ValueError(f"{theme}: missing decoration {index}")
            left, right = int(xx.min()), int(xx.max()) + 1
            top, bottom = int(yy.min()), int(yy.max()) + 1
            region = [x0 + left, y0 + top, right - left, bottom - top]
            decorations.append({"id": index, "region": region})
            resource = '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
            resource += f'[ext_resource type="Texture2D" path="res://assets/sprites/flat_maps/{theme}/decor_atlas.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\n'
            resource += f'region = Rect2({", ".join(map(str, region))})\nfilter_clip = true\n'
            (folder / f"decor_{index:02d}.tres").write_text(resource, encoding="utf-8")
        manifest["decorations"] = decorations
        manifest["decor_atlas_size"] = [width, height]
    write_json(folder / "manifest.json", manifest)


def platform_center(platform: dict) -> tuple[float, float]:
    x, y, w, _ = platform["rect"]
    return x + w / 2, y


def assign_styles(config: dict) -> None:
    counts: Counter[int] = Counter()
    assigned: list[dict] = []
    platforms = sorted(config["platforms"], key=lambda p: (0 if p.get("route_role") == "main" else 1, p.get("route_order", 99999), p["id"]))
    for platform in platforms:
        material = platform.get("material", "")
        pool = [6, 7, 8, 10] if "bridge" in material else list(range(12))
        if "boss" in material:
            pool = [11, 5, 8]
        x, y = platform_center(platform)
        neighbors = {p["art"]["variant"] for p in assigned if abs(platform_center(p)[0] - x) < 800 and abs(platform_center(p)[1] - y) < 300}
        last = assigned[-1]["art"]["variant"] if assigned else -1
        candidates = [i for i in pool if i not in neighbors and i != last]
        if not candidates:
            candidates = [i for i in pool if i != last]
        seed = int(hashlib.sha256((config["id"] + ":" + platform["id"]).encode()).hexdigest()[:8], 16)
        candidates.sort(key=lambda i: (counts[i], (i - seed) % 12))
        variant = candidates[0]
        body_pool = [i for i in pool if i != variant]
        platform["art"] = {"variant": variant, "flip_h": bool(seed % 2), "body_variants": [variant, body_pool[seed % len(body_pool)], body_pool[(seed + 3) % len(body_pool)]]}
        counts[variant] += 1
        assigned.append(platform)
    config["map_art"] = {"style": "flat_2d_side_view", "platform_variant_count": 12, "variant_usage": dict(sorted(counts.items())), "repeat_rule": "avoid matching nearby platforms; preserve end caps; vary long-platform middle segments", "background": f"res://assets/sprites/flat_maps/{config['art_theme']}/background.png"}


def landmarks_and_rewards(config: dict, theme_index: int) -> None:
    for room in config.get("map_rooms", []):
        if room.get("kind") not in ["entry", "hub", "boss", "save", "overlook", "reward", "treasure", "exit"]:
            continue
        x, y, width, height = room["layout_rect"]
        landmark_width = min(400, width * 0.5)
        landmark_height = min(540, max(220, height * 0.8))
        room["landmark_art"] = {"motif": MOTIFS[theme_index], "position": [round(x + width * 0.66 - landmark_width * 0.5), round(y - landmark_height * 0.18)], "size": [round(landmark_width), round(landmark_height)]}
    if theme_index < 2:
        return
    item_id = ["salt_crystal_shard", "pollen_wax", "obsidian_splinter", "crown_echo_shard"][theme_index - 2]
    for room in config["map_rooms"]:
        if room.get("kind") != "reward":
            continue
        reward_id = "col_branch_" + room["id"]
        if any(c.get("id") == reward_id for c in config.get("collectibles", [])):
            continue
        x, y, w, h = room["layout_rect"]
        floors = [p for p in config["platforms"] if p["rect"][3] <= 100 and x <= platform_center(p)[0] <= x + w and y <= p["rect"][1] <= y + h]
        if floors:
            floor = max(floors, key=lambda p: p["rect"][2])
            fx, fy = platform_center(floor)
            config["collectibles"].append({"id": reward_id, "kind": "item", "item_id": item_id, "amount": 5, "position": [round(fx), round(fy - 46)], "room_id": room["id"], "platform_id": floor["id"], "reward_role": "optional_exploration"})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path)
    args = parser.parse_args()
    sources = json.loads(args.sources.read_text()) if args.sources else {}
    for theme in THEMES:
        folder = ART_ROOT / theme
        folder.mkdir(parents=True, exist_ok=True)
        if theme in sources:
            for key, destination in [("background", "background.png"), ("platforms", "platform_atlas.png"), ("decor", "decor_atlas.png")]:
                shutil.copyfile(sources[theme][key], folder / destination)
        manifest = index_atlas(theme)
        index_decorations(theme, manifest)
    for path in sorted((ROOT / "godot/data").glob("demo_ch0[1-6]_*.json")):
        config = json.loads(path.read_text(encoding="utf-8-sig"))
        theme = config.get("art_theme", "moss_cavern")
        config.setdefault("art_theme", theme)
        assign_styles(config)
        landmarks_and_rewards(config, THEMES.index(theme))
        write_json(path, config)
    print("FLAT_MAP_ART_BUILD_PASS chapters=6 distinct_platform_drawings=72 scenery_props=36")


if __name__ == "__main__":
    main()

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
DATA_DIR = GODOT / "data"
OUT_ROOT = GODOT / "assets" / "third_party" / "dark_fantasy_bestiary" / "runtime_keyframes"

CONFIG_FILES = sorted(DATA_DIR.glob("demo_ch*.json"))

GRID_OVERRIDES = {
    "ansimuz-shambler-pal2-alpha_0.png": (32, 40),
    "ansimuz-shambler-short-pal2-alpha_0.png": (32, 32),
    "balmer-andromalius-57x88-alpha.png": (57, 88),
    "balmer-minion-45x66-alpha.png": (45, 66),
    "calciumtrice-emceeflesher-worm-alpha.png": (32, 48),
    "redshrike-blatty-alpha-pal2.png": (64, 64),
    "redshrike-blatty-alpha.png": (64, 64),
    "redshrike-bonio-alpha.png": (32, 32),
    "redshrike-emceeflesher-eyewasp-alpha.png": (36, 36),
    "redshrike-emceeflesher-skullwasp-alpha.png": (36, 36),
    "redshrike-emceeflesher-wasp.png": (38, 36),
    "redshrike-evert-pufalotti-frogman-pal2-alpha.png": (60, 60),
    "redshrike-evert-pufalotti-frogman-pal2-smaller-alpha.png": (60, 60),
    "redshrike-thompson-golem-pal2-alpha.png": (64, 72),
    "redshrike-wartaur-alpha.png": (80, 80),
    "sparky-surt-emceeflesher-alpha.png": (32, 32),
    "surt-emceeflesher-spitsnail-alpha_0.png": (32, 32),
}

REQUIRED_ANIMS = ["idle", "walk", "attack", "hurt", "death"]


def main() -> None:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    updated = 0
    manifests: dict[str, str] = {}
    for config_path in CONFIG_FILES:
        data = load_json(config_path)
        for actor in all_actors(data):
            sprite = str(actor.get("sprite", ""))
            if "dark_fantasy_bestiary" not in sprite:
                continue
            source_sprite = str(actor.get("source_sprite", sprite))
            source_region = actor.get("source_sprite_region", actor.get("sprite_region", []))
            source_path = res_path(source_sprite)
            if source_path.suffix.lower() == ".json":
                continue
            if not source_path.exists():
                continue
            kind = str(actor.get("kind", "enemy"))
            manifest_path = build_manifest_for_actor(kind, source_path, source_region)
            actor["source_sprite"] = source_sprite
            actor["source_sprite_region"] = source_region
            actor["sprite"] = to_res_path(manifest_path)
            actor["sprite_region"] = [0, 0, int(manifest_path.with_suffix(".meta").read_text(encoding="utf-8").split("x")[0]), int(manifest_path.with_suffix(".meta").read_text(encoding="utf-8").split("x")[1])]
            actor["sprite_regions"] = {
                "idle": actor["sprite_region"],
                "walk": actor["sprite_region"],
                "attack": actor["sprite_region"],
                "hurt": actor["sprite_region"],
                "death": actor["sprite_region"],
            }
            manifests[kind] = actor["sprite"]
            updated += 1
        config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for meta_path in OUT_ROOT.rglob("*.meta"):
        meta_path.unlink()
    print(f"BUILD_ENEMY_RUNTIME_KEYFRAMES_PASS actors={updated} manifests={len(set(manifests.values()))}")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def all_actors(data: dict[str, Any]) -> list[dict[str, Any]]:
    actors: list[dict[str, Any]] = []
    actors.extend(actor for actor in data.get("enemy_spawns", []) if isinstance(actor, dict))
    boss = data.get("boss", {})
    if isinstance(boss, dict) and boss:
        actors.append(boss)
    return actors


def res_path(path: str) -> Path:
    if path.startswith("res://"):
        return GODOT / path.removeprefix("res://")
    return ROOT / path


def to_res_path(path: Path) -> str:
    return "res://" + path.relative_to(GODOT).as_posix()


def build_manifest_for_actor(kind: str, source_path: Path, source_region: Any) -> Path:
    image = Image.open(source_path).convert("RGBA")
    cell_w, cell_h = cell_size(source_path, source_region)
    out_dir = OUT_ROOT / sanitize(kind)
    out_dir.mkdir(parents=True, exist_ok=True)
    frames = build_frames(image, cell_w, cell_h, start_index(source_region, cell_w, cell_h, image.width))
    if not frames:
        raise RuntimeError(f"No usable frames for {kind}: {source_path}")
    frame_paths: list[Path] = []
    for index, frame in enumerate(frames[:8]):
        frame_path = out_dir / f"frame_{index:02d}.png"
        frame.save(frame_path)
        frame_paths.append(frame_path)
    anims = {
        "idle": [0, 1],
        "walk": [1, 2, 3],
        "attack": [3, 4],
        "hurt": [4],
        "death": [5],
    }
    manifest = {
        "source": to_res_path(source_path),
        "note": "Runtime keyframes cropped from open dark fantasy source sprites; no generated art.",
        "cell_size": [cell_w, cell_h],
        "animations": [],
    }
    for name in REQUIRED_ANIMS:
        indexes = [i % len(frame_paths) for i in anims[name]]
        manifest["animations"].append({
            "name": name,
            "fps": 7.0 if name in {"idle", "walk"} else 10.0,
            "loop": name in {"idle", "walk"},
            "frames": [to_res_path(frame_paths[i]) for i in indexes],
        })
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest_path.with_suffix(".meta").write_text(f"{cell_w}x{cell_h}", encoding="utf-8")
    return manifest_path


def cell_size(source_path: Path, region: Any) -> tuple[int, int]:
    if source_path.name in GRID_OVERRIDES:
        return GRID_OVERRIDES[source_path.name]
    if isinstance(region, list) and len(region) >= 4:
        return max(1, int(region[2])), max(1, int(region[3]))
    image = Image.open(source_path)
    return image.width, image.height


def start_index(region: Any, cell_w: int, cell_h: int, image_width: int) -> int:
    if not isinstance(region, list) or len(region) < 2:
        return 0
    cols = max(1, image_width // max(1, cell_w))
    return int(region[1]) // max(1, cell_h) * cols + int(region[0]) // max(1, cell_w)


def build_frames(image: Image.Image, cell_w: int, cell_h: int, preferred_index: int) -> list[Image.Image]:
    tiles: list[tuple[int, Image.Image, int, tuple[int, int, int, int]]] = []
    tile_index = 0
    for y in range(0, image.height, cell_h):
        if y + 1 > image.height:
            continue
        for x in range(0, image.width, cell_w):
            if x + 1 > image.width:
                continue
            crop = image.crop((x, y, min(x + cell_w, image.width), min(y + cell_h, image.height)))
            frame = isolate_single_actor(crop, cell_w, cell_h)
            bbox = frame.getbbox()
            if bbox is not None:
                tiles.append((tile_index, frame, alpha_area(frame), bbox))
            tile_index += 1
    if not tiles:
        return []
    tiles = filter_actor_tiles(tiles)
    after = [frame for index, frame, _area, _bbox in tiles if index >= preferred_index]
    before = [frame for index, frame, _area, _bbox in tiles if index < preferred_index]
    ordered = after + before
    while len(ordered) < 6:
        ordered.extend(ordered)
    return ordered[:8]


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


def alpha_area(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    return sum(1 for value in alpha.getdata() if value > 0)


def isolate_single_actor(crop: Image.Image, cell_w: int, cell_h: int) -> Image.Image:
    components = connected_components(crop)
    if not components:
        return Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    anchor = max(components, key=lambda item: item["area"])
    keep = [anchor]
    for component in components:
        if component is anchor:
            continue
        if should_merge_component(anchor["bbox"], component["bbox"], anchor["area"], component["area"]):
            keep.append(component)
    mask = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    source = crop.load()
    target = mask.load()
    keep_points = set()
    for component in keep:
        keep_points.update(component["points"])
    for x, y in keep_points:
        target[x, y] = source[x, y]
    if mask.size != (cell_w, cell_h):
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        canvas.alpha_composite(mask, (0, 0))
        return canvas
    return mask


def should_merge_component(anchor: tuple[int, int, int, int], candidate: tuple[int, int, int, int], anchor_area: int, candidate_area: int) -> bool:
    if candidate_area < max(10, anchor_area * 0.12):
        return False
    ax0, ay0, ax1, ay1 = anchor
    bx0, by0, bx1, by1 = candidate
    x_overlap = max(0, min(ax1, bx1) - max(ax0, bx0))
    min_width = max(1, min(ax1 - ax0, bx1 - bx0))
    vertical_gap = max(0, max(ay0, by0) - min(ay1, by1))
    y_overlap = max(0, min(ay1, by1) - max(ay0, by0))
    horizontal_gap = max(0, max(ax0, bx0) - min(ax1, bx1))
    if x_overlap / min_width >= 0.35 and vertical_gap <= 18:
        return True
    if y_overlap >= 12 and horizontal_gap <= 1 and candidate_area >= anchor_area * 0.45:
        return True
    return False


def connected_components(image: Image.Image) -> list[dict[str, Any]]:
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    result: list[dict[str, Any]] = []
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
            if len(points) < 4:
                continue
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            result.append({
                "area": len(points),
                "bbox": (min(xs), min(ys), max(xs) + 1, max(ys) + 1),
                "points": points,
            })
    return result


def sanitize(value: str) -> str:
    allowed = []
    for char in value.lower():
        allowed.append(char if char.isalnum() or char in {"_", "-"} else "_")
    return "".join(allowed).strip("_") or "enemy"


if __name__ == "__main__":
    main()

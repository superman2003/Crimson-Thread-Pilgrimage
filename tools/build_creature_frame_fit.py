#!/usr/bin/env python3
"""Even out body size between the frames of each creature animation.

Creature frames were drawn one by one, so the same body is up to ~15% larger or
smaller from one frame to the next and the animation pulses. Redrawing is the
real cure; until then this tool measures how large each frame's body is next to
the frames the game shows around it and writes one small correction per frame.
The runtime applies it when it draws the frame (hit_flash.gdshader vertex
scale about the feet), so no drawing, atlas or manifest is changed.

How a frame is measured: its silhouette is overlaid on each neighbour at a
range of scales, free to slide, and the scale with the best overlap says how
much bigger one body is than the other. Those pairwise ratios (next frame, the
one after) are solved together per clip. Only a frame's jump against the
clip's slow trend is corrected: a body that rears up or curls over several
frames keeps doing so, and clips are not resized against each other. A frame
that barely overlays its neighbours (a very different pose) is believed less,
down to no correction at all.

    python tools/build_creature_frame_fit.py            # rewrite frame_fit.json files
    python tools/build_creature_frame_fit.py --check    # fail if any is stale or missing
    python tools/build_creature_frame_fit.py --only echo_moss_larva --sheet out.jpg
    python tools/build_creature_frame_fit.py --self-test
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CREATURES = ROOT / "godot/assets/sprites/original_creatures"
# Same order as hand_drawn_assets.character_manifest: the first present is loaded.
ACTIVE_LAYERS = ["motion_transition_manifest.json", "motion_onion_manifest.json", "motion_v8_manifest.json", "boss_behavior_manifest.json",
                 "combat_motion_v7_manifest.json", "motion_manifest.json", "manifest.json"]
OUTPUT = "frame_fit.json"
GRID = 192                      # overlay resolution
SCALES = [math.exp(v) for v in np.linspace(math.log(0.76), math.log(1 / 0.76), 21)]
DEADBAND = 0.025                # smaller differences are left alone
LIMIT = (0.87, 1.15)            # never correct by more than this
# How well a frame overlays its direct neighbours decides how far its measured
# size is believed. Between two very different poses (a spear swung from upright
# to level) the best overlay says little about body size: no correction at or
# below TRUST[0], the full LIMIT only from TRUST[1] up.
TRUST = (0.5, 0.7)
SOLID_ALPHA = 128
# A body that is falling apart has no size to keep.
SKIP_CLIPS = ("death",)


def active_manifest(folder: Path) -> Path | None:
    return next((folder / name for name in ACTIVE_LAYERS if (folder / name).exists()), None)


def animations_of(manifest: dict) -> list[dict]:
    rows = manifest["animations"]
    return rows if isinstance(rows, list) else [dict(row, name=name) for name, row in rows.items()]


def atlas_digests(manifest: dict) -> dict[str, str]:
    """Fingerprint the pixels actually measured, including in-place redraws."""
    resources = sorted({frame["atlas"] for clip in animations_of(manifest)
                        for frame in clip["frames"] if isinstance(frame, dict)})
    return {resource: hashlib.sha256((ROOT / "godot" / resource.removeprefix("res://")).read_bytes()).hexdigest()
            for resource in resources}


def is_grounded(manifest: dict) -> bool:
    # Stationary creatures stand on a fixed base just like walking creatures.
    return manifest.get("motion", "ground") in ("ground", "stationary")


class Atlases:
    def __init__(self):
        self.pages = {}

    def alpha(self, frame: dict) -> Image.Image:
        resource = frame["atlas"]
        if resource not in self.pages:
            if len(self.pages) > 10:
                self.pages.clear()
            with Image.open(ROOT / "godot" / resource.removeprefix("res://")) as image:
                self.pages[resource] = image.convert("RGBA").getchannel("A")
        x, y, w, h = frame["region"]
        return self.pages[resource].crop((x, y, x + w, y + h))


def _raster(image: Image.Image, scale: float) -> np.ndarray:
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    pixels = np.asarray(image.resize(size, Image.Resampling.BILINEAR), np.float32)[:GRID, :GRID] / 255.0
    canvas = np.zeros((GRID, GRID), np.float32)
    canvas[:pixels.shape[0], :pixels.shape[1]] = pixels
    return canvas


def overlay_scale(reference: Image.Image, other: Image.Image) -> tuple[float, float]:
    """(s, overlap): `other` enlarged by s overlays `reference` best; overlap is that IoU."""
    shrink = (GRID * 0.5) / (max(reference.size + other.size) / SCALES[0])
    shrink = min(1.0, shrink)
    base = _raster(reference, shrink)
    spectrum, total = np.fft.rfft2(base), float(base.sum())
    overlaps = []
    for scale in SCALES:
        moved = _raster(other, shrink * scale)
        shared = float(np.fft.irfft2(spectrum * np.conj(np.fft.rfft2(moved)), s=(GRID, GRID)).max())
        overlaps.append(shared / max(1e-6, total + float(moved.sum()) - shared))
    best = int(np.argmax(overlaps))
    log_scale = math.log(SCALES[best])
    if 0 < best < len(SCALES) - 1:
        a, b, c = overlaps[best - 1], overlaps[best], overlaps[best + 1]
        curve = a - 2 * b + c
        if curve < -1e-9:
            log_scale += 0.5 * (a - c) / curve * (math.log(SCALES[1]) - math.log(SCALES[0]))
    return math.exp(log_scale), overlaps[best]


def solve_levels(count: int, links: list[tuple[int, int, float, float]], anchors: list[int]) -> np.ndarray:
    """Log body size per frame from links (i, j, log(size_i / size_j), weight); anchors average 0."""
    if not links:
        return np.zeros(count)
    weights = np.array([link[3] for link in links])
    levels = np.zeros(count)
    for _ in range(3):
        rows = np.zeros((len(links) + 1, count))
        target = np.zeros(len(links) + 1)
        for row, (i, j, value, _) in enumerate(links):
            rows[row, i], rows[row, j], target[row] = weights[row], -weights[row], value * weights[row]
        rows[-1, anchors or list(range(count))] = 10.0
        levels = np.linalg.lstsq(rows, target, rcond=None)[0]
        # One bad overlay (a pose with nothing in common) must not move the rest.
        residual = np.array([abs(levels[i] - levels[j] - value) for i, j, value, _ in links])
        weights = np.array([link[3] for link in links]) / (1.0 + (residual / 0.05) ** 2)
    return levels


def pivot_of(alpha: Image.Image, frame: dict, canvas: list[int], grounded: bool) -> list[float]:
    """Point the body is scaled about, in pixels from the canvas centre (how the sprite is drawn)."""
    solid = np.asarray(alpha) > SOLID_ALPHA
    ys, xs = np.nonzero(solid)
    margin = frame.get("margin", [0, 0, 0, 0])
    if len(xs) == 0:
        return [0.0, 0.0]
    x = margin[0] + float(xs.mean()) - canvas[0] / 2
    y = margin[1] + (float(ys.max()) + 1 if grounded else float(ys.mean())) - canvas[1] / 2
    return [round(x, 1), round(y, 1)]


def trend(levels: np.ndarray, loop: bool) -> np.ndarray:
    """Slow change of size along a clip (a body rearing up or curling), which is kept."""
    count = len(levels)
    reach = 3 if count >= 16 else 2
    if count < 2 * reach + 1:
        return np.full(count, float(np.median(levels)))
    out = np.zeros(count)
    for i in range(count):
        window = [(i + d) % count for d in range(-reach, reach + 1)] if loop else list(range(max(0, i - reach), min(count, i + reach + 1)))
        out[i] = np.median(levels[window])
    return out


def measure_clip(images: list[Image.Image], loop: bool) -> list[float]:
    """Scale per frame that removes its size jump against the frames around it."""
    count = len(images)
    visible = [image.getbbox() is not None for image in images]
    links = []
    seen = [[] for _ in range(count)]
    for number in range(count):
        for step in (1, 2):
            other = number + step
            if other >= count:
                if not loop or count <= step:
                    continue
                other %= count
            if other == number or not (visible[number] and visible[other]):
                continue
            scale, overlap = overlay_scale(images[number], images[other])
            links.append((number, other, math.log(scale), max(0.03, overlap - 0.4)))
            if step == 1:
                seen[number].append(overlap)
                seen[other].append(overlap)
    levels = solve_levels(count, links, [])
    jump = levels - trend(levels, loop)
    result = []
    for number in range(count):
        trust = (sum(seen[number]) / len(seen[number]) - TRUST[0]) / (TRUST[1] - TRUST[0]) if seen[number] else 0.0
        reach = math.log(LIMIT[1]) * min(1.0, max(0.0, trust))
        change = min(reach, max(-reach, -jump[number]))
        result.append(1.0 if abs(change) < DEADBAND or not visible[number] else round(math.exp(change), 3))
    return result


def measure(kind: str) -> dict | None:
    folder = CREATURES / kind
    path = active_manifest(folder)
    if path is None:
        return None
    manifest = json.loads(path.read_text(encoding="utf-8"))
    atlases = Atlases()
    grounded = is_grounded(manifest)
    result = {}
    for clip in animations_of(manifest):
        frames = clip["frames"]
        if clip["name"].startswith(SKIP_CLIPS) or len(frames) < 3 or not all(isinstance(frame, dict) for frame in frames):
            continue
        images = [atlases.alpha(frame) for frame in frames]
        canvas = manifest.get("canvas") or [images[0].width, images[0].height]
        scales = measure_clip(images, bool(clip.get("loop", True)))
        if any(scale != 1.0 for scale in scales):
            result[clip["name"]] = [[round(scale, 3)] + (pivot_of(image, frame, canvas, grounded) if scale != 1.0 else [0, 0])
                                    for scale, image, frame in zip(scales, images, frames)]
    return dict(kind=kind, manifest=path.name, manifest_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                atlas_sha256=atlas_digests(manifest), frames=result)


def encode(data: dict) -> str:
    lines = ["{", f' "kind": {json.dumps(data["kind"])},', f' "manifest": {json.dumps(data["manifest"])},',
             f' "manifest_sha256": {json.dumps(data["manifest_sha256"])},',
             f' "atlas_sha256": {json.dumps(data["atlas_sha256"], sort_keys=True)},', ' "frames": {']
    clips = list(data["frames"].items())
    for position, (name, rows) in enumerate(clips):
        comma = "," if position < len(clips) - 1 else ""
        lines.append(f'  {json.dumps(name)}: {json.dumps(rows, separators=(",", ":"))}{comma}')
    lines += [" }", "}"]
    return "\n".join(lines) + "\n"


def kinds() -> list[str]:
    return sorted(folder.name for folder in CREATURES.iterdir() if folder.is_dir() and active_manifest(folder))


def sheet(kind: str, data: dict, out: Path, limit: int = 6):
    """Before / after rows of the most corrected clips, for a flip-through by eye."""
    manifest = json.loads((CREATURES / kind / data["manifest"]).read_text(encoding="utf-8"))
    clips = {clip["name"]: clip for clip in animations_of(manifest)}
    canvas = manifest["canvas"]
    ranked = sorted(data["frames"], key=lambda n: -sum(abs(math.log(r[0])) for r in data["frames"][n]))[:limit]
    cell = (canvas[0] // 2, canvas[1] // 2)
    rows = []
    pages = {}
    for name in ranked:
        frames = clips[name]["frames"][:16]
        for corrected in (False, True):
            row = Image.new("RGBA", (cell[0] * 16, cell[1]), (38, 38, 46, 255))
            for number, frame in enumerate(frames):
                resource = frame["atlas"]
                if resource not in pages:
                    pages[resource] = Image.open(ROOT / "godot" / resource.removeprefix("res://")).convert("RGBA")
                x, y, w, h = frame["region"]
                scale, px, py = data["frames"][name][number] if corrected else (1.0, 0, 0)
                art = pages[resource].crop((x, y, x + w, y + h))
                art = art.resize((max(1, round(w * scale / 2)), max(1, round(h * scale / 2))), Image.Resampling.LANCZOS)
                left = canvas[0] / 2 + px + (frame["margin"][0] - canvas[0] / 2 - px) * scale
                top = canvas[1] / 2 + py + (frame["margin"][1] - canvas[1] / 2 - py) * scale
                row.alpha_composite(art, (max(0, number * cell[0] + round(left / 2)), max(0, round(top / 2))))
            rows.append(row)
    if not rows:
        return
    page = Image.new("RGB", (rows[0].width, sum(row.height for row in rows)), (0, 0, 0))
    offset = 0
    for row in rows:
        page.paste(row.convert("RGB"), (0, offset))
        offset += row.height
    page.save(out, quality=85)


def self_test():
    # A body redrawn 10% larger in the middle of five frames is found and undone.
    def blob(scale):
        image = Image.new("L", (200, 160), 0)
        pixels = image.load()
        for y in range(160):
            for x in range(200):
                if ((x - 100) / (60 * scale)) ** 2 + ((y - 90) / (38 * scale)) ** 2 < 1 or (abs(x - 100 - 30 * scale) < 9 * scale and y > 90):
                    pixels[x, y] = 255
        return image.crop(image.getbbox())
    sizes = [1.0, 1.0, 1.1, 1.0, 1.0, 0.92, 1.0, 1.0]
    found = measure_clip([blob(size) for size in sizes], True)
    assert all(abs(f * s - 1.0) <= 0.025 for f, s in zip(found, sizes)), found
    # A steady growth over the clip is a pose change, not a jump: left alone.
    grow = measure_clip([blob(1.0 + 0.02 * i) for i in range(8)], False)
    assert all(abs(f - 1.0) <= 0.03 for f in grow[1:-1]), grow
    # A pose with little in common with its neighbours is not resized on a guess.
    bar = Image.new("L", (220, 40), 255)
    swung = measure_clip([blob(1.0), blob(1.0), bar, blob(1.0), blob(1.0), blob(1.0)], False)
    assert swung[2] == 1.0, swung
    assert solve_levels(3, [], []).tolist() == [0, 0, 0]
    print("build_creature_frame_fit self-test passed", found)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only", action="append")
    parser.add_argument("--sheet", type=Path)
    parser.add_argument("--jobs", type=int, default=0)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    selected = args.only or kinds()
    if args.check:
        # Currency is tied to the drawings' manifest; re-measuring every frame in CI would add minutes.
        stale = []
        for kind in selected:
            path, manifest = CREATURES / kind / OUTPUT, active_manifest(CREATURES / kind)
            if not path.exists():
                stale.append(kind + ": missing " + OUTPUT)
                continue
            data = json.loads(path.read_text(encoding="utf-8"))
            if data["manifest"] != manifest.name or data["manifest_sha256"] != hashlib.sha256(manifest.read_bytes()).hexdigest():
                stale.append(f"{kind}: drawings changed since {OUTPUT} was measured; run: python tools/build_creature_frame_fit.py --only {kind}")
                continue
            contents = json.loads(manifest.read_text(encoding="utf-8"))
            if data.get("atlas_sha256") != atlas_digests(contents):
                stale.append(f"{kind}: atlas pixels changed; run: python tools/build_creature_frame_fit.py --only {kind}")
            clips = {clip["name"]: len(clip["frames"]) for clip in animations_of(contents)}
            for name, rows in data["frames"].items():
                if clips.get(name) != len(rows):
                    stale.append(f"{kind}/{name}: frame count differs")
                if any(not (LIMIT[0] - 0.001 <= row[0] <= LIMIT[1] + 0.001) or len(row) != 3 for row in rows):
                    stale.append(f"{kind}/{name}: correction outside limits")
        for line in stale:
            print("STALE", line)
        print(json.dumps(dict(creatures=len(selected), stale=len(stale))))
        return 1 if stale else 0
    with ProcessPoolExecutor(max_workers=args.jobs or None) as pool:
        results = list(pool.map(measure, selected))
    corrected = total = 0
    for data in results:
        (CREATURES / data["kind"] / OUTPUT).write_text(encode(data), encoding="utf-8", newline="\n")
        changed = sum(row[0] != 1.0 for rows in data["frames"].values() for row in rows)
        corrected += changed
        total += sum(len(rows) for rows in data["frames"].values())
        print(f'{data["kind"]:32s} clips={len(data["frames"]):3d} corrected_frames={changed}')
        if args.sheet:
            target = args.sheet if len(results) == 1 else args.sheet.with_name(f'{args.sheet.stem}_{data["kind"]}{args.sheet.suffix}')
            sheet(data["kind"], data, target)
    print(json.dumps(dict(creatures=len(results), corrected_frames=corrected)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Onion-skin in-between pipeline: geometry from the manifest, drawing from image_gen.

A hand animator keeps a creature the same size by drawing every pose on the same
canvas, over faint copies of the poses before and after it. This pipeline gives
the image model that same frame of reference instead of guessing scale later:

  prepare  For each requested transition (pose i -> the pose the runtime shows
           next) draw one cell: the runtime canvas at a per-character scale K that
           never changes, both endpoint poses as tinted onion skins at their real
           runtime position, the shared ground line, and four green corner
           markers on the sheet. Six cells per sheet.
  deliver  Find the markers on the generated sheet and fit the affine that maps
           it back onto the reference sheet (the model may shift or resize the
           whole image, never one cell). Every figure then maps to runtime canvas
           coordinates by construction: (sheet - cell origin) / K. No per-figure
           scale is estimated.
           Each drawing is then checked like a flip-through: solid area between
           the endpoints, ground contact, horizontal placement, colour, and that
           it is not a copy of an endpoint. Rejected drawings are not corrected;
           `retry` plans new sheets for exactly those transitions.
  build    Writes motion_onion_manifest.json beside the creature's manifests.
           Over a baseline layer, an animation whose every transition has an
           accepted drawing gets a new pose after each old one and doubled fps
           (same duration). Over a doubled layer (motion_v8) an accepted drawing
           replaces that transition's existing midpoint, so only failed frames
           need redrawing.
  preview  Contact strip and looping GIF per animation for a human flip-through.

    python tools/motion_onion.py prepare --kind wax_bee [--animation idle] [--batch NAME]
    python tools/motion_onion.py deliver --job wax_bee__idle__01 --image out.png
    python tools/motion_onion.py retry --kind wax_bee
    python tools/motion_onion.py build --kind wax_bee [--over motion_v8_manifest.json]
    python tools/motion_onion.py preview --kind wax_bee --animation idle
    python tools/motion_onion.py check            # every committed onion layer rebuilds byte-identically
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from audit_motion_scale_consistency import THRESHOLD, check_clip

ROOT = Path(__file__).resolve().parents[1]
CREATURES = ROOT / "godot/assets/sprites/original_creatures"
REQUEST = ROOT / "art_requests/motion_onion"
LAYER = "motion_onion_manifest.json"
# Poses the onion skins are taken from: the authored clips, never generated midpoints.
BASELINE_LAYERS = ["boss_behavior_manifest.json", "combat_motion_v7_manifest.json", "motion_manifest.json", "manifest.json"]
DOUBLED_LAYERS = ["motion_v8_manifest.json"]

SHEET = (1536, 1024)
GRID = (3, 2)
CELL = 512
CELL_PAD = 44
MARKER = 28
MARKER_INSET = 10
MARKER_RGB = (0, 230, 64)
MARKER_TOLERANCE = 6.0
SOLID_ALPHA = 128
INK_ALPHA = 24
SPECK = 24
GROUND_SHARED = 4
GROUND_TOLERANCE = 0.05
PLACEMENT_TOLERANCE = 0.12
COLOUR_TOLERANCE = 30.0
COPY_IOU = 0.97
COPY_SHIFT = 2

PROMPT = """Use case: identity-preserve. Asset type: production 2D game animation IN-BETWEEN drawings for Crimson Thread Pilgrimage.
Input image 1 is an ONION-SKIN SHEET, 1536x1024, three columns by two rows of 512x512 cells, read row-major 1 to {cells}. In each used cell two faint tinted ghosts show the SAME character in two consecutive poses: the BLUE ghost is the EARLIER pose and the ORANGE ghost is the LATER pose. They are drawn at the character's exact production size and position; the grey line is the ground the character stands on.
Input image 2 is the same character in full colour at the same scale, for identity only.
Output one 1536x1024 image with a genuinely transparent background. Keep the four solid green corner squares EXACTLY where they are in image 1, same size. In each used cell draw ONE new full-colour pose halfway between its two ghosts, drawn ON TOP OF the ghosts: same position, same body size as the ghosts, feet on the same ground line, same right-facing side view. The body must not grow when it crouches or shrink when it stretches: match the ghosts' body mass, limb lengths and weapon length.
Remove everything else: no ghosts, no grey lines, no cell borders, no numbers, text, shadows, glow, particles or background. Leave unused cells empty. Nothing may cross a cell border.
Character ID: {kind}. Preserve the existing design exactly; this is animation completion, not redesign."""


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def rel(path):
    path = Path(path).resolve()
    return path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else path.as_posix()


def res_path(resource):
    prefix = "res://assets/sprites/original_creatures/"
    if resource.startswith(prefix):
        return CREATURES / resource.removeprefix(prefix)
    return ROOT / "godot" / resource.removeprefix("res://")


def clips_of(manifest):
    rows = manifest["animations"]
    return rows if isinstance(rows, dict) else {row["name"]: row for row in rows}


def first_layer(kind, names):
    return next((CREATURES / kind / name for name in names if (CREATURES / kind / name).exists()), None)


_atlases = {}


def cel(frame):
    path = res_path(frame["atlas"])
    if path not in _atlases:
        with Image.open(path) as image:
            _atlases[path] = image.convert("RGBA")
    x, y, w, h = frame["region"]
    return _atlases[path].crop((x, y, x + w, y + h))


def follower(clips, clip, index):
    """The pose the runtime shows after clip[index] (same rule as the v8 midpoint plan)."""
    name, frames = clip["name"], clip["frames"]
    if index + 1 < len(frames):
        return frames[index + 1]
    if clip.get("loop"):
        return frames[0]
    if name == "death":
        return frames[-1]
    if name == "windup":
        target = "attack"
    elif name.endswith("_windup"):
        target = name.removesuffix("_windup")
    elif name.endswith("_bridge"):
        target = "recover"
    elif name == "ready_guard":
        target = "ready_settle"
    elif name == "attack":
        target = "recover"
    elif name + "_recover" in clips:
        target = name + "_recover"
    else:
        target = "idle"
    return clips.get(target, clips["idle"])["frames"][0]


# ---------------------------------------------------------------- geometry

def scale_for(canvas):
    """One sheet scale per character: the largest that fits its runtime canvas in a cell."""
    return round(min((CELL - 2 * CELL_PAD) / canvas[0], (CELL - 2 * CELL_PAD) / canvas[1]), 4)


def canvas_origin(slot, canvas, k):
    col, row = slot % GRID[0], slot // GRID[0]
    return (col * CELL + (CELL - canvas[0] * k) / 2, row * CELL + (CELL - canvas[1] * k) / 2)


def marker_centres():
    half = MARKER_INSET + MARKER / 2
    return [(half, half), (SHEET[0] - half, half), (half, SHEET[1] - half), (SHEET[0] - half, SHEET[1] - half)]


def draw_markers(image):
    draw = ImageDraw.Draw(image)
    for cx, cy in marker_centres():
        draw.rectangle((cx - MARKER / 2, cy - MARKER / 2, cx + MARKER / 2 - 1, cy + MARKER / 2 - 1), fill=MARKER_RGB + (255,))


def solid_bbox(image):
    return Image.fromarray(((np.asarray(image)[:, :, 3] > SOLID_ALPHA) * 255).astype(np.uint8)).getbbox()


def placed(frame):
    """(image, x, y) of a manifest frame on its runtime canvas."""
    return cel(frame), frame["margin"][0], frame["margin"][1]


def ground_of(frame):
    image, _, y = placed(frame)
    box = solid_bbox(image)
    return None if box is None else y + box[3]


def mass_x(image, x):
    weights = np.asarray(image)[:, :, 3].astype(np.float64).sum(axis=0)
    return x + float((weights * np.arange(len(weights))).sum() / max(1.0, weights.sum()))


def ghost(image, tint, alpha):
    pixels = np.asarray(image).astype(np.float32)
    grey = pixels[:, :, :3].mean(axis=2, keepdims=True)
    pixels[:, :, :3] = grey * 0.45 + np.array(tint, dtype=np.float32) * 0.55
    pixels[:, :, 3] *= alpha
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------- prepare

def transitions(kind, animation=None):
    path = first_layer(kind, BASELINE_LAYERS)
    if path is None:
        raise ValueError(f"{kind}: no baseline manifest")
    manifest = read(path)
    clips = clips_of(manifest)
    edges = []
    for name, clip in clips.items():
        if animation and name != animation:
            continue
        clip = dict(clip, name=name)
        for index, frame in enumerate(clip["frames"]):
            edges.append(dict(animation=name, after=index, left=frame, right=follower(clips, clip, index)))
    if not edges:
        raise ValueError(f"{kind}: nothing to plan for {animation}")
    return rel(path), manifest["canvas"], edges


def render_sheets(kind, canvas, k, edges):
    cells = GRID[0] * GRID[1]
    onion = Image.new("RGBA", SHEET, (238, 236, 230, 255))
    identity = Image.new("RGBA", SHEET, (0, 0, 0, 0))
    draw = ImageDraw.Draw(onion)
    size = (round(canvas[0] * k), round(canvas[1] * k))
    for slot, edge in enumerate(edges):
        ox, oy = canvas_origin(slot, canvas, k)
        draw.rectangle((ox, oy, ox + size[0], oy + size[1]), outline=(205, 203, 198, 255))
        grounds = [ground_of(edge["left"]), ground_of(edge["right"])]
        if None not in grounds and abs(grounds[0] - grounds[1]) <= GROUND_SHARED:
            gy = oy + max(grounds) * k
            draw.line((ox + 6, gy, ox + size[0] - 6, gy), fill=(150, 150, 150, 255), width=2)
        for key, tint in (("left", (40, 110, 235)), ("right", (240, 120, 30))):
            image, x, y = placed(edge[key])
            scaled = image.resize((max(1, round(image.width * k)), max(1, round(image.height * k))), Image.Resampling.LANCZOS)
            onion.alpha_composite(ghost(scaled, tint, 0.42), (round(ox + x * k), round(oy + y * k)))
            if key == "left":
                identity.alpha_composite(scaled, (round(ox + x * k), round(oy + y * k)))
    assert len(edges) <= cells
    draw_markers(onion)
    draw_markers(identity)
    return onion, identity


def plan_jobs(kind, edges, canvas, k, baseline, batch):
    cells = GRID[0] * GRID[1]
    jobs = []
    for offset in range(0, len(edges), cells):
        chunk = edges[offset:offset + cells]
        job_id = f"{kind}__{batch}__{offset // cells + 1:02}"
        onion, identity = render_sheets(kind, canvas, k, chunk)
        folder = REQUEST / "sheets" / kind
        folder.mkdir(parents=True, exist_ok=True)
        onion.convert("RGB").save(folder / f"{job_id}.onion.png")
        identity.save(folder / f"{job_id}.identity.png")
        jobs.append(dict(id=job_id, kind=kind, baseline=baseline, canvas=canvas, scale=k,
                         onion=rel(folder / f"{job_id}.onion.png"), identity=rel(folder / f"{job_id}.identity.png"),
                         source=rel(REQUEST / "incoming" / kind / f"{job_id}.png"),
                         prompt=PROMPT.format(cells=len(chunk), kind=kind),
                         edges=[dict(animation=e["animation"], after=e["after"], left=e["left"], right=e["right"]) for e in chunk]))
    return jobs


def spec_path(kind):
    return REQUEST / "jobs" / f"{kind}.json"


def load_spec(kind):
    path = spec_path(kind)
    return read(path) if path.exists() else dict(schema=1, kind=kind, jobs=[])


def prepare(kind, animation=None, batch=None, edges_filter=None):
    baseline, canvas, edges = transitions(kind, animation)
    if edges_filter is not None:
        edges = [e for e in edges if (e["animation"], e["after"]) in edges_filter]
    spec = load_spec(kind)
    k = spec.get("scale") or scale_for(canvas)
    if spec.get("canvas") not in (None, canvas):
        raise ValueError(f"{kind}: runtime canvas changed since the first sheets; replan from scratch")
    batch = batch or (animation or "all")
    if any(j["id"].startswith(f"{kind}__{batch}__") for j in spec["jobs"]):
        raise ValueError(f"{kind}: batch {batch!r} already planned; pick another --batch")
    jobs = plan_jobs(kind, edges, canvas, k, baseline, batch)
    spec.update(canvas=canvas, scale=k, baseline=baseline)
    spec["jobs"].extend(jobs)
    write(spec_path(kind), spec)
    print(json.dumps(dict(kind=kind, scale=k, transitions=len(edges), jobs=[j["id"] for j in jobs]), ensure_ascii=False))
    return jobs


# ---------------------------------------------------------------- deliver

def find_markers(rgba):
    """Centres of the four solid green squares, plus a mask of just those squares."""
    r, g, b, a = (rgba[:, :, i].astype(np.int32) for i in range(4))
    green = (a > SOLID_ALPHA) & (g > 170) & (r < 110) & (b < 140) & (g - np.maximum(r, b) > 90)
    labels, count = ndimage.label(green)
    height, width = green.shape
    expected = (MARKER * width / SHEET[0]) ** 2
    found, chosen = [], []
    for corner_x, corner_y in [(0, 0), (1, 0), (0, 1), (1, 1)]:
        best = None
        for label, box in enumerate(ndimage.find_objects(labels), start=1):
            h, w = box[0].stop - box[0].start, box[1].stop - box[1].start
            size = int((labels[box] == label).sum())
            cy, cx = (box[0].start + box[0].stop) / 2, (box[1].start + box[1].stop) / 2
            # A marker is a filled square near its own corner; green paint on a
            # creature is neither square-filled nor there.
            if not 0.3 * expected <= size <= 3 * expected or not 0.7 <= w / h <= 1.4 or size < 0.8 * w * h:
                continue
            if abs(cx - corner_x * width) > width * 0.12 or abs(cy - corner_y * height) > height * 0.12:
                continue
            score = abs(math.log(size / expected))
            if best is None or score < best[0]:
                best = (score, label, cx, cy)
        if best is None:
            raise ValueError("a corner marker is missing")
        chosen.append(best[1])
        found.append((best[2], best[3]))
    return found, np.isin(labels, chosen)


def fit_affine(source, target):
    """Least-squares affine taking source points onto target points; returns 2x3 and max residual."""
    a = np.array([[x, y, 1.0] for x, y in source])
    t = np.array(target, dtype=np.float64)
    coef, *_ = np.linalg.lstsq(a, t, rcond=None)
    residual = float(np.abs(a @ coef - t).max())
    return coef.T, residual


def to_sheet(path, *, stable_affine=False):
    """Resample the marked sheet; stable_affine versions reproducible sampling.

    Existing onion deliveries retain their original registration by default.
    New movement gestures opt into the recorded fixed-precision transform.
    """
    with Image.open(path) as image:
        rgba = np.asarray(image.convert("RGBA"))
    found, mask = find_markers(rgba)
    forward, residual = fit_affine(found, marker_centres())
    if residual > MARKER_TOLERANCE:
        raise ValueError(f"corner markers moved independently (residual {residual:.1f}px)")
    stretch = np.linalg.svd(forward[:, :2], compute_uv=False)
    if not 0.25 <= stretch.min() <= stretch.max() <= 4 or stretch.max() / stretch.min() > 1.06:
        raise ValueError(f"sheet was distorted, not just moved or resized ({stretch.round(3).tolist()})")
    cleaned = rgba.copy()
    cleaned[ndimage.binary_dilation(mask, iterations=2)] = 0
    if stable_affine:
        # Use the recorded precision for sampling as well as provenance. Tiny
        # LAPACK differences around integer coordinates otherwise change which
        # side of a pixel Pillow samples, even for an identity registration.
        forward = np.round(forward, 6)
    full = np.vstack([forward, [0, 0, 1]])
    inverse = np.linalg.inv(full)[:2]
    if stable_affine:
        inverse = np.round(inverse, 12)
    inverse = inverse.ravel().tolist()
    sheet = Image.fromarray(cleaned).transform(SHEET, Image.Transform.AFFINE, inverse, resample=Image.Resampling.BICUBIC)
    fit = dict(affine=[[round(v, 6) for v in row] for row in forward.tolist()], marker_residual=round(residual, 2))
    if stable_affine:
        fit["registration"] = "affine6_inverse12_v1"
    return sheet, fit


def figure_in(sheet, slot):
    col, row = slot % GRID[0], slot // GRID[0]
    box = (col * CELL, row * CELL, col * CELL + CELL, row * CELL + CELL)
    cell = np.asarray(sheet.crop(box)).copy()
    ink = cell[:, :, 3] > INK_ALPHA
    labels, count = ndimage.label(ink, structure=np.ones((3, 3)))
    if count == 0:
        return None, "empty cell"
    sizes = ndimage.sum(ink, labels, range(1, count + 1))
    keep = [i + 1 for i, size in enumerate(sizes) if size >= SPECK]
    if not keep:
        return None, "empty cell"
    mask = np.isin(labels, keep)
    cell[~mask] = 0
    ys, xs = np.nonzero(mask)
    if xs.min() == 0 or ys.min() == 0 or xs.max() == CELL - 1 or ys.max() == CELL - 1:
        return None, "figure crosses the cell border"
    left, top = int(xs.min()), int(ys.min())
    image = Image.fromarray(cell[top:ys.max() + 1, left:xs.max() + 1])
    return (image, box[0] + left, box[1] + top), None


def solid_area(image):
    return int((np.asarray(image)[:, :, 3] > SOLID_ALPHA).sum())


def mean_rgb(image):
    pixels = np.asarray(image)
    mask = pixels[:, :, 3] > SOLID_ALPHA
    return pixels[:, :, :3][mask].mean(axis=0) if mask.any() else np.zeros(3)


def canvas_mask(image, x, y, canvas):
    mask = np.zeros((canvas[1], canvas[0]), dtype=bool)
    alpha = np.asarray(image)[:, :, 3] > SOLID_ALPHA
    h, w = alpha.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(canvas[0], x + w), min(canvas[1], y + h)
    if x1 > x0 and y1 > y0:
        mask[y0:y1, x0:x1] = alpha[y0 - y:y1 - y, x0 - x:x1 - x]
    return mask


def overlap(a, b):
    """Best intersection-over-union of two masks within a small shift."""
    best = 0.0
    for dy in range(-COPY_SHIFT, COPY_SHIFT + 1):
        for dx in range(-COPY_SHIFT, COPY_SHIFT + 1):
            moved = np.roll(np.roll(b, dy, axis=0), dx, axis=1)
            union = (a | moved).sum()
            if union:
                best = max(best, (a & moved).sum() / union)
    return best


def inspect(drawing, x, y, edge, canvas, threshold=THRESHOLD):
    """Flip-through checks of one registered drawing against its two endpoints."""
    reasons = []
    w, h = drawing.size
    if x < 0 or y < 0 or x + w > canvas[0] or y + h > canvas[1]:
        reasons.append("leaves the runtime canvas")
    ends = [placed(edge["left"]), placed(edge["right"])]
    areas = [solid_area(ends[0][0]), solid_area(drawing), solid_area(ends[1][0])]
    ratio = areas[1] / math.sqrt(max(1, areas[0] * areas[2]))
    if list(check_clip(areas, False, threshold)):
        reasons.append(f"body area x{ratio:.2f} of its endpoints")
    grounds = [ground_of(edge["left"]), ground_of(edge["right"])]
    box = solid_bbox(drawing)
    ground = None if box is None else y + box[3]
    if None not in grounds and ground is not None and abs(grounds[0] - grounds[1]) <= GROUND_SHARED:
        if abs(ground - max(grounds)) > max(4, GROUND_TOLERANCE * h):
            reasons.append(f"feet {ground - max(grounds):+d}px off the shared ground")
    xs = [mass_x(image, ex) for image, ex, _ in ends]
    slack = PLACEMENT_TOLERANCE * canvas[0]
    centre = mass_x(drawing, x)
    if not min(xs) - slack <= centre <= max(xs) + slack:
        reasons.append(f"body centre {centre:.0f}px outside {min(xs):.0f}-{max(xs):.0f}")
    colour = float(np.abs(mean_rgb(drawing) - (mean_rgb(ends[0][0]) + mean_rgb(ends[1][0])) / 2).max())
    if colour > COLOUR_TOLERANCE:
        reasons.append(f"colour drift {colour:.0f}")
    # A copy survives resampling only to within a pixel or two, so compare with
    # a little slack; near-identical endpoints (a settling loop) may look alike.
    mine = canvas_mask(drawing, x, y, canvas)
    masks = [canvas_mask(image, ex, ey, canvas) for image, ex, ey in ends]
    if overlap(masks[0], masks[1]) < COPY_IOU:
        for theirs, side in zip(masks, ["earlier", "later"]):
            if overlap(mine, theirs) >= COPY_IOU:
                reasons.append(f"copies the {side} pose")
    metrics = dict(solid_area=areas, area_ratio=round(ratio, 3), ground=ground, centre_x=round(centre, 1), colour_drift=round(colour, 1))
    return reasons, metrics


def register(job, image_path, *, stable_affine=False):
    sheet, fit = to_sheet(image_path, stable_affine=stable_affine)
    k, canvas = job["scale"], job["canvas"]
    results = []
    for slot, edge in enumerate(job["edges"]):
        found, problem = figure_in(sheet, slot)
        row = dict(animation=edge["animation"], after=edge["after"], slot=slot)
        if found is None:
            results.append(row | dict(accepted=False, reasons=[problem]))
            continue
        figure, sx, sy = found
        ox, oy = canvas_origin(slot, canvas, k)
        size = (max(1, round(figure.width / k)), max(1, round(figure.height / k)))
        drawing = figure.resize(size, Image.Resampling.LANCZOS)
        x, y = round((sx - ox) / k), round((sy - oy) / k)
        reasons, metrics = inspect(drawing, x, y, edge, canvas)
        results.append(row | dict(accepted=not reasons, reasons=reasons, metrics=metrics, margin_xy=[x, y], image=drawing))
    return results, fit


def deliver(job_id, image_path, generator="built-in image_gen", prompt=None):
    kind = job_id.split("__")[0]
    spec = load_spec(kind)
    job = next((j for j in spec["jobs"] if j["id"] == job_id), None)
    if job is None:
        raise ValueError(f"unknown job {job_id}")
    raw = Path(image_path).read_bytes()
    digest = sha256(raw).hexdigest()
    source = ROOT / job["source"]
    source.parent.mkdir(parents=True, exist_ok=True)
    attempt = len(job.get("attempts", [])) + 1
    stored = source.with_name(f"{job_id}__try{attempt:02}.png")
    stored.write_bytes(raw)
    try:
        results, fit = register(job, stored)
    except ValueError as error:
        job.setdefault("attempts", []).append(dict(source=rel(stored), sha256=digest, generator=generator, prompt=prompt or job["prompt"], error=str(error)))
        write(spec_path(kind), spec)
        print(f"DELIVERY_REJECTED {job_id}: {error}")
        return 1
    accepted_dir = REQUEST / "accepted" / kind
    rows = []
    for row in results:
        image = row.pop("image", None)
        if row["accepted"]:
            path = accepted_dir / f"{row['animation']}__{row['after']:03}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path)
            row["drawing"] = rel(path)
            row["drawing_sha256"] = sha256(path.read_bytes()).hexdigest()
        rows.append(row)
    job.setdefault("attempts", []).append(dict(source=rel(stored), sha256=digest, generator=generator, prompt=prompt or job["prompt"], **fit, cells=rows))
    accepted = spec.setdefault("accepted", {})
    for row in rows:
        if row["accepted"]:
            accepted[f"{row['animation']}#{row['after']}"] = dict(job=job_id, attempt=attempt, drawing=row["drawing"],
                                                                     sha256=row["drawing_sha256"], margin_xy=row["margin_xy"], metrics=row["metrics"])
    write(spec_path(kind), spec)
    good = sum(row["accepted"] for row in rows)
    for row in rows:
        if not row["accepted"]:
            print(f"REJECTED {job_id} {row['animation']}[{row['after']}]: {'; '.join(row['reasons'])}")
    print(f"DELIVERY {job_id} attempt={attempt} accepted={good}/{len(rows)}")
    return 0


def pending(kind):
    spec = load_spec(kind)
    accepted = spec.get("accepted", {})
    planned = {(e["animation"], e["after"]) for j in spec["jobs"] for e in j["edges"]}
    return sorted(edge for edge in planned if f"{edge[0]}#{edge[1]}" not in accepted)


def retry(kind):
    spec = load_spec(kind)
    tried = {(e["animation"], e["after"]) for j in spec["jobs"] if j.get("attempts") for e in j["edges"]}
    todo = [edge for edge in pending(kind) if edge in tried]
    if not todo:
        print(f"{kind}: no rejected transitions to replan")
        return []
    batch = f"retry{sum(j['id'].startswith(kind + '__retry') for j in spec['jobs']) + 1:02}"
    return prepare(kind, batch=batch, edges_filter=set(todo))


# ---------------------------------------------------------------- build

def replacement_offset(kind, spec, manifest):
    """Map baseline coordinates into v8's symmetrically padded canvas."""
    delta = [new - old for new, old in zip(manifest["canvas"], spec["canvas"])]
    if any(value < 0 or value % 2 for value in delta):
        raise ValueError(f"{kind}: v8 canvas is not symmetric integer padding of the planned canvas")
    offset = [value // 2 for value in delta]
    jobs = {job["id"]: job for job in spec["jobs"]}
    clips = clips_of(manifest)
    for key, row in spec.get("accepted", {}).items():
        name, after = key.rsplit("#", 1)
        after = int(after)
        job = jobs[row["job"]]
        source = next(edge["left"] for edge in job["edges"]
                      if edge["animation"] == name and edge["after"] == after)
        frames = clips.get(name, {}).get("frames", [])
        expected_margin = [source["margin"][0] + offset[0], source["margin"][1] + offset[1],
                           source["margin"][2] + delta[0], source["margin"][3] + delta[1]]
        if (2 * after + 1 >= len(frames) or frames[2 * after].get("atlas") != source["atlas"]
                or frames[2 * after].get("region") != source["region"]
                or frames[2 * after].get("margin") != expected_margin):
            raise ValueError(f"{kind}: {name}[{after}] original pose differs from the planned onion reference")
    return offset


def build(kind, over=None, check=False):
    spec = load_spec(kind)
    accepted = spec.get("accepted", {})
    folder = CREATURES / kind
    if over:
        base_path = folder / over
        if over not in DOUBLED_LAYERS:
            raise ValueError(f"--over must be one of {DOUBLED_LAYERS}")
    else:
        base_path = first_layer(kind, BASELINE_LAYERS)
    manifest = read(base_path)
    canvas = manifest["canvas"]
    offset = replacement_offset(kind, spec, manifest) if over else [0, 0]
    drawings = {}
    for key, row in accepted.items():
        path = ROOT / row["drawing"]
        if sha256(path.read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError(f"{kind}: accepted drawing changed: {row['drawing']}")
        name, after = key.rsplit("#", 1)
        with Image.open(path) as image:
            drawings[(name, int(after))] = (image.convert("RGBA"),
                                          [value + shift for value, shift in zip(row["margin_xy"], offset)])
    pages, frames = pack(kind, drawings, canvas)
    used = set()
    for name, clip in clips_of(manifest).items():
        old = clip["frames"]
        if over:
            for (clip_name, after), frame in frames.items():
                if clip_name == name and 2 * after + 1 < len(old):
                    old[2 * after + 1] = frame
                    used.add((clip_name, after))
        elif all((name, i) in frames for i in range(len(old))):
            clip["frames"] = [f for i, frame in enumerate(old) for f in (frame, frames[(name, i)])]
            clip["fps"] = clip["fps"] * 2
            used.update((name, i) for i in range(len(old)))
    unused = sorted(set(frames) - used)
    manifest["onion_record"] = dict(base=base_path.name, spec=rel(spec_path(kind)), drawings=len(used),
                                    coordinate_shift=offset,
                                    waiting=[f"{n}#{a}" for n, a in unused])
    outputs = [(folder / LAYER, manifest)] + [(folder / f"motion_onion_{i:02}.png", page) for i, page in enumerate(pages)]
    for path, data in outputs:
        if check:
            if isinstance(data, dict):
                if not path.exists() or read(path) != data:
                    raise ValueError(f"{kind}: stale {path.name}")
            else:
                with Image.open(path) as current:
                    if current.convert("RGBA").tobytes() != data.tobytes():
                        raise ValueError(f"{kind}: stale {path.name}")
        elif isinstance(data, dict):
            write(path, data)
        else:
            data.save(path)
    print(json.dumps(dict(kind=kind, base=base_path.name, drawings=len(used), waiting=len(unused), pages=len(pages), check=check)))
    return manifest


def pack(kind, drawings, canvas):
    pages, frames = [], {}
    page = Image.new("RGBA", (2048, 2048))
    x = y = row_h = 0
    for key in sorted(drawings):
        image, (mx, my) = drawings[key]
        w, h = image.size
        if x + w + 4 > 2048:
            x, y, row_h = 0, y + row_h + 4, 0
        if y + h + 4 > 2048:
            pages.append(page.crop((0, 0, 2048, y)))
            page = Image.new("RGBA", (2048, 2048))
            x = y = row_h = 0
        page.alpha_composite(image, (x + 2, y + 2))
        frames[key] = dict(atlas=f"res://assets/sprites/original_creatures/{kind}/motion_onion_{len(pages):02}.png",
                           region=[x + 2, y + 2, w, h], margin=[mx, my, canvas[0] - w, canvas[1] - h])
        x += w + 4
        row_h = max(row_h, h + 4)
    if frames and page.getbbox():
        pages.append(page.crop((0, 0, 2048, min(2048, y + row_h))))
    return pages, frames


def check_all():
    kinds = sorted(p.parent.name for p in CREATURES.glob(f"*/{LAYER}"))
    for kind in kinds:
        base = read(CREATURES / kind / LAYER).get("onion_record", {}).get("base")
        build(kind, base if base in DOUBLED_LAYERS else None, check=True)
    print(f"MOTION_ONION_CHECK layers={len(kinds)}")


# ---------------------------------------------------------------- preview

def preview(kind, animation, layer=None, out=None):
    path = CREATURES / kind / layer if layer else first_layer(kind, [LAYER] + DOUBLED_LAYERS + BASELINE_LAYERS)
    manifest = read(path)
    clip = clips_of(manifest)[animation]
    canvas = manifest["canvas"]
    frames = []
    for frame in clip["frames"]:
        board = Image.new("RGBA", canvas, (36, 46, 52, 255))
        image, x, y = placed(frame)
        board.alpha_composite(image, (x, y))
        if "motion_onion_" in frame["atlas"]:
            ImageDraw.Draw(board).rectangle((0, 0, canvas[0] - 1, canvas[1] - 1), outline=(240, 120, 30, 255), width=2)
        frames.append(board.convert("RGB"))
    out = Path(out) if out else REQUEST / "previews" / kind / f"{animation}.gif"
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=round(1000 / clip["fps"]), loop=0)
    strip = Image.new("RGB", (canvas[0] * len(frames), canvas[1]))
    for i, frame in enumerate(frames):
        strip.paste(frame, (i * canvas[0], 0))
    strip.save(out.with_suffix(".png"))
    print(f"PREVIEW {rel(out)} frames={len(frames)} layer={path.name}")
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare"); p.add_argument("--kind", required=True); p.add_argument("--animation"); p.add_argument("--batch")
    p = sub.add_parser("deliver"); p.add_argument("--job", required=True); p.add_argument("--image", type=Path, required=True)
    p.add_argument("--generator", default="built-in image_gen"); p.add_argument("--prompt")
    p = sub.add_parser("retry"); p.add_argument("--kind", required=True)
    p = sub.add_parser("build"); p.add_argument("--kind", required=True); p.add_argument("--over"); p.add_argument("--check", action="store_true")
    p = sub.add_parser("preview"); p.add_argument("--kind", required=True); p.add_argument("--animation", required=True)
    p.add_argument("--layer"); p.add_argument("--out", type=Path)
    sub.add_parser("check")
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.kind, args.animation, args.batch)
    elif args.command == "deliver":
        return deliver(args.job, args.image, args.generator, args.prompt)
    elif args.command == "retry":
        retry(args.kind)
    elif args.command == "build":
        build(args.kind, args.over, args.check)
    elif args.command == "check":
        check_all()
    else:
        preview(args.kind, args.animation, args.layer, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

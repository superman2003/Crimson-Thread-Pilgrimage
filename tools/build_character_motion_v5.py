#!/usr/bin/env python3
"""Register the character motion v5 source sheets (art_requests/character_motion_v5).

Each delivered sheet is cut by its grid (every cel is a complete, separated
silhouette; validate_incoming.py checks that) and written into the character's
motion_generation.json runtime_frames. tools/build_expanded_character_motion.py
then packs the pixels; the runtime never loads the sheets.

  E  boss phase strike      replaces the 4 `phase` cels that duplicated `attack`
  F  boss move bridge       new `<move>_bridge` (2 cels) played before the shared
                            `recover`; `<move>_settle` when the drawn bridge
                            already ends standing, so it goes straight to idle
  G  regular creature fix   replaces wind-up/strike cels, or prepends 2 cels to
                            the shared `recover`
  H  clipped single frame   replaces that one cel

Calibration, against the character's runtime poses as they were before this
batch (the record keeps the replaced entries, so rebuilds restore them first):

  scale   sqrt(alpha-area) ratio of matched pose pairs; a pair disagreeing by
          more than SCALE_AGREEMENT with the others falls back to the pair
          marked primary (the cel drawn to equal an existing pose)
  anchor  alpha-mass column median offset by the matched pose's
          median-to-rig-origin distance (see build_creature_attack_motion.py)
  grade   one HSV saturation gain plus one gain per RGB channel per sheet,
          matching the mean of the poses the cels stand next to; the generator
          drew these sheets more saturated, some with a hue cast

Calibration is computed once per sheet checksum and stored; --check verifies the
stored record and never recomputes. To recalibrate a re-delivered sheet: --undo,
repack (build_expanded_character_motion.py), then run this tool again.
"""
from __future__ import annotations
import argparse
import colorsys
from hashlib import sha256
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / "art_requests/character_motion_v5"
INCOMING = REQUEST / "incoming"
SPRITES = ROOT / "godot/assets/sprites"
RECORD_KEY = "character_motion_v5"
SCALE_AGREEMENT = 0.15
MIN_COMPONENT = 20
E_BOSSES = ["broken_string_gardener", "rust_crown_guardian", "saltwhite_contract_judge", "sunken_hammer_smith"]
ALL_BOSSES = E_BOSSES + ["silent_crown_core", "silent_pilgrim_commander"]
# The root bishop's heavy and phase bridges end upright; its shared recovery
# starts crouched, so these two settle straight into idle instead.
SETTLE = {("broken_string_gardener", "heavy"), ("broken_string_gardener", "phase")}


def plan() -> list[dict]:
    sheets = []
    for boss in E_BOSSES:
        sheets.append({"image": f"E_phase_{boss}.png", "folder": f"original_creatures/{boss}", "grid": (2, 2),
                       "op": "replace_animation", "animation": "phase",
                       "match": [("median", "phase")], "anchor": "phase", "grade_from": ["phase_windup"]})
    for boss in ALL_BOSSES:
        for move in ("heavy", "cast", "phase"):
            name = f"{move}_settle" if (boss, move) in SETTLE else f"{move}_bridge"
            # The four E bosses' phase now ends on the new strike, so only the
            # recovery end calibrates their phase bridge.
            pairs = [(0, (move, -1)), (1, ("recover", 0))] if not (move == "phase" and boss in E_BOSSES) else [(1, ("recover", 0))]
            sheets.append({"image": f"F_recover_{boss}_{move}.png", "folder": f"original_creatures/{boss}", "grid": (2, 1),
                           "op": "new_animation", "animation": name, "pairs": pairs, "primary": ("recover", 0),
                           "scale_from": "primary"})
    creature = "original_creatures/"
    sheets += [
        {"image": "G_ash_banner_imp_attack0.png", "folder": creature + "ash_banner_imp", "grid": (1, 1),
         "op": "replace_frames", "animation": "attack", "indices": [0], "pairs": [(0, ("attack", 0))], "primary": ("attack", 0)},
        {"image": "G_ash_banner_imp_windup.png", "folder": creature + "ash_banner_imp", "grid": (2, 2),
         "op": "replace_animation", "animation": "windup", "pairs": [(0, ("idle", 0))], "primary": ("idle", 0)},
        {"image": "G_ash_banner_imp_recover.png", "folder": creature + "ash_banner_imp", "grid": (2, 1),
         "op": "prepend_frames", "animation": "recover", "pairs": [(0, ("attack", 3)), (1, ("recover", 0))], "primary": ("recover", 0)},
        {"image": "G_echo_contract_scribe_attack3.png", "folder": creature + "echo_contract_scribe", "grid": (1, 1),
         "op": "replace_frames", "animation": "attack", "indices": [3], "pairs": [(0, ("attack", 0))], "primary": ("attack", 0)},
        {"image": "G_wax_lancer_recover.png", "folder": creature + "wax_lancer", "grid": (2, 1),
         "op": "prepend_frames", "animation": "recover", "pairs": [(0, ("attack", 3)), (1, ("recover", 0))], "primary": ("recover", 0)},
    ]
    for image, folder, animation, index in [
            ("H_broken_string_gardener_death3.png", creature + "broken_string_gardener", "death", 3),
            ("H_delayed_shadow_recover0.png", creature + "delayed_shadow", "recover", 0),
            ("H_pipe_thrower_hurt2.png", creature + "pipe_thrower", "hurt", 2),
            ("H_npc_blind_bell_knight_talk3.png", "original_npcs/npc_blind_bell_knight", "talk", 3),
            ("H_npc_deserter_flagbearer_talk6.png", "original_npcs/npc_deserter_flagbearer", "talk", 6)]:
        # The clipped original lost a little silhouette, so its neighbours in the
        # same animation also size the redrawn cel.
        neighbours = [(0, (animation, i)) for i in (index - 1, index + 1) if i >= 0]
        sheets.append({"image": image, "folder": folder, "grid": (1, 1), "op": "replace_frames", "animation": animation,
                       "indices": [index], "pairs": [(0, (animation, index))] + neighbours, "primary": (animation, index)})
    return sheets


def measure(cel: np.ndarray) -> dict:
    alpha = cel[:, :, 3] > 24
    columns = alpha.sum(axis=0).cumsum()
    median_x = float(np.searchsorted(columns, columns[-1] / 2.0)) + 0.5
    rgb = cel[:, :, :3][cel[:, :, 3] > 200].astype(np.float64) / 255.0
    step = max(1, len(rgb) // 6000)
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb[::step]])
    return {"area": int(alpha.sum()), "median_x": median_x, "saturation": float(hsv[:, 1].mean()), "rgb": rgb.mean(axis=0) * 255.0}


def graded_mean(cel: np.ndarray, saturation: float) -> np.ndarray:
    """Mean opaque RGB after the packer's saturation gain (same conversion path)."""
    image = Image.fromarray(cel, "RGBA")
    hsv = np.asarray(image.convert("RGB").convert("HSV")).astype(np.float32)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * saturation, 0, 255)
    rgb = np.asarray(Image.fromarray(np.round(hsv).astype(np.uint8), "HSV").convert("RGB")).astype(np.float64)
    return rgb[cel[:, :, 3] > 200].mean(axis=0)


def existing_poses(folder: Path) -> dict:
    manifest = json.loads((folder / "motion_manifest.json").read_text())
    half = manifest["canvas"][0] / 2.0
    atlases, poses = {}, {}
    for animation in manifest["animations"]:
        entries = []
        for frame in animation["frames"]:
            path = ROOT / "godot" / frame["atlas"].removeprefix("res://")
            if path not in atlases:
                atlases[path] = np.asarray(Image.open(path).convert("RGBA"))
            x, y, w, h = frame["region"]
            stats = measure(atlases[path][y:y + h, x:x + w])
            stats["anchor_offset"] = stats["median_x"] - (half - frame["margin"][0])
            entries.append(stats)
        poses[animation["name"]] = entries
    return poses


def cut(sheet: Path, grid: tuple[int, int]) -> list[dict]:
    rgba = np.asarray(Image.open(sheet).convert("RGBA"))
    labels, count = ndimage.label(rgba[:, :, 3] > 24, structure=np.ones((3, 3)))
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
    cols, rows = grid
    cw, ch = rgba.shape[1] // cols, rgba.shape[0] // rows
    cels = []
    for r in range(rows):
        for c in range(cols):
            x, y = c * cw, r * ch
            window = labels[y:y + ch, x:x + cw]
            seeds = []
            for label in np.unique(window):
                if label == 0 or sizes[label - 1] < MIN_COMPONENT:
                    continue
                ys, xs = np.nonzero(labels == label)
                if xs.min() < x or ys.min() < y or xs.max() >= x + cw or ys.max() >= y + ch:
                    raise ValueError(f"{sheet.name}: a silhouette crosses cel {len(cels) + 1}")
                seeds.append([int(xs[0]), int(ys[0])])
            if not seeds:
                raise ValueError(f"{sheet.name}: cel {len(cels) + 1} is empty")
            cel = rgba[y:y + ch, x:x + cw].copy()
            cel[~np.isin(window, [labels[sy, sx] for sx, sy in seeds])] = 0
            cels.append({"region": [x, y, cw, ch], "seeds": seeds, "pixels": cel})
    return cels


def calibrate(item: dict, cels: list[dict], poses: dict) -> dict:
    stats = [measure(c["pixels"]) for c in cels]
    if item.get("match"):
        # A new strike has no same-pose counterpart: match the median area of the
        # cels it replaces (similar silhouettes) and keep their mean rig offset.
        old = poses[item["anchor"]]
        old_area = float(np.median([p["area"] for p in old]))
        new_area = float(np.median([s["area"] for s in stats]))
        scale = math.sqrt(old_area / new_area)
        offsets = [float(np.mean([p["anchor_offset"] for p in old]))] * len(cels)
        basis = {"method": "median area of replaced cels", "ratio": round(scale, 4)}
    else:
        ratios = {}
        pairs = [(i, (a, f)) for i, (a, f) in item["pairs"] if -len(poses[a]) <= f < len(poses[a])]
        for index, (animation, frame) in pairs:
            ratios[(animation, frame)] = math.sqrt(poses[animation][frame]["area"] / stats[index]["area"])
        primary = ratios[item["primary"]]
        # A bridge must match the shared recovery it hands over to; the attack end
        # only places the anchor (some bosses' last attack cels are drawn smaller).
        agree = item.get("scale_from") != "primary" and all(abs(r / primary - 1.0) <= SCALE_AGREEMENT for r in ratios.values())
        scale = float(np.exp(np.mean(np.log(list(ratios.values()))))) if agree else primary
        by_cel = {}
        for index, (a, f) in pairs:
            by_cel.setdefault(index, poses[a][f]["anchor_offset"])  # the first pair of a cel places it
        fallback = float(np.mean(list(by_cel.values())))
        offsets = [by_cel.get(i, fallback) for i in range(len(cels))]
        basis = {"method": "matched poses" if agree else "primary matched pose",
                 "ratios": {f"{a}[{f}]": round(r, 4) for (a, f), r in ratios.items()}}
    # Colour is matched against the poses these cels stand next to: the matched
    # poses plus whatever cels they replace or extend (and a strike's wind-up).
    names = set(item.get("grade_from", []))
    if item["op"] in ("replace_animation", "replace_frames", "prepend_frames"):
        names.add(item["animation"])
    reference = [p for name in sorted(names) for p in poses[name]]
    reference += [poses[a][f] for _, (a, f) in item.get("pairs", []) if -len(poses[a]) <= f < len(poses[a])]
    saturation = min(1.15, max(0.6, float(np.mean([p["saturation"] for p in reference])) / float(np.mean([s["saturation"] for s in stats]))))
    graded = [graded_mean(c["pixels"], saturation) for c in cels]
    target = np.mean([p["rgb"] for p in reference], axis=0)
    rgb = [round(min(1.2, max(0.8, float(t / g))), 3) for t, g in zip(target, np.mean(graded, axis=0))]
    grade = {"saturation": round(saturation, 3), "rgb": rgb}
    anchors = [round(s["median_x"] - o / scale, 1) for s, o in zip(stats, offsets)]
    return {"scale": round(scale, 4), "anchors": anchors, "grade": grade, "calibration": basis}


def restore(runtime: dict, previous: dict) -> None:
    """Undo a previous registration so the batch can be applied again."""
    for change in reversed(previous.get("changes", [])):
        animation = change["animation"]
        if change["op"] == "new_animation":
            runtime.pop(animation, None)
        elif change["op"] == "prepend_frames":
            del runtime[animation][:change["count"]]
        else:
            for index, entry in change["replaced"].items():
                if index == "all":
                    runtime[animation] = entry
                else:
                    runtime[animation][int(index)] = entry


def apply(runtime: dict, item: dict, entries: list[dict]) -> dict:
    animation = item["animation"]
    change = {"image": item["image"], "op": item["op"], "animation": animation}
    if item["op"] == "new_animation":
        if animation in runtime:
            raise ValueError(f"{item['folder']}/{animation}: already registered")
        runtime[animation] = entries
    elif item["op"] == "replace_animation":
        change["replaced"] = {"all": runtime[animation]}
        runtime[animation] = entries
    elif item["op"] == "prepend_frames":
        runtime[animation] = entries + runtime[animation]
        change["count"] = len(entries)
    else:
        change["replaced"] = {}
        for index, entry in zip(item["indices"], entries):
            change["replaced"][str(index)] = runtime[animation][index]
            runtime[animation][index] = entry
    return change


def undo(folder: Path) -> None:
    record_path = folder / "motion_generation.json"
    record = json.loads(record_path.read_text())
    restore(record["runtime_frames"], record.pop(RECORD_KEY, {}))
    record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")


def register(folder: Path, items: list[dict], check: bool) -> dict:
    record_path = folder / "motion_generation.json"
    record = json.loads(record_path.read_text())
    runtime = record["runtime_frames"]
    previous = record.get(RECORD_KEY, {})
    stored = {s["image"]: s for s in previous.get("sheets", [])}
    restore(runtime, previous)
    poses = None
    sheets, changes = [], []
    delivery = {a["name"]: a for a in json.loads((INCOMING / "delivery_manifest.json").read_text())["assets"]}
    for item in items:
        path = INCOMING / item["image"]
        digest = sha256(path.read_bytes()).hexdigest()
        if digest != delivery[item["image"]]["sha256"]:
            raise ValueError(f"{item['image']}: bytes differ from the delivery manifest")
        cels = cut(path, item["grid"])
        if digest == stored.get(item["image"], {}).get("image_sha256"):
            values = {k: stored[item["image"]][k] for k in ("scale", "anchors", "grade", "calibration")}
        elif check:
            raise ValueError(f"{folder.name}: {item['image']} is not registered; rebuild")
        else:
            if previous:
                # The packed manifest still holds this batch; calibrating against it
                # would measure the new cels against themselves.
                raise ValueError(f"{folder.name}: {item['image']} changed; run --undo, repack, then rebuild")
            if poses is None:
                poses = existing_poses(folder)
            values = calibrate(item, cels, poses)
        entries = [{"source": str(path.relative_to(ROOT)), "region": cel["region"], "component_seeds": cel["seeds"],
                    "scale": values["scale"], "anchor_x": anchor, "grade": values["grade"]}
                   for cel, anchor in zip(cels, values["anchors"])]
        changes.append(apply(runtime, item, entries))
        sheets.append({"image": item["image"], "image_sha256": digest, "op": item["op"], "animation": item["animation"], **values})
    record[RECORD_KEY] = {"brief": "art_requests/character_motion_v5/README.md", "tool": "tools/build_character_motion_v5.py",
                          "sheets": sheets, "changes": changes}
    encoded = json.dumps(record, ensure_ascii=False, indent=2) + "\n"
    if check:
        if record_path.read_text() != encoded:
            raise ValueError(f"{folder.name}: v5 registration differs; rebuild")
    else:
        record_path.write_text(encoded)
    return {"character": folder.name, "sheets": [s["image"] for s in sheets],
            "scales": {s["image"]: s["scale"] for s in sheets}, "grades": {s["image"]: s["grade"] for s in sheets}}


def verify_phase_strikes() -> list[str]:
    """The batch's reason to exist: no boss phase cel may repeat an attack cel."""
    for boss in E_BOSSES:
        folder = SPRITES / "original_creatures" / boss
        manifest = json.loads((folder / "motion_manifest.json").read_text())
        atlases, digests = {}, {}
        for animation in manifest["animations"]:
            if animation["name"] not in ("attack", "phase"):
                continue
            for frame in animation["frames"]:
                path = ROOT / "godot" / frame["atlas"].removeprefix("res://")
                atlases.setdefault(path, Image.open(path).convert("RGBA"))
                x, y, w, h = frame["region"]
                digests.setdefault(animation["name"], set()).add(sha256(atlases[path].crop((x, y, x + w, y + h)).tobytes()).hexdigest())
        if len(digests["phase"]) != 4 or digests["phase"] & digests["attack"]:
            raise ValueError(f"{boss}: phase strike still repeats attack cels")
    return E_BOSSES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--undo", action="store_true", help="restore the pre-v5 runtime frames (repack afterwards)")
    args = parser.parse_args()
    items = plan()
    delivered = {p.name for p in INCOMING.glob("*.png")}
    if {i["image"] for i in items} != delivered:
        raise ValueError(f"plan and delivery differ: {sorted({i['image'] for i in items} ^ delivered)}")
    by_folder: dict[str, list] = {}
    for item in items:
        by_folder.setdefault(item["folder"], []).append(item)
    if args.undo:
        for folder in sorted(by_folder):
            undo(SPRITES / folder)
        print(json.dumps({"undone": sorted(by_folder)}, indent=2))
        return
    results = [register(SPRITES / folder, group, args.check) for folder, group in sorted(by_folder.items())]
    verified = verify_phase_strikes() if args.check else []
    print(json.dumps({"characters": len(results), "sheets": sum(len(r["sheets"]) for r in results),
                      "distinct_phase_strikes": verified, "coverage": results},
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

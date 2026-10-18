#!/usr/bin/env python3
"""Register the creature attack source sheets (art_requests/creature_attacks_v1).

Each delivered sheet is split by its own reviewed regions/component seeds and
mapped to animations by the same cel plan the briefs were written from:

  new / elite attack <id>.png  -> <id>_windup, <id>, <id>_recover, <id>_charge, <id>_travel
  kept attack <id>_loops.png   -> charge, travel (the species' generic attack keeps them)

Only registration is computed here; tools/build_expanded_character_motion.py
packs the pixels. The source sheets differ in canvas resolution, so each sheet
gets one packaging scale and every cel one horizontal anchor, both calibrated
against the species' existing runtime poses:

  scale   sqrt(alpha area) ratio of a matched pose pair. Attack sheets match
          their last recovery cel (drawn as "returns to the idle stance") and
          their first wind-up cel against the first idle pose; loop sheets
          match against the existing pose they continue from (last wind-up for
          charge, second strike for travel). Area rather than bounding box,
          so weapons, lifted arms and crouches do not drift the body size.
  anchor  alpha-mass column median (thin weapons barely move it), offset by
          the same median-to-rig-origin distance the matched existing pose has.
          Attacks that move the actor already move it in game, so the body
          stays on the rig origin instead of drifting inside the canvas.

The feet baseline is the shared rule of the packer (bottom of each silhouette).
"""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT / "art_requests/creature_attacks_v1"
INCOMING = REQUEST / "incoming"
CREATURES = ROOT / "godot/assets/sprites/original_creatures"
sys.path.insert(0, str(REQUEST))
from design import DESIGN, ELITE  # noqa: E402
import build_docs as BRIEF  # noqa: E402

RECORD_KEY = "attack_motion_v1"
SECTION = {"wind-up": "_windup", "strike": "", "recovery": "_recover", "charge loop": "_charge", "travel loop": "_travel"}
# Two calibration poses that disagree by more than this fall back to the recovery cel.
SCALE_AGREEMENT = 0.12


def sheet_plan(kind: str, image: str):
    stem = image.removesuffix(".png")
    if stem.endswith("_loops"):
        keep = BRIEF.attack(kind, DESIGN[kind]["keep"])
        if stem != keep["id"] + "_loops":
            raise ValueError(f"{image}: loops sheet is not for kept attack {keep['id']}")
        return "keep", "", [(en, 2) for _, en, _, _ in BRIEF.loops_section(kind, keep, DESIGN[kind])]
    item = BRIEF.attack(kind, stem)
    if DESIGN[kind]["new"] == stem:
        role, beats = "new", DESIGN[kind]
    elif ELITE.get(kind, {}).get("id") == stem:
        role, beats = "elite", ELITE[kind]
    else:
        raise ValueError(f"{image}: not a briefed attack of {kind}")
    strike = 6 if item["type"] == "combo" else 4
    return role, stem, [(en, count) for _, en, _, count in BRIEF.cel_plan(beats, item, strike)]


def isolated_cels(sheet: Path, frames: list) -> list:
    rgba = np.asarray(Image.open(sheet).convert("RGBA"))
    labels, _ = ndimage.label(rgba[:, :, 3] > 24, structure=np.ones((3, 3)))
    cels = []
    for frame in frames:
        x, y, w, h = frame["region"]
        sx, sy = frame["component_seed"]
        label = labels[sy, sx]
        if label == 0:
            raise ValueError(f"{sheet.name} cel {frame['cel']}: seed misses visible ink")
        cel = rgba[y:y + h, x:x + w].copy()
        cel[labels[y:y + h, x:x + w] != label] = 0
        cels.append(cel)
    return cels


def measure(cel: np.ndarray) -> dict:
    alpha = cel[:, :, 3] > 24
    ys, xs = np.nonzero(alpha)
    columns = alpha.sum(axis=0).cumsum()
    median_x = float(np.searchsorted(columns, columns[-1] / 2.0)) + 0.5
    return {"area": int(alpha.sum()), "left": int(xs.min()), "median_x": median_x, "height": int(ys.max() - ys.min() + 1)}


def existing_poses(kind: str) -> dict:
    manifest = json.loads((CREATURES / kind / "motion_manifest.json").read_text())
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
            # Pose-local rig origin: the packer centres the canvas on it.
            stats["anchor_offset"] = stats["median_x"] - (half - frame["margin"][0])
            entries.append(stats)
        poses[animation["name"]] = entries
    return poses


def calibrate(role: str, plan: list, cels: list, poses: dict) -> tuple[float, list, dict]:
    stats = [measure(cel) for cel in cels]
    if role == "keep":
        refs, index = [], 0
        for section, count in plan:
            ref = poses["windup"][-1] if section == "charge loop" else poses["attack"][1]
            refs += [ref] * count
            index += count
        ratios = [math.sqrt(ref["area"] / s["area"]) for ref, s in zip(refs, stats)]
        scale = float(np.exp(np.mean(np.log(ratios))))
        offsets = [ref["anchor_offset"] for ref in refs]
        basis = {"method": "matched continued pose", "ratios": [round(r, 4) for r in ratios]}
    else:
        idle = poses["idle"][0]
        last_recover = sum(count for _, count in plan[:3]) - 1
        first = math.sqrt(idle["area"] / stats[0]["area"])
        last = math.sqrt(idle["area"] / stats[last_recover]["area"])
        agree = abs(first / last - 1.0) <= SCALE_AGREEMENT
        scale = math.sqrt(first * last) if agree else last
        offset = float(np.mean([p["anchor_offset"] for p in poses["idle"]]))
        offsets = [offset] * len(cels)
        basis = {"method": "idle stance" if agree else "recovery idle stance", "first_windup_ratio": round(first, 4), "last_recover_ratio": round(last, 4)}
    anchors = [s["median_x"] - offset / scale for s, offset in zip(stats, offsets)]
    return scale, anchors, basis


def register(kind: str, sheets: list, check: bool) -> dict:
    folder = CREATURES / kind
    record_path = folder / "motion_generation.json"
    record = json.loads(record_path.read_text())
    runtime = record["runtime_frames"]
    previous = record.get(RECORD_KEY, {})
    for name in previous.get("animations", []):
        runtime.pop(name, None)
    poses = existing_poses(kind) if not check else None
    added, sources = [], []
    for data in sheets:
        sheet = INCOMING / data["image"]
        role, attack_id, plan = sheet_plan(kind, data["image"])
        if sum(count for _, count in plan) != len(data["frames"]):
            raise ValueError(f"{data['image']}: {len(data['frames'])} cels, plan needs {sum(c for _, c in plan)}")
        digest = sha256(sheet.read_bytes()).hexdigest()
        if digest != data["image_sha256"]:
            raise ValueError(f"{data['image']}: bytes differ from the delivery record")
        if check:
            source = next(s for s in previous["sheets"] if s["image"] == data["image"])
            scale, anchors, basis = source["scale"], source["anchors"], source["calibration"]
        else:
            scale, anchors, basis = calibrate(role, plan, isolated_cels(sheet, data["frames"]), poses)
            scale = round(scale, 4)
            anchors = [round(a, 1) for a in anchors]
        index = 0
        for section, count in plan:
            name = (attack_id + SECTION[section]) if attack_id else SECTION[section].lstrip("_")
            if name in runtime:
                raise ValueError(f"{kind}/{name}: already registered")
            runtime[name] = [
                {"source": str(sheet.relative_to(ROOT)), "region": data["frames"][index + i]["region"],
                 "component_seeds": [data["frames"][index + i]["component_seed"]], "scale": scale, "anchor_x": anchors[index + i]}
                for i in range(count)]
            added.append(name)
            index += count
        sources.append({"image": data["image"], "image_sha256": digest, "role": role, "attack": attack_id or DESIGN[kind]["keep"],
                        "plan": [[section, count] for section, count in plan], "scale": scale, "anchors": anchors, "calibration": basis})
    record[RECORD_KEY] = {"brief": "art_requests/creature_attacks_v1/" + kind + ".md", "tool": "tools/build_creature_attack_motion.py",
                          "animations": added, "sheets": sources}
    encoded = json.dumps(record, ensure_ascii=False, indent=2) + "\n"
    if check:
        if record_path.read_text() != encoded:
            raise ValueError(f"{kind}: attack registration differs; rebuild")
    else:
        record_path.write_text(encoded)
    return {"kind": kind, "animations": added, "frames": sum(len(runtime[n]) for n in added),
            "scales": {s["image"]: s["scale"] for s in sources}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", action="append")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    by_kind: dict[str, list] = {}
    for path in sorted(INCOMING.glob("*.json")):
        data = json.loads(path.read_text())
        if data.get("schema") != "creature-attack-source-v1":
            continue
        by_kind.setdefault(data["kind"], []).append(data)
    if set(by_kind) != set(DESIGN):
        raise ValueError(f"source sheets missing for {sorted(set(DESIGN) - set(by_kind))}")
    results = [register(kind, sheets, args.check) for kind, sheets in sorted(by_kind.items()) if not args.kind or kind in args.kind]
    print(json.dumps({"kinds": len(results), "sheets": sum(len(r["scales"]) for r in results),
                      "frames": sum(r["frames"] for r in results), "coverage": results}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

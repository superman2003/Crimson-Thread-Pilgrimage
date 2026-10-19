#!/usr/bin/env python3
"""Register reviewed, imagegen-authored poses; never synthesize/interpolate art.

The source manifest and portrait remain immutable. New production sequences live
in motion_manifest.json. Each input region must be explicitly reviewed and listed
in motion_generation.json under runtime_frames: {animation: [{sheet, region}]}.
An entry may instead name a delivered source sheet outside the folder
({source: "art_requests/<batch>/incoming/<sheet>.png", ...}); those poses are
always packed into motion_runtime.png, so the runtime never loads the sheet.
Only atlas coordinates/margins change; source RGBA bytes are never edited.
"""
from __future__ import annotations
import argparse
from collections import Counter
from hashlib import sha256
from io import BytesIO
import json
import math
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "godot/assets/sprites"
MIN_CREATURE = {"idle": 4, "walk": 8, "windup": 4, "attack": 4, "recover": 4, "hurt": 2, "death": 3}
MIN_NPC = {"idle": 4, "talk": 6, "greet": 2, "rest": 2}
SOURCE_ROOTS = (ROOT / "art_requests",)
FPS = {"idle": 8, "walk": 16, "windup": 12, "attack": 18, "recover": 14, "hurt": 16, "death": 10, "talk": 10, "greet": 8, "rest": 4}

def read(path):
    return json.loads(path.read_text())

def looping(name):
    return name in ("idle","walk","talk","charge","travel") or name.endswith("_charge") or name.endswith("_travel")

def sheet_path(folder, entry):
    if "source" in entry:
        path = (ROOT / entry["source"]).resolve()
        if not entry["source"].endswith(".png") or not any(path.is_relative_to(root) and path.parent.name == "incoming" for root in SOURCE_ROOTS):
            raise ValueError(f"unsafe source sheet: {entry['source']}")
        return entry["source"], path
    sheet = entry.get("sheet", "motion_expanded.png")
    if Path(sheet).name != sheet or not sheet.endswith(".png"):
        raise ValueError(f"unsafe sheet: {sheet}")
    return sheet, folder / sheet

def apply_grade(image, saturation, rgb):
    """Uniform colour match for a whole source sheet's palette drift: one HSV
    saturation gain, then one gain per RGB channel (fixes a hue cast too).

    Mechanical colour matching only: alpha, silhouette and every pose are kept."""
    if not 0.5 <= saturation <= 1.5 or len(rgb) != 3 or not all(0.5 <= g <= 1.5 for g in rgb):
        raise ValueError(f"invalid colour grade {saturation}/{rgb}")
    alpha = image.getchannel("A")
    hsv = np.asarray(image.convert("RGB").convert("HSV")).astype(np.float32)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * saturation, 0, 255)
    rgb_pixels = np.asarray(Image.fromarray(np.round(hsv).astype(np.uint8), "HSV").convert("RGB")).astype(np.float32)
    rgb_pixels = np.clip(rgb_pixels * np.asarray(rgb, dtype=np.float32), 0, 255)
    graded = Image.fromarray(np.round(rgb_pixels).astype(np.uint8), "RGB").convert("RGBA")
    graded.putalpha(alpha)
    return graded

def shelf_pack(sizes, max_width):
    """Row-major shelf packing in pose order with a 2px gutter."""
    placements, x, y, shelf, width = [], 0, 0, 0, 0
    for w, h in sizes:
        if x and x + w > max_width:
            x, y, shelf = 0, y + shelf + 2, 0
        placements.append((x, y))
        x += w + 2
        shelf = max(shelf, h)
        width = max(width, x - 2)
    return placements, (width, y + shelf)

def build(folder: Path, check=False):
    source = read(folder / "manifest.json")
    record = read(folder / "motion_generation.json")
    runtime = record.get("runtime_frames", {})
    npc = folder.parent.name == "original_npcs"
    minimums = MIN_NPC if npc else MIN_CREATURE
    for name, minimum in minimums.items():
        if len(runtime.get(name, [])) < minimum:
            raise ValueError(f"{folder.name}/{name}: reviewed poses {len(runtime.get(name, []))} < {minimum}")
    source_animations = {a["name"]: a for a in source["animations"]}
    if not npc:
        for name in source_animations:
            if name not in minimums and len(runtime.get(name, [])) < 4:
                raise ValueError(f"{folder.name}/{name}: missing reviewed special poses")
    images = {}
    ownership = {}
    poses = []
    per_animation = {}
    for name, entries in runtime.items():
        hashes = set()
        per_animation[name] = []
        for entry in entries:
            sheet, path = sheet_path(folder, entry)
            if sheet not in images:
                im = Image.open(path)
                if im.mode != "RGBA" or im.getchannel("A").getextrema()[0] != 0:
                    raise ValueError(f"{folder.name}/{sheet}: genuine RGBA transparency required")
                images[sheet] = im
            im = images[sheet]
            x,y,w,h = map(int, entry["region"])
            if min(x,y) < 0 or min(w,h) <= 0 or x+w > im.width or y+h > im.height:
                raise ValueError(f"{folder.name}/{name}: out-of-bounds region")
            cell = im.crop((x,y,x+w,y+h))
            if entry.get("component_seeds"):
                # A reviewed shape may have an interlocking rectangle with its
                # neighbour despite no actual ink contact. Isolate explicitly
                # seeded visible components, retaining their original RGBA and
                # nearest faint antialias pixels within three source pixels.
                # Disconnected props require additional explicit seeds. Actual
                # merged figures must be redrawn; a seed cannot split them.
                if sheet not in ownership:
                    rgba = np.asarray(im)
                    labels, _ = ndimage.label(rgba[:,:,3] > 24, structure=np.ones((3,3)))
                    distance, nearest = ndimage.distance_transform_edt(labels==0, return_indices=True)
                    nearest_labels = labels[tuple(nearest)]
                    ownership[sheet] = (rgba, labels, distance, nearest_labels)
                rgba, labels, distance, nearest_labels = ownership[sheet]
                ids = []
                for sx, sy in entry["component_seeds"]:
                    label = int(labels[int(sy),int(sx)])
                    if label == 0: raise ValueError(f"{folder.name}/{name}: seed misses visible ink")
                    ids.append(label)
                core = np.isin(labels,ids)
                ys,xs = np.nonzero(core)
                if xs.min()<x or ys.min()<y or xs.max()>=x+w or ys.max()>=y+h:
                    raise ValueError(f"{folder.name}/{name}: seeded full silhouette exceeds region")
                keep = core | ((rgba[:,:,3] <= 24) & (rgba[:,:,3] > 0) & (distance<=3) & np.isin(nearest_labels,ids))
                isolated = rgba[y:y+h,x:x+w].copy()
                isolated[~keep[y:y+h,x:x+w]] = 0
                cell = Image.fromarray(isolated)
            box = cell.getchannel("A").getbbox()
            if not box:
                raise ValueError(f"{folder.name}/{name}: empty pose")
            # The reviewer must provide a complete silhouette, with at least one
            # clear pixel along every cut. Reject hard clipping rather than hide it.
            alpha = np.asarray(cell)[:,:,3]
            if any((edge > 24).any() for edge in (alpha[0], alpha[-1], alpha[:,0], alpha[:,-1])):
                raise ValueError(f"{folder.name}/{name}: content touches reviewed region edge {entry['region']}")
            bx,by,ex,ey = box
            cropped = cell.crop(box)
            digest = sha256(cropped.tobytes()).hexdigest()
            hashes.add(digest)
            # Keep the reviewed cell center as the horizontal rig origin; align
            # the baseline, without changing scale, silhouette or source pixels.
            anchor = float(entry.get("anchor_x", w/2))
            scale = float(entry.get("scale", 1.0))
            if not math.isfinite(scale) or not 0.1 <= scale <= 4.0:
                raise ValueError(f"{folder.name}/{name}: invalid packaging scale {scale}")
            grade = entry.get("grade")
            if grade:
                cropped = apply_grade(cropped, float(grade["saturation"]), [float(g) for g in grade["rgb"]])
            if scale != 1.0:
                cropped = cropped.resize((max(1,round(cropped.width*scale)),max(1,round(cropped.height*scale))),Image.Resampling.LANCZOS)
            pose = {"sheet":sheet, "region":[x+bx,y+by,cropped.width,cropped.height], "left":(bx-anchor)*scale, "height":cropped.height, "hash":digest, "image":cropped, "scale":scale, "isolated":bool(entry.get("component_seeds")) or "source" in entry or bool(grade)}
            poses.append(pose)
            per_animation[name].append(pose)
        if len(hashes) != len(entries):
            raise ValueError(f"{folder.name}/{name}: duplicate visible poses")
    left = min(p["left"] for p in poses)
    right = max(p["left"]+p["region"][2] for p in poses)
    half = int(np.ceil(max(-left,right)))+8
    height = max(p["height"] for p in poses)+16
    canvas = [2*half,height]
    if any(p["scale"] != 1.0 or p["isolated"] for p in poses):
        # Some separately authored action strips have a different resolution.
        # Normalize their entire silhouettes with the reviewer's single scale;
        # this is mechanical crop/resize/packing, never generated in-betweens.
        # Poses are shelf-packed tightly: the margin, not the atlas position,
        # places each one on the rig canvas.
        placements, size = shelf_pack([p["image"].size for p in poses], max(4096, max(p["image"].width for p in poses)))
        atlas = Image.new("RGBA", size)
        for pose, (x, y) in zip(poses, placements):
            atlas.alpha_composite(pose["image"], (x,y))
            pose["sheet"] = "motion_runtime.png"
            pose["region"] = [x,y,pose["image"].width,pose["image"].height]
        buffer = BytesIO()
        atlas.save(buffer,format="PNG")
        path = folder/"motion_runtime.png"
        if check:
            if not path.exists() or Image.open(path).mode != "RGBA" or not np.array_equal(np.asarray(Image.open(path)),np.asarray(atlas)):
                raise ValueError(f"{folder.name}: normalized atlas differs; rebuild")
        else:
            path.write_bytes(buffer.getvalue())
    base_idle = source_animations["idle"]["frames"][0]
    old_height = base_idle["region"][3]
    display_height = old_height * float(source["visual_scale"])
    scale = display_height / per_animation["idle"][0]["height"]
    # Preserve the exact first-frame ground/hover anchor from the old manifest.
    old_margin = base_idle.get("margin", [0,0,0,0])
    old_canvas_h = base_idle["region"][3] + old_margin[3]
    old_bottom = old_margin[1]+old_height-old_canvas_h/2
    old_offset = source.get("visual_offset", [0,0])
    offset = [old_offset[0],old_offset[1]+old_bottom*source["visual_scale"]-(height/2-8)*scale]
    animations=[]
    for name, entries in per_animation.items():
        frames=[]
        for pose in entries:
            _,_,w,h=pose["region"]
            frames.append({"atlas":"res://"+str((folder/pose["sheet"]).relative_to(ROOT/"godot")), "region":pose["region"], "margin":[int(round(half+pose["left"])),height-8-h,canvas[0]-w,height-h]})
        fps = FPS.get(name,12)
        if name in ("idle", "walk"):
            old = source_animations[name]
            fps = len(entries) * float(old["fps"]) / len(old["frames"])
        animations.append({"name":name,"fps":fps,"loop":looping(name),"frames":frames})
    output = {k:v for k,v in source.items() if k not in ("animations","attack_integrity","atlas_size")}
    output.update({"source":"imagegen authored expanded poses; reviewed atlas regions; no interpolation", "version":2,"canvas":canvas,"visual_scale":scale,"visual_offset":offset,"animations":animations,"generation_record":"motion_generation.json"})
    encoded=json.dumps(output,ensure_ascii=False,indent=2)+"\n"
    dest=folder/"motion_manifest.json"
    if check:
        if not dest.exists() or dest.read_text()!=encoded:
            raise ValueError(f"{folder.name}: motion manifest differs; rebuild")
    else:
        dest.write_text(encoded)
    return {"id":folder.name,"family":folder.parent.name,"animations":{k:len(v) for k,v in per_animation.items()},"frames":len(poses),"canvas":canvas,"source_hash":sha256((folder/"manifest.json").read_bytes()).hexdigest()}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character",action="append")
    parser.add_argument("--check",action="store_true")
    parser.add_argument("--all",action="store_true",help="Require every production character")
    args=parser.parse_args()
    results=[]
    for family in ("original_creatures","original_npcs"):
        for folder in sorted((BASE/family).iterdir()):
            if not (folder/"manifest.json").is_file() or (args.character and folder.name not in args.character): continue
            if not (folder/"motion_generation.json").exists():
                if args.all: raise ValueError(f"{folder.name}: missing generation record")
                continue
            results.append(build(folder,args.check))
    print(json.dumps({"characters":len(results),"frames":sum(r["frames"] for r in results),"coverage":results},ensure_ascii=False,indent=2))

if __name__=="__main__": main()

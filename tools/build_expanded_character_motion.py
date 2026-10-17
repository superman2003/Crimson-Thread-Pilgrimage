#!/usr/bin/env python3
"""Register reviewed, imagegen-authored poses; never synthesize/interpolate art.

The source manifest and portrait remain immutable. New production sequences live
in motion_manifest.json. Each input region must be explicitly reviewed and listed
in motion_generation.json under runtime_frames: {animation: [{sheet, region}]}.
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
FPS = {"idle": 8, "walk": 16, "windup": 12, "attack": 18, "recover": 14, "hurt": 16, "death": 10, "talk": 10, "greet": 8, "rest": 4}

def read(path):
    return json.loads(path.read_text())

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
            sheet = entry.get("sheet", "motion_expanded.png")
            if Path(sheet).name != sheet or not sheet.endswith(".png"):
                raise ValueError(f"unsafe sheet: {sheet}")
            if sheet not in images:
                im = Image.open(folder / sheet)
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
            if scale != 1.0:
                cropped = cropped.resize((max(1,round(cropped.width*scale)),max(1,round(cropped.height*scale))),Image.Resampling.LANCZOS)
            pose = {"sheet":sheet, "region":[x+bx,y+by,cropped.width,cropped.height], "left":(bx-anchor)*scale, "height":cropped.height, "hash":digest, "image":cropped, "scale":scale, "isolated":bool(entry.get("component_seeds"))}
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
        cols = 6
        atlas = Image.new("RGBA", (canvas[0]*cols,canvas[1]*math.ceil(len(poses)/cols)))
        for index, pose in enumerate(poses):
            x = (index%cols)*canvas[0]+int(round(half+pose["left"]))
            y = (index//cols)*canvas[1]+height-8-pose["height"]
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
        animations.append({"name":name,"fps":fps,"loop":name in ("idle","walk","talk"),"frames":frames})
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

"""Check the assets the game selects, rather than a retired legacy art layout."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
from PIL import Image
import audit_character_animation_assets as production

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = re.compile(r'''["'](res://[^"'\n]+)["']''')
EXACT = re.compile(r"res://[^\s:]*\.(?:png|jpg|webp|svg|json|gd|tscn|tres|wav|ogg|otf|ttf)")
POINTER = b"version https://git-lfs.github.com/spec/v1"


class WorkingAssets:
    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.commit = "working-tree"
        self.paths = {p.relative_to(self.root).as_posix() for folder in ["godot/assets", "godot/data"]
                      for p in (self.root/folder).rglob("*") if p.is_file()}
        self.image_sizes = {}
        self.unresolved_lfs = {}
        self.missing = set()

    def json(self, name):
        return json.loads((self.root/name).read_text(encoding="utf-8"))

    def png_size(self, name):
        if name not in self.image_sizes:
            path = self.root/name
            if not path.is_file():
                self.missing.add(name)
                return None
            with path.open("rb") as source:
                if source.read(len(POINTER)) == POINTER:
                    self.unresolved_lfs[name] = "LFS pointer has not been hydrated"
                    return None
            with Image.open(path) as image:
                size = image.size
                image.verify()
            self.image_sizes[name] = size
        return self.image_sizes[name]


def check_canvas(manifest, path, errors):
    canvas = manifest.get("canvas")
    if not canvas:
        return
    for animation in manifest.get("animations", []):
        for frame in animation.get("frames", []):
            if not isinstance(frame, dict) or "region" not in frame:
                continue
            region, margin = frame["region"], frame.get("margin", [0, 0, 0, 0])
            if [region[2]+margin[2], region[3]+margin[3]] != canvas:
                errors.append(f"{path}/{animation['name']}: logical frame size disagrees with the declared canvas")
            if margin[0] < 0 or margin[1] < 0 or margin[0] > margin[2] or margin[1] > margin[3]:
                errors.append(f"{path}/{animation['name']}: frame extends outside its fixed canvas")


def resource_closure(root=ROOT):
    root = Path(root)
    pending = ["godot/project.godot", "godot/scenes/World.tscn", "godot/scenes/Main.tscn"]
    # Data catalogs also supply dynamic resource paths which static preloads miss.
    pending += [p.relative_to(root).as_posix() for p in (root/"godot/data").rglob("*.json")]
    visited, missing, pointers, templates = set(), set(), set(), set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        path = root/name
        if not path.is_file():
            missing.add(name)
            continue
        with path.open("rb") as source:
            if source.read(len(POINTER)) == POINTER:
                pointers.add(name)
                continue
        if path.suffix not in {".gd", ".tscn", ".tres", ".json", ".godot"}:
            continue
        # Entries such as res://scripts/foo.gd::method in documentation are not paths.
        for value in RESOURCE.findall(path.read_text(encoding="utf-8")):
            if EXACT.fullmatch(value):
                if "%" in value or "{" in value or "$" in value:
                    templates.add(value)
                else:
                    pending.append("godot/"+value[6:])
    return {"resources":len(visited), "missing":sorted(missing), "unhydrated_lfs":sorted(pointers),
            "dynamic_templates":sorted(templates), "dynamic_path_validation":"Static templates are reported separately; concrete catalog paths and native loading are checked."}


def run(min_unique_enemies=40, output=None):
    tree = WorkingAssets()
    report = production.audit(tree)
    errors = report["errors"]
    for row in report["actors"]:
        check_canvas(tree.json(row["manifest"]), row["manifest"], errors)
    npcs = json.loads((ROOT/"godot/data/original_world_art_designs.json").read_text(encoding="utf-8"))["npcs"]
    npc_frames = 0
    for npc in npcs:
        folder = f"godot/assets/sprites/original_npcs/{npc['id']}/"
        path = next((folder+n for n in production.LAYERS if folder+n in tree.paths), None)
        if path is None:
            errors.append(f"{npc['id']}: missing NPC acting manifest")
            continue
        manifest, clips = production.inspect_manifest(tree,path,errors)
        check_canvas(manifest,path,errors)
        for name in ["idle","talk","greet"]:
            if not clips.get(name,{}).get("frame_refs"):
                errors.append(f"{npc['id']}: missing {name}")
        npc_frames += sum(c["frame_refs"] for c in clips.values())
    closure = resource_closure()
    errors += ["Missing resource: "+p for p in closure["missing"]]
    errors += ["Unhydrated resource: "+p for p in closure["unhydrated_lfs"]]
    errors += ["Missing atlas: "+p for p in sorted(tree.missing)]
    errors += ["Unhydrated atlas: "+p for p in tree.unresolved_lfs]
    if report["summary"]["minor_species"] < min_unique_enemies:
        errors.append("Too few unique runtime enemy species")
    report["dependency_closure"] = closure
    report["npc_count"] = len(npcs)
    report["npc_frame_refs"] = npc_frames
    report["errors"] = sorted(set(errors))
    report["method"] = "Working-file dependency closure, PNG integrity/crops, fixed logical canvases and production attack/manifest precedence. No playback-quality claim."
    if output:
        Path(output).parent.mkdir(parents=True,exist_ok=True)
        Path(output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if report["errors"]:
        raise ValueError("\n".join(report["errors"]))
    print(f"RUNTIME_ASSET_DEPENDENCIES enemies={report['summary']['minor_species']} bosses={report['summary']['chapter_bosses']} npcs={len(npcs)} resources={closure['resources']} errors=0")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min-unique-enemies",type=int,default=40)
    parser.add_argument("--output",type=Path)
    args = parser.parse_args()
    run(args.min_unique_enemies,args.output)

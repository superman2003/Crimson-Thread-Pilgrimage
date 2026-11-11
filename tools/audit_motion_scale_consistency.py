"""Gate: every animation frame keeps the character's body size between its neighbours.

A hand animator draws each pose over onion skins of the poses around it, so the
body never swells or shrinks between two frames. Generated in-betweens have no
such guide; this audit stands in for the flip-through check. For each frame it
counts solid pixels (alpha > 128) and compares them with the previous and next
frame the runtime actually shows (loops wrap). Area is quadratic in scale but
far less sensitive than silhouette height to a wing angle or a crouch, so a
frame whose area leaves [min/T, max*T] of its neighbours was drawn at the wrong
scale. Frames whose neighbours are both empty or which end a one-shot clip are
skipped.

    python tools/audit_motion_scale_consistency.py            # gate the active layers
    python tools/audit_motion_scale_consistency.py --report out.json
    python tools/audit_motion_scale_consistency.py --self-test
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CREATURES = ROOT / "godot/assets/sprites/original_creatures"
# Newest layer first; the first one present is what the game loads.
ACTIVE_LAYERS = ["motion_redraw_manifest.json", "motion_transition_manifest.json", "motion_onion_manifest.json", "motion_v8_manifest.json", "boss_behavior_manifest.json",
                 "combat_motion_v7_manifest.json", "motion_manifest.json", "manifest.json"]
# Only drawings produced by generated in-between layers are gated; earlier
# layers were authored as whole clips and stay report-only.
GATED_ATLAS_MARKERS = ("motion_onion_", "motion_v8_", "motion_transition_")
THRESHOLD = 1.5
SOLID_ALPHA = 128


def res_path(resource: str) -> Path:
    prefix = "res://assets/sprites/original_creatures/"
    if resource.startswith(prefix):
        return CREATURES / resource.removeprefix(prefix)
    return ROOT / "godot" / resource.removeprefix("res://")


def animations_of(manifest: dict) -> dict:
    rows = manifest["animations"]
    return rows if isinstance(rows, dict) else {row["name"]: row for row in rows}


class AtlasCache:
    def __init__(self):
        self.alpha = {}

    def solid_area(self, frame: dict) -> int:
        path = res_path(frame["atlas"])
        if path not in self.alpha:
            with Image.open(path) as image:
                self.alpha[path] = np.asarray(image.convert("RGBA"))[:, :, 3]
        x, y, w, h = frame["region"]
        return int((self.alpha[path][y:y + h, x:x + w] > SOLID_ALPHA).sum())


def neighbours(index: int, count: int, loop: bool):
    if count < 3:
        return None
    if 0 < index < count - 1:
        return index - 1, index + 1
    if loop:
        return (index - 1) % count, (index + 1) % count
    return None


def check_clip(areas: list[int], loop: bool, threshold: float = THRESHOLD):
    """Yield (index, left, mid, right, ratio) for frames sized outside their neighbours."""
    for index, mid in enumerate(areas):
        pair = neighbours(index, len(areas), loop)
        if pair is None:
            continue
        left, right = areas[pair[0]], areas[pair[1]]
        if left == 0 or right == 0:
            continue
        if mid > max(left, right) * threshold or mid < min(left, right) / threshold:
            yield index, left, mid, right, round(mid / math.sqrt(left * right), 3)


def active_manifest(folder: Path):
    return next((folder / name for name in ACTIVE_LAYERS if (folder / name).exists()), None)


def audit(threshold: float = THRESHOLD, kinds=None):
    cache = AtlasCache()
    findings = []
    checked = 0
    for folder in sorted(p for p in CREATURES.iterdir() if p.is_dir()):
        if kinds and folder.name not in kinds:
            continue
        path = active_manifest(folder)
        if path is None:
            continue
        manifest = json.loads(path.read_text(encoding="utf-8"))
        for name, clip in animations_of(manifest).items():
            frames = clip["frames"]
            areas = [cache.solid_area(frame) for frame in frames]
            for index, left, mid, right, ratio in check_clip(areas, bool(clip.get("loop")), threshold):
                gated = any(marker in frames[index]["atlas"] for marker in GATED_ATLAS_MARKERS)
                findings.append(dict(kind=folder.name, layer=path.name, animation=name, index=index,
                                     frames=len(frames), left=left, mid=mid, right=right,
                                     ratio=ratio, gated=gated))
            checked += len(frames)
    return checked, findings


def self_test() -> int:
    ok = True

    def expect(condition, label):
        nonlocal ok
        if not condition:
            print("SELF_TEST FAIL:", label)
            ok = False

    steady = [1000, 1040, 980, 1010]
    expect(list(check_clip(steady, True)) == [], "steady loop passes")
    swollen = [1000, 2600, 1000, 1000]
    expect([row[0] for row in check_clip(swollen, True)] == [1], "swollen midpoint is caught")
    shrunk = [1000, 1000, 380, 1000, 1000]
    expect([row[0] for row in check_clip(shrunk, False)] == [2], "shrunk death midpoint is caught")
    expect(list(check_clip([1000, 3000], True)) == [], "two-frame clips have no midpoint")
    expect(list(check_clip([3000, 1000, 1000], False)) == [], "one-shot ends are not judged")
    expect([row[0] for row in check_clip([3000, 1000, 1000], True)] == [0], "loop seam is judged")
    expect(list(check_clip([1000, 1400, 1900], False)) == [], "monotonic growth inside the range passes")
    expect(list(check_clip([0, 5000, 0], False)) == [], "empty neighbours are skipped")
    print("MOTION_SCALE_SELF_TEST", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--threshold", type=float, default=THRESHOLD)
    parser.add_argument("--kind", action="append")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    checked, findings = audit(args.threshold, args.kind)
    gated = [row for row in findings if row["gated"]]
    if args.report:
        args.report.write_text(json.dumps(findings, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for row in gated[:60]:
        print(f"FAIL: {row['kind']} {row['animation']}[{row['index']}/{row['frames']}] "
              f"solid {row['left']}/{row['mid']}/{row['right']} ratio x{row['ratio']}")
    print(f"MOTION_SCALE_CONSISTENCY frames={checked} outliers={len(findings)} "
          f"gated_failures={len(gated)} threshold={args.threshold}")
    return 1 if gated else 0


if __name__ == "__main__":
    raise SystemExit(main())

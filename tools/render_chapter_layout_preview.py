"""Render a top-down preview of a chapter's platform/room layout to a PNG.

Dev aid only (not shipped): lets us eyeball the branch+loop geometry without
launching Godot.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"

SCALE = 0.16
PAD = 40


def layer_color(top: float, h: float) -> tuple:
    if h > 80:  # vertical wall
        return (90, 90, 110)
    if top <= 430:
        return (95, 170, 235)   # upper
    if top >= 600:
        return (220, 140, 90)   # lower
    return (150, 200, 120)      # middle


def render(name: str, out: Path) -> None:
    cfg = json.loads((DATA_DIR / name).read_text(encoding="utf-8-sig"))
    width = cfg["world"]["width"]
    height = cfg["world"].get("height", 720)
    W = int(width * SCALE) + PAD * 2
    H = int(height * SCALE) + PAD * 2 + 60
    img = Image.new("RGB", (W, H), (24, 22, 30))
    d = ImageDraw.Draw(img)

    def sx(x):
        return int(x * SCALE) + PAD

    def sy(y):
        return int(y * SCALE) + PAD

    # room bands
    for room in cfg["map_rooms"]:
        x0, x1 = room["range"]
        d.line([(sx(x0), PAD - 6), (sx(x0), H - PAD)], fill=(60, 58, 72), width=1)
        d.text((sx(x0) + 3, H - 36), str(room.get("kind", "")), fill=(120, 118, 135))
    # platforms
    for p in cfg["platforms"]:
        x, y, w, h = p["rect"][:4]
        d.rectangle([sx(x), sy(y), sx(x + w), sy(y + h)], fill=layer_color(y, h))
    # enemies
    for e in cfg.get("enemy_spawns", []):
        ex, ey = e["position"][:2]
        d.ellipse([sx(ex) - 3, sy(ey) - 3, sx(ex) + 3, sy(ey) + 3], fill=(235, 70, 70))
    # interactives / save points
    for it in cfg.get("interactives", []):
        ix, iy = it.get("position", [0, 0])[:2]
        d.rectangle([sx(ix) - 3, sy(iy) - 3, sx(ix) + 3, sy(iy) + 3], outline=(245, 220, 90), width=2)
    for sp in cfg.get("save_points", []):
        sxp, syp = sp.get("position", [0, 0])[:2]
        d.ellipse([sx(sxp) - 4, sy(syp) - 4, sx(sxp) + 4, sy(syp) + 4], outline=(120, 240, 220), width=2)
    # player start / boss
    ps = cfg.get("player_start", [0, 0])
    d.rectangle([sx(ps[0]) - 4, sy(ps[1]) - 4, sx(ps[0]) + 4, sy(ps[1]) + 4], fill=(120, 240, 120))

    d.text((PAD, 10), f"{name}  width={width}  platforms={len(cfg['platforms'])} "
                      f"rooms={len(cfg['map_rooms'])}  "
                      f"[blue=upper green=mid orange=lower; red=enemy yellow=interactive cyan=save]",
           fill=(220, 220, 230))
    img.save(out)
    print(f"rendered {out}")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "demo_ch03_saltwhite_archive.json"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "ch03_layout_preview.png"
    render(target, out)

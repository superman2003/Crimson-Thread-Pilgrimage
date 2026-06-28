from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "platformer_original_pack"
FRAMES = OUT / "frames"
SHEET = OUT / "sheets"

SCALE = 4
FRAME = 64

INK = "#172039"
INK_2 = "#26314d"
SHADOW = "#101522"
SKIN = "#d9a66f"
SKIN_DARK = "#9c6148"
TEAL = "#0b8f8c"
TEAL_DARK = "#07616d"
GOLD = "#d6a33b"
GOLD_DARK = "#7b5326"
IVORY = "#f3e6c8"
BOOT = "#20202b"
STEEL = "#d7e6ef"
EDGE = "#342433"
FX = "#8ef6e9"
STONE_1 = "#887f84"
STONE_2 = "#5f6377"
STONE_3 = "#b4a38a"
STONE_DARK = "#3e3b4f"
BG = "#948371"


ANIMS = {
    "idle": 4,
    "walk": 6,
    "run": 6,
    "dash_slash": 5,
    "combo": 5,
    "jump": 4,
}


def ensure_dirs() -> None:
    for path in [OUT, FRAMES, SHEET]:
        path.mkdir(parents=True, exist_ok=True)
    for name in ANIMS:
        (FRAMES / name).mkdir(parents=True, exist_ok=True)


def px(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: str) -> None:
    draw.rectangle(box, fill=color)


def poly(draw: ImageDraw.ImageDraw, points: Iterable[tuple[int, int]], color: str) -> None:
    draw.polygon(list(points), fill=color)


def line(
    draw: ImageDraw.ImageDraw,
    points: Iterable[tuple[int, int]],
    color: str,
    width: int = 1,
) -> None:
    draw.line(list(points), fill=color, width=width)


def draw_sword(
    draw: ImageDraw.ImageDraw,
    hand: tuple[int, int],
    tip: tuple[int, int],
    glow: bool = False,
) -> None:
    hx, hy = hand
    tx, ty = tip
    if glow:
        line(draw, [(hx, hy), (tx, ty)], FX, 3)
    line(draw, [(hx, hy), (tx, ty)], STEEL, 1)
    px(draw, (hx - 3, hy - 1, hx + 2, hy + 1), GOLD)
    px(draw, (hx - 1, hy - 3, hx + 1, hy + 3), GOLD_DARK)


def draw_guardian(draw: ImageDraw.ImageDraw, i: int, pose: str) -> None:
    ox, oy = 32, 45
    lean = 0
    bob = 0
    cape = 0
    sword_tip = (54, 35)
    arm = (37, 33)
    slash = False
    airborne = False

    if pose == "idle":
        bob = [0, -1, 0, 1][i % 4]
        cape = [0, 1, 0, -1][i % 4]
    elif pose == "walk":
        lean = 1
        bob = [0, 1, 0, -1, 0, 1][i % 6]
        cape = [1, 2, 1, 0, -1, 0][i % 6]
    elif pose == "run":
        lean = 5
        bob = [0, -1, 1, 0, -1, 1][i % 6]
        cape = [3, 5, 4, 2, 4, 6][i % 6]
        sword_tip = (57, 40)
    elif pose == "dash_slash":
        lean = [7, 10, 12, 9, 5][i % 5]
        bob = [0, 0, -1, 0, 1][i % 5]
        cape = [4, 8, 10, 7, 3][i % 5]
        sword_tip = [(55, 33), (61, 31), (63, 32), (58, 28), (54, 37)][i % 5]
        arm = [(37, 33), (42, 32), (47, 31), (44, 29), (38, 34)][i % 5]
        slash = i >= 1
    elif pose == "combo":
        states = [
            (2, 0, 1, (58, 36), (39, 34), False),
            (7, 1, 5, (61, 41), (43, 35), True),
            (-1, 0, -2, (18, 34), (30, 34), True),
            (4, -10, 6, (50, 14), (39, 25), True),
            (11, 2, 8, (63, 37), (47, 34), True),
        ]
        lean, bob, cape, sword_tip, arm, slash = states[i % 5]
        airborne = i == 3
    elif pose == "jump":
        airborne = True
        lean = [1, 3, 0, 5][i % 4]
        bob = [-8, -13, -10, -3][i % 4]
        cape = [0, 3, 6, 4][i % 4]
        sword_tip = [(43, 17), (51, 24), (47, 31), (58, 37)][i % 4]
        arm = [(33, 27), (38, 30), (37, 32), (43, 35)][i % 4]

    y = oy + bob
    x = ox + lean

    if slash:
        if pose == "combo" and i == 3:
            line(draw, [(24, 17), (34, 9), (49, 8), (57, 15)], FX, 2)
            line(draw, [(25, 18), (40, 11), (58, 18)], IVORY, 1)
        else:
            line(draw, [(x - 4, y - 20), (x + 16, y - 23), (x + 29, y - 14)], FX, 2)
            line(draw, [(x, y - 18), (x + 20, y - 19), (x + 31, y - 11)], IVORY, 1)

    if pose == "dash_slash" and i in (1, 2):
        for n in range(3):
            line(draw, [(x - 34 - n * 5, y - 15 + n * 3), (x - 13 - n * 3, y - 15 + n * 3)], FX, 1)

    # shadow
    if not airborne:
        px(draw, (x - 17, 57, x + 14, 59), "#00000033")

    # cape, large identifying silhouette distinct from the reference.
    poly(
        draw,
        [
            (x - 9, y - 31),
            (x - 24 - cape, y - 23),
            (x - 29 - cape, y - 9),
            (x - 13 - cape, y - 12),
            (x - 4, y - 21),
        ],
        TEAL_DARK,
    )
    poly(
        draw,
        [
            (x - 8, y - 32),
            (x - 23 - cape, y - 23),
            (x - 24 - cape, y - 12),
            (x - 10 - cape, y - 14),
            (x - 1, y - 22),
        ],
        TEAL,
    )
    px(draw, (x - 20 - cape, y - 18, x - 17 - cape, y - 15), GOLD)

    # legs
    leg_cycle = i % 6
    if pose in ("run", "dash_slash"):
        front = [(x + 2, y - 4), (x + 13, y + 5), (x + 11, y + 13)]
        back = [(x - 4, y - 4), (x - 15, y + 3), (x - 17, y + 12)]
    elif pose == "walk" and leg_cycle in (1, 2, 4):
        front = [(x + 1, y - 3), (x + 8, y + 7), (x + 5, y + 13)]
        back = [(x - 5, y - 3), (x - 10, y + 6), (x - 14, y + 10)]
    elif airborne:
        front = [(x + 1, y - 5), (x + 10, y + 1), (x + 9, y + 8)]
        back = [(x - 5, y - 4), (x - 12, y - 1), (x - 14, y + 6)]
    else:
        front = [(x + 0, y - 3), (x + 5, y + 8), (x + 3, y + 13)]
        back = [(x - 6, y - 3), (x - 9, y + 8), (x - 12, y + 13)]
    line(draw, back, INK, 4)
    line(draw, front, INK_2, 4)
    px(draw, (back[-1][0] - 4, back[-1][1], back[-1][0] + 2, back[-1][1] + 2), BOOT)
    px(draw, (front[-1][0] - 3, front[-1][1], front[-1][0] + 4, front[-1][1] + 2), BOOT)

    # torso
    poly(draw, [(x - 9, y - 29), (x + 8, y - 27), (x + 11, y - 9), (x - 7, y - 6), (x - 13, y - 18)], INK)
    px(draw, (x - 8, y - 25, x + 7, y - 18), INK_2)
    px(draw, (x - 9, y - 21, x + 8, y - 18), TEAL_DARK)
    px(draw, (x - 7, y - 20, x + 6, y - 18), TEAL)
    px(draw, (x - 2, y - 27, x + 2, y - 7), GOLD_DARK)
    px(draw, (x - 1, y - 26, x + 1, y - 8), GOLD)
    px(draw, (x + 6, y - 24, x + 11, y - 18), GOLD_DARK)
    px(draw, (x - 13, y - 24, x - 8, y - 18), GOLD_DARK)

    # arms
    line(draw, [(x - 8, y - 23), (x - 17, y - 15)], INK_2, 4)
    px(draw, (x - 20, y - 16, x - 15, y - 12), GOLD)
    line(draw, [(x + 8, y - 22), arm], INK_2, 4)
    px(draw, (arm[0] - 2, arm[1] - 2, arm[0] + 2, arm[1] + 2), GOLD)

    draw_sword(draw, arm, sword_tip, slash)

    # head, hair, scarf mask
    px(draw, (x - 8, y - 42, x + 7, y - 28), SKIN_DARK)
    px(draw, (x - 6, y - 40, x + 6, y - 30), SKIN)
    px(draw, (x - 9, y - 42, x + 7, y - 38), INK)
    px(draw, (x - 11, y - 39, x - 6, y - 29), INK)
    px(draw, (x + 5, y - 38, x + 11, y - 27), INK)
    px(draw, (x - 5, y - 36, x + 7, y - 32), EDGE)
    px(draw, (x + 2, y - 36, x + 4, y - 34), FX)
    px(draw, (x - 8, y - 29, x + 6, y - 26), IVORY)
    px(draw, (x - 2, y - 46, x + 5, y - 42), GOLD)
    px(draw, (x + 4, y - 49, x + 7, y - 43), GOLD_DARK)
    px(draw, (x - 5, y - 46, x - 2, y - 42), GOLD_DARK)


def make_frame(anim: str, i: int) -> Image.Image:
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_guardian(draw, i, anim)
    return img


def save_frames() -> dict[str, list[str]]:
    manifest: dict[str, list[str]] = {}
    for anim, count in ANIMS.items():
        manifest[anim] = []
        for i in range(count):
            img = make_frame(anim, i)
            path = FRAMES / anim / f"{anim}_{i:02d}.png"
            img.save(path)
            manifest[anim].append(path.relative_to(OUT).as_posix())
    return manifest


def make_sheet(anim: str, count: int) -> None:
    sheet = Image.new("RGBA", (FRAME * count, FRAME), (0, 0, 0, 0))
    for i in range(count):
        sheet.alpha_composite(make_frame(anim, i), (FRAME * i, 0))
    sheet.save(SHEET / f"{anim}_sheet.png")


def draw_platform(draw: ImageDraw.ImageDraw, x: int, y: int, tiles: int) -> None:
    for t in range(tiles):
        tx = x + t * 16
        color = [STONE_1, STONE_2, STONE_3, "#777184"][t % 4]
        px(draw, (tx, y, tx + 15, y + 8), color)
        px(draw, (tx, y + 9, tx + 15, y + 14), STONE_2)
        line(draw, [(tx, y), (tx + 15, y)], STONE_DARK)
        line(draw, [(tx, y + 8), (tx + 15, y + 8)], STONE_DARK)
        line(draw, [(tx, y), (tx, y + 14)], STONE_DARK)
        if t % 2 == 0:
            line(draw, [(tx + 8, y), (tx + 6, y + 8)], STONE_DARK)
        else:
            line(draw, [(tx + 10, y + 8), (tx + 9, y + 14)], STONE_DARK)


def paste_scaled(dst: Image.Image, sprite: Image.Image, x: int, y: int, scale: int = SCALE) -> None:
    scaled = sprite.resize((FRAME * scale, FRAME * scale), Image.Resampling.NEAREST)
    dst.alpha_composite(scaled, (x, y))


def preview() -> None:
    w, h = 960, 540
    img = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(img)

    for col in range(0, w, 4):
        if col % 16 == 0:
            px(draw, (col, 0, col + 3, h), "#8d7b68")

    draw_platform(draw, 48, 136, 38)
    paste_scaled(img, make_frame("idle", 0), 370, 48)

    draw_platform(draw, 48, 410, 38)
    for idx in range(5):
        paste_scaled(img, make_frame("combo", idx), 80 + idx * 120, 310, 3)

    draw_platform(draw, 48, 260, 38)
    for idx in range(6):
        paste_scaled(img, make_frame("run", idx), 70 + idx * 84, 170, 2)

    for idx in range(5):
        paste_scaled(img, make_frame("dash_slash", idx), 610 + idx * 62, 165, 2)

    for idx in range(4):
        spr = make_frame("jump", idx)
        paste_scaled(img, spr, 640 + idx * 76, 335 - idx * 18, 2)

    # Faint reflection showcase.
    for idx in range(3):
        spr = make_frame("idle" if idx == 0 else "run", idx)
        scaled = spr.resize((FRAME * 2, FRAME * 2), Image.Resampling.NEAREST)
        reflect = scaled.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        alpha = reflect.getchannel("A").point(lambda a: int(a * 0.25))
        reflect.putalpha(alpha)
        img.alpha_composite(reflect, (690 + idx * 72, 72))

    label_color = "#352b25"
    draw.text((48, 108), "ORIGINAL teal bell-guard platformer pack", fill=label_color)
    draw.text((610, 140), "dash slash", fill=label_color)
    draw.text((642, 312), "jump arc", fill=label_color)
    draw.text((82, 382), "5-hit combo sample - original silhouette", fill=label_color)

    img.save(OUT / "preview.png")


def write_html() -> None:
    rows = "\n".join(
        f"""
        <section class="strip">
          <h2>{anim.replace("_", " ").title()}</h2>
          <img src="sheets/{anim}_sheet.png" alt="{anim} spritesheet">
        </section>
        """.strip()
        for anim in ANIMS
    )
    html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Original Platformer Character Pack</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #2a2730;
      --panel: #3a3340;
      --ink: #f0e7d8;
      --muted: #bda991;
      --accent: #71ded4;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--ink);
      font-family: "Segoe UI", Arial, sans-serif;
      display: grid;
      place-items: start center;
      padding: 24px;
    }}
    main {{ width: min(1120px, 100%); }}
    h1 {{ margin: 0 0 8px; font-size: 24px; letter-spacing: 0; }}
    p {{ margin: 0 0 18px; color: var(--muted); }}
    .preview {{
      image-rendering: pixelated;
      width: 100%;
      height: auto;
      border: 1px solid #584f58;
      background: #948371;
      display: block;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 12px;
      margin-top: 16px;
    }}
    .strip {{
      background: var(--panel);
      border: 1px solid #574c58;
      padding: 12px;
      border-radius: 8px;
      overflow: hidden;
    }}
    h2 {{ margin: 0 0 8px; font-size: 14px; color: var(--accent); }}
    .strip img {{
      image-rendering: pixelated;
      width: 100%;
      height: auto;
      background-image:
        linear-gradient(45deg, #4b4450 25%, transparent 25%),
        linear-gradient(-45deg, #4b4450 25%, transparent 25%),
        linear-gradient(45deg, transparent 75%, #4b4450 75%),
        linear-gradient(-45deg, transparent 75%, #4b4450 75%);
      background-size: 16px 16px;
      background-position: 0 0, 0 8px, 8px -8px, -8px 0;
    }}
  </style>
</head>
<body>
  <main>
    <h1>Original Platformer Character Pack</h1>
    <p>原创像素动作平台角色包预览：透明帧、横向 spritesheet、预览图，非付费素材复刻。</p>
    <img class="preview" src="preview.png" alt="original pixel platformer character pack preview">
    <div class="grid">
      {rows}
    </div>
  </main>
</body>
</html>
"""
    (OUT / "preview.html").write_text(html, encoding="utf-8")


def write_manifest(frame_manifest: dict[str, list[str]]) -> None:
    data = {
        "name": "original-teal-bell-guard-platformer-pack",
        "license_note": "Project-original generated placeholder asset. Do not treat as a copy of any paid third-party pack.",
        "frame_size": [FRAME, FRAME],
        "animations": {
            anim: {
                "fps": 8 if anim in ("idle", "walk", "jump") else 12,
                "frames": frames,
                "sheet": f"sheets/{anim}_sheet.png",
            }
            for anim, frames in frame_manifest.items()
        },
        "preview": "preview.png",
    }
    (OUT / "manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    ensure_dirs()
    frame_manifest = save_frames()
    for anim, count in ANIMS.items():
        make_sheet(anim, count)
    preview()
    write_html()
    write_manifest(frame_manifest)
    print(f"generated {OUT}")


if __name__ == "__main__":
    main()

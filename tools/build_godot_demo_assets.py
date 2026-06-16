from __future__ import annotations

import math
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "assets" / "sprites" / "demo"
SOURCE_ROOT = Path(r"D:\CrimsonThreadOdysseyAssets_v2")
CH01_PANEL = SOURCE_ROOT / "05_chapters_split" / "ch01_moss_bell_court_environment_panel.png"
MONSTER_ROOT = SOURCE_ROOT / "03_monsters_split" / "ch01_moss_bell_court"
BOSS_ROOT = SOURCE_ROOT / "04_bosses_split"
BG_WIDTH = 8192
BG_HEIGHT = 720


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=None, width=1):
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def polygon(draw: ImageDraw.ImageDraw, points, fill, outline=None):
    draw.polygon(points, fill=fill, outline=outline)


def line(draw: ImageDraw.ImageDraw, points, fill, width=1):
    draw.line(points, fill=fill, width=width, joint="curve")


def save_sprite(name: str, draw_fn, size=(128, 128)) -> None:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    draw_fn(draw, size)
    image.save(OUT / f"{name}.png")


def save_image(name: str, image: Image.Image) -> None:
    image.save(OUT / f"{name}.png")


def background_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    samples: list[tuple[int, int, int]] = []
    for x0, y0 in ((0, 0), (width - 14, 0), (0, height - 14), (width - 14, height - 14)):
        for x in range(max(0, x0), min(width, x0 + 14)):
            for y in range(max(0, y0), min(height, y0 + 14)):
                samples.append(rgb.getpixel((x, y)))
    return tuple(int(median(channel)) for channel in zip(*samples))


def foreground_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    bg = background_color(rgb)
    mask = Image.new("L", rgb.size, 0)
    px = rgb.load()
    out = mask.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = px[x, y]
            luma = 0.299 * r + 0.587 * g + 0.114 * b
            saturation = max(r, g, b) - min(r, g, b)
            delta = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            if (delta > 14 and (luma > 16 or saturation > 8)) or luma > 40 or saturation > 38:
                out[x, y] = 255
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = mask.filter(ImageFilter.MaxFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))
    return mask.point(lambda value: 255 if value > 18 else 0)


def save_source_sprite(name: str, source_path: Path, max_width: int = 116, max_height: int = 116) -> bool:
    if not source_path.exists():
        return False
    source = Image.open(source_path).convert("RGB")
    source = ImageEnhance.Color(source).enhance(1.06)
    source = ImageEnhance.Contrast(source).enhance(1.08)
    mask = foreground_mask(source)
    box = mask.getbbox()
    if box is None:
        return False
    left, top, right, bottom = box
    box = (max(0, left - 6), max(0, top - 6), min(source.width, right + 6), min(source.height, bottom + 6))
    rgba = source.convert("RGBA")
    rgba.putalpha(mask.filter(ImageFilter.GaussianBlur(0.45)))
    cutout = rgba.crop(box)
    scale = min(max_width / cutout.width, max_height / cutout.height)
    cutout = cutout.resize((max(1, round(cutout.width * scale)), max(1, round(cutout.height * scale))), Image.Resampling.LANCZOS)
    sprite = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    sprite.alpha_composite(cutout, ((128 - cutout.width) // 2, 122 - cutout.height))
    save_image(name, sprite)
    return True


def vertical_gradient(width: int, height: int, top: tuple[int, int, int], mid: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    px = image.load()
    for y in range(height):
        if y < height * 0.52:
            t = y / (height * 0.52)
            a, b = top, mid
        else:
            t = (y - height * 0.52) / (height * 0.48)
            a, b = mid, bottom
        color = tuple(round(a[i] * (1.0 - t) + b[i] * t) for i in range(3))
        for x in range(width):
            px[x, y] = (*color, 255)
    return image


def draw_arch(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, color, edge=None, width: int = 4) -> None:
    arch_start = y + round(h * 0.34)
    arch_height = round(h * 0.68)
    draw.rectangle((x, arch_start, x + w, y + h), fill=color)
    draw.pieslice((x, y, x + w, y + arch_height), 180, 360, fill=color)
    if edge:
        draw.arc((x, y, x + w, y + arch_height), 180, 360, fill=edge, width=width)
        draw.line((x, arch_start, x, y + h), fill=edge, width=width)
        draw.line((x + w, arch_start, x + w, y + h), fill=edge, width=width)


def draw_bell(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float, color, edge, alpha: int) -> None:
    w = round(44 * scale)
    h = round(58 * scale)
    draw.line((cx, cy - round(42 * scale), cx, cy - round(20 * scale)), fill=(*edge[:3], alpha), width=max(2, round(4 * scale)))
    draw.ellipse((cx - w, cy - h, cx + w, cy + h * 0.42), fill=(*color[:3], alpha), outline=(*edge[:3], min(255, alpha + 35)), width=max(2, round(4 * scale)))
    draw.rectangle((cx - w + round(5 * scale), cy + round(10 * scale), cx + w - round(5 * scale), cy + round(22 * scale)), fill=(*edge[:3], min(255, alpha + 25)))
    draw.ellipse((cx - round(12 * scale), cy + round(17 * scale), cx + round(12 * scale), cy + round(39 * scale)), fill=(226, 168, 61, min(255, alpha + 45)))


def draw_ruin_tower(draw: ImageDraw.ImageDraw, x: int, base_y: int, h: int, color, edge, alpha: int) -> None:
    w = round(h * 0.19)
    draw.polygon([(x - w, base_y), (x - round(w * 0.7), base_y - h), (x + round(w * 0.7), base_y - h), (x + w, base_y)], fill=(*color[:3], alpha))
    draw.line((x - w, base_y, x - round(w * 0.7), base_y - h, x + round(w * 0.7), base_y - h, x + w, base_y), fill=(*edge[:3], min(255, alpha + 30)), width=3)
    for i in range(4):
        y = base_y - h + 38 + i * round(h * 0.18)
        draw.line((x - round(w * 0.52), y, x + round(w * 0.52), y + 8), fill=(*edge[:3], min(255, alpha + 12)), width=2)
    draw_bell(draw, x, base_y - round(h * 0.63), 0.46, (124, 84, 38), edge, alpha + 12)


def draw_vines(draw: ImageDraw.ImageDraw, start_x: int, start_y: int, length: int, color, alpha: int, count: int) -> None:
    for i in range(count):
        x = start_x + i * 21
        points = []
        for step in range(0, length, 24):
            wave = math.sin((step + i * 13) * 0.042) * 10
            points.append((x + round(wave), start_y + step))
        draw.line(points, fill=(*color[:3], alpha), width=3)
        for j in range(2, len(points), 3):
            px, py = points[j]
            draw.ellipse((px - 4, py - 2, px + 8, py + 8), fill=(81, 124, 60, min(255, alpha + 35)))


def make_background_layers() -> dict[str, Image.Image]:
    sky = vertical_gradient(BG_WIDTH, BG_HEIGHT, (7, 14, 18), (28, 42, 34), (8, 10, 12))
    sky_draw = ImageDraw.Draw(sky, "RGBA")
    for x, y, rx, ry, alpha, color in [
        (560, 210, 360, 150, 45, (88, 186, 165)),
        (1830, 160, 420, 170, 38, (208, 164, 84)),
        (3140, 230, 320, 130, 36, (91, 164, 129)),
    ]:
        sky_draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(*color, alpha))
    for i in range(130):
        x = (i * 131 + 43) % BG_WIDTH
        y = 58 + (i * 47) % 420
        alpha = 18 + (i % 5) * 9
        sky_draw.rectangle((x, y, x + 1, y + 1), fill=(204, 190, 126, alpha))

    far = Image.new("RGBA", (BG_WIDTH, BG_HEIGHT), (0, 0, 0, 0))
    far_draw = ImageDraw.Draw(far, "RGBA")
    for i, x in enumerate(range(-70, BG_WIDTH, 360)):
        h = 340 + (i % 4) * 38
        draw_ruin_tower(far_draw, x + 120, 575, h, (27, 39, 34), (73, 80, 51), 120)
    for x in range(-180, BG_WIDTH, 420):
        draw_arch(far_draw, x, 330, 240, 260, (16, 25, 24, 88), (82, 72, 46, 92), 3)
    for x in range(0, BG_WIDTH, 512):
        far_draw.line((x, 402, x + 460, 390), fill=(94, 88, 52, 60), width=3)

    mid = Image.new("RGBA", (BG_WIDTH, BG_HEIGHT), (0, 0, 0, 0))
    mid_draw = ImageDraw.Draw(mid, "RGBA")
    for i, x in enumerate(range(-120, BG_WIDTH, 520)):
        y = 270 + (i % 2) * 34
        draw_arch(mid_draw, x, y, 320, 360, (28, 35, 31, 150), (126, 106, 55, 150), 5)
        draw_arch(mid_draw, x + 92, y + 74, 134, 232, (10, 16, 15, 130), (55, 72, 54, 120), 3)
        for sx in (x + 28, x + 258):
            mid_draw.rectangle((sx, y + 118, sx + 32, 622), fill=(32, 40, 34, 138), outline=(112, 97, 54, 118), width=3)
    for x in (630, 1540, 2520, 3340):
        mid_draw.line((x, 92, x, 326), fill=(132, 94, 43, 160), width=7)
        draw_bell(mid_draw, x, 340, 1.28, (141, 86, 35), (61, 39, 22), 178)
    for x in range(260, BG_WIDTH, 720):
        mid_draw.ellipse((x, 476, x + 210, 686), outline=(112, 139, 80, 96), width=8)
        mid_draw.ellipse((x + 42, 518, x + 168, 644), outline=(132, 91, 45, 82), width=5)

    near = Image.new("RGBA", (BG_WIDTH, BG_HEIGHT), (0, 0, 0, 0))
    near_draw = ImageDraw.Draw(near, "RGBA")
    for x in range(-90, BG_WIDTH, 340):
        near_draw.rectangle((x, 0, x + 44, 178 + (x % 3) * 28), fill=(8, 12, 12, 150))
        near_draw.rectangle((x - 20, 0, x + 80, 28), fill=(15, 20, 16, 170))
        draw_vines(near_draw, x + 8, 0, 270 + (x % 4) * 30, (50, 92, 55), 148, 3)
    for x in range(120, BG_WIDTH, 470):
        near_draw.line((x, 0, x + 80, 168), fill=(41, 30, 20, 140), width=8)
        draw_bell(near_draw, x + 88, 190, 0.54, (117, 71, 33), (53, 34, 21), 148)
    for x in range(-60, BG_WIDTH, 290):
        near_draw.arc((x, 542, x + 320, 848), 190, 350, fill=(13, 18, 16, 150), width=18)
        near_draw.line((x + 35, 621, x + 280, 596), fill=(68, 91, 58, 115), width=5)

    fog = Image.new("RGBA", (BG_WIDTH, BG_HEIGHT), (0, 0, 0, 0))
    fog_draw = ImageDraw.Draw(fog, "RGBA")
    for i in range(7):
        y = 250 + i * 54
        fog_draw.rectangle((0, y, BG_WIDTH, y + 16), fill=(106, 163, 135, 14 + i * 2))
    for x in range(80, BG_WIDTH, 260):
        fog_draw.ellipse((x, 520 + (x % 5) * 14, x + 90, 562 + (x % 3) * 20), fill=(87, 171, 151, 28))

    return {
        "bg_ch01_sky": sky,
        "bg_ch01_far_silhouettes": far,
        "bg_ch01_mid_arches": mid,
        "bg_ch01_near_vines": near,
        "bg_ch01_fog": fog,
    }


def save_background_layers() -> int:
    layers = make_background_layers()
    composite = layers["bg_ch01_sky"].copy()
    for name in ("bg_ch01_far_silhouettes", "bg_ch01_mid_arches", "bg_ch01_fog", "bg_ch01_near_vines"):
        composite.alpha_composite(layers[name])
    for name, image in layers.items():
        save_image(name, image)
    save_image("map_background_ch01", composite)
    save_image("bg_ch01_composite_preview", composite)
    return len(layers)


def make_tile(name: str, palette: str) -> Image.Image:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    if palette == "moss":
        base, edge, moss, shine = (45, 54, 42, 255), (22, 28, 24, 255), (94, 126, 62, 255), (186, 170, 82, 190)
    elif palette == "bronze":
        base, edge, moss, shine = (83, 64, 38, 255), (38, 30, 24, 255), (76, 104, 67, 210), (211, 150, 55, 210)
    else:
        base, edge, moss, shine = (72, 49, 36, 255), (32, 24, 20, 255), (61, 80, 51, 160), (208, 132, 48, 210)
    draw.rounded_rectangle((2, 12, 126, 118), radius=9, fill=base, outline=edge, width=5)
    for y in (34, 62, 91):
        draw.line((8, y, 120, y + 6), fill=edge, width=3)
    for x in (22, 49, 84, 108):
        draw.line((x, 22, x - 8, 114), fill=(edge[0], edge[1], edge[2], 120), width=2)
    for x in range(4, 124, 15):
        draw.ellipse((x, 6, x + 22, 22), fill=moss)
        draw.line((x + 5, 18, x + 1, 35), fill=(moss[0], moss[1], moss[2], 170), width=2)
    for i in range(9):
        x = 12 + i * 12
        draw.line((x, 26, x + 7, 18), fill=shine, width=2)
    return img


def moss_larva(draw, size):
    ellipse(draw, (22, 58, 102, 96), (72, 119, 47, 255), (23, 48, 24, 255), 4)
    ellipse(draw, (34, 45, 78, 82), (103, 151, 63, 255), (23, 48, 24, 255), 3)
    for x in (44, 57, 70):
        polygon(draw, [(x, 62), (x + 6, 72), (x - 4, 72)], (225, 220, 170, 255))
    ellipse(draw, (48, 55, 56, 63), (255, 218, 92, 255))
    for x in (34, 50, 66, 82):
        line(draw, [(x, 91), (x - 8, 108)], (43, 64, 33, 255), 4)


def bronze_moth(draw, size):
    ellipse(draw, (55, 35, 75, 91), (111, 72, 36, 255), (54, 37, 24, 255), 3)
    polygon(draw, [(62, 55), (18, 30), (28, 83)], (184, 126, 45, 210), (67, 45, 24, 255))
    polygon(draw, [(68, 55), (110, 31), (101, 83)], (202, 143, 54, 210), (67, 45, 24, 255))
    ellipse(draw, (58, 42, 64, 49), (255, 229, 119, 255))
    ellipse(draw, (68, 42, 74, 49), (255, 229, 119, 255))
    line(draw, [(61, 37), (45, 18)], (115, 83, 43, 255), 3)
    line(draw, [(70, 37), (87, 18)], (115, 83, 43, 255), 3)


def spore_bellmaker(draw, size):
    ellipse(draw, (38, 42, 92, 100), (82, 104, 63, 255), (35, 51, 33, 255), 4)
    polygon(draw, [(33, 54), (64, 20), (96, 54)], (170, 121, 52, 255), (77, 51, 24, 255))
    ellipse(draw, (50, 57, 78, 82), (230, 177, 75, 170), (115, 78, 38, 255), 2)
    line(draw, [(64, 84), (64, 109)], (51, 37, 23, 255), 5)
    for x in (43, 85):
        line(draw, [(x, 89), (x - 10 if x < 64 else x + 10, 111)], (51, 37, 23, 255), 4)


def gear_sentinel(draw, size):
    ellipse(draw, (28, 25, 100, 97), (92, 84, 72, 255), (196, 143, 54, 255), 5)
    ellipse(draw, (47, 44, 81, 78), (39, 43, 42, 255), (196, 143, 54, 255), 4)
    for angle in range(0, 360, 45):
        import math

        cx, cy = 64, 61
        x = cx + int(math.cos(math.radians(angle)) * 45)
        y = cy + int(math.sin(math.radians(angle)) * 45)
        ellipse(draw, (x - 5, y - 5, x + 5, y + 5), (196, 143, 54, 255))
    line(draw, [(64, 97), (64, 115)], (60, 49, 39, 255), 6)
    line(draw, [(42, 116), (86, 116)], (60, 49, 39, 255), 5)


def rust_crown_guardian(draw, size):
    ellipse(draw, (24, 20, 104, 100), (88, 71, 56, 255), (214, 154, 54, 255), 5)
    ellipse(draw, (43, 40, 85, 82), (34, 36, 35, 255), (214, 154, 54, 255), 4)
    for x in (42, 55, 68, 81):
        line(draw, [(x, 26), (x + 8, 8)], (214, 154, 54, 255), 5)
    line(draw, [(35, 103), (21, 121)], (214, 154, 54, 255), 5)
    line(draw, [(93, 103), (109, 121)], (214, 154, 54, 255), 5)
    line(draw, [(26, 60), (6, 53), (10, 43)], (125, 87, 38, 255), 6)
    line(draw, [(102, 60), (122, 53), (118, 43)], (125, 87, 38, 255), 6)


def hazard_spikes(draw, size):
    for x in range(10, 120, 18):
        polygon(draw, [(x, 112), (x + 9, 60), (x + 18, 112)], (194, 65, 44, 255), (92, 27, 23, 255))
    line(draw, [(4, 114), (124, 114)], (92, 27, 23, 255), 5)


def hazard_bell(draw, size):
    ellipse(draw, (37, 32, 91, 91), (169, 95, 35, 230), (90, 44, 18, 255), 4)
    line(draw, [(64, 18), (64, 32)], (218, 154, 58, 255), 5)
    line(draw, [(42, 90), (86, 90)], (90, 44, 18, 255), 4)
    ellipse(draw, (57, 90, 71, 104), (226, 180, 71, 255), (90, 44, 18, 255), 2)


def trap_fake_moss_floor(draw, size):
    draw.rounded_rectangle((5, 60, 123, 104), radius=8, fill=(46, 56, 42, 255), outline=(25, 30, 24, 255), width=4)
    for x in range(8, 122, 16):
        draw.ellipse((x, 48, x + 28, 68), fill=(86, 126, 58, 230))
        line(draw, [(x + 8, 66), (x + 5, 82)], (68, 96, 48, 220), 2)
    for x in (30, 60, 91):
        line(draw, [(x, 66), (x + 18, 98)], (130, 70, 45, 210), 3)
    polygon(draw, [(50, 82), (64, 116), (78, 82)], (35, 22, 17, 230), (12, 9, 8, 255))


def trap_bell_gap(draw, size):
    line(draw, [(18, 22), (64, 106), (110, 22)], (102, 66, 28, 255), 4)
    ellipse(draw, (42, 45, 86, 91), (178, 102, 35, 245), (79, 42, 18, 255), 4)
    ellipse(draw, (55, 88, 73, 106), (232, 176, 64, 255), (79, 42, 18, 255), 3)
    line(draw, [(8, 112), (46, 112)], (71, 61, 42, 255), 7)
    line(draw, [(82, 112), (120, 112)], (71, 61, 42, 255), 7)
    for x in (56, 64, 72):
        line(draw, [(x, 106), (x, 121)], (216, 81, 48, 210), 3)


def trap_spore_chest(draw, size):
    draw.rounded_rectangle((28, 62, 100, 103), radius=7, fill=(83, 56, 32, 255), outline=(35, 24, 18, 255), width=4)
    draw.rectangle((31, 55, 97, 70), fill=(117, 80, 38, 255), outline=(35, 24, 18, 255), width=3)
    ellipse(draw, (55, 72, 73, 90), (224, 178, 65, 255), (54, 35, 18, 255), 2)
    for x, y in [(29, 45), (45, 36), (86, 38), (99, 47), (64, 28)]:
        ellipse(draw, (x, y, x + 12, y + 12), (116, 167, 80, 170))
        line(draw, [(x + 6, y + 12), (64, 65)], (99, 138, 73, 150), 2)
    polygon(draw, [(31, 102), (98, 102), (92, 119), (37, 119)], (35, 24, 18, 220))


def trap_falling_clapper(draw, size):
    line(draw, [(64, 4), (64, 38)], (188, 123, 43, 255), 5)
    line(draw, [(33, 14), (95, 14)], (89, 58, 31, 255), 4)
    ellipse(draw, (31, 34, 97, 98), (164, 88, 34, 235), (70, 35, 16, 255), 5)
    ellipse(draw, (52, 91, 76, 116), (235, 164, 58, 255), (70, 35, 16, 255), 4)
    for x in (38, 64, 90):
        line(draw, [(x, 34), (x - 8, 19)], (236, 192, 89, 180), 2)
    line(draw, [(24, 118), (104, 118)], (194, 65, 44, 180), 4)


def trap_shortcut_revenge(draw, size):
    draw.rounded_rectangle((16, 42, 112, 112), radius=8, fill=(50, 38, 28, 255), outline=(179, 116, 43, 255), width=4)
    draw.rectangle((25, 53, 103, 104), fill=(31, 26, 23, 255))
    for x in range(31, 99, 15):
        polygon(draw, [(x, 53), (x + 7, 83), (x + 14, 53)], (203, 158, 78, 255), (91, 51, 23, 255))
        polygon(draw, [(x, 104), (x + 7, 74), (x + 14, 104)], (203, 158, 78, 255), (91, 51, 23, 255))
    line(draw, [(20, 32), (108, 32)], (97, 73, 38, 255), 4)
    ellipse(draw, (54, 18, 74, 38), (236, 178, 62, 255), (83, 53, 22, 255), 3)


def trap_false_lamp(draw, size):
    ellipse(draw, (42, 24, 86, 78), (66, 75, 68, 240), (198, 145, 55, 255), 4)
    ellipse(draw, (52, 39, 76, 65), (67, 84, 80, 140), (198, 145, 55, 180), 2)
    line(draw, [(64, 10), (64, 24)], (198, 145, 55, 255), 4)
    line(draw, [(47, 78), (37, 113)], (89, 61, 33, 255), 5)
    line(draw, [(81, 78), (91, 113)], (89, 61, 33, 255), 5)
    line(draw, [(34, 114), (94, 114)], (89, 61, 33, 255), 5)
    for x in (40, 64, 88):
        line(draw, [(x, 82), (x + 9, 97)], (92, 27, 23, 210), 3)
    ellipse(draw, (58, 48, 70, 60), (31, 24, 20, 255))


def bell_key(draw, size):
    ellipse(draw, (42, 31, 86, 75), (246, 181, 55, 255), (106, 72, 26, 255), 4)
    line(draw, [(64, 75), (64, 105)], (246, 181, 55, 255), 7)
    line(draw, [(64, 97), (84, 97)], (246, 181, 55, 255), 5)
    line(draw, [(64, 86), (78, 86)], (246, 181, 55, 255), 4)
    ellipse(draw, (54, 43, 74, 63), (36, 35, 30, 255))


def shortcut_lever(draw, size):
    line(draw, [(48, 106), (80, 106)], (117, 82, 35, 255), 8)
    line(draw, [(63, 104), (78, 31)], (205, 143, 47, 255), 8)
    ellipse(draw, (67, 18, 91, 42), (239, 185, 67, 255), (103, 63, 24, 255), 3)


def boss_gate(draw, size):
    polygon(draw, [(27, 112), (101, 112), (98, 30), (64, 10), (30, 30)], (63, 41, 28, 245), (205, 143, 47, 255))
    ellipse(draw, (48, 48, 80, 80), (38, 35, 30, 255), (205, 143, 47, 255), 4)
    line(draw, [(64, 18), (64, 107)], (205, 143, 47, 255), 3)


def build_preview(names: list[str]) -> None:
    tile = 160
    cols = 5
    rows = (len(names) + cols - 1) // cols
    preview = Image.new("RGBA", (cols * tile, rows * tile), (15, 18, 17, 255))
    draw = ImageDraw.Draw(preview, "RGBA")
    for index, name in enumerate(names):
        image = Image.open(OUT / f"{name}.png").convert("RGBA")
        x = (index % cols) * tile + 16
        y = (index // cols) * tile + 10
        preview.alpha_composite(image, (x, y))
        draw.text((x, y + 130), name, fill=(226, 210, 156, 255))
    preview.save(OUT / "demo_asset_replacement_preview.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    background_layers = save_background_layers()
    save_image("platform_moss_stone", make_tile("platform_moss_stone", "moss"))
    save_image("platform_bronze_bridge", make_tile("platform_bronze_bridge", "bronze"))
    save_image("platform_boss_stone", make_tile("platform_boss_stone", "boss"))

    source_sprites = {
        "enemy_moss_larva": MONSTER_ROOT / "01_moss_toothed_larva.png",
        "enemy_bronze_moth": MONSTER_ROOT / "02_bronze_wing_moth.png",
        "enemy_spore_bellmaker": MONSTER_ROOT / "03_spore_bellmaker.png",
        "enemy_gear_sentinel": MONSTER_ROOT / "04_gear_sentinel.png",
        "boss_rust_crown_guardian": BOSS_ROOT / "ch01_moss_bell_court_rust_crown_guardian_boss.png",
    }
    sprite_defs = {
        "enemy_moss_larva": moss_larva,
        "enemy_bronze_moth": bronze_moth,
        "enemy_spore_bellmaker": spore_bellmaker,
        "enemy_gear_sentinel": gear_sentinel,
        "boss_rust_crown_guardian": rust_crown_guardian,
        "hazard_spikes": hazard_spikes,
        "hazard_bell": hazard_bell,
        "trap_fake_moss_floor": trap_fake_moss_floor,
        "trap_bell_gap": trap_bell_gap,
        "trap_spore_chest": trap_spore_chest,
        "trap_falling_clapper": trap_falling_clapper,
        "trap_shortcut_revenge": trap_shortcut_revenge,
        "trap_false_lamp": trap_false_lamp,
        "pickup_bell_key": bell_key,
        "shortcut_lever": shortcut_lever,
        "boss_gate": boss_gate,
    }
    for name, fn in sprite_defs.items():
        if name in source_sprites and save_source_sprite(name, source_sprites[name], 124 if name.startswith("boss_") else 116, 120 if name.startswith("boss_") else 116):
            continue
        save_sprite(name, fn)
    build_preview([
        "platform_moss_stone",
        "platform_bronze_bridge",
        "platform_boss_stone",
        "trap_fake_moss_floor",
        "trap_bell_gap",
        "trap_spore_chest",
        "trap_falling_clapper",
        "trap_shortcut_revenge",
        "trap_false_lamp",
        "boss_gate",
    ])
    print(f"GODOT_DEMO_ASSETS_PASS png=27 background_layers={background_layers} platforms=3 traps=6 formal_enemies=5")


if __name__ == "__main__":
    main()

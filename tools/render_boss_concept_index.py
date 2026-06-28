from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
IMAGE_DIR = ROOT / "artifacts" / "boss_concepts" / "images"
CONTACT_DIR = ROOT / "artifacts" / "boss_concepts" / "contact_sheets"
DOCS_DIR = ROOT / "docs" / "spec"

BOSSES = [
    (1, "\u82d4\u949f\u5b88\u6bcd", "Moss Bell Matriarch", "boss_01_moss_bell_matriarch.png"),
    (2, "\u7eef\u7ebf\u6267\u526a\u8005", "Crimson Thread Scissor Apostle", "boss_02_crimson_thread_scissor_apostle.png"),
    (3, "\u7070\u51a0\u87b3\u5c06", "Ash-Crowned Mantis Warlord", "boss_03_ash_crowned_mantis_warlord.png"),
    (4, "\u94dc\u6839\u4e3b\u6559", "Copperroot Bishop", "boss_04_copperroot_bishop.png"),
    (5, "\u955c\u6c60\u65b0\u5a18", "Mirrorpool Bride", "boss_05_mirrorpool_bride.png"),
    (6, "\u767e\u94a5\u770b\u95e8\u4eba", "Hundred-Key Gatekeeper", "boss_06_hundred_key_gatekeeper.png"),
    (7, "\u70db\u810a\u517d", "Candle-Spine Beast", "boss_07_candle_spine_beast.png"),
    (8, "\u65e0\u9762\u949f\u7ae5", "Faceless Bell Child", "boss_08_faceless_bell_child.png"),
    (9, "\u94c1\u8537\u8587\u5973\u7235", "Iron Rose Baroness", "boss_09_iron_rose_baroness.png"),
    (10, "\u83cc\u5893\u9a6e\u7891\u8005", "Fungus-Tomb Slab Bearer", "boss_10_fungus_tomb_slab_bearer.png"),
    (11, "\u91d1\u7fc5\u9a8c\u5c38\u5b98", "Gilded-Wing Coroner", "boss_11_gilded_wing_coroner.png"),
    (12, "\u7ee3\u9aa8\u5723\u5f92", "Embroidered Bone Saint", "boss_12_embroidered_bone_saint.png"),
    (13, "\u9ed1\u949f\u9a91\u58eb", "Black Bell Knight", "boss_13_black_bell_knight.png"),
    (14, "\u96e8\u5eca\u76f2\u4e50\u5e08", "Blind Musician of the Rain Corridor", "boss_14_blind_musician_rain_corridor.png"),
    (15, "\u8d64\u8327\u4ea7\u5a46", "Red Cocoon Midwife", "boss_15_red_cocoon_midwife.png"),
    (16, "\u65ad\u9636\u5de1\u793c\u738b", "Broken-Stair Pilgrim King", "boss_16_broken_stair_pilgrim_king.png"),
    (17, "\u94f6\u69f2\u9e7f\u7075", "Silver Oak Stag Spirit", "boss_17_silver_oak_stag_spirit.png"),
    (18, "\u7802\u6f0f\u4fee\u5973", "Hourglass Nun", "boss_18_hourglass_nun.png"),
    (19, "\u9752\u7130\u5893\u949f", "Blueflame Grave Bell", "boss_19_blueflame_grave_bell.png"),
    (20, "\u7eef\u5ead\u7ec8\u793c\u8005", "Final Rite Officiant of the Crimson Court", "boss_20_final_rite_officiant_crimson_court.png"),
]


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def build_entries() -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for index, name_zh, name_en, filename in BOSSES:
        entries.append(
            {
                "id": f"boss_{index:02d}",
                "name_zh": name_zh,
                "name_en": name_en,
                "file": f"artifacts/boss_concepts/images/{filename}",
                "style": "high quality dark fantasy concept art, non-pixel",
                "usage": "boss concept art / future cutout reference / Godot integration candidate",
            }
        )
    return entries


def write_contact_sheet(entries: list[dict[str, str]]) -> Path:
    font_title = load_font(22)
    font_small = load_font(15)
    thumb_w, thumb_h = 320, 220
    label_h = 54
    cols = 4
    rows = 5
    sheet = Image.new("RGB", (cols * thumb_w, rows * (thumb_h + label_h)), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)

    for index, entry in enumerate(entries):
        path = ROOT / entry["file"]
        image = Image.open(path).convert("RGB")
        image.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        col = index % cols
        row = index // cols
        x = col * thumb_w
        y = row * (thumb_h + label_h)
        sheet.paste(image, (x + (thumb_w - image.width) // 2, y + (thumb_h - image.height) // 2))
        draw.rectangle((x, y, x + thumb_w - 1, y + thumb_h + label_h - 1), outline=(66, 69, 78), width=1)
        draw.text((x + 10, y + thumb_h + 6), f"{entry['id']} {entry['name_zh']}", fill=(240, 226, 190), font=font_title)
        draw.text((x + 10, y + thumb_h + 32), entry["name_en"][:36], fill=(166, 180, 190), font=font_small)

    CONTACT_DIR.mkdir(parents=True, exist_ok=True)
    contact_path = CONTACT_DIR / "boss_concepts_contact_sheet.png"
    sheet.save(contact_path, quality=95)
    return contact_path


def write_index(entries: list[dict[str, str]]) -> Path:
    index_path = ROOT / "artifacts" / "boss_concepts" / "boss_concepts_index.json"
    index_path.write_text(json.dumps({"count": len(entries), "entries": entries}, ensure_ascii=False, indent=2), encoding="utf-8")
    return index_path


def write_spec_doc(entries: list[dict[str, str]], contact_path: Path, index_path: Path) -> Path:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d%H%M%S") + f"{now.microsecond // 1000:03d}"
    doc_path = DOCS_DIR / f"{timestamp}_20\u4e2aBoss\u9ad8\u8d28\u91cf\u975e\u50cf\u7d20\u7d20\u6750\u89c4\u683c.md"
    lines = [
        "# 20\u4e2aBoss\u9ad8\u8d28\u91cf\u975e\u50cf\u7d20\u7d20\u6750\u89c4\u683c",
        "",
        "\u7ed3\u679c\uff1a\u5df2\u751f\u6210 20 \u5f20\u539f\u521b Boss \u9ad8\u8d28\u91cf\u6982\u5ff5\u7d20\u6750\u56fe\uff0c\u7edf\u4e00\u4e3a\u6697\u8272\u5947\u5e7b\u3001\u975e\u50cf\u7d20\u3001\u5168\u8eab/3/4 \u5168\u8eab\u7acb\u7ed8\u65b9\u5411\u3002",
        "",
        f"- \u56fe\u7247\u76ee\u5f55\uff1a`{IMAGE_DIR.as_posix()}`",
        f"- \u603b\u89c8\u56fe\uff1a`{contact_path.as_posix()}`",
        f"- JSON \u7d22\u5f15\uff1a`{index_path.as_posix()}`",
        "",
        "## \u7edf\u4e00\u89c4\u683c",
        "",
        "- \u98ce\u683c\uff1ahigh quality dark fantasy action game concept art, painterly-realistic, premium 2D boss asset\u3002",
        "- \u6784\u56fe\uff1asingle boss only, full body \u6216 3/4 full body\uff0c\u5e72\u51c0\u6df1\u8272\u80cc\u666f\uff0c\u4fbf\u4e8e\u540e\u7eed\u62a0\u56fe\u3002",
        "- \u907f\u514d\uff1apixel art\u3001chibi\u3001cute\u3001low-res\u3001blurry\u3001text\u3001watermark\u3001logo\u3001UI\u3001cropped limbs\u3002",
        "",
        "## \u7d20\u6750\u6e05\u5355",
        "",
    ]
    for entry in entries:
        lines.append(f"- {entry['id']}\uff1a{entry['name_zh']} / {entry['name_en']} -> `{entry['file']}`")
    lines.extend(
        [
            "",
            "## \u5907\u6ce8",
            "",
            "- \u5f53\u524d\u4e3a\u6982\u5ff5\u7d20\u6750\u56fe\uff0c\u8fd8\u672a\u63a5\u5165 Godot runtime\u3002",
            "- \u82e5\u540e\u7eed\u8981\u505a\u6e38\u620f\u5185\u900f\u660e\u7acb\u7ed8/\u52a8\u753b\u5e27\uff0c\u5efa\u8bae\u4ece\u8fd9\u4e9b\u56fe\u4e2d\u9009\u5b9a Boss \u540e\u518d\u5355\u72ec\u505a\u62a0\u56fe\u3001\u62c6\u4ef6\u3001\u52a8\u4f5c\u8bbe\u8ba1\u3002",
        ]
    )
    doc_path.write_text("\n".join(lines), encoding="utf-8")
    return doc_path


def validate(entries: list[dict[str, str]]) -> list[tuple[str, tuple[int, int]]]:
    bad: list[tuple[str, tuple[int, int]]] = []
    for entry in entries:
        image = Image.open(ROOT / entry["file"])
        if image.width < 512 or image.height < 512:
            bad.append((entry["id"], image.size))
    return bad


def main() -> None:
    entries = build_entries()
    contact_path = write_contact_sheet(entries)
    index_path = write_index(entries)
    doc_path = write_spec_doc(entries, contact_path, index_path)
    bad = validate(entries)
    print(
        "BOSS_CONCEPT_ASSETS_PASS "
        f"count={len(entries)} contact={contact_path} index={index_path} doc={doc_path} bad_sizes={bad}"
    )


if __name__ == "__main__":
    main()

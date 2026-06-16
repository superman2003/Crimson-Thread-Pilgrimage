from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(r"D:\CrimsonThreadOdysseyAssets_v2")
SOURCE = ROOT / "01_characters_redesign" / "lumen_spoolwright_original_character_sheet.png"
OUT_DIR = ROOT / "01_characters_redesign_split"
POSES = [
    "idle",
    "run",
    "jump",
    "wall_cling",
    "thread_chakram_attack",
    "portrait_bust",
]


def main() -> None:
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    with Image.open(SOURCE) as img:
        cell_w = img.width // 3
        cell_h = img.height // 2
        for index, pose in enumerate(POSES):
            col = index % 3
            row = index // 3
            left = col * cell_w
            top = row * cell_h
            right = img.width if col == 2 else (col + 1) * cell_w
            bottom = img.height if row == 1 else (row + 1) * cell_h
            img.crop((left, top, right, bottom)).save(OUT_DIR / f"lumen_{index + 1:02d}_{pose}.png")
    print("SPLIT_LUMEN_CHARACTER_PASS")


if __name__ == "__main__":
    main()

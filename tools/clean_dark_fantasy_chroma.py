from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BESTIARY_DIR = ROOT / "godot" / "assets" / "third_party" / "dark_fantasy_bestiary"
CHROMA_KEYS = {
    (0, 0, 255),
    (64, 0, 128),
    (128, 0, 255),
}


def main() -> None:
    changed = 0
    pixels_cleared = 0
    for path in sorted(BESTIARY_DIR.glob("*.png")):
        image = Image.open(path).convert("RGBA")
        data = list(image.getdata())
        next_data = []
        local_cleared = 0
        for r, g, b, a in data:
            if a > 0 and (r, g, b) in CHROMA_KEYS:
                next_data.append((r, g, b, 0))
                local_cleared += 1
            else:
                next_data.append((r, g, b, a))
        if local_cleared <= 0:
            continue
        image.putdata(next_data)
        image.save(path)
        changed += 1
        pixels_cleared += local_cleared
        print(f"cleaned {path.name}: {local_cleared} pixels")
    print(f"CLEAN_DARK_FANTASY_CHROMA_PASS files={changed} pixels={pixels_cleared}")


if __name__ == "__main__":
    main()

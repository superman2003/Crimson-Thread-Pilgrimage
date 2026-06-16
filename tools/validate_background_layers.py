from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "godot" / "assets" / "sprites" / "gothicvania" / "demo"
MAIN_LEVEL = ROOT / "godot" / "scripts" / "main_level.gd"
BUILD_SCRIPT = ROOT / "tools" / "build_gothicvania_asset_replacements.py"
EXPECTED_SIZE = (8192, 720)
LAYERS = [
    "bg_ch01_sky.png",
    "bg_ch01_far_silhouettes.png",
    "bg_ch01_mid_arches.png",
    "bg_ch01_fog.png",
    "bg_ch01_near_vines.png",
]


def assert_layer(path: Path) -> None:
    if not path.exists():
        raise AssertionError(f"missing background layer: {path.name}")
    image = Image.open(path).convert("RGBA")
    if image.size != EXPECTED_SIZE:
        raise AssertionError(f"{path.name} size {image.size} != {EXPECTED_SIZE}")
    if path.name != "bg_ch01_sky.png" and image.getchannel("A").getbbox() is None:
        raise AssertionError(f"{path.name} is fully transparent")


def main() -> None:
    for name in LAYERS:
        assert_layer(ASSET_DIR / name)

    main_source = MAIN_LEVEL.read_text(encoding="utf-8")
    if 'texture = load(SPRITES["map_background"])' in main_source or "MapBackgroundCh01" in main_source:
        raise AssertionError("runtime still uses the old stretched map background sprite")
    for key in ("bg_sky", "bg_far", "bg_mid", "bg_fog", "bg_near"):
        if f'"{key}"' not in main_source:
            raise AssertionError(f"runtime missing background layer key: {key}")
    if "_background_layer(" not in main_source:
        raise AssertionError("runtime does not build layered background sprites")

    build_source = BUILD_SCRIPT.read_text(encoding="utf-8")
    if "OUT_ROOT = ROOT / \"godot\" / \"assets\" / \"sprites\" / \"gothicvania\"" not in build_source:
        raise AssertionError("background script is not targeting the gothicvania runtime asset tree")

    print("BACKGROUND_LAYER_VALIDATION_PASS layers=5 size=8192x720 single_stretch_removed=true")


if __name__ == "__main__":
    main()

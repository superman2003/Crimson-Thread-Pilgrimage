from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(r"D:\CrimsonThreadOdysseyAssets_v2")

HERO_POSES = ["idle", "dash", "jump", "slide_dash", "slash", "portrait"]
WEAPONS = [
    "thread_needle",
    "bell_sabre",
    "glass_glaive",
    "ember_hook_blade",
    "moon_salt_lance",
    "bone_orchard_claws",
    "starless_core_scythe",
    "furnace_maul",
]
CHAPTERS = [
    ("ch01_moss_bell_court", ["moss_toothed_larva", "bronze_wing_moth", "spore_bellmaker", "gear_sentinel", "rust_crown_guardian_boss"]),
    ("ch02_glass_rain_archive", ["refracted_bird", "glass_footsoldier", "indexing_prism", "mirror_page_lurker", "mirror_rain_librarian_boss"]),
    ("ch03_ember_loom_furnace", ["coal_shell_hound", "fire_shuttle_weaver", "furnace_armored_charger", "ash_ray", "ember_weaving_butcher_boss"]),
    ("ch04_moon_salt_aqueduct", ["tide_ghost_lantern", "salt_shell_cruiser", "moon_canal_flutist", "silver_tide_ambusher", "moon_salt_chanteuse_boss"]),
    ("ch05_bone_branch_sky_orchard", ["bone_swallow", "windbell_watcher", "root_bone_walker", "branch_crown_assassin", "bone_branch_wind_rider_boss"]),
    ("ch06_starless_spindle_core", ["black_thread_cavalry", "star_eclipse_floater", "spindle_core_observer", "dark_pattern_walker", "starless_spinner_boss"]),
]


def main() -> None:
    split_hero()
    split_weapons()
    split_monsters_and_bosses()
    split_environments()
    print("SPLIT_V2_SHEETS_PASS")


def clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def crop_grid(source: Path, out_dir: Path, names: list[str], cols: int, rows: int, prefix: str = "") -> None:
    clean_dir(out_dir)
    with Image.open(source) as img:
        cell_w = img.width // cols
        cell_h = img.height // rows
        for index, name in enumerate(names):
            col = index % cols
            row = index // cols
            left = col * cell_w
            upper = row * cell_h
            right = img.width if col == cols - 1 else (col + 1) * cell_w
            lower = img.height if row == rows - 1 else (row + 1) * cell_h
            crop = img.crop((left, upper, right, lower))
            crop.save(out_dir / f"{prefix}{index + 1:02d}_{name}.png")


def split_hero() -> None:
    crop_grid(
        ROOT / "01_characters" / "hero_linebound_vowkeeper_concept_sheet.png",
        ROOT / "01_characters_split",
        HERO_POSES,
        cols=3,
        rows=2,
        prefix="hero_",
    )


def split_weapons() -> None:
    crop_grid(
        ROOT / "02_weapons" / "weapons_painted_concept_sheet.png",
        ROOT / "02_weapons_split",
        WEAPONS,
        cols=8,
        rows=1,
        prefix="weapon_",
    )


def split_monsters_and_bosses() -> None:
    sources = [
        ROOT / "03_monsters" / "chapters_01_03_monsters_bosses_painted_sheet.png",
        ROOT / "03_monsters" / "chapters_04_06_monsters_bosses_painted_sheet.png",
    ]
    monster_dir = ROOT / "03_monsters_split"
    boss_dir = ROOT / "04_bosses_split"
    clean_dir(monster_dir)
    clean_dir(boss_dir)

    chapter_offset = 0
    for source in sources:
        with Image.open(source) as img:
            cell_w = img.width // 5
            cell_h = img.height // 3
            for row in range(3):
                chapter_id, names = CHAPTERS[chapter_offset + row]
                chapter_dir = monster_dir / chapter_id
                chapter_dir.mkdir(parents=True, exist_ok=True)
                for col, name in enumerate(names):
                    left = col * cell_w
                    upper = row * cell_h
                    right = img.width if col == 4 else (col + 1) * cell_w
                    lower = img.height if row == 2 else (row + 1) * cell_h
                    crop = img.crop((left, upper, right, lower))
                    if name.endswith("_boss"):
                        crop.save(boss_dir / f"{chapter_id}_{name}.png")
                    else:
                        crop.save(chapter_dir / f"{col + 1:02d}_{name}.png")
            chapter_offset += 3


def split_environments() -> None:
    sources = [
        ROOT / "05_chapters" / "chapters_01_03_environment_painted_sheet.png",
        ROOT / "05_chapters" / "chapters_04_06_environment_painted_sheet.png",
    ]
    out_dir = ROOT / "05_chapters_split"
    clean_dir(out_dir)
    chapter_index = 0
    for source in sources:
        with Image.open(source) as img:
            panel_h = img.height // 3
            for row in range(3):
                chapter_id = CHAPTERS[chapter_index][0]
                upper = row * panel_h
                lower = img.height if row == 2 else (row + 1) * panel_h
                crop = img.crop((0, upper, img.width, lower))
                crop.save(out_dir / f"{chapter_id}_environment_panel.png")
                chapter_index += 1


if __name__ == "__main__":
    main()

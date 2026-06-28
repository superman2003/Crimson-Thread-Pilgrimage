from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
BOSS_ROOT = GODOT_ROOT / "assets" / "sprites" / "bosses"
REGISTRY_PATH = BOSS_ROOT / "boss_asset_registry.json"

RUNTIME_ANIMATIONS = ["idle", "walk", "attack", "hurt", "death"]
WALK_FRAME_COUNT = 16
ATTACK_FRAME_COUNT = 8


def main() -> None:
    manifest_paths = sorted(BOSS_ROOT.glob("boss_*/manifest.json"), key=boss_sort_key)
    if len(manifest_paths) != 20:
        raise AssertionError(f"expected 20 boss manifests, got {len(manifest_paths)}")

    demo_refs = collect_demo_refs()
    entries: list[dict[str, Any]] = []
    for manifest_path in manifest_paths:
        manifest = read_json(manifest_path)
        boss_id = str(manifest["id"])
        slug = manifest_path.parent.name
        attack_ids = [str(attack["id"]) for attack in manifest.get("attacks", [])]
        required_directional = [
            "walk_left",
            "walk_right",
            "attack_left",
            "attack_right",
        ]
        for attack_id in attack_ids:
            required_directional.append(f"{attack_id}_left")
            required_directional.append(f"{attack_id}_right")

        pack = manifest.get("directional_asset_pack", {})
        contact_sheet = str(pack.get("contact_sheet", "")) if isinstance(pack, dict) else ""
        if not contact_sheet:
            contact_sheet = find_contact_sheet(slug, boss_id)

        animations = manifest.get("animations", [])
        entries.append(
            {
                "id": boss_id,
                "slug": slug,
                "name_zh": manifest.get("name_zh", ""),
                "name_en": manifest.get("name_en", ""),
                "manifest": godot_res(manifest_path),
                "source_concept": manifest.get("source_concept", ""),
                "style": manifest.get("style", ""),
                "frame_size": manifest.get("frame_size", []),
                "anchor": manifest.get("anchor", ""),
                "runtime_animations": RUNTIME_ANIMATIONS,
                "required_directional_animations": required_directional,
                "walk_frames_per_direction": int(pack.get("walk_frames_per_direction", WALK_FRAME_COUNT))
                if isinstance(pack, dict)
                else WALK_FRAME_COUNT,
                "attack_frames_per_direction": int(pack.get("attack_frames_per_direction", ATTACK_FRAME_COUNT))
                if isinstance(pack, dict)
                else ATTACK_FRAME_COUNT,
                "contact_sheet": contact_sheet,
                "animation_count": len(animations),
                "total_frame_refs": sum(len(animation.get("frames", [])) for animation in animations),
                "attacks": [
                    {
                        "id": str(attack.get("id", "")),
                        "name_zh": attack.get("name_zh", ""),
                        "name_en": attack.get("name_en", ""),
                        "animation": str(attack.get("id", "")),
                        "left_animation": f"{attack.get('id', '')}_left",
                        "right_animation": f"{attack.get('id', '')}_right",
                        "hit_frame_index": int(attack.get("hit_frame_index", 3)),
                    }
                    for attack in manifest.get("attacks", [])
                ],
                "godot_demo_refs": demo_refs.get(godot_res(manifest_path), []),
            }
        )

    registry = {
        "version": 1,
        "count": len(entries),
        "completed_boss_count": len(entries),
        "frame_size": [256, 256],
        "manifest_root": "res://assets/sprites/bosses",
        "note": "Full Godot boss asset registry. All 20 bosses have manifests, walk keyframes, attack keyframes, and three directional special attacks; godot_demo_refs lists playable chapter usage.",
        "entries": entries,
    }
    REGISTRY_PATH.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"BUILD_BOSS_ASSET_REGISTRY_PASS bosses={len(entries)} registry={rel(REGISTRY_PATH)}")


def collect_demo_refs() -> dict[str, list[dict[str, str]]]:
    refs: dict[str, list[dict[str, str]]] = {}
    for path in sorted((GODOT_ROOT / "data").glob("demo_ch*.json")):
        data = read_json(path)
        for trail, sprite in walk_sprites(data):
            if "res://assets/sprites/bosses/" not in sprite:
                continue
            refs.setdefault(sprite, []).append({"config": path.name, "json_path": trail})
    return refs


def walk_sprites(value: Any, trail: str = "") -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    if isinstance(value, dict):
        for key, child in value.items():
            next_trail = f"{trail}.{key}" if trail else str(key)
            if key == "sprite" and isinstance(child, str):
                found.append((next_trail, child))
            found.extend(walk_sprites(child, next_trail))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(walk_sprites(child, f"{trail}[{index}]"))
    return found


def find_contact_sheet(slug: str, boss_id: str) -> str:
    asset_dir = ROOT / "artifacts" / "boss_keyframes" / slug
    candidates = [
        asset_dir / f"{boss_id}_directional_contact.png",
        asset_dir / f"{boss_id.replace('_', '')}_directional_contact.png",
        asset_dir / f"{boss_id.replace('_', '')}_walk_16f_contact.png",
    ]
    for candidate in candidates:
        if candidate.exists():
            return rel(candidate)
    return ""


def boss_sort_key(path: Path) -> int:
    return int(path.parent.name.split("_", 2)[1])


def godot_res(path: Path) -> str:
    return "res://" + path.resolve().relative_to(GODOT_ROOT).as_posix()


def rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()

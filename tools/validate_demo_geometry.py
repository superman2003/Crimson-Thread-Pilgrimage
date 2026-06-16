from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "godot" / "data" / "demo_ch01_moss_bell_court.json"
PLAYER = ROOT / "godot" / "scripts" / "player_controller.gd"


def rect_top(platform: dict) -> float:
    return float(platform["rect"][1])


def rect_left(platform: dict) -> float:
    return float(platform["rect"][0])


def rect_right(platform: dict) -> float:
    rect = platform["rect"]
    return float(rect[0]) + float(rect[2])


def platform_map(config: dict) -> dict[str, dict]:
    return {str(item["id"]): item for item in config["platforms"]}


def export_value(source: str, name: str) -> float:
    match = re.search(rf"@export var {re.escape(name)}: float = (-?\d+(?:\.\d+)?)", source)
    if match is None:
        raise AssertionError(f"missing exported player value: {name}")
    return float(match.group(1))


def assert_step(platforms: dict[str, dict], from_id: str, to_id: str, max_jump_height: float) -> None:
    delta = rect_top(platforms[from_id]) - rect_top(platforms[to_id])
    if delta > max_jump_height * 0.92:
        raise AssertionError(
            f"{from_id}->{to_id} vertical step {delta:.1f}px exceeds safe jump {max_jump_height * 0.92:.1f}px"
        )


def assert_reachable_step(
    platforms: dict[str, dict],
    from_id: str,
    to_id: str,
    max_jump_height: float,
    max_horizontal_gap: float = 260.0,
) -> None:
    assert_step(platforms, from_id, to_id, max_jump_height)
    gap = max(0.0, rect_left(platforms[to_id]) - rect_right(platforms[from_id]), rect_left(platforms[from_id]) - rect_right(platforms[to_id]))
    if gap > max_horizontal_gap:
        raise AssertionError(f"{from_id}->{to_id} horizontal gap {gap:.1f}px exceeds safe reach {max_horizontal_gap:.1f}px")


def assert_climb_chain(platforms: dict[str, dict], chain: tuple[str, ...], max_jump_height: float) -> None:
    for from_id, to_id in zip(chain, chain[1:]):
        assert_reachable_step(platforms, from_id, to_id, max_jump_height)


def assert_lower_detour_clear(config: dict) -> None:
    gates = {str(item["id"]): item for item in config["locked_gates"]}
    platforms = platform_map(config)
    under_top = rect_top(platforms["under_gate_lip"])
    if "front_gate_locked" in gates:
        gate = gates["front_gate_locked"]["rect"]
        gate_bottom = float(gate[1]) + float(gate[3])
        if under_top - gate_bottom < 80:
            raise AssertionError(f"under-gate detour clearance is only {under_top - gate_bottom:.1f}px")
        return
    outer_top = rect_top(platforms["outer_drop"])
    if outer_top - under_top < 20:
        raise AssertionError(f"lower detour does not descend enough: {outer_top - under_top:.1f}px")


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    player_source = PLAYER.read_text(encoding="utf-8")
    jump_velocity = abs(export_value(player_source, "jump_velocity"))
    gravity = export_value(player_source, "gravity")
    max_jump_height = jump_velocity * jump_velocity / (2 * gravity)
    platforms = platform_map(config)

    for required_id in (
        "start_ground",
        "starter_step",
        "vista_bridge",
        "upper_gate_step",
        "under_gate_lip",
        "outer_drop",
        "gear_lift",
        "mm_route_19_mm_floor",
        "bell_leaf_tangle_mm_floor",
        "bell_leaf_return_step_low",
        "bell_leaf_return_step_high",
    ):
        if required_id not in platforms:
            raise AssertionError(f"missing platform: {required_id}")

    assert_step(platforms, "start_ground", "starter_step", max_jump_height)
    assert_step(platforms, "starter_step", "vista_bridge", max_jump_height)
    assert_step(platforms, "vista_bridge", "upper_gate_step", max_jump_height)
    assert_step(platforms, "upper_gate_step", "under_gate_lip", max_jump_height)
    assert_step(platforms, "outer_drop", "gear_lift", max_jump_height)
    assert_climb_chain(
        platforms,
        ("bell_leaf_tangle_mm_floor", "bell_leaf_return_step_low", "bell_leaf_return_step_high", "mm_route_19_mm_floor"),
        max_jump_height,
    )
    assert_lower_detour_clear(config)
    print(f"DEMO_GEOMETRY_PASS max_jump_height={max_jump_height:.1f}px opening_steps=60px/74px/68px/78px bell_leaf_return=true")


if __name__ == "__main__":
    main()

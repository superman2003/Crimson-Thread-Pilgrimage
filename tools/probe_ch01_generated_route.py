from __future__ import annotations

import json
from collections import deque
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "data" / "generated" / "demo_ch01_moss_bell_court.generated.json"
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "godot_generated_preview"
OUT_PATH = OUT_DIR / "demo_ch01_route_probe.json"


TARGETS = {
    "first_save_overlook": "first_overlook_save_balcony",
    "first_shortcut_lock": "first_backside_shortcut_lock",
    "moss_bell_hub": "moss_bell_court_hub",
    "first_ability": "first_ability_tutorial_span",
    "canopy_shortcut_lever": "canopy_shortcut_lever_room",
    "root_well_miniboss": "root_well_miniboss_foyer",
    "second_ability_lesson": "second_ability_gate_lesson",
    "final_key_memory": "final_key_memory_room",
    "boss_run_save": "boss_run_short_save",
}


def fail(message: str) -> None:
    raise SystemExit(f"route probe failed: {message}")


def load_config() -> dict[str, Any]:
    if not CONFIG_PATH.exists():
        fail(f"missing generated CH01 config: {CONFIG_PATH}")
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8-sig"))


def room_by_setpiece(config: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    for room in config.get("map_rooms", []):
        setpiece = str(room.get("setpiece", ""))
        if setpiece:
            result[setpiece] = str(room.get("id", ""))
    return result


def build_graph(config: dict[str, Any], include_shortcuts: bool) -> dict[str, set[str]]:
    room_ids = {str(room["id"]) for room in config.get("map_rooms", [])}
    graph = {room_id: set() for room_id in room_ids}
    for link in config.get("connections", []):
        a = str(link.get("from", ""))
        b = str(link.get("to", ""))
        if a not in graph or b not in graph:
            continue
        link_type = str(link.get("type", ""))
        graph[a].add(b)
        if link_type != "shortcut" or include_shortcuts:
            graph[b].add(a)
    return graph


def shortest_path(graph: dict[str, set[str]], start: str, target: str) -> list[str]:
    queue: deque[str] = deque([start])
    parent: dict[str, str | None] = {start: None}
    while queue:
        room_id = queue.popleft()
        if room_id == target:
            break
        for nxt in sorted(graph.get(room_id, set())):
            if nxt in parent:
                continue
            parent[nxt] = room_id
            queue.append(nxt)
    if target not in parent:
        return []
    path = [target]
    while parent[path[-1]] is not None:
        path.append(str(parent[path[-1]]))
    path.reverse()
    return path


def room_name_map(config: dict[str, Any]) -> dict[str, str]:
    return {str(room["id"]): str(room.get("name", room["id"])) for room in config.get("map_rooms", [])}


def path_summary(config: dict[str, Any], graph: dict[str, set[str]], start: str, target: str) -> dict[str, Any]:
    names = room_name_map(config)
    path = shortest_path(graph, start, target)
    return {
        "from": start,
        "to": target,
        "steps": max(0, len(path) - 1) if path else None,
        "path": path,
        "path_names": [names.get(room_id, room_id) for room_id in path],
    }


def validate_probe(probe: dict[str, Any]) -> None:
    required_max_steps = {
        "entry_to_first_save_overlook": 2,
        "entry_to_first_shortcut_lock": 6,
        "entry_to_first_ability": 10,
        "first_ability_to_canopy_shortcut_lever": 6,
        "entry_to_root_well_miniboss": 13,
        "entry_to_boss_run_save_after_shortcuts": 18,
        "boss_run_save_to_boss": 3,
    }
    metrics = probe["route_metrics"]
    for key, max_steps in required_max_steps.items():
        steps = metrics.get(key, {}).get("steps")
        if steps is None:
            fail(f"missing route metric {key}")
        if int(steps) > max_steps:
            fail(f"{key} too long: {steps} > {max_steps}")
    if int(probe["shortcut_value"]["total_steps_saved"]) < 8:
        fail("CH01 shortcut compression too weak")
    if int(probe["setpiece_count"]) < 18:
        fail("CH01 setpiece count too low")


def main() -> None:
    config = load_config()
    setpieces = room_by_setpiece(config)
    missing = sorted(set(TARGETS.values()) - set(setpieces))
    if missing:
        fail(f"missing setpieces: {missing}")

    start_room = str(config["map_rooms"][0]["id"])
    boss_room = next(str(room["id"]) for room in config["map_rooms"] if room.get("kind") == "boss")
    no_shortcut_graph = build_graph(config, include_shortcuts=False)
    shortcut_graph = build_graph(config, include_shortcuts=True)
    target_rooms = {key: setpieces[setpiece] for key, setpiece in TARGETS.items()}

    metrics = {
        "entry_to_first_save_overlook": path_summary(config, no_shortcut_graph, start_room, target_rooms["first_save_overlook"]),
        "entry_to_first_shortcut_lock": path_summary(config, no_shortcut_graph, start_room, target_rooms["first_shortcut_lock"]),
        "entry_to_moss_bell_hub": path_summary(config, no_shortcut_graph, start_room, target_rooms["moss_bell_hub"]),
        "entry_to_first_ability": path_summary(config, no_shortcut_graph, start_room, target_rooms["first_ability"]),
        "first_ability_to_canopy_shortcut_lever": path_summary(
            config,
            no_shortcut_graph,
            target_rooms["first_ability"],
            target_rooms["canopy_shortcut_lever"],
        ),
        "entry_to_root_well_miniboss": path_summary(config, no_shortcut_graph, start_room, target_rooms["root_well_miniboss"]),
        "entry_to_second_ability_lesson": path_summary(config, no_shortcut_graph, start_room, target_rooms["second_ability_lesson"]),
        "entry_to_final_key_memory": path_summary(config, no_shortcut_graph, start_room, target_rooms["final_key_memory"]),
        "entry_to_boss_run_save_after_shortcuts": path_summary(config, shortcut_graph, start_room, target_rooms["boss_run_save"]),
        "boss_run_save_to_boss": path_summary(config, shortcut_graph, target_rooms["boss_run_save"], boss_room),
    }

    shortcut_links = [link for link in config.get("connections", []) if str(link.get("type", "")) == "shortcut"]
    shortcut_total_saved = sum(int(link.get("shortcut_value", {}).get("distance_saved", 0)) for link in shortcut_links)
    probe = {
        "ok": True,
        "config": str(CONFIG_PATH),
        "setpiece_count": len([room for room in config.get("map_rooms", []) if room.get("setpiece")]),
        "target_rooms": target_rooms,
        "route_metrics": metrics,
        "shortcut_value": {
            "shortcuts": len(shortcut_links),
            "total_steps_saved": shortcut_total_saved,
            "average_steps_saved": round(shortcut_total_saved / max(1, len(shortcut_links)), 2),
        },
    }
    validate_probe(probe)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(probe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "probe": str(OUT_PATH), "summary": probe["shortcut_value"], "setpiece_count": probe["setpiece_count"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

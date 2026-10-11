## Original, stateful dialogue for the inter-region return journey.
## Does not mutate progress: callers commit completion_flags only after all lines.
class_name WorldNarrative
extends RefCounted

const DATA_PATH := "res://data/world_narrative.json"
var entries: Dictionary = {}

func _init() -> void:
    if FileAccess.file_exists(DATA_PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
        if parsed is Dictionary:
            entries = parsed.get("npcs", {})

func resolve(npc_id: String, fallback_lines: Array, abilities: Array, flags: Dictionary, inventory: Dictionary = {}) -> Dictionary:
    var entry: Dictionary = entries.get(npc_id, {})
    if entry.is_empty():
        return {}
    for variant in entry.get("states", []):
        var state: Dictionary = variant
        if not _matches(state, abilities, flags, inventory):
            continue
        return {"state": String(state.get("id", "world_repeat")), "lines": state.get("lines", fallback_lines).duplicate(), "grant_flags": state.get("grant_flags", []).duplicate(), "voice_profile": String(entry.get("voice_profile", "warm"))}
    return {}

func _matches(state: Dictionary, abilities: Array, flags: Dictionary, inventory: Dictionary) -> bool:
    for flag in state.get("flags_all", []):
        if not bool(flags.get(String(flag), false)):
            return false
    for flag in state.get("flags_none", []):
        if bool(flags.get(String(flag), false)):
            return false
    for ability in state.get("abilities_all", []):
        if not abilities.has(String(ability)) and not inventory.has(String(ability)):
            return false
    var items: Array = state.get("items_any", [])
    if not items.is_empty():
        var found := false
        for item in items:
            found = found or int(inventory.get(String(item), 0)) > 0
        if not found:
            return false
    return true

## Pass the zero-based displayed line index. Reopening before the end never
## completes a quest, and repeated conversations cannot manufacture new rewards.
static func completion_flags(result: Dictionary, displayed_index: int, flags: Dictionary) -> Array:
    var lines: Array = result.get("lines", [])
    if lines.is_empty() or displayed_index < lines.size() - 1:
        return []
    var fresh: Array = []
    for flag in result.get("grant_flags", []):
        if not bool(flags.get(String(flag), false)):
            fresh.append(String(flag))
    return fresh

## Reading estimate for subtitle pacing; never auto-advances a conversation.
static func subtitle_duration(line: String) -> float:
    var pauses := 0
    for mark in ["，", "。", "？", "！", "；", "…"]:
        pauses += line.count(mark)
    return clampf(float(line.length()) / 17.0 + float(pauses) * 0.16, 0.55, 5.0)

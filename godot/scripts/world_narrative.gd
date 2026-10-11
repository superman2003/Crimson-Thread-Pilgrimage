## Original, stateful dialogue for the inter-region return journey.
## Does not mutate progress: callers commit completion_flags only after all lines.
class_name WorldNarrative
extends RefCounted

const DATA_PATH := "res://data/world_narrative.json"
var entries: Dictionary = {}
var story_data: Dictionary = {}

func _init() -> void:
    if FileAccess.file_exists(DATA_PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
        if parsed is Dictionary:
            story_data = parsed
            entries = parsed.get("npcs", {})

func resolve(npc_id: String, fallback_lines: Array, abilities: Array, flags: Dictionary, inventory: Dictionary = {}) -> Dictionary:
    var entry: Dictionary = entries.get(npc_id, {})
    if entry.is_empty():
        return {}
    for variant in entry.get("states", []):
        var state: Dictionary = variant
        if not _matches(state, abilities, flags, inventory):
            continue
        return {"state": String(state.get("id", "world_repeat")), "lines": state.get("lines", fallback_lines).duplicate(), "grant_flags": state.get("grant_flags", []).duplicate(), "grant_rewards": state.get("grant_rewards", {}).duplicate(true), "reward_flag": String(state.get("reward_flag", "")), "voice_profile": String(entry.get("voice_profile", "warm")), "response": String(state.get("response", ""))}
    return {}

func _matches(state: Dictionary, abilities: Array, flags: Dictionary, inventory: Dictionary) -> bool:
    for flag in state.get("flags_all", []):
        if not bool(flags.get(String(flag), false)):
            return false
    for flag in state.get("flags_none", []):
        if bool(flags.get(String(flag), false)):
            return false
    var flags_any: Array = state.get("flags_any", [])
    if not flags_any.is_empty():
        var any_flag := false
        for flag in flags_any:
            any_flag = any_flag or bool(flags.get(String(flag), false))
        if not any_flag:
            return false
    for item in state.get("items_all", []):
        if int(inventory.get(String(item), 0)) <= 0:
            return false
    for ability in state.get("abilities_all", []):
        if not abilities.has(String(ability)) and int(inventory.get(String(ability), 0)) <= 0:
            return false
    if int(state.get("evidence_min", 0)) > int(evaluate_evidence(inventory, flags).get("acquired_count", 0)):
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
    var reward_flag := String(result.get("reward_flag", ""))
    if not reward_flag.is_empty() and not bool(flags.get(reward_flag, false)):
        fresh.append(reward_flag)
    return fresh

## Read rewards before committing completion_flags. The same persistent marker
## guards both the quest and its reward; callers save the resulting transaction.
static func completion_rewards(result: Dictionary, displayed_index: int, flags: Dictionary) -> Dictionary:
    var reward_flag := String(result.get("reward_flag", ""))
    if reward_flag.is_empty() or bool(flags.get(reward_flag, false)):
        return {}
    var lines: Array = result.get("lines", [])
    if lines.is_empty() or displayed_index < lines.size() - 1:
        return {}
    return result.get("grant_rewards", {}).duplicate(true)

## Evidence does not depend on conversation order or optional quest completion.
## Possession, not a zero-count inventory key or a stale flag, proves discovery.
func evaluate_evidence(inventory: Dictionary, flags: Dictionary = {}) -> Dictionary:
    var evidence_entries: Array = []
    var fresh_flags: Array = []
    var acquired_count := 0
    for value in story_data.get("evidence", []):
        var entry: Dictionary = value.duplicate(true)
        var acquired := false
        for source in entry.get("items_any", []):
            acquired = acquired or int(inventory.get(String(source), 0)) > 0
        entry["acquired"] = acquired
        evidence_entries.append(entry)
        if acquired:
            acquired_count += 1
            var flag := "evidence_read_%s" % String(entry.get("id", ""))
            if not bool(flags.get(flag, false)):
                fresh_flags.append(flag)
    var complete := evidence_entries.size() == 6 and acquired_count == 6
    if complete and not bool(flags.get("true_ending_testimony_complete", false)):
        fresh_flags.append("true_ending_testimony_complete")
    return {"entries": evidence_entries, "acquired_count": acquired_count, "complete": complete, "grant_flags": fresh_flags}

func evaluate_progress(inventory: Dictionary, flags: Dictionary = {}) -> Dictionary:
    return evaluate_evidence(inventory, flags)

## Journal rows come from the same save flags and inventory as NPC decisions.
## Unseen optional quests are omitted so reading the UI does not reveal secrets.
func quest_journal(inventory: Dictionary, flags: Dictionary) -> Array:
    var rows: Array = []
    for value in story_data.get("quests", []):
        var quest: Dictionary = value
        var complete := bool(flags.get(String(quest.get("complete_flag", "")), false))
        var started := bool(flags.get(String(quest.get("started_flag", "")), false))
        if not complete and not started:
            continue
        var steps: Array = []
        var guidance := "已完成；可以在相关城区重逢。" if complete else String(quest.get("description", ""))
        var found_pending := false
        for step_value in quest.get("journal_steps", []):
            var step: Dictionary = step_value
            var done := complete or _matches(step, inventory.keys(), flags, inventory)
            steps.append({"label": String(step.get("label", "")), "complete": done})
            if not done and not found_pending:
                guidance = String(step.get("hint", step.get("label", "")))
                found_pending = true
        rows.append({"id": quest.get("id", ""), "title": quest.get("title", ""), "status": "complete" if complete else "active", "description": quest.get("description", ""), "steps": steps, "guidance": guidance, "reward_claimed": bool(flags.get(String(quest.get("reward_flag", "")), false))})
    return rows

## Readable requirement records support both gate rejection and the journal.
## All methods here are pure: only the runtime caller may commit a choice.
func evaluate_ending(ending_id: String, inventory: Dictionary, flags: Dictionary) -> Dictionary:
    var endings: Dictionary = story_data.get("endings", {})
    var entry: Dictionary = endings.get(ending_id, {})
    if entry.is_empty():
        return {"available": false, "missing": [{"id": ending_id, "label": "未知结局", "kind": "ending"}], "grant_flags": [], "consequences": {}}
    var missing: Array = []
    var chosen := String(flags.get("ending_chosen", ""))
    if not chosen.is_empty() and chosen != ending_id:
        missing.append({"id": "ending_chosen", "label": "已选择另一结局", "kind": "choice"})
    if not bool(flags.get("boss_down_ch06", false)):
        missing.append({"id": "boss_down_ch06", "label": "击败无声王冠", "kind": "flag"})
    if bool(entry.get("requires_evidence", false)):
        for evidence in evaluate_evidence(inventory, flags).get("entries", []):
            if not bool(evidence.get("acquired", false)):
                missing.append({"id": evidence.get("id", ""), "label": evidence.get("title", ""), "kind": "evidence", "region": evidence.get("region", ""), "hint": evidence.get("location_hint", "")})
    var grant_flags: Array = []
    if missing.is_empty() and chosen.is_empty():
        grant_flags.append(ending_id + "_done")
        for flag in entry.get("consequence_flags", []):
            if not bool(flags.get(String(flag), false)):
                grant_flags.append(String(flag))
    return {"id": ending_id, "title": entry.get("title", ending_id), "available": missing.is_empty(), "missing": missing, "grant_flags": grant_flags, "consequences": entry.get("consequences", {}).duplicate(true), "message": entry.get("message", ""), "already_chosen": chosen == ending_id}

## A physical relocation is staged by the level; this state remains saveable
## and gives the destination explicitly rather than only promising migration.
func npc_world_state(npc_id: String, flags: Dictionary) -> Dictionary:
    var entry: Dictionary = entries.get(npc_id, {})
    for value in entry.get("world_states", []):
        var state: Dictionary = value
        if _matches(state, [], flags, {}):
            return state.duplicate(true)
    return {}

## Reading estimate for subtitle pacing; never auto-advances a conversation.
static func subtitle_duration(line: String) -> float:
    var pauses := 0
    for mark in ["，", "。", "？", "！", "；", "…"]:
        pauses += line.count(mark)
    return clampf(float(line.length()) / 17.0 + float(pauses) * 0.16, 0.55, 5.0)

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
    var effective_flags := _effective_flags(flags)
    # Recover a partially written/legacy save where the quest completion marker
    # survived but its one-time reward marker did not. This reward state must win
    # over later aftermath/repeat dialogue, even if its original item was consumed.
    for variant in entry.get("states", []):
        var pending_reward_state: Dictionary = variant
        if _has_unclaimed_completed_reward(pending_reward_state, effective_flags):
            return _state_result(entry, pending_reward_state, fallback_lines)
    # An ending must not swallow a remaining quest or an earned seal unlock.
    # Only explicitly authored continuations with a fresh commit may preempt
    # aftermath; repeat conversations return to the selected world's response.
    if not _resolved_ending_choice(flags).is_empty():
        for variant in entry.get("states", []):
            var continuation: Dictionary = variant
            if not bool(continuation.get("continues_after_ending", false)) or not _matches(continuation, abilities, effective_flags, inventory):
                continue
            var outcome := completion_outcome(continuation, continuation.get("lines", []).size() - 1, effective_flags)
            if not outcome.get("flags", []).is_empty():
                return _state_result(entry, continuation, fallback_lines)
    for variant in entry.get("states", []):
        var state: Dictionary = variant
        if not _matches(state, abilities, effective_flags, inventory):
            continue
        return _state_result(entry, state, fallback_lines)
    return {}

func _state_result(entry: Dictionary, state: Dictionary, fallback_lines: Array) -> Dictionary:
    return {"state": String(state.get("id", "world_repeat")), "lines": state.get("lines", fallback_lines).duplicate(), "grant_flags": state.get("grant_flags", []).duplicate(), "grant_rewards": state.get("grant_rewards", {}).duplicate(true), "reward_flag": String(state.get("reward_flag", "")), "voice_profile": String(entry.get("voice_profile", "warm")), "response": String(state.get("response", ""))}

func _has_unclaimed_completed_reward(state: Dictionary, flags: Dictionary) -> bool:
    var reward_flag := String(state.get("reward_flag", ""))
    if reward_flag.is_empty() or bool(flags.get(reward_flag, false)) or state.get("grant_rewards", {}).is_empty():
        return false
    for value in state.get("grant_flags", []):
        var flag := String(value)
        if flag.begins_with("quest_") and flag.ends_with("_complete") and bool(flags.get(flag, false)):
            return true
    return false

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
        # Runtime passes inventory.keys() as its ability list. A stale zero key
        # must not turn into a learned ability through that convenience array.
        var learned := int(inventory.get(String(ability), 0)) > 0 if inventory.has(String(ability)) else abilities.has(String(ability))
        if not learned:
            return false
    if int(state.get("evidence_min", 0)) > int(_calculate_evidence(inventory, flags).get("acquired_count", 0)):
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
    return completion_outcome(result, displayed_index, flags).get("flags", [])

## Read rewards before committing completion_flags. The same persistent marker
## guards both the quest and its reward; callers save the resulting transaction.
static func completion_rewards(result: Dictionary, displayed_index: int, flags: Dictionary) -> Dictionary:
    return completion_outcome(result, displayed_index, flags).get("rewards", {})

## Single pure transaction evaluation for interrupted, complete, and repeat visits.
## Runtime callers commit `flags` and `rewards` together with their save operation.
static func completion_outcome(result: Dictionary, displayed_index: int, flags: Dictionary) -> Dictionary:
    var lines: Array = result.get("lines", [])
    var complete := not lines.is_empty() and displayed_index >= lines.size() - 1
    if not complete:
        return {"complete": false, "flags": [], "rewards": {}}
    var fresh: Array = []
    for value in result.get("grant_flags", []):
        var flag := String(value)
        if not flag.is_empty() and not bool(flags.get(flag, false)) and not fresh.has(flag):
            fresh.append(flag)
    var reward_flag := String(result.get("reward_flag", ""))
    var rewards: Dictionary = {}
    if not reward_flag.is_empty() and not bool(flags.get(reward_flag, false)):
        if not fresh.has(reward_flag):
            fresh.append(reward_flag)
        rewards = result.get("grant_rewards", {}).duplicate(true)
    return {"complete": true, "flags": fresh, "rewards": rewards}

## Evidence does not depend on conversation order or optional quest completion.
## Possession, not a zero-count inventory key or a stale flag, proves discovery.
func _calculate_evidence(inventory: Dictionary, flags: Dictionary = {}) -> Dictionary:
    var evidence_entries: Array = []
    var fresh_flags: Array = []
    var acquired_count := 0
    var known_entries: Array = []
    for value in story_data.get("evidence", []):
        var entry: Dictionary = value.duplicate(true)
        var evidence_id := String(entry.get("id", ""))
        var acquired := false
        for source in entry.get("items_any", []):
            acquired = acquired or int(inventory.get(String(source), 0)) > 0
        entry["connections"] = []
        if acquired:
            for link in evidence_connections(inventory):
                if link.get("evidence_all", []).has(evidence_id):
                    entry["connections"].append(String(link.get("text", "")))
        entry["acquired"] = acquired
        entry["known"] = acquired or bool(flags.get("evidence_known_%s" % evidence_id, false)) or bool(flags.get("evidence_read_%s" % evidence_id, false))
        evidence_entries.append(entry)
        if bool(entry["known"]):
            known_entries.append(entry.duplicate(true))
        if acquired:
            acquired_count += 1
            var flag := "evidence_read_%s" % evidence_id
            if not bool(flags.get(flag, false)):
                fresh_flags.append(flag)
    var total := evidence_entries.size()
    var complete := total > 0 and acquired_count == total
    if complete and not bool(flags.get("true_ending_testimony_complete", false)):
        fresh_flags.append("true_ending_testimony_complete")
    return {"entries": evidence_entries, "known_entries": known_entries, "acquired_count": acquired_count, "evidence_total": total, "complete": complete, "grant_flags": fresh_flags}

func evaluate_evidence(inventory: Dictionary, flags: Dictionary = {}) -> Dictionary:
    var evidence := _calculate_evidence(inventory, flags)
    # Public journal rows contain encountered clues only. Internal readiness still
    # evaluates the full authored set from possession via _calculate_evidence().
    evidence["entries"] = evidence.get("known_entries", []).duplicate(true)
    return evidence

func evaluate_progress(inventory: Dictionary, flags: Dictionary = {}) -> Dictionary:
    var evidence := _calculate_evidence(inventory, flags)
    var endings: Array = []
    var selected := _resolved_ending_choice(flags)
    var choice_encountered := bool(flags.get("boss_down_ch06", false)) or not selected.is_empty()
    if choice_encountered:
        var ending_ids: Array[String] = ["ending_a", "ending_b", "ending_c"]
        for ending_id in ending_ids:
            var row := _evaluate_ending(ending_id, inventory, flags, evidence)
            row["chosen"] = String(row.get("id", "")) == selected and not selected.is_empty()
            if bool(row["chosen"]):
                row["status"] = "chosen"
                row["aftermath_rows"] = aftermath_rows(flags)
            elif not selected.is_empty():
                row["status"] = "closed"
            else:
                row["status"] = "ready" if bool(row.get("available", false)) else "locked"
            endings.append(row)
    var quest_rows := quest_journal(inventory, flags)
    return {
		"entries": evidence.get("known_entries", []),
        "known_entries": evidence.get("known_entries", []),
        "acquired_count": evidence.get("acquired_count", 0),
        "evidence_count": evidence.get("acquired_count", 0),
        "evidence_total": evidence.get("evidence_total", 0),
        "complete": evidence.get("complete", false),
        "evidence_complete": evidence.get("complete", false),
        "grant_flags": evidence.get("grant_flags", []),
        "quests": quest_rows,
        "endings": endings,
        "ending_choices_encountered": choice_encountered,
        "ending_chosen": selected,
        "main_line": main_line(inventory, flags, evidence)
    }

## Cross-reading never exposes an undiscovered proof, even if the caller has
## persisted knowledge flags. It follows current possession like ending C.
func evidence_connections(inventory: Dictionary) -> Array:
    var rows: Array = []
    for value in story_data.get("evidence_links", []):
        var link: Dictionary = value
        var ready := true
        for evidence_id in link.get("evidence_all", []):
            var found := false
            for evidence_value in story_data.get("evidence", []):
                var evidence_entry: Dictionary = evidence_value
                if String(evidence_entry.get("id", "")) != String(evidence_id):
                    continue
                for source in evidence_entry.get("items_any", []):
                    found = found or int(inventory.get(String(source), 0)) > 0
            ready = ready and found
        if ready:
            rows.append(link.duplicate(true))
    return rows

func consequence_rows(consequences: Dictionary) -> Array:
    var rows: Array = []
    for key in consequences:
        var entry: Dictionary = entries.get(String(key), {})
        rows.append({"id": String(key), "title": "六城" if String(key) == "world" else String(entry.get("display_name", "旅途中相识的人")), "text": String(consequences[key])})
    return rows

## N05: the main line as the journal shows it, from the same save flags as the
## gates: guardians beaten, the crown, testimonies and the choice itself.
func main_line(inventory: Dictionary, flags: Dictionary, evidence: Dictionary = {}) -> Dictionary:
    if evidence.is_empty():
        evidence = _calculate_evidence(inventory, flags)
    # Counts only: naming unbeaten regions would reveal places not yet reached.
    var beaten := 0
    for index in range(1, 6):
        if bool(flags.get("boss_down_ch%02d" % index, false)):
            beaten += 1
    var crown := bool(flags.get("boss_down_ch06", false))
    var found := int(evidence.get("acquired_count", 0))
    var total := int(evidence.get("evidence_total", 6))
    var selected := _resolved_ending_choice(flags)
    var title := String(story_data.get("endings", {}).get(selected, {}).get("title", ""))
    var steps: Array = [
        {"label": "五区守门者：已击败 %d / 5" % beaten, "complete": beaten >= 5},
        {"label": "无声王冠：" + ("已击败" if crown else "未击败"), "complete": crown},
        {"label": "证词：已取得 %d / %d；集齐后，第三扇结局门可以打开" % [found, total], "complete": found >= total},
        {"label": "结局：" + ("已选择「%s」" % title if not selected.is_empty() else "尚未选择"), "complete": not selected.is_empty()},
    ]
    var guidance := "选择已经做出；回到各区看看它留下了什么。" if not selected.is_empty() else ("王冠已倒，结局之门在六印前廊等你。" if crown else "继续探索，击败守门者，前往无声王冠。")
    return {"id": "main_line", "title": String(story_data.get("main_story", {}).get("title", "主线")), "goal": String(story_data.get("main_story", {}).get("protagonist_goal", "")), "steps": steps, "guidance": guidance}

## N05: what the chosen ending changed at this region's shrine; {} before a choice.
func aftermath_scene(region_id: String, flags: Dictionary) -> Dictionary:
    var selected := _resolved_ending_choice(flags)
    if selected.is_empty():
        return {}
    for scene in story_data.get("aftermath_scenes", []):
        if String(scene.get("region", "")) != region_id.trim_prefix("demo_"):
            continue
        var variant: Dictionary = scene.get("endings", {}).get(selected, {})
        if variant.is_empty():
            return {}
        var result: Dictionary = variant.duplicate(true)
        result.merge({"region": String(scene.region), "region_name": String(scene.get("region_name", "")), "anchor": String(scene.get("anchor", "")), "ending": selected,
            "seen_flag": "aftermath_seen_" + String(scene.region)}, true)
        return result
    return {}

## Every region's change under the chosen ending; unseen ones only say where to look.
func aftermath_rows(flags: Dictionary) -> Array:
    var rows: Array = []
    for scene in story_data.get("aftermath_scenes", []):
        var row := aftermath_scene(String(scene.get("region", "")), flags)
        if row.is_empty():
            continue
        row["seen"] = bool(flags.get(String(row.seen_flag), false))
        rows.append(row)
    return rows

## Normalize only ending-owned fields. A unique legacy marker is recoverable;
## conflicting legacy markers have no authority to silently select a branch.
func restored_ending_flags(flags: Dictionary) -> Dictionary:
    var restored := flags.duplicate(true)
    var selected := _resolved_ending_choice(flags)
    restored.erase("ending_chosen")
    restored.erase("ending_consequences")
    for ending_id in story_data.get("endings", {}):
        restored.erase(String(ending_id) + "_done")
        for flag in story_data.endings[ending_id].get("consequence_flags", []):
            restored.erase(String(flag))
    if not selected.is_empty():
        restored["ending_chosen"] = selected
        restored[selected + "_done"] = true
        var ending: Dictionary = story_data.get("endings", {}).get(selected, {})
        restored["ending_consequences"] = ending.get("consequences", {}).duplicate(true)
        for flag in ending.get("consequence_flags", []):
            restored[String(flag)] = true
    return restored

## Journal rows come from the same save flags and inventory as NPC decisions.
## Unseen optional quests are omitted so reading the UI does not reveal secrets.
func quest_journal(inventory: Dictionary, flags: Dictionary) -> Array:
    var rows: Array = []
    var effective_flags := _effective_flags(flags)
    for value in story_data.get("quests", []):
        var quest: Dictionary = value
        var complete := bool(effective_flags.get(String(quest.get("complete_flag", "")), false))
        var started := bool(effective_flags.get(String(quest.get("started_flag", "")), false))
        if not complete and not started:
            continue
        var steps: Array = []
        var guidance := "已完成；可以在相关城区重逢。" if complete else String(quest.get("description", ""))
        var found_pending := false
        for step_value in quest.get("journal_steps", []):
            var step: Dictionary = step_value
            var done := complete or _matches(step, inventory.keys(), effective_flags, inventory)
            steps.append({"label": String(step.get("label", "")), "complete": done})
            if not done and not found_pending:
                guidance = String(step.get("hint", step.get("label", "")))
                found_pending = true
        rows.append({"id": quest.get("id", ""), "title": quest.get("title", ""), "status": "complete" if complete else "active", "description": quest.get("description", ""), "steps": steps, "guidance": guidance, "reward_claimed": bool(effective_flags.get(String(quest.get("reward_flag", "")), false))})
    return rows

## Readable requirement records support both gate rejection and the journal.
## All methods here are pure: only the runtime caller may commit a choice.
func evaluate_ending(ending_id: String, inventory: Dictionary, flags: Dictionary) -> Dictionary:
    return _evaluate_ending(ending_id, inventory, flags, _calculate_evidence(inventory, flags))

func _evaluate_ending(ending_id: String, inventory: Dictionary, flags: Dictionary, evidence: Dictionary) -> Dictionary:
    var endings: Dictionary = story_data.get("endings", {})
    var entry: Dictionary = endings.get(ending_id, {})
    if entry.is_empty():
        return {"available": false, "missing": [{"id": ending_id, "label": "未知结局", "kind": "ending"}], "grant_flags": [], "consequences": {}}
    var missing: Array = []
    var chosen := _resolved_ending_choice(flags)
    if not chosen.is_empty() and chosen != ending_id:
        missing.append({"id": "ending_chosen", "label": "已选择另一结局", "kind": "choice"})
    if not bool(flags.get("boss_down_ch06", false)):
        missing.append({"id": "boss_down_ch06", "label": "击败无声王冠", "kind": "flag"})
    if bool(entry.get("requires_evidence", false)):
        for evidence_value in evidence.get("entries", []):
            var evidence_entry: Dictionary = evidence_value
            if not bool(evidence_entry.get("acquired", false)):
                missing.append({"id": evidence_entry.get("id", ""), "label": evidence_entry.get("title", ""), "kind": "evidence", "region": evidence_entry.get("region", ""), "hint": evidence_entry.get("location_hint", "")})
    var known_missing: Array = []
    var hidden_missing_count := 0
    for requirement_value in missing:
        var requirement: Dictionary = requirement_value
        if String(requirement.get("kind", "")) != "evidence":
            known_missing.append(requirement.duplicate(true))
            continue
        var evidence_id := String(requirement.get("id", ""))
        var is_known := false
        for evidence_value in evidence.get("entries", []):
            var evidence_entry: Dictionary = evidence_value
            if String(evidence_entry.get("id", "")) == evidence_id:
                is_known = bool(evidence_entry.get("known", false))
                break
        if is_known:
            known_missing.append(requirement.duplicate(true))
        else:
            hidden_missing_count += 1
    var grant_flags: Array = []
    # A saved choice is already committed. Readiness remains queryable for the
    # selected branch, but only an unchosen branch emits its first commit flags.
    if missing.is_empty() and chosen.is_empty():
        if not bool(flags.get(ending_id + "_done", false)):
            grant_flags.append(ending_id + "_done")
        for flag in entry.get("consequence_flags", []):
            if not bool(flags.get(String(flag), false)):
                grant_flags.append(String(flag))
    var available := missing.is_empty() and (chosen.is_empty() or chosen == ending_id)
    return {"id": ending_id, "title": entry.get("title", ending_id), "available": available, "missing": missing, "known_missing": known_missing, "hidden_missing_count": hidden_missing_count, "grant_flags": grant_flags, "consequences": entry.get("consequences", {}).duplicate(true), "consequence_rows": consequence_rows(entry.get("consequences", {})), "message": entry.get("message", ""), "already_chosen": chosen == ending_id}

func _resolved_ending_choice(flags: Dictionary) -> String:
    var chosen := String(flags.get("ending_chosen", ""))
    if chosen in ["ending_a", "ending_b", "ending_c"]:
        return chosen
    var done_choices: Array[String] = []
    for ending_id in ["ending_a", "ending_b", "ending_c"]:
        if bool(flags.get(ending_id + "_done", false)):
            done_choices.append(ending_id)
    return done_choices[0] if done_choices.size() == 1 else ""

func _effective_flags(flags: Dictionary) -> Dictionary:
    return restored_ending_flags(flags)

## A physical relocation is staged by the level; this state remains saveable
## and gives the destination explicitly rather than only promising migration.
func npc_world_state(npc_id: String, flags: Dictionary) -> Dictionary:
    var entry: Dictionary = entries.get(npc_id, {})
    var effective_flags := _effective_flags(flags)
    for value in entry.get("world_states", []):
        var state: Dictionary = value
        if _matches(state, [], effective_flags, {}):
            return state.duplicate(true)
    return {}

## Reading estimate for subtitle pacing; never auto-advances a conversation.
static func subtitle_duration(line: String) -> float:
    var pauses := 0
    for mark in ["，", "。", "？", "！", "；", "…"]:
        pauses += line.count(mark)
    return clampf(float(line.length()) / 17.0 + float(pauses) * 0.16, 0.55, 5.0)

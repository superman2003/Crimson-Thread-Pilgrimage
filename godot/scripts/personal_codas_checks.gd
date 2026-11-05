extends RefCounted
const NARRATIVE := preload("res://scripts/world_narrative.gd")
const RESPONSE := preload("res://scripts/protagonist_response_memory.gd")
const MEMORY := preload("res://scripts/npc_recollections.gd")
const STATE := preload("res://scripts/world_state.gd")

func pure(tree: SceneTree) -> void:
    var narrative := NARRATIVE.new()
    var codas := 0
    for npc in narrative.entries:
        for row in narrative.entries[npc].states:
            if not row.has("quest_coda"):
                continue
            codas += 1
            var flags := {}
            for flag in row.flags_all:
                flags[String(flag)] = true
            flags["ending_chosen"] = row.ending
            var before := flags.duplicate(true)
            var result: Dictionary = narrative.resolve(String(npc), [], [], flags, {})
            tree.check(result.state == row.id and result.lines == row.lines, "every completed relationship selects its own ending-specific coda")
            tree.check(narrative.completion_outcome(result, 0, flags).flags.is_empty(), "leaving before the final coda line commits nothing")
            tree.check(RESPONSE.quote(String(npc), result, 0, flags, "demo_" + String(narrative.entries[npc].region)).is_empty(), "partial coda reading cannot manufacture a remembered protagonist response")
            for requirement in row.flags_all:
                var missing := flags.duplicate(true)
                missing.erase(String(requirement))
                if String(requirement).ends_with("_done"):
                    missing.erase("ending_chosen")
                tree.check(narrative.resolve(String(npc), [], [], missing, {}).state != row.id, "each quest, reward, migration and selected-ending prerequisite remains necessary")
            for ending in ["ending_a", "ending_b", "ending_c"]:
                if ending == row.ending:
                    continue
                var other := flags.duplicate(true)
                other["ending_chosen"] = ending
                tree.check(narrative.resolve(String(npc), [], [], other, {}).state != row.id, "stale opposing ending flags cannot reveal another world's personal response")
            var outcome: Dictionary = narrative.completion_outcome(result, result.lines.size() - 1, flags)
            tree.check(outcome.flags == row.grant_flags and outcome.rewards.is_empty(), "codas record exactly one fresh narrative marker and no resources")
            var region := "demo_" + String(narrative.entries[npc].region)
            tree.check(not MEMORY.completion_marker(String(npc), result, result.lines.size() - 1, region).is_empty(), "each new conversation fits inside the bounded transcript catalogue")
            tree.check(not RESPONSE.quote(String(npc), result, result.lines.size() - 1, flags, region).is_empty(), "all fifteen new protagonist gestures have exact source-bound memory identities")
            tree.check(flags == before, "pure coda evaluation preserves its input flags")
            flags[String(row.grant_flags[0])] = true
            var repeat: Dictionary = narrative.resolve(String(npc), [], [], flags, {})
            tree.check(String(repeat.state).begins_with("aftermath_"), "a personal coda settles back into the same selected world's ordinary aftermath")
            tree.check(narrative.completion_outcome(result, result.lines.size() - 1, flags).flags.is_empty(), "late repeated completion callbacks cannot grant another coda marker")
            var restored: Dictionary = JSON.parse_string(JSON.stringify(flags))
            tree.check(narrative.resolve(String(npc), [], [], restored, {}).state == repeat.state, "JSON restoration retains completed personal follow-ups")
    tree.check(codas == 15, "all five relationships have distinct responses for all three endings")

func live(tree: SceneTree, world: Node, npc: Area2D) -> void:
    var result: Dictionary = world.world_narrative.resolve("npc_root_prisoner", [], [], world.story_flags, world.inventory_counts)
    tree.check(result.state == "coda_severed", "a real saved rescue and severed-crown ending offer the new west-gate reunion")
    if result.state != "coda_severed":
        return
    var marker := String(result.grant_flags[0])
    var region := String(world.config.id)
    var reply := RESPONSE.quote("npc_root_prisoner", result, result.lines.size() - 1, world.story_flags, region)
    var flags_before: Dictionary = world.story_flags.duplicate(true)
    var inventory_before: Dictionary = world.inventory_counts.duplicate(true)
    var wallet_before: int = world.currency_count
    var position_before: Vector2 = npc.position
    world._talk_to_npc(npc)
    world.dialogue_text_label.visible_characters = 0
    world._commit_world_dialogue()
    world._close_overlays()
    tree.check(world.story_flags == flags_before, "opening and interrupting the actual coda preserves every story flag")
    var disk_before := FileAccess.get_file_as_bytes(world.world_save_path)
    world.world_save_failure_injected_for_validation = true
    tree.hear_round(npc)
    tree.check(world.story_flags == flags_before and not world.story_flags.has(marker), "failed real coda save rolls back the personal marker with the transcript and gesture")
    tree.check(FileAccess.get_file_as_bytes(world.world_save_path) == disk_before, "failed personal follow-up leaves the previous checkpoint bytes intact")
    world.world_save_failure_injected_for_validation = false
    tree.hear_round(npc)
    tree.check(world.story_flags.get(marker, false) and world.story_flags.get(reply.marker, false), "successful retry saves the personal ending and its exact protagonist gesture together")
    tree.check(world.currency_count == wallet_before and world.inventory_counts == inventory_before and npc.position == position_before, "the new reunion neither pays again nor changes possessions or the saved migration")
    var disk := STATE.new()
    tree.check(disk.read(world.world_save_path) and disk.data.story_flags.get(marker, false) and disk.data.story_flags.get(reply.marker, false), "the actual World checkpoint restores both new memory identities")
    var rows := RESPONSE.records(disk.data.story_flags).filter(func(row): return row.id == reply.marker)
    tree.check(rows.size() == 1 and rows[0].voice_context == "确认交谈之后", "the committed gesture returns under the correct journal source category")
    var people := MEMORY.records(disk.data.story_flags).filter(func(row): return row.title == "根笼囚徒")
    tree.check(people.size() == 1 and people[0].description.contains(result.lines.back()), "the real saved NPC transcript also contains the selected personal ending")
    world.ui_shell._show_journal_record(rows[0])
    tree.check(world.ui_shell.bag_category_label.text == "自述 · 确认交谈之后", "the production journal labels the new personal gesture as a confirmed conversation")
    tree.hear_round(npc)
    tree.check(world.currency_count == wallet_before and RESPONSE.records(world.story_flags).filter(func(row): return row.id == reply.marker).size() == 1, "returning after the coda cannot duplicate money or its personal response")

extends SceneTree

const Narrative = preload("res://scripts/world_narrative.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run_checks")

func finish_dialogue(result: Dictionary, flags: Dictionary, displayed_index: int = -1) -> Dictionary:
    var index := displayed_index
    if index < 0:
        index = result.get("lines", []).size() - 1
    var rewards: Dictionary = Narrative.completion_rewards(result, index, flags)
    for flag in Narrative.completion_flags(result, index, flags):
        flags[String(flag)] = true
    return rewards

func run_checks() -> void:
    var narrative := Narrative.new()
    var flags: Dictionary = {}
    var inventory: Dictionary = {}
    check(narrative.evaluate_evidence(inventory).acquired_count == 0, "New save has no fabricated evidence")
    var order: Array = [6, 4, 1, 5, 3, 2]
    for index in range(order.size()):
        inventory["testimony_%02d" % int(order[index])] = 1
        var snapshot: Dictionary = inventory.duplicate(true)
        var result: Dictionary = narrative.evaluate_evidence(inventory, flags)
        check(result.acquired_count == index + 1, "Evidence can be discovered in a non-linear route")
        check(inventory == snapshot and flags.is_empty(), "Evidence evaluation does not mutate progress")
        check(bool(result.complete) == (index == 5), "Completion needs exactly six distinct proofs")
    check(narrative.evaluate_evidence({"testimony_01": 0}).acquired_count == 0, "Zero-count inventory keys are not evidence")
    check(not narrative.evaluate_evidence({}, {"true_ending_testimony_complete": true}).complete, "Stale flags cannot replace evidence")
    check(not narrative.evaluate_ending("ending_c", inventory, flags).available, "Final boss is required despite full evidence")
    flags["boss_down_ch06"] = true
    check(narrative.evaluate_ending("ending_a", {}, flags).available, "Mainline ending A does not depend on optional quests")
    check(narrative.evaluate_ending("ending_b", {}, flags).available, "Mainline ending B does not depend on optional quests")
    var locked: Dictionary = narrative.evaluate_ending("ending_c", {"testimony_06": 1}, flags)
    check(not locked.available and locked.missing.size() == 5, "True ending reports individual missing regions")
    check(not String(locked.missing[0].hint).is_empty(), "Missing evidence carries actionable route guidance")
    var ready: Dictionary = narrative.evaluate_ending("ending_c", inventory, flags)
    check(ready.available and ready.grant_flags.has("world_contract_rewritten"), "All evidence offers concrete persistent aftermath")
    check(not ready.consequences.is_empty(), "Every choice reports NPC and environment consequences")
    check(not flags.has("ending_c_done"), "Inspecting an ending cannot commit it")
    var saved_flags: Dictionary = flags.duplicate(true)
    saved_flags["ending_chosen"] = "ending_b"
    saved_flags["ending_b_done"] = true
    check(not narrative.evaluate_ending("ending_c", inventory, saved_flags).available, "Chosen ending cannot be overwritten")
    check(narrative.evaluate_ending("ending_b", inventory, saved_flags).grant_flags.is_empty(), "Reopening chosen ending cannot duplicate consequence commits")
    check(not narrative.evaluate_ending("unknown", inventory, flags).available, "Unknown choice is rejected")

    var quests: Array = [
        {"npc": "npc_root_prisoner", "ability": "thorn_downstrike", "inventory": {}, "complete": "quest_root_rescue_complete", "reward": "reward_root_rescue_claimed"},
        {"npc": "npc_beeswax_vendor", "ability": "", "inventory": {"pollen_wax": 1}, "complete": "quest_wax_lamps_complete", "reward": "reward_wax_lamps_claimed"},
        {"npc": "npc_lantern_sister", "ability": "lantern_phase", "inventory": {"testimony_05": 1}, "complete": "quest_lantern_watch_complete", "reward": "reward_lantern_watch_claimed"},
        {"npc": "npc_deserter_flagbearer", "ability": "", "inventory": {"silent_order": 1}, "complete": "quest_deserter_order_complete", "reward": "reward_deserter_order_claimed"}
    ]
    for quest in quests:
        var quest_flags: Dictionary = {}
        var abilities: Array = [] if String(quest.ability).is_empty() else [String(quest.ability)]
        var dialogue: Dictionary = narrative.resolve(quest.npc, [], abilities, quest_flags, quest.inventory)
        check(not quest_flags.has(quest.complete), "Opening dialogue cannot complete a quest")
        check(finish_dialogue(dialogue, quest_flags, 0).is_empty(), "Interrupted dialogue cannot grant a reward")
        check(quest_flags.is_empty(), "Interrupted dialogue leaves persistent progress unchanged")
        var reward: Dictionary = finish_dialogue(dialogue, quest_flags)
        check(int(reward.get("currency", 0)) > 0, "Complete quest grants a useful runtime reward")
        check(bool(quest_flags.get(quest.complete, false)) and bool(quest_flags.get(quest.reward, false)), "Quest and claim marker complete together")
        check(Narrative.completion_rewards(dialogue, 99, quest_flags).is_empty(), "Repeated dialogue cannot mint rewards")
        var reloaded: Dictionary = JSON.parse_string(JSON.stringify(quest_flags))
        check(Narrative.completion_flags(dialogue, 99, reloaded).is_empty(), "Reload retains one-time completion guards")
        check(narrative.resolve(quest.npc, [], abilities, reloaded, quest.inventory).state != dialogue.state, "Reload restores completed NPC conversation state")
    var sister_locked: Dictionary = narrative.resolve("npc_lantern_sister", [], [], {}, {"testimony_05": 1})
    check(sister_locked.state == "watch_request", "Lantern quest requires both evidence and real movement ability")
    check(narrative.resolve("npc_root_prisoner", [], [], {}, {"thorn_downstrike": 0}).state == "root_waiting", "Zero-count movement ability cannot rescue")
    check(narrative.npc_world_state("npc_root_prisoner", {"npc_root_prisoner_at_west_gate": true}).room == "west_gate", "Root rescue has a saved relocation destination")
    check(narrative.npc_world_state("npc_deserter_flagbearer", {"npc_deserter_at_camp": true}).room == "pilgrim_camp", "Deserter returns to a saved safe camp")
    check(narrative.resolve("npc_broken_singer", [], [], {"ending_a_done": true}).state == "aftermath_resound", "Ending changes character response")
    check(narrative.resolve("npc_first_pilgrim_echo", [], [], {}, inventory).state == "echo_six", "Protagonist receives original contract at any evidence order")
    var reverse_flags: Dictionary = {}
    var archive_first: Dictionary = narrative.resolve("npc_fugitive_scribe", [], [], reverse_flags, {"testimony_03": 1})
    check(archive_first.state == "names_scribe_evidence", "Archive-first exploration can begin the names quest")
    finish_dialogue(archive_first, reverse_flags)
    var child_second: Dictionary = narrative.resolve("npc_canal_child", [], [], reverse_flags)
    finish_dialogue(child_second, reverse_flags)
    var return_last: Dictionary = narrative.resolve("npc_threadsmith_apprentice", [], [], reverse_flags)
    check(return_last.state == "names_homecoming", "Archive then canal then court completes cross-region quest")
    check(int(finish_dialogue(return_last, reverse_flags).get("currency", 0)) == 40, "Names homecoming has a useful one-time reward")
    check(Narrative.completion_rewards(return_last, 99, reverse_flags).is_empty(), "Returning names cannot duplicate its reward")
    check(narrative.quest_journal({}, {}).is_empty(), "Journal does not reveal unseen optional quests")
    var journal: Array = narrative.quest_journal({}, {"quest_lantern_watch_started": true})
    check(journal.size() == 1 and journal[0].status == "active", "Accepted task appears as active in the journal")
    var updated_journal: Array = narrative.quest_journal({"testimony_05": 1}, {"quest_lantern_watch_started": true})
    check(bool(updated_journal[0].steps[0].complete) and not bool(updated_journal[0].steps[1].complete), "Journal stages derive from actual evidence and ability state")
    check(narrative.quest_journal({}, reverse_flags)[0].status == "complete", "Saved quest completion remains readable")
    print("NARRATIVE_PROGRESSION_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

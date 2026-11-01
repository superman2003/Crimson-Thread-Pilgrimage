extends SceneTree

const NARRATIVE := preload("res://scripts/world_narrative.gd")
const EVIDENCE_ORDERS := [
	[1, 2, 3, 4, 5, 6],
	[6, 5, 4, 3, 2, 1],
	[6, 4, 1, 5, 3, 2],
	[2, 4, 6, 1, 3, 5],
	[3, 1, 5, 2, 6, 4],
	[5, 2, 4, 6, 1, 3]
]

var checks := 0
var failures := 0
var narrative: WorldNarrative

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	narrative = NARRATIVE.new()
	preload("res://scripts/protagonist_response_validation.gd").new().run(narrative,_check)
	_test_evidence_orders_and_visibility()
	print("NARRATIVE_GROUP evidence_visibility checks=%d failures=%d" % [checks, failures])
	_test_reward_transactions_and_recovery()
	print("NARRATIVE_GROUP reward_transactions checks=%d failures=%d" % [checks, failures])
	_test_variable_quest_order()
	print("NARRATIVE_GROUP variable_quest_order checks=%d failures=%d" % [checks, failures])
	_test_ending_world_phase()
	print("NARRATIVE_GROUP ending_world_phase checks=%d failures=%d" % [checks, failures])
	_test_return_journey_contract()
	print("NARRATIVE_OUTCOMES checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_evidence_orders_and_visibility() -> void:
	for order_index in EVIDENCE_ORDERS.size():
		var inventory: Dictionary = {}
		var flags: Dictionary = {"boss_down_ch06": true}
		var order: Array = EVIDENCE_ORDERS[order_index]
		for step in order.size():
			var evidence_id := "testimony_%02d" % int(order[step])
			inventory[evidence_id] = 1
			var before_inventory: Dictionary = inventory.duplicate(true)
			var before_flags: Dictionary = flags.duplicate(true)
			var progress: Dictionary = narrative.evaluate_progress(inventory, flags)
			_check(int(progress.get("evidence_count", -1)) == step + 1,
				"evidence order %d counts only possessed proofs at step %d" % [order_index + 1, step + 1])
			_check(inventory == before_inventory and flags == before_flags,
				"progress evaluation is pure for evidence order %d step %d" % [order_index + 1, step + 1])
			var expected_complete := step == order.size() - 1
			_check(bool(progress.get("evidence_complete", false)) == expected_complete,
				"all six proofs are required for evidence order %d step %d" % [order_index + 1, step + 1])
			if expected_complete:
				_check(progress.get("grant_flags", []).has("true_ending_testimony_complete"),
					"complete evidence emits the legacy branch flag")
				_check(bool(narrative.evaluate_ending("ending_c", inventory, flags).get("available", false)),
					"ending C readiness is independent of evidence order")

	var hidden_progress: Dictionary = narrative.evaluate_progress({}, {})
	_check(hidden_progress.get("endings", []).is_empty(), "ending choices stay hidden before the final boss")
	_check(hidden_progress.get("entries", []).is_empty(), "unencountered evidence titles and hints stay out of the journal")
	_check(hidden_progress.get("quests", []).is_empty(), "unseen optional quests stay hidden")
	var partial_inventory: Dictionary = {"testimony_06": 1}
	var revealed_progress: Dictionary = narrative.evaluate_progress(partial_inventory, {"boss_down_ch06": true})
	_check(revealed_progress.get("endings", []).size() == 3, "all three choices appear after the choice encounter")
	var rewrite_row: Dictionary = _ending_row(revealed_progress.get("endings", []), "ending_c")
	_check(not bool(rewrite_row.get("available", true)) and int(rewrite_row.get("hidden_missing_count", -1)) == 5,
		"locked rewrite reports hidden count without revealing unknown clues")
	_check(rewrite_row.get("known_missing", []).is_empty(), "unknown evidence titles and locations stay hidden")
	_check(revealed_progress.get("known_entries", []).size() == 1,
		"journal progress exposes only an encountered proof")
	var explicit_known: Dictionary = narrative.evaluate_progress(partial_inventory,
		{"boss_down_ch06": true, "evidence_known_testimony_03": true})
	var known_rewrite: Dictionary = _ending_row(explicit_known.get("endings", []), "ending_c")
	_check(known_rewrite.get("known_missing", []).size() == 1 and String(known_rewrite.known_missing[0].id) == "testimony_03",
		"readiness exposes a missing clue only after its clue-known flag")
	_check(not known_rewrite.known_missing[0].hint.is_empty(), "known missing clue carries its actionable hint")
	_check(bool(_ending_row(revealed_progress.endings, "ending_a").available), "ending A ignores optional quests and evidence")
	_check(bool(_ending_row(revealed_progress.endings, "ending_b").available), "ending B ignores optional quests and evidence")

	var zero_counts: Dictionary = {}
	var stale_flags: Dictionary = {"boss_down_ch06": true, "true_ending_testimony_complete": true}
	for index in range(1, 7):
		var testimony := "testimony_%02d" % index
		zero_counts[testimony] = 0
		stale_flags["evidence_read_%s" % testimony] = true
	var zero_progress: Dictionary = narrative.evaluate_progress(zero_counts, stale_flags)
	_check(int(zero_progress.get("evidence_count", -1)) == 0 and not bool(zero_progress.get("evidence_complete", true)),
		"zero-count keys and stale completion flags cannot bypass evidence")
	_check(not bool(narrative.evaluate_ending("ending_c", zero_counts, stale_flags).get("available", true)),
		"stale evidence flags cannot unlock the true ending")
	_check(zero_progress.get("known_entries", []).size() == 6,
		"persisted read flags preserve knowledge without replacing possession requirements")

func _test_reward_transactions_and_recovery() -> void:
	var data := JSON.parse_string(FileAccess.get_file_as_string("res://data/world_narrative.json")) as Dictionary
	var npc_entries: Dictionary = data.get("npcs", {})
	var tested_rewards := 0
	for npc_id_value in npc_entries.keys():
		var npc_id := String(npc_id_value)
		var npc: Dictionary = npc_entries[npc_id]
		for state_value in npc.get("states", []):
			var state: Dictionary = state_value
			var reward_flag := String(state.get("reward_flag", ""))
			var rewards: Dictionary = state.get("grant_rewards", {})
			if reward_flag.is_empty() or rewards.is_empty():
				continue
			tested_rewards += 1
			var result: Dictionary = state.duplicate(true)
			var flags: Dictionary = {}
			var lines: Array = result.get("lines", [])
			var interrupted: Dictionary = NARRATIVE.completion_outcome(result, -1, flags)
			_check(not bool(interrupted.get("complete", true)) and interrupted.get("flags", []).is_empty() and interrupted.get("rewards", {}).is_empty(),
				"interrupted %s dialogue commits no flags or rewards" % String(state.get("id", "")))
			var complete_index := lines.size() - 1
			var outcome: Dictionary = NARRATIVE.completion_outcome(result, complete_index, flags)
			_check(bool(outcome.get("complete", false)) and int(outcome.get("rewards", {}).get("currency", 0)) > 0,
				"completed %s dialogue produces its one-time reward" % String(state.get("id", "")))
			_check(outcome.get("flags", []).has(reward_flag), "completed reward and claim marker share one transaction")
			var saved_flags: Dictionary = flags.duplicate(true)
			for flag_value in outcome.get("flags", []):
				saved_flags[String(flag_value)] = true
			var reloaded: Dictionary = JSON.parse_string(JSON.stringify(saved_flags)) as Dictionary
			var repeated: Dictionary = NARRATIVE.completion_outcome(result, complete_index, reloaded)
			_check(repeated.get("rewards", {}).is_empty() and repeated.get("flags", []).is_empty(),
				"reloaded %s dialogue cannot duplicate reward" % String(state.get("id", "")))
			_check(NARRATIVE.completion_flags(result, complete_index, reloaded).is_empty() and NARRATIVE.completion_rewards(result, complete_index, reloaded).is_empty(),
				"legacy completion wrappers use the same one-time transaction")

			var partial_flags: Dictionary = {}
			for flag_value in state.get("grant_flags", []):
				var grant_flag := String(flag_value)
				if grant_flag.begins_with("quest_") and grant_flag.ends_with("_complete"):
					partial_flags[grant_flag] = true
			var recovered: Dictionary = narrative.resolve(npc_id, [], [], partial_flags, {})
			_check(String(recovered.get("state", "")) == String(state.get("id", "")),
				"revisit repairs pending reward for %s after partial save" % String(state.get("id", "")))
			var recovered_result: Dictionary = NARRATIVE.completion_outcome(recovered, recovered.get("lines", []).size() - 1, partial_flags)
			_check(int(recovered_result.get("rewards", {}).get("currency", 0)) == int(rewards.get("currency", 0)),
				"recovered %s reward remains claimable once" % String(state.get("id", "")))
	_check(tested_rewards >= 5, "all authored one-time quest reward states are covered")

func _test_variable_quest_order() -> void:
	for archive_first in [true, false]:
		var flags: Dictionary = {}
		var inventory: Dictionary = {"testimony_03": 1}
		var order: Array = ["npc_fugitive_scribe", "npc_canal_child"] if archive_first else ["npc_canal_child", "npc_fugitive_scribe"]
		for npc_id in order:
			var dialogue: Dictionary = narrative.resolve(npc_id, [], [], flags, inventory)
			_check(not dialogue.is_empty(), "cross-region quest evidence order resolves %s" % npc_id)
			var outcome: Dictionary = NARRATIVE.completion_outcome(dialogue, dialogue.get("lines", []).size() - 1, flags)
			for flag_value in outcome.get("flags", []):
				flags[String(flag_value)] = true
		var return_dialogue: Dictionary = narrative.resolve("npc_threadsmith_apprentice", [], [], flags, inventory)
		_check(String(return_dialogue.get("state", "")) == "names_homecoming",
			"canal/archive order %s reaches the same homecoming" % ("archive-first" if archive_first else "canal-first"))
		var reward: Dictionary = NARRATIVE.completion_outcome(return_dialogue, return_dialogue.get("lines", []).size() - 1, flags)
		_check(int(reward.get("rewards", {}).get("currency", 0)) == 40, "names homecoming reward is awarded once in either order")
		for flag_value in reward.get("flags", []):
			flags[String(flag_value)] = true
		var reloaded: Dictionary = JSON.parse_string(JSON.stringify(flags)) as Dictionary
		var revisit: Dictionary = narrative.resolve("npc_threadsmith_apprentice", [], [], reloaded, inventory)
		var duplicate: Dictionary = NARRATIVE.completion_outcome(revisit, revisit.get("lines", []).size() - 1, reloaded)
		_check(duplicate.get("rewards", {}).is_empty(), "reloaded homecoming cannot pay twice")

func _test_ending_world_phase() -> void:
	var selected_flags: Dictionary = {
		"ending_chosen": "ending_b",
		"boss_down_ch06": true,
		"ending_a_done": true,
		"ending_c_done": true
	}
	_check(narrative.resolve("npc_broken_singer", [], [], selected_flags).get("state", "") == "aftermath_severed",
		"saved ending choice overrides stale competing done flags in NPC aftermath")
	var progress: Dictionary = narrative.evaluate_progress({}, selected_flags)
	var chosen_row: Dictionary = _ending_row(progress.get("endings", []), "ending_b")
	_check(String(chosen_row.get("status", "")) == "chosen", "the journal derives the selected phase from ending_chosen")
	var selected_eval: Dictionary = narrative.evaluate_ending("ending_b", {}, selected_flags)
	_check(bool(selected_eval.get("available", false)) and selected_eval.get("grant_flags", []).is_empty(),
		"a reopened chosen ending remains readable without re-emitting consequence commits")
	var closed_row: Dictionary = _ending_row(progress.get("endings", []), "ending_c")
	_check(String(closed_row.get("status", "")) == "closed", "other encountered choices close after a persistent selection")
	var legacy_flags: Dictionary = {"ending_c_done": true}
	_check(narrative.resolve("npc_black_tide_child", [], [], legacy_flags).get("state", "") == "aftermath_rewritten",
		"a unique legacy ending marker restores its matching world phase")
	var invalid_choice_flags: Dictionary = {"ending_chosen": "ending_unknown", "boss_down_ch06": true}
	_check(bool(narrative.evaluate_ending("ending_a", {}, invalid_choice_flags).get("available", false)),
		"an invalid saved choice cannot lock valid endings")
	var invalid_with_legacy_flags: Dictionary = {"ending_chosen": "ending_unknown", "ending_c_done": true}
	_check(narrative.resolve("npc_black_tide_child", [], [], invalid_with_legacy_flags).get("state", "") == "aftermath_rewritten",
		"an invalid saved choice falls back to a unique valid legacy ending marker")

func _ending_row(rows: Array, ending_id: String) -> Dictionary:
	for row_value in rows:
		var row: Dictionary = row_value
		if String(row.get("id", "")) == ending_id:
			return row
	return {}

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error(description)

func _test_return_journey_contract() -> void:
	var all_orders: Array = []
	_permute_evidence([], [1, 2, 3, 4, 5, 6], all_orders)
	_check(all_orders.size() == 720, "all six-proof permutations are enumerated")
	for order in all_orders:
		var inventory: Dictionary = {}
		for index in order.size():
			inventory["testimony_%02d" % int(order[index])] = 1
			var progress := narrative.evaluate_progress(inventory, {})
			_check(int(progress.evidence_count) == index + 1, "any discovery order preserves exact proof count")
			_check(bool(progress.evidence_complete) == (index == 5), "no incomplete prefix finishes the main evidence chain")
		_check(bool(narrative.evaluate_ending("ending_c", inventory, {"boss_down_ch06": true}).available), "every complete permutation enables rewrite without optional quests")
	_check(narrative.evidence_connections({}).is_empty(), "unknown cross-reading stays hidden")
	_check(narrative.evidence_connections({"testimony_02": 1, "testimony_03": 0}).is_empty(), "zero proof does not reveal a connection")
	_check(narrative.evidence_connections({"testimony_02": 1, "testimony_03": 1}).size() == 1, "two acquired proofs reveal their authored connection")
	var zero_ability := narrative.resolve("npc_root_prisoner", [], ["thorn_downstrike"], {}, {"thorn_downstrike": 0})
	_check(String(zero_ability.get("state", "")) == "root_waiting", "zero-count ability cannot rescue an NPC via inventory keys")
	for ending_id in ["ending_a", "ending_b", "ending_c"]:
		var flags: Dictionary = {"ending_chosen": ending_id, "quest_keep_me": true}
		for other in ["ending_a", "ending_b", "ending_c"]:
			flags[other + "_done"] = true
		var restored := narrative.restored_ending_flags(flags)
		_check(bool(restored.quest_keep_me), "ending repair preserves unrelated quest flags")
		_check(narrative.restored_ending_flags(restored) == restored, "ending restoration is idempotent")
		for other in ["ending_a", "ending_b", "ending_c"]:
			_check(bool(restored.get(other + "_done", false)) == (ending_id == other), "only the selected branch survives restoration")
			for flag in narrative.story_data.endings[other].consequence_flags:
				_check(bool(restored.get(flag, false)) == (ending_id == other), "opposing world consequences cannot survive restore")
		# Finish each authored continuation first. Every NPC must then offer the
		# local aftermath, without changing or suppressing optional quest rewards.
		for npc_id in narrative.entries:
			var npc_flags := restored.duplicate(true)
			var settled := false
			for visit in range(12):
				var dialogue := narrative.resolve(npc_id, [], [], npc_flags, {})
				if String(dialogue.get("state", "")).begins_with("aftermath_"):
					settled = true
					_check(dialogue.lines.size() > 0, "all six regions retain a readable local consequence")
					break
				var outcome := NARRATIVE.completion_outcome(dialogue, dialogue.get("lines", []).size() - 1, npc_flags)
				for flag in outcome.get("flags", []): npc_flags[String(flag)] = true
			_check(settled, "continuations settle into aftermath without repeat loops: " + String(npc_id))
		var rescue := narrative.resolve("npc_root_prisoner", [], [], restored, {"thorn_downstrike": 1})
		_check(String(rescue.get("state", "")) == "root_rescued", "rescue remains completable after every ending")
		var home_flags := restored.duplicate(true)
		home_flags["quest_bring_names_canal_heard"] = true
		home_flags["quest_bring_names_archive_heard"] = true
		_check(String(narrative.resolve("npc_threadsmith_apprentice", [], [], home_flags).state) == "names_homecoming", "homecoming outranks aftermath when earned")
	var conflicting: Dictionary = {"ending_a_done": true, "ending_b_done": true, "world_bells_restored": true, "quest_keep_me": true}
	var repaired := narrative.restored_ending_flags(conflicting)
	_check(not repaired.has("ending_chosen") and not repaired.has("ending_a_done") and not repaired.has("world_bells_restored"), "ambiguous legacy branches restore to an unchosen state")
	_check(narrative.resolve("npc_black_tide_child", [], [], conflicting).state == "child_first", "ambiguous legacy flags cannot select a random aftermath")
	var legacy := narrative.restored_ending_flags({"ending_c_done": true})
	_check(legacy.get("ending_chosen", "") == "ending_c" and bool(legacy.get("world_names_restored", false)), "unique legacy choice restores its consequences")
	for row in narrative.consequence_rows(narrative.story_data.endings.ending_c.consequences):
		_check(not String(row.title).begins_with("npc_"), "player-facing consequence names contain no internal IDs")

func _permute_evidence(prefix: Array, remaining: Array, output: Array) -> void:
	if remaining.is_empty():
		output.append(prefix.duplicate())
		return
	for value in remaining:
		var next := remaining.duplicate()
		next.erase(value)
		var path := prefix.duplicate()
		path.append(value)
		_permute_evidence(path, next, output)

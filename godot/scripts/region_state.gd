extends RefCounted
## W00 stage 2 (docs/W00_SEAMLESS_RESIDENCY_PLAN.md): the level host's fields
## that describe one resident region, taken out and put back as a set.
## The fields stay on the host, where roughly 7000 references read them; a
## second region is built by switching this set around each batch of build
## jobs, and becomes the current region by applying its set at handover.
## GROUPS classifies every host variable that region travel resets;
## world_residency_inventory_validation fails when one is added or removed
## without being classified here.

const GROUPS := {
	"region_nodes": ["flat_map_art", "chapter_terrain", "cave_world", "cave_lifts", "world_platforms",
		"world_gameplay_residency", "gate_body", "locked_gate_bodies", "boss_actor", "boss_arena_lock_body",
		"challenge_arena_lock_body", "hidden_route_clues", "ending_aftermath", "nearby_interactable",
		"death_cache_area", "metsys_bridge", "region_tweens"],
	"region_runtime": ["config_path", "npc_residency_memory", "save_point_residency_memory", "config", "current_campaign_chapter",
		"tool_practice_rooms", "tool_encounter_hints", "skill_practice_hits", "skill_practice_serials",
		"active_challenge_id", "challenge_alive_ids", "challenge_spawn_null_ids_for_validation", "active_spawn",
		"bell_count", "max_bells", "shortcut_open", "opened_shortcuts", "boss_unlocked", "boss_spawned",
		"demo_complete", "post_boss_route_open", "enemy_total", "enemy_defeated", "hazard_total",
		"collectible_total", "save_point_total", "hidden_save_point_total", "world_width", "world_height",
		"fall_y", "current_room_id", "active_save_point_id", "pending_enemy_respawn", "ending_gates_spawned",
		"last_safe_ground", "death_recorded", "world_pickup_leases", "boss_trial_mode"],
	"interface": ["ui_shell", "ui_canvas", "hud_label", "toast_label", "lore_banner_label", "lore_banner_time_left",
		"item_lore", "win_label", "dialogue_panel", "dialogue_name_label", "dialogue_meta_label",
		"dialogue_text_label", "dialogue_hint_label", "backpack_panel", "backpack_text", "backpack_detail_text",
		"backpack_entry_ids", "backpack_selection", "map_panel", "map_text", "map_draw_root", "survey_map_view", "map_rendered_state",
		"active_overlay", "settings_panel", "settings_text", "settings_selection", "last_toast_sfx_ms",
		"wish_panel", "wish_text", "new_journey_dialog", "subtitle_elapsed", "subtitle_seconds", "world_map_view"],
	"audio": ["bgm_player", "bgm_duck_tween", "low_hp_audio_active", "low_hp_heartbeat_player",
		"pending_sfx_players", "audio_director"],
	"progress": ["unlocked_abilities", "inventory_counts", "inventory_tools", "inventory_relics",
		"inventory_materials", "currency_count", "visited_rooms", "story_flags", "carried_inventory_enabled",
		"carried_inventory_counts", "carried_currency", "world_collected_ids", "achievements"],
	"static_data": ["campaign", "chapter_file_configs", "audio_visual_manifest"],
	"transition": ["chapter_transitioning", "world_portal_request_pending", "entry_spawn_override_enabled",
		"entry_spawn_override", "entered_from_config_id", "transition_entry_message", "world_loading",
		"initial_region_ready", "world_initial_error", "world_save_capture_ok",
		"world_save_failure_injected_for_validation", "world_new_key_held", "world_resumed_journey",
		"world_start_region_id", "world_catalog_prepare_staging"],
}

## "region": part of the set switched with the region (its nodes, runtime
## state, interface and audio are all rebuilt per region today).
## "host": stays with the host; reset and restored from WorldState on travel,
## so its value is the same for every region.
## "transition": loader control state.
const TARGET := {
	"region_nodes": "region", "region_runtime": "region", "interface": "region", "audio": "region",
	"progress": "host", "static_data": "host", "transition": "transition",
}

## Progress values that must survive travel unchanged (validated).
const PROGRESS_VALUES := ["unlocked_abilities", "inventory_counts", "inventory_tools", "inventory_relics",
	"inventory_materials", "currency_count", "story_flags", "world_collected_ids"]


static func fields() -> Array[String]:
	var out: Array[String] = []
	for group in GROUPS:
		if TARGET[group] == "region":
			out.append_array(GROUPS[group])
	return out


## Every host field that travel resets: the region's own set plus progress,
## shared data and loader flags. A destination built while the source region is
## still resident (W00 stage 3) switches all of them, so the source's values
## are untouched until handover.
static func travel_fields() -> Array[String]:
	var out: Array[String] = []
	for group in GROUPS:
		out.append_array(GROUPS[group])
	return out


## The host's current region set. Values are handed over as they are (no
## copies): the caller owns the set until it is applied again.
static func capture(host: Node, names: Array[String] = fields()) -> Dictionary:
	var state := {}
	for field in names:
		state[field] = host.get(field)
	return state


static func apply(host: Node, state: Dictionary, names: Array[String] = fields()) -> void:
	for field in names:
		host.set(field, state[field])


## A set holding the script defaults, as a region has before it is built.
static func fresh(host: Node, names: Array[String] = fields()) -> Dictionary:
	var defaults: Node = host.get_script().new()
	var state := fresh_from(defaults, names)
	defaults.free()
	return state


## The same, read from a detached host instance the caller already made.
static func fresh_from(defaults: Node, names: Array[String] = fields()) -> Dictionary:
	var state := {}
	for field in names:
		var value: Variant = defaults.get(field)
		state[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return state


## Puts `state` on the host and returns the set it replaced.
static func switch_to(host: Node, state: Dictionary, names: Array[String] = fields()) -> Dictionary:
	var previous := capture(host, names)
	apply(host, state, names)
	return previous

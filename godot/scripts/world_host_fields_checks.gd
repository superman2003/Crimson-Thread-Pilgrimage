extends RefCounted
## W00 stage 0: every main_level script variable that region travel resets,
## grouped by where it should live once two regions can be resident at once.
## world_residency_inventory_validation fails when a field is added, removed
## or left unclassified, so this list stays the migration inventory for stage 2.
## Target "region" moves into a per-region RegionState; "session" should stop
## being rebuilt on travel; "transition" is loader control state.

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
		"backpack_entry_ids", "backpack_selection", "map_panel", "map_text", "map_draw_root", "survey_map_view",
		"active_overlay", "settings_panel", "settings_text", "settings_selection", "last_toast_sfx_ms",
		"wish_panel", "wish_text", "new_journey_dialog", "subtitle_elapsed", "subtitle_seconds", "world_map_view"],
	"audio": ["bgm_player", "bgm_duck_tween", "low_hp_audio_active", "low_hp_heartbeat_player",
		"pending_sfx_players", "audio_director"],
	"progress": ["unlocked_abilities", "inventory_counts", "inventory_tools", "inventory_relics",
		"inventory_materials", "currency_count", "visited_rooms", "story_flags", "carried_inventory_enabled",
		"carried_inventory_counts", "carried_currency", "world_collected_ids", "journey_clock", "achievements"],
	"static_data": ["campaign", "chapter_file_configs", "audio_visual_manifest"],
	"transition": ["chapter_transitioning", "world_portal_request_pending", "entry_spawn_override_enabled",
		"entry_spawn_override", "entered_from_config_id", "transition_entry_message", "world_loading",
		"initial_region_ready", "world_initial_error", "world_save_capture_ok",
		"world_save_failure_injected_for_validation", "world_new_key_held", "world_resumed_journey",
		"world_start_region_id", "world_catalog_prepare_staging"],
}

const TARGET := {
	"region_nodes": "region", "region_runtime": "region", "interface": "session", "audio": "session",
	"progress": "session", "static_data": "session", "transition": "transition",
}

## Progress fields are reset and then restored from WorldState on every travel,
## so their values must survive it unchanged (validated). The two RefCounted
## trackers are rebuilt from saved data and compared through their snapshots.
const PROGRESS_VALUES := ["unlocked_abilities", "inventory_counts", "inventory_tools", "inventory_relics",
	"inventory_materials", "currency_count", "story_flags", "world_collected_ids"]


static func group_of(field: String) -> String:
	for group in GROUPS:
		if field in GROUPS[group]:
			return group
	return ""

extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_ACTOR_SCRIPT := preload("res://scripts/enemy_actor.gd")
const METSYS_BRIDGE_SCRIPT := preload("res://scripts/metroidvania_bridge.gd")
const DEFAULT_CONFIG_PATH := "res://data/demo_ch01_moss_bell_court.json"
const CAMPAIGN_PATH := "res://data/campaign_chapters.json"
const CHAPTER_DATA_DIR := "res://data/chapters"
const AV_MANIFEST_PATH := "res://data/audio_visual_manifest.json"

const ROOM_DISPLAY_NAMES := {
    "entry_bell": "Entry Gate",
    "outer_court": "Outer Court",
    "gear_lift": "Gear Lift",
    "upper_bells": "Upper Gallery",
    "backdoor": "Back Chapel",
    "runback": "Crown Runback",
    "boss_chamber": "Rust Crown Hall"
}

const ROOM_MAP_COPY := {
    "entry_bell": {
        "objective": "Clear the first enemy group, then drop under the blocked gate.",
        "guide": "Use the lower route after the front gate blocks the bridge.",
        "danger": "Do not force the gate jump; the safe route is below.",
        "next": "Reach the Outer Court."
    },
    "outer_court": {
        "objective": "Cross the lower court and keep distance from melee bugs.",
        "guide": "Fight one creature at a time, then step back to recover energy.",
        "danger": "False moss floors send you back to the last lamp.",
        "next": "Move toward the Gear Lift."
    },
    "gear_lift": {
        "objective": "Clear the lift guards and confirm the map updates.",
        "guide": "Open the map to check explored rooms and the current route.",
        "danger": "Bell-gap traps punish rushed jumps.",
        "next": "Climb into the Upper Gallery."
    },
    "upper_bells": {
        "objective": "Win the upper-gallery fight and return toward the shortcut.",
        "guide": "Save a dash for the falling clapper trap.",
        "danger": "Watch the warning flash before the clapper falls.",
        "next": "Head for the Back Chapel."
    },
    "backdoor": {
        "objective": "After every enemy falls, use the shortcut lever.",
        "guide": "Opening the shortcut also moves the checkpoint near the boss run.",
        "danger": "The bite trap sits close to the lever.",
        "next": "Enter the Crown Runback."
    },
    "runback": {
        "objective": "Reach the boss bell gate with health and energy ready.",
        "guide": "This hall has fewer enemies but heavier body hits.",
        "danger": "The false lamp is not a checkpoint.",
        "next": "Challenge Rust Crown Hall."
    },
    "boss_chamber": {
        "objective": "Ring the boss gate and defeat the Rust Crown Guardian.",
        "guide": "All boss attacks are body-range charges, slams, or stomps.",
        "danger": "Keep 60 energy ready for a right-click heal.",
        "next": "Route to Chapter 2."
    }
}

const ITEM_DISPLAY := {
    "currency": {"name": "Rosin Shards", "description": ""},
    "bell_key": {"name": "Battle Mark", "description": "Old routing token kept only for legacy saves."},
    "thread_burst": {"name": "Thread Burst", "description": "Spend 30 energy for a heavy thread slash."},
    "menders_right": {"name": "Mender's Hand", "description": "Right click spends 60 energy to restore 1 HP."},
    "moss_lens": {"name": "Moss Lens", "description": "Records explored rooms on the route map."},
    "moss_chitin": {"name": "Moss Chitin", "description": "Hard shell dropped by melee court beasts."},
    "crown_splinter": {"name": "Crown Splinter", "description": "A warm shard from the Rust Crown Guardian."}
}

const NPC_DISPLAY_NAMES := {
    "threadsmith": "Threadsmith Apprentice",
    "pilgrim": "Gate Pilgrim",
    "cartographer": "Lift Cartographer",
    "sacristan": "Backdoor Sacristan",
    "scout": "Runback Scout"
}

const NPC_DIALOGUE := {
    "threadsmith": [
        "Left click slashes. Right click spends 60 energy to mend 1 HP.",
        "E spends 30 energy for Thread Burst. F talks, pulls levers, and rings gates.",
        "Moss Bell Court is only the first lost mark on the pilgrimage."
    ],
    "pilgrim": [
        "The front gate is sealed. Do not try to brute-force the bridge.",
        "Clear each enemy group: one above the start, one in the lower court, one in the gallery.",
        "Open the map if you lose the route. Bright rooms are already explored."
    ],
    "cartographer": [
        "The Moss Lens records this court. The map shows the room objective and next route.",
        "Cyan marks you, amber marks devices, and red marks the boss.",
        "The upper gallery loops back to the shortcut. Do not wander the lower court forever."
    ],
    "sacristan": [
        "Once every enemy in the court is down, pull the lever behind me to open the shortcut.",
        "Once it opens, the checkpoint moves close to the boss run.",
        "The crown is not a helmet. It is a bell turned over the city."
    ],
    "scout": [
        "The lamp ahead is false. Your real safety is the checkpoint behind you.",
        "The Rust Crown has no ranged spells, only charges, body checks, and stomps.",
        "Keep 60 energy for a right-click heal. Greedy attacks get punished."
    ]
}

const SPRITES := {
    "bg_sky": "res://assets/sprites/gothicvania/demo/bg_ch01_sky.png",
    "bg_far": "res://assets/sprites/gothicvania/demo/bg_ch01_far_silhouettes.png",
    "bg_mid": "res://assets/sprites/gothicvania/demo/bg_ch01_mid_arches.png",
    "bg_fog": "res://assets/sprites/gothicvania/demo/bg_ch01_fog.png",
    "bg_near": "res://assets/sprites/gothicvania/demo/bg_ch01_near_vines.png",
    "moss_stone": "res://assets/sprites/gothicvania/demo/platform_moss_stone.png",
    "bronze_bridge": "res://assets/sprites/gothicvania/demo/platform_bronze_bridge.png",
    "boss_stone": "res://assets/sprites/gothicvania/demo/platform_boss_stone.png",
    "moss_larva": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "bronze_moth": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "spore_bellmaker": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "gear_sentinel": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "rust_crown_guardian": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "drain_leech": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "pipe_thrower": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "rust_diver": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "bell_mote": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "waterwheel_knight": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "sunken_hammer_smith": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "salt_bookmite": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "page_duelist": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "index_scribe": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "summoned_page": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "wax_lancer": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "erasure_bailiff": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "saltwhite_contract_judge": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "vine_crawler": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "wax_bee": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "root_cage_hunter": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "pollen_lutist": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "thorn_sentinel": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "broken_string_garden_lord": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "broken_string_gardener": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "obsidian_spearman": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "phase_censor": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "silent_bugbler": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "kneeling_crossbowman": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "pilgrim_chariot": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "silent_pilgrim_commander": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "echo_moss_larva": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "echo_waterwheel_knight": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "echo_contract_scribe": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "delayed_shadow": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "echo_thorn_sentinel": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "echo_pilgrim_commander_minor": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "isotope_lumen": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "silent_crown_core": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "spikes": "res://assets/sprites/gothicvania/demo/hazard_spikes.png",
    "bell": "res://assets/sprites/gothicvania/demo/hazard_bell.png",
    "fake_moss_floor": "res://assets/sprites/gothicvania/demo/trap_fake_moss_floor.png",
    "bell_gap": "res://assets/sprites/gothicvania/demo/trap_bell_gap.png",
    "spore_chest": "res://assets/sprites/gothicvania/demo/trap_spore_chest.png",
    "falling_clapper": "res://assets/sprites/gothicvania/demo/trap_falling_clapper.png",
    "shortcut_revenge": "res://assets/sprites/gothicvania/demo/trap_shortcut_revenge.png",
    "false_lamp": "res://assets/sprites/gothicvania/demo/trap_false_lamp.png",
    "bell_key": "res://assets/sprites/gothicvania/demo/pickup_bell_key.png",
    "pump_key": "res://assets/sprites/gothicvania/demo/pickup_bell_key.png",
    "lever": "res://assets/sprites/gothicvania/demo/shortcut_lever.png",
    "boss_gate": "res://assets/sprites/gothicvania/demo/boss_gate.png",
    "save_point": "res://addons/MetroidvaniaSystem/Themes/Kenney/Symbols/Save.png",
    "map_background": "res://assets/sprites/gothicvania/demo/map_background_ch01.png",
    "hud_key": "res://assets/sprites/ui/kenney/hud_key_yellow.png",
    "hud_heart": "res://assets/sprites/ui/kenney/hud_heart_full.png",
    "hud_coin": "res://assets/sprites/ui/kenney/hud_coins.png"
}

const NPC_SPRITES := {
    "threadsmith": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "pilgrim": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "cartographer": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "sacristan": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "scout": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "rain_smith": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "canal_child": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "sluice_nun": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "half_drowned_foreman": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "unreliable_guide": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "mechanic_teacher": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "true_ending_clue": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "vendor_guard_hint": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "main_witness": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "keeper_truth": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "vendor_sidequest": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "gate_hint": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "route_hint": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "key_witness": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "ability_teacher": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "sidequest_moral_choice": "res://assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    "true_ending_core": "res://assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
    "world_warning": "res://assets/sprites/gothicvania/demo/enemy_gear_sentinel.png",
    "ending_checker": "res://assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    "hidden_temptation": "res://assets/sprites/gothicvania/demo/enemy_moss_larva.png"
}

const MOSSY_PLATFORM_TILES := {
    "left": "res://assets/sprites/gothicvania/demo/platform_moss_stone.png",
    "mid": "res://assets/sprites/gothicvania/demo/platform_bronze_bridge.png",
    "mid_alt": "res://assets/sprites/gothicvania/demo/platform_moss_stone.png",
    "right": "res://assets/sprites/gothicvania/demo/platform_bronze_bridge.png",
    "cap_small": "res://assets/sprites/gothicvania/demo/platform_boss_stone.png"
}

const INDUSTRIAL_PLATFORM_TILES := {
    "left": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_001.png",
    "mid": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_002.png",
    "mid_alt": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_003.png",
    "right": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_004.png",
    "cap_small": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_008.png",
    "warning": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_064.png",
    "pipe": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_085.png",
    "pipe_cap": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_099.png",
    "panel": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_073.png",
    "panel_alt": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_075.png",
    "gear": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_067.png",
    "light_blue": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_090.png",
    "light_yellow": "res://assets/third_party/kenney_platformer_industrial/PNG/Default size/platformIndustrial_093.png"
}

const GOTHICVANIA_CEMETERY_ASSETS := {
    "tileset": "res://assets/third_party/gothicvania_cemetery/tileset.png",
    "background": "res://assets/third_party/gothicvania_cemetery/background.png",
    "graveyard": "res://assets/third_party/gothicvania_cemetery/graveyard.png",
    "mountains": "res://assets/third_party/gothicvania_cemetery/mountains.png"
}

const CEMETERY_PLATFORM_REGIONS := {
    "left": [16, 64, 32, 80],
    "mid": [48, 56, 80, 64],
    "mid_alt": [304, 16, 64, 64],
    "right": [176, 60, 32, 80],
    "cap_small": [224, 50, 48, 88]
}

const KENNEY_DELUXE_ASSETS := {
    "bg": "res://assets/third_party/kenney_platformer_deluxe/bg.png",
    "bg_castle": "res://assets/third_party/kenney_platformer_deluxe/bg_castle.png"
}

const GODOT_PLATFORMER_2D_ASSETS := {
    "sky": "res://assets/third_party/godot_platformer_2d/sky.png",
    "mountains": "res://assets/third_party/godot_platformer_2d/mountains.png"
}

const KENNEY_DELUXE_TILE_FAMILIES := {
    "grass": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/grassLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/grassMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/grassRight.png"
    },
    "grass_half": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/grassHalfLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/grassHalfMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/grassHalfRight.png"
    },
    "dirt": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/dirtLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/dirtMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/dirtRight.png"
    },
    "stone": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/stoneLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/stoneMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/stoneRight.png"
    },
    "castle": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/castleLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/castleMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/castleRight.png"
    },
    "snow": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/snowLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/snowMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/snowRight.png"
    },
    "snow_half": {
        "left": "res://assets/third_party/kenney_platformer_deluxe/snowHalfLeft.png",
        "mid": "res://assets/third_party/kenney_platformer_deluxe/snowHalfMid.png",
        "right": "res://assets/third_party/kenney_platformer_deluxe/snowHalfRight.png"
    }
}

const AUDIO := {
    "bgm_ch01": "res://assets/audio/bgm/ch01_cave_loop.ogg",
    "bgm_boss": "res://assets/audio/bgm/boss_rust_crown_loop.ogg",
    "pickup": "res://assets/audio/sfx/pickup.ogg",
    "lever": "res://assets/audio/sfx/lever.ogg",
    "interact": "res://assets/audio/sfx/interact.ogg"
}

var config: Dictionary = {}
var campaign: Dictionary = {}
var current_campaign_chapter: Dictionary = {}
var chapter_file_configs: Array = []
var audio_visual_manifest: Dictionary = {}
var player: CharacterBody2D
var ui_canvas: CanvasLayer
var hud_label: Label
var toast_label: Label
var win_label: Label
var dialogue_panel: ColorRect
var dialogue_name_label: Label
var dialogue_meta_label: Label
var dialogue_text_label: Label
var dialogue_hint_label: Label
var backpack_panel: ColorRect
var backpack_text: Label
var map_panel: ColorRect
var map_text: Label
var map_draw_root: Control
var gate_body: StaticBody2D
var boss_actor: Area2D
var boss_arena_lock_body: StaticBody2D
var nearby_interactable: Area2D
var active_spawn := Vector2(120, 500)
var bell_count := 0
var max_bells := 3
var shortcut_open := false
var boss_unlocked := false
var boss_spawned := false
var demo_complete := false
var post_boss_route_open := false
var chapter_transitioning := false
var entry_spawn_override_enabled := false
var entry_spawn_override := Vector2.ZERO
var entered_from_config_id := ""
var transition_entry_message := ""
var enemy_total := 0
var enemy_defeated := 0
var hazard_total := 0
var collectible_total := 0
var save_point_total := 0
var hidden_save_point_total := 0
var world_width := 4096.0
var world_height := 720.0
var fall_y := 790.0
var active_overlay := ""
var metsys_bridge: Node
var inventory_counts: Dictionary = {}
var inventory_tools: Array = []
var inventory_relics: Array = []
var inventory_materials: Dictionary = {}
var currency_count := 0
var visited_rooms: Dictionary = {}
var current_room_id := ""
var active_save_point_id := "start"
var bgm_player: AudioStreamPlayer
var pending_enemy_respawn := false

@export var config_path := DEFAULT_CONFIG_PATH


func _ready() -> void:
    _apply_cmdline_config_override()
    config = _load_json(config_path)
    if config.is_empty():
        push_error("Missing demo config: " + config_path)
        return
    campaign = _load_json(CAMPAIGN_PATH)
    chapter_file_configs = _load_chapter_file_configs()
    audio_visual_manifest = _load_json(AV_MANIFEST_PATH)
    current_campaign_chapter = _campaign_chapter_for_id(String(config.get("id", "")))
    var world: Dictionary = config.get("world", {})
    world_width = float(world.get("width", 4096.0))
    world_height = float(world.get("height", 720.0))
    fall_y = float(world.get("fall_y", 790.0))
    active_spawn = _vec2(config.get("player_start", [120, 500]))
    if entry_spawn_override_enabled:
        active_spawn = entry_spawn_override
    max_bells = 0 if _combat_progression_enabled() else int(config.get("required_keys", 3))
    _init_inventory_state()
    _build_metsys_bridge()
    _build_audio()
    _build_world_from_config()
    _spawn_player()
    _build_hud()
    _show_chapter_entry_message()


func _apply_cmdline_config_override() -> void:
    for arg in OS.get_cmdline_args():
        var text := String(arg)
        if text.begins_with("--demo-config="):
            config_path = text.get_slice("=", 1)


func _process(_delta: float) -> void:
    if pending_enemy_respawn:
        pending_enemy_respawn = false
        _spawn_normal_enemies()
        _refresh_hud()
    if Input.is_action_just_pressed("close_overlay"):
        _close_overlays()
    elif Input.is_action_just_pressed("inventory"):
        _toggle_backpack()
    elif Input.is_action_just_pressed("map"):
        _toggle_map()
    if Input.is_action_just_pressed("interact"):
        _try_interact()
    if player != null and is_instance_valid(player) and player.global_position.y > fall_y:
        _void_respawn()
    if player != null and is_instance_valid(player):
        _update_room_visit()
        if active_overlay == "map":
            _refresh_map_overlay()


func _exit_tree() -> void:
    if bgm_player != null:
        bgm_player.stop()
        bgm_player.stream = null


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _art_theme_id() -> String:
    var theme_id := String(config.get("art_theme", ""))
    if not theme_id.is_empty():
        return theme_id
    var config_id := String(config.get("id", ""))
    if config_id.contains("rain_foundry") or config_id.contains("ch02"):
        return "rain_foundry"
    if config_id.contains("saltwhite") or config_id.contains("ch03"):
        return "salt_archive"
    if config_id.contains("broken_string") or config_id.contains("ch04"):
        return "string_greenhouse"
    if config_id.contains("obsidian") or config_id.contains("ch05"):
        return "obsidian_pilgrim"
    if config_id.contains("silent_crown") or config_id.contains("ch06"):
        return "silent_crown"
    return "moss_cavern"


func _is_rain_foundry_theme() -> bool:
    return _art_theme_id() == "rain_foundry"


func _theme_map_title() -> String:
    var title := String(config.get("map_title", ""))
    if not title.is_empty():
        return title
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return "Rain Foundry Canal Map"
    if theme == "salt_archive":
        return "Saltwhite Archive Map"
    if theme == "string_greenhouse":
        return "Broken String Greenhouse Map"
    if theme == "obsidian_pilgrim":
        return "Obsidian Pilgrim Road Map"
    if theme == "silent_crown":
        return "Silent Crown Core Map"
    return "Moss Bell Court Map"


func _theme_map_background_texture() -> String:
    if _art_theme_id() == "salt_archive":
        return GOTHICVANIA_CEMETERY_ASSETS["graveyard"]
    if _art_theme_id() == "silent_crown":
        return GODOT_PLATFORMER_2D_ASSETS["mountains"]
    if _theme_uses_kenney_deluxe():
        return KENNEY_DELUXE_ASSETS["bg_castle"]
    if _theme_uses_industrial_tiles():
        return INDUSTRIAL_PLATFORM_TILES["panel_alt"]
    return SPRITES["map_background"]


func _theme_map_art_modulate() -> Color:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return Color(0.62, 0.88, 0.96, 0.16)
    if theme == "salt_archive":
        return Color(0.88, 0.86, 0.72, 0.17)
    if theme == "string_greenhouse":
        return Color(0.58, 0.86, 0.62, 0.18)
    if theme == "obsidian_pilgrim":
        return Color(0.88, 0.46, 0.32, 0.16)
    if theme == "silent_crown":
        return Color(0.74, 0.78, 1.0, 0.15)
    return Color(0.62, 0.78, 0.70, 0.18)


func _theme_asset_source() -> String:
    if _art_theme_id() == "salt_archive":
        return "GothicVania Cemetery by Ansimuz, Public Domain"
    if _art_theme_id() == "silent_crown":
        return "Godot Platformer 2D MIT + Kenney Platformer Art Deluxe CC0"
    if _theme_uses_kenney_deluxe():
        return "Kenney Platformer Art Deluxe CC0"
    if _theme_uses_industrial_tiles():
        return "Kenney Platformer Pack Industrial CC0"
    return "GothicVania demo public-domain-style assets"


func _theme_uses_industrial_tiles() -> bool:
    return _art_theme_id() == "rain_foundry"


func _theme_uses_kenney_deluxe() -> bool:
    var theme := _art_theme_id()
    return theme == "string_greenhouse" or theme == "obsidian_pilgrim" or theme == "silent_crown"


func _background_visual_asset_paths() -> Array:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return [
            INDUSTRIAL_PLATFORM_TILES["panel"],
            INDUSTRIAL_PLATFORM_TILES["pipe"],
            INDUSTRIAL_PLATFORM_TILES["gear"],
            INDUSTRIAL_PLATFORM_TILES["light_blue"]
        ]
    if theme == "salt_archive":
        return [
            GOTHICVANIA_CEMETERY_ASSETS["background"],
            GOTHICVANIA_CEMETERY_ASSETS["mountains"],
            GOTHICVANIA_CEMETERY_ASSETS["graveyard"]
        ]
    if theme == "string_greenhouse":
        return [KENNEY_DELUXE_ASSETS["bg"]]
    if theme == "obsidian_pilgrim":
        return [KENNEY_DELUXE_ASSETS["bg_castle"]]
    if theme == "silent_crown":
        return [
            GODOT_PLATFORMER_2D_ASSETS["sky"],
            GODOT_PLATFORMER_2D_ASSETS["mountains"]
        ]
    return [
        SPRITES["bg_sky"],
        SPRITES["bg_fog"],
        SPRITES["bg_near"]
    ]


func _theme_boss_material() -> String:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return "foundry_boss"
    if theme == "salt_archive":
        return "archive_boss"
    if theme == "string_greenhouse":
        return "root_boss"
    if theme == "obsidian_pilgrim":
        return "pilgrim_boss"
    if theme == "silent_crown":
        return "core_boss"
    return "boss_stone"


func _platform_visual_asset_paths_for_material(material: String) -> Array:
    if _is_cemetery_material(material):
        return [GOTHICVANIA_CEMETERY_ASSETS["tileset"]]
    var kenney_family := _kenney_deluxe_family(material)
    if not kenney_family.is_empty():
        var family_tiles: Dictionary = KENNEY_DELUXE_TILE_FAMILIES.get(kenney_family, {})
        return [
            String(family_tiles.get("left", "")),
            String(family_tiles.get("mid", "")),
            String(family_tiles.get("right", ""))
        ]
    if _is_industrial_material(material):
        return [
            INDUSTRIAL_PLATFORM_TILES["left"],
            INDUSTRIAL_PLATFORM_TILES["mid"],
            INDUSTRIAL_PLATFORM_TILES["mid_alt"],
            INDUSTRIAL_PLATFORM_TILES["right"],
            INDUSTRIAL_PLATFORM_TILES["cap_small"]
        ]
    return [
        MOSSY_PLATFORM_TILES["left"],
        MOSSY_PLATFORM_TILES["mid"],
        MOSSY_PLATFORM_TILES["mid_alt"],
        MOSSY_PLATFORM_TILES["right"],
        MOSSY_PLATFORM_TILES["cap_small"]
    ]


func _combat_progression_enabled() -> bool:
    return String(config.get("progression_mode", "keys")).to_lower() == "combat_clear"


func _combat_goal_met() -> bool:
    return enemy_total <= 0 or enemy_defeated >= enemy_total


func _init_inventory_state() -> void:
    inventory_counts.clear()
    inventory_tools.clear()
    inventory_relics.clear()
    inventory_materials.clear()
    currency_count = 0
    visited_rooms.clear()
    current_room_id = ""
    var inventory_config: Dictionary = config.get("inventory", {})
    for item_id in inventory_config.get("starting_tools", []):
        _add_inventory_item(String(item_id), 1, false)
    for item_id in inventory_config.get("starting_relics", []):
        _add_inventory_item(String(item_id), 1, false)


func _item_data(item_id: String) -> Dictionary:
    var inventory_config: Dictionary = config.get("inventory", {})
    var catalog: Dictionary = inventory_config.get("catalog", {})
    return catalog.get(item_id, {"name": item_id, "category": "Materials", "description": ""})


func _item_display_name(item_id: String) -> String:
    var item := _item_data(item_id)
    if item.has("name"):
        return String(item.get("name", item_id.capitalize()))
    var display: Dictionary = ITEM_DISPLAY.get(item_id, {})
    return String(display.get("name", item_id.capitalize()))


func _item_display_description(item_id: String) -> String:
    var item := _item_data(item_id)
    if item.has("description"):
        return String(item.get("description", ""))
    var display: Dictionary = ITEM_DISPLAY.get(item_id, {})
    return String(display.get("description", ""))


func _room_map_copy(room_id: String, field: String, fallback: String) -> String:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if String(room_data.get("id", "")) == room_id and room_data.has(field):
            return String(room_data.get(field, fallback))
    var copy: Dictionary = ROOM_MAP_COPY.get(room_id, {})
    return String(copy.get(field, fallback))


func _npc_display_name(data: Dictionary) -> String:
    if data.has("name"):
        return String(data.get("name", "Wanderer"))
    var role := String(data.get("role", ""))
    return String(NPC_DISPLAY_NAMES.get(role, "Wanderer"))


func _npc_dialogue(data: Dictionary) -> Array:
    var config_dialogue: Array = data.get("dialogue", [])
    if not config_dialogue.is_empty():
        return config_dialogue
    var role := String(data.get("role", ""))
    return NPC_DIALOGUE.get(role, ["..."])


func _campaign_chapter_for_id(chapter_id: String) -> Dictionary:
    for chapter in campaign.get("chapters", []):
        var item := chapter as Dictionary
        if String(item.get("id", "")) == chapter_id or String(item.get("runtime_config_id", "")) == chapter_id:
            return item
    var chapters: Array = campaign.get("chapters", [])
    return chapters[0] if not chapters.is_empty() else {}


func _chapter_objective_text() -> String:
    if current_campaign_chapter.is_empty():
        return "Defeat normal enemies, open the boss route, and clear the chapter boss."
    return "第%d章 %s：%s" % [
        int(current_campaign_chapter.get("index", 1)),
        String(current_campaign_chapter.get("name", "苔钟庭")),
        String(current_campaign_chapter.get("objective", "Defeat normal enemies, open the boss route, and clear the chapter boss."))
    ]


func _next_campaign_chapter_name() -> String:
    var current_index := int(current_campaign_chapter.get("index", 1))
    for chapter in campaign.get("chapters", []):
        var item := chapter as Dictionary
        if int(item.get("index", 0)) == current_index + 1:
            return String(item.get("name", ""))
    return "二周目挑战"


func _show_chapter_entry_message() -> void:
    var message := transition_entry_message
    if message.is_empty() and not entered_from_config_id.is_empty():
        message = "进入" + String(config.get("name", "下一章"))
    if message.is_empty():
        _toast(_chapter_objective_text())
        return
    if win_label != null:
        win_label.text = message
        win_label.visible = true
    _toast(message)


func _boss_display_name(boss_data: Dictionary) -> String:
    if boss_data.has("name"):
        return String(boss_data.get("name", "Boss"))
    var chapter_boss: Dictionary = current_campaign_chapter.get("boss", {})
    return String(chapter_boss.get("name", "Boss"))


func _load_chapter_file_configs() -> Array:
    var loaded: Array = []
    var dir := DirAccess.open(CHAPTER_DATA_DIR)
    if dir == null:
        return loaded
    var files: Array = []
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".json"):
            files.append(file_name)
        file_name = dir.get_next()
    dir.list_dir_end()
    files.sort()
    for name in files:
        var chapter := _load_json(CHAPTER_DATA_DIR + "/" + String(name))
        if not chapter.is_empty():
            loaded.append(chapter)
    return loaded


func _chapter_file_ids() -> Array:
    var ids: Array = []
    for chapter in chapter_file_configs:
        var item := chapter as Dictionary
        ids.append(String(item.get("id", "")))
    return ids


func _add_inventory_item(item_id: String, amount: int = 1, announce: bool = true) -> void:
    var data := _item_data(item_id)
    var category := String(data.get("category", "Materials"))
    inventory_counts[item_id] = int(inventory_counts.get(item_id, 0)) + amount
    if category == "Tools" and not inventory_tools.has(item_id):
        inventory_tools.append(item_id)
    elif category == "Relics" and not inventory_relics.has(item_id):
        inventory_relics.append(item_id)
    elif category == "Materials":
        inventory_materials[item_id] = int(inventory_materials.get(item_id, 0)) + amount
    if announce:
        _toast("Added to bag: " + _item_display_name(item_id))
    if active_overlay == "backpack":
        _refresh_backpack_overlay()


func _add_currency(amount: int) -> void:
    currency_count += amount
    if active_overlay == "backpack":
        _refresh_backpack_overlay()


func _build_metsys_bridge() -> void:
    metsys_bridge = METSYS_BRIDGE_SCRIPT.new()
    metsys_bridge.name = "MetSysBridge"
    add_child(metsys_bridge)
    metsys_bridge.configure(config, world_width, world_height)


func _build_audio() -> void:
    if not _should_autoplay_audio():
        return
    _switch_bgm("bgm_ch01")


func _should_autoplay_audio() -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


func _switch_bgm(audio_key: String) -> void:
    var stream := _load_audio_stream(audio_key)
    if stream == null:
        return
    if bgm_player == null:
        bgm_player = AudioStreamPlayer.new()
        bgm_player.name = "BgmPlayer"
        bgm_player.bus = "Master"
        bgm_player.volume_db = -18.0
        bgm_player.finished.connect(_on_bgm_finished)
        add_child(bgm_player)
    if bgm_player.stream == stream and bgm_player.playing:
        return
    bgm_player.stream = stream
    bgm_player.play()


func _on_bgm_finished() -> void:
    if bgm_player != null and bgm_player.stream != null:
        bgm_player.play()


func _play_sfx(audio_key: String, volume_db: float = -7.0) -> void:
    if not _should_autoplay_audio():
        return
    var stream := _load_audio_stream(audio_key)
    if stream == null:
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "Sfx_" + audio_key
    player_node.bus = "Master"
    player_node.stream = stream
    player_node.volume_db = volume_db
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


func _load_audio_stream(audio_key: String) -> AudioStream:
    var path := String(AUDIO.get(audio_key, ""))
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    if path.ends_with(".ogg"):
        return AudioStreamOggVorbis.load_from_file(path)
    return load(path) as AudioStream


func _load_texture_resource(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if ResourceLoader.exists(path):
        var texture := load(path) as Texture2D
        if texture != null:
            return texture
    if not FileAccess.file_exists(path):
        return null
    var image := Image.load_from_file(path)
    if image == null:
        return null
    return ImageTexture.create_from_image(image)


func _build_backpack_overlay() -> void:
    backpack_panel = ColorRect.new()
    backpack_panel.name = "BackpackOverlay"
    backpack_panel.position = Vector2(78, 78)
    backpack_panel.size = Vector2(460, 500)
    backpack_panel.color = Color(0.035, 0.045, 0.05, 0.93)
    backpack_panel.visible = false
    ui_canvas.add_child(backpack_panel)

    var title := Label.new()
    title.text = "Bag"
    title.position = Vector2(22, 18)
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42))
    backpack_panel.add_child(title)

    backpack_text = Label.new()
    backpack_text.position = Vector2(22, 60)
    backpack_text.size = Vector2(410, 420)
    backpack_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    backpack_text.add_theme_color_override("font_color", Color(0.86, 0.91, 0.84))
    backpack_panel.add_child(backpack_text)
    _refresh_backpack_overlay()


func _build_map_overlay() -> void:
    map_panel = ColorRect.new()
    map_panel.name = "CourtMapOverlay"
    map_panel.position = Vector2(52, 54)
    map_panel.size = Vector2(1176, 640)
    map_panel.color = Color(0.012, 0.015, 0.018, 0.97)
    map_panel.visible = false
    ui_canvas.add_child(map_panel)

    var map_art := TextureRect.new()
    map_art.name = "MapBackgroundArt"
    map_art.texture = _load_texture_resource(_theme_map_background_texture())
    map_art.position = Vector2.ZERO
    map_art.size = map_panel.size
    map_art.stretch_mode = TextureRect.STRETCH_SCALE
    map_art.modulate = _theme_map_art_modulate()
    map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_panel.add_child(map_art)

    var title := Label.new()
    title.text = _theme_map_title()
    title.position = Vector2(28, 18)
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(0.58, 0.92, 0.86))
    map_panel.add_child(title)

    map_draw_root = Control.new()
    map_draw_root.name = "MapDrawRoot"
    map_draw_root.position = Vector2(34, 72)
    map_draw_root.size = Vector2(1108, 430)
    map_panel.add_child(map_draw_root)

    map_text = Label.new()
    map_text.position = Vector2(34, 514)
    map_text.size = Vector2(1108, 98)
    map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    map_text.add_theme_color_override("font_color", Color(0.86, 0.90, 0.84))
    map_panel.add_child(map_text)
    _refresh_map_overlay()


func _toggle_backpack() -> void:
    if active_overlay == "backpack":
        _close_overlays()
        return
    active_overlay = "backpack"
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if backpack_panel != null:
        backpack_panel.visible = true
    _refresh_backpack_overlay()


func _toggle_map() -> void:
    if active_overlay == "map":
        _close_overlays()
        return
    active_overlay = "map"
    if backpack_panel != null:
        backpack_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if map_panel != null:
        map_panel.visible = true
    _update_room_visit()
    _refresh_map_overlay()


func _close_overlays() -> void:
    active_overlay = ""
    if backpack_panel != null:
        backpack_panel.visible = false
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false


func _refresh_backpack_overlay() -> void:
    if backpack_text == null:
        return
    var lines: Array[String] = []
    lines.append("%s: %d" % [_item_display_name("currency"), currency_count])
    lines.append("")
    if not _combat_progression_enabled():
        lines.append("Route Marks")
        lines.append(_inventory_line_for_category("Combat"))
    lines.append("")
    lines.append("Tools")
    lines.append(_inventory_list(inventory_tools))
    lines.append("")
    lines.append("Relics")
    lines.append(_inventory_list(inventory_relics))
    lines.append("")
    lines.append("Materials")
    lines.append(_inventory_dict_list(inventory_materials))
    lines.append("")
    lines.append("Tab/I Bag   M Map   Esc Close")
    backpack_text.text = "\n".join(lines)


func _inventory_line_for_category(category: String) -> String:
    var entries: Array[String] = []
    for item_id in inventory_counts.keys():
        var data := _item_data(String(item_id))
        if String(data.get("category", "")) == category:
            entries.append("%s x%d" % [_item_display_name(String(item_id)), int(inventory_counts[item_id])])
    return "  None" if entries.is_empty() else "  " + ", ".join(entries)


func _inventory_list(item_ids: Array) -> String:
    if item_ids.is_empty():
        return "  None"
    var entries: Array[String] = []
    for item_id in item_ids:
        entries.append("  %s - %s" % [_item_display_name(String(item_id)), _item_display_description(String(item_id))])
    return "\n".join(entries)


func _inventory_dict_list(items: Dictionary) -> String:
    if items.is_empty():
        return "  None"
    var entries: Array[String] = []
    for item_id in items.keys():
        entries.append("  %s x%d - %s" % [
            _item_display_name(String(item_id)),
            int(items[item_id]),
            _item_display_description(String(item_id))
        ])
    return "\n".join(entries)


func _update_room_visit() -> void:
    if player == null or not is_instance_valid(player):
        return
    var room := _room_for_position(player.global_position)
    if room.is_empty():
        return
    current_room_id = String(room.get("id", ""))
    if not current_room_id.is_empty():
        visited_rooms[current_room_id] = true
        if metsys_bridge != null:
            metsys_bridge.update_player_position(player.global_position, current_room_id)


func _room_for_x(world_x: float) -> Dictionary:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_range: Array = room_data.get("range", [0.0, world_width])
        if room_range.size() < 2:
            continue
        if world_x >= float(room_range[0]) and world_x <= float(room_range[1]):
            return room_data
    return {}


func _room_for_position(world_position: Vector2) -> Dictionary:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if _room_contains_position(room_data, world_position):
            return room_data
    return _room_for_x(world_position.x)


func _room_layout_rect(room_data: Dictionary) -> Rect2:
    var rect_value: Variant = room_data.get("layout_rect", room_data.get("play_rect", []))
    if typeof(rect_value) != TYPE_ARRAY or rect_value.size() < 4:
        return Rect2()
    return _rect2(rect_value)


func _rect_contains_position(rect: Rect2, position_value: Vector2, padding: float = 0.0) -> bool:
    return (
        position_value.x >= rect.position.x - padding
        and position_value.x <= rect.position.x + rect.size.x + padding
        and position_value.y >= rect.position.y - padding
        and position_value.y <= rect.position.y + rect.size.y + padding
    )


func _room_contains_position(room_data: Dictionary, world_position: Vector2) -> bool:
    var layout := _room_layout_rect(room_data)
    if layout.size.x > 0.0 and layout.size.y > 0.0 and _rect_contains_position(layout, world_position):
        return true
    for rect_value in room_data.get("visit_rects", []):
        var rect := _rect2(rect_value)
        if rect.size.x > 0.0 and rect.size.y > 0.0 and _rect_contains_position(rect, world_position):
            return true
    return false


func _room_name(room_id: String) -> String:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if String(room_data.get("id", "")) == room_id and room_data.has("name"):
            return String(room_data.get("name", room_id))
    return String(ROOM_DISPLAY_NAMES.get(room_id, room_id if not room_id.is_empty() else "Unknown Room"))


func _room_is_visited(room_id: String) -> bool:
    return bool(visited_rooms.get(room_id, false))


func _refresh_map_overlay() -> void:
    if map_draw_root == null or map_text == null:
        return
    for child in map_draw_root.get_children():
        child.free()

    var rooms: Array = config.get("map_rooms", [])
    var draw_width := 1108.0
    var draw_size := Vector2(1108.0, 430.0)
    var base_y := 132.0
    var depth_step := 72.0
    var layout_bounds := _map_layout_bounds(rooms)
    var uses_layout := layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0
    if not uses_layout:
        _add_map_route_line(rooms, draw_width, base_y, depth_step, layout_bounds, draw_size)
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_id := String(room_data.get("id", ""))
        var overlay_rect := _map_room_overlay_rect(room_data, layout_bounds, draw_size, draw_width, base_y, depth_step)
        if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
            continue
        var visited := _room_is_visited(room_id)
        var current := room_id == current_room_id
        var room_size := overlay_rect.size
        var fill := Color(0.060, 0.115, 0.092, 0.98) if visited else Color(0.030, 0.038, 0.042, 0.98)
        var border := Color(0.74, 1.0, 0.92, 1.0) if current else (Color(0.42, 0.78, 0.56, 0.90) if visited else Color(0.24, 0.30, 0.28, 0.92))
        var border_width := 4.0 if current else 2.0
        _add_map_ui_rect("Room_" + room_id, overlay_rect.position, room_size, fill, border, border_width)
        _add_map_room_texture(overlay_rect.position, room_size, visited, current)
        _add_map_wall_caps(room_id, overlay_rect.position, room_size, visited, current)

        var room_kind := String(room_data.get("kind", ""))
        var should_label := not uses_layout or current or room_kind == "boss" or room_kind == "exit" or room_id == "entry_bell"
        if not should_label:
            continue
        var label := Label.new()
        label.text = _room_name(room_id)
        label.position = overlay_rect.position + (Vector2(4.0, 4.0) if uses_layout else Vector2(6.0, 48.0))
        label.size = Vector2(maxf(62.0, room_size.x - 4.0), 42.0)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.add_theme_font_size_override("font_size", 11 if uses_layout and not current else (12 if uses_layout else (13 if current else 12)))
        label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.95) if current else (Color(0.86, 0.94, 0.80) if visited else Color(0.50, 0.56, 0.52)))
        map_draw_root.add_child(label)

    _add_map_special_passage_markers(draw_width, base_y, depth_step, layout_bounds, draw_size)
    _add_world_map_pins(draw_width, base_y, depth_step, layout_bounds, draw_size)
    if player != null and is_instance_valid(player):
        if uses_layout:
            var player_pos := _map_world_to_overlay(player.global_position, layout_bounds, draw_size)
            _add_map_ui_rect("PlayerMarker", player_pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0), Color(0.21, 0.92, 1.0, 0.98), Color(0.86, 1.0, 1.0, 1.0), 3.0)
        else:
            var player_x := clampf(player.global_position.x / world_width * draw_width, 0.0, draw_width)
            _add_map_ui_rect("PlayerMarker", Vector2(player_x - 7.0, base_y - 36.0), Vector2(14.0, 96.0), Color(0.21, 0.92, 1.0, 0.98), Color(0.86, 1.0, 1.0, 1.0), 3.0)

    var current_room := _room_for_position(player.global_position) if player != null and is_instance_valid(player) else {}
    var current_map_room_id := String(current_room.get("id", current_room_id))
    var objective := _room_map_copy(current_map_room_id, "objective", "Keep exploring toward the next bell.")
    var guide := _room_map_copy(current_map_room_id, "guide", "Use the map for route status and F for nearby interactions.")
    var danger := _room_map_copy(current_map_room_id, "danger", "Watch traps and melee windups.")
    var next_step := _room_map_copy(current_map_room_id, "next", "Move forward.")
    var transition: Dictionary = config.get("chapter_transition", {})
    var transition_text := String(transition.get("entry_hint", "击败本章首领后进入下一章。"))
    var metsys_state: Dictionary = metsys_bridge.get_state() if metsys_bridge != null else {}
    map_text.text = "Chapter: %s\nRoom: %s\nExplored: %d/%d\nObjective: %s\nRoute: %s\nHazard: %s\nNext: %s\nCampaign Next: %s\nLink: %s\nMetSys: walls %d / passages %d / locks %d / connectors %d\nLegend: cyan=you, teal=route, charcoal=wall, blue=exit, amber=gate, red=boss." % [
        String(current_campaign_chapter.get("name", "Moss Bell Court")),
        _room_name(current_room_id),
        visited_rooms.size(),
        rooms.size(),
        objective,
        guide,
        danger,
        next_step,
        _next_campaign_chapter_name(),
        transition_text,
        int(metsys_state.get("metsys_wall_borders", 0)),
        int(metsys_state.get("metsys_passage_borders", 0)),
        int(metsys_state.get("metsys_locked_edges", 0)),
        int(metsys_state.get("metsys_connector_cells", 0))
    ]


func _map_layout_bounds(rooms: Array) -> Rect2:
    var has_layout := false
    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF
    for room in rooms:
        if not (room is Dictionary):
            continue
        var rect := _room_layout_rect(room)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        has_layout = true
        min_x = minf(min_x, rect.position.x)
        min_y = minf(min_y, rect.position.y)
        max_x = maxf(max_x, rect.position.x + rect.size.x)
        max_y = maxf(max_y, rect.position.y + rect.size.y)
    if not has_layout:
        return Rect2()
    return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _map_world_to_overlay(world_position: Vector2, layout_bounds: Rect2, draw_size: Vector2) -> Vector2:
    if layout_bounds.size.x <= 0.0 or layout_bounds.size.y <= 0.0:
        return Vector2.ZERO
    var map_scale := minf(draw_size.x / layout_bounds.size.x, draw_size.y / layout_bounds.size.y)
    var fitted_size := layout_bounds.size * map_scale
    var offset := Vector2((draw_size.x - fitted_size.x) * 0.5, (draw_size.y - fitted_size.y) * 0.5)
    return offset + (world_position - layout_bounds.position) * map_scale


func _map_room_overlay_rect(room_data: Dictionary, layout_bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> Rect2:
    var layout := _room_layout_rect(room_data)
    if layout.size.x > 0.0 and layout.size.y > 0.0 and layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0:
        var top_left := _map_world_to_overlay(layout.position, layout_bounds, draw_size)
        var bottom_right := _map_world_to_overlay(layout.position + layout.size, layout_bounds, draw_size)
        return Rect2(top_left, Vector2(maxf(24.0, bottom_right.x - top_left.x), maxf(12.0, bottom_right.y - top_left.y)))
    var room_range: Array = room_data.get("range", [0.0, 0.0])
    if room_range.size() < 2:
        return Rect2()
    var start_x := float(room_range[0])
    var end_x := float(room_range[1])
    var x0 := start_x / world_width * draw_width
    var x1 := end_x / world_width * draw_width
    var y := base_y + float(int(room_data.get("depth", 0))) * depth_step
    return Rect2(Vector2(x0, y), Vector2(maxf(34.0, x1 - x0 - 6.0), 42.0))


func _add_world_map_pins(draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary:
            var data: Dictionary = collectible
            _add_map_pin(_vec2(data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(1.0, 0.74, 0.24, 0.95), Vector2(9, 9), layout_bounds, draw_size)
    for interactive in config.get("interactives", []):
        if interactive is Dictionary:
            var data: Dictionary = interactive
            _add_map_pin(_vec2(data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(0.94, 0.54, 0.22, 0.95), Vector2(9, 9), layout_bounds, draw_size)
    var boss_data: Dictionary = config.get("boss", {})
    if not boss_data.is_empty():
        _add_map_pin(_vec2(boss_data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(0.86, 0.18, 0.16, 0.95), Vector2(14, 14), layout_bounds, draw_size)


func _add_map_pin(world_position: Vector2, draw_width: float, base_y: float, depth_step: float, color: Color, size_value: Vector2 = Vector2(9, 9), layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    var room := _room_for_position(world_position)
    if not room.is_empty() and not _room_is_visited(String(room.get("id", ""))):
        return
    var pin_pos := Vector2.ZERO
    if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
        pin_pos = _map_world_to_overlay(world_position, layout_bounds, draw_size) - size_value * 0.5
    else:
        var depth := 0
        if not room.is_empty():
            depth = int(room.get("depth", 0))
        pin_pos = Vector2(clampf(world_position.x / world_width * draw_width, 0.0, draw_width) - size_value.x * 0.5, base_y + float(depth) * depth_step - 18.0)
    _add_map_ui_rect("MapPin", pin_pos, size_value + Vector2(5.0, 5.0), color, Color(1.0, 0.95, 0.72, 0.95), 2.0)


func _add_map_route_line(rooms: Array, draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    var route := Line2D.new()
    route.name = "MapRouteLine"
    route.width = 4.0
    route.default_color = Color(0.54, 0.82, 0.92, 0.62) if _is_rain_foundry_theme() else Color(0.33, 0.72, 0.58, 0.58)
    route.z_index = 1
    var points := PackedVector2Array()
    var previous_point := Vector2.ZERO
    var has_previous_point := false
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var point := Vector2.ZERO
        var layout := _room_layout_rect(room_data)
        if layout.size.x > 0.0 and layout.size.y > 0.0 and layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
            point = _map_world_to_overlay(layout.position + layout.size * 0.5, layout_bounds, draw_size)
        else:
            var room_range: Array = room_data.get("range", [0.0, 0.0])
            if room_range.size() < 2:
                continue
            var center_x := ((float(room_range[0]) + float(room_range[1])) * 0.5) / world_width * draw_width
            var y := base_y + float(int(room_data.get("depth", 0))) * depth_step + 21.0
            point = Vector2(center_x, y)
        if has_previous_point and not is_equal_approx(previous_point.y, point.y):
            points.append(Vector2(previous_point.x, point.y))
        points.append(point)
        previous_point = point
        has_previous_point = true
    route.points = points
    map_draw_root.add_child(route)


func _add_map_wall_caps(room_id: String, rect_position: Vector2, rect_size: Vector2, visited: bool, current: bool) -> void:
    var alpha := 0.94 if visited or current else 0.62
    var wall_fill := Color(0.008, 0.014, 0.014, alpha)
    var wall_edge := Color(0.13, 0.22, 0.20, alpha)
    var cap_size := Vector2(5.0, maxf(18.0, rect_size.y - 14.0))
    var y := rect_position.y + 7.0
    _add_map_ui_rect("MapWallL_" + room_id, Vector2(rect_position.x - 2.0, y), cap_size, wall_fill, wall_edge, 1.0)
    _add_map_ui_rect("MapWallR_" + room_id, Vector2(rect_position.x + rect_size.x - 3.0, y), cap_size, wall_fill, wall_edge, 1.0)


func _add_map_special_passage_markers(draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    for interactive in config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var data: Dictionary = interactive
        var interact_type := String(data.get("kind", data.get("type", "")))
        if interact_type != "boss_gate" and interact_type != "chapter_exit" and interact_type != "ending_exit":
            continue
        var world_position := _vec2(data.get("position", [0, 0]))
        var room := _room_for_position(world_position)
        if not room.is_empty() and not _room_is_visited(String(room.get("id", ""))):
            continue
        var marker_position := Vector2.ZERO
        if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
            marker_position = _map_world_to_overlay(world_position, layout_bounds, draw_size)
        else:
            var depth := int(room.get("depth", 0)) if not room.is_empty() else 0
            marker_position = Vector2(clampf(world_position.x / world_width * draw_width, 0.0, draw_width), base_y + float(depth) * depth_step + 21.0)
        var marker_color := Color(1.0, 0.68, 0.24, 0.96) if interact_type == "boss_gate" else Color(0.45, 0.76, 1.0, 0.96)
        _add_map_ui_rect("MetSysPassage_" + interact_type, marker_position - Vector2(4.0, 17.0), Vector2(8.0, 34.0), marker_color, Color(1.0, 0.95, 0.72, 0.94), 2.0)


func _add_map_room_texture(rect_position: Vector2, rect_size: Vector2, visited: bool, current: bool) -> void:
    var texture := TextureRect.new()
    texture.name = "RoomMossTexture"
    texture.texture = _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["mid"] if _theme_uses_industrial_tiles() else MOSSY_PLATFORM_TILES["mid"])
    texture.position = rect_position + Vector2(3.0, 3.0)
    texture.size = rect_size - Vector2(6.0, 6.0)
    texture.stretch_mode = TextureRect.STRETCH_SCALE
    if current:
        texture.modulate = _theme_map_art_modulate() * Color(1.25, 1.25, 1.25, 1.75)
    elif visited:
        texture.modulate = _theme_map_art_modulate() * Color(0.92, 0.92, 0.92, 1.25)
    else:
        texture.modulate = _theme_map_art_modulate() * Color(0.42, 0.42, 0.42, 0.75)
    texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_draw_root.add_child(texture)


func _add_map_ui_rect(node_name: String, rect_position: Vector2, rect_size: Vector2, fill: Color, border: Color, border_width: float) -> ColorRect:
    var border_rect := ColorRect.new()
    border_rect.name = node_name + "Border"
    border_rect.position = rect_position - Vector2(border_width, border_width)
    border_rect.size = rect_size + Vector2(border_width * 2.0, border_width * 2.0)
    border_rect.color = border
    map_draw_root.add_child(border_rect)

    var fill_rect := ColorRect.new()
    fill_rect.name = node_name
    fill_rect.position = rect_position
    fill_rect.size = rect_size
    fill_rect.color = fill
    map_draw_root.add_child(fill_rect)
    return fill_rect


func _build_world_from_config() -> void:
    _background()
    for platform in config.get("platforms", []):
        _platform(
            String(platform.get("id", "platform")),
            _rect2(platform.get("rect", [])),
            _color(platform.get("color", "333333")),
            String(platform.get("material", "moss_stone"))
        )

    for gate in config.get("locked_gates", []):
        gate_body = _platform(
            String(gate.get("id", "locked_gate")),
            _rect2(gate.get("rect", [])),
            _color(gate.get("color", "875f29")),
            String(gate.get("material", "bronze_bridge"))
        )

    for hazard in config.get("hazards", []):
        _hazard(hazard)
    hazard_total = config.get("hazards", []).size()

    if _combat_progression_enabled():
        collectible_total = 0
    else:
        for collectible in config.get("collectibles", []):
            _collectible(collectible)
        collectible_total = config.get("collectibles", []).size()

    for interactive in config.get("interactives", []):
        var kind := String(interactive.get("kind", ""))
        if kind == "lever":
            _lever(interactive)
        elif kind == "boss_gate":
            _boss_door(interactive)
        elif kind == "chapter_exit" or kind == "ending_exit":
            _chapter_exit(interactive)

    for save_point in config.get("save_points", []):
        _save_point(save_point)
    save_point_total = config.get("save_points", []).size()
    hidden_save_point_total = 0
    for save_point in config.get("save_points", []):
        if save_point is Dictionary and bool(save_point.get("hidden", false)):
            hidden_save_point_total += 1

    for npc in config.get("npcs", []):
        _npc(npc)

    _spawn_normal_enemies()
    enemy_total = config.get("enemy_spawns", []).size()
    if _combat_progression_enabled() and _combat_goal_met():
        shortcut_open = true
        boss_unlocked = true

    # World labels are intentionally suppressed so tutorial copy does not cover the level art.


func _spawn_player() -> void:
    player = PLAYER_SCENE.instantiate()
    add_child(player)
    player.global_position = active_spawn
    player.set_spawn(active_spawn)
    player.hp_changed.connect(_on_hp_changed)
    player.energy_changed.connect(_on_energy_changed)
    player.player_respawned.connect(_on_player_respawned)
    _configure_player_camera()


func _build_hud() -> void:
    ui_canvas = CanvasLayer.new()
    add_child(ui_canvas)
    hud_label = Label.new()
    hud_label.position = Vector2(18, 14)
    hud_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
    ui_canvas.add_child(hud_label)

    toast_label = Label.new()
    toast_label.position = Vector2(18, 42)
    toast_label.add_theme_color_override("font_color", Color(0.62, 0.94, 0.86))
    ui_canvas.add_child(toast_label)

    win_label = Label.new()
    win_label.position = Vector2(380, 88)
    win_label.visible = false
    win_label.add_theme_font_size_override("font_size", 34)
    win_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
    ui_canvas.add_child(win_label)
    _build_backpack_overlay()
    _build_map_overlay()
    _build_dialogue_overlay()
    _refresh_hud()


func _build_dialogue_overlay() -> void:
    dialogue_panel = ColorRect.new()
    dialogue_panel.name = "DialogueOverlay"
    dialogue_panel.position = Vector2(72, 504)
    dialogue_panel.size = Vector2(1136, 172)
    dialogue_panel.color = Color(0.020, 0.024, 0.024, 0.94)
    dialogue_panel.visible = false
    ui_canvas.add_child(dialogue_panel)

    dialogue_name_label = Label.new()
    dialogue_name_label.position = Vector2(24, 16)
    dialogue_name_label.size = Vector2(330, 34)
    dialogue_name_label.add_theme_font_size_override("font_size", 24)
    dialogue_name_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.48))
    dialogue_panel.add_child(dialogue_name_label)

    dialogue_meta_label = Label.new()
    dialogue_meta_label.position = Vector2(372, 18)
    dialogue_meta_label.size = Vector2(730, 34)
    dialogue_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_meta_label.add_theme_font_size_override("font_size", 15)
    dialogue_meta_label.add_theme_color_override("font_color", Color(0.58, 0.90, 0.82))
    dialogue_panel.add_child(dialogue_meta_label)

    dialogue_text_label = Label.new()
    dialogue_text_label.position = Vector2(24, 58)
    dialogue_text_label.size = Vector2(1068, 70)
    dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text_label.add_theme_font_size_override("font_size", 20)
    dialogue_text_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.84))
    dialogue_panel.add_child(dialogue_text_label)

    dialogue_hint_label = Label.new()
    dialogue_hint_label.position = Vector2(24, 132)
    dialogue_hint_label.size = Vector2(1068, 28)
    dialogue_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_hint_label.add_theme_font_size_override("font_size", 14)
    dialogue_hint_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.68))
    dialogue_panel.add_child(dialogue_hint_label)


func _background() -> void:
    var left := -300.0
    var right := world_width + 300.0
    var top := -200.0
    var bottom := world_height + 220.0
    var bg := Polygon2D.new()
    bg.polygon = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
    bg.color = _theme_background_color()
    bg.z_index = -120
    add_child(bg)

    if _art_theme_id() == "salt_archive":
        _cemetery_background_layers()
    elif _art_theme_id() == "silent_crown":
        _godot_platformer_background_layers(_theme_background_tint())
    elif _theme_uses_kenney_deluxe():
        _kenney_deluxe_background_layers(_theme_background_tint())
    elif _theme_uses_industrial_tiles():
        _industrial_background_layers(_theme_background_tint())
    else:
        _background_layer("BgSkyCh01", "bg_sky", -118, _theme_background_tint())
        _background_layer("BgFarBellCourt", "bg_far", -114, _theme_background_tint())
        _background_layer("BgMidBellCourt", "bg_mid", -108, _theme_background_tint())
        _background_layer("BgFogCh01", "bg_fog", -102, _theme_background_tint())
        _background_layer("BgNearVinesCh01", "bg_near", -96, _theme_background_tint())

    var shade := Polygon2D.new()
    shade.polygon = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
    var shade_alpha := 0.035 if _art_theme_id() == "moss_cavern" else (0.03 if _theme_uses_industrial_tiles() else 0.08)
    shade.color = Color(0.0, 0.0, 0.0, shade_alpha)
    shade.z_index = -94
    add_child(shade)


func _configure_player_camera() -> void:
    var camera := player.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        return
    camera.limit_left = -40
    camera.limit_top = -120
    camera.limit_right = int(world_width + 80.0)
    camera.limit_bottom = int(world_height + 70.0)


func _void_respawn() -> void:
    if player == null or not is_instance_valid(player):
        return
    if player.has_method("restore_at_save_point"):
        player.restore_at_save_point()
    if player.has_method("respawn_at"):
        player.respawn_at(active_spawn)
    else:
        player.global_position = active_spawn
    _toast("You fell. Back to the save point.")
    _update_room_visit()
    _refresh_hud()


func _theme_background_color() -> Color:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return Color(0.065, 0.078, 0.080)
    if theme == "salt_archive":
        return Color(0.075, 0.070, 0.058)
    if theme == "string_greenhouse":
        return Color(0.043, 0.068, 0.052)
    if theme == "obsidian_pilgrim":
        return Color(0.052, 0.047, 0.052)
    if theme == "silent_crown":
        return Color(0.040, 0.045, 0.062)
    return Color(0.055, 0.065, 0.072)


func _theme_background_tint() -> Color:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return Color(0.70, 0.92, 1.0, 1.0)
    if theme == "salt_archive":
        return Color(1.0, 0.92, 0.72, 1.0)
    if theme == "string_greenhouse":
        return Color(0.68, 1.0, 0.70, 1.0)
    if theme == "obsidian_pilgrim":
        return Color(1.0, 0.62, 0.48, 1.0)
    if theme == "silent_crown":
        return Color(0.72, 0.78, 1.0, 1.0)
    return Color(1.0, 1.0, 1.0, 1.0)


func _background_layer(node_name: String, sprite_key: String, z_value: int, tint: Color = Color.WHITE) -> void:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = _load_texture_resource(SPRITES[sprite_key])
    sprite.centered = false
    sprite.position = Vector2(-180, -40)
    if sprite.texture != null and sprite.texture.get_width() > 0 and sprite.texture.get_height() > 0:
        sprite.scale = Vector2(1.12, 1.12)
        if sprite_key == "bg_far":
            sprite.position = Vector2(760, -50)
            sprite.modulate = Color(0.75, 0.88, 0.82, 0.42) * tint
        elif sprite_key == "bg_mid":
            sprite.position = Vector2(1700, -35)
            sprite.modulate = Color(0.70, 0.94, 0.82, 0.34) * tint
        elif sprite_key == "bg_near":
            sprite.position = Vector2(-120, -320)
            sprite.scale = Vector2(0.36, 0.36)
            sprite.modulate = Color(0.76, 0.98, 0.80, 0.46) * tint
        else:
            sprite.modulate = tint
    sprite.z_index = z_value
    add_child(sprite)


func _cemetery_background_layers() -> void:
    _background_repeated_sprite(
        "BgCemeterySky",
        GOTHICVANIA_CEMETERY_ASSETS["background"],
        Vector2(-220, -70),
        384.0,
        Color(0.82, 0.78, 0.62, 0.30),
        -118,
        Vector2(2.4, 2.4),
        0.0
    )
    _background_repeated_sprite(
        "BgCemeteryMountains",
        GOTHICVANIA_CEMETERY_ASSETS["mountains"],
        Vector2(-120, 70),
        520.0,
        Color(0.70, 0.64, 0.48, 0.42),
        -112,
        Vector2(2.15, 2.15),
        18.0
    )
    _background_repeated_sprite(
        "BgCemeteryGraveyard",
        GOTHICVANIA_CEMETERY_ASSETS["graveyard"],
        Vector2(-80, 290),
        520.0,
        Color(0.88, 0.80, 0.56, 0.42),
        -104,
        Vector2(2.0, 2.0),
        16.0
    )


func _kenney_deluxe_background_layers(tint: Color = Color.WHITE) -> void:
    var texture_path := KENNEY_DELUXE_ASSETS["bg_castle"] if _art_theme_id() == "obsidian_pilgrim" or _art_theme_id() == "silent_crown" else KENNEY_DELUXE_ASSETS["bg"]
    _background_repeated_sprite(
        "BgKenneyDeluxe",
        texture_path,
        Vector2(-160, 24),
        512.0,
        Color(0.48, 0.58, 0.66, 0.23) * tint,
        -116,
        Vector2(2.8, 2.8),
        22.0
    )
    _background_repeated_sprite(
        "BgKenneyDeluxeFar",
        texture_path,
        Vector2(120, 240),
        760.0,
        Color(0.42, 0.50, 0.56, 0.16) * tint,
        -108,
        Vector2(2.0, 2.0),
        32.0
    )


func _godot_platformer_background_layers(tint: Color = Color.WHITE) -> void:
    _background_repeated_sprite(
        "BgSilentSky",
        GODOT_PLATFORMER_2D_ASSETS["sky"],
        Vector2(-160, -90),
        480.0,
        Color(0.40, 0.48, 0.76, 0.28) * tint,
        -118,
        Vector2(3.2, 3.2),
        0.0
    )
    _background_repeated_sprite(
        "BgSilentMountains",
        GODOT_PLATFORMER_2D_ASSETS["mountains"],
        Vector2(-180, 120),
        900.0,
        Color(0.50, 0.56, 0.82, 0.30) * tint,
        -108,
        Vector2(1.35, 1.35),
        28.0
    )


func _industrial_background_layers(tint: Color = Color.WHITE) -> void:
    _background_repeated_sprite(
        "BgFoundryPanel",
        INDUSTRIAL_PLATFORM_TILES["panel"],
        Vector2(-160, 78),
        520.0,
        Color(0.52, 0.64, 0.63, 0.22) * tint,
        -116,
        Vector2(2.45, 2.45),
        28.0
    )
    _background_repeated_sprite(
        "BgFoundryPipe",
        INDUSTRIAL_PLATFORM_TILES["pipe"],
        Vector2(-80, 300),
        350.0,
        Color(0.58, 0.76, 0.78, 0.30) * tint,
        -110,
        Vector2(1.55, 2.95),
        18.0
    )
    _background_repeated_sprite(
        "BgFoundryGear",
        INDUSTRIAL_PLATFORM_TILES["gear"],
        Vector2(640, 118),
        1450.0,
        Color(0.72, 0.82, 0.80, 0.22) * tint,
        -104,
        Vector2(1.65, 1.65),
        42.0
    )
    _background_repeated_sprite(
        "BgFoundrySignal",
        INDUSTRIAL_PLATFORM_TILES["light_blue"],
        Vector2(360, 220),
        1180.0,
        Color(0.80, 0.96, 1.0, 0.26) * tint,
        -101,
        Vector2(1.0, 1.0),
        30.0
    )
    _background_rain_streaks()


func _background_repeated_sprite(node_prefix: String, texture_path: String, start_position: Vector2, spacing: float, tint: Color, z_value: int, scale_value: Vector2, y_wave: float) -> void:
    var texture := _load_texture_resource(texture_path)
    if texture == null:
        return
    var x := start_position.x
    var index := 0
    while x < world_width + 700.0:
        var sprite := Sprite2D.new()
        sprite.name = "%s%02d" % [node_prefix, index]
        sprite.texture = texture
        sprite.centered = false
        sprite.position = Vector2(x, start_position.y + float((index % 3) - 1) * y_wave)
        sprite.scale = scale_value
        sprite.modulate = tint
        sprite.z_index = z_value
        add_child(sprite)
        x += spacing
        index += 1


func _background_rain_streaks() -> void:
    var index := 0
    var x := -240.0
    while x < world_width + 500.0:
        var rain := Line2D.new()
        rain.name = "BgRainStreak%02d" % index
        var top_y := -80.0 + float(index % 5) * 34.0
        rain.points = PackedVector2Array([
            Vector2(x, top_y),
            Vector2(x - 36.0, top_y + 190.0)
        ])
        rain.width = 2.0
        rain.default_color = Color(0.58, 0.82, 0.88, 0.18)
        rain.z_index = -98
        add_child(rain)
        x += 155.0
        index += 1


func _platform(node_name: String, rect: Rect2, color: Color, material: String = "moss_stone") -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = node_name
    body.position = rect.position + rect.size * 0.5
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = rect.size
    shape.shape = rectangle
    body.add_child(shape)

    _add_platform_readability_base(body, rect.size, material, color)
    _add_platform_plate(body, Vector2(0, 18), rect.size + Vector2(12, 36), _platform_shadow_color(material), -7)
    _add_platform_visual(body, rect.size, material)
    _decorate_platform(body, rect.size, material)
    add_child(body)
    return body


func _add_platform_readability_base(parent: Node, size_value: Vector2, material: String, fallback_color: Color) -> void:
    var body_color := _platform_body_color(material, fallback_color)
    var edge_color := _platform_edge_color(material)
    _add_platform_plate(parent, Vector2(0, 6.0), size_value + Vector2(10.0, 18.0), body_color, -6)
    _add_platform_plate(parent, Vector2(0, -size_value.y * 0.5 + 4.0), Vector2(size_value.x + 12.0, 8.0), edge_color, -2)
    _add_platform_plate(parent, Vector2(0, size_value.y * 0.5 - 3.0), Vector2(size_value.x + 8.0, 5.0), Color(0.015, 0.026, 0.024, 0.82), -2)


func _platform_body_color(material: String, fallback_color: Color) -> Color:
    if material == "moss_stone":
        return Color(0.105, 0.185, 0.145, 0.96)
    if material == "bronze_bridge":
        return Color(0.185, 0.160, 0.092, 0.95)
    if material == "boss_stone":
        return Color(0.180, 0.105, 0.095, 0.96)
    if material.contains("wall") or material.contains("gate"):
        return Color(0.145, 0.105, 0.092, 0.98)
    return Color(fallback_color.r, fallback_color.g, fallback_color.b, maxf(fallback_color.a, 0.92))


func _platform_edge_color(material: String) -> Color:
    if material == "moss_stone":
        return Color(0.42, 0.74, 0.47, 0.96)
    if material == "bronze_bridge":
        return Color(0.76, 0.63, 0.30, 0.94)
    if material == "boss_stone":
        return Color(0.76, 0.44, 0.36, 0.95)
    return Color(0.50, 0.68, 0.55, 0.86)


func _add_platform_plate(parent: Node, local_center: Vector2, plate_size: Vector2, plate_color: Color, z_value: int) -> Polygon2D:
    var plate := Polygon2D.new()
    var half := plate_size * 0.5
    plate.polygon = PackedVector2Array([
        local_center + Vector2(-half.x, -half.y),
        local_center + Vector2(half.x, -half.y),
        local_center + Vector2(half.x, half.y),
        local_center + Vector2(-half.x, half.y)
    ])
    plate.color = plate_color
    plate.z_index = z_value
    parent.add_child(plate)
    return plate


func _platform_shadow_color(material: String) -> Color:
    if material == "salt_marble" or material == "vellum_bridge" or material == "archive_boss":
        return Color(0.02, 0.018, 0.014, 0.22)
    if material == "moss_stone" or material == "bronze_bridge" or material == "boss_stone":
        return Color(0.0, 0.025, 0.016, 0.26)
    return Color(0.0, 0.0, 0.0, 0.32)


func _add_platform_visual(parent: Node, size_value: Vector2, material: String) -> void:
    if _is_cemetery_material(material):
        _add_cemetery_platform_visual(parent, size_value, material)
        return
    var kenney_family := _kenney_deluxe_family(material)
    if not kenney_family.is_empty():
        _add_kenney_deluxe_platform_visual(parent, size_value, material, kenney_family)
        return
    if _is_industrial_material(material):
        _add_industrial_platform_visual(parent, size_value, material)
        return
    _add_mossy_platform_visual(parent, size_value, material)


func _is_cemetery_material(material: String) -> bool:
    return material == "salt_marble" or material == "vellum_bridge" or material == "archive_boss"


func _kenney_deluxe_family(material: String) -> String:
    if material == "greenhouse_loam":
        return "grass"
    if material == "glassvine_bridge":
        return "grass_half"
    if material == "root_boss":
        return "dirt"
    if material == "obsidian_basalt":
        return "stone"
    if material == "ember_bridge" or material == "pilgrim_boss":
        return "castle"
    if material == "crown_bone":
        return "snow"
    if material == "void_bridge" or material == "core_boss":
        return "snow_half"
    return ""


func _is_industrial_material(material: String) -> bool:
    return material in ["rain_pipe", "wet_metal", "sluice_bridge", "foundry_boss", "drain_grate"] or _theme_uses_industrial_tiles()


func _add_mossy_platform_visual(parent: Node, size_value: Vector2, material: String) -> void:
    var tint := _platform_tint(material)
    var top_y := -size_value.y * 0.5
    var visual_center_y := top_y + 52.0
    var left_texture := _load_texture_resource(MOSSY_PLATFORM_TILES["left"])
    var mid_texture := _load_texture_resource(MOSSY_PLATFORM_TILES["mid"])
    var mid_alt_texture := _load_texture_resource(MOSSY_PLATFORM_TILES["mid_alt"])
    var right_texture := _load_texture_resource(MOSSY_PLATFORM_TILES["right"])
    var cap_texture := _load_texture_resource(MOSSY_PLATFORM_TILES["cap_small"])

    if size_value.x < 165.0 and cap_texture != null:
        _add_platform_sprite(parent, "Material", cap_texture, Vector2.ZERO + Vector2(0, visual_center_y + 8.0), tint, -3)
        return
    if left_texture == null or mid_texture == null or right_texture == null:
        _add_platform_plate(parent, Vector2(0, 8), size_value, Color(0.06, 0.12, 0.09, 0.90), -4)
        return

    var left_width := float(left_texture.get_width())
    var right_width := float(right_texture.get_width())
    var start_x := -size_value.x * 0.5
    var end_x := size_value.x * 0.5
    _add_platform_sprite(parent, "Material", left_texture, Vector2(start_x + left_width * 0.5, visual_center_y), tint, -3)
    _add_platform_sprite(parent, "MossyPlatformRight", right_texture, Vector2(end_x - right_width * 0.5, visual_center_y), tint, -3)

    var x := start_x + left_width
    var index := 0
    while x < end_x - right_width - 12.0:
        var texture := mid_texture if index % 2 == 0 or mid_alt_texture == null else mid_alt_texture
        var tile_width := float(texture.get_width())
        _add_platform_sprite(parent, "MossyPlatformTile", texture, Vector2(x + tile_width * 0.5, visual_center_y), tint, -3)
        x += tile_width - 8.0
        index += 1


func _add_industrial_platform_visual(parent: Node, size_value: Vector2, material: String) -> void:
    var tint := _platform_tint(material)
    var top_y := -size_value.y * 0.5
    var visual_center_y := top_y + 35.0
    var left_texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["left"])
    var mid_texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["mid"])
    var mid_alt_texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["mid_alt"])
    var right_texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["right"])
    var cap_texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["cap_small"])

    if size_value.x < 140.0 and cap_texture != null:
        _add_platform_sprite(parent, "IndustrialPlatformCap", cap_texture, Vector2(0, visual_center_y), tint, -3)
        return
    if left_texture == null or mid_texture == null or right_texture == null:
        _add_platform_plate(parent, Vector2(0, 8), size_value, Color(0.24, 0.31, 0.31, 0.92), -4)
        return

    var left_width := float(left_texture.get_width())
    var right_width := float(right_texture.get_width())
    var start_x := -size_value.x * 0.5
    var end_x := size_value.x * 0.5
    _add_platform_sprite(parent, "IndustrialPlatformLeft", left_texture, Vector2(start_x + left_width * 0.5, visual_center_y), tint, -3)
    _add_platform_sprite(parent, "IndustrialPlatformRight", right_texture, Vector2(end_x - right_width * 0.5, visual_center_y), tint, -3)

    var x := start_x + left_width
    var index := 0
    while x < end_x - right_width - 8.0:
        var texture := mid_texture if index % 2 == 0 or mid_alt_texture == null else mid_alt_texture
        var tile_width := float(texture.get_width())
        _add_platform_sprite(parent, "IndustrialPlatformTile", texture, Vector2(x + tile_width * 0.5, visual_center_y), tint, -3)
        x += tile_width - 4.0
        index += 1

    if material == "sluice_bridge" or material == "foundry_boss":
        _add_industrial_warning_strip(parent, size_value, top_y + 71.0)


func _add_cemetery_platform_visual(parent: Node, size_value: Vector2, material: String) -> void:
    var texture := _load_texture_resource(GOTHICVANIA_CEMETERY_ASSETS["tileset"])
    var tint := _platform_tint(material)
    var top_y := -size_value.y * 0.5
    var visual_center_y := top_y + 34.0
    _add_cemetery_platform_fill(parent, size_value, material)
    if texture == null:
        _add_platform_plate(parent, Vector2(0, 8), size_value, Color(0.17, 0.14, 0.16, 0.94), -4)
        return
    if size_value.x < 150.0:
        _add_platform_region_sprite(parent, "CemeteryPlatformCap", texture, CEMETERY_PLATFORM_REGIONS["cap_small"], Vector2(0, visual_center_y), tint, -3)
        return
    var left_region: Array = CEMETERY_PLATFORM_REGIONS["left"]
    var mid_region: Array = CEMETERY_PLATFORM_REGIONS["mid"]
    var right_region: Array = CEMETERY_PLATFORM_REGIONS["right"]
    var start_x := -size_value.x * 0.5
    var end_x := size_value.x * 0.5
    var left_width := float(left_region[2])
    var right_width := float(right_region[2])
    _add_platform_region_sprite(parent, "CemeteryPlatformLeft", texture, left_region, Vector2(start_x + left_width * 0.5, visual_center_y), tint, -3)
    _add_platform_region_sprite(parent, "CemeteryPlatformRight", texture, right_region, Vector2(end_x - right_width * 0.5, visual_center_y), tint, -3)
    var x := start_x + left_width
    var tile_stride := 54.0
    while x < end_x - right_width:
        var region: Array = mid_region
        var tile_width := float(region[2])
        var draw_width := minf(tile_width, end_x - right_width - x)
        if draw_width <= 0.0:
            break
        var tile := _add_platform_region_sprite(parent, "CemeteryPlatformTile", texture, region, Vector2(x + draw_width * 0.5, visual_center_y), tint, -3)
        tile.region_rect = Rect2(float(region[0]), float(region[1]), draw_width, float(region[3]))
        x += minf(tile_stride, draw_width)


func _add_cemetery_platform_fill(parent: Node, size_value: Vector2, material: String) -> void:
    var base := Color(0.30, 0.27, 0.22, 0.96)
    var top := Color(0.63, 0.58, 0.40, 0.76)
    if material == "vellum_bridge":
        base = Color(0.38, 0.33, 0.22, 0.95)
        top = Color(0.82, 0.70, 0.43, 0.76)
    elif material == "archive_boss":
        base = Color(0.35, 0.27, 0.20, 0.96)
        top = Color(0.88, 0.65, 0.42, 0.78)
    _add_platform_plate(parent, Vector2(0, 8), size_value, base, -5)
    _add_platform_plate(parent, Vector2(0, -size_value.y * 0.5 + 5.0), Vector2(size_value.x, 10.0), top, -4)


func _add_kenney_deluxe_platform_visual(parent: Node, size_value: Vector2, material: String, family: String) -> void:
    var family_tiles: Dictionary = KENNEY_DELUXE_TILE_FAMILIES.get(family, {})
    var tint := _platform_tint(material)
    var top_y := -size_value.y * 0.5
    var visual_center_y := top_y + 34.0
    var left_texture := _load_texture_resource(String(family_tiles.get("left", "")))
    var mid_texture := _load_texture_resource(String(family_tiles.get("mid", "")))
    var right_texture := _load_texture_resource(String(family_tiles.get("right", "")))
    if left_texture == null or mid_texture == null or right_texture == null:
        _add_platform_plate(parent, Vector2(0, 8), size_value, Color(0.12, 0.16, 0.16, 0.92), -4)
        return
    if size_value.x < 132.0:
        var cap := _add_platform_sprite(parent, "KenneyDeluxePlatformCap", mid_texture, Vector2(0, visual_center_y), tint, -3)
        cap.scale = Vector2(0.72, 0.72)
        return
    var left_width := float(left_texture.get_width())
    var right_width := float(right_texture.get_width())
    var start_x := -size_value.x * 0.5
    var end_x := size_value.x * 0.5
    _add_platform_sprite(parent, "KenneyDeluxePlatformLeft", left_texture, Vector2(start_x + left_width * 0.5, visual_center_y), tint, -3)
    _add_platform_sprite(parent, "KenneyDeluxePlatformRight", right_texture, Vector2(end_x - right_width * 0.5, visual_center_y), tint, -3)
    var x := start_x + left_width
    var index := 0
    while x < end_x - right_width - 4.0:
        var tile_width := float(mid_texture.get_width())
        _add_platform_sprite(parent, "KenneyDeluxePlatformTile", mid_texture, Vector2(x + tile_width * 0.5, visual_center_y), tint, -3)
        x += tile_width - 3.0
        index += 1


func _add_industrial_warning_strip(parent: Node, size_value: Vector2, local_y: float) -> void:
    var texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES["warning"])
    if texture == null:
        return
    var start_x := -size_value.x * 0.5 + 44.0
    var end_x := size_value.x * 0.5 - 44.0
    var x := start_x
    while x < end_x:
        _add_platform_sprite(parent, "IndustrialWarningStripe", texture, Vector2(x, local_y), Color(1.0, 1.0, 1.0, 0.92), -2)
        x += 68.0


func _add_platform_sprite(parent: Node, node_name: String, texture: Texture2D, local_position: Vector2, tint: Color, z_value: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.position = local_position
    sprite.modulate = tint
    sprite.z_index = z_value
    parent.add_child(sprite)
    return sprite


func _add_platform_region_sprite(parent: Node, node_name: String, texture: Texture2D, region_value: Array, local_position: Vector2, tint: Color, z_value: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(float(region_value[0]), float(region_value[1]), float(region_value[2]), float(region_value[3]))
    sprite.position = local_position
    sprite.modulate = tint
    sprite.z_index = z_value
    parent.add_child(sprite)
    return sprite


func _platform_tint(material: String) -> Color:
    if material == "archive_boss":
        return Color(1.0, 0.88, 0.60, 1.0)
    if material == "vellum_bridge":
        return Color(0.96, 0.90, 0.72, 1.0)
    if material == "salt_marble":
        return Color(0.86, 0.88, 0.76, 1.0)
    if material == "root_boss":
        return Color(0.76, 0.92, 0.60, 1.0)
    if material == "glassvine_bridge":
        return Color(0.62, 0.96, 0.74, 1.0)
    if material == "greenhouse_loam":
        return Color(0.68, 0.88, 0.55, 1.0)
    if material == "pilgrim_boss":
        return Color(1.0, 0.55, 0.42, 1.0)
    if material == "ember_bridge":
        return Color(0.92, 0.56, 0.38, 1.0)
    if material == "obsidian_basalt":
        return Color(0.58, 0.56, 0.65, 1.0)
    if material == "core_boss":
        return Color(0.72, 0.78, 1.0, 1.0)
    if material == "void_bridge":
        return Color(0.62, 0.66, 0.88, 1.0)
    if material == "crown_bone":
        return Color(0.78, 0.82, 0.96, 1.0)
    if material == "foundry_boss":
        return Color(1.0, 0.82, 0.62, 1.0)
    if material == "sluice_bridge":
        return Color(0.98, 0.94, 0.76, 1.0)
    if material == "rain_pipe":
        return Color(0.76, 0.92, 0.98, 1.0)
    if material == "drain_grate":
        return Color(0.74, 0.82, 0.82, 1.0)
    if material == "wet_metal":
        return Color(0.88, 0.98, 1.0, 1.0)
    if material == "boss_stone":
        return Color(0.88, 0.78, 0.74, 1.0)
    if material == "bronze_bridge":
        return Color(0.95, 0.94, 0.78, 1.0)
    return Color(1.0, 1.0, 1.0, 1.0)


func _decorate_platform(parent: Node, size_value: Vector2, material: String) -> void:
    var width: float = size_value.x
    var top_y: float = -size_value.y * 0.5
    var segment_count: int = maxi(2, int(width / 86.0))
    for index in range(segment_count):
        var t := float(index + 1) / float(segment_count + 1)
        var x := -width * 0.5 + width * t
        if material == "greenhouse_loam" and index % 2 == 0:
            _add_vine(parent, Vector2(x + 16.0, top_y + 18.0), Color(0.50, 0.95, 0.50, 0.88))
        elif material == "glassvine_bridge" and index % 3 == 1:
            _add_vine(parent, Vector2(x + 8.0, top_y + 18.0), Color(0.42, 1.0, 0.76, 0.74))
        elif material == "root_boss" and index % 2 == 1:
            _add_crack(parent, Vector2(x - 8.0, top_y + 16.0), Color(0.42, 0.82, 0.36, 0.80))
        elif material == "salt_marble" or material == "vellum_bridge" or material == "archive_boss":
            if index % 3 == 1:
                _add_crack(parent, Vector2(x - 8.0, top_y + 48.0), Color(0.92, 0.78, 0.50, 0.72))
        elif material == "obsidian_basalt" or material == "ember_bridge" or material == "pilgrim_boss":
            if index % 2 == 0:
                _add_crack(parent, Vector2(x - 12.0, top_y + 44.0), Color(1.0, 0.34, 0.22, 0.68))
        elif material == "crown_bone" or material == "void_bridge" or material == "core_boss":
            if index % 2 == 1:
                _add_crack(parent, Vector2(x - 12.0, top_y + 44.0), Color(0.54, 0.68, 1.0, 0.74))
        elif _is_industrial_material(material) and index % 3 == 1:
            _add_pipe_marker(parent, Vector2(x, top_y + 52.0), material)


func _add_pipe_marker(parent: Node, local_position: Vector2, material: String) -> void:
    var texture_key := "light_yellow" if material == "foundry_boss" else "pipe_cap"
    var texture := _load_texture_resource(INDUSTRIAL_PLATFORM_TILES[texture_key])
    if texture == null:
        return
    var tint := Color(1.0, 0.88, 0.56, 0.80) if material == "foundry_boss" else Color(0.70, 0.94, 1.0, 0.62)
    var marker := _add_platform_sprite(parent, "IndustrialPipeMarker", texture, local_position, tint, 1)
    marker.scale = Vector2(0.52, 0.52)


func _add_vine(parent: Node, local_position: Vector2, vine_color: Color = Color(0.33, 0.70, 0.34, 0.82)) -> void:
    var vine := Line2D.new()
    vine.name = "MossVine"
    vine.points = PackedVector2Array([
        local_position,
        local_position + Vector2(-4.0, 18.0),
        local_position + Vector2(3.0, 36.0)
    ])
    vine.width = 3.0
    vine.default_color = vine_color
    vine.z_index = 2
    parent.add_child(vine)


func _add_crack(parent: Node, local_position: Vector2, crack_color: Color) -> void:
    var crack := Line2D.new()
    crack.name = "RedStoneCrack"
    crack.points = PackedVector2Array([
        local_position,
        local_position + Vector2(14.0, 6.0),
        local_position + Vector2(7.0, 20.0),
        local_position + Vector2(31.0, 28.0)
    ])
    crack.width = 2.0
    crack.default_color = crack_color
    crack.z_index = 2
    parent.add_child(crack)


func _hazard(data: Dictionary) -> void:
    var rect := _rect2(data.get("rect", []))
    var area := Area2D.new()
    area.name = String(data.get("id", "hazard"))
    area.position = rect.position + rect.size * 0.5
    area.set_meta("message", String(data.get("message", "Trap hit.")))
    area.set_meta("damage", int(data.get("damage", 1)))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = rect.size
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES.get(String(data.get("kind", "spikes")), SPRITES["spikes"]))
    var visual_scale := maxf(rect.size.x, rect.size.y) / 112.0
    sprite.scale = Vector2(visual_scale, visual_scale)
    sprite.position = Vector2(0, -rect.size.y * 0.9)
    sprite.z_index = 6
    area.add_child(sprite)
    area.body_entered.connect(_on_hazard_body_entered.bind(area))
    add_child(area)


func _collectible(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "collectible"))
    area.position = _vec2(data.get("position", [0, 0]))
    area.set_meta("message", "Bell key acquired.")
    area.set_meta("kind", String(data.get("kind", "bell_key")))
    area.set_meta("object_id", "collectible/" + area.name)

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18
    shape.shape = circle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES["bell_key"])
    sprite.scale = Vector2(0.45, 0.45)
    area.add_child(sprite)
    area.body_entered.connect(_on_collectible_body_entered.bind(area))
    add_child(area)
    if metsys_bridge != null:
        var room := _room_for_position(area.global_position)
        metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


func _lever(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "shortcut_lever"))
    area.position = _vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "lever")
    area.set_meta("label", String(data.get("label", "Boss Route Control" if _combat_progression_enabled() else "Shortcut Lever")))
    area.set_meta("object_id", "interactable/" + area.name)
    area.set_meta("requires_keys", int(data.get("requires_keys", max_bells)))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(50, 72)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES["lever"])
    sprite.scale = Vector2(0.52, 0.52)
    area.add_child(sprite)
    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)
    if metsys_bridge != null:
        var room := _room_for_position(area.global_position)
        metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


func _boss_door(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "boss_gate"))
    area.position = _vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "boss_gate")
    area.set_meta("label", "Boss Gate")
    area.set_meta("object_id", "interactable/" + area.name)

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(96, 126)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES["boss_gate"])
    sprite.scale = Vector2(0.82, 0.82)
    area.add_child(sprite)
    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)
    if metsys_bridge != null:
        var room := _room_for_position(area.global_position)
        metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


func _chapter_exit(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "chapter_exit"))
    area.position = _vec2(data.get("position", [0, 0]))
    var kind := String(data.get("kind", "chapter_exit"))
    area.set_meta("kind", kind)
    area.set_meta("label", String(data.get("label", "Chapter Exit")))
    area.set_meta("object_id", "interactable/" + area.name)
    area.set_meta("next_runtime_config_id", String(data.get("next_runtime_config_id", "")))
    area.set_meta("next_config_path", String(data.get("next_config_path", "")))
    area.set_meta("requires_demo_complete", bool(data.get("requires_demo_complete", true)))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = _vec2(data.get("interaction_size", [210, 156]))
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.name = "ChapterExitSprite"
    sprite.texture = load(SPRITES["boss_gate"])
    sprite.scale = Vector2(0.66, 0.66)
    sprite.modulate = Color(0.48, 1.0, 0.92, 0.84) if kind == "chapter_exit" else Color(1.0, 0.74, 0.96, 0.88)
    sprite.z_index = 7
    area.add_child(sprite)

    var glow := Line2D.new()
    glow.name = "ChapterExitGlow"
    glow.width = 3.0
    glow.closed = true
    glow.default_color = Color(0.42, 1.0, 0.92, 0.62) if kind == "chapter_exit" else Color(1.0, 0.54, 0.88, 0.70)
    glow.points = PackedVector2Array([
        Vector2(-36, -52), Vector2(36, -52), Vector2(46, 0), Vector2(30, 54), Vector2(-30, 54), Vector2(-46, 0)
    ])
    glow.z_index = 8
    area.add_child(glow)

    var tween := create_tween()
    tween.set_loops()
    tween.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.8)
    tween.parallel().tween_property(glow, "modulate:a", 0.42, 0.8)
    tween.tween_property(glow, "scale", Vector2(0.96, 0.96), 0.8)
    tween.parallel().tween_property(glow, "modulate:a", 1.0, 0.8)

    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)
    if metsys_bridge != null:
        var room := _room_for_position(area.global_position)
        metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


func _save_point(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "save_point"))
    area.position = _vec2(data.get("position", active_spawn))
    area.set_meta("kind", "save_point")
    area.set_meta("label", String(data.get("label", "Save Point")))
    area.set_meta("hidden", bool(data.get("hidden", false)))
    area.set_meta("object_id", "save_point/" + area.name)
    area.set_meta("activated", false)

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 42 if bool(data.get("hidden", false)) else 52
    shape.shape = circle
    area.add_child(shape)

    var pedestal := Polygon2D.new()
    pedestal.name = "SavePointPedestal"
    pedestal.polygon = PackedVector2Array([
        Vector2(-32, 28),
        Vector2(-18, 8),
        Vector2(0, 0),
        Vector2(18, 8),
        Vector2(32, 28)
    ])
    pedestal.color = Color(0.13, 0.22, 0.20, 0.94)
    pedestal.z_index = 5
    area.add_child(pedestal)

    var marker := Sprite2D.new()
    marker.name = "SavePointSprite"
    marker.texture = load(SPRITES["save_point"])
    marker.position = Vector2(0, -18)
    marker.scale = Vector2(2.9, 2.9)
    marker.modulate = Color(0.70, 1.0, 0.82, 0.84) if bool(data.get("hidden", false)) else Color(0.92, 1.0, 0.62, 1.0)
    marker.z_index = 8
    area.add_child(marker)

    var ring := Line2D.new()
    ring.name = "SavePointHalo"
    ring.width = 3.0
    ring.default_color = Color(0.40, 1.0, 0.78, 0.48) if bool(data.get("hidden", false)) else Color(0.78, 1.0, 0.56, 0.72)
    ring.closed = true
    ring.z_index = 6
    ring.points = PackedVector2Array([
        Vector2(-24, 8), Vector2(-10, -13), Vector2(12, -15), Vector2(27, 7), Vector2(10, 24), Vector2(-14, 22)
    ])
    area.add_child(ring)

    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)
    _animate_save_point(area, marker, ring)
    if metsys_bridge != null:
        var room := _room_for_position(area.global_position)
        metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


func _animate_save_point(area: Area2D, marker: Sprite2D, ring: Line2D) -> void:
    var bob := create_tween()
    bob.set_loops()
    bob.tween_property(marker, "position:y", -26.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    bob.tween_property(marker, "position:y", -18.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var pulse := create_tween()
    pulse.set_loops()
    pulse.tween_property(ring, "scale", Vector2(1.22, 1.22), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(ring, "modulate:a", 0.35, 0.95)
    pulse.tween_property(ring, "scale", Vector2(0.92, 0.92), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(ring, "modulate:a", 0.95, 0.95)

    var blink := create_tween()
    blink.set_loops()
    blink.tween_property(area, "modulate:a", 0.82, 1.25)
    blink.tween_property(area, "modulate:a", 1.0, 1.25)


func _play_save_point_activation(area: Area2D) -> void:
    area.set_meta("activated", true)
    var sprite := area.get_node_or_null("SavePointSprite") as Sprite2D
    var ring := area.get_node_or_null("SavePointHalo") as Line2D
    if sprite != null:
        sprite.modulate = Color(0.96, 1.0, 0.62, 1.0)
        var flash := create_tween()
        flash.tween_property(sprite, "scale", Vector2(3.45, 3.45), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flash.tween_property(sprite, "scale", Vector2(2.9, 2.9), 0.18)
    if ring != null:
        ring.default_color = Color(0.90, 1.0, 0.58, 0.95)
    for index in range(3):
        var echo := Line2D.new()
        echo.name = "SavePointActivationRing"
        echo.global_position = area.global_position + Vector2(0, -10)
        echo.closed = true
        echo.width = 3.0
        echo.default_color = Color(0.74, 1.0, 0.70, 0.78)
        echo.z_index = 90
        var points := PackedVector2Array()
        for step in range(32):
            var angle := TAU * float(step) / 32.0
            points.append(Vector2(cos(angle), sin(angle)) * (24.0 + float(index) * 8.0))
        echo.points = points
        add_child(echo)
        var tween := create_tween()
        tween.tween_interval(float(index) * 0.07)
        tween.tween_property(echo, "scale", Vector2(2.15, 2.15), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(echo, "modulate:a", 0.0, 0.38)
        tween.finished.connect(Callable(echo, "queue_free"))


func _npc(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "npc"))
    area.position = _vec2(data.get("position", [0, 0]))
    var role := String(data.get("role", ""))
    area.set_meta("kind", "npc")
    area.set_meta("label", _npc_display_name(data))
    area.set_meta("dialogue", _npc_dialogue(data))
    area.set_meta("dialogue_index", 0)
    area.set_meta("identity", String(data.get("identity", "")))
    area.set_meta("help", String(data.get("help", "")))

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 34
    shape.shape = circle
    area.add_child(shape)

    var npc_texture := _load_texture_resource(String(NPC_SPRITES.get(role, "")))
    if npc_texture != null:
        var sprite := Sprite2D.new()
        sprite.name = "FriendlyFamilySprite"
        sprite.texture = npc_texture
        sprite.position = Vector2(0, -24)
        sprite.scale = Vector2(0.46, 0.46)
        sprite.modulate = Color(0.86, 1.0, 0.92, 0.92)
        sprite.z_index = 3
        area.add_child(sprite)
    else:
        var body := Polygon2D.new()
        body.polygon = PackedVector2Array([
            Vector2(-16, 26),
            Vector2(-22, -8),
            Vector2(0, -30),
            Vector2(22, -8),
            Vector2(16, 26)
        ])
        body.color = Color(0.18, 0.31, 0.34, 0.92)
        area.add_child(body)

        var face := Polygon2D.new()
        face.polygon = PackedVector2Array([
            Vector2(-9, -8),
            Vector2(0, -17),
            Vector2(9, -8),
            Vector2(5, 3),
            Vector2(-5, 3)
        ])
        face.color = Color(0.91, 0.69, 0.28, 0.95)
        face.z_index = 2
        area.add_child(face)

    var friendly_badge := Polygon2D.new()
    friendly_badge.name = "FriendlyTalkBadge"
    friendly_badge.polygon = PackedVector2Array([
        Vector2(0, -56),
        Vector2(10, -45),
        Vector2(0, -34),
        Vector2(-10, -45)
    ])
    friendly_badge.color = Color(0.32, 0.96, 0.80, 0.92)
    friendly_badge.z_index = 8
    area.add_child(friendly_badge)

    var halo := Line2D.new()
    halo.name = "FriendlyHalo"
    halo.points = PackedVector2Array([
        Vector2(-22, 31),
        Vector2(0, 40),
        Vector2(22, 31)
    ])
    halo.width = 3.0
    halo.default_color = Color(0.48, 1.0, 0.80, 0.72)
    halo.z_index = 7
    area.add_child(halo)

    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)


func _resolve_enemy_spawn_position(data: Dictionary) -> Vector2:
    var requested := _vec2(data.get("position", [0, 0]))
    var clearance := float(data.get("clearance", 40.0))
    var requested_top := requested.y + clearance
    var explicit_platform := String(data.get("platform_id", ""))
    var best_platform_id := ""
    var best_rect := Rect2()
    var best_score := INF

    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect := _rect2(platform_data.get("rect", []))
        if not _enemy_spawn_platform_allowed(platform_id, rect):
            continue
        if not explicit_platform.is_empty() and platform_id != explicit_platform:
            continue

        var margin := minf(38.0, rect.size.x * 0.22)
        var clamped_x := clampf(requested.x, rect.position.x + margin, rect.position.x + rect.size.x - margin)
        if explicit_platform.is_empty() and absf(clamped_x - requested.x) > 2.0:
            continue

        var score := absf(rect.position.y - requested_top) + absf(clamped_x - requested.x) * 0.25
        if score < best_score:
            best_score = score
            best_rect = rect
            best_platform_id = platform_id

    if best_score < INF:
        return _safe_enemy_spawn_on_platform(data, requested, best_platform_id, best_rect, clearance)
    return _fallback_enemy_spawn_position(data, requested, clearance)


func _safe_enemy_spawn_on_platform(data: Dictionary, requested: Vector2, platform_id: String, rect: Rect2, clearance: float) -> Vector2:
    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data)))
    var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
    var min_x := rect.position.x + margin
    var max_x := rect.position.x + rect.size.x - margin
    if min_x > max_x:
        var center_x := rect.position.x + rect.size.x * 0.5
        var center_position := Vector2(center_x, rect.position.y - clearance)
        if _enemy_spawn_rect_clear(center_position, half_width, visual_height, platform_id):
            return center_position
        return _fallback_enemy_spawn_position(data, requested, clearance, platform_id)

    var requested_x := clampf(requested.x, min_x, max_x)
    var candidate_xs: Array = [
        requested_x,
        requested_x - 70.0,
        requested_x + 70.0,
        requested_x - 140.0,
        requested_x + 140.0,
        min_x,
        max_x,
        rect.position.x + rect.size.x * 0.5
    ]
    var best_position := Vector2(requested_x, rect.position.y - clearance)
    var best_score := INF
    for candidate_value in candidate_xs:
        var x := clampf(float(candidate_value), min_x, max_x)
        var position_value := Vector2(x, rect.position.y - clearance)
        if not _enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
            continue
        var score := absf(x - requested.x)
        if score < best_score:
            best_score = score
            best_position = position_value
    if best_score < INF:
        return best_position
    return _fallback_enemy_spawn_position(data, requested, clearance, platform_id)


func _fallback_enemy_spawn_position(data: Dictionary, requested: Vector2, clearance: float, preferred_platform_id: String = "") -> Vector2:
    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data)))
    var requested_top := requested.y + clearance
    var best_position := requested
    var best_score := INF
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect := _rect2(platform_data.get("rect", []))
        if not _enemy_spawn_platform_allowed(platform_id, rect):
            continue
        var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
        var min_x := rect.position.x + margin
        var max_x := rect.position.x + rect.size.x - margin
        if min_x > max_x:
            continue
        var candidate_xs: Array = [
            clampf(requested.x, min_x, max_x),
            rect.position.x + rect.size.x * 0.5,
            min_x,
            max_x
        ]
        var step := maxf(44.0, half_width * 1.5)
        var scan_x := min_x
        while scan_x <= max_x + 0.5:
            candidate_xs.append(scan_x)
            scan_x += step
        for candidate_value in candidate_xs:
            var x := clampf(float(candidate_value), min_x, max_x)
            var position_value := Vector2(x, rect.position.y - clearance)
            if not _enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
                continue
            var platform_bias := 0.0 if platform_id == preferred_platform_id else 220.0
            var score := absf(rect.position.y - requested_top) * 1.8 + absf(x - requested.x) * 0.35 + platform_bias
            if score < best_score:
                best_score = score
                best_position = position_value
    if best_score >= INF:
        push_warning("No clear enemy spawn found for " + String(data.get("id", "enemy")) + "; check platform geometry.")
    return best_position


func _enemy_spawn_visual_height(data: Dictionary) -> float:
    var region: Array = data.get("sprite_region", [])
    var region_height := 72.0
    if region.size() >= 4:
        region_height = float(region[3])
    var scale_value := float(data.get("visual_scale", 1.0))
    var offset := _vec2(data.get("visual_offset", [0, 0]))
    var sprite_center_above_origin := 18.0 - offset.y
    return clampf(sprite_center_above_origin + region_height * scale_value * 0.5 + 12.0, 48.0, 116.0)


func _enemy_spawn_rect_clear(position_value: Vector2, half_width: float = 36.0, visual_height: float = 104.0, floor_platform_id: String = "") -> bool:
    var actor_rect := Rect2(position_value + Vector2(-half_width, -visual_height), Vector2(half_width * 2.0, visual_height + 8.0))
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        if platform_id == floor_platform_id:
            continue
        var rect := _rect2(platform_data.get("rect", []))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        if rect.position.y >= position_value.y + 10.0:
            continue
        if actor_rect.intersects(rect):
            return false
    return true


func _enemy_spawn_platform_allowed(platform_id: String, rect: Rect2) -> bool:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    var lowered := platform_id.to_lower()
    if lowered.contains("wall") or lowered.contains("gate") or lowered.contains("locked"):
        return false
    if rect.size.x < 86.0 or rect.size.y > 90.0:
        return false
    return true


func _platform_under_position(position_value: Vector2, clearance: float = 40.0) -> String:
    var expected_top := position_value.y + clearance
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect := _rect2(platform_data.get("rect", []))
        if not _enemy_spawn_platform_allowed(platform_id, rect):
            continue
        if position_value.x >= rect.position.x - 1.0 and position_value.x <= rect.position.x + rect.size.x + 1.0 and absf(rect.position.y - expected_top) <= 8.0:
            return platform_id
    return ""


func _enemy_platform_movement_bounds(platform_id: String, spawn_position: Vector2, data: Dictionary) -> Array:
    if platform_id.is_empty():
        return []
    var floor_rect := Rect2()
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if String(platform_data.get("id", "")) == platform_id:
            floor_rect = _rect2(platform_data.get("rect", []))
            break
    if floor_rect.size.x <= 0.0:
        return []

    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data)))
    var margin := maxf(half_width + 12.0, minf(54.0, floor_rect.size.x * 0.24))
    var min_x := floor_rect.position.x + margin
    var max_x := floor_rect.position.x + floor_rect.size.x - margin
    if min_x >= max_x:
        return []

    var center_x := clampf(spawn_position.x, min_x, max_x)
    var step := maxf(8.0, minf(18.0, half_width * 0.45))
    var left := center_x
    var right := center_x
    while left - step >= min_x and _enemy_spawn_rect_clear(Vector2(left - step, spawn_position.y), half_width, visual_height, platform_id):
        left -= step
    while right + step <= max_x and _enemy_spawn_rect_clear(Vector2(right + step, spawn_position.y), half_width, visual_height, platform_id):
        right += step
    if right - left < half_width:
        return [min_x, max_x]
    return [left, right]


func _spawn_normal_enemies() -> void:
    for spawn in config.get("enemy_spawns", []):
        if spawn is Dictionary:
            _enemy(spawn)


func _enemy(data: Dictionary) -> Area2D:
    var enemy := Area2D.new()
    var clearance := float(data.get("clearance", 40.0))
    enemy.position = _resolve_enemy_spawn_position(data)
    enemy.set_script(ENEMY_ACTOR_SCRIPT)
    var kind := String(data.get("kind", "moss_larva"))
    var profiles: Dictionary = config.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(kind, {})
    if profile.is_empty():
        push_warning("Missing normal enemy AI profile: " + kind)
    enemy.configure(data, SPRITES.get(kind, SPRITES["moss_larva"]), false, profile)
    var floor_platform_id := _platform_under_position(enemy.position, clearance)
    var bounds := _enemy_platform_movement_bounds(floor_platform_id, enemy.position, data)
    if bounds.size() >= 2 and enemy.has_method("set_platform_movement_bounds"):
        enemy.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
    enemy.died.connect(_on_enemy_died)
    enemy.set_meta("platform_id", floor_platform_id)
    enemy.set_meta("spawn_half_width", float(data.get("spawn_half_width", 36.0)))
    enemy.set_meta("spawn_visual_height", float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data))))
    add_child(enemy)
    return enemy


func _spawn_boss() -> void:
    if boss_spawned:
        return
    var boss_data: Dictionary = config.get("boss", {})
    boss_actor = Area2D.new()
    boss_actor.position = _vec2(boss_data.get("position", [3430, 470]))
    boss_actor.set_script(ENEMY_ACTOR_SCRIPT)
    var kind := String(boss_data.get("kind", "rust_crown_guardian"))
    var profiles: Dictionary = config.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(kind, {})
    if profile.is_empty():
        push_warning("Missing boss AI profile: " + kind)
    boss_actor.configure(boss_data, SPRITES.get(kind, SPRITES["rust_crown_guardian"]), true, profile)
    boss_actor.died.connect(_on_enemy_died)
    add_child(boss_actor)
    boss_spawned = true
    _switch_bgm("bgm_boss")
    _toast("Boss awakened: " + _boss_display_name(boss_data) + ".")
    _refresh_hud()


func _set_boss_arena_locked(locked: bool) -> void:
    if locked:
        if boss_arena_lock_body != null and is_instance_valid(boss_arena_lock_body):
            return
        var lock_rect := _boss_arena_lock_rect()
        var material := _theme_boss_material()
        boss_arena_lock_body = _platform("boss_arena_lock_wall", lock_rect, _color("2a1715"), material)
        boss_arena_lock_body.set_meta("temporary_boss_lock", true)
        if player != null and is_instance_valid(player):
            var safe_x := lock_rect.position.x + lock_rect.size.x + 54.0
            if player.global_position.x < safe_x:
                player.global_position = Vector2(safe_x, player.global_position.y)
                player.set("velocity", Vector2.ZERO)
        _toast("Boss arena sealed. Defeat the boss or die to leave.")
        return

    if boss_arena_lock_body != null and is_instance_valid(boss_arena_lock_body):
        _spawn_route_open_effect(boss_arena_lock_body.global_position)
        boss_arena_lock_body.queue_free()
    boss_arena_lock_body = null


func _boss_arena_lock_rect() -> Rect2:
    var boss_data: Dictionary = config.get("boss", {})
    if boss_data.has("lock_rect"):
        return _rect2(boss_data.get("lock_rect", []))
    var gate_position := _boss_gate_position()
    var floor_top := _floor_top_near_x(gate_position.x)
    var height := float(boss_data.get("lock_height", 315.0))
    var width := float(boss_data.get("lock_width", 46.0))
    var lock_x := float(boss_data.get("lock_x", gate_position.x - 172.0))
    return Rect2(lock_x, floor_top - height, width, height + 44.0)


func _boss_gate_position() -> Vector2:
    for interactive in config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var data: Dictionary = interactive
        if String(data.get("kind", "")) == "boss_gate":
            return _vec2(data.get("position", config.get("boss_checkpoint", active_spawn)))
    return _vec2(config.get("boss_checkpoint", active_spawn))


func _floor_top_near_x(world_x: float) -> float:
    var best_y := 540.0
    var best_score := INF
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var rect := _rect2(data.get("rect", []))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        if world_x < rect.position.x - 8.0 or world_x > rect.position.x + rect.size.x + 8.0:
            continue
        if rect.size.y > 90.0:
            continue
        var score := rect.position.y
        if score < best_score:
            best_score = score
            best_y = rect.position.y
    return best_y


func _world_label(text: String, position_value: Vector2, color: Color) -> void:
    pass


func _on_hazard_body_entered(body: Node, area: Area2D) -> void:
    if body == player:
        player.take_damage(int(area.get_meta("damage", 1)), area.global_position)
        _toast(String(area.get_meta("message", "Trap hit.")))
        _refresh_hud()


func _on_collectible_body_entered(body: Node, area: Area2D) -> void:
    if body != player:
        return
    bell_count += 1
    _play_sfx("pickup")
    _add_inventory_item(String(area.get_meta("kind", "bell_key")), 1, false)
    if metsys_bridge != null:
        metsys_bridge.store_object(area)
    _toast(String(area.get_meta("message", "Collected.")))
    _spawn_pickup_effect(area.global_position)
    area.queue_free()
    _refresh_hud()


func _on_interactable_entered(body: Node, area: Area2D) -> void:
    if body != player:
        return
    nearby_interactable = area
    if String(area.get_meta("kind", "")) == "npc":
        _toast("按F交谈")
    else:
        _toast("F: " + String(area.get_meta("label", area.name)))
    var exit_kind := String(area.get_meta("kind", ""))
    if (exit_kind == "chapter_exit" or exit_kind == "ending_exit") and _chapter_exit_can_open(area):
        call_deferred("_activate_chapter_exit", area)


func _on_interactable_exited(body: Node, area: Area2D) -> void:
    if body != player:
        return
    if nearby_interactable == area:
        nearby_interactable = null
    if String(area.get_meta("kind", "")) == "npc" and dialogue_panel != null and dialogue_panel.visible:
        _close_overlays()


func _try_interact() -> void:
    if nearby_interactable == null or not is_instance_valid(nearby_interactable):
        nearby_interactable = _nearest_interactable(170.0)
        if nearby_interactable == null or not is_instance_valid(nearby_interactable):
            _toast("No nearby target.")
            return
    var kind := String(nearby_interactable.get_meta("kind", ""))
    if kind == "lever":
        _activate_lever(nearby_interactable)
    elif kind == "boss_gate":
        _activate_boss_gate()
    elif kind == "npc":
        _talk_to_npc(nearby_interactable)
    elif kind == "save_point":
        _activate_save_point(nearby_interactable)
    elif kind == "chapter_exit" or kind == "ending_exit":
        _activate_chapter_exit(nearby_interactable)


func _nearest_interactable(radius: float) -> Area2D:
    if player == null or not is_instance_valid(player):
        return null
    var best: Area2D = null
    var best_distance := radius
    var preferred_best: Area2D = null
    var preferred_distance := radius
    for child in get_children():
        var area := child as Area2D
        if area == null or not is_instance_valid(area):
            continue
        var kind := String(area.get_meta("kind", ""))
        if not ["lever", "boss_gate", "npc", "save_point", "chapter_exit", "ending_exit"].has(kind):
            continue
        var distance := player.global_position.distance_to(area.global_position)
        if distance > radius:
            continue
        if (kind == "chapter_exit" or kind == "ending_exit") and _chapter_exit_can_open(area) and distance < preferred_distance:
            preferred_best = area
            preferred_distance = distance
        if distance < best_distance:
            best = area
            best_distance = distance
    return preferred_best if preferred_best != null else best


func _activate_lever(area: Area2D) -> void:
    if shortcut_open:
        _toast("Shortcut already open.")
        return
    if _combat_progression_enabled():
        if not _combat_goal_met():
            _toast("Defeat nearby enemies to open the boss route.")
            return
        _open_shortcut()
        _play_sfx("lever")
        return
    var required_keys := int(area.get_meta("requires_keys", max_bells))
    if bell_count < required_keys:
        _toast("Shortcut needs %d route marks. You have %d." % [required_keys, bell_count])
        return
    _open_shortcut()
    _play_sfx("lever")
    if metsys_bridge != null:
        metsys_bridge.store_object(area)


func _open_shortcut() -> void:
    shortcut_open = true
    boss_unlocked = true
    if gate_body != null:
        gate_body.queue_free()
        gate_body = null
    _toast("Boss route open. Find a save point before the boss run.")
    _refresh_hud()


func _activate_save_point(area: Area2D) -> void:
    active_spawn = area.global_position
    active_save_point_id = String(area.name)
    player.set_spawn(active_spawn)
    if player.has_method("restore_at_save_point"):
        player.restore_at_save_point()
    _play_sfx("interact", -9.0)
    _play_save_point_activation(area)
    if metsys_bridge != null:
        metsys_bridge.store_object(area)
    _toast("Saved and restored at " + String(area.get_meta("label", "Save Point")) + ".")
    _refresh_hud()


func _activate_chapter_exit(area: Area2D) -> void:
    if chapter_transitioning:
        return
    if not _chapter_exit_can_open(area):
        _toast("The way forward opens after this chapter boss falls.")
        return
    var kind := String(area.get_meta("kind", "chapter_exit"))
    if kind == "ending_exit":
        win_label.text = String(config.get("ending_message", "ENDING ROUTE OPEN: the silent crown answers."))
        win_label.visible = true
        _toast("Ending route opened.")
        return
    var next_config_path := String(area.get_meta("next_config_path", ""))
    if next_config_path.is_empty():
        _toast("Next chapter path missing.")
        return
    chapter_transitioning = true
    _toast("Entering " + String(area.get_meta("next_runtime_config_id", "next chapter")) + ".")
    call_deferred("_transition_to_next_chapter", next_config_path)


func _chapter_exit_can_open(area: Area2D) -> bool:
    return not bool(area.get_meta("requires_demo_complete", true)) or demo_complete


func _transition_to_next_chapter(next_config_path: String) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        chapter_transitioning = false
        return
    var next_config := _load_json(next_config_path)
    var entry_data: Dictionary = next_config.get("entry_from_previous", {})
    var entry_position := _vec2(entry_data.get("position", next_config.get("player_start", [120, 500])))
    var entry_message := String(entry_data.get("message", "Entering " + String(next_config.get("name", "next chapter")) + "."))
    var next_scene: Node = load("res://scenes/Main.tscn").instantiate()
    next_scene.set("config_path", next_config_path)
    next_scene.set("entry_spawn_override_enabled", true)
    next_scene.set("entry_spawn_override", entry_position)
    next_scene.set("entered_from_config_id", String(config.get("id", "")))
    next_scene.set("transition_entry_message", entry_message)
    parent_node.add_child(next_scene)
    queue_free()


func _activate_boss_gate() -> void:
    if not boss_unlocked:
        if _combat_progression_enabled():
            _toast("Boss gate sealed. Defeat all normal enemies first.")
        else:
            _toast("Boss gate sealed. Open the shortcut first.")
        return
    _spawn_boss()
    if boss_spawned and not demo_complete:
        _set_boss_arena_locked(true)


func _talk_to_npc(area: Area2D) -> void:
    var dialogue: Array = area.get_meta("dialogue", [])
    if dialogue.is_empty():
        _show_dialogue(area, "...")
        return
    var index := int(area.get_meta("dialogue_index", 0))
    _play_sfx("interact", -10.0)
    _show_dialogue(area, String(dialogue[index % dialogue.size()]))
    area.set_meta("dialogue_index", index + 1)


func _show_dialogue(area: Area2D, line: String) -> void:
    active_overlay = "dialogue"
    if backpack_panel != null:
        backpack_panel.visible = false
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = true
    if dialogue_name_label != null:
        dialogue_name_label.text = String(area.get_meta("label", area.name))
    if dialogue_meta_label != null:
        dialogue_meta_label.text = String(area.get_meta("identity", ""))
    if dialogue_text_label != null:
        dialogue_text_label.text = line
    if dialogue_hint_label != null:
        dialogue_hint_label.text = String(area.get_meta("help", ""))
    _toast("F继续 / Esc关闭")


func _on_enemy_died(spawn_id: String, is_boss: bool, kind: String) -> void:
    if is_boss:
        var boss_data: Dictionary = config.get("boss", {})
        var boss_name := _boss_display_name(boss_data)
        var reward_item := String(boss_data.get("reward_item", "crown_splinter"))
        demo_complete = true
        _set_boss_arena_locked(false)
        win_label.text = String(config.get("completion_message", "DEMO COMPLETE: " + boss_name + " defeated"))
        win_label.visible = true
        _add_currency(30)
        _add_inventory_item(reward_item, 1, false)
        if metsys_bridge != null and boss_actor != null:
            if not boss_actor.has_meta("object_id"):
                boss_actor.set_meta("object_id", "boss/" + spawn_id)
                var boss_room := _room_for_position(boss_actor.global_position)
                metsys_bridge.register_object(boss_actor, String(boss_actor.get_meta("object_id")), String(boss_room.get("id", "boss_chamber")))
            metsys_bridge.store_object(boss_actor)
        if player != null:
            player.gain_energy(30)
        _open_post_boss_route()
        _toast(String(config.get("completion_toast", "Demo complete: " + boss_name + " defeated.")))
        var transition: Dictionary = config.get("chapter_transition", {})
        if not transition.is_empty():
            _toast("Chapter exit opened: " + String(transition.get("entry_hint", _next_campaign_chapter_name())))
    else:
        var drop_item := String(config.get("enemy_drop_item", "moss_chitin"))
        enemy_defeated += 1
        _add_currency(8)
        _add_inventory_item(drop_item, 1, false)
        if player != null:
            player.gain_energy(20)
        _toast("Enemy defeated: %s (%s)" % [spawn_id, kind])
        if _combat_progression_enabled() and _combat_goal_met():
            _open_shortcut()
            _toast("All threats cleared. Boss route opened.")
    _refresh_hud()


func _on_player_respawned() -> void:
    _reset_encounters_after_player_death()


func _reset_encounters_after_player_death() -> void:
    if demo_complete:
        _refresh_hud()
        return
    _set_boss_arena_locked(false)
    for enemy_node in get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        enemy_area.queue_free()
    boss_actor = null
    boss_spawned = false
    enemy_defeated = 0
    pending_enemy_respawn = true
    _switch_bgm("bgm_ch01")
    _toast("Death reset: enemies and boss restored.")
    _refresh_hud()


func _open_post_boss_route() -> void:
    if post_boss_route_open:
        return
    post_boss_route_open = true
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        if not _is_post_boss_blocker(platform_id):
            continue
        var blocker := get_node_or_null(platform_id)
        if blocker != null:
            _spawn_route_open_effect(blocker.global_position)
            blocker.queue_free()


func _is_post_boss_blocker(platform_id: String) -> bool:
    var lowered := platform_id.to_lower()
    return lowered == "boss_back_wall" or lowered.contains("post_boss_wall") or lowered.contains("chapter_exit_wall")


func _spawn_route_open_effect(position_value: Vector2) -> void:
    for index in range(3):
        var ring := Line2D.new()
        ring.name = "PostBossRouteOpenRing"
        ring.closed = true
        ring.width = 3.0
        ring.default_color = Color(0.44, 1.0, 0.86, 0.72)
        ring.points = PackedVector2Array([
            Vector2(-34, -46),
            Vector2(34, -46),
            Vector2(54, 0),
            Vector2(34, 46),
            Vector2(-34, 46),
            Vector2(-54, 0)
        ])
        ring.position = position_value
        ring.z_index = 12
        add_child(ring)
        var tween := create_tween()
        tween.tween_interval(float(index) * 0.08)
        tween.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.42)
        tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.42)
        tween.tween_callback(ring.queue_free)


func _on_hp_changed(_value: int) -> void:
    _refresh_hud()


func _on_energy_changed(_value: int, _maximum: int) -> void:
    _refresh_hud()


func _refresh_hud() -> void:
    if hud_label == null:
        return
    var hp_text := str(player.hp) if player != null else "5"
    var energy_text := "%d/%d" % [player.energy, player.max_energy] if player != null else "0/100"
    var skill_text := "Ready" if player != null and player.skill_cooldown <= 0.0 and player.energy >= player.skill_energy_cost else "Charging"
    var shortcut_text := "Open" if shortcut_open else "Closed"
    var boss_text := "Awake" if boss_spawned else ("Ready" if boss_unlocked else "Locked")
    var save_text := active_save_point_id
    if _combat_progression_enabled():
        hud_label.text = "HP %s/5  EN %s  Skill %s  Enemies %d/%d  Boss Route %s  Boss %s  Save %s  A/D Move W/S Aim Space Jump Shift Dash LMB/J Slash RMB Heal E Skill F Use Tab Bag M Map" % [
            hp_text,
            energy_text,
            skill_text,
            enemy_defeated,
            enemy_total,
            shortcut_text,
            boss_text,
            save_text
        ]
    else:
        hud_label.text = "HP %s/5  EN %s  Skill %s  Marks %d/%d  Enemies %d/%d  Shortcut %s  Boss %s  Save %s  A/D Move W/S Aim Space Jump Shift Dash LMB/J Slash RMB Heal E Skill F Use Tab Bag M Map" % [
            hp_text,
            energy_text,
            skill_text,
            bell_count,
            max_bells,
            enemy_defeated,
            enemy_total,
            shortcut_text,
            boss_text,
            save_text
        ]


func _toast(text: String) -> void:
    if toast_label != null:
        toast_label.text = text
    print(text)


func _spawn_pickup_effect(world_position: Vector2) -> void:
    var ring := Line2D.new()
    ring.name = "PickupEffectRing"
    ring.global_position = world_position
    var points := PackedVector2Array()
    for step in range(24):
        var angle := TAU * float(step) / 24.0
        points.append(Vector2(cos(angle), sin(angle)) * 20.0)
    ring.points = points
    ring.closed = true
    ring.width = 3.0
    ring.default_color = Color(1.0, 0.78, 0.25, 0.95)
    ring.z_index = 90
    add_child(ring)

    var ray := Line2D.new()
    ray.name = "PickupSparkVfx"
    ray.global_position = world_position
    ray.points = PackedVector2Array([
        Vector2(-18.0, 0.0),
        Vector2(18.0, 0.0),
        Vector2(0.0, 0.0),
        Vector2(0.0, -26.0)
    ])
    ray.width = 2.0
    ray.default_color = Color(0.64, 1.0, 0.76, 0.86)
    ray.z_index = 91
    add_child(ray)

    var tween := create_tween()
    tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.28)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
    tween.parallel().tween_property(ray, "scale", Vector2(1.5, 1.5), 0.20)
    tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.20)
    tween.finished.connect(Callable(ring, "queue_free"))
    tween.finished.connect(Callable(ray, "queue_free"))


func get_demo_state() -> Dictionary:
    var chapter_exit_total := 0
    var ending_exit_total := 0
    for interactive in config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var interactive_data: Dictionary = interactive
        var interactive_kind := String(interactive_data.get("kind", ""))
        if interactive_kind == "chapter_exit":
            chapter_exit_total += 1
        elif interactive_kind == "ending_exit":
            ending_exit_total += 1
    var boss_data: Dictionary = config.get("boss", {})
    var boss_kind := String(boss_data.get("kind", ""))
    var boss_profile: Dictionary = config.get("ai_profiles", {}).get(boss_kind, {})
    var transition_state: Dictionary = config.get("chapter_transition", {})
    var boss_attack_types: Array = []
    for attack in boss_profile.get("attacks", []):
        if not (attack is Dictionary):
            continue
        var attack_data: Dictionary = attack
        var attack_type := String(attack_data.get("type", ""))
        if not boss_attack_types.has(attack_type):
            boss_attack_types.append(attack_type)
    var platform_materials: Array = []
    var platform_visual_asset_paths: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var material := String(platform_data.get("material", "moss_stone"))
        if not platform_materials.has(material):
            platform_materials.append(material)
        for asset_path in _platform_visual_asset_paths_for_material(material):
            var asset_path_string := String(asset_path)
            if not asset_path_string.is_empty() and not platform_visual_asset_paths.has(asset_path_string):
                platform_visual_asset_paths.append(asset_path_string)
    var state := {
        "config_path": config_path,
        "config_id": config.get("id", ""),
        "config_name": config.get("name", ""),
        "config_goal": config.get("goal", ""),
        "progression_mode": config.get("progression_mode", "keys"),
        "art_theme_id": _art_theme_id(),
        "map_title": _theme_map_title(),
        "visual_asset_source": _theme_asset_source(),
        "platform_materials": platform_materials,
        "platform_visual_asset_paths": platform_visual_asset_paths,
        "background_visual_asset_paths": _background_visual_asset_paths(),
        "world_width": world_width,
        "map_room_total": config.get("map_rooms", []).size(),
        "platform_total": config.get("platforms", []).size(),
        "bell_count": bell_count,
        "required_keys": max_bells,
        "shortcut_open": shortcut_open,
        "boss_unlocked": boss_unlocked,
        "boss_spawned": boss_spawned,
        "boss_arena_locked": boss_arena_lock_body != null and is_instance_valid(boss_arena_lock_body),
        "demo_complete": demo_complete,
        "post_boss_route_open": post_boss_route_open,
        "entry_spawn_override_enabled": entry_spawn_override_enabled,
        "entered_from_config_id": entered_from_config_id,
        "transition_entry_message": transition_entry_message,
        "normal_enemy_total": enemy_total,
        "normal_enemy_defeated": enemy_defeated,
        "hazard_total": hazard_total,
        "collectible_total": collectible_total,
        "save_point_total": save_point_total,
        "hidden_save_point_total": hidden_save_point_total,
        "active_save_point_id": active_save_point_id,
        "active_spawn": [active_spawn.x, active_spawn.y],
        "ai_profile_total": config.get("ai_profiles", {}).size(),
        "npc_total": config.get("npcs", []).size(),
        "currency_count": currency_count,
        "inventory_item_total": inventory_counts.size(),
        "visited_room_total": visited_rooms.size(),
        "current_room_id": current_room_id,
        "backpack_overlay_ready": backpack_panel != null,
        "map_overlay_ready": map_panel != null,
        "dialogue_overlay_ready": dialogue_panel != null,
        "guide_marker_total": config.get("guides", []).size(),
        "active_overlay": active_overlay,
        "chapter_exit_total": chapter_exit_total,
        "ending_exit_total": ending_exit_total,
        "chapter_transition_to": transition_state.get("to_runtime_config_id", ""),
        "boss_attack_total": boss_profile.get("attacks", []).size(),
        "boss_attack_types": boss_attack_types
    }
    var enemy_positions: Array = []
    for enemy_node in get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        if bool(enemy_area.get("is_boss")):
            continue
        var spawn_position_value: Vector2 = enemy_area.get("spawn_position")
        var leash_radius_value := float(enemy_area.get("leash_radius"))
        var spawn_half_width := float(enemy_area.get_meta("spawn_half_width", 36.0))
        var spawn_visual_height := float(enemy_area.get_meta("spawn_visual_height", 104.0))
        var spawn_clear := _enemy_spawn_rect_clear(enemy_area.global_position, spawn_half_width, spawn_visual_height, String(enemy_area.get_meta("platform_id", "")))
        var ai_debug := {}
        if enemy_area.has_method("get_ai_debug_state"):
            ai_debug = enemy_area.get_ai_debug_state()
        enemy_positions.append({
            "id": String(enemy_area.get("spawn_id")),
            "kind": String(enemy_area.get("kind")),
            "position": [enemy_area.global_position.x, enemy_area.global_position.y],
            "spawn_position": [spawn_position_value.x, spawn_position_value.y],
            "leash_radius": leash_radius_value,
            "spawn_visual_height": spawn_visual_height,
            "platform_id": _platform_under_position(enemy_area.global_position),
            "spawn_clear": spawn_clear,
            "ai_command_total": int(ai_debug.get("ai_command_total", 0)),
            "attack_desire": float(ai_debug.get("attack_desire", 0.0)),
            "attack_desire_threshold": float(ai_debug.get("attack_desire_threshold", 0.0)),
            "last_player_command": String(ai_debug.get("last_player_command", "none")),
            "last_ai_decision": String(ai_debug.get("last_ai_decision", "none")),
            "last_attack_id": String(ai_debug.get("last_attack_id", "")),
            "reads_player_commands": bool(ai_debug.get("reads_player_commands", false)),
            "command_read_count": int(ai_debug.get("command_read_count", 0)),
            "max_attack_range": float(ai_debug.get("max_attack_range", 0.0))
        })
    state["enemy_positions"] = enemy_positions
    if boss_actor != null and is_instance_valid(boss_actor):
        var boss_body_size: Vector2 = boss_actor.get("body_size")
        var boss_hurtbox_size: Vector2 = boss_actor.get("hurtbox_size")
        state["boss_body_size"] = [boss_body_size.x, boss_body_size.y]
        state["boss_hurtbox_size"] = [boss_hurtbox_size.x, boss_hurtbox_size.y]
        state["boss_visual_scale"] = float(boss_actor.get("visual_scale"))
    if not campaign.is_empty():
        state["campaign_chapter_total"] = campaign.get("chapters", []).size()
        state["campaign_current_chapter"] = current_campaign_chapter.get("name", "")
        state["campaign_next_chapter"] = _next_campaign_chapter_name()
        state["chapter_file_total"] = chapter_file_configs.size()
        state["chapter_file_ids"] = _chapter_file_ids()
    if not audio_visual_manifest.is_empty():
        state["av_runtime_event_total"] = audio_visual_manifest.get("runtime_events", {}).size()
        state["av_chapter_total"] = audio_visual_manifest.get("chapter_audio_visual", []).size()
    if metsys_bridge != null:
        state.merge(metsys_bridge.get_state(), true)
    return state


func _debug_collect_all_keys() -> void:
    bell_count = max_bells
    _refresh_hud()


func _debug_clear_combat_route() -> void:
    enemy_defeated = enemy_total
    if _combat_progression_enabled():
        _open_shortcut()
    _refresh_hud()


func _debug_open_shortcut() -> void:
    if not shortcut_open:
        _open_shortcut()


func _debug_start_boss() -> void:
    boss_unlocked = true
    _spawn_boss()


func _debug_kill_boss() -> void:
    if not boss_spawned:
        _debug_start_boss()
    if boss_actor != null and is_instance_valid(boss_actor):
        boss_actor.take_hit(999, 1)


func _rect2(value: Variant) -> Rect2:
    if typeof(value) != TYPE_ARRAY or value.size() < 4:
        return Rect2()
    return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


func _vec2(value: Variant) -> Vector2:
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return Vector2.ZERO
    return Vector2(float(value[0]), float(value[1]))


func _color(hex: Variant) -> Color:
    return Color.html("#" + String(hex))

Warning: truncated output (original token count: 80036)
Total output lines: 7024

extends Node2D

const FLAT_MAP_ART_SCRIPT := preload("res://scripts/flat_map_art.gd")
const TERRAIN_SCRIPT := preload("res://scripts/chapter_terrain.gd")
const CAVE_WORLD_SCRIPT := preload("res://scripts/cave_world.gd")
const CAVE_LIFT_SCRIPT := preload("res://scripts/cave_lift.gd")
const PILGRIMAGE_UI_SCRIPT := preload("res://scripts/pilgrimage_interface.gd")
var ui_shell: Control
const ORIGINAL_ART := preload("res://scripts/hand_drawn_assets.gd")
var flat_map_art: Node2D
var chapter_terrain: Node2D
var cave_world: Node2D
var cave_lifts: Array[Node2D] = []

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_ACTOR_SCRIPT := preload("res://scripts/enemy_actor.gd")
const METSYS_BRIDGE_SCRIPT := preload("res://scripts/metroidvania_bridge.gd")
const AUDIO_DIRECTOR_SCRIPT := preload("res://scripts/audio_director.gd")
const AUDIO_RETIREMENT_SCRIPT := preload("res://scripts/audio_retirement.gd")
const BUILD_SYSTEM_SCRIPT := preload("res://scripts/build_system.gd")
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")
const WORLD_PASSAGE := preload("res://scripts/world_passage.gd")
const WORLD_REGION_LOADER := preload("res://scripts/world_region_loader.gd")
const PLATFORM_BODY := preload("res://scripts/world_platform_body.gd")
const WORLD_PLATFORMS := preload("res://scripts/world_platform_residency.gd")
var world_platforms: RefCounted
const WORLD_GAMEPLAY_RESIDENCY := preload("res://scripts/world_gameplay_residency.gd")
var world_gameplay_residency: RefCounted
var npc_residency_memory: Dictionary = {}
var save_point_residency_memory: Dictionary = {}
const WORLD_PREFETCH := preload("res://scripts/world_prefetch.gd")
const WORLD_COORDINATES := preload("res://scripts/world_coordinates.gd")
const WORLD_ROUTES_SCRIPT := preload("res://scripts/world_routes.gd")
const WORLD_NARRATIVE_SCRIPT := preload("res://scripts/world_narrative.gd")
const WORLD_ABILITIES := ["thread_dash", "silk_wall_grip", "echo_hook", "double_thread_jump", "bell_guard", "thorn_downstrike", "lantern_phase", "crown_resonance"]
const DEFAULT_CONFIG_PATH := "res://data/demo_ch01_moss_bell_court.json"
const BOSS_TRIAL_CONFIG_PATH := "res://data/demo_ch01_boss_trial.json"
const CAMPAIGN_PATH := "res://data/campaign_chapters.json"
const CHAPTER_DATA_DIR := "res://data/chapters"
const AV_MANIFEST_PATH := "res://data/audio_visual_manifest.json"
## 圣典 §7 物品铭文库（tools/build_item_lore.mjs 从圣典逐字生成，勿手改铭文文本）。
## 单点数据源：六章共用，展示时铭文优先于各章 JSON catalog 的短句。
const ITEM_LORE_PATH := "res://data/item_lore.json"
## 剧情关键物品拾取横幅停留秒数（比普通 toast 更久，"捡到证词=听到一段历史"）。
const LORE_BANNER_SECONDS := 7.0
## 真名信物类关键物品（证词/印记用前缀判断，见 _is_story_key_item）。
const STORY_KEY_ITEM_IDS := {
    "crown_splinter": true,
    "smith_oath_plate": true,
    "contract_original_fragment": true,
    "salt_page_1_3": true,
    "living_cover_vein": true,
    "silent_order": true,
    "seventh_name_parts": true,
    "redline_gate_token": true
}

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

# 旧版兜底表（正常路径：圣典铭文表 item_lore > 章节 catalog > 本表）。
const ITEM_DISPLAY := {
    "currency": {"name": "松脂碎片", "description": ""},
    "bell_key": {"name": "敌群", "description": "唤醒捷径钟门的锈蚀战斗标记。"},
    "thread_burst": {"name": "绯线爆裂", "description": "消耗30点能量，打出一次重型线刃。"},
    "menders_right": {"name": "缝补右手", "description": "鼠标右键消耗60点能量，恢复1点生命。"},
    "moss_lens": {"name": "苔光镜", "description": "会记录已探索房间的破损镜片。"},
    "moss_chitin": {"name": "苔壳", "description": "近战庭兽留下的硬壳。"},
    "crown_splinter": {"name": "王冠裂片", "description": "苔钟守母体内仍带余温的金属碎片。"}
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
    "moss_larva": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/moss_larva/manifest.json",
    "bronze_moth": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/bronze_moth/manifest.json",
    "spore_bellmaker": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/spore_bellmaker/manifest.json",
    "gear_sentinel": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/gear_sentinel/manifest.json",
    "corridor_heavy": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/corridor_heavy/manifest.json",
    "bellroot_acolyte": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/bellroot_acolyte/manifest.json",
    "rust_crown_guardian": "res://assets/sprites/bosses/boss_01_moss_bell_matriarch/manifest.json",
    "drain_leech": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/drain_leech/manifest.json",
    "pipe_thrower": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/pipe_thrower/manifest.json",
    "rust_diver": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/rust_diver/manifest.json",
    "bell_mote": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/bell_mote/manifest.json",
    "valve_crawler": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/valve_crawler/manifest.json",
    "rain_censer_mote": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/rain_censer_mote/manifest.json",
    "waterwheel_knight": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/waterwheel_knight/manifest.json",
    "sunken_hammer_smith": "res://assets/sprites/bosses/boss_02_crimson_thread_scissor_apostle/manifest.json",
    "salt_bookmite": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/salt_bookmite/manifest.json",
    "page_duelist": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/page_duelist/manifest.json",
    "index_scribe": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/index_scribe/manifest.json",
    "summoned_page": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/summoned_page/manifest.json",
    "wax_lancer": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/wax_lancer/manifest.json",
    "erasure_bailiff": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/erasure_bailiff/manifest.json",
    "saltwhite_contract_judge": "res://assets/sprites/bosses/boss_03_ash_crowned_mantis_warlord/manifest.json",
    "vine_crawler": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/vine_crawler/manifest.json",
    "wax_bee": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/wax_bee/manifest.json",
    "root_cage_hunter": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/root_cage_hunter/manifest.json",
    "pollen_lutist": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/pollen_lutist/manifest.json",
    "thorn_sentinel": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/thorn_sentinel/manifest.json",
    "thorn_bloom_mote": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/thorn_bloom_mote/manifest.json",
    "broken_string_garden_lord": "res://assets/sprites/bosses/boss_04_copperroot_bishop/manifest.json",
    "broken_string_gardener": "res://assets/sprites/bosses/boss_04_copperroot_bishop/manifest.json",
    "obsidian_spearman": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/obsidian_spearman/manifest.json",
    "obsidian_bellwheel": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/obsidian_bellwheel/manifest.json",
    "phase_censor": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/phase_censor/manifest.json",
    "silent_bugbler": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/silent_bugbler/manifest.json",
    "kneeling_crossbowman": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/kneeling_crossbowman/manifest.json",
    "pilgrim_chariot": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/pilgrim_chariot/manifest.json",
    "ash_banner_imp": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/ash_banner_imp/manifest.json",
    "silent_pilgrim_commander": "res://assets/sprites/bosses/boss_05_mirrorpool_bride/manifest.json",
    "echo_moss_larva": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_moss_larva/manifest.json",
    "echo_waterwheel_knight": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_waterwheel_knight/manifest.json",
    "echo_contract_scribe": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_contract_scribe/manifest.json",
    "delayed_shadow": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/delayed_shadow/manifest.json",
    "echo_thorn_sentinel": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_thorn_sentinel/manifest.json",
    "echo_pilgrim_commander_minor": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_pilgrim_commander_minor/manifest.json",
    "isotope_lumen": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/isotope_lumen/manifest.json",
    "silent_crown_core": "res://assets/sprites/bosses/boss_06_hundred_key_gatekeeper/manifest.json",
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

# Each NPC role gets a distinct idle portrait from the shared bestiary set so
# friendly characters no longer recycle the four CH01 enemy placeholder sheets.
const NPC_SPRITES := {
    "threadsmith": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/wax_lancer/frames/idle/idle_00.png",
    "pilgrim": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/silent_bugbler/frames/idle/idle_00.png",
    "cartographer": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/index_scribe/frames/idle/idle_00.png",
    "sacristan": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/phase_censor/frames/idle/idle_00.png",
    "scout": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/kneeling_crossbowman/frames/idle/idle_00.png",
    "rain_smith": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/waterwheel_knight/frames/idle/idle_00.png",
    "canal_child": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/bell_mote/frames/idle/idle_00.png",
    "sluice_nun": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/rain_censer_mote/frames/idle/idle_00.png",
    "half_drowned_foreman": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/rust_diver/frames/idle/idle_00.png",
    "unreliable_guide": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/summoned_page/frames/idle/idle_00.png",
    "mechanic_teacher": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/gear_sentinel/frames/idle/idle_00.png",
    "true_ending_clue": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/isotope_lumen/frames/idle/idle_00.png",
    "vendor_guard_hint": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/obsidian_spearman/frames/idle/idle_00.png",
    "main_witness": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/erasure_bailiff/frames/idle/idle_00.png",
    "keeper_truth": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_contract_scribe/frames/idle/idle_00.png",
    "vendor_sidequest": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/pollen_lutist/frames/idle/idle_00.png",
    "gate_hint": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/bellroot_acolyte/frames/idle/idle_00.png",
    "route_hint": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/salt_bookmite/frames/idle/idle_00.png",
    "key_witness": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/delayed_shadow/frames/idle/idle_00.png",
    "ability_teacher": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/page_duelist/frames/idle/idle_00.png",
    "sidequest_moral_choice": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/wax_bee/frames/idle/idle_00.png",
    "true_ending_core": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_pilgrim_commander_minor/frames/idle/idle_00.png",
    "world_warning": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/ash_banner_imp/frames/idle/idle_00.png",
    "ending_checker": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/echo_moss_larva/frames/idle/idle_00.png",
    "hidden_temptation": "res://assets/third_party/dark_fantasy_bestiary/runtime_keyframes/thorn_bloom_mote/frames/idle/idle_00.png"
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
    "interact": "res://assets/audio/sfx/interact.ogg",
    # 自产 SFX 包（tools/generate_sfx_pack.py，project-generated CC0，音频规格 §4.5/§4.6；
    # 生成器已切 OGG 封装，generated/ 下同名 .wav → .ogg 零例外）。
    "shrine_wrap": "res://assets/audio/sfx/generated/env_shrine_wrap.ogg",
    "shrine_rest_ch01": "res://assets/audio/sfx/generated/env_shrine_rest_ch01.ogg",
    "shrine_rest_ch02": "res://assets/audio/sfx/generated/env_shrine_rest_ch02.ogg",
    "shrine_rest_ch03": "res://assets/audio/sfx/generated/env_shrine_rest_ch03.ogg",
    "shrine_rest_ch04": "res://assets/audio/sfx/generated/env_shrine_rest_ch04.ogg",
    "shrine_rest_ch05": "res://assets/audio/sfx/generated/env_shrine_rest_ch05.ogg",
    "shrine_rest_ch06": "res://assets/audio/sfx/generated/env_shrine_rest_ch06.ogg",
    "gate_dash": "res://assets/audio/sfx/generated/env_gate_dash.ogg",
    "gate_wallshaft": "res://assets/audio/sfx/generated/env_gate_wallshaft.ogg",
    "gate_hookring": "res://assets/audio/sfx/generated/env_gate_hookring.ogg",
    "gate_doublejump": "res://assets/audio/sfx/generated/env_gate_doublejump.ogg",
    "gate_guardbreak": "res://assets/audio/sfx/generated/env_gate_guardbreak.ogg",
    "gate_shadow": "res://assets/audio/sfx/generated/env_gate_shadow.ogg",
    "gate_crown": "res://assets/audio/sfx/generated/env_gate_crown.ogg",
    "gate_downstrike": "res://assets/audio/sfx/generated/player_downstrike_break.ogg",
    "chapter_transition": "res://assets/audio/sfx/generated/env_chapter_transition.ogg",
    "low_hp_heartbeat": "res://assets/audio/sfx/generated/player_low_hp_heartbeat.ogg",
    # 三结局 stinger（自产 CC0，结局门文案显示同时播放，挂 root 防截断）。
    "ending_a_stinger": "res://assets/audio/sfx/generated/story_ending_a_rebell.ogg",
    "ending_b_stinger": "res://assets/audio/sfx/generated/story_ending_b_severance.ogg",
    "ending_c_stinger": "res://assets/audio/sfx/generated/story_ending_c_reweave.ogg",
    # 系统事件音（ambience 包尾批自产 CC0：能力解锁 jingle/关键拾取/证词链集齐）。
    "ui_ability_unlock": "res://assets/audio/sfx/generated/ui_ability_unlock.ogg",
    "ui_pickup_key_item": "res://assets/audio/sfx/generated/ui_pickup_key_item.ogg",
    "ui_testimony_complete": "res://assets/audio/sfx/generated/ui_testimony_complete.ogg",
    # Kenney CC0 三包（Interface Sounds / RPG Audio；音频规格 §4.5 UI 与系统）。
    "ui_inventory_open": "res://assets/audio/sfx/kenney/interface/open_001.ogg",
    "ui_inventory_close": "res://assets/audio/sfx/kenney/interface/close_001.ogg",
    "ui_map_open": "res://assets/audio/sfx/kenney/interface/maximize_001.ogg",
    "ui_map_close": "res://assets/audio/sfx/kenney/interface/minimize_001.ogg",
    "ui_dialogue_close": "res://assets/audio/sfx/kenney/interface/back_002.ogg",
    "ui_menu_move_1": "res://assets/audio/sfx/kenney/interface/tick_001.ogg",
    "ui_menu_move_2": "res://assets/audio/sfx/kenney/interface/tick_002.ogg",
    "ui_toast": "res://assets/audio/sfx/kenney/interface/pluck_001.ogg",
    "ui_menu_confirm": "res://assets/audio/sfx/kenney/interface/confirmation_001.ogg",
    "ui_menu_cancel": "res://assets/audio/sfx/kenney/interface/error_004.ogg",
    "lever_latch": "res://assets/audio/sfx/kenney/rpg/metalLatch.ogg",
    "door_open": "res://assets/audio/sfx/kenney/rpg/doorOpen_1.ogg",
    "pickup_coins_1": "res://assets/audio/sfx/kenney/rpg/handleCoins.ogg",
    "pickup_coins_2": "res://assets/audio/sfx/kenney/rpg/handleCoins2.ogg",
    "pickup_cloth": "res://assets/audio/sfx/kenney/rpg/cloth1.ogg"
}

## 章节 art theme → 玩家脚步材质组（音频规格 §4.2 材质化脚步）。
const FOOTSTEP_MATERIAL_BY_THEME := {
    "moss_cavern": "moss",
    "rain_foundry": "copper",
    "salt_archive": "salt",
    "string_greenhouse": "fiber",
    "obsidian_pilgrim": "obsidian",
    "silent_crown": "obsidian"
}

## 结局 → 终止式 stinger（音频规格 §3.8）。
const ENDING_STINGER_SFX := {
    "ending_a": "ending_a_stinger",
    "ending_b": "ending_b_stinger",
    "ending_c": "ending_c_stinger"
}

## 能力门族提示音映射（音频规格 §4.5 ui_gate_unlock：对应能力家族音）。
const GATE_UNLOCK_SFX := {
    "thread_dash": "gate_dash",
    "silk_wall_grip": "gate_wallshaft",
    "echo_hook": "gate_hookring",
    "double_thread_jump": "gate_doublejump",
    "bell_guard": "gate_guardbreak",
    "lantern_phase": "gate_shadow",
    "crown_resonance": "gate_crown",
    "thorn_downstrike": "gate_downstrike"
}

## P0 音频总线基建（音效与音乐设计规格 20260726160400000 §5.1 / §6.3 第 0 期）。
## 五总线：Master + BGM/SFX/Ambience/UI；MusicExplore/MusicCombat 等子总线随
## audio_director 一期再拆。总线音量保持 0dB（BGM/SFX），使现有 11 个 sfx 与
## 2 首 BGM 的节点级 volume_db 行为不回退。
const AUDIO_BUSES := ["BGM", "SFX", "Ambience", "UI"]
const AUDIO_BUS_DEFAULT_VOLUME_DB := {
    "BGM": 0.0,
    "SFX": 0.0,
    "Ambience": -14.0,
    "UI": -10.0
}
## 区域混响参数表（规格 §5.2）：世界海拔 L+3 → L-2 递变，值照抄文档。
const REVERB_TIERS := {
    "L+3": {"room_size": 0.95, "damping": 0.10, "wet": 0.50, "predelay_msec": 40.0},
    "L+2_salt": {"room_size": 0.70, "damping": 0.25, "wet": 0.30, "predelay_msec": 25.0},
    "L+2_glass": {"room_size": 0.55, "damping": 0.30, "wet": 0.28, "predelay_msec": 15.0},
    "L+1": {"room_size": 0.60, "damping": 0.65, "wet": 0.25, "predelay_msec": 18.0},
    "L0": {"room_size": 0.50, "damping": 0.40, "wet": 0.35, "predelay_msec": 30.0, "predelay_feedback": 0.3},
    "L-1": {"room_size": 0.30, "damping": 0.20, "wet": 0.15, "predelay_msec": 60.0},
    "L-2": {"room_size": 0.85, "damping": 0.90, "wet": 0.60, "predelay_msec": 10.0}
}
const CHAPTER_REVERB_TIER := {
    "demo_ch01_moss_bell_court": "L+1",
    "demo_ch01_boss_trial": "L+1",
    "demo_ch02_rain_foundry_canal": "L0",
    "demo_ch03_saltwhite_archive": "L+2_salt",
    "demo_ch04_broken_string_greenhouse": "L+2_glass",
    "demo_ch05_obsidian_pilgrim_road": "L-1",
    "demo_ch06_silent_crown_core": "L+3"
}
## 濒死混音态（规格 §5.5）：HP==1 时 BGM 总线低通目标截止频率。
const LOW_HP_LOWPASS_CUTOFF_HZ := 800.0

## 音频设置四滑条行定义（which 键与 AudioDirector.USER_VOLUME_BUS 对齐）。
const AUDIO_SETTINGS_ROWS := [
    ["master", "主音量 Master"],
    ["music", "音乐 Music"],
    ["sfx", "音效 SFX"],
    ["ambience", "环境 Ambience"]
]

## 结局门（剧情蓝图 §12 三结局最小闭环）：Boss 后按 ending 字段着色三扇门。
const ENDING_GATE_TINTS := {
    "ending_a": Color(1.0, 0.84, 0.38, 0.92),
    "ending_b": Color(1.0, 0.42, 0.46, 0.92),
    "ending_c": Color(0.52, 0.95, 1.0, 0.92)
}

var config: Dictionary = {}
var campaign: Dictionary = {}
var current_campaign_chapter: Dictionary = {}
var chapter_file_configs: Array = []
var audio_visual_manifest: Dictionary = {}
var world_shared_metadata_cache: Dictionary = {}
var world_shared_metadata_reads: Dictionary = {}
var world_shared_metadata_probes: Dictionary = {}
var world_shared_metadata_bytes: Dictionary = {}
var world_shared_metadata_parses: Dictionary = {}
var world_shared_metadata_failures: Dictionary = {}
var player: CharacterBody2D
var ui_canvas: CanvasLayer
var hud_label: Label
var toast_label: Label
var lore_banner_label: Label
var lore_banner_time_left := 0.0
# 圣典铭文表：item_id -> {display_name?, lore: Array[String], function?}（ITEM_LORE_PATH）。
var item_lore: Dictionary = {}
var win_label: Label
var dialogue_panel: ColorRect
var dialogue_name_label: Label
var dialogue_meta_label: Label
var dialogue_text_label: Label
var dialogue_hint_label: Label
var backpack_panel: ColorRect
var backpack_text: Label
var backpack_detail_text: Label
var backpack_entry_ids: Array[String] = []
var backpack_selection := 0
var map_panel: ColorRect
var map_text: Label
var map_draw_root: Control
var survey_map_view: Control
var gate_body: StaticBody2D
var locked_gate_bodies: Dictionary = {}
var unlocked_abilities: Dictionary = {}
var boss_actor: Area2D
var boss_arena_lock_body: StaticBody2D
var nearby_interactable: Area2D
var active_spawn := Vector2(120, 500)
var bell_count := 0
var max_bells := 3
var shortcut_open := false
var opened_shortcuts: Dictionary = {}
var boss_unlocked := false
var boss_spawned := false
var demo_complete := false
var post_boss_route_open := false
var chapter_transitioning := false
var world_portal_request_pending := false
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
var boss_trial_mode := false
var inventory_counts: Dictionary = {}
var inventory_tools: Array = []
var inventory_relics: Array = []
var inventory_materials: Dictionary = {}
var currency_count := 0
var visited_rooms: Dictionary = {}
var current_room_id := ""
var active_save_point_id := "start"
var bgm_player: AudioStreamPlayer
var bgm_duck_tween: Tween
var low_hp_audio_active := false
var low_hp_heartbeat_player: AudioStreamPlayer
var pending_sfx_players: Dictionary = {}
# AudioDirector 一期：章节音乐组/环境床/混音状态总导演（audio_director.gd）。
# 战斗层轮询/摇篮曲距离/Boss 相位三个状态机已整体迁入 director._process
#（bind_runtime 注入 player/敌群），main_level 不再持有轮询状态。
# 类型标注用 preload 常量（不依赖编辑器全局类缓存，headless 直跑安全）。
var audio_director: AUDIO_DIRECTOR_SCRIPT
# 音频设置覆盖层（音量四滑条）。
var settings_panel: ColorRect
var settings_text: Label
var settings_selection := 0
var last_toast_sfx_ms := 0
var pending_enemy_respawn := false
# Story flags (npc_met_*, boss_down_*, whisper_*, quest flags ...). Part of the
# carried save state; missing keys always default to false for old saves.
var story_flags: Dictionary = {}
# 跨章背包携带（照抄 story_flags 深拷贝携带模式）：_transition_to_next_chapter
# 把 inventory_counts + currency 快照进下一场景，入章时与该章 starting_tools 做
# 并集合并（starting_tools 只兜底不覆盖）。旧调用路径（直接启动单章、boss_trial）
# 不设置 carried_inventory_enabled，行为完全不变。
var carried_inventory_enabled := false
var carried_inventory_counts: Dictionary = {}
var carried_currency := 0
# 结局门运行时（章节配置可选 "ending_gates" 数组，Boss 死亡后生成交互点）。
var ending_gates_spawned := false
# 巡礼愿板最小闭环（章节配置可选 "wish_board" 数组，target_flag 完成即发奖一次）。
var wish_panel: ColorRect
var wish_text: Label

@export var world_mode := false
@export var world_resume := true
@export var world_save_path := "user://pilgrimage_world.json"
var world_state: WORLD_STATE_SCRIPT
var world_passage: Node2D
var world_loader: WORLD_REGION_LOADER
var world_prefetch: WORLD_PREFETCH
var region_tweens: Array[Tween] = []
var world_narrative: WORLD_NARRATIVE_SCRIPT
var world_collected_ids: Dictionary = {}
var world_catalog: Dictionary = {}
var world_catalog_prepare_staging: Dictionary = {}
var world_write_error_shown := false
## Narrow failure seam for transaction validations; simulates the storage boundary failing after capture.
var world_save_failure_injected_for_validation := false
var world_loading := true
var initial_region_ready := false
var build_system: RefCounted
var world_slot := 1
var death_cache_area: Area2D
var last_safe_ground := Vector2.ZERO
var death_recorded := false
var world_initial_error := ""
# Command-line options belong to the initial launch, never slot switches or travel.
var world_startup_options_enabled := true
# Keep incompatible saved builds on disk until explicit recovery or a new journey.
var world_save_blocked := false
var subtitle_elapsed := 0.0
var subtitle_seconds := 0.0
var new_journey_dialog: ConfirmationDialog
var world_new_key_held := false
var world_map_view := false
var world_map_key_held := false
var applied_build_profile: Dictionary = {}
var world_start_region_id := ""

@export var config_path := DEFAULT_CONFIG_PATH


const CARTOGRAPHY := preload("res://scripts/pilgrimage_cartography.gd")
const WORLD_ATLAS := preload("res://scripts/world_atlas.gd")
const CARTOGRAPHY_UI := preload("res://scripts/cartography_runtime.gd")

func _ready() -> void:
    _apply_cmdline_config_override()
    _prepare_world_start()
    if world_mode:
        world_loader = WORLD_REGION_LOADER.new()
        world_prefetch = WORLD_PREFETCH.new()
        world_passage = WORLD_PASSAGE.new()
        add_child(world_passage)
        world_passage.bind(self)
    if world_mode:
        var previous_mode := process_mode
        process_mode = Node.PROCESS_MODE_DISABLED
        world_loader.request_startup_region(self, previous_mode)
    else:
        _initialize_region()


func _initialize_region(prepared_config: Dictionary = {}) -> void:
    _prepare_region(prepared_config)
    _build_world_from_config()
    _finish_region()


func _prepare_region(prepared_config: Dictionary = {}) -> void:
    var jobs := _region_prepare_jobs(prepared_config)
    var cursor := 0
    while cursor < jobs.size():
        var job: Dictionary = jobs[cursor]
        var result: Variant = callv(job.method, job.args)
        if result is Array and not result.is_empty() and result[0] is Dictionary and result[0].has("method"):
            for offset in range(result.size()):
                jobs.insert(cursor + 1 + offset, result[offset])
        var completed_method := String(job.get("method", ""))
        if config.is_empty() and ((completed_method == "_prepare_narrative_config" and (not world_mode or not world_catalog.is_empty())) or completed_method == "_commit_world_catalog_prepare"):
            break
        cursor += 1


## Ordered preparation contract shared by synchronous startup and async World travel.
## Planning enumerates chapter filenames only; content reads, parsing and deep copies stay in jobs.
func _region_prepare_jobs(prepared_config: Dictionary = {}) -> Array:
    var jobs: Array = [
        {"method": "_prepare_config_and_route", "args": [prepared_config]},
        {"method": "_prepare_narrative_config", "args": []}
    ]
    if world_mode and world_catalog.is_empty():
        jobs.append({"method": "_begin_world_catalog_prepare", "args": []})
        # The index job reads route order once and expands into one job per region.
        jobs.append({"method": "_prepare_world_catalog_jobs", "args": []})
        jobs.append({"method": "_commit_world_catalog_prepare", "args": []})
    jobs.append_array([
        {"method": "_prepare_campaign_metadata", "args": []},
        {"method": "_begin_chapter_metadata", "args": []}
    ])
    for path in _chapter_metadata_paths():
        jobs.append({"method": "_prepare_chapter_metadata", "args": [path]})
    jobs.append_array([
        {"method": "_prepare_av_metadata", "args": []},
        {"method": "_prepare_item_lore_metadata", "args": []},
        {"method": "_resolve_chapter_world_and_spawn", "args": []},
        {"method": "_prepare_inventory_state", "args": []}
    ])
    if world_mode:
        jobs.append({"method": "_restore_inventory_and_region", "args": []})
    jobs.append_array([
        {"method": "_restore_build_state", "args": []},
        {"method": "_sync_build_progress", "args": []},
        {"method": "_prepare_build_inputs", "args": []},
        {"method": "_prepare_audio_settings_key", "args": []},
        {"method": "_prepare_metsys_bridge", "args": []},
        {"method": "_prepare_audio", "args": []}
    ])
    if world_mode:
        jobs.append({"method": "_prepare_platform_and_gameplay_residency", "args": []})
    return jobs


func _chapter_metadata_paths() -> Array:
    var paths: Array = []
    var dir := DirAccess.open(CHAPTER_DATA_DIR)
…60036 tokens truncated…instance_valid(player):
            player.global_position = active_spawn
            if player.has_method("restore_at_save_point"):
                player.restore_at_save_point()
        _defer_region_call("_respawn_boss_trial_boss")
        _toast("试炼重置 · 守门者已经归位。")
    else:
        pending_enemy_respawn = true
        # 死亡重置：停 Boss 曲回到本章探索循环（director 缺席回退旧 ch01 单曲）。
        if audio_director != null:
            audio_director.stop_boss_music()
        else:
            _switch_bgm("bgm_ch01")
        _toast("归途重新开始，敌群与守门者已经归位。")
    _refresh_hud()


func _respawn_boss_trial_boss() -> void:
    if demo_complete or not boss_trial_mode:
        return
    _spawn_boss()


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
    return lowered == "boss_back_wall" or lowered.ends_with("_boss_back_wall") or lowered.contains("post_boss_wall") or lowered.contains("chapter_exit_wall")


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
        var tween := _region_tween()
        tween.tween_interval(float(index) * 0.08)
        tween.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.42)
        tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.42)
        tween.tween_callback(ring.queue_free)


func _on_hp_changed(value: int) -> void:
    # 濒死混音态（规格 §5.5）：HP==1 挂低通，回升或死亡即摘除。
    _set_low_hp_audio(value == 1)
    if value <= 0:
        # Enemy body-entered callbacks run during physics query flushing.
        _defer_region_call("_record_death_cache")
        # 玩家死亡（规格 §5.3/§5.5）：director 在场时全总线 300Hz 低通 + duck 自清；
        # 缺席时保持旧 duck 行为。
        if audio_director != null:
            audio_director.on_player_death()
        else:
            duck_bgm(-10.0, 1.2)
    _refresh_hud()


func _on_energy_changed(_value: int, _maximum: int) -> void:
    _refresh_hud()


func _refresh_hud() -> void:
    if hud_label == null:
        return
    var hp_text := str(player.hp) if player != null else "5"
    var energy_text := "%d/%d" % [player.energy, player.max_energy] if player != null else "0/100"
    var skill_text := "Ready" if player != null and player.skill_cooldown <= 0.0 and player.energy >= player.skill_energy_cost else "Charging"
    var shortcut_total := _shortcut_total()
    var opened_shortcut_count := _opened_shortcut_total()
    var shortcut_text := ("%d/%d" % [opened_shortcut_count, shortcut_total]) if shortcut_total > 0 else ("Open" if shortcut_open else "Closed")
    var boss_text := "Awake" if boss_spawned else ("Ready" if boss_unlocked else "Locked")
    var save_text := active_save_point_id
    if _combat_progression_enabled():
        var boss_route_text := "Open" if boss_unlocked else "Closed"
        hud_label.text = "HP %s/5  EN %s  Skill %s  Enemies %d/%d  Boss Route %s  Shortcuts %s  Boss %s  Save %s  A/D Move W/S Aim Space Jump Shift Dash LMB/J Slash RMB Heal E Skill F Use Tab Bag M Map" % [
            hp_text,
            energy_text,
            skill_text,
            enemy_defeated,
            enemy_total,
            boss_route_text,
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
    if ui_shell!=null:
        ui_shell.toast_age=0.0
    if toast_label != null:
        toast_label.text = text
    # toast 提示微音（音频规格 §4.5 ui_toast）：900ms 冷却防连发刷屏音。
    var now := Time.get_ticks_msec()
    if now - last_toast_sfx_ms >= 900:
        last_toast_sfx_ms = now
        _play_sfx("ui_toast", -6.0)
    print(text)


## 证词/失声印记/真名信物类物品的拾取展示（圣典 §7）：普通材料不打扰，
## 关键物品用独立横幅停留更久，后续 toast 不会盖掉它。headless 下纯 no-op 安全。
func _is_story_key_item(item_id: String) -> bool:
    return item_id.begins_with("testimony_") \
        or item_id.begins_with("silent_mark_") \
        or STORY_KEY_ITEM_IDS.has(item_id)


func _announce_lore_pickup(item_id: String) -> void:
    if not _is_story_key_item(item_id):
        return
    # 关键道具拾取混音态（规格 §5.3）：Music -6dB 短暂让位 + 专属拾取音。
    if audio_director != null:
        audio_director.on_key_item_pickup()
    _play_sfx("ui_pickup_key_item", -8.0)
    var lore_entry: Dictionary = item_lore.get(item_id, {})
    var lore_lines: Array = lore_entry.get("lore", [])
    if lore_lines.is_empty():
        return
    var text := "拾获「%s」——%s" % [_item_display_name(item_id), String(lore_lines[0])]
    lore_banner_time_left = LORE_BANNER_SECONDS
    if lore_banner_label != null:
        lore_banner_label.text = text
        lore_banner_label.visible = true
    print("LORE_PICKUP " + text)


# _process 驱动的横幅倒计时：不挂定时器/回调，headless 退出无残留。
func _tick_lore_banner(delta: float) -> void:
    if lore_banner_time_left <= 0.0:
        return
    lore_banner_time_left -= delta
    if lore_banner_time_left <= 0.0 and lore_banner_label != null:
        lore_banner_label.text = ""
        lore_banner_label.visible = false


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

    var tween := _region_tween()
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
        "shortcut_total": _shortcut_total(),
        "opened_shortcut_total": _opened_shortcut_total(),
        "opened_shortcut_ids": opened_shortcuts.keys(),
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
        "story_flag_total": story_flags.size(),
        "story_flags": story_flags.duplicate(),
        "currency_count": currency_count,
        "inventory_item_total": inventory_counts.size(),
        "unlocked_ability_total": unlocked_abilities.size(),
        "unlocked_ability_ids": unlocked_abilities.keys(),
        "locked_gate_total": config.get("locked_gates", []).size(),
        "locked_gate_remaining": locked_gate_bodies.size(),
        "visited_room_total": visited_rooms.size(),
        "current_room_id": current_room_id,
        "current_room_archetype": _room_map_copy(current_room_id, "archetype", ""),
        "current_room_pacing_role": _room_map_copy(current_room_id, "pacing_role", ""),
        "current_room_traversal_focus": _room_map_copy(current_room_id, "traversal_focus", ""),
        "current_room_reward_contract": _room_map_copy(current_room_id, "reward_contract", ""),
        "current_room_setpiece": _room_map_copy(current_room_id, "setpiece", ""),
        "current_room_micro_objective": _room_map_copy(current_room_id, "micro_objective", ""),
        "backpack_overlay_ready": backpack_panel != null,
        "map_overlay_ready": map_panel != null,
        "dialogue_overlay_ready": dialogue_panel != null,
        "guide_marker_total": config.get("guides", []).size(),
        "active_overlay": active_overlay,
        "boss_trial_mode": boss_trial_mode,
        "chapter_exit_total": chapter_exit_total,
        "ending_exit_total": ending_exit_total,
        "carried_inventory_enabled": carried_inventory_enabled,
        "ending_gate_total": _ending_gate_entries().size(),
        "ending_gates_spawned": ending_gates_spawned,
        "ending_chosen": String(story_flags.get("ending_chosen", "")),
        "wish_total": _wish_board_entries().size(),
        "wish_claimed_total": _wish_claimed_total(),
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
        var query := PhysicsShapeQueryParameters2D.new()
        var shape := RectangleShape2D.new()
        shape.size=enemy_area.hurtbox_size
        query.shape=shape
        query.transform=Transform2D(0,enemy_area.global_position+enemy_area.hurtbox_offset)
        query.collision_mask=1
        query.collide_with_areas=false
        var spawn_clear := get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
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
            "platform_id": String(enemy_area.get_meta("platform_id","")),
            "locomotion": String(enemy_area.get("locomotion")),
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
        state["boss_position"] = [boss_actor.global_position.x, boss_actor.global_position.y]
        state["boss_body_size"] = [boss_body_size.x, boss_body_size.y]
        state["boss_hurtbox_size"] = [boss_hurtbox_size.x, boss_hurtbox_size.y]
        state["boss_visual_scale"] = float(boss_actor.get("visual_scale"))
        state["boss_asset_path"] = String(boss_actor.get("asset_path"))
        if boss_actor.has_method("get_ai_debug_state"):
            var boss_ai_debug: Dictionary = boss_actor.get_ai_debug_state()
            state["boss_last_attack_id"] = String(boss_ai_debug.get("last_attack_id", ""))
            state["boss_last_ai_decision"] = String(boss_ai_debug.get("last_ai_decision", ""))
            state["boss_tactical_ai"] = bool(boss_ai_debug.get("tactical_ai", false))
            state["boss_tactic"] = String(boss_ai_debug.get("boss_tactic", ""))
            state["boss_tactic_timer"] = float(boss_ai_debug.get("boss_tactic_timer", 0.0))
            state["boss_attack_desire"] = float(boss_ai_debug.get("attack_desire", 0.0))
            state["boss_attack_desire_threshold"] = float(boss_ai_debug.get("attack_desire_threshold", 0.0))
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


func _wish_claimed_total() -> int:
    var claimed := 0
    for wish_value in _wish_board_entries():
        if bool(story_flags.get(_wish_claim_flag(wish_value), false)):
            claimed += 1
    return claimed


func _debug_collect_all_keys() -> void:
    bell_count = max_bells
    _refresh_hud()


func _debug_collect_all_abilities() -> void:
    for collectible in config.get("collectibles", []):
        if not (collectible is Dictionary):
            continue
        var data: Dictionary = collectible
        if String(data.get("kind", "")) != "item":
            continue
        var item_id := String(data.get("item_id", ""))
        if item_id.is_empty():
            continue
        _add_inventory_item(item_id, 1, false)
        unlocked_abilities[item_id] = String(data.get("ability_name", data.get("label", item_id)))
    _refresh_ability_gates()
    _refresh_hud()


func _debug_clear_combat_route() -> void:
    enemy_defeated = enemy_total
    if _combat_progression_enabled():
        _open_combat_clear_route()
    _refresh_hud()


func _debug_open_shortcut() -> void:
    _open_all_shortcuts()


func _debug_open_all_shortcuts() -> void:
    _open_all_shortcuts()


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

func _shortcut_is_lever_controlled(shortcut_id: String) -> bool:
    if shortcut_id.is_empty():
        return false
    for interactive in config.get("interactives", []):
        if interactive is Dictionary and String(interactive.get("kind", "")) == "lever" and String(interactive.get("shortcut_id", "")) == shortcut_id:
            return true
    return false


func _room_has_position_bounds(room_data: Dictionary) -> bool:
    if _room_layout_rect(room_data).has_area():
        return true
    for rect_value in room_data.get("visit_rects", []):
        if _rect2(rect_value).has_area():
            return true
    return false


func _room_containing_area(room_data: Dictionary, world_position: Vector2) -> float:
    var area := INF
    var layout := _room_layout_rect(room_data)
    if layout.has_area() and _rect_contains_position(layout, world_position):
        area = layout.get_area()
    for rect_value in room_data.get("visit_rects", []):
        var rect := _rect2(rect_value)
        if rect.has_area() and _rect_contains_position(rect, world_position):
            area = minf(area, rect.get_area())
    return area


func _unlock_boss_route() -> void:
    boss_unlocked = true
    shortcut_open = true
    if gate_body != null and is_instance_valid(gate_body):
        gate_body.queue_free()
        gate_body = null


func _open_combat_clear_route() -> void:
    for shortcut_id in _shortcut_ids():
        if not _shortcut_is_lever_controlled(String(shortcut_id)):
            opened_shortcuts[String(shortcut_id)] = true
    _unlock_boss_route()
    _refresh_hud()



func get_build_system() -> RefCounted:
    return build_system

func _sync_player_build() -> void:
    if not world_mode or build_system == null:
        return
    build_system.sync_progress(inventory_counts, String(config.get("id", "")), story_flags)
    if player != null and is_instance_valid(player):
        var profile: Dictionary = build_system.profile()
        if profile != applied_build_profile:
            player.apply_build_stats(profile)
            applied_build_profile = profile.duplicate(true)

func _bind_build_inputs() -> void:
    var bindings := {"skill_cycle": [KEY_C, JOY_AXIS_TRIGGER_LEFT],
        "tool_cast": [KEY_T, JOY_BUTTON_DPAD_DOWN], "tool_cycle": [KEY_G, JOY_AXIS_TRIGGER_RIGHT]}
    for action in bindings:
        if InputMap.has_action(action):
            continue
        InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = int(bindings[action][0])
        InputMap.action_add_event(action, key)
        if action == "tool_cast":
            var joy := InputEventJoypadButton.new()
            joy.button_index = int(bindings[action][1])
            InputMap.action_add_event(action, joy)
        else:
            var trigger := InputEventJoypadMotion.new()
            trigger.axis = int(bindings[action][1])
            trigger.axis_value = 1.0
            InputMap.action_add_event(action, trigger)

func _near_workstation(crafting: bool = false) -> bool:
    if player == null or player.hp <= 0 or player.death_timer > 0.0 or (boss_arena_lock_body != null and is_instance_valid(boss_arena_lock_body)):
        return false
    for child in get_children():
        if not child is Area2D or player.global_position.distance_to(child.global_position) > 120.0:
            continue
        var kind := String(child.get_meta("kind", ""))
        if kind == "save_point" and not crafting:
            return true
        if crafting and kind == "npc":
            var id := String(child.get_meta("npc_id", child.name))
            if id in ["npc_rain_smith_liu", "npc_threadsmith_apprentice", "npc_beeswax_vendor"]:
                return true
    return false

## Read-only proximity query used by UI affordances and explicit quote actions.
func is_near_shrine() -> bool:
    return _near_workstation(false)

func _build_wallet_snapshot() -> Dictionary:
    return {"currency": currency_count, "inventory_counts": inventory_counts.duplicate(true)}

func _set_build_wallet(wallet: Dictionary) -> void:
    currency_count = int(wallet.get("currency", currency_count))
    inventory_counts = wallet.get("inventory_counts", inventory_counts).duplicate(true)
    inventory_materials.clear()
    for item_id in inventory_counts:
        if String(_item_data(String(item_id)).get("category", "Materials")) == "Materials":
            inventory_materials[item_id] = int(inventory_counts[item_id])

func _rollback_build_transaction(build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> void:
    if build_system != null:
        build_system.restore(build_before)
    currency_count = int(wallet_before.get("currency", currency_count))
    inventory_counts = wallet_before.get("inventory_counts", inventory_counts).duplicate(true)
    inventory_materials = materials_before.duplicate(true)

func _finish_build_transaction(result: Dictionary, build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> Dictionary:
    if not _save_world():
        _rollback_build_transaction(build_before, wallet_before, materials_before)
        result.ok = false
        result.reason = "归途记录未能写入；本次购买或制作已回滚。"
        _toast(String(result.reason))
        _refresh_hud()
        return result
    # Apply derived player stats only after the save transaction commits. A
    # failed disk write therefore cannot disturb HP, thread or action cooldowns.
    _sync_player_build()
    _refresh_hud()
    return result

func perform_build_action(action: String, id: String = "", extra: Variant = null) -> Dictionary:
    if build_system == null or not world_mode:
        return {"ok": false, "reason": "构筑系统在互联世界旅途中开放"}
    if player == null or player.hp <= 0 or chapter_transitioning or world_loading:
        return {"ok": false, "reason": "当前无法更换构筑"}
    if action == "quote_resupply":
        if not _near_workstation():
            return {"ok": false, "reason": "请在钟龛查看战具补给报价"}
        return build_system.quote_resupply(_build_wallet_snapshot())
    if action in ["resupply_tools", "paid_resupply"] and not _near_workstation():
        return {"ok": false, "reason": "请在钟龛补给战具"}
    if world_save_blocked:
        return {"ok": false, "reason": "构筑存档不兼容，当前不能保存交易"}
    var build_before: Dictionary = build_system.serialize()
    var wallet_before := _build_wallet_snapshot()
    var materials_before: Dictionary = inventory_materials.duplicate(true)
    var result: Dictionary = {"ok": false, "reason": "未知构筑操作"}
    match action:
        "switch_crest", "crest":
            result = build_system.switch_crest(id, _near_workstation())
        "select_skill", "skill":
            result = build_system.select_skill(id, int(extra) if extra is int or extra is float else -1) if _near_workstation() else {"ok": false, "reason": "请在钟龛调整技能位置"}
        "select_tool", "tool":
            result = build_system.select_tool(id, int(extra) if extra is int or extra is float else -1) if _near_workstation() else {"ok": false, "reason": "请在钟龛调整战具位置"}
        "equip_family_slot":
            var family := String(extra.get("family", "")) if extra is Dictionary else ""
            var slot := int(extra.get("slot", -1)) if extra is Dictionary else -1
            result = build_system.equip_family_slot(id, family, slot, _near_workstation())
        "cycle_skill":
            result = build_system.cycle_skill()
        "cycle_tool":
            result = build_system.cycle_tool()
        "equip_passive", "passive":
            result = build_system.equip_passive(id) if _near_workstation() else {"ok": false, "reason": "请在钟龛调整铭饰"}
        "save_loadout":
            result = build_system.save_loadout(id)
        "restore_loadout", "load_loadout":
            result = build_system.restore_loadout(id) if _near_workstation() else {"ok": false, "reason": "请在钟龛恢复构筑方案"}
        "resupply_tools", "paid_resupply":
            result = build_system.resupply_tools(_build_wallet_snapshot(), _near_workstation())
            if result.get("ok", false):
                _set_build_wallet(result.wallet)
        "transact", "craft":
            if not _near_workstation(true):
                result = {"ok": false, "reason": "请与雨铸匠、织线学徒或蜂蜡商人面对面强化"}
            else:
                result = build_system.transact(id, _build_wallet_snapshot())
                if result.get("ok", false):
                    _set_build_wallet(result.wallet)
        "use_tool":
            if not active_overlay.is_empty() or not player._can_start_action():
                return {"ok": false, "reason": "请在动作结束后使用战具"}
            var selected_tool_id := String(build_system.state.tools[int(build_system.state.active_tool_slot)])
            if selected_tool_id == "mine":
                var owned_traps := 0
                for effect in get_tree().get_nodes_in_group("player_trap"):
                    if effect.get("owner_player") == player:
                        owned_traps += 1
                if owned_traps >= 2:
                    return {"ok": false, "reason": "场上已有两枚布置中的地雷"}
            result = build_system.use_tool()
    if result.get("ok", false):
        result = _finish_build_transaction(result, build_before, wallet_before, materials_before)
        if result.get("ok", false) and action == "use_tool" and not player.cast_tool(result):
            # Stock is durable before effects exist. If the effect cannot start,
            # persist a refund; if that write fails, retain the spent state so
            # memory and disk still agree and no free effect can be created.
            var spent_build: Dictionary = build_system.serialize()
            build_system.restore(build_before)
            if _save_world():
                _sync_player_build()
                result = {"ok": false, "reason": "当前无法使用战具；已退还次数"}
            else:
                build_system.restore(spent_build)
                _sync_player_build()
                result = {"ok": false, "reason": "战具未能启动且退款暂未写入；本次次数已消耗"}
    elif not String(result.get("reason", "")).is_empty():
        _toast(String(result.reason))
    return result

func _toggle_build() -> void:
    if ui_shell == null or not is_instance_valid(ui_shell.get("build_panel")):
        return
    if active_overlay == "build":
        _close_overlays()
        return
    _close_overlays()
    active_overlay = "build"
    ui_shell.build_panel.visible = true
    ui_shell.refresh_build()
    _sync_ui_input_lock()

func _on_ability_action(ability_id: String, origin: Vector2, direction: Vector2) -> void:
    if _walking_world_passage():
        return
    if not world_mode or int(inventory_counts.get(ability_id, 0)) <= 0 or player == null or player.hp <= 0:
        return
    var changed := false
    for gate in config.get("locked_gates", []):
        if String(gate.get("requires_action", "")) != ability_id:
            continue
        var id := String(gate.get("id", ""))
        if not locked_gate_bodies.has(id):
            continue
        var rect := _rect2(gate.get("rect", []))
        var closest := Vector2(clampf(origin.x, rect.position.x, rect.end.x), clampf(origin.y - 42.0, rect.position.y, rect.end.y))
        if closest.distance_to(origin - Vector2(0, 42)) > float(gate.get("action_range", 150.0)):
            continue
        # A downward break only acts on ground below the player, never a side wall.
        if ability_id == "thorn_downstrike" and (direction.y < 0.5 or origin.y > rect.end.y):
            continue
        var unlock_id := String(gate.get("permanent_action_unlock_id", id))
        changed = true
        story_flags["action_gate_" + unlock_id] = true
        _spawn_route_open_effect(rect.get_center())
        _unlock_ability_gate(id, String(GATE_UNLOCK_SFX.get(ability_id, "gate_dash")))
        _toast(String(gate.get("open_message", "动作唤醒旧机关，回访通路永久接通。")))
    if changed:
        _save_world()

func get_save_slots() -> Array:
    return WORLD_STATE_SCRIPT.slot_summaries()

func select_save_slot(index: int) -> bool:
    if not world_mode or index < 1 or index > 3 or chapter_transitioning or player.hp <= 0:
        return false
    var path := WORLD_STATE_SCRIPT.slot_path(index)
    if path == world_save_path:
        return true
    var candidate = WORLD_STATE_SCRIPT.new()
    if FileAccess.file_exists(path) and not candidate.read(path):
        _toast("该旅途记录无法读取，已保留原文件；请先恢复该槽备份。")
        return false
    _save_world()
    chapter_transitioning = true
    _defer_region_call("_replace_with_save_slot", [index])
    return true

func _replace_with_save_slot(index: int, path_override: String = "") -> void:
    var parent_node := get_parent()
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_slot = index
    scene.world_startup_options_enabled = false
    scene.world_save_path = path_override if not path_override.is_empty() else WORLD_STATE_SCRIPT.slot_path(index)
    var was_current := get_tree().current_scene == self
    parent_node.remove_child(self)
    parent_node.add_child(scene)
    if was_current:
        scene.get_tree().current_scene = scene
    queue_free()

func restore_save_backup(index: int = 0) -> bool:
    if not world_mode or chapter_transitioning:
        return false
    var slot := world_slot if index == 0 else clampi(index, 1, 3)
    var recovered = WORLD_STATE_SCRIPT.new()
    if not recovered.restore_backup(WORLD_STATE_SCRIPT.slot_path(slot)):
        _toast("备份恢复失败：" + recovered.last_error)
        return false
    chapter_transitioning = true
    _defer_region_call("_replace_with_save_slot", [slot])
    return true

func _ground_is_hazardous(position_value: Vector2) -> bool:
    for hazard in config.get("hazards", []):
        if _rect2(hazard.get("rect", [])).grow(36).has_point(position_value):
            return true
    return false

func _record_death_cache() -> void:
    if not world_mode or death_recorded or world_state == null:
        return
    death_recorded = true
    var lost := int(currency_count / 2)
    currency_count -= lost
    var recovery := last_safe_ground if last_safe_ground != Vector2.ZERO else active_spawn
    # Boss attempts leave currency at the outside checkpoint, beyond the arena seal.
    if boss_spawned:
        recovery = active_spawn
    world_state.capture_global({"death_cache": {"region_id": String(config.get("id", "")), "position": [recovery.x, recovery.y], "currency": lost}})
    _spawn_death_cache()
    _save_world()
    _toast("碎钱的一半留在归途结；再次倒下会替换旧结，能力与装备保留。")

func _spawn_death_cache() -> void:
    if death_cache_area != null and is_instance_valid(death_cache_area):
        death_cache_area.queue_free()
    death_cache_area = null
    if not world_mode or world_state == null:
        return
    var cache: Dictionary = world_state.data.get("death_cache", {})
    if cache.is_empty() or String(cache.get("region_id", "")) != String(config.get("id", "")) or int(cache.get("currency", 0)) <= 0:
        return
    var area := Area2D.new()
    area.name = "DeathRecoveryKnot"
    area.position = _vec2(cache.position)
    area.set_meta("kind", "death_cache")
    area.set_meta("manual_pickup", true)
    area.set_meta("label", "归途结 · 找回碎钱")
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 54.0
    shape.shape = circle
    area.add_child(shape)
    var ring := Line2D.new()
    ring.closed = true
    ring.width = 4.0
    ring.default_color = Color("e9c276")
    for i in range(17):
        var angle := TAU * float(i) / 16.0
        ring.add_point(Vector2(cos(angle), sin(angle)) * 24.0 - Vector2(0, 32))
    area.add_child(ring)
    _add_wayfinding(area)
    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)
    death_cache_area = area

func _recover_death_cache(area: Area2D) -> void:
    if not world_mode or player.hp <= 0 or world_state == null:
        return
    var cache: Dictionary = world_state.data.get("death_cache", {})
    _add_currency(int(cache.get("currency", 0)))
    world_state.capture_global({"death_cache": {}})
    area.queue_free()
    death_cache_area = null
    _save_world()
    _toast("归途结已收回，遗留碎钱回到行囊。")
    _refresh_hud()


func _hold_actor_support(platform_id: String) -> void:
    if world_platforms != null:
        world_platforms.hold(self, platform_id)
    if is_instance_valid(chapter_terrain):
        chapter_terrain.hold_collision_support(platform_id)


func _ensure_collision_segment(from: Vector2, to: Vector2) -> void:
    if world_mode and is_instance_valid(chapter_terrain):
        chapter_terrain.ensure_collision_segment(from, to)
    if world_mode and is_instance_valid(cave_world):
        cave_world.ensure_collision_segment(from, to)
    if world_platforms != null:
        world_platforms.ensure_segment(self, from, to)


func _rock_ray_hit(from: Vector2, to: Vector2) -> Dictionary:
    var hit: Dictionary = cave_world.rock_ray_hit(from, to) if world_mode and is_instance_valid(cave_world) else {}
    if world_platforms != null:
        var platform: Dictionary = world_platforms.ray_hit(self, from, to)
        if not platform.is_empty() and (hit.is_empty() or from.distance_squared_to(platform.position) < from.distance_squared_to(hit.position)):
            hit = platform
    if world_mode and is_instance_valid(chapter_terrain):
        var terrain: Dictionary = chapter_terrain.terrain_ray_hit(from, to)
        if not terrain.is_empty() and (hit.is_empty() or from.distance_squared_to(terrain.position) < from.distance_squared_to(hit.position)):
            hit = terrain
    return hit


func _walking_world_passage() -> bool:
    return is_instance_valid(world_passage) and world_passage.active


func _world_collision_ready() -> bool:
    if is_instance_valid(world_passage) and world_passage.active:
        return not world_passage.settling and Engine.get_physics_frames() > world_passage.sync_until
    var cave_ready: bool = not world_mode or not is_instance_valid(cave_world) or cave_world.critical_collision_ready()
    var terrain_ready: bool = not world_mode or not is_instance_valid(chapter_terrain) or chapter_terrain.critical_collision_ready()
    return cave_ready and terrain_ready and (world_platforms == null or world_platforms.ready())


func _release_region_platforms() -> void:
    if is_instance_valid(chapter_terrain):
        chapter_terrain.close_collisions()
    if world_platforms != null:
        world_platforms.shutdown()
    if world_gameplay_residency != null:
        world_gameplay_residency.shutdown()
    npc_residency_memory.clear()
    save_point_residency_memory.clear()

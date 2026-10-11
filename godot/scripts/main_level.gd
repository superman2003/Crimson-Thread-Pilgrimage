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
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")
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
var world_narrative: WORLD_NARRATIVE_SCRIPT
var world_collected_ids: Dictionary = {}
var world_catalog: Dictionary = {}
var world_write_error_shown := false
var world_loading := true
var world_initial_error := ""
var subtitle_elapsed := 0.0
var subtitle_seconds := 0.0
var new_journey_dialog: ConfirmationDialog
var world_new_key_held := false
var world_map_view := false
var world_map_key_held := false

@export var config_path := DEFAULT_CONFIG_PATH


func _ready() -> void:
    _apply_cmdline_config_override()
    _prepare_world_start()
    config = _load_json(config_path)
    if world_mode:
        config = WORLD_ROUTES_SCRIPT.apply_to(config)
        world_narrative = WORLD_NARRATIVE_SCRIPT.new()
        _build_world_catalog()
    if config.is_empty():
        push_error("Missing demo config: " + config_path)
        return
    campaign = _load_json(CAMPAIGN_PATH)
    chapter_file_configs = _load_chapter_file_configs()
    audio_visual_manifest = _load_json(AV_MANIFEST_PATH)
    item_lore = _load_json(ITEM_LORE_PATH).get("items", {})
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
    if world_mode:
        _restore_world_inventory_and_region()
    _bind_audio_settings_key()
    _build_metsys_bridge()
    _build_audio()
    _build_world_from_config()
    _spawn_player()
    if world_mode:
        _restore_world_runtime()
    # 音频状态机运行时注入（契约 bind_runtime）：director 自驱轮询，这里只此一行。
    audio_director.bind_runtime(player, func() -> Array: return get_tree().get_nodes_in_group("enemy"))
    _build_hud()
    _show_chapter_entry_message()
    world_loading = false
    if world_mode:
        _build_new_journey_dialog()
        if not world_initial_error.is_empty():
            _toast(world_initial_error)
        _save_world()
    if boss_trial_mode:
        call_deferred("_start_boss_trial")


func _apply_cmdline_config_override() -> void:
    var args := OS.get_cmdline_args()
    args.append_array(OS.get_cmdline_user_args())
    for arg in args:
        var text := String(arg)
        if text.begins_with("--demo-config="):
            config_path = text.get_slice("=", 1)
            world_mode = false
        elif text == "--boss-trial" or text == "--ch01-boss-trial":
            boss_trial_mode = true
            world_mode = false
            config_path = BOSS_TRIAL_CONFIG_PATH


func _physics_process(_delta: float) -> void:
    # Check the void before player movement can depenetrate against deep cave rock.
    if player != null and is_instance_valid(player) and player.global_position.y > fall_y:
        _void_respawn()


func _process(_delta: float) -> void:
    var new_key := Input.is_physical_key_pressed(KEY_F9)
    var new_requested := new_key and not world_new_key_held
    world_new_key_held = new_key
    var map_key := Input.is_physical_key_pressed(KEY_TAB)
    if world_mode and active_overlay == "map" and map_key and not world_map_key_held:
        world_map_view = not world_map_view
        _refresh_map_overlay()
    world_map_key_held = map_key
    if world_mode and new_requested and new_journey_dialog != null and not new_journey_dialog.visible:
        new_journey_dialog.popup_centered()
        active_overlay = "new_journey"
        _sync_ui_input_lock()
    if active_overlay == "new_journey":
        return
    if active_overlay == "dialogue" and dialogue_text_label != null:
        subtitle_elapsed += _delta
        dialogue_text_label.visible_characters = mini(dialogue_text_label.text.length(), int(dialogue_text_label.text.length() * subtitle_elapsed / maxf(0.1, subtitle_seconds)))
    _tick_lore_banner(_delta)
    if pending_enemy_respawn:
        pending_enemy_respawn = false
        _spawn_normal_enemies()
        if boss_unlocked and not demo_complete and not boss_spawned:
            _spawn_boss()
        _refresh_hud()
    if Input.is_action_just_pressed("close_overlay"):
        _close_overlays()
    elif Input.is_action_just_pressed("inventory"):
        _toggle_backpack()
    elif Input.is_action_just_pressed("map"):
        _toggle_map()
    elif Input.is_action_just_pressed("audio_settings"):
        _toggle_audio_settings()
    if active_overlay == "backpack":
        if Input.is_action_just_pressed("aim_up"):
            _move_backpack_selection(-1)
        elif Input.is_action_just_pressed("aim_down"):
            _move_backpack_selection(1)
    elif active_overlay == "settings":
        if Input.is_action_just_pressed("aim_up"):
            _move_settings_selection(-1)
        elif Input.is_action_just_pressed("aim_down"):
            _move_settings_selection(1)
        if Input.is_action_just_pressed("move_left"):
            _adjust_settings_volume(-5.0)
        elif Input.is_action_just_pressed("move_right"):
            _adjust_settings_volume(5.0)
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
    var active_director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if active_director != null and active_director != audio_director:
        if bgm_duck_tween != null and bgm_duck_tween.is_valid():
            bgm_duck_tween.kill()
        return
    # 总线是全局状态：场景销毁时摘掉濒死低通并复位 duck 音量，避免跨章节残留。
    _set_low_hp_audio(false)
    if bgm_duck_tween != null and bgm_duck_tween.is_valid():
        bgm_duck_tween.kill()
    # 章节转场竞态修复：新场景的 AudioDirector 已接管总线（并按用户音量归位）时，
    # 老场景退树不得再把 BGM 总线打回默认 0dB。
    var live_director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if live_director != null and live_director != audio_director:
        return
    _set_bgm_bus_volume_db(float(AUDIO_BUS_DEFAULT_VOLUME_DB.get("BGM", 0.0)))


func _prepare_world_start() -> void:
    if not world_mode:
        return
    if world_state == null:
        world_state = WORLD_STATE_SCRIPT.new()
        var args := OS.get_cmdline_args()
        args.append_array(OS.get_cmdline_user_args())
        if args.has("--new-game"):
            world_resume = false
            if FileAccess.file_exists(world_save_path):
                DirAccess.copy_absolute(ProjectSettings.globalize_path(world_save_path), ProjectSettings.globalize_path(world_save_path + ".previous"))
                DirAccess.remove_absolute(ProjectSettings.globalize_path(world_save_path))
        if world_resume and world_state.read(world_save_path):
            var saved_path := WORLD_ROUTES_SCRIPT.config_path(String(world_state.data.current_region))
            if not saved_path.is_empty():
                config_path = saved_path
                entry_spawn_override_enabled = true
                entry_spawn_override = _vec2(world_state.data.entry)
        elif world_resume and world_state.last_error != "missing":
            world_initial_error = "归途记录无法读取，本次不会覆盖原记录。"


func _build_world_catalog() -> void:
    # Cross-region items keep their category and description on every visit.
    var routes := _load_json("res://data/world_routes.json")
    for region_id in routes.get("chapters", {}):
        var region_config := WORLD_ROUTES_SCRIPT.apply_to(_load_json(WORLD_ROUTES_SCRIPT.config_path(String(region_id))))
        world_catalog.merge(region_config.get("inventory", {}).get("catalog", {}), false)


func _restore_world_inventory_and_region() -> void:
    var snapshot: Dictionary = world_state.data
    story_flags = snapshot.story_flags.duplicate(true)
    for item_id in snapshot.inventory_counts:
        var missing := int(snapshot.inventory_counts[item_id]) - int(inventory_counts.get(item_id, 0))
        if missing > 0:
            _add_inventory_item(String(item_id), missing, false)
    currency_count = int(snapshot.currency)
    story_flags = snapshot.story_flags.duplicate(true)
    var region := world_state.get_region(String(config.get("id", "")))
    world_collected_ids = region.collected_ids.duplicate(true)
    opened_shortcuts = region.opened_shortcuts.duplicate(true)
    visited_rooms = region.visited_rooms.duplicate(true)
    bell_count = int(region.bell_count)
    shortcut_open = bool(region.shortcut_open)
    boss_unlocked = bool(region.boss_unlocked)
    demo_complete = bool(region.boss_defeated)
    if not String(region.checkpoint_id).is_empty():
        active_spawn = _vec2(region.checkpoint)
        active_save_point_id = String(region.checkpoint_id)


func _restore_world_runtime() -> void:
    if entry_spawn_override_enabled:
        player.global_position = entry_spawn_override
    player.set_spawn(active_spawn)
    player.hp = clampi(int(world_state.data.hp), 1, player.max_hp)
    player.energy = clampi(int(world_state.data.energy), 0, player.max_energy)
    if shortcut_open or boss_unlocked:
        _unlock_boss_route()
    if demo_complete:
        _open_post_boss_route()
    # Reconstruct discovered cells after MetSys builds this region's map.
    if metsys_bridge != null:
        for room_id in visited_rooms:
            if bool(visited_rooms[room_id]):
                metsys_bridge.discover_room(String(room_id))


func _save_world() -> void:
    if not world_mode or world_loading or world_state == null or player == null:
        return
    var region_id := String(config.get("id", ""))
    var captured := world_state.capture_region(region_id, {
        "collected_ids": world_collected_ids, "opened_shortcuts": opened_shortcuts,
        "visited_rooms": visited_rooms, "boss_defeated": demo_complete,
        "boss_unlocked": boss_unlocked, "shortcut_open": shortcut_open,
        "bell_count": bell_count, "checkpoint": active_spawn,
        "checkpoint_id": active_save_point_id})
    captured = world_state.capture_global({
        "inventory_counts": inventory_counts, "currency": currency_count,
        "story_flags": story_flags, "current_region": region_id,
        "entry": active_spawn, "hp": player.hp, "energy": player.energy}) and captured
    if (not captured or not world_state.write(world_save_path)) and not world_write_error_shown:
        world_write_error_shown = true
        _toast("归途记录暂未写入，当前旅途进度仍保留。")


func _world_portal(data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "world_portal"))
    area.position = _vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "world_portal")
    area.set_meta("label", String(data.get("label", "旧通路")))
    area.set_meta("interaction_label", String(data.get("label", "旧通路")))
    area.set_meta("world_portal_data", data.duplicate(true))
    area.add_to_group("interactable")
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = _vec2(data.get("interaction_size", [100, 100]))
    shape.shape = rectangle
    area.add_child(shape)
    var arch := Line2D.new()
    arch.name = "WorldPortalArch"
    arch.width = 5.0
    arch.default_color = Color(0.40, 0.80, 0.88) if _world_portal_missing(data).is_empty() else Color(0.93, 0.67, 0.30)
    for index in range(17):
        var angle := PI + PI * index / 16.0
        arch.add_point(Vector2(cos(angle) * 29.0, sin(angle) * 46.0))
    arch.add_point(Vector2(29, 17))
    area.add_child(arch)
    var glyph := Label.new()
    glyph.text = "F"
    glyph.position = Vector2(-8, -32)
    glyph.add_theme_font_size_override("font_size", 20)
    area.add_child(glyph)
    area.body_entered.connect(_on_interactable_entered.bind(area))
    area.body_exited.connect(_on_interactable_exited.bind(area))
    add_child(area)


func _world_grapple_anchor(data: Dictionary) -> void:
    var anchor := Node2D.new()
    anchor.name = String(data.get("id", "grapple_anchor"))
    anchor.position = _vec2(data.get("position", [0, 0]))
    anchor.set_meta("required_ability", String(data.get("required_ability", "echo_hook")))
    anchor.set_meta("grapple_enabled", false)
    anchor.add_to_group("grapple_anchor")
    var ring := Line2D.new()
    ring.name = "CopperGrappleRing"
    ring.width = 3.0
    ring.default_color = Color(0.80, 0.62, 0.30)
    for index in range(25):
        ring.add_point(Vector2.from_angle(TAU * index / 24.0) * 13.0)
    anchor.add_child(ring)
    var chain := Line2D.new()
    chain.width = 2.0
    chain.default_color = Color(0.48, 0.43, 0.28)
    chain.add_point(Vector2(0, -45))
    chain.add_point(Vector2(0, -13))
    anchor.add_child(chain)
    add_child(anchor)


func _world_portal_missing(data: Dictionary) -> String:
    var shortcut := String(data.get("unlock_shortcut_id", ""))
    if not shortcut.is_empty() and bool(story_flags.get("world_shortcut_" + shortcut, false)):
        return ""
    var required_shortcut := String(data.get("requires_shortcut", ""))
    if not required_shortcut.is_empty() and not bool(story_flags.get("world_shortcut_" + required_shortcut, false)):
        return String(data.get("hint", "门闩在另一侧。请先寻找别的通路。"))
    var ability := String(data.get("required_ability", ""))
    if not ability.is_empty() and int(inventory_counts.get(ability, 0)) <= 0:
        return String(data.get("hint", "需要" + _item_display_name(ability) + "。暂时可以探索别处。"))
    return ""


func _activate_world_portal(area: Area2D) -> void:
    if not world_mode or chapter_transitioning or area == null or player.hp <= 0 or player.death_timer > 0.0:
        return
    var data: Dictionary = area.get_meta("world_portal_data", {})
    var missing := _world_portal_missing(data)
    if not missing.is_empty():
        _toast(missing)
        return
    var next_path := WORLD_ROUTES_SCRIPT.config_path(String(data.get("target_config_id", "")))
    if next_path.is_empty():
        _toast("这条旧路尚未接通。")
        return
    var shortcut := String(data.get("unlock_shortcut_id", ""))
    if not shortcut.is_empty():
        story_flags["world_shortcut_" + shortcut] = true
    chapter_transitioning = true
    _close_overlays()
    _save_world()
    if audio_director != null:
        audio_director.begin_chapter_transition()
    _play_sfx_persistent("chapter_transition", -9.0)
    call_deferred("_travel_world", next_path, _vec2(data.get("target_spawn", [120, 500])))


func _travel_world(next_path: String, entry: Vector2) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        chapter_transitioning = false
        return
    _save_world()
    var next_scene: Node = load("res://scenes/World.tscn").instantiate()
    next_scene.config_path = next_path
    next_scene.world_state = world_state
    next_scene.world_resume = false
    next_scene.world_save_path = world_save_path
    next_scene.entry_spawn_override_enabled = true
    next_scene.entry_spawn_override = entry
    next_scene.entered_from_config_id = String(config.get("id", ""))
    next_scene.transition_entry_message = "旧路重新接通 · " + String(_load_json(next_path).get("name", ""))
    var was_current := get_tree().current_scene == self
    parent_node.remove_child(self)
    parent_node.add_child(next_scene)
    if was_current:
        next_scene.get_tree().current_scene = next_scene
    queue_free()


func _commit_world_dialogue() -> void:
    if not world_mode or active_overlay != "dialogue" or ui_shell == null or dialogue_text_label == null:
        return
    if dialogue_text_label.visible_characters >= 0 and dialogue_text_label.visible_characters < dialogue_text_label.text.length():
        return
    var area: Area2D = ui_shell.dialogue_area
    if not is_instance_valid(area):
        return
    if bool(area.get_meta("world_line_committed", false)):
        return
    area.set_meta("world_line_committed", true)
    var state := String(area.get_meta("dialogue_state", "repeat"))
    var indices: Dictionary = area.get_meta("dialogue_state_indices", {})
    var displayed_index := int(area.get_meta("world_displayed_index", -1))
    indices[state] = displayed_index + 1
    area.set_meta("dialogue_state_indices", indices)
    if state == "first_meet" and displayed_index + 1 >= int(area.get_meta("world_displayed_total", 0)):
        _set_story_flag("npc_met_%s" % String(area.get_meta("npc_id", area.name)))
    var result: Dictionary = area.get_meta("world_dialogue_result", {})
    for flag in WORLD_NARRATIVE_SCRIPT.completion_flags(result, int(area.get_meta("world_displayed_index", -1)), story_flags):
        _set_story_flag(String(flag))
    if bool(story_flags.get("quest_bring_names_complete", false)) and not bool(story_flags.get("quest_bring_names_rewarded", false)):
        story_flags["quest_bring_names_rewarded"] = true
        _add_currency(40)
        _toast("名字已经带回 · 学徒将四十枚碎钱缝进你的行囊。")
    _save_world()


func _add_world_portal_map_pins(bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> void:
    for data in config.get("interactives", []):
        if String(data.get("kind", "")) != "world_portal":
            continue
        var position_value := _vec2(data.get("position", [0, 0]))
        var room := _room_for_position(position_value)
        if not _room_is_visited(String(room.get("id", ""))):
            continue
        var color := Color(0.35, 0.83, 1.0) if _world_portal_missing(data).is_empty() else Color(1.0, 0.68, 0.24)
        _add_map_pin(position_value, draw_width, base_y, depth_step, color, Vector2(13, 13), bounds, draw_size)


func _world_route_status() -> String:
    var parts: Array[String] = []
    for data in config.get("interactives", []):
        if String(data.get("kind", "")) == "world_portal":
            var status := "通" if _world_portal_missing(data).is_empty() else "待"
            parts.append("%s〔%s〕" % [String(data.get("label", "通路")), status])
    return " · ".join(parts)


func _world_exploration_hint() -> String:
    var region_id := String(config.get("id", ""))
    if region_id.contains("ch01"):
        if inventory_counts.has("double_thread_jump"):
            return "双线跃已会：返回运书索道，穿过盐风封门，带回失名证词。"
        return "盐风口暂不可通。沿下庭排水钟管去雨渠，也可先探索庭内捷径。"
    if region_id.contains("ch02"):
        if inventory_counts.has("silk_wall_grip"):
            return "攀壁已会：雨溢立管通向书库；排水钟管随时可以返回钟庭。"
        return "寻找低处检修台遗留的攀壁线爪；雨溢立管在上方，钟庭在来路。"
    if region_id.contains("ch03"):
        if inventory_counts.has("double_thread_jump"):
            return "双线跃使旧地生出新路：阅览台旁的运书线通回钟庭。"
        return "沿烛台阅览支线寻找双线跃；先前的雨渠入口仍可返回。"
    return "来路与返程都已标在地图上。继续探索，或带着新证据返回旧地。"


func _draw_world_atlas() -> void:
    var routes := _load_json("res://data/world_routes.json")
    var regions: Dictionary = routes.get("chapters", {})
    var region_ids: Array = regions.keys()
    var centers: Dictionary = {}
    var current_id := String(config.get("id", ""))
    var titles: Dictionary = {}
    for index in range(region_ids.size()):
        var region_id := String(region_ids[index])
        centers[region_id] = Vector2(145 + (index % 3) * 290, 185 + (index / 3) * 165)
        var region_config := _load_json(WORLD_ROUTES_SCRIPT.config_path(region_id))
        titles[region_id] = String(region_config.get("chapter_name", region_config.get("name", region_id)))
    var drawn: Dictionary = {}
    for region_id_value in region_ids:
        var region_id := String(region_id_value)
        for data in regions[region_id].get("portals", []):
            var target := String(data.get("target_config_id", ""))
            if target == region_id or not centers.has(target):
                continue
            var key := region_id + ":" + target if region_id < target else target + ":" + region_id
            if drawn.has(key):
                continue
            var source_seen: bool = world_state.data.regions.has(region_id) or current_id == region_id
            var target_seen: bool = world_state.data.regions.has(target) or current_id == target
            if not source_seen and not target_seen:
                continue
            drawn[key] = true
            var line := Line2D.new()
            line.width = 3.0
            line.default_color = Color(0.35, 0.82, 0.90) if _world_portal_missing(data).is_empty() else Color(0.88, 0.63, 0.30)
            line.add_point(centers[region_id])
            line.add_point(centers[target])
            map_draw_root.add_child(line)
    for region_id_value in region_ids:
        var region_id := String(region_id_value)
        var center: Vector2 = centers[region_id]
        var known: bool = world_state.data.regions.has(region_id) or current_id == region_id
        var fill := Color(0.07, 0.18, 0.17) if known else Color(0.045, 0.055, 0.065)
        var border := Color(0.80, 1.0, 0.88) if region_id == current_id else Color(0.27, 0.48, 0.47)
        _add_map_ui_rect("WorldRegion_" + region_id, center - Vector2(104, 40), Vector2(208, 80), fill, border, 3.0 if region_id == current_id else 1.5)
        var label := Label.new()
        label.position = center - Vector2(98, 32)
        label.size = Vector2(196, 65)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 17)
        var explored: int = world_state.get_region(region_id).get("visited_rooms", {}).size()
        label.text = String(titles[region_id]) + ("\n探索 %d 室" % explored if known else "\n尚未踏足")
        map_draw_root.add_child(label)
    map_text.text = "倒扣巨钟 · 互联世界\n蓝线：当前可用通路  ·  金线：尚有门槛  ·  仅显示已踏足区域的相邻通路\n" + _world_exploration_hint() + "\nTab 区域地图 · M / Esc 返回旅途"


func _build_new_journey_dialog() -> void:
    new_journey_dialog = ConfirmationDialog.new()
    new_journey_dialog.title = "重新开始巡礼"
    new_journey_dialog.dialog_text = "是否从苔钟庭开始新的旅途？当前归途记录会保留为上一段旅途的备份。"
    new_journey_dialog.ok_button_text = "开始新旅途"
    new_journey_dialog.cancel_button_text = "继续当前旅途"
    add_child(new_journey_dialog)
    new_journey_dialog.confirmed.connect(_start_new_journey)
    new_journey_dialog.canceled.connect(func():
        active_overlay = ""
        _sync_ui_input_lock())


func _start_new_journey() -> void:
    if FileAccess.file_exists(world_save_path):
        var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(world_save_path), ProjectSettings.globalize_path(world_save_path + ".previous"))
        if backup_error != OK:
            _toast("旧旅途无法备份，当前记录已保留。")
            active_overlay = ""
            _sync_ui_input_lock()
            return
        DirAccess.remove_absolute(ProjectSettings.globalize_path(world_save_path))
    # Keep the old scene's shared snapshot valid until it has left the tree.
    world_state = WORLD_STATE_SCRIPT.new()
    world_loading = true
    _travel_world(DEFAULT_CONFIG_PATH, _vec2(_load_json(DEFAULT_CONFIG_PATH).get("player_start", [120, 500])))


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _art_theme_id() -> String:
    var theme_id := String(config.get("art_theme", ""))
    if not theme_id.is_empty():
        if theme_id == "moss_bell":
            return "moss_cavern"
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


## 钟龛 rest 音六区变体（音频规格 §2.1 摇篮曲/§4.5 ui_shrine_rest）。
func _shrine_rest_audio_key() -> String:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return "shrine_rest_ch02"
    if theme == "salt_archive":
        return "shrine_rest_ch03"
    if theme == "string_greenhouse":
        return "shrine_rest_ch04"
    if theme == "obsidian_pilgrim":
        return "shrine_rest_ch05"
    if theme == "silent_crown":
        return "shrine_rest_ch06"
    return "shrine_rest_ch01"


## 敌人死亡材质音（音频规格 §4.3 六材质）：按章节 art theme 选择。
func _enemy_death_sfx_key() -> String:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return "death_copper"
    if theme == "salt_archive":
        return "death_salt"
    if theme == "string_greenhouse":
        return "death_fiber"
    if theme == "obsidian_pilgrim":
        return "death_obsidian"
    if theme == "silent_crown":
        return "death_silent"
    return "death_moss"


func _original_map_art() -> Dictionary:
    var root := "res://assets/sprites/flat_maps/" + _art_theme_id() + "/"
    return {"map":root+"background.png","sky":root+"background.png","mid_tile":root+"platform_00.tres"}

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
    return String(_original_map_art().get("map", ""))


func _theme_map_art_modulate() -> Color:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return Color(0.72, 0.90, 0.96, 0.48)
    if theme == "salt_archive":
        return Color(0.92, 0.86, 0.70, 0.48)
    if theme == "string_greenhouse":
        return Color(0.62, 0.88, 0.66, 0.48)
    if theme == "obsidian_pilgrim":
        return Color(0.92, 0.56, 0.40, 0.46)
    if theme == "silent_crown":
        return Color(0.76, 0.80, 1.0, 0.46)
    return Color(0.66, 0.82, 0.72, 0.48)


func _theme_asset_source() -> String:
    return "Original hand-drawn 2D PNG atlases / built-in image_gen"


func _theme_uses_industrial_tiles() -> bool:
    return _art_theme_id() == "rain_foundry"


func _theme_uses_kenney_deluxe() -> bool:
    var theme := _art_theme_id()
    return theme == "string_greenhouse" or theme == "obsidian_pilgrim" or theme == "silent_crown"


func _background_visual_asset_paths() -> Array:
    var root := "res://assets/sprites/flat_maps/"+_art_theme_id()+"/"
    return [root+"background.png",root+"decor_atlas.png"]

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


func _platform_visual_asset_paths_for_material(_material: String) -> Array:
    var root := "res://assets/sprites/flat_maps/"+_art_theme_id()+"/"
    return [root+"platform_atlas.png",root+"terrain_atlas.png"]

func _combat_progression_enabled() -> bool:
    return String(config.get("progression_mode", "keys")).to_lower() == "combat_clear"


func _combat_goal_met() -> bool:
    return enemy_total <= 0 or enemy_defeated >= enemy_total


func _shortcut_ids() -> Array:
    var ids: Array = []
    for connection in config.get("connections", []):
        if not (connection is Dictionary):
            continue
        if String(connection.get("type", "")) != "shortcut":
            continue
        var shortcut_id := String(connection.get("shortcut_id", ""))
        if shortcut_id.is_empty() or ids.has(shortcut_id):
            continue
        ids.append(shortcut_id)
    return ids


func _shortcut_total() -> int:
    return _shortcut_ids().size()


func _opened_shortcut_total() -> int:
    return opened_shortcuts.size()


func _shortcut_id_for_area(area: Area2D) -> String:
    if area == null:
        return ""
    return String(area.get_meta("shortcut_id", ""))


func _is_shortcut_open(shortcut_id: String = "") -> bool:
    if shortcut_id.is_empty():
        return shortcut_open
    return opened_shortcuts.has(shortcut_id)


func _init_inventory_state() -> void:
    inventory_counts.clear()
    inventory_tools.clear()
    inventory_relics.clear()
    inventory_materials.clear()
    currency_count = 0
    unlocked_abilities.clear()
    opened_shortcuts.clear()
    shortcut_open = false
    visited_rooms.clear()
    current_room_id = ""
    var inventory_config: Dictionary = config.get("inventory", {})
    for item_id in inventory_config.get("starting_tools", []):
        if world_mode and WORLD_ABILITIES.has(String(item_id)):
            continue
        _add_inventory_item(String(item_id), 1, false)
    for item_id in inventory_config.get("starting_relics", []):
        _add_inventory_item(String(item_id), 1, false)
    if carried_inventory_enabled:
        _merge_carried_inventory()


# 跨章并集合并：starting_tools 先落底，再把携带背包中缺口补齐（按 max 计数，
# 不重复叠加同名工具）。走 _add_inventory_item 以保持 Tools/Relics/Materials
# 分类簿记与 testimony 链 flag 刷新一致；合并发生在 _spawn_player →
# _refresh_ability_gates → _sync_player_abilities 之前，因此"ch2 拿
# silk_wall_grip → 回 ch1 开 gate_wall_mossgrip"的数据链路直接成立。
func _merge_carried_inventory() -> void:
    for item_id_value in carried_inventory_counts.keys():
        var item_id := String(item_id_value)
        if item_id.is_empty():
            continue
        var missing := int(carried_inventory_counts[item_id_value]) - int(inventory_counts.get(item_id, 0))
        if missing > 0:
            _add_inventory_item(item_id, missing, false)
    if carried_currency > 0:
        _add_currency(carried_currency)


func _item_data(item_id: String) -> Dictionary:
    var inventory_config: Dictionary = config.get("inventory", {})
    var catalog: Dictionary = inventory_config.get("catalog", {})
    if world_mode and not catalog.has(item_id) and world_catalog.has(item_id):
        return world_catalog[item_id]
    return catalog.get(item_id, {"name": item_id, "category": "Materials", "description": ""})


# 展示层口径（圣典 §7）：铭文表优先于各章 catalog；catalog 只负责 category
# 与圣典未收录物品（功能道具/章节变体）的功能短句，避免六章重复维护铭文。
func _item_display_name(item_id: String) -> String:
    var lore_entry: Dictionary = item_lore.get(item_id, {})
    if lore_entry.has("display_name"):
        return String(lore_entry.get("display_name", item_id))
    var catalog: Dictionary = config.get("inventory", {}).get("catalog", {})
    if catalog.has(item_id):
        var entry: Dictionary = catalog.get(item_id, {})
        if entry.has("name"):
            return String(entry.get("name", item_id.capitalize()))
    # 跨章携带兜底：本章 catalog 没有该物品时退回圣典名，最后才退回旧表/原始 id。
    if world_mode and world_catalog.has(item_id):
        return String(world_catalog[item_id].get("name", item_id))
    if lore_entry.has("canon_name"):
        return String(lore_entry.get("canon_name", item_id))
    var display: Dictionary = ITEM_DISPLAY.get(item_id, {})
    return String(display.get("name", item_id.capitalize()))


# 圣典铭文多行保留分行；功能性物品先铭文后功能行（【功能】…）。
func _item_display_description(item_id: String) -> String:
    var lore_entry: Dictionary = item_lore.get(item_id, {})
    var parts: Array[String] = []
    for lore_line in lore_entry.get("lore", []):
        parts.append(String(lore_line))
    if not parts.is_empty():
        var function_line := String(lore_entry.get("function", ""))
        if not function_line.is_empty():
            parts.append(function_line)
        return "\n".join(parts)
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
    if world_mode:
        return _world_exploration_hint() + "  M 地图 / Tab 世界图 · F9 新旅途。"
    if bool(config.get("boss_route_via_exploration",false)):
        return "第%d章 %s：探索洞道，接通捷径，挑战守门者。F 呼叫升降笼。" % [int(current_campaign_chapter.get("index",1)),String(config.get("chapter_name",config.get("name","")))]
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
    if item_id.begins_with("testimony_"):
        _refresh_testimony_chain_flag()
    if announce:
        _toast("收入行囊 · " + _item_display_name(item_id))
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
    _ensure_audio_buses()
    _apply_chapter_reverb(String(config.get("id", "")))
    # AudioDirector 一期：不注册 autoload，由本函数实例化挂树（headless 验证脚本
    # 不跑主场景时 instance 保持 null，各薄封装回退旧行为）。
    audio_director = AUDIO_DIRECTOR_SCRIPT.new()
    audio_director.name = "AudioDirector"
    audio_director.autoplay_enabled = _should_autoplay_audio()
    add_child(audio_director)
    if _should_autoplay_audio():
        # 探索播放器仍叫 BgmPlayer、挂本节点、bus=BGM（audio_visual_validation 口径）。
        _ensure_bgm_player()
        audio_director.attach_explore_player(bgm_player)
    audio_director.set_chapter(String(config.get("id", "")))


## 音频设置面板开关键（V）：玩家基础键位由 player_controller 注册，这里只补自己的。
func _bind_audio_settings_key() -> void:
    if not InputMap.has_action("audio_settings"):
        InputMap.add_action("audio_settings")
    if InputMap.action_get_events("audio_settings").is_empty():
        var event := InputEventKey.new()
        event.physical_keycode = KEY_V
        InputMap.action_add_event("audio_settings", event)


## P0 总线保障（规格 §5.1）：default_bus_layout.tres 缺失或加载失败时动态补建。
## 幂等：章节切换重建场景时只补缺，并清理上一场景遗留的濒死低通 / duck 音量。
func _ensure_audio_buses() -> void:
    for bus_name in AUDIO_BUSES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()
            var new_index := AudioServer.bus_count - 1
            AudioServer.set_bus_name(new_index, bus_name)
            AudioServer.set_bus_send(new_index, "Master")
        var bus_index := AudioServer.get_bus_index(bus_name)
        AudioServer.set_bus_volume_db(bus_index, float(AUDIO_BUS_DEFAULT_VOLUME_DB.get(bus_name, 0.0)))
    for reverb_bus_name in ["SFX", "Ambience"]:
        var reverb_bus := AudioServer.get_bus_index(reverb_bus_name)
        if reverb_bus != -1 and _find_bus_effect(reverb_bus, "AudioEffectReverb") == -1:
            AudioServer.add_bus_effect(reverb_bus, AudioEffectReverb.new())
    low_hp_audio_active = false
    var bgm_bus := AudioServer.get_bus_index("BGM")
    if bgm_bus != -1:
        var stale_lowpass := _find_bus_effect(bgm_bus, "AudioEffectLowPassFilter")
        if stale_lowpass != -1:
            AudioServer.remove_bus_effect(bgm_bus, stale_lowpass)
    # 子总线（MusicExplore/MusicCombat/MusicStinger/SFX*/ReverbZone）转调 director 幂等补建。
    AUDIO_DIRECTOR_SCRIPT.ensure_sub_buses()


func _find_bus_effect(bus_index: int, effect_class: String) -> int:
    for effect_index in AudioServer.get_bus_effect_count(bus_index):
        var effect := AudioServer.get_bus_effect(bus_index, effect_index)
        if effect != null and effect.get_class() == effect_class:
            return effect_index
    return -1


## 区域混响（规格 §5.2）：章节加载时按海拔档把 SFX/Ambience 总线的混响调到位。
func _apply_chapter_reverb(chapter_id: String) -> void:
    var tier_key := String(CHAPTER_REVERB_TIER.get(chapter_id, "L+1"))
    var params: Dictionary = REVERB_TIERS.get(tier_key, {})
    if params.is_empty():
        return
    for bus_name in ["SFX", "Ambience"]:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index == -1:
            continue
        var effect_index := _find_bus_effect(bus_index, "AudioEffectReverb")
        if effect_index == -1:
            continue
        var reverb := AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectReverb
        if reverb == null:
            continue
        reverb.room_size = float(params.get("room_size", 0.6))
        reverb.damping = float(params.get("damping", 0.5))
        reverb.wet = float(params.get("wet", 0.25))
        reverb.predelay_msec = float(params.get("predelay_msec", 20.0))
        if params.has("predelay_feedback"):
            reverb.predelay_feedback = float(params.get("predelay_feedback", 0.0))


## 战斗/演出 ducking（规格 §5.3）：BGM 总线压低 duck_db dB，保持 seconds 秒后回弹。
## AudioDirector 在场时转调（回弹基准含用户音量），缺席时保持旧行为。
## headless 下 AudioServer 照常可写、tween 随场景销毁，安全 no-op。
func duck_bgm(duck_db: float, seconds: float) -> void:
    var director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if director != null and director.is_inside_tree():
        director.duck(duck_db, seconds)
        return
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1 or not is_inside_tree():
        return
    if bgm_duck_tween != null and bgm_duck_tween.is_valid():
        bgm_duck_tween.kill()
    var base_db := float(AUDIO_BUS_DEFAULT_VOLUME_DB.get("BGM", 0.0))
    var ducked_db := base_db + minf(duck_db, 0.0)
    bgm_duck_tween = create_tween()
    bgm_duck_tween.tween_method(_set_bgm_bus_volume_db, AudioServer.get_bus_volume_db(bus_index), ducked_db, 0.35)
    bgm_duck_tween.tween_interval(maxf(seconds, 0.0))
    bgm_duck_tween.tween_method(_set_bgm_bus_volume_db, ducked_db, base_db, 0.6)


func _set_bgm_bus_volume_db(value: float) -> void:
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index != -1:
        AudioServer.set_bus_volume_db(bus_index, value)


## 濒死混音态（规格 §5.5）：HP==1 时 BGM 总线挂 800Hz 低通 + 55-60 BPM 心跳
## 循环（自产 player_low_hp_heartbeat.wav，不与音乐 BPM 同步）；HP 回升/死亡移除。
func _set_low_hp_audio(active: bool) -> void:
    if active == low_hp_audio_active:
        return
    low_hp_audio_active = active
    if active:
        _start_low_hp_heartbeat()
    else:
        _stop_low_hp_heartbeat()
    # AudioDirector 在场时低通改扫频版（2kHz→800Hz 2s；关断当帧摘除），缺席回退旧行为。
    var director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if director != null:
        director.set_low_hp(active)
        return
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1:
        return
    var effect_index := _find_bus_effect(bus_index, "AudioEffectLowPassFilter")
    if active and effect_index == -1:
        var lowpass := AudioEffectLowPassFilter.new()
        lowpass.cutoff_hz = LOW_HP_LOWPASS_CUTOFF_HZ
        AudioServer.add_bus_effect(bus_index, lowpass)
    elif not active and effect_index != -1:
        AudioServer.remove_bus_effect(bus_index, effect_index)


func _start_low_hp_heartbeat() -> void:
    if not _should_autoplay_audio():
        return
    if low_hp_heartbeat_player == null or not is_instance_valid(low_hp_heartbeat_player):
        # 循环标记由 load_cached(looped=true) 在入缓存前置好，不再原地改流。
        var stream := AUDIO_DIRECTOR_SCRIPT.load_cached(String(AUDIO.get("low_hp_heartbeat", "")), true)
        if stream == null:
            return
        low_hp_heartbeat_player = AudioStreamPlayer.new()
        low_hp_heartbeat_player.name = "LowHpHeartbeat"
        # 濒死心跳走 SFXDry（send→Master 干声）：不吃章节混响，贴耳而非贴房间。
        low_hp_heartbeat_player.bus = _first_existing_bus(["SFXDry", "SFX", "Master"])
        low_hp_heartbeat_player.stream = stream
        low_hp_heartbeat_player.volume_db = -10.0
        add_child(low_hp_heartbeat_player)
    if not low_hp_heartbeat_player.playing:
        low_hp_heartbeat_player.play()


func _first_existing_bus(bus_names: Array) -> String:
    for bus_name in bus_names:
        if AudioServer.get_bus_index(String(bus_name)) != -1:
            return String(bus_name)
    return "Master"


func _stop_low_hp_heartbeat() -> void:
    if low_hp_heartbeat_player != null and is_instance_valid(low_hp_heartbeat_player) and low_hp_heartbeat_player.playing:
        low_hp_heartbeat_player.stop()


func _should_autoplay_audio() -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


## 旧版单播放器 BGM 切换：仅作 AudioDirector 缺席时的兜底路径。
## 无缝循环由 load_cached(looped=true) 承担；缓存对同路径返回同一对象，
## 因此下方 stream 同一性比较的"同曲去重"再次生效（不重头重播）。
func _switch_bgm(audio_key: String) -> void:
    var stream := AUDIO_DIRECTOR_SCRIPT.load_cached(String(AUDIO.get(audio_key, "")), true)
    if stream == null:
        return
    _ensure_bgm_player()
    if bgm_player.stream == stream and bgm_player.playing:
        return
    bgm_player.stream = stream
    bgm_player.play()


func _ensure_bgm_player() -> void:
    if bgm_player != null and is_instance_valid(bgm_player):
        return
    bgm_player = AudioStreamPlayer.new()
    bgm_player.name = "BgmPlayer"
    bgm_player.bus = "BGM" if AudioServer.get_bus_index("BGM") != -1 else "Master"
    bgm_player.volume_db = -18.0
    add_child(bgm_player)


func _play_sfx(audio_key: String, volume_db: float = -7.0) -> void:
    if not _should_autoplay_audio():
        return
    # 声部管理（规格 §5.4）：同 key 限频/并发 + 全局 24 声部，被拒即不播。
    if not AUDIO_DIRECTOR_SCRIPT.request_voice(audio_key):
        return
    var stream := _load_audio_stream(audio_key)
    if stream == null:
        # 声部回滚（契约 release_voice）：拿不到流就撤销刚批准的登记。
        AUDIO_DIRECTOR_SCRIPT.release_voice(audio_key)
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "Sfx_" + audio_key
    player_node.bus = _sfx_bus_for_key(audio_key)
    player_node.stream = stream
    player_node.volume_db = volume_db
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


## UI 音走 UI 总线（干声），世界音走 SFXWorld 子总线（send→SFX 吃章节混响）。
func _sfx_bus_for_key(audio_key: String) -> String:
    if audio_key.begins_with("ui_"):
        if AudioServer.get_bus_index("UI") != -1:
            return "UI"
    elif AudioServer.get_bus_index("SFXWorld") != -1:
        return "SFXWorld"
    return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


func _load_audio_stream(audio_key: String) -> AudioStream:
    # 统一走 AudioDirector 静态流缓存（契约 load_cached：直读 + 负缓存 + 告警一次）。
    return AUDIO_DIRECTOR_SCRIPT.load_cached(String(AUDIO.get(audio_key, "")))


## 场景切换不截断的一次性音（章节切换线音）：播放器挂 tree root，播完自毁。
func _play_sfx_persistent(audio_key: String, volume_db: float = -7.0) -> void:
    if not _should_autoplay_audio():
        return
    if not AUDIO_DIRECTOR_SCRIPT.request_voice(audio_key):
        return
    var stream := _load_audio_stream(audio_key)
    if stream == null or not is_inside_tree():
        # 声部回滚（契约 release_voice）：拿不到流/不在树上都不会真正发声。
        AUDIO_DIRECTOR_SCRIPT.release_voice(audio_key)
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "PersistentSfx_" + audio_key
    player_node.bus = _sfx_bus_for_key(audio_key)
    player_node.stream = stream
    player_node.volume_db = volume_db
    get_tree().root.add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


## 同事件多变体随机轮播（Kenney 变体组用）。
func _play_sfx_random(audio_keys: Array, volume_db: float = -7.0) -> void:
    if audio_keys.is_empty():
        return
    _play_sfx(String(audio_keys[randi() % audio_keys.size()]), volume_db)


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
    backpack_panel=ui_shell.bag
    backpack_text=ui_shell.legacy_bag_text
    backpack_detail_text=ui_shell.legacy_bag_detail
    _refresh_backpack_overlay()

func _build_map_overlay() -> void:
    map_panel = ColorRect.new()
    map_panel.name = "CourtMapOverlay"
    map_panel.position = Vector2(52, 54)
    map_panel.size = Vector2(1176, 640)
    map_panel.color = Color(0.012, 0.015, 0.018, 0.97)
    map_panel.visible = false
    ui_shell.add_child(map_panel)

    var map_art := TextureRect.new()
    map_art.name = "MapBackgroundArt"
    map_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    map_art.texture = _load_texture_resource(_theme_map_background_texture())
    map_art.position = Vector2.ZERO
    map_art.size = map_panel.size
    map_art.stretch_mode = TextureRect.STRETCH_SCALE
    map_art.modulate = Color(1,1,1,.07)
    map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_panel.add_child(map_art)

    var title := Label.new()
    title.text = _theme_map_title()
    title.position = Vector2(28, 18)
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color("b5a17c"))
    map_panel.add_child(title)
    ui_shell._button(map_panel,"返回",Vector2(1080,18),Vector2(62,34),func():_close_overlays())

    map_draw_root = Control.new()
    map_draw_root.name = "MapDrawRoot"
    map_draw_root.position = Vector2(34, 72)
    map_draw_root.size = Vector2(1108, 430)
    map_panel.add_child(map_draw_root)

    map_text = Label.new()
    map_text.position = Vector2(34, 514)
    map_text.size = Vector2(1108, 110)
    map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    map_text.add_theme_font_size_override("font_size", 14)
    map_text.add_theme_color_override("font_color", Color(0.86, 0.90, 0.84))
    map_panel.add_child(map_text)
    _build_wish_board_overlay()
    _refresh_map_overlay()


# 巡礼愿板最小闭环（任务设计文档 §3 schema 子集）。章节配置可选 "wish_board"
# 数组：{id, title, desc, kind, target_flag, reward_currency}。target_flag 在
# story_flags 中翻转即视为完成，完成时经 _add_currency 发奖一次并记
# wish_claimed_<id> flag（随 story_flags 跨章携带，不重复发奖）。
# 没有该字段的章节不建面板、不做任何检查，行为完全不变。
func _wish_board_entries() -> Array:
    var entries: Array = []
    for wish in config.get("wish_board", []):
        if wish is Dictionary and not String((wish as Dictionary).get("id", "")).is_empty():
            entries.append(wish)
    for npc in config.get("npcs",[]):
        var topics: Dictionary=npc.get("dialogue_topics",{})
        var quest: Dictionary=topics.get("quest",{})
        if not quest.is_empty():
            entries.append({"id":"npc_"+String(npc.id),"title":_npc_display_name(npc)+"的心愿","desc":topics.get("wish",""),"kind":"心愿","target_flag":quest.get("complete_flag",""),"reward_currency":0})
    return entries


func _build_wish_board_overlay() -> void:
    if map_panel == null or _wish_board_entries().is_empty():
        return
    wish_panel = ColorRect.new()
    wish_panel.name = "WishBoardPanel"
    wish_panel.position = Vector2(826, 72)
    wish_panel.size = Vector2(316, 430)
    wish_panel.color = Color(0.035, 0.045, 0.05, 0.93)
    map_panel.add_child(wish_panel)

    var title := Label.new()
    title.text = "巡礼愿板"
    title.position = Vector2(16, 12)
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42))
    wish_panel.add_child(title)

    wish_text = Label.new()
    wish_text.position = Vector2(16, 48)
    wish_text.size = Vector2(284, 366)
    wish_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wish_text.add_theme_font_size_override("font_size", 13)
    wish_text.add_theme_color_override("font_color", Color(0.86, 0.91, 0.84))
    wish_panel.add_child(wish_text)
    _refresh_wish_board_overlay()


func _wish_completed(wish: Dictionary) -> bool:
    var target_flag := String(wish.get("target_flag", ""))
    return not target_flag.is_empty() and bool(story_flags.get(target_flag, false))


func _wish_claim_flag(wish: Dictionary) -> String:
    return "wish_claimed_%s" % String(wish.get("id", ""))


func _check_wish_board_rewards() -> void:
    for wish_value in _wish_board_entries():
        var wish: Dictionary = wish_value
        if not _wish_completed(wish):
            continue
        var claim_flag := _wish_claim_flag(wish)
        if bool(story_flags.get(claim_flag, false)):
            continue
        # 直接写 flag（不走 _set_story_flag）避免奖励检查递归。
        story_flags[claim_flag] = true
        var reward := int(wish.get("reward_currency", 0))
        if reward > 0:
            _add_currency(reward)
        if reward==0:
            _toast("心愿达成 · "+String(wish.get("title",wish.get("id",""))))
            continue
        _toast("愿望达成：%s（+%d %s）" % [
            String(wish.get("title", wish.get("id", ""))),
            reward,
            _item_display_name("currency")
        ])
    _refresh_wish_board_overlay()


func _refresh_wish_board_overlay() -> void:
    if wish_text == null:
        return
    var lines: Array[String] = []
    for wish_value in _wish_board_entries():
        var wish: Dictionary = wish_value
        var done := _wish_completed(wish)
        lines.append("%s [%s] %s" % [
            "已了" if done else "未了",
            String(wish.get("kind", "wish")),
            String(wish.get("title", wish.get("id", "")))
        ])
        var desc := String(wish.get("desc", ""))
        if not desc.is_empty():
            lines.append("    " + desc)
    wish_text.text = "\n".join(lines)


func _toggle_backpack() -> void:
    if active_overlay == "backpack":
        _close_overlays()
        return
    _play_sfx("ui_inventory_open", -2.0)
    _notify_dialogue_closed()
    active_overlay = "backpack"
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = false
    if backpack_panel != null:
        backpack_panel.visible = true
    _sync_ui_input_lock()
    _refresh_backpack_overlay()


func _toggle_map() -> void:
    if active_overlay == "map":
        _close_overlays()
        return
    _play_sfx("ui_map_open", -2.0)
    _notify_dialogue_closed()
    active_overlay = "map"
    if backpack_panel != null:
        backpack_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = false
    if map_panel != null:
        map_panel.visible = true
    _sync_ui_input_lock()
    _update_room_visit()
    _refresh_map_overlay()


# ---- 音频设置覆盖层（音量四滑条，复用背包面板构建模式）----

func _build_settings_overlay() -> void:
    settings_panel=ui_shell.settings
    settings_text=ui_shell.legacy_settings
    _refresh_settings_overlay()

func _toggle_audio_settings() -> void:
    if active_overlay == "settings":
        _close_overlays()
        return
    _play_sfx("ui_menu_confirm", -2.0)
    _notify_dialogue_closed()
    active_overlay = "settings"
    if backpack_panel != null:
        backpack_panel.visible = false
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = true
    _sync_ui_input_lock()
    _refresh_settings_overlay()


func _settings_selection_clamped() -> int:
    return clampi(settings_selection, 0, AUDIO_SETTINGS_ROWS.size() - 1)


func _move_settings_selection(delta: int) -> void:
    _play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    settings_selection = wrapi(_settings_selection_clamped() + delta, 0, AUDIO_SETTINGS_ROWS.size())
    _refresh_settings_overlay()


func _adjust_settings_volume(delta: float) -> void:
    if audio_director == null:
        return
    var which := String(AUDIO_SETTINGS_ROWS[_settings_selection_clamped()][0])
    var value: float = clampf(float(audio_director.get_user_volume(which)) + delta, 0.0, 100.0)
    audio_director.set_user_volume(which, value)
    if which == "sfx":
        # SFX 行试听反馈改播世界音（走 SFXWorld→SFX 总线）：调的就是它，所听即所调。
        _play_sfx("pickup")
    else:
        _play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    _refresh_settings_overlay()


func _refresh_settings_overlay() -> void:
    if settings_text == null:
        return
    var lines: Array[String] = []
    for index in AUDIO_SETTINGS_ROWS.size():
        var row: Array = AUDIO_SETTINGS_ROWS[index]
        var percent := 100.0
        if audio_director != null:
            percent = float(audio_director.get_user_volume(String(row[0])))
        var filled := clampi(int(round(percent / 10.0)), 0, 10)
        var bar := "█".repeat(filled) + "░".repeat(10 - filled)
        var marker := "▶ " if index == _settings_selection_clamped() else "  "
        lines.append("%s%s  [%s] %d%%" % [marker, String(row[1]), bar, int(round(percent))])
    lines.append("")
    lines.append("W/S 选择   A/D 调节   V/Esc 关闭")
    settings_text.text = "\n".join(lines)
    if ui_shell != null:
        ui_shell.refresh_settings_selection()


func _close_overlays() -> void:
    # UI 关闭音（音频规格 §4.5）：按正在关的 overlay 选音，空关不发声。
    if active_overlay == "backpack":
        _play_sfx("ui_inventory_close", -3.0)
    elif active_overlay == "map":
        _play_sfx("ui_map_close", -3.0)
    elif active_overlay == "dialogue":
        _play_sfx("ui_dialogue_close", -4.0)
    elif active_overlay == "settings":
        _play_sfx("ui_menu_cancel", -4.0)
    _notify_dialogue_closed()
    active_overlay = ""
    if backpack_panel != null:
        backpack_panel.visible = false
    if map_panel != null:
        map_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = false
    _sync_ui_input_lock()


## 玩家输入闸（契约 ui_input_locked）：任一 overlay 开合即同步，锁移动/瞄准
## 不锁 Esc/UI 键；player_controller 侧按该标志忽略 move_left/right 与 aim_up/down。
func _sync_ui_input_lock() -> void:
    if player != null and is_instance_valid(player):
        player.set("ui_input_locked", active_overlay != "")
    if is_inside_tree():
        for actor in get_tree().get_nodes_in_group("enemy"):
            if actor.has_method("_set_combat_visuals_paused"):
                actor._set_combat_visuals_paused(active_overlay != "")


## 对话面板关闭时归还 BGM/Ambience 压低（所有关闭路径共用：Esc、走远、切换 overlay）。
func _notify_dialogue_closed() -> void:
    _commit_world_dialogue()
    if ui_shell!=null:
        ui_shell.close_dialogue()
    if active_overlay == "dialogue" and audio_director != null:
        audio_director.on_dialogue(false)


# 背包分区顺序：印记/证词等剧情要物靠前，材料殿后；分区标题仅作视觉分组。
const BACKPACK_SECTIONS := [
    ["工具 Tools", "Tools"],
    ["能力 Abilities", "Abilities"],
    ["护符 Charms", "Charms"],
    ["升级 Upgrades", "Upgrades"],
    ["圣物 Relics", "Relics"],
    ["印记与要物 Quest", "Quest"],
    ["材料 Materials", "Materials"]
]


func _refresh_backpack_overlay() -> void:
    if backpack_text == null:
        return
    backpack_entry_ids.clear()
    var lines: Array[String] = []
    backpack_entry_ids.append("currency")
    lines.append("%s%s x%d" % [_selection_marker("currency"), _item_display_name("currency"), currency_count])
    if not _combat_progression_enabled():
        lines.append("")
        lines.append("Route Marks")
        lines.append(_inventory_line_for_category("Combat"))
    for section in BACKPACK_SECTIONS:
        var section_ids := _inventory_ids_for_category(String(section[1]))
        if section_ids.is_empty():
            continue
        lines.append("")
        lines.append(String(section[0]))
        for item_id in section_ids:
            backpack_entry_ids.append(item_id)
            var count := int(inventory_counts.get(item_id, 0))
            var count_suffix := " x%d" % count if count > 1 else ""
            lines.append("%s%s%s" % [_selection_marker(item_id), _item_display_name(item_id), count_suffix])
    lines.append("")
    lines.append("Tab/I 背包   W/S 查看铭文   M 地图   Esc 关闭")
    backpack_text.text = "\n".join(lines)
    _refresh_backpack_detail()
    if ui_shell!=null:
        ui_shell.refresh_inventory()


func _inventory_ids_for_category(category: String) -> Array[String]:
    var ids: Array[String] = []
    for item_id in inventory_counts.keys():
        var data := _item_data(String(item_id))
        if String(data.get("category", "")) == category:
            ids.append(String(item_id))
    return ids


func _selection_marker(item_id: String) -> String:
    var index := backpack_entry_ids.find(item_id)
    return "▶ " if index == _backpack_selection_clamped() else "  "


func _backpack_selection_clamped() -> int:
    if backpack_entry_ids.is_empty():
        return -1
    return clampi(backpack_selection, 0, backpack_entry_ids.size() - 1)


func _move_backpack_selection(delta: int) -> void:
    if backpack_entry_ids.is_empty():
        return
    _play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    if ui_shell != null:
        ui_shell.move_inventory_selection(delta)
    else:
        backpack_selection = wrapi(_backpack_selection_clamped() + delta, 0, backpack_entry_ids.size())
    _refresh_backpack_overlay()


# 详情区：选中物品的完整铭文（多行保留分行；功能行随描述一起展示）。
func _refresh_backpack_detail() -> void:
    if backpack_detail_text == null:
        return
    var index := _backpack_selection_clamped()
    if index < 0:
        backpack_detail_text.text = ""
        return
    var item_id := backpack_entry_ids[index]
    var lines: Array[String] = []
    if item_id == "currency":
        lines.append("%s x%d" % [_item_display_name("currency"), currency_count])
    else:
        var count := int(inventory_counts.get(item_id, 0))
        lines.append(_item_display_name(item_id) + (" x%d" % count if count > 1 else ""))
    var description := _item_display_description(item_id)
    if not description.is_empty():
        lines.append("")
        for description_line in description.split("\n"):
            lines.append(description_line)
    backpack_detail_text.text = "\n".join(lines)


func _inventory_line_for_category(category: String) -> String:
    var entries: Array[String] = []
    for item_id in inventory_counts.keys():
        var data := _item_data(String(item_id))
        if String(data.get("category", "")) == category:
            entries.append("%s x%d" % [_item_display_name(String(item_id)), int(inventory_counts[item_id])])
    return "  None" if entries.is_empty() else "  " + ", ".join(entries)


func _update_room_visit() -> void:
    if player == null or not is_instance_valid(player):
        return
    var room := _room_for_position(player.global_position)
    if room.is_empty():
        return
    var previous_room_id := current_room_id
    current_room_id = String(room.get("id", ""))
    if not current_room_id.is_empty():
        visited_rooms[current_room_id] = true
        if metsys_bridge != null:
            metsys_bridge.update_player_position(player.global_position, current_room_id)
        if current_room_id != previous_room_id:
            _save_world()
            _trigger_whispers("enter_room", current_room_id)
            # 房型混响微调（规格 §5.2）：hub/vista 抬 wet、corridor/secret 收 wet。
            if audio_director != null:
                audio_director.on_room_changed(String(room.get("kind", "")))


func _room_for_x(world_x: float, legacy_only: bool = false) -> Dictionary:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if legacy_only and _room_has_position_bounds(room_data):
            continue
        var room_range: Array = room_data.get("range", [0.0, world_width])
        if room_range.size() < 2:
            continue
        if world_x >= float(room_range[0]) and world_x <= float(room_range[1]):
            return room_data
    return {}


func _room_for_position(world_position: Vector2) -> Dictionary:
    var best_room: Dictionary = {}
    var best_area := INF
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var area := _room_containing_area(room_data, world_position)
        if area < best_area:
            best_room = room_data
            best_area = area
    # A nested corridor or reward pocket takes precedence over its enclosing
    # hall. Only legacy rooms without authored 2D bounds may use x fallback.
    return best_room if not best_room.is_empty() else _room_for_x(world_position.x, true)


func _room_layout_rect(room_data: Dictionary) -> Rect2:
    var rect_value: Variant = room_data.get("layout_rect", room_data.get("play_rect", []))
    if typeof(rect_value) != TYPE_ARRAY or rect_value.size() < 4:
        return Rect2()
    return _rect2(rect_value)


func _room_map_rect(room_data: Dictionary) -> Rect2:
    var rect_value: Variant = room_data.get("map_rect", [])
    if typeof(rect_value) == TYPE_ARRAY and rect_value.size() >= 4:
        return _rect2(rect_value)
    return _room_layout_rect(room_data)


func _map_room_by_id(room_id: String) -> Dictionary:
    for room_value in config.get("map_rooms", []):
        if room_value is Dictionary and String(room_value.get("id", "")) == room_id:
            return room_value
    return {}


func _rect_contains_position(rect: Rect2, position_value: Vector2, padding: float = 0.0) -> bool:
    return (
        position_value.x >= rect.position.x - padding
        and position_value.x <= rect.position.x + rect.size.x + padding
        and position_value.y >= rect.position.y - padding
        and position_value.y <= rect.position.y + rect.size.y + padding
    )


func _room_contains_position(room_data: Dictionary, world_position: Vector2) -> bool:
    return _room_containing_area(room_data, world_position) < INF


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
    var draw_width := 760.0 if not _wish_board_entries().is_empty() else 1108.0
    var draw_size := Vector2(draw_width, 430.0)
    var base_y := 132.0
    var depth_step := 72.0
    var layout_bounds := _map_layout_bounds(rooms)
    var uses_layout := layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0
    if wish_panel != null:
        wish_panel.visible = not (world_mode and world_map_view)
    if world_mode and world_map_view:
        _draw_world_atlas()
        return
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
    if world_mode:
        _add_world_portal_map_pins(layout_bounds, draw_size, draw_width, base_y, depth_step)
    if player != null and is_instance_valid(player):
        if uses_layout:
            var player_room := _room_for_position(player.global_position)
            var player_pos := _map_room_world_position_to_overlay(player_room, player.global_position, layout_bounds, draw_size)
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
    if world_mode:
        objective = "找回被删去的名字，接通旧运书线。"
        guide = _world_exploration_hint()
        next_step = "金色出口待解锁；蓝色出口已接通 · Tab 世界图"
    map_text.text = "%s  ·  %s  ·  探索 %d/%d  ·  捷径 %d/%d\n目标  %s\n路线  %s  →  %s\n危险  %s\nM / Esc 返回  ·  F 与附近人物或机关互动" % [
        String(current_campaign_chapter.get("name", "Moss Bell Court")),
        _room_name(current_room_id),
        visited_rooms.size(),
        rooms.size(),
        _opened_shortcut_total(),
        _shortcut_total(),
        objective,
        guide,
        next_step,
        danger
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
        var rect := _room_map_rect(room)
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


func _map_room_world_position_to_overlay(room: Dictionary, world_position: Vector2, layout_bounds: Rect2, draw_size: Vector2) -> Vector2:
    if room.is_empty():
        return _map_world_to_overlay(world_position, layout_bounds, draw_size)
    var map_rect := _room_map_rect(room)
    var physical_rect := _room_layout_rect(room)
    if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
        return _map_world_to_overlay(world_position, layout_bounds, draw_size)
    var normalized := Vector2(0.5, 0.5)
    if physical_rect.size.x > 0.0 and physical_rect.size.y > 0.0:
        normalized.x = clampf((world_position.x - physical_rect.position.x) / physical_rect.size.x, 0.16, 0.84)
        normalized.y = clampf((world_position.y - physical_rect.position.y) / physical_rect.size.y, 0.20, 0.80)
    return _map_world_to_overlay(map_rect.position + map_rect.size * normalized, layout_bounds, draw_size)


func _map_room_overlay_rect(room_data: Dictionary, layout_bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> Rect2:
    var layout := _room_map_rect(room_data)
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
    for data in config.get("cave_lifts", []):
        for y in [float(data.top_y),float(data.bottom_y)]:
            _add_map_pin(Vector2(float(data.x),y),draw_width,base_y,depth_step,Color(.6,.8,.9,.95),Vector2(11,11),layout_bounds,draw_size)
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
        pin_pos = _map_room_world_position_to_overlay(room, world_position, layout_bounds, draw_size) - size_value * 0.5
    else:
        var depth := 0
        if not room.is_empty():
            depth = int(room.get("depth", 0))
        pin_pos = Vector2(clampf(world_position.x / world_width * draw_width, 0.0, draw_width) - size_value.x * 0.5, base_y + float(depth) * depth_step - 18.0)
    _add_map_ui_rect("MapPin", pin_pos, size_value + Vector2(5.0, 5.0), color, Color(1.0, 0.95, 0.72, 0.95), 2.0)


func _add_map_route_line(rooms: Array, draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
        var drew_connection := false
        for connection_value in config.get("connections", []):
            if not (connection_value is Dictionary):
                continue
            var connection: Dictionary = connection_value
            var from_room := _map_room_by_id(String(connection.get("from", "")))
            var to_room := _map_room_by_id(String(connection.get("to", "")))
            if from_room.is_empty() or to_room.is_empty():
                continue
            var from_rect := _room_map_rect(from_room)
            var to_rect := _room_map_rect(to_room)
            if from_rect.size.x <= 0.0 or to_rect.size.x <= 0.0:
                continue
            var edge := Line2D.new()
            var edge_kind := String(connection.get("edge_kind", connection.get("type", "passage")))
            edge.name = "MapEdge_" + String(connection.get("from", "")) + "_" + String(connection.get("to", ""))
            edge.width = 5.0 if edge_kind in ["unlock_shortcut", "ability_gate"] else 3.0
            edge.default_color = Color(0.91, 0.68, 0.28, 0.86) if edge_kind in ["unlock_shortcut", "ability_gate"] else (Color(0.38, 0.76, 0.96, 0.78) if edge_kind == "one_way_drop" else Color(0.33, 0.72, 0.58, 0.70))
            edge.z_index = 1
            edge.points = PackedVector2Array([
                _map_world_to_overlay(from_rect.position + from_rect.size * 0.5, layout_bounds, draw_size),
                _map_world_to_overlay(to_rect.position + to_rect.size * 0.5, layout_bounds, draw_size)
            ])
            map_draw_root.add_child(edge)
            drew_connection = true
        if drew_connection:
            return
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
        var layout := _room_map_rect(room_data)
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
            marker_position = _map_room_world_position_to_overlay(room, world_position, layout_bounds, draw_size)
        else:
            var depth := int(room.get("depth", 0)) if not room.is_empty() else 0
            marker_position = Vector2(clampf(world_position.x / world_width * draw_width, 0.0, draw_width), base_y + float(depth) * depth_step + 21.0)
        var marker_color := Color(1.0, 0.68, 0.24, 0.96) if interact_type == "boss_gate" else Color(0.45, 0.76, 1.0, 0.96)
        _add_map_ui_rect("MetSysPassage_" + interact_type, marker_position - Vector2(4.0, 17.0), Vector2(8.0, 34.0), marker_color, Color(1.0, 0.95, 0.72, 0.94), 2.0)


func _add_map_room_texture(rect_position: Vector2, rect_size: Vector2, visited: bool, current: bool) -> void:
    var texture := TextureRect.new()
    texture.name = "RoomOriginalTexture"
    texture.texture = _load_texture_resource(String(_original_map_art().get("mid_tile", "")))
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
    if world_mode:
        for data in config.get("grapple_anchors", []):
            _world_grapple_anchor(data)
    for data in config.get("cave_lifts", []):
        var lift := CAVE_LIFT_SCRIPT.new()
        add_child(lift)
        lift.configure(data,self)
        cave_lifts.append(lift)
    for block in config.get("environment_blocks", []):
        if block is Dictionary:
            _environment_block(block)
    for platform in config.get("platforms", []):
        if platform.has("terrain_id"):
            continue
        _platform(
            String(platform.get("id", "platform")),
            _rect2(platform.get("rect", [])),
            _color(platform.get("color", "333333")),
            String(platform.get("material", "moss_stone")),
            String(platform.get("collision_role", ""))
        )

    locked_gate_bodies.clear()
    for gate in config.get("locked_gates", []):
        var locked_gate := _platform(
            String(gate.get("id", "locked_gate")),
            _rect2(gate.get("rect", [])),
            _color(gate.get("color", "875f29")),
            String(gate.get("material", "bronze_bridge"))
        )
        locked_gate.set_meta("required_ability", String(gate.get("required_ability", "")))
        locked_gate.set_meta("required_ability_name", String(gate.get("required_ability_name", "")))
        locked_gate_bodies[String(gate.get("id", "locked_gate"))] = locked_gate

    for hazard in config.get("hazards", []):
        _hazard(hazard)
    hazard_total = config.get("hazards", []).size()

    if _combat_progression_enabled():
        collectible_total = 0
        for collectible in config.get("collectibles", []):
            if collectible is Dictionary and String(collectible.get("kind", "")) == "item":
                _collectible(collectible)
                collectible_total += 1
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
        elif kind == "world_portal":
            _world_portal(interactive)
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
        _open_all_shortcuts(false)

    # World labels are intentionally suppressed so tutorial copy does not cover the level art.


func _environment_block(data: Dictionary) -> void:
    if flat_map_art != null:
        flat_map_art.add_environment_ornament(data)

func _add_environment_block_texture(block_id: String, rect: Rect2, z_value: int, block_alpha: float) -> void:
    var art := _original_map_art()
    var texture_path := String(art.get("wall", ""))
    var texture := _load_texture_resource(texture_path)
    if texture == null:
        return
    var panel := Sprite2D.new()
    panel.name = block_id + "Texture"
    panel.texture = texture
    panel.centered = true
    panel.position = rect.position + rect.size * 0.5
    panel.scale = Vector2(rect.size.x / float(texture.get_width()), rect.size.y / float(texture.get_height()))
    panel.flip_h = block_id.hash() % 2 == 1
    panel.modulate = Color(0.88, 0.92, 0.90, 0.34 if block_alpha < 0.80 else 0.58)
    panel.z_index = z_value
    panel.set_meta("original_map_asset", texture_path)
    add_child(panel)


func _spawn_player() -> void:
    player = PLAYER_SCENE.instantiate()
    add_child(player)
    player.global_position = active_spawn
    player.set_spawn(active_spawn)
    player.hp_changed.connect(_on_hp_changed)
    player.energy_changed.connect(_on_energy_changed)
    player.player_respawned.connect(_on_player_respawned)
    # 材质化脚步（音频规格 §4.2）：按章节 art theme 指定脚步材质组。
    player.set("footstep_material", String(FOOTSTEP_MATERIAL_BY_THEME.get(_art_theme_id(), "moss")))
    _configure_player_camera()
    _refresh_ability_gates()


func _build_hud() -> void:
    ui_canvas=CanvasLayer.new()
    add_child(ui_canvas)
    ui_shell=PILGRIMAGE_UI_SCRIPT.new()
    ui_canvas.add_child(ui_shell)
    ui_shell.bind(self)
    hud_label=Label.new()
    hud_label.visible=false
    ui_shell.add_child(hud_label)
    toast_label=ui_shell.toast
    lore_banner_label=Label.new()
    lore_banner_label.position=Vector2(325,603)
    lore_banner_label.size=Vector2(620,54)
    lore_banner_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    lore_banner_label.add_theme_font_size_override("font_size",17)
    lore_banner_label.add_theme_color_override("font_color",Color("e8ddc3"))
    lore_banner_label.visible=false
    ui_shell.add_child(lore_banner_label)
    win_label=Label.new()
    win_label.position=Vector2(350,132)
    win_label.size=Vector2(600,60)
    win_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    win_label.add_theme_font_size_override("font_size",30)
    win_label.visible=false
    ui_shell.add_child(win_label)
    _build_backpack_overlay()
    _build_map_overlay()
    _build_dialogue_overlay()
    _build_settings_overlay()
    ui_shell.frame(map_panel)
    _check_wish_board_rewards()
    _refresh_hud()

func _build_dialogue_overlay() -> void:
    dialogue_panel=ui_shell.dialogue
    dialogue_name_label=ui_shell.dialogue_name
    dialogue_meta_label=ui_shell.dialogue_identity
    dialogue_text_label=ui_shell.dialogue_body
    dialogue_hint_label=ui_shell.dialogue_hint

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

    flat_map_art = FLAT_MAP_ART_SCRIPT.new()
    add_child(flat_map_art)
    flat_map_art.configure(_art_theme_id(),config)
    chapter_terrain = TERRAIN_SCRIPT.new()
    add_child(chapter_terrain)
    chapter_terrain.configure(config,_art_theme_id())
    if not config.get("cave_world", {}).is_empty():
        cave_world = CAVE_WORLD_SCRIPT.new()
        add_child(cave_world)
        cave_world.configure(config,_art_theme_id(),self)

    var shade := Polygon2D.new()
    shade.polygon = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
    var shade_alpha := 0.025
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
    var feel := get_node_or_null("/root/FeelKit")
    if feel != null:
        feel.register_camera(camera)


func _void_respawn() -> void:
    if player == null or not is_instance_valid(player):
        return
    if player.has_method("restore_at_save_point"):
        player.restore_at_save_point()
    if player.has_method("respawn_at"):
        player.respawn_at(active_spawn)
    else:
        player.global_position = active_spawn
    _toast("绯线牵你回到了上一处钟龛。")
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


func _original_background_layers() -> void:
    var art := _original_map_art()
    _add_original_parallax_layer(
        "OriginalSky",
        String(art.get("sky", "")),
        Vector2(0.04, 0.05),
        -118,
        1.14,
        Vector2(0, -170),
        Color(0.90, 0.94, 0.94, 1.0)
    )
    _add_original_parallax_layer(
        "OriginalFar",
        String(art.get("far", "")),
        Vector2(0.12, 0.10),
        -113,
        1.10,
        Vector2(0, -130),
        Color(0.86, 0.91, 0.90, 0.94)
    )
    _add_original_parallax_layer(
        "OriginalMid",
        String(art.get("mid", "")),
        Vector2(0.28, 0.18),
        -106,
        1.08,
        Vector2(0, -110),
        Color(0.92, 0.96, 0.94, 0.96)
    )
    _add_original_parallax_layer(
        "OriginalNear",
        String(art.get("near", "")),
        Vector2(0.62, 0.34),
        -97,
        1.08,
        Vector2(0, -100),
        Color(0.90, 0.94, 0.92, 0.90)
    )
    if _art_theme_id() == "rain_foundry":
        _background_rain_streaks()


func _add_original_parallax_layer(node_name: String, texture_path: String, scroll_scale_value: Vector2, z_value: int, scale_value: float, offset: Vector2, tint: Color) -> void:
    var texture := _load_texture_resource(texture_path)
    if texture == null:
        return
    var parallax := Parallax2D.new()
    parallax.name = node_name
    parallax.scroll_scale = scroll_scale_value
    parallax.z_index = z_value
    var tile_width := float(texture.get_width()) * scale_value
    var x := offset.x - tile_width
    var index := 0
    while x < world_width + tile_width * 2.0:
        var sprite := Sprite2D.new()
        sprite.name = "%sTexture%02d" % [node_name, index]
        sprite.texture = texture
        sprite.centered = false
        sprite.position = Vector2(x, offset.y)
        sprite.scale = Vector2(scale_value, scale_value)
        sprite.flip_h = index % 2 == 1
        sprite.modulate = tint
        parallax.add_child(sprite)
        x += tile_width
        index += 1
    add_child(parallax)


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


func _platform(node_name: String, rect: Rect2, color: Color, material: String = "moss_stone", collision_role: String = "") -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = node_name
    body.position = rect.position + rect.size * 0.5
    var lower_name := node_name.to_lower()
    var normalized_role := collision_role.to_lower()
    if normalized_role not in ["decorative", "no_collision"]:
        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = rect.size
        shape.shape = rectangle
        # Explicit one-way metadata keeps vertical routes passable from below.
        if normalized_role == "one_way" or lower_name.begins_with("bridge_") or lower_name.begins_with("step_") or lower_name.begins_with("shaft_bridge_"):
            shape.one_way_collision = true
            shape.one_way_collision_margin = 2.0
        body.add_child(shape)

    if flat_map_art != null and flat_map_art.ready_for_platforms():
        flat_map_art.add_platform_visual(body,rect.size,material)
    else:
        _add_platform_readability_base(body,rect.size,material,color)
    add_child(body)
    return body


func _add_platform_readability_base(parent: Node, size_value: Vector2, material: String, fallback_color: Color) -> void:
    var body_color := _platform_body_color(material, fallback_color)
    var edge_color := _platform_edge_color(material)
    _add_platform_plate(parent, Vector2(0, 6.0), size_value + Vector2(10.0, 18.0), body_color, -6)
    _add_platform_plate(parent, Vector2(0, -size_value.y * 0.5 + 4.0), Vector2(size_value.x + 12.0, 8.0), edge_color, -2)
    _add_platform_plate(parent, Vector2(0, size_value.y * 0.5 - 3.0), Vector2(size_value.x + 8.0, 5.0), Color(0.015, 0.026, 0.024, 0.82), -2)


func _platform_body_color(material: String, fallback_color: Color) -> Color:
    var theme := _art_theme_id()
    var color := Color(0.15, 0.22, 0.18, 0.98)
    if theme == "rain_foundry":
        color = Color(0.19, 0.24, 0.24, 0.98)
    elif theme == "salt_archive":
        color = Color(0.26, 0.23, 0.20, 0.98)
    elif theme == "string_greenhouse":
        color = Color(0.17, 0.24, 0.17, 0.98)
    elif theme == "obsidian_pilgrim":
        color = Color(0.19, 0.17, 0.20, 0.98)
    elif theme == "silent_crown":
        color = Color(0.20, 0.21, 0.27, 0.98)
    if material.contains("wall") or material.contains("gate"):
        color = color.darkened(0.18)
    return color


func _platform_edge_color(material: String) -> Color:
    var theme := _art_theme_id()
    if theme == "rain_foundry":
        return Color(0.44, 0.61, 0.60, 0.96)
    if theme == "salt_archive":
        return Color(0.72, 0.63, 0.44, 0.96)
    if theme == "string_greenhouse":
        return Color(0.44, 0.62, 0.34, 0.96)
    if theme == "obsidian_pilgrim":
        return Color(0.52, 0.40, 0.36, 0.96)
    if theme == "silent_crown":
        return Color(0.59, 0.62, 0.75, 0.96)
    return Color(0.45, 0.60, 0.33, 0.96)


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
    _add_original_platform_visual(parent, size_value, material)


func _add_original_platform_visual(parent: Node, size_value: Vector2, material: String) -> void:
    var art := _original_map_art()
    var left_texture := _load_texture_resource(String(art.get("left", "")))
    var mid_texture := _load_texture_resource(String(art.get("mid_tile", "")))
    var mid_alt_texture := _load_texture_resource(String(art.get("mid_alt", "")))
    var right_texture := _load_texture_resource(String(art.get("right", "")))
    var cap_texture := _load_texture_resource(String(art.get("cap_small", "")))
    var top_y := -size_value.y * 0.5
    var visual_scale_y := clampf(size_value.y / 128.0 + 0.38, 0.56, 1.0)
    var visual_center_y := top_y + 64.0 * visual_scale_y
    var tint := Color(1.0, 1.0, 1.0, 0.98)
    if material.contains("boss"):
        tint = Color(1.08, 0.96, 0.86, 1.0)
    elif material.contains("wall") or material.contains("gate"):
        tint = Color(0.86, 0.88, 0.86, 1.0)

    if size_value.x < 286.0 and cap_texture != null:
        var cap := _add_platform_sprite(parent, "Material", cap_texture, Vector2(0.0, visual_center_y), tint, -3)
        cap.scale = Vector2(minf(1.0, (size_value.x + 16.0) / float(cap_texture.get_width())), visual_scale_y)
        cap.set_meta("original_map_asset", String(art.get("cap_small", "")))
        return
    if left_texture == null or mid_texture == null or right_texture == null:
        _add_platform_plate(parent, Vector2(0, 8), size_value, _platform_body_color(material, Color(0.16, 0.20, 0.18)), -4)
        return

    var start_x := -size_value.x * 0.5
    var end_x := size_value.x * 0.5
    var left_width := float(left_texture.get_width())
    var right_width := float(right_texture.get_width())
    var left := _add_platform_sprite(parent, "Material", left_texture, Vector2(start_x + left_width * 0.5, visual_center_y), tint, -3)
    left.scale.y = visual_scale_y
    left.set_meta("original_map_asset", String(art.get("left", "")))
    var right := _add_platform_sprite(parent, "OriginalMapPlatformRight", right_texture, Vector2(end_x - right_width * 0.5, visual_center_y), tint, -3)
    right.scale.y = visual_scale_y
    right.set_meta("original_map_asset", String(art.get("right", "")))

    var x := start_x + left_width
    var index := 0
    while x < end_x - right_width:
        var texture := mid_alt_texture if index % 4 == 3 and mid_alt_texture != null else mid_texture
        var available := end_x - right_width - x
        var draw_width := minf(float(texture.get_width()), available)
        if draw_width <= 0.0:
            break
        var tile := _add_platform_sprite(parent, "OriginalMapPlatformTile", texture, Vector2(x + draw_width * 0.5, visual_center_y), tint, -3)
        tile.scale = Vector2(draw_width / float(texture.get_width()), visual_scale_y)
        tile.set_meta("original_map_asset", String(art.get("mid_tile", "")) if texture == mid_texture else String(art.get("mid_alt", "")))
        x += draw_width
        index += 1


func _is_cemetery_material(material: String) -> bool:
    return material == "salt_marble" or material == "vellum_bridge" or material == "archive_boss"


func _kenney_deluxe_family(material: String) -> String:
    if material == "moss_stone" or material == "greenhouse_loam":
        return "grass"
    if material == "bronze_bridge" or material == "glassvine_bridge":
        return "grass_half"
    if material == "boss_stone" or material == "root_boss" or material == "dirt":
        return "dirt"
    if material == "stone" or material == "obsidian_basalt":
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
    if material == "dirt":
        return Color(0.72, 0.58, 0.40, 1.0)
    if material == "stone":
        return Color(0.72, 0.72, 0.78, 1.0)
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


func _apply_original_prop(sprite: Sprite2D, key: String, height: float) -> void:
    var props := ORIGINAL_ART.manifest("res://assets/sprites/original_interactables/manifest.json")
    var texture := ORIGINAL_ART.frame(props.get(key,{}))
    if texture==null:return
    sprite.texture=texture
    sprite.scale=Vector2.ONE*(height/texture.get_height())
    sprite.position=Vector2(0,40-height*.5)
    sprite.modulate=Color.WHITE

func _collectible(data: Dictionary) -> void:
    if world_mode and bool(world_collected_ids.get(String(data.get("id", "")), false)):
        return
    var area := Area2D.new()
    area.name = String(data.get("id", "collectible"))
    area.position = _vec2(data.get("position", [0, 0]))
    var collectible_kind := String(data.get("kind", "bell_key"))
    var item_id := String(data.get("item_id", collectible_kind))
    area.set_meta("message", String(data.get("label", "Bell key acquired.")))
    area.set_meta("kind", collectible_kind)
    area.set_meta("item_id", item_id)
    area.set_meta("amount", int(data.get("amount", 1)))
    area.set_meta("ability_name", String(data.get("ability_name", data.get("label", ""))))
    area.set_meta("object_id", "collectible/" + area.name)

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18
    shape.shape = circle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = ORIGINAL_ART.item(item_id)
    if sprite.texture != null:
        sprite.scale=Vector2.ONE*(32.0/maxf(sprite.texture.get_width(),sprite.texture.get_height()))
    area.add_child(sprite)
    area.set_meta("manual_pickup",collectible_kind=="item" and _is_story_key_item(item_id))
    if bool(area.get_meta("manual_pickup")):
        area.add_to_group("interactable")
        area.set_meta("interaction_label","收取 · "+_item_display_name(item_id))
    else:
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
    area.set_meta("shortcut_id", String(data.get("shortcut_id", "")))
    area.set_meta("opens_connection", data.get("opens_connection", {}))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(50, 72)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES["lever"])
    sprite.scale = Vector2(0.52, 0.52)
    sprite.name="LeverSprite"
    _apply_original_prop(sprite,"lever_closed",83)
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
    area.set_meta("label", "踏入钟门")
    area.set_meta("object_id", "interactable/" + area.name)

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(96, 126)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(SPRITES["boss_gate"])
    sprite.scale = Vector2(0.82, 0.82)
    _apply_original_prop(sprite,"gate_closed",152)
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
    _apply_original_prop(sprite,"gate_open",138)
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
    _apply_original_prop(marker,"rest_root" if bool(data.get("hidden",false)) else "rest_bell",118)
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
        sprite.modulate = Color(1.0, 0.94, 0.78, 1.0)
        var base_scale := sprite.scale
        var flash := create_tween()
        flash.tween_property(sprite, "scale", base_scale*1.08, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flash.tween_property(sprite, "scale", base_scale, 0.18)
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
    area.set_meta("npc_id", String(data.get("id", "")))
    area.set_meta("story_dialogue", data.get("story_dialogue", {}))
    area.set_meta("dialogue_meta", data.get("dialogue_meta", {}))
    area.set_meta("dialogue_state", "")
    area.set_meta("dialogue_state_indices", {})
    area.set_meta("identity", String(data.get("identity", "")))
    area.set_meta("help", String(data.get("help", "")))

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 34
    shape.shape = circle
    area.add_child(shape)

    var art_id := ORIGINAL_ART.npc_art_id(String(data.get("id","")))
    var manifest_path := "res://assets/sprites/original_npcs/"+art_id+"/manifest.json"
    var art_data := ORIGINAL_ART.manifest(manifest_path)
    var npc_frames := ORIGINAL_ART.frames(manifest_path)
    if npc_frames != null:
        var sprite := AnimatedSprite2D.new()
        sprite.name="FriendlyFamilySprite"
        sprite.sprite_frames=npc_frames
        sprite.play("idle")
        sprite.scale=Vector2.ONE*float(art_data.get("visual_scale",.3))
        sprite.position=_vec2(art_data.get("visual_offset",[0,-24]))
        sprite.z_index=3
        area.add_child(sprite)
    area.add_to_group("interactable")
    area.set_meta("portrait_id",art_id)
    area.set_meta("dialogue_topics",data.get("dialogue_topics",{}))
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
    var original_path := String(data.get("sprite",""))
    if original_path.contains("original_creatures"):
        return maxf(20,float(ORIGINAL_ART.manifest(original_path).get("display_height",90))-40)
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
    if chapter_terrain != null and chapter_terrain.intersects_rect(actor_rect):
        return false
    if cave_world != null and cave_world.intersects_rect(actor_rect):
        return false
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if not String(platform_data.get("terrain_id", "")).is_empty():
            continue # The anchor rectangle was replaced by a continuous terrain polygon.
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
        return [left-0.05, right+0.05]
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
    enemy.set("death_sfx_key", _enemy_death_sfx_key())
    var floor_platform_id := _platform_under_position(enemy.position, clearance)
    var bounds := _enemy_platform_movement_bounds(floor_platform_id, enemy.position, data)
    if bounds.size() >= 2 and enemy.has_method("set_platform_movement_bounds"):
        enemy.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
    enemy.died.connect(_on_enemy_died)
    enemy.set_meta("platform_id", floor_platform_id)
    enemy.set_meta("spawn_half_width", float(data.get("spawn_half_width", 36.0)))
    enemy.set_meta("spawn_visual_height", float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data))))
    if String(enemy.locomotion)=="flight":
        while enemy.hover_height>35 and not _enemy_spawn_rect_clear(enemy.position-Vector2(0,enemy.hover_height),24,_enemy_spawn_visual_height(data),floor_platform_id):
            enemy.hover_height-=10
        if not _enemy_spawn_rect_clear(enemy.position-Vector2(0,enemy.hover_height),24,_enemy_spawn_visual_height(data),floor_platform_id):
            for offset in [-48.0,48.0,-96.0,96.0]:
                var candidate := enemy.position+Vector2(offset,-enemy.hover_height)
                if _enemy_spawn_rect_clear(candidate,24,_enemy_spawn_visual_height(data),floor_platform_id):
                    enemy.position.x=candidate.x
                    break
    add_child(enemy)
    return enemy


func _spawn_boss() -> void:
    if boss_spawned:
        return
    var boss_data: Dictionary = config.get("boss", {})
    boss_actor = Area2D.new()
    var clearance := float(boss_data.get("clearance", 40.0))
    boss_actor.position = _resolve_enemy_spawn_position(boss_data)
    boss_actor.set_script(ENEMY_ACTOR_SCRIPT)
    var kind := String(boss_data.get("kind", "rust_crown_guardian"))
    var profiles: Dictionary = config.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(kind, {})
    if profile.is_empty():
        push_warning("Missing boss AI profile: " + kind)
    boss_actor.configure(boss_data, SPRITES.get(kind, SPRITES["rust_crown_guardian"]), true, profile)
    boss_actor.set("death_sfx_key", _enemy_death_sfx_key())
    var floor_platform_id := _platform_under_position(boss_actor.position, clearance)
    var bounds := _enemy_platform_movement_bounds(floor_platform_id, boss_actor.position, boss_data)
    if bounds.size() >= 2 and boss_actor.has_method("set_platform_movement_bounds"):
        boss_actor.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
    boss_actor.died.connect(_on_enemy_died)
    boss_actor.set_meta("platform_id", floor_platform_id)
    boss_actor.set_meta("spawn_half_width", float(boss_data.get("spawn_half_width", 84.0)))
    boss_actor.set_meta("spawn_visual_height", float(boss_data.get("spawn_visual_height", _enemy_spawn_visual_height(boss_data))))
    add_child(boss_actor)
    boss_spawned = true
    # Boss 曲按章 boss kind 选曲（终 Boss silent_crown_core 三乐章由血量轮询驱动）。
    if audio_director != null:
        audio_director.start_boss_music(kind)
    else:
        _switch_bgm("bgm_boss")
    # Boss 战开始 ducking 示范点（规格 §5.3）：入场威压瞬间压低 BGM 再回弹，
    # 覆盖 _debug_start_boss 与 _activate_boss_gate 两条激活路径。
    duck_bgm(-6.0, 1.5)
    _toast("钟门深处 · " + _boss_display_name(boss_data))
    _refresh_hud()


func _start_boss_trial() -> void:
    for enemy_node in get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        if bool(enemy_area.get("is_boss")):
            continue
        if enemy_area.has_method("_cancel_attack_effects"):
            enemy_area._cancel_attack_effects()
        enemy_area.queue_free()
    enemy_defeated = enemy_total
    _open_all_shortcuts(false)
    var boss_data: Dictionary = config.get("boss", {})
    var boss_position := _vec2(boss_data.get("position", config.get("boss_checkpoint", active_spawn)))
    var trial_spawn := _vec2(config.get("boss_checkpoint", boss_position + Vector2(-520.0, 0.0)))
    if trial_spawn == Vector2.ZERO:
        trial_spawn = boss_position + Vector2(-520.0, 0.0)
    active_spawn = trial_spawn
    active_save_point_id = "boss_trial"
    if player != null and is_instance_valid(player):
        player.global_position = trial_spawn
        if player.has_method("set_spawn"):
            player.set_spawn(trial_spawn)
        if player.has_method("restore_at_save_point"):
            player.restore_at_save_point()
    _spawn_boss()
    if boss_spawned and not demo_complete:
        if boss_trial_mode or not config.get("interactives", []).is_empty():
            _set_boss_arena_locked(true)
    _update_room_visit()
    _toast("试炼开始 · 苔钟守母已苏醒。")
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
        _toast("钟门已合，战斗开始。")
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
    if body != player or area.is_queued_for_deletion():
        return
    var collectible_kind := String(area.get_meta("kind", "bell_key"))
    var item_id := String(area.get_meta("item_id", collectible_kind))
    var amount := int(area.get_meta("amount", 1))
    var ability_name := String(area.get_meta("ability_name", ""))
    if collectible_kind == "currency":
        _add_currency(amount)
        # 松脂碎钱质感层（音频规格 §4.5 ui_pickup_resin，Kenney RPG handleCoins ×2 随机）。
        _play_sfx_random(["pickup_coins_1", "pickup_coins_2"], -10.0)
    else:
        bell_count += 1
        _add_inventory_item(item_id, amount, false)
        if collectible_kind == "item":
            unlocked_abilities[item_id] = ability_name if not ability_name.is_empty() else item_id
            # 能力解锁 jingle（音频规格 §4.5 ui_ability_unlock）：与 pickup 基础音叠播。
            _play_sfx("ui_ability_unlock", -4.0)
            _refresh_ability_gates(true)
        _trigger_whispers("pickup_item", item_id)
        _announce_lore_pickup(item_id)
        # 收进布包质感层（Kenney RPG cloth1，与 pickup.ogg 叠放）。
        _play_sfx("pickup_cloth", -12.0)
    _play_sfx("pickup")
    if metsys_bridge != null:
        metsys_bridge.store_object(area)
    _toast(String(area.get_meta("message", "Collected.")))
    _spawn_pickup_effect(area.global_position)
    if world_mode:
        world_collected_ids[String(area.name)] = true
        _save_world()
    area.queue_free()
    _refresh_hud()


## play_unlock_sfx 仅在"拾取能力当场开门"时为 true；章节加载/调试同步保持静音，
## 避免开场把已解锁门的开门音一次性齐鸣。
func _refresh_ability_gates(play_unlock_sfx: bool = false) -> void:
    for gate in config.get("locked_gates", []):
        if not (gate is Dictionary):
            continue
        var gate_data: Dictionary = gate
        var gate_id := String(gate_data.get("id", ""))
        var required_ability := String(gate_data.get("required_ability", ""))
        if gate_id.is_empty() or required_ability.is_empty():
            continue
        if int(inventory_counts.get(required_ability, 0)) > 0:
            var unlock_sfx := String(GATE_UNLOCK_SFX.get(required_ability, "gate_dash")) if play_unlock_sfx else ""
            _unlock_ability_gate(gate_id, unlock_sfx)
    _sync_player_abilities()


func _sync_player_abilities() -> void:
    if player == null:
        return
    var gated_start := bool(config.get("ability_gated_start", false))
    player.dash_unlocked = (not gated_start) or inventory_counts.has("thread_dash")
    player.wall_grip_unlocked = (not gated_start and not world_mode) or inventory_counts.has("silk_wall_grip")
    player.dash_unlocked = (not gated_start and not world_mode) or inventory_counts.has("thread_dash")
    player.double_jump_unlocked = int(inventory_counts.get("double_thread_jump", 0)) > 0
    player.thread_grapple_unlocked = int(inventory_counts.get("echo_hook", 0)) > 0
    if world_mode:
        for anchor in get_tree().get_nodes_in_group("grapple_anchor"):
            if anchor.get_parent() != self:
                continue
            var enabled := int(inventory_counts.get(String(anchor.get_meta("required_ability", "echo_hook")), 0)) > 0
            anchor.set_meta("grapple_enabled", enabled)
            anchor.modulate = Color.WHITE if enabled else Color(0.50, 0.50, 0.50)


func _unlock_ability_gate(gate_id: String, unlock_sfx_key: String = "") -> void:
    if not locked_gate_bodies.has(gate_id):
        return
    var body := locked_gate_bodies[gate_id] as StaticBody2D
    if body != null and is_instance_valid(body):
        body.queue_free()
    locked_gate_bodies.erase(gate_id)
    # 能力门开启音（音频规格 §4.5 ui_gate_unlock）：按门族播对应家族音。
    if not unlock_sfx_key.is_empty():
        _play_sfx(unlock_sfx_key, -7.0)


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
    # Continue the visible speaker only while it is valid and in range.
    if active_overlay == "dialogue":
        if world_mode and dialogue_text_label != null and dialogue_text_label.visible_characters >= 0 and dialogue_text_label.visible_characters < dialogue_text_label.text.length():
            subtitle_elapsed = subtitle_seconds
            dialogue_text_label.visible_characters = -1
            return
        _commit_world_dialogue()
        var speaker: Area2D = null
        if ui_shell != null and is_instance_valid(ui_shell.dialogue_area):
            speaker = ui_shell.dialogue_area
        if speaker != null and not speaker.is_queued_for_deletion() and player.global_position.distance_to(speaker.global_position) <= 150.0:
            nearby_interactable = speaker
        else:
            _close_overlays()
    # Overlapping Areas cannot choose the target through body-enter order.
    if active_overlay != "dialogue":
        nearby_interactable = _nearest_interactable(150.0)
    if nearby_interactable == null or not is_instance_valid(nearby_interactable):
        for lift in cave_lifts:
            if lift.request(player.global_position):
                _toast("升降笼启动。可在途中跳离，落点两侧可呼叫。")
                return
        _toast("附近没有可交互的人物或机关。")
        return
    if bool(nearby_interactable.get_meta("manual_pickup", false)):
        _on_collectible_body_entered(player, nearby_interactable)
        nearby_interactable = null
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
    elif kind == "world_portal":
        _activate_world_portal(nearby_interactable)
    elif kind == "ending_gate":
        _activate_ending_gate(nearby_interactable)


func _nearest_interactable(radius: float) -> Area2D:
    if player == null or not is_instance_valid(player):
        return null
    var best: Area2D = null
    var best_distance := radius
    var preferred_best: Area2D = null
    var preferred_distance := radius
    for child in get_children():
        var area := child as Area2D
        if area == null or not is_instance_valid(area) or area.is_queued_for_deletion():
            continue
        var kind := String(area.get_meta("kind", ""))
        if not ["lever", "boss_gate", "npc", "save_point", "chapter_exit", "ending_exit", "ending_gate", "world_portal", "item"].has(kind):
            continue
        if kind == "item" and not bool(area.get_meta("manual_pickup", false)):
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
    var shortcut_id := _shortcut_id_for_area(area)
    if _is_shortcut_open(shortcut_id):
        _toast("这条捷径已经接通。")
        return
    if _combat_progression_enabled() and not _shortcut_is_lever_controlled(shortcut_id):
        if not _combat_goal_met():
            _toast("清除附近的敌群，才能接通钟门前的道路。")
            return
        _open_shortcut(shortcut_id)
        _play_sfx("lever")
        _play_sfx("lever_latch", -10.0)
        return
    var required_keys := int(area.get_meta("requires_keys", max_bells))
    if bell_count < required_keys:
        _toast("Shortcut needs %d route marks. You have %d." % [required_keys, bell_count])
        return
    _open_shortcut(shortcut_id)
    _play_sfx("lever")
    # 拉杆金属锁舌质感层（Kenney RPG Audio，与 Bread Adventure lever.ogg 叠放）。
    _play_sfx("lever_latch", -10.0)
    if metsys_bridge != null:
        metsys_bridge.store_object(area)


func _open_shortcut(shortcut_id: String = "") -> void:
    if shortcut_id.is_empty():
        var ids := _shortcut_ids()
        if not ids.is_empty():
            shortcut_id = String(ids[0])
    if not shortcut_id.is_empty():
        opened_shortcuts[shortcut_id] = true
    for child in get_children():
        if child is Area2D and String(child.get_meta("kind",""))=="lever" and _shortcut_id_for_area(child)==shortcut_id:
            var sprite := child.get_node_or_null("LeverSprite") as Sprite2D
            if sprite!=null:_apply_original_prop(sprite,"lever_open",52)
    shortcut_open = true
    if bool(config.get("boss_route_via_exploration", false)) or not _combat_progression_enabled() or _combat_goal_met():
        _unlock_boss_route()
    # 捷径门接通（音频规格 §4.5 ui_door_open）："绕回来了"的木门吱呀。
    _play_sfx("door_open", -9.0)
    var progress := "%d/%d" % [_opened_shortcut_total(), max(1, _shortcut_total())]
    _toast("捷径已通（%s）。钟门前可以先在钟龛休息。" % progress)
    _refresh_hud()
    _save_world()


func _open_all_shortcuts(show_toast: bool = true) -> void:
    var ids := _shortcut_ids()
    for shortcut_id in ids:
        opened_shortcuts[String(shortcut_id)] = true
    shortcut_open = true
    _unlock_boss_route()
    if show_toast:
        _toast("本区捷径均已接通。")
    _refresh_hud()


func _activate_save_point(area: Area2D) -> void:
    active_spawn = area.global_position
    active_save_point_id = String(area.name)
    player.set_spawn(active_spawn)
    if player.has_method("restore_at_save_point"):
        player.restore_at_save_point()
    # 钟龛安坐（音频规格 §4.5 env_shrine_wrap/env_shrine_rest）：
    # 缠线窸窣 + 龛铃"龛中眠"动机（D-A-B），六区各自音色滤波变体。
    _play_sfx("shrine_wrap", -9.0)
    _play_sfx(_shrine_rest_audio_key(), -6.0)
    # 钟龛摇篮曲（规格 §2.1）：安坐记锚点切摇篮曲；走远收场由 director 距离机自驱。
    if audio_director != null:
        audio_director.engage_shrine(area.global_position)
    _play_save_point_activation(area)
    if metsys_bridge != null:
        metsys_bridge.store_object(area)
    _save_world()
    _toast("安坐钟龛 · 已记下归途，恢复生命与绯线。")
    _refresh_hud()


func _activate_chapter_exit(area: Area2D) -> void:
    if chapter_transitioning:
        return
    if not _chapter_exit_can_open(area):
        _toast("击败本章守门者后，前路才会开启。")
        return
    var kind := String(area.get_meta("kind", "chapter_exit"))
    if kind == "ending_exit":
        win_label.text = String(config.get("ending_message", "ENDING ROUTE OPEN: the silent crown answers."))
        win_label.visible = true
        _toast("最后的巡礼之路已经开启。")
        return
    var next_config_path := String(area.get_meta("next_config_path", ""))
    if next_config_path.is_empty():
        _toast("前路尚未接通。")
        return
    chapter_transitioning = true
    # 章节转场：BGM 总线 0.5s 淡出（新章 set_chapter 起播再从静音 0.8s 淡入）。
    if audio_director != null:
        audio_director.begin_chapter_transition()
    # 章节切换线音（音频规格 §4.5 env_chapter_transition）：挂 root 不被换场截断。
    _play_sfx_persistent("chapter_transition", -7.0)
    _toast("Entering " + String(area.get_meta("next_runtime_config_id", "next chapter")) + ".")
    call_deferred("_transition_to_next_chapter", next_config_path)


func _chapter_exit_can_open(area: Area2D) -> bool:
    return not bool(area.get_meta("requires_demo_complete", true)) or demo_complete


func _transition_to_next_chapter(next_config_path: String) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        chapter_transitioning = false
        return
    if world_mode:
        var next_config_id := String(_load_json(next_config_path).get("id", ""))
        var path := WORLD_ROUTES_SCRIPT.config_path(next_config_id)
        if path.is_empty():
            chapter_transitioning = false
            return
        var legacy_entry: Dictionary = _load_json(path).get("entry_from_previous", {})
        _travel_world(path, _vec2(legacy_entry.get("position", _load_json(path).get("player_start", [120,500]))))
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
    next_scene.set("story_flags", story_flags.duplicate(true))
    next_scene.set("carried_inventory_enabled", true)
    next_scene.set("carried_inventory_counts", inventory_counts.duplicate(true))
    next_scene.set("carried_currency", currency_count)
    parent_node.add_child(next_scene)
    queue_free()


# 结局门运行时（剧情蓝图 §12：Boss 后三扇门 + 结局文本 + 存档 flag 的最小闭环）。
# 数据契约（章节 JSON 可选 "ending_gates" 数组，缺省章节行为完全不变）：
#   {id, ending("ending_a"|"ending_b"|"ending_c"), label, position:[x,y](可选，
#    缺省绕 Boss 尸位/玩家横向散开), requires:{items:[], flags:[]},
#    message(达成结局文案), reject_message(可选，缺项拒绝提示)}
func _ending_gate_entries() -> Array:
    var entries: Array = []
    for gate in config.get("ending_gates", []):
        if gate is Dictionary:
            entries.append(gate)
    return entries


func _spawn_ending_gates() -> void:
    if ending_gates_spawned:
        return
    var entries := _ending_gate_entries()
    if entries.is_empty():
        return
    ending_gates_spawned = true
    var anchor := Vector2(world_width * 0.5, world_height * 0.5)
    if boss_actor != null and is_instance_valid(boss_actor):
        anchor = boss_actor.global_position
    elif player != null and is_instance_valid(player):
        anchor = player.global_position
    for index in range(entries.size()):
        var data: Dictionary = entries[index]
        var ending := String(data.get("ending", String(data.get("id", "ending_%d" % index))))
        var area := Area2D.new()
        area.name = String(data.get("id", "ending_gate_%d" % index))
        var fallback := anchor + Vector2(-230.0 + 230.0 * float(index), 0.0)
        area.position = _vec2(data.get("position", [fallback.x, fallback.y]))
        area.set_meta("kind", "ending_gate")
        area.set_meta("label", String(data.get("label", "Ending Gate")))
        area.set_meta("ending", ending)
        area.set_meta("requires", data.get("requires", {}))
        area.set_meta("message", String(data.get("message", "")))
        area.set_meta("reject_message", String(data.get("reject_message", "")))
        area.set_meta("object_id", "interactable/" + area.name)

        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = _vec2(data.get("interaction_size", [150, 150]))
        shape.shape = rectangle
        area.add_child(shape)

        var tint: Color = ENDING_GATE_TINTS.get(ending, Color(0.82, 0.90, 1.0, 0.90))
        var sprite := Sprite2D.new()
        sprite.name = "EndingGateSprite"
        sprite.texture = load(SPRITES["boss_gate"])
        sprite.scale = Vector2(0.66, 0.66)
        sprite.modulate = tint
        sprite.z_index = 7
        area.add_child(sprite)

        var glow := Line2D.new()
        glow.name = "EndingGateGlow"
        glow.width = 3.0
        glow.closed = true
        glow.default_color = Color(tint.r, tint.g, tint.b, 0.66)
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
    _toast("守门者陨落。结局之门显现，按 F 抉择。")


func _ending_gate_missing_requirements(requires_value: Variant) -> Array[String]:
    var missing: Array[String] = []
    if typeof(requires_value) != TYPE_DICTIONARY:
        return missing
    var requires: Dictionary = requires_value
    for item_value in requires.get("items", []):
        var item_id := String(item_value)
        if not item_id.is_empty() and not inventory_counts.has(item_id):
            missing.append(_item_display_name(item_id))
    for flag_value in requires.get("flags", []):
        var flag := String(flag_value)
        if not flag.is_empty() and not bool(story_flags.get(flag, false)):
            missing.append(flag)
    return missing


func _activate_ending_gate(area: Area2D) -> void:
    var ending := String(area.get_meta("ending", ""))
    var chosen := String(story_flags.get("ending_chosen", ""))
    if not chosen.is_empty():
        if chosen == ending:
            if win_label != null:
                win_label.text = String(area.get_meta("message", ""))
                win_label.visible = true
            _toast("结局已选定：" + String(area.get_meta("label", ending)))
        else:
            _toast("结局已定（%s），此门不再回应。" % chosen)
        return
    var missing := _ending_gate_missing_requirements(area.get_meta("requires", {}))
    if not missing.is_empty():
        var reject := String(area.get_meta("reject_message", ""))
        if reject.is_empty():
            reject = "此门未应：缺少 " + "、".join(missing)
        # 门拒绝=取消音（音频规格 §4.5 ui_menu_cancel，Kenney Interface）。
        _play_sfx("ui_menu_cancel", -4.0)
        _toast(reject)
        return
    story_flags["ending_chosen"] = ending
    _set_story_flag("%s_done" % ending)
    _play_sfx("interact", -6.0)
    # 结局确认音 + 终止式 stinger（音频规格 §3.8）：stinger 挂 root 防演出切场截断。
    _play_sfx("ui_menu_confirm", 0.0)
    _play_sfx_persistent(String(ENDING_STINGER_SFX.get(ending, "ending_a_stinger")), -5.0)
    # 三结局全曲（规格 §3.8）：短 stinger 之后紧跟整曲（MusicStinger 总线）。
    if audio_director != null:
        audio_director.play_stinger(ending)
    if win_label != null:
        win_label.text = String(area.get_meta("message", "ENDING: " + ending))
        win_label.visible = true
    _toast("结局达成：" + String(area.get_meta("label", ending)))
    _refresh_hud()


func _activate_boss_gate() -> void:
    if not boss_unlocked:
        if _combat_progression_enabled():
            _toast("钟门未应。先探索洞道并接通捷径拉杆。" if bool(config.get("boss_route_via_exploration",false)) else "钟门未应。先清除本区敌群。")
        else:
            _toast("钟门未应。先接通附近的捷径。")
        return
    _spawn_boss()
    if boss_spawned and not demo_complete:
        _set_boss_arena_locked(true)


func _talk_to_npc(area: Area2D) -> void:
    var lines := _resolve_npc_lines(area)
    if lines.is_empty():
        _show_dialogue(area, "...")
        return
    var state := String(area.get_meta("dialogue_state", "repeat"))
    var state_indices: Dictionary = area.get_meta("dialogue_state_indices", {})
    var index := int(state_indices.get(state, 0))
    _play_sfx("interact", -10.0)
    _show_dialogue(area, String(lines[index % lines.size()]))
    area.set_meta("world_displayed_index", index % lines.size())
    area.set_meta("world_line_committed", false)
    area.set_meta("world_displayed_total", lines.size())
    if not world_mode:
        state_indices[state] = index + 1
        area.set_meta("dialogue_state_indices", state_indices)
    area.set_meta("dialogue_index", int(area.get_meta("dialogue_index", 0)) + 1)
    # first_meet flips npc_met_<id> only after the full round has been heard
    # (doc 2.1: 播完整轮后置位).
    if not world_mode and state == "first_meet" and index + 1 >= lines.size():
        _set_story_flag("npc_met_%s" % String(area.get_meta("npc_id", area.name)))


# Six-state dialogue machine (doc 2.1/2.3). Priority: first_meet (only while
# npc_met_<id> unset) -> true_ending_branch -> late_game -> sidequest_done ->
# after_boss -> after_ability -> repeat. NPCs without story_dialogue fall back
# to the legacy dialogue array untouched.
func _resolve_npc_lines(area: Area2D) -> Array:
    var fallback: Array = area.get_meta("dialogue", [])
    if world_mode and world_narrative != null:
        var result := world_narrative.resolve(String(area.get_meta("npc_id", area.name)), fallback, inventory_counts.keys(), story_flags, inventory_counts)
        area.set_meta("world_dialogue_result", result)
        if not result.is_empty():
            area.set_meta("dialogue_state", String(result.get("state", "world_repeat")))
            return result.get("lines", fallback)
    var story_dialogue_value: Variant = area.get_meta("story_dialogue", {})
    if typeof(story_dialogue_value) != TYPE_DICTIONARY:
        area.set_meta("dialogue_state", "repeat")
        return fallback
    var story_dialogue: Dictionary = story_dialogue_value
    if story_dialogue.is_empty():
        area.set_meta("dialogue_state", "repeat")
        return fallback
    var npc_id := String(area.get_meta("npc_id", area.name))
    var dialogue_meta_value: Variant = area.get_meta("dialogue_meta", {})
    var dialogue_meta: Dictionary = dialogue_meta_value if typeof(dialogue_meta_value) == TYPE_DICTIONARY else {}
    if not bool(story_flags.get("npc_met_%s" % npc_id, false)):
        area.set_meta("dialogue_state", "first_meet")
        var first_lines: Array = story_dialogue.get("first_meet", [])
        return first_lines if not first_lines.is_empty() else fallback
    for state in ["true_ending_branch", "late_game", "sidequest_done", "after_boss", "after_ability"]:
        var lines: Array = story_dialogue.get(state, [])
        if not lines.is_empty() and _dialogue_state_ok(String(state), dialogue_meta):
            area.set_meta("dialogue_state", state)
            return lines
    area.set_meta("dialogue_state", "repeat")
    var repeat_lines: Array = story_dialogue.get("repeat", [])
    return repeat_lines if not repeat_lines.is_empty() else fallback


func _dialogue_state_ok(state: String, dialogue_meta: Dictionary) -> bool:
    match state:
        "true_ending_branch":
            return bool(story_flags.get("true_ending_testimony_complete", false))
        "late_game":
            var testimony_ref := String(dialogue_meta.get("testimony_ref", ""))
            return not testimony_ref.is_empty() and inventory_counts.has(testimony_ref)
        "sidequest_done":
            var quest_flag := String(dialogue_meta.get("quest_flag", ""))
            return not quest_flag.is_empty() and bool(story_flags.get(quest_flag, false))
        "after_boss":
            return demo_complete or bool(story_flags.get("boss_down_%s" % _chapter_story_id(), false))
        "after_ability":
            var ability_ref := String(dialogue_meta.get("ability_ref", dialogue_meta.get("ability_key", "")))
            return not ability_ref.is_empty() and inventory_counts.has(ability_ref)
    return false


# "demo_ch01_moss_bell_court" -> "ch01" (used for boss_down_<chapter> flags).
func _chapter_story_id() -> String:
    for part in String(config.get("id", "")).split("_"):
        var token := String(part)
        if token.length() >= 3 and token.begins_with("ch") and token.substr(2).is_valid_int():
            return token
    return String(config.get("id", ""))


func _set_story_flag(flag: String) -> void:
    if flag.is_empty():
        return
    story_flags[flag] = true
    _check_wish_board_rewards()
    _save_world()


# true_ending_testimony_complete flips once all six testimonies are held
# (doc 2.1: true_ending_branch gate).
func _refresh_testimony_chain_flag() -> void:
    if bool(story_flags.get("true_ending_testimony_complete", false)):
        return
    for index in range(1, 7):
        if not inventory_counts.has("testimony_%02d" % index):
            return
    # 证词链集齐达成音（音频规格 §4.5 ui_testimony_complete）：置 flag 前一次性播。
    _play_sfx("ui_testimony_complete", -4.0)
    _set_story_flag("true_ending_testimony_complete")


# One-shot ambient whispers (绯线低语, config `whispers`). trigger:
# "enter_room" keyed by room_id, "pickup_item" keyed by item_id.
func _trigger_whispers(trigger: String, key: String) -> void:
    if key.is_empty():
        return
    for whisper in config.get("whispers", []):
        if not (whisper is Dictionary):
            continue
        var data: Dictionary = whisper
        if String(data.get("trigger", "enter_room")) != trigger:
            continue
        if String(data.get("room_id", data.get("item_id", ""))) != key:
            continue
        var whisper_id := String(data.get("id", ""))
        if whisper_id.is_empty() or bool(story_flags.get("whisper_%s" % whisper_id, false)):
            continue
        _set_story_flag("whisper_%s" % whisper_id)
        _toast(String(data.get("line", "")))


func _show_dialogue(area: Area2D, line: String) -> void:
    # 对话混音态（规格 §5.3）：Music -4dB / Ambience -6dB，关闭时归还。
    if active_overlay != "dialogue" and audio_director != null:
        audio_director.on_dialogue(true)
    active_overlay = "dialogue"
    if backpack_panel != null:
        backpack_panel.visible = false
    if map_panel != null:
        map_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = false
    if dialogue_panel != null:
        dialogue_panel.visible = true
    if dialogue_name_label != null:
        dialogue_name_label.text = String(area.get_meta("label", area.name))
    if dialogue_meta_label != null:
        dialogue_meta_label.text = String(area.get_meta("identity", ""))
    if dialogue_text_label != null:
        dialogue_text_label.text = line
        if world_mode:
            subtitle_elapsed = 0.0
            subtitle_seconds = WORLD_NARRATIVE_SCRIPT.subtitle_duration(line)
            dialogue_text_label.visible_characters = 0
            if audio_director != null:
                var profile := String(area.get_meta("world_dialogue_result", {}).get("voice_profile", "warm"))
                audio_director.play_npc_voice(String(area.get_meta("npc_id", area.name)), line, profile)
        else:
            dialogue_text_label.visible_characters = -1
    if dialogue_hint_label != null:
        dialogue_hint_label.text = String(area.get_meta("help", ""))
    if ui_shell!=null:
        ui_shell.show_speaker(area)
    _sync_ui_input_lock()


func _on_enemy_died(spawn_id: String, is_boss: bool, kind: String) -> void:
    if is_boss:
        var boss_data: Dictionary = config.get("boss", {})
        var boss_name := _boss_display_name(boss_data)
        var reward_item := String(boss_data.get("reward_item", "crown_splinter"))
        demo_complete = true
        _set_story_flag("boss_down_%s" % _chapter_story_id())
        _set_boss_arena_locked(false)
        # Boss 战收尾：停 Boss 曲、恢复本章探索循环。
        if audio_director != null:
            audio_director.stop_boss_music()
        win_label.text = String(config.get("completion_message", "DEMO COMPLETE: " + boss_name + " defeated"))
        win_label.visible = true
        _add_currency(30)
        _add_inventory_item(reward_item, 1, false)
        _announce_lore_pickup(reward_item)
        if metsys_bridge != null and boss_actor != null:
            if not boss_actor.has_meta("object_id"):
                boss_actor.set_meta("object_id", "boss/" + spawn_id)
                var boss_room := _room_for_position(boss_actor.global_position)
                metsys_bridge.register_object(boss_actor, String(boss_actor.get_meta("object_id")), String(boss_room.get("id", "boss_chamber")))
            metsys_bridge.store_object(boss_actor)
        if player != null:
            player.gain_energy(30)
        _open_post_boss_route()
        _spawn_ending_gates()
        _toast(String(config.get("completion_toast", "Demo complete: " + boss_name + " defeated.")))
        var transition: Dictionary = config.get("chapter_transition", {})
        if not transition.is_empty():
            _toast("前往下一片土地 · " + String(transition.get("entry_hint", _next_campaign_chapter_name())))
    else:
        var drop_item := String(config.get("enemy_drop_item", "moss_chitin"))
        enemy_defeated += 1
        _add_currency(8)
        _add_inventory_item(drop_item, 1, false)
        if player != null:
            player.gain_energy(20)
        _toast("拾得碎钱与材料 · 绯线回充")
        if _combat_progression_enabled() and _combat_goal_met():
            _open_combat_clear_route()
            _play_sfx("door_open", -9.0)
            _toast("本区敌群已清，钟门前的道路开启。")
    _refresh_hud()
    _save_world()


func _on_player_respawned() -> void:
    _reset_encounters_after_player_death()
    _save_world()


func _reset_encounters_after_player_death() -> void:
    if demo_complete and not world_mode:
        _refresh_hud()
        return
    _set_boss_arena_locked(false)
    for enemy_node in get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        if enemy_area.has_method("_cancel_attack_effects"):
            enemy_area._cancel_attack_effects()
        enemy_area.queue_free()
    boss_actor = null
    boss_spawned = false
    enemy_defeated = 0
    if boss_trial_mode:
        _open_all_shortcuts(false)
        pending_enemy_respawn = false
        if player != null and is_instance_valid(player):
            player.global_position = active_spawn
            if player.has_method("restore_at_save_point"):
                player.restore_at_save_point()
        call_deferred("_respawn_boss_trial_boss")
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
        var tween := create_tween()
        tween.tween_interval(float(index) * 0.08)
        tween.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.42)
        tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.42)
        tween.tween_callback(ring.queue_free)


func _on_hp_changed(value: int) -> void:
    # 濒死混音态（规格 §5.5）：HP==1 挂低通，回升或死亡即摘除。
    _set_low_hp_audio(value == 1)
    if value <= 0:
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


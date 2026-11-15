extends Node2D

const INTERACTION_REACH := 150.0

const FLAT_MAP_ART_SCRIPT := preload("res://scripts/flat_map_art.gd")
const TERRAIN_SCRIPT := preload("res://scripts/chapter_terrain.gd")
const CAVE_WORLD_SCRIPT := preload("res://scripts/cave_world.gd")
const CAVE_LIFT_SCRIPT := preload("res://scripts/cave_lift.gd")
const PILGRIMAGE_UI_SCRIPT := preload("res://scripts/pilgrimage_interface.gd")
var ui_shell: Control
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")
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
const ABILITY_GATE_SIGN := preload("res://scripts/ability_gate_sign.gd")
const WORLD_PLATFORMS := preload("res://scripts/world_platform_residency.gd")
var world_platforms: RefCounted
const WORLD_GAMEPLAY_RESIDENCY := preload("res://scripts/world_gameplay_residency.gd")
var world_gameplay_residency: RefCounted
var npc_residency_memory: Dictionary = {}
var save_point_residency_memory: Dictionary = {}
const WORLD_PREFETCH := preload("res://scripts/world_prefetch.gd")
const WORLD_COORDINATES := preload("res://scripts/world_coordinates.gd")
const WORLD_ROUTES_SCRIPT := preload("res://scripts/world_routes.gd")
const SCENE_HISTORY := preload("res://scripts/scene_history.gd")
const HISTORY_PROP := preload("res://scripts/scene_history_prop.gd")
const HIDDEN_ROUTE_CLUE_SCRIPT := preload("res://scripts/hidden_route_clue.gd")
const ENDING_AFTERMATH_SCRIPT := preload("res://scripts/ending_aftermath_scene.gd")
const AFTERMATH_NOTICE_RANGE := 260.0
const HIDDEN_CLUE_NOTICE_RANGE := 260.0
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
        "danger": "Choose your landing before jumping.",
        "next": "Climb into the Upper Gallery."
    },
    "upper_bells": {
        "objective": "Win the upper-gallery fight and return toward the shortcut.",
        "guide": "Save a dash for the next landing.",
        "danger": "Watch enemy windups before crossing the upper platform.",
        "next": "Head for the Back Chapel."
    },
    "backdoor": {
        "objective": "After every enemy falls, use the shortcut lever.",
        "guide": "Opening the shortcut also moves the checkpoint near the boss run.",
        "danger": "Look for the lever beside the path.",
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
    "menders_right": {"name": "缝补右手", "description": "按治疗键缝补伤口；消耗、回复量与能否空中缝补由所装契印决定，详见构筑页的契印说明。"},
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
    "falling_clapper": "res://assets/sprites/original_creatures/falling_clapper/manifest.json",
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
    # ch6 beat `ending_doors`（manifest ch06_beat_03）：最终 Boss 倒下、三色结局门现形时一次。
    "ch06_beat_ending_doors": "res://assets/audio/sfx/generated/ch06_silent_crown_core_beat_03_audio.ogg",
    # ch4 beat `string_bridge_break`（manifest ch04_beat_03）：断弦温室里下劈击碎地面时
    # 在碎裂声上叠断弦拨片与石屑落地。
    "ch04_beat_string_break": "res://assets/audio/sfx/generated/ch04_broken_string_greenhouse_beat_03_audio.ogg",
    # ch6 beat `echo_room_open`（manifest ch06_beat_01）：第一次走进无声王冠的五间回声室时
    # 各响一次低频钟声短句；重访不再响。
    "ch06_beat_echo_room": "res://assets/audio/sfx/generated/ch06_silent_crown_core_beat_01_audio.ogg",
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
## E02: this region's tool practice rooms and encounter hints, built with the region.
var tool_practice_rooms: Dictionary = {}
var tool_encounter_hints: Dictionary = {}

## C04: practice hits per skill this session; three open its 校习 directions.
var skill_practice_hits: Dictionary = {}
var skill_practice_serials: Dictionary = {}
## B04 optional challenge rooms / optional bosses: sealed on demand, one-time clear.
var challenge_arena_lock_body: StaticBody2D
var active_challenge_id := ""
var challenge_alive_ids: Dictionary = {}
## Validation-only: these spawn ids are treated as `_enemy` returning null.
var challenge_spawn_null_ids_for_validation: Dictionary = {}
var hidden_route_clues: Array[Node2D] = []
var ending_aftermath: Node2D = null
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
var world_pickup_leases: Dictionary = {}
var world_catalog: Dictionary = {}
var world_catalog_prepare_staging: Dictionary = {}
var world_write_error_shown := false
## Narrow failure seam for transaction validations; simulates the storage boundary failing after capture.
var world_save_failure_injected_for_validation := false
# Distinguish a settled blocked-save memory checkpoint from capture failure.
var world_save_capture_ok := false
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
var world_resumed_journey := false
var journey_clock: RefCounted
var achievements: RefCounted
var world_map_view := false
var applied_build_profile: Dictionary = {}
var world_start_region_id := ""

@export var config_path := DEFAULT_CONFIG_PATH


const CARTOGRAPHY := preload("res://scripts/pilgrimage_cartography.gd")
const WORLD_ATLAS := preload("res://scripts/world_atlas.gd")
const LEVEL_PROPS := preload("res://scripts/level_props.gd")
const LEVEL_SCENERY := preload("res://scripts/level_scenery.gd")
const LEVEL_OVERLAYS := preload("res://scripts/level_overlays.gd")
const LEVEL_AUDIO := preload("res://scripts/level_audio.gd")
const ENEMY_PLACEMENT := preload("res://scripts/enemy_placement.gd")
const ENDING_GATES := preload("res://scripts/ending_gates.gd")
const OPTIONAL_CHALLENGES := preload("res://scripts/optional_challenges.gd")
const WISH_TOPICS := preload("res://scripts/wish_topics.gd")
const MAP_OVERLAY := preload("res://scripts/map_overlay.gd")
const CARTOGRAPHY_UI := preload("res://scripts/cartography_runtime.gd")
const DEATH_RECALL := preload("res://scripts/death_recall.gd")
const MAP_PLAYER_PINS := preload("res://scripts/map_player_pins_runtime.gd")
const LEVEL_WORLD_START := preload("res://scripts/level_world_start.gd")
const LEVEL_WORLD_TRAVEL := preload("res://scripts/level_world_travel.gd")
const LEVEL_CATALOGUE := preload("res://scripts/level_catalogue.gd")
const LEVEL_ROOMS := preload("res://scripts/level_rooms.gd")
const LEVEL_HUD_BUILD := preload("res://scripts/level_hud_build.gd")
const LEVEL_BOSS := preload("res://scripts/level_boss.gd")
const LEVEL_PICKUPS := preload("res://scripts/level_pickups.gd")
const LEVEL_INTERACTION := preload("res://scripts/level_interaction.gd")
const LEVEL_ACTIVATION := preload("res://scripts/level_activation.gd")
const LEVEL_REGION_BUILD := preload("res://scripts/level_region_build.gd")
const LEVEL_DIALOGUE := preload("res://scripts/level_dialogue.gd")
const LEVEL_ENCOUNTERS := preload("res://scripts/level_encounters.gd")
const LEVEL_HUD := preload("res://scripts/level_hud.gd")
const LEVEL_BUILD := preload("res://scripts/level_build.gd")
const LEVEL_SAVE_SLOTS := preload("res://scripts/level_save_slots.gd")
const LEVEL_GROUND := preload("res://scripts/level_ground.gd")
const LEVEL_REGION_PIPELINE := preload("res://scripts/level_region_pipeline.gd")
const LEVEL_JOURNEY_DATA := preload("res://scripts/level_journey_data.gd")
const LEVEL_PLAYER_FRAME := preload("res://scripts/level_player_frame.gd")
const LEVEL_RESIDENTS := preload("res://scripts/level_residents.gd")
const LEVEL_DEMO_STATE := preload("res://scripts/level_demo_state.gd")
const LEVEL_ROUTE_STATE := preload("res://scripts/level_route_state.gd")

func _ready() -> void:
    preload("res://scripts/application_close.gd").install(get_tree())
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
    LEVEL_REGION_PIPELINE.initialize_region(self, prepared_config)


func _prepare_region(prepared_config: Dictionary = {}) -> void:
    LEVEL_REGION_PIPELINE.prepare_region(self, prepared_config)


## Ordered preparation contract shared by synchronous startup and async World travel.
## Planning enumerates chapter filenames only; content reads, parsing and deep copies stay in jobs.
func _region_prepare_jobs(prepared_config: Dictionary = {}) -> Array:
    return LEVEL_REGION_PIPELINE.region_prepare_jobs(self, prepared_config)


func _chapter_metadata_paths() -> Array:
    return LEVEL_REGION_PIPELINE.chapter_metadata_paths(self)


func _prepare_config_and_route(prepared_config: Dictionary) -> void:
    LEVEL_REGION_PIPELINE.prepare_config_and_route(self, prepared_config)


func _prepare_narrative_config() -> void:
    LEVEL_REGION_PIPELINE.prepare_narrative_config(self)


func _begin_world_catalog_prepare() -> void:
    LEVEL_REGION_PIPELINE.begin_world_catalog_prepare(self)


func _prepare_world_catalog_jobs() -> Array:
    return LEVEL_REGION_PIPELINE.prepare_world_catalog_jobs(self)


func _prepare_world_catalog_region(region_id: String, route_catalog: Dictionary) -> void:
    LEVEL_REGION_PIPELINE.prepare_world_catalog_region(self, region_id, route_catalog)


func _commit_world_catalog_prepare() -> void:
    LEVEL_REGION_PIPELINE.commit_world_catalog_prepare(self)


func _prepare_campaign_metadata() -> void:
    LEVEL_REGION_PIPELINE.prepare_campaign_metadata(self)


func _begin_chapter_metadata() -> void:
    LEVEL_REGION_PIPELINE.begin_chapter_metadata(self)


func _prepare_chapter_metadata(path: String) -> void:
    LEVEL_REGION_PIPELINE.prepare_chapter_metadata(self, path)


func _prepare_av_metadata() -> void:
    LEVEL_REGION_PIPELINE.prepare_av_metadata(self)


func _prepare_item_lore_metadata() -> void:
    LEVEL_REGION_PIPELINE.prepare_item_lore_metadata(self)


func _resolve_chapter_world_and_spawn() -> void:
    LEVEL_REGION_PIPELINE.resolve_chapter_world_and_spawn(self)


func _prepare_inventory_state() -> void:
    LEVEL_REGION_PIPELINE.prepare_inventory_state(self)


func _restore_inventory_and_region() -> void:
    LEVEL_REGION_PIPELINE.restore_inventory_and_region(self)


func _restore_build_state() -> void:
    LEVEL_REGION_PIPELINE.restore_build_state(self)


func _sync_build_progress() -> void:
    LEVEL_REGION_PIPELINE.sync_build_progress(self)


func _prepare_build_inputs() -> void:
    LEVEL_REGION_PIPELINE.prepare_build_inputs(self)


func _prepare_audio_settings_key() -> void:
    LEVEL_REGION_PIPELINE.prepare_audio_settings_key(self)


func _prepare_metsys_bridge() -> void:
    LEVEL_REGION_PIPELINE.prepare_metsys_bridge(self)


func _prepare_audio() -> void:
    LEVEL_REGION_PIPELINE.prepare_audio(self)


func _prepare_platform_and_gameplay_residency() -> void:
    LEVEL_REGION_PIPELINE.prepare_platform_and_gameplay_residency(self)


func _finish_region() -> void:
    LEVEL_REGION_PIPELINE.finish_region(self)


func _region_finish_jobs() -> Array:
    return LEVEL_REGION_PIPELINE.region_finish_jobs(self)


func _finish_region_spawn() -> void:
    LEVEL_REGION_PIPELINE.finish_region_spawn(self)


func _bind_region_audio() -> void:
    LEVEL_REGION_PIPELINE.bind_region_audio(self)


func _setup_cartography() -> void:
    LEVEL_REGION_PIPELINE.setup_cartography(self)


func _publish_region() -> void:
    LEVEL_REGION_PIPELINE.publish_region(self)


func _restore_saved_build() -> void:
    LEVEL_REGION_PIPELINE.restore_saved_build(self)


func _apply_cmdline_config_override() -> void:
    LEVEL_REGION_PIPELINE.apply_cmdline_config_override(self)


func _physics_process(_delta: float) -> void:
    if world_mode and not initial_region_ready:
        return
    if is_instance_valid(world_passage) and world_passage.active:
        world_passage.step()
        return
    if is_instance_valid(world_passage):
        world_passage.try_walk_entry()
        if world_passage.active:
            return
    if world_mode and not world_loading and is_instance_valid(chapter_terrain) and is_instance_valid(player):
        chapter_terrain.update_collision_window(player.global_position, player.velocity, _delta)
    if world_mode and not world_loading and world_platforms != null and is_instance_valid(player):
        world_platforms.update(self, player.global_position, player.velocity, _delta)
    if world_mode and not world_loading and is_instance_valid(cave_world) and is_instance_valid(player):
        cave_world.update_collision_window(player.global_position, player.velocity, _delta)
    # Check the void before player movement can depenetrate against deep cave rock.
    if player != null and is_instance_valid(player) and player.global_position.y > fall_y:
        _void_respawn()


func _process(_delta: float) -> void:
    if world_mode and not initial_region_ready:
        return
    if journey_clock != null:
        journey_clock.tick(_delta)
    if is_instance_valid(world_passage) and world_passage.active:
        return
    if world_mode and not world_loading and world_prefetch != null:
        world_prefetch.step(self, _delta)
    if world_mode and not world_loading and world_gameplay_residency != null and is_instance_valid(player):
        world_gameplay_residency.update(self, player.global_position, player.velocity, _delta)
    if ui_shell != null and ui_shell.has_method("is_remapping_input") and ui_shell.is_remapping_input():
        world_new_key_held = Input.is_physical_key_pressed(KEY_F9)
        return
    if ui_shell != null and ui_shell.has_method("is_browsing_journey_history") and ui_shell.is_browsing_journey_history():
        world_new_key_held = Input.is_physical_key_pressed(KEY_F9)
        return
    # Native transaction dialogs own keyboard focus (Tab also binds inventory).
    # Polling global overlay shortcuts would close the dialog before GUI focus
    # can reach its purchase buttons. Escape keeps its normal close behavior.
    if active_overlay in ["cartographer", "recall"]:
        world_new_key_held = Input.is_physical_key_pressed(KEY_F9)
        if Input.is_action_just_pressed("close_overlay"):
            _close_overlays()
        return
    var new_key := Input.is_physical_key_pressed(KEY_F9)
    var new_requested := new_key and not world_new_key_held
    world_new_key_held = new_key
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
        # World encounters start at the manual bell gate, including after death.
        if not world_mode and boss_unlocked and not demo_complete and not boss_spawned:
            _spawn_boss()
        _refresh_hud()
    # Text entry suppresses polled shortcuts, while fall/room lifecycle work
    # below continues even when a search or scheme-name field owns focus.
    var typing: bool=ui_shell!=null and ui_shell.has_method("is_text_entry_focused") and ui_shell.is_text_entry_focused()
    var modal: bool=ui_shell!=null and ui_shell.has_method("has_modal_window") and ui_shell.has_modal_window()
    if not modal and (not typing or Input.is_action_just_pressed("close_overlay")):
        if Input.is_action_just_pressed("close_overlay"):
            _close_overlays()
        elif Input.is_action_just_pressed("inventory"):
            if world_mode and active_overlay == "map":
                world_map_view = not world_map_view
                _refresh_map_overlay()
            else:
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
        if active_overlay.is_empty():
            if Input.is_action_just_pressed("tool_cast"):
                perform_build_action("use_tool")
            elif Input.is_action_just_pressed("skill_cycle"):
                perform_build_action("cycle_skill")
            elif Input.is_action_just_pressed("tool_cycle"):
                perform_build_action("cycle_tool")
        if Input.is_action_just_pressed("interact"):
            _try_interact()
    if player != null and is_instance_valid(player) and player.global_position.y > fall_y:
        _void_respawn()
    if player != null and is_instance_valid(player):
        _update_safe_ground()
        _update_room_visit()
        _notice_hidden_route_clues()
        _notice_ending_aftermath()
        _update_first_journey_hint()
        if active_overlay == "map":
            _refresh_map_overlay()


func _exit_tree() -> void:
    _cancel_pending_sfx()
    if world_platforms != null:
        world_platforms.shutdown()
    if world_loader != null:
        world_loader.shutdown()
    if world_prefetch != null:
        world_prefetch.shutdown()
    if world_gameplay_residency != null:
        world_gameplay_residency.shutdown()
    npc_residency_memory.clear()
    save_point_residency_memory.clear()
    world_shared_metadata_cache.clear()
    _stop_region_tweens()
    _release_region_audio()


func _release_region_audio() -> void:
    LEVEL_PLAYER_FRAME.release_region_audio(self)


func _prepare_world_start() -> void:
    LEVEL_WORLD_START.prepare_world_start(self)

## T02: the damaged file stays untouched; tell the player whether its backup can
## bring the journey back, and where.
func _damaged_save_message() -> String:
    return LEVEL_WORLD_START.damaged_save_message(self)

func _resolve_world_start_route() -> bool:
    return LEVEL_WORLD_START.resolve_world_start_route(self)


func _consume_world_startup_options(arguments: PackedStringArray) -> bool:
    return LEVEL_WORLD_START.consume_world_startup_options(self, arguments)


func _restore_world_inventory_and_region() -> void:
    LEVEL_WORLD_START.restore_world_inventory_and_region(self)


func _world_runtime_jobs() -> Array:
    return LEVEL_WORLD_START.world_runtime_jobs(self)


func _restore_world_player() -> void:
    LEVEL_WORLD_START.restore_world_player(self)


func _warm_arrival_cave() -> void:
    LEVEL_WORLD_START.warm_arrival_cave(self)


func _warm_arrival_terrain() -> void:
    LEVEL_WORLD_START.warm_arrival_terrain(self)


func _warm_arrival_platforms() -> void:
    LEVEL_WORLD_START.warm_arrival_platforms(self)


func _restore_world_routes() -> void:
    LEVEL_WORLD_START.restore_world_routes(self)


func _restore_world_discovery() -> void:
    LEVEL_WORLD_START.restore_world_discovery(self)


## Shared coordinate frame for the future streaming host and world navigation.
## The existing chapter scene still simulates in its own local physics frame.
func player_world_position() -> Vector2:
    return LEVEL_WORLD_START.player_world_position(self)


func _prepare_world_checkpoint(global_snapshot: Dictionary, region_patch: Dictionary={}) -> Dictionary:
    return LEVEL_WORLD_START.prepare_world_checkpoint(self, global_snapshot, region_patch)


## Build and persist a detached gameplay patch. Callers publish live owners only
## after success; the returned candidate also lets death retain its explicit
## unsaved field snapshot, matching the existing respawn contract.
func _persist_world_change(patch: Dictionary, region_patch: Dictionary={}) -> Dictionary:
    return LEVEL_WORLD_START.persist_world_change(self, patch, region_patch)

func _save_world() -> bool:
    return LEVEL_WORLD_START.save_world(self)


const WAYFINDING := preload("res://scripts/world_wayfinding.gd")

func _first_interaction_type(area: Area2D) -> String:
    return LEVEL_WORLD_START.first_interaction_type(self, area)

func _show_first_interaction_hint(area: Area2D) -> void:
    LEVEL_WORLD_START.show_first_interaction_hint(self, area)


func _update_first_journey_hint() -> void:
    LEVEL_WORLD_START.update_first_journey_hint(self)


func _first_journey_heal_safe() -> bool:
    return LEVEL_WORLD_START.first_journey_heal_safe(self)

func _add_wayfinding(area: Area2D) -> void:
    LEVEL_WORLD_TRAVEL.add_wayfinding(self, area)

func _make_world_portal(data: Dictionary) -> Area2D:
    return LEVEL_WORLD_TRAVEL.make_world_portal(self, data)


func _world_portal(data: Dictionary) -> void:
    LEVEL_WORLD_TRAVEL.world_portal(self, data)


func _apply_world_npc_state(area: Area2D) -> void:
    LEVEL_WORLD_TRAVEL.apply_world_npc_state(self, area)


func _world_grapple_anchor(data: Dictionary) -> void:
    LEVEL_WORLD_TRAVEL.world_grapple_anchor(self, data)


func _world_portal_missing(data: Dictionary) -> String:
    return LEVEL_WORLD_TRAVEL.world_portal_missing(self, data)


func _refresh_world_portals() -> void:
    LEVEL_WORLD_TRAVEL.refresh_world_portals(self)


func _activate_world_portal(area: Area2D) -> void:
    LEVEL_WORLD_TRAVEL.activate_world_portal(self, area)


func _travel_world(next_path: String, entry: Vector2) -> void:
    LEVEL_WORLD_TRAVEL.travel_world(self, next_path, entry)


func _request_world_travel(next_path: String, entry: Vector2, shortcut: String = "") -> void:
    LEVEL_WORLD_TRAVEL.request_world_travel(self, next_path, entry, shortcut)


func _travel_world_async(next_path: String, entry: Vector2, shortcut: String = "") -> void:
    if world_loader == null or world_loader.phase != "idle":
        world_portal_request_pending = false
        return
    var publish_flags: Dictionary = {}
    if not shortcut.is_empty():
        publish_flags["world_shortcut_" + shortcut] = true
    var ok: bool = await world_loader.replace_region_async(self, next_path, entry, Vector2.INF, publish_flags)
    if not is_instance_valid(self) or not is_inside_tree():
        return
    world_portal_request_pending = false
    if not ok:
        _toast("旧路暂未接通，仍留在当前区域。" + world_loader.last_error)


func _region_tween() -> Tween:
    return LEVEL_WORLD_TRAVEL.region_tween(self)


func _stop_region_tweens() -> void:
    LEVEL_WORLD_TRAVEL.stop_region_tweens(self)


func _defer_region_call(method: StringName, arguments: Array = []) -> void:
    LEVEL_WORLD_TRAVEL.defer_region_call(self, method, arguments)


func _run_region_deferred(generation: int, method: StringName, arguments: Array) -> void:
    LEVEL_WORLD_TRAVEL.run_region_deferred(self, generation, method, arguments)


func _commit_world_dialogue() -> void:
    LEVEL_WORLD_TRAVEL.commit_world_dialogue(self)


func _rollback_narrative_transaction(flags_before: Dictionary, currency_before: int, world_before: Dictionary, build_before: Dictionary) -> void:
    LEVEL_WORLD_TRAVEL.rollback_narrative_transaction(self, flags_before, currency_before, world_before, build_before)


func _add_world_portal_map_pins(bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> void:
    LEVEL_WORLD_TRAVEL.add_world_portal_map_pins(self, bounds, draw_size, draw_width, base_y, depth_step)


func _world_exploration_hint() -> String:
    return LEVEL_WORLD_TRAVEL.world_exploration_hint(self)


func _draw_world_atlas() -> void:
    WORLD_ATLAS.render(self)


func _build_new_journey_dialog() -> void:
    LEVEL_JOURNEY_DATA.build_new_journey_dialog(self)


func _preserve_previous_journey() -> bool:
    return LEVEL_JOURNEY_DATA.preserve_previous_journey(self)


func _start_new_journey() -> void:
    LEVEL_JOURNEY_DATA.start_new_journey(self)


func _load_json(path: String) -> Dictionary:
    return LEVEL_JOURNEY_DATA.load_json(self, path)


## Immutable campaign presentation data is reused only by a persistent World
## host. Dynamic region configs, saves and progression never enter this cache.
## The returned deep copy keeps mutable scene consumers from altering the host
## snapshot. Empty dictionaries are valid JSON; open/parse/type failures are
## deliberately not cached, so a repaired source can succeed on the next call.
func _load_world_shared_json(path: String) -> Dictionary:
    return LEVEL_JOURNEY_DATA.load_world_shared_json(self, path)


func world_shared_metadata_snapshot() -> Dictionary:
    return LEVEL_JOURNEY_DATA.world_shared_metadata_snapshot(self)


func _world_shared_metadata_key(path: String) -> String:
    return ProjectSettings.localize_path(ProjectSettings.globalize_path(path).simplify_path())


func _art_theme_id() -> String:
    return LEVEL_CATALOGUE.art_theme_id(self)


## 钟龛 rest 音六区变体（音频规格 §2.1 摇篮曲/§4.5 ui_shrine_rest）。
func _shrine_rest_audio_key() -> String:
    return LEVEL_CATALOGUE.shrine_rest_audio_key(self)


## 敌人死亡材质音（音频规格 §4.3 六材质）：按章节 art theme 选择。
func _enemy_death_sfx_key() -> String:
    return LEVEL_CATALOGUE.enemy_death_sfx_key(self)


func _original_map_art() -> Dictionary:
    return LEVEL_CATALOGUE.original_map_art(self)

func _is_rain_foundry_theme() -> bool:
    return LEVEL_CATALOGUE.is_rain_foundry_theme(self)


func _theme_map_title() -> String:
    return LEVEL_CATALOGUE.theme_map_title(self)


func _theme_map_background_texture() -> String:
    return LEVEL_CATALOGUE.theme_map_background_texture(self)


func _theme_asset_source() -> String:
    return LEVEL_CATALOGUE.theme_asset_source(self)


func _background_visual_asset_paths() -> Array:
    return LEVEL_CATALOGUE.background_visual_asset_paths(self)

func _theme_boss_material() -> String:
    return LEVEL_CATALOGUE.theme_boss_material(self)


func _platform_visual_asset_paths_for_material(_material: String) -> Array:
    return LEVEL_CATALOGUE.platform_visual_asset_paths_for_material(self, _material)

func _combat_progression_enabled() -> bool:
    return LEVEL_CATALOGUE.combat_progression_enabled(self)


func _combat_goal_met() -> bool:
    return LEVEL_CATALOGUE.combat_goal_met(self)


func _shortcut_ids() -> Array:
    return LEVEL_CATALOGUE.shortcut_ids(self)


func _shortcut_total() -> int:
    return LEVEL_CATALOGUE.shortcut_total(self)


func _opened_shortcut_total() -> int:
    return LEVEL_CATALOGUE.opened_shortcut_total(self)


func _shortcut_id_for_area(area: Area2D) -> String:
    return LEVEL_CATALOGUE.shortcut_id_for_area(self, area)


func _is_shortcut_open(shortcut_id: String = "") -> bool:
    return LEVEL_CATALOGUE.is_shortcut_open(self, shortcut_id)


func _init_inventory_state() -> void:
    LEVEL_CATALOGUE.init_inventory_state(self)


# 跨章并集合并：starting_tools 先落底，再把携带背包中缺口补齐（按 max 计数，
# 不重复叠加同名工具）。走 _add_inventory_item 以保持 Tools/Relics/Materials
# 分类簿记与 testimony 链 flag 刷新一致；合并发生在 _spawn_player →
# _refresh_ability_gates → _sync_player_abilities 之前，因此"ch2 拿
# silk_wall_grip → 回 ch1 开 gate_wall_mossgrip"的数据链路直接成立。
func _merge_carried_inventory() -> void:
    LEVEL_CATALOGUE.merge_carried_inventory(self)


func _item_data(item_id: String) -> Dictionary:
    return LEVEL_CATALOGUE.item_data(self, item_id)


# 展示层口径（圣典 §7）：铭文表优先于各章 catalog；catalog 只负责 category
# 与圣典未收录物品（功能道具/章节变体）的功能短句，避免六章重复维护铭文。
func _item_display_name(item_id: String) -> String:
    return LEVEL_CATALOGUE.item_display_name(self, item_id)


# 圣典铭文多行保留分行；功能性物品先铭文后功能行（【功能】…）。
func _item_display_description(item_id: String) -> String:
    return LEVEL_CATALOGUE.item_display_description(self, item_id)


func _room_map_copy(room_id: String, field: String, fallback: String) -> String:
    return LEVEL_CATALOGUE.room_map_copy(self, room_id, field, fallback)


func _npc_display_name(data: Dictionary) -> String:
    return LEVEL_CATALOGUE.npc_display_name(self, data)


func _npc_dialogue(data: Dictionary) -> Array:
    return LEVEL_CATALOGUE.npc_dialogue(self, data)


func _campaign_chapter_for_id(chapter_id: String) -> Dictionary:
    return LEVEL_CATALOGUE.campaign_chapter_for_id(self, chapter_id)


func _chapter_objective_text() -> String:
    return LEVEL_CATALOGUE.chapter_objective_text(self)


func _next_campaign_chapter_name() -> String:
    return LEVEL_CATALOGUE.next_campaign_chapter_name(self)


func _show_chapter_entry_message() -> void:
    LEVEL_CATALOGUE.show_chapter_entry_message(self)


func _boss_display_name(boss_data: Dictionary) -> String:
    return LEVEL_CATALOGUE.boss_display_name(self, boss_data)


func _chapter_file_ids() -> Array:
    return LEVEL_CATALOGUE.chapter_file_ids(self)


## Shared detached reward plan: derive unlocks/capacities without calling live
## inventory, narrative or stat helpers. No resource refills before durability.
func _prepare_inventory_progress(items: Dictionary, next_flags: Dictionary, next_currency: int) -> Dictionary:
    return LEVEL_CATALOGUE.prepare_inventory_progress(self, items, next_flags, next_currency)

func _publish_inventory_progress(plan: Dictionary, candidate: Dictionary) -> void:
    LEVEL_CATALOGUE.publish_inventory_progress(self, plan, candidate)

func _add_inventory_item(item_id: String, amount: int = 1, announce: bool = true) -> void:
    LEVEL_CATALOGUE.add_inventory_item(self, item_id, amount, announce)


func _add_currency(amount: int) -> void:
    LEVEL_CATALOGUE.add_currency(self, amount)


func _build_metsys_bridge() -> void:
    metsys_bridge = METSYS_BRIDGE_SCRIPT.new()
    metsys_bridge.name = "MetSysBridge"
    add_child(metsys_bridge)
    metsys_bridge.configure(config, world_width, world_height)


func _build_audio() -> void:
    LEVEL_AUDIO.build_audio(self)


## Separate stream loads remain ordinary prepare jobs so cancellation and the
## existing per-frame operation/time budget also apply between the two decodes.
func _begin_audio() -> void:
    LEVEL_AUDIO.begin_audio(self)


func _start_audio_explore() -> void:
    LEVEL_AUDIO.start_audio_explore(self)


func _start_audio_ambience() -> void:
    LEVEL_AUDIO.start_audio_ambience(self)


## 音频设置面板开关键（V）：玩家基础键位由 player_controller 注册，这里只补自己的。
func _bind_audio_settings_key() -> void:
    LEVEL_AUDIO.bind_audio_settings_key(self)


## P0 总线保障（规格 §5.1）：default_bus_layout.tres 缺失或加载失败时动态补建。
## 幂等：章节切换重建场景时只补缺，并清理上一场景遗留的濒死低通 / duck 音量。
func _ensure_audio_buses() -> void:
    LEVEL_AUDIO.ensure_audio_buses(self)


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
        preload("res://scripts/room_reverb_mix.gd").set_baseline(reverb, float(params.get("wet", 0.25)))
        reverb.predelay_msec = float(params.get("predelay_msec", 20.0))
        if params.has("predelay_feedback"):
            reverb.predelay_feedback = float(params.get("predelay_feedback", 0.0))


## 战斗/演出 ducking（规格 §5.3）：BGM 总线压低 duck_db dB，保持 seconds 秒后回弹。
## AudioDirector 在场时转调（回弹基准含用户音量），缺席时保持旧行为。
## headless 下 AudioServer 照常可写、tween 随场景销毁，安全 no-op。
func duck_bgm(duck_db: float, seconds: float) -> void:
    LEVEL_AUDIO.duck_bgm(self, duck_db, seconds)


func _set_bgm_bus_volume_db(value: float) -> void:
    LEVEL_AUDIO.set_bgm_bus_volume_db(self, value)


## 濒死混音态（规格 §5.5）：HP==1 时 BGM 总线挂 800Hz 低通 + 55-60 BPM 心跳
## 循环（自产 player_low_hp_heartbeat.wav，不与音乐 BPM 同步）；HP 回升/死亡移除。
func _set_low_hp_audio(active: bool) -> void:
    LEVEL_AUDIO.set_low_hp_audio(self, active)


func _start_low_hp_heartbeat() -> void:
    LEVEL_AUDIO.start_low_hp_heartbeat(self)


func _first_existing_bus(bus_names: Array) -> String:
    return LEVEL_AUDIO.first_existing_bus(self, bus_names)


func _stop_low_hp_heartbeat() -> void:
    LEVEL_AUDIO.stop_low_hp_heartbeat(self)


func _should_autoplay_audio() -> bool:
    return LEVEL_AUDIO.should_autoplay_audio(self)


## 旧版单播放器 BGM 切换：仅作 AudioDirector 缺席时的兜底路径。
## 无缝循环由 load_cached(looped=true) 承担；缓存对同路径返回同一对象，
## 因此下方 stream 同一性比较的"同曲去重"再次生效（不重头重播）。
func _switch_bgm(audio_key: String) -> void:
    LEVEL_AUDIO.switch_bgm(self, audio_key)


func _ensure_bgm_player() -> void:
    LEVEL_AUDIO.ensure_bgm_player(self)


func _play_sfx(audio_key: String, volume_db: float = -7.0) -> void:
    LEVEL_AUDIO.play_sfx(self, audio_key, volume_db)


func _attach_pending_sfx(instance_id: int) -> void:
    LEVEL_AUDIO.attach_pending_sfx(self, instance_id)


func _cancel_pending_sfx() -> void:
    LEVEL_AUDIO.cancel_pending_sfx(self)


## UI 音走 UI 总线（干声），世界音走 SFXWorld 子总线（send→SFX 吃章节混响）。
func _sfx_bus_for_key(audio_key: String) -> String:
    return LEVEL_AUDIO.sfx_bus_for_key(self, audio_key)


func _load_audio_stream(audio_key: String) -> AudioStream:
    return LEVEL_AUDIO.load_audio_stream(self, audio_key)


## 场景切换不截断的一次性音（章节切换线音）：播放器挂 tree root，播完自毁。
func _play_sfx_persistent(audio_key: String, volume_db: float = -7.0) -> void:
    LEVEL_AUDIO.play_sfx_persistent(self, audio_key, volume_db)


## 同事件多变体随机轮播（Kenney 变体组用）。
func _play_sfx_random(audio_keys: Array, volume_db: float = -7.0) -> void:
    LEVEL_AUDIO.play_sfx_random(self, audio_keys, volume_db)


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
    LEVEL_OVERLAYS.build_backpack_overlay(self)

func _build_map_overlay() -> void:
    MAP_OVERLAY.build_map_overlay(self)


# 巡礼愿板最小闭环（任务设计文档 §3 schema 子集）。章节配置可选 "wish_board"
# 数组：{id, title, desc, kind, target_flag, reward_currency}。target_flag 在
# story_flags 中翻转即视为完成，完成时经 _add_currency 发奖一次并记
# wish_claimed_<id> flag（随 story_flags 跨章携带，不重复发奖）。
# 没有该字段的章节不建面板、不做任何检查，行为完全不变。
func _wish_board_entries() -> Array:
    return WISH_TOPICS.wish_board_entries(self)


func _build_wish_board_overlay() -> void:
    WISH_TOPICS.build_wish_board_overlay(self)


func _wish_claim_flag(wish: Dictionary) -> String:
    return WISH_TOPICS.wish_claim_flag(self, wish)


func _check_wish_board_rewards(announce: bool = true) -> void:
    WISH_TOPICS.check_wish_board_rewards(self, announce)


func _refresh_wish_board_overlay() -> void:
    WISH_TOPICS.refresh_wish_board_overlay(self)


func _toggle_backpack() -> void:
    LEVEL_OVERLAYS.toggle_backpack(self)


func _toggle_map() -> void:
    MAP_OVERLAY.toggle_map(self)


# ---- 音频设置覆盖层（音量四滑条，复用背包面板构建模式）----

func _build_settings_overlay() -> void:
    LEVEL_OVERLAYS.build_settings_overlay(self)

func _toggle_audio_settings() -> void:
    LEVEL_OVERLAYS.toggle_audio_settings(self)


func _settings_selection_clamped() -> int:
    return LEVEL_OVERLAYS.settings_selection_clamped(self)


func _move_settings_selection(delta: int) -> void:
    LEVEL_OVERLAYS.move_settings_selection(self, delta)


func _adjust_settings_volume(delta: float) -> void:
    LEVEL_OVERLAYS.adjust_settings_volume(self, delta)


func _refresh_settings_overlay() -> void:
    LEVEL_OVERLAYS.refresh_settings_overlay(self)


func _close_overlays() -> void:
    LEVEL_OVERLAYS.close_overlays(self)


## 玩家输入闸（契约 ui_input_locked）：任一 overlay 开合即同步，锁移动/瞄准
## 不锁 Esc/UI 键；player_controller 侧按该标志忽略 move_left/right 与 aim_up/down。
func _sync_ui_input_lock() -> void:
    LEVEL_OVERLAYS.sync_ui_input_lock(self)


## 对话面板关闭时归还 BGM/Ambience 压低（所有关闭路径共用：Esc、走远、切换 overlay）。
func _notify_dialogue_closed() -> void:
    LEVEL_OVERLAYS.notify_dialogue_closed(self)


# 背包分区顺序：印记/证词等剧情要物靠前，材料殿后；分区标题仅作视觉分组。
const BACKPACK_SECTIONS := [
    ["探索工具 Tools", "Tools"],
    ["能力 Abilities", "Abilities"],
    ["铭饰 Charms", "Charms"],
    ["升级 Upgrades", "Upgrades"],
    ["圣物 Relics", "Relics"],
    ["印记与要物 Quest", "Quest"],
    ["材料 Materials", "Materials"]
]


func _refresh_backpack_overlay(render_inventory: bool = true) -> void:
    LEVEL_OVERLAYS.refresh_backpack_overlay(self, render_inventory)


func _inventory_ids_for_category(category: String) -> Array[String]:
    return LEVEL_OVERLAYS.inventory_ids_for_category(self, category)


func _selection_marker(item_id: String) -> String:
    return LEVEL_OVERLAYS.selection_marker(self, item_id)


func _backpack_selection_clamped() -> int:
    return LEVEL_OVERLAYS.backpack_selection_clamped(self)


func _move_backpack_selection(delta: int) -> void:
    LEVEL_OVERLAYS.move_backpack_selection(self, delta)


# 详情区：选中物品的完整铭文（多行保留分行；功能行随描述一起展示）。
func _refresh_backpack_detail() -> void:
    LEVEL_OVERLAYS.refresh_backpack_detail(self)


func _inventory_line_for_category(category: String) -> String:
    return LEVEL_OVERLAYS.inventory_line_for_category(self, category)


func _update_room_visit() -> void:
    LEVEL_ROOMS.update_room_visit(self)


## The five echo rooms of the silent crown each answer the first visit with the
## chapter's low bell phrase. `visited_rooms` is saved, so a revisit stays quiet.
func _play_echo_room_beat(room: Dictionary) -> bool:
    return LEVEL_ROOMS.play_echo_room_beat(self, room)


func _room_for_x(world_x: float, legacy_only: bool = false) -> Dictionary:
    return LEVEL_ROOMS.room_for_x(self, world_x, legacy_only)


func _room_for_position(world_position: Vector2) -> Dictionary:
    return LEVEL_ROOMS.room_for_position(self, world_position)


func _room_layout_rect(room_data: Dictionary) -> Rect2:
    return LEVEL_ROOMS.room_layout_rect(self, room_data)


func _map_room_by_id(room_id: String) -> Dictionary:
    return MAP_OVERLAY.map_room_by_id(self, room_id)


func _rect_contains_position(rect: Rect2, position_value: Vector2, padding: float = 0.0) -> bool:
    return LEVEL_ROOMS.rect_contains_position(self, rect, position_value, padding)


func _room_contains_position(room_data: Dictionary, world_position: Vector2) -> bool:
    return LEVEL_ROOMS.room_contains_position(self, room_data, world_position)


func _room_name(room_id: String) -> String:
    return LEVEL_ROOMS.room_name(self, room_id)


func _room_is_visited(room_id: String) -> bool:
    return LEVEL_ROOMS.room_is_visited(self, room_id)


func _refresh_map_overlay() -> void:
    MAP_OVERLAY.refresh_map_overlay(self)


func _map_world_to_overlay(world_position: Vector2, layout_bounds: Rect2, draw_size: Vector2) -> Vector2:
    return MAP_OVERLAY.map_world_to_overlay(self, world_position, layout_bounds, draw_size)


func _add_map_pin(world_position: Vector2, draw_width: float, base_y: float, depth_step: float, color: Color, size_value: Vector2 = Vector2(9, 9), layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    MAP_OVERLAY.add_map_pin(self, world_position, draw_width, base_y, depth_step, color, size_value, layout_bounds, draw_size)


func _build_world_from_config() -> void:
    LEVEL_REGION_BUILD.build_world_from_config(self)


## Shared ordered plan: synchronous boot/fixtures and budgeted travel build the
## same authored content. One job may contain a complex object, not one node.
func _region_build_jobs() -> Array:
    return LEVEL_REGION_BUILD.region_build_jobs(self)


func _region_lift(data: Dictionary) -> void:
    LEVEL_REGION_BUILD.region_lift(self, data)


func _region_platform(data: Dictionary) -> void:
    LEVEL_REGION_BUILD.region_platform(self, data)


func _make_region_platform(data: Dictionary) -> StaticBody2D:
    return LEVEL_REGION_BUILD.make_region_platform(self, data)


func _region_gate(data: Dictionary) -> void:
    LEVEL_REGION_BUILD.region_gate(self, data)


func _finish_region_geometry() -> void:
    LEVEL_REGION_BUILD.finish_region_geometry(self)


func _spawn_seal_practice_targets() -> void:
    LEVEL_REGION_BUILD.spawn_seal_practice_targets(self)

## E02: each primary tool has a practice puppet beside the skill racks. The
## puppet runs real AI from its plan profile so the tool visibly acts on it.
func _spawn_tool_practice_targets() -> void:
    LEVEL_REGION_BUILD.spawn_tool_practice_targets(self)


func _in_tool_practice_room() -> bool:
    return LEVEL_REGION_BUILD.in_tool_practice_room(self)


## E02: the first time an equipped tool's suited encounter room is entered, say
## why the tool fits there. Shown once per room, kept in the save.
func _show_tool_encounter_hint() -> void:
    LEVEL_REGION_BUILD.show_tool_encounter_hint(self)

## W04: each planned hidden room leaks light into its entrance room. Coming
## near the crack says what the player notices, once; finding the room dims it.
func _spawn_history_prop(entry: Dictionary) -> void:
    LEVEL_REGION_BUILD.spawn_history_prop(self, entry)

func _read_history_prop(area: Area2D) -> void:
    LEVEL_REGION_BUILD.read_history_prop(self, area)

func _commit_history_prop(area: Area2D) -> void:
    LEVEL_REGION_BUILD.commit_history_prop(self, area)

func _spawn_hidden_route_clues() -> void:
    LEVEL_REGION_BUILD.spawn_hidden_route_clues(self)


## N05: once an ending is chosen, each region's main shrine shows what it changed.
func _spawn_ending_aftermath() -> void:
    ENDING_GATES.spawn_ending_aftermath(self)

func _notice_ending_aftermath() -> void:
    ENDING_GATES.notice_ending_aftermath(self)

## Saves from before these clues already record visits to the hidden rooms;
## a room the player has been in counts as found.
func _sync_hidden_route_clues_with_visits() -> void:
    LEVEL_REGION_BUILD.sync_hidden_route_clues_with_visits(self)


func _notice_hidden_route_clues() -> void:
    LEVEL_REGION_BUILD.notice_hidden_route_clues(self)


## Rooms the hidden route plan reaches through an environmental clue.
func _is_hidden_room(room_id: String) -> bool:
    return LEVEL_REGION_BUILD.is_hidden_room(self, room_id)


func _mark_hidden_route_found() -> void:
    LEVEL_REGION_BUILD.mark_hidden_route_found(self)

const SKILL_PRACTICE_HITS := 3
const SKILL_PRACTICE_WINDOW_MSEC := 1500

func get_skill_practice_progress(skill_id: String) -> Dictionary:
    return LEVEL_REGION_BUILD.get_skill_practice_progress(self, skill_id)

## Only a canonical rack's actual skill/guard contact can train. The cast
## sequence is captured by emitted effects; melee cannot borrow a recent cast.
func _on_skill_practice_hit(skill_id: String, target: Area2D=null, serial: int=0, contact_kind: String="skill") -> void:
    LEVEL_REGION_BUILD.on_skill_practice_hit(self, skill_id, target, serial, contact_kind)


func _environment_block(data: Dictionary) -> void:
    if flat_map_art != null:
        flat_map_art.add_environment_ornament(data)


func _spawn_player() -> void:
    LEVEL_REGION_BUILD.spawn_player(self)


func _build_hud() -> void:
    LEVEL_HUD_BUILD.build_hud(self)


func _hud_build_jobs() -> Array:
    return LEVEL_HUD_BUILD.hud_build_jobs(self)


func _begin_hud() -> void:
    LEVEL_HUD_BUILD.begin_hud(self)


func _build_interface_step(method: String, args: Array = []) -> void:
    LEVEL_HUD_BUILD.build_interface_step(self, method, args)


func _build_hud_labels() -> void:
    LEVEL_HUD_BUILD.build_hud_labels(self)


func _finish_hud() -> void:
    LEVEL_HUD_BUILD.finish_hud(self)

func _build_dialogue_overlay() -> void:
    LEVEL_HUD_BUILD.build_dialogue_overlay(self)

func _background() -> void:
    LEVEL_SCENERY.background(self)


func _background_jobs() -> Array:
    return LEVEL_SCENERY.background_jobs(self)


func _background_base() -> void:
    LEVEL_SCENERY.background_base(self)


func _background_art() -> void:
    LEVEL_SCENERY.background_art(self)


func _background_terrain_metadata() -> void:
    LEVEL_SCENERY.background_terrain_metadata(self)


func _background_landform(data: Dictionary) -> void:
    LEVEL_SCENERY.background_landform(self, data)


func _background_terrain_warm() -> void:
    LEVEL_SCENERY.background_terrain_warm(self)


func _background_cave() -> void:
    LEVEL_SCENERY.background_cave(self)


## Second half of the painted rock: body trim and rim chunks, in a build job of
## its own so the cave does not take one long frame on a first visit.
func _background_cave_surface() -> void:
    LEVEL_SCENERY.background_cave_surface(self)


func _background_shade() -> void:
    LEVEL_SCENERY.background_shade(self)


func _configure_player_camera() -> void:
    LEVEL_PLAYER_FRAME.configure_player_camera(self)


func _void_respawn() -> void:
    LEVEL_PLAYER_FRAME.void_respawn(self)


func _theme_background_color() -> Color:
    return LEVEL_SCENERY.theme_background_color(self)


func _background_layer(node_name: String, sprite_key: String, z_value: int, tint: Color = Color.WHITE) -> void:
    LEVEL_SCENERY.background_layer(self, node_name, sprite_key, z_value, tint)


func _platform(node_name: String, rect: Rect2, color: Color, material: String = "moss_stone", collision_role: String = "", warmed: StaticBody2D = null) -> StaticBody2D:
    return LEVEL_SCENERY.platform(self, node_name, rect, color, material, collision_role, warmed)


func _add_platform_readability_base(parent: Node, size_value: Vector2, material: String, fallback_color: Color) -> void:
    LEVEL_SCENERY.add_platform_readability_base(self, parent, size_value, material, fallback_color)


func _platform_body_color(material: String, fallback_color: Color) -> Color:
    return LEVEL_SCENERY.platform_body_color(self, material, fallback_color)


func _platform_edge_color(material: String) -> Color:
    return LEVEL_SCENERY.platform_edge_color(self, material)


func _add_platform_plate(parent: Node, local_center: Vector2, plate_size: Vector2, plate_color: Color, z_value: int) -> Polygon2D:
    return LEVEL_SCENERY.add_platform_plate(self, parent, local_center, plate_size, plate_color, z_value)


func _hazard(_data: Dictionary) -> void:
    LEVEL_SCENERY.hazard(self, _data)

func _add_hazard_visual(_area: Area2D, _kind: String, _size: Vector2) -> void:
    LEVEL_SCENERY.add_hazard_visual(self, _area, _kind, _size)

func _apply_original_prop(sprite: Sprite2D, key: String, height: float) -> void:
    LEVEL_SCENERY.apply_original_prop(self, sprite, key, height)

func _collectible(data: Dictionary) -> void:
    LEVEL_PROPS.collectible(self, data)


func _make_lever(data: Dictionary) -> Area2D:
    return LEVEL_PROPS.make_lever(self, data)


func _lever(data: Dictionary) -> void:
    LEVEL_PROPS.lever(self, data)


func _make_boss_door(data: Dictionary) -> Area2D:
    return LEVEL_PROPS.make_boss_door(self, data)


func _boss_door(data: Dictionary) -> void:
    LEVEL_PROPS.boss_door(self, data)


func _chapter_exit(data: Dictionary) -> void:
    LEVEL_PROPS.chapter_exit(self, data)


func _make_save_point(data: Dictionary) -> Area2D:
    return LEVEL_PROPS.make_save_point(self, data)


func _save_point(data: Dictionary) -> void:
    LEVEL_PROPS.save_point(self, data)


func _animate_save_point(area: Area2D, marker: Sprite2D, ring: Line2D) -> Array:
    return LEVEL_PROPS.animate_save_point(self, area, marker, ring)


func _play_save_point_activation(area: Area2D) -> void:
    LEVEL_PROPS.play_save_point_activation(self, area)


func _make_npc(data: Dictionary) -> Area2D:
    return LEVEL_PROPS.make_npc(self, data)


func _npc(data: Dictionary) -> void:
    LEVEL_PROPS.npc(self, data)


func _resolve_enemy_spawn_position(data: Dictionary) -> Vector2:
    return ENEMY_PLACEMENT.resolve_enemy_spawn_position(self, data)


func _safe_enemy_spawn_on_platform(data: Dictionary, requested: Vector2, platform_id: String, rect: Rect2, clearance: float) -> Vector2:
    return ENEMY_PLACEMENT.safe_enemy_spawn_on_platform(self, data, requested, platform_id, rect, clearance)


func _fallback_enemy_spawn_position(data: Dictionary, requested: Vector2, clearance: float, preferred_platform_id: String = "") -> Vector2:
    return ENEMY_PLACEMENT.fallback_enemy_spawn_position(self, data, requested, clearance, preferred_platform_id)


func _enemy_spawn_visual_height(data: Dictionary) -> float:
    return ENEMY_PLACEMENT.enemy_spawn_visual_height(self, data)


func _enemy_spawn_rect_clear(position_value: Vector2, half_width: float = 36.0, visual_height: float = 104.0, floor_platform_id: String = "") -> bool:
    return ENEMY_PLACEMENT.enemy_spawn_rect_clear(self, position_value, half_width, visual_height, floor_platform_id)


func _enemy_spawn_platform_allowed(platform_id: String, rect: Rect2) -> bool:
    return ENEMY_PLACEMENT.enemy_spawn_platform_allowed(self, platform_id, rect)


func _platform_under_position(position_value: Vector2, clearance: float = 40.0) -> String:
    return LEVEL_RESIDENTS.platform_under_position(self, position_value, clearance)


func _enemy_platform_movement_bounds(platform_id: String, spawn_position: Vector2, data: Dictionary) -> Array:
    return ENEMY_PLACEMENT.enemy_platform_movement_bounds(self, platform_id, spawn_position, data)


## The subset of _enemy_spawn_rect_clear's blockers that can intersect any
## actor rect inside `sweep` standing at `floor_y` (same filters).
func _enemy_walk_obstacles(sweep: Rect2, floor_y: float, floor_platform_id: String) -> Dictionary:
    return LEVEL_RESIDENTS.enemy_walk_obstacles(self, sweep, floor_y, floor_platform_id)


func _enemy_walk_clear(position_value: Vector2, half_width: float, visual_height: float, obstacles: Dictionary) -> bool:
    return LEVEL_RESIDENTS.enemy_walk_clear(self, position_value, half_width, visual_height, obstacles)

func _spawn_normal_enemies() -> void:
    LEVEL_RESIDENTS.spawn_normal_enemies(self)


func _take_gameplay_prefab(kind: String, data: Dictionary, profile: Dictionary = {}) -> Area2D:
    return LEVEL_RESIDENTS.take_gameplay_prefab(self, kind, data, profile)

func _make_enemy_prefab(data: Dictionary, profile: Dictionary) -> Area2D:
    return LEVEL_RESIDENTS.make_enemy_prefab(self, data, profile)

func _create_gameplay_prefab(kind: String, data: Dictionary, prepared: Dictionary) -> Area2D:
    return LEVEL_RESIDENTS.create_gameplay_prefab(self, kind, data, prepared)


func _build_resident_interaction(kind: String, data: Dictionary) -> Area2D:
    return LEVEL_RESIDENTS.build_resident_interaction(self, kind, data)


func _release_resident_interaction(kind: String, id: String, area: Area2D) -> bool:
    return LEVEL_RESIDENTS.release_resident_interaction(self, kind, id, area)


func _world_npc_residency_position(npc_id: String, fallback: Vector2) -> Vector2:
    return LEVEL_RESIDENTS.world_npc_residency_position(self, npc_id, fallback)


func _enemy(data: Dictionary) -> Area2D:
    return LEVEL_RESIDENTS.enemy(self, data)


func _spawn_boss() -> void:
    LEVEL_BOSS.spawn_boss(self)


func _start_boss_trial() -> void:
    LEVEL_BOSS.start_boss_trial(self)


func _set_boss_arena_locked(locked: bool) -> void:
    LEVEL_BOSS.set_boss_arena_locked(self, locked)


## B04: optional challenge shrine / sealed room / optional boss helpers.
func _optional_challenge(challenge_id: String) -> Dictionary:
    return OPTIONAL_CHALLENGES.optional_challenge(self, challenge_id)


func _challenge_shrine_from_interactive(data: Dictionary) -> void:
    OPTIONAL_CHALLENGES.challenge_shrine_from_interactive(self, data)


func _challenge_shrine(challenge: Dictionary) -> void:
    OPTIONAL_CHALLENGES.challenge_shrine(self, challenge)


func _challenge_tracks_ready(challenge: Dictionary) -> bool:
    return OPTIONAL_CHALLENGES.challenge_tracks_ready(self, challenge)


func _hunt_track(challenge: Dictionary, track: Dictionary) -> void:
    OPTIONAL_CHALLENGES.hunt_track(self, challenge, track)


func _activate_hunt_track(area: Area2D) -> void:
    OPTIONAL_CHALLENGES.activate_hunt_track(self, area)


func _activate_challenge_shrine(area: Area2D) -> void:
    OPTIONAL_CHALLENGES.activate_challenge_shrine(self, area)


func _challenge_lock_inside_x(challenge: Dictionary, lock_rect: Rect2) -> float:
    return OPTIONAL_CHALLENGES.challenge_lock_inside_x(self, challenge, lock_rect)


func _is_optional_challenge_spawn(spawn_id: String) -> bool:
    return OPTIONAL_CHALLENGES.is_optional_challenge_spawn(self, spawn_id)


func _start_optional_challenge(challenge: Dictionary) -> void:
    OPTIONAL_CHALLENGES.start_optional_challenge(self, challenge)


func _clear_active_challenge(grant_if_empty: bool) -> void:
    OPTIONAL_CHALLENGES.clear_active_challenge(self, grant_if_empty)


## The seal only closes one entrance. Walking out through the other side ends
## the attempt: the foes go, the seal opens and the bell can be rung again later.
func _abort_challenge_if_left_room() -> void:
    OPTIONAL_CHALLENGES.abort_challenge_if_left_room(self)


func _on_challenge_enemy_died(spawn_id: String) -> void:
    OPTIONAL_CHALLENGES.on_challenge_enemy_died(self, spawn_id)


func _challenge_pending_flag(challenge: Dictionary) -> String:
    return OPTIONAL_CHALLENGES.challenge_pending_flag(self, challenge)


func _grant_optional_challenge_reward(challenge: Dictionary) -> void:
    OPTIONAL_CHALLENGES.grant_optional_challenge_reward(self, challenge)


func _lock_boss_camera() -> void:
    LEVEL_BOSS.lock_boss_camera(self)


func _boss_arena_lock_rect() -> Rect2:
    return LEVEL_BOSS.boss_arena_lock_rect(self)


func _boss_gate_position() -> Vector2:
    return LEVEL_BOSS.boss_gate_position(self)


func _floor_top_near_x(world_x: float) -> float:
    return LEVEL_BOSS.floor_top_near_x(self, world_x)


func _on_hazard_body_entered(_body: Node, _area: Area2D) -> void:
    LEVEL_PICKUPS.on_hazard_body_entered(self, _body, _area)

func _forget_world_pickup(instance_id: int) -> void:
    LEVEL_PICKUPS.forget_world_pickup(self, instance_id)

func _pickup_retry(area: Area2D, item_id: String, reason: String) -> void:
    LEVEL_PICKUPS.pickup_retry(self, area, item_id, reason)

func _on_collectible_body_entered(body: Node, area: Area2D) -> void:
    LEVEL_PICKUPS.on_collectible_body_entered(self, body, area)

## Workshop capacity fragments report their set progress, or the finished
## item when a set completes; any other pickup keeps its own label.
func _capacity_fragment_message(item_id: String, fallback: String) -> String:
    return LEVEL_PICKUPS.capacity_fragment_message(self, item_id, fallback)


func _on_collectible_body_entered_legacy(body: Node, area: Area2D) -> void:
    LEVEL_PICKUPS.on_collectible_body_entered_legacy(self, body, area)


## play_unlock_sfx 仅在"拾取能力当场开门"时为 true；章节加载/调试同步保持静音，
## 避免开场把已解锁门的开门音一次性齐鸣。
func _refresh_ability_gates(play_unlock_sfx: bool = false) -> void:
    LEVEL_PICKUPS.refresh_ability_gates(self, play_unlock_sfx)


func _owns_permanent_item(item_id: String) -> bool:
    return LEVEL_PICKUPS.owns_permanent_item(self, item_id)

func _sync_player_abilities() -> void:
    LEVEL_PICKUPS.sync_player_abilities(self)


func _unlock_ability_gate(gate_id: String, unlock_sfx_key: String = "") -> void:
    LEVEL_PICKUPS.unlock_ability_gate(self, gate_id, unlock_sfx_key)


func _on_interactable_entered(body: Node, area: Area2D) -> void:
    LEVEL_INTERACTION.on_interactable_entered(self, body, area)


func _on_interactable_exited(body: Node, area: Area2D) -> void:
    LEVEL_INTERACTION.on_interactable_exited(self, body, area)


func _can_interact_with_world(allow_dialogue: bool = false) -> bool:
    return LEVEL_INTERACTION.can_interact_with_world(self, allow_dialogue)


func _try_interact() -> void:
    LEVEL_INTERACTION.try_interact(self)


func interaction_target(prompt_candidate: Area2D = null) -> Area2D:
    return LEVEL_INTERACTION.interaction_target(self, prompt_candidate)


func _nearest_interactable(radius: float) -> Area2D:
    return LEVEL_INTERACTION.nearest_interactable(self, radius)


## A portal inside a room still closed by an ability gate must not be used from
## outside it: its return would put the player inside the closed room. While
## any gate into the portal's room stands, the portal needs a clear line to the
## player (the room's own walls and floor count, not only the gate). A portal
## that leads into a room every way into which is a standing ability gate is
## closed outright, whichever side it is reached from.
func _behind_locked_gate(portal: Area2D) -> bool:
    return LEVEL_INTERACTION.behind_locked_gate(self, portal)


func _room_has_standing_gate(room_id: String) -> bool:
    return LEVEL_INTERACTION.room_has_standing_gate(self, room_id)


## True while a room can only be entered through ability gates and one of the
## gates leading into it from another room still stands.
func _room_sealed_by_gates(room_id: String) -> bool:
    return LEVEL_INTERACTION.room_sealed_by_gates(self, room_id)


func _better_interaction_target(area: Area2D, distance: float, current: Area2D, current_distance: float) -> bool:
    return LEVEL_INTERACTION.better_interaction_target(self, area, distance, current, current_distance)


func _activate_lever(area: Area2D) -> void:
    LEVEL_ACTIVATION.activate_lever(self, area)


func _open_shortcut(shortcut_id: String = "") -> void:
    LEVEL_ACTIVATION.open_shortcut(self, shortcut_id)


func _open_all_shortcuts(show_toast: bool = true) -> void:
    LEVEL_ACTIVATION.open_all_shortcuts(self, show_toast)


func _activate_save_point(area: Area2D) -> void:
    LEVEL_ACTIVATION.activate_save_point(self, area)


func _activate_chapter_exit(area: Area2D) -> void:
    LEVEL_ACTIVATION.activate_chapter_exit(self, area)


func _chapter_exit_can_open(area: Area2D) -> bool:
    return LEVEL_ACTIVATION.chapter_exit_can_open(self, area)


func _transition_to_next_chapter(next_config_path: String) -> void:
    LEVEL_ACTIVATION.transition_to_next_chapter(self, next_config_path)


# 结局门运行时（剧情蓝图 §12：Boss 后三扇门 + 结局文本 + 存档 flag 的最小闭环）。
# 数据契约（章节 JSON 可选 "ending_gates" 数组，缺省章节行为完全不变）：
#   {id, ending("ending_a"|"ending_b"|"ending_c"), label, position:[x,y](可选，
#    缺省绕 Boss 尸位/玩家横向散开), requires:{items:[], flags:[]},
#    message(达成结局文案), reject_message(可选，缺项拒绝提示)}
func _ending_gate_entries() -> Array:
    return ENDING_GATES.ending_gate_entries(self)


## announce: the doors appear at the final defeat (the ending-doors beat plays
## once); reloading a completed region restores them silently.
func _spawn_ending_gates(announce: bool = false) -> void:
    ENDING_GATES.spawn_ending_gates(self, announce)


func _activate_ending_gate(area: Area2D) -> void:
    ENDING_GATES.activate_ending_gate(self, area)


func _activate_boss_gate() -> void:
    LEVEL_ACTIVATION.activate_boss_gate(self)


func _talk_to_npc(area: Area2D) -> void:
    LEVEL_DIALOGUE.talk_to_npc(self, area)


# Six-state dialogue machine (doc 2.1/2.3). Priority: first_meet (only while
# npc_met_<id> unset) -> true_ending_branch -> late_game -> sidequest_done ->
# after_boss -> after_ability -> repeat. NPCs without story_dialogue fall back
# to the legacy dialogue array untouched.
func _resolve_npc_lines(area: Area2D) -> Array:
    return WISH_TOPICS.resolve_npc_lines(self, area)


# "demo_ch01_moss_bell_court" -> "ch01" (used for boss_down_<chapter> flags).
func _chapter_story_id() -> String:
    return LEVEL_DIALOGUE.chapter_story_id(self)


## A zero/negative/fractional key is not an offering. JSON whole-number floats
## remain compatible with legacy in-memory inventories; booleans are rejected.
func wish_offering_available(item_id: String) -> bool:
    return WISH_TOPICS.wish_offering_available(self, item_id)

## Include a fully read final line in a wish's candidate, rather than saving
## dialogue first and risking a durable completed quest without its reward.
func _wish_dialogue_candidate(area: Area2D, flags: Dictionary, wallet: int) -> Dictionary:
    return WISH_TOPICS.wish_dialogue_candidate(self, area, flags, wallet)

## Pure candidate shared by preview and the one-write transaction.
func _wish_topic_plan(quest: Dictionary, area: Area2D) -> Dictionary:
    return WISH_TOPICS.wish_topic_plan(self, quest, area)

func quote_wish_topic(quest: Dictionary, area: Area2D) -> Dictionary:
    return WISH_TOPICS.quote_wish_topic(self, quest, area)

## Prepare a privately owned checkpoint without invoking inventory/story helpers:
## those helpers may save recursively, apply Player stats, or announce rewards.
## Publish inventory, unlocks and capacities only after the one durable write.
func perform_wish_topic(quest: Dictionary, area: Area2D) -> Dictionary:
    return WISH_TOPICS.perform_wish_topic(self, quest, area)


func _set_story_flag(flag: String) -> void:
    LEVEL_DIALOGUE.set_story_flag(self, flag)


# true_ending_testimony_complete flips once all six testimonies are held
# (doc 2.1: true_ending_branch gate).
func _refresh_testimony_chain_flag() -> void:
    LEVEL_DIALOGUE.refresh_testimony_chain_flag(self)


# One-shot ambient whispers (绯线低语, config `whispers`). trigger:
# "enter_room" keyed by room_id, "pickup_item" keyed by item_id.
func _trigger_whispers(trigger: String, key: String) -> void:
    LEVEL_DIALOGUE.trigger_whispers(self, trigger, key)


func _show_dialogue(area: Area2D, line: String) -> void:
    LEVEL_DIALOGUE.show_dialogue(self, area, line)


func _on_enemy_died(spawn_id: String, is_boss: bool, kind: String) -> void:
    LEVEL_ENCOUNTERS.on_enemy_died(self, spawn_id, is_boss, kind)


## B04: an elite is an optional, harder fight. Its first defeat pays a one-time
## bonus (kept in story flags), so respawned elites cannot be farmed for it.
const ELITE_FIRST_CURRENCY := 30
const ELITE_FIRST_MATERIALS := 2

func _spawn_is_elite(spawn_id: String) -> bool:
    return LEVEL_ENCOUNTERS.spawn_is_elite(self, spawn_id)

## Returns the reward message ("" when no bonus) so a following toast can keep it.
func _grant_elite_first_defeat(spawn_id: String, drop_item: String) -> String:
    return LEVEL_ENCOUNTERS.grant_elite_first_defeat(self, spawn_id, drop_item)


func _on_player_respawned() -> void:
    LEVEL_ENCOUNTERS.on_player_respawned(self)


func _reset_encounters_after_player_death() -> void:
    LEVEL_ENCOUNTERS.reset_encounters_after_player_death(self)


func _respawn_boss_trial_boss() -> void:
    LEVEL_ENCOUNTERS.respawn_boss_trial_boss(self)


func _open_post_boss_route() -> void:
    LEVEL_ENCOUNTERS.open_post_boss_route(self)


func _is_post_boss_blocker(platform_id: String) -> bool:
    return LEVEL_ENCOUNTERS.is_post_boss_blocker(self, platform_id)


func _spawn_route_open_effect(position_value: Vector2) -> void:
    LEVEL_ENCOUNTERS.spawn_route_open_effect(self, position_value)


func _on_hp_changed(value: int) -> void:
    LEVEL_HUD.on_hp_changed(self, value)


func _on_energy_changed(_value: int, _maximum: int) -> void:
    LEVEL_HUD.on_energy_changed(self, _value, _maximum)


func _refresh_hud() -> void:
    LEVEL_HUD.refresh_hud(self)


func _toast(text: String) -> void:
    LEVEL_HUD.toast(self, text)


## 证词/失声印记/真名信物类物品的拾取展示（圣典 §7）：普通材料不打扰，
## 关键物品用独立横幅停留更久，后续 toast 不会盖掉它。headless 下纯 no-op 安全。
func _is_story_key_item(item_id: String) -> bool:
    return LEVEL_HUD.is_story_key_item(self, item_id)


func _announce_lore_pickup(item_id: String) -> void:
    LEVEL_HUD.announce_lore_pickup(self, item_id)


## The story banner stays longer than a toast and later toasts never cover it.
func _show_lore_banner(text: String) -> void:
    LEVEL_HUD.show_lore_banner(self, text)


# _process 驱动的横幅倒计时：不挂定时器/回调，headless 退出无残留。
func _tick_lore_banner(delta: float) -> void:
    LEVEL_HUD.tick_lore_banner(self, delta)


func _spawn_pickup_effect(world_position: Vector2) -> void:
    LEVEL_HUD.spawn_pickup_effect(self, world_position)


func get_demo_state() -> Dictionary:
    return LEVEL_DEMO_STATE.get_demo_state(self)


func _wish_claimed_total() -> int:
    return WISH_TOPICS.wish_claimed_total(self)


func _debug_collect_all_abilities() -> void:
    LEVEL_DEMO_STATE.debug_collect_all_abilities(self)


func _debug_clear_combat_route() -> void:
    LEVEL_DEMO_STATE.debug_clear_combat_route(self)


func _debug_open_all_shortcuts() -> void:
    LEVEL_DEMO_STATE.debug_open_all_shortcuts(self)


func _debug_start_boss() -> void:
    LEVEL_DEMO_STATE.debug_start_boss(self)


func _debug_kill_boss() -> void:
    LEVEL_DEMO_STATE.debug_kill_boss(self)


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
    return LEVEL_ROUTE_STATE.shortcut_is_lever_controlled(self, shortcut_id)


func _room_has_position_bounds(room_data: Dictionary) -> bool:
    return LEVEL_ROUTE_STATE.room_has_position_bounds(self, room_data)


func _room_containing_area(room_data: Dictionary, world_position: Vector2) -> float:
    return LEVEL_ROUTE_STATE.room_containing_area(self, room_data, world_position)


func _unlock_boss_route() -> void:
    LEVEL_ROUTE_STATE.unlock_boss_route(self)


func _open_combat_clear_route() -> void:
    LEVEL_ROUTE_STATE.open_combat_clear_route(self)


func get_build_system() -> RefCounted:
    return LEVEL_BUILD.get_build_system(self)

func _sync_player_build() -> void:
    LEVEL_BUILD.sync_player_build(self)


func _sync_hazard_trigger_sizes() -> void:
    LEVEL_BUILD.sync_hazard_trigger_sizes(self)

func _bind_build_inputs() -> void:
    LEVEL_BUILD.bind_build_inputs(self)

## Artisans who sell 校习 and make 改制 (E04); each recipe names its own maker.
const ARTISAN_NPCS := ["npc_rain_smith_liu", "npc_threadsmith_apprentice", "npc_beeswax_vendor"]

func _near_workstation(crafting: bool = false) -> bool:
    return LEVEL_BUILD.near_workstation(self, crafting)

## Read-only proximity query used by UI affordances and explicit quote actions.
func is_near_shrine() -> bool:
    return LEVEL_BUILD.is_near_shrine(self)

## U02: beside an artisan the build page opens on 强化, where 校习 is bought.
func is_near_artisan() -> bool:
    return LEVEL_BUILD.is_near_artisan(self)

## E04: which artisan is in reach; each one makes only their own 改制.
func near_artisan_id() -> String:
    return LEVEL_BUILD.near_artisan_id(self)

## E04: why this artisan cannot make the recipe yet; "" when only the price remains.
func artisan_craft_block(recipe: Dictionary) -> String:
    return LEVEL_BUILD.artisan_craft_block(self, recipe)

func _build_wallet_snapshot() -> Dictionary:
    return LEVEL_BUILD.build_wallet_snapshot(self)

func _set_build_wallet(wallet: Dictionary) -> void:
    LEVEL_BUILD.set_build_wallet(self, wallet)

func _rollback_build_transaction(build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> void:
    LEVEL_BUILD.rollback_build_transaction(self, build_before, wallet_before, materials_before)

func _finish_build_transaction(result: Dictionary, build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> Dictionary:
    return LEVEL_BUILD.finish_build_transaction(self, result, build_before, wallet_before, materials_before)

## Read-only availability used by both the HUD and the actual tool transaction.
func get_tool_readiness(id: String) -> Dictionary:
    return LEVEL_BUILD.get_tool_readiness(self, id)

func quote_loadout_restore(name: String) -> Dictionary:
    return LEVEL_BUILD.quote_loadout_restore(self, name)

func apply_reviewed_loadout(name: String, fingerprint: String) -> Dictionary:
    return LEVEL_BUILD.apply_reviewed_loadout(self, name, fingerprint)

func quote_craft_cart(request: Variant) -> Dictionary:
    return LEVEL_BUILD.quote_craft_cart(self, request)

func perform_build_action(action: String, id: String = "", extra: Variant = null) -> Dictionary:
    return LEVEL_BUILD.perform_build_action(self, action, id, extra)

func _toggle_build() -> void:
    LEVEL_BUILD.toggle_build(self)

## An ordinary strike on a breakable floor: the floor shudders but holds.
func _on_gate_struck(gate: Node, _point: Vector2) -> void:
    LEVEL_BUILD.on_gate_struck(self, gate, _point)


func _on_ability_action(ability_id: String, origin: Vector2, direction: Vector2) -> void:
    LEVEL_BUILD.on_ability_action(self, ability_id, origin, direction)

func get_save_slots() -> Array:
    return LEVEL_SAVE_SLOTS.get_save_slots(self)

func quote_save_operation(action: String, index: int) -> Dictionary:
    return LEVEL_SAVE_SLOTS.quote_save_operation(self, action, index)

func perform_save_operation(action: String, index: int, fingerprint: String) -> Dictionary:
    return LEVEL_SAVE_SLOTS.perform_save_operation(self, action, index, fingerprint)

func get_journey_history_page(offset: int, limit: int) -> Dictionary:
    return LEVEL_SAVE_SLOTS.get_journey_history_page(self, offset, limit)

func get_journey_archive_detail(file: String, sha: String) -> Dictionary:
    return LEVEL_SAVE_SLOTS.get_journey_archive_detail(self, file, sha)

func get_journey_history() -> Dictionary:
    return LEVEL_SAVE_SLOTS.get_journey_history(self)

func select_save_slot(index: int) -> bool:
    return LEVEL_SAVE_SLOTS.select_save_slot(self, index)

func _replace_with_save_slot(index: int, path_override: String = "") -> void:
    LEVEL_SAVE_SLOTS.replace_with_save_slot(self, index, path_override)

func restore_save_backup(index: int = 0) -> bool:
    return LEVEL_SAVE_SLOTS.restore_save_backup(self, index)

## G02: the return knot is left at the last place the player stood on
## permanent terrain. A lift basket travels away, and ability gates or fragile
## floors can be opened later, so standing on them never moves the knot there.
func _update_safe_ground() -> void:
    LEVEL_GROUND.update_safe_ground(self)


func _standing_on_permanent_floor() -> bool:
    return LEVEL_GROUND.standing_on_permanent_floor(self)


func _ground_is_hazardous(_position_value: Vector2) -> bool:
    return LEVEL_GROUND.ground_is_hazardous(self, _position_value)

func _record_death_cache() -> void:
    LEVEL_GROUND.record_death_cache(self)


func _spawn_death_cache() -> void:
    LEVEL_GROUND.spawn_death_cache(self)

func _recover_death_cache(area: Area2D) -> void:
    LEVEL_GROUND.recover_death_cache(self, area)


func _hold_actor_support(platform_id: String) -> void:
    LEVEL_GROUND.hold_actor_support(self, platform_id)


func _ensure_collision_segment(from: Vector2, to: Vector2) -> void:
    LEVEL_GROUND.ensure_collision_segment(self, from, to)


func _rock_ray_hit(from: Vector2, to: Vector2) -> Dictionary:
    return LEVEL_GROUND.rock_ray_hit(self, from, to)


func _walking_world_passage() -> bool:
    return LEVEL_GROUND.walking_world_passage(self)


func _world_collision_ready() -> bool:
    return LEVEL_GROUND.world_collision_ready(self)


func _release_region_platforms() -> void:
    LEVEL_GROUND.release_region_platforms(self)

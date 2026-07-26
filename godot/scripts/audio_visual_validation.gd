extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"
var failures := 0
const AUDIO_PATHS := [
    "res://assets/audio/bgm/ch01_cave_loop.ogg",
    "res://assets/audio/bgm/boss_rust_crown_loop.ogg",
    "res://assets/audio/sfx/player_attack.ogg",
    "res://assets/audio/sfx/player_hook.ogg",
    "res://assets/audio/sfx/player_dash.ogg",
    "res://assets/audio/sfx/player_jump.ogg",
    "res://assets/audio/sfx/player_heal.ogg",
    "res://assets/audio/sfx/player_hurt.ogg",
    "res://assets/audio/sfx/enemy_hit.ogg",
    "res://assets/audio/sfx/heavy_hit.ogg",
    "res://assets/audio/sfx/pickup.ogg",
    "res://assets/audio/sfx/lever.ogg",
    "res://assets/audio/sfx/interact.ogg"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for path in AUDIO_PATHS:
        _assert(FileAccess.file_exists(path), "audio file exists: " + path)
        _assert(AudioStreamOggVorbis.load_from_file(path) != null, "audio stream loads: " + path)

    for path in [
        "res://assets/sprites/original_map/moss_cavern/platform_mid.png",
        "res://assets/sprites/original_map/moss_cavern/platform_cap_small.png",
        "res://assets/sprites/original_map/moss_cavern/wall.png",
        "res://assets/sprites/original_map/moss_cavern/map.png"
    ]:
        _assert(Image.load_from_file(path) != null, "CH01 original map texture loads: " + path)
    _assert(FileAccess.file_exists("res://assets/NOTICE.md"), "third-party asset notice exists")

    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var bgm := scene.get_node_or_null("BgmPlayer") as AudioStreamPlayer
    _assert(bgm != null and bgm.stream != null, "background music player is active")

    # P0 音频基建断言（音频规格 §5.1/§6.1）：五总线、BGM 归位、区域混响、duck、濒死低通。
    _assert(load("res://default_bus_layout.tres") as AudioBusLayout != null, "default bus layout resource loads")
    for bus_name in ["BGM", "SFX", "Ambience", "UI"]:
        _assert(AudioServer.get_bus_index(bus_name) != -1, "audio bus exists: " + bus_name)
    _assert(bgm != null and String(bgm.bus) == "BGM", "bgm player routed to BGM bus")
    var sfx_bus_index := AudioServer.get_bus_index("SFX")
    _assert(sfx_bus_index != -1 and _bus_has_effect(sfx_bus_index, "AudioEffectReverb"), "SFX bus carries chapter reverb")
    var ambience_bus_index := AudioServer.get_bus_index("Ambience")
    _assert(ambience_bus_index != -1 and _bus_has_effect(ambience_bus_index, "AudioEffectReverb"), "Ambience bus carries chapter reverb")
    _assert(scene.has_method("duck_bgm"), "main level exposes duck_bgm")
    scene.duck_bgm(-6.0, 0.1)
    var bgm_bus_index := AudioServer.get_bus_index("BGM")
    scene._set_low_hp_audio(true)
    _assert(_bus_has_effect(bgm_bus_index, "AudioEffectLowPassFilter"), "low hp lowpass engages on BGM bus")
    scene._set_low_hp_audio(false)
    _assert(not _bus_has_effect(bgm_bus_index, "AudioEffectLowPassFilter"), "low hp lowpass releases on BGM bus")

    var manifest := _load_manifest()
    _assert(int(manifest.get("version", 1)) >= 2, "AV manifest upgraded to v2")
    for block in ["buses", "sfx_catalog", "ambience_zones", "reverb_zones", "mix_states"]:
        _assert(manifest.has(block), "AV manifest v2 block present: " + block)

    var start_ground := scene.get_node_or_null("start_ground")
    _assert(start_ground != null, "start platform exists")
    _assert(_sprite_uses_original_map(start_ground.get_node_or_null("Material") as Sprite2D), "CH01 platform uses original map material")

    # ch1 箱庭重做后旧 vista_bridge 已移除，改用中央钟庭枢纽地板做同口径断言。
    var hub_floor := scene.get_node_or_null("hub_floor_w")
    _assert(hub_floor != null, "hub platform exists")
    if hub_floor != null:
        var hub_material := hub_floor.get_node_or_null("Material") as Sprite2D
        _assert(_sprite_uses_original_map(hub_material), "hub uses original CH01 material sprite")
        _assert(_count_textured_sprites(hub_floor) >= 1, "hub has an original CH01 material module")

    scene._toggle_map()
    await process_frame
    _assert(scene.map_panel.get_node_or_null("MapBackgroundArt") != null, "map overlay uses background art")

    scene.player.hp = scene.player.max_hp - 1
    scene.player.energy = scene.player.heal_energy_cost
    scene.player._try_heal()
    await process_frame
    _assert(_has_named_child(scene.player, "HealEffectRing"), "heal ring effect spawns")
    _assert(_has_named_child(scene.player, "HealThread"), "heal thread effect spawns")

    scene.player._start_attack(&"attack_1")
    _assert(_has_named_child(scene.player, "AttackSlashVfx"), "normal attack slash vfx spawns")
    _assert(_audio_children_on_bus(scene.player, "SFX"), "player sfx players routed to SFX bus")
    scene.player.attack_timer = 0.0
    scene.player._start_attack(&"hook_throw")
    _assert(_has_named_child(scene.player, "HookTrailVfx"), "hook trail vfx spawns")
    scene.player.attack_timer = 0.0
    scene.player._start_attack(&"attack_2")
    _assert(_has_named_child(scene.player, "SkillSlashVfx"), "skill slash vfx spawns")

    var enemy = _find_enemy(scene, "E01")
    _assert(enemy != null, "validation enemy exists")
    _assert(_enemy_has_runtime_visual(enemy), "validation enemy uses open gothicvania visual")
    scene.player._spawn_hit_confirm_vfx(enemy.global_position, &"attack_1")
    await process_frame
    _assert(_has_named_descendant(scene, "HitConfirmVfx"), "hit confirm vfx spawns")
    enemy._spawn_windup_vfx({"hit_width": 86.0, "hit_height": 58.0, "offset": 42.0, "windup": 0.18})
    enemy._spawn_attack_burst_vfx({"type": "melee", "hit_width": 86.0, "hit_height": 58.0, "offset": 42.0})
    _assert(_has_named_child(enemy, "EnemyWindupVfx"), "enemy windup vfx spawns")
    _assert(_has_named_child(enemy, "EnemyAttackBurstVfx"), "enemy attack burst vfx spawns")
    enemy.take_hit(1, 1)
    await process_frame
    _assert(_has_named_child(enemy, "HitSpark"), "enemy hit spark spawns")

    scene._debug_start_boss()
    await process_frame
    _assert(scene.boss_actor != null, "boss actor spawns for vfx validation")
    scene.boss_actor._spawn_attack_burst_vfx({"type": "aoe", "hit_width": 180.0, "hit_height": 90.0})
    _assert(_has_named_child(scene.boss_actor, "BossAttackBurstVfx"), "boss attack burst vfx spawns")

    scene._spawn_pickup_effect(Vector2(180.0, 140.0))
    await process_frame
    _assert(_has_named_descendant(scene, "PickupEffectRing"), "pickup effect ring spawns")

    _stop_audio_nodes(root)
    scene.queue_free()
    await process_frame
    await process_frame
    if failures == 0:
        print("AUDIO_VISUAL_VALIDATION_PASS audio=%d heal_effect=true hit_spark=true platform_art=true" % AUDIO_PATHS.size())
        quit(0)
    else:
        push_error("AUDIO_VISUAL_VALIDATION_FAIL failures=%d" % failures)
        quit(1)


func _bus_has_effect(bus_index: int, effect_class: String) -> bool:
    if bus_index < 0:
        return false
    for effect_index in AudioServer.get_bus_effect_count(bus_index):
        var effect := AudioServer.get_bus_effect(bus_index, effect_index)
        if effect != null and effect.get_class() == effect_class:
            return true
    return false


func _audio_children_on_bus(parent: Node, bus_name: String) -> bool:
    var found := false
    for child in parent.get_children():
        if child is AudioStreamPlayer2D:
            found = true
            if String(child.bus) != bus_name:
                return false
    return found


func _load_manifest() -> Dictionary:
    var file := FileAccess.open("res://data/audio_visual_manifest.json", FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _has_named_child(parent: Node, child_name: String) -> bool:
    for child in parent.get_children():
        if String(child.name) == child_name:
            return true
    return false


func _has_named_descendant(parent: Node, child_name: String) -> bool:
    if String(parent.name) == child_name:
        return true
    for child in parent.get_children():
        if _has_named_descendant(child, child_name):
            return true
    return false


func _count_textured_sprites(parent: Node) -> int:
    var count := 0
    for child in parent.get_children():
        var sprite := child as Sprite2D
        if sprite != null and sprite.texture != null:
            count += 1
    return count


func _sprite_uses_original_map(sprite: Sprite2D) -> bool:
    if sprite == null or sprite.texture == null:
        return false
    var source_path := String(sprite.get_meta("original_map_asset", sprite.texture.resource_path))
    return source_path.contains("/original_map/")


func _find_enemy(scene: Node, spawn_id: String):
    for enemy in scene.get_tree().get_nodes_in_group("enemy"):
        if String(enemy.get("spawn_id")) == spawn_id:
            return enemy
    return null


func _enemy_has_runtime_visual(enemy: Node) -> bool:
    var animated := enemy.get_node_or_null("EnemyAnimatedSprite") as AnimatedSprite2D
    if animated != null and animated.sprite_frames != null:
        return animated.sprite_frames.has_animation("idle") and animated.sprite_frames.get_frame_count("idle") > 0
    var static_sprite := enemy.get_node_or_null("EnemySprite") as Sprite2D
    if static_sprite != null and static_sprite.texture != null:
        return true
    var part_root := enemy.get_node_or_null("EnemyPartSprite")
    if part_root == null:
        return false
    for child in part_root.get_children():
        var part := child as Sprite2D
        if part != null and part.texture != null:
            return true
    return false


func _stop_audio_nodes(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stop()
        node.stream = null
    elif node is AudioStreamPlayer2D:
        node.stop()
        node.stream = null
    for child in node.get_children():
        _stop_audio_nodes(child)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    failures += 1

extends SceneTree
## Real-scene regression for death/overlay interactions and persistent boss rewards.
const SAVE := "user://world_interaction_safety_validation.json"
var checks := 0
var failures: Array[String] = []
var scene: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    create_timer(90.0).timeout.connect(func():
        _check(false, "interaction safety timed out")
        _finish())
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _clean()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_save_path = SAVE
    scene.world_resume = false
    scene.world_startup_options_enabled = false
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames()
    scene._close_overlays()
    var shrine: Area2D = _find_kind("save_point")
    var npc: Area2D = _find_kind("npc")
    _check(shrine != null and npc != null, "actual shrine and dialogue NPC exist")
    if shrine == null or npc == null:
        _finish()
        return
    scene.player.global_position = shrine.global_position
    scene.player.hp = 0
    scene.player.death_timer = 0.9
    scene.death_recorded = true
    var old_checkpoint: Vector2 = scene.active_spawn
    scene._try_interact()
    _check(scene.player.hp == 0 and scene.player.death_timer == 0.9, "F cannot cancel death at a shrine")
    scene._activate_save_point(shrine)
    _check(scene.player.hp == 0 and scene.active_spawn == old_checkpoint, "direct shrine callback cannot revive a dead player")
    _check(scene.death_recorded, "failed dead interaction does not reset death bookkeeping")
    var exit := Area2D.new()
    exit.set_meta("kind", "ending_exit")
    exit.set_meta("requires_demo_complete", false)
    scene.add_child(exit)
    var prior_win: String = scene.win_label.text
    scene._activate_chapter_exit(exit)
    _check(scene.win_label.text == prior_win and not scene.chapter_transitioning, "Area-triggered exit is inert during death")
    var ending := Area2D.new()
    ending.set_meta("ending", "ending_a")
    scene.add_child(ending)
    scene._activate_ending_gate(ending)
    _check(not scene.story_flags.has("ending_chosen"), "dead player cannot commit an ending")
    scene.boss_unlocked = true
    scene._activate_boss_gate()
    _check(not scene.boss_spawned, "dead player cannot wake a boss")
    scene.player.hp = 1
    scene.player.death_timer = 0.0
    scene.chapter_transitioning = true
    scene._activate_save_point(shrine)
    _check(scene.player.hp == 1 and scene.active_spawn == old_checkpoint, "pending scene transition blocks shrine mutation")
    scene.chapter_transitioning = false
    for overlay in ["settings", "map", "backpack", "build", "new_journey"]:
        scene.active_overlay = overlay
        scene._try_interact()
        _check(scene.player.hp == 1, "overlay F does not activate world: " + overlay)
    scene.active_overlay = ""
    scene._activate_save_point(shrine)
    _check(scene.player.hp == scene.player.max_hp and scene.active_save_point_id == String(shrine.name), "alive player still rests normally")
    scene.player.global_position = npc.global_position
    scene._talk_to_npc(npc)
    _check(scene._can_interact_with_world(true) and not scene._can_interact_with_world(), "alive dialogue continuation remains allowed, other world actions do not")
    scene._try_interact()
    _check(scene.dialogue_text_label.visible_characters == -1, "F still reveals an alive speaker's subtitle")
    scene._close_overlays()
    scene.player.hp = scene.player.max_hp
    scene.player.death_timer = 0.0
    scene.demo_complete = false
    var reward_id := String(scene.config.boss.get("reward_item", "crown_splinter"))
    var before_currency: int = scene.currency_count
    var before_reward := int(scene.inventory_counts.get(reward_id, 0))
    scene._on_enemy_died("interaction_validation_boss", true, "rust_crown_guardian")
    _check(scene.demo_complete and scene.currency_count == before_currency + 30, "first boss victory grants currency")
    _check(int(scene.inventory_counts.get(reward_id, 0)) == before_reward + 1, "first boss victory grants unique item")
    scene._on_enemy_died("interaction_validation_boss", true, "rust_crown_guardian")
    _check(scene.currency_count == before_currency + 30 and int(scene.inventory_counts.get(reward_id, 0)) == before_reward + 1, "duplicate boss-death callback cannot duplicate rewards")
    scene.boss_spawned = false
    scene._activate_boss_gate()
    scene._spawn_boss()
    _check(not scene.boss_spawned and scene.boss_actor == null, "completed boss cannot be reactivated through door or direct spawn")
    scene._travel_world(scene.config_path, scene.active_spawn)
    scene = current_scene
    await _frames()
    scene._activate_boss_gate()
    scene._on_enemy_died("interaction_validation_boss", true, "rust_crown_guardian")
    _check(scene.demo_complete and not scene.boss_spawned, "boss stays defeated after region reload")
    _check(scene.currency_count == before_currency + 30 and int(scene.inventory_counts.get(reward_id, 0)) == before_reward + 1, "reload preserves exactly one boss reward")
    # Intentional replay is a new boss-trial scene, not resurrection of campaign state.
    scene.player.hp = 0
    scene.player.death_timer = 0.9
    scene._toggle_audio_settings()
    _check(scene.active_overlay == "settings", "settings remain accessible during death")
    scene._start_new_journey()
    scene = current_scene
    await _frames()
    _check(not scene.demo_complete and scene.player.hp > 0, "explicit new journey remains available during death")
    _finish()

func _find_kind(kind: String) -> Area2D:
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == kind:
            return child
    return null

func _frames() -> void:
    await process_frame
    await process_frame

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".previous"]:
        var path: String = SAVE + String(suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(scene):
        scene.queue_free()
    _clean()
    print("WORLD_INTERACTION_SAFETY checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)

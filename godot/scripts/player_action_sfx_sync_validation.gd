extends SceneTree
## S02 action sync: each player action sound starts on the frame its action
## happens (strike, second jump, block, heal settle, heal break, phase entry), on a real
## floor with the production Player and real InputMap actions.
class ProbePlayer extends "res://scripts/player_controller.gd":
    var played: Array[Dictionary] = []
    func _should_play_sfx() -> bool:
        return true
    func _play_sfx_voice(audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> Node:
        var voice := super._play_sfx_voice(audio_key, volume_db, pitch_scale, voice_key, voice_priority)
        played.append({"key": audio_key, "pitch": pitch_scale, "elapsed": attack_duration - attack_timer,
            "attack_timer": attack_timer, "windup": attack_windup, "struck": attack_vfx_started,
            "hp": hp, "heal": heal_timer, "air": not is_on_floor(), "voice": voice})
        return voice

var checks := 0
var failures: Array[String] = []
var player: ProbePlayer
var fixture: Node2D
var report := {}
const ACTIONS := ["move_left", "move_right", "jump", "attack", "heal", "bell_guard", "dash", "lantern_phase"]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _frames(count: int) -> void:
    for index in count:
        await physics_frame
        await process_frame

func _release() -> void:
    for action in ACTIONS:
        Input.action_release(action)

func _tap(action: String, hold := 2) -> void:
    Input.action_press(action)
    await _frames(hold)
    Input.action_release(action)

func _reset() -> void:
    _release()
    player.restore_at_save_point()
    player.respawn_at(Vector2(300, 300))
    player.build_profile.erase("crest_id")
    player.energy = player.max_energy
    player.guard_cooldown = 0.0
    player.heal_cooldown = 0.0
    await _frames(30)
    player.played.clear()

func _sounds(key: String) -> Array:
    return player.played.filter(func(row): return row.key == key)

func _body(center: Vector2, size: Vector2) -> void:
    var body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    collision.shape = rectangle
    body.position = center
    body.add_child(collision)
    fixture.add_child(body)

func _run() -> void:
    fixture = Node2D.new()
    root.add_child(fixture)
    _body(Vector2(1000, 310), Vector2(5000, 20))
    var instance := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
    instance.set_script(ProbePlayer)
    player = instance
    fixture.add_child(player)
    player.feel = null
    await _reset()
    _check(player.is_on_floor(), "fixture has real floor contact")

    # Bell seal turns the basic strike into the heavy strike (attack_2).
    player.build_profile["crest_id"] = "bell"
    await _tap("attack")
    await _frames(30)
    var heavy := _sounds("skill")
    _check(heavy.size() == 1, "heavy strike plays its impact once (%d)" % heavy.size())
    if heavy.size() == 1:
        _check(heavy[0].struck and heavy[0].elapsed >= heavy[0].windup - 0.001,
            "heavy impact waits for the strike frame (%.3fs after press, windup %.2fs)" % [heavy[0].elapsed, heavy[0].windup])
        report["heavy_impact_after_press"] = snappedf(heavy[0].elapsed, 0.001)

    await _reset()
    await _tap("attack")
    await _frames(30)
    var swing := player.played.filter(func(row): return String(row.key).begins_with("attack"))
    _check(swing.size() == 1 and _sounds("skill").is_empty(), "basic strike keeps one swing and no heavy impact")

    await _reset()
    player.double_jump_unlocked = true
    await _tap("jump", 3)
    await _frames(10)
    _check(not player.is_on_floor(), "first jump leaves the floor")
    await _tap("jump", 2)
    await _frames(2)
    var second := _sounds("double_jump")
    _check(second.size() == 1 and second[0].air, "second jump plays the silk wing snap in the air")
    _check(_sounds("jump").size() == 1, "ground jump keeps its own sound and the second jump does not reuse it")
    await _frames(80)

    await _reset()
    player.bell_guard_unlocked = true
    player.facing = 1
    await _tap("bell_guard", 1)
    var front := player.global_position + Vector2(80, 0)
    player.take_damage(1, front)
    _check(_sounds("guard_perfect").size() == 1 and _sounds("guard_block").is_empty(), "perfect guard rings once on the block frame")
    _check(_sounds("ch03_beat_guard_ring").is_empty(), "outside the salt archive a perfect guard has no archive ring")
    await _frames(70)
    player.energy = player.max_energy
    await _tap("bell_guard", 1)
    await _frames(16)
    var hp_before := player.hp
    player.take_damage(1, front)
    _check(player.hp == hp_before and _sounds("guard_block").size() == 1, "late guard still blocks with the clamp sound")
    _check(_sounds("hurt").is_empty(), "blocked hits never play the hurt sound")
    _check(_sounds("ch03_beat_guard_ring").is_empty(), "a late guard never plays the archive ring")

    # Salt archive (salt footsteps): the perfect guard also rings the bell shell.
    await _reset()
    player.footstep_material = "salt"
    await _tap("bell_guard", 1)
    player.take_damage(1, player.global_position + Vector2(80, 0))
    var ring := _sounds("ch03_beat_guard_ring")
    _check(_sounds("guard_perfect").size() == 1 and ring.size() == 1, "salt archive perfect guard layers the bell shell ring once")
    player.footstep_material = "moss"
    await _frames(70)

    # Lantern phase: entering the phase plays the wick intake once per entry.
    await _reset()
    player.lantern_phase_unlocked = true
    Input.action_press("lantern_phase")
    await _frames(2)
    _check(player.is_phasing() and _sounds("phase_enter").size() == 1, "entering the lantern phase plays the wick intake")
    await _frames(20)
    _check(_sounds("phase_enter").size() == 1, "holding the phase does not replay the entry sound")
    Input.action_release("lantern_phase")
    await _frames(4)
    _check(not player.is_phasing(), "releasing ends the phase")
    Input.action_press("lantern_phase")
    await _frames(2)
    _check(_sounds("phase_enter").size() == 2, "entering again plays it again")
    Input.action_release("lantern_phase")
    await _frames(4)

    await _reset()
    player.hp = player.max_hp - 1
    await _tap("heal", 1)
    _check(player.heal_timer > 0.0, "heal channel starts on a real floor")
    await _frames(int(ceil(player.heal_duration * 60.0)) + 10)
    var settle := _sounds("bind_tighten")
    _check(player.hp == player.max_hp and settle.size() == 1, "completed heal plays the tighten once")
    if settle.size() == 1:
        _check(settle[0].hp == player.max_hp and settle[0].heal <= 0.0, "tighten sounds on the frame HP returns")
    _check(_sounds("bind_interrupt").is_empty(), "completed heal is not reported as broken")

    await _reset()
    player.hp = player.max_hp - 1
    await _tap("heal", 1)
    await _frames(12)
    var channel := _sounds("heal")
    _check(channel.size() == 1 and is_instance_valid(channel[0].voice), "heal channel sound is playing")
    player.take_damage(1, player.global_position + Vector2(80, 0), false)
    await _frames(2)
    _check(_sounds("bind_interrupt").size() == 1 and _sounds("bind_tighten").is_empty(), "a hit during the channel plays the snap, not the tighten")
    var cut: bool = channel.size() == 1 and (not is_instance_valid(channel[0].voice) or not channel[0].voice.playing)
    _check(cut, "interrupted heal cuts its channel sound instead of ringing on")

    _release()
    fixture.queue_free()
    print("PLAYER_ACTION_SFX_SYNC_REPORT ", JSON.stringify(report))
    if failures.is_empty():
        print("PLAYER_ACTION_SFX_SYNC_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("PLAYER_ACTION_SFX_SYNC_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)

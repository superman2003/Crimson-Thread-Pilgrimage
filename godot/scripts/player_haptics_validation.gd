extends RefCounted
## Exercises the production pulse scheduler and real Player hooks. Only native
## hardware enumeration/output and the monotonic clock use a recording adapter.
class RecordingHaptics extends "res://scripts/player_haptics.gd":
    var connected: Array[int] = [2,3]
    var clock := 1000
    var starts: Array = []
    var stops: Array[int] = []
    func _devices() -> Array[int]:return connected
    func _now_ms() -> int:return clock
    func _start_output(device: int, weak: float, strong: float, seconds: float) -> void:
        starts.append({"device":device,"weak":weak,"strong":strong,"seconds":seconds})
    func _stop_output(device: int) -> void:stops.append(device)

var checks := 0
var checker: Callable

func _check(ok: bool, label: String) -> void:
    checks += 1
    checker.call(ok,label)

func _joy(device: int) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.device = device
    event.button_index = JOY_BUTTON_X
    event.pressed = true
    return event

func run(tree: SceneTree, player: Node, check_callback: Callable) -> void:
    checker = check_callback
    var production: Node = load("res://scenes/Player.tscn").instantiate()
    tree.root.add_child(production)
    production.set_physics_process(false)
    _check(is_instance_valid(production.haptics) and production.haptics.get_parent()==production,"Production Player creates its haptics child")
    _check(production.haptics.selected_device == -1 and not production.haptics.pulse("hit"),"Production output remains idle before real controller input")
    production.free()
    var h := RecordingHaptics.new()
    player.add_child(h)
    h.set_process(false)
    player.haptics = h
    player.hp = player.max_hp
    player.death_timer = 0.0
    player.hurt_timer = 0.0
    player.set_meta("accessibility",{"vibration_enabled":true})
    _check(not h.pulse("hit") and h.starts.is_empty(),"No controller input means no vibration")
    var noise := InputEventJoypadMotion.new()
    noise.device = 2
    noise.axis_value = 0.3
    h._input(noise)
    _check(h.selected_device == -1,"Controller jitter cannot claim feedback ownership")
    h._input(_joy(9))
    _check(h.selected_device == -1,"Disconnected device cannot claim feedback ownership")
    h._input(_joy(2))
    player._trigger_hit_feedback(false)
    _check(h.starts.size() == 1 and h.starts[0].device == 2 and h.priority == 1,"Confirmed player hit targets the last controller")
    var deadline: int = h.deadline_ms
    for unused in 100:player._trigger_hit_feedback(false)
    _check(h.starts.size() == 1 and h.deadline_ms == deadline,"Crowded hits neither restart nor extend the active pulse")
    player._trigger_hit_feedback(true)
    _check(h.starts.size() == 2 and h.priority == 2,"Confirmed kill replaces the weaker hit pulse")
    player.take_damage(1,player.global_position + Vector2(50,0))
    _check(h.starts.size() == 3 and h.priority == 3,"Actual damage replaces lower-priority hit feedback")
    player._trigger_hit_feedback(true)
    _check(h.starts.size() == 3,"A kill cannot mask active damage feedback")
    for output in h.starts:
        _check(output.weak > 0 and output.weak <= 1 and output.strong > 0 and output.strong <= 1 and output.seconds > 0 and output.seconds <= 0.14,"Every native pulse has bounded strength and duration")
    var old_scale := Engine.time_scale
    Engine.time_scale = 0.05
    h.clock += 141
    h._process(0.001)
    Engine.time_scale = old_scale
    _check(h.running_device == -1 and h.stops.back() == 2,"Real-time expiry stops feedback independently of hitstop")
    h._input(_joy(3))
    _check(h.pulse("hit") and h.starts.back().device == 3,"Controller switching targets only the most recently used device")
    var key := InputEventKey.new()
    key.keycode = KEY_J
    key.pressed = true
    h._input(key)
    _check(h.running_device == -1 and h.selected_device == -1 and not h.pulse("hit"),"Keyboard input stops controller feedback and releases ownership")
    h._input(_joy(2))
    h.pulse("hit")
    player.set_meta("accessibility",{"vibration_enabled":false})
    h.set_process(true)
    await tree.process_frame
    await tree.process_frame
    h.set_process(false)
    _check(h.running_device == -1 and not h.pulse("hurt"),"Disabling the existing preference stops active and future vibration")
    var count: int = h.starts.size()
    player.set_meta("accessibility",{"vibration_enabled":true})
    h._process(0.001)
    _check(h.starts.size() == count and h.running_device == -1,"Re-enabling does not replay suppressed feedback")
    h.pulse("hit")
    player.ui_input_locked = true
    _check(h.running_device == -1 and not h.pulse("hurt"),"Opening a player overlay stops vibration immediately")
    player.ui_input_locked = false
    h.pulse("hit")
    tree.paused = true
    h.set_process(true)
    await tree.process_frame
    await tree.process_frame
    h.set_process(false)
    var blocked_while_paused := not h.pulse("hurt")
    tree.paused = false
    _check(h.running_device == -1 and blocked_while_paused,"Pause stops active feedback and rejects new pulses")
    h.pulse("hit")
    Input.joy_connection_changed.emit(2,false)
    _check(h.running_device == -1 and h.selected_device == -1,"Disconnect immediately stops output and releases the device")
    Input.joy_connection_changed.emit(2,true)
    _check(not h.pulse("hit"),"Reconnection alone never resumes vibration")
    h._input(_joy(2))
    h.pulse("hit")
    h.connected.erase(2)
    h._process(0.001)
    _check(h.running_device == -1 and h.selected_device == -1,"Device polling also stops output and ownership if disconnect notification is missed")
    h.connected.append(2)
    h._input(_joy(2))
    h.pulse("hit")
    player.prepare_region_handoff()
    _check(h.running_device == -1,"Region handoff stops output synchronously")
    h.pulse("hit")
    player.respawn_at(Vector2.ZERO)
    _check(h.running_device == -1,"Relocation or respawn stops output synchronously")
    h.pulse("hit")
    player.restore_at_save_point()
    _check(h.running_device == -1,"Rest stops output synchronously")
    player.arrival_guard_timer = 1.0
    count = h.starts.size()
    player.take_damage(1)
    _check(h.starts.size() == count,"Ignored damage does not create feedback")
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    h.pulse("hit")
    player.hp = 1
    player.take_damage(1)
    _check(h.running_device == -1 and not h.pulse("hit"),"Lethal damage stops output and dead players cannot pulse")
    player.death_timer = 0.0 # Natural death countdown has completed.
    player._hard_respawn()
    _check(h.running_device == -1,"Death respawn does not restore the old pulse")
    h._input(_joy(3))
    h.pulse("hit")
    player.remove_child(h)
    _check(h.running_device == -1 and h.stops.back() == 3,"Leaving the scene tree stops the last native output")
    h.free()
    player.haptics = null
    _check(not is_instance_valid(player.haptics),"Controller tests release the haptics child cleanly")
    print("PLAYER_HAPTICS checks=%d" % checks)

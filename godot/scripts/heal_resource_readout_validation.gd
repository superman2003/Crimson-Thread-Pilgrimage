extends SceneTree
const READOUT = preload("res://scripts/heal_resource_readout.gd")
const UI = preload("res://scripts/pilgrimage_interface.gd")
const TRACK = preload("res://scripts/heal_reservation_track.gd")
const RETIRE = preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0

class QuietPlayer extends "res://scripts/player_controller.gd":
    func _ready() -> void: pass
    func _process(_delta: float) -> void: pass
    func _physics_process(_delta: float) -> void: pass
    func _exit_tree() -> void: pass

class Runtime extends Node:
    var player: Node
    var active_overlay := ""
    var inventory_counts := {}
    var currency_count := 0
    var build_system := preload("res://scripts/build_system.gd").new()
    func get_build_system() -> RefCounted: return build_system
    func is_near_shrine() -> bool: return false

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL HEAL_READOUT: " + label)

func active(cost: int = 60, loss: int = 30) -> Dictionary:
    return {"reason":"channeling", "remaining":.6, "duration":1.2,
        "reserved":cost, "cost":cost, "interrupt_loss":loss, "amount":2}

func model_checks() -> void:
    var heal := active()
    var before := heal.duplicate(true)
    var state := READOUT.snapshot(heal, 40, 100)
    check(state.active and state.reserved == 60, "paid channel remains distinct from available energy")
    check(state.loss == 30 and state.refundable == 30 and state.returned == 30, "exact partial-loss reservation")
    check(state.energy == 40 and state.maximum == 100, "meter still displays unreserved energy")
    check(is_equal_approx(state.progress, .5), "channel progress follows actual duration")
    check(heal == before, "readout cannot mutate player-owned snapshot")
    var view := READOUT.present(state)
    check(view.visible and view.text.contains("已预留 60"), "HUD says cost is already reserved")
    check(view.text.contains("损失 30") and view.text.contains("退回 30"), "visible refund and loss without hover")
    check(view.detail.contains("不需要再次支付"), "tooltip does not imply a second charge")
    for energy in [0, 40, 69, 70, 71, 99, 100, 110]:
        var current := READOUT.snapshot(heal, energy, 100)
        var expected := mini(30, 100 - clampi(energy, 0, 100))
        check(current.returned == expected, "capacity-bound refund at energy %d" % energy)
        check(current.refundable == current.reserved - current.loss, "reservation conservation at energy %d" % energy)
        check(current.capacity_limited == (expected < 30), "capacity warning matches actual headroom")
    for loss in [0, 1, 30, 59, 60, 90]:
        var current := READOUT.snapshot(active(60, loss), 0, 100)
        check(current.loss == mini(60, loss), "loss cannot exceed paid cost")
        check(current.returned == 60 - mini(60, loss), "nonnegative partial refund")
    for reason in ["ready", "busy", "energy", "full_health", "dead", "cooldown", "airborne", "moving"]:
        var idle := active()
        idle.reason = reason
        var current := READOUT.snapshot(idle, 40, 100)
        check(not current.active and current.reserved == 0 and current.returned == 0, "inactive state has no phantom reservation: " + reason)
        check(not READOUT.present(current).visible, "inactive state hides payment line: " + reason)
    for remaining in [0.0, -1.0, NAN, INF, -INF]:
        var invalid := active()
        invalid.remaining = remaining
        check(not READOUT.snapshot(invalid, 40, 100).active, "invalid or settled channel has no paid banner")
    for bad in [NAN, INF, -INF, -1.0, "60", null, {}, true]:
        var invalid := active()
        invalid.reserved = bad
        var current := READOUT.snapshot(invalid, 40, 100)
        check(current.reserved == 0 and current.loss == 0 and current.returned == 0, "invalid reservation fails closed")
    var changed := active()
    changed.cost = 99
    check(READOUT.snapshot(changed, 40, 100).reserved == 60, "next configuration cost cannot replace paid cost")
    var tiny := active()
    tiny.duration = .1
    tiny.remaining = .05
    check(is_equal_approx(READOUT.snapshot(tiny, 0, 100).progress, .5), "short channels use actual duration")
    check(READOUT.snapshot({}, 0, 100).progress == 0, "missing snapshot is quiet")

func make_player() -> Node:
    var player := preload("res://scenes/Player.tscn").instantiate()
    player.set_script(QuietPlayer)
    root.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    player.hp = 2
    player.max_hp = 5
    player.max_energy = 100
    player.energy = 100
    player.heal_energy_cost = 60
    player.heal_duration = 1.2
    player.heal_amount = 2
    player.build_profile = {"heal_airborne":true, "heal_interrupt_loss_ratio":.5}
    return player

func live_player_checks() -> void:
    var player := make_player()
    var panel := Control.new()
    root.add_child(panel)
    var label := READOUT.create_label(panel, UI.FONT, Color.WHITE)
    check(player._try_heal(), "actual Player begins paid airborne-compatible heal fixture")
    check(player.energy == 40 and player.heal_reserved_cost == 60, "actual action pays once before UI query")
    var state := READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(state.reserved == 60 and state.returned == 30, "live snapshot exposes actual reservation and interrupt loss")
    var before := [player.energy, player.hp, player.heal_timer, player.heal_reservation_generation]
    for index in range(20):
        READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(before == [player.energy, player.hp, player.heal_timer, player.heal_reservation_generation], "repeated rendering cannot pay, heal, advance time or cancel")
    player.heal_timer = .6
    state = READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(is_equal_approx(state.progress, .5), "live paid timer feeds progress")
    player.gain_energy(50)
    state = READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(state.returned == 10 and state.capacity_limited, "newly earned thread reduces refund headroom without losing reservation identity")
    check(label.tooltip_text.contains("容量限制"), "capacity saturation has explicit explanation")
    player._interrupt_heal()
    check(player.energy == 100 and player.heal_timer == 0, "actual interrupt returns only available capacity")
    READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(not label.visible and label.text.is_empty(), "settled interruption clears stale reserved text")
    player.heal_cooldown = 0
    check(player._try_heal(), "new channel after settlement has fresh reservation")
    var paid_energy: int = player.energy
    player._update_heal(player.heal_duration)
    check(player.hp == 4 and player.energy == paid_energy, "actual completion heals without second payment or refund")
    state = READOUT.apply(label, player.get_heal_readiness(), player.energy, player.max_energy, false)
    check(not state.active and not label.visible, "completion clears paid banner")
    RETIRE.retire_tree(player)
    player.queue_free()
    panel.queue_free()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self), "Player fixture retires actual owned audio")

func ui_checks() -> void:
    var ui := UI.new()
    root.add_child(ui)
    ui.set_process(false)
    ui._build_hud()
    var world := Runtime.new()
    world.player = make_player()
    root.add_child(world)
    ui.level = world
    world.player.heal_timer = .6
    world.player.heal_reserved_cost = 60
    world.player.heal_reserved_loss_ratio = .5
    world.player.energy = 40
    ui._refresh_combat_status(world.player)
    check(ui.healing_payment.visible and ui.healing_payment_track.visible, "actual production refresh updates both readouts")
    check(ui.healing_payment.text.contains("预留 60"), "production player snapshot reaches native HUD row")
    world.active_overlay = "map"
    ui._refresh_combat_status(world.player)
    check(not ui.healing_payment.visible and not ui.healing_payment_track.visible, "actual overlay refresh hides both readouts")
    world.active_overlay = ""
    world.player.heal_timer = 0
    ui._refresh_combat_status(world.player)
    check(not ui.healing_payment.visible, "actual completed-channel refresh clears reservation")
    check(ui.healing_payment is Label and not ui.healing_payment.visible, "production HUD installs quiet reservation row")
    check(ui.healing_payment.position == Vector2(30,208), "row uses space below the channel meter")
    check(ui.healing_payment.size.y <= 25 and ui.healing_payment.position.y >= ui.healing_bar.position.y + ui.healing_bar.size.y, "readout does not cover existing meter")
    check(ui._hud_groups().top.has(ui.healing_payment), "danger occlusion includes new HUD content")
    READOUT.apply(ui.healing_payment, active(), 40, 100, false)
    check(ui.healing_payment.visible, "visible world shows paid breakdown")
    check(ui.healing_payment.get_meta("heal_reservation").reserved == 60, "native row carries exact inspectable paid state")
    READOUT.apply(ui.healing_payment, active(), 40, 100, true)
    check(not ui.healing_payment.visible, "overlay hides new HUD information")
    READOUT.apply(ui.healing_payment, active(), 40, 100, false)
    check(ui.healing_payment.visible, "closing overlay restores active channel breakdown")
    var text: String = ui.healing_payment.text
    READOUT.apply(ui.healing_payment, active(), 40, 100, false)
    check(ui.healing_payment.text == text, "same state does not accumulate repeated lines")
    var copied: Dictionary = ui.healing_payment.get_meta("heal_reservation")
    copied.reserved = 999
    READOUT.apply(ui.healing_payment, active(), 40, 100, false)
    check(ui.healing_payment.get_meta("heal_reservation").reserved == 60, "outside inspection cannot rewrite the next presentation")
    var detached := Label.new()
    detached.free()
    check(READOUT.apply(detached, active(), 40, 100, false).reserved == 60, "late query tolerates retired UI")
    ui.queue_free()
    world.player.queue_free()
    world.queue_free()
    await process_frame

func track_checks() -> void:
    var state := READOUT.snapshot(active(), 90, 100)
    var pieces := TRACK.segments(state, 300)
    check(pieces.size() == 3, "saturated refund shows loss, return and overflow separately")
    check(pieces[0].amount == 30 and pieces[1].amount == 10 and pieces[2].amount == 20, "visual split matches exact paid accounting")
    check(pieces[0].rect == Rect2(0,0,150,4), "loss segment geometry")
    check(pieces[1].rect == Rect2(150,0,50,4), "return segment geometry")
    check(pieces[2].rect == Rect2(200,0,100,4), "capacity segment geometry")
    for width in [1.0, 100.0, 300.0, 1000.0]:
        var total := 0.0
        for part in TRACK.segments(state, width):
            check(is_equal_approx(part.rect.position.x, total), "segments join without overlapping")
            total += part.rect.size.x
        check(is_equal_approx(total, width), "paid reservation fills exact track width")
    for width in [0.0, -1.0, NAN, INF]:
        check(TRACK.segments(state, width).is_empty(), "invalid geometry does not draw")
    check(TRACK.segments(READOUT.snapshot({},0,100),300).is_empty(), "idle state has no paid track")
    var track := TRACK.new()
    root.add_child(track)
    track.update_snapshot(state, false)
    check(track.visible and track.mouse_filter == Control.MOUSE_FILTER_IGNORE, "paid strip is visible without taking controls")
    state.reserved = 999
    check(track.state.reserved == 60, "strip does not retain mutable caller dictionary")
    track.update_snapshot(track.state, true)
    check(not track.visible, "overlay hides strip even when state is unchanged")
    track.queue_free()
    await process_frame

func run() -> void:
    for action in ["move_left", "move_right", "jump", "dash", "heal"]:
        if not InputMap.has_action(action): InputMap.add_action(action)
    model_checks()
    await live_player_checks()
    await ui_checks()
    await track_checks()
    print("HEAL_RESOURCE_READOUT checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

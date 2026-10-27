extends SceneTree
const ACCOUNT = preload("res://scripts/heal_refund_account.gd")
const RETIRE = preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0

class QuietPlayer extends "res://scripts/player_controller.gd":
    func _ready() -> void: pass
    func _process(_delta: float) -> void: pass
    func _physics_process(_delta: float) -> void: pass
    func _exit_tree() -> void: pass

class Target extends Node2D:
    var hp := 20
    var is_boss := false
    func take_hit(damage: int, _direction: int) -> void:
        hp -= damage
    func get_hurtbox_rect() -> Rect2:
        return Rect2(global_position-Vector2(80,80),Vector2(160,160))

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL HEAL_REFUND: " + label)

func make_player() -> Node:
    var player := preload("res://scenes/Player.tscn").instantiate()
    player.set_script(QuietPlayer)
    root.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    player.hp = 2
    player.max_hp = 5
    player.energy = 100
    player.max_energy = 100
    player.heal_energy_cost = 60
    player.heal_duration = 1.2
    player.heal_amount = 2
    player.build_profile = {"heal_airborne":true, "heal_interrupt_loss_ratio":.5}
    return player

func release(player: Node) -> void:
    RETIRE.retire_tree(player)
    player.queue_free()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self), "actual Player audio retires")

func arithmetic() -> void:
    var plan := ACCOUNT.settlement(60,40,.5,90,100,0)
    check(plan.accepted == 10 and plan.practice_return == 10, "capacity admits ten thread and ten practice labels")
    check(plan.energy_after == 100 and plan.practice_after == 10, "only accepted refund enters wallet")
    check(plan.loss == 30 and plan.overflow == 20, "capacity overflow is separate from interrupt loss")
    for ratio in [0.0,.1,.5,.99,1.0]:
        for cost in [0,1,3,60,100]:
            for balance in [0,40,90,100]:
                var value := ACCOUNT.settlement(cost,cost,ratio,balance,100,0)
                var loss := mini(cost,int(ceil(cost*ratio)))
                check(value.loss == loss, "loss uses exact ceiling")
                check(value.accepted == mini(cost-loss,100-balance), "refund fits actual remaining capacity")
                check(value.practice_return == value.accepted, "all-practice refund follows accepted amount")
                check(value.energy_after <= 100 and value.practice_after <= value.energy_after, "wallet bounds and provenance bounds")
                check(value.paid == value.loss + value.accepted + value.overflow, "paid thread is conserved across refund, loss and overflow")
    for ratio in [NAN,INF,-INF]:
        var invalid := ACCOUNT.settlement(60,60,ratio,40,100,0)
        check(invalid.accepted == 0 and invalid.loss == 60, "non-finite ratio cannot mint currency")
    var mixed := ACCOUNT.settlement(60,10,0,0,100,5)
    check(mixed.practice_after == 10 and mixed.energy_after == 60, "invalid prior practice outside wallet does not survive")
    var clamped := ACCOUNT.settlement(60,100,0,10,100,5)
    check(clamped.practice_return == 60 and clamped.practice_after == 65, "practice reservation cannot exceed paid cost")
    check(ACCOUNT.settlement(-60,-10,.5,-5,-1,-5).energy_after == 0, "negative metadata fails within zero wallet")

func saturated_refund() -> void:
    for practice in [0,10,40,60,100]:
        for earned in [0,30,50,60]:
            var player := make_player()
            player.practice_energy = practice
            check(player._try_heal(), "actual mixed heal can start")
            var reserved: int = player.heal_reserved_practice
            var old_energy: int = player.energy
            var old_practice: int = player.practice_energy
            player.gain_energy(earned)
            var before: int = player.energy
            var accepted := mini(30,100-before)
            var expected_practice := old_practice + mini(accepted,reserved)
            player._interrupt_heal()
            check(player.energy == before+accepted, "actual interrupt respects capacity")
            check(player.practice_energy == expected_practice, "only actual refund is marked as practice")
            check(player.heal_reserved_cost == 0 and player.heal_timer == 0, "settled reservation clears once")
            var settled: Array = [player.energy,player.practice_energy,player.heal_reservation_generation]
            player._interrupt_heal()
            check(settled == [player.energy,player.practice_energy,player.heal_reservation_generation], "duplicate interruption cannot refund twice")
            player._settle_practice_energy()
            check(player.energy == before+accepted-expected_practice and player.practice_energy == 0, "leaving practice removes only actual tagged practice thread")
            check(old_energy == 40, "paid action reserved exact original cost")
            await release(player)

func signal_observation() -> void:
    var player := make_player()
    player.practice_energy = 40
    check(player._try_heal(), "signal fixture reserves mixed thread")
    player.gain_energy(50)
    var seen: Array = []
    var watcher := func(_energy: int,_maximum: int):
        seen.append([player.energy,player.practice_energy,player.heal_reserved_cost,player.heal_timer])
    player.energy_changed.connect(watcher,CONNECT_ONE_SHOT)
    player._interrupt_heal()
    check(seen == [[100,10,0,0.0]], "energy listener sees atomically settled wallet and provenance")
    await release(player)

func reentrant_settlement() -> void:
    var player := make_player()
    player.practice_energy = 40
    check(player._try_heal(), "reentrant fixture reserves practice")
    player.gain_energy(50)
    var entered := [false]
    var watcher := func(_energy: int,_maximum: int):
        entered[0] = true
        player._settle_practice_energy()
    player.energy_changed.connect(watcher,CONNECT_ONE_SHOT)
    player._interrupt_heal()
    check(entered[0], "actual refund emits energy_changed")
    check(player.energy == 90 and player.practice_energy == 0, "listener can settle practice before outer refund returns")
    check(player.heal_reserved_cost == 0, "outer call cannot resurrect settled reservation")
    await release(player)

func reentrant_channel() -> void:
    var player := make_player()
    player.practice_energy = 40
    check(player._try_heal(), "new-channel fixture pays original reservation")
    player.gain_energy(50)
    var entered := [false]
    var states: Array[String]=[]
    var state_observer:=func(state: String):states.append(state)
    player.heal_state_changed.connect(state_observer)
    var watcher := func(_energy: int,_maximum: int):
        player.heal_cooldown = 0
        entered[0] = player._try_heal()
    player.energy_changed.connect(watcher,CONNECT_ONE_SHOT)
    player._interrupt_heal()
    check(entered[0] and player.heal_timer > 0, "listener can start an explicitly unlocked newer channel")
    check(states==["started"], "outer interruption cannot publish stale state after newer channel starts")
    check(player.heal_reserved_practice == 10 and player.practice_energy == 0, "new channel reserves refunded practice before using real thread")
    var generation: int = player.heal_reservation_generation
    player._interrupt_heal()
    check(player.heal_reservation_generation == generation+1, "new reservation settles independently exactly once")
    check(player.energy == 70 and player.practice_energy == 10, "second interrupt preserves actual mixed-source balance")
    await release(player)

func full_loss_and_completion() -> void:
    var player := make_player()
    player.practice_energy = 60
    player.build_profile.heal_interrupt_loss_ratio = 1.0
    check(player._try_heal(), "full-loss fixture begins")
    player._interrupt_heal()
    check(player.energy == 40 and player.practice_energy == 0, "full-loss contract still refunds nothing")
    player.heal_cooldown = 0
    player.gain_energy(60)
    check(player._try_heal(), "completion fixture begins")
    player._update_heal(1.2)
    check(player.hp == 4 and player.energy == 40 and player.practice_energy == 0, "completed heal still spends original cost and grants authored HP")
    player._interrupt_heal()
    check(player.energy == 40, "completed heal cannot later be refunded")
    await release(player)

func reentrant_completion() -> void:
    var player:=make_player()
    check(player._try_heal(), "completion callback fixture begins")
    var states: Array[String]=[]
    var observer:=func(state: String):states.append(state)
    player.heal_state_changed.connect(observer)
    var listener:=func(_hp: int):
        player.gain_energy(60)
        player.heal_cooldown=0
        player._try_heal()
    player.hp_changed.connect(listener,CONNECT_ONE_SHOT)
    player._update_heal(1.2)
    check(player.hp==4 and player.heal_timer>0 and player.heal_reserved_cost==60, "HP callback can start an explicitly unlocked new paid channel")
    check(states==["started"], "old completion cannot overtake new-channel notification")
    player._interrupt_heal()
    check(player.energy==70 and player.heal_timer==0, "new reservation remains independently refundable")
    await release(player)

func provenance_changes() -> void:
    for practice in [0,10,80,100]:
        for amount in [-200,-60,-1,0,1,60,200]:
            var plan := ACCOUNT.change(amount,100,100,practice,true)
            var expected := clampi(100+amount,0,100)
            check(plan.energy == expected, "spend/gain preserves bounded energy")
            check(plan.practice == maxi(0,practice-(100-expected)), "spending consumes practice first")
    var gain := ACCOUNT.change(50,90,100,0,true)
    check(gain.energy == 100 and gain.practice == 10, "practice income tags only accepted headroom")
    check(ACCOUNT.change(10,0,100,0,false).practice == 0, "ordinary enemy income remains real")
    var reduced := ACCOUNT.change(0,100,30,80)
    check(reduced.energy == 30 and reduced.practice == 10, "capacity discard preserves twenty earned thread")
    var player := make_player()
    player.energy = 90
    var observations: Array = []
    var listener := func(_value: int,_maximum: int):
        observations.append([player.energy,player.practice_energy])
        player._settle_practice_energy()
    player.energy_changed.connect(listener,CONNECT_ONE_SHOT)
    player.gain_energy(50,true)
    check(observations == [[100,10]], "practice gain listener sees atomic provenance")
    check(player.energy == 90 and player.practice_energy == 0, "listener cannot carry a practice gain outside its range")
    player.energy = 100
    player.practice_energy = 80
    player._apply_capacity_limits({"max_energy":30,"max_hp":5})
    check(player.energy == 30 and player.practice_energy == 10, "actual capacity change discards practice first")
    player._settle_practice_energy()
    check(player.energy == 20 and player.practice_energy == 0, "capacity shrink never relabels genuine thread as practice")
    player.energy = 100
    player.practice_energy = 80
    player.max_energy = 100
    player.apply_build_stats({"max_energy":30,"max_hp":5,"heal_cost":60,"heal_duration":1.2,"heal_amount":2})
    check(player.energy == 30 and player.practice_energy == 10, "full build application has same capacity provenance")
    player._settle_practice_energy()
    check(player.energy == 20, "full build change preserves genuinely earned remainder")
    await release(player)

func reentrant_practice_payment() -> void:
    var player := make_player()
    player.energy = 90
    var called := [false]
    var listener := func(_value: int,_maximum: int):
        called[0] = player._try_heal()
    player.energy_changed.connect(listener,CONNECT_ONE_SHOT)
    player.gain_energy(50,true)
    check(called[0], "practice income can synchronously fund actual paid heal")
    check(player.energy == 40 and player.practice_energy == 0 and player.heal_reserved_practice == 10, "reentrant payment captures accepted practice before consumption")
    player._interrupt_heal()
    check(player.energy == 70 and player.practice_energy == 10, "refunding nested practice payment retains provenance")
    player._settle_practice_energy()
    check(player.energy == 60, "nested earning/payment/refund leaves only earned balance outside practice")
    await release(player)

func actual_training_contacts() -> void:
    for source in ["seal_training_target", "tool_training_target", "ordinary"]:
        var player := make_player()
        player.energy = 90
        var target := Target.new()
        target.position = Vector2(60,-40)
        if source != "ordinary":
            target.set_meta(source,true)
        root.add_child(target)
        target.add_to_group("enemy")
        await physics_frame
        var seen: Array = []
        var listener := func(_value: int,_maximum: int):
            seen.append([player.energy,player.practice_energy])
            player.gain_energy(-5)
        player.energy_changed.connect(listener,CONNECT_ONE_SHOT)
        var was_hp: int = target.hp
        player._apply_attack_hits()
        check(target.hp < was_hp, "production needle hit reaches actual target fixture")
        var tagged := 0 if source == "ordinary" else 10
        check(seen == [[100,tagged]], "melee income publishes exact accepted source before callbacks")
        check(player.energy == 95 and player.practice_energy == maxi(0,tagged-5), "reentrant spending consumes practice first")
        player.position = Vector2(2000,0)
        player._settle_practice_energy()
        check(player.practice_energy == 0 and player.energy == (95 if source == "ordinary" else 90), "leaving target keeps exact genuine remainder")
        target.queue_free()
        await release(player)

func run() -> void:
    for action in ["move_left","move_right","jump","dash","heal"]:
        if not InputMap.has_action(action): InputMap.add_action(action)
    arithmetic()
    await saturated_refund()
    await signal_observation()
    await reentrant_settlement()
    await reentrant_channel()
    await full_loss_and_completion()
    await reentrant_completion()
    await provenance_changes()
    await reentrant_practice_payment()
    await actual_training_contacts()
    print("HEAL_REFUND_ACCOUNT checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

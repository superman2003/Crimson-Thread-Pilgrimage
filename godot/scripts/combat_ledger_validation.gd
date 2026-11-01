extends SceneTree
const LEDGER := preload("res://scripts/combat_ledger.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures.append(message)
func run() -> void:
    var ledger:=LEDGER.new();ledger.configure("ledger_unit")
    check(ledger.start("known","已到地区","crimson").ok,"manual observation starts without modifying progress")
    ledger.contact({"kind":"strike","damage":3,"practice":true})
    check(ledger.active.hits==0,"practice target contacts cannot become combat damage")
    ledger.contact({"kind":"strike","damage":NAN})
    check(ledger.active.hits==0,"invalid contact values cannot become recorded damage")
    ledger.contact({"kind":"strike","damage":3,"killed":true,"boss":true})
    ledger.contact({"kind":"guard","perfect":true});ledger.heal("completed");ledger.heal("interrupted");ledger.cast("cleave");ledger.energy(20,12);ledger.energy(12,16);ledger.tick(1.0)
    check(ledger.active.hits==1 and ledger.active.outgoing==3 and ledger.active.boss_kills==1 and ledger.active.perfect==1,"accepted contact counters retain distinct meanings")
    for index in 80:ledger.event("样本"+str(index))
    check(ledger.active.events.size()==60,"observation timeline has a bounded memory budget")
    ledger.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not ledger.finish("主动结束") and not ledger.pending.is_empty() and ledger.history.is_empty(),"failed final write retains a retryable result without publishing history")
    check(not ledger.start("new","new","bell").ok,"unsaved result cannot be overwritten by a new session")
    ledger.store.writer=Callable();check(ledger.retry() and ledger.retry() and ledger.history.size()==1,"retry writes an observation once")
    var loaded:=LEDGER.new();loaded.configure("ledger_unit")
    check(loaded.history==ledger.history,"actual disk reload restores a sanitized session")
    check(LEDGER.sanitize({"region":"a","title":"b","crest":"c","seconds":1,"hits":true}).is_empty(),"boolean counters cannot masquerade as measurements")
    for index in 23:ledger.start("r","r","c");ledger.finish("主动结束")
    check(ledger.history.size()==20,"history eviction remains bounded")
    for index in 14:
        ledger.start("large","长记录","当前契印")
        for step in 60:ledger.event("复".repeat(120))
        check(ledger.finish("主动结束"),"large timelines evict older records before auxiliary byte budget is exceeded")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://combat_ledger_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var desk: Node=main.ui_shell.get_node("CombatDesk")
    main._toggle_backpack();main.ui_shell.bag.get_node("CombatDeskButton").pressed.emit();await process_frame
    check(desk.window.visible and desk.query.has_focus(),"actual inventory button opens the combat ledger")
    desk.start_observation();desk._bind_player()
    check(not desk.ledger.active.is_empty() and main.active_overlay.is_empty(),"starting observation releases actual gameplay controls")
    var data: Dictionary=main.config.enemy_spawns[0].duplicate(true)
    data.id="combat_observation_fixture";data.hp=50
    var enemy: Node=main._enemy(data);enemy.set_physics_process(false)
    main.player._start_attack(&"attack_1",false)
    enemy.global_position=main.player.global_position+main.player._attack_center_offset()
    var flags: Dictionary=main.story_flags.duplicate(true)
    var inventory: Dictionary=main.inventory_counts.duplicate(true)
    var wallet: int=main.currency_count
    main.player._apply_attack_hits()
    check(desk.ledger.active.hits==1 and desk.ledger.active.outgoing>0,"actual accepted Player hit produces an observed damage event")
    main.player._apply_attack_hits()
    check(desk.ledger.active.hits==1,"same swing's target deduplication also protects observation counters")
    enemy.global_position+=Vector2(1000,0)
    var dummy:=Area2D.new();dummy.set_script(load("res://scripts/enemy_dummy.gd"));dummy.hp=50;main.add_child(dummy)
    dummy.set_physics_process(false)
    main.player._start_attack(&"attack_1",false)
    dummy.global_position=main.player.global_position+main.player._attack_center_offset()
    main.player._apply_attack_hits()
    check(desk.ledger.active.hits==2 and desk.ledger.active.boss_kills==0,"accepted receiver without boss metadata remains a valid ordinary contact")
    dummy.free()
    main.player.debug_invulnerable=false;main.player.arrival_guard_timer=0;main.player.hurt_timer=0;main.player.guard_timer=0
    var hp: int=main.player.hp
    main.player.take_damage(1,main.player.global_position-Vector2(100,0),true)
    check(desk.ledger.active.incoming==hp-main.player.hp and desk.ledger.active.incoming>0,"real damage observer records actual HP loss after multipliers")
    main.player.attack_timer=0;main.player.hurt_timer=0;main.player.bell_guard_unlocked=true;main.player.facing=1
    check(main.player._try_guard(),"explicit guard fixture accepts the normal paid guard action")
    main.player.take_damage(1,main.player.global_position+Vector2(100,0),true)
    check(desk.ledger.active.guards==1 and desk.ledger.active.perfect==1,"real guard resolution records success and timely timing")
    check(desk.ledger.active.energy_out>=8 and desk.ledger.active.energy_in>=4,"real resource signals distinguish paid guard and bounded refund")
    check(main.story_flags==flags and main.inventory_counts==inventory and main.currency_count==wallet,"observation changes no story inventory or wallet beyond the performed combat")
    desk.ledger.finish("主动结束")
    main._toggle_backpack();desk.open();await process_frame
    check(desk.visible_records.size()==1 and desk.detail.text.contains("实际承伤"),"production history renders the observed session")
    desk.export_selected()
    check(FileAccess.file_exists(desk.ledger.store.path.get_basename()+"_report.txt"),"production export writes a standalone readable recap")
    var resumed:=LEDGER.new();resumed.configure(main.world_save_path)
    check(resumed.history==desk.ledger.history,"production session survives an actual new reader instance")
    desk.start_observation();main.player.hp=1;main.player.hurt_timer=0;main.player.guard_timer=0
    main.player.take_damage(2,main.player.global_position-Vector2(100,0),true)
    check(desk.ledger.active.is_empty() and desk.ledger.history[0].reason=="倒下","real lethal damage finalizes one death observation")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture retires actual audio")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("COMBAT_LEDGER checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)

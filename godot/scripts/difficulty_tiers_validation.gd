extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const MODEL:=preload("res://scripts/difficulty_setting.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames(count: int=5) -> void:
    for index in count:await process_frame
## One real hit on the production player; returns masks lost.
func hit(player: Node, amount: int) -> int:
    player.hp=5;player.hurt_timer=0.0;player.mercy_timer=0.0;player.arrival_guard_timer=0.0;player.guard_timer=0.0
    var before: int=player.hp
    player.take_damage(amount,player.global_position+Vector2(40,0))
    var feel:=root.get_node_or_null("FeelKit")
    if feel!=null and feel.has_method("cancel_hitstop"):feel.cancel_hitstop()
    return before-int(player.hp)
func run() -> void:
    check(MODEL.ORDER.size()==3 and MODEL.TIERS.size()==3 and MODEL.TIERS.has(MODEL.DEFAULT),"three tiers, standard by default")
    check(MODEL.TIERS.standard.damage_bonus==0 and MODEL.TIERS.standard.mercy==0.0,"standard changes nothing")
    var invalid:=MODEL.new();invalid.attach("user://difficulty_empty_record.json")
    invalid.store.write({})
    var invalid_bytes:=FileAccess.get_file_as_bytes(invalid.store.path)
    invalid.attach("user://difficulty_empty_record.json")
    check(not invalid.store.writable and invalid.tier=="standard","existing empty difficulty payload is invalid and preserved")
    check(not invalid.choose("gentle").ok and FileAccess.get_file_as_bytes(invalid.store.path)==invalid_bytes,"a choice cannot overwrite the existing invalid record")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid.store.path))
    var path:="user://difficulty_tiers_world.json"
    var probe:=MODEL.new();probe.attach(path)
    if FileAccess.file_exists(probe.store.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(probe.store.path))
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path=path;root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    await frames(6)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=world.ui_shell
    var desk: Node=ui.get_node_or_null("DifficultyDesk")
    check(desk!=null and desk.model.tier=="standard","a new journey starts on standard")
    var player: Node=world.player
    check(player.difficulty_damage_bonus==0 and player.difficulty_mercy==0.0,"standard reaches the player unchanged")
    check(await hit(player,1)==1 and await hit(player,2)==2,"standard: hits cost their authored masks")
    player.hurt_timer=0.0
    check(player.mercy_timer==0.0,"standard: no extra safe time")
    # The settings window drives the journey's record and the live player.
    world._toggle_audio_settings();await frames()
    var launcher:=ui.settings.get_node_or_null("DifficultyButton") as Button
    check(launcher!=null and launcher.text=="难度" and not is_instance_valid(desk.window),"launcher present; window not built until opened")
    var rect:=launcher.get_global_rect()
    for child in ui.settings.get_children():
        if child is Control and child!=launcher and child.visible and child.size.x<900 and child.get_global_rect().intersects(rect):
            check(false,"difficulty launcher overlaps "+String(child.name))
    launcher.pressed.emit();await frames()
    check(desk.window.visible and desk.options.item_count==3 and desk.options.selected==1,"window lists three tiers with standard selected")
    desk.options.select(0);desk.options.item_selected.emit(0);await frames()
    check(desk.model.tier=="gentle" and player.difficulty_damage_bonus==-1 and is_equal_approx(player.difficulty_mercy,0.9),"gentle reaches the live player")
    check(desk.status.text==MODEL.TIERS.gentle.note,"the window says what the tier does")
    desk.window.hide();world._close_overlays();await frames()
    check(await hit(player,1)==1,"gentle: a light hit still costs one mask")
    check(await hit(player,2)==1,"gentle: a heavy hit costs one mask less")
    player.hp=5;player.take_damage(1,player.global_position+Vector2(40,0));player.hurt_timer=0.0
    var after_first: int=player.hp
    check(player.mercy_timer>0.9 and not player.take_damage(1,player.global_position+Vector2(40,0)) and player.hp==after_first,"gentle: a second hit inside the safe time does nothing")
    player.mercy_timer=0.0
    check(player.take_damage(1,player.global_position+Vector2(40,0)) and player.hp==after_first-1,"gentle: safe time ends")
    var reread:=MODEL.new();reread.attach(path)
    check(reread.tier=="gentle","the choice is recorded beside this journey")
    var other:=MODEL.new();other.attach("user://another_slot.json")
    check(other.tier=="standard","another journey keeps its own difficulty")
    desk.model.choose("harsh");await frames()
    check(player.difficulty_damage_bonus==1,"harsh reaches the live player")
    check(await hit(player,1)==2 and await hit(player,2)==3,"harsh: every hit costs one more mask")
    player.hurt_timer=0.0
    check(player.mercy_timer==0.0,"harsh: no extra safe time")
    check(not desk.model.choose("nightmare").ok and desk.model.tier=="harsh","unknown tier refused")
    desk.model.choose("standard");await frames()
    check(await hit(player,2)==2,"back to standard")
    player.hp=5
    DirAccess.remove_absolute(ProjectSettings.globalize_path(desk.model.store.path))
    RETIRE.retire_tree(world);world.queue_free();await frames(8)
    await RETIRE.drain(self)
    print("DIFFICULTY_TIERS checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)

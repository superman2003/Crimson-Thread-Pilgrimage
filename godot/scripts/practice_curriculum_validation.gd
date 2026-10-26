extends SceneTree
const COURSE := preload("res://scripts/practice_curriculum.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if not ok:failures.append(message)
func run() -> void:
    var model:=COURSE.new();model.configure("curriculum_unit")
    check(model.courses.size()==12 and model.available({}).size()==2,"twelve courses with unearned ability titles withheld")
    check(not model.start("thread_dash",{"thread_dash":true}).ok,"boolean inventory cannot open an ability course")
    check(model.start("thread_dash",{"thread_dash":1}).ok,"earned ability opens its curriculum")
    check(not model.accept("echo_hook",1),"wrong action cannot advance a stage")
    model.tick(0.5)
    check(model.accept("thread_dash",2) and model.active.stage==1,"first accepted action advances the actual stage")
    check(not model.accept("thread_dash",2),"same-frame duplicate cannot count into a later stage")
    model.accept("thread_dash",3);model.tick(0.5);model.accept("thread_dash",4)
    check(model.active.is_empty() and model.history[0].complete and is_equal_approx(model.best("thread_dash"),1.0),"completing all stages writes a bounded timed record")
    var loaded:=COURSE.new();loaded.configure("curriculum_unit")
    check(loaded.history==model.history,"actual disk reload restores best and recent records")
    model.start("casting",{});model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    model.finish(false,"主动结束")
    check(not model.pending.is_empty() and model.history.size()==1,"failed record save retains a retryable private candidate")
    check(not model.start("healing",{}).ok,"pending result must be handled before another course")
    model.store.writer=Callable();check(model.retry() and model.history.size()==2,"retry writes the same record once")
    check(model.retry() and model.history.size()==2,"repeating successful retry cannot duplicate a result")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://curriculum_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var desk: Node=main.ui_shell.get_node("PracticeDesk")
    main._toggle_build();desk.open();await process_frame
    check(desk.window.visible and desk.available.size()==2,"production course menu opens without leaking future ability names")
    desk.selected="casting";desk.start_selected()
    check(desk.curriculum.active.is_empty(),"beginning away from a real rack is rejected")
    var target:=preload("res://scripts/seal_training_target.gd").new()
    target.name="curriculum_fixture_rack"
    target.configure({"id":"curriculum_fixture","kind":"seal_training","hp":30,"speed":0,"damage":0},"res://assets/ui/seals/ward.svg",false,{"attacks":[],"locomotion":"stationary"})
    target.position=main.player.global_position+Vector2(80,0);main.add_child(target);target.set_physics_process(false)
    desk.selected="casting";desk.start_selected();desk._bind_player()
    check(not desk.curriculum.active.is_empty() and main.active_overlay.is_empty(),"actual rack proximity starts training and releases the game controls")
    var flags: Dictionary=main.story_flags.duplicate(true)
    var inventory: Dictionary=main.inventory_counts.duplicate(true)
    var wallet: int=main.currency_count
    # Explicit cast fixture: use the production Player's fallback payload,
    # without claiming a naturally earned skill or emitting its signal by hand.
    var build: RefCounted=main.player.build_system
    main.player.build_system=null
    main.player.configure_selected_skill({"id":"thread_burst","kind":"melee","energy_cost":1,"damage":1,"windup":0.1,"active":0.2,"recovery":0.2})
    var energy: int=main.player.energy
    check(main.player.cast_selected_skill() and desk.curriculum.active.count==1 and main.player.energy==energy-1,"real accepted cast consumes thread and reaches the current course")
    check(not main.player.cast_selected_skill() and desk.curriculum.active.count==1,"rejected second cast cannot advance the training stage")
    main.player.build_system=build
    desk._heal("interrupted")
    check(desk.curriculum.active.count==1,"interrupted heal never impersonates a completed action")
    main.player.global_position=desk.origin+Vector2(600,0);desk._process(0.1)
    check(desk.curriculum.active.is_empty() and not desk.curriculum.history[0].complete,"leaving the real rack range ends and records the attempt")
    check(main.story_flags==flags and main.inventory_counts==inventory and main.currency_count==wallet,"course attempts grant no progression inventory or money")
    main._toggle_build();desk.open();main._close_overlays()
    check(not desk.window.visible,"closing build also closes curriculum reading")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture drains actual audio ownership")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("PRACTICE_CURRICULUM checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)

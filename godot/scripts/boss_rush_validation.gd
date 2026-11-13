extends SceneTree
const RUSH:=preload("res://scripts/boss_rush.gd")
const CARD:=preload("res://scripts/title_card.gd")
const ACHIEVEMENTS:=preload("res://scripts/achievements.gd")
var checks:=0
var failures:=0
var made: Array[Node]=[]
var result:={}
class Stage extends Node:
    var boss_actor: Node
    var demo_complete:=false
    var path:=""
class World extends Node:
    var audio_director:=Node.new()
    var new_journey_dialog:=ConfirmationDialog.new()
    var active_overlay:=""
    func _ready() -> void:add_child(audio_director);add_child(new_journey_dialog)
    func _sync_ui_input_lock() -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames(count: int=3) -> void:
    for index in count:await process_frame
func rush(world: Node,count: int) -> Node:
    var controller:=RUSH.new()
    var paths: Array[String]=[]
    for index in count:paths.append("stage_%d" % index)
    controller.stages=paths
    controller.make_stage=func(path: String):
        var stage:=Stage.new();stage.path=path;made.append(stage);return stage
    controller.make_world=func():return World.new()
    controller.begin(world)
    return controller
func best() -> float:
    var probe:=RUSH.new();var value: float=probe.best();probe.free();return value
func clear(feature: String) -> void:
    var store:=preload("res://scripts/journey_desk_store.gd").new();store.configure(feature,"installation")
    if FileAccess.file_exists(store.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
func beat(stage: Node) -> void:
    stage.boss_actor=Node.new();stage.add_child(stage.boss_actor)
    await frames(6)
    stage.demo_complete=true
    await frames(3)
func run() -> void:
    check(RUSH.STAGES.size()==6,"six gatekeepers")
    for path in RUSH.STAGES:
        var file:=FileAccess.open(path,FileAccess.READ)
        var config: Variant=JSON.parse_string(file.get_as_text()) if file!=null else null
        check(config is Dictionary and config.get("boss") is Dictionary and config.has("boss_checkpoint"),"stage has a gatekeeper and a checkpoint: "+path.get_file())
    check(RUSH.clock_text(0.0)=="0:00.0" and RUSH.clock_text(75.26)=="1:15.2" and RUSH.clock_text(-3.0)=="0:00.0","clock shows minutes, seconds, tenths")
    clear("achievements");clear("boss_rush")
    check(not RUSH.available(),"locked until every gatekeeper has been beaten")
    var record:=ACHIEVEMENTS.new();record.load();record.unlocked["all_gatekeepers"]=1;record.store.write(record.unlocked)
    check(RUSH.available(),"unlocked by the six-gatekeeper achievement")
    # Title card entry.
    var level:=World.new();root.add_child(level);current_scene=level;await frames()
    var card: Node=CARD.open(level,true);await frames()
    check(card.buttons.has("rush") and card.buttons["rush"].text=="首领连战","title card offers the mode once unlocked")
    card.choose("continue");await frames();CARD.shown=false
    # A full clear over three stand-in stages.
    made.clear()
    var controller:=rush(level,3);await frames()
    check(not is_instance_valid(level) or level.is_queued_for_deletion(),"the journey scene leaves")
    check(made.size()==1 and current_scene==made[0] and made[0].path=="stage_0","the first stage becomes the running scene")
    check(controller.label.text=="1 / 3 · 0:00.0" and not controller.fighting,"clock waits while the stage loads")
    await frames(10)
    check(controller.elapsed==0.0,"no time passes before the gatekeeper stands")
    await beat(made[0])
    check(controller.splits.size()==1 and controller.splits[0]>0.0 and made.size()==2 and current_scene==made[1],"a defeat records a split and loads the next stage")
    var first: float=controller.elapsed
    await frames(6)
    check(controller.elapsed==first,"loading the next stage is off the clock")
    paused=true;made[1].boss_actor=Node.new();made[1].add_child(made[1].boss_actor);await frames(6)
    check(controller.elapsed==first,"a paused game is off the clock")
    paused=false;await frames(4);made[1].demo_complete=true;await frames(3)
    await beat(made[2])
    controller.finished.connect(func(value: Dictionary):result=value)
    var window:=controller.get_node_or_null("Result") as AcceptDialog
    check(controller.done and window!=null and window.visible and window.dialog_text.begins_with("用时 ") and window.dialog_text.ends_with("新纪录"),"the result shows the time and marks a first record")
    check(current_scene is World and current_scene!=level,"the journey scene is back behind the result")
    var total: float=controller.elapsed
    window.confirmed.emit();await frames()
    check(result.get("cleared")==true and result.splits.size()==3 and is_equal_approx(result.seconds,total) and result.record,"result reports the clear, three splits and the record")
    check(is_equal_approx(best(),total),"the best time is kept")
    # A slower clear keeps the record; quitting records nothing.
    made.clear();var again:=rush(current_scene,1);await frames()
    made[0].boss_actor=Node.new();made[0].add_child(made[0].boss_actor);again.elapsed=total+50.0;await frames(3)
    made[0].demo_complete=true;await frames(3)
    check(not again.get_node("Result").dialog_text.contains("新纪录") and again.get_node("Result").dialog_text.contains("最佳 "+RUSH.clock_text(total)),"a slower clear shows the standing best")
    again.get_node("Result").confirmed.emit();await frames()
    check(is_equal_approx(best(),total),"…and does not replace it")
    made.clear();var quitter:=rush(current_scene,2);await frames()
    quitter.quit_held=RUSH.QUIT_HOLD;quitter._finish(false);await frames()
    check(quitter.get_node("Result").dialog_text=="已退出连战。" and is_equal_approx(best(),total) and current_scene is World,"quitting returns to the journey and records nothing")
    quitter.get_node("Result").canceled.emit();await frames()
    var store:=preload("res://scripts/journey_desk_store.gd").new();store.configure("boss_rush","installation")
    var file:=FileAccess.open(store.path,FileAccess.WRITE);file.store_string('{"version":1,"payload":{"best_seconds":-1}}');file.close()
    check(best()==0.0,"an invalid record reads as no record")
    clear("achievements");clear("boss_rush")
    current_scene.queue_free();await frames(4)
    print("BOSS_RUSH checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)

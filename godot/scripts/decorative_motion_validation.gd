extends SceneTree
const MOTION:=preload("res://scripts/decorative_motion.gd")
const SETTINGS:=preload("res://scripts/decorative_motion_settings.gd")
const ENDING:=preload("res://scripts/ending_aftermath_scene.gd")
const PROP:=preload("res://scripts/scene_history_prop.gd")
var checks:=0
var failures:=0
class Player extends Node2D:
    var hp:=4
class Host extends Node2D:
    var world_loading:=false
    var chapter_transitioning:=false
    var active_overlay:=""
    var current_room_id:="room_a"
    var player:=Player.new()
    func _ready() -> void:add_child(player)
    func interaction_target(actor: Node) -> Node:return actor
class Shell extends Control:
    var settings:=Control.new()
    func _ready() -> void:add_child(settings)
    func _button(parent: Node,text: String,point: Vector2,dimensions: Vector2,callback: Callable) -> Button:
        var button:=Button.new();button.text=text;button.position=point;button.size=dimensions
        parent.add_child(button);button.pressed.connect(callback);return button
    func _label(parent: Node,text: String,point: Vector2,dimensions: Vector2,font_size: int) -> Label:
        var label:=Label.new();label.text=text;label.position=point;label.size=dimensions
        label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var host:=Host.new();root.add_child(host)
    var actor:=Node2D.new();host.add_child(actor);actor.position=Vector2(100,180)
    var clock:=MOTION.new()
    for delta in [0.0,-1.0,INF,NAN]:check(not clock.step(actor,delta) and clock.elapsed==0,"invalid cosmetic delta cannot advance clock")
    check(clock.step(actor,0.04) and is_equal_approx(clock.elapsed,0.04),"visible decoration advances normal time")
    var time:=clock.elapsed
    for overlay in ["bag","map","dialogue","settings","ending_story"]:
        host.active_overlay=overlay
        check(not clock.step(actor,1.0) and clock.elapsed==time,"each real overlay freezes cosmetic time")
    host.active_overlay="";host.world_loading=true
    check(not clock.step(actor,0.04),"region load suspends decoration")
    host.world_loading=false;host.chapter_transitioning=true
    check(not clock.step(actor,0.04),"chapter transition suspends decoration")
    host.chapter_transitioning=false;host.player.hp=0
    check(not clock.step(actor,0.04),"death freezes cosmetic time")
    host.player.hp=4;host.hide()
    check(not clock.step(actor,0.04),"hidden ancestor blocks decoration")
    host.show();actor.hide()
    check(not clock.step(actor,0.04),"hidden decoration blocks time")
    actor.show();actor.position=Vector2(90000,90000)
    check(not clock.step(actor,0.04),"offscreen prop consumes no decorative time")
    actor.position=Vector2(100,180);MOTION.enabled=false
    check(not clock.step(actor,0.04) and clock.elapsed==time,"reduced motion freezes current pose")
    MOTION.enabled=true;clock.redraw_clock=0
    for index in 3:check(not clock.step(actor,1.0/120.0),"cosmetic redraw budget skips subframes")
    check(clock.step(actor,1.0/120.0),"thirtieth-second boundary redraws once")
    time=clock.elapsed;clock.step(actor,100.0)
    check(is_equal_approx(clock.elapsed-time,0.1),"long frame has bounded cosmetic advance")
    var plain:=Node2D.new();root.add_child(plain);host.remove_child(actor);plain.add_child(actor)
    check(clock.step(actor,0.04),"reparenting safely invalidates host property cache")
    plain.remove_child(actor);host.add_child(actor)
    check(clock.step(actor,0.04),"returning to world host resumes")
    var ending:=ENDING.new();host.add_child(ending);ending.set_process(false);ending.position=Vector2(100,180)
    var prop:=PROP.new();prop.entry={"look":"pump_manifold","role":"artifact","title":"泵渠旧物"}
    host.add_child(prop);prop.set_process(false);prop.position=Vector2(200,180)
    ending._process(0.04);prop._process(0.04)
    check(ending.elapsed>0 and prop.elapsed>0,"both real production decorations use active clock")
    var ending_time:=ending.elapsed;var prop_time:=prop.elapsed
    var transform:=prop.transform;var layer:=prop.collision_layer;var mask:=prop.collision_mask
    var shape: CollisionShape2D=prop.get_child(1)
    var size: Vector2=shape.shape.size
    MOTION.enabled=false;ending._process(2);prop._process(2)
    check(ending.elapsed==ending_time and prop.elapsed==prop_time,"actual production poses freeze without rewinding")
    check(prop.transform==transform and prop.collision_layer==layer and prop.collision_mask==mask and shape.shape.size==size,"motion preference cannot move interaction geometry")
    check(prop.inspection_focused and prop.inspection_caption.visible,"stationary artifact remains inspectable")
    prop.mark_seen()
    check(prop.seen and prop.inspection_text().begins_with("已记下"),"stationary artifact can still record discovery")
    MOTION.enabled=true;host.active_overlay="bag";ending._process(2);prop._process(2)
    check(ending.elapsed==ending_time and prop.elapsed==prop_time and not prop.inspection_caption.visible,"overlay freeze retains interaction hiding policy")
    host.active_overlay="";prop.entry={"look":"pump_manifold","role":"witness","room_id":"room_b"}
    prop._process(0.04)
    check(not prop.visible and prop.elapsed==prop_time,"hidden witness cannot animate or reveal itself")
    host.current_room_id="room_b";prop._process(0.04)
    check(prop.visible and prop.elapsed>prop_time,"known-room witness resumes normally")
    var shell:=Shell.new();root.add_child(shell);SETTINGS.install(shell);SETTINGS.install(shell)
    check(shell.get_child_count()==2,"settings reinstallation does not duplicate controls")
    var settings=shell.get_node("DecorativeMotionSettings")
    settings.store.path="user://motion_fixture.json"
    settings.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    settings.toggle()
    check(not MOTION.enabled and settings.dirty and settings.notice.contains("未保存"),"runtime toggle and failed persistence are distinguished")
    settings.store.writer=func(_data: Dictionary):return OK
    settings.save()
    check(not settings.dirty and settings.retry.disabled,"explicit save retry preserves chosen motion state")
    shell.settings.hide();settings.toggle()
    check(not MOTION.enabled,"hidden settings callback cannot toggle global preference")
    settings.store.writable=false;shell.settings.show();settings.toggle()
    check(MOTION.enabled and settings.dirty,"quarantined settings remain runtime adjustable without overwriting")
    check(settings.button.position.x>=600 and settings.retry.get_rect().end.x<919,"controls stay between title and back button")
    var durable:=preload("res://scripts/journey_desk_store.gd").new();durable.configure("decorative_motion","installation")
    check(durable.write({"enabled":false}),"real preference stored atomically")
    shell.free();await process_frame
    shell=Shell.new();root.add_child(shell);SETTINGS.install(shell)
    check(not MOTION.enabled,"new UI restores exact disabled preference")
    shell.free();await process_frame
    var file:=FileAccess.open(durable.path,FileAccess.WRITE);file.store_string("broken");file.close()
    var bytes:=FileAccess.get_file_as_bytes(durable.path)
    shell=Shell.new();root.add_child(shell);SETTINGS.install(shell)
    settings=shell.get_node("DecorativeMotionSettings")
    check(not settings.store.writable and settings.notice.contains("损坏"),"damaged motion record remains visible and quarantined")
    check(FileAccess.get_file_as_bytes(durable.path)==bytes,"bad motion file bytes preserved")
    shell.free();await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(durable.path))
    actor.queue_free();check(not clock.step(actor,0.04),"queued actor cannot advance cosmetic clock")
    plain.free();host.free();await process_frame;MOTION.enabled=true
    print("DECORATIVE_MOTION checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

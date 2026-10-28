extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const POLICY:=preload("res://scripts/camera_observation_preferences.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://camera_observation_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    world.set_process(false);world.set_physics_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=world.ui_shell
    ui.accessibility_path="user://camera_observation_preferences_test.cfg"
    ui.accessibility.camera_lookahead=0.0;ui._apply_accessibility()
    await physics_frame;await physics_frame
    check(world._save_world(),"save fixture before readonly configuration")
    var disk:=FileAccess.get_file_as_bytes(world.world_save_path)
    var game:=var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy])
    world._toggle_audio_settings();await process_frame
    var desk: Node=ui.get_node("CameraObservationDesk")
    var row: Dictionary=ui.accessibility_controls.camera_lookahead
    check(desk.launcher==row.label and desk.launcher.is_visible_in_tree(),"existing label replaced by keyboard-focusable entry")
    check(desk.launcher.get_rect().end.x<=row.slider.position.x,"actual settings launcher and slider do not overlap")
    desk.launcher.pressed.emit();await process_frame
    check(desk.window.visible and desk.window.get_cancel_button().has_focus(),"actual native child opens with cancel focused")
    check(world.player.ui_input_locked,"settings retain gameplay input ownership")
    desk.mode_picker.select(1);desk.mode_picker.item_selected.emit(1)
    desk.delay_slider.value=0.6;desk.distance_slider.value=0.5
    check(POLICY.normalize(ui.accessibility)==POLICY.DEFAULTS,"staged controls do not apply current preference")
    check(not FileAccess.file_exists(ui.accessibility_path),"staged control cannot create preference file")
    desk.window.get_cancel_button().pressed.emit();await process_frame
    check(desk.candidate.is_empty() and desk.baseline.is_empty(),"cancel retires pending draft")
    check(POLICY.normalize(ui.accessibility)==POLICY.DEFAULTS,"cancel keeps original observation behavior")
    desk.open();desk.mode_picker.select(1);desk.mode_picker.item_selected.emit(1)
    desk.delay_slider.value=0.6;desk.distance_slider.value=0.5;desk.apply()
    check(ui.accessibility.observation_mode==1 and is_equal_approx(ui.accessibility.observation_delay,0.6),"confirmed controls apply to actual shell")
    check(world.player.get_meta("accessibility").observation_mode==1,"live player receives independent mode")
    var config:=ConfigFile.new();check(config.load(ui.accessibility_path)==OK,"confirmed controls saved through preference transaction")
    check(config.get_value("accessibility","observation_mode")==1 and config.get_value("accessibility","observation_distance")==0.5,"disk retains exact selected settings")
    ui.accessibility.observation_mode=2;ui._load_accessibility();ui._apply_accessibility()
    check(ui.accessibility.observation_mode==1,"existing loader restores new observation keys")
    var camera: Camera2D=world.player.get_node("Camera2D")
    var region: Rect2=world.player.camera_focus.region_bounds;var zoom:=camera.zoom
    world._close_overlays();await process_frame
    # Use a real grounded Player scene, while World player verifies setting propagation.
    var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.world_2d=World2D.new();root.add_child(viewport)
    var stage:=Node2D.new();viewport.add_child(stage)
    var floor_body:=StaticBody2D.new();var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new()
    rectangle.size=Vector2(4000,20);shape.shape=rectangle;floor_body.position=Vector2(2000,1510);floor_body.add_child(shape);stage.add_child(floor_body)
    var player: Node=load("res://scenes/Player.tscn").instantiate();stage.add_child(player);player.feel=null
    player.configure_camera_focus(Rect2(0,0,4000,2400));player.respawn_at(Vector2(1000,1500));player.set_meta("accessibility",ui.accessibility.duplicate())
    for index in 25:await physics_frame
    check(player.is_on_floor(),"actual player settles on authored fixture floor")
    var point: Vector2=player.global_position
    Input.action_press("aim_up")
    for index in 50:await physics_frame
    check(player.camera_focus.look_offset==-75.0,"actual player can observe at zero automatic strength")
    check(absf(player.get_node("Camera2D").position.x)<0.01,"manual observation does not enable horizontal automatic ahead")
    check(player.global_position.distance_to(point)<1,"observation never displaces actual player body")
    player.set_meta("accessibility",{"camera_lookahead":0.0})
    for index in 2:await physics_frame
    check(player.camera_focus.look_offset==0,"old absent keys retain disabled zero-ahead behavior")
    player.set_meta("accessibility",ui.accessibility.duplicate());player.camera_focus.push_lock("boss",Rect2(0,0,4000,2400),100,true,false)
    for index in 50:await physics_frame
    check(player.camera_focus.look_offset==0,"actual boss restriction survives independent preference")
    Input.action_release("aim_up");player.camera_focus.remove_lock("boss")
    viewport.queue_free();await process_frame
    check(camera.zoom==zoom and world.player.camera_focus.region_bounds==region,"settings preserve World zoom and region bounds")
    world._toggle_audio_settings();desk.open();desk.mode_picker.select(2);desk.mode_picker.item_selected.emit(2)
    ui.accessibility.observation_distance=0.75;desk.apply()
    check(desk.notice.text.contains("已改变") and ui.accessibility.observation_mode==1,"stale dialog cannot overwrite external observation change")
    desk.window.hide();desk.open();var preference_path: String=ui.accessibility_path
    var preference_bytes:=FileAccess.get_file_as_bytes(preference_path)
    # Existing injected persistence boundary uses _write override below, no production bypass.
    var original: Variant=ui.settings_persistence
    ui.settings_persistence=FailingSave.new();desk.mode_picker.select(2);desk.mode_picker.item_selected.emit(2);desk.apply()
    check(ui.accessibility.observation_mode==2 and desk.notice.text.contains("尚未保存"),"failed disk write keeps live explicit setting with honest pending notice")
    check(FileAccess.get_file_as_bytes(preference_path)==preference_bytes,"preference remains readable after failed writer")
    ui.settings_persistence=original;ui._save_accessibility()
    check(var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy])==game,"preference operations do not change economy or progression")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==disk,"preference operations preserve exact gameplay save bytes")
    ui.settings.hide();await process_frame
    check(not desk.window.visible and desk.candidate.is_empty(),"parent hide discards unapplied draft")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for path in ["user://camera_observation_world.json",preference_path]:
        for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
    print("CAMERA_OBSERVATION_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
class FailingSave extends "res://scripts/settings_persistence.gd":
    func _write(_config: ConfigFile,_path: String) -> Error:return ERR_CANT_CREATE

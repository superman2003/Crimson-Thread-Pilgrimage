extends SceneTree
const PREFS := preload("res://scripts/controller_preferences.gd")
const CAPTIONS := preload("res://scripts/danger_captions.gd")
const ORIGIN := Vector2(1000000,1000000)
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func actor_at(main: Node,point: Vector2,unblockable: bool=false) -> Area2D:
    var actor: Area2D=main._make_enemy_prefab({"id":"caption_fixture_"+str(point.x),"kind":"moss_larva","hp":4}, {})
    actor.position=point;main.add_child(actor);actor.set_physics_process(false)
    actor.state="windup";actor.state_timer=0.8;actor.active_attack=actor.ai_commands[0].duplicate(true);actor.active_attack.blockable=not unblockable
    return actor
func run() -> void:
    var values:=PREFS.normalize({"danger_captions":1,"danger_caption_limit":INF,"danger_caption_contrast":"yes"})
    check(not values.danger_captions and values.danger_caption_limit==2 and values.danger_caption_contrast,"malformed and non-finite caption preferences fall back safely")
    check(PREFS.normalize({"danger_caption_limit":99}).danger_caption_limit==3 and PREFS.normalize({"danger_caption_limit":-1}).danger_caption_limit==1,"caption line budget is bounded")
    check(CAPTIONS.direction(Vector2(-90,0))=="左侧" and CAPTIONS.direction(Vector2(10,-90))=="上方" and CAPTIONS.direction(Vector2.ZERO)=="身侧","relative direction vocabulary")
    check(CAPTIONS.rank(true,false,1,500)<CAPTIONS.rank(false,true,0.1,50),"unblockable tells rank before blockable bosses")
    var main: Node=load("res://scenes/World.tscn").instantiate();main.world_resume=false;main.world_save_path="user://danger_captions_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.set_physics_process(false);main.player.set_physics_process(false)
    var ui: Control=main.ui_shell;var desk: Node=ui.get_node("DangerCaptionDesk");var director: Node=desk.director;director.set_process(false)
    ui.accessibility_path="user://danger_caption_preferences.cfg";DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.accessibility_path))
    main._toggle_audio_settings();ui.settings.get_node("DangerCaptionButton").pressed.emit();await process_frame
    check(desk.window.visible and not desk.enabled.button_pressed,"actual settings open an opt-in confirmation")
    desk.enabled.button_pressed=true;desk.limit.value=3
    check(not ui.accessibility.danger_captions,"editing candidate has no live effect")
    var valid_path: String=ui.accessibility_path;ui.accessibility_path="user://missing_caption_directory/prefs.cfg"
    desk.apply();check(not ui.accessibility.danger_captions and desk.window.visible,"failed preference write keeps original settings and retry window")
    ui.accessibility_path=valid_path;desk.apply()
    check(ui.accessibility.danger_captions and ui.accessibility.danger_caption_limit==3 and not desk.window.visible,"successful atomic write publishes settings")
    var cfg:=ConfigFile.new();check(cfg.load(valid_path)==OK and cfg.get_value("accessibility","danger_captions")==true and cfg.get_value("accessibility","danger_caption_limit")==3,"caption preferences exist on real disk")
    ui.accessibility.danger_captions=false;ui._load_accessibility();check(ui.accessibility.danger_captions and ui.accessibility.danger_caption_limit==3,"normal startup path restores new preferences")
    var profiles:=preload("res://scripts/settings_profiles.gd").new();profiles.configure("caption_validation");profiles.profiles={}
    check(profiles.manage("save","","字幕",profiles.capture(ui)).ok,"named profiles capture caption preferences")
    ui.accessibility.danger_captions=false;var quote:=profiles.quote("字幕",ui,1)
    check(quote.ok and quote.values.danger_captions and quote.values.danger_caption_limit==3,"visual-only profile scope carries caption settings")
    ui.accessibility.danger_captions=true;main._close_overlays()
    main.player.position=ORIGIN
    var camera:=Camera2D.new();camera.position=ORIGIN+Vector2(0,-40);camera.position_smoothing_enabled=false;main.add_child(camera);camera.make_current();camera.force_update_scroll()
    await process_frame
    var normal:=actor_at(main,ORIGIN+Vector2(-100,0));var danger:=actor_at(main,ORIGIN+Vector2(120,0),true)
    await physics_frame;await process_frame
    director.refresh([normal,danger])
    check(director.rows.size()==2 and director.rows[0].unblockable and director.panel.visible,"actual visible production tells render in priority order")
    check(String(director.rows[0].text).contains("右侧") and String(director.rows[0].text).contains("不可格挡") and not JSON.stringify(director.rows).contains("moss_larva"),"direction and danger appear without hidden species or spawn identity")
    normal.state="recover";director.refresh([normal]);check(director.rows.is_empty(),"interrupted windup retracts immediately")
    normal.state="windup";normal.dying=true;director.refresh([normal]);check(director.rows.is_empty(),"dead source retracts immediately")
    normal.dying=false;normal.set_meta("world_residency_active",false);director.refresh([normal]);check(director.rows.is_empty(),"inactive resident is ignored")
    normal.set_meta("world_residency_active",true);normal.hide();director.refresh([normal]);check(director.rows.is_empty(),"hidden actor is ignored");normal.show()
    normal.position=ORIGIN+Vector2(1000,0);director.refresh([normal]);check(director.rows.is_empty(),"out-of-range actor is ignored")
    normal.position=ORIGIN+Vector2(400,0);camera.zoom=Vector2(2,2);camera.force_update_scroll();await process_frame
    director.refresh([normal]);check(director.rows.is_empty(),"offscreen tell is ignored even within hearing range")
    camera.zoom=Vector2.ONE;camera.force_update_scroll();normal.position=ORIGIN+Vector2(-100,0)
    var wall:=StaticBody2D.new();wall.position=ORIGIN+Vector2(-50,-40);var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20,140);shape.shape=rect;wall.add_child(shape);main.add_child(wall)
    await physics_frame;await physics_frame
    director.refresh([normal]);check(director.rows.is_empty(),"real terrain ray blocks a caption through a wall")
    wall.free();await physics_frame
    ui.accessibility.danger_caption_limit=1;director.refresh([normal,danger]);check(director.rows.size()==1 and director.rows[0].unblockable,"live line budget preserves highest-priority source")
    var crowded: Array=[];for unused in 200:crowded.append(danger)
    director.refresh(crowded);check(director.scanned==CAPTIONS.MAX_SCAN and director.rows.size()==1,"scan budget and source dedup remain bounded")
    main.active_overlay="settings";director.refresh([danger]);check(not director.panel.visible,"menus remove old captions")
    main.active_overlay="";ui.accessibility.danger_captions=false;director.refresh([danger]);check(not director.panel.visible,"turning feature off removes captions")
    ui.accessibility.danger_captions=true;ui.accessibility.danger_caption_limit=2;director.refresh([normal,danger]);await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/f05-danger-captions.png")
    main._close_overlays();var audio:=preload("res://scripts/audio_retirement.gd");audio.retire_tree(main);main.free();await process_frame;check(await audio.drain(self),"caption fixture audio exits cleanly")
    for failure in failures:push_error(failure)
    print("DANGER_CAPTIONS checks=%d failures=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)

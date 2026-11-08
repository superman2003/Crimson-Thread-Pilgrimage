extends SceneTree
## Isolated native presentation evidence. Never reads the player's save.
const ART := preload("res://scripts/hand_drawn_assets.gd")
var destination := ""
var actor_script: Script
var legacy_art := false
var all_bosses := false
var behavior_review := false

class Target extends CharacterBody2D:
    var hp := 9999
    var ui_input_locked := false
    var facing := 1
    var attack_timer := 0.0
    var heal_timer := 0.0
    var current_attack := "attack_1"
    var current_attack_direction := Vector2.LEFT
    func take_damage(_amount: int, _point: Vector2, _blockable: bool = true) -> bool:return false

func _initialize() -> void:call_deferred("run")

func run() -> void:
    var script_path := "res://scripts/enemy_actor.gd"
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--capture-dir="):destination=String(argument).trim_prefix("--capture-dir=")
        if String(argument).begins_with("--actor-script="):script_path=String(argument).trim_prefix("--actor-script=")
        if String(argument)=="--legacy-art":legacy_art=true
        if String(argument)=="--all-bosses":all_bosses=true
        if String(argument)=="--behavior-review":behavior_review=true
    if destination.is_empty() or DisplayServer.get_name()=="headless":
        push_error("Capture requires an explicit output directory and a real renderer")
        quit(1);return
    DirAccess.make_dir_recursive_absolute(destination)
    actor_script=load(script_path)
    root.size=Vector2i(960,540)
    RenderingServer.set_default_clear_color(Color(.055,.085,.09))
    var title_layer:=CanvasLayer.new();root.add_child(title_layer)
    var label:=Label.new();label.position=Vector2(28,20)
    label.add_theme_font_override("font",load("res://assets/fonts/GlobalTypeface.otf"))
    label.add_theme_font_size_override("font_size",24);title_layer.add_child(label)
    var index:=0
    var events: Array=[]
    var bosses:=["rust_crown_guardian","sunken_hammer_smith","saltwhite_contract_judge","broken_string_gardener","silent_pilgrim_commander","silent_crown_core"]
    var slugs:=["moss_bell_court","rain_foundry_canal","saltwhite_archive","broken_string_greenhouse","obsidian_pilgrim_road","silent_crown_core"]
    var kinds:=bosses if all_bosses else ["moss_larva","bronze_moth","rust_crown_guardian","sunken_hammer_smith"]
    for kind: String in kinds:
        var stage:=Node2D.new();root.add_child(stage)
        var camera:=Camera2D.new();camera.position=Vector2(410,292);camera.zoom=Vector2(2,2);stage.add_child(camera)
        var target:=Target.new();target.position=Vector2(500,350);target.add_to_group("player");stage.add_child(target)
        var marker:=Line2D.new();marker.default_color=Color(.65,.75,.7,.5);marker.width=1.0
        marker.points=PackedVector2Array([Vector2(-8,-20),Vector2(8,-20),Vector2.ZERO,Vector2(0,-28)])
        target.add_child(marker)
        var chapter_index:=maxi(0,bosses.find(kind))
        var chapter:="demo_ch%02d_%s" % [chapter_index+1,slugs[chapter_index]]
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+chapter+".json"))
        var enemy: Node2D=actor_script.new()
        enemy.configure({"id":"flow_"+kind,"kind":kind,"hp":9999,"patrol":100},ART.character_manifest("original_creatures",kind),kind in bosses,config.ai_profiles[kind])
        if legacy_art:
            var path:="res://assets/sprites/original_creatures/"+kind+"/motion_manifest.json"
            var data: Dictionary=ART.manifest(path)
            enemy.asset_path=path;enemy.visual_scale=float(data.visual_scale)
            enemy.visual_offset=Vector2(float(data.visual_offset[0]),float(data.visual_offset[1]))
            enemy.authored_combat_sequences=[]
        if kind in bosses:
            enemy.battle_phase=2;enemy.arena_min_x=180;enemy.arena_max_x=650
            var expanded: Dictionary=ART.manifest(ART.character_manifest("original_creatures",kind))
            var retained: Dictionary=ART.manifest("res://assets/sprites/original_creatures/"+kind+"/motion_manifest.json")
            var width:=maxf(float(expanded.canvas[0])*float(expanded.visual_scale),float(retained.canvas[0])*float(retained.visual_scale))
            camera.zoom=Vector2.ONE*minf(2.0,1200.0/(width+500.0))
        enemy.position=Vector2(340,350);stage.add_child(enemy)
        label.text=("升级前 · " if legacy_art else "补帧后 · ")+kind+" / 固定靶 · 无声诊断"
        for frame in (720 if behavior_review else 360):
            if behavior_review:
                var mode:=int(frame/180)%4
                target.position.x=clampf(enemy.position.x+([125,290,390,140][mode]),190,640)
                target.velocity=Vector2(0,-160 if mode==1 else 0)
                target.heal_timer=.8 if mode==2 else 0.0
                target.attack_timer=.2 if mode==3 else 0.0
                if frame==360:enemy.hp=4000
                label.text=kind+" / "+String(enemy.boss_brain.intent)+" / "+enemy.state
            await physics_frame
            await process_frame
            await RenderingServer.frame_post_draw
            var image:=root.get_texture().get_image()
            if not behavior_review or frame%4==0:
                image.save_png(destination.path_join("frame_%05d.png" % index));index+=1
            events.append({"kind":kind,"frame":index-1,"intent":String(enemy.boss_brain.intent) if enemy.boss_brain!=null else "legacy","state":String(enemy.state),"animation":String(enemy.animated_sprite.animation),"pose":enemy.animated_sprite.frame,"progress":enemy.animated_sprite.frame_progress,"x":enemy.global_position.x,"y":enemy.global_position.y})
        enemy._cancel_attack_effects()
        preload("res://scripts/audio_retirement.gd").retire_tree(stage)
        stage.queue_free();enemy=null;target=null
        await process_frame;await process_frame
    preload("res://scripts/audio_retirement.gd").retire_tree(root)
    ART.frame_cache.clear();ART.textures.clear()
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    await preload("res://scripts/audio_retirement.gd").drain(self)
    var report:=FileAccess.open(destination.path_join("events.json"),FileAccess.WRITE)
    report.store_string(JSON.stringify(events))
    report.close()
    print("COMBAT_SHOWCASE_CAPTURE_PASS frames=%d" % index)
    quit()

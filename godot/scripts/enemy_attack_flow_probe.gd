extends SceneTree
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const ART:=preload("res://scripts/hand_drawn_assets.gd")
var summaries: Array=[]

class Target extends CharacterBody2D:
    var hp:=9999
    var ui_input_locked:=false
    var facing:=1
    func take_damage(_amount: int,_point: Vector2,_blockable: bool=true) -> bool:return false

func _initialize() -> void:call_deferred("run")

func run() -> void:
    for kind in ["moss_larva","bronze_moth","rust_crown_guardian","sunken_hammer_smith"]:
        var stage:=Node2D.new();root.add_child(stage)
        var target:=Target.new();target.position=Vector2(500,350);target.add_to_group("player");stage.add_child(target)
        var boss: bool=kind in ["rust_crown_guardian","sunken_hammer_smith"]
        var chapter:="demo_ch02_rain_foundry_canal" if kind=="sunken_hammer_smith" else "demo_ch01_moss_bell_court"
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+chapter+".json"))
        var enemy:=ENEMY.new()
        enemy.configure({"id":"flow_"+kind,"kind":kind,"hp":9999,"patrol":100},ART.character_manifest("original_creatures",kind),boss,config.ai_profiles[kind])
        enemy.position=Vector2(340,350);stage.add_child(enemy)
        var events: Array=[];var previous:="";var gap_start:=-1;var gaps: Array=[];var attacks:=0
        var stationary_gaps: Array=[];var stationary_frames:=0;var last_position:=enemy.global_position
        for frame in 1500:
            await physics_frame
            var state:=String(enemy.state)
            if gap_start>=0 and state=="patrol" and absf(enemy.global_position.x-last_position.x)<.03:stationary_frames+=1
            if state!=previous:
                var sprite: AnimatedSprite2D=enemy.animated_sprite
                events.append({"t":snappedf(frame/60.0,.001),"state":state,"decision":enemy.last_ai_decision,"desire":snappedf(enemy.attack_desire,.001),"animation":String(sprite.animation) if sprite!=null else "", "x":snappedf(enemy.position.x,.1)})
                if previous=="recover" and state in ["patrol","windup"]:gap_start=frame;stationary_frames=0
                if state=="windup":
                    attacks+=1
                    if gap_start>=0:
                        gaps.append(snappedf((frame-gap_start)/60.0,.001));stationary_gaps.append(snappedf(stationary_frames/60.0,.001));gap_start=-1
                previous=state
            last_position=enemy.global_position
        var result:={"kind":kind,"attack_count":attacks,"post_recovery_gaps":gaps,"stationary_post_recovery_seconds":stationary_gaps,"events":events}
        summaries.append(result)
        print("ENEMY_FLOW "+JSON.stringify(result))
        enemy._cancel_attack_effects()
        preload("res://scripts/audio_retirement.gd").retire_tree(stage)
        stage.queue_free()
        await process_frame;await process_frame
    var destination:=""
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--report="):destination=String(argument).trim_prefix("--report=")
    if not destination.is_empty():
        var file:=FileAccess.open(destination,FileAccess.WRITE);file.store_string(JSON.stringify({"simulation_seconds_each":25,"cases":summaries},"  "))
    print("ENEMY_FLOW_PROBE_PASS cases=4")
    preload("res://scripts/audio_retirement.gd").retire_tree(root)
    ART.frame_cache.clear()
    ART.textures.clear()
    await process_frame
    await preload("res://scripts/audio_retirement.gd").drain(self)
    quit()

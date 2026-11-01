extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func finish() -> void:
    for failure in failures:push_error(failure)
    print("UPGRADE_%s checks=%d failures=%d" % [get_script().resource_path.get_file().get_basename(),checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
func photograph() -> void:
    var target:=OS.get_environment("UPGRADE_CAPTURE")
    if target.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(target)
const PLAN=preload("res://scripts/npc_landmark_schedule.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
class Listener extends Node2D:
    var hp:=5
    var ui_input_locked:=false
func run() -> void:
    var rows: Array=[{"id":"near","distance":10.0},{"id":"far","distance":500.0}]
    check(PLAN.choose(rows,{"near":10000,"far":0},30000)==1,"least recently heard neighbor outranks nearest")
    check(PLAN.choose(rows,{},30000)==0,"unheard ties prefer nearest")
    check(PLAN.choose([{"id":"z","distance":10},{"id":"a","distance":10}],{},30000)==1,"equal distances use deterministic identity")
    check(PLAN.choose(rows,{"near":25000,"far":25000},30000)==-1,"per-NPC cooldown prevents replay")
    for distance in [NAN,INF,-1,651,"10"]:
        check(PLAN.choose([{"id":"bad","distance":distance}],{},30000)==-1,"invalid or distant landmark is ineligible")
    var host:=Node.new();root.add_child(host)
    var director:=AUDIO.new();director.autoplay_enabled=false;director.settings_path="user://upgrade_e10_audio.cfg";host.add_child(director);director.set_process(false)
    var player:=Listener.new();host.add_child(player);director.bind_runtime(player,func():return [])
    director.set_user_volume("master",100);director.set_user_volume("sfx",100)
    var npc:=Node2D.new();npc.set_meta("kind","npc");npc.set_meta("npc_id","upgrade_fixture");npc.position=Vector2(50,0);host.add_child(npc)
    director.landmark_next_ms=0;await physics_frame
    check(director.play_npc_landmark(npc),"actual visible NPC starts spatial landmark")
    var voice: AudioStreamPlayer2D
    for child in director.get_children():
        if child is AudioStreamPlayer2D and child.get_meta("npc_landmark",false):voice=child
    npc.hide();director._retire_invalid_landmarks()
    check(is_instance_valid(voice) and voice.is_queued_for_deletion() and voice.stream==null,"hidden source immediately releases stream")
    director.set_npc_landmarks(true)
    check(director.landmark_next_ms>=Time.get_ticks_msec()+1100,"reenabling gives entry grace")
    director.landmark_next_ms=0;director._tick_npc_landmarks()
    check(director.landmark_next_ms>=Time.get_ticks_msec()+400,"empty poll backs off")
    RETIRE.retire_tree(host);host.free();await process_frame;AUDIO._npc_voice_cache.clear()
    await RETIRE.drain(self,2000)
    finish()

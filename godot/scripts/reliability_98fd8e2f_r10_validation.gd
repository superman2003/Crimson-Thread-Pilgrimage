extends SceneTree
const SPATIAL=preload("res://scripts/spatial_enemy_alert.gd")
const SCHEDULE=preload("res://scripts/landmark_spatial_refresh.gd")
const DIRECTOR=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
class TestDirector extends "res://scripts/audio_director.gd":
    func _ready() -> void:pass
    func _process(_delta: float) -> void:pass
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var schedule:=SCHEDULE.new()
    check(schedule.choose(5,100)==[0,1],"two rays maximum")
    check(schedule.choose(5,101).is_empty(),"same interval no extra rays")
    check(schedule.choose(5,200)==[2,3] and schedule.choose(5,300)==[4,0],"round robin services all voices")
    check(schedule.choose(0,301).is_empty(),"empty set resets without retaining actors")
    var listener:=CharacterBody2D.new();root.add_child(listener)
    var source:=Node2D.new();source.position=Vector2(300,0);root.add_child(source)
    var director:=TestDirector.new();root.add_child(director);director.runtime_player=listener
    var voice:=SPATIAL.new();director.add_child(voice)
    voice.set_meta("npc_landmark",true);voice.set_meta("landmark_source",weakref(source))
    check(voice.place(source.global_position,listener,-25.0),"actual spatial voice placed")
    voice.max_distance=650
    check(not voice.occluded and is_equal_approx(voice.volume_db,-25),"initial open path")
    var wall:=StaticBody2D.new();wall.position=Vector2(150,0)
    var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(30,150);shape.shape=rectangle;wall.add_child(shape);root.add_child(wall)
    await physics_frame;await physics_frame
    director.landmark_spatial_refresh.next_ms=0;director._retire_invalid_landmarks()
    check(voice.occluded and is_equal_approx(voice.volume_db,-37),"new wall refreshes existing landmark attenuation")
    check(voice.max_distance==650,"refresh retains landmark-specific range")
    wall.position.y=400;await physics_frame;await physics_frame
    source.position=Vector2(320,10)
    director.landmark_spatial_refresh.next_ms=0;director._retire_invalid_landmarks()
    check(not voice.occluded and is_equal_approx(voice.volume_db,-25),"opened door restores original base without cumulative dimming")
    check(voice.global_position==source.global_position,"moving source refreshes actual emitter")
    source.hide();director._retire_invalid_landmarks()
    check(voice.is_queued_for_deletion(),"hidden source retires immediately")
    director.free();source.free();listener.free();wall.free()
    await process_frame;await process_frame
    print("RELIABILITY_R10 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

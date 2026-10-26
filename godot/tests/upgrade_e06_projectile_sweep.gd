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
const SWEEP=preload("res://scripts/attack_sweep.gd")
class Shot extends "res://scripts/enemy_attack_effect.gd":
    func _finish_impact(_point: Vector2) -> void:cancelled=true
class Target extends CharacterBody2D:
    var facing:=1
    var hp:=10
    var ui_input_locked:=false
    var hits:=0
    var parrying:=false
    func take_damage(_damage,_point,_blockable):hits+=1
    func can_deflect_projectile():return parrying
class Enemy extends Node2D:
    var hits:=0
    var dying:=false
    func take_hit(_damage,_direction):hits+=1
func run() -> void:
    check(is_equal_approx(SWEEP.circle_time(Vector2.ZERO,Vector2(100,0),Vector2(50,0),10),0.4),"earliest contact occurs before endpoint")
    check(is_inf(SWEEP.circle_time(Vector2.ZERO,Vector2(100,0),Vector2(50,30),10)),"parallel path misses")
    check(SWEEP.circle_time(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,10)==0,"stationary overlap is contact")
    check(is_inf(SWEEP.circle_time(Vector2(NAN,0),Vector2.ONE,Vector2.ZERO,10)),"nonfinite input is rejected")
    var host:=Node2D.new();root.add_child(host)
    var player:=Target.new();host.add_child(player);player.position=Vector2(100,42)
    for fps in [30,60,120]:
        var shot:=Shot.new();host.add_child(shot);shot.set_physics_process(false);shot.velocity=Vector2(18000,0)
        var end:=Vector2(18000.0/fps,0)
        check(shot._resolve_swept_projectile(player,Vector2.ZERO,end,{}) and shot.hit_player,"fast shot hits across physics rates")
        shot.free()
    check(player.hits==3,"each shot damages only once")
    var shot:=Shot.new();host.add_child(shot);shot.set_physics_process(false)
    check(not shot._resolve_swept_projectile(player,Vector2.ZERO,Vector2(200,0),{"position":Vector2(20,0)}),"earlier wall blocks player")
    check(shot._resolve_swept_projectile(player,Vector2.ZERO,Vector2(200,0),{"position":Vector2(180,0)}),"player before later wall remains hittable")
    shot.free()
    shot=Shot.new();host.add_child(shot);shot.set_physics_process(false);shot.velocity=Vector2(-1000,0);player.parrying=true
    check(shot._resolve_swept_projectile(player,Vector2(200,0),Vector2.ZERO,{}) and shot.reflected and shot.velocity.x>0,"front parry reflects at swept contact")
    shot.free()
    var far:=Enemy.new();far.position=Vector2(170,0);host.add_child(far);far.add_to_group("enemy")
    var near:=Enemy.new();near.position=Vector2(80,0);host.add_child(near);near.add_to_group("enemy")
    shot=Shot.new();host.add_child(shot);shot.set_physics_process(false);shot.reflected=true;shot.velocity=Vector2.RIGHT*1000
    check(shot._resolve_swept_projectile(null,Vector2.ZERO,Vector2(250,0),{}) and near.hits==1 and far.hits==0,"reflected shot selects first contact regardless of group order")
    host.free();await process_frame;finish()

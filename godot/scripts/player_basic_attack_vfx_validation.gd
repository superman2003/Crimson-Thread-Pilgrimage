extends SceneTree
## Production attacks must stay free of decorative lines while combat still advances.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func frames(count: int) -> void:
    for index in count: await physics_frame; await process_frame
func live_lines(player: Node) -> Array:
    return player.find_children("*","Line2D",true,false).filter(func(n):return not n.is_queued_for_deletion())
func run() -> void:
    var arena := Node2D.new(); root.add_child(arena)
    var floor_body := StaticBody2D.new(); arena.add_child(floor_body)
    var shape := CollisionShape2D.new(); var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(1600,20); shape.shape = rectangle
    floor_body.position = Vector2(0,10); floor_body.add_child(shape)
    var player = load("res://scenes/Player.tscn").instantiate()
    player.set_script(QuietPlayer); arena.add_child(player)
    player.feel = null; player.get_node("Camera2D").enabled = false
    await frames(4)
    for crest in ["crimson","bell","salt"]:
        player.apply_build_stats({"crest_id":crest,"crimson_repaired":true})
        for airborne in [false,true]:
            for facing in [1,-1]:
                for direction in [Vector2(facing,0),Vector2.UP,Vector2.DOWN]:
                    player._reset_traversal_state(); player.hurt_timer=0; player.arrival_guard_timer=0
                    player.position=Vector2(0,-180 if airborne else 0); player.velocity=Vector2.ZERO
                    player.set_physics_process(true); await frames(3); player.set_physics_process(false)
                    check(player.is_on_floor()==not airborne,"fixture establishes actual ground/air contact")
                    player.facing=facing; player.sprite.flip_h=facing<0
                    player._start_attack(&"attack_1",false,direction)
                    var before: Array=[player.attack_duration,player.attack_windup,player.attack_active_time,player.attack_damage,player.attack_range,player.attack_height,player.energy,player.hp]
                    var prior_lines := live_lines(player)
                    var dt: float=player.attack_duration/16.0
                    for tick in 18:
                        if tick>0: player._update_attack(dt)
                        player._update_animation(0)
                        check(player.get_node_or_null("AttackSlashVfx")==null,"no basic ribbon at any attack phase")
                        check(live_lines(player).all(func(n):return prior_lines.has(n)),"attack allocates no line or ring fallback")
                        check(get_nodes_in_group(POLICY.ACTION_TRACE_GROUP).filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"seal cues add no decorative attack trace")
                    check(before==[player.attack_duration,player.attack_windup,player.attack_active_time,player.attack_damage,player.attack_range,player.attack_height,player.energy,player.hp],"visual removal preserves timing, geometry, HP and whiff energy")
                    check(player.attack_timer<=0 and player.attack_shape.disabled,"attack still completes and closes its damage window")
                    await process_frame
    # Previously this unsupported heavy family entered the pink line/ring fallback.
    player._reset_traversal_state(); player.apply_build_stats({"crest_id":"crimson","crimson_repaired":true})
    player._start_attack(&"attack_2",false,Vector2.RIGHT)
    player._update_attack(player.attack_windup+0.001)
    check(player.attack_vfx_started and player.get_node_or_null("SkillSlashVfx")==null and player.get_node_or_null("SkillBurstRingVfx")==null,"unsupported heavy slash cannot restore legacy line art")
    for action in ["cleave","crosscut","needle","snare","ward","shockwave"]:
        for phase in ["prepare","active","recovery"]: player._seal_present(action,phase)
    check(player.seal_presentation.active_effect_count()==0,"all attack cue stages are audio-only")
    player.seal_presentation.cue_unblockable(Vector2(40,-40))
    check(player.seal_presentation.active_effect_count()==1,"real unblockable danger cue remains available")
    arena.queue_free(); await process_frame; await process_frame
    print("PLAYER_BASIC_ATTACK_VFX checks=%d failures=%d"%[checks,failures])
    quit(0 if failures==0 else 1)

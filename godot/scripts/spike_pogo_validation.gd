extends SceneTree
const LEVEL := preload("res://scripts/main_level.gd")
const PLAYER := preload("res://scenes/Player.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var level:=LEVEL.new()
    var player: CharacterBody2D=PLAYER.instantiate()
    root.add_child(player);level.player=player;level.world_loading=false
    for result in preload("res://scripts/trap_free_validation_helper.gd").probe(level,player):
        checks+=1
        if not bool(result[0]): failures+=1;push_error(String(result[1]))
    checks+=1
    if not get_nodes_in_group("pogo_surface").is_empty(): failures+=1
    preload("res://scripts/audio_retirement.gd").retire_tree(player)
    player.queue_free();level.free();await process_frame;await process_frame
    print("SPIKE_POGO checks=%d failures=%d"%[checks,failures])
    quit(0 if failures==0 else 1)

extends SceneTree

const ARENA := preload("res://scripts/sparring_arena.gd")
const BUILD := preload("res://scripts/build_system.gd")

var checks := 0
var failures := 0

class PracticePlayer extends CharacterBody2D:
	var accept_cast := false
	func cast_tool(_payload: Dictionary) -> bool:
		return accept_cast


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func run() -> void:
	var arena: Node2D = ARENA.new()
	root.add_child(arena)
	arena.build = BUILD.new()
	arena.build.unlock_event("tool_shard_found")
	arena.build.select_tool("shard", 0)
	arena.build.state.tool_counts.shard = 1
	arena.player = PracticePlayer.new()
	arena.add_child(arena.player)
	check(not arena._use_tool() and int(arena.build.state.tool_counts.shard) == 1,
		"a rejected practice cast refunds the cloned tool charge")
	(arena.player as PracticePlayer).accept_cast = true
	check(arena._use_tool() and int(arena.build.state.tool_counts.shard) == 0,
		"an accepted practice cast consumes exactly one cloned charge")
	arena.last_hp = 5
	arena.hits = 0
	arena._on_player_hp_changed(4)
	check(arena.hits == 1, "taking damage increments sparring hit counter")
	arena._on_player_hp_changed(5)
	check(arena.hits == 1, "healing upward does not increment sparring hit counter")
	arena.build = null
	arena.free()
	await process_frame
	print("SPARRING_TOOL_ACCEPTANCE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

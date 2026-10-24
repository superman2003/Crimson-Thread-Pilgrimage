extends Node
## Own only the final OS close boundary; ordinary region/scene retirement is unchanged.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const OWNER_NAME := "PilgrimageApplicationClose"
var closing := false

static func install(tree: SceneTree) -> void:
    if tree.root.get_node_or_null(NodePath(OWNER_NAME)) != null:
        return
    var owner := new()
    owner.name = OWNER_NAME
    tree.root.add_child(owner)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().auto_accept_quit = false
    get_tree().root.close_requested.connect(_close_requested)

func _close_requested() -> void:
    if closing:
        return
    closing = true
    var tree := get_tree()
    # No new gameplay/voice admission while releasing the application owners.
    tree.paused = true
    RETIREMENT.retire_tree(tree.root)
    for child in tree.root.get_children():
        if child != self:
            child.queue_free()
    # Normal _exit_tree hooks cancel and join region/resource workers. Keep the
    # SceneTree and audio backend alive until those owners have actually left.
    await tree.process_frame
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    var drained := await RETIREMENT.drain(tree)
    if OS.is_stdout_verbose():
        print("APPLICATION_CLOSE drained=%s pending=%d" % [str(drained), RETIREMENT.pending.size()])
    tree.quit(0 if drained else 1)

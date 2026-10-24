extends Node
## Own only the final OS close boundary; ordinary region/scene retirement is unchanged.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const OWNER_NAME := "PilgrimageApplicationClose"
var closing := false

static func install(tree: SceneTree) -> void:
    # The main scene installs from _ready while root is still adding children,
    # so a direct add_child fails and leaks the owner; join on the next idle.
    if tree.root.get_node_or_null(NodePath(OWNER_NAME)) != null or tree.root.has_meta(OWNER_NAME):
        return
    var owner := new()
    owner.name = OWNER_NAME
    tree.root.set_meta(OWNER_NAME, true)
    tree.root.add_child.call_deferred(owner)

func _exit_tree() -> void:
    if get_tree() != null and get_tree().root.has_meta(OWNER_NAME):
        get_tree().root.remove_meta(OWNER_NAME)

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

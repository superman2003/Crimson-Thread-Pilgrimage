extends RefCounted
## Weak bookkeeping only: do not keep AudioServer playback or streams alive.
static var pending: Dictionary = {}
static var observed := 0
static var retired := 0

static func watch(voice: AudioStreamPlayer2D) -> void:
    watch_player(voice)

static func watch_player(voice: Node) -> void:
    if not is_instance_valid(voice):
        return
    if not (voice is AudioStreamPlayer or voice is AudioStreamPlayer2D):
        return
    var stream: AudioStream
    var playback: AudioStreamPlayback
    if voice is AudioStreamPlayer:
        var player := voice as AudioStreamPlayer
        stream = player.stream
        if player.playing:
            playback = player.get_stream_playback()
    else:
        var player_2d := voice as AudioStreamPlayer2D
        stream = player_2d.stream
        if player_2d.playing:
            playback = player_2d.get_stream_playback()
    if stream != null:
        _track(stream, "stream")
    if voice.playing and playback != null:
        _track(playback, "playback")
        observed += 1

## Capture every owned player before stopping it and releasing its stream.
## Call before the scene's children leave the tree so AudioServer playback stays observable.
static func retire_tree(root: Node) -> int:
    if not is_instance_valid(root):
        return 0
    var count := _retire_subtree(root)
    retired += count
    return count

static func _retire_subtree(root: Node) -> int:
    var count := _retire_node(root)
    for child in root.get_children():
        count += _retire_subtree(child)
    return count

static func _retire_node(node: Node) -> int:
    if node is AudioStreamPlayer:
        var player := node as AudioStreamPlayer
        watch_player(player)
        if player.playing:
            player.stop()
        player.stream = null
        return 1
    if node is AudioStreamPlayer2D:
        var player_2d := node as AudioStreamPlayer2D
        watch_player(player_2d)
        if player_2d.playing:
            player_2d.stop()
        player_2d.stream = null
        return 1
    return 0

static func _track(resource: Object, kind: String) -> void:
    var id := resource.get_instance_id()
    pending[id] = {"ref": weakref(resource), "kind": kind}

static func _prune() -> void:
    for id in pending.keys():
        var entry: Dictionary = pending[id]
        if entry.ref.get_ref() == null:
            pending.erase(id)

## For accelerated headless teardown: rendered frames are not audio mix ticks.
## Retire scene voices first, then wait for actual playback ownership to end.
static func drain(tree: SceneTree, timeout_msec: int = 1000) -> bool:
    var started := Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < timeout_msec:
        _prune()
        if pending.is_empty():
            print("AUDIO_RETIREMENT pending=0 elapsed_msec=%d observed=%d retired=%d" % [Time.get_ticks_msec() - started, observed, retired])
            return true
        await tree.process_frame
    _prune()
    if not pending.is_empty():
        var kinds := {}
        for entry_value in pending.values():
            var entry: Dictionary = entry_value
            var kind := String(entry.get("kind", "unknown"))
            kinds[kind] = int(kinds.get(kind, 0)) + 1
        push_error("AUDIO_RETIREMENT timeout pending=%s elapsed_msec=%d" % [JSON.stringify(kinds), Time.get_ticks_msec() - started])
    return false

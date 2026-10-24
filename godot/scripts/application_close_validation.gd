extends SceneTree
const CLOSE := preload("res://scripts/application_close.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0
var streams: Array[WeakRef] = []
var playbacks: Array[WeakRef] = []
var exited := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func _add_voice(container: Node, spatial: bool) -> void:
    var voice: Node = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
    voice.stream = AUDIO.load_cached("res://assets/audio/bgm/generated/ch05_obsidian_pilgrim_road_explore_loop.ogg", true)
    container.add_child(voice)
    voice.play()
    streams.append(weakref(voice.stream))
    playbacks.append(weakref(voice.get_stream_playback()))

func _run() -> void:
    CLOSE.install(self)
    var owner := root.get_node(NodePath(CLOSE.OWNER_NAME))
    CLOSE.install(self)
    _check(root.get_node(NodePath(CLOSE.OWNER_NAME)) == owner, "one owner across repeated World installation")
    _check(not auto_accept_quit and not paused and not owner.closing, "only explicit OS close starts shutdown")
    var container := Node.new()
    root.add_child(container)
    container.tree_exiting.connect(func(): exited += 1)
    _add_voice(container, false)
    _add_voice(container, true)
    await process_frame
    _check(playbacks.size() == 2 and playbacks.all(func(ref): return ref.get_ref() != null), "two actual Ogg players are live")
    _check(not AUDIO._stream_cache.is_empty(), "application cache actually owns the stream")
    root.tree_exiting.connect(_verify_exit, CONNECT_ONE_SHOT)
    paused = true
    root.close_requested.emit()
    root.close_requested.emit()
    _check(owner.closing and paused, "paused application admits a single close transition")
    _check(container.is_queued_for_deletion(), "close releases the real scene owner")

func _verify_exit() -> void:
    _check(exited == 1, "duplicate close frees the scene exactly once")
    _check(RETIREMENT.observed >= 2, "live playback was captured before scene exit")
    _check(RETIREMENT.pending.is_empty(), "weak retirement completed before quitting")
    _check(streams.all(func(ref): return ref.get_ref() == null), "Ogg streams have no remaining owner")
    _check(playbacks.all(func(ref): return ref.get_ref() == null), "Ogg playback has no remaining owner")
    _check(AUDIO._stream_cache.is_empty() and AUDIO._npc_voice_cache.is_empty(), "final application cache lifetime ended")
    print("APPLICATION_CLOSE_VALIDATION checks=%d failures=%d" % [checks, failures])

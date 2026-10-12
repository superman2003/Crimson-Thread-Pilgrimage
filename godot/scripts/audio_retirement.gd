extends RefCounted
## Weak bookkeeping only: do not keep AudioServer playback or WAV resources alive.
static var pending: Dictionary = {}
static var observed := 0

static func watch(voice: AudioStreamPlayer2D) -> void:
    _prune()
    if voice.playing:
        var playback: AudioStreamPlayback = voice.get_stream_playback()
        if playback != null:
            pending[playback.get_instance_id()] = weakref(playback)
            if voice.stream != null:
                pending[voice.stream.get_instance_id()] = weakref(voice.stream)
            observed += 1

static func _prune() -> void:
    for id in pending.keys():
        if pending[id].get_ref() == null:
            pending.erase(id)

## For accelerated headless teardown: rendered frames are not audio mix ticks.
## Retire scene voices first, then wait for actual playback ownership to end.
static func drain(tree: SceneTree, timeout_msec: int = 1000) -> bool:
    var started := Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < timeout_msec:
        _prune()
        if pending.is_empty():
            print("AUDIO_RETIREMENT pending=0 elapsed_msec=%d observed=%d" % [Time.get_ticks_msec() - started, observed])
            return true
        await tree.process_frame
    return false

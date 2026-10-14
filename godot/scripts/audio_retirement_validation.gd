extends SceneTree
const PRESENTATION := preload("res://scripts/seal_presentation.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var watches := RETIREMENT.observed
    var presentation := PRESENTATION.new()
    root.add_child(presentation)
    for i in range(12):
        presentation.play_action("cleave", "active")
    await physics_frame
    await process_frame
    var voice: AudioStreamPlayer2D = presentation._voices.back()
    var playback: WeakRef = weakref(voice.get_stream_playback())
    var wav: WeakRef = weakref(voice.stream)
    root.remove_child(presentation)
    if voice.playing or voice.stream != null or not presentation._streams.is_empty():
        failures += 1
    presentation.free()
    if RETIREMENT.observed - watches != 12:
        failures += 1
    if not await RETIREMENT.drain(self) or playback.get_ref() != null or wav.get_ref() != null:
        failures += 1
    if failures > 0:
        push_error("retired playback/WAV ownership did not drain")
    print("AUDIO RETIREMENT PASS: live cap eviction and immediate scene exit, failures=%d" % failures)
    call_deferred("quit", 1 if failures > 0 else 0)

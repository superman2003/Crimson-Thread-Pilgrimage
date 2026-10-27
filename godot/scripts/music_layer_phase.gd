extends RefCounted
## Both stems share the same output queue. Predict the source's position at the
## next mixer boundary; subtracting output latency here would offset it twice.
static func phase(position: float, since_mix: float, until_mix: float, speed: float, length: float) -> float:
    for value in [position, since_mix, until_mix, speed, length]:
        if not is_finite(value):
            return 0.0
    if position < 0.0 or speed <= 0.0 or length <= 0.0:
        return 0.0
    return fposmod(position + (maxf(0.0, since_mix) + maxf(0.0, until_mix)) * speed, length)

static func start_position(source: Variant, target: AudioStream) -> float:
    if not is_instance_valid(source) or not source is AudioStreamPlayer:
        return 0.0
    if not source.is_inside_tree() or source.is_queued_for_deletion():
        return 0.0
    if not source.playing or source.stream_paused or source.stream == null or target == null:
        return 0.0
    return phase(source.get_playback_position(), AudioServer.get_time_since_last_mix(),
        AudioServer.get_time_to_next_mix(), source.pitch_scale * AudioServer.playback_speed_scale, target.get_length())

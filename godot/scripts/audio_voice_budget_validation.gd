extends RefCounted
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var checks := 0
func run(tree: SceneTree, check: Callable) -> void:
    var host := Node.new()
    tree.root.add_child(host)
    # Real looping WAV stays audible beyond the old nominal 900 ms accounting.
    var stream := AudioStreamWAV.new()
    stream.format=AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate=22050
    stream.data=PackedByteArray()
    var samples := PackedByteArray()
    samples.resize(4410)
    for index in 2205:samples.encode_s16(index*2,int(sin(TAU*220.0*float(index)/22050.0)*1600.0))
    stream.data=samples
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    stream.loop_end=2205
    var voices: Array[Node] = []
    for index in AUDIO.MAX_GLOBAL_VOICES:
        var voice: Node = AudioStreamPlayer.new() if index%2==0 else AudioStreamPlayer2D.new()
        voice.stream=stream
        host.add_child(voice)
        var ticket := AUDIO.reserve_voice("budget_%d" % index,2,0,1)
        _check(check,ticket>0 and AUDIO.start_reserved_voice(ticket,voice),"actual low-priority playback enters available slot")
        voices.append(voice)
    await tree.create_timer(1.05).timeout
    _check(check,AUDIO.active_voice_count()==24 and _playing(voices)==24,"long playback still occupies all slots after nominal duration")
    _check(check,AUDIO.reserve_voice("same_priority",2,0,1)==0,"full budget refuses equal priority without removing live sound")
    var critical := AudioStreamPlayer.new()
    critical.stream=stream
    host.add_child(critical)
    var critical_ticket := AUDIO.reserve_voice("critical_warning",0,0,1)
    _check(check,critical_ticket>0 and not voices[0].playing,"critical admission actually stops a lower-priority player")
    _check(check,AUDIO.start_reserved_voice(critical_ticket,critical),"critical warning claims its exact reservation")
    _check(check,_playing(voices)+int(critical.playing)==24 and AUDIO.active_voice_count()==24,"actual audible player count stays within global budget")
    var escaped := AudioStreamPlayer.new()
    escaped.stream=stream
    host.add_child(escaped)
    _check(check,not AUDIO.start_reserved_voice(critical_ticket,escaped) and not escaped.playing,"a consumed ticket cannot start a second player")
    _check(check,critical.playing and AUDIO.active_voice_count()==24,"rejecting duplicate ticket must preserve its already playing owner")
    RETIRE.retire_tree(host)
    host.queue_free()
    await tree.process_frame
    _check(check,AUDIO.active_voice_count()==0,"tree retirement releases all bound slots")
    var first := AUDIO.reserve_voice("same_key",1,0,3)
    var second := AUDIO.reserve_voice("same_key",1,0,3)
    AUDIO.release_ticket(first)
    _check(check,AUDIO.reserve_voice("same_key",1,900,3)==0,"older same-key rollback cannot erase a newer throttle timestamp")
    AUDIO.release_ticket(second)
    var recovered := AUDIO.reserve_voice("same_key",1,900,3)
    _check(check,recovered>0,"rolling back latest missing-stream reservation permits retry")
    AUDIO.release_ticket(recovered)
    var short_stream := stream.duplicate() as AudioStreamWAV
    short_stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
    var short_voice := AudioStreamPlayer.new()
    short_voice.stream=short_stream
    tree.root.add_child(short_voice)
    short_voice.finished.connect(short_voice.queue_free)
    var short_ticket := AUDIO.reserve_voice("short",1,0,1)
    AUDIO.start_reserved_voice(short_ticket,short_voice)
    _check(check,AUDIO.reserve_voice("short",1,0,1)==0,"same-key concurrency rejects overlap while a real one-shot is playing")
    await tree.create_timer(0.3).timeout
    _check(check,AUDIO.active_voice_count()==0,"natural completion releases a slot before nominal timeout")
    short_ticket=AUDIO.reserve_voice("short",1,0,1)
    _check(check,short_ticket>0,"next one-shot is not blocked by a finished voice's old nominal duration")
    AUDIO.release_ticket(short_ticket)
    short_stream=null
    var expired := AUDIO.reserve_voice("abandoned",2,0,1)
    await tree.create_timer(1.0).timeout
    var late := AudioStreamPlayer.new()
    late.stream=stream
    tree.root.add_child(late)
    _check(check,not AUDIO.start_reserved_voice(expired,late) and not late.playing,"expired deferred reservation cannot escape admission")
    var reusable := AudioStreamPlayer.new()
    reusable.stream=stream
    tree.root.add_child(reusable)
    var reusable_ticket := AUDIO.reserve_voice("reusable",1,0,1)
    AUDIO.start_reserved_voice(reusable_ticket,reusable,true)
    reusable.stream_paused=true
    _check(check,AUDIO.active_voice_count()==1,"paused playback retains its slot")
    reusable.stop()
    _check(check,AUDIO.active_voice_count()==0,"stopping a paused player releases its slot even with pause flag retained")
    reusable.stream_paused=false
    reusable_ticket=AUDIO.reserve_voice("reusable",1,0,1)
    AUDIO.start_reserved_voice(reusable_ticket,reusable,true)
    AUDIO.release_ticket(reusable_ticket)
    _check(check,is_instance_valid(reusable) and not reusable.is_queued_for_deletion() and not reusable.playing,"persistent player survives actual preemption for later reuse")
    reusable_ticket=AUDIO.reserve_voice("reusable",1,0,1)
    _check(check,AUDIO.start_reserved_voice(reusable_ticket,reusable,true),"persistent player can acquire a fresh lease")
    RETIRE.retire_tree(reusable)
    reusable.queue_free()
    await tree.process_frame
    var presentation := preload("res://scripts/seal_presentation.gd").new()
    tree.root.add_child(presentation)
    for index in 4:presentation.cue_unblockable(Vector2.ZERO)
    _check(check,presentation._voices.size()==4,"four local critical cues claim real playback slots")
    presentation._sound("cleave_active",Vector2.ZERO)
    _check(check,presentation._voices.size()==4 and _playing(presentation._voices)==4,"cosmetic action sound cannot evict local critical warnings")
    RETIRE.retire_tree(presentation)
    presentation.queue_free()
    await tree.process_frame
    _check(check,AUDIO.active_voice_count()==0,"presentation retirement releases global voice ownership")
    stream=null
    await tree.process_frame
    _check(check,AUDIO.active_voice_count()==0 and await RETIRE.drain(tree),"voice budget retains no player, stream or playback after retirement")
    print("AUDIO_VOICE_BUDGET checks=%d" % checks)

func _playing(voices: Array) -> int:
    var total := 0
    for voice in voices:
        if is_instance_valid(voice) and voice.playing:total += 1
    return total

func _check(callback: Callable,ok: bool,label: String) -> void:
    checks += 1
    callback.call(ok,label)

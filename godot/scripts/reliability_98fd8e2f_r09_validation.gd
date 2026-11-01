extends SceneTree
const DIRECTOR=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
class TestDirector extends "res://scripts/audio_director.gd":
    var fail_music:=true
    var requests:=0
    var candidate: AudioStreamWAV
    func _ready() -> void:pass
    func _process(_delta: float) -> void:pass
    func _music_candidate(_path: String) -> AudioStream:
        requests+=1
        return null if fail_music else candidate
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var music:=AudioStreamWAV.new();music.format=AudioStreamWAV.FORMAT_16_BITS;music.mix_rate=22050;var bytes:=PackedByteArray();bytes.resize(44100);music.data=bytes;music.loop_mode=AudioStreamWAV.LOOP_FORWARD;music.loop_end=22050
    var director:=TestDirector.new();director.candidate=music;root.add_child(director)
    for path in director.FINAL_BOSS_MOVEMENTS:DIRECTOR._stream_cache[String(path)+"|1"]=music
    director.autoplay_enabled=true
    director.explore_player=AudioStreamPlayer.new();director.add_child(director.explore_player);director.explore_player.stream=music;director.explore_player.play()
    director.start_boss_music(director.FINAL_BOSS_ID)
    check(not director.boss_active and director.boss_phase==0,"missing boss never commits active state")
    check(not director.explore_player.stream_paused and director.explore_tween==null,"missing boss never schedules exploration pause")
    director.start_lullaby()
    check(not director.lullaby_active,"missing lullaby can be retried")
    director.fail_music=false;director.start_lullaby()
    check(director.lullaby_active and director.lullaby_player.playing,"lullaby retry starts actual stream")
    director.start_boss_music(director.FINAL_BOSS_ID)
    check(director.boss_active and not director.lullaby_active and director.boss_player.playing,"valid boss commits and replaces lullaby")
    director.fail_music=true;director.set_boss_phase(2)
    check(director.boss_phase==1 and director.boss_player.stream==music,"missing phase retains current movement")
    director.fail_music=false;director.set_boss_phase(2)
    check(director.boss_phase==2,"valid phase retry commits")
    director.set_boss_phase(9);check(director.boss_phase==3,"phase clamped")
    var previous:=director.requests;director.set_boss_phase(9)
    check(director.boss_phase==3 and director.requests==previous,"same clamped phase does not select another movement")
    var retry:=DIRECTOR.new()
    var fake:="res://missing.ogg";DIRECTOR._stream_cache[fake+"|1"]=null
    retry.music_retry_after[fake]=Time.get_ticks_msec()+1000
    check(retry._music_candidate(fake)==null,"negative music retry throttled")
    DIRECTOR._stream_cache[fake+"|1"]=music
    check(retry._music_candidate(fake)==music and not retry.music_retry_after.has(fake),"available music clears failure window")
    retry.free()
    for player in [director.explore_player,director.boss_player,director.lullaby_player]:
        if is_instance_valid(player):preload("res://scripts/audio_retirement.gd").watch_player(player)
    director.free();DIRECTOR._stream_cache.clear();music=null
    for unused in 20:await create_timer(.01).timeout
    print("RELIABILITY_R09 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

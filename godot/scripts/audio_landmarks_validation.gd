extends SceneTree
const MIX = preload("res://scripts/duck_mix.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures: Array[String] = []
class UiContext extends Node:
    var audio_director: Node
    var player: Node
class Listener extends CharacterBody2D:
    var hp := 5
    var ui_input_locked := false
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func cue(director: Node) -> AudioStreamPlayer2D:
    for child in director.get_children():
        if child is AudioStreamPlayer2D and not child.is_queued_for_deletion() and child.get_meta("npc_landmark",false):return child
    return null

func run() -> void:
    var mix := MIX.new()
    check(mix.admit(1,-12).ok and mix.admit(2,-3).ok, "independent foreground envelopes receive separate leases")
    mix.set_level(1,-12);mix.set_level(2,-3)
    check(mix.level() == -12, "weaker cue cannot replace the stronger active attenuation")
    mix.remove(2)
    check(mix.level() == -12, "weaker completion cannot restore another cue's music")
    mix.remove(1);mix.set_level(1,-20)
    check(mix.level() == 0 and mix.layers.is_empty(), "late callbacks from retired leases cannot change the mix")
    check(not mix.admit(0,-2).ok and not mix.admit(1,NAN).ok and not mix.admit(1,INF).ok, "malformed lease values are rejected")
    for index in 8:mix.admit(index+1,-float(index+1)*2);mix.set_level(index+1,-float(index+1)*2)
    var before := mix.level()
    check(not mix.admit(99,-1).ok and mix.layers.size() == 8, "full layer budget rejects a weaker request")
    var strongest: Dictionary = mix.admit(100,-50)
    check(strongest.ok and strongest.target == -24 and mix.layers.size() == 8 and mix.level() <= before, "stronger admission is bounded and does not brighten the current mix")
    mix.set_level(100,NAN)
    check(is_finite(mix.level()), "non-finite animation update cannot corrupt the mixer")

    var host := Node.new();root.add_child(host)
    var director := AUDIO.new();director.autoplay_enabled=false;director.settings_path="user://audio_landmarks_mix.cfg";host.add_child(director);director.set_process(false)
    var bus:=AudioServer.get_bus_index("BGM")
    check(bus>=0,"actual project music bus exists")
    director._set_music_bus_db(-5)
    director.duck(-12,0.2,0.01,0.01)
    var strong_id:=int(director.duck_serial);director._set_duck_layer(strong_id,-12)
    director.duck(-3,0.01,0.01,0.01)
    var weak_id:=int(director.duck_serial);director._set_duck_layer(weak_id,-3)
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-17),"actual music bus combines overlapping ducks by strongest level")
    director.duck_mix.remove(weak_id);director._render_music_mix()
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-17),"retiring a weak actual layer keeps the strong layer")
    director.set_user_volume("music",50)
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(0.5)-12),"user volume updates the live baseline under active attenuation")
    director.on_dialogue(true);director.set_user_volume("music",40)
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(0.4)+AUDIO.DIALOGUE_MUSIC_DUCK_DB-12),"dialogue baseline and transient leases coexist")
    await create_timer(0.35).timeout
    await process_frame
    check(director.duck_mix.layers.is_empty() and is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(0.4)+AUDIO.DIALOGUE_MUSIC_DUCK_DB),"completed independent envelopes restore the latest user and dialogue baseline")
    director.set_user_volume("music",0);director.duck(-6,0.1)
    check(AudioServer.is_bus_mute(bus),"transient mix never unmutes a user-muted music bus")
    var replacement:=AUDIO.new();replacement.autoplay_enabled=false;replacement.settings_path="user://audio_landmarks_replacement.cfg";host.add_child(replacement);replacement.set_process(false)
    replacement._set_music_bus_db(-7)
    director._set_duck_layer(int(director.duck_serial),-6)
    director.free()
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-7),"retired director callbacks and teardown cannot overwrite a newer owner")
    replacement.free()

    director=AUDIO.new();director.autoplay_enabled=false;director.settings_path="user://audio_landmarks_spatial.cfg";host.add_child(director);director.set_process(false)
    var player:=Listener.new();host.add_child(player)
    director.bind_runtime(player,func():return [])
    director.set_user_volume("master",100);director.set_user_volume("sfx",100)
    var npc:=Node2D.new();npc.set_meta("kind","npc");npc.set_meta("npc_id","npc_cartographer_fixture");npc.position=Vector2(300,0);host.add_child(npc)
    director.landmark_next_ms=0
    await physics_frame
    check(director.play_npc_landmark(npc),"actual nearby NPC starts a spatial nonverbal landmark")
    var voice:=cue(director)
    check(voice!=null and voice.global_position==npc.global_position and voice.max_distance==650 and voice.has_stream_playback(),"landmark uses actual positional playback with a finite hearing radius")
    check(not director.play_npc_landmark(npc),"global and per-NPC limits prevent repeated greeting spam")
    npc.position=Vector2(3000,0);director.landmark_next_ms=0
    check(not director.play_npc_landmark(npc),"distant NPCs cannot allocate landmark voices")
    npc.position=Vector2(300,0);director.on_dialogue(true)
    check(not voice.playing and not director.play_npc_landmark(npc),"foreground dialogue retires landmarks and suppresses new ones")
    director.on_dialogue(false);director.set_npc_landmarks(false)
    check(not director.play_npc_landmark(npc),"explicit landmark preference disables admission")
    director.set_npc_landmarks(true);player.ui_input_locked=true
    check(not director.play_npc_landmark(npc),"menus suppress exploration landmarks")
    player.ui_input_locked=false;player.hp=0
    check(not director.play_npc_landmark(npc),"dead player receives no exploration cue")
    player.hp=5
    var wall:=StaticBody2D.new();wall.position=Vector2(150,0)
    var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(20,200);collision.shape=shape;wall.add_child(collision);host.add_child(wall)
    npc.set_meta("npc_id","npc_carto_occluded_fixture");director.landmark_next_ms=0
    await physics_frame;await physics_frame
    check(director.play_npc_landmark(npc),"nearby occluded NPC can still have a quiet landmark")
    voice=cue(director)
    check(voice!=null and voice.occluded and voice.volume_db<=-37,"terrain occlusion attenuates actual landmark playback")
    director.foreground_warning(npc)
    check(not voice.playing and not director.duck_mix.layers.is_empty(),"nearby danger retires the landmark and gives music priority to the warning")
    director.set_user_volume("sfx",0)
    check(not director.play_npc_landmark(npc),"muted sound effects allocate no exploration landmarks")
    director.set_user_volume("sfx",100)
    npc.set_meta("npc_id","npc_tick_near");npc.position=Vector2(250,0);npc.add_to_group("npc_sound_landmark")
    var farther:=Node2D.new();farther.position=Vector2(500,0);farther.set_meta("kind","npc");farther.set_meta("npc_id","npc_tick_far");farther.add_to_group("npc_sound_landmark");host.add_child(farther)
    director.landmark_next_ms=0;director._tick_npc_landmarks()
    voice=cue(director)
    check(voice!=null and voice.global_position==npc.global_position,"runtime landmark poll selects the nearest eligible actual NPC")
    director._stop_npc_landmarks();await process_frame
    director.landmark_next_ms=0;director._tick_npc_landmarks()
    voice=cue(director)
    check(voice!=null and voice.global_position==farther.global_position,"per-NPC cooldown lets a later poll select another nearby NPC")
    var context:=UiContext.new();context.audio_director=director;context.player=player;host.add_child(context)
    var ui:=preload("res://scripts/pilgrimage_interface.gd").new();context.add_child(ui);ui.level=context
    ui.accessibility_path="user://audio_landmark_ui.cfg";ui.settings=ColorRect.new();ui.add_child(ui.settings)
    ui._accessibility_toggle("npc_landmarks","NPC声音地标",Vector2.ZERO)
    ui.accessibility_toggles.npc_landmarks.button_pressed=false
    check(not director.npc_landmarks_enabled and not ui.accessibility.npc_landmarks,"production preference toggle stops actual director landmark admission")
    ui.accessibility.npc_landmarks=true;ui._load_accessibility()
    check(not ui.accessibility.npc_landmarks,"landmark preference survives an actual settings-file reload")
    RETIREMENT.retire_tree(host);host.free();await process_frame
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"fixture drains real audio players streams and leases")
    check(AUDIO.active_voice_count()==0,"all admitted landmark voices release the existing global voice budget")
    for file in ["audio_landmarks_mix.cfg","audio_landmarks_replacement.cfg","audio_landmarks_spatial.cfg","audio_landmark_ui.cfg"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://"+file))
    if failures.is_empty():print("AUDIO_LANDMARKS checks=%d failures=0" % checks)
    else:
        for item in failures:push_error(item)
    quit(0 if failures.is_empty() else 1)

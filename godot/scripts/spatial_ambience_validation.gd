extends SceneTree
const AUDIO := preload("res://scripts/audio_director.gd")
const SOUNDSCAPE := preload("res://scripts/ambient_soundscape.gd")
const VOICE := preload("res://scripts/spatial_ambience_voice.gd")
const FILTER := preload("res://scripts/enemy_sound_filter.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures: Array[String] = []
class Listener extends CharacterBody2D:
    var hp := 5
    var ui_input_locked := false
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
func fixture() -> Dictionary:
    return {"id":"demo_ch01_moss_bell_court","map_rooms":[
        {"id":"court_hub","layout_rect":[100,-100,400,200]},
        {"id":"rust_crown_hall","layout_rect":[4000,0,400,200]}]}
func reset(director: Node) -> void:
    director.ambient_soundscape.stop()
    director.ambient_soundscape.source_times.clear()
    # Keep lifecycle/overlap probes on the existing 2.6-second clip; production
    # selection remains random among each authored source's variants.
    for row in director.ambient_soundscape.sources:
        if row.family=="regional":row.variants=[8]
    AUDIO._voice_last_ms.erase("amb_oneshot")
    AUDIO._prune_voices()
func first(director: Node) -> AudioStreamPlayer2D:
    return director.ambient_soundscape.voices[0] if not director.ambient_soundscape.voices.is_empty() else null
func refresh(director: Node) -> void:
    director.ambient_soundscape.next_refresh_ms=0
    director.ambient_soundscape.tick(director,director.runtime_player)

func run() -> void:
    var host := Node2D.new()
    root.add_child(host)
    var soundscape := SOUNDSCAPE.new()
    for region: String in SOUNDSCAPE.PROFILES:
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+region+".json"))
        var original := config.duplicate(true)
        soundscape.configure(config,host)
        check(soundscape.sources.size()==SOUNDSCAPE.PROFILES[region].size(),region+" resolves every authored source")
        check(soundscape.chapter==region.substr(5,4),region+" retains its own sound pack")
        for source in soundscape.sources:
            var rooms: Array=config.map_rooms.filter(func(row):return row.id==source.id)
            var rect: Array=rooms[0].layout_rect
            check(Rect2(rect[0],rect[1],rect[2],rect[3]).has_point(source.position),source.id+" anchor is inside its production room")
            check(rooms[0].kind!="secret",source.id+" is an ordinary room, not a secret beacon")
            var paths: Array=[]
            for variant in source.variants:
                paths.append("res://assets/audio/ambience/amb_%s_os_%d.ogg" % [soundscape.chapter,variant])
            if source.family=="anvil":paths.append("res://assets/audio/ambience/amb_ch02_anvil_far.ogg")
            for path in paths:
                check(FileAccess.file_exists(path),source.id+" uses a shipped clip: "+path)
        check(config==original,region+" catalogue construction leaves config, map knowledge and rewards untouched")
    soundscape.configure(fixture(),host)
    check(soundscape.sources.size()==2,"fixture resolves two authored origins")
    soundscape.configure({"id":"invented_ch01"},host)
    check(soundscape.sources.is_empty() and soundscape.chapter.is_empty(),"unsupported regions discard previous sources")
    for bad in [null,"wrong",{},[],[1,2,3],[0,0,-1,2],[0,0,1,0],[NAN,0,1,2],[0,INF,1,2],[false,0,1,2]]:
        check(not SOUNDSCAPE.valid_rect(bad),"malformed room bounds are rejected: "+str(bad))
    check(SOUNDSCAPE.valid_rect([0,-3,5,8]),"finite authored rectangles remain valid")
    var duplicate := fixture()
    duplicate.map_rooms.append(duplicate.map_rooms[0].duplicate(true))
    soundscape.configure(duplicate,host)
    check(soundscape.sources.size()==1 and soundscape.sources[0].id=="rust_crown_hall","ambiguous duplicate room IDs cannot choose an arbitrary source")
    var malformed := fixture()
    malformed.map_rooms[0].layout_rect=[0,0,INF,2]
    soundscape.configure(malformed,host)
    check(soundscape.sources.size()==1,"invalid room geometry cannot create a non-finite spatial origin")
    soundscape.clear()

    var director := AUDIO.new()
    director.autoplay_enabled=false
    director.settings_path="user://spatial_ambience.cfg"
    host.add_child(director)
    director.set_process(false)
    director.set_user_volume("master",100)
    director.set_user_volume("ambience",100)
    director.set_user_volume("music",100)
    var listener := Listener.new()
    host.add_child(listener)
    director.bind_runtime(listener,func():return [])
    director.configure_ambience(fixture(),host)
    check(not director._play_ambience_oneshot(-6),"disabled autoplay admits no ambient playback")
    director.autoplay_enabled=true
    listener.position=Vector2(-3000,0)
    check(not director._play_ambience_oneshot(-6),"distant listeners allocate no global fallback voice")
    check(director.ambient_soundscape.voices.is_empty(),"distant request leaves the voice pool empty")
    listener.position=Vector2.ZERO
    await physics_frame
    check(director._play_ambience_oneshot(-6),"production director starts a nearby authored one-shot")
    var voice := first(director)
    check(voice!=null and voice.playing and voice.has_stream_playback(),"actual Ogg playback is live")
    check(voice!=null and voice.global_position==Vector2(320,60),"voice uses the authored room anchor, not the listener")
    check(voice!=null and voice.max_distance==SOUNDSCAPE.RANGE and voice.attenuation==1,"actual 2D playback enables bounded distance attenuation")
    check(voice!=null and voice.bus=="Ambience" and not voice.occluded,"clear sound uses the user-controlled ambience bus")
    check(not director._play_ambience_oneshot(-6),"the same source cannot immediately retrigger")
    check(not director._play_ambience_oneshot(NAN) and not director._play_ambience_oneshot(INF),"invalid gain requests are rejected")
    check(not director._play_ambience_oneshot(-6,"invented"),"unknown families cannot create clips")
    check(not director._play_ambience_oneshot(-8,"anvil"),"remote-region anvil is not heard from the courtyard")

    var wall := StaticBody2D.new()
    wall.position=Vector2(160,30)
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size=Vector2(20,500)
    collision.shape=rectangle
    wall.add_child(collision)
    host.add_child(wall)
    await physics_frame
    await physics_frame
    var playback_ref: WeakRef = weakref(voice.get_stream_playback())
    var stream_ref: WeakRef = weakref(voice.stream)
    refresh(director)
    check(voice.occluded and voice.bus==VOICE.FILTER_BUS,"actual solid terrain routes the running accent through the ambient low-pass")
    check(is_equal_approx(voice.volume_db,-18),"occlusion subtracts exactly 12 dB from the original gain")
    var index := AudioServer.get_bus_index(VOICE.FILTER_BUS)
    var effect := FILTER.owned_effect(index,VOICE.FILTER_OWNER)
    check(effect!=null and is_equal_approx(effect.cutoff_hz,2400),"real owned low-pass effect uses the declared cutoff")
    check(index>AudioServer.get_bus_index("Ambience") and AudioServer.get_bus_send(index)=="Ambience","filtered accents retain user gain, dialogue duck and room reverb downstream")
    listener.position=Vector2(270,0)
    await physics_frame
    await physics_frame
    refresh(director)
    check(not voice.occluded and voice.bus=="Ambience" and is_equal_approx(voice.volume_db,-6),"moving beyond the wall restores clear routing and base gain")
    check(voice.get_stream_playback()==playback_ref.get_ref() and voice.stream==stream_ref.get_ref(),"occlusion refresh preserves the same playback and stream")
    listener.position=Vector2.ZERO
    await physics_frame
    await physics_frame
    refresh(director)
    refresh(director)
    check(voice.occluded and is_equal_approx(voice.volume_db,-18),"returning behind the wall cannot compound attenuation")
    wall.position=Vector2(320,60)
    await physics_frame
    await physics_frame
    refresh(director)
    check(voice.occluded,"an origin embedded in terrain remains acoustically occluded")
    wall.position=Vector2(160,30)
    await physics_frame
    await physics_frame
    refresh(director)
    var buses_before := AudioServer.bus_count
    var effect_id := effect.get_instance_id()
    for repeat in 20:refresh(director)
    check(AudioServer.bus_count==buses_before and FILTER.owned_effect(index,VOICE.FILTER_OWNER).get_instance_id()==effect_id,"repeated refreshes reuse one owned effect and one bus")
    effect=null
    var db_before := voice.volume_db
    listener.position=Vector2(270,0)
    await physics_frame
    await physics_frame
    director.ambient_soundscape.next_refresh_ms=Time.get_ticks_msec()+10000
    director.ambient_soundscape.tick(director,listener)
    check(voice.volume_db==db_before,"refresh work respects its time budget")
    refresh(director)
    check(not voice.occluded,"the next admitted refresh follows the listener")
    listener.position=Vector2(1600,0)
    refresh(director)
    check(not voice.playing and voice.stream==null and director.ambient_soundscape.voices.is_empty(),"leaving hearing range stops playback and releases the stream")
    voice=null
    wall.queue_free()
    listener.position=Vector2.ZERO
    await physics_frame
    await physics_frame

    host.position=Vector2(10000,-500)
    host.scale=Vector2(1.5,1.5)
    reset(director)
    check(director._play_ambience_oneshot(-6),"translated and scaled region still admits its own nearby source")
    voice=first(director)
    check(voice!=null and voice.global_position==host.to_global(Vector2(320,60)),"local authored origin is transformed exactly once into the live world")
    reset(director)
    host.position=Vector2.ZERO
    host.scale=Vector2.ONE
    voice=null

    # Each foreground/lifecycle boundary exercises the actual production hook.
    for boundary in ["dialogue","combat","boss","death","transition","warning"]:
        reset(director)
        check(director._play_ambience_oneshot(-6),boundary+" starts with an admitted real voice")
        voice=first(director)
        match boundary:
            "dialogue":director.on_dialogue(true)
            "combat":director.autoplay_enabled=false;director.enter_combat();director.autoplay_enabled=true
            "boss":director.autoplay_enabled=false;director.start_boss_music("fixture");director.autoplay_enabled=true
            "death":listener.hp=0;director.on_player_death()
            "transition":director.begin_chapter_transition()
            "warning":director.foreground_warning(listener)
        check(not voice.playing and voice.stream==null,boundary+" immediately retires background playback")
        if boundary!="warning":check(not director._play_ambience_oneshot(-6),boundary+" cannot immediately admit another accent")
        director.on_dialogue(false)
        director.combat_active=false
        director.boss_active=false
        director.active_boss_id=""
        listener.hp=5
        director.cancel_chapter_transition()
        director._clear_death_lowpass()
        voice=null
    for context in ["menu","shrine","mute","master"]:
        reset(director)
        check(director._play_ambience_oneshot(-6),context+" fixture begins with playback")
        voice=first(director)
        match context:
            "menu":listener.ui_input_locked=true
            "shrine":director.shrine_engaged=true
            "mute":director.set_user_volume("ambience",0)
            "master":director.set_user_volume("master",0)
        director.ambient_soundscape.tick(director,listener)
        check(not voice.playing and not director._play_ambience_oneshot(-6),context+" retires and suppresses background accents")
        listener.ui_input_locked=false
        director.shrine_engaged=false
        director.set_user_volume("master",100)
        director.set_user_volume("ambience",100)
        voice=null

    # Two real voices share the existing global priority budget.
    reset(director)
    var close_rooms := fixture()
    close_rooms.map_rooms[1].layout_rect=[200,-100,400,200]
    director.configure_ambience(close_rooms,host)
    reset(director)
    check(director._play_ambience_oneshot(-6),"first nearby source occupies one real voice")
    # Admission uses monotonic milliseconds, so await that same clock rather
    # than a frame-delta timer that can run ahead during fast test startup.
    var overlap_deadline := Time.get_ticks_msec()+300
    while Time.get_ticks_msec()<overlap_deadline:await process_frame
    check(director._play_ambience_oneshot(-6),"second authored source can overlap within the two-voice budget")
    check(director.ambient_soundscape.voices.size()==2,"pool contains exactly two active positional players")
    director.ambient_soundscape.source_times.clear()
    AUDIO._voice_last_ms.erase("amb_oneshot")
    check(not director._play_ambience_oneshot(-6),"a third accent cannot exceed the local voice cap")
    reset(director)
    director.configure_ambience(fixture(),host)
    var tickets: Array[int]=[]
    for slot in AUDIO.MAX_GLOBAL_VOICES:
        tickets.append(AUDIO.reserve_voice("ambient_budget_fixture_"+str(slot),0,0,1))
    check(tickets.all(func(ticket):return ticket>0),"fixture occupies the global budget with foreground reservations")
    check(not director._play_ambience_oneshot(-6),"background admission cannot steal a foreground reservation")
    for ticket in tickets:AUDIO.release_ticket(ticket)
    tickets.clear()
    reset(director)
    check(director._play_ambience_oneshot(-6),"ambient playback returns after foreground reservations release")
    voice=first(director)
    for slot in AUDIO.MAX_GLOBAL_VOICES-1:
        tickets.append(AUDIO.reserve_voice("ambient_preempt_fixture_"+str(slot),0,0,1))
    var warning_ticket:=AUDIO.reserve_voice("ambient_danger_fixture",0,0,1)
    check(warning_ticket>0 and not voice.playing and voice.stream==null,"a new danger cue actually preempts background playback at capacity")
    for ticket in tickets:AUDIO.release_ticket(ticket)
    AUDIO.release_ticket(warning_ticket)
    voice=null
    reset(director)

    # The separate furnace family must resolve in its own region and then be
    # forgotten on reconfiguration; it cannot fall back to a random global hit.
    var rain_config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch02_rain_foundry_canal.json"))
    director.configure_ambience(rain_config,host)
    var anvil_sources: Array=director.ambient_soundscape.sources.filter(func(row):return row.family=="anvil")
    listener.position=anvil_sources[0].position
    await physics_frame
    check(director._play_ambience_oneshot(-8,"anvil"),"real furnace location admits the existing anvil Ogg")
    voice=first(director)
    check(voice!=null and voice.global_position==anvil_sources[0].position and voice.stream is AudioStreamOggVorbis,"far anvil now has a fixed production origin")
    director.configure_ambience(fixture(),host)
    check(not voice.playing and voice.stream==null,"reconfiguration retires the prior region's anvil")
    check(director.ambient_soundscape.source_times.is_empty(),"old region cooldown identifiers are discarded")
    voice=null
    listener.position=Vector2.ZERO
    var other_viewport:=SubViewport.new()
    other_viewport.world_2d=World2D.new()
    host.add_child(other_viewport)
    var other_listener:=Listener.new()
    other_viewport.add_child(other_listener)
    check(not director.ambient_soundscape.play_nearby(director,other_listener,-6),"a listener in another physics world cannot hear this region")
    other_viewport.queue_free()
    await process_frame

    reset(director)
    check(director._play_ambience_oneshot(-6),"old scene starts playback before an ownership handoff")
    voice=first(director)
    var replacement := AUDIO.new()
    replacement.autoplay_enabled=false
    replacement.settings_path="user://spatial_ambience_next.cfg"
    host.add_child(replacement)
    replacement.set_process(false)
    refresh(director)
    check(not voice.playing and not director._play_ambience_oneshot(-6),"superseded director cannot keep or start environmental voices")
    director.free()
    check(AUDIO.instance==replacement,"old teardown leaves the newer director in ownership")
    voice=null
    replacement.free()
    host.queue_free()
    await process_frame
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"all observed ambient streams/playbacks retire before exit")
    check(playback_ref.get_ref()==null and stream_ref.get_ref()==null,"weak observations prove playback and cached clip were released")
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with("spatial_ambience"):DirAccess.remove_absolute("user://"+file)
    for failure in failures:printerr("FAIL: "+failure)
    print("SPATIAL_AMBIENCE checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)

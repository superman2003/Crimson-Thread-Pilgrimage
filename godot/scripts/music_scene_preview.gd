extends SceneTree
## Development-only scene listening session. The launcher isolates APPDATA.
var world: Node
var preview_voice: AudioStreamPlayer
var finishing := false
var key := "ch01_cave_loop"
var fixed_music := false
var invulnerable := false
var auto_exit := 0.0
var proof := ""
var trial_badge: Label
var status_clock := 0.0
var last_sound_state := ""
var auto_test := false
var auto_failures: Array[String] = []

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var value:=String(argument)
        if value.begins_with("--music-key="):key=value.trim_prefix("--music-key=")
        elif value.begins_with("--music-lock="):fixed_music=value.trim_prefix("--music-lock=")=="true"
        elif value.begins_with("--music-invulnerable="):invulnerable=value.trim_prefix("--music-invulnerable=")=="true"
        elif value.begins_with("--music-auto-exit="):auto_exit=float(value.trim_prefix("--music-auto-exit="))
        elif value.begins_with("--music-proof="):proof=value.trim_prefix("--music-proof=")
        elif value=="--music-auto-test":auto_test=true
    call_deferred("prepare")

func prepare() -> void:
    var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/bgm/ai_generated/music_pack.json"))
    var cue: Dictionary={}
    for entry in pack.entries:
        if entry.get("key")==key and entry.get("status")=="installed":cue=entry;break
    if cue.is_empty():push_error("Unknown delivered music cue: "+key);quit(1);return
    var category:=String(cue.get("category","boss" if key=="boss_rust_crown_loop" else "explore"))
    var chapter:=int(key.substr(2,2)) if key.begins_with("ch") else (1 if key=="boss_rust_crown_loop" or key.begins_with("bellway") else 6)
    var slugs:=["moss_bell_court","rain_foundry_canal","saltwhite_archive","broken_string_greenhouse","obsidian_pilgrim_road","silent_crown_core"]
    world=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://music_preview.json"
    world.config_path="res://data/demo_ch%02d_%s.json" % [chapter,slugs[chapter-1]]
    root.add_child(world)
    current_scene=world
    var deadline:=Time.get_ticks_msec()+180000
    while not world.initial_region_ready and Time.get_ticks_msec()<deadline:await process_frame
    if not world.initial_region_ready or not is_instance_valid(world.player):
        push_error("Music scene did not publish a player");quit(1);return
    for frame in 10:await process_frame
    if not fixed_music:
        # The production headless host disables music for non-audio suites.
        # This dedicated listening session always enables the real selector.
        world.audio_director.autoplay_enabled=true
        world.audio_director._play_explore_track(world.audio_director._explore_track_path())
    if category in ["boss","boss_final"]:
        world.boss_trial_mode=true
        world._start_boss_trial()
        if is_instance_valid(world.boss_actor) and key.begins_with("boss_final"):
            var movement:=int(key.right(1))
            if movement>1:world.boss_actor.hp=maxi(1,int(world.boss_actor.max_hp*(.6 if movement==2 else .3)))
    elif category=="lullaby":
        if not await start_at_shrine():
            push_error("Could not prepare the authored shrine start")
            await finish(1)
            return
    world.player.debug_invulnerable=invulnerable
    world.player.reset_camera_after_arrival()
    if fixed_music:
        var audio: Node=world.audio_director
        audio.autoplay_enabled=false
        for name in ["explore_tween","combat_tween","boss_tween","lullaby_tween","transit_tween","hidden_drone_tween"]:
            var tween: Variant=audio.get(name)
            if tween is Tween and tween.is_valid():tween.kill()
        for name in ["explore_player","combat_player","boss_player","lullaby_player","stinger_player","transit_player","hidden_drone_player"]:
            var voice: Variant=audio.get(name)
            if is_instance_valid(voice):voice.stop();voice.stream=null
        var stream:=AudioStreamOggVorbis.load_from_file(cue.runtime)
        if stream==null:push_error("Preview cue cannot decode");quit(1);return
        stream.loop=bool(cue.loop)
        preview_voice=AudioStreamPlayer.new()
        preview_voice.stream=stream
        preview_voice.bus="BGM"
        preview_voice.volume_db=-16.0 if category in ["combat","boss","boss_final"] else -18.0
        root.add_child(preview_voice)
        preview_voice.play()
    var layer:=CanvasLayer.new();layer.layer=120;root.add_child(layer)
    var badge:=Label.new()
    trial_badge=badge
    badge.text="区域试玩 · "+String(world.config.get("name",""))+" · 音乐自动切换   |   F8 结束"
    badge.position=Vector2(530,130)
    badge.add_theme_font_size_override("font_size",16)
    badge.add_theme_color_override("font_color",Color("e7d4a5"))
    badge.add_theme_color_override("font_shadow_color",Color.BLACK)
    badge.add_theme_constant_override("shadow_offset_x",1)
    badge.add_theme_constant_override("shadow_offset_y",1)
    badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
    layer.add_child(badge)
    DisplayServer.window_set_title("绯线巡礼 · 区域试玩 · "+String(world.config.get("name","")))
    print("MUSIC_SCENE_PREVIEW_READY key=%s region=%s isolated_save=true fixed_music=%s" % [key,String(world.config.id),fixed_music])
    if auto_test:
        await verify_automatic_music()
        return
    if not proof.is_empty():
        for frame in 30:await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(proof)
    if auto_exit>0.0:
        await create_timer(auto_exit).timeout
        await finish()

func start_at_shrine() -> bool:
    var target: Dictionary={}
    for point in world.config.get("save_points",[]):
        if not bool(point.get("hidden",false)):target=point;break
    if target.is_empty():return false
    world.player.set_physics_process(false)
    world.player.debug_invulnerable=true
    world.player.velocity=Vector2.ZERO
    world.player.global_position=Vector2(float(target.position[0]),float(target.position[1]))
    # Let the production residency/collision window bring this authored shrine
    # into the live scene before invoking its actual interaction.
    for frame in 240:
        for child in world.get_children():
            if child is Area2D and String(child.name)==String(target.id) and String(child.get_meta("kind",""))=="save_point":
                world._activate_save_point(child)
                world.player.set_physics_process(true)
                print("SHRINE_PREVIEW_READY id="+String(target.id))
                return true
        await process_frame
    world.player.set_physics_process(true)
    return false

func _process(_delta: float) -> bool:
    if Input.is_physical_key_pressed(KEY_F8) and not finishing:call_deferred("finish")
    status_clock+=_delta
    if status_clock>=.5 and is_instance_valid(world) and world.initial_region_ready and is_instance_valid(trial_badge):
        status_clock=0.0
        var audio: Node=world.audio_director
        if is_instance_valid(audio):
            var state:="探索"
            if audio.boss_active:state="Boss · 乐章 %d" % maxi(1,int(audio.boss_phase))
            elif audio.lullaby_active:state="钟龛休息"
            elif audio.combat_active:state="战斗静默" if String(audio.chapter_short_id)=="ch06" else "遇敌战斗"
            elif audio.in_transit_room:state="钟骨长梯"
            elif audio.hidden_zone:state="隐藏区域"
            var current:=String(world.config.get("name",""))+" · "+state
            trial_badge.text="区域试玩 · "+current+"（自动选曲） | F8 结束"
            if current!=last_sound_state:
                print("AUTO_MUSIC_STATE "+current)
                last_sound_state=current
    return false

func auto_check(condition: bool, message: String) -> void:
    if not condition:auto_failures.append(message);push_error(message)

func verify_automatic_music() -> void:
    var audio: Node=world.audio_director
    var director:=load("res://scripts/audio_director.gd")
    world.set_process(false);world.set_physics_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    audio.set_process(false)
    auto_check(not fixed_music and preview_voice==null and audio.autoplay_enabled,"region preview must use the production music controller")
    auto_check(audio.explore_player.stream==director.load_cached(audio._explore_track_path(),true),"exploration cue matches the region")
    audio.enter_combat()
    await create_timer(.95).timeout
    auto_check(audio.explore_player.stream_paused,"encounter pauses exploration")
    if String(audio.chapter_short_id)=="ch06":auto_check(not is_instance_valid(audio.combat_player) or not audio.combat_player.playing,"CH06 ordinary encounters are silent")
    else:auto_check(is_instance_valid(audio.combat_player) and audio.combat_player.playing and audio.combat_player.stream==director.load_cached(audio._combat_layer_path(),true),"encounter plays the region combat cue")
    audio.exit_combat()
    auto_check(not audio.explore_player.stream_paused,"calm restores exploration")
    audio.start_lullaby()
    await create_timer(.95).timeout
    auto_check(audio.lullaby_active and audio.lullaby_player.stream==director.load_cached(audio._lullaby_path(),true) and audio.explore_player.stream_paused,"rest selects the region shrine lullaby")
    audio.stop_lullaby()
    audio.start_boss_music(String(world.config.boss.kind))
    await create_timer(.7).timeout
    auto_check(audio.boss_active and audio.boss_player.playing and audio.explore_player.stream_paused,"Boss entry replaces exploration with Boss music")
    audio.stop_boss_music()
    auto_check(not audio.explore_player.stream_paused,"Boss exit restores exploration")
    print("REGION_AUTO_MUSIC_%s region=%s checks=8 failures=%d" % ["PASS" if auto_failures.is_empty() else "FAIL",String(world.config.id),auto_failures.size()])
    await finish(0 if auto_failures.is_empty() else 1)

func finish(code: int = 0) -> void:
    if finishing:return
    finishing=true
    if is_instance_valid(preview_voice):preview_voice.stop();preview_voice.stream=null;preview_voice.queue_free()
    var retirement:=load("res://scripts/audio_retirement.gd")
    if is_instance_valid(world):retirement.retire_tree(world);world.queue_free()
    var director:=load("res://scripts/audio_director.gd")
    director._stream_cache.clear()
    await process_frame
    await process_frame
    await retirement.drain(self)
    quit(code)

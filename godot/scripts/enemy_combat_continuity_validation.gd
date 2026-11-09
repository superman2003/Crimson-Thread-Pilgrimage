extends SceneTree
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const AUDIO:=preload("res://scripts/enemy_combat_audio.gd")
const ART:=preload("res://scripts/hand_drawn_assets.gd")
var checks:=0
var failures:=0

class Target extends CharacterBody2D:
    var hp:=10
    var ui_input_locked:=false
    var accept:=true
    func take_damage(amount: int,_point: Vector2,_blockable: bool=true) -> bool:
        if not accept:return false
        hp-=amount;return true

class SoundEnemy extends "res://scripts/enemy_actor.gd":
    var heard: Array=[]
    func _play_sfx(key: String,volume: float=-6,pitch: float=1,priority: int=1) -> void:
        heard.append({"key":key,"volume":volume,"pitch":pitch,"priority":priority})

class NativeSoundEnemy extends "res://scripts/enemy_actor.gd":
    func _should_play_sfx() -> bool:return true

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)

func run() -> void:
    var stage:=Node2D.new();root.add_child(stage)
    var target:=Target.new();target.position=Vector2(360,300);target.add_to_group("player");stage.add_child(target)
    var enemy:=SoundEnemy.new()
    enemy.configure({"id":"continuity","kind":"rust_crown_guardian","hp":30},"",true)
    enemy.position=Vector2(300,300);stage.add_child(enemy);enemy.set_physics_process(false)
    await physics_frame
    var command:={"id":"continuity_strike","type":"melee","animation":"heavy","range":180,"windup":.3,"active":.2,"recover":.8,"cooldown":999,"damage":1,"hit_width":120,"hit_height":100,"offset":40}
    enemy.ai_commands=[command];enemy.cooldowns={"continuity_strike":999.0}
    enemy.active_attack=command;enemy.state="recover";enemy.state_timer=.8;enemy.attack_recovery=true;enemy.attack_desire=0
    enemy._pose_sprite("recover",command)
    enemy._update_recover(.2)
    check(enemy.state=="recover" and enemy.attack_desire==0,"early recovery stays committed without precharging")
    enemy._update_recover(.25);enemy._update_recover(.1)
    check(enemy.state=="recover" and enemy.attack_desire>0,"late recovery plans the next action while remaining vulnerable")
    check(enemy.attack_desire<enemy._attack_desire_threshold(),"planning retains a small decision margin")
    enemy._update_recover(.249)
    check(enemy.state=="recover","original full recovery deadline is preserved")
    enemy._update_recover(.002)
    check(enemy.state=="patrol" and not enemy.attack_recovery,"completion returns to the decision layer")
    check(float(enemy.cooldowns.continuity_strike)==999,"animation handoff cannot bypass cooldowns")

    enemy.active_attack=command;enemy.state="recover";enemy.state_timer=.8;enemy.attack_recovery=true
    enemy.global_position=Vector2(309,300);enemy.arena_min_x=290;enemy.arena_max_x=310;enemy.recovery_velocity_x=100
    var hp_before:=target.hp
    enemy._update_recover(.1)
    check(enemy.global_position.x<=310.001,"short recovery momentum respects Boss arena bounds")
    check(target.hp==hp_before,"recovery momentum creates no attack damage")
    enemy.apply_trip(.6)
    check(enemy.attack_recovery and enemy.trip_timer==0,"Boss trip immunity preserves committed recovery")
    enemy.combat_resistance.trip_immune=false
    enemy.apply_trip(.6)
    check(not enemy.attack_recovery and enemy.recovery_velocity_x==0,"trip cancels planned attack momentum")
    enemy.arena_min_x=0;enemy.arena_max_x=1000
    enemy.trip_timer=0;enemy.state="patrol";enemy.global_position=Vector2(300,300)

    var minor:=SoundEnemy.new()
    minor.configure({"id":"bounded_recovery","kind":"moss_larva","hp":10},"",false)
    minor.position=Vector2(309,300);stage.add_child(minor);minor.set_physics_process(false)
    minor.platform_min_x=290;minor.platform_max_x=310
    minor.active_attack=command;minor.state="recover";minor.state_timer=.8
    minor.attack_recovery=true;minor.recovery_velocity_x=80
    minor._update_recover(.1)
    check(minor.global_position.x<=310.001,"ordinary recovery respects authored platform bounds")
    minor.apply_trip(.6)
    check(not minor.attack_recovery and minor.recovery_velocity_x==0,"ordinary trip cancels the recovery plan")

    enemy._pose_sprite("idle");enemy.animated_sprite.pause();enemy._set_enemy_animation("idle")
    check(enemy.animated_sprite.is_playing(),"stopped idle loop resumes without a state change")
    enemy._set_combat_visuals_paused(true);enemy._set_enemy_animation("idle")
    check(not enemy.animated_sprite.is_playing(),"UI pause keeps the resumed-loop guard quiet")
    enemy._set_combat_visuals_paused(false)
    check(enemy.animated_sprite.is_playing(),"closing UI resumes the previous loop")
    enemy._set_enemy_animation("walk")
    enemy._sync_walk_cadence(.1,enemy.global_position-Vector2(enemy.speed*.05,0))
    check(enemy.animated_sprite.speed_scale<.8,"slow footwork uses slower walk playback")
    enemy._sync_walk_cadence(.1,enemy.global_position-Vector2(enemy.speed*.1,0))
    check(absf(enemy.animated_sprite.speed_scale-1)<.01,"full-speed movement restores authored walk cadence")

    enemy.state="patrol"
    enemy._set_enemy_animation("walk",true)
    var slow_origin:=enemy.global_position-Vector2(enemy.speed*.015,0)
    enemy._sync_walk_cadence(.1,slow_origin)
    enemy._update_animation_motion(.1,slow_origin,"patrol")
    check(enemy.animated_sprite.speed_scale<.4,"pose feedback preserves slow grounded footwork cadence")

    check(not enemy.authored_combat_sequences.is_empty(),"merged actor retains authored combat sequences")
    if not enemy.authored_combat_sequences.is_empty():
        enemy._set_enemy_animation(String(enemy.authored_combat_sequences[0]),true)
        var authored_animation:=enemy.animated_sprite.animation
        var authored_frames:=enemy.animated_sprite.sprite_frames
        var authored_weights: Array[float]=[]
        for index in authored_frames.get_frame_count(authored_animation):
            authored_weights.append(authored_frames.get_frame_duration(authored_animation,index))
        enemy._fit_animation_duration(3.0,"windup")
        var preserved:=true
        for index in authored_weights.size():
            preserved=preserved and is_equal_approx(enemy.animated_sprite.sprite_frames.get_frame_duration(authored_animation,index),authored_weights[index])
        check(preserved,"legacy phase holds preserve authored combat frame weights")

    check(AUDIO.release_family("sunken_hammer_smith","ground",command)=="heavy","visual heavy strike gets weight even at damage one")
    check(AUDIO.release_family("bronze_moth","flight",{"type":"dive"})=="wing","dive uses wing and air material")
    check(AUDIO.release_family("moss_larva","ground",{"type":"melee"})=="claw","larva bite uses chitin articulation")
    check(AUDIO.release_family("root_hound","ground",{"type":"melee"})=="claw","root hound bite keeps its animal articulation")
    enemy.active_attack=command
    check(not enemy._active_attack_is_heavy(),"sound weight does not change lethal warning classification")
    var gameplay_rng: int=enemy.ai_rng.state
    var previous:=""
    for attempt in 24:
        enemy.heard.clear();check(enemy._play_combat_material("heavy",-8),"new material cue is installed")
        var key:=String(enemy.heard.back().key)
        check(key!=previous,"material variants avoid immediate repetition")
        previous=key
    check(enemy.ai_rng.state==gameplay_rng,"sound randomness never changes gameplay attack choices")

    enemy.heard.clear();enemy.attack_has_hit=false;enemy.state="active";target.accept=false
    enemy._try_damage_player(command)
    check(enemy.heard.is_empty(),"rejected damage produces no false impact cue")
    enemy.attack_has_hit=false;target.accept=true
    enemy._try_damage_player(command)
    check(enemy.heard.size()==1 and String(enemy.heard[0].key).begins_with("combat_impact_"),"accepted physical contact owns the impact layer")

    var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sfx/ai_combat/manifest.json"))
    check(manifest.entries.size()==30,"30 original source variants are installed")
    var hashes:={}
    for entry in manifest.entries:
        var stream:=AudioStreamOggVorbis.load_from_file(entry.path)
        check(stream!=null and stream.get_length()>.06,"native SFX decoding: "+String(entry.id))
        check(FileAccess.get_sha256(entry.path)==String(entry.sha256),"SFX hash: "+String(entry.id))
        hashes[entry.sha256]=true;stream=null
    check(hashes.size()==30,"variants are distinct source files")

    # Exercise the production voice gate, cache, stream and ownership route
    # with the runner's Dummy audio driver; no desktop/audio device is opened.
    var native:=NativeSoundEnemy.new()
    native.configure({"id":"native_combat_audio","kind":"rust_crown_guardian","hp":30},"",true)
    native.position=Vector2(300,300);stage.add_child(native);native.set_physics_process(false)
    native.active_attack=command
    native._play_attack_sfx("windup")
    native._play_attack_sfx("release")
    var native_materials:=0
    var native_warnings:=0
    for child in native.get_children():
        if not child is AudioStreamPlayer2D:continue
        if String(child.name).begins_with("Sfx_combat_"):
            native_materials+=1
            check(child.stream is AudioStreamOggVorbis and child.playing,"material cue reaches a real native Ogg voice")
            check(child.pitch_scale>=.88 and child.pitch_scale<=1.04,"native combat pitch stays within its restrained variation")
        if String(child.name).begins_with("Sfx_boss_windup_light"):native_warnings+=1
    check(native_materials==2,"preparation and release own separate native voices")
    check(native_warnings==1,"material audio retains the important warning route")
    enemy._cancel_attack_effects()
    preload("res://scripts/audio_retirement.gd").retire_tree(root)
    stage.queue_free();enemy=null;target=null;minor=null;native=null
    ART.frame_cache.clear();ART.textures.clear()
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    await process_frame;await process_frame
    check(await preload("res://scripts/audio_retirement.gd").drain(self),"continuity fixture retires native playback")
    print("ENEMY_COMBAT_CONTINUITY checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

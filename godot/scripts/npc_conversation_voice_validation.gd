extends SceneTree
const LEVEL := preload("res://scripts/main_level.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const LANGUAGE := preload("res://scripts/npc_insect_language.gd")
const PORTRAIT := preload("res://scripts/npc_dialogue_portrait.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0
var evidence: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error("NPC_CONVERSATION_VOICE " + label)
func frames(count: int) -> void:
    for index in count: await process_frame
func real_wait(seconds: float) -> void:
    var end := Time.get_ticks_msec() + int(seconds*1000)
    while Time.get_ticks_msec() < end: await process_frame

func run() -> void:
    check(DisplayServer.get_name() != "headless", "portrait checks require rendered pixels")
    if failures: quit(1); return
    root.size=Vector2i(1000,640); root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color("10191b"))
    # Capture the real SFXWorld mix before Master. Keep test playback inaudible
    # on the user's desktop, without replacing the game stream or mixer.
    AudioServer.set_bus_mute(0,true)
    var stage:=Node2D.new();root.add_child(stage)
    var factory:=LEVEL.new()
    AUDIO.ensure_sub_buses()
    var director:=AUDIO.new();director.autoplay_enabled=false;stage.add_child(director)
    director.on_dialogue(true)
    var bus:=AudioServer.get_bus_index("SFXWorld")
    check(bus>=0,"production SFXWorld bus exists")
    var capture:=AudioEffectCapture.new();capture.buffer_length=4.0
    var effect:=AudioServer.get_bus_effect_count(bus);AudioServer.add_bus_effect(bus,capture)
    var portrait:=PORTRAIT.new();portrait.position=Vector2(640,150);portrait.size=Vector2(250,290)
    portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    stage.add_child(portrait)
    var catalogue:=LANGUAGE.catalogue()
    check(catalogue.actors.size()==25,"all 25 named characters have voices")
    var output:=ProjectSettings.globalize_path("res://../artifacts/npc_insect_language_v1/native")
    DirAccess.make_dir_recursive_absolute(output)
    for id: String in catalogue.actors:
        var actor: Area2D=factory._make_npc({"id":id,"name":id})
        stage.add_child(actor);actor.position=Vector2(350,390)
        var sprite:=actor.get_node("FriendlyFamilySprite") as AnimatedSprite2D
        var scale_before:=sprite.scale;var position_before:=sprite.position;var transform_before:=sprite.transform
        await frames(2)
        capture.clear_buffer()
        portrait.bind_speaker(actor,ART.portrait(id))
        if id in ["npc_gate_pilgrim","npc_canal_child","npc_rain_smith_liu"]:
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_jpg(output.path_join(id+"_idle.jpg"),.9)==OK,"save native idle evidence")
        sprite.begin_conversation()
        portrait.bind_speaker(actor,ART.portrait(id))
        var size_before:=portrait.texture.get_size()
        check(director.play_npc_voice(id,"你好，路上有什么新消息？","warm",sprite),id+" starts a real phrase")
        var player: AudioStreamPlayer=director._npc_voice_player
        check(player.bus=="SFXWorld" and player.stream.get_length()>.5,id+" uses the production bus and complete utterance")
        var saw_talk:=false;var stable_portrait:=true;var stable_rig:=true;var peak:=0.0;var mixed:=0;var saved_talk:=false
        var deadline:=Time.get_ticks_msec()+4000
        while player.playing and Time.get_ticks_msec()<deadline:
            await process_frame
            stable_rig=stable_rig and sprite.transform==transform_before
            saw_talk=saw_talk or (sprite.animation==&"talk" and sprite.presentation_state==&"talk")
            portrait._refresh()
            if not saved_talk and saw_talk and id in ["npc_gate_pilgrim","npc_canal_child","npc_rain_smith_liu"]:
                await RenderingServer.frame_post_draw
                check(root.get_texture().get_image().save_jpg(output.path_join(id+"_speaking.jpg"),.9)==OK,"save native speech evidence")
                saved_talk=true
            stable_portrait=stable_portrait and portrait.texture!=null and portrait.texture.get_size()==size_before
            var buffer:=capture.get_buffer(capture.get_frames_available())
            mixed+=buffer.size()
            for index in range(0,buffer.size(),8):
                peak=maxf(peak,maxf(absf(buffer[index].x),absf(buffer[index].y)))
        await frames(2)
        check(not player.playing,id+" phrase ends without a loop")
        check(saw_talk,id+" visibly speaks after its greeting")
        check(sprite.conversation_active and not sprite.speech_active and sprite.presentation_state==&"listen" and sprite.animation==&"idle",id+" listens while the player reads")
        check(stable_rig and sprite.scale==scale_before and sprite.position==position_before,id+" never resizes or moves the rig during speech")
        check(stable_portrait,id+" portrait has one fixed crop through every state")
        check(mixed>256 and peak>.0001,id+" produces nonzero native mixer samples")
        check(AUDIO.active_voice_count()==0,id+" finished phrase releases its voice lease")
        evidence.append({"id":id,"saw_talk":saw_talk,"mix_frames":mixed,"mix_peak":peak,"portrait_size":[size_before.x,size_before.y],"scale":[scale_before.x,scale_before.y]})
        if id in ["npc_gate_pilgrim","npc_canal_child","npc_rain_smith_liu"]:
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_jpg(output.path_join(id+"_listening.jpg"),.9)==OK,"save native listening evidence")
        sprite.end_conversation();director.stop_npc_voice();portrait.release_speaker()
        actor.queue_free();await frames(2)
    await ownership(factory,stage,director)
    portrait.release_speaker()
    AudioServer.remove_bus_effect(bus,effect)
    RETIRE.retire_tree(stage);stage.queue_free();factory.free();await frames(3)
    AUDIO._stream_cache.clear()
    check(await RETIRE.drain(self),"all phrase playbacks retire")
    await actual_interface()
    ART.frame_cache.clear();ART.textures.clear();AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"scene closure drains audio")
    var file:=FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"actors":evidence,"audio_mix":true},"  ")+"\n");file.close()
    print("NPC_CONVERSATION_VOICE checks=%d failures=%d actors=25 phrases=150 audio_mix=true"%[checks,failures])
    quit(0 if failures==0 else 1)

func ownership(factory: Node2D,stage: Node2D,director: Node) -> void:
    var a: Area2D=factory._make_npc({"id":"npc_gate_pilgrim"});stage.add_child(a)
    var first:=a.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    first.begin_conversation()
    check(director.play_npc_voice("npc_gate_pilgrim","先听这一句话。","warm",first),"ownership fixture starts")
    var phase:=Vector2(first.frame,first.frame_progress)
    check(not director.play_npc_voice("npc_gate_pilgrim","先听这一句话。","warm",first) and Vector2(first.frame,first.frame_progress)==phase,"duplicate callbacks never restart a gesture or phrase")
    check(not director.play_npc_voice("npc_gate_pilgrim","快速跳到下一句话。","warm",first) and not director._npc_voice_player.playing,"fast text changes cut the old phrase without a burst of chatter")
    var b: Area2D=factory._make_npc({"id":"npc_canal_child"});stage.add_child(b)
    var second:=b.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    second.begin_conversation()
    check(director.play_npc_voice("npc_canal_child","现在轮到另一个人。","bright",second),"another speaker starts immediately")
    check(not first.speech_active and AUDIO.active_voice_count()==1,"one dialogue voice owns the active speaker")
    second.end_conversation();await frames(2)
    check(not director._npc_voice_player.playing and AUDIO.active_voice_count()==0,"ending the conversation stops its voice")
    var c: Area2D=factory._make_npc({"id":"npc_rain_smith_liu"});stage.add_child(c)
    var third:=c.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    third.begin_conversation();director.play_npc_voice("npc_rain_smith_liu","角色即将卸载。","low",third)
    c.queue_free();await frames(3)
    check(not director._npc_voice_player.playing and AUDIO.active_voice_count()==0,"unloading a speaker cannot leave a voice behind")
    director.on_dialogue(false);a.queue_free();b.queue_free();await frames(2)

func actual_interface() -> void:
    var level=load("res://scenes/Main.tscn").instantiate();root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    await real_wait(.5)
    var actor: Area2D=level.get_node("npc_gate_pilgrim")
    var sprite:=actor.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    var original_mode: bool=level.world_mode
    level.world_mode=false
    level._show_dialogue(actor,"旧章节界面也要能听见虫语。")
    level.world_mode=original_mode
    check(level.audio_director._npc_voice_player.playing and sprite.speech_active,"legacy dialogue plays speech and binds its acting")
    check(level.dialogue_text_label.visible_characters==-1,"legacy dialogue keeps its existing full-text reading mode")
    level._close_overlays()
    check(not level.audio_director._npc_voice_player.playing and sprite.presentation_state==&"idle","actual UI close stops voice and acting together")
    check(level.ui_shell.dialogue_portrait.texture==null,"closed portrait releases its sprite reference")
    var second: Area2D=level._make_npc({"id":"npc_gear_cartographer"});level.add_child(second)
    level._show_dialogue(second,"新的对话仍然保留原有字幕。")
    var history:=Area2D.new();history.set_meta("kind","history");level.add_child(history)
    level._show_dialogue(history,"史迹不属于说话的角色。")
    check(not level.audio_director._npc_voice_player.playing,"history reading remains silent and retires the previous NPC")
    level._close_overlays();level.queue_free();await frames(4)

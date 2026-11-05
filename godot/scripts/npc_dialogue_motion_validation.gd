extends SceneTree
## Actual NPC factory, native animation clocks and production dialogue lifecycle.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const LEVEL := preload("res://scripts/main_level.gd")
const MOTION := preload("res://scripts/npc_dialogue_motion.gd")
const LIVE := preload("res://scripts/world_neighbor_gameplay_live_validation.gd")
var checks := 0
var failures := 0
var character_count := 0
var evidence: Array = []
var callback_contract: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error("NPC_MOTION: "+label)
func frames(count: int) -> void:
    for index in count: await process_frame
func phase(sprite: AnimatedSprite2D) -> Vector2:
    return Vector2(sprite.frame,sprite.frame_progress)

func run() -> void:
    var stage := Node2D.new(); root.add_child(stage)
    var factory := LEVEL.new()
    var designs: Dictionary = ART.manifest("res://data/original_world_art_designs.json")
    var actors: Array[AnimatedSprite2D] = []
    var seen: Array[Dictionary] = []
    for design in designs.npcs:
        var id := String(design.id)
        var area: Area2D = factory._make_npc({"id":id,"name":id})
        stage.add_child(area)
        var sprite := area.get_node("FriendlyFamilySprite") as AnimatedSprite2D
        actors.append(sprite); seen.append({0:true}); character_count += 1
        check(sprite.get_script()==MOTION,"normal factory installs conversation motion: "+id)
        check(sprite.sprite_frames==ART.frames(ART.character_manifest("original_npcs",id)),"existing production drawings stay bound: "+id)
        sprite.call("begin_conversation")
        check(sprite.animation==&"greet" and sprite.frame==0,"conversation begins at authored greeting: "+id)
        check(bool(sprite.get("conversation_active")),"greeting belongs to an active conversation: "+id)
    check(character_count>=25,"cover every named production NPC design")
    # Repeated lines while greeting must let both native cels play to completion.
    for tick in 45:
        await process_frame
        for index in actors.size():
            var sprite := actors[index]
            if sprite.animation==&"greet": seen[index][sprite.frame]=true
            sprite.call("begin_conversation")
    for index in actors.size():
        var sprite := actors[index]
        check(seen[index].size()==sprite.sprite_frames.get_frame_count(&"greet"),"every greeting cel actually played")
        check(sprite.animation==&"talk" and sprite.is_playing(),"finished greeting hands off to the authored talk loop")
        var before := phase(sprite)
        sprite.call("begin_conversation")
        check(phase(sprite)==before,"topic changes retain native talk phase")
        sprite.call("end_conversation")
        sprite.animation_finished.emit()
        check(sprite.animation==&"idle" and not bool(sprite.get("conversation_active")),"closing prevents late completion from reviving talk")
        evidence.append({"id":String(designs.npcs[index].id),"greeting_cels_seen":seen[index].size(),"talk_cels":sprite.sprite_frames.get_frame_count(&"talk")})
    var saved_frames := actors[0].sprite_frames
    stage.free(); factory.free()
    await clock_and_fallback(saved_frames)
    await actual_dialogue()
    var output := ProjectSettings.globalize_path("res://../artifacts/npc_dialogue_motion_v10")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"characters":character_count,"actual_dialogue":true,"characters_checked":evidence,"callback_contract":callback_contract},"  ")+"\n"); file.close()
    print("NPC_DIALOGUE_MOTION checks=%d failures=%d characters=%d actual_dialogue=true"%[checks,failures,character_count])
    quit(0 if failures==0 else 1)

func clock_and_fallback(source: SpriteFrames) -> void:
    var sprite := MOTION.new(); sprite.sprite_frames=source; root.add_child(sprite)
    check(sprite.greet_on_approach(),"approach can play a greeting before any dialogue overlay")
    await frames(3)
    var approach_phase := phase(sprite)
    check(not sprite.greet_on_approach() and phase(sprite)==approach_phase,"repeated approach preserves the active greeting clock")
    sprite.begin_conversation()
    check(phase(sprite)==approach_phase,"opening dialogue continues an already visible approach greeting")
    sprite.end_conversation()
    check(not sprite.greet_on_approach(),"approach cooldown prevents repeated boundary greetings")
    sprite.last_approach_greeting_msec=Time.get_ticks_msec()-9000
    check(sprite.greet_on_approach(),"an expired approach cooldown permits another greeting")
    await frames(20)
    check(sprite.animation==&"idle" and not sprite.conversation_active,"approach greeting returns to idle when no conversation opens")
    sprite.begin_conversation(); sprite.speed_scale=0.5
    await frames(12)
    check(sprite.animation==&"greet" and float(sprite.frame)+sprite.frame_progress>0.6 and float(sprite.frame)+sprite.frame_progress<1.0,"greeting follows native speed scale")
    var before := phase(sprite)
    paused=true; await frames(8)
    check(phase(sprite)==before,"SceneTree pause freezes greeting without a separate timer")
    paused=false; sprite.speed_scale=1.0
    sprite.end_conversation(); sprite.begin_conversation(); await frames(3)
    sprite.end_conversation(); await frames(24)
    check(sprite.animation==&"idle" and not sprite.conversation_active,"early close remains idle beyond the old greeting deadline")
    sprite.begin_conversation()
    check(sprite.animation==&"greet" and sprite.frame==0,"reopening starts a fresh greeting")
    sprite.end_conversation()
    for mode in ["missing","looping","stopped"]:
        sprite.sprite_frames=source.duplicate()
        if mode=="missing": sprite.sprite_frames.remove_animation(&"greet")
        elif mode=="looping": sprite.sprite_frames.set_animation_loop(&"greet",true)
        else: sprite.sprite_frames.set_animation_speed(&"greet",0)
        sprite.begin_conversation()
        check(sprite.animation==&"talk","unusable greeting falls back to talk: "+mode)
        sprite.end_conversation()
    sprite.free(); await process_frame

func capture(name: String, sprite: AnimatedSprite2D) -> void:
    if DisplayServer.get_name()=="headless": return
    # The fixture teleports a physics-disabled Player into interaction range.
    # Flush its camera transform before reading pixels from that same frame.
    var camera := sprite.get_viewport().get_camera_2d()
    if camera!=null: camera.force_update_scroll()
    await RenderingServer.frame_post_draw
    var screen := sprite.get_global_transform_with_canvas().origin
    if name=="approach":
        print("NPC_FRAMING camera_path=%s center=%s zoom=%s offset=%s limits=%s canvas=%s layer=%s"%[str(camera.get_path()),str(camera.get_screen_center_position()),str(camera.zoom),str(camera.offset),str([camera.limit_left,camera.limit_top,camera.limit_right,camera.limit_bottom]),str(root.canvas_transform),str(sprite.get_canvas_layer_node())])
    print("NPC_CAPTURE name=%s world=%s screen=%s camera=%s visible=%s viewport=%s"%[name,str(sprite.global_position),str(screen),str(camera.global_position if camera!=null else Vector2.ZERO),str(sprite.is_visible_in_tree()),str(sprite.get_viewport().size)])
    check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(screen),"NPC body is inside the actual camera: "+name)
    var output := ProjectSettings.globalize_path("res://../artifacts/npc_dialogue_motion_v10")
    DirAccess.make_dir_recursive_absolute(output)
    check(root.get_texture().get_image().save_jpg(output.path_join(name+".jpg"),0.9)==OK,"save real dialogue capture: "+name)

func actual_dialogue() -> void:
    var level = load("res://scenes/Main.tscn").instantiate(); root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    await frames(2)
    level.player.set_physics_process(false)
    var npc: Area2D = level.get_node("npc_gate_pilgrim")
    var sprite := npc.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    var probe := PhysicsRayQueryParameters2D.create(npc.global_position+Vector2(-160,-60),npc.global_position+Vector2(-160,240),1)
    var ground: Dictionary = level.get_world_2d().direct_space_state.intersect_ray(probe)
    check(not ground.is_empty(),"approach fixture has actual authored ground")
    if ground.is_empty(): level.free(); return
    level.player.global_position=Vector2(npc.global_position.x-160,ground.position.y-1)
    level.player.velocity=Vector2.ZERO; level.player.set_physics_process(true)
    await frames(12)
    check(level.player.is_on_floor(),"real Player settles on the authored ground before approach")
    level.player.set_physics_process(false)
    level.player.global_position.x=npc.global_position.x-38
    level.player.reset_camera_after_arrival()
    await frames(4)
    check(sprite.animation==&"greet" and not bool(sprite.get("conversation_active")),"real Player body entering the NPC area triggers a visible approach greeting")
    check(not level.dialogue_panel.visible,"approach greeting is visible before the dialogue panel")
    await capture("approach",sprite)
    var approach_phase := phase(sprite)
    level.player.reset_camera_after_arrival()
    level._try_interact()
    check(level.dialogue_panel.visible and level.ui_shell.dialogue_area==npc,"actual range interaction opens the normal dialogue")
    check(sprite.animation==&"greet","normal dialogue starts authored greeting")
    check(phase(sprite)==approach_phase,"normal interaction continues the approach greeting phase")
    check(level.dialogue_text_label.text==String(npc.get_meta("dialogue")[0]),"greeting does not delay or replace the first text")
    await frames(3)
    var before := phase(sprite)
    level.ui_shell._topic("route")
    check(sprite.animation==&"greet" and phase(sprite)==before,"route topic during greeting keeps the current pose clock")
    await capture("greeting",sprite)
    await frames(24)
    check(sprite.animation==&"talk","normal interface reaches talk after greeting")
    await capture("talking",sprite)
    var shrine := level.get_node_or_null("save_first_bell") as Area2D
    var bindings := LIVE.arrival_bindings(level,npc,shrine)
    callback_contract.exact=bindings.gameplay and bindings.components
    check(callback_contract.exact,"real NPC and shrine have exact gameplay and greeting callbacks")
    if shrine==null: level.free(); return
    var correct := Callable(level,"_on_interactable_entered").bind(npc)
    var foreign := Callable(level,"_on_interactable_entered").bind(shrine)
    var extra := Callable(level,"_on_interactable_exited").bind(shrine)
    npc.body_entered.connect(extra)
    bindings=LIVE.arrival_bindings(level,npc,shrine)
    callback_contract.extra_listener_rejected=not (bindings.gameplay and bindings.components)
    check(callback_contract.extra_listener_rejected,"an additional foreign-area listener is rejected")
    npc.body_entered.disconnect(extra)
    bindings=LIVE.arrival_bindings(level,npc,shrine)
    callback_contract.extra_removed=bindings.gameplay and bindings.components
    check(callback_contract.extra_removed,"removing an extra listener restores the exact contract")
    npc.body_entered.disconnect(correct); npc.body_entered.connect(foreign)
    bindings=LIVE.arrival_bindings(level,npc,shrine)
    callback_contract.wrong_area_rejected=not bindings.gameplay and bindings.components
    check(callback_contract.wrong_area_rejected,"correct listener totals with the wrong bound area are rejected")
    npc.body_entered.disconnect(foreign); npc.body_entered.connect(correct)
    bindings=LIVE.arrival_bindings(level,npc,shrine)
    callback_contract.restored=bindings.gameplay and bindings.components
    check(callback_contract.restored,"restoring the correct area restores the exact contract")
    var second: Area2D = level._make_npc({"id":"npc_gear_cartographer","name":"dialogue switch fixture"})
    level.add_child(second)
    level._show_dialogue(second,"切换说话者夹具。")
    check(sprite.animation==&"idle" and not bool(sprite.get("conversation_active")),"switching speakers returns the previous NPC to idle")
    var second_sprite := second.get_node("FriendlyFamilySprite") as AnimatedSprite2D
    check(second_sprite.animation==&"greet","new speaker gets one fresh greeting")
    level._close_overlays()
    await frames(20)
    check(second_sprite.animation==&"idle" and level.ui_shell.dialogue_area==null,"real overlay close cancels greeting and clears its owner")
    level._show_dialogue(npc,"重新交谈夹具。")
    check(sprite.animation==&"greet" and sprite.frame==0,"real interface can reopen after close")
    level._close_overlays()
    await capture("closed",sprite)
    var history := Area2D.new(); history.set_meta("kind","history"); level.add_child(history)
    level._show_dialogue(npc,"转向史迹前的交谈夹具。")
    level._show_dialogue(history,"史迹阅读夹具。")
    check(sprite.animation==&"idle" and level.ui_shell.dialogue_area==history,"reading a history object ends the previous NPC gesture")
    check(not level.ui_shell.dialogue_route_button.visible,"history keeps its original reading interface")
    level._close_overlays(); history.free()
    level._show_dialogue(second,"卸载角色夹具。")
    second.free()
    level._close_overlays()
    check(level.ui_shell.dialogue_area==null,"closing tolerates a freed speaker")
    level.free(); await frames(3)

extends SceneTree

var failures := 0
var moves_tested := 0
var elite_moves_tested:=0
var kinds_seen := {}
var capture := false

func _initialize() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func snap(label: String) -> void:
    if not capture: return
    var camera := root.get_viewport().get_camera_2d()
    if camera!=null:
        camera.reset_smoothing()
        camera.force_update_scroll()
    await process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://../artifacts/pilgrimage_overhaul")
    root.get_texture().get_image().save_png("res://../artifacts/pilgrimage_overhaul/"+label+".png")

func _run() -> void:
    var paths := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
    for id in paths:
        var scene: Node = load("res://scenes/Main.tscn").instantiate()
        scene.config_path="res://data/"+id+".json"
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        for i in range(15): await physics_frame
        check(scene.chapter_terrain.landforms.size()>0,id+" terrain exists")
        check(scene.chapter_terrain.ramp_count>0,id+" slopes exist")
        check(scene.flat_map_art.ready_for_platforms(),id+" platform art loaded")
        await slope_walk(scene,id)
        await snap(id)
        var npc: Area2D=scene.get_node(String(scene.config.npcs[0].id))
        scene.player.global_position=npc.global_position
        scene._try_interact()
        check(scene.active_overlay=="dialogue",id+" F opens dialogue")
        check(not scene.ui_shell.dialogue_body.text.is_empty(),id+" dialogue text")
        check(scene.ui_shell.dialogue_portrait.texture!=null,id+" portrait texture")
        scene.ui_shell._topic("route")
        if id==paths[0]: await snap("dialogue")
        scene._close_overlays()
        if id==paths[0]:
            scene._toggle_map()
            await snap("map")
            scene._close_overlays()
            scene._toggle_audio_settings()
            await snap("settings")
            scene._close_overlays()
        for data in scene.config.npcs:
            var quest: Dictionary=data.get("dialogue_topics",{}).get("quest",{})
            if quest.is_empty():continue
            var quest_npc: Area2D=scene.get_node(String(data.id))
            scene._add_inventory_item(String(quest.item),1,false)
            scene._talk_to_npc(quest_npc)
            scene.ui_shell._topic("wish")
            check(bool(scene.story_flags.get(String(quest.complete_flag),false)),id+" NPC delivery completes")
            var reward:=String(quest.get("reward",""))
            var reward_count:=int(scene.inventory_counts.get(reward,0))
            scene.ui_shell._topic("wish")
            check(int(scene.inventory_counts.get(reward,0))==reward_count,id+" NPC reward cannot duplicate")
            scene._close_overlays()
        scene._add_inventory_item("moss_lens",1,false)
        scene._toggle_backpack()
        check(scene.ui_shell.bag_grid.get_child_count()>0,id+" inventory populated")
        if id==paths[0]: await snap("inventory")
        scene._close_overlays()
        scene.player.ui_input_locked=true
        scene._spawn_boss()
        for i in range(2): await process_frame
        for actor in get_nodes_in_group("enemy"):
            if actor.get_parent()!=scene: continue
            if kinds_seen.has(actor.kind): continue
            kinds_seen[actor.kind]=true
            check(actor.original_visual,actor.kind+" redraw installed")
            check(actor.animated_sprite.sprite_frames.has_animation("windup"),actor.kind+" windup animation")
            if actor.locomotion=="stationary":
                var hold: Vector2=actor.global_position
                actor._update_locomotion(.25,scene.player)
                check(actor.global_position.distance_to(hold)<.1,actor.kind+" stays fixed")
            elif actor.locomotion=="flight":
                for data in scene.config.enemy_spawns:
                    if String(data.kind)==actor.kind:
                        var ground: Vector2=scene._resolve_enemy_spawn_position(data)
                        check(actor.spawn_position.y<=ground.y-35,actor.kind+" spawns above the ground")
                        break
            actor.battle_phase=2
            for command in actor.ai_profile.attacks:
                scene.player.global_position=actor.global_position+Vector2(85,40)
                actor._begin_attack(command)
                check(actor.state=="windup",actor.kind+" enters windup")
                actor._update_windup(float(command.windup)+.001)
                check(actor.state=="active",actor.kind+" enters active")
                for step in range(5):actor._update_active(float(command.active)/5.0+.001)
                check(actor.state=="recover",actor.kind+" enters recovery")
                actor._update_recover(float(command.recover)+.001)
                if bool(command.get("elite_only",false)): elite_moves_tested+=1
                else: moves_tested+=1
        scene.player.ui_input_locked=false
        scene.player.debug_invulnerable=true
        for effect in get_nodes_in_group("hostile_attack"):
            if effect.get_parent()==scene:
                effect._physics_process(.05)
                effect._physics_process(.8)
        scene.player.ui_input_locked=true
        var boss: Node=scene.boss_actor
        check(boss!=null,id+" boss spawns")
        if boss!=null:
            boss.battle_phase=1
            boss.hp=int(boss.max_hp*.5)
            scene.player.ui_input_locked=false
            boss._physics_process(.016)
            check(boss.battle_phase==2,id+" phase transition")
            scene.player.ui_input_locked=true
            scene.player.global_position=boss.global_position+Vector2(-190,40)
            var camera: Camera2D=scene.player.get_node("Camera2D")
            camera.reset_smoothing()
            boss._begin_attack(boss.ai_profile.attacks[0])
            await snap(id+"_boss")
        scene.queue_free()
        for i in range(3):await process_frame
    check(kinds_seen.size()==46,"46 distinct creature kinds exercised")
    check(moves_tested==104,"104 attack windup/active/recovery sequences exercised")
    # An elite may be the first actor of its kind; its signature attack is extra.
    check(elite_moves_tested<=10,"elite signature attacks are counted separately: %d" % elite_moves_tested)
    print("PILGRIMAGE_OVERHAUL_VALIDATION kinds=%d moves=%d failures=%d" %[kinds_seen.size(),moves_tested,failures])
    quit(0 if failures==0 else 1)

func slope_walk(scene: Node, id: String) -> void:
    for form in scene.chapter_terrain.landforms:
        var surface: Array=form.surface
        for j in range(1,surface.size()-2):
            var a:=Vector2(float(surface[j][0]),float(surface[j][1]))
            var b:=Vector2(float(surface[j+1][0]),float(surface[j+1][1]))
            if absf(a.y-b.y)<2 or b.x-a.x<45:continue
            var probe:=CharacterBody2D.new()
            probe.collision_layer=0
            probe.collision_mask=1
            probe.floor_snap_length=18
            probe.floor_constant_speed=true
            var collision:=CollisionShape2D.new()
            var shape:=CapsuleShape2D.new()
            shape.radius=12
            shape.height=60
            collision.shape=shape
            probe.add_child(collision)
            scene.add_child(probe)
            for dir in [1,-1]:
                probe.global_position=Vector2(a.x-24,a.y-31) if dir==1 else Vector2(b.x+24,b.y-31)
                probe.velocity=Vector2.ZERO
                for step in range(ceili((b.x-a.x+48)/4)+12):
                    await physics_frame
                    probe.velocity=Vector2(dir*240,probe.velocity.y+1600.0/60)
                    probe.move_and_slide()
                check(probe.is_on_floor(),id+" slope remains walkable direction "+str(dir))
                check(probe.global_position.x>b.x if dir==1 else probe.global_position.x<a.x,id+" slope can be crossed without jumping")
            probe.queue_free()
            return
    check(false,id+" slope traversal sample exists")

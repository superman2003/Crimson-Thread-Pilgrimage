extends SceneTree

var failures := 0
var checks := 0
var capture := false

func _initialize() -> void:
    capture="--capture" in OS.get_cmdline_user_args()
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    checks+=1
    if not condition:
        failures+=1
        push_error(message)

func snap(scene: Node, label: String) -> void:
    if not capture:return
    var camera: Camera2D=scene.player.get_node("Camera2D")
    camera.reset_smoothing();camera.force_update_scroll()
    await process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://../artifacts/cave_exploration")
    root.get_texture().get_image().save_png("res://../artifacts/cave_exploration/"+label+".png")

func _run() -> void:
    var ids: Array=["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]
    for id in ids:
        var scene: Node=load("res://scenes/Main.tscn").instantiate()
        scene.config_path="res://data/"+String(id)+".json"
        root.add_child(scene)
        for i in range(15):await physics_frame
        check(scene.cave_world!=null,String(id)+" cave installed")
        check(scene.cave_world.solid_rects.size()>80,String(id)+" solid rock envelope")
        check(not scene.cave_world.intersects_rect(Rect2(scene.player.global_position+Vector2(-17,-84),Vector2(34,84))),String(id)+" spawn not buried")
        check(scene.cave_lifts.size()==1,String(id)+" physical lift installed")
        await snap(scene,String(id)+"_entry")
        # Clear incidental combat while traversing geometry.
        for actor in get_nodes_in_group("enemy"):
            if actor.get_parent()==scene:actor.set_physics_process(false)
        scene.player.set_physics_process(false)
        scene.player.hurt_timer=1000
        for interactive in scene.config.interactives:
            if String(interactive.kind)=="lever":
                scene._activate_lever(scene.get_node(String(interactive.id)))
                break
        check(scene.boss_unlocked and scene.enemy_defeated==0,String(id)+" exploration lever opens boss route without a kill quota")
        scene.player.velocity=Vector2.ZERO
        for terrain in scene.chapter_terrain.landforms:
            if String(terrain.kind)=="tunnel":
                var p: Array=terrain.surface[0]
                scene.player.global_position=Vector2(float(p[0])+90,float(p[1]))
                await snap(scene,String(id)+"_cave")
                break
        var lift: Node=scene.cave_lifts[0]
        scene.player.global_position=Vector2(lift.x,lift.bottom_y)
        scene.player.velocity=Vector2.ZERO
        scene.player.set_physics_process(true)
        for i in range(10):await physics_frame
        check(scene.player.is_on_floor(),String(id)+" live player settles on basket before ascent")
        check(lift.request(scene.player.global_position),String(id)+" lift accepts rider")
        var rock_clear:=true
        for i in range(ceili((lift.bottom_y-lift.top_y)/lift.speed*60)+8):
            await physics_frame
            rock_clear=rock_clear and not scene.cave_world.intersects_rect(Rect2(scene.player.global_position+Vector2(-17,-84),Vector2(34,83)))
        check(not lift.moving,String(id)+" lift reaches upper landing")
        check(absf(scene.player.global_position.y-lift.top_y)<4,String(id)+" rider reaches upper landing without teleport")
        check(rock_clear,String(id)+" lift shaft keeps rider outside rock")
        await snap(scene,String(id)+"_lift")
        scene.player.set_physics_process(true)
        check(lift.request(Vector2(lift.x,lift.bottom_y)),String(id)+" lower landing can call basket back")
        for i in range(ceili((lift.bottom_y-lift.top_y)/lift.speed*60)+8):await physics_frame
        check(absf(lift.basket.position.y-lift.bottom_y)<1,String(id)+" basket returns to lower landing")
        check(absf(scene.player.global_position.y-lift.bottom_y)<12,String(id)+" live player physics rides down to the lower landing")
        scene.player.set_physics_process(false)
        check(not lift.request(Vector2.ZERO),String(id)+" remote lift activation rejected")
        # Exercise a newly joined route in both directions without jump input.
        var links: Array=[]
        for t in scene.chapter_terrain.landforms:
            if bool(t.get("cave_walk_link",false)):links.append(t)
        check(not links.is_empty(),String(id)+" walking route added")
        var surface: Array=links[0].surface
        var a:=Vector2(float(surface[0][0]),float(surface[0][1]))
        var b:=Vector2(float(surface[-1][0]),float(surface[-1][1]))
        var probe:=CharacterBody2D.new()
        probe.collision_layer=0;probe.collision_mask=1;probe.floor_snap_length=18;probe.floor_constant_speed=true
        var collider:=CollisionShape2D.new()
        var shape:=RectangleShape2D.new();shape.size=Vector2(30,80)
        collider.shape=shape;collider.position=Vector2(0,-40)
        probe.add_child(collider);scene.add_child(probe)
        for direction in [1,-1]:
            probe.global_position=Vector2(a.x+4,a.y-2) if direction==1 else Vector2(b.x-4,b.y-2)
            probe.velocity=Vector2.ZERO
            for i in range(ceili((b.x-a.x)/4)+6):
                await physics_frame
                probe.velocity=Vector2(direction*240,probe.velocity.y+1850.0/60)
                probe.move_and_slide()
            check(probe.global_position.x>b.x-5 if direction==1 else probe.global_position.x<a.x+5,String(id)+" new ground crosses without jump "+str(direction)+" at "+str(probe.global_position)+" target "+str(a)+" -> "+str(b))
            check(probe.is_on_floor(),String(id)+" remains grounded "+str(direction))
        probe.queue_free()
        # Real physics sight rays terminate in opaque cave mass.
        var rock: Rect2=scene.cave_world.solid_rects[0]
        var center:=rock.get_center()
        var query:=PhysicsRayQueryParameters2D.create(center-Vector2(rock.size.x+50,0),center,16)
        check(not scene.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),String(id)+" rock blocks sight ray")
        check(scene.cave_world.shader_material!=null,String(id)+" sight material installed")
        scene.queue_free()
        for i in range(3):await process_frame
    print("CAVE_EXPLORATION_VALIDATION chapters=6 checks=%d failures=%d"%[checks,failures])
    quit(0 if failures==0 else 1)

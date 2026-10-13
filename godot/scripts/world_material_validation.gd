extends SceneTree
## Verify every region uses one continuous stone material, without touching collision.
const ROCK := preload("res://scripts/world_rock_material.gd")
const MAP_ART := preload("res://scripts/flat_map_art.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    for bridge in ["bronze_bridge", "sluice_bridge", "vellum_bridge", "glassvine_bridge", "ember_bridge", "void_bridge"]:
        check(MAP_ART.material_variant_for(bridge) in [6,7],bridge+" selects bridge rather than fractured rock")
    for id in ["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]:
        var scene: Node = load("res://scenes/Main.tscn").instantiate()
        scene.config_path="res://data/"+id+".json"
        root.add_child(scene)
        scene.player.set_physics_process(false)
        for actor in get_nodes_in_group("enemy"): actor.set_physics_process(false)
        await process_frame
        var theme: String = scene._art_theme_id()
        var material: ShaderMaterial = ROCK.for_theme(theme)
        check(material!=null and material.get_shader_parameter("stone_atlas")!=null,id+" stone texture loaded")
        var texture: Texture2D = material.get_shader_parameter("stone_atlas")
        check(texture.resource_path==ROCK.INK_ROCK,id+" shares hand-inked rock family")
        check(material.get_shader_parameter("stone_tint")==ROCK.TINTS[theme],id+" keeps region palette")
        check(material.get_shader_parameter("tile_size")==Vector2(texture.get_size()),id+" mural uses native density")
        var mass: Node = scene.cave_world.get_node("PaintedRockMass")
        check(mass.material==material,id+" visible rock uses regional material")
        check(scene.cave_world.get_node("SolidCaveMass").get_child_count()==scene.config.cave_world.solid_rects.size(),id+" rock collision count preserved")
        var collision_count: int = scene.cave_world.get_node("SolidCaveMass").get_child_count()
        # Visit real camera positions; renderer culling must not remove collision.
        var camera: Camera2D = scene.player.get_node("Camera2D")
        for sample in [Vector2(400,700),Vector2(scene.world_width*0.5,scene.world_height*0.5),Vector2(scene.world_width-400,scene.world_height-400)]:
            scene.player.position=sample
            camera.reset_smoothing()
            await process_frame
            await process_frame
            mass._refresh_view()
            for solid in scene.cave_world.solid_rects:
                var visible: Rect2 = solid.intersection(mass.view_bounds)
                if visible.has_area():
                    check(mass.painted_rects.has(visible),id+" visible collision has opaque rock coverage")
            for painted in mass.painted_rects:
                check(mass.view_bounds.encloses(painted),id+" distant rock is culled")
            check(scene.cave_world.get_node("SolidCaveMass").get_child_count()==collision_count,id+" distant collisions survive camera travel")
        for form in scene.chapter_terrain.get_children():
            for face in form.get_children():
                if face is Polygon2D:
                    check(face.material==material,id+" entire ground stratum shares cave material")
        for data in scene.config.platforms:
            if data.has("terrain_id"): continue
            var platform: Node = scene.get_node(String(data.id))
            var selected: Array = platform.get_meta("platform_art_body_variants",[])
            check(selected.size()==1 and int(selected[0])==int(platform.get_meta("platform_art_variant",-1)),id+" platform caps/body never mix variants: "+String(data.id))
            var sprites: Array = []
            for child in platform.get_children():
                if child is Sprite2D and child.has_meta("original_map_asset"): sprites.append(child)
            if sprites.size()>1:
                for sprite in sprites: check(sprite.flip_h==sprites[0].flip_h,id+" platform segments keep one orientation")
        scene.queue_free()
        for i in 3: await process_frame
    print("WORLD_MATERIAL_VALIDATION regions=6 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

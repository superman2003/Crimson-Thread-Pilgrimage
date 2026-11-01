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
    # Rims blend into the rock body with the body's own sampling; the shared
    # block must stay byte-identical or a seam appears where they join.
    var blocks: Array = []
    for path in ["res://shaders/world_rock.gdshader","res://shaders/ink_cave_edge.gdshader"]:
        var code: String = (load(path) as Shader).code
        var begin := code.find("// ROCK_SAMPLE_BEGIN")
        var end := code.find("// ROCK_SAMPLE_END")
        check(begin>=0 and end>begin,path+" carries the shared rock sampling block")
        blocks.append(code.substr(begin,end-begin))
    check(blocks.size()==2 and blocks[0]==blocks[1],"rock body and rim join use identical sampling")
    for bridge in ["bronze_bridge", "sluice_bridge", "vellum_bridge", "glassvine_bridge", "ember_bridge", "void_bridge"]:
        check(MAP_ART.material_variant_for(bridge) in [6,7],bridge+" selects bridge rather than fractured rock")
    for id in ["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]:
        var scene: Node = load("res://scenes/Main.tscn").instantiate()
        scene.config_path="res://data/"+id+".json"
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
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
                if face is Polygon2D and not face.has_meta("independent_edge_art"):
                    check(face.material==material,id+" entire ground stratum shares cave material")
        var ledge_counts := {}
        var ledge_total := 0
        var flips := {}
        for data in scene.config.platforms:
            if data.has("terrain_id"): continue
            var platform: Node = scene.get_node(String(data.id))
            var chosen := int(platform.get_meta("platform_art_variant",-1))
            var art: Dictionary = data.get("art",{})
            var again: Dictionary = MAP_ART.platform_choice(theme,String(data.id),String(data.get("material","moss_stone")),art)
            check(int(again.variant)==chosen and bool(again.flip)==bool(platform.get_meta("platform_art_flip",false)),id+" platform slice and orientation are stable across rebuilds: "+String(data.id))
            if art.get("flip_h") is bool and not art.has("material_flip_h"):
                check(bool(platform.get_meta("platform_art_flip",false))==bool(art.flip_h),id+" authored whole-platform flip_h is honoured: "+String(data.id))
            if int(again.family)==2 and not art.has("material_variant"):
                check(chosen in MAP_ART.LEDGE_FAMILIES[theme],id+" ordinary ledge stays inside the theme ledge family: "+String(data.id))
                ledge_counts[chosen]=int(ledge_counts.get(chosen,0))+1
                ledge_total+=1
                flips[bool(platform.get_meta("platform_art_flip",false))]=true
            var selected: Array = platform.get_meta("platform_art_body_variants",[])
            check(selected.size()==1 and int(selected[0])==int(platform.get_meta("platform_art_variant",-1)),id+" platform caps/body never mix variants: "+String(data.id))
            var sprites: Array = []
            for child in platform.get_children():
                if child is Sprite2D and child.has_meta("original_map_asset"): sprites.append(child)
            if sprites.size()>1:
                for sprite in sprites: check(sprite.flip_h==sprites[0].flip_h,id+" platform segments keep one orientation")
        # V03: a region's ordinary ledges no longer repeat one silhouette.
        var most := 0
        for count in ledge_counts.values(): most=maxi(most,int(count))
        check(ledge_total>=10 and ledge_counts.size()>=3,id+" ordinary ledges use at least three slices (%d ledges, %d slices)" % [ledge_total,ledge_counts.size()])
        check(most*2<=ledge_total,id+" no single slice covers more than half the ordinary ledges (%d/%d)" % [most,ledge_total])
        check(flips.size()==2,id+" ordinary ledges appear in both orientations")
        scene.queue_free()
        for i in 3: await process_frame
    print("WORLD_MATERIAL_VALIDATION regions=6 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

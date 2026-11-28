extends SceneTree
## Real scene publication needs the fully imported game, not the isolated
## Boss Rush logic fixture used by Native contracts.
const RUSH := preload("res://scripts/boss_rush.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const STALE := "res://assets/sprites/original_creatures/boss_rush_validation/old.png"
const DEST := "res://assets/sprites/original_creatures/waterwheel_knight/motion_redraw_manifest.json"
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func seed_old() -> void:
    ART.textures[STALE] = ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
    ART.recent_region_assets.append({"id":"previous-challenge", "manifests":{}, "textures":{STALE:true}})
func check_ready_cache_boundaries() -> void:
    var source := Node.new()
    root.add_child(source)
    current_scene=source
    var controller:=RUSH.new()
    root.add_child(controller)
    controller.set_process(false)
    seed_old()
    var stage: Node=load("res://scenes/Main.tscn").instantiate()
    stage.config_path="res://data/demo_ch02_rain_foundry_canal.json"
    stage.world_mode=false
    controller._swap(source,stage)
    check(stage.initial_region_ready and not stage.config.is_empty(),"production Main publishes its destination after entering tree")
    check(not ART.textures.has(STALE),"completed boss scene swap drops stale challenge texture despite the recent list")
    check(ART.frame_cache.has(DEST),"completed boss scene swap keeps destination character frames")
    seed_old()
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_startup_options_enabled=false
    world.world_resume=false
    world.world_save_path="user://crimson_review_boss_cache.json"
    controller._swap(stage,world)
    check(not world.initial_region_ready and ART.textures.has(STALE),"asynchronous destination keeps current texture until publication")
    controller.queue_free()
    await READY.wait_for(world)
    check(world.initial_region_ready and not ART.textures.has(STALE),"return safely prunes stale textures after publication even when the controller is freed")
    check(ART.recent_region_assets.size()==1 and String(ART.recent_region_assets[0].id)==String(world.config.id),"return keeps only the published destination in recent region assets")
    world.queue_free()
    for i in 8:await process_frame

func run() -> void:
    await check_ready_cache_boundaries()
    print("WORLD_BOSS_RUSH_CACHE checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

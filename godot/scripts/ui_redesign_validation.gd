extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:
        failures+=1
        push_error(message)
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://ui_redesign_validation.json"
    root.add_child(world)
    await process_frame
    world.set_process(false)
    world.player.set_physics_process(false)
    var ui: Control=world.ui_shell
    for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768),Vector2i(960,540)]:
        root.size=dimensions
        await process_frame
        ui._fit_viewport()
        for panel in [ui.bag,ui.build_panel,ui.dialogue,ui.settings,world.map_panel]:
            var bounds: Rect2=panel.get_global_rect()
            check(Rect2(Vector2.ZERO,ui.get_viewport_rect().size).encloses(bounds),"Overlay remains inside viewport at %s: %s" % [dimensions,panel.name])
        check(is_equal_approx(ui.scale.x,ui.scale.y),"UI preserves icon proportions")
    world.player.hp=1
    ui._process(0.0)
    check(ui.health_glyphs.hp==1 and ui.health_glyphs.maximum==world.player.max_hp,"Low health follows player state")
    check(ui.thread_bar.size.y<=8,"Energy meter keeps a thin profile: size=%s minimum=%s" % [ui.thread_bar.size,ui.thread_bar.get_combined_minimum_size()])
    world._toggle_backpack()
    ui._process(0.0)
    check(ui.modal_shade.visible and not ui.hud_card.visible and not ui.tactical_cards[0].visible,"Inventory dims the world and removes competing combat HUD")
    check(world.player.ui_input_locked,"Modal menu prevents accidental combat input")
    world._close_overlays()
    ui._process(0.0)
    check(not ui.modal_shade.visible and ui.hud_card.visible and ui.tactical_cards[0].visible,"Closing restores combat HUD")
    check(not world.player.ui_input_locked,"Closing returns player controls")
    world.free()
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_redesign_validation.json"+suffix))
    print("UI_REDESIGN_VALIDATION_%s checks=%d failures=%d" % ["PASS" if failures==0 else "FAIL",checks,failures])
    quit(1 if failures else 0)

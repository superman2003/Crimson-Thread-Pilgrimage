extends SceneTree
## A paused, isolated rendering fixture for before/after settings comparison.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")

func _initialize() -> void:
    call_deferred("run")

static func vector(value: Vector2) -> Array:
    return [snappedf(value.x,0.001), snappedf(value.y,0.001)]

static func snapshot_settings(node: Node) -> Dictionary:
    var result := {"class":node.get_class()}
    var node_name := String(node.name)
    if not node_name.begins_with("@"): result.name = node_name
    if node is Control:
        result.position = vector(node.position)
        result.size = vector(node.size)
        result.minimum = vector(node.custom_minimum_size)
        result.visible = node.visible
        result.mouse_filter = node.mouse_filter
        result.focus_mode = node.focus_mode
    if node is Label or node is Button:
        result.text = node.text
        result.font_size = node.get_theme_font_size("font_size")
    if node is BaseButton:
        result.disabled = node.disabled
        result.pressed = node.button_pressed
    if node is Range:
        result.range = [node.min_value,node.max_value,node.step,node.value]
    if node is OptionButton:
        result.options = []
        for index in node.item_count: result.options.append(node.get_item_text(index))
    if node is Window:
        result.title = node.title
        result.visible = node.visible
        result.minimum = [node.min_size.x,node.min_size.y]
    if node is TextureRect and node.texture != null:
        result.texture = node.texture.resource_path
    result.children = []
    for child in node.get_children(): result.children.append(snapshot_settings(child))
    return result

static func sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Settings pixel capture requires real GL")
        quit(1)
        return
    root.size = Vector2i(1280,720)
    root.content_scale_size = root.size
    root.process_mode = Node.PROCESS_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color("18222b"))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://settings_construction_capture.json"
    root.add_child(world)
    await READY.wait_for(world)
    current_scene = world
    print("SETTINGS CAPTURE ready=true render_loop=",RenderingServer.render_loop_enabled)
    for child in world.get_children():
        if child is CanvasItem: child.visible = false
        elif child is CanvasLayer and child != world.ui_canvas: child.visible = false
    var ui: Control = world.ui_shell
    for child in ui.get_children():
        if child is CanvasItem: child.visible = false
    ui.settings.visible = true
    for unused in 4: await process_frame
    # This paused capture needs one explicit frame, including offscreen windows.
    # https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-force-draw
    RenderingServer.force_draw(false)
    print("SETTINGS CAPTURE explicit_frame=true")
    var pixels := root.get_texture().get_image()
    var output := ProjectSettings.globalize_path("res://../artifacts/settings_construction_v12/capture/current")
    DirAccess.make_dir_recursive_absolute(output)
    var saved := pixels.save_png(output.path_join("settings.png"))
    var result := {"viewport":[pixels.get_width(),pixels.get_height()],
        "pixel_sha256":sha256(pixels.get_data()),"tree":snapshot_settings(ui.settings),
        "fixture":"Paused settings only over a solid clear color; not natural gameplay."}
    var file := FileAccess.open(output.path_join("settings.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  ")+"\n")
    file.close()
    RETIRE.retire_tree(world)
    world.free()
    current_scene = null
    var drained: bool = await RETIRE.drain(self)
    print("SETTINGS_CONSTRUCTION_CAPTURE saved=%s drained=%s" % [saved == OK,drained])
    quit(0 if saved == OK and drained else 1)

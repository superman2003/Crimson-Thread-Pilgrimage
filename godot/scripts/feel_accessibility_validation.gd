extends RefCounted
## Real rendering-service checks, invoked by ui_build_accessibility's CI entry.
const FEEL = preload("res://scripts/feel_kit.gd")
var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func run(tree: SceneTree, ui: Control) -> int:
    var real_gl := DisplayServer.get_name() != "headless"
    var enabled_effects := 2 if real_gl else 0
    var feel := FEEL.new()
    tree.root.add_child(feel)
    feel.set_process(false)
    var camera := Camera2D.new()
    tree.root.add_child(camera)
    feel.register_camera(camera)
    feel.add_trauma(0.7)
    feel._process(0.01)
    _check(feel._trauma > 0.0 and camera.offset != Vector2.ZERO, "Enabled trauma moves the actual camera")
    feel.flash_screen(Color.WHITE, 0.5, 600)
    feel.black_frame(Vector2(100, 100), 600)
    _check(feel._overlay_layer.get_child_count() == enabled_effects, "Enabled flash and black frame create real overlay controls")
    feel.set_accessibility({"flash_enabled":false,"camera_shake":0.0})
    _check(feel._trauma == 0.0 and camera.offset == Vector2.ZERO and camera.rotation == 0.0, "Disabling shake clears current trauma and transform immediately")
    _check(feel._overlay_layer.get_child_count() == 0, "Disabling flash immediately detaches both existing effects")
    feel.add_trauma(0.9)
    feel.flash_screen(Color.WHITE, 0.5, 600)
    feel.black_frame(Vector2.ZERO, 600)
    feel._process(0.01)
    _check(feel._trauma == 0.0 and camera.offset == Vector2.ZERO, "Disabled service rejects future trauma")
    _check(feel._overlay_layer.get_child_count() == 0, "Disabled service rejects future flash and black frames")
    feel.set_accessibility({"flash_enabled":true,"camera_shake":0.5})
    _check(feel._trauma == 0.0 and feel._overlay_layer.get_child_count() == 0, "Re-enabling does not replay suppressed effects")
    feel.add_trauma(0.2)
    _check(is_equal_approx(feel._trauma, 0.2), "Nonzero slider does not scale player trauma a second time")
    feel.flash_screen(Color.WHITE, 0.5, 1)
    feel.black_frame(Vector2.ZERO, 1)
    _check(feel._overlay_layer.get_child_count() == enabled_effects, "Re-enabled flashes can be created again")
    await tree.create_timer(0.1).timeout
    await tree.process_frame
    _check(feel._overlay_layer.get_child_count() == 0, "Normal timed flash cleanup still works")
    feel._process(0.01)
    var active_trauma: float = feel._trauma
    feel.register_camera(camera)
    _check(feel._trauma == active_trauma, "Re-registering the active camera preserves its shake")
    var next_camera := Camera2D.new()
    tree.root.add_child(next_camera)
    feel.register_camera(next_camera)
    _check(camera.offset == Vector2.ZERO and camera.rotation == 0.0 and feel._trauma == 0.0, "Camera replacement clears the old camera and pending shake")
    camera.free()
    next_camera.rotation = 0.2
    feel._process(0.01)
    _check(next_camera.rotation == 0.0, "Decay cleanup clears pure rotation even with zero offset")
    feel.register_camera(null)
    next_camera.free()
    feel.set_accessibility({"camera_shake":0.0})
    _check(feel._trauma == 0.0, "Settings tolerate a retired camera")
    var global_feel := tree.root.get_node("FeelKit")
    global_feel.set_process(false)
    var old_preferences: Dictionary = ui.accessibility.duplicate()
    ui.accessibility["flash_enabled"] = true
    ui.accessibility["camera_shake"] = 1.0
    ui._apply_accessibility()
    global_feel.flash_screen(Color.WHITE, 0.5, 600)
    global_feel.add_trauma(0.8)
    _check(global_feel._overlay_layer.get_child_count() == (1 if real_gl else 0) and global_feel._trauma > 0.0, "UI enabling reaches the real autoload")
    ui.accessibility["flash_enabled"] = false
    ui.accessibility["camera_shake"] = 0.0
    ui._apply_accessibility()
    _check(global_feel._overlay_layer.get_child_count() == 0 and global_feel._trauma == 0.0, "UI disabling clears the global service in the same call")
    ui._save_accessibility()
    ui.accessibility["flash_enabled"] = true
    ui.accessibility["camera_shake"] = 1.0
    ui._load_accessibility()
    ui._apply_accessibility()
    _check(not global_feel._flash_enabled and not global_feel._shake_enabled, "Reloaded settings keep the global effects disabled")
    ui.accessibility = old_preferences
    ui._apply_accessibility()
    global_feel.set_process(true)
    feel.free()
    await tree.process_frame
    print("FEEL_ACCESSIBILITY checks=%d failures=%d real_gl=%s" % [checks, failures, real_gl])
    return failures

extends SceneTree
## C01: a field enemy's hit box sits on its drawn body and is at least as wide
## as the core of that body, while the box its attack lunges sweep against
## terrain keeps the configured footprint. Measure every idle frame.
const CHAPTERS := ["res://data/demo_ch01_moss_bell_court.json", "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json", "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json", "res://data/demo_ch06_silent_crown_core.json"]

var failures := 0
var checks := 0
var kinds := 0
var lowest_body := INF


func _initialize() -> void:
    call_deferred("_run")


func _opaque_rect(sprite: AnimatedSprite2D) -> Rect2:
    var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
    if texture == null:
        return Rect2()
    var size := texture.get_size()
    var inner := Rect2(Vector2.ZERO, size)
    if texture is AtlasTexture:
        inner = Rect2(texture.margin.position, texture.region.size)
    var origin := (-size * 0.5 if sprite.centered else Vector2.ZERO) + sprite.offset
    var transform := sprite.get_global_transform()
    var a := transform * (origin + inner.position)
    var b := transform * (origin + inner.end)
    return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _run() -> void:
    var seen := {}
    for path: String in CHAPTERS:
        var scene: Node = preload("res://scenes/Main.tscn").instantiate()
        scene.set("config_path", path)
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        await _frames(10)
        for enemy in get_nodes_in_group("enemy"):
            if enemy.is_boss or seen.has(enemy.kind) or enemy.get("hurtbox_authored") == true or not is_instance_valid(enemy.animated_sprite):
                continue
            seen[enemy.kind] = true
            kinds += 1
            var sprite: AnimatedSprite2D = enemy.animated_sprite
            sprite.play(&"idle")
            sprite.pause()
            for index in sprite.sprite_frames.get_frame_count(&"idle"):
                sprite.frame = index
                var body := _opaque_rect(sprite)
                var hit: Rect2 = enemy.get_hurtbox_rect()
                var overlap := body.intersection(hit).get_area()
                var on_body := overlap / maxf(1.0, hit.get_area())
                var covered := overlap / maxf(1.0, body.get_area())
                lowest_body = minf(lowest_body, covered)
                _check(on_body >= 0.9, "%s idle[%d] hit box lies on its drawn body (%.2f)" % [enemy.kind, index, on_body])
                _check(covered >= 0.38, "%s idle[%d] drawn body is mostly hittable (%.2f)" % [enemy.kind, index, covered])
                _check(hit.size.x >= 48.0, "%s hit box never narrower than the old fixed 48px" % enemy.kind)
                var motion: Rect2 = enemy.get_motion_rect() if enemy.has_method("get_motion_rect") else hit
                _check(is_equal_approx(motion.size.x, 48.0), "%s lunges keep the configured terrain footprint" % enemy.kind)
        scene.queue_free()
        await _frames(4)
    _check(kinds >= 35, "field enemy kinds measured (%d)" % kinds)
    if failures > 0:
        print("ENEMY_HURTBOX_FIT_FAIL failures=%d checks=%d" % [failures, checks])
        call_deferred("quit", 1)
        return
    print("ENEMY_HURTBOX_FIT_PASS kinds=%d lowest_body=%.2f checks=%d" % [kinds, lowest_body, checks])
    call_deferred("quit", 0)


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("ENEMY_HURTBOX_FIT " + label)

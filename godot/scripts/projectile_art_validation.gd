extends RefCounted
## Invoked by the existing enemy_effect_lifetime CI entry, without new registry files.
const ART := preload("res://scripts/projectile_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
var checks := 0
var failures := 0

class Target extends CharacterBody2D:
    var ui_input_locked := false
    var damage_received := 0
    var facing := 1
    var deflect_enabled := false
    func take_damage(amount: int, _point: Vector2, _blockable: bool = true) -> void:
        damage_received += amount
    func can_deflect_projectile() -> bool:
        return deflect_enabled

class ReflectedTarget extends Node2D:
    var dying := false
    var hit_count := 0
    func take_hit(_amount: int, _direction: int) -> void:
        hit_count += 1

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PROJECTILE_ART: " + label)

func run(tree: SceneTree, enemy) -> int:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/projectiles/manifest.json"))
    _check(manifest.families == ART.FAMILIES and manifest.cell == ART.CELL, "runtime order and packed manifest agree")
    var image := ART.ATLAS.get_image()
    _check(image.get_size() == Vector2i(1024, 1920), "one bounded atlas contains all 120 frames")
    for family in ART.FAMILIES:
        var flight := {}
        var impact := {}
        for frame in range(8):
            var cel := image.get_region(Rect2i(ART.atlas_rect(family, frame)))
            _check(not cel.is_invisible(), "%s/%d has actual authored pixels" % [family, frame])
            var fingerprint := cel.get_data().hex_encode().sha256_text()
            if frame < 4: flight[fingerprint] = true
            else: impact[fingerprint] = true
        _check(flight.size() == 4 and impact.size() == 4, family + " has four distinct flight and four distinct impact cels")
    await _verify_flight_pixels(tree, enemy)
    var expected := {"root_cage_hunter":"net", "wax_bee":"stinger", "phase_censor":"blade", "kneeling_crossbowman":"bolt", "pipe_thrower":"slug", "silent_bugbler":"chime", "falling_clapper":"chime", "rain_censer_mote":"incense", "broken_string_gardener":"seed"}
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var seen := {}
    var old_kind: String = enemy.kind
    for kind in catalogue:
        var commands: Array = catalogue[kind].get("attacks", []).duplicate()
        commands.append_array(catalogue[kind].get("elite", {}).get("attacks", []))
        for command: Dictionary in commands:
            if not String(command.get("type", "")) in ["projectile", "fan", "mortar", "nova"]:
                continue
            enemy.kind = kind
            var effect: Node2D = enemy._effect("projectile", Vector2(800, 300), Vector2.RIGHT * 90, command, 0.1, 2.0)
            effect.set_physics_process(false)
            var family := ART.family_for(effect.skin, enemy)
            var want := String(expected.get(kind, command.get("skin", "thorn")))
            _check(family == want, "%s/%s selects its own family through the real spawn path" % [kind, command.id])
            _check(effect.damage == int(command.get("damage", enemy.damage)) and effect.skin == String(command.get("skin", "thorn")), "presentation leaves authored command and damage unchanged")
            seen[family] = true
            effect.cancel()
    enemy.kind = old_kind
    _check(seen.size() == 15, "all fifteen families are used by current attacks")
    _check(ART.family_for("unrecognized_future_skin") == "", "unknown future skin retains procedural fallback")
    _check(ART.family_for("page", enemy) == "page", "explicit nonlegacy skin is respected")
    await tree.process_frame
    var stage: Node2D = enemy.get_parent()
    var target := Target.new()
    target.position = Vector2(300, 242)
    stage.add_child(target)
    target.add_to_group("player")
    target.deflect_enabled = true
    var incoming: Node2D = enemy._effect("projectile", Vector2(330, 200), Vector2.LEFT * 180, {"skin":"bolt", "damage":2}, 0, 2)
    incoming.set_physics_process(false)
    incoming._physics_process(0.001)
    _check(incoming.reflected and incoming.velocity.x >= 250 and target.damage_received == 0, "facing deflection preserves the real reflection path and avoids player damage")
    incoming.cancel()
    target.deflect_enabled = false
    var shot: Node2D = enemy._effect("projectile", Vector2(300, 200), Vector2.RIGHT * 1, {"skin":"bolt", "damage":2}, 0, 2)
    shot.set_physics_process(false)
    shot._physics_process(0.001)
    _check(target.damage_received == 2 and shot.cancelled and not shot.is_in_group("hostile_attack"), "player hit deals damage once and retires the dangerous object immediately")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 1, "player hit emits one separate impact decoration")
    shot._physics_process(0.001)
    _check(target.damage_received == 2, "retired shot cannot damage again while impact animation plays")
    target.queue_free()
    await tree.process_frame
    var reflected_target := ReflectedTarget.new()
    reflected_target.position = Vector2(500, 300)
    stage.add_child(reflected_target)
    reflected_target.add_to_group("enemy")
    var returned: Node2D = enemy._effect("projectile", Vector2(500, 300), Vector2.LEFT, {"skin":"key"}, 0, 2)
    returned.set_physics_process(false)
    returned.reflected = true
    returned._physics_process(0.001)
    _check(reflected_target.hit_count == 1 and returned.cancelled, "returned shot still damages the enemy once")
    reflected_target.queue_free()
    var wall := StaticBody2D.new()
    wall.position = Vector2(700, 200)
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(10, 100)
    collider.shape = shape
    wall.add_child(collider)
    stage.add_child(wall)
    await tree.physics_frame
    await tree.process_frame
    var wall_shot: Node2D = enemy._effect("projectile", Vector2(650, 200), Vector2.RIGHT * 500, {"skin":"slug"}, 0, 2)
    wall_shot.set_physics_process(false)
    wall_shot._physics_process(0.2)
    _check(wall_shot.cancelled, "solid wall still cancels a travelling projectile")
    var hit_mark: Node2D = tree.get_nodes_in_group(POLICY.CONTACT_GROUP).back()
    _check(absf(hit_mark.global_position.x - 695.0) < 0.1, "wall impact is anchored to the ray hit, not the overshot endpoint")
    var mortar: Node2D = enemy._effect("projectile", Vector2(650, 200), Vector2.RIGHT * 500, {"skin":"slug", "impact_pool":true}, 0, 2)
    mortar.set_physics_process(false)
    var before_pool := tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    mortar._physics_process(0.2)
    _check(mortar.effect_kind == "pool" and not mortar.cancelled and is_equal_approx(mortar.arm_delay, 0.55), "mortar retains its real pool transition and warning")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before_pool, "mortar transition does not pretend to be a terminal hit")
    mortar.cancel()
    wall.queue_free()
    for mark in tree.get_nodes_in_group(POLICY.CONTACT_GROUP): mark.queue_free()
    await tree.process_frame
    var marks: Array = []
    for index in range(20):
        var mark := ART.spawn_impact(stage, Vector2(200, 200), "thorn", 11, Vector2.RIGHT, false)
        if mark != null: marks.append(mark)
    _check(marks.size() == 12, "impact burst obeys the existing shared twelve-decoration budget")
    var selected: Array[int] = []
    marks[0].paint = func(_host, _family, frame, _radius, _axis, _alpha, _reflected):
        selected.append(frame)
        return true
    for time in [0.001, 0.051, 0.101, 0.151]:
        marks[0].age = time
        marks[0]._draw()
    _check(selected == [4, 5, 6, 7], "live impact drawing selects all four delivered impact cels in order")
    marks[0].age = 0.0
    for mark in marks:
        _check(not mark.is_in_group("hostile_attack"), "impact decoration is never a damaging projectile")
        mark._process(0.1)
        _check(not mark.is_queued_for_deletion(), "slow first frame retains its first draw opportunity")
        mark._process(0.21)
        _check(mark.is_queued_for_deletion(), "impact expires after its four authored cels")
    await tree.process_frame
    var before_cancel := tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    var cancelled: Node2D = enemy._effect("projectile", Vector2(900, 300), Vector2.RIGHT, {"skin":"thorn"}, 0, 2)
    cancelled.cancel()
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before_cancel, "owner cancellation does not emit a fake impact")
    var expired: Node2D = enemy._effect("projectile", Vector2(900, 300), Vector2.RIGHT, {"skin":"thorn"}, 0, 0.01)
    expired.set_physics_process(false)
    expired._physics_process(0.02)
    _check(expired.cancelled and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before_cancel, "natural expiry cancels without an invented hit")
    print("PROJECTILE_ART_VALIDATION checks=%d failures=%d families=%d" % [checks, failures, seen.size()])
    return failures

func _verify_flight_pixels(tree: SceneTree, enemy) -> void:
    _check(DisplayServer.get_name() != "headless", "authored projectile rendering requires real GL")
    if DisplayServer.get_name() == "headless":
        return
    var view := SubViewport.new()
    view.size = Vector2i(400, 240)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    tree.root.add_child(view)
    var stage := Node2D.new()
    view.add_child(stage)
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(400,0), Vector2(400,240), Vector2(0,240)])
    stage.add_child(background)
    var shots: Array[Node2D] = []
    for index in range(15):
        var shot: Node2D = enemy._effect("projectile", Vector2.ZERO, Vector2.RIGHT * 90, {"skin":ART.FAMILIES[index], "radius":11}, 0, 2)
        shot.set_physics_process(false)
        shot.reparent(stage, false)
        shot.position = Vector2(index % 5 * 80 + 40, index / 5 * 80 + 40)
        shots.append(shot)
    for light in [false, true]:
        background.color = Color(0.89,0.87,0.8) if light else Color(0.08,0.12,0.14)
        var fingerprints: Array[Dictionary] = []
        for index in range(15): fingerprints.append({})
        for frame in range(4):
            for shot in shots:
                shot.age = float(frame) / ART.FLIGHT_FPS + 0.001
                shot.queue_redraw()
            await tree.process_frame
            await RenderingServer.frame_post_draw
            var rendered := view.get_texture().get_image()
            for index in range(15):
                var pos: Vector2 = shots[index].position
                var cel := rendered.get_region(Rect2i(Vector2i(pos) - Vector2i(18,18), Vector2i(36,36)))
                fingerprints[index][cel.get_data().hex_encode().sha256_text()] = true
                if frame == 0:
                    var visible := 0
                    for y in range(36):
                        for x in range(36):
                            if Vector3(cel.get_pixel(x,y).r - background.color.r, cel.get_pixel(x,y).g - background.color.g, cel.get_pixel(x,y).b - background.color.b).length() > 0.1: visible += 1
                    _check(visible >= 12, "%s remains visible at its real 22px body on light=%s" % [ART.FAMILIES[index], light])
            var capture := OS.get_environment("PROJECTILE_ART_CAPTURE_DIR")
            if not capture.is_empty():
                DirAccess.make_dir_recursive_absolute(capture)
                rendered.save_png(capture.path_join("flight_%s_%d.png" % ["light" if light else "dark", frame]))
        for index in range(15):
            _check(fingerprints[index].size() == 4, "%s really renders four distinct flight frames on light=%s" % [ART.FAMILIES[index], light])
    view.queue_free()
    await tree.process_frame
    await tree.process_frame

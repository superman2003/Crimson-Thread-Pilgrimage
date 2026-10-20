extends RefCounted
## Runs through the registered enemy_effect_lifetime entry with real GL.
const ART := preload("res://scripts/ground_hazard_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
var checks := 0
var failures := 0

class Target extends CharacterBody2D:
    var ui_input_locked := false
    var damage_received := 0
    var snares: Array[float] = []
    func take_damage(amount: int, _point: Vector2, _blockable: bool = true) -> void:
        damage_received += amount
    func apply_snare(seconds: float) -> void:
        snares.append(seconds)

class Reference extends Node2D:
    var family := ""
    var frame := 2
    var radius := 32.0
    var tint := Color.WHITE
    var paint: Callable
    func _draw() -> void:
        paint.call(self, family, frame, radius, tint)

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("GROUND_HAZARD_ART: " + label)

func run(tree: SceneTree, enemy) -> int:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/ground_hazards/manifest.json"))
    _check(manifest.families == ART.FAMILIES and manifest.floor_anchor == [96.0,144.0], "manifest and runtime floor registration agree")
    var atlas := ART.ATLAS.get_image()
    _check(atlas.get_size() == Vector2i(1536,1536), "one bounded atlas contains 64 cels")
    for family in ART.FAMILIES:
        var distinct := {}
        for frame in range(8):
            var cel := atlas.get_region(Rect2i(ART.atlas_rect(family,frame)))
            _check(not cel.is_invisible(), "%s/%d has authored pixels" % [family,frame])
            distinct[cel.get_data().hex_encode().sha256_text()] = true
        _check(distinct.size() == 8, family + " preserves eight distinct phases")
    _check(ART.frame_for(0,1) == -1 and ART.frame_for(.801,1) == 0 and ART.frame_for(.901,1) == 1, "appear occupies only the final 200ms of an unchanged warning")
    _check(ART.frame_for(.001,.1) == 0 and ART.frame_for(.051,.1) == 1, "short warning fits both appear frames without lengthening")
    for frame in range(4):
        _check(ART.frame_for(1 + frame / ART.ACTIVE_FPS + .001,1) == frame+2, "active loop cel %d" % frame)
    _check(ART.frame_for(2.999,1) >= 2 and ART.frame_for(0,0) == 2, "active never fades early and zero-warning begins fully formed")
    _check(ART.family_for("future") == "" and ART.family_for("seal",enemy) == "seal", "unknown fallback and explicit family remain available")
    var expected := {"spore_bellmaker":"fungus", "echo_moss_larva":"fungus", "rain_censer_mote":"haze", "pollen_lutist":"haze", "index_scribe":"seal", "echo_contract_scribe":"seal", "root_cage_hunter":"snare", "broken_string_gardener":"snare", "sunken_hammer_smith":"snare", "pilgrim_chariot":"caltrops", "delayed_shadow":"shadow", "silent_pilgrim_commander":"shadow", "isotope_lumen":"focus"}
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var old_kind: String = enemy.kind
    var seen := {}
    for kind in catalogue:
        var commands: Array = catalogue[kind].get("attacks", []).duplicate()
        commands.append_array(catalogue[kind].get("elite", {}).get("attacks", []))
        for command: Dictionary in commands:
            if command.get("type","") != "pool": continue
            enemy.kind = kind
            enemy.attack_target = Vector2(500,200)
            enemy._spawn_command_effects(command,true)
            var effects: Array = []
            for effect in enemy.owned_attack_effects:
                if is_instance_valid(effect) and not effect.is_queued_for_deletion(): effects.append(effect)
            _check(effects.size() == int(command.get("shot_count",1)), command.id + " preserves real spawn count")
            for effect in effects:
                effect.set_physics_process(false)
                var family := ART.family_for(effect.skin,enemy)
                _check(family == expected[kind], command.id + " selects authored family through actual command spawn")
                _check(is_equal_approx(effect.radius,float(command.radius)) and effect.damage == command.damage and is_equal_approx(effect.snare,float(command.get("snare",0))), command.id + " preserves radius damage and snare")
                _check(is_equal_approx(effect.arm_delay,float(command.windup)+float(command.warning)) and is_equal_approx(effect.duration-effect.arm_delay,float(command.hazard_life)), command.id + " preserves warning and lifetime")
                _check(is_equal_approx(effect.global_position.y,237) and effect.z_index == POLICY.DANGER_Z and not effect.z_as_relative, command.id + " keeps sampled floor and danger priority")
                seen[family] = true
                effect.cancel()
            await tree.process_frame
    enemy.kind = old_kind
    _check(seen.size() == 7, "all seven direct-pool families reached from catalogue")
    await _verify_pixels(tree,enemy)
    await _verify_lifetime(tree,enemy)
    print("GROUND_HAZARD_ART_VALIDATION checks=%d failures=%d families=8" % [checks,failures])
    return failures

func _verify_pixels(tree: SceneTree, enemy) -> void:
    _check(DisplayServer.get_name() != "headless", "render validation requires real GL")
    if DisplayServer.get_name() == "headless": return
    var view := SubViewport.new()
    view.size = Vector2i(640,320)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    tree.root.add_child(view)
    var stage := Node2D.new()
    view.add_child(stage)
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(640,0),Vector2(640,320),Vector2(0,320)])
    stage.add_child(background)
    var pools: Array[Node2D] = []
    var references: Array[Node2D] = []
    for index in range(8):
        var radius: float = [28,48,45,36,37,36,32,34][index]
        var pool: Node2D = enemy._effect("pool",Vector2.ZERO,Vector2.ZERO,{"skin":ART.FAMILIES[index],"radius":radius},1,2)
        pool.set_physics_process(false)
        pool.reparent(stage,false)
        pool.position = Vector2(index%4*160+40,index/4*160+85)
        pools.append(pool)
        var reference := Reference.new()
        reference.family = ART.FAMILIES[index]
        reference.radius = radius
        reference.tint = pool.tint
        reference.paint = ART.draw_frame
        reference.position = pool.position + Vector2(80,0)
        stage.add_child(reference)
        references.append(reference)
    for light in [false,true]:
        background.color = Color(.89,.87,.8) if light else Color(.08,.12,.14)
        var fingerprints: Array[Dictionary] = []
        for index in range(8): fingerprints.append({})
        var fades: Array[Node2D] = []
        for pool in pools: pool.show()
        for frame in range(8):
            if frame == 6:
                for index in range(8):
                    pools[index].hide()
                    var fade := ART.spawn_fade(stage,pools[index].position,ART.FAMILIES[index],pools[index].radius,pools[index].tint)
                    fade.set_process(false)
                    fades.append(fade)
            for index in range(8):
                references[index].tint = pools[index].tint
                references[index].frame = frame
                if frame < 2:
                    pools[index].age = .801 + frame * .1
                    references[index].tint.a = .55
                elif frame < 6:
                    pools[index].age = 1 + (frame-2) / ART.ACTIVE_FPS + .001
                else:
                    fades[index].age = (frame-6) / ART.FADE_FPS + .001
                    fades[index].queue_redraw()
                    references[index].tint.a = clampf((ART.FADE_SECONDS-fades[index].age)*ART.FADE_FPS,0,1)
                pools[index].queue_redraw()
                references[index].queue_redraw()
            await tree.process_frame
            await RenderingServer.frame_post_draw
            var image := view.get_texture().get_image()
            for index in range(8):
                var center: Vector2i = Vector2i(pools[index].position)
                # Interior excludes the safety ring. Compare the actual runtime
                # with separately painted source pixels, so a procedural fallback
                # or wrong family cannot pass merely by animating a ring.
                var actual := image.get_region(Rect2i(center-Vector2i(15,15),Vector2i(30,18)))
                var expected := image.get_region(Rect2i(center+Vector2i(65,-15),Vector2i(30,18)))
                # Separate canvas positions can differ by one framebuffer LSB
                # at a translucent edge. Larger per-channel errors still fail.
                var actual_bytes := actual.get_data()
                var expected_bytes := expected.get_data()
                var max_error := 0
                for offset in range(actual_bytes.size()): max_error = maxi(max_error,absi(int(actual_bytes[offset])-int(expected_bytes[offset])))
                _check(max_error <= 1, "%s/%d displays its source pixels light=%s" % [ART.FAMILIES[index],frame,light])
                if frame >= 2 and frame < 6: fingerprints[index][actual.get_data().hex_encode().sha256_text()] = true
                if frame == 2:
                    var visible := 0
                    for y in range(18):
                        for x in range(30):
                            var pixel := actual.get_pixel(x,y)
                            if Vector3(pixel.r-background.color.r,pixel.g-background.color.g,pixel.b-background.color.b).length() > .1: visible += 1
                    _check(visible > 15, "%s readable at gameplay radius on light=%s" % [ART.FAMILIES[index],light])
        for index in range(8): _check(fingerprints[index].size() == 4, ART.FAMILIES[index] + " has four rendered active cels")
        for fade in fades: fade.queue_free()
        await tree.process_frame
    view.queue_free()
    await tree.process_frame
    await tree.process_frame

func _verify_lifetime(tree: SceneTree, enemy) -> void:
    var stage: Node2D = enemy.get_parent()
    var target := Target.new()
    target.position = Vector2(300,242)
    stage.add_child(target)
    target.add_to_group("player")
    var pool: Node2D = enemy._effect("pool",Vector2(300,200),Vector2.ZERO,{"skin":"seal","radius":37,"damage":2,"snare":.9},1,1)
    pool.set_physics_process(false)
    pool._physics_process(.999)
    _check(target.damage_received == 0 and target.snares.is_empty(), "appear phase does not enable damage or slow")
    pool._physics_process(.002)
    _check(target.damage_received == 2 and target.snares == [.9], "warning boundary applies original damage and snare once")
    pool._physics_process(.5)
    _check(target.damage_received == 2 and target.snares.size() == 1 and not pool.cancelled, "persistent pool remains alive without repeat damage")
    _check(pool._hits_player(pool.global_position+Vector2(59.99,0)) and not pool._hits_player(pool.global_position+Vector2(60.01,0)), "original circular predicate includes player tolerance unchanged")
    var before := tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    target.ui_input_locked = true
    var saved_age: float = pool.age
    pool._physics_process(10)
    _check(pool.age == saved_age and not pool.cancelled, "UI lock still pauses hazard clock")
    target.ui_input_locked = false
    pool._physics_process(.5)
    _check(pool.cancelled and not pool.is_in_group("hostile_attack"), "expiry immediately unregisters the damaging object")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before+1, "natural expiry creates one separate safe fade")
    var mark: Node2D = tree.get_nodes_in_group(POLICY.CONTACT_GROUP).back()
    mark.set_process(false)
    _check(mark.family == "seal" and mark.global_position == Vector2(300,200) and not mark.is_in_group("hostile_attack"), "fade snapshots family and ground without collision")
    var sampled: Array[int] = []
    mark.paint = func(_host,_family,frame,_radius,_tint): sampled.append(frame)
    mark.age = .001
    mark._draw()
    mark.age = 1.0/ART.FADE_FPS+.001
    mark._draw()
    _check(sampled == [6,7], "both delivered fade cels play in order")
    mark.age = 0
    mark._process(.3)
    _check(not mark.is_queued_for_deletion(), "slow first frame has a draw opportunity")
    mark._process(.2)
    _check(mark.is_queued_for_deletion(), "safe fade expires within its two-frame lifetime")
    target.queue_free()
    await tree.process_frame
    before = tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    var cancelled: Node2D = enemy._effect("pool",Vector2.ZERO,Vector2.ZERO,{"skin":"snare"},0,1)
    cancelled.cancel()
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "cancellation emits no false natural fade")
    var skipped: Node2D = enemy._effect("pool",Vector2.ZERO,Vector2.ZERO,{"skin":"fungus"},1,1)
    skipped.set_physics_process(false)
    skipped._physics_process(3)
    _check(skipped.cancelled and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "skipped entire lifetime creates no phantom fade")
    var retired: Node2D = enemy._effect("pool",Vector2.ZERO,Vector2.ZERO,{"skin":"snare"},0,1)
    retired.set_physics_process(false)
    var was_dying: bool = enemy.dying
    enemy.dying = true
    retired._physics_process(2)
    enemy.dying = was_dying
    _check(retired.cancelled and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "owner retirement cancels even at expiry without leaving a fade")
    var wall := StaticBody2D.new()
    wall.position = Vector2(700,200)
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(10,100)
    collider.shape = shape
    wall.add_child(collider)
    stage.add_child(wall)
    await tree.physics_frame
    await tree.process_frame
    var old_kind: String = enemy.kind
    enemy.kind = "pipe_thrower"
    var mortar: Node2D = enemy._effect("projectile",Vector2(650,200),Vector2.RIGHT*500,{"skin":"metal","impact_pool":true},0,2)
    mortar.set_physics_process(false)
    mortar._physics_process(.2)
    _check(mortar.effect_kind == "pool" and ART.family_for(mortar.skin,enemy) == "slag", "real mortar wall collision reaches eighth family")
    _check(mortar.global_position.distance_to(Vector2(695,195)) < .1 and mortar.radius == 32 and mortar.arm_delay == .55 and mortar.duration == 1.4, "mortar preserves impact anchor radius warning and lifetime")
    mortar.cancel()
    enemy.kind = old_kind
    wall.queue_free()
    for i in range(20): ART.spawn_fade(stage,Vector2.ZERO,"slag",32,Color.WHITE)
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 12, "fade obeys shared twelve-decoration cap")
    var uncapped: Node2D = enemy._effect("pool",Vector2.ZERO,Vector2.ZERO,{"skin":"focus"},0,1)
    uncapped.set_physics_process(false)
    _check(uncapped.is_in_group("hostile_attack") and not uncapped.cancelled, "cosmetic saturation never culls a dangerous pool")
    uncapped.cancel()
    for node in tree.get_nodes_in_group(POLICY.CONTACT_GROUP): node.queue_free()
    await tree.process_frame

extends RefCounted
## Invoked by the registered lifecycle suite; independent source-pixel oracle.
const ART := preload("res://scripts/terrain_attack_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
var manifest: Dictionary

class Target extends CharacterBody2D:
    var ui_input_locked := false
    var damage_received := 0
    var facing := 1
    func can_deflect_projectile() -> bool: return true
    func take_damage(amount: int,_point: Vector2,_blockable: bool=true) -> void: damage_received += amount

class Terrain extends Node:
    var calls := 0
    func floor_height(x: float,_probe: float,_drop: float) -> float:
        calls += 1
        return 300+x*.05

class Arena extends Node2D:
    var chapter_terrain: Node

class Reference extends Node2D:
    var source := Rect2()
    var destination := Rect2()
    var mirror := 1.0
    var color := Color.WHITE
    func _draw() -> void:
        draw_set_transform(Vector2.ZERO,0,Vector2(mirror,1))
        draw_texture_rect_region(ART.ATLAS,destination,source,color)
        draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("TERRAIN_ATTACK_ART: "+label)

func run(tree: SceneTree,enemy) -> int:
    manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/terrain_attacks/manifest.json"))
    _check(manifest.families == ART.FAMILIES, "manifest family order matches runtime")
    var image := ART.ATLAS.get_image()
    _check(image.get_size() == Vector2i(1152,1024), "bounded atlas has expected dimensions")
    for family in ART.FAMILIES:
        var meta: Dictionary = manifest.sources[family]
        var seen := {}
        for frame in range(meta.frames.size()):
            var rect: Array = meta.frames[frame].atlas_rect
            _check(ART.atlas_rect(family,frame) == Rect2(rect[0],rect[1],rect[2],rect[3]), "%s/%d runtime uses delivered cel" % [family,frame])
            var cel := image.get_region(Rect2i(ART.atlas_rect(family,frame)))
            _check(not cel.is_invisible(), "%s/%d source pixels exist" % [family,frame])
            seen[cel.get_data().hex_encode().sha256_text()] = true
        _check(seen.size() == meta.frames.size(), family+" phases remain distinct")
    _check(ART.frame_for("eruption",.2,1) == -1 and ART.frame_for("eruption",.801,1) == 0 and ART.frame_for("eruption",.901,1) == 1, "eruption emerges only in last 200ms of unchanged warning")
    _check(ART.frame_for("eruption",0,0) == 2 and ART.frame_for("eruption",.051,.1) == 1, "zero and short warnings preserve damage boundary")
    _check(ART.frame_for("wave",.001,0) == 0 and ART.frame_for("wave",.084,0) == 1 and ART.frame_for("wave",.167,0) == 2, "wave rises then loops without delaying damage")
    _check(ART.frame_for("wave",.2,1) == -1, "future warned waves do not draw active art early")
    for i in range(8):
        _check(ART.frame_for("eruption",1+i/ART.FPS+.001,1) == 2+i%2, "eruption retains full-height hold until expiry")
    _check(ART.family_for("wave","roots") == "" and ART.family_for("eruption","quake") == "" and ART.family_for("wave","future") == "", "unknown and wrong-kind families retain fallback")
    await _catalogue(tree,enemy)
    await _pixels(tree,enemy)
    await _lifetime(tree)
    print("TERRAIN_ATTACK_ART_VALIDATION checks=%d failures=%d families=5 frames=36" % [checks,failures])
    return failures

func _catalogue(tree: SceneTree,enemy) -> void:
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var old_kind: String = enemy.kind
    var expected := {"corridor_heavy":"quake","rust_crown_guardian":"quake","bellroot_acolyte":"chime","silent_bugbler":"chime","obsidian_bellwheel":"chime","echo_waterwheel_knight":"chime","silent_crown_core":"chime","rust_diver":"surge"}
    var seen := {}
    var commands_seen := 0
    for kind in catalogue:
        var commands: Array = catalogue[kind].get("attacks",[]).duplicate()
        commands.append_array(catalogue[kind].get("elite",{}).get("attacks",[]))
        for command: Dictionary in commands:
            var type := String(command.get("type",""))
            if type not in ["wave","rootline"]: continue
            commands_seen += 1
            enemy.kind = kind
            enemy.attack_direction = -1
            enemy.attack_target = Vector2(500,200)
            enemy._spawn_command_effects(command,true)
            var effects: Array = []
            for node in enemy.owned_attack_effects:
                if is_instance_valid(node) and not node.is_queued_for_deletion(): effects.append(node)
            _check(effects.size() == int(command.get("shot_count",1)), command.id+" preserves real spawn count")
            for index in range(effects.size()):
                var effect: Node2D = effects[index]
                effect.set_physics_process(false)
                var want := String(expected.get(kind,"")) if type == "wave" else ("spears" if kind == "echo_pilgrim_commander_minor" else "roots")
                var family := ART.family_for(effect.effect_kind,effect.skin,enemy)
                _check(family == want, command.id+" selects its family through actual command")
                seen[family] = true
                _check(effect.damage == command.damage and effect.radius == float(command.get("radius",11)) and not effect.get_meta("blockable",true), command.id+" preserves damage radius and unblockable flag")
                if type == "wave":
                    var speed := float(command.get("projectile_speed",220))+floori(index/2)*float(command.get("speed_step",0))
                    _check(effect.velocity == Vector2((-1 if index%2==0 else 1)*speed,0), command.id+" preserves left/right and staggered speed")
                    _check(effect.arm_delay == 0 and effect.duration == 3, command.id+" preserves existing three-second travel")
                else:
                    var delay := float(command.windup)+float(command.warning)+index*.12
                    _check(is_equal_approx(effect.arm_delay,delay) and is_equal_approx(effect.duration-delay,float(command.get("hazard_life",.7))), command.id+" preserves per-spike stagger and lifetime")
                    var x: float = enemy.global_position.x-(index+1)*float(command.get("spacing",90))
                    var y: float = enemy.global_position.y+35
                    if command.get("targeted",false):
                        x=500+(index-(effects.size()-1)*.5)*float(command.get("spacing",90))
                        y=237
                    _check(effect.global_position.distance_to(Vector2(x,y)) < .001, command.id+" preserves line/target placement")
                _check(effect.z_index == POLICY.DANGER_Z and not effect.z_as_relative, command.id+" retains absolute danger priority")
                effect.cancel()
            await tree.process_frame
    enemy.kind = old_kind
    _check(commands_seen == 17 and seen.size() == 5, "all 17 current wave/rootline commands reach all five families")

func _set_reference(reference: Reference,family: String,frame: int,radius: float,direction: float,alpha: float,tint: Color) -> void:
    var meta: Dictionary = manifest.sources[family]
    var rect: Array = meta.frames[frame].atlas_rect
    reference.source = Rect2(rect[0],rect[1],rect[2],rect[3])
    var scale := Vector2.ONE*(radius*2/64.0) if meta.kind == "wave" else Vector2(radius*2/128.0,97.0/224.0)
    var anchor := Vector2(meta.floor_anchor[0],meta.floor_anchor[1])
    reference.destination = Rect2(Vector2(0,18 if meta.kind == "wave" else 5)-anchor*scale,Vector2(meta.cell[0],meta.cell[1])*scale)
    reference.mirror = -1 if meta.kind == "wave" and direction < 0 else 1
    reference.color = Color(tint,alpha) if family == "chime" else Color(1,1,1,alpha)
    reference.queue_redraw()

func _pixels(tree: SceneTree,enemy) -> void:
    _check(DisplayServer.get_name() != "headless", "real GL required for phase, direction and range pixels")
    if DisplayServer.get_name() == "headless": return
    var view := SubViewport.new()
    view.size = Vector2i(800,480)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    tree.root.add_child(view)
    var stage := Node2D.new(); view.add_child(stage)
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(800,0),Vector2(800,480),Vector2(0,480)])
    stage.add_child(background)
    var nodes: Array[Node2D] = []
    var references: Array[Reference] = []
    var radii := [11.0,23.0,16.0,26.0,22.0]
    for index in range(5):
        var kind := "wave" if index < 3 else "eruption"
        var node: Node2D = enemy._effect(kind,Vector2.ZERO,Vector2.RIGHT*200,{"skin":ART.FAMILIES[index],"radius":radii[index]},0 if index < 3 else 1,3)
        node.set_physics_process(false); node.reparent(stage,false)
        node.position = Vector2(index%3*260+60,index/3*240+150)
        nodes.append(node)
        var reference := Reference.new();reference.position=node.position+Vector2(120,0);stage.add_child(reference);references.append(reference)
    for light in [false,true]:
        background.color=Color(.89,.87,.8) if light else Color(.08,.12,.14)
        for direction in [-1.0,1.0]:
            var distinct: Array[Dictionary] = []
            for i in range(5): distinct.append({})
            for slot in range(8):
                var fades: Array[Node2D] = []
                for index in range(5):
                    var node: Node2D = nodes[index]
                    var wave := index < 3
                    var frame := slot if wave else mini(slot,5)
                    var alpha := .55 if not wave and slot < 2 else 1.0
                    var first_fade := 6 if wave else 4
                    var fade_phase := slot >= first_fade
                    if fade_phase:
                        node.hide()
                        var mark := ART.spawn_fade(stage,node.position,ART.FAMILIES[index],radii[index],direction,node.tint)
                        mark.set_process(false);mark.age=(frame-first_fade)/ART.FPS+.001;mark.queue_redraw();fades.append(mark)
                        alpha=clampf((ART.FADE_SECONDS-mark.age)*ART.FPS,0,1)
                    else:
                        node.show()
                        node.velocity.x=direction*200
                        node.age=slot/ART.FPS+.001 if wave else (.801+slot*.1 if slot < 2 else 1+(slot-2)/ART.FPS+.001)
                        node.queue_redraw()
                    _set_reference(references[index],ART.FAMILIES[index],frame,radii[index],direction,alpha,node.tint)
                await tree.process_frame
                await RenderingServer.frame_post_draw
                var image := view.get_texture().get_image()
                for index in range(5):
                    var point: Vector2i = Vector2i(nodes[index].position)
                    # Eruption interior avoids the four collision corner markers.
                    # Wave interior avoids its circular safety rim, while extending
                    # below the collision center to inspect floor registration.
                    var offset := Vector2i(-6,-1) if index < 3 else Vector2i(-14,-82)
                    var size := Vector2i(12,19) if index < 3 else Vector2i(28,84)
                    var actual := image.get_region(Rect2i(point+offset,size))
                    var expected := image.get_region(Rect2i(point+Vector2i(120,0)+offset,size))
                    var a := actual.get_data();var b := expected.get_data();var max_error := 0
                    # Mask circle-rim pixels; the source oracle paints only art.
                    for y in range(size.y):
                        for x in range(size.x):
                            var local := Vector2(offset+Vector2i(x,y))+Vector2(.5,.5)
                            if index < 3 and absf(local.length()-radii[index]) < 3.5: continue
                            if index >= 3 and slot < 2 and (absf(local.length()-radii[index]) < 4.5 or absf(local.y) < 4): continue
                            for channel in range(4):
                                var at := (y*size.x+x)*4+channel
                                max_error=maxi(max_error,absi(int(a[at])-int(b[at])))
                    _check(max_error <= 1,"%s phase=%d direction=%s light=%s uses registered source pixels" % [ART.FAMILIES[index],slot,direction,light])
                    if slot == 2:
                        var boundary := Vector2i(0,-int(radii[index])) if index < 3 else Vector2i(-int(radii[index]),-92)
                        var separation := 0
                        for by in range(-1,2):
                            for bx in range(-1,2):
                                var pixel := image.get_pixelv(point+boundary+Vector2i(bx,by))
                                var source_pixel := image.get_pixelv(point+Vector2i(120,0)+boundary+Vector2i(bx,by))
                                separation += int(absf(pixel.r-source_pixel.r)*255+absf(pixel.g-source_pixel.g)*255+absf(pixel.b-source_pixel.b)*255)
                        _check(separation > 100, ART.FAMILIES[index]+" keeps stable collision boundary outside painted silhouette")
                    if (index < 3 and slot in [2,3,4,5]) or (index >= 3 and slot in [2,3]): distinct[index][a.hex_encode().sha256_text()]=true
                for mark in fades: mark.queue_free()
                await tree.process_frame
            for index in range(5):
                _check(distinct[index].size() == (4 if index < 3 else 2), ART.FAMILIES[index]+" has a visibly changing active loop")
    view.queue_free()
    await tree.process_frame
    await tree.process_frame

func _lifetime(tree: SceneTree) -> void:
    var arena := Arena.new();tree.root.add_child(arena)
    var terrain := Terrain.new();arena.add_child(terrain);arena.chapter_terrain=terrain
    var enemy := ENEMY.new();arena.add_child(enemy);enemy.set_physics_process(false)
    var target := Target.new();arena.add_child(target);target.add_to_group("player");target.position=Vector2(800,242)
    var wave: Node2D = enemy._effect("wave",Vector2(100,280),Vector2.LEFT*200,{"skin":"surge","radius":16,"damage":2,"blockable":false},0,3)
    wave.set_physics_process(false);wave._physics_process(.1)
    _check(wave.global_position.distance_to(Vector2(80,286)) < .001 and terrain.calls == 1, "wave preserves actual leftward movement and sampled slope floor")
    target.position=wave.global_position+Vector2(0,42)
    wave._physics_process(.001)
    _check(target.damage_received == 2 and wave.hit_player and not wave.reflected and not wave.cancelled, "rising wave still damages once, remains active and cannot be parried")
    wave._physics_process(.001)
    _check(target.damage_received == 2, "persistent wave never deals a repeated hit")
    var saved_age: float = wave.age
    target.ui_input_locked=true;wave._physics_process(10);target.ui_input_locked=false
    _check(wave.age == saved_age and not wave.cancelled, "UI lock pauses travel and expiration")
    _check(wave._hits_player(wave.global_position+Vector2(38.99,0)) and not wave._hits_player(wave.global_position+Vector2(39.01,0)), "wave keeps original circular player-center tolerance")
    var eruption: Node2D = enemy._effect("eruption",Vector2(600,300),Vector2.ZERO,{"skin":"spears","radius":22,"damage":2,"blockable":false},1,.6)
    eruption.set_physics_process(false);target.position=Vector2(600,280)
    eruption._physics_process(.999)
    _check(target.damage_received == 2, "emerging spear tips cannot damage before original warning ends")
    eruption._physics_process(.002)
    _check(target.damage_received == 4 and eruption.hit_player, "full-height spear holds damage boundary unchanged")
    _check(eruption._hits_player(Vector2(578.01,208.01)) and not eruption._hits_player(Vector2(577.99,208)) and not eruption._hits_player(Vector2(600,207.99)) and not eruption._hits_player(Vector2(600,308)), "eruption retains exact 44x100 rectangle and exclusive bottom edge")
    target.position=Vector2(1000,1000)
    var before := tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    wave._physics_process(3)
    eruption._physics_process(.6)
    _check(wave.cancelled and eruption.cancelled and not wave.is_in_group("hostile_attack") and not eruption.is_in_group("hostile_attack"), "expiry immediately retires both dangerous objects")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before+2, "expiry emits two safe fade decorations")
    var selected: Array[int] = []
    for mark in tree.get_nodes_in_group(POLICY.CONTACT_GROUP):
        mark.set_process(false)
        _check(not mark.is_in_group("hostile_attack"), "fade has no damage group")
        if mark.family == "surge": _check(mark.global_position == wave.global_position and mark.direction < 0, "wave fade snapshots final floor point and direction")
        selected.clear()
        mark.paint=func(_host,_family,frame,_radius,_direction,_tint):selected.append(frame)
        mark.age=.001;mark._draw();mark.age=1/ART.FPS+.001;mark._draw()
        _check(selected == ([6,7] if mark.family == "surge" else [4,5]), "both safe terminal cels are selected in order")
        mark.age=0;mark._process(.3)
        _check(not mark.is_queued_for_deletion(), "slow first frame retains its first draw")
        mark._process(.2)
        _check(mark.is_queued_for_deletion(), "fade expires after two cels")
    await tree.process_frame
    before=tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    for kind in ["wave","eruption"]:
        var skin := "quake" if kind == "wave" else "roots"
        var cancelled: Node2D = enemy._effect(kind,Vector2.ZERO,Vector2.ZERO,{"skin":skin},0,1)
        cancelled.cancel()
        _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "cancelled "+kind+" has no residual fade")
        var skipped: Node2D = enemy._effect(kind,Vector2.ZERO,Vector2.ZERO,{"skin":skin},1,1)
        skipped.set_physics_process(false);skipped._physics_process(3)
        _check(skipped.cancelled and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "whole-life skipped "+kind+" emits no phantom fade")
        var retired: Node2D = enemy._effect(kind,Vector2.ZERO,Vector2.ZERO,{"skin":skin},0,1)
        retired.set_physics_process(false);enemy.dying=true;retired._physics_process(2);enemy.dying=false
        _check(retired.cancelled and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == before, "owner retirement clears "+kind+" even at expiry")
    for i in range(20): ART.spawn_fade(arena,Vector2.ZERO,"roots",24,1,Color.WHITE)
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 12, "terminal decorations share existing twelve-mark cap")
    var uncapped: Node2D = enemy._effect("eruption",Vector2.ZERO,Vector2.ZERO,{"skin":"roots"},0,1)
    uncapped.set_physics_process(false)
    _check(uncapped.is_in_group("hostile_attack") and not uncapped.cancelled, "decoration saturation never rejects dangerous eruptions")
    arena.queue_free()
    await tree.process_frame
    await tree.process_frame
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "scene retirement releases all terminal decorations")

extends SceneTree
## Exercises actual configured ordinary/elite attacks. No damage timing is derived from artwork.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/minor_enemy_skill_art.gd")
const SHARED_ART := preload("res://scripts/hand_drawn_assets.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const PROJECTILES := preload("res://scripts/projectile_art.gd")
const GROUND := preload("res://scripts/ground_hazard_art.gd")
const TERRAIN := preload("res://scripts/terrain_attack_art.gd")
const BEAMS := preload("res://scripts/beam_art.gd")
const EXECUTION_TYPES := ["melee","lunge","dive","guard","combo","vault","feint","blink","retreat"]
const CONTACT_TYPES := ["melee","lunge","dive","guard","combo","vault","feint","retreat"]
var checks := 0
var failures := 0

class Arena extends Node2D:
    var chapter_terrain: Node
    var wall_distance := -1.0
    func _rock_ray_hit(start: Vector2, finish: Vector2) -> Dictionary:
        return {"position":start+start.direction_to(finish)*wall_distance,"authored_rock":true} if wall_distance >= 0 else {}

class PausedTarget extends CharacterBody2D:
    var ui_input_locked := true

class ContactTarget extends CharacterBody2D:
    var ui_input_locked := false
    var hits := 0
    var received_damage := 0
    func take_damage(amount: int, _source: Vector2, _blockable: bool = true) -> void:
        hits += 1
        received_damage += amount

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("MINOR_ENEMY_SKILL_ART: " + label)

func live_marks(actor: Node, mode := "") -> Array[Node]:
    var result: Array[Node] = []
    for child in actor.get_children():
        if child.has_meta("minor_enemy_skill_art") and not child.is_queued_for_deletion() and (mode.is_empty() or child.get_meta("minor_enemy_skill_art") == mode): result.append(child)
    return result

func commands_for(profile: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for command: Dictionary in profile.get("attacks", []): result.append(command.duplicate(true))
    for command: Dictionary in profile.get("elite", {}).get("attacks", []): result.append(command.duplicate(true))
    return result

func freeze_effects(actor: Node) -> void:
    for effect in actor.owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion(): effect.set_physics_process(false)

func active_family(effect: Node) -> String:
    match effect.effect_kind:
        "projectile": return PROJECTILES.family_for(effect.skin,effect.owner_actor)
        "pool": return GROUND.family_for(effect.skin,effect.owner_actor)
        "beam": return BEAMS.family_for(effect.skin,effect.owner_actor)
        "wave", "eruption": return TERRAIN.family_for(effect.effect_kind,effect.skin,effect.owner_actor)
    return ""

func verify_cels(image: Image, entry: Dictionary, label: String) -> void:
    var frames: Array = entry.get("frames", [])
    check(frames.size() == 3,label + " has three authored cels")
    var unique: Dictionary = {}
    for frame in range(frames.size()):
        var rect := Rect2i(ART.source_rect(entry,frame))
        check(rect.size == Vector2i(192,192) and Rect2i(Vector2i.ZERO,image.get_size()).encloses(rect),label + " source rect stays inside registered atlas")
        if not Rect2i(Vector2i.ZERO,image.get_size()).encloses(rect): continue
        var cel := image.get_region(rect)
        check(not cel.is_invisible(),label + " cel %d contains authored pixels" % frame)
        unique[cel.get_data().hex_encode().sha256_text()] = true
    check(unique.size() == frames.size(),label + " preserves distinct animation contours")

func run() -> void:
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var registry := ART.registry()
    check(registry.get("creatures",{}).size() == 40,"all forty ordinary species registered")
    check(registry.get("commands",{}).size() == 90,"eighty base and ten elite attacks registered")
    if registry.get("creatures",{}).is_empty():
        print("MINOR_ENEMY_SKILL_ART_VALIDATION creatures=0 commands=0 executions=0 checks=%d failures=%d" % [checks,failures])
        quit(1)
        return
    var arena := Arena.new()
    root.add_child(arena)
    var command_count := 0
    var execution_count := 0
    var elite_count := 0
    for kind in registry.creatures:
        check(catalogue.has(kind),kind + " has a live combat profile")
        if not catalogue.has(kind): continue
        var actor = ENEMY.new()
        actor.configure({"kind":kind,"hp":40,"elite":true},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",false,catalogue[kind])
        actor.position = Vector2(400,300)
        arena.add_child(actor)
        actor.set_physics_process(false)
        check(actor.minor_skill_texture != null,kind + " prepares only its own atlas before combat")
        if actor.minor_skill_texture == null:
            RETIREMENT.retire_tree(actor)
            actor.queue_free()
            await process_frame
            continue
        var image: Image = actor.minor_skill_texture.get_image()
        check(image.get_size() == Vector2i(registry.creatures[kind].size[0],registry.creatures[kind].size[1]),kind + " imported atlas matches measured size")
        var calls_before := SHARED_ART.synchronous_texture_loads
        for command in commands_for(catalogue[kind]):
            var cid := String(command.id)
            command_count += 1
            if bool(command.get("elite_only",false)):
                elite_count += 1
                check(actor.is_elite and actor.ai_commands.any(func(a):return a.get("id","")==cid),cid + " is activated by the real elite profile")
            check(ART.matches(actor,command),cid + " matches its species and registered command")
            check(ART.ready_for(actor,command),cid + " has prepared texture and registered artwork")
            var entry: Dictionary = registry.commands.get(cid,{})
            verify_cels(image,entry.get("warning",{}),cid+" warning")
            if EXECUTION_TYPES.has(String(command.type)):
                execution_count += 1
                check(entry.has("execution"),cid + " has dedicated execution artwork")
                if entry.has("execution"): verify_cels(image,entry.execution,cid+" execution")
            for facing in [-1,1]:
                actor.direction = facing
                actor.attack_direction = facing
                actor.position = Vector2(400,300)
                actor.spawn_position = actor.position
                actor._begin_attack(command)
                freeze_effects(actor)
                var hazards := String(command.type) in ["beam","pool","rootline"]
                var warnings := live_marks(actor,"warning")
                check(actor.telegraph == null and actor.windup_vfx == null,cid + " authored warning replaces generic line and polygon")
                check(warnings.is_empty() if hazards else warnings.size()==1,cid + " warning belongs to the actual actor or independent hazard")
                for mark in warnings:
                    check(mark.direction == facing and mark.z_index == POLICY.WARNING_Z,cid + " primary cue retains committed facing and danger layer")
                check(is_equal_approx(actor.state_timer,float(command.windup)),cid + " preserves configured windup")
                if hazards:
                    check(actor.owned_attack_effects.size()==int(command.get("shot_count",1)),cid + " creates exactly the authored hazard count")
                    for index in range(actor.owned_attack_effects.size()):
                        var effect: Node2D = actor.owned_attack_effects[index]
                        check(effect.minor_command_id==cid,cid + " hazard retains originating command ID")
                        check(not effect.hit_player and effect.age<effect.arm_delay,cid + " hazard warning is initially unarmed")
                        check(not ART.hazard_entry(effect).is_empty(),cid + " exact ground/channel geometry resolves authored warning pixels")
                        check(is_equal_approx(effect.radius,float(command.get("radius",11))),cid + " warning preserves configured hazard radius")
                        var expected_delay := float(command.windup)
                        if command.type != "beam": expected_delay += float(command.get("warning",.65))+index*(.12 if command.type=="rootline" else 0)
                        check(is_equal_approx(effect.arm_delay,expected_delay),cid + " each warning keeps its real arm delay")
                        check(is_equal_approx(effect.duration-effect.arm_delay,float(command.get("hazard_life",.4 if command.type=="beam" else .7))),cid + " dangerous lifetime is unchanged")
                var target := PausedTarget.new()
                arena.add_child(target)
                target.add_to_group("player")
                var clock: float = actor.state_timer
                actor._physics_process(.12)
                await process_frame
                check(actor.combat_visuals_paused and actor.state_timer==clock,cid + " UI lock stops the production combat clock")
                target.remove_from_group("player")
                target.queue_free()
                actor._set_combat_visuals_paused(false)
                actor._update_windup(float(command.windup)+.001)
                freeze_effects(actor)
                check(actor.state=="active" and live_marks(actor,"warning").is_empty(),cid + " warning switches at release")
                check(is_equal_approx(actor.state_timer,float(command.active)),cid + " preserves configured active time")
                if EXECUTION_TYPES.has(String(command.type)):
                    check(not live_marks(actor,"execution").is_empty(),cid + " release shows dedicated active material")
                for effect in actor.owned_attack_effects:
                    check(effect.damage==int(command.get("damage",actor.damage)) and effect.get_meta("blockable")==bool(command.get("blockable",true)),cid + " visual selection does not rewrite damage or block rules")
                    check(not active_family(effect).is_empty() or not ART._hazard_extra(effect).get("execution",{}).is_empty(),cid + " independent dangerous object resolves authored active pixels")
                if String(command.type) in ["lunge","vault","combo","dive","retreat"]:
                    var before: Vector2 = actor.global_position
                    actor._update_active(minf(.07,float(command.active)*.2))
                    check(actor.global_position!=before,cid + " real attack movement remains active")
                    for mark in live_marks(actor,"execution"):
                        check(mark.global_position==actor.global_position,cid + " active silhouette follows its owner")
                actor._clear_telegraph()
                actor._cancel_attack_effects()
                check(live_marks(actor).is_empty(),cid + " interruption clears all actor-attached art immediately")
                check(actor.owned_attack_effects.is_empty(),cid + " cancellation clears independent hazard ownership")
                await process_frame
            if command.type=="beam":
                arena.wall_distance = 7
                var clipped: Node2D = actor._effect("beam",Vector2(100,100),Vector2.RIGHT,command,.5,.4)
                clipped.set_physics_process(false)
                check(is_equal_approx(clipped.length,7),cid + " wall truncates warning channel to seven pixels")
                check(clipped._hits_player(Vector2(103,100)) and not clipped._hits_player(Vector2(108,100)),cid + " collision still stops at the same clipped endpoint")
                check(not ART.hazard_entry(clipped).is_empty(),cid + " tiny clipped channel retains its authored warning")
                actor._cancel_attack_effects()
                arena.wall_distance = -1
                await process_frame
        check(SHARED_ART.synchronous_texture_loads==calls_before,kind + " no texture is synchronously loaded on attack/release")
        var reset_command: Dictionary = catalogue[kind].attacks[0]
        actor._begin_attack(reset_command)
        freeze_effects(actor)
        actor.reset_for_respawn()
        check(live_marks(actor).is_empty() and actor.owned_attack_effects.is_empty(),kind + " respawn removes every old cue and dangerous object")
        actor._begin_attack(reset_command)
        freeze_effects(actor)
        var effect_refs: Array[WeakRef] = []
        for effect in actor.owned_attack_effects: effect_refs.append(weakref(effect))
        actor.set_meta("world_residency_active",false)
        for mark in live_marks(actor): mark._process(.01)
        check(live_marks(actor).is_empty(),kind + " residency loss hides attached cues")
        RETIREMENT.retire_tree(actor)
        actor.queue_free()
        await process_frame
        await process_frame
        for ref in effect_refs: check(ref.get_ref()==null,kind + " owner retirement removes independent hazards")
    await verify_secondary_hazards(arena,catalogue,registry)
    await verify_support(arena,catalogue,registry)
    await verify_contact_attacks(arena,catalogue,registry)
    check(command_count==90 and execution_count==42 and elite_count==10,"all eighty base and ten elite commands covered, with forty-two missing executions supplied")
    check(ART.frame_for(0)==0 and ART.frame_for(.5)==1 and ART.frame_for(.999)==2 and ART.frame_for(1)==2,"warning never fades to invisible before release")
    RETIREMENT.retire_tree(arena)
    arena.queue_free()
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    await process_frame
    await process_frame
    check(await RETIREMENT.drain(self),"isolated rapid-attack fixture releases mixer references before exit")
    print("MINOR_ENEMY_SKILL_ART_VALIDATION creatures=40 commands=%d executions=%d checks=%d failures=%d" % [command_count,execution_count,checks,failures])
    quit(0 if failures==0 else 1)

func setup_actor(arena: Node, kind: String, profile: Dictionary, point: Vector2) -> Node2D:
    var actor=ENEMY.new()
    actor.configure({"kind":kind,"hp":8},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",false,profile)
    actor.position=point
    arena.add_child(actor)
    actor.set_physics_process(false)
    return actor

func verify_contact_attacks(arena: Arena, catalogue: Dictionary, registry: Dictionary) -> void:
    # The target has no contact collision shape: these probes exercise only the
    # authored weapon/body strike, not the enemy's ordinary touch damage.
    var target := ContactTarget.new()
    target.collision_layer = 0
    target.collision_mask = 0
    arena.add_child(target)
    target.add_to_group("player")
    var contact_count := 0
    for kind in registry.creatures:
        var actor := setup_actor(arena,kind,catalogue[kind],Vector2(400,300))
        for command in commands_for(catalogue[kind]):
            if String(command.type) not in CONTACT_TYPES: continue
            contact_count += 1
            var cid := String(command.id)
            var entry: Dictionary = registry.commands[cid]
            check(entry.get("execution",{}).get("topology","") in ["sweep","guard"],cid + " active material represents a contact strike rather than a casting point")
            for facing in [-1,1]:
                actor.direction = facing
                actor.attack_direction = facing
                actor.global_position = Vector2(400,300)
                actor.spawn_position = actor.global_position
                target.hits = 0
                target.received_damage = 0
                target.global_position = actor.contact_attack_rect(command).get_center()+Vector2(0,40)
                actor._begin_attack(command)
                actor._update_windup(float(command.windup)*.5)
                check(actor.state=="windup" and target.hits==0,cid + " near target remains unharmed during the real windup")
                check(actor.owned_attack_effects.is_empty(),cid + " contact anticipation does not create a remote damage object")
                actor._update_windup(float(command.windup)*.5+.001)
                check(actor.state=="active" and target.hits==0,cid + " visual release alone does not deal damage")
                check(actor.owned_attack_effects.is_empty(),cid + " contact release emits no projectile, beam or wave")
                target.global_position = actor.global_position+Vector2(facing*2000,0)
                var start: Vector2 = actor.global_position
                actor._update_active(float(command.active)*.68)
                freeze_effects(actor)
                check(target.hits==0,cid + " moving contact strike cannot damage a distant target")
                if String(command.type) in ["lunge","dive","vault","combo","retreat"]:
                    check(actor.global_position!=start,cid + " body movement supplies the attack travel")
                for effect in actor.owned_attack_effects:
                    check(effect.effect_kind=="pool" and bool(command.get("trail",false)),cid + " only an explicitly authored ground trail may accompany a contact strike")
                var strike: Rect2 = actor.contact_attack_rect(command)
                target.global_position = strike.get_center()+Vector2(0,40)
                actor._update_active(0)
                check(target.hits==1 and target.received_damage==int(command.get("damage",actor.damage)),cid + " active body or weapon hitbox damages its nearby target")
                var marks := live_marks(actor,"execution")
                check(not marks.is_empty(),cid + " near hit retains its dedicated active material")
                for mark in marks:
                    check(mark.global_position==actor.global_position and mark.direction==facing,cid + " contact material follows the moving body and committed facing")
                actor._update_active(0)
                check(target.hits==1,cid + " a held collision does not repeat the same strike hit")
                actor._cancel_attack_effects()
                actor._clear_telegraph()
                await process_frame
        RETIREMENT.retire_tree(actor)
        actor.queue_free()
        await process_frame
    check(contact_count==40,"all forty ordinary and elite contact attacks retain melee modules")
    target.remove_from_group("player")
    target.queue_free()
    await process_frame

func verify_secondary_hazards(arena: Arena, catalogue: Dictionary, registry: Dictionary) -> void:
    var wax:=setup_actor(arena,"wax_lancer",catalogue.wax_lancer,Vector2(400,300))
    var command:Dictionary=catalogue.wax_lancer.attacks[0]
    wax._begin_attack(command)
    wax._update_windup(float(command.windup)+.001)
    wax._update_active(.18)
    freeze_effects(wax)
    check(not wax.owned_attack_effects.is_empty(),"wax charge actually emits its delayed trail pool")
    for effect in wax.owned_attack_effects:
        if effect.effect_kind != "pool":continue
        check(effect.minor_command_id=="wax_charge","wax trail retains charge identity")
        check(is_equal_approx(effect.arm_delay,.35) and is_equal_approx(effect.duration,1.45),"wax trail retains .35 warning and 1.1 active seconds")
        check(not ART.hazard_entry(effect).is_empty(),"wax trail has its separate pool warning material")
        check(not ART._hazard_extra(effect).get("execution",{}).is_empty(),"wax trail has newly authored damaging pool pixels")
    if wax.minor_skill_texture!=null:
        verify_cels(wax.minor_skill_texture.get_image(),registry.get("extras",{}).get("wax_trail",{}).get("warning",{}),"wax trail warning")
        verify_cels(wax.minor_skill_texture.get_image(),registry.get("extras",{}).get("wax_trail",{}).get("execution",{}),"wax trail active")
    wax._cancel_attack_effects()
    wax._clear_telegraph()
    RETIREMENT.retire_tree(wax)
    wax.queue_free()
    await process_frame
    var pipe:=setup_actor(arena,"pipe_thrower",catalogue.pipe_thrower,Vector2(400,300))
    command=catalogue.pipe_thrower.attacks[0]
    arena.wall_distance=4
    var shot:Node2D=pipe._effect("projectile",Vector2(400,200),Vector2.RIGHT*200,command,0,2)
    shot.set_physics_process(false)
    shot._physics_process(.05)
    check(shot.effect_kind=="pool" and shot.minor_command_id=="pipe_mortar","real terrain hit converts mortar into an identified slag pool")
    check(is_equal_approx(shot.radius,32) and is_equal_approx(shot.arm_delay,.55) and is_equal_approx(shot.duration,1.4),"mortar impact warning keeps existing radius and independent clocks")
    check(not ART.hazard_entry(shot).is_empty(),"mortar impact resolves extra pool warning instead of projectile source cue")
    check(active_family(shot)=="slag","mortar impact continues to use authored slag active material")
    if pipe.minor_skill_texture!=null:verify_cels(pipe.minor_skill_texture.get_image(),registry.get("extras",{}).get("pipe_impact",{}).get("warning",{}),"mortar impact warning")
    arena.wall_distance=-1
    pipe._cancel_attack_effects()
    RETIREMENT.retire_tree(pipe)
    pipe.queue_free()
    await process_frame

func verify_support(arena: Arena,catalogue: Dictionary,registry: Dictionary) -> void:
    var imp:=setup_actor(arena,"ash_banner_imp",catalogue.ash_banner_imp,Vector2(300,300))
    var ally:=setup_actor(arena,"moss_larva",catalogue.moss_larva,Vector2(390,300))
    ally.hp=3
    var target:=PausedTarget.new()
    target.position=Vector2(550,300)
    target.ui_input_locked=false
    arena.add_child(target)
    target.add_to_group("player")
    var entries:Dictionary=registry.get("extras",{}).get("support",{})
    check(entries.has("channel") and entries.has("link") and entries.has("release"),"banner support has separate channel, link, and paid-success materials")
    if imp.minor_skill_texture!=null:
        for family in entries: verify_cels(imp.minor_skill_texture.get_image(),entries[family],"banner support "+family)
    check(imp._try_start_support(),"banner support starts through real ally selection")
    check(imp.state=="support" and imp.windup_vfx==null and live_marks(imp,"support").size()==1,"support channel uses authored material and connection instead of a line")
    var health:int=ally.hp
    target.ui_input_locked=true
    var clock:float=imp.state_timer
    imp._physics_process(.2)
    check(imp.state_timer==clock and ally.hp==health,"UI lock freezes support clock without giving free health")
    target.ui_input_locked=false
    imp._set_combat_visuals_paused(false)
    imp._update_support(imp.SUPPORT_WINDUP+.001,target)
    check(ally.hp==health+1 and imp.state=="recover","support success restores exactly the existing one HP")
    check(live_marks(imp,"support").is_empty(),"support success clears channel and connection immediately")
    var releases:=ally.get_children().filter(func(n):return n.has_meta("minor_enemy_support_release") and not n.is_queued_for_deletion())
    check(releases.size()==1,"support success alone creates its release feedback")
    for release in releases:release.queue_free()
    await process_frame
    imp.support_cooldown=0
    check(imp._try_start_support(),"support can start again after the authored cooldown fixture resets")
    health=ally.hp
    ally.set_meta("world_residency_active",false)
    imp._update_support(.1,target)
    check(ally.hp==health and live_marks(imp,"support").is_empty(),"leaving the active world cancels the link without healing")
    check(ally.get_children().all(func(n):return not n.has_meta("minor_enemy_support_release")),"cancelled support never emits success pixels")
    target.remove_from_group("player")
    target.queue_free()
    RETIREMENT.retire_tree(imp)
    RETIREMENT.retire_tree(ally)
    imp.queue_free()
    ally.queue_free()
    await process_frame

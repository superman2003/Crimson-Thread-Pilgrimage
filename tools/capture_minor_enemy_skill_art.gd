extends SceneTree
## Production configured actors and independent effects; native scale, both facings.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/minor_enemy_skill_art.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const FULL_SAMPLE_KINDS := ["moss_larva","spore_bellmaker","gear_sentinel","pipe_thrower","wax_lancer","ash_banner_imp","erasure_bailiff","root_cage_hunter","phase_censor","echo_pilgrim_commander_minor"]
var view: SubViewport
var output := ""
var selected := ""
var capture_count := 0

class Arena extends Node2D:
    var chapter_terrain: Node
    var wall_distance := -1.0
    func _rock_ray_hit(start: Vector2, finish: Vector2) -> Dictionary:
        return {"position":start+start.direction_to(finish)*wall_distance,"authored_rock":true} if wall_distance>=0 else {}

class Observer extends CharacterBody2D:
    var ui_input_locked := false

func _initialize() -> void: call_deferred("run")

func commands_for(profile: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for command: Dictionary in profile.get("attacks",[]): result.append(command.duplicate(true))
    for command: Dictionary in profile.get("elite",{}).get("attacks",[]): result.append(command.duplicate(true))
    return result

func capture(file: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(file+".webp"),true,.93)!=OK:
        push_error("Cannot save ordinary enemy material capture")
        quit(1)
        return
    capture_count += 1

func freeze_effects(actor: Node) -> void:
    for effect in actor.owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion(): effect.set_physics_process(false)

func sample_actor(actor: Node2D, warning: bool, slot: int) -> void:
    var command: Dictionary = actor.active_attack
    var progress: float = [.02,.5,.98][slot]
    if warning:
        actor.state_timer=float(command.windup)*(1.0-progress)
    else:
        var t: float = float(command.active)*[.04,.45,.9][slot]
        var difference := maxf(0,t-actor.attack_elapsed)
        if difference>0: actor._update_active(difference)
        freeze_effects(actor)
    for effect in actor.owned_attack_effects:
        if not is_instance_valid(effect) or effect.is_queued_for_deletion(): continue
        if warning:
            effect.age=effect.arm_delay*progress
        else:
            var life: float = effect.duration-effect.arm_delay
            var elapsed := minf(life*.8,[.01,.2,.45][slot])
            effect.age=effect.arm_delay+elapsed
            if effect.effect_kind in ["projectile","wave"]:
                var origin: Vector2 = effect.get_meta("gallery_origin",effect.global_position)
                effect.set_meta("gallery_origin",origin)
                effect.global_position=origin+effect.velocity*elapsed
        effect.queue_redraw()

func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Ordinary enemy material capture requires real GL")
        quit(1)
        return
    output=OS.get_environment("MINOR_ENEMY_SKILL_CAPTURE_DIR")
    if output.is_empty(): output="res://../artifacts/minor_enemy_skill_art"
    selected=OS.get_environment("MINOR_ENEMY_SKILL_CAPTURE_KIND")
    DirAccess.make_dir_recursive_absolute(output)
    var registry:=ART.registry()
    if registry.get("creatures",{}).is_empty():
        push_error("Ordinary enemy material manifest is missing")
        quit(1)
        return
    var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    view=SubViewport.new()
    view.size=Vector2i(1600,840)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var kinds:Array=registry.creatures.keys()
    kinds.sort()
    var command_total:=0
    var species_total:=0
    for kind in kinds:
        if not selected.is_empty() and selected!=kind:continue
        var commands:=commands_for(profiles[kind])
        var stage:=Arena.new()
        view.add_child(stage)
        var actors:Array[Node2D]=[]
        for row in range(commands.size()):
            var command:Dictionary=commands[row]
            command_total+=1
            for column in range(2):
                var base:=Vector2(column*800,row*280)
                var background:=Polygon2D.new()
                background.polygon=PackedVector2Array([base,base+Vector2(800,0),base+Vector2(800,280),base+Vector2(0,280)])
                background.color=Color(.07,.1,.12) if column==0 else Color(.86,.83,.75)
                stage.add_child(background)
                var label:=Label.new()
                label.position=base+Vector2(12,8)
                label.text=String(command.id)+( "  ELITE" if bool(command.get("elite_only",false)) else "")
                label.add_theme_color_override("font_color",Color(.92,.87,.74) if column==0 else Color(.12,.1,.08))
                stage.add_child(label)
                var actor=ENEMY.new()
                actor.configure({"kind":kind,"hp":40,"elite":true},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",false,profiles[kind])
                actor.direction=1 if column==0 else -1
                actor.position=base+Vector2(120 if column==0 else 680,205)
                actor.platform_min_x=base.x+20
                actor.platform_max_x=base.x+780
                stage.add_child(actor)
                actor.set_physics_process(false)
                actor._begin_attack(command)
                freeze_effects(actor)
                actors.append(actor)
        # Empty third row still receives both comparison backgrounds.
        if commands.size()==2:
            for column in range(2):
                var background:=Polygon2D.new()
                var at:=Vector2(column*800,560)
                background.polygon=PackedVector2Array([at,at+Vector2(800,0),at+Vector2(800,280),at+Vector2(0,280)])
                background.color=Color(.07,.1,.12) if column==0 else Color(.86,.83,.75)
                stage.add_child(background)
        var slots: Array = [0,1,2] if FULL_SAMPLE_KINDS.has(kind) else [1]
        for slot in slots:
            for actor in actors:sample_actor(actor,true,slot)
            await capture(kind+"_warning_"+str(slot))
        for actor in actors:
            actor._update_windup(float(actor.active_attack.windup)+.001)
            freeze_effects(actor)
        for slot in slots:
            for actor in actors:sample_actor(actor,false,slot)
            await capture(kind+"_active_"+str(slot))
        for actor in actors:
            actor._clear_telegraph()
            actor._cancel_attack_effects()
        await capture(kind+"_cleared")
        RETIREMENT.retire_tree(stage)
        stage.queue_free()
        await process_frame
        await process_frame
        if kind in ["wax_lancer","pipe_thrower","ash_banner_imp"]: await capture_extras(kind,profiles)
        species_total+=1
    view.queue_free()
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    await process_frame
    await process_frame
    if not await RETIREMENT.drain(self):quit(1);return
    print("MINOR_ENEMY_SKILL_CAPTURE creatures=%d commands=%d frames=%d directions=2 backgrounds=2 real_gl=true" % [species_total,command_total,capture_count])
    quit(0)

func extra_actor(stage: Node2D, kind: String, profile: Dictionary, point: Vector2, direction: int) -> Node2D:
    var actor=ENEMY.new()
    actor.configure({"kind":kind,"hp":8},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",false,profile)
    actor.direction=direction
    actor.position=point
    stage.add_child(actor)
    actor.set_physics_process(false)
    return actor

func capture_extras(kind: String,profiles: Dictionary) -> void:
    var stage:=Arena.new()
    view.add_child(stage)
    var actors:Array[Node2D]=[]
    var allies:Array[Node2D]=[]
    var effects:Array[Node2D]=[]
    var observer:=Observer.new()
    observer.position=Vector2(800,300)
    stage.add_child(observer)
    observer.add_to_group("player")
    for column in range(2):
        var base:=Vector2(column*800,0)
        var background:=Polygon2D.new()
        background.polygon=PackedVector2Array([base,base+Vector2(800,0),base+Vector2(800,840),base+Vector2(0,840)])
        background.color=Color(.07,.1,.12) if column==0 else Color(.86,.83,.75)
        stage.add_child(background)
        var label:=Label.new()
        label.position=base+Vector2(12,12)
        label.text=kind+"  "+("support channel / paid heal" if kind=="ash_banner_imp" else "secondary ground hazard")
        label.add_theme_color_override("font_color",Color(.92,.87,.74) if column==0 else Color(.12,.1,.08))
        stage.add_child(label)
        var direction:=1 if column==0 else -1
        var actor:=extra_actor(stage,kind,profiles[kind],base+Vector2(190 if column==0 else 610,360),direction)
        actors.append(actor)
        if kind=="ash_banner_imp":
            var ally:=extra_actor(stage,"moss_larva",profiles.moss_larva,base+Vector2(350 if column==0 else 450,360),direction)
            ally.hp=3
            allies.append(ally)
            actor._try_start_support()
            actor.state_timer=actor.SUPPORT_WINDUP*.5
        else:
            var command:Dictionary=profiles[kind].attacks[0]
            if kind=="wax_lancer":
                actor._begin_attack(command)
                actor._update_windup(float(command.windup)+.001)
                actor._update_active(.18)
                freeze_effects(actor)
                actor._clear_telegraph()
                for effect in actor.owned_attack_effects:
                    if effect.effect_kind=="pool":effects.append(effect)
            else:
                stage.wall_distance=4
                var effect:Node2D=actor._effect("projectile",actor.global_position+Vector2(direction*110,20),Vector2(direction*200,0),command,0,2)
                effect.set_physics_process(false)
                effect._physics_process(.05)
                stage.wall_distance=-1
                effects.append(effect)
    for effect in effects:
        effect.age=effect.arm_delay*.5
        effect.queue_redraw()
    await capture(kind+"_extra_warning")
    if kind=="ash_banner_imp":
        for index in range(actors.size()):
            # Use the production completion path; keep both targets within each
            # actor's normal engage window for the isolated support sample.
            observer.position=actors[index].global_position+Vector2(160 if index==0 else -160,0)
            actors[index]._update_support(actors[index].SUPPORT_WINDUP+.001,observer)
    else:
        for effect in effects:
            effect.age=effect.arm_delay+minf(.15,(effect.duration-effect.arm_delay)*.5)
            effect.queue_redraw()
    await capture(kind+"_extra_active")
    for actor in actors:
        actor._clear_telegraph()
        actor._cancel_attack_effects()
    observer.remove_from_group("player")
    RETIREMENT.retire_tree(stage)
    stage.queue_free()
    await process_frame
    await process_frame

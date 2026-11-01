extends SceneTree
## Production actors/effects in a real renderer, all 24 commands at native scale.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/boss_skill_art.gd")
var view: SubViewport
var stage: Node2D
var output := ""

class Arena extends Node2D:
    var chapter_terrain: Node

func _initialize() -> void: call_deferred("run")

func capture(file: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(file+".webp"),true,.95) != OK:
        push_error("Cannot save boss skill capture")
        quit(1)

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Boss skill capture requires real GL")
        quit(1)
        return
    output = OS.get_environment("BOSS_SKILL_CAPTURE_DIR")
    if output.is_empty(): output = "res://../artifacts/boss_skill_art"
    DirAccess.make_dir_recursive_absolute(output)
    view = SubViewport.new()
    view.size = Vector2i(1920,1040)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    for kind in ART.data.bosses:
        stage = Arena.new()
        view.add_child(stage)
        var actors: Array[Node2D] = []
        for row in range(4):
            var command: Dictionary = profiles[kind].attacks[row]
            for column in range(2):
                var base := Vector2(column*960,row*260)
                var background := Polygon2D.new()
                background.polygon = PackedVector2Array([base,base+Vector2(960,0),base+Vector2(960,260),base+Vector2(0,260)])
                background.color = Color(.07,.1,.12) if column == 0 else Color(.86,.83,.75)
                stage.add_child(background)
                var label := Label.new()
                label.position = base+Vector2(12,6)
                label.text = String(command.id)
                label.add_theme_color_override("font_color",Color(.9,.87,.75) if column==0 else Color(.12,.1,.08))
                stage.add_child(label)
                var actor = ENEMY.new()
                actor.configure({"kind":kind,"hp":24},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",true,profiles[kind])
                actor.direction = 1 if column == 0 else -1
                actor.position = base+Vector2(180 if column==0 else 780,204)
                stage.add_child(actor)
                actor.set_physics_process(false)
                actor._begin_attack(command)
                for effect in actor.owned_attack_effects: effect.set_physics_process(false)
                actors.append(actor)
        for slot in range(3):
            for actor in actors:
                actor.state_timer = float(actor.active_attack.windup)*(1.0-[.05,.5,.98][slot])
                for effect in actor.owned_attack_effects:
                    effect.age = effect.arm_delay*[.05,.5,.98][slot]
                    effect.queue_redraw()
            await capture(kind+"_warning_"+str(slot))
        for actor in actors:
            actor._update_windup(float(actor.active_attack.windup)+.001)
            for effect in actor.owned_attack_effects: effect.set_physics_process(false)
        for slot in range(4):
            for actor in actors:
                actor.attack_elapsed = float(actor.active_attack.active)*[.05,.32,.68,.93][slot]
                for effect in actor.owned_attack_effects:
                    effect.age = effect.arm_delay+[.01,.09,.17,.23][slot]
                    if effect.effect_kind in ["projectile","wave"]:
                        var flight: float = [.01,.18,.4,.6][slot]
                        effect.age = effect.arm_delay+flight
                        effect.position = actor.attack_start_position+Vector2(0,24) + effect.velocity*flight if effect.effect_kind == "wave" else actor.global_position+Vector2(actor.attack_direction*18,-22)+effect.velocity*flight
                    effect.queue_redraw()
            await capture(kind+"_active_"+str(slot))
        for actor in actors:
            actor._cancel_attack_effects()
            actor._clear_telegraph()
        await capture(kind+"_cleared")
        for actor in actors:
            actor.phase_pause = .45
            actor._set_enemy_animation("phase",true)
            ART.spawn_phase(actor)
        await capture(kind+"_phase")
        stage.queue_free()
        await process_frame
    view.queue_free()
    await process_frame
    await process_frame
    print("BOSS_SKILL_CAPTURE bosses=6 commands=24 directions=2 backgrounds=2 real_gl=true")
    quit(0)

extends SceneTree
## Exercises every configured command through the production actor/effect path.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/boss_skill_art.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO_DIRECTOR := preload("res://scripts/audio_director.gd")
var checks := 0
var failures := 0

class Arena extends Node2D:
    var chapter_terrain: Node
    var wall_distance := -1.0
    func _rock_ray_hit(start: Vector2, finish: Vector2) -> Dictionary:
        return {"position":start+start.direction_to(finish)*wall_distance,"authored_rock":true} if wall_distance >= 0 else {}

class PausedTarget extends CharacterBody2D:
    var ui_input_locked := true

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("BOSS_SKILL_ART: " + label)

func live_marks(actor: Node, mode: String) -> Array[Node]:
    var result: Array[Node] = []
    for child in actor.get_children():
        if not child.is_queued_for_deletion() and child.get_meta("boss_skill_art", "") == mode: result.append(child)
    return result

func run() -> void:
    var arena := Arena.new()
    root.add_child(arena)
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var commands := 0
    var executions := 0
    for kind in ART.data.bosses:
        var actor = ENEMY.new()
        actor.configure({"kind":kind,"hp":24},"res://assets/sprites/original_creatures/"+kind+"/manifest.json",true,profiles[kind])
        arena.add_child(actor)
        actor.set_physics_process(false)
        check(actor.boss_skill_texture != null, kind + " prepares only its own atlas")
        var image: Image = actor.boss_skill_texture.get_image()
        for command in profiles[kind].attacks:
            var cid := String(command.id)
            commands += 1
            check(ART.matches(actor, command), cid + " has a registered warning")
            for slot in ["warning", "execution"]:
                if not ART.data.commands[cid].has(slot): continue
                var hashes: Dictionary = {}
                for frame in range(6):
                    var cel := image.get_region(Rect2i(ART.source_rect(ART.data.commands[cid][slot], frame)))
                    check(not cel.is_invisible(), cid + " " + slot + " cel %d contains authored pixels" % frame)
                    hashes[cel.get_data().hex_encode().sha256_text()] = true
                check(hashes.size() == 6, cid + " " + slot + " preserves six distinct contours")
            for dir in [-1,1]:
                actor.direction = dir
                actor.position = Vector2(400,300)
                actor._begin_attack(command)
                check(live_marks(actor,"warning").size() == 1 and actor.windup_vfx == null and actor.telegraph == null, cid + " warning uses a sprite, no generic line/polygon")
                check(is_equal_approx(actor.state_timer,float(command.windup)), cid + " preserves configured windup")
                check(live_marks(actor,"warning")[0].direction == dir, cid + " warning follows committed facing")
                var delayed: Array[Node2D] = actor.owned_attack_effects.duplicate()
                for effect in delayed:
                    check(effect.boss_command_id == cid, cid + " hazard keeps its exact originating command")
                    check(not effect.hit_player and effect.age < effect.arm_delay, cid + " warning starts unarmed")
                var pause_target := PausedTarget.new()
                arena.add_child(pause_target)
                pause_target.add_to_group("player")
                var clock: float = actor.state_timer
                actor._physics_process(.12)
                await process_frame
                check(actor.state_timer == clock and actor.combat_visuals_paused, cid + " UI lock freezes the actual combat clock")
                pause_target.remove_from_group("player")
                pause_target.queue_free()
                actor._set_combat_visuals_paused(false)
                actor._update_windup(float(command.windup)+.001)
                check(actor.state == "active" and live_marks(actor,"warning").is_empty(), cid + " warning clears exactly at release")
                if ART.data.commands[cid].has("execution"):
                    check(not live_marks(actor,"execution").is_empty(), cid + " release uses dedicated execution art")
                    if dir == 1: executions += 1
                    if String(command.type) in ["vault","lunge","combo"]:
                        var before: Vector2 = actor.global_position
                        actor._update_active(.1)
                        check(actor.global_position != before and live_marks(actor,"execution")[0].global_position == actor.global_position, cid + " active art follows real movement")
                else:
                    check(not actor.owned_attack_effects.is_empty(), cid + " release uses existing projectile/terrain/beam art")
                    for effect in actor.owned_attack_effects:
                        var family := ""
                        match effect.effect_kind:
                            "projectile": family = preload("res://scripts/projectile_art.gd").family_for(effect.skin,actor)
                            "pool": family = preload("res://scripts/ground_hazard_art.gd").family_for(effect.skin,actor)
                            "beam": family = preload("res://scripts/beam_art.gd").family_for(effect.skin,actor)
                            "wave", "eruption": family = preload("res://scripts/terrain_attack_art.gd").family_for(effect.effect_kind,effect.skin,actor)
                        check(not family.is_empty(), cid + " live effect resolves authored active pixels")
                if cid == "boss_bride_mirror":
                    check(preload("res://scripts/projectile_art.gd").family_for("thorn",actor)=="blade", "mirror stab uses mirror-blade pixels instead of green thorns")
                actor._clear_telegraph()
                actor._cancel_attack_effects()
                check(live_marks(actor,"warning").is_empty() and live_marks(actor,"execution").is_empty(), cid + " interrupt clears all attached art immediately")
                await process_frame
            if command.type == "beam":
                arena.wall_distance = 7
                var effect: Node2D = actor._effect("beam",Vector2(100,100),Vector2.RIGHT,command,.5,.4)
                effect.set_physics_process(false)
                check(is_equal_approx(effect.length,7), cid + " retains obstruction-clipped warning length")
                check(effect._hits_player(Vector2(103,100)) and not effect._hits_player(Vector2(108,100)), cid + " retains clipped collision")
                actor._cancel_attack_effects()
                arena.wall_distance = -1
                await process_frame
        actor.phase_pause = .9
        ART.spawn_phase(actor)
        check(live_marks(actor,"phase").size() == 1, kind + " has dedicated phase charge art")
        actor._clear_telegraph()
        check(live_marks(actor,"phase").is_empty(), kind + " retirement clears phase art")
        RETIREMENT.retire_tree(actor)
        actor.queue_free()
        await process_frame
    check(commands == 24 and executions == 12, "all 24 enabled commands covered, 12 dedicated execution sheets")
    check(ART.frame_for(0)==0 and ART.frame_for(.99)==5 and ART.frame_for(1)==5,"warning remains visible through its final frame")
    RETIREMENT.retire_tree(arena)
    arena.queue_free()
    # This isolated fixture has no owning AudioDirector scene to close its cache.
    AUDIO_DIRECTOR._stream_cache.clear()
    AUDIO_DIRECTOR._npc_voice_cache.clear()
    await process_frame
    await process_frame
    check(await RETIREMENT.drain(self), "rapid attack fixture retires audio mixer references before exit")
    print("BOSS_SKILL_ART_VALIDATION commands=%d executions=%d checks=%d failures=%d" % [commands,executions,checks,failures])
    quit(0 if failures == 0 else 1)

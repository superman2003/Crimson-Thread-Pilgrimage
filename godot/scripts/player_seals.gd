extends RefCounted
## Seal state and mechanisms: readiness snapshots, practice energy, crest and the seal effects applied when a heal completes.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func seal_present(player: Node, id: String, stage: String) -> void:
    if player.seal_presentation == null and ResourceLoader.exists("res://scripts/seal_presentation.gd"):
        player.seal_presentation = Node2D.new()
        player.seal_presentation.set_script(load("res://scripts/seal_presentation.gd"))
        player.add_child(player.seal_presentation)
    if player.seal_presentation != null:
        player.seal_presentation.set("muted", float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) <= -70.0 if AudioServer.get_bus_index("SFX") >= 0 else false)
        player.seal_presentation.set("reduced_flash", not bool(player._accessibility().get("flash_enabled", true)))
        player.seal_presentation.play_action(id, stage, player.facing, {"range":player.attack_range})


static func seal_mechanism_ready(player: Node) -> bool:
    return bool(player.build_profile.get("mechanism_unlocked", true)) and (player._crest() != "crimson" or bool(player.build_profile.get("crimson_repaired", true)))


static func get_seal_mechanism_snapshot(player: Node) -> Dictionary:
    var state = {"label":"线势", "stacks":player.line_stacks, "max_stacks":3, "remaining":player.line_expiry}
    if player._crest() == "bell":
        state = {"label":"钟压", "stacks":player.bell_pressure, "max_stacks":2, "remaining":0.0}
    elif player._crest() == "salt":
        var count := 0
        for enemy in player.get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
                continue
            if enemy.get("salt_mark_timer") != null and float(enemy.get("salt_mark_timer")) > 0.0:
                count += 1
        state = {"label":"盐记", "stacks":count, "max_stacks":0, "remaining":0.0}
    state["unlocked"] = player._seal_mechanism_ready()
    state["heal_effect"] = "疾行" if player.heal_speed_timer > 0.0 else "抗击退" if player.heal_stability_timer > 0.0 else ""
    state["heal_remaining"] = maxf(player.heal_speed_timer,player.heal_stability_timer)
    return state


static func get_seal_combat_state(player: Node) -> Dictionary:
    return {"crest": String(player.build_profile.get("crest_id", "crimson")), "line_stacks": player.line_stacks, "bell_pressure": player.bell_pressure, "line_expiry": player.line_expiry, "heal_speed": player.heal_speed_timer, "heal_stability": player.heal_stability_timer}


static func seal_tick(player: Node, delta: float) -> void:
    player.line_expiry = maxf(0.0, player.line_expiry - delta)
    if player.line_expiry <= 0.0:
        player.line_stacks = 0
    player.heal_speed_timer = maxf(0.0, player.heal_speed_timer - delta)
    player.heal_stability_timer = maxf(0.0, player.heal_stability_timer - delta)
    player.status_resist_timer = maxf(0.0, player.status_resist_timer - delta)
    player._settle_practice_energy()


static func settle_practice_energy(player: Node) -> void:
    player.practice_energy = mini(player.practice_energy, player.energy)
    if player.practice_energy <= 0:
        player.practice_energy = 0
        return
    for node in player.get_tree().get_nodes_in_group("enemy"):
        if node is Node2D and (node.has_meta("seal_training_target") or node.has_meta("tool_training_target")) and node.global_position.distance_to(player.global_position) <= player.PRACTICE_ENERGY_RADIUS:
            return
    var unspent = player.practice_energy
    player.practice_energy = 0
    player.gain_energy(-unspent)


static func heal_airborne(player: Node) -> bool:
    return bool(player.build_profile.get("heal_airborne", false))


static func crest(player: Node) -> String:
    return String(player.build_profile.get("crest_id", "crimson"))


static func basic_seal_hit(player: Node) -> void:
    if player._crest() == "crimson" and player._seal_mechanism_ready():
        player.line_stacks = mini(3, player.line_stacks + 1)
        player.line_expiry = 3.5


static func seal_heal_completed(player: Node) -> void:
    if player._crest() == "crimson":
        player.heal_speed_timer = maxf(0.0,float(player.build_profile.get("heal_move_duration",2.5)))
    elif player._crest() == "bell":
        player.heal_stability_timer = maxf(0.0,float(player.build_profile.get("heal_knockback_duration",4.0)))
    elif player._crest() == "salt":
        for enemy in player.get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
                continue
            if enemy is Node2D and enemy.global_position.distance_to(player.global_position) <= 240.0 and enemy.has_method("extend_salt_mark_once"):
                enemy.extend_salt_mark_once(maxf(0.0,float(player.build_profile.get("heal_mark_extension",2.0))))
    if float(player.build_profile.get("status_buildup_mult", 1.0)) < 1.0:
        player.status_resist_timer = 3.0

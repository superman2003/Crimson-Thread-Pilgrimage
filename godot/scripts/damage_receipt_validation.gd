extends SceneTree
const EFFECT := preload("res://scripts/enemy_attack_effect.gd")
const CONTACT := preload("res://scripts/damage_contact.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func run() -> void:
    var stage := Node2D.new(); root.add_child(stage)
    var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate(); stage.add_child(player)
    player.set_physics_process(false); player.position = Vector2(150, 42)
    for mode in ["guard", "arrival", "invulnerable", "hurt", "wound"]:
        player.hp = 5; player.max_hp = 5; player.hurt_timer = 0; player.death_timer = 0; player.snare_timer = 0
        player.arrival_guard_timer = 1.0 if mode == "arrival" else 0.0
        player.debug_invulnerable = mode == "invulnerable"
        player.guard_timer = 0.4 if mode == "guard" else 0.0; player.guard_initial_duration = 0.42; player.facing = -1
        if mode == "hurt": player.hurt_timer = 0.2
        var effect := EFFECT.new(); effect.radius = 10; effect.velocity = Vector2(1000, 0); effect.snare = 1
        stage.add_child(effect); effect.set_physics_process(false)
        effect._resolve_swept_projectile(player, Vector2.ZERO, Vector2(300, 0), {})
        check(player.hp == (4 if mode == "wound" else 5), mode + " preserves authoritative health result")
        check((player.snare_timer > 0) == (mode == "wound"), mode + " only a real wound receives snare")
        effect.free()
    player.hurt_timer = 0; player.snare_timer = 0; player.debug_invulnerable = true
    check(not CONTACT.apply(player, 1, Vector2.ZERO, true), "invulnerability returns rejected receipt")
    player.debug_invulnerable = false; player.guard_timer = 0; player.arrival_guard_timer = 0
    check(CONTACT.apply(player, 1, Vector2.ZERO, true), "real damage returns accepted receipt")
    player.hurt_timer = 0; player.hp = 1
    check(CONTACT.apply(player, 1, Vector2.ZERO, false) and player.hp == 0, "lethal wound is still an accepted receipt")
    player.hp = 5; player.hurt_timer = 0; player.death_timer = 0; player.guard_timer = 0
    var enemy: Area2D = preload("res://scripts/enemy_actor.gd").new(); enemy.position = Vector2(100, 42)
    stage.add_child(enemy); enemy.set_physics_process(false); enemy.hp = 1; enemy.max_hp = 3
    var command := {"type": "melee", "damage": 1, "leech": true, "offset": 44, "hit_width": 100, "hit_height": 100}
    player.debug_invulnerable = true; enemy._try_damage_player(command)
    check(enemy.hp == 1, "rejected contact cannot grant enemy leech")
    player.debug_invulnerable = false; enemy.attack_has_hit = false; enemy._try_damage_player(command)
    check(enemy.hp == 2 and player.hp == 4, "accepted wound grants one enemy leech")
    enemy._try_damage_player(command)
    check(enemy.hp == 2, "repeated callback cannot duplicate leech")
    var dead := Node2D.new(); stage.add_child(dead); dead.free()
    check(not CONTACT.apply(dead, 1, Vector2.ZERO, true), "freed receiver rejected before method dispatch")
    var retirement := preload("res://scripts/audio_retirement.gd"); retirement.retire_tree(stage); stage.free(); await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    check(await retirement.drain(self), "real player audio retired")
    print("DAMAGE_RECEIPT checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

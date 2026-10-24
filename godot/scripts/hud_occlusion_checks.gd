extends RefCounted
## U03 on the production World HUD: a real enemy behind the top HUD and an
## enemy attack effect behind the tool cards fade only their own group, the
## groups return when clear, open overlays restore them, and beams count by
## their full length. Positions are placed by inverting the live camera.
const EFFECT := preload("res://scripts/enemy_attack_effect.gd")
const OCCLUSION := preload("res://scripts/hud_occlusion.gd")

func settle(ui: Node, frames: int = 6) -> void:
    for index in frames: ui._process(0.1)

func world_under(main: Node, screen_point: Vector2) -> Vector2:
    return main.get_viewport().get_canvas_transform().affine_inverse() * screen_point

func run(main: Node, check: Callable) -> void:
    main._close_overlays()
    var ui: Node = main.ui_shell
    # One HUD frame re-shows the cards an overlay had hidden.
    ui._process(0.0)
    var groups: Dictionary = ui._hud_groups()
    var top_rect := OCCLUSION.group_rect(groups.top)
    var tool_rect := OCCLUSION.group_rect(groups.tactical)
    check.call(top_rect.size.x > 100.0 and tool_rect.size.x > 100.0, "both HUD groups have real on-screen bounds")
    var enemy: Area2D
    for node in main.get_tree().get_nodes_in_group("enemy"):
        if node.has_method("world_residency_active") and node.world_residency_active() and not node.is_boss:
            enemy = node
            break
    check.call(enemy != null, "fixture finds a resident ordinary enemy")
    if enemy == null: return
    var home: Vector2 = enemy.global_position
    # Park every resident enemy off screen first so only the probe can cover a group.
    var parked := {}
    for node in main.get_tree().get_nodes_in_group("enemy"):
        parked[node] = (node as Node2D).global_position
        (node as Node2D).global_position = world_under(main, Vector2(-5000, -5000))
    var player_home: Vector2 = main.player.global_position
    var clear_rect: Rect2 = main.get_viewport().get_canvas_transform() * Rect2(main.player.global_position + OCCLUSION.PLAYER_RECT.position, OCCLUSION.PLAYER_RECT.size)
    settle(ui)
    var player_covering := top_rect.intersects(clear_rect) or tool_rect.intersects(clear_rect)
    check.call(player_covering or (ui.hud_group_alpha.top == 1.0 and ui.hud_group_alpha.tactical == 1.0), "with nothing behind it the HUD stays fully opaque")
    var hurt_offset: Vector2 = enemy.get_hurtbox_rect().get_center() - enemy.global_position
    enemy.global_position = world_under(main, top_rect.get_center()) - hurt_offset
    ui._process(1.0 / 60.0)
    check.call(ui.hud_group_alpha.top < 1.0 and ui.hud_group_alpha.top > OCCLUSION.FADED_ALPHA, "the top HUD starts fading on the first frame, not instantly")
    settle(ui)
    check.call(is_equal_approx(ui.hud_group_alpha.top, OCCLUSION.FADED_ALPHA) and is_equal_approx(ui.hud_card.modulate.a, OCCLUSION.FADED_ALPHA) and is_equal_approx(ui.healing_status.modulate.a, OCCLUSION.FADED_ALPHA), "an enemy behind the health and thread card fades that whole group")
    check.call(player_covering or ui.hud_group_alpha.tactical == 1.0, "the tool cards stay opaque while only the top group is covered")
    enemy.global_position = world_under(main, Vector2(-5000, -5000))
    settle(ui)
    check.call(ui.hud_group_alpha.top == 1.0 and ui.hud_card.modulate.a == 1.0, "the top HUD returns once the enemy leaves")
    var bolt: Node2D = EFFECT.new()
    bolt.set_physics_process(false)
    bolt.set_process(false)
    main.add_child(bolt)
    bolt.global_position = world_under(main, tool_rect.get_center())
    enemy.owned_attack_effects.append(bolt)
    settle(ui)
    check.call(is_equal_approx(ui.hud_group_alpha.tactical, OCCLUSION.FADED_ALPHA) and is_equal_approx(ui.tactical_cards[0].modulate.a, OCCLUSION.FADED_ALPHA), "a live enemy attack behind the tool cards fades them even while its owner is away")
    main._toggle_map()
    settle(ui)
    check.call(ui.hud_group_alpha.tactical == 1.0, "an open overlay restores the HUD it covers")
    main._close_overlays()
    enemy.owned_attack_effects.erase(bolt)
    bolt.free()
    settle(ui)
    check.call(ui.hud_group_alpha.tactical == 1.0, "a removed attack effect no longer fades the cards")
    var beam: Node2D = EFFECT.new()
    beam.set_physics_process(false)
    beam.set_process(false)
    main.add_child(beam)
    beam.effect_kind = "beam"
    beam.heading = Vector2.RIGHT
    beam.length = 300.0
    beam.radius = 10.0
    beam.global_position = Vector2(100, 200)
    var footprint := OCCLUSION.effect_rect(beam)
    check.call(footprint.has_point(Vector2(390, 200)) and footprint.has_point(Vector2(90, 200)) and not footprint.has_point(Vector2(450, 200)), "a beam's footprint spans its full length")
    beam.free()
    for node in parked: if is_instance_valid(node): (node as Node2D).global_position = parked[node]
    enemy.global_position = home
    main.player.global_position = player_home
    settle(ui)

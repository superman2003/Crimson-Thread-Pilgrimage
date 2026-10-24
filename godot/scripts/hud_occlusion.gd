extends RefCounted
## U03 combat readability: the HUD steps aside for the fight. When the player,
## a resident enemy or a live enemy attack effect sits behind a HUD group on
## screen, that group fades so the danger stays visible. Presentation only;
## nothing here changes input, hit tests or which HUD values are shown.
const FADED_ALPHA := 0.3
const FADE_RATE := 8.0
## Player body (Player.tscn CollisionShape2D: 34x84 at y -42) with sprite margin.
const PLAYER_RECT := Rect2(-24, -92, 48, 96)


## Screen-space rects of everything the HUD must not hide.
static func occupant_rects(level: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if level == null or not level.is_inside_tree():
		return rects
	var canvas := level.get_viewport().get_canvas_transform()
	var player := level.get("player") as Node2D
	if is_instance_valid(player) and player.is_inside_tree():
		rects.append(canvas * Rect2(player.global_position + PLAYER_RECT.position, PLAYER_RECT.size))
	for node in level.get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
			continue
		if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
			continue
		if enemy.get("dying") == true:
			continue
		if enemy.has_method("get_hurtbox_rect"):
			rects.append(canvas * (enemy.get_hurtbox_rect() as Rect2))
		var effects: Variant = enemy.get("owned_attack_effects")
		if effects is Array:
			for effect_node in effects:
				# Owners may still list effects that were already freed; never
				# cast a freed reference.
				if not is_instance_valid(effect_node):
					continue
				var effect := effect_node as Node2D
				if effect != null and effect.is_inside_tree() and not effect.is_queued_for_deletion():
					rects.append(canvas * effect_rect(effect))
	return rects


## World-space footprint of an enemy attack effect (beams span their length).
static func effect_rect(effect: Node2D) -> Rect2:
	var reach := maxf(24.0, float(effect.get("radius")) if effect.get("radius") != null else 24.0)
	var area := Rect2(effect.global_position - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	if String(effect.get("effect_kind")) == "beam":
		var heading: Variant = effect.get("heading")
		var length: Variant = effect.get("length")
		if heading is Vector2 and (length is float or length is int):
			var tip: Vector2 = effect.global_position + (heading as Vector2).normalized() * float(length)
			area = area.expand(tip - Vector2.ONE * reach).expand(tip + Vector2.ONE * reach)
	return area


## Screen-space bounds of the visible members of one HUD group.
static func group_rect(controls: Array) -> Rect2:
	var bounds := Rect2()
	var found := false
	for item in controls:
		var control := item as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		bounds = rect if not found else bounds.merge(rect)
		found = true
	return bounds if found else Rect2()


static func covered(group: Rect2, occupants: Array[Rect2]) -> bool:
	if group.size == Vector2.ZERO:
		return false
	for rect in occupants:
		if group.intersects(rect):
			return true
	return false


## Eases each group's alpha toward faded/clear; returns the new alpha.
static func step_alpha(current: float, faded: bool, delta: float) -> float:
	var target := FADED_ALPHA if faded else 1.0
	return move_toward(current, target, maxf(0.0, delta) * FADE_RATE)

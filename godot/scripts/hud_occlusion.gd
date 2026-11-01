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
	var effects_seen: Dictionary = {}
	if level == null or not level.is_inside_tree():
		return rects
	var canvas := level.get_viewport().get_canvas_transform()
	var player := level.get("player") as Node2D
	if is_instance_valid(player) and player.is_inside_tree():
		rects.append(canvas * Rect2(player.global_position + PLAYER_RECT.position, PLAYER_RECT.size))
	for node in level.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):continue
		var enemy := node as Node2D
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
			continue
		if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
			continue
		if enemy.get("dying") == true:
			continue
		if enemy.is_visible_in_tree() and enemy.has_method("get_hurtbox_rect"):
			rects.append(canvas * (enemy.get_hurtbox_rect() as Rect2))
		var effects: Variant = enemy.get("owned_attack_effects")
		if effects is Array:
			for effect_node in effects:
				_append_effect(rects, effects_seen, effect_node, canvas)
	# The effect owns its visible lifetime. A group-only attack can outlive a
	# stale owner list until its next physics cancellation; do not hide it.
	for effect in level.get_tree().get_nodes_in_group("hostile_attack"):
		_append_effect(rects, effects_seen, effect, canvas)
	return rects


static func _append_effect(rects: Array[Rect2], seen: Dictionary, value: Variant, canvas: Transform2D) -> void:
	if not is_instance_valid(value) or not value is Node2D:return
	var effect := value as Node2D
	if not effect.is_inside_tree() or effect.is_queued_for_deletion() or not effect.is_visible_in_tree() or effect.get("cancelled") == true:return
	if seen.has(effect.get_instance_id()):return
	seen[effect.get_instance_id()] = true
	var rect := effect_rect(effect)
	if rect.position.is_finite() and rect.size.is_finite():rects.append(canvas * rect)


## World-space footprint of an enemy attack effect (beams span their length).
static func effect_rect(effect: Node2D) -> Rect2:
	var radius: Variant = effect.get("radius")
	var reach := maxf(24.0, float(radius)) if (radius is int or radius is float) and is_finite(float(radius)) else 24.0
	var area := Rect2(effect.global_position - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	if String(effect.get("effect_kind")) == "beam":
		var heading: Variant = effect.get("heading")
		var length: Variant = effect.get("length")
		if heading is Vector2 and heading.is_finite() and (length is float or length is int) and is_finite(float(length)):
			var tip: Vector2 = effect.global_position + (heading as Vector2).normalized() * float(length)
			area = area.expand(tip - Vector2.ONE * reach).expand(tip + Vector2.ONE * reach)
	return area


## Screen-space bounds of the visible members of one HUD group.
static func group_rect(controls: Array) -> Rect2:
	var bounds := Rect2()
	var found := false
	for item in controls:
		if not is_instance_valid(item):continue
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
	if not is_finite(current):return target
	var elapsed := maxf(0.0, delta) if is_finite(delta) else 0.0
	return move_toward(clampf(current, FADED_ALPHA, 1.0), target, elapsed * FADE_RATE)

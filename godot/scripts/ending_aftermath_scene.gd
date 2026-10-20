extends Node2D
## N05: what the chosen ending left at a region's shrine. Drawn beside the lamp
## the player rests at, so the change is seen in the world, not only read in
## the journal. Colours follow the ending gates.
const LOOKS := {"bells": Color("f6d27a"), "barrier": Color("e8746f"), "names": Color("84e8f2")}
var look := "bells"
var elapsed := 0.0

func _ready() -> void:
	# Behind wayfinding signs (portal signs draw at -1): a decoration never hides a route.
	z_index = -2

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var tint: Color = LOOKS.get(look, LOOKS.bells)
	match look:
		"bells":
			# A small bell swinging on its frame, its sound rings widening.
			var swing := sin(elapsed * 2.4) * 0.22
			var hang := Vector2(0, -118)
			draw_line(Vector2(-26, -10), hang + Vector2(-26, 0), Color(tint, 0.7), 3.0)
			draw_line(Vector2(26, -10), hang + Vector2(26, 0), Color(tint, 0.7), 3.0)
			draw_line(hang + Vector2(-30, 0), hang + Vector2(30, 0), Color(tint, 0.8), 3.0)
			var bell := PackedVector2Array()
			for point in [Vector2(-5, 4), Vector2(-14, 26), Vector2(-17, 34), Vector2(17, 34), Vector2(14, 26), Vector2(5, 4)]:
				bell.append(hang + point.rotated(swing))
			draw_colored_polygon(bell, Color(tint, 0.85))
			for ring in 3:
				var t := fmod(elapsed * 0.5 + ring / 3.0, 1.0)
				draw_arc(hang + Vector2(0, 26), 22.0 + t * 70.0, PI * 1.1, PI * 1.9, 24, Color(tint, 0.5 * (1.0 - t)), 2.0)
		"barrier":
			# A stopped bell with a crack, and a stacked tide barrier beside the lamp.
			var hang := Vector2(-46, -112)
			draw_line(hang + Vector2(-22, 0), hang + Vector2(22, 0), Color(tint, 0.6), 3.0)
			var bell := PackedVector2Array([hang + Vector2(-5, 4), hang + Vector2(-14, 26), hang + Vector2(-17, 34), hang + Vector2(17, 34), hang + Vector2(14, 26), hang + Vector2(5, 4)])
			draw_colored_polygon(bell, Color(tint.darkened(0.45), 0.85))
			draw_polyline(PackedVector2Array([hang + Vector2(2, 8), hang + Vector2(-3, 18), hang + Vector2(4, 26), hang + Vector2(-1, 33)]), Color(tint, 0.9), 2.0)
			for row in 4:
				for column in 3 - row % 2:
					var corner := Vector2(16 + column * 26 + (row % 2) * 13, -14 - row * 13)
					draw_rect(Rect2(corner, Vector2(24, 11)), Color(tint.darkened(0.25), 0.9))
					draw_rect(Rect2(corner, Vector2(24, 11)), Color(tint, 0.6), false, 1.0)
			# The tide is close: a dark waterline breathing at the barrier's foot.
			var level := -4.0 + sin(elapsed * 1.6) * 3.0
			draw_line(Vector2(6, level), Vector2(104, level), Color(0.15, 0.25, 0.3, 0.8), 3.0)
		"names":
			# A rota board: names in turn, one line lit as the watch passes on.
			var board := Rect2(Vector2(22, -122), Vector2(58, 92))
			draw_line(Vector2(36, -30), Vector2(36, 0), Color(tint.darkened(0.4), 0.9), 3.0)
			draw_line(Vector2(66, -30), Vector2(66, 0), Color(tint.darkened(0.4), 0.9), 3.0)
			draw_rect(board, Color(0.1, 0.16, 0.18, 0.9))
			draw_rect(board, Color(tint, 0.8), false, 2.0)
			var lit := int(elapsed * 0.5) % 6
			for line in 6:
				var y := board.position.y + 14.0 + line * 13.0
				var width := 22.0 + float((line * 37) % 17)
				draw_line(Vector2(board.position.x + 8, y), Vector2(board.position.x + 8 + width, y), Color(tint, 1.0 if line == lit else 0.45), 2.0)

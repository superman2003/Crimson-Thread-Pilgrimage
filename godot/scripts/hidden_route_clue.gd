extends Node2D
## W04: a crack of warm light leaking from a hidden room into its entrance
## room, so the secret is something the player sees in the world rather than a
## line on the map. It dims once the hidden room has been found.
const LIGHT := Color("f3d9a0")
var clue_id := ""
var found := false
var elapsed := 0.0
var crack: PackedVector2Array

func _ready() -> void:
	z_index = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(clue_id)
	crack = PackedVector2Array()
	for index in 6:
		crack.append(Vector2(rng.randf_range(-7.0, 7.0), -30.0 + index * 12.0))

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var strength := 0.35 if found else 0.75 + 0.25 * sin(elapsed * 2.2)
	for ring in 4:
		draw_circle(Vector2.ZERO, 46.0 - ring * 10.0, Color(LIGHT, 0.05 * strength * (ring + 1)))
	draw_polyline(crack, Color(LIGHT, strength), 3.0, true)
	# Motes drift up through the gap: the room beyond has air moving in it.
	for mote in 4:
		var t := fmod(elapsed * 0.35 + mote * 0.25, 1.0)
		var x := sin(elapsed * 1.3 + mote * 1.7) * 9.0
		draw_circle(Vector2(x, 26.0 - t * 70.0), 2.0, Color(LIGHT, strength * (1.0 - t)))

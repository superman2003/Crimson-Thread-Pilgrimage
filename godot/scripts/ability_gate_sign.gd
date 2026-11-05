extends Node2D
## A01: a closed ability gate names the permanent ability that opens it. The
## pictogram is always on the gate face at eye height; the written name only
## appears while the Player is close, like interaction captions. The sign is a
## child of the gate body, so opening the gate removes it with the wall.
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")
const AMBER := Color(0.93, 0.67, 0.30)
const PLATE := Color(0.06, 0.07, 0.07, 0.86)
const NEAR := 180.0
const GLYPHS := ["thread_dash", "silk_wall_grip", "double_thread_jump", "thorn_downstrike", "lantern_phase", "crown_resonance", "echo_hook"]

var ability := ""
var ability_name := ""
var host: Node
var nearby := false


func _process(_delta: float) -> void:
    if not is_instance_valid(host):
        return
    var player: Variant = host.get("player")
    var close: bool = player is Node2D and is_instance_valid(player) and (player as Node2D).global_position.distance_to(global_position) <= NEAR
    if close != nearby:
        nearby = close
        queue_redraw()


func caption() -> String:
    return "需要 · " + ability_name if not ability_name.is_empty() else ""


func _draw() -> void:
    draw_circle(Vector2.ZERO, 17.0, PLATE)
    draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, AMBER, 2.0, true)
    _glyph(ability)
    if nearby and not caption().is_empty():
        var size := FONT.get_string_size(caption(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
        var box := Rect2(Vector2(-size.x * 0.5 - 8.0, -52.0), Vector2(size.x + 16.0, 24.0))
        draw_rect(box, PLATE)
        draw_rect(box, AMBER, false, 1.0)
        draw_string(FONT, Vector2(-size.x * 0.5, -35.0), caption(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMBER)


## One stroke pictogram per ability, readable at gameplay zoom.
func _glyph(id: String) -> void:
    match id:
        "thread_dash":
            for x in [-6.0, 3.0]:
                draw_polyline(PackedVector2Array([Vector2(x - 4, -7), Vector2(x + 4, 0), Vector2(x - 4, 7)]), AMBER, 2.5, true)
        "silk_wall_grip":
            draw_line(Vector2(6, -10), Vector2(6, 10), AMBER, 2.5, true)
            for y in [-5.0, 4.0]:
                draw_polyline(PackedVector2Array([Vector2(-6, y + 4), Vector2(2, y), Vector2(6, y)]), AMBER, 2.0, true)
        "double_thread_jump":
            for y in [-4.0, 5.0]:
                draw_polyline(PackedVector2Array([Vector2(-7, y + 4), Vector2(0, y - 3), Vector2(7, y + 4)]), AMBER, 2.5, true)
        "thorn_downstrike":
            draw_line(Vector2(0, -10), Vector2(0, 3), AMBER, 2.5, true)
            draw_polyline(PackedVector2Array([Vector2(-5, -2), Vector2(0, 4), Vector2(5, -2)]), AMBER, 2.5, true)
            draw_polyline(PackedVector2Array([Vector2(-9, 9), Vector2(-3, 7), Vector2(0, 10), Vector2(4, 7), Vector2(9, 9)]), AMBER, 2.0, true)
        "lantern_phase":
            for index in 8:
                var a := TAU * index / 8.0
                draw_line(Vector2.from_angle(a) * 6.0, Vector2.from_angle(a + 0.4) * 6.0, AMBER, 2.0, true)
            draw_circle(Vector2.ZERO, 2.5, AMBER)
        "crown_resonance":
            draw_circle(Vector2(0, 4), 2.5, AMBER)
            for radius in [6.0, 10.0]:
                draw_arc(Vector2(0, 4), radius, PI * 1.15, PI * 1.85, 10, AMBER, 2.0, true)
        "echo_hook":
            draw_line(Vector2(0, -10), Vector2(0, 3), AMBER, 2.5, true)
            draw_arc(Vector2(-4, 3), 4.0, 0.0, PI, 10, AMBER, 2.5, true)
        _:
            draw_circle(Vector2.ZERO, 3.0, AMBER)

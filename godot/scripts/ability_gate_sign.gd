extends Node2D
## A01: a closed ability gate names the permanent ability that opens it. The
## pictogram is always on the gate face at eye height; the written name only
## appears while the Player is close, like interaction captions. The sign is a
## child of the gate body, so opening the gate removes it with the wall.
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")
const AMBER := Color(0.93, 0.67, 0.30)
const RETURN_TINT := Color(0.69, 0.87, 0.68)
const PLATE := Color(0.06, 0.07, 0.07, 0.86)
const NEAR := 180.0
const GLYPHS := ["thread_dash", "silk_wall_grip", "double_thread_jump", "thorn_downstrike", "lantern_phase", "crown_resonance", "echo_hook"]
const SIGN_TEXTURES := {
    "thread_dash": preload("res://assets/sprites/art05/ability_signs/thread_dash.png"),
    "silk_wall_grip": preload("res://assets/sprites/art05/ability_signs/silk_wall_grip.png"),
    "double_thread_jump": preload("res://assets/sprites/art05/ability_signs/double_thread_jump.png"),
    "thorn_downstrike": preload("res://assets/sprites/art05/ability_signs/thorn_downstrike.png"),
    "lantern_phase": preload("res://assets/sprites/art05/ability_signs/lantern_phase.png"),
    "crown_resonance": preload("res://assets/sprites/art05/ability_signs/crown_resonance.png"),
    "echo_hook": preload("res://assets/sprites/art05/ability_signs/echo_hook.png"),
    "return_arrow": preload("res://assets/sprites/art05/ability_signs/return_arrow.png"),
}

var ability := ""
var ability_name := ""
var return_room := ""
var return_side := 0
var host: Node
var nearby := false
var showing_return := false


func _process(_delta: float) -> void:
    if not is_instance_valid(host):
        return
    var player: Variant = host.get("player")
    var close: bool = player is Node2D and is_instance_valid(player) and (player as Node2D).global_position.distance_to(global_position) <= NEAR
    var on_return_side: bool = close and return_side != 0 and not return_room.is_empty() \
        and (player.global_position.x - global_position.x) * return_side > 0.0
    if close != nearby or on_return_side != showing_return:
        nearby = close
        showing_return = on_return_side
        queue_redraw()


func caption() -> String:
    if showing_return:
        return "↑ " + tr(return_room)
    if ability_name.is_empty():
        return ""
    return tr("需要 · %s") % tr(ability_name)


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
        queue_redraw()


func _draw() -> void:
    var tint := RETURN_TINT if showing_return else AMBER
    var sign_key := "return_arrow" if showing_return else ability
    var sign_tex: Texture2D = SIGN_TEXTURES.get(sign_key)
    if sign_tex != null:
        draw_texture_rect(sign_tex, Rect2(-20.0, -20.0, 40.0, 40.0), false)
    else:
        draw_circle(Vector2.ZERO, 17.0, PLATE)
        draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, tint, 2.0, true)
        if showing_return:
            draw_line(Vector2(0, -8), Vector2(0, 8), tint, 2.0, true)
            draw_polyline(PackedVector2Array([Vector2(-6, -2), Vector2(0, -8), Vector2(6, -2)]), tint, 2.0, true)
        else:
            _glyph(ability)
    var label := caption()
    if nearby and not label.is_empty():
        var size := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
        var box := Rect2(Vector2(-size.x * 0.5 - 8.0, -52.0), Vector2(size.x + 16.0, 24.0))
        draw_rect(box, PLATE)
        draw_rect(box, tint, false, 1.0)
        draw_string(FONT, Vector2(-size.x * 0.5, -35.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)


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

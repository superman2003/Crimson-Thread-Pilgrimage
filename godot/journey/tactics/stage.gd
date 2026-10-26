extends Control
const MODEL := preload("res://journey/tactics/model.gd")
var attack: Dictionary = {}
var comparison: Dictionary = {}
var cursor := 0.0
var playing := true
var speed := 1.0
var target_distance := 180.0
const PHASE_COLORS := {"windup":Color("c5a86e"), "active":Color("d17e6e"), "recover":Color("7da799")}

func configure(a: Dictionary, b: Dictionary = {}) -> void:
    attack = a.duplicate(true)
    comparison = b.duplicate(true)
    custom_minimum_size = Vector2(500, 320)
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    queue_redraw()

func _process(delta: float) -> void:
    if not playing or attack.is_empty() or not is_visible_in_tree():
        return
    cursor += delta * speed
    var span := maxf(0.1, timeline_duration())
    if cursor > span + 0.5:
        cursor = 0.0
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0d2026"))
    if attack.is_empty():
        return
    var font := get_theme_default_font()
    var phase := MODEL.phase(attack, cursor)
    draw_string(font, Vector2(16, 28), "字段演示：%s · %.2f秒" % [phase.name, cursor], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e4d4b4"))
    _timeline(attack, Rect2(18, 45, size.x - 36, 24), Color("d2b784"))
    if not comparison.is_empty():
        _timeline(comparison, Rect2(18, 78, size.x - 36, 18), Color("83a6bc"))
    var origin := Vector2(65, 216)
    var span := maxf(500, float(attack.get("range", 300)))
    var scale_value := (size.x - 110) / span
    draw_line(Vector2(20, 241), Vector2(size.x - 20, 241), Color("4a6666"), 2, true)
    draw_rect(Rect2(origin - Vector2(10, 46), Vector2(20, 46)), Color("b7b5a0"))
    var target := origin + Vector2(target_distance * scale_value, 0)
    draw_rect(Rect2(target - Vector2(8, 40), Vector2(16, 40)), Color("84a7b4"), false, 2.0)
    var tint: Color = PHASE_COLORS.get(phase.id, Color("627977"))
    var range_value := float(attack.get("range", 200)) * scale_value
    draw_line(origin + Vector2(0, 20), origin + Vector2(range_value, 20), Color("756951"), 1, true)
    if phase.id == "active":
        _geometry(origin, scale_value, float(phase.progress), tint)
    elif phase.id == "windup":
        draw_arc(origin - Vector2(0, 22), 25, PI, PI + float(phase.progress) * PI, 24, tint, 2, true)
    draw_string(font, Vector2(16, 278), "灰：示意来源 · 蓝框：参考站位；不是实际命中判定", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b0c1b8"))
    draw_string(font, Vector2(16, 302), "下方几何使用目录尺寸，省略真实AI、重力校正、墙体与角色状态。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a1b4ab"))

func _timeline(value: Dictionary, area: Rect2, accent: Color) -> void:
    var duration := maxf(0.01, timeline_duration())
    for phase in MODEL.phases(value):
        var begin := float(phase.start) / duration
        var width := (float(phase.finish) - float(phase.start)) / duration
        var rect := Rect2(area.position + Vector2(begin * area.size.x, 0), Vector2(width * area.size.x, area.size.y))
        draw_rect(rect, PHASE_COLORS[phase.id])
    var x := area.position.x + clampf(cursor / duration, 0, 1) * area.size.x
    draw_line(Vector2(x, area.position.y - 4), Vector2(x, area.end.y + 4), accent, 2, true)

func _geometry(origin: Vector2, scale_value: float, progress: float, tint: Color) -> void:
    var type := String(attack.get("type", ""))
    var distance := float(attack.get("range", 200)) * scale_value
    var count := clampi(int(attack.get("shot_count", 1)), 1, 12)
    if type in ["fan", "nova", "projectile", "wave", "mortar"]:
        var spread := float(attack.get("spread", 0.4))
        for index in count:
            var angle := lerpf(-spread, spread, float(index) / maxi(1, count - 1))
            if type == "nova":
                angle = float(index) * TAU / count
            var point := origin - Vector2(0, 20) + Vector2.from_angle(angle) * distance * progress
            draw_circle(point, 4, tint)
    elif type in ["pool", "rootline"]:
        for index in count if type == "rootline" else 1:
            var x := float(attack.get("spacing", 85)) * (index + 1) if type == "rootline" else target_distance
            draw_arc(origin + Vector2(x * scale_value, 0), float(attack.get("radius", 35)) * scale_value, PI, TAU, 24, tint, 3, true)
    elif type == "beam":
        var length := float(attack.get("beam_length", 300)) * scale_value
        draw_line(origin - Vector2(0, 22), origin + Vector2(length, -22), tint, maxf(2, float(attack.get("radius", 10)) * scale_value), true)
    else:
        var offset := float(attack.get("offset", 50)) * scale_value
        var width := float(attack.get("hit_width", 90)) * scale_value
        var height := float(attack.get("hit_height", 70)) * scale_value
        var defaults := {"lunge":220.0, "vault":240.0, "combo":125.0}
        var translation := float(attack.get("lunge_speed", defaults.get(type, 0.0))) * float(attack.get("active", 0)) * progress * scale_value
        if type == "dive":
            translation = target_distance * progress * scale_value
        var rise := -sin(progress * PI) * float(attack.get("jump_height", 130)) * scale_value if type == "vault" else 0.0
        draw_rect(Rect2(origin + Vector2(offset + translation - width * 0.5, -height + rise), Vector2(width, height)), tint, false, 2.0)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y >= 40 and event.position.y <= 100:
        cursor = clampf((event.position.x - 18) / maxf(1, size.x - 36), 0, 1) * timeline_duration()
        playing = false
        queue_redraw()
        accept_event()

func timeline_duration() -> float:
    return maxf(MODEL.duration(attack), MODEL.duration(comparison))

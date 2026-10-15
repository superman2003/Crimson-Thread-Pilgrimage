extends Control
## Camera only transforms the presentation; the cartography frame never moves.
signal secondary_pressed(content_position: Vector2)
var content: Control
var zoom := 1.0
var dragging := false
var view := -1
func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
func reset() -> void:
    zoom = 1.0
    content.scale = Vector2.ONE
    content.position = Vector2.ZERO
func set_view(next: int) -> void:
    if next != view:
        view = next
        reset()
func magnify(factor: float, anchor: Vector2 = Vector2.INF) -> void:
    if not anchor.is_finite(): anchor = size * 0.5
    var next := clampf(zoom * factor, 1.0, 4.0)
    content.position = anchor - (anchor - content.position) * (next / zoom)
    zoom = next
    content.scale = Vector2.ONE * zoom
    clamp_pan()
func clamp_pan() -> void:
    content.position = content.position.clamp(size - content.size * zoom, Vector2.ZERO)
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            magnify(1.25, event.position)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            magnify(0.8, event.position)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if not dragging and Rect2(Vector2.ZERO, size).has_point(event.position):
                secondary_pressed.emit((event.position - content.position) / zoom)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
            accept_event()
    elif event is InputEventMouseMotion and dragging and zoom > 1.0:
        content.position += event.relative
        clamp_pan()
        accept_event()
func _input(event: InputEvent) -> void:
    # Release beyond the clipped viewport must also end a drag.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        dragging = false

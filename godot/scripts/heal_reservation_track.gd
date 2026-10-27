extends Control
## This is the already-paid channel's split, never another available-thread bar.
## Red = interruption loss; gold = refundable now; grey = capacity overflow.
const READOUT = preload("res://scripts/heal_resource_readout.gd")
var state: Dictionary = {}

static func segments(snapshot: Dictionary, extent: float) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var reserved := READOUT.whole(snapshot.get("reserved", 0))
    if not bool(snapshot.get("active", false)) or reserved <= 0 or not is_finite(extent) or extent <= 0:
        return result
    var loss := mini(reserved, READOUT.whole(snapshot.get("loss", 0)))
    var returned := mini(reserved - loss, READOUT.whole(snapshot.get("returned", 0)))
    var overflow := reserved - loss - returned
    var offset := 0.0
    var parts := [{"kind":"loss", "amount":loss},
        {"kind":"return", "amount":returned}, {"kind":"capacity", "amount":overflow}]
    for part in parts:
        if int(part.amount) <= 0:
            continue
        var width := extent * float(part.amount) / float(reserved)
        result.append({"kind":part.kind, "amount":part.amount,
            "rect":Rect2(offset, 0, width, 4)})
        offset += width
    return result

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    position = Vector2(30, 236)
    size = Vector2(300, 4)
    visible = false

func update_snapshot(snapshot: Dictionary, obscured: bool) -> void:
    var next_visible := bool(snapshot.get("active", false)) and not obscured and int(snapshot.get("reserved", 0)) > 0
    visible = next_visible
    if state == snapshot:
        return
    state = snapshot.duplicate(true)
    queue_redraw()

func _draw() -> void:
    for part in segments(state, size.x):
        var color: Color = {"loss":Color("c85450"), "return":Color("bca07a"), "capacity":Color("65726c")}[part.kind]
        draw_rect(part.rect, color)
        # Boundaries remain readable without depending only on colour.
        if part.kind == "capacity":
            var rect: Rect2 = part.rect
            var x := rect.position.x + 3.0
            while x < rect.end.x:
                draw_line(Vector2(x,0),Vector2(x-3,4),Color("dae0d8"),1)
                x += 6.0

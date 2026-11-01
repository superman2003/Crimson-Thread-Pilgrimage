extends RefCounted
## Read-only description of the actual paid channel, separate from the next
## heal's affordability. No timers, refunds, HP or inventory are changed here.
static func whole(value: Variant, fallback: int = 0) -> int:
    if not (value is int or value is float):
        return fallback
    if not is_finite(float(value)) or float(value) < 0 or float(value) > 1000000:
        return fallback
    return int(value)

static func seconds(value: Variant) -> float:
    if not (value is int or value is float) or not is_finite(float(value)):
        return 0.0
    return clampf(float(value), 0.0, 3600.0)

static func snapshot(heal: Dictionary, energy: int, maximum: int) -> Dictionary:
    var remaining := seconds(heal.get("remaining", 0))
    var duration := seconds(heal.get("duration", 0))
    var active := String(heal.get("reason", "")) == "channeling" and remaining > 0
    var reserved := whole(heal.get("reserved", 0)) if active else 0
    var loss := mini(reserved, whole(heal.get("interrupt_loss", 0)))
    var refundable := reserved - loss
    var capacity := maxi(0, maximum)
    var current := clampi(energy, 0, capacity)
    var returned := mini(refundable, capacity - current)
    var progress := clampf(1.0 - remaining / duration, 0.0, 1.0) if active and duration > 0 else 0.0
    return {
        "active": active,
        "reserved": reserved,
        "loss": loss,
        "refundable": refundable,
        "returned": returned,
        "capacity_limited": refundable > returned,
        "energy": current,
        "maximum": capacity,
        "remaining": remaining if active else 0.0,
        "progress": progress,
        "next_cost": whole(heal.get("cost", 0)),
        "amount": whole(heal.get("amount", 0)),
    }

static func present(state: Dictionary) -> Dictionary:
    if not bool(state.get("active", false)):
        return {"visible": false, "text": "", "detail": ""}
    var reserved := whole(state.get("reserved", 0))
    var loss := whole(state.get("loss", 0))
    var returned := whole(state.get("returned", 0))
    var text := "已预留 %d · 中断损失 %d · 可退回 %d" % [reserved, loss, returned]
    var detail := "本次疗伤已预留 %d 绯线，当前绯线不需要再次支付。\n" % reserved
    detail += "现在中断会损失 %d 绯线，最多退回 %d 绯线。" % [loss, returned]
    if bool(state.get("capacity_limited", false)):
        detail += "\n退款受当前绯线容量限制，超出容量的部分不会保留。"
    detail += "\n移动、跳跃、冲刺、受击会中断；不会因为查看此提示而中断。"
    return {"visible": true, "text": text, "detail": detail}

## Keep construction, presentation, theme and lifetime on the owning UI node.
static func create_label(parent: Control, font: Font, tint: Color) -> Label:
    var label := Label.new()
    label.name = "HealReservationReadout"
    label.position = Vector2(30, 208)
    label.size = Vector2(360, 25)
    label.clip_text = true
    label.mouse_filter = Control.MOUSE_FILTER_PASS
    label.add_theme_font_override("font", font)
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_color_override("font_color", tint)
    label.visible = false
    parent.add_child(label)
    return label

static func apply(label: Variant, heal: Dictionary, energy: int, maximum: int, obscured: bool) -> Dictionary:
    var state := snapshot(heal, energy, maximum)
    var view := present(state)
    if not is_instance_valid(label):
        return state
    var visible := bool(view.visible) and not obscured
    if label.visible != visible:
        label.visible = visible
    if label.text != String(view.text):
        label.text = String(view.text)
    if label.tooltip_text != String(view.detail):
        label.tooltip_text = String(view.detail)
    label.set_meta("heal_reservation", state.duplicate(true))
    return state

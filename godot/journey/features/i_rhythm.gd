extends "res://journey/fieldwork/sessionpanel.gd"
const DOMAIN := preload("res://journey/fieldwork/rhythm/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_rhythm", "name": "节奏训练台", "summary": "显式窗口击拍、可暂停时钟与节拍误差分析"}


func draw_session_controls(parent: Control) -> void:
    UI.button(
        parent,
        "击拍（T）",
        func():
            if _active():
                live.tap(_clock()),
        not _active()
    )


func accept_session_event(event: InputEvent, clock: float) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
        live.tap(clock)
        var window := _window()
        if window != null:
            window.set_input_as_handled()

extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/return_notes/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_return_notes", "name": "复访观察台", "summary": "已抵达地点复访问题、变化记录和复查优先级"}


func _current(parent: Control) -> void:
    super._current(parent)
    var current: Dictionary = domain.capture(context.snapshot())
    _sections(parent, domain.history_sections(data.records, current))


func _edit_requested(payload: Dictionary, id: String) -> void:
    if not domain.validate(payload) or not domain.index(payload).has(id):
        return
    draft = payload.duplicate(true)
    draft.room = id
    draft_title = "复访问题 · " + String(domain.index(payload)[id].name)
    draft_note = ""
    draft_favorite = false
    selected_id = 0
    tab = "editor"
    context.refresh()

extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/milestones/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_milestones", "name": "已获成长对照", "summary": "已取得能力、物资和任务状态的快照变化与归因"}


func _current(parent: Control) -> void:
    super._current(parent)
    _sections(parent, domain.history_sections(data.records))

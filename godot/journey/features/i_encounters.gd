extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/encounters/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_encounters", "name": "遭遇复盘单", "summary": "已击败敌人的攻击组合、窗口及个人风险对比"}
